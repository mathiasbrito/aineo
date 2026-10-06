local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local report_editor = dofile('tests/helpers/report_editor.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- Starts the child's report home with the clock at `times`, a fresh state
--- directory and the working directory `/projects/alpha`.
---
---@param times string[]
local function start_editor(times)
  report_editor.start(child, {
    times = times,
    state_directory = fixture.directory('report-state'),
    working_directory = '/projects/alpha',
  })
end

--- A second editor in the same working directory, for the tests of two
--- editors keeping records in one file.
local other_editor = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    post_once = function()
      child.stop()
      other_editor.stop()
    end,
  },
})

T['a report'] = MiniTest.new_set()

T['a report']['renders as its time, status, task and summary'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(
    child,
    { task = 'Refactor the parser', status = 'done', summary = 'All tests pass' }
  )

  eq(report_editor.lines(child), { '09:05 [done] Refactor the parser — All tests pass' })
end

T['a report']['renders its time first, whatever its status'] = MiniTest.new_set({
  parametrize = {
    { 'started', '09:05 [started] Task — Summary' },
    { 'progress', '09:05 [progress] Task — Summary' },
    { 'blocked', '09:05 [blocked] Task — Summary' },
    { 'done', '09:05 [done] Task — Summary' },
    { 'failed', '09:05 [failed] Task — Summary' },
  },
})

T['a report']['renders its time first, whatever its status']['for the status'] = function(
  status,
  header
)
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(child, { task = 'Task', status = status, summary = 'Summary' })

  eq(report_editor.lines(child), { header })
end

T['a report']['shows with no icon among the records when the Report opens in a new editor'] = function()
  local state_directory = fixture.directory('report-state')
  local environment = { state_directory = state_directory, working_directory = '/projects/alpha' }
  report_editor.start(
    child,
    vim.tbl_extend('error', environment, { times = { '2026-09-24T09:05:00' } })
  )
  report_editor.receive(child, { task = 'Task', status = 'failed', summary = 'Summary' })

  report_editor.start(
    child,
    vim.tbl_extend('error', environment, { times = { '2026-09-24T10:00:00' } })
  )

  eq(report_editor.lines(child), { '09:05 [failed] Task — Summary' })
end

T['a report']['shows with no icon when the user edits the Report again'] = function()
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(child, { task = 'Task', status = 'progress', summary = 'Summary' })
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])

  child.cmd('edit')

  eq(report_editor.lines(child), { '09:05 [progress] Task — Summary' })
end

T['a report']['renders each line of its details below it as an item, starting under its status'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(child, {
    task = 'Refactor the parser',
    status = 'done',
    summary = 'All tests pass',
    details = 'Changed three files\nRemoved the old tokenizer',
  })

  eq(report_editor.lines(child), {
    '09:05 [done] Refactor the parser — All tests pass',
    '      - Changed three files',
    '      - Removed the old tokenizer',
  })
end

T['a report']["indents its details six cells under 'ambiwidth' double"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  child.o.ambiwidth = 'double'

  report_editor.receive(
    child,
    { task = 'Task', status = 'progress', summary = 'Summary', details = 'Detail' }
  )

  eq(report_editor.lines(child), {
    '09:05 [progress] Task — Summary',
    '      - Detail',
  })
end

T['a report']['indents its details six cells whatever setcellwidths() gives its characters'] = function()
  start_editor({ '2026-09-24T09:05:00' })
  child.fn.setcellwidths({ { 0x2014, 0x2014, 2 } })

  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = 'Detail' }
  )

  eq(report_editor.lines(child), {
    '09:05 [done] Task — Summary',
    '      - Detail',
  })
end

T['a report']['indents its details six cells, however the current window wraps'] =
  MiniTest.new_set({
    parametrize = { { 'setlocal linebreak' }, { 'set showbreak=↪\\ ' } },
  })

T['a report']['indents its details six cells, however the current window wraps']['with'] = function(
  wrapping
)
  start_editor({ '2026-09-24T09:05:00' })
  child.cmd('vsplit')
  child.lua('vim.api.nvim_win_set_width(0, 6)')
  child.cmd(wrapping)

  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = 'Detail' }
  )

  eq(report_editor.lines(child), {
    '09:05 [done] Task — Summary',
    '      - Detail',
  })
end

T['a report']["indents every report's details six cells when reports of different statuses show together"] = function()
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  child.o.ambiwidth = 'double'
  report_editor.receive(
    child,
    { task = 'First', status = 'progress', summary = 'Began', details = 'One' }
  )
  report_editor.receive(
    child,
    { task = 'Second', status = 'done', summary = 'Ended', details = 'Two' }
  )
  local before_the_edit = report_editor.lines(child)
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])

  child.cmd('edit')

  eq({ before_the_edit, report_editor.lines(child) }, {
    {
      '09:05 [progress] First — Began',
      '      - One',
      '09:06 [done] Second — Ended',
      '      - Two',
    },
    {
      '09:05 [progress] First — Began',
      '      - One',
      '09:06 [done] Second — Ended',
      '      - Two',
    },
  })
end

T['a report']["indents every report's details six cells when a done report shows before a progress report"] = function()
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  child.o.ambiwidth = 'double'
  report_editor.receive(
    child,
    { task = 'First', status = 'done', summary = 'Ended', details = 'One' }
  )
  report_editor.receive(
    child,
    { task = 'Second', status = 'progress', summary = 'Began', details = 'Two' }
  )
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])

  child.cmd('edit')

  eq(report_editor.lines(child), {
    '09:05 [done] First — Ended',
    '      - One',
    '09:06 [progress] Second — Began',
    '      - Two',
  })
