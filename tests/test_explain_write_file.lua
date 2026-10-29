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

--- The edit that writes `SORTING` below line 3, which it keeps as it is.
local BELOW_LINE_3 = {
  line = 3,
  last = 3,
  old = { CODE[3] },
  new = { CODE[3], SORTING },
  why = 'Sorts the values first.',
}

--- The edit that adds `IMPORT` above line 1.
local IMPORTING = {
  line = 1,
  last = 1,
  old = { CODE[1] },
  new = { IMPORT, CODE[1] },
  why = 'Imports sorted at the top, as the file does.',
}

--- The answer that writes `SORTING` below line 3 and imports what it needs.
local SORTING_WITH_AN_IMPORT = {
  summary = 'Sorts the values.',
  edits = { BELOW_LINE_3, IMPORTING },
}

--- The record the fake `claude` writes (`explained.start()` makes its folder).
local RECORD = vim.fs.joinpath(
  vim.fn.fnamemodify('.', ':p'):gsub('/$', ''),
  '.tests',
  'fixtures',
  'explain-write-file-record',
  'fake.jsonl'
)

--- Starts the child with `lines`, `CODE` when absent, open in a project of
--- its own, aineo configured to run the fake `claude`, which answers
--- `answer`, its screen wide enough for a keys row on one row.
---
---@param answer table
---@param lines? string[]
local function start(answer, lines)
  explained.start(
    child,
    'explain-write-file',
    lines or CODE,
    { claude = { cmd = explained.FAKE_CLAUDE } }
  )
  child.o.columns = 200
  explained.answer_with(child, answer)
end

--- Asks the explain home, in the child, to write code in the current buffer
--- with the fake `claude`, as the fields `fields` say over these defaults:
--- code that may edit the whole file, below the cursor's line, the model
--- `sonnet` at effort `high` with the tools, a long timeout, the keys of
--- written code, and `\WW` named as the key that asks again.
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
      tools = true,
      whole_file = true,
      command = command,
      model = 'sonnet',
      effort = 'high',
      timeout_ms = 180000,
      keys = {
        accept = '\\Wa',
        reject = '\\Wr',
        diff = '\\Wd',
        accept_all = '\\WA',
        reject_all = '\\WR',
        next = ']w',
        previous = '[w',
      },
      ask_key = '\\WW',
    }, fields))
  ]],
    { fields or vim.empty_dict(), explained.FAKE_CLAUDE }
  )
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

--- Asks the child to write code below line `line` (`ask_write()` with
--- `fields`), types `request` in the float and sends it.
---
---@param line integer
---@param request string
---@param fields? table
local function send_request(line, request, fields)
  child.cmd(tostring(line))
  ask_write(fields)
  child.api.nvim_buf_set_lines(0, 0, -1, false, { request })
  press('<CR>')
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

--- What the prompt for code that may edit the whole file says after the
--- rules of the edit at the cursor's line.
local WHOLE_FILE_RULES = 'The code may also need edits elsewhere in this file:'
  .. ' an import at the top, a variable or constant at module scope, a helper function,'
  .. ' a changed signature.'
  .. ' Give each as a further edit after that first one,'
  .. ' placed where the file’s own conventions put it:'
  .. ' never a local import inside a function or a branch when the file imports at the top.'
  .. ' Each further edit gives in line and last the first and last lines it replaces,'
  .. ' and repeats in old exactly those lines of the numbered text below,'
  .. ' verbatim with their indentation and without their numbers;'
  .. ' new holds the lines that replace them, and, to add lines, starts with the line they go after.'
  .. ' No two edits share a line, and there are at most 20 edits.'
  .. ' Edit no other file.'

T['the prompt'] = MiniTest.new_set()

T['the prompt']['allows edits elsewhere in the file, after the rules of the cursor’s line'] = function()
  start(SORTING_WITH_AN_IMPORT)

  send_request(3, 'Sort the values first.')

  local stdin = vim.split(recorded(2)[2].stdin, '\n')
  eq(vim.list_slice(stdin, 1, 4), {
    'Write code in the file src/code.lua (language: lua) for the request below,'
      .. ' to be inserted after line 3 as numbered below.',
    '',
    'Sort the values first.',
    '',
  })
  eq(vim.list_slice(stdin, 6, 9), { '', WHOLE_FILE_RULES, '', '1 | local M = {}' })
end

T['the prompt']['of code written at the cursor alone allows no edit elsewhere'] = function()
  start(SORTING_WITH_AN_IMPORT)

  send_request(3, 'Sort the values first.', { whole_file = false })

  local stdin = vim.split(recorded(2)[2].stdin, '\n')
  eq(vim.list_slice(stdin, 6, 7), { '', '1 | local M = {}' })
