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

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

T['a report'] = MiniTest.new_set()

T['a report']['renders as its time, status, task and summary'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(
    child,
    { task = 'Refactor the parser', status = 'done', summary = 'All tests pass' }
  )

  eq(report_editor.lines(child), { '09:05 [done] Refactor the parser — All tests pass' })
end

T['a report']['renders each line of its details below it, indented'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  report_editor.receive(child, {
    task = 'Refactor the parser',
    status = 'done',
    summary = 'All tests pass',
    details = 'Changed three files\nRemoved the old tokenizer',
  })

  eq(report_editor.lines(child), {
    '09:05 [done] Refactor the parser — All tests pass',
    '      Changed three files',
    '      Removed the old tokenizer',
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

T['a report']['that is invalid is refused, naming the field, and not rendered'] = function()
  start_editor({ '2026-09-24T09:05:00' })

  local refusal = child.lua(
    [[return select(2, pcall(require('aineo.report').receive_report, ...))]],
    { { task = '', status = 'done', summary = 'Summary' } }
  )

  eq(refusal, 'aineo refused the report: task: expected a non-empty string')
  eq(report_editor.lines(child), { '' })
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
    parametrize = { { 'bdelete' }, { 'bwipeout' } },
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

T['the Report buffer']['is refused until the report home has its environment'] = function()
  children.restart(child)

  local refusal = child.lua([[return select(2, pcall(require('aineo.report').report_buffer))]])

  eq(refusal, 'aineo.report has no environment: call set_report_environment() first')
end

T['the records'] = MiniTest.new_set()

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
