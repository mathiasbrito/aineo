local MiniTest = require('mini.test')
local explained = dofile('tests/helpers/explain_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The lines of the file every case fixes.
local CODE = {
  'local function sub(a, b)',
  '  return a + b',
  'end',
  '',
  'local function mul(a, b)',
  '  return a + b',
  'end',
}

--- The issue the fake `claude` finds on line 2.
local ISSUE = 'Adds where it should subtract.'

--- The record the fake `claude` writes (`explained.start()` makes its folder).
local RECORD = vim.fs.joinpath(
  vim.fn.fnamemodify('.', ':p'):gsub('/$', ''),
  '.tests',
  'fixtures',
  'explain-fix-record',
  'fake.jsonl'
)

--- Starts the child with `CODE` open in a project of its own, aineo
--- configured to run the fake `claude`, and the issue `ISSUE` shown above
--- line 2.
local function start()
  explained.start(child, 'explain-fix', CODE, { claude = { cmd = explained.FAKE_CLAUDE } })
  explained.place(child, 'issues', { { line = 2, text = ISSUE } })
end

--- Asks the explain home, in the child, for a fix of the issue on the
--- cursor's line of the current buffer with the fake `claude`, as the fields
--- `fields` say over these defaults: the model `sonnet`, effort `high`, a
--- long timeout and the keys `\Va`, `\Vr` and `\Vd`.
---
---@param fields? table
local function ask_fix(fields)
  child.lua(
    [[
    local fields, command = ...
    require('aineo.explain').propose_fix(vim.tbl_deep_extend('force', {
      buffer = vim.api.nvim_get_current_buf(),
      window = vim.api.nvim_get_current_win(),
      line = vim.fn.line('.'),
      command = command,
      model = 'sonnet',
      effort = 'high',
      timeout_ms = 180000,
      keys = { accept = '\\Va', reject = '\\Vr', diff = '\\Vd' },
    }, fields))
  ]],
    { fields or vim.empty_dict(), explained.FAKE_CLAUDE }
  )
end

--- The messages the child was told, without their levels.
---
---@return string[]
local function messages()
  return vim.tbl_map(function(told)
    return told.message
  end, explained.told(child))
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

--- What the prompt of the fix of `ISSUE` says after the text the user may
--- edit.
local FIXED_PART = 'The issue to fix is at line 2 of the file src/code.lua: ' .. ISSUE

T['asking a fix'] = MiniTest.new_set()

T['asking a fix']['runs Claude Code with the read-only tools alone, the model and the effort asked for'] = function()
  start()
  child.cmd('2')

  ask_fix({ model = 'opus', effort = 'xhigh' })

  local argv = recorded(3)[3].argv
  eq(vim.list_slice(argv, 1, 4), { '-p', '--output-format', 'json', '--json-schema' })
  eq(vim.json.decode(argv[5]).required, { 'summary', 'edits' })
  eq(vim.list_slice(argv, 6), {
    '--no-session-persistence',
    '--strict-mcp-config',
    '--model',
    'opus',
    '--setting-sources',
    'user',
    '--tools',
    'Read,Grep,Glob',
    '--allowedTools',
    'Read,Grep,Glob',
    '--effort',
    'xhigh',
  })
end

T['asking a fix']['hands Claude Code the default text, the issue and the rules, then every line numbered'] = function()
  start()
  child.cmd('2')

  ask_fix()

  local stdin = vim.split(recorded(4)[4].stdin, '\n')
  eq(vim.list_slice(stdin, 1, 4), {
    'Propose a fix for the issue at line 2 of the file src/code.lua (language: lua),'
      .. ' as numbered below.',
    'Make the smallest change that fixes it, reading the project with the tools where it helps.',
    '',
    FIXED_PART,
  })
  eq(vim.list_slice(stdin, #stdin - 6), {
    '1 | local function sub(a, b)',
    '2 |   return a + b',
    '3 | end',
    '4 | ',
    '5 | local function mul(a, b)',
    '6 |   return a + b',
    '7 | end',
  })
end

--- Starts the child as `start()` does but with the issues `A.` above line 2
--- and `B.` above line 3, whose line it then joins to line 2, after
--- marking `B.` when `marked` is set: line 2 then shows both.
---
---@param marked boolean
local function start_with_two_issues_on_line_2(marked)
  explained.start(child, 'explain-fix', CODE, { claude = { cmd = explained.FAKE_CLAUDE } })
  explained.place(child, 'issues', { { line = 2, text = 'A.' }, { line = 3, text = 'B.' } })
  child.lua('vim.g.mark_b = ...', { marked })
  child.lua([[
    if vim.g.mark_b then
      require('aineo.explain').toggle_issue_marks(vim.api.nvim_get_current_buf(), 3, 3)
    end
  ]])
  child.cmd('2')
  child.cmd('normal! J')
end

T['asking a fix']['of a line with several issues fixes the marked one'] = function()
  start_with_two_issues_on_line_2(true)

  ask_fix()

  eq(
    vim.split(recorded(4)[4].stdin, '\n')[4],
    'The issue to fix is at line 2 of the file src/code.lua: B.'
  )
end

T['asking a fix']['of a line with several issues none marked fixes the first'] = function()
  start_with_two_issues_on_line_2(false)

  ask_fix()

  eq(
    vim.split(recorded(4)[4].stdin, '\n')[4],
    'The issue to fix is at line 2 of the file src/code.lua: A.'
  )
end

T['asking a fix']['on a line with no issue tells so and asks nothing'] = function()
  start()
  child.cmd('4')

  ask_fix()

  eq(messages(), { 'aineo: no issue on this line' })
end

--- Waits until no fix request runs in the child: the virtual line that says
--- one is working is gone, or `PATIENCE_MS` is over.
local function wait_for_answer()
  vim.wait(explained.PATIENCE_MS, function()
    return child.lua_get([[#vim.api.nvim_buf_get_extmarks(0,
      vim.api.nvim_create_namespace('aineo_explain_fix'), 0, -1, {})]]) == 0
  end, 20)