end

--- Waits until the child's current buffer shows a preview, or
--- `PATIENCE_MS` is over.
local function wait_for_preview()
  vim.wait(explained.PATIENCE_MS, function()
    return child.lua_get([[#vim.api.nvim_buf_get_extmarks(0,
      vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {})]]) > 0
  end, 20)
end

--- Asks for `SORTING_WITH_AN_IMPORT` below line 3 (`send_request()`) and
--- waits until it shows.
local function show_sorting()
  start(SORTING_WITH_AN_IMPORT)
  send_request(3, 'Sort the values first.')
  wait_for_preview()
end

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

--- The rows of the child's screen that are keys rows of written code, in
--- the order they show.
---
---@return string[]
local function keys_rows()
  return vim.tbl_filter(function(row)
    return vim.startswith(row, '┊ write ')
  end, screen())
end

--- What the keys row of the proposal `number` of `count` says while the
--- buffer is read-only.
---
---@param number integer
---@param count integer
---@return string
local function keys_row(number, count)
  return ('┊ write %d/%d · read-only until \\Wa accepts or \\Wr rejects · \\Wd shows the diff'):format(
    number,
    count
  ) .. ' · ]w [w move · \\WA accepts all · \\WR rejects all'
end

T['the proposals'] = MiniTest.new_set()

T['the answer'] = MiniTest.new_set()

T['the proposals']['are each edit, with a keys row of its own naming its place'] = function()
  show_sorting()

  eq(keys_rows(), { keys_row(1, 2), keys_row(2, 2) })
end

--- The messages the child was told, without their levels.
---
---@return string[]
local function messages()
  return vim.tbl_map(function(told)
    return told.message
  end, explained.told(child))
end

--- Waits until the child was told something, or `PATIENCE_MS` is over.
local function wait_until_told()
  vim.wait(explained.PATIENCE_MS, function()
    return #explained.told(child) > 0
  end, 20)
end

--- How many extmarks of a preview the child's current buffer holds.
---
---@return integer
local function preview_marks()
  return child.lua_get([[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {})]])
end

--- An edit of line `line` of `CODE` that replaces it with `new`.
---
---@param line integer
---@param new string[]
---@return table
local function replacing(line, new)
  return { line = line, last = line, old = { CODE[line] }, new = new, why = 'Changes it.' }
end

--- Twenty edits, each of one of the lines 2 to 21 of a file of 21 lines
--- (`lines_of_21()`), each replacing it with itself and a comment.
---
---@return table[]
local function twenty_edits()
  local edits = {}
  for line = 2, 21 do
    table.insert(edits, {
      line = line,
      last = line,
      old = { 'x = ' .. line },
      new = { 'x = ' .. line, '-- ' .. line },
      why = 'Comments it.',
    })
  end
  return edits
end

--- A file of 21 lines, each `x = ` and its number.
---
---@return string[]
local function lines_of_21()
  local lines = {}
  for line = 1, 21 do
    lines[line] = 'x = ' .. line
  end
  return lines
end

T['the answer refused'] = MiniTest.new_set({
  parametrize = {
    { { IMPORTING }, 'its first edit must insert after the cursor’s line' },
    { { IMPORTING, BELOW_LINE_3 }, 'its first edit must insert after the cursor’s line' },
    {
      { BELOW_LINE_3, replacing(4, { '  return #values' }), replacing(4, { '  return nil' }) },
      'two edits overlap',
    },
    {
      { BELOW_LINE_3, { line = 9, last = 9, old = { 'x' }, new = { 'y' }, why = 'Past the end.' } },
      'an edit names lines the file does not have',
    },
    {
      {
        BELOW_LINE_3,
        { line = 5, last = 5, old = { 'end -- nowhere' }, new = { 'end' }, why = 'Elsewhere.' },
      },
      'the old lines of an edit stand nowhere in the file',
    },
  },
})

T['the answer refused']['is told once, and nothing is shown'] = function(edits, reason)
  start({ summary = 'Sorts the values.', edits = edits })

  send_request(3, 'Sort the values first.')
  wait_until_told()

  eq(messages(), { 'aineo: the written code was refused: ' .. reason })
  eq(preview_marks(), 0)
end

