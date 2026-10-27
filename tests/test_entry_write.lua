local MiniTest = require('mini.test')
local explained = dofile('tests/helpers/explain_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The lines of the file every case writes code into: line 3 holds a
--- request, as a user types one in a comment.
local CODE = {
  'local M = {}',
  '',
  '-- a function that adds two values and returns the sum',
  '',
  'return M',
}

--- The code that fulfils the request.
local ADD = {
  'function M.add(a, b)',
  '  return a + b',
  'end',
}

--- The answer that writes `ADD` below line 1, which it keeps as it is.
local BELOW_LINE_1 = {
  summary = 'Adds two values.',
  edits = {
    {
      line = 1,
      last = 1,
      old = { CODE[1] },
      new = vim.list_extend({ CODE[1], '' }, ADD),
      why = 'Returns the sum of a and b.',
    },
  },
}

--- The answer that replaces the request of line 3 with `ADD`.
local REPLACING_THE_REQUEST = {
  summary = 'Adds two values.',
  edits = {
    { line = 3, last = 3, old = { CODE[3] }, new = ADD, why = 'Returns the sum of a and b.' },
  },
}

--- The record the fake `claude` writes (`explained.start()` makes its folder).
local RECORD = vim.fs.joinpath(
  vim.fn.fnamemodify('.', ':p'):gsub('/$', ''),
  '.tests',
  'fixtures',
  'entry-write-record',
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
  explained.start(child, 'entry-write', CODE, {
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

--- Presses `keys` on line 1 of the child, types the request in the float
--- that opens and sends it.
---
---@param keys string
local function ask_below_line_1(keys)
  child.cmd('1')
  press(keys)
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'A function that adds two values.' })
  press('<CR>')
end

T['\\w'] = MiniTest.new_set()

T['\\w']['asks with Haiku and no tool, at Claude Code’s own effort, by default'] = function()
  start(BELOW_LINE_1)

  ask_below_line_1('\\w')

  local argv = recorded(2)[1].argv
  eq(vim.json.decode(argv[5]).required, { 'summary', 'edits' })
  eq(vim.list_slice(argv, 8), {
    '--model',
    'haiku',
    '--setting-sources',
    'user',
    '--tools',
    '',
  })
end

T['\\w']['takes the model from write.model'] = function()
  start(BELOW_LINE_1, { model = 'sonnet' })

  ask_below_line_1('\\w')

  eq(recorded(2)[1].argv[9], 'sonnet')
end

T['\\W'] = MiniTest.new_set()

T['\\W']['asks with Sonnet at effort high, with the read-only tools alone, by default'] = function()
  start(BELOW_LINE_1)

  ask_below_line_1('\\W')

  eq(vim.list_slice(recorded(2)[1].argv, 8), {
    '--model',
    'sonnet',
    '--setting-sources',
    'user',
    '--tools',
    'Read,Grep,Glob',
    '--allowedTools',
    'Read,Grep,Glob',
    '--effort',
    'high',
  })
end

T['\\W']['takes the model and the effort from write.deep_model and write.deep_effort'] = function()
  start(BELOW_LINE_1, { deep_model = 'opus', deep_effort = 'max' })

  ask_below_line_1('\\W')

  local argv = recorded(2)[1].argv
  eq({ argv[9], argv[#argv] }, { 'opus', 'max' })
end

T[':Aineo write'] = MiniTest.new_set()

T[':Aineo write']['with a range asks at once for the lines of the range, as \\w does'] = function()
  start(REPLACING_THE_REQUEST)

  child.cmd('3,3Aineo write')

  local argv = recorded(2)[1].argv
  eq({ argv[9], argv[#argv] }, { 'haiku', '' })
  eq(vim.startswith(recorded(2)[2].stdin, 'Write code in the file src/code.lua'), true)
end

T[':Aineo write']['deep, with a range, asks as \\W does'] = function()
  start(REPLACING_THE_REQUEST)

  child.cmd('3Aineo write deep')

  local argv = recorded(2)[1].argv
  eq({ argv[9], argv[#argv] }, { 'sonnet', 'high' })
end

T[':Aineo write']['without a range opens the float of the request below the cursor'] = function()
  start(BELOW_LINE_1)

  child.cmd('Aineo write')

  eq(
    child.lua_get('vim.api.nvim_win_get_config(0).title[1][1]'),
    ' Write code: <CR> sends · q or <Esc> cancels '
  )
end

T[':Aineo write']['tells the user, and asks nothing, given a word but deep'] = function()
  start(REPLACING_THE_REQUEST)

  child.cmd('3Aineo write fast')

  eq(explained.told(child), {
    { message = 'aineo: :Aineo write takes one of deep', level = vim.log.levels.ERROR },
  })
end

T[':Aineo write']['offers deep after write'] = function()
  start(REPLACING_THE_REQUEST)

  eq(child.fn.getcompletion('Aineo write ', 'cmdline'), { 'deep' })
end

T['in Visual mode'] = MiniTest.new_set({ parametrize = { { '\\w' }, { '\\W' } } })

--- Whether the child is in a floating window.
---
---@return boolean
local function in_a_float()
  return child.lua_get('vim.api.nvim_win_get_config(0).relative') ~= ''
end

T['in Visual mode']['asks at once for the selected lines, with no float'] = function(keys)
  start(REPLACING_THE_REQUEST)
  child.cmd('3')

  press('V', keys)

  local stdin = vim.split(recorded(2)[2].stdin, '\n')
  eq(in_a_float(), false)
  eq(
    stdin[1],
    'Write code in the file src/code.lua (language: lua) for the request lines 3 to 3 hold,'
      .. ' as numbered below: those lines are the request, to be replaced by the code that fulfils it.'
  )
end

--- Waits until the child's current buffer shows a preview, or
--- `PATIENCE_MS` is over.
local function wait_for_preview()
  vim.wait(explained.PATIENCE_MS, function()
    return child.lua_get([[#vim.api.nvim_buf_get_extmarks(0,
      vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {})]]) > 0
  end, 20)
end

T['in Visual mode']['replaces the selected lines once \\Va accepts, and \\Vr leaves them'] = function(
  keys
)
  start(REPLACING_THE_REQUEST)
  child.cmd('3')
  press('V', keys)
  wait_for_preview()
  press('\\Vr')
  local rejected = child.api.nvim_buf_get_lines(0, 0, -1, false)
  press('V', keys)
  wait_for_preview()

  press('\\Va')

  eq(rejected, CODE)
  eq(
    child.api.nvim_buf_get_lines(0, 0, -1, false),
    { CODE[1], CODE[2], ADD[1], ADD[2], ADD[3], CODE[4], CODE[5] }
  )
end

T['the time limit'] = MiniTest.new_set()

--- Waits until the child was told something, or `PATIENCE_MS` is over.
local function wait_until_told()
  vim.wait(explained.PATIENCE_MS, function()
    return #explained.told(child) > 0
  end, 20)
end

T['the time limit']['of \\w is write.timeout_ms'] = function()
  start(REPLACING_THE_REQUEST, { timeout_ms = 300, deep_timeout_ms = 300000 })
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "5000"')
  child.cmd('3')

  press('V', '\\w')
  wait_until_told()

  eq(explained.told(child), {
    {
      message = 'aineo: writing code failed: Claude Code did not answer within 0.3 s',
      level = vim.log.levels.ERROR,
    },
  })
end

T['the time limit']['of \\W is write.deep_timeout_ms'] = function()
  start(REPLACING_THE_REQUEST, { timeout_ms = 300000, deep_timeout_ms = 400 })
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "5000"')
  child.cmd('3')

  press('V', '\\W')
  wait_until_told()

  eq(explained.told(child), {
    {
      message = 'aineo: writing code failed: Claude Code did not answer within 0.4 s',
      level = vim.log.levels.ERROR,
    },
  })
end

T['the keys'] = MiniTest.new_set()

T['the keys']['tell the user, and ask nothing, in a buffer that holds no file'] = function()
  start(REPLACING_THE_REQUEST)
  child.cmd('enew')

  press('\\w')

  eq(explained.told(child), {
    { message = 'aineo: code is written in the buffer of a file', level = vim.log.levels.ERROR },
  })
end

--- The rows of the child's screen once redrawn, white space at their ends
--- cut off.
---
---@return string[]
local function screen_rows()
  child.cmd('redraw')
  return vim.tbl_map(function(row)
    return vim.trim(table.concat(row))
  end, child.get_screenshot().text)
end

T['the keys']['of code whose lines changed name the key that asked it, which asks again'] = function()
  local stale_head = '┊ the code under the fix changed · \\Vr rejects · \\W asks again'
  start(REPLACING_THE_REQUEST)
  child.cmd('3')
  press('V', '\\W')
  wait_for_preview()

  child.bo.modifiable = true
  child.api.nvim_buf_set_text(0, 2, 0, 2, 0, { 'x' })
  vim.wait(explained.PATIENCE_MS, function()
    return vim.tbl_contains(screen_rows(), stale_head)
  end, 20)

  eq(vim.tbl_contains(screen_rows(), stale_head), true)
end

T['the keys']['with no prefix name the <Plug> mapping that asks again'] = function()
  local stale_end = '┊ <Plug>(aineo-write) asks again'
  explained.start(child, 'entry-write', CODE, {
    claude = { cmd = explained.FAKE_CLAUDE },
    prefix = false,
  })
  explained.answer_with(child, REPLACING_THE_REQUEST)
  child.cmd('3')
  child.cmd('execute "normal V\\<Plug>(aineo-write)"')
  wait_for_preview()

  child.bo.modifiable = true
  child.api.nvim_buf_set_text(0, 2, 0, 2, 0, { 'x' })
  vim.wait(explained.PATIENCE_MS, function()
    return vim.tbl_contains(screen_rows(), stale_end)
  end, 20)

  eq(vim.tbl_contains(screen_rows(), stale_end), true)
end

T['the keys']['have their <Plug> mappings in Normal and in Visual mode'] = function()
  start(REPLACING_THE_REQUEST)

  eq(
    child.lua_get([[vim.tbl_map(function(name)
      return { vim.fn.maparg(name, 'n') ~= '', vim.fn.maparg(name, 'x') ~= '' }
    end, { '<Plug>(aineo-write)', '<Plug>(aineo-write-deep)' })]]),
    { { true, true }, { true, true } }
  )
end

return T
