local MiniTest = require('mini.test')
local explained = dofile('tests/helpers/explain_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The lines of the file every case writes code into.
local CODE = {
  'local M = {}',
  '',
  'function M.run(values)',
  '  return values',
  'end',
  '',
  'return M',
}

--- The import the code written below line 3 needs, at the top of the file.
local IMPORT = "local sorted = require('sorted')"

--- The line the code written below line 3 adds.
local SORTING = '  values = sorted(values)'

--- The answer that writes `SORTING` below line 3 and imports what it needs
--- at the top of the file.
local SORTING_WITH_AN_IMPORT = {
  summary = 'Sorts the values.',
  edits = {
    { line = 3, last = 3, old = { CODE[3] }, new = { CODE[3], SORTING }, why = 'Sorts them.' },
    { line = 1, last = 1, old = { CODE[1] }, new = { IMPORT, CODE[1] }, why = 'Imports sorted.' },
  },
}

--- `CODE` with `SORTING` below line 3.
local SORTED = { CODE[1], CODE[2], CODE[3], SORTING, CODE[4], CODE[5], CODE[6], CODE[7] }

--- The record the fake `claude` writes (`explained.start()` makes its folder).
local RECORD = vim.fs.joinpath(
  vim.fn.fnamemodify('.', ':p'):gsub('/$', ''),
  '.tests',
  'fixtures',
  'entry-write-file-record',
  'fake.jsonl'
)

--- Starts the child with `CODE` open in a project of its own, aineo
--- configured to run the fake `claude` with the settings `write`
--- (`vim.g.aineo`'s `write`), keys told apart after 100 ms, and the fake
--- answering `answer`.
---
---@param answer table
---@param write? table
local function start(answer, write)
  explained.start(child, 'entry-write-file', CODE, {
    claude = { cmd = explained.FAKE_CLAUDE },
    write = write,
  })
  child.o.timeoutlen = 100
  explained.answer_with(child, answer)
end

--- Types `keys` in the child and waits until it has settled.
---
---@param ... string
local function press(...)
  child.type_keys(...)
  vim.wait(explained.PATIENCE_MS, function()
    return not child.is_blocked()
  end, 20)
end

--- The lines the fake `claude` recorded, decoded, once it has recorded at
--- least `count` of them, or after `PATIENCE_MS`: two for each request, its
--- arguments and then what it read.
---
---@param count integer
---@return table[]
local function recorded(count)
  local lines = {}
  vim.wait(explained.PATIENCE_MS, function()
    lines = vim.uv.fs_stat(RECORD) and vim.fn.readfile(RECORD) or {}
    return #lines >= count
  end, 20)
  return vim.tbl_map(vim.json.decode, lines)
end

--- Presses `keys` on line 3 of the child, types the request in the float
--- that opens and sends it.
---
---@param keys string
local function ask_below_line_3(keys)
  child.cmd('3')
  press(keys)
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'Sort the values first.' })
  press('<CR>')
end

--- Whether the prompt `stdin` allows edits elsewhere in the file.
---
---@param stdin string
---@return boolean
local function allows_the_whole_file(stdin)
  return stdin:find('The code may also need edits elsewhere in this file:', 1, true) ~= nil
end

T['\\WW'] = MiniTest.new_set()

T['\\WW']['asks as \\W does, with write.deep_model and write.deep_effort and the read-only tools'] = function()
  start(SORTING_WITH_AN_IMPORT, { deep_model = 'opus', deep_effort = 'max' })

  ask_below_line_3('\\WW')

  local records = recorded(2)
  eq(vim.list_slice(records[1].argv, 8), {
    '--model',
    'opus',
    '--setting-sources',
    'user',
    '--tools',
    'Read,Grep,Glob',
    '--allowedTools',
    'Read,Grep,Glob',
    '--effort',
    'max',
  })
  eq(allows_the_whole_file(records[2].stdin), true)
end

T['\\WW']['opens a float that says what it does'] = function()
  start(SORTING_WITH_AN_IMPORT)
  child.cmd('3')

  press('\\WW')

  eq(
    child.lua_get('vim.api.nvim_win_get_config(0).title[1][1]'),
    ' Write code that may change the whole file: <CR> sends · q or <Esc> cancels '
  )
end

T['\\WW']['in Visual mode asks at once for the selected lines, allowing edits elsewhere'] = function()
  start(SORTING_WITH_AN_IMPORT)
  child.cmd('4')

  press('V', '\\WW')

  local stdin = recorded(2)[2].stdin
  eq(
    vim.startswith(
      stdin,
      'Write code in the file src/code.lua (language: lua) for the request lines 4 to 4 hold'
    ),
    true
  )
  eq(allows_the_whole_file(stdin), true)
