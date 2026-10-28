local MiniTest = require('mini.test')
local explained = dofile('tests/helpers/explain_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The lines of the file every case fixes.
local CODE = {
  'local function add(a, b)',
  '  return a - b',
  'end',
  '',
  'return add',
}

--- The record the fake `claude` writes (`explained.start()` makes its folder).
local RECORD = vim.fs.joinpath(
  vim.fn.fnamemodify('.', ':p'):gsub('/$', ''),
  '.tests',
  'fixtures',
  'entry-explain-fix-record',
  'fake.jsonl'
)

--- The fix of the issue on line 2.
local FIX = {
  summary = 'Add.',
  edits = {
    { line = 2, last = 2, old = { '  return a - b' }, new = { '  return a + b' }, why = 'Adds.' },
    {
      line = 5,
      last = 5,
      old = { 'return add' },
      new = { 'return { add = add }' },
      why = 'Exports.',
    },
  },
}

--- Starts the child with `CODE` open in a project of its own, aineo
--- configured to run the fake `claude` with the settings `explain`
--- (`vim.g.aineo`'s `explain`), keys told apart after 100 ms, an issue shown
--- above line 2, the cursor on it, and the fake answering `FIX`.
---
---@param explain? table
local function start(explain)
  explained.start(child, 'entry-explain-fix', CODE, {
    claude = { cmd = explained.FAKE_CLAUDE },
    explain = explain,
  })
  child.o.timeoutlen = 100
  explained.place(child, 'issues', { { line = 2, text = 'Subtracts where it should add.' } })
  explained.answer_with(child, FIX)
  child.cmd('2')
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
--- least `count` of them, or after `PATIENCE_MS`.
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

--- Waits until no fix request runs in the child, or `PATIENCE_MS` is over.
local function wait_for_answer()
  vim.wait(explained.PATIENCE_MS, function()
    return child.lua_get([[#vim.api.nvim_buf_get_extmarks(0,
      vim.api.nvim_create_namespace('aineo_explain_fix'), 0, -1, {})]]) == 0
  end, 20)
end

--- How many extmarks the child's current buffer holds in the namespace
--- named `name`.
---
---@param name string
---@return integer
local function marks_in(name)
  return child.lua_get(
    '#vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace(...), 0, -1, {})',
    { name }
  )
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

--- Starts the child as `start()` does, but with `prefix = false`: aineo
--- maps no key.
local function start_without_prefix()
  explained.start(child, 'entry-explain-fix', CODE, {
    claude = { cmd = explained.FAKE_CLAUDE },
    prefix = false,
  })
  explained.place(child, 'issues', { { line = 2, text = 'Subtracts where it should add.' } })
  explained.answer_with(child, FIX)
  child.cmd('2')
end

--- Edits line 2 of the child's current buffer, under the fix it shows, its
--- 'modifiable' turned back on first, as a user forcing an edit does, and
--- waits until the screen shows the row `row`, or `PATIENCE_MS` is over.
---
---@param row string
local function force_edit_until_shown(row)
  child.bo.modifiable = true
  child.api.nvim_buf_set_text(0, 1, 2, 1, 2, { 'x' })
  vim.wait(explained.PATIENCE_MS, function()
    return vim.tbl_contains(screen_rows(), row)
  end, 20)
end

T['\\Vf'] = MiniTest.new_set()

T['\\Vf']['asks a fix of the issue on the line with the read-only tools, Sonnet and effort high by default'] = function()
  start()

  press('\\Vf')

  local argv = recorded(3)[3].argv
  eq(vim.json.decode(argv[5]).required, { 'summary', 'edits' })
  eq(vim.list_slice(argv, 8), {
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

T['\\Vf']['takes the model and the effort from explain.fix_model and explain.fix_effort'] = function()
  start({ fix_model = 'opus', fix_effort = 'max' })

  press('\\Vf')

  local argv = recorded(3)[3].argv
  eq({ argv[9], argv[#argv] }, { 'opus', 'max' })
end

T['\\Vf']['stops the request at explain.fix_timeout_ms'] = function()
  start({ timeout_ms = 180000, deep_timeout_ms = 180000, fix_timeout_ms = 300 })
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "5000"')

  press('\\Vf')
  vim.wait(explained.PATIENCE_MS, function()
    return #explained.told(child) > 0
  end, 20)

  eq(explained.told(child), {
    {
      message = 'aineo: proposing a fix failed: Claude Code did not answer within 0.3 s',
      level = vim.log.levels.ERROR,
    },
  })
end

T['\\VVf'] = MiniTest.new_set()

T['\\VVf']['opens the float with the fix’s default text, and asks nothing yet'] = function()
  start()

  press('\\VVf')

  eq(
    child.lua_get('vim.api.nvim_get_current_line()'),
    'Propose a fix for the issue at line 2 of the file src/code.lua (language: lua), as numbered below.'
  )
  eq(#recorded(2), 2)
end

T['the preview keys'] = MiniTest.new_set()

T['the preview keys']['\\Va accepts every edit, and one u takes them back'] = function()
  start()
  press('\\Vf')
  wait_for_answer()

  press('\\Va')
  local accepted = child.api.nvim_buf_get_lines(0, 0, -1, false)
  press('u')

  eq(accepted, {
    'local function add(a, b)',
    '  return a + b',
    'end',
    '',
    'return { add = add }',
  })
  eq(child.api.nvim_buf_get_lines(0, 0, -1, false), CODE)
end

T['the preview keys']['\\Vr rejects, and \\Vd shows the diff'] = function()
  start()
  press('\\Vf')
  wait_for_answer()

  press('\\Vd')
  local struck = marks_in('aineo_explain_fix_drawn')
  press('\\Vr')

  eq({ struck > 0, marks_in('aineo_explain_fix_drawn') }, { true, 0 })
  eq(child.api.nvim_buf_get_lines(0, 0, -1, false), CODE)
end

T['the preview keys']['of a fix are \\Va, \\Vr and \\Vd, never those of written code'] = function()
  start()

  press('\\Vf')
  wait_for_answer()

  eq(
    child.lua_get([[vim.tbl_map(function(key)
      return vim.fn.maparg(key, 'n') ~= ''
    end, { '\\Va', '\\Vr', '\\Vd', '\\Wa', '\\Wr', '\\Wd' })]]),
    { true, true, true, false, false, false }
  )
end

T['the preview keys']['with no prefix are none, and the head row names the <Plug> mappings'] = function()
  start_without_prefix()

  child.cmd('execute "normal \\<Plug>(aineo-explain-fix)"')
  wait_for_answer()

  local rows = screen_rows()
  local head = vim.fn.index(
    rows,
    '┊ read-only until <Plug>(aineo-fix-accept) accepts or <Plug>(aineo-fix-reject)'
  ) + 1
  eq(rows[head + 1], '┊ rejects · <Plug>(aineo-fix-diff) shows the diff')
  eq(child.lua_get([[vim.fn.maparg('\\Va', 'n')]]), '')
end

T['the preview keys']['of a fix whose code changed name \\Vf, which asks again'] = function()
  local stale_head = '┊ the code under the fix changed · \\Vr rejects · \\Vf asks again'
  start()
  press('\\Vf')
  wait_for_answer()

  force_edit_until_shown(stale_head)

  eq(vim.tbl_contains(screen_rows(), stale_head), true)
end

T['the preview keys']['with no prefix, of a fix whose code changed name the <Plug> mapping that asks again'] = function()
  local stale_end = '┊ <Plug>(aineo-explain-fix) asks again'
  start_without_prefix()
  child.cmd('execute "normal \\<Plug>(aineo-explain-fix)"')
  wait_for_answer()

  force_edit_until_shown(stale_end)

  eq(vim.tbl_contains(screen_rows(), stale_end), true)
end

T['the mappings'] = MiniTest.new_set()

T['the mappings']['of the fix exist in Normal mode'] = function()
  start()

  eq(
    child.lua_get([[vim.tbl_map(function(name)
      return vim.fn.maparg(name, 'n') ~= ''
    end, {
      '<Plug>(aineo-explain-fix)',
      '<Plug>(aineo-explain-fix-steered)',
      '<Plug>(aineo-fix-accept)',
      '<Plug>(aineo-fix-reject)',
      '<Plug>(aineo-fix-diff)',
    })]]),
    { true, true, true, true, true }
  )
end

return T