end

--- Has the fake `claude` answer `fix`, asks a fix of the issue on the
--- cursor's line, as `ask_fix()` does with `fields`, and waits for the answer.
---
---@param fix table the structured output: a summary and edits
---@param fields? table
local function propose(fix, fields)
  explained.answer_with(child, fix)
  ask_fix(fields)
  wait_for_answer()
end

--- The edit of line 2 that fixes `ISSUE`.
local SUBTRACT = {
  line = 2,
  last = 2,
  old = { '  return a + b' },
  new = { '  return a - b' },
  why = 'Subtracts b from a.',
}

--- The rows of the child's screen once redrawn, white space at their ends
--- cut off.
---
---@return string[]
local function screen()
  child.cmd('redraw')
  return vim.tbl_map(function(row)
    return (table.concat(row):gsub('%s+$', ''))
  end, child.get_screenshot().text)
end

--- The number of the first of `rows` that is `text`, or `nil`.
---
---@param rows string[]
---@param text string
---@return integer|nil
local function row_of(rows, text)
  for number, row in ipairs(rows) do
    if row == text then
      return number
    end
  end
end

--- The row after the first of `rows` that is `text`; `nil` when none is
--- `text`.
---
---@param rows string[]
---@param text string
---@return string|nil
local function row_after(rows, text)
  local number = row_of(rows, text)
  return number and rows[number + 1]
end

--- How many of `rows` are `text`.
---
---@param rows string[]
---@param text string
---@return integer
local function count_of(rows, text)
  return #vim.tbl_filter(function(row)
    return row == text
  end, rows)
end

--- The lines of the child's current buffer.
---
---@return string[]
local function buffer_lines()
  return child.api.nvim_buf_get_lines(0, 0, -1, false)
end

