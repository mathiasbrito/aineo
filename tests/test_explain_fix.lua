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

--- Waits until the child was told `message`, or `PATIENCE_MS` is over.
---
---@param message string
local function wait_until_told(message)
  vim.wait(explained.PATIENCE_MS, function()
    return vim.tbl_contains(messages(), message)
  end, 20)
end

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

--- Starts the child as `start()` does, its current window showing line
--- numbers six columns wide, so that the gutter has room for a label.
local function start_with_gutter()
  start()
  child.wo.number = true
  child.wo.numberwidth = 6
end

T['the preview']['shows the keys, then explains each edit after the summary, then its new lines'] = function()
  start_with_gutter()
  child.cmd('2')

  propose({ summary = 'Subtract.', edits = { SUBTRACT } })

  local rows = screen()
  local first = row_of(rows, '    1 local function sub(a, b)')
  eq(vim.list_slice(rows, first, first + 5), {
    '    1 local function sub(a, b)',
    '▎ fix ┊ \\Va accepts · \\Vr rejects · \\Vd shows the diff',
    '▎ why ┊ Subtract.',
    '▎     ┊ Subtracts b from a.',
    '▎       return a - b',
    '    3 end',
  })
end

--- The highlight group of the first chunk of the preview's virtual lines
--- whose text is `text`, or `nil`.
---
---@param text string
---@return string|nil
local function group_of(text)
  return child.lua(
    [[
    local text = ...
    local namespace = vim.api.nvim_create_namespace('aineo_explain_fix_drawn')
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })) do
      for _, line in ipairs(mark[4].virt_lines or {}) do
        for _, chunk in ipairs(line) do
          if vim.trim(chunk[1]) == text then
            return chunk[2]
          end
        end
      end
    end
  ]],
    { text }
  )
end

T['the preview']['draws the fix explanation in its own groups, and the keys and new lines in the fix’s'] = function()
  start_with_gutter()
  child.cmd('2')

  propose({ summary = 'Subtract.', edits = { SUBTRACT } })

  eq({
    why_label = group_of('why'),
    why = group_of('┊ Subtract.'),
    fix_label = group_of('fix'),
    keys = group_of('┊ \\Va accepts · \\Vr rejects · \\Vd shows the diff'),
    new = group_of('return a - b'),
  }, {
    why_label = 'AineoFixWhyGutter',
    why = 'AineoFixWhy',
    fix_label = 'AineoFixGutter',
    keys = 'AineoFix',
    new = 'AineoFix',
  })
end

T['the preview']['colours the fix explanation with the hint accent, apart from the fix’s green'] = function()
  start()

  local colours = child.lua_get([[{
    why = vim.api.nvim_get_hl(0, { name = 'AineoFixWhy' }).fg,
    hint = vim.api.nvim_get_hl(0, { name = 'DiagnosticHint', link = false }).fg,
    fix = vim.api.nvim_get_hl(0, { name = 'AineoFix' }).fg,
    ok = vim.api.nvim_get_hl(0, { name = 'DiagnosticOk', link = false }).fg,
  }]])

  eq({ colours.why, colours.fix }, { colours.hint, colours.ok })
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

--- Rejects the fix the child's current buffer shows, as `\Vr` does.
local function reject()
  child.lua('require("aineo.explain").reject_fix(vim.api.nvim_get_current_buf())')
end

T['the preview']['hides the old lines in a window split from one showing it, until rejected'] = function()
  start()
  child.cmd('2')
  propose({ summary = 'Subtract.', edits = { SUBTRACT } })

  child.cmd('split')
  local in_split = conceal_options()
  reject()

  eq(in_split, { 2, 'n' })
  eq(conceal_options(), { 0, '' })
  child.cmd('wincmd p')
  eq(conceal_options(), { 0, '' })
end

T['the preview']['hides the old lines in a window that comes to show the buffer, which gets the buffer’s own options back'] = function()
  start()
  child.cmd('2')
  local buffer = child.api.nvim_get_current_buf()
  propose({ summary = 'Subtract.', edits = { SUBTRACT } })
  child.cmd('new')
  child.wo.conceallevel = 1
  child.wo.concealcursor = 'i'

  child.cmd('buffer ' .. buffer)
  local while_shown = conceal_options()
  child.api.nvim_set_current_buf(buffer)
  reject()

  eq(while_shown, { 2, 'n' })
  eq(conceal_options(), { 0, '' })
end

--- A fix of two edits, the first of which adds a line.
local TWO_EDITS = {
  summary = 'Subtract, and multiply.',
  edits = {
    {
      line = 2,
      last = 2,
      old = { '  return a + b' },
      new = { '  local difference = a - b', '  return difference' },
      why = 'Subtracts.',
    },
    {
      line = 6,
      last = 6,
      old = { '  return a + b' },
      new = { '  return a * b' },
      why = 'Multiplies.',
    },
  },
}

