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

--- The word of the hook's command the shell expands to the pid of the
--- process that ran the hook's shell — Claude Code's — whose record the
--- hook relay writes; the one word left unquoted for the shell.
local CLAUDE_PID_WORD = '"$PPID"'

--- The shell command that runs the hook relay for `event`, telling the
--- editor of `settings` the start `start_token`, then the pid of Claude
--- Code's process (`CLAUDE_PID_WORD`) and the directory it runs in, every
--- word but the pid's quoted (`shell_word()`): Claude Code runs a command
--- hook's command through a shell.
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
  local quoted = vim.tbl_map(shell_word, words)
  vim.list_extend(quoted, { CLAUDE_PID_WORD, shell_word(settings.cwd) })
  return table.concat(quoted, ' ')
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

--- The text of the file at `path` when it is a regular file, or a symbolic
--- link to one; nil when it is not — a FIFO, a directory or a device, whose
--- read could wait or never end — or cannot be read, with why.
---
---@param path string
---@return string? text
---@return string? problem
local function regular_file_text(path)
  local stat, stat_problem = vim.uv.fs_stat(path)
  if not stat then
    return nil, stat_problem
  end
  if stat.type ~= 'file' then
    return nil, ('%s is not a regular file (%s)'):format(path, stat.type)
  end
  local file, open_problem = io.open(path, 'r')
  if not file then
    return nil, open_problem
  end
  local text = file:read('*a')
  file:close()
  return text
end

--- A UTF-8 byte order mark, which Claude Code 2.1.292 drops from the start
--- of settings before it parses them.
local BYTE_ORDER_MARK = '\239\187\191'

--- What the problems `read_settings()` and `hooks_problem()` tell name
--- settings given inline by.
local INLINE_SOURCE = 'the inline value'

