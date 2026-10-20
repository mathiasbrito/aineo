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
    state_directory = fixture.directory('report-days-state'),
    working_directory = '/projects/alpha',
  })
end

--- Hands the child's report home a report whose task is `task`.
---
---@param task string
local function receive(task)
  report_editor.receive(child, { task = task, status = 'done', summary = 'S' })
end

local T = MiniTest.new_set({
  hooks = {
    post_once = function()
      child.stop()
    end,
  },
})

T['the days'] = MiniTest.new_set()

T['the days']['a report received now is under the separator of today'] = function()
  start_editor({ '2026-10-20T09:05:00' })

  receive('A')

  eq(report_editor.lines_with_days(child), { '── Today ──', '09:05 [done] A — S' })
end

T['the days']['three days of reports read, as of the last, a date, Yesterday and Today'] = function()
  start_editor({ '2026-10-18T09:05:00', '2026-10-19T10:00:00', '2026-10-20T11:30:00' })

  receive('A')
  receive('B')
  receive('C')

  eq(report_editor.lines_with_days(child), {
    '── Sun 18 Oct ──',
    '09:05 [done] A — S',
    '── Yesterday ──',
    '10:00 [done] B — S',
    '── Today ──',
    '11:30 [done] C — S',
  })
end

T['the days']['a day of another year reads with its year'] = function()
  start_editor({ '2025-10-19T09:05:00', '2026-10-20T11:30:00' })

  receive('A')
  receive('B')

  eq(report_editor.lines_with_days(child), {
    '── Sun 19 Oct 2025 ──',
    '09:05 [done] A — S',
    '── Today ──',
    '11:30 [done] B — S',
  })
end

T['the days']['two reports of one day have one separator'] = function()
  start_editor({ '2026-10-20T09:05:00', '2026-10-20T11:30:00' })

  receive('A')
  receive('B')

  eq(
    report_editor.lines_with_days(child),
    { '── Today ──', '09:05 [done] A — S', '11:30 [done] B — S' }
  )
end

T['the days']['a report with no readable time goes under the separator before it'] = function()
  start_editor({ '2026-10-20T09:05:00', 'sometime' })

  receive('A')
  receive('B')

  eq(
    report_editor.lines_with_days(child),
    { '── Today ──', '09:05 [done] A — S', ' [done] B — S' }
  )
end

T['the days']['the saved reports read as of the clock when the Report opens again'] = function()
  local state_directory = fixture.directory('report-days-reopened-state')
  local environment = { state_directory = state_directory, working_directory = '/projects/alpha' }
  report_editor.start(
    child,
    vim.tbl_extend('error', environment, { times = { '2026-10-19T09:05:00' } })
  )
  receive('A')

  report_editor.start(
    child,
    vim.tbl_extend('error', environment, { times = { '2026-10-20T08:00:00' } })
  )
  receive('B')

  eq(report_editor.lines_with_days(child), {
    '── Yesterday ──',
    '09:05 [done] A — S',
    '── Today ──',
    '08:00 [done] B — S',
  })
end

--- The expression, run in the child, that lists every colour on the lines of
--- its Report as `{ line, first column, end column, group, url }`, counted as
--- the API counts them: from 0, the end column excluded.
local COLOURS_OF_REPORT = [[(function()
  local buffer = require('aineo.report').report_buffer()
  local marks = vim.api.nvim_buf_get_extmarks(buffer, -1, 0, -1, { details = true })
  return vim.tbl_map(function(mark)
    return { mark[2], mark[3], mark[4].end_col, mark[4].hl_group, mark[4].url }
  end, marks)
end)()]]

T['the colours'] = MiniTest.new_set()

