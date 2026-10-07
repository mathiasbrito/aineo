--- The command that runs Claude Code: `claude.cmd`, the words that pick its
--- session, which `aineo.claude` chooses, and the arguments aineo gives it.

local M = {}

--- The hook relay script, beside this file.
local HOOK_RELAY =
  vim.fs.joinpath(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h'), 'hook_relay.lua')

--- How long Claude Code lets the hook relay run, in seconds, before it stops
--- it. Claude Code's documentation gives a command hook 600 s by default,
--- and the `SessionEnd` hooks of an exit, a `/clear` or an in-session
--- `/resume` 1.5 s in all, a budget a hook's own timeout raises. 5 s is far
--- above the hook's own run — a Neovim start and a spawn, 20–43 ms on an
--- idle host — so that a loaded host does not stop a `SessionEnd` hook
--- before it has started its deliverer, which would lose that switch; in
--- return, a hook that stalls holds Claude Code's `/clear` up to 5 s.
local HOOK_TIMEOUT_SECONDS = 5

--- The Claude Code hook events the hook relay runs for.
local RELAYED_EVENTS = { 'SessionStart', 'SessionEnd' }

--- The flag that gives Claude Code settings, and the prefix of its spelling
--- joined to its value in one word.
local SETTINGS_FLAG = '--settings'
local JOINED_SETTINGS_FLAG = SETTINGS_FLAG .. '='

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

--- aineo's hook entry for each of `RELAYED_EVENTS`, by event: a command hook
--- with no matcher, so that it runs whatever the event's source or reason,
--- that runs the hook relay (`relay_command()`) and is stopped after
--- `HOOK_TIMEOUT_SECONDS`.
---
---@param settings aineo.claude.Settings
---@param start_token string
---@return table<string, table>
local function hook_entries(settings, start_token)
  local entries = {}
  for _, event in ipairs(RELAYED_EVENTS) do
    local hook = {
      type = 'command',
      command = relay_command(settings, start_token, event),
      timeout = HOOK_TIMEOUT_SECONDS,
    }
    entries[event] = { hooks = { hook } }
  end
  return entries
end

--- Where `cmd` gives Claude Code settings, as Claude Code 2.1.292 reads them
--- when given several, the last of them: a `--settings` word and the word
--- after it, its value, or one `--settings=<value>` word; nil when it gives
--- none. `first` and `last` are the indexes of the words that give them.
---
---@param cmd string[]
---@return { first: integer, last: integer, value: string? }?
local function given_settings(cmd)
  for index = #cmd, 1, -1 do
    if cmd[index] == SETTINGS_FLAG then
      return { first = index, last = index + 1, value = cmd[index + 1] }
    elseif vim.startswith(cmd[index], JOINED_SETTINGS_FLAG) then
      return { first = index, last = index, value = cmd[index]:sub(#JOINED_SETTINGS_FLAG + 1) }
    end
  end
end

--- Whether `value`, decoded from JSON, was a JSON object.
---
---@param value any
---@return boolean
local function is_object(value)
  return type(value) == 'table' and not vim.islist(value)
end

--- The settings `value`, a `--settings` value, gives: the JSON object it
--- holds when, its blanks trimmed, it begins with `{` and ends with `}` —
--- how Claude Code 2.1.292 tells inline settings from a file — else the JSON
--- object in the file it names, a relative name taken from `cwd`, Claude
--- Code's working directory. Returns nil and why when it gives no JSON
--- object.
---
---@param value string?
---@param cwd string
---@return table? settings
---@return string? failure
local function read_settings(value, cwd)
  if not value then
    return nil, 'it has no value'
  end
  local text = vim.trim(value)
  if not (vim.startswith(text, '{') and vim.endswith(text, '}')) then
    local path = vim.startswith(value, '/') and value or vim.fs.joinpath(cwd, value)
    local file, failure = io.open(path, 'r')
    if not file then
      return nil, failure
    end
    text = file:read('*a')
    file:close()
  end
  local decoded, settings = pcall(vim.json.decode, text)
  if not decoded then
    return nil, settings
  end
  if not is_object(settings) then
    return nil, 'it holds no JSON object'
  end
  return settings
end

--- Adds each of `entries`, by event, after the hook entries `settings`
--- already gives that event, in place. Returns `settings`, or nil and why
--- when its `hooks` is not an object, or an event's entries in it not a
--- list, so that nothing can be added to them.
---
---@param settings table settings decoded from JSON
---@param entries table<string, table> `hook_entries()`
---@return table? settings
---@return string? failure
local function add_hook_entries(settings, entries)
  settings.hooks = settings.hooks or vim.empty_dict()
  if not is_object(settings.hooks) then
    return nil, 'its hooks are not an object'
  end
  for event, entry in pairs(entries) do
    local given = settings.hooks[event] or {}
    if type(given) ~= 'table' or not vim.islist(given) then
      return nil, ('its %s hooks are not a list'):format(event)
    end
    settings.hooks[event] = vim.list_extend(given, { entry })
  end
  return settings
end

--- What aineo gives Claude Code as `--settings` for `settings`, with
--- `entries`, its own hook entries, in them: the settings `settings.cmd`
--- gives (`given_settings()`, `read_settings()`) with `entries` added after
--- its own hooks (`add_hook_entries()`), and `cmd` without the words that
--- gave them; or `entries` alone, and `cmd` whole, when it gives none. When
--- `settings.cmd` gives settings that cannot be read or added to, `cmd` is
--- `settings.cmd` whole, `settings` is nil, and `unread` says why.
---
---@param settings aineo.claude.Settings
---@param entries table<string, table>
---@return { cmd: string[], settings: table?, unread: string? }
local function settings_with_hooks(settings, entries)
  local given = given_settings(settings.cmd)
  if not given then
    return { cmd = settings.cmd, settings = add_hook_entries(vim.empty_dict(), entries) }
  end
  local read, failure = read_settings(given.value, settings.cwd)
  local merged, refusal
  if read then
    merged, refusal = add_hook_entries(read, entries)
  end
  if not merged then
    return { cmd = settings.cmd, unread = failure or refusal }
  end
  local cmd = vim.list_slice(settings.cmd, 1, given.first - 1)
  return { cmd = vim.list_extend(cmd, settings.cmd, given.last + 1), settings = merged }
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
--- system prompt as they are, `claude_settings` as one JSON object when it
--- is given, and the tools it may use without asking, each one word after
--- `--allowedTools`. Claude Code's CLI reference gives that flag several
--- words (its example names three tools), as it gives `--mcp-config` several
--- space-separated values, so that flag comes last, where no word of aineo's
--- own follows it, and `--mcp-config` is followed by a flag.
---
---@param settings aineo.claude.Settings
---@param claude_settings table?
---@return string[]
local function claude_arguments(settings, claude_settings)
  local servers = vim.empty_dict()
  for name, server in pairs(settings.mcp_servers) do
    servers[name] = encodable_server(server)
  end
  local words = {
    '--mcp-config',
    vim.json.encode({ mcpServers = servers }),
    '--append-system-prompt',
    settings.instructions,
  }
  if claude_settings then
    vim.list_extend(words, { SETTINGS_FLAG, vim.json.encode(claude_settings) })
  end
  table.insert(words, '--allowedTools')
  return vim.list_extend(words, settings.allowed_tools)
end

--- The command that runs Claude Code with `settings` on the session
--- `session_words` pick: `settings.cmd`, then `session_words`, then aineo's
--- arguments (`claude_arguments()`), among them `--settings` with a
--- `SessionStart` and a `SessionEnd` hook that tell the editor of each,
--- naming `start_token`. A `--settings` of `settings.cmd`, in a file or
--- inline, gets aineo's hooks after its own and is passed as that one
--- `--settings`, nothing of it dropped (`settings_with_hooks()`). When it
--- cannot be read or added to, `settings.cmd` is passed whole and aineo
--- passes no `--settings`, and `unread` says why.
---
---@param settings aineo.claude.Settings
---@param session_words string[]
---@param start_token string the token that tells this start's hooks from another's
---@return string[] command
---@return string? unread
function M.claude_command(settings, session_words, start_token)
  local given = settings_with_hooks(settings, hook_entries(settings, start_token))
  local command = vim.list_extend(vim.list_slice(given.cmd), session_words)
  return vim.list_extend(command, claude_arguments(settings, given.settings)), given.unread
end

return M