T['the preview'] = MiniTest.new_set()

T['the preview']['hides the old lines and shows the new in their place, the buffer untouched'] = function()
  start()
  child.cmd('2')

  propose({ summary = 'Subtract.', edits = { SUBTRACT } })

  local rows = screen()
  eq(buffer_lines(), CODE)
  eq(child.bo.modified, false)
  eq(row_after(rows, '  return a - b'), 'end')
  eq(count_of(rows, '  return a - b'), 1)
  eq(count_of(rows, '  return a + b'), 1)
end

T['the answer'] = MiniTest.new_set()

T['the answer']['is not shown when the buffer changed while it was asked'] = function()
  start()
  child.cmd('2')
  explained.answer_with(child, { summary = 'Subtract.', edits = { SUBTRACT } })
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "400"')

  ask_fix()
  child.api.nvim_buf_set_lines(0, 6, 7, false, { 'end -- mul' })
  wait_for_answer()

  local rows = screen()
  eq(messages()[#messages()], 'aineo: the buffer changed while the fix was asked; ask again')
  eq(count_of(rows, '  return a - b'), 0)
  eq(count_of(rows, '  return a + b'), 2)
end

T['the answer']['of a run that failed is told once, and nothing is shown'] = function()
  start()
  child.cmd('2')
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT = nil; vim.env.AINEO_FAKE_CLAUDE_PRINT_EXIT = "2"')

  ask_fix()
  wait_for_answer()

  eq(explained.told(child)[#explained.told(child)], {
    message = 'aineo: proposing a fix failed: Claude Code exited with code 2: Error: fake failure',
    level = vim.log.levels.ERROR,
  })
  eq(count_of(screen(), '  return a + b'), 2)
end

T['the answer']['that holds no fix is told once, and nothing is shown'] = function()
  start()
  child.cmd('2')

  propose({ explanations = {} })

  eq(explained.told(child)[#explained.told(child)], {
    message = 'aineo: proposing a fix failed: its answer holds no fix',
    level = vim.log.levels.ERROR,
  })
  eq(count_of(screen(), '  return a + b'), 2)
end

T['the answer']['that cannot be placed is refused with the reason, and nothing is shown'] = function()
  start()
  child.cmd('2')

  propose({
    summary = 'Subtract.',
    edits = { vim.tbl_extend('force', SUBTRACT, { old = { 'return a + b' } }) },
  })

  eq(explained.told(child)[#explained.told(child)], {
    message = 'aineo: the fix was refused: the old lines of an edit stand nowhere in the file',
    level = vim.log.levels.WARN,
  })
  eq(count_of(screen(), '  return a + b'), 2)
end

T['the answer']['with no edits tells its summary, and nothing is shown'] = function()
  start()
  child.cmd('2')

  propose({ summary = 'The code already subtracts.', edits = {} })

  eq(explained.told(child)[#explained.told(child)], {
    message = 'aineo: no fix proposed: The code already subtracts.',
    level = vim.log.levels.INFO,
  })
  eq(count_of(screen(), '  return a + b'), 2)
end

--- The 'conceallevel' and 'concealcursor' of the child's current window.
---
---@return table
local function conceal_options()
  return { child.wo.conceallevel, child.wo.concealcursor }
end

T['the preview']['hides the old lines in every window, which get their own options back when rejected'] = function()
  start()
  child.cmd('2')
  child.wo.conceallevel = 1
  child.wo.concealcursor = 'v'

  propose({ summary = 'Subtract.', edits = { SUBTRACT } })
  local while_shown = conceal_options()
  child.lua('require("aineo.explain").reject_fix(vim.api.nvim_get_current_buf())')

  local rows = screen()
  eq(while_shown, { 2, 'vn' })
  eq(conceal_options(), { 1, 'v' })
  eq(buffer_lines(), CODE)
  eq(count_of(rows, '  return a + b'), 2)
  eq(count_of(rows, '  return a - b'), 0)
end

return T
