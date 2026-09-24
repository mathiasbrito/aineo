--- The arguments aineo gives Claude Code after its command.

local M = {}

--- `server` as `--mcp-config` needs it written: its `env` an object even when
--- it has no variable or none is given, where an empty Lua table would encode
--- as a JSON array.
---
---@param server table an MCP server entry, `{ type, command, args, env? }`
---@return table
local function encodable_server(server)
  if server.env ~= nil and not vim.tbl_isempty(server.env) then
    return server
  end
  return vim.tbl_extend('force', server, { env = vim.empty_dict() })
end

--- The arguments that hand Claude Code the MCP servers of `settings` as one
--- JSON object — `{}` when there are none — the instructions appended to its
--- system prompt as they are, and the tools it may use without asking, each
--- one word after `--allowedTools`. Claude Code's CLI reference gives that
--- flag several words (its example names three tools), as it gives
--- `--mcp-config` several space-separated values, so that flag comes last,
--- where no word of aineo's own follows it, and `--mcp-config` is followed by
--- a flag.
---
---@param settings aineo.claude.Settings
---@return string[]
function M.claude_arguments(settings)
  local servers = vim.empty_dict()
  for name, server in pairs(settings.mcp_servers) do
    servers[name] = encodable_server(server)
  end
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