end

--- The expression, run in the child, that hands its report home one report
--- of each status the report tool accepts, each with one line of details,
--- and lists what went wrong: each error a report raised, and each line that
--- is neither a header starting with its time and `[status]` nor the details
--- as an item starting six cells in, under the `[status]`.
local EVERY_STATUS_FAULTS = [[(function()
  local report = require('aineo.report')
  local faults = {}
  for _, status in ipairs(report.report_schema().properties.status.enum) do
    local shown, failure = pcall(
      report.receive_report,
      { task = 'Task', status = status, summary = 'Summary', details = 'Detail' }
    )
    if not shown then
      table.insert(faults, failure)
    end
  end
  for _, line in ipairs(vim.api.nvim_buf_get_lines(report.report_buffer(), 0, -1, false)) do
    if not (line:find('^%d%d:%d%d %[%l+%] Task — Summary$') or line == '      - Detail') then
      table.insert(faults, line)
    end
  end
  return faults
end)()]]

T['a report']['of every status the report tool accepts shows with no icon, its details under its status'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  local faults = child.lua_get(EVERY_STATUS_FAULTS)

  eq(faults, {})
end

T['a report']["keeps its details six cells in when 'ambiwidth' changes before the user edits the Report again"] = function()
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  report_editor.receive(
    child,
    { task = 'First', status = 'progress', summary = 'Began', details = 'One' }
  )
  child.o.ambiwidth = 'double'
  report_editor.receive(
    child,
    { task = 'Second', status = 'progress', summary = 'Began', details = 'Two' }
  )
  local before_the_edit = report_editor.lines(child)
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])

  child.cmd('edit')

  eq({ before_the_edit, report_editor.lines(child) }, {
    {
      '09:05 [progress] First — Began',
      '      - One',
      '09:06 [progress] Second — Began',
      '      - Two',
    },
    {
      '09:05 [progress] First — Began',
      '      - One',
      '09:06 [progress] Second — Began',
      '      - Two',
    },
  })
end

T['a report']["keeps its details six cells in when 'ambiwidth' changes before the Report is made anew after the user deletes it"] =
  MiniTest.new_set({
    parametrize = { { 'bdelete' }, { 'bwipeout' }, { 'bunload' } },
  })

T['a report']["keeps its details six cells in when 'ambiwidth' changes before the Report is made anew after the user deletes it"]['with the command'] = function(
  command
)
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  report_editor.receive(
    child,
    { task = 'First', status = 'progress', summary = 'Began', details = 'One' }
  )
  child.o.ambiwidth = 'double'
  local before_the_delete = report_editor.lines(child)
  child.cmd(('%s %d'):format(command, child.lua_get([[require('aineo.report').report_buffer()]])))

  report_editor.receive(
    child,
    { task = 'Second', status = 'progress', summary = 'Began', details = 'Two' }
  )

  eq({ before_the_delete, report_editor.lines(child) }, {
    { '09:05 [progress] First — Began', '      - One' },
    {
      '09:05 [progress] First — Began',
      '      - One',
      '09:06 [progress] Second — Began',
      '      - Two',
    },
  })
end

T['a report']['renders a newline in its task or summary as a space'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  local failure = child.lua(
    [[return select(2, pcall(require('aineo.report').receive_report, ...))]],
    { { task = 'Refactor\nthe parser', status = 'done', summary = 'All\ntests pass' } }
  )

  eq(
    { failure, report_editor.lines(child) },
    { vim.NIL, { '09:05 [done] Refactor the parser — All tests pass' } }
  )
end

T['a report']['renders no details line when its details are empty'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = '' }
  )

  eq(report_editor.lines(child), { '09:05 [done] Task — Summary' })
end

--- Each row: a report's details, then the lines its details render as.
T['a report']['renders a details line that is empty, or white space alone, as an empty line'] =
  MiniTest.new_set({
    parametrize = {
      { 'One\n\nTwo', { '      - One', '', '      - Two' } },
      { 'One\n  \t \nTwo', { '      - One', '', '      - Two' } },
      { 'One\n', { '      - One', '' } },
    },
  })

T['a report']['renders a details line that is empty, or white space alone, as an empty line']['with the details'] = function(
  details,
  details_lines
)
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = details }
  )

  eq(report_editor.lines(child), { '09:05 [done] Task — Summary', unpack(details_lines) })
end

--- Each row: a details line Claude wrote as an item, or as its marker alone,
--- then the line it renders as.
T['a report']["renders a details line Claude marked as an item with aineo's marker in place of its own"] =
  MiniTest.new_set({
    parametrize = {
      { '- x', '      - x' },
      { '* x', '      - x' },
      { '+ x', '      - x' },
      { '• x', '      - x' },
      { '-  x', '      -  x' },
      { '-', '' },
      { '- ', '' },
      { '*  ', '' },
      { '+\t', '' },
      { '•', '' },
    },
  })

T['a report']["renders a details line Claude marked as an item with aineo's marker in place of its own"]['with the line'] = function(
  details,
  rendered
)
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = details }
  )

  eq(report_editor.lines(child), { '09:05 [done] Task — Summary', rendered })
end

--- Each row: a details line holding no marker aineo replaces, then the line
--- it renders as.
T['a report']['renders any other details line as an item, keeping its text as written'] =
  MiniTest.new_set({
    parametrize = {
      { '(D18, C12, #31)', '      - (D18, C12, #31)' },
      { '  - x', '      -   - x' },
      { '1. x', '      - 1. x' },
      { '-x', '      - -x' },
      { '**x**', '      - **x**' },
      { '•x', '      - •x' },
    },
  })

