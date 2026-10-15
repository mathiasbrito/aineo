--- The one clock of the busy indicator in the tab line: a timer for the
--- whole editor that flips between two glyphs while it runs, and a call to
--- the tab line's redraw at each flip. It runs only between `run()` and
--- `stop()`, so an editor with no busy tab has no timer.

local M = {}

--- The glyphs of the two frames, ◒ and ◓, in turn.
local FRAMES = { '◒', '◓' }

--- The time between two frames: twice a second, a rate at which a redraw of
--- the tab line costs the editor next to nothing.
local FRAME_MS = 500

--- The timer, while the clock runs.
---
---@type uv.uv_timer_t|nil
local timer = nil

--- The place of the frame shown now in `FRAMES`.
local frame = 1

--- The glyph of the frame shown now.
---
---@return string
function M.glyph()
  return FRAMES[frame]
end

--- Whether the clock runs.
---
---@return boolean
function M.is_running()
  return timer ~= nil
end

--- Stops the clock and closes its timer. Stopped, nothing happens.
function M.stop()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end

--- Starts the clock at the first frame, unless it runs: every
--- 500 ms the frame changes and `on_frame()` is called, on the main loop.
--- Run again, it changes nothing, `on_frame` as it was.
---
---@param on_frame fun()
function M.run(on_frame)
  vim.validate('on_frame', on_frame, 'function')
  if timer then
    return
  end
  frame = 1
  timer = assert(vim.uv.new_timer())
  timer:start(
    FRAME_MS,
    FRAME_MS,
    vim.schedule_wrap(function()
      if not timer then
        return
      end
      frame = frame % #FRAMES + 1
      on_frame()
    end)
  )
end

return M
