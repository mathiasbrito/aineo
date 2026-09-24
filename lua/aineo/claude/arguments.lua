--- The arguments aineo gives Claude Code after its command.

local M = {}

--- `server` as `--mcp-config` needs it written: its `env` an object even when
--- it has no variable, where an empty Lua table would encode as a JSON array.
---
---@param server table an MCP server entry, `{ type, command, args, env }`
---@return table
local function encodable_server(server)
  if not vim.tbl_isempty(server.env) then
    return server
  end
  return vim.tbl_extend('force', server, { env = vim.empty_dict() })
end

--- The arguments that hand Claude Code the MCP servers of `settings` as one
--- JSON text, the instructions appended to its system prompt as they are, and
--- the tools it may use without asking, each one word after `--allowedTools`.
--- That flag comes last because it takes every word that follows it up to the
--- next flag.
---
---@param settings aineo.claude.Settings
---@return string[]
function M.claude_arguments(settings)
  local servers = vim.tbl_map(encodable_server, settings.mcp_servers)
  local words = {
    '--mcp-config',
    vim.json.encode({ mcpServers = servers }),
    '--append-system-prompt',
    settings.instructions,
    '--allowedTools',
  }
  return vim.list_extend(words, settings.allowed_tools)
end

return M
