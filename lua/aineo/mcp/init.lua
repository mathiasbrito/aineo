--- aineo's MCP home, `require('aineo.mcp')`: the report server Claude Code
--- runs, described for Claude Code's `--mcp-config` and `--allowedTools`.

local names = require('aineo.mcp.names')

local M = {}

--- The relay script, beside this file.
local RELAY =
  vim.fs.joinpath(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h'), 'relay.lua')

--- The MCP servers aineo gives Claude Code, in the format of its
--- `--mcp-config`: the report server, as a stdio server Claude Code starts as
--- `<editor_program> --headless --clean --cmd 'set noloadplugins' -l <relay>`,
--- told the address of the editor to deliver reports to. `--clean` leaves out
--- the user's configuration and site directories, but not the system's
--- (`$XDG_CONFIG_DIRS`, `$XDG_DATA_DIRS`), whose plugins would still load and
--- could write to the relay's stdout; `noloadplugins` loads none.
---
--- Raises an error naming the argument that is not a string.
---
---@param editor_address string the editor's server address (`v:servername`)
---@param editor_program string the editor's own program (`v:progpath`)
---@return table<string, { type: string, command: string, args: string[], env: table<string, string> }>
function M.mcp_servers(editor_address, editor_program)
  vim.validate('editor_address', editor_address, 'string')
  vim.validate('editor_program', editor_program, 'string')
  return {
    [names.SERVER_NAME] = {
      type = 'stdio',
      command = editor_program,
      args = { '--headless', '--clean', '--cmd', 'set noloadplugins', '-l', RELAY },
      env = { [names.EDITOR_ADDRESS_VARIABLE] = editor_address },
    },
  }
end

--- The name Claude Code gives the report tool: `mcp__<server>__<tool>`.
---
---@return string
function M.report_tool_name()
  return ('mcp__%s__%s'):format(names.SERVER_NAME, names.REPORT_TOOL)
end

--- The tools Claude Code may call without asking the user (its
--- `--allowedTools`): the report tool, and nothing else.
---
---@return string[]
function M.allowed_mcp_tools()
  return { M.report_tool_name() }
end

return M
