--- Which looks of the explorer's tree are on: the guides, the icons, the
--- dimming of unchanged files, the counts, the compact chains and the
--- diagnostics. All are on unless the settings say otherwise.

local M = {}

--- The looks that can be turned off.
---@class aineo.explorer.Look
---@field guides boolean
---@field icons boolean
---@field dim boolean
---@field counts boolean
---@field compact boolean
---@field diagnostics boolean

--- The looks with every one on.
---@type aineo.explorer.Look
M.ALL_ON = {
  guides = true,
  icons = true,
  dim = true,
  counts = true,
  compact = true,
  diagnostics = true,
}

--- The looks `given` says, each one it does not say on.
---
---@param given table<string, boolean>|nil
---@return aineo.explorer.Look
function M.resolve(given)
  return vim.tbl_extend('force', M.ALL_ON, given or {})
end

return M