T['a report']['renders any other details line as an item, keeping its text as written']['with the line'] = function(
  details,
  rendered
)
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(
    child,
    { task = 'Task', status = 'done', summary = 'Summary', details = details }
  )

  eq(report_editor.lines(child), { '09:05 [done] Task — Summary', rendered })
end

T['a report']['that is invalid is refused, naming the field, and not rendered'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  local refusal = child.lua(
    [[return select(2, pcall(require('aineo.report').receive_report, ...))]],
    { { task = '', status = 'done', summary = 'Summary' } }
  )

  eq(refusal, 'aineo refused the report: task: expected a non-empty string')
  eq(report_editor.lines(child), { '' })
end

--- The expression, run in the child, that shows its Report in a new window
--- `width` columns wide at the editor's left, wrapping long lines as the
--- layout makes it wrap (`'wrap'`, `'linebreak'` and `'breakindent'`, as
--- `:setlocal` sets them), and returns that window.
local SHOW_REPORT_WRAPPING = [[(function(width)
  vim.cmd('topleft vsplit')
  local window = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(window, require('aineo.report').report_buffer())
  vim.api.nvim_win_set_width(window, width)
  for _, option in ipairs({ 'wrap', 'linebreak', 'breakindent' }) do
    vim.wo[window][0][option] = true
  end
  return window
end)(...)]]

--- The expression, run in the child, that returns the column of `window`,
--- from 1, at which the second screen row of line `line`, from 1, of the
--- buffer it shows starts: where that line, wrapped, continues. Nil when the
--- line takes one screen row.
local CONTINUATION_COLUMN = [[(function(window, line)
  vim.cmd('redraw')
  local left = vim.fn.win_screenpos(window)[2]
  local buffer = vim.api.nvim_win_get_buf(window)
  local text = vim.api.nvim_buf_get_lines(buffer, line - 1, line, true)[1]
  local first_row = vim.fn.screenpos(window, line, 1).row
  for byte = 2, #text do
    local position = vim.fn.screenpos(window, line, byte)
    if position.row ~= first_row then
      return position.col - left + 1
    end
  end
  return nil
end)(...)]]

--- Shows the child's Report in a new window `width` columns wide, wrapping
--- as the layout makes it wrap (`SHOW_REPORT_WRAPPING`), and returns that
--- window.
---
---@param width integer
---@return integer
local function show_report_wrapping(width)
  return child.lua_get(SHOW_REPORT_WRAPPING, { width })
end

--- Where line `line` of the buffer `window` shows continues when wrapped
--- (`CONTINUATION_COLUMN`).
---
---@param window integer
---@param line integer
---@return integer?
local function continuation_column(window, line)
  return child.lua_get(CONTINUATION_COLUMN, { window, line })
end

--- A report whose header and details line each wrap in a Report 30 columns
--- wide or narrower.
local LONG_REPORT = {
  task = 'Refactor the parser',
  status = 'done',
  summary = 'moved the tokenizer into its own module',
  details = 'a details line long enough to wrap in a narrow Report, twice over',
}

T['a wrapped report'] = MiniTest.new_set()

T['a wrapped report']['continues its first line under the [ of its status'] = function()
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(child, LONG_REPORT)
  local window = show_report_wrapping(30)

  local column = continuation_column(window, 1)

  eq(column, 7)
end

T['a wrapped report']["continues its first line under the [ of its status with 'number' on"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(child, LONG_REPORT)
  local window = show_report_wrapping(30)
  child.lua('vim.wo[...].number = true', { window })

  local column = continuation_column(window, 1)

  eq(column, 7 + child.lua_get('vim.wo[...].numberwidth', { window }))
end

T['a wrapped report']["continues its first line the width of the user's 'showbreak' past the ["] = function()
  start_editor({ '2026-09-24T09:05:00' })
  child.cmd('set showbreak=↪\\ ')
  report_editor.receive(child, LONG_REPORT)
  local window = show_report_wrapping(30)

  local column = continuation_column(window, 1)

  eq(column, 9)
end

T['a wrapped report']['continues a details line under its text, not under its -'] = function()
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(child, LONG_REPORT)
  local window = show_report_wrapping(30)

  local column = continuation_column(window, 2)

  eq(column, 9)
end

T['a wrapped report']['narrower than 28 columns continues a details line further left, keeping 20 columns of text'] = function()
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(child, LONG_REPORT)
  local window = show_report_wrapping(24)

  local column = continuation_column(window, 2)

  eq(column, 5)
end

T['a wrapped report']["continues a details line under its text in a window split from the Report's"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(child, LONG_REPORT)
  show_report_wrapping(30)
  child.cmd('split')

  local column = continuation_column(child.api.nvim_get_current_win(), 2)

  eq(column, 9)
end

--- The expression, run in the child, that shows in `window` a new buffer
--- holding one numbered line, long enough to wrap in a narrow window, which
--- Neovim's own `'formatlistpat'` matches, and makes it wrap as the layout
--- makes Input wrap (`'wrap'`, `'linebreak'` and `'breakindent'`, as
--- `:setlocal` sets them).
local SHOW_NUMBERED_LINE = [[(function(window)
  local other = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(other, 0, -1, false, {
    '1. a numbered line long enough to wrap in a narrow window, twice over',
  })
  vim.api.nvim_win_set_buf(window, other)
  for _, option in ipairs({ 'wrap', 'linebreak', 'breakindent' }) do
    vim.wo[window][0][option] = true
  end
end)(...)]]

T['a wrapped report']["leaves Neovim's wrapping to another buffer shown later in the Report's window"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(child, LONG_REPORT)
  local window = show_report_wrapping(30)

  child.lua(SHOW_NUMBERED_LINE, { window })

  eq(continuation_column(window, 1), 1)
end

T['a wrapped report']["leaves Neovim's wrapping to another buffer in a window split from the Report's"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(child, LONG_REPORT)
  show_report_wrapping(30)
  child.cmd('split')
  local split = child.api.nvim_get_current_win()

  child.lua(SHOW_NUMBERED_LINE, { split })

  eq(continuation_column(split, 1), 1)
end

T['a wrapped report']["continues a details line under its text again when shown again after the user empties 'breakindentopt'"] = function()
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(child, LONG_REPORT)
  local window = show_report_wrapping(30)
  child.cmd('setlocal breakindentopt=')
  child.lua(SHOW_NUMBERED_LINE, { window })

  child.lua([[vim.api.nvim_win_set_buf(..., require('aineo.report').report_buffer())]], { window })

  eq(continuation_column(window, 2), 9)
end

T['a wrapped report']['continues a details line under its text after the user edits the Report again'] = function()
  start_editor({ '2026-09-24T09:05:00' })
  report_editor.receive(child, LONG_REPORT)
  local window = show_report_wrapping(30)

  child.cmd('edit')

  eq(continuation_column(window, 2), 9)
end

T['a wrapped report']['continues a details line under its text in a Report made anew after the user wipes it out'] = function()
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  report_editor.receive(child, LONG_REPORT)
  child.cmd(('bwipeout %d'):format(child.lua_get([[require('aineo.report').report_buffer()]])))
  report_editor.receive(child, LONG_REPORT)

  local window = show_report_wrapping(30)

  eq(continuation_column(window, 2), 9)
end

T['the Report buffer'] = MiniTest.new_set()

--- The expression, run in the child, that describes its Report buffer.
local REPORT_BUFFER_IDENTITY = [[(function()
  local buffer = require('aineo.report').report_buffer()
  return {
    number = buffer,
    name = vim.api.nvim_buf_get_name(buffer),
    buftype = vim.bo[buffer].buftype,
    swapfile = vim.bo[buffer].swapfile,
    bufhidden = vim.bo[buffer].bufhidden,
    buflisted = vim.bo[buffer].buflisted,
  }
end)()]]

T['the Report buffer']['is named aineo://report, is no file, has no swap file, is kept hidden and unlisted'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  local identity = child.lua_get(REPORT_BUFFER_IDENTITY)

  eq(
    { identity.name, identity.buftype, identity.swapfile, identity.bufhidden, identity.buflisted },
    { 'aineo://report', 'nofile', false, 'hide', false }
  )
end

T['the Report buffer']['is the same buffer on every use'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  local first = child.lua_get([[require('aineo.report').report_buffer()]])
  local second = child.lua_get([[require('aineo.report').report_buffer()]])

  eq(second, first)
end

T['the Report buffer']['stays the Report when a file is edited from its window while it is empty'] = function()
  start_editor({ '2026-09-24T09:05:00' })
  local file = fixture.write('report-edit/notes.txt', { 'a note' })
  local before = child.lua_get(REPORT_BUFFER_IDENTITY)
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])

  child.cmd('edit ' .. vim.fn.fnameescape(file))

  eq(child.lua_get(REPORT_BUFFER_IDENTITY), before)
end

T['the Report buffer']['keeps every report when the user edits it again'] = MiniTest.new_set({
  parametrize = { { 'edit' }, { 'edit!' } },
})

T['the Report buffer']['keeps every report when the user edits it again']['with'] = function(
  command
)
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  report_editor.receive(child, { task = 'First', status = 'started', summary = 'Began' })
  report_editor.receive(child, { task = 'First', status = 'done', summary = 'Ended' })
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])

  child.cmd(command)

  eq(
    report_editor.lines(child),
    { '09:05 [started] First — Began', '09:06 [done] First — Ended' }
  )
end

T['the Report buffer']['shows reports in the order they arrive'] = function()
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })

  report_editor.receive(child, { task = 'First', status = 'started', summary = 'Began' })
  report_editor.receive(child, { task = 'First', status = 'done', summary = 'Ended' })

  eq(
    report_editor.lines(child),
    { '09:05 [started] First — Began', '09:06 [done] First — Ended' }
  )
end

T['the Report buffer']['refuses the user an edit, and still takes the next report'] = function()
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  report_editor.receive(child, { task = 'First', status = 'started', summary = 'Began' })
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])

  local refusal = child.lua([[return select(2, pcall(vim.cmd, 'normal! Goa line the user typed'))]])
  report_editor.receive(child, { task = 'First', status = 'done', summary = 'Ended' })

  eq(tostring(refusal):match('E21:'), 'E21:')
  eq(
    report_editor.lines(child),
    { '09:05 [started] First — Began', '09:06 [done] First — Ended' }
  )