T['the answer refused']['of more than 20 edits is told once, and nothing is shown'] = function()
  local below_line_1 = {
    line = 1,
    last = 1,
    old = { 'x = 1' },
    new = { 'x = 1', 'y = 1' },
    why = 'Adds y.',
  }
  start(
    { summary = 'Many.', edits = vim.list_extend({ below_line_1 }, twenty_edits()) },
    lines_of_21()
  )

  send_request(1, 'Add y.')
  wait_until_told()

  eq(messages(), { 'aineo: the written code was refused: it holds more than 20 edits' })
  eq(preview_marks(), 0)
end

T['the answer']['of 20 edits is shown'] = function()
  local below_line_1 = {
    line = 1,
    last = 1,
    old = { 'x = 1' },
    new = { 'x = 1', 'y = 1' },
    why = 'Adds y.',
  }
  local edits = vim.list_extend({ below_line_1 }, vim.list_slice(twenty_edits(), 1, 19))
  start({ summary = 'Many.', edits = edits }, lines_of_21())

  send_request(1, 'Add y.')
  wait_for_preview()

  eq(messages(), {})
  eq(preview_marks() > 0, true)
end

--- The lines of the child's current buffer.
---
---@return string[]
local function buffer_lines()
  return child.api.nvim_buf_get_lines(0, 0, -1, false)
end

--- Has the explain home accept, in the child's current buffer, the written
--- code chosen by the cursor's line `line`, or, with none, by what chose it
--- last.
---
---@param line? integer
local function accept(line)
  child.lua(
    "require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf(), 'write', ...)",
    { line }
  )
end

--- `CODE` with `SORTING` below line 3.
local SORTED = { CODE[1], CODE[2], CODE[3], SORTING, CODE[4], CODE[5], CODE[6], CODE[7] }

T['accepting one'] = MiniTest.new_set()

T['accepting one']['applies the proposal on the cursor’s line alone, the other staying on its text'] = function()
  show_sorting()

  accept(3)

  eq(buffer_lines(), SORTED)
  eq(keys_rows(), { keys_row(1, 1) })
end

T['accepting one']['then the other applies it too, where its text moved to'] = function()
  show_sorting()
  accept(3)

  accept(1)

  eq(buffer_lines(), vim.list_extend({ IMPORT }, SORTED))
  eq(preview_marks(), 0)
end

--- Has the explain home reject, in the child's current buffer, the written
--- code chosen by the cursor's line `line`, or, with none, by what chose it
--- last.
---
---@param line? integer
local function reject(line)
  child.lua(
    "require('aineo.explain').reject_fix(vim.api.nvim_get_current_buf(), 'write', ...)",
    { line }
  )
end

T['rejecting one'] = MiniTest.new_set()

T['rejecting one']['leaves the buffer as it is and the other proposal shown'] = function()
  show_sorting()

  reject(1)

  eq(buffer_lines(), CODE)
  eq(keys_rows(), { keys_row(1, 1) })
end

T['rejecting one']['that is the last ends the preview, giving the buffer back'] = function()
  show_sorting()
  reject(1)

  reject(3)

  eq(preview_marks(), 0)
  eq(child.bo.modifiable, true)
  eq(buffer_lines(), CODE)
end

--- Has the explain home move the cursor of the child's current window to
--- the first line of the written code `way` of it, and returns the line it
--- is on then.
---
---@param way 'next'|'previous'
---@return integer
local function jump(way)
  child.lua(
    "require('aineo.explain').jump_to_proposal(vim.api.nvim_get_current_win(), ...)",
    { way }
  )
  return child.fn.line('.')
end

T['moving'] = MiniTest.new_set()

T['moving']['goes to the first line of the next proposal, and of the first after the last'] = function()
  show_sorting()
  child.cmd('3')

  local lines = { jump('next'), jump('next') }

  eq(lines, { 1, 3 })
end

T['moving']['goes to the first line of the previous proposal, and of the last before the first'] = function()
  show_sorting()
  child.cmd('3')

  local lines = { jump('previous'), jump('previous') }

  eq(lines, { 1, 3 })
end

T['moving']['goes to the next proposal from a line between two'] = function()
  show_sorting()
  child.cmd('2')

  eq(jump('next'), 3)
end

T['choosing'] = MiniTest.new_set()

T['choosing']['takes the proposal last moved to when the cursor is on none'] = function()
  show_sorting()
  child.cmd('3')
  jump('next')

  accept(6)

  eq(buffer_lines(), vim.list_extend({ IMPORT }, CODE))
end

T['choosing']['takes the proposal on the cursor’s line before the one last moved to'] = function()
  show_sorting()
  child.cmd('3')
  jump('next')

  accept(3)

  eq(buffer_lines(), SORTED)
end

