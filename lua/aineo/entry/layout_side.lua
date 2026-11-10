--- The side of the screen Claude Code's column is on, for the editor's life:
--- the one the user chose with `:Aineo layout`, else the one the setting
--- `layout.claude_side` names. Every tab's layout is handed it with each
--- arrangement, so a tab opened later, a restore and a reopened window all
--- land on it.

local settings = require('aineo.entry.settings')

local M = {}

--- The side the user chose, nil until they choose one.
---@type aineo.layout.Side?
local chosen = nil

--- The side Claude Code's column is on now.
---
---@param config? table the resolved configuration; read from the settings when not given
---@return aineo.layout.Side
function M.current(config)
  return chosen or (config or settings.resolved()).layout.claude_side
end

--- Records `side` as the one the user chose, which lasts for the editor's
--- life and wins over the setting.
---
---@param side aineo.layout.Side
function M.choose(side)
  chosen = side
end

return M