end

T['the Report buffer']['moves every window showing it to the newest report'] = function()
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])
  child.cmd('split')

  report_editor.receive(child, { task = 'First', status = 'started', summary = 'Began' })
  report_editor.receive(
    child,
    { task = 'First', status = 'done', summary = 'Ended', details = 'One\nTwo' }
  )

  eq(
    child.lua_get([[vim.tbl_map(function(window)
      return vim.api.nvim_win_get_cursor(window)[1]
    end, vim.fn.win_findbuf(require('aineo.report').report_buffer()))]]),
    { 4, 4 }
  )
end

T['the Report buffer']['comes back with every report after the user deletes it'] =
  MiniTest.new_set({
    parametrize = { { 'bdelete' }, { 'bwipeout' }, { 'bunload' } },
  })

T['the Report buffer']['comes back with every report after the user deletes it']['with the command'] = function(
  command
)
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  report_editor.receive(child, { task = 'First', status = 'started', summary = 'Began' })
  child.cmd(('%s %d'):format(command, child.lua_get([[require('aineo.report').report_buffer()]])))

  local failure = child.lua(
    [[return select(2, pcall(require('aineo.report').receive_report, ...))]],
    { { task = 'First', status = 'done', summary = 'Ended' } }
  )

  eq(failure, vim.NIL)
  local identity = child.lua_get(REPORT_BUFFER_IDENTITY)
  eq({ identity.name, identity.buftype }, { 'aineo://report', 'nofile' })
  eq(
    report_editor.lines(child),
    { '09:05 [started] First — Began', '09:06 [done] First — Ended' }
  )
