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

--- Claude Code's configuration directory: `$CLAUDE_CONFIG_DIR`, else
--- `.claude` in the user's home.
---
---@return string
function M.claude_config_directory()
  local configured = vim.env.CLAUDE_CONFIG_DIR
  if configured and configured ~= '' then
    return configured
  end
  return vim.fs.joinpath(vim.uv.os_homedir(), '.claude')
end

--- The file Claude Code writes the transcript of `session_id` in when the
--- session belongs to the folder this Neovim started in (`kept_places()`):
--- `projects/<folder>/<session id>.jsonl` under its configuration directory
--- (`M.claude_config_directory()`), `<folder>` that folder's path with every
--- character but a letter or a digit made a dash.
---
---@param session_id string
---@return string path
function M.folder_transcript(session_id)
  local folder = vim.fn.substitute(kept_places().working_directory, '[^a-zA-Z0-9]', '-', 'g')
  return vim.fs.joinpath(M.claude_config_directory(), 'projects', folder, session_id .. '.jsonl')
end

--- Whether a Claude Code runs the session `session`, wherever it runs: a
--- process aineo started, by its record under the state directory of
--- `kept_places()` (`aineo.mcp`'s `is_session_running()`), or any process
--- Claude Code's own registry names in its configuration directory
--- (`aineo.claude`'s `is_session_registered()`, `M.claude_config_directory()`).
---
---@param session string
---@return boolean
function M.is_session_running(session)
  return require('aineo.mcp').is_session_running(kept_places().state_directory, session)
    or require('aineo.claude').is_session_registered(M.claude_config_directory(), session)
end

M.kept_places = kept_places

return M
