--- Runs an asynchronous read one at a time.

local M = {}

--- A function that asks for `read` to run: at once when it is not running,
--- and otherwise once more after the run in progress has ended, however
--- often it is asked for meanwhile. `read` is given the function it calls
--- once it has ended.
---
---@param read fun(ended: fun())
---@return fun() ask
function M.one_at_a_time(read)
  local running, asked_again = false, false
  local function ask()
    if running then
      asked_again = true
      return
    end
    running = true
    read(function()
      running = false
      if asked_again then
        asked_again = false
        ask()
      end
    end)
  end
  return ask
end

return M