T['the colours']['a separator is coloured once after the user edits the Report anew'] = function()
  start_editor({ '2026-10-19T09:05:00', '2026-10-20T10:00:00' })
  receive('A')
  receive('B')
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])

  child.cmd('edit')

  local on_separators = vim.tbl_filter(function(colour)
    return colour[4] == 'AineoReportDay'
  end, child.lua_get(COLOURS_OF_REPORT))
  eq(on_separators, {
    { 0, 0, #'── Yesterday ──', 'AineoReportDay' },
    { 2, 0, #'── Today ──', 'AineoReportDay' },
  })
end

T['the colours']['AineoReportDay links to Comment unless a scheme says otherwise'] = function()
  start_editor({ '2026-10-20T09:05:00' })
  receive('A')

  eq(child.lua_get([[vim.api.nvim_get_hl(0, { name = 'AineoReportDay' }).link]]), 'Comment')
end

T['the colours']['a separator is in AineoReportDay alone, with no address'] = function()
  start_editor({ '2026-10-20T09:05:00' })
  receive('A')

  local on_separator = vim.tbl_filter(function(colour)
    return colour[1] == 0
  end, child.lua_get(COLOURS_OF_REPORT))

  eq(on_separator, { { 0, 0, #'── Today ──', 'AineoReportDay' } })
end

T['the double-click'] = MiniTest.new_set()

T['the double-click']['on a separator opens nothing and selects its word'] = function()
  start_editor({ '2026-10-20T09:05:00' })
  receive('A')
  child.lua([[vim.api.nvim_set_current_buf(require('aineo.report').report_buffer())]])
  local cell = child.lua_get([[(function()
    local position = vim.fn.screenpos(0, 1, 5)
    return { row = position.row - 1, col = position.col - 1 }
  end)()]])

  for _ = 1, 2 do
    child.api.nvim_input_mouse('left', 'press', '', 0, cell.row, cell.col)
    child.api.nvim_input_mouse('left', 'release', '', 0, cell.row, cell.col)
  end

  eq(child.lua_get([[{ vim.api.nvim_buf_get_name(0), vim.v.errmsg, vim.fn.mode() }]]), {
    'aineo://report',
    '',
    'v',
  })
end

--- Restarts the child with a report home whose clock tells what the child's
--- `_G.now` holds, `now`, and whose timers are a list, `_G.timers`, that the
--- test fires itself: each as `{ delay_ms, callback, cancelled }`, the last
--- the one that waits.
---
---@param now string
local function start_with_timers_it_fires(now)
  children.restart(child)
  child.lua(
    [[
      local state_directory
      state_directory, _G.now = ...
      _G.timers = {}
      require('aineo.report').set_report_environment({
        clock = function()
          return _G.now
        end,
        state_directory = state_directory,
        working_directory = '/projects/alpha',
        schedule_after = function(delay_ms, callback)
          local timer = { delay_ms = delay_ms, callback = callback, cancelled = false }
          table.insert(_G.timers, timer)
          return function()
            timer.cancelled = true
          end
        end,
      })
    ]],
    { fixture.directory('report-days-timers-state'), now }
  )
end

T['midnight'] = MiniTest.new_set()

T['midnight']['redraws the separators of a Report left open, and waits for the next'] = function()
  start_with_timers_it_fires('2026-10-19T23:59:30')
  receive('A')
  eq(child.lua_get([[_G.timers[#_G.timers].delay_ms]]), 30000)

  child.lua([[_G.now = '2026-10-20T00:00:00']])
  child.lua([[_G.timers[#_G.timers].callback()]])

  eq(report_editor.lines_with_days(child), { '── Yesterday ──', '23:59 [done] A — S' })
  eq(child.lua_get([[_G.timers[#_G.timers].delay_ms]]), 86400000)
end

T['midnight']['is no longer waited for once the Report is wiped'] = function()
  start_with_timers_it_fires('2026-10-19T23:59:30')
  receive('A')

  child.lua([[vim.api.nvim_buf_delete(require('aineo.report').report_buffer(), { force = true })]])

  eq(child.lua_get([[_G.timers[#_G.timers].cancelled]]), true)
end

--- How many timers of the child's loop are open and not closing.
---
---@return integer
local function timers_open()
  return child.lua_get([[(function()
    local count = 0
    vim.uv.walk(function(handle)
      if handle:get_type() == 'timer' and not handle:is_closing() then
        count = count + 1
      end
    end)
    return count
  end)()]])
end

T['midnight']['leaves no timer of the editor once the Report is wiped'] = function()
  start_editor({ '2026-10-20T09:05:00' })
  local timers_before = timers_open()
  receive('A')
  eq(timers_open(), timers_before + 1)

  child.lua([[vim.api.nvim_buf_delete(require('aineo.report').report_buffer(), { force = true })]])

  eq(timers_open(), timers_before)
end

return T
