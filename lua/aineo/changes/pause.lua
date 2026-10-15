--- A pause that starts over each time it is asked for.

local M = {}

--- A pause of `milliseconds`: each `restart()` starts it over, and `act` runs
--- on the main loop once a full pause has passed with no `restart()` in it.
--- The timer behind it is made at the first `restart()`, and is not running
--- between a pause's end and the next `restart()`.
---
--- `close()` stops the pause and closes its timer, if one was made; a pause
--- closed starts no more, and `act` does not run after it.
---
---@param milliseconds integer
---@param act fun()
---@return { restart: fun(), close: fun() } pause
function M.restartable(milliseconds, act)
  local timer
  local is_closed = false
  local function restart()
    if is_closed then
      return
    end
    timer = timer or vim.uv.new_timer()
    timer:stop()
    timer:start(
      milliseconds,
      0,
      vim.schedule_wrap(function()
        if not is_closed then
          act()
        end
      end)
    )
  end
  local function close()
    is_closed = true
    if timer and not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end
  return { restart = restart, close = close }
end

return M
