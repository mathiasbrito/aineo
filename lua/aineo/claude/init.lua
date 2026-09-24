--- aineo's Claude session home, `require('aineo.claude')`: Claude Code's
--- interactive CLI running in a terminal buffer.

local arguments = require('aineo.claude.arguments')

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

--- Starts Claude Code in a new terminal buffer and returns that buffer.
---
---@param settings aineo.claude.Settings
---@return integer buffer the terminal buffer Claude Code runs in
function M.start_session(settings)
  local command =
    vim.list_extend(vim.list_slice(settings.cmd), arguments.claude_arguments(settings))
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_call(buffer, function()
    vim.fn.jobstart(command, { term = true, cwd = settings.cwd, env = CHILD_ENVIRONMENT })
  end)
  return buffer
end

return M
