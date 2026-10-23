local MiniTest = require('mini.test')
local office_cells = dofile('tests/helpers/office_cells.lua')
local office_child = dofile('tests/helpers/office_child.lua')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- How long an idle time lasts in the cases that wait for a real countdown.
local SHORT_IDLE_MS = 250

--- How long a wait for something that should happen may last, in milliseconds.
local PATIENCE_MS = 4000

--- The settings, as the source of a table, of an office that waits
--- `idle_ms` (the source of a number or `false`).
---
---@param idle_ms string
---@return string
local function settings_with_idle(idle_ms)
  return ("{ pack = 'default', pieces = {}, idle_ms = %s }"):format(idle_ms)
end

--- Opens the layout and makes an office of the idle time `idle_ms`, waiting
--- through the stand-in that keeps its waits; the cursor is in the layout's
--- Claude window, out of the right side.
---
---@param idle_ms string the source of a number or `false`
---@return table buffers
local function open_office_waiting(idle_ms)
  local buffers = office_child.open_layout(child)
  office_child.make_office(child, settings_with_idle(idle_ms), office_child.WAIT_THROUGH_STAND_IN)
  return buffers
end

--- Whether the office shows.
---
---@return boolean
local function shows()
  return office_cells.window(child) ~= vim.NIL
end

T['the idle countdown'] = MiniTest.new_set()

T['the idle countdown']['shows the office when the idle time has passed with the cursor out of the right side'] = function()
  open_office_waiting('180000')

  office_child.enter_the_left_window(child)
  eq(shows(), false)
  office_child.let_time_pass(child)

  eq(shows(), true)
end

T['the idle countdown']['waits the idle time the settings give'] = function()
  open_office_waiting('4321')

  office_child.enter_the_left_window(child)

  eq(office_child.wait_lengths(child), { 4321 })
end

T['the idle countdown']['starts as the office is made when the cursor is out of the right side already'] = function()
  office_child.open_layout(child)
  office_child.enter_the_left_window(child)

  office_child.make_office(child, settings_with_idle('1000'), office_child.WAIT_THROUGH_STAND_IN)

  eq(office_child.waits_pending(child), 1)
end

T['the idle countdown']['is stopped by the cursor entering the right side'] = function()
  local buffers = open_office_waiting('1000')
  office_child.enter_the_left_window(child)

  layout.enter_window_showing(child, buffers.report)

  eq(office_child.waits_pending(child), 0)
end

