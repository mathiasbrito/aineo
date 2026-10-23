local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality
local expect = MiniTest.expect

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The working directory the cases' editors are in: any path names one, and
--- nothing is written there.
local WORKING_DIRECTORY = '/projects/alpha'

--- A report, as the report tool's arguments.
local REPORT = { task = 'Task', status = 'done', summary = 'All tests pass' }

--- Restarts the child with a report home of its own, held as `_G.home`,
--- whose environment has the callback `on_report_received_source` (the
--- source of a function) when it is given. What the callback is given is
--- kept in `_G.received`.
---
---@param on_report_received_source? string
local function start_home(on_report_received_source)
  children.restart(child)
  child.lua(
    [[
      local state, working_directory, source = ...
      _G.received = {}
      _G.home = require('aineo.report').new()
      _G.home.set_report_environment({
        clock = function()
          return '2026-10-07T10:00:00'
        end,
        state_directory = state,
        working_directory = working_directory,
        on_report_received = source ~= vim.NIL and loadstring('return ' .. source)() or nil,
      })
    ]],
    {
      fixture.directory('report-taken-state'),
      WORKING_DIRECTORY,
      on_report_received_source or vim.NIL,
    }
  )
end

--- The callback that keeps its argument in `_G.received`.
local KEEPING_CALLBACK = [[function(report) table.insert(_G.received, report) end]]

T['a report home with a callback for the reports it takes'] = MiniTest.new_set()

T['a report home with a callback for the reports it takes']['gives it each report it shows'] = function()
  start_home(KEEPING_CALLBACK)

  child.lua([[_G.home.receive_report(...)]], { REPORT })
  child.lua(
    [[_G.home.receive_report(...)]],
    { vim.tbl_extend('force', REPORT, { status = 'failed' }) }
  )

  eq(child.lua_get('_G.received'), {
    REPORT,
    vim.tbl_extend('force', REPORT, { status = 'failed' }),
  })
end

T['a report home with a callback for the reports it takes']['gives it a report of the session it follows, offered by the editor'] = function()
  start_home(KEEPING_CALLBACK)
  child.lua([[_G.home.follow_report_session('session-a')]])

  local taken = child.lua_get([[_G.home.receive_session_report(..., 'session-a')]], { REPORT })

  eq(taken, true)
  eq(child.lua_get('_G.received'), { REPORT })
end

T['a report home with a callback for the reports it takes']['gives it nothing for a report it does not take'] = function()
  start_home(KEEPING_CALLBACK)
  child.lua([[_G.home.follow_report_session('session-a')]])

  local taken = child.lua_get([[_G.home.receive_session_report(..., 'session-b')]], { REPORT })

  eq(taken, false)
  eq(child.lua_get('_G.received'), {})
end

T['a report home with a callback for the reports it takes']['shows the report though the callback fails, and tells the user of each failure'] = function()
  start_home([[function() error('the callback failed') end]])
  child.lua([[
    _G.told = {}
    vim.notify = function(message) table.insert(_G.told, message) end
  ]])

  expect.no_error(function()
    child.lua([[_G.home.receive_report(...)]], { REPORT })
    child.lua([[_G.home.receive_report(...)]], { REPORT })
  end)
  child.lua([[vim.wait(100)]])

  eq(child.lua_get([[#vim.api.nvim_buf_get_lines(_G.home.report_buffer(), 0, -1, false)]]), 3)
  eq(#child.lua_get('_G.told'), 2)
  eq(child.lua_get('_G.told')[1]:find('the callback failed', 1, true) ~= nil, true)
end

T['a report home with a callback for the reports it takes']['needs the callback to be a function'] = function()
  start_home()

  expect.error(function()
    child.lua(
      [[_G.home.set_report_environment({
        clock = function() return '2026-10-07T10:00:00' end,
        state_directory = ...,
        working_directory = select(2, ...),
        on_report_received = 'not a function',
      })]],
      { fixture.directory('report-taken-state'), WORKING_DIRECTORY }
    )
  end, 'on_report_received')
end

T['a report home without a callback'] = MiniTest.new_set()

T['a report home without a callback']['takes reports as before'] = function()
  start_home()

  child.lua([[_G.home.receive_report(...)]], { REPORT })

  eq(child.lua_get([[#vim.api.nvim_buf_get_lines(_G.home.report_buffer(), 0, -1, false)]]), 2)
end

return T
