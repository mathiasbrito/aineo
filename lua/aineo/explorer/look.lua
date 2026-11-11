--- Which looks of the explorer are on: the guides, the icons, the dimming of
--- unchanged files, the counts, the compact chains and the diagnostics of its
--- tree are on unless the settings say otherwise; the line numbers of the
--- windows that show it are off unless they do.

local M = {}

--- The looks that can be turned off.
---@class aineo.explorer.Look
---@field guides boolean
---@field icons boolean
---@field dim boolean
---@field counts boolean
---@field compact boolean
---@field diagnostics boolean
---@field numbers boolean whether a window showing the explorer keeps the user's own line numbers

--- The looks the settings leave alone: those of the tree on, the line numbers
--- off.
---@type aineo.explorer.Look
M.DEFAULT = {
  guides = true,
  icons = true,
  dim = true,
  counts = true,
  compact = true,
  diagnostics = true,
  numbers = false,
}

--- The looks `given` says, each one it does not say as `M.DEFAULT` has it.
---
---@param given table<string, boolean>|nil
---@return aineo.explorer.Look
function M.resolve(given)
  return vim.tbl_extend('force', M.DEFAULT, given or {})
end

--- Makes the function that reads the looks as they are set: it calls `ask()`
--- under `pcall()`, which answers the looks given by name and, after them, the
--- problems of the values that were wrong; a failure of `ask()` is a problem
--- too, and every look is then on. Each problem is passed to `tell` once, for
--- as long as it lasts: a problem that was gone and comes back is told again.
---
---@param ask fun(): table<string, boolean>|nil, string[]|nil
---@param tell fun(problem: string)
---@return fun(): aineo.explorer.Look
function M.reader(ask, tell)
  local told = {}
  return function()
    local answered, given, problems = pcall(ask)
    if not answered then
      given, problems = nil, { tostring(given) }
    end
    local still = {}
    for _, problem in ipairs(problems or {}) do
      still[problem] = true
      if not told[problem] then
        tell(problem)
      end
    end
    told = still
    return M.resolve(given)
  end
end

return M