end

--- The expression, run in the child, that lists the `'buftype'` of each
--- buffer named `aineo://report`, and counts the `nofile` buffers.
local REPORT_NAME_HOLDERS = [[{
  named = vim.tbl_map(function(buffer)
    return vim.bo[buffer].buftype
  end, vim.tbl_filter(function(buffer)
    return vim.api.nvim_buf_get_name(buffer) == 'aineo://report'
  end, vim.api.nvim_list_bufs())),
  scratch = #vim.tbl_filter(function(buffer)
    return vim.bo[buffer].buftype == 'nofile'
  end, vim.api.nvim_list_bufs()),
}]]

T['the Report buffer']['takes its name back from a buffer holding it, and leaks none'] =
  MiniTest.new_set({
    parametrize = {
      {
        {
          [[lua require('aineo.report').report_buffer()]],
          'bwipeout aineo://report',
          'edit aineo://report',
        },
      },
      { { 'file aineo://report' } },
    },
  })

T['the Report buffer']['takes its name back from a buffer holding it, and leaks none']['after'] = function(
  commands
)
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  child.lua([[for _, command in ipairs(...) do vim.cmd(command) end]], { commands })

  local failures = child.lua(
    [[return {
    select(2, pcall(require('aineo.report').receive_report, ...)),
    select(2, pcall(require('aineo.report').receive_report, ...)),
  }]],
    { { task = 'First', status = 'done', summary = 'Ended' } }
  )

  eq(failures, {})
  eq(child.lua_get(REPORT_NAME_HOLDERS), { named = { 'nofile' }, scratch = 1 })
end

T['the Report buffer']['deleted then shown again by the user takes no report, and the editor quits'] =
  MiniTest.new_set({ parametrize = { { 'buffer #' }, { 'buffer aineo://report' } } })

T['the Report buffer']['deleted then shown again by the user takes no report, and the editor quits']['with'] = function(
  command
)
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  report_editor.receive(child, { task = 'First', status = 'started', summary = 'Began' })
  child.lua([[
    local report = require('aineo.report').report_buffer()
    vim.api.nvim_set_current_buf(report)
    vim.cmd.enew()
    vim.cmd.bdelete(report)
  ]])
  child.cmd(command)

  local failure = child.lua(
    [[return select(2, pcall(require('aineo.report').receive_report, ...))]],
    { { task = 'First', status = 'done', summary = 'Ended' } }
  )
  local identity = child.lua_get(REPORT_BUFFER_IDENTITY)
  pcall(child.cmd, 'qall')

  eq(
    { failure, identity.buftype, vim.fn.jobwait({ child.job.id }, 2000)[1] },
    { vim.NIL, 'nofile', 0 }
  )
end

T['the Report buffer']['never discards text the user typed into a buffer holding its name'] =
  MiniTest.new_set({
    parametrize = {
      { 'bwipeout %d | edit aineo://report' },
      { 'enew | bdelete %d | buffer aineo://report' },
    },
  })

T['the Report buffer']['never discards text the user typed into a buffer holding its name']['after'] = function(
  commands
)
  start_editor({ '2026-09-24T09:05:00', '2026-09-24T09:06:00' })
  report_editor.receive(child, { task = 'First', status = 'started', summary = 'Began' })
  child.cmd(commands:format(child.lua_get([[require('aineo.report').report_buffer()]])))
  local typed = child.lua_get('vim.api.nvim_get_current_buf()')
  child.lua([[vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'my own notes' })]])

  local failure = child.lua(
    [[return select(2, pcall(require('aineo.report').receive_report, ...))]],
    { { task = 'First', status = 'done', summary = 'Ended' } }
  )

  eq(
    { failure, child.lua_get(('vim.fn.getbufline(%d, "$")'):format(typed)) },
    { vim.NIL, { 'my own notes' } }
  )
end

T['the Report buffer']['is refused until the report home has its environment'] = function()
  children.restart(child)

  local refusal = child.lua([[return select(2, pcall(require('aineo.report').report_buffer))]])

  eq(refusal, 'aineo.report has no environment: call set_report_environment() first')
end

T['the records'] = MiniTest.new_set()