T['choosing']['tells how to choose, and changes nothing, when none is chosen'] = function()
  show_sorting()

  accept(6)

  eq(messages(), {
    'aineo: no written code is chosen: put the cursor on its lines, or move to it with ]w or [w',
  })
  eq(buffer_lines(), CODE)
  eq(#keys_rows(), 2)
end

T['deciding all'] = MiniTest.new_set()

T['deciding all']['accepts every proposal left as one undo step'] = function()
  show_sorting()

  child.lua("require('aineo.explain').accept_all(vim.api.nvim_get_current_buf(), 'write')")
  local accepted = buffer_lines()
  local marks = preview_marks()
  child.cmd('undo')

  eq(accepted, vim.list_extend({ IMPORT }, SORTED))
  eq(marks, 0)
  eq(buffer_lines(), CODE)
end

T['deciding all']['accepts those left after one was rejected'] = function()
  show_sorting()
  reject(1)

  child.lua("require('aineo.explain').accept_all(vim.api.nvim_get_current_buf(), 'write')")

  eq(buffer_lines(), SORTED)
end

T['deciding all']['rejects every proposal left, giving the buffer back as it was'] = function()
  show_sorting()

  child.lua("require('aineo.explain').reject_all(vim.api.nvim_get_current_buf(), 'write')")

  eq(buffer_lines(), CODE)
  eq(preview_marks(), 0)
  eq(child.bo.modifiable, true)
end

--- What the keys row of the stale proposal `number` of `count` says.
---
---@param number integer
---@param count integer
---@return string
local function stale_row(number, count)
  return ('┊ write %d/%d · the lines under the written code changed · \\Wr rejects · \\WW asks again'):format(
    number,
    count
  )
end

--- Changes line 1 of the child's current buffer, as another plugin may
--- while the buffer is read-only, and waits until the preview is drawn
--- again.
local function change_line_1()
  child.bo.modifiable = true
  child.api.nvim_buf_set_text(0, 0, 0, 0, 0, { '-- ' })
  child.bo.modifiable = false
  vim.wait(explained.PATIENCE_MS, function()
    return vim.iter(keys_rows()):any(function(row)
      return row:find('changed', 1, true) ~= nil
    end)
  end, 20)
end

T['a stale proposal'] = MiniTest.new_set()

T['a stale proposal']['is the one whose text changed after an earlier accept, alone'] = function()
  show_sorting()
  accept(3)

  change_line_1()

  eq(keys_rows(), { stale_row(1, 1) })
end

T['a stale proposal']['is never accepted, with a word'] = function()
  show_sorting()
  accept(3)
  change_line_1()

  accept(1)

  eq(messages()[#messages()], 'aineo: the lines under the written code changed; ask again')
  eq(buffer_lines()[1], '-- ' .. CODE[1])
  eq(keys_rows(), { stale_row(1, 1) })
end

T['a stale proposal']['is rejected, ending the preview, the text left as it reads'] = function()
  show_sorting()
  accept(3)
  change_line_1()

  reject(1)

  eq(preview_marks(), 0)
  eq(buffer_lines()[1], '-- ' .. CODE[1])
end

T['a stale proposal']['stays shown when all are accepted, the others applied'] = function()
  show_sorting()
  change_line_1()

  child.lua("require('aineo.explain').accept_all(vim.api.nvim_get_current_buf(), 'write')")

  eq(vim.list_slice(buffer_lines(), 3, 5), { CODE[3], SORTING, CODE[4] })
  eq(keys_rows(), { stale_row(1, 1) })
end

--- The answer that writes `SORTING` below line 3 and changes line 4, the
--- line after it, which touches it.
local TOUCHING = {
  summary = 'Sorts the values and counts them.',
  edits = { BELOW_LINE_3, replacing(4, { '  return #values' }) },
}

T['touching proposals'] = MiniTest.new_set({ parametrize = { { 3, 5 }, { 4, 3 } } })

T['touching proposals']['each stay on their text as the other is accepted first'] = function(
  first,
  second
)
  start(TOUCHING)
  send_request(3, 'Sort the values first.')
  wait_for_preview()

  accept(first)
  accept(second)

  eq(
    buffer_lines(),
    { CODE[1], CODE[2], CODE[3], SORTING, '  return #values', CODE[5], CODE[6], CODE[7] }
  )
end

--- The lines, from 0, of the child's current buffer that the preview shows
--- struck through, as the diff view does, and those it hides, as the
--- overlay does.
---
---@return { struck: integer[], hidden: integer[] }
local function drawn_lines()
  return child.lua([[
    local namespace = vim.api.nvim_create_namespace('aineo_explain_fix_drawn')
    local drawn = { struck = {}, hidden = {} }
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })) do
      if mark[4].hl_group == 'AineoFixOld' then
        table.insert(drawn.struck, mark[2])
      elseif mark[4].conceal_lines then
        table.insert(drawn.hidden, mark[2])
      end
    end
    return drawn
  ]])
