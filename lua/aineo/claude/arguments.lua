--- The arguments aineo gives Claude Code after its command and after the
--- words that pick its session, which `aineo.claude` puts first.

local M = {}

--- The hook relay script, beside this file.
local HOOK_RELAY =
  vim.fs.joinpath(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h'), 'hook_relay.lua')

--- How long Claude Code lets the hook relay run, in seconds, before it stops
--- it.
local HOOK_TIMEOUT_SECONDS = 5

--- The Claude Code hook events the hook relay runs for.
local RELAYED_EVENTS = { 'SessionStart', 'SessionEnd' }

--- `word` quoted for a POSIX shell: between single quotes, each single quote
--- in it written `'\''`, so that the shell reads it back as it is.
---
---@param word string
---@return string
local function shell_word(word)
  return "'" .. word:gsub("'", [['\'']]) .. "'"
end

--- The shell command that runs the hook relay for `event`, telling the
--- editor of `settings` the start `start_token`, every word quoted
--- (`shell_word()`): Claude Code runs a command hook's command through a
--- shell.
---
---@param settings aineo.claude.Settings
---@param start_token string
---@param event string
---@return string
local function relay_command(settings, start_token, event)
  local words = {
    settings.editor_program,
    '--headless',
    '--clean',
    '--cmd',
    'set noloadplugins',
    '-l',
    HOOK_RELAY,
    settings.editor_address,
    start_token,
    event,
  }
  return table.concat(vim.tbl_map(shell_word, words), ' ')
end

--- The settings, as one JSON object for `--settings`, that give Claude Code
--- a command hook for each of `RELAYED_EVENTS` with no matcher, so that it
--- runs whatever the event's source or reason: the hook relay
--- (`relay_command()`), stopped after `HOOK_TIMEOUT_SECONDS`. They hold the
--- `hooks` key alone.
---
---@param settings aineo.claude.Settings
---@param start_token string
---@return string
local function hook_settings(settings, start_token)
  local hooks = {}
  for _, event in ipairs(RELAYED_EVENTS) do
    local hook = {
      type = 'command',
      command = relay_command(settings, start_token, event),
      timeout = HOOK_TIMEOUT_SECONDS,
    }
    hooks[event] = { { hooks = { hook } } }
  end
  return vim.json.encode({ hooks = hooks })
end

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
--- system prompt as they are, the session hooks that tell the editor of
--- each `SessionStart` and `SessionEnd`, naming `start_token`
--- (`hook_settings()`), and the tools it may use without asking, each one
--- word after `--allowedTools`. Claude Code's CLI reference gives that flag
--- several words (its example names three tools), as it gives `--mcp-config`
--- several space-separated values, so that flag comes last, where no word of
--- aineo's own follows it, and `--mcp-config` is followed by a flag.
---
---@param settings aineo.claude.Settings
---@param start_token string the token that tells this start's hooks from another's
---@return string[]
function M.claude_arguments(settings, start_token)
  local servers = vim.empty_dict()
  for name, server in pairs(settings.mcp_servers) do
    servers[name] = encodable_server(server)
  end
  local words = {
    '--mcp-config',
    vim.json.encode({ mcpServers = servers }),
    '--append-system-prompt',
    settings.instructions,
    '--settings',
    hook_settings(settings, start_token),
    '--allowedTools',
  }
  return vim.list_extend(words, settings.allowed_tools)
end

return M