--- A records line of exactly `bytes` bytes, its newline counted, holding a
--- report received at 09:05 whose task is `Task <number>`.
---
---@param number integer
---@param bytes integer
---@return string
local function record_line(number, bytes)
  local record = {
    time = '2026-09-24T09:05:00',
    report = { task = ('Task %04d'):format(number), status = 'done', summary = 'Summary' },
  }
  record.report.details = ('x'):rep(bytes - 1 - #vim.json.encode(record) - #',"details":""')
  return vim.json.encode(record)
end

--- The records file of `/projects/alpha` under `state_directory`, holding
--- the records numbered `first` to `last`, each a line of exactly 1 KiB (its
--- newline counted) whose task is `Task <number>`.
---
---@param child_editor table the child the records are made through
---@param state_directory string
---@param first integer
---@param last integer
---@return string file
local function records_file_holding(child_editor, state_directory, first, last)
  report_editor.start(child_editor, {
    times = { '2026-09-24T09:05:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })
  report_editor.receive(child_editor, { task = 'Task', status = 'done', summary = 'Summary' })
  local file = vim.fs.find(function()
    return true
  end, { path = state_directory, type = 'file' })[1]
  local lines = {}
  for number = first, last do
    table.insert(lines, record_line(number, 1024))
  end
  vim.fn.writefile(lines, file)
  return file
end

--- The expression, run in the child, that lists the header line of each
--- report its Report shows, leaving out the lines of their details: a
--- header starts with its time, a details line with its indent.
local REPORT_HEADERS = [[vim.tbl_filter(function(line)
  return line:find('^%S')
end, vim.api.nvim_buf_get_lines(require('aineo.report').report_buffer(), 0, -1, false))]]

T['the records']['show the newest 2 MiB of them'] = function()
  local state_directory = fixture.directory('report-state')
  local file = records_file_holding(child, state_directory, 1, 3072)
  report_editor.start(child, {
    times = { '2026-09-24T10:00:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })

  local headers = child.lua_get(REPORT_HEADERS)

  eq({ vim.uv.fs_stat(file).size, #headers, headers[1], headers[#headers] }, {
    3 * 1024 * 1024,
    2048,
    '09:05 [done] Task 1025 — Summary',
    '09:05 [done] Task 3072 — Summary',
  })
end

T['the records']['show whole records only, when the newest 2 MiB begin inside one'] = function()
  local state_directory = fixture.directory('report-state')
  local file = records_file_holding(child, state_directory, 1, 3072)
  vim.fn.writefile({ record_line(3073, 1536) }, file, 'a')
  report_editor.start(child, {
    times = { '2026-09-24T10:00:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })

  local headers = child.lua_get(REPORT_HEADERS)
  local messages = child.cmd_capture('messages')

  eq(
    { #headers, headers[1], headers[#headers], messages },
    { 2047, '09:05 [done] Task 1027 — Summary', '09:05 [done] Task 3073 — Summary', '' }
  )
end

--- The task of the report the records line `line` holds, or nil when the
--- line holds no record: a test reading a broken line fails on its assertion.
---
---@param line string
---@return string?
local function recorded_task(line)
  local read, task = pcall(function()
    return vim.json.decode(line).report.task
  end)
  return read and task or nil
end

T['the records']['are cut to their newest 2 MiB once they have grown past 4 MiB'] = function()
  local state_directory = fixture.directory('report-state')
  local file = records_file_holding(child, state_directory, 1, 4097)
  report_editor.start(child, {
    times = { '2026-09-24T10:00:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })

  report_editor.receive(child, { task = 'Newest', status = 'done', summary = 'Kept' })

  local lines = vim.fn.readfile(file)
  eq(
    { #lines, recorded_task(lines[1]), recorded_task(lines[#lines]) },
    { 2049, 'Task 2050', 'Newest' }
  )
end

T['the records']['are kept whole up to 4 MiB when a report is added'] = function()
  local state_directory = fixture.directory('report-state')
  local file = records_file_holding(child, state_directory, 1, 4096)
  report_editor.start(child, {
    times = { '2026-09-24T10:00:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })

  report_editor.receive(child, { task = 'Newest', status = 'done', summary = 'Kept' })

  local lines = vim.fn.readfile(file)
  eq(
    { #lines, recorded_task(lines[1]), recorded_task(lines[#lines]) },
    { 4097, 'Task 0001', 'Newest' }
  )
end

T['the records']['cut by another editor while this one cuts them are still cut, without a warning'] = function()
  local state_directory = fixture.directory('report-state')
  local environment = {
    times = { '2026-09-24T10:00:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  }
  records_file_holding(child, state_directory, 1, 4097)
  report_editor.start(other_editor, environment)
  report_editor.start(child, environment)
  child.lua(
    [[
      local other_address, other_report = ...
      local rename = vim.uv.fs_rename
      vim.uv.fs_rename = function(...)
        vim.uv.fs_rename = rename
        local channel = vim.fn.sockconnect('pipe', other_address, { rpc = true })
        vim.rpcrequest(
          channel,
          'nvim_exec_lua',
          "require('aineo.report').receive_report(...)",
          { other_report }
        )
        vim.fn.chanclose(channel)
        return rename(...)
      end
    ]],
    { other_editor.job.address, { task = 'Other', status = 'done', summary = 'Cut first' } }
  )

  local failure = child.lua(
    [[return select(2, pcall(require('aineo.report').receive_report, ...))]],
    { { task = 'Newest', status = 'done', summary = 'Kept' } }
  )

  eq({ failure, child.cmd_capture('messages') }, { vim.NIL, '' })
end

T['the records']['kept through a symbolic link are cut behind it, and the link stays'] = function()
  local state_directory = fixture.directory('report-state')
  local file = records_file_holding(child, state_directory, 1, 4097)
  local target = vim.fs.joinpath(fixture.directory('report-records-target'), 'records.jsonl')
  vim.uv.fs_rename(file, target)
  vim.uv.fs_symlink(target, file)
  report_editor.start(child, {
    times = { '2026-09-24T10:00:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })

  report_editor.receive(child, { task = 'Newest', status = 'done', summary = 'Kept' })

  local lines = vim.fn.readfile(target)
  eq(
    { vim.uv.fs_lstat(file).type, #lines, recorded_task(lines[#lines]) },
    { 'link', 2049, 'Newest' }
  )
end

T['the records']['that cannot be cut keep the report, and tell the user why'] = function()
  local state_directory = fixture.directory('report-state')
  local file = records_file_holding(child, state_directory, 1, 4097)
  local records_directory = vim.fs.dirname(file)
  report_editor.start(child, {
    times = { '2026-09-24T10:00:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })
  vim.fn.setfperm(records_directory, 'r-x------')

  local failure = child.lua(
    [[return select(2, pcall(require('aineo.report').receive_report, ...))]],
    { { task = 'Newest', status = 'done', summary = 'Kept' } }
  )
  local messages = child.cmd_capture('messages')
  vim.fn.setfperm(records_directory, 'rwx------')

  local lines = vim.fn.readfile(file)
  eq({
    failure,
    #lines,
    recorded_task(lines[#lines]),
    vim.startswith(messages, 'aineo cannot cut the report records in ' .. file),
  }, { vim.NIL, 4098, 'Newest', true })
end

T['the records']['show a report again, at its own time, in a new editor in the same directory'] = function()
  local state_directory = fixture.directory('report-state')
  report_editor.start(child, {
    times = { '2026-09-24T09:05:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })
  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  report_editor.start(child, {
    times = { '2026-09-24T10:00:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })

  eq(report_editor.lines(child), { '09:05 [done] Task — Summary' })
end

--- Every file under `directory`, at any depth.
---
---@param directory string
---@return string[]
local function files_under(directory)
  return vim.fs.find(function()
    return true
  end, { path = directory, type = 'file', limit = math.huge })
end

T['the records']['keep each report as one line of one file under the state directory'] = function()
  local state_directory = fixture.directory('report-state')
  report_editor.start(child, {
    times = { '2026-09-24T09:05:00', '2026-09-24T09:06:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })

  report_editor.receive(child, { task = 'First', status = 'started', summary = 'Began' })
  report_editor.receive(child, { task = 'First', status = 'done', summary = 'Ended' })

  local files = files_under(state_directory)
  eq({ #files, #vim.fn.readfile(files[1]) }, { 1, 2 })
end

T['the records']['are readable and writable by their owner only'] = function()
  local state_directory = fixture.directory('report-state')
  report_editor.start(child, {
    times = { '2026-09-24T09:05:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })

  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  local permissions = vim.uv.fs_stat(files_under(state_directory)[1]).mode % 512
  eq(('%o'):format(permissions), '600')
end

T['the records']['refuse a report they cannot keep, naming the file, and show nothing'] = function()
  local state_directory = fixture.directory('report-state')
  local records_directory = vim.fs.joinpath(state_directory, 'aineo', 'reports')
  vim.fn.mkdir(records_directory, 'p')
  vim.fn.setfperm(records_directory, 'r-x------')
  report_editor.start(child, {
    times = { '2026-09-24T09:05:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })

  local refusal = child.lua(
    [[return select(2, pcall(require('aineo.report').receive_report, ...))]],
    { { task = 'Task', status = 'done', summary = 'Summary' } }
  )
  vim.fn.setfperm(records_directory, 'rwx------')

  eq(
    vim.startswith(tostring(refusal), 'aineo cannot keep the report in ' .. records_directory),
    true
  )
  eq(report_editor.lines(child), { '' })
end

T['the records']['that cannot keep a report tell the user why, once'] = function()
  local state_directory = fixture.directory('report-state')
  local records_directory = vim.fs.joinpath(state_directory, 'aineo', 'reports')
  vim.fn.mkdir(records_directory, 'p')
  vim.fn.setfperm(records_directory, 'r-x------')
  report_editor.start(child, {
    times = { '2026-09-24T09:05:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })

  local refusal = child.lua(
    [[return select(2, pcall(require('aineo.report').receive_report, ...))]],
    { { task = 'Task', status = 'done', summary = 'Summary' } }
  )
  local messages = child.cmd_capture('messages')
  vim.fn.setfperm(records_directory, 'rwx------')

  eq(messages, refusal)
end

--- The Lua, run in the child, that makes its next `vim.fn.mkdir()` calls
--- fail as they do for an editor that loses races to make a directory: for
--- each number in the list `...`, another editor has just made the directory
--- that many levels up the path (0 for the directory itself), and mkdir
--- fails on it with E739. The calls after those are mkdir's own.
local LOSE_MKDIR_RACES = [[
  local levels_up = ...
  local make_directory = vim.fn.mkdir
  vim.fn.mkdir = function(directory, flags)
    local levels = table.remove(levels_up, 1)
    if #levels_up == 0 then
      vim.fn.mkdir = make_directory
    end
    local made_by_another = vim.fn.fnamemodify(directory, (':h'):rep(levels))
    make_directory(made_by_another, flags)
    error('Vim:E739: Cannot create directory ' .. made_by_another .. ': file already exists', 0)
  end
]]

T['the records']['keep a report when another editor makes their directory at the same moment'] =
  MiniTest.new_set({ parametrize = { { { 0 } }, { { 1 } }, { { 1, 0 } } } })

T['the records']['keep a report when another editor makes their directory at the same moment']['levels up'] = function(
  levels_up
)
  report_editor.start(child, {
    times = { '2026-09-24T09:05:00' },
    state_directory = fixture.directory('report-state'),
    working_directory = '/projects/alpha',
  })
  child.lua(LOSE_MKDIR_RACES, { levels_up })

  local failure = child.lua(
    [[return select(2, pcall(require('aineo.report').receive_report, ...))]],
    { { task = 'Task', status = 'done', summary = 'Summary' } }
  )

  eq({ failure, report_editor.lines(child) }, { vim.NIL, { '09:05 [done] Task — Summary' } })
end

T['the records']['whose directory cannot be made refuse a report, naming the directory'] = function()
  local state_directory = fixture.directory('report-state')
  local records_directory = vim.fs.joinpath(state_directory, 'aineo', 'reports')
  vim.fn.writefile({}, vim.fs.joinpath(state_directory, 'aineo'))
  report_editor.start(child, {
    times = { '2026-09-24T09:05:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })

  local refusal = child.lua(
    [[return select(2, pcall(require('aineo.report').receive_report, ...))]],
    { { task = 'Task', status = 'done', summary = 'Summary' } }
  )

  eq(
    vim.startswith(
      tostring(refusal),
      'aineo cannot make the directory of the report records ' .. records_directory .. ': '
    ),
    true
  )
end

T['the records']['keep no refused report'] = function()
  local state_directory = fixture.directory('report-state')
  report_editor.start(child, {
    times = { '2026-09-24T09:05:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })

  child.lua(
    [[pcall(require('aineo.report').receive_report, ...)]],
    { { task = 'Task', status = 'finished', summary = 'Summary' } }
  )

  eq(files_under(state_directory), {})
end

T['the records']['show before a new report, and each only once'] = function()
  local state_directory = fixture.directory('report-state')
  report_editor.start(child, {
    times = { '2026-09-24T09:05:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })
  report_editor.receive(child, { task = 'First', status = 'done', summary = 'Kept' })
  report_editor.start(child, {
    times = { '2026-09-24T10:00:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })

  report_editor.receive(child, { task = 'Second', status = 'started', summary = 'New' })

  eq(
    report_editor.lines(child),
    { '09:05 [done] First — Kept', '10:00 [started] Second — New' }
  )
end

T['the records']['that cannot be read are skipped and counted'] = MiniTest.new_set({
  parametrize = {
    { 'not JSON' },
    { '{"time":"2026-09-24T08:00:00"}' },
    { '{"time":"08:00","report":{"task":"T","status":"done","summary":"S"}}' },
    { '[1,2]' },
  },
})

T['the records']['that cannot be read are skipped and counted']['as a line'] = function(line)
  local state_directory = fixture.directory('report-state')
  local environment = {
    times = { '2026-09-24T09:05:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  }
  report_editor.start(child, environment)
  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })
  local file = files_under(state_directory)[1]
  vim.fn.writefile({ line }, file, 'a')
  report_editor.start(child, environment)

  local lines = report_editor.lines(child)

  eq(lines, { '09:05 [done] Task — Summary' })
  eq(child.cmd_capture('messages'), 'aineo: skipped 1 unreadable report record(s) in ' .. file)
end

T['the records']['that cannot be read are reported, and the Report opens without them'] = function()
  local state_directory = fixture.directory('report-state')
  local environment = {
    times = { '2026-09-24T09:05:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  }
  report_editor.start(child, environment)
  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })
  local file = files_under(state_directory)[1]
  vim.fn.setfperm(file, '-w-------')
  report_editor.start(child, environment)

  local lines = report_editor.lines(child)
  local messages = child.cmd_capture('messages')
  vim.fn.setfperm(file, 'rw-------')

  eq(lines, { '' })
  eq(vim.startswith(messages, 'aineo cannot read the report records in ' .. file), true)
end

T['the records']['that are no file are reported, naming the file, and the Report opens without them'] = function()
  local state_directory = fixture.directory('report-state')
  local file = vim.fs.joinpath(
    state_directory,
    'aineo',
    'reports',
    vim.fn.sha256('/projects/alpha') .. '.jsonl'
  )
  vim.fn.mkdir(file, 'p')
  report_editor.start(child, {
    times = { '2026-09-24T09:05:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })

  local lines = report_editor.lines(child)
  local messages = child.cmd_capture('messages')

  eq(lines, { '' })
  eq(vim.startswith(messages, 'aineo cannot read the report records in ' .. file), true)
end

T['the records']['of another working directory never show'] = function()
  local state_directory = fixture.directory('report-state')
  report_editor.start(child, {
    times = { '2026-09-24T09:05:00' },
    state_directory = state_directory,
    working_directory = '/projects/alpha',
  })
  report_editor.receive(child, { task = 'Task', status = 'done', summary = 'Summary' })

  report_editor.start(child, {
    times = { '2026-09-24T10:00:00' },
    state_directory = state_directory,
    working_directory = '/projects/beta',
  })

  eq(report_editor.lines(child), { '' })
end

T['a report']['is refused until the report home has its environment'] = function()
  children.restart(child)

  local refusal = child.lua(
    [[return select(2, pcall(require('aineo.report').receive_report, ...))]],
    { { task = 'Task', status = 'done', summary = 'Summary' } }
  )

  eq(refusal, 'aineo.report has no environment: call set_report_environment() first')
end

return T
