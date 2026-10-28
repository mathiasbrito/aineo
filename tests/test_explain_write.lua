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

--- The code that fulfils the request of line 3.
local ADD = {
  'function M.add(a, b)',
  '  return a + b',
  'end',
}

--- The answer that replaces the request of line 3 with `ADD`.
local REPLACING_THE_REQUEST = {
  summary = 'Adds two values.',
  edits = {
    {
      line = 3,
      last = 3,
      old = { CODE[3] },
      new = ADD,
      why = 'Returns the sum of a and b.',
    },
  },
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

--- The record the fake `claude` writes (`explained.start()` makes its folder).
local RECORD = vim.fs.joinpath(
  vim.fn.fnamemodify('.', ':p'):gsub('/$', ''),
  '.tests',
  'fixtures',
  'explain-write-record',
  'fake.jsonl'
)

--- Starts the child with `CODE` open in a project of its own, aineo
--- configured to run the fake `claude`, which answers `answer`.
---
---@param answer table
local function start(answer)
  explained.start(child, 'explain-write', CODE, { claude = { cmd = explained.FAKE_CLAUDE } })
  explained.answer_with(child, answer)
end

--- Asks the explain home, in the child, to write code in the current buffer
--- with the fake `claude`, as the fields `fields` say over these defaults:
--- below the cursor's line, the model `haiku`, no tools, no effort, a long
--- timeout, the keys `\Wa`, `\Wr` and `\Wd`, and `\w` named as the key that
--- asks again.
---
---@param fields? table
local function ask_write(fields)
  child.lua(
    [[
    local fields, command = ...
    require('aineo.explain').propose_write(vim.tbl_deep_extend('force', {
      buffer = vim.api.nvim_get_current_buf(),
      window = vim.api.nvim_get_current_win(),
      line = vim.fn.line('.'),
      tools = false,
      command = command,
      model = 'haiku',
      timeout_ms = 180000,
      keys = { accept = '\\Wa', reject = '\\Wr', diff = '\\Wd' },
      ask_key = '\\w',
    }, fields))
  ]],
    { fields or vim.empty_dict(), explained.FAKE_CLAUDE }
  )
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

--- Whether the child is in a floating window.
---
---@return boolean
local function in_a_float()
  return child.lua_get('vim.api.nvim_win_get_config(0).relative') ~= ''
end

--- Lets the child's scheduled callbacks run: what the case expects not to
--- happen would have happened by then.
local function settle()
  vim.wait(300, function()
    return false
  end, 20)
end

T['writing for the selected lines'] = MiniTest.new_set()

T['writing for the selected lines']['asks at once, with no float, the selected lines being the request'] = function()
  start(REPLACING_THE_REQUEST)

  ask_write({ range = { 3, 3 } })

  eq(in_a_float(), false)
  local stdin = vim.split(recorded(2)[2].stdin, '\n')
  eq(vim.list_slice(stdin, 1, 2), {
    'Write code in the file src/code.lua (language: lua) for the request lines 3 to 3 hold,'
      .. ' as numbered below: those lines are the request, to be replaced by the code that fulfils it.',
    '',
  })
  eq(vim.list_slice(stdin, #stdin - 4), {
    '1 | local M = {}',
    '2 | ',
    '3 | -- a function that adds two values and returns the sum',
    '4 | ',
    '5 | return M',
  })
end

T['writing for the selected lines']['tells Claude Code to answer one edit of exactly those lines, in this file alone'] = function()
  start(REPLACING_THE_REQUEST)

  ask_write({ range = { 3, 4 } })

  eq(
    vim.split(recorded(2)[2].stdin, '\n')[3],
    'Answer in summary what the code does in one sentence, and one edit that replaces the request with it.'
      .. ' Write only into this file.'
      .. ' The edit gives in line and last the lines 3 and 4, and repeats in old exactly those lines'
      .. ' of the numbered text below, verbatim with their indentation and without their numbers;'
      .. ' new holds the lines of the code, in the language of the file and its style,'
      .. ' the first indented as line 3 is,'
      .. ' and why says what the code does.'
      .. ' When the request cannot be fulfilled in this file, answer no edits and say why in the summary.'
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

--- The lines of the child's current buffer.
---
---@return string[]
local function buffer_lines()
  return child.api.nvim_buf_get_lines(0, 0, -1, false)
end

T['writing for the selected lines']['replaces exactly those lines on accept, as one undo step'] = function()
  start(REPLACING_THE_REQUEST)
  ask_write({ range = { 3, 3 } })
  wait_for_preview()

  child.lua("require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf())")
  local accepted = buffer_lines()
  child.cmd('undo')

  eq(accepted, { CODE[1], CODE[2], ADD[1], ADD[2], ADD[3], CODE[4], CODE[5] })
  eq(buffer_lines(), CODE)
end

T['writing for the selected lines']['leaves them as they are on reject'] = function()
  start(REPLACING_THE_REQUEST)
  ask_write({ range = { 3, 3 } })
  wait_for_preview()

  child.lua("require('aineo.explain').reject_fix(vim.api.nvim_get_current_buf())")

  eq(buffer_lines(), CODE)
end

T['writing for the selected lines']['refuses lines of white space alone with one message, and asks nothing'] = function()
  start(REPLACING_THE_REQUEST)
  child.api.nvim_buf_set_lines(0, 1, 2, false, { '  \t ' })

  ask_write({ range = { 2, 2 } })

  eq(explained.told(child), {
    {
      message = 'aineo: the selected lines are blank: there is no request to write code for',
      level = vim.log.levels.WARN,
    },
  })
  settle()
  eq(#recorded(0), 0)
end

--- The messages the child was told, without their levels.
---
---@return string[]
local function messages()
  return vim.tbl_map(function(told)
    return told.message
  end, explained.told(child))
end

--- Waits until the child was told `message`, or `PATIENCE_MS` is over.
---
---@param message string
local function wait_until_told(message)
  vim.wait(explained.PATIENCE_MS, function()
    return vim.tbl_contains(messages(), message)
  end, 20)
end

--- How many extmarks of a preview the child's current buffer holds.
---
---@return integer
local function preview_marks()
  return child.lua_get([[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {})]])
end

T['writing for the selected lines']['shows nothing when the lines were edited before the answer, and says so'] = function()
  local changed = 'aineo: the buffer changed while the code was written; ask again'
  start(REPLACING_THE_REQUEST)
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "1000"')
  ask_write({ range = { 3, 3 } })

  child.api.nvim_buf_set_lines(0, 2, 3, false, { '-- a function that adds three values' })
  wait_until_told(changed)

  eq(messages(), { changed })
  eq(preview_marks(), 0)
end

--- The refusal of an answer that changes lines outside the selection.
local OUTSIDE_THE_SELECTION =
  'aineo: the written code was refused: it must replace the lines of the request alone'

T['writing for the selected lines']['refuses an answer that changes a line outside them, and shows nothing'] = function()
  start({
    summary = 'Adds two values.',
    edits = {
      {
        line = 3,
        last = 4,
        old = { CODE[3], CODE[4] },
        new = ADD,
        why = 'Returns the sum of a and b.',
      },
    },
  })

  ask_write({ range = { 3, 3 } })
  wait_until_told(OUTSIDE_THE_SELECTION)

  eq(messages(), { OUTSIDE_THE_SELECTION })
  eq(preview_marks(), 0)
end

T['writing for the selected lines']['refuses an answer whose edit starts before them, and shows nothing'] = function()
  start({
    summary = 'Adds two values.',
    edits = {
      { line = 2, last = 3, old = { CODE[2], CODE[3] }, new = ADD, why = 'Adds.' },
    },
  })

  ask_write({ range = { 3, 3 } })
  wait_until_told(OUTSIDE_THE_SELECTION)

  eq(messages(), { OUTSIDE_THE_SELECTION })
  eq(preview_marks(), 0)
end

T['writing for the selected lines']['refuses an answer the placement of a fix refuses, with its reason'] = function()
  local refused =
    'aineo: the written code was refused: the old lines of an edit stand nowhere in the file'
  start({
    summary = 'Adds two values.',
    edits = { { line = 3, last = 3, old = { '-- another request' }, new = ADD, why = 'Adds.' } },
  })

  ask_write({ range = { 3, 3 } })
  wait_until_told(refused)

  eq(messages(), { refused })
  eq(preview_marks(), 0)
end

T['the answer'] = MiniTest.new_set()

T['the answer']['of a run that failed is told once, and nothing is shown'] = function()
  local failed = 'aineo: writing code failed: Claude Code exited with code 2: Error: fake failure'
  start(REPLACING_THE_REQUEST)
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT = nil; vim.env.AINEO_FAKE_CLAUDE_PRINT_EXIT = "2"')

  ask_write({ range = { 3, 3 } })
  wait_until_told(failed)

  eq(explained.told(child), { { message = failed, level = vim.log.levels.ERROR } })
  eq(preview_marks(), 0)
end

T['the answer']['with no edits tells its summary, and nothing is shown'] = function()
  local told = 'aineo: no code written: The request asks for another file.'
  start({ summary = 'The request asks for another file.', edits = {} })

  ask_write({ range = { 3, 3 } })
  wait_until_told(told)

  eq(explained.told(child), { { message = told, level = vim.log.levels.INFO } })
  eq(preview_marks(), 0)
end

--- The float the child is in, if any: its lines, the 'filetype' of its
--- buffer and its title; `vim.NIL` when it is in none.
local FLOAT_STATE = [[(function()
  local window = vim.api.nvim_get_current_win()
  local config = vim.api.nvim_win_get_config(window)
  if config.relative == '' then
    return vim.NIL
  end
  local buffer = vim.api.nvim_win_get_buf(window)
  local title = ''
  for _, chunk in ipairs(config.title or {}) do
    title = title .. chunk[1]
  end
  return {
    lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false),
    filetype = vim.bo[buffer].filetype,
    title = title,
  }
end)()]]

--- The float the child is in (`FLOAT_STATE`); a table with no field when it
--- is in none.
---
---@return table
local function float()
  local state = child.lua_get(FLOAT_STATE)
  return state ~= vim.NIL and state or {}
end

T['writing below the cursor'] = MiniTest.new_set()

T['writing below the cursor']['first opens an empty float titled with what it does and its keys, and asks nothing yet'] = function()
  start(BELOW_LINE_1)
  child.cmd('1')

  ask_write()

  eq(float(), {
    lines = { '' },
    filetype = 'markdown',
    title = ' Write code: <CR> sends · q or <Esc> cancels ',
  })
  settle()
  eq(#recorded(0), 0)
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

--- Asks the child to write code below line `line` (`ask_write()`), types
--- `request` in the float and sends it.
---
---@param line integer
---@param request string[]
local function send_request(line, request)
  child.cmd(tostring(line))
  ask_write()
  child.api.nvim_buf_set_lines(0, 0, -1, false, request)
  press('<CR>')
end

T['writing below the cursor']['sends the request typed, to insert the code after the cursor’s line, with the rules of the answer'] = function()
  start(BELOW_LINE_1)

  send_request(1, { 'A function that adds', 'two values.' })

  local stdin = vim.split(recorded(2)[2].stdin, '\n')
  eq(float(), {})
  eq(vim.list_slice(stdin, 1, 7), {
    'Write code in the file src/code.lua (language: lua) for the request below,'
      .. ' to be inserted after line 1 as numbered below.',
    '',
    'A function that adds',
    'two values.',
    '',
    'Answer in summary what the code does in one sentence, and one edit that inserts it.'
      .. ' Write only into this file.'
      .. ' The edit gives in line and last the line 1, and repeats in old exactly that line'
      .. ' of the numbered text below, verbatim with its indentation and without its number;'
      .. ' new holds that line unchanged, then the lines of the code, in the language of the file'
      .. ' and its style, indented as the code around line 1 is,'
      .. ' and why says what the code does.'
      .. ' When the request cannot be fulfilled in this file, answer no edits and say why in the summary.',
    '',
  })
  eq(stdin[8], '1 | local M = {}')
end

T['writing below the cursor']['inserts the code below the cursor’s line on accept, as answered, as one undo step'] = function()
  start(BELOW_LINE_1)
  send_request(1, { 'A function that adds two values.' })
  wait_for_preview()

  child.lua("require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf())")
  local accepted = buffer_lines()
  child.cmd('undo')

  eq(accepted, { CODE[1], '', ADD[1], ADD[2], ADD[3], CODE[2], CODE[3], CODE[4], CODE[5] })
  eq(buffer_lines(), CODE)
end

T['writing below the cursor']['refuses an answer that changes the cursor’s line, and shows nothing'] = function()
  local refused = 'aineo: the written code was refused: it must keep the cursor’s line as it is'
  start({
    summary = 'Adds two values.',
    edits = {
      {
        line = 1,
        last = 1,
        old = { CODE[1] },
        new = vim.list_extend({ 'local M = { name = "add" }' }, ADD),
        why = 'Adds.',
      },
    },
  })

  send_request(1, { 'A function that adds two values.' })
  wait_until_told(refused)

  eq(messages(), { refused })
  eq(preview_marks(), 0)
end

T['writing below the cursor']['refuses an answer that writes the code above the cursor’s line'] = function()
  local refused = 'aineo: the written code was refused: it must keep the cursor’s line as it is'
  start({
    summary = 'Adds two values.',
    edits = {
      {
        line = 1,
        last = 1,
        old = { CODE[1] },
        new = vim.list_extend(vim.deepcopy(ADD), { CODE[1] }),
        why = 'Adds.',
      },
    },
  })

  send_request(1, { 'A function that adds two values.' })
  wait_until_told(refused)

  eq(messages(), { refused })
  eq(preview_marks(), 0)
end

T['writing below the cursor']['inserts the code below the cursor’s line on a line that is not the first'] = function()
  start({
    summary = 'Adds two values.',
    edits = {
      {
        line = 5,
        last = 5,
        old = { CODE[5] },
        new = vim.list_extend({ CODE[5] }, ADD),
        why = 'Adds.',
      },
    },
  })
  send_request(5, { 'A function that adds two values.' })
  wait_for_preview()

  child.lua("require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf())")

  eq(vim.split(recorded(2)[2].stdin, '\n')[1]:match('after line %d+'), 'after line 5')
  eq(buffer_lines(), vim.list_extend(vim.deepcopy(CODE), ADD))
end

T['writing below the cursor']['refuses an answer that edits another line too, and shows nothing'] = function()
  local refused =
    'aineo: the written code was refused: it must insert after the cursor’s line alone'
  local below_and_more = vim.deepcopy(BELOW_LINE_1)
  table.insert(below_and_more.edits, {
    line = 5,
    last = 5,
    old = { CODE[5] },
    new = { 'return { M = M }' },
    why = 'Exports.',
  })
  start(below_and_more)

  send_request(1, { 'A function that adds two values.' })
  wait_until_told(refused)

  eq(messages(), { refused })
  eq(preview_marks(), 0)
end

T['writing on a blank line'] = MiniTest.new_set()

--- The answer that writes `ADD` in place of line 2, which is blank.
local IN_PLACE_OF_LINE_2 = {
  summary = 'Adds two values.',
  edits = {
    { line = 2, last = 2, old = { CODE[2] }, new = ADD, why = 'Returns the sum of a and b.' },
  },
}

T['writing on a blank line']['sends the request typed, to write the code in place of that line'] = function()
  start(IN_PLACE_OF_LINE_2)

  send_request(2, { 'A function that adds two values.' })

  local stdin = vim.split(recorded(2)[2].stdin, '\n')
  eq(vim.list_slice(stdin, 1, 6), {
    'Write code in the file src/code.lua (language: lua) for the request below,'
      .. ' to replace line 2 as numbered below, which is blank.',
    '',
    'A function that adds two values.',
    '',
    'Answer in summary what the code does in one sentence, and one edit that replaces that line with it.'
      .. ' Write only into this file.'
      .. ' The edit gives in line and last the line 2, and repeats in old exactly that line'
      .. ' of the numbered text below, verbatim with its white space and without its number;'
      .. ' new holds the lines of the code alone, in the language of the file and its style,'
      .. ' indented as the code around line 2 is,'
      .. ' and why says what the code does.'
      .. ' When the request cannot be fulfilled in this file, answer no edits and say why in the summary.',
    '',
  })
end

--- The lines of the child's current buffer once the proposal it shows is
--- accepted, and then once that is undone.
---
---@return string[] accepted
---@return string[] undone
local function accept_then_undo()
  child.lua("require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf())")
  local accepted = buffer_lines()
  child.cmd('undo')
  return accepted, buffer_lines()
end

T['writing on a blank line']['replaces it with the code on accept, leaving no blank line, as one undo step'] = function()
  start(IN_PLACE_OF_LINE_2)
  send_request(2, { 'A function that adds two values.' })
  wait_for_preview()

  local accepted, undone = accept_then_undo()

  eq(accepted, { CODE[1], ADD[1], ADD[2], ADD[3], CODE[3], CODE[4], CODE[5] })
  eq(undone, CODE)
end

T['writing on a blank line']['counts a line of white space alone as blank'] = function()
  start(IN_PLACE_OF_LINE_2)
  child.api.nvim_buf_set_lines(0, 1, 2, false, { '  \t' })

  send_request(2, { 'A function that adds two values.' })

  eq(
    vim.split(recorded(2)[2].stdin, '\n')[1],
    'Write code in the file src/code.lua (language: lua) for the request below,'
      .. ' to replace line 2 as numbered below, which is blank.'
  )
end

T['writing on a blank line']['counts spaces and tabs alone as blank: a page break is written below'] = function()
  start(IN_PLACE_OF_LINE_2)
  child.api.nvim_buf_set_lines(0, 1, 2, false, { '\f' })

  send_request(2, { 'A function that adds two values.' })

  eq(
    vim.split(recorded(2)[2].stdin, '\n')[1],
    'Write code in the file src/code.lua (language: lua) for the request below,'
      .. ' to be inserted after line 2 as numbered below.'
  )
end

T['writing on a blank line']['refuses an edit whose old line is not that line exactly, saying so'] = function()
  local refused = 'aineo: the written code was refused:'
    .. ' the edit’s old line does not match the cursor’s line exactly'
  start(IN_PLACE_OF_LINE_2)
  child.api.nvim_buf_set_lines(0, 1, 2, false, { '    ' })

  send_request(2, { 'A function that adds two values.' })
  wait_until_told(refused)

  eq(messages(), { refused })
  eq(preview_marks(), 0)
end

T['writing on a blank line']['drops a copy of that line the code starts with, leaving no blank line'] = function()
  start({
    summary = 'Adds two values.',
    edits = {
      {
        line = 2,
        last = 2,
        old = { CODE[2] },
        new = vim.list_extend({ CODE[2] }, ADD),
        why = 'Adds.',
      },
    },
  })
  send_request(2, { 'A function that adds two values.' })
  wait_for_preview()

  local accepted, undone = accept_then_undo()

  eq(accepted, { CODE[1], ADD[1], ADD[2], ADD[3], CODE[3], CODE[4], CODE[5] })
  eq(undone, CODE)
end

T['writing on a blank line']['writes into line 1 of an empty file'] = function()
  start({
    summary = 'Adds two values.',
    edits = { { line = 1, last = 1, old = { '' }, new = ADD, why = 'Adds.' } },
  })
  child.api.nvim_buf_set_lines(0, 0, -1, false, {})
  send_request(1, { 'A function that adds two values.' })
  wait_for_preview()

  local accepted, undone = accept_then_undo()

  eq(accepted, ADD)
  eq(undone, { '' })
end

T['writing on a blank line']['refuses an answer that edits another line too, and shows nothing'] = function()
  local refused =
    'aineo: the written code was refused: it must replace the cursor’s blank line alone'
  local in_place_and_more = vim.deepcopy(IN_PLACE_OF_LINE_2)
  table.insert(in_place_and_more.edits, {
    line = 5,
    last = 5,
    old = { CODE[5] },
    new = { 'return { M = M }' },
    why = 'Exports.',
  })
  start(in_place_and_more)

  send_request(2, { 'A function that adds two values.' })
  wait_until_told(refused)

  eq(messages(), { refused })
  eq(preview_marks(), 0)
end

T['writing at the last line'] = MiniTest.new_set()

--- The answer that writes `ADD` below line `line` of `lines`, which it
--- keeps as it is.
---
---@param lines string[]
---@param line integer
---@return table
local function below_line(lines, line)
  return {
    summary = 'Adds two values.',
    edits = {
      {
        line = line,
        last = line,
        old = { lines[line] },
        new = vim.list_extend({ lines[line] }, ADD),
        why = 'Adds.',
      },
    },
  }
end

--- The answer that writes `ADD` in place of line `line` of `lines`.
---
---@param lines string[]
---@param line integer
---@return table
local function in_place_of(lines, line)
  return {
    summary = 'Adds two values.',
    edits = { { line = line, last = line, old = { lines[line] }, new = ADD, why = 'Adds.' } },
  }
end

--- `CODE` with a blank last line.
local ENDING_BLANK = vim.list_extend(vim.deepcopy(CODE), { '' })

T['writing at the last line']['touches no other line, as one undo step, typed'] = MiniTest.new_set({
  parametrize = {
    { 'below it', CODE, '', below_line(CODE, 5), vim.list_extend(vim.deepcopy(CODE), ADD) },
    {
      'below it, with no line end at the end of the file',
      CODE,
      'setlocal noendofline nofixendofline',
      below_line(CODE, 5),
      vim.list_extend(vim.deepcopy(CODE), ADD),
    },
    {
      'below the only line',
      { CODE[1] },
      '',
      below_line({ CODE[1] }, 1),
      vim.list_extend({ CODE[1] }, ADD),
    },
    {
      'in place of a blank last line',
      ENDING_BLANK,
      '',
      in_place_of(ENDING_BLANK, 6),
      vim.list_extend(vim.deepcopy(CODE), ADD),
    },
  },
})

T['writing at the last line']['touches no other line, as one undo step, typed'][1] = function(
  _,
  lines,
  options,
  answer,
  expected
)
  start(answer)
  child.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  child.cmd(options)
  send_request(#lines, { 'A function that adds two values.' })
  wait_for_preview()

  local accepted, undone = accept_then_undo()

  eq(accepted, expected)
  eq(undone, lines)
end

T['writing at the last line']['replaces the selected last line, and no other'] = function()
  start(in_place_of(CODE, 5))
  ask_write({ range = { 5, 5 } })
  wait_for_preview()

  local accepted, undone = accept_then_undo()

  eq(accepted, vim.list_extend({ CODE[1], CODE[2], CODE[3], CODE[4] }, ADD))
  eq(undone, CODE)
end

T['the preview'] = MiniTest.new_set()

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

--- The row after the first of `rows` that is `text`; `nil` when none is
--- `text`.
---
---@param rows string[]
---@param text string
---@return string|nil
local function row_after(rows, text)
  local number = vim.fn.index(rows, text)
  return number >= 0 and rows[number + 2] or nil
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

--- What the head row of a preview says while the buffer is read-only.
local KEYS_ROW = '┊ read-only until \\Wa accepts or \\Wr rejects · \\Wd shows the diff'

T['the preview']['starts with the request, in the look of written code, above its keys'] = function()
  start(REPLACING_THE_REQUEST)

  ask_write({ range = { 3, 3 } })
  wait_for_preview()

  eq(row_after(screen(), '┊ ' .. CODE[3]), KEYS_ROW)
  eq(group_of('┊ ' .. CODE[3]), 'AineoWrite')
end

T['the preview']['names a long request on one line of 60 characters, cut with an ellipsis'] = function()
  start(BELOW_LINE_1)

  send_request(1, {
    'A function that adds two values and returns their sum,',
    '  checking that both are numbers first.',
  })
  wait_for_preview()

  eq(
    row_after(screen(), '┊ A function that adds two values and returns their sum, chec…'),
    KEYS_ROW
  )
end

--- The answer that replaces the only line of a file, a request, with `ADD`.
local REPLACING_THE_ONLY_LINE = {
  summary = 'Adds two values.',
  edits = {
    { line = 1, last = 1, old = { CODE[3] }, new = ADD, why = 'Returns the sum of a and b.' },
  },
}

T['the preview']['shows its keys row for code replacing the only line of a file'] = function()
  start(REPLACING_THE_ONLY_LINE)
  child.api.nvim_buf_set_lines(0, 0, -1, false, { CODE[3] })

  ask_write({ range = { 1, 1 } })
  wait_for_preview()

  eq(vim.tbl_contains(screen(), KEYS_ROW), true)
end

T['the preview']['shows its keys row for code inserted below the only line of a file'] = function()
  start({
    summary = 'Adds two values.',
    edits = {
      { line = 1, last = 1, old = { CODE[1] }, new = { CODE[1], ADD[1] }, why = 'Adds.' },
    },
  })
  child.api.nvim_buf_set_lines(0, 0, -1, false, { CODE[1] })

  send_request(1, { 'A function that adds two values.' })
  wait_for_preview()

  eq(vim.tbl_contains(screen(), KEYS_ROW), true)
end

--- The answer that replaces line 1 with `ADD`.
local REPLACING_LINE_1 = {
  summary = 'Adds two values.',
  edits = {
    { line = 1, last = 1, old = { CODE[1] }, new = ADD, why = 'Returns the sum of a and b.' },
  },
}

T['the preview']['shows its keys row in the diff view of code that starts on line 1'] = function()
  start(REPLACING_LINE_1)
  ask_write({ range = { 1, 1 } })
  wait_for_preview()

  child.lua("require('aineo.explain').toggle_fix_diff(vim.api.nvim_get_current_buf())")

  eq(vim.tbl_contains(screen(), KEYS_ROW), true)
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

T['the preview']['draws its keys row once in the diff view of code on line 1, even scrolled up'] = function()
  start(REPLACING_LINE_1)
  ask_write({ range = { 1, 1 } })
  wait_for_preview()
  child.lua("require('aineo.explain').toggle_fix_diff(vim.api.nvim_get_current_buf())")

  child.cmd('normal! gg')
  child.type_keys('<C-y>', '<C-y>', '<C-y>')

  eq(count_of(screen(), KEYS_ROW), 1)
end

T['the preview']['shows its stale row on line 1 once its marks are cleared'] = function()
  start(REPLACING_LINE_1)
  ask_write({ range = { 1, 1 } })
  wait_for_preview()

  child.api.nvim_buf_clear_namespace(0, -1, 0, -1)

  eq(
    vim.tbl_contains(
      screen(),
      '┊ the lines under the written code changed · \\Wr rejects · \\w asks again'
    ),
    true
  )
end

T['the preview']['names the <Plug> mappings of written code when it maps no key'] = function()
  start(REPLACING_THE_REQUEST)

  child.lua(
    [[
    require('aineo.explain').propose_write({
      buffer = vim.api.nvim_get_current_buf(),
      window = vim.api.nvim_get_current_win(),
      line = 3,
      range = { 3, 3 },
      tools = false,
      command = ...,
      model = 'haiku',
      timeout_ms = 180000,
      ask_key = '<Plug>(aineo-write)',
    })
  ]],
    { explained.FAKE_CLAUDE }
  )
  wait_for_preview()

  eq(
    row_after(screen(), '┊ ' .. CODE[3]),
    '┊ read-only until <Plug>(aineo-write-accept) accepts or'
  )
end

T['the preview in view'] = MiniTest.new_set()

--- The answer that writes `ADD` below line 3, which it keeps as it is.
local BELOW_LINE_3 = below_line(CODE, 3)

--- Asks the child to write code below the cursor's line (`ask_write()`),
--- where the cursor stands, types `request` in the float and sends it.
---
---@param request string[]
local function ask_below_cursor(request)
  ask_write()
  child.api.nvim_buf_set_lines(0, 0, -1, false, request)
  press('<CR>')
end

--- The cursor of the child's current window: its line, from 1, and its
--- column, from 0.
---
---@return integer[]
local function cursor()
  return child.api.nvim_win_get_cursor(0)
end

T['the preview in view']['is brought into view when its line is the window’s top line, the cursor kept'] = function()
  start(BELOW_LINE_3)
  child.api.nvim_win_set_cursor(0, { 3, 5 })
  child.cmd('normal! zt')

  ask_below_cursor({ 'A function that adds two values.' })
  wait_for_preview()

  eq(vim.tbl_contains(screen(), KEYS_ROW), true)
  eq(cursor(), { 3, 5 })
end

T['the preview in view']['is brought into view on line 1 of a window scrolled down, the cursor kept'] = function()
  start(REPLACING_LINE_1)
  ask_write({ range = { 1, 1 } })
  wait_for_preview()
  child.lua("require('aineo.explain').reject_fix(vim.api.nvim_get_current_buf())")
  child.api.nvim_win_set_cursor(0, { 2, 0 })
  child.lua('vim.fn.winrestview({ topline = 2 })')

  ask_write({ range = { 1, 1 } })

  eq(vim.tbl_contains(screen(), KEYS_ROW), true)
  eq(cursor(), { 2, 0 })
end

--- The view of the child's current window: its top line and the filler
--- lines it shows above it.
---
---@return integer[]
local function view()
  local saved = child.lua_get('vim.fn.winsaveview()')
  return { saved.topline, saved.topfill }
end

T['the preview in view']['leaves a window that shows it as it is'] = function()
  start(BELOW_LINE_3)
  child.api.nvim_win_set_cursor(0, { 3, 0 })
  local before = view()

  ask_below_cursor({ 'A function that adds two values.' })
  wait_for_preview()

  eq(view(), before)
end

--- A file of 60 lines, for the cases whose windows show parts of it.
local LONG = { 'local M = {}' }
for number = 2, 59 do
  LONG[number] = ('local v%d = %d'):format(number, number)
end
LONG[60] = 'return M'

--- The view of every window of the child's tab page, in the order of the
--- windows: its top line and the filler lines it shows above it.
---
---@return integer[][]
local function views()
  return child.lua([[return vim.tbl_map(function(window)
    local saved = vim.api.nvim_win_call(window, vim.fn.winsaveview)
    return { saved.topline, saved.topfill }
  end, vim.api.nvim_tabpage_list_wins(0))]])
end

T['the preview in view']['leaves a window whose cursor is far from it as it was'] = function()
  start(below_line(LONG, 5))
  child.api.nvim_buf_set_lines(0, 0, -1, false, LONG)
  child.cmd('split')
  child.api.nvim_win_set_cursor(0, { 50, 2 })
  child.lua('vim.fn.winrestview({ topline = 45 })')
  child.cmd('wincmd j')
  child.api.nvim_win_set_cursor(0, { 5, 0 })
  child.cmd('normal! zt')

  ask_below_cursor({ 'A function that adds two values.' })
  wait_for_preview()

  eq(views()[1], { 45, 0 })
end

T['the preview in view']['leaves the view of a user who scrolled away while it was asked'] = function()
  start(below_line(LONG, 5))
  child.api.nvim_buf_set_lines(0, 0, -1, false, LONG)
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "1500"')
  child.api.nvim_win_set_cursor(0, { 5, 0 })
  ask_below_cursor({ 'A function that adds two values.' })
  child.api.nvim_win_set_cursor(0, { 50, 2 })
  child.lua('vim.fn.winrestview({ topline = 40 })')

  wait_for_preview()

  eq({ views()[1], cursor() }, { { 40, 0 }, { 50, 2 } })
end

T['the preview in view']['is brought into view again by the diff view, not before'] = function()
  start(BELOW_LINE_3)
  child.api.nvim_win_set_cursor(0, { 3, 0 })
  ask_below_cursor({ 'A function that adds two values.' })
  wait_for_preview()
  child.cmd('normal! zt')
  local scrolled_away = vim.tbl_contains(screen(), KEYS_ROW)

  child.lua("require('aineo.explain').toggle_fix_diff(vim.api.nvim_get_current_buf())")

  eq({ scrolled_away, vim.tbl_contains(screen(), KEYS_ROW) }, { false, true })
end

T['the preview']['says on accept that the code is written, and that u undoes it'] = function()
  start(REPLACING_THE_REQUEST)
  ask_write({ range = { 3, 3 } })
  wait_for_preview()

  child.lua("require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf())")

  eq(explained.told(child), {
    { message = 'aineo: code written (u undoes it)', level = vim.log.levels.INFO },
  })
end

T['the code kept'] = MiniTest.new_set()

--- What the child is told when the code kept for a request is shown again.
local KEPT = 'aineo: the code written before for this request, the file unchanged'
  .. ' (change the request to ask anew)'

--- Asks the child for code for the request of line 3, waits for its
--- preview and rejects it, as `fields` say over `ask_write()`'s defaults.
---
---@param fields? table
local function ask_and_reject(fields)
  ask_write(vim.tbl_extend('force', { range = { 3, 3 } }, fields or {}))
  wait_for_preview()
  child.lua("require('aineo.explain').reject_fix(vim.api.nvim_get_current_buf())")
end

T['the code kept']['is shown again for the same request on unchanged text, starting no request'] = function()
  start(REPLACING_THE_REQUEST)
  ask_and_reject()

  ask_write({ range = { 3, 3 } })

  eq(preview_marks() > 0, true)
  eq(messages(), { KEPT })
  settle()
  eq(#recorded(0), 2)
end

--- Sends `request`, typed in the float, for code below line 1, waits for
--- its preview and rejects it.
---
---@param request string
local function send_and_reject(request)
  send_request(1, { request })
  wait_for_preview()
  child.lua("require('aineo.explain').reject_fix(vim.api.nvim_get_current_buf())")
end

T['the code kept']['is not reused for another request typed below the same line: that is a new request'] = function()
  start(BELOW_LINE_1)
  send_and_reject('A function that adds two values.')

  send_request(1, { 'A function that subtracts two values.' })

  eq(#recorded(4), 4)
  eq(vim.tbl_contains(messages(), KEPT), false)
end

T['the code kept']['is not reused for another model or effort: that is a new request'] =
  MiniTest.new_set({ parametrize = { { { model = 'sonnet' } }, { { effort = 'high' } } } })

T['the code kept']['is not reused for another model or effort: that is a new request']['for'] = function(
  other
)
  start(REPLACING_THE_REQUEST)
  ask_and_reject()

  ask_write(vim.tbl_extend('force', { range = { 3, 3 } }, other))

  eq(#recorded(4), 4)
  eq(vim.tbl_contains(messages(), KEPT), false)
end

T['the code kept']['is not reused once the file changed'] = function()
  start(REPLACING_THE_REQUEST)
  ask_and_reject()
  child.api.nvim_buf_set_lines(0, 4, 5, false, { 'return { M = M }' })

  ask_write({ range = { 3, 3 } })

  eq(#recorded(4), 4)
  eq(vim.tbl_contains(messages(), KEPT), false)
end

T['the code kept']['is not reused for the same request typed below another line'] = function()
  start(BELOW_LINE_1)
  send_and_reject('A function that adds two values.')

  send_request(5, { 'A function that adds two values.' })

  eq(#recorded(4), 4)
  eq(vim.tbl_contains(messages(), KEPT), false)
end

T['the code kept']['for the selected lines is not reused for the same text typed below them'] = function()
  start(REPLACING_THE_REQUEST)
  ask_and_reject()

  send_request(3, { CODE[3] })

  eq(#recorded(4), 4)
  eq(vim.tbl_contains(messages(), KEPT), false)
end

T['one proposal for each buffer'] = MiniTest.new_set()

--- The fix the fake `claude` answers for the issue on line 5.
local EXPORT = {
  summary = 'Export.',
  edits = {
    { line = 5, last = 5, old = { CODE[5] }, new = { 'return { M = M }' }, why = 'Exports.' },
  },
}

--- Asks the explain home, in the child, for a fix of the issue on line 5
--- with the fake `claude`.
local function ask_fix()
  child.lua(
    [[
    require('aineo.explain').propose_fix({
      buffer = vim.api.nvim_get_current_buf(),
      window = vim.api.nvim_get_current_win(),
      line = 5,
      command = ...,
      model = 'sonnet',
      effort = 'high',
      timeout_ms = 180000,
      ask_keys = { plain = '\\Vf', steered = '\\VVf' },
    })
  ]],
    { explained.FAKE_CLAUDE }
  )
end

--- Starts the child as `start()` does, with an issue shown above line 5.
local function start_with_an_issue()
  start(REPLACING_THE_REQUEST)
  explained.place(child, 'issues', { { line = 5, text = 'Exports nothing.' } })
end

--- Waits until the screen of the child shows a row that is `row`, or
--- `PATIENCE_MS` is over.
---
---@param row string
local function wait_for_row(row)
  vim.wait(explained.PATIENCE_MS, function()
    return vim.tbl_contains(screen(), row)
  end, 20)
end

T['one proposal for each buffer']['is the written code once asked while a fix shows, and rejecting it gives the buffer back'] = function()
  start_with_an_issue()
  explained.answer_with(child, EXPORT)
  ask_fix()
  wait_for_row('return { M = M }')
  explained.answer_with(child, REPLACING_THE_REQUEST)

  ask_write({ range = { 3, 3 } })
  wait_for_row('┊ ' .. CODE[3])
  local rows = screen()
  child.lua("require('aineo.explain').reject_fix(vim.api.nvim_get_current_buf())")

  eq(vim.tbl_contains(rows, 'return { M = M }'), false)
  eq({ child.bo.modifiable, preview_marks() }, { true, 0 })
end

T['one proposal for each buffer']['is the fix once asked while written code shows, and rejecting it gives the buffer back'] = function()
  start_with_an_issue()
  explained.answer_with(child, REPLACING_THE_REQUEST)
  ask_write({ range = { 3, 3 } })
  wait_for_row('┊ ' .. CODE[3])
  explained.answer_with(child, EXPORT)

  ask_fix()
  wait_for_row('return { M = M }')
  local rows = screen()
  child.lua("require('aineo.explain').reject_fix(vim.api.nvim_get_current_buf())")

  eq(vim.tbl_contains(rows, ADD[1]), false)
  eq({ child.bo.modifiable, preview_marks() }, { true, 0 })
end

--- How many virtual lines say that a request for code is working.
---
---@return integer
local function writing_marks()
  return child.lua_get([[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_write'), 0, -1, {})]])
end

T['one proposal for each buffer']['is the fix once asked while code is written: that request is stopped'] = function()
  start_with_an_issue()
  explained.answer_with(child, REPLACING_THE_REQUEST)
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "1500"')
  ask_write({ range = { 3, 3 } })
  local while_writing = writing_marks()
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = nil')
  explained.answer_with(child, EXPORT)

  ask_fix()
  wait_for_row('return { M = M }')
  settle()
  vim.wait(1500, function()
    return false
  end, 50)

  eq({ while_writing, writing_marks() }, { 1, 0 })
  eq(vim.tbl_contains(screen(), '┊ ' .. CODE[3]), false)
end

T['one proposal for each buffer']['is the written code once asked while a fix is asked: that request is stopped'] = function()
  start_with_an_issue()
  explained.answer_with(child, EXPORT)
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "1500"')
  ask_fix()
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = nil')
  explained.answer_with(child, REPLACING_THE_REQUEST)

  ask_write({ range = { 3, 3 } })
  wait_for_row('┊ ' .. CODE[3])
  vim.wait(1500, function()
    return false
  end, 50)

  eq(vim.tbl_contains(screen(), 'return { M = M }'), false)
  eq(vim.tbl_contains(screen(), '┊ ' .. CODE[3]), true)
end

T['the answer']['that outlasts its time limit is stopped, with a word'] = function()
  local late = 'aineo: writing code failed: Claude Code did not answer within 0.2 s'
  start(REPLACING_THE_REQUEST)
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "3000"')

  ask_write({ range = { 3, 3 }, timeout_ms = 200 })
  wait_until_told(late)

  eq(explained.told(child), { { message = late, level = vim.log.levels.ERROR } })
  eq(writing_marks(), 0)
end

T['cleaning the buffer'] = MiniTest.new_set()

--- Cleans the child's current buffer as `\vc` does.
local function clean()
  child.lua("require('aineo.explain').clear(vim.api.nvim_get_current_buf())")
end

T['cleaning the buffer']['removes the written code it shows and forgets it: asking again asks anew'] = function()
  start(REPLACING_THE_REQUEST)
  ask_write({ range = { 3, 3 } })
  wait_for_preview()

  clean()
  local after_cleaning = { child.bo.modifiable, preview_marks() }
  ask_write({ range = { 3, 3 } })

  eq(after_cleaning, { true, 0 })
  eq(#recorded(4), 4)
end

T['cleaning the buffer']['stops the request for code that runs: its answer is never shown'] = function()
  start(REPLACING_THE_REQUEST)
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "1000"')
  ask_write({ range = { 3, 3 } })

  clean()
  vim.wait(2000, function()
    return false
  end, 50)

  eq({ writing_marks(), preview_marks() }, { 0, 0 })
end

T['cleaning the buffer']['closes the float in which a request is typed'] = function()
  start(BELOW_LINE_1)
  ask_write()

  child.lua("require('aineo.explain').clear(vim.fn.bufnr('src/code.lua'))")

  eq(float(), {})
end

T['the request float'] = MiniTest.new_set()

T['the request float']['cancels with nothing sent on q and on <Esc> in Normal mode'] =
  MiniTest.new_set({ parametrize = { { 'q' }, { '<Esc>' } } })

T['the request float']['cancels with nothing sent on q and on <Esc> in Normal mode']['by'] = function(
  key
)
  start(BELOW_LINE_1)
  ask_write()
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'A function that adds two values.' })

  press(key)

  eq(float(), {})
  settle()
  eq(#recorded(0), 0)
end

T['the request float']['refuses a request of white space alone with one message, and stays open'] = function()
  start(BELOW_LINE_1)
  ask_write()
  child.api.nvim_buf_set_lines(0, 0, -1, false, { '   ', '' })

  press('<CR>')

  eq(messages(), { 'aineo: the prompt is empty: nothing is sent' })
  eq(float().lines, { '   ', '' })
end

T['the request float']['starts empty for each request, whatever was typed before'] = function()
  start(BELOW_LINE_1)
  send_request(1, { 'A function that adds two values.' })
  wait_for_preview()
  child.lua("require('aineo.explain').reject_fix(vim.api.nvim_get_current_buf())")

  ask_write()

  eq(float().lines, { '' })
end

T['the request float']['leaves R to Neovim: there is no default request to restore'] = function()
  start(BELOW_LINE_1)

  ask_write()

  eq(child.lua_get([[vim.fn.maparg('R', 'n')]]), '')
end

T['the request float']['sends nothing, with a word, when the line asked about is gone'] = function()
  local gone = 'aineo: the line asked about is gone'
  start(BELOW_LINE_1)
  child.cmd('3')
  ask_write()
  child.lua([[vim.api.nvim_buf_set_lines(vim.fn.bufnr('src/code.lua'), 2, 3, false, {})]])
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'A function that adds two values.' })

  press('<CR>')

  eq(messages(), { gone })
  settle()
  eq(#recorded(0), 0)
end

T['the request float']['asks below the line asked about where it stands when the request is sent'] = function()
  start(BELOW_LINE_1)
  child.cmd('3')
  ask_write()
  child.lua(
    [[vim.api.nvim_buf_set_lines(vim.fn.bufnr('src/code.lua'), 0, 0, false, { '-- header' })]]
  )
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'A function that adds two values.' })

  press('<CR>')

  eq(vim.split(recorded(2)[2].stdin, '\n')[1]:match('after line %d+'), 'after line 4')
end

T['the request float']['tells once, with no traceback, that claude.cmd cannot be run'] = function()
  start(BELOW_LINE_1)
  ask_write({ command = { '/nonexistent/aineo-claude' } })
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'A function that adds two values.' })

  child.lua([[_G.sent = pcall(vim.cmd, 'execute "normal \\<CR>"')]])

  local told = explained.told(child)
  eq(#told, 1)
  eq(vim.startswith(told[1].message, 'aineo: claude.cmd cannot be run: '), true)
  eq(
    { told[1].level, child.lua_get('vim.v.errmsg'), child.lua_get('_G.sent') },
    { vim.log.levels.ERROR, '', true }
  )
end

--- Sets, in the child's current buffer, the mark `a` and an extmark at
--- column 5 of line `line`, from 1.
---
---@param line integer
local function mark_line(line)
  child.lua(
    [[
    local line = ...
    vim.api.nvim_buf_set_mark(0, 'a', line, 5, {})
    _G.kept_mark = vim.api.nvim_buf_set_extmark(
      0, vim.api.nvim_create_namespace('test_kept'), line - 1, 5, {})
  ]],
    { line }
  )
end

--- Where the mark `a` and the extmark `mark_line()` set stand now: the
--- mark's line and column, and the extmark's row, from 0, and column.
---
---@return integer[]
local function marks_now()
  return child.lua_get([[(function()
    local mark = vim.api.nvim_buf_get_mark(0, 'a')
    local extmark = vim.api.nvim_buf_get_extmark_by_id(
      0, vim.api.nvim_create_namespace('test_kept'), _G.kept_mark, {})
    return { mark[1], mark[2], extmark[1], extmark[2] }
  end)()]])
end

T['writing below the cursor']['leaves the cursor’s line itself untouched on accept: its marks stay where they were'] = function()
  start(BELOW_LINE_1)
  send_request(1, { 'A function that adds two values.' })
  wait_for_preview()
  mark_line(1)

  child.lua("require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf())")

  eq(marks_now(), { 1, 5, 0, 5 })
end

T['the words'] = MiniTest.new_set()

--- Asks for code for the request of line 3 and waits for its preview,
--- then edits line 3 under it, its 'modifiable' turned back on first, as a
--- user forcing an edit does, which makes it stale.
local function show_then_change()
  start(REPLACING_THE_REQUEST)
  ask_write({ range = { 3, 3 } })
  wait_for_preview()
  child.bo.modifiable = true
  child.api.nvim_buf_set_text(0, 2, 0, 2, 0, { 'x' })
  settle()
end

T['the words']['of an accept refused name the written code'] = function()
  show_then_change()

  child.lua("require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf())")

  eq(messages(), { 'aineo: the lines under the written code changed; ask again' })
end

T['the words']['of the diff of stale code name the written code'] = function()
  show_then_change()

  child.lua("require('aineo.explain').toggle_fix_diff(vim.api.nvim_get_current_buf())")

  eq(messages(), { 'aineo: the written code is stale: \\Wr rejects, \\w asks again' })
end

T['the words']['of the head row label it write'] = function()
  start(REPLACING_THE_REQUEST)
  child.wo.number = true
  child.wo.numberwidth = 6

  ask_write({ range = { 3, 3 } })
  wait_for_preview()

  eq(
    row_after(screen(), '▎writ ┊ ' .. CODE[3]),
    '▎writ ┊ read-only until \\Wa accepts or \\Wr rejects · \\Wd shows the diff'
  )
end

T['the words']['of an accept with nothing shown name no fix'] = function()
  start(REPLACING_THE_REQUEST)

  child.lua("require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf())")

  eq(messages(), { 'aineo: no proposal is shown in this buffer' })
end

return T
