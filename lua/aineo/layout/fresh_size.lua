--- A fresh resize for a terminal's pty at its window's final size. Neovim
--- gives a terminal's pty the size of its window as it draws the screen, and
--- Claude Code lays its screen out for the size it was last told: a window
--- that took other sizes on the way to its last one (a zoom, a column closing,
--- the editor resized) can leave Claude Code laid out for one of them. Telling
--- it the final size again, once the windows have settled, lays it out for
--- that.

local M = {}

--- How long after a window of the layout changed size the pty is told its
--- size again, in milliseconds: the changes of one command, and the redraws
--- they cause, are done by then.
M.SETTLE_DELAY_MS = 100

--- How long the pty keeps the size one column narrower, in milliseconds, so
--- that the process in it sees two sizes and not one: a busy process serves a
--- signal between its tasks, and sees only the last of the sizes told in that
--- time.
M.GAP_MS = 300

--- How long after the pty is told its final size `after` runs, in
--- milliseconds: the process has served the resize by then, and a redraw it is
--- asked for lays out the whole screen for the size it has.
M.AFTER_DELAY_MS = 200

--- Tells the pty of the terminal job `job` the size `size_of_window()` gives
--- now, one column narrower, and, `M.GAP_MS` later, the size it gives then:
--- the process sees a resize to the window's final size. Then, `M.AFTER_DELAY_MS`
--- later, runs `after`. Does nothing while the window gives fewer than two
--- columns, as in a full zoom, or none: `after` does not run either.
---
---@param job integer
---@param size_of_window fun(): integer|nil, integer|nil the width and height the window gives the terminal now, nil when it has no window
---@param after? fun() runs once the process has served the final size
function M.give(job, size_of_window, after)
  local width, height = size_of_window()
  if not width or width < 2 then
    return
  end
  if not pcall(vim.fn.jobresize, job, width - 1, height) then
    return
  end
  vim.defer_fn(function()
    local final_width, final_height = size_of_window()
    pcall(vim.fn.jobresize, job, final_width or width, final_height or height)
    if after then
      vim.defer_fn(after, M.AFTER_DELAY_MS)
    end
  end, M.GAP_MS)
end

return M
