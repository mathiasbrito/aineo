--- A pause that starts over each time it is asked for.

local M = {}

--- A pause of `milliseconds`: each `restart()` starts it over, and `act` runs
--- on the main loop once a full pause has passed with no `restart()` in it.
--- The timer behind it is made at the first `restart()`, and is not running
--- between a pause's end and the next `restart()`.
---
---@param milliseconds integer
---@param act fun()
---@return { restart: fun() } pause
function M.restartable(milliseconds, act)
  local timer
  local function restart()
    timer = timer or vim.uv.new_timer()
    timer:stop()
    timer:start(milliseconds, 0, vim.schedule_wrap(act))
  end
  return { restart = restart }
end

return M