T['the idle countdown']['is not started again by a move between windows out of the right side'] = function()
  open_office_waiting('1000')
  office_child.enter_the_left_window(child)
  child.cmd('vsplit')

  child.cmd('wincmd w')
  child.cmd('wincmd w')

  eq(#office_child.wait_lengths(child), 1)
end

T['the idle countdown']['starts again when the cursor leaves the right side'] = function()
  local buffers = open_office_waiting('1000')
  office_child.enter_the_left_window(child)
  layout.enter_window_showing(child, buffers.report)

  office_child.enter_the_left_window(child)

  eq(office_child.waits_pending(child), 1)
  eq(#office_child.wait_lengths(child), 2)
end

T['the idle countdown']['does not show the office when the cursor entered the right side before it ran out'] = function()
  local buffers = open_office_waiting('1000')
  office_child.enter_the_left_window(child)
  layout.enter_window_showing(child, buffers.report)

  office_child.let_time_pass(child)

  eq(shows(), false)
end

T['the idle countdown']['starts again from the start when a report comes in'] = function()
  open_office_waiting('1000')
  office_child.enter_the_left_window(child)

  child.lua([[_G.office.report_arrived({ status = 'done', summary = 'tagged' })]])

  eq(office_child.waits_pending(child), 1)
  eq(office_child.wait_lengths(child), { 1000, 1000 })
end

T['the idle countdown']['is not run for a report that comes in while the cursor is in the right side'] = function()
  local buffers = open_office_waiting('1000')
  layout.enter_window_showing(child, buffers.report)

  child.lua([[_G.office.report_arrived({ status = 'done', summary = 'tagged' })]])

  eq(office_child.waits_pending(child), 0)
end

T['the idle countdown']['is off when office.idle_ms is false'] = function()
  open_office_waiting('false')

  office_child.enter_the_left_window(child)

  eq(#office_child.wait_lengths(child), 0)
  eq(shows(), false)
end

T['the idle countdown']['shows the office once a real countdown has run out'] = function()
  office_child.open_layout(child)
  office_child.enter_the_left_window(child)

  office_child.make_office(child, settings_with_idle(tostring(SHORT_IDLE_MS)))

  eq(
    vim.wait(PATIENCE_MS, function()
      return shows()
    end, 20),
    true
  )
end

T['the idle countdown']['is the one timer a hidden office holds, with no frame timer and no watch'] = function()
  office_child.open_layout(child)
  office_child.enter_the_left_window(child)
  local timers = office_cells.open_handles(child, 'timer')
  local repeating = office_cells.open_repeating_timers(child)
  local watches = office_cells.open_handles(child, 'fs_event')

  office_child.make_office(child, settings_with_idle('180000'))
  office_child.follow_transcript(child, '/nonexistent/session.jsonl')

  eq(office_cells.open_handles(child, 'timer'), timers + 1)
  eq(office_cells.open_repeating_timers(child), repeating)
  eq(office_cells.open_handles(child, 'fs_event'), watches)
end

T['the idle countdown']['leaves no timer behind when the office is let go'] = function()
  office_child.open_layout(child)
  office_child.enter_the_left_window(child)
  local timers = office_cells.open_handles(child, 'timer')
  office_child.make_office(child, settings_with_idle('180000'))

  child.lua([[_G.office.let_go()]])

  eq(office_cells.open_handles(child, 'timer'), timers)
end

T['the idle countdown']['stops showing by itself once the office is let go'] = function()
  open_office_waiting('1000')
  office_child.enter_the_left_window(child)

  child.lua([[_G.office.let_go()]])

  eq(office_child.waits_pending(child), 0)
end

--- The source of the options that wait through the stand-in and give the
--- office the right side `_G.right_side` holds in the child: the layout's, or
--- none.
local WAIT_AND_RIGHT_SIDE_IN_GLOBAL = [[{
  schedule_after = function(milliseconds, callback)
    local wait = { milliseconds = milliseconds, callback = callback, over = false }
    table.insert(_G.waits, wait)
    return function()
      wait.over = true
    end
  end,
  right_side = function()
    return _G.right_side
  end,
}]]

--- Opens the layout and makes an office whose right side is what `_G.right_side`
--- holds, the layout's own area first.
---
---@return table buffers
local function open_office_with_a_right_side_that_comes_and_goes()
  local buffers = office_child.open_layout(child)
  child.lua([[_G.right_side = require('aineo.layout').right_column_area()]])
  office_child.make_office(child, settings_with_idle('1000'), WAIT_AND_RIGHT_SIDE_IN_GLOBAL)
  return buffers
end

T['without a right side'] = MiniTest.new_set()

T['without a right side']['the office does not show when the idle time passes, and says nothing'] = function()
  open_office_with_a_right_side_that_comes_and_goes()
  office_child.enter_the_left_window(child)
  child.lua([[_G.right_side = nil]])

  office_child.let_time_pass(child)

  eq(shows(), false)
  eq(child.lua_get([[_G.told]]), {})
end

T['without a right side']['the office shows once the right side comes back after the idle time passed'] = function()
  open_office_with_a_right_side_that_comes_and_goes()
  office_child.enter_the_left_window(child)
  child.lua([[_G.right_side = nil]])
  office_child.let_time_pass(child)

  child.lua([[_G.right_side = require('aineo.layout').right_column_area()]])
  child.cmd('doautocmd VimResized')

  eq(shows(), true)
end

T['without a right side']['the office does not show when the right side comes back before the idle time passed'] = function()
  open_office_with_a_right_side_that_comes_and_goes()
  office_child.enter_the_left_window(child)
  child.lua([[_G.right_side = nil]])
  child.cmd('doautocmd VimResized')

  child.lua([[_G.right_side = require('aineo.layout').right_column_area()]])
  child.cmd('doautocmd VimResized')

  eq(shows(), false)
  eq(office_child.waits_pending(child), 1)
end

T['without a right side']['the office counts again from the start when the cursor returns from another tab page'] = function()
  open_office_with_a_right_side_that_comes_and_goes()
  office_child.enter_the_left_window(child)
  child.lua([[_G.right_side = nil]])
  office_child.let_time_pass(child)
  child.cmd('tabnew')
  child.cmd('tabprevious')
  child.lua([[_G.right_side = require('aineo.layout').right_column_area()]])
  child.cmd('doautocmd VimResized')

  eq(shows(), false)
  eq(office_child.waits_pending(child), 1)
end

return T
