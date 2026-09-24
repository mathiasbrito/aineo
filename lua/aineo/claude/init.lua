--- aineo's Claude session home, `require('aineo.claude')`: Claude Code's
--- interactive CLI running in a terminal buffer.

local arguments = require('aineo.claude.arguments')
local readiness = require('aineo.claude.readiness')

local M = {}

--- What the session runs Claude Code with. The composition root assembles it
--- from the configuration and from the homes that own each value.
---@class aineo.claude.Settings
---@field cmd string[] the command that runs Claude Code, as `claude.cmd`
---@field cwd string the directory Claude Code runs in: the editor's working directory
---@field mcp_servers table<string, table> the MCP servers Claude Code starts, by name, each in its `--mcp-config` server format
---@field allowed_tools string[] the tools Claude Code may call without asking the user
---@field instructions string the text appended to Claude Code's system prompt

--- The variables Claude Code's process gets on top of the editor's own, which
--- it inherits unchanged: `AINEO_CHILD` tells aineo, should Claude Code start a
--- Neovim, that it runs inside aineo's own session.
local CHILD_ENVIRONMENT = { AINEO_CHILD = '1' }

--- The one Claude Code session, once one has started: its terminal buffer,
--- whether Claude Code has become ready and, once its process has ended, the
--- process's exit code.
---@type { buffer: integer, ready: boolean?, exit_code: integer? }?
local session

--- Puts `replacement` in every window that shows `buffer`, then wipes
--- `buffer` — in that order, since wiping a buffer closes the windows that
--- still show it. Does nothing to a `buffer` already wiped.
---
---@param buffer integer the terminal of a Claude Code that has exited
---@param replacement integer
local function replace_terminal(buffer, replacement)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return
  end
  for _, window in ipairs(vim.fn.win_findbuf(buffer)) do
    vim.api.nvim_win_set_buf(window, replacement)
  end
  vim.api.nvim_buf_delete(buffer, { force = true })
end

--- Starts Claude Code in a new terminal buffer and returns that buffer. While
--- a session runs it starts nothing and returns that session's buffer: one
--- Claude Code at a time. Once it has exited, it starts a new one, whose
--- terminal takes the old one's place in every window that showed it.
---
--- Show a new buffer in a window at once: its terminal takes its size from
--- the first window that shows it, and until then has the few rows of a
--- hidden window, where Claude Code's prompt does not fit.
---
---@param settings aineo.claude.Settings
---@return integer buffer the terminal buffer Claude Code runs in
function M.start_session(settings)
  if session and not session.exit_code then
    return session.buffer
  end
  local previous = session
  local command =
    vim.list_extend(vim.list_slice(settings.cmd), arguments.claude_arguments(settings))
  local started = { buffer = vim.api.nvim_create_buf(false, true) }
  readiness.when_ready(started.buffer, function()
    started.ready = true
  end)
  vim.api.nvim_buf_call(started.buffer, function()
    vim.fn.jobstart(command, {
      term = true,
      cwd = settings.cwd,
      env = CHILD_ENVIRONMENT,
      on_exit = function(_, exit_code)
        started.exit_code = exit_code
      end,
    })
  end)
  session = started
  if previous then
    replace_terminal(previous.buffer, started.buffer)
  end
  return started.buffer
end

--- Where the session stands: `'starting'` until Claude Code is ready for
--- input, then `'ready'`, and `'exited'` with the exit code once its process
--- has ended; nothing before a session has started.
---
---@return string? state
---@return integer? exit_code
function M.session_status()
  if not session then
    return nil
  end
  if session.exit_code then
    return 'exited', session.exit_code
  end
  if session.ready then
    return 'ready'
  end
  return 'starting'
end

return M
