--- The countdown of the office's idleness: one wait at a time, started again
--- from the start each time it is started. It is the one timer the office has
--- while it is hidden.

local M = {}

---@class aineo.office.CountdownOptions
---@field schedule_after? fun(milliseconds: integer, callback: fun()): fun() calls `callback`, on the main loop, once `milliseconds` have passed, and returns what cancels the wait, which may be called after the wait is over; a timer of the editor's loop when not given
---@field on_elapsed fun() called when the wait is over

---@class aineo.office.Countdown
---@field start fun(milliseconds: integer) waits `milliseconds`, in place of a wait that goes on
---@field stop fun() ends a wait that goes on, without calling `on_elapsed`
---@field is_running fun(): boolean whether a wait goes on

--- Waits `milliseconds` with a timer of the editor's loop, then calls
--- `callback` on the main loop. What it returns cancels the wait and closes
--- the timer, and may be called after the wait is over.
---
---@param milliseconds integer
---@param callback fun()
---@return fun() cancel
local function wait_with_timer(milliseconds, callback)
  local timer = vim.defer_fn(callback, milliseconds)
  return function()
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end
end

--- A countdown that is not running.
---
---@param options aineo.office.CountdownOptions
---@return aineo.office.Countdown
function M.new_countdown(options)
  vim.validate('options.schedule_after', options.schedule_after, 'function', true)
  vim.validate('options.on_elapsed', options.on_elapsed, 'function')
  local schedule_after = options.schedule_after or wait_with_timer

  ---@type fun()|nil
  local cancel_wait = nil

  local countdown = {}

  function countdown.stop()
    local cancel = cancel_wait
    cancel_wait = nil
    if cancel then
      cancel()
    end
  end

  function countdown.start(milliseconds)
    countdown.stop()
    local this_wait
    this_wait = schedule_after(milliseconds, function()
      if cancel_wait ~= this_wait then
        return
      end
      cancel_wait = nil
      options.on_elapsed()
    end)
    cancel_wait = this_wait
  end

  function countdown.is_running()
    return cancel_wait ~= nil
  end

  return countdown
end

return M