--- Accepts the fix the child's current buffer shows, as `\Va` does.
local function accept()
  child.lua('require("aineo.explain").accept_fix(vim.api.nvim_get_current_buf())')
end

T['accepting'] = MiniTest.new_set()

T['accepting']['applies every edit, writes nothing, and one undo takes them all back'] = function()
  start()
  child.cmd('2')
  propose(TWO_EDITS)

  accept()
  local accepted = buffer_lines()
  child.cmd('undo')

  eq(accepted, {
    'local function sub(a, b)',
    '  local difference = a - b',
    '  return difference',
    'end',
    '',
    'local function mul(a, b)',
    '  return a * b',
    'end',
  })
  eq(child.fn.readfile(child.api.nvim_buf_get_name(0)), CODE)
  eq(messages()[#messages()], 'aineo: fix applied (u undoes it)')
  eq(buffer_lines(), CODE)
end

--- How many issues the child's current buffer shows.
---
---@return integer
local function issues_shown()
  return child.lua_get([[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_issues'), 0, -1, {})]])
end

T['accepting']['no longer shows the issue it fixes, even when its edits leave the issue’s line'] = function()
  start()
  child.cmd('2')
  propose({
    summary = 'Rename.',
    edits = {
      {
        line = 1,
        last = 1,
        old = { 'local function sub(a, b)' },
        new = { 'local function subtract(a, b)' },
        why = 'Names it.',
      },
    },
  })
  local before = issues_shown()

  accept()

  eq({ before, issues_shown() }, { 1, 0 })
end

T['accepting']['changes nothing when the code under the fix changed meanwhile'] = function()
  start()
  child.cmd('2')
  propose(TWO_EDITS)

  child.lua([[
    vim.api.nvim_buf_set_lines(0, 5, 6, false, { '  return a + b + 0' })
    require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf())
  ]])
  wait_until_told('aineo: the fix was dropped: its lines were edited')

  eq(messages(), {
    'aineo: the code under the fix changed; ask again',
    'aineo: the fix was dropped: its lines were edited',
  })
  eq(buffer_lines(), {
    'local function sub(a, b)',
    '  return a + b',
    'end',
    '',
    'local function mul(a, b)',
    '  return a + b + 0',
    'end',
  })
end

--- Toggles the diff view of the fix the child's current buffer shows, as
--- `\Vd` does.
local function toggle_diff()
  child.lua('require("aineo.explain").toggle_fix_diff(vim.api.nvim_get_current_buf())')
end

--- The highlight groups the preview sets over lines of the child's current
--- buffer, each with the lines it spans, from 1.
---
---@return table[]
local function line_highlights()
  return child.lua_get([[(function()
    local namespace = vim.api.nvim_create_namespace('aineo_explain_fix_drawn')
    local found = {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })) do
      if mark[4].hl_group then
        table.insert(found, { group = mark[4].hl_group, first = mark[2] + 1, last = mark[4].end_row })
      end
    end
    return found
  end)()]])
end

T['the preview']['shows edits that touch one after the other, the old lines of both hidden'] = function()
  start_with_gutter()
  child.cmd('2')

  propose({
    summary = 'Subtract.',
    edits = {
      SUBTRACT,
      { line = 3, last = 3, old = { 'end' }, new = { 'end -- sub' }, why = 'Names the end.' },
    },
  })

  local rows = screen()
  local first = row_of(rows, '    1 local function sub(a, b)')
  eq(vim.list_slice(rows, first, first + 9), {
    '    1 local function sub(a, b)',
    '▎ fix ┊ \\Va accepts · \\Vr rejects · \\Vd shows the diff',
    '▎ why ┊ Subtract.',
    '▎     ┊ Subtracts b from a.',
    '▎       return a - b',
    '▎ why ┊ Subtract.',
    '▎     ┊ Names the end.',
    '▎     end -- sub',
    '    4',
    '    5 local function mul(a, b)',
  })
end

T['the preview']['hangs the rows of an edit of the first line above the line after it'] = function()
  start_with_gutter()
  child.cmd('2')

  propose({
    summary = 'Rename.',
    edits = {
      {
        line = 1,
        last = 1,
        old = { 'local function sub(a, b)' },
        new = { 'local function subtract(a, b)' },
        why = 'Names it.',
      },
    },
  })

  local rows = screen()
  eq(count_of(rows, '    1 local function sub(a, b)'), 0)
  eq(row_after(rows, '▎     local function subtract(a, b)'), '    2   return a + b')
end

T['the preview']['of an edit of every line shows it as the diff view does'] = function()
  start_with_gutter()
  child.cmd('2')
  local all_new = vim.tbl_map(string.upper, CODE)

  propose({
    summary = 'Shout.',
    edits = { { line = 1, last = 7, old = CODE, new = all_new, why = 'Louder.' } },
  })

  local rows = screen()
  eq(line_highlights(), { { group = 'AineoFixOld', first = 1, last = 7 } })
  eq(row_after(rows, '    7 end'), '▎     LOCAL FUNCTION SUB(A, B)')
end

T['the diff view'] = MiniTest.new_set()

T['the diff view']['shows the old lines struck through under the issue and above the new, and toggles back'] = function()
  start_with_gutter()
  child.cmd('2')
  propose({ summary = 'Subtract.', edits = { SUBTRACT } })

  toggle_diff()
  local rows = screen()
  local highlights = line_highlights()
  toggle_diff()

  local first = row_of(rows, '    1 local function sub(a, b)')
  eq(vim.list_slice(rows, first, first + 7), {
    '    1 local function sub(a, b)',
    '▎issu   ┊ Adds where it should subtract.',
    '▎ fix ┊ \\Va accepts · \\Vr rejects · \\Vd shows the diff',
    '▎ why ┊ Subtract.',
    '▎     ┊ Subtracts b from a.',
    '    2   return a + b',
    '▎       return a - b',
    '    3 end',
  })
  eq(highlights, { { group = 'AineoFixOld', first = 2, last = 2 } })
  eq(count_of(screen(), '    2   return a + b'), 0)
end

T['the diff view']['strikes the old lines through in the error accent'] = function()
  start()

  local looks = child.lua_get([[{
    old = vim.api.nvim_get_hl(0, { name = 'AineoFixOld' }),
    error = vim.api.nvim_get_hl(0, { name = 'DiagnosticError', link = false }).fg,
  }]])

  eq({ looks.old.strikethrough, looks.old.fg }, { true, looks.error })
end

T['the diff view']['keeps the fix explanation and its colours'] = function()
  start_with_gutter()
  child.cmd('2')
  propose({ summary = 'Subtract.', edits = { SUBTRACT } })

  toggle_diff()

  eq({ group_of('why'), group_of('┊ Subtract.') }, { 'AineoFixWhyGutter', 'AineoFixWhy' })
end

T['while shown'] = MiniTest.new_set()

T['while shown']['an edit of its old lines drops it, with a word'] = function()
  start()
  child.cmd('2')
  propose({ summary = 'Subtract.', edits = { SUBTRACT } })

  child.api.nvim_buf_set_text(0, 1, 2, 1, 2, { 'local x = 1; ' })
  wait_until_told('aineo: the fix was dropped: its lines were edited')

  eq(messages()[#messages()], 'aineo: the fix was dropped: its lines were edited')
  eq(conceal_options(), { 0, '' })
  eq(count_of(screen(), '  return a - b'), 0)
end

T['while shown']['an undo that changes its old lines drops it'] = function()
  start()
  child.cmd('2')
  child.cmd('2s/b/b/')
  propose({ summary = 'Subtract.', edits = { SUBTRACT } })

  child.cmd('undo')
  wait_until_told('aineo: the fix was dropped: its lines were edited')

  eq(messages()[#messages()], 'aineo: the fix was dropped: its lines were edited')
end

T['while shown']['reloading the file drops it'] = function()
  start()
  child.cmd('2')
  propose({ summary = 'Subtract.', edits = { SUBTRACT } })

  child.cmd('edit!')
  wait_until_told('aineo: the fix was dropped: its lines were edited')

  eq(messages()[#messages()], 'aineo: the fix was dropped: its lines were edited')
  eq(conceal_options(), { 0, '' })
end

T['while shown']['wiping the buffer out drops it without a word'] = function()
  start()
  child.cmd('2')
  propose({ summary = 'Subtract.', edits = { SUBTRACT } })
  local told_before = #messages()

  child.cmd('bwipeout!')
  vim.wait(explained.PATIENCE_MS, function()
    return child.wo.conceallevel == 0
  end, 20)

  eq(conceal_options(), { 0, '' })
  eq(#messages(), told_before)
end

T['while shown']['an edit above it moves it, and accepting applies it where its lines are now'] = function()
  start()
  child.cmd('2')
  propose({ summary = 'Subtract.', edits = { SUBTRACT } })

  child.api.nvim_buf_set_lines(0, 0, 0, false, { '-- head' })
  accept()

  eq(vim.list_slice(buffer_lines(), 1, 4), {
    '-- head',
    'local function sub(a, b)',
    '  return a - b',
    'end',
  })
end

T['while shown']['deleting the line before it keeps its new lines in view'] = function()
  start()
  child.cmd('2')
  propose({ summary = 'Subtract.', edits = { SUBTRACT } })

  child.api.nvim_buf_set_lines(0, 0, 1, false, {})

  vim.wait(explained.PATIENCE_MS, function()
    return count_of(screen(), '  return a - b') == 1
  end, 20)
  eq(row_after(screen(), '  return a - b'), 'end')
end

T['accepting']['tells the user when the buffer shows no fix'] = function()
  start()

  accept()

  eq(messages(), { 'aineo: no fix is shown in this buffer' })
end

return T