end

T['\\W'] = MiniTest.new_set()

T['\\W']['alone still asks for code once the time for a second W is over'] = function()
  start(SORTING_WITH_AN_IMPORT)
  child.cmd('3')

  press('\\W')
  vim.wait(explained.PATIENCE_MS, function()
    return child.lua_get('vim.api.nvim_win_get_config(0).relative') ~= ''
  end, 20)

  eq(
    child.lua_get('vim.api.nvim_win_get_config(0).title[1][1]'),
    ' Write code, reading the project: <CR> sends · q or <Esc> cancels '
  )
end

T['\\W']['asks for code that does not allow edits elsewhere'] = function()
  start(SORTING_WITH_AN_IMPORT)

  ask_below_line_3('\\W')

  eq(allows_the_whole_file(recorded(2)[2].stdin), false)
end

--- Waits until the child's current buffer shows a preview, or
--- `PATIENCE_MS` is over.
local function wait_for_preview()
  vim.wait(explained.PATIENCE_MS, function()
    return child.lua_get([[#vim.api.nvim_buf_get_extmarks(0,
      vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {})]]) > 0
  end, 20)
end

--- Asks for `SORTING_WITH_AN_IMPORT` below line 3 with `keys` and waits
--- until it shows.
---
---@param keys string
local function show_sorting(keys)
  start(SORTING_WITH_AN_IMPORT)
  ask_below_line_3(keys)
  wait_for_preview()
end

--- Whether each of `keys` is mapped in Normal mode in the child's current
--- buffer.
---
---@param keys string[]
---@return boolean[]
local function mapped(keys)
  return child.lua(
    [[return vim.tbl_map(function(key)
      return vim.fn.maparg(key, 'n') ~= ''
    end, ...)]],
    { keys }
  )
end

--- The keys of written code that may edit the whole file, while it shows.
local KEYS = { '\\Wa', '\\Wr', '\\Wd', '\\WA', '\\WR', ']w', '[w' }

--- The lines of the child's current buffer.
---
---@return string[]
local function buffer_lines()
  return child.api.nvim_buf_get_lines(0, 0, -1, false)
end

T['the keys'] = MiniTest.new_set()

T['the keys']['are mapped while the proposals show, and go with the last decided'] = function()
  show_sorting('\\WW')
  local shown = mapped(KEYS)

  press('\\WR')

  eq(shown, { true, true, true, true, true, true, true })
  eq(mapped(KEYS), { false, false, false, false, false, false, false })
end

T['the keys']['of code written by \\W are its three alone'] = function()
  start({ summary = 'Sorts the values.', edits = { SORTING_WITH_AN_IMPORT.edits[1] } })
  ask_below_line_3('\\W')
  wait_for_preview()

  eq(mapped(KEYS), { true, true, true, false, false, false, false })
end

T['the keys']['leave a ]w of the user’s as it is'] = function()
  start(SORTING_WITH_AN_IMPORT)
  child.lua([[vim.keymap.set('n', ']w', '<Cmd>let g:mine = 1<CR>')]])

  ask_below_line_3('\\WW')
  wait_for_preview()

  eq(child.lua_get([[vim.fn.maparg(']w', 'n')]]), '<Cmd>let g:mine = 1<CR>')
end

T['the keys']['move between the proposals, wrapping'] = function()
  show_sorting('\\WW')

  press(']w')
  local after_next = child.fn.line('.')
  press(']w')
  local after_next_again = child.fn.line('.')
  press('[w')

  eq({ after_next, after_next_again, child.fn.line('.') }, { 1, 3, 1 })
end

T['the keys']['accept each proposal as one undo step'] = function()
  show_sorting('\\WW')

  press('\\Wa')
  press(']w', '\\Wa')
  local accepted = buffer_lines()
  press('u')
  local undone_once = buffer_lines()
  press('u')

  eq(accepted, vim.list_extend({ IMPORT }, SORTED))
  eq(undone_once, SORTED)
  eq(buffer_lines(), CODE)
end

T['the keys']['accept every proposal left as one undo step'] = function()
  show_sorting('\\WW')

  press('\\WA')
  local accepted = buffer_lines()
  press('u')

  eq(accepted, vim.list_extend({ IMPORT }, SORTED))
  eq(buffer_lines(), CODE)
end

T['the keys']['reject the proposal under the cursor alone'] = function()
  show_sorting('\\WW')

  press('\\Wr', ']w', '\\Wa')

  eq(buffer_lines(), vim.list_extend({ IMPORT }, CODE))
end

return T