end

T['the diff'] = MiniTest.new_set()

T['the diff']['shows the proposal on the cursor’s line alone as a diff, and back'] = function()
  show_sorting()

  child.lua("require('aineo.explain').toggle_fix_diff(vim.api.nvim_get_current_buf(), 'write', 1)")
  local diffed = drawn_lines()
  child.lua("require('aineo.explain').toggle_fix_diff(vim.api.nvim_get_current_buf(), 'write', 1)")

  eq(diffed, { struck = { 0 }, hidden = { 2 } })
  eq(drawn_lines(), { struck = {}, hidden = { 0, 2 } })
end

--- The answer that replaces the request line 4 holds with code that needs
--- an import.
local REPLACING_LINE_4 = {
  summary = 'Returns the values sorted.',
  edits = { replacing(4, { '  return sorted(values)' }), IMPORTING },
}

T['the selected lines'] = MiniTest.new_set()

T['the selected lines']['are the request, the prompt allowing edits elsewhere in the file'] = function()
  start(REPLACING_LINE_4)

  ask_write({ range = { 4, 4 } })

  local stdin = vim.split(recorded(2)[2].stdin, '\n')
  eq(
    stdin[1],
    'Write code in the file src/code.lua (language: lua) for the request lines 4 to 4 hold,'
      .. ' as numbered below: those lines are the request, to be replaced by the code that fulfils it.'
  )
  eq(vim.list_slice(stdin, 4, 7), { '', WHOLE_FILE_RULES, '', '1 | local M = {}' })
end

T['the selected lines']['are replaced by one proposal, the edits elsewhere by others'] = function()
  start(REPLACING_LINE_4)
  ask_write({ range = { 4, 4 } })
  wait_for_preview()

  accept(4)
  accept(1)

  eq(
    buffer_lines(),
    { IMPORT, CODE[1], CODE[2], CODE[3], '  return sorted(values)', CODE[5], CODE[6], CODE[7] }
  )
end

T['the code kept'] = MiniTest.new_set()

--- Asks for `SORTING_WITH_AN_IMPORT` below line 3, as `fields` say, waits
--- until it shows and rejects it all.
---
---@param fields? table
local function send_and_reject(fields)
  send_request(3, 'Sort the values first.', fields)
  wait_for_preview()
  child.lua("require('aineo.explain').reject_all(vim.api.nvim_get_current_buf(), 'write')")
end

T['the code kept']['is shown again, every proposal, for the same request on unchanged text'] = function()
  start(SORTING_WITH_AN_IMPORT)
  send_and_reject()

  send_request(3, 'Sort the values first.')

  eq(#recorded(2), 2)
  eq(keys_rows(), { keys_row(1, 2), keys_row(2, 2) })
end

T['the code kept']['is never reused for code written at the cursor alone'] = function()
  start(SORTING_WITH_AN_IMPORT)
  send_and_reject()

  send_request(3, 'Sort the values first.', { whole_file = false })

  eq(#recorded(4), 4)
end

T['cleaning the buffer'] = MiniTest.new_set()

T['cleaning the buffer']['removes every proposal, giving the buffer back'] = function()
  show_sorting()

  child.lua("require('aineo.explain').clear(vim.api.nvim_get_current_buf())")

  eq(preview_marks(), 0)
  eq(child.bo.modifiable, true)
  eq(buffer_lines(), CODE)
end

T['the preview in view'] = MiniTest.new_set()

T['the preview in view']['is the proposal at the cursor’s line, when it is the window’s top line'] = function()
  local lines = lines_of_21()
  vim.list_extend(lines, lines_of_21())
  vim.list_extend(lines, lines_of_21())
  local anchor = {
    line = 50,
    last = 50,
    old = { lines[50] },
    new = { lines[50], 'y = 1' },
    why = 'Adds y.',
  }
  local import =
    { line = 1, last = 1, old = { lines[1] }, new = { 'local y', lines[1] }, why = 'Declares y.' }
  start({ summary = 'Adds y.', edits = { anchor, import } }, lines)
  child.cmd('50')
  child.cmd('normal! zt')

  send_request(50, 'Add y.')
  wait_for_preview()

  local view = child.fn.winsaveview()
  eq({ view.topline, view.topfill > 0, child.fn.line('.') }, { 50, true, 50 })
end

return T
