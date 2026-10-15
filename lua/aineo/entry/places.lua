--- Where aineo keeps what it keeps for the folder the editor started in,
--- and the sessions that run there.

local M = {}

--- Where aineo keeps what it keeps — the Reports, Input's draft, the
--- changes pane's kept bases and the session id Claude Code resumes — once
--- `kept_places()` has taken it.
---@type { state_directory: string, working_directory: string }|nil
local places = nil

--- The editor's state directory and working directory, as they are the
--- first time this is called: the Reports and Input's draft are kept under
--- that state directory — for that working directory until the panes follow
--- a Claude session (`follow_session()`), then per session — whatever `:cd`
--- does later.
---
---@return { state_directory: string, working_directory: string }
local function kept_places()
  places = places
    or { state_directory = vim.fn.stdpath('state'), working_directory = vim.fn.getcwd() }
  return places
end

--- The sessions that have a running Claude Code in the directory this
--- Neovim started in (`kept_places()`), which `:Aineo claim` offers.
---
---@return string[]
function M.running_sessions_here()
  return require('aineo.mcp').running_sessions(
    kept_places().state_directory,
    kept_places().working_directory
  )
end

M.kept_places = kept_places

return M
