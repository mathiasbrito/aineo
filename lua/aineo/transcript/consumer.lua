--- The consumer of `aineo.transcript`'s signals, protected: whoever takes the
--- signals in cannot break the follower by failing. Pure but for the one
--- notification it gives.

local M = {}

--- What the user is told, once, when the function that takes signals in raised;
--- `%s` is the kind of the signal it raised on.
local FAILED = "aineo: the office could not take in a '%s' signal of the transcript"

--- `on_signal` made safe to call from the follower's own loop: a raise in it is
--- caught, so that the lines read go on, none is read twice, and nothing the
--- follower holds is left open. The first raise is told to the user, naming the
--- kind of the signal and nothing of the line, the error or the transcript.
---
---@param on_signal fun(signal: aineo.transcript.Signal)
---@return fun(signal: aineo.transcript.Signal)
function M.protect(on_signal)
  local told = false
  return function(signal)
    local taken = pcall(on_signal, signal)
    if not taken and not told then
      told = true
      vim.notify(FAILED:format(signal.kind), vim.log.levels.WARN)
    end
  end
end

return M
