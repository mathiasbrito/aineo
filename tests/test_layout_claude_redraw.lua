local MiniTest = require('mini.test')
local pty = dofile('tests/helpers/pty_recorder.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

local CTRL_L = '0c'

--- The explorer column closing: Claude's window grows.
local CLOSE_EXPLORER = [[require('aineo.layout').set_explorer_column(false, 20)]]

--- The explorer column opening again: Claude's window shrinks.
local RESTORE_EXPLORER = [[require('aineo.layout').set_explorer_column('right', 20)]]

--- How long after a change of Claude's window the layout is giving its
--- terminal the size, between the narrower size and the final one, in
--- milliseconds.
local MID_GAP_MS = 250

--- Three changes of Claude's window's size in a row, within the time the
--- layout waits for the windows to settle.
local RESIZE_THREE_TIMES = [[
  local layout = require('aineo.layout')
  layout.set_explorer_column(false, 20)
  layout.set_explorer_column('right', 20)
  layout.set_explorer_column(false, 20)
]]

--- Puts Report's window in focus and zooms it over the whole screen.
local ZOOM_FULLY = [[vim.api.nvim_set_current_win(vim.fn.bufwinid('aineo://report'))
  require('aineo.layout').toggle_full_zoom()]]

--- The bytes among `events`.
---
---@param events table[]
---@return string[]
local function keys_among(events)
  local keys = {}
  for _, event in ipairs(events) do
    if event.key then
      table.insert(keys, event.key)
    end
  end
  return keys
end

T['the terminal of Claude Code'] = MiniTest.new_set()

T['the terminal of Claude Code']['reads one Ctrl+L, after its final size, once Claude’s window changed size'] = function()
  local record = pty.open_around_key_recorder(child, 'redraw-once')

  local recorded = pty.events_during(child, record, CLOSE_EXPLORER)

  local events = recorded.events
  eq(keys_among(events), { CTRL_L })
  eq(events[#events].key, CTRL_L)
  eq(events[#events - 1].size, recorded.final)
end

T['the terminal of Claude Code']['reads one Ctrl+L for several changes in one run'] = function()
  local record = pty.open_around_key_recorder(child, 'redraw-run')

  local recorded = pty.events_during(child, record, RESIZE_THREE_TIMES)

  eq(keys_among(recorded.events), { CTRL_L })
  eq(recorded.events[#recorded.events].key, CTRL_L)
end

T['the terminal of Claude Code']['reads one Ctrl+L when the window changes size again while it is being given its size'] = function()
  local record = pty.open_around_key_recorder(child, 'redraw-overlap')

  child.lua(CLOSE_EXPLORER)
  vim.wait(MID_GAP_MS)
  local recorded = pty.events_during(child, record, RESTORE_EXPLORER)

  eq(keys_among(recorded.events), { CTRL_L })
  eq(recorded.events[#recorded.events].key, CTRL_L)
end

T['the terminal of Claude Code']['reads no Ctrl+L when claude_redraw_on_resize is off, and still its fresh size'] = function()
  local record =
    pty.open_around_key_recorder(child, 'redraw-off', { claude_redraw_on_resize = false })

  local recorded = pty.events_during(child, record, CLOSE_EXPLORER)

  local events = recorded.events
  eq(keys_among(events), {})
  eq(#events >= 2, true)
  eq(events[#events].size, recorded.final)
  eq(events[#events - 1].size ~= recorded.final, true)
end

T['the terminal of Claude Code']['reads no Ctrl+L while Claude Code is not ready for input'] = function()
  local record = pty.open_around_key_recorder(child, 'redraw-not-ready')
  child.g.test_claude_is_ready = false

  local recorded = pty.events_during(child, record, CLOSE_EXPLORER)

  eq(keys_among(recorded.events), {})
end

T['the terminal of Claude Code']['reads no Ctrl+L when the layout is handed no word on Claude Code’s readiness'] = function()
  local record = pty.open_around_key_recorder(child, 'redraw-no-predicate', nil, true)

  local recorded = pty.events_during(child, record, CLOSE_EXPLORER)

  eq(keys_among(recorded.events), {})
end

T['the terminal of Claude Code']['reads one Ctrl+L after a resize once Claude Code is ready'] = function()
  local record = pty.open_around_key_recorder(child, 'redraw-became-ready')
  child.g.test_claude_is_ready = false
  pty.events_during(child, record, CLOSE_EXPLORER)
  child.g.test_claude_is_ready = true

  local recorded = pty.events_during(child, record, RESTORE_EXPLORER)

  eq(keys_among(recorded.events), { CTRL_L })
end

T['the terminal of Claude Code']['reads no Ctrl+L while a window is zoomed fully'] = function()
  local record = pty.open_around_key_recorder(child, 'redraw-zoomed')

  local recorded = pty.events_during(child, record, ZOOM_FULLY)

  eq(keys_among(recorded.events), {})
end

return T