--- The settings `value`, a `--settings` value, gives: the JSON object it
--- holds when, its blanks trimmed, it begins with `{` and ends with `}` —
--- how Claude Code 2.1.292 tells inline settings from a file — else the JSON
--- object in the regular file it names (`regular_file_text()`), a relative
--- name taken from `cwd`, the working directory Claude Code starts in, which
--- is where Claude Code 2.1.292 resolves one from. As Claude Code 2.1.292
--- reads them, a `BYTE_ORDER_MARK` they begin with is dropped, and settings
--- of blanks alone, or none, are an empty object. Returns nil when it gives
--- no JSON object, with why; and where they came from: the file's path, or
--- `INLINE_SOURCE`.
---
---@param value string?
---@param cwd string
---@return table? settings
---@return string? problem
---@return string? source
local function read_settings(value, cwd)
  if not value then
    return nil, 'no value follows it'
  end
  local text, source = value, INLINE_SOURCE
  local trimmed = vim.trim(value)
  if not (vim.startswith(trimmed, '{') and vim.endswith(trimmed, '}')) then
    local problem
    source = vim.startswith(value, '/') and value or vim.fs.joinpath(cwd, value)
    text, problem = regular_file_text(source)
    if not text then
      return nil, problem
    end
  end
  if vim.startswith(text, BYTE_ORDER_MARK) then
    text = text:sub(#BYTE_ORDER_MARK + 1)
  end
  if vim.trim(text) == '' then
    return vim.empty_dict(), nil, source
  end
  local decoded, settings = pcall(vim.json.decode, text)
  if not decoded then
    return nil, ('%s is not valid JSON: %s'):format(source, settings)
  end
  if not is_object(settings) then
    return nil, ('%s holds no JSON object'):format(source)
  end
  return settings, nil, source
end

--- Why aineo's hook entries for `RELAYED_EVENTS` cannot be added after the
--- hooks `settings`, from `source`, already gives: its `hooks` not an
--- object, or an event's entries in it not a list; nil when they can.
---
---@param settings table settings decoded from JSON
---@param source string where they came from, as `read_settings()` names it
---@return string? problem
local function hooks_problem(settings, source)
  if not settings.hooks then
    return nil
  end
  if not is_object(settings.hooks) then
    return ('the hooks in %s are not an object'):format(source)
  end
  for _, event in ipairs(RELAYED_EVENTS) do
    local given = settings.hooks[event]
    if given and not (type(given) == 'table' and vim.islist(given)) then
      return ('the %s hooks in %s are not a list'):format(event, source)
    end
  end
  return nil
end

--- Adds each of `entries`, by event, after the hook entries `settings`
--- already gives that event, in place, and returns `settings`; settings for
--- which `hooks_problem()` finds no problem.
---
---@param settings table settings decoded from JSON
---@param entries table<string, table> `hook_entries()`
---@return table settings
local function add_hook_entries(settings, entries)
  settings.hooks = settings.hooks or vim.empty_dict()
  for event, entry in pairs(entries) do
    settings.hooks[event] = vim.list_extend(settings.hooks[event] or {}, { entry })
  end
  return settings
end

--- The settings `given` gives (`read_settings()`), when aineo can add its
--- hook entries to them (`hooks_problem()`); else nil, with why.
---
---@param given { value: string? } `given_settings()`
---@param cwd string the directory Claude Code starts in
---@return table? settings
---@return string? problem
local function settings_taking_hooks(given, cwd)
  local settings, problem, source = read_settings(given.value, cwd)
  if not settings then
    return nil, problem
  end
  problem = hooks_problem(settings, source)
  if problem then
    return nil, problem
  end
  return settings
end

--- The mode of a file only its owner can read and write, 0600.
local PRIVATE_FILE_MODE = tonumber('600', 8)

--- Writes `text` to a new file in Neovim's own temporary directory
--- (`tempname()`), which Neovim removes when it exits, that only the user
--- can read and write (`PRIVATE_FILE_MODE`). Returns its path, or nil when
--- it cannot write it whole, removing what part of it it wrote.
---
---@param text string
---@return string? path
local function write_private_file(text)
  local path = vim.fn.tempname()
  local file = vim.uv.fs_open(path, 'wx', PRIVATE_FILE_MODE)
  if not file then
    return nil
  end
  local written = vim.uv.fs_write(file, text)
  vim.uv.fs_close(file)
  if written ~= #text then
    vim.uv.fs_unlink(path)
    return nil
  end
  return path
end

--- What aineo gives Claude Code as `--settings` for `settings`, with
--- `entries`, its own hook entries, in them, as `value`: the settings
--- `settings.cmd` gives (`given_settings()`, `settings_taking_hooks()`) with
--- `entries` added after its own hooks (`add_hook_entries()`), written to a
--- file only the user can read (`write_private_file()`), which `value` names,
--- and `cmd` without the words that gave them; or `entries` alone, as JSON,
--- and `cmd` whole, when it gives none. When `settings.cmd` gives settings
--- that cannot be read or added to, or the file cannot be written, `cmd` is
--- `settings.cmd` whole, `value` is nil, and `unread` is true.
---
---@param settings aineo.claude.Settings
---@param entries table<string, table>
---@return { cmd: string[], value: string?, unread: boolean? }
local function settings_with_hooks(settings, entries)
  local given = given_settings(settings.cmd)
  if not given then
    return {
      cmd = settings.cmd,
      value = vim.json.encode(add_hook_entries(vim.empty_dict(), entries)),
    }
  end
  local read = settings_taking_hooks(given, settings.cwd)
  local merged = read and add_hook_entries(read, entries)
  local file = merged and write_private_file(vim.json.encode(merged))
  if not file then
    return { cmd = settings.cmd, unread = true }
  end
  local cmd = vim.list_slice(settings.cmd, 1, given.first - 1)
  return { cmd = vim.list_extend(cmd, settings.cmd, given.last + 1), value = file }
end

--- What becomes of the `--settings` that `cmd` gives when Claude Code starts
--- in `cwd`, read as `M.claude_command()` reads it: nil when `cmd` gives
--- none; else a verdict whose `problem` says why aineo cannot add its
--- session hooks to them, nil when it can. Whether the file aineo writes
--- them to can be written is not part of it.
---
---@param cmd string[]
---@param cwd string
---@return { problem: string? }?
function M.given_settings_verdict(cmd, cwd)
  local given = given_settings(cmd)
  if not given then
    return nil
  end
  local _, problem = settings_taking_hooks(given, cwd)
  return { problem = problem }
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
--- JSON object — `{}` when there are none — aineo's report server among them
--- told `start_token` (`aineo.mcp`'s `with_start_token()`), the instructions
--- appended to its system prompt as they are, `settings_value` as
--- `--settings` when it is given, and the tools it may use without asking,
--- each one word after `--allowedTools`. Claude Code's CLI reference gives
--- that flag several
--- words (its example names three tools), as it gives `--mcp-config` several
--- space-separated values, so that flag comes last, where no word of aineo's
--- own follows it, and `--mcp-config` is followed by a flag.
---
---@param settings aineo.claude.Settings
---@param settings_value string?
---@param start_token string
---@return string[]
local function claude_arguments(settings, settings_value, start_token)
  local servers = vim.empty_dict()
  -- Required here, at a start, so that loading the Claude home, as
  -- `:checkhealth aineo` does, loads no MCP home.
  local mcp = require('aineo.mcp')
  for name, server in pairs(mcp.with_start_token(settings.mcp_servers, start_token)) do
    servers[name] = encodable_server(server)
  end
  local words = {
    '--mcp-config',
    vim.json.encode({ mcpServers = servers }),
    '--append-system-prompt',
    settings.instructions,
  }
  if settings_value then
    vim.list_extend(words, { SETTINGS_FLAG, settings_value })
  end
  table.insert(words, '--allowedTools')
  return vim.list_extend(words, settings.allowed_tools)
end

--- The command that runs Claude Code with `settings` on the session
--- `session_words` pick: `settings.cmd`, then `session_words`, then aineo's
--- arguments (`claude_arguments()`), among them `--settings` with a
--- `SessionStart` and a `SessionEnd` hook that tell the editor of each,
--- naming `start_token`: inline when `settings.cmd` gives no `--settings`.
--- A `--settings` of `settings.cmd`, in a file or inline, gets aineo's hooks
--- after its own, nothing of it dropped, and is written to a new file only
--- the user can read, in Neovim's temporary directory, which that one
--- `--settings` names, so that nothing of it is on the command line
--- (`settings_with_hooks()`). When it cannot be read or added to, or that
--- file cannot be written, `settings.cmd` is passed whole, aineo passes no
--- `--settings`, and `unread` is true.
---
---@param settings aineo.claude.Settings
---@param session_words string[]
---@param start_token string the token that tells this start's hooks from another's
---@return string[] command
---@return boolean unread
function M.claude_command(settings, session_words, start_token)
  local given = settings_with_hooks(settings, hook_entries(settings, start_token))
  local command = vim.list_extend(vim.list_slice(given.cmd), session_words)
  return vim.list_extend(command, claude_arguments(settings, given.value, start_token)),
    given.unread == true
end

return M
