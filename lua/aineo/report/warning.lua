--- The warning the report home gives the user when a report arrives.

local M = {}

--- Warns the user with `message` once the editor is done with what it is
--- doing: a report arrives over RPC, and a warning too long for the command
--- line waits at a hit-enter prompt, which would hold that request (and the
--- relay waiting on it) until the user answered.
---
---@param message string
function M.warn_later(message)
  vim.schedule(function()
    vim.notify(message, vim.log.levels.WARN)
  end)
end

return M
