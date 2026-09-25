--- aineo's health check, `:checkhealth aineo`. It reads the configuration
--- and the editor's state and reports on them, running only
--- `claude.cmd --version`; it starts no Claude session, opens no layout and
--- maps no key.

local config = require('aineo.config')

local M = {}

--- The position Lua puts before an error it raises: `<file>.lua:<line>: `
--- for Lua code loaded from a file, `vim/<module>:<line>: ` for Neovim's own
--- Lua from 0.12 on, whose modules are named without the `.lua`.
local ERROR_POSITIONS = { '^.-%.lua:%d+: ', '^vim/[%w_/]+:%d+: ' }

--- The error `message` tells, on one line: its first line, without the
--- position of the Lua code that raised it (`ERROR_POSITIONS`).
---
---@param message any
---@return string
local function error_line(message)
  local line = tostring(message):match('^[^\n]*')
  for _, position in ipairs(ERROR_POSITIONS) do
    line = line:gsub(position, '')
  end
  return line
end

--- Reports whether aineo's configuration — `vim.g.aineo` and the options
--- `require('aineo').setup()` recorded — is valid, warning of each key no
--- setting knows, and returns it resolved; when a value is wrong, reports the
--- error naming it and returns `nil`.
---
---@return table|nil config
local function check_configuration()
  vim.health.start('Configuration')
  local resolved, resolved_config, unknown_keys =
    pcall(config.resolve_config, vim.g.aineo, config.recorded_setup_options())
  if not resolved then
    vim.health.error(error_line(resolved_config))
    return nil
  end
  vim.health.ok('the configuration is valid')
  for _, key in ipairs(unknown_keys) do
    vim.health.warn(("unknown setting '%s', which aineo ignores"):format(key))
  end
  return resolved_config
end

--- The version of Claude Code aineo's behaviour was measured on.
local MEASURED_CLAUDE_VERSION = '2.1.281'

--- The first line of `text` that holds more than white space, trimmed; `nil`
--- when there is none.
---
---@param text string
---@return string|nil
local function first_line(text)
  local trimmed = vim.trim(text)
  if trimmed == '' then
    return nil
  end
  return trimmed:match('^[^\r\n]*')
end

--- How long `claude.cmd --version` may run before it is killed, with every
--- process in its process group.
local VERSION_BOUND_MS = 3000

--- How much of what `claude.cmd --version` writes the check keeps, of its
--- standard output and of its standard error each; the rest is read and
--- dropped.
local KEPT_OUTPUT_BYTES = 1024

--- `text` without the bytes of a UTF-8 character its end cuts short: a lead
--- byte followed by fewer continuation bytes than it announces (RFC 3629
--- §3).
---
---@param text string
---@return string
local function without_cut_character(text)
  for back = 0, 3 do
    local position = #text - back
    local byte = text:byte(position)
    if byte == nil or byte < 0x80 then
      return text
    end
    if byte >= 0xC0 then
      local length = byte >= 0xF0 and 4 or byte >= 0xE0 and 3 or 2
      if back + 1 < length then
        return text:sub(1, position - 1)
      end
      return text
    end
  end
  return text
end

--- A sink for one of a process's outputs, in the form `vim.system()` calls,
--- that keeps its first `KEPT_OUTPUT_BYTES`, less a character they end
--- partway through (`without_cut_character()`); and a function returning
--- what it kept.
---
---@return fun(err: string|nil, data: string|nil) keep
---@return fun(): string kept
local function bounded_output()
  local pieces, size = {}, 0
  local function keep(_, data)
    if data and size < KEPT_OUTPUT_BYTES then
      local piece = data:sub(1, KEPT_OUTPUT_BYTES - size)
      table.insert(pieces, piece)
      size = size + #piece
    end
  end
  return keep, function()
    return without_cut_character(table.concat(pieces))
  end
end

--- Runs `command` as a list of words, never through a shell, leading a
--- process group of its own, and returns how it ended. A timer of the
--- check's own kills the whole group at `VERSION_BOUND_MS` — the command and
--- every process in its group, such as a wrapper's child — so the wait keeps
--- its bound even while the command writes without end, when Neovim's own
--- `vim.wait()` time-out does not run out. A descendant that starts a process
--- group or a session of its own is not in the group: it escapes the kill
--- and can outlive the check.
---
--- Whenever the wait ends before the command has finished — at the bound, or
--- early, on Ctrl-C — the group is killed and the result is `nil`. A command
--- that finished is reported by its result, even when the timer came due in
--- the same event-loop iteration.
---
--- Raises the error `vim.system()` raises when the command cannot start.
---
---@param command string[]
---@return { code: integer, stdout: string, stderr: string }|nil result `nil` when it did not finish in time
local function run_within_bound(command)
  local keep_stdout, kept_stdout = bounded_output()
  local keep_stderr, kept_stderr = bounded_output()
  local completed = nil
  local process = vim.system(
    command,
    { stdout = keep_stdout, stderr = keep_stderr, detach = true },
    function(result)
      completed = result
    end
  )
  local timed_out = false
  local timer = assert(vim.uv.new_timer())
  timer:start(VERSION_BOUND_MS, 0, function()
    timed_out = true
    vim.uv.kill(-process.pid, 'sigkill')
  end)
  vim.wait(2 * VERSION_BOUND_MS, function()
    return timed_out or completed ~= nil
  end, 10, true)
  timer:stop()
  timer:close()
  if completed == nil then
    vim.uv.kill(-process.pid, 'sigkill')
    return nil
  end
  return { code = completed.code, stdout = kept_stdout(), stderr = kept_stderr() }
end

--- Reports the version `command` prints when run whole with `--version`
--- appended (`run_within_bound()`), or warns when it cannot start, runs past
--- `VERSION_BOUND_MS`, fails, or prints nothing.
---
---@param command string[] `claude.cmd`
local function check_claude_version(command)
  local started, result =
    pcall(run_within_bound, vim.list_extend(vim.list_slice(command), { '--version' }))
  if not started then
    vim.health.warn('claude.cmd --version could not run: ' .. error_line(result))
    return
  end
  if result == nil then
    vim.health.warn(
      ('claude.cmd --version did not finish within %d s'):format(VERSION_BOUND_MS / 1000)
    )
    return
  end
  if result.code ~= 0 then
    vim.health.warn(
      ('claude.cmd --version exited with %d'):format(result.code),
      first_line(result.stderr)
    )
    return
  end
  local version = first_line(result.stdout)
  if version == nil then
    vim.health.warn('claude.cmd --version printed nothing')
    return
  end
  vim.health.ok('claude.cmd --version: ' .. version)
end

--- Reports on the command that runs Claude Code, `claude.cmd`: an error when
--- its first word is not executable (`executable()`), in the words the
--- Claude session uses when it refuses to start; else the version it prints
--- (`check_claude_version()`).
---
---@param command string[] `claude.cmd`
local function check_claude_command(command)
  local program = command[1]
  if vim.fn.executable(program) == 0 then
    vim.health.error(
      ("claude.cmd: '%s' is not executable"):format(program),
      'Install Claude Code, or set claude.cmd to the command that runs it: :help aineo-config-claude.cmd'
    )
    return
  end
  check_claude_version(command)
end

--- Reports on the Claude Code `resolved_config`'s `claude.cmd` runs, and the version
--- aineo was measured on.
---
---@param resolved_config table|nil the configuration, `nil` when it is wrong
local function check_claude(resolved_config)
  vim.health.start('Claude Code')
  if resolved_config == nil then
    vim.health.info('claude.cmd is not checked while the configuration is wrong')
  else
    check_claude_command(resolved_config.claude.cmd)
  end
  vim.health.info(
    ("aineo's behaviour was measured on Claude Code %s"):format(MEASURED_CLAUDE_VERSION)
  )
end

--- Reports the address the editor listens at, `v:servername`, where the
--- report tool's relay delivers Claude's reports; an error when it listens
--- nowhere.
local function check_server_socket()
  vim.health.start('Server socket')
  if vim.v.servername == '' then
    vim.health.error(
      'the editor listens nowhere (v:servername is empty)',
      "Claude's reports cannot reach this editor; start one with :call serverstart()"
    )
    return
  end
  vim.health.ok('the editor listens at ' .. vim.v.servername)
end

--- The key that follows the prefix for each of `:Aineo`'s subcommands, in
--- the order `plugin/aineo.lua` maps them.
local PREFIX_KEYS = {
  { key = 's', subcommand = 'send' },
  { key = 'o', subcommand = 'open' },
  { key = 'r', subcommand = 'report' },
  { key = 'i', subcommand = 'input' },
  { key = 'c', subcommand = 'claude' },
}

--- The keys `keys`, written as in a mapping, stand for when typed.
---
---@param keys string
---@return string
local function typed_keys(keys)
  return vim.api.nvim_replace_termcodes(keys, true, true, true)
end

--- The global Normal-mode mapping of `keys`, written as in a mapping, if
--- any — compared in both the forms Neovim records, as `plugin/aineo.lua`
--- compares them when it decides whether the user has mapped a key.
---
---@param keys string
---@return table|nil mapping as `nvim_get_keymap()` gives it
local function global_mapping(keys)
  local typed = typed_keys(keys)
  return vim.iter(vim.api.nvim_get_keymap('n')):find(function(mapping)
    return mapping.lhsraw == typed or mapping.lhsrawalt == typed
  end)
end

--- What `mapping` runs, in words: its keys quoted, or a Lua function, named
--- by its description when it has one.
---
---@param mapping table as `nvim_get_keymap()` gives it
---@return string
local function what_mapping_runs(mapping)
  if mapping.rhs then
    return ("'%s'"):format(mapping.rhs)
  end
  if mapping.desc then
    return ('a Lua function (%s)'):format(mapping.desc)
  end
  return 'a Lua function'
end

--- Reports what the key sequence `prefix` followed by `prefix_key.key`
--- runs: ok when it runs the subcommand's `<Plug>` mapping, a warning when
--- it runs anything else or is not mapped at all.
---
---@param prefix string
---@param prefix_key { key: string, subcommand: string }
local function check_prefix_key(prefix, prefix_key)
  local keys = prefix .. prefix_key.key
  local plug_mapping = ('<Plug>(aineo-%s)'):format(prefix_key.subcommand)
  local mapping = global_mapping(keys)
  if mapping == nil then
    vim.health.warn(
      ('%s is not mapped'):format(keys),
      'aineo maps its keys once, when the editor has started; a prefix changed or a key unmapped since stays so until the next start: :help aineo-config-prefix'
    )
  elseif mapping.rhs == plug_mapping then
    vim.health.ok(('%s runs %s'):format(keys, plug_mapping))
  else
    vim.health.warn(
      ('%s runs %s, not %s'):format(keys, what_mapping_runs(mapping), plug_mapping),
      ('aineo leaves a key you mapped alone; map %s to a key of your own: :help aineo-mappings'):format(
        plug_mapping
      )
    )
  end
end

--- The longest leader, in bytes, Neovim copies into a mapping; it maps a
--- backslash for a longer one.
local LONGEST_LEADER_BYTES = 48

--- The characters a mapping's `<Leader>` or `<LocalLeader>` stands for,
--- from `value`, the `mapleader` or `maplocalleader` that sets it: a
--- backslash when it is not set, empty, a List or a Dictionary, or a string
--- longer than `LONGEST_LEADER_BYTES`; a Number's digits; and any other value
--- as it is — a string's characters as written, never read as key notation,
--- since Neovim copies them into a mapping literally (`:h <Leader>`;
--- `'<Space>'` maps `<lt>Space>`).
---
---@param value any
---@return any keys
local function leader_keys(value)
  if value == nil or value == '' or type(value) == 'table' then
    return '\\'
  end
  if type(value) == 'number' then
    return tostring(value)
  end
  if type(value) == 'string' and #value > LONGEST_LEADER_BYTES then
    return '\\'
  end
  return value
end

--- Warns when a leader is `prefix`: a filetype plugin's `<LocalLeader>` or
--- `<Leader>` mapping local to a buffer would then shadow aineo's key in
--- that buffer.
---
---@param prefix string
local function check_leaders(prefix)
  local prefix_keys = typed_keys(prefix)
  if leader_keys(vim.g.maplocalleader) == prefix_keys then
    vim.health.warn(
      'the local leader is the prefix, ' .. prefix,
      "A filetype plugin's <LocalLeader> mapping shadows aineo's key in its buffer; set maplocalleader to another key: :help aineo-config-prefix"
    )
  end
  if leader_keys(vim.g.mapleader) == prefix_keys then
    vim.health.warn(
      'the leader is the prefix, ' .. prefix,
      "A filetype plugin's <Leader> mapping shadows aineo's key in its buffer, as Neovim's own ChangeLog plugin does with <Leader>o; set mapleader to another key: :help aineo-config-prefix"
    )
  end
end

--- What the health check says of the autostart when aineo was loaded after
--- the editor had started.
local SOURCED_LATE_FINDING = {
  level = 'info',
  text = 'the autostart did not run: aineo was loaded after startup, as a plugin manager that loads it lazily does',
}

--- What the health check says of each reason `plugin/aineo.lua` records for
--- the autostart's decision: the `vim.health` function it reports with, and
--- its words.
---@type table<string, { level: 'ok'|'info'|'warn', text: string }>
local AUTOSTART_FINDINGS = {
  starting = {
    level = 'info',
    text = "the autostart has not decided: aineo's VimEnter handler, which decides it, has not run — the editor is still starting, or a VimEnter autocommand before it threw an exception",
  },
  opening = {
    level = 'info',
    text = 'the autostart decided to open the layout, which opens once startup has settled',
  },
  opened = { level = 'ok', text = 'the autostart opened the layout at startup' },
  ['autostart-off'] = { level = 'info', text = 'the autostart did not run: autostart is false' },
  ['no-ui'] = {
    level = 'info',
    text = 'the autostart did not run: no user interface was attached (a headless start)',
  },
  ['file-argument'] = {
    level = 'info',
    text = 'the autostart did not run: Neovim was given a file to edit',
  },
  stdin = { level = 'info', text = 'the autostart did not run: Neovim read its standard input' },
  ['startup-task'] = {
    level = 'info',
    text = 'the autostart did not run: Neovim was given something to do besides edit (-c, -S, -e, -s, -E or a + command)',
  },
  ['inside-claude'] = {
    level = 'info',
    text = "the autostart did not run: this Neovim runs inside aineo's own Claude terminal ($AINEO_CHILD is set)",
  },
  ['session-restored'] = {
    level = 'info',
    text = 'the autostart did not run: a session was restored at startup (v:this_session is set)',
  },
  ['mapping-late'] = SOURCED_LATE_FINDING,
  ['sourced-late'] = SOURCED_LATE_FINDING,
  ['open-failed'] = {
    level = 'warn',
    text = 'the autostart tried to open the layout and failed',
  },
  ['wrong-setting'] = {
    level = 'warn',
    text = 'the autostart did not run: a setting was wrong at startup',
  },
}

--- aineo's record of the autostart, the editor variable `vim.g.aineo_startup`
--- that `plugin/aineo.lua` writes from the moment it is sourced: the record,
--- a table whose `reason` is one of `AUTOSTART_FINDINGS`; `nil` when the
--- variable is not set; `false` when it holds anything else.
---
---@return { reason: string, failure: any }|false|nil
local function startup_record()
  local record = vim.g.aineo_startup
  if record == nil then
    return nil
  end
  if type(record) == 'table' and AUTOSTART_FINDINGS[record.reason] then
    return record
  end
  return false
end

--- What the Prefix mappings section says in place of a line per key while
--- aineo's record (`startup_record()`) says it has not mapped them yet, by
--- the record's reason.
local PREFIX_KEYS_PENDING = {
  starting = 'the prefix keys are not mapped: aineo maps them from its VimEnter handler, which has not run — the editor is still starting, or a VimEnter autocommand before it threw an exception',
  ['mapping-late'] = 'the prefix keys are not mapped yet: aineo was loaded after startup, and maps them in the next event-loop tick',
}

--- Reports on the prefix mappings `resolved_config`'s `prefix` names: each
--- key — or, while aineo's record says it has not mapped them yet, one line
--- saying why (`PREFIX_KEYS_PENDING`) — and the leaders.
---
---@param resolved_config table|nil the configuration, `nil` when it is wrong
local function check_prefix_mappings(resolved_config)
  vim.health.start('Prefix mappings')
  if resolved_config == nil then
    vim.health.info('the prefix mappings are not checked while the configuration is wrong')
    return
  end
  if resolved_config.prefix == false then
    vim.health.info(
      'prefix is false: aineo maps no key; :Aineo and the <Plug>(aineo-…) mappings remain'
    )
    return
  end
  local record = startup_record()
  local pending = record and PREFIX_KEYS_PENDING[record.reason]
  if pending then
    vim.health.info(pending)
  else
    for _, prefix_key in ipairs(PREFIX_KEYS) do
      check_prefix_key(resolved_config.prefix, prefix_key)
    end
  end
  check_leaders(resolved_config.prefix)
end

--- Reports what the autostart decided when the editor started, and why, from
--- aineo's record (`startup_record()`), with the error an open that failed
--- met when the record holds it as text.
local function check_autostart()
  vim.health.start('Autostart')
  local record = startup_record()
  if record == nil then
    vim.health.info(
      'no record of the autostart: plugin/aineo.lua did not run at startup (vim.g.loaded_aineo set before it, or --noplugin)'
    )
    return
  end
  if record == false then
    vim.health.info(
      'no record of the autostart: vim.g.aineo_startup holds something aineo did not write'
    )
    return
  end
  local finding = AUTOSTART_FINDINGS[record.reason]
  local failure = type(record.failure) == 'string' and ': ' .. record.failure or ''
  vim.health[finding.level](finding.text .. failure)
end

--- Names the limits of aineo that no check can detect.
local function name_limits()
  vim.health.start('Limits')
  vim.health.info(
    "aineo stops Claude Code from its own VimLeavePre handler when Neovim quits; a VimLeavePre handler registered before it that raises an error makes Neovim skip aineo's, and a Claude Code that hangs then outlives the editor; aineo cannot detect this: :help aineo-limits"
  )
end

--- Runs aineo's health check (`:h health-dev`).
function M.check()
  local resolved_config = check_configuration()
  check_claude(resolved_config)
  check_server_socket()
  check_prefix_mappings(resolved_config)
  check_autostart()
  name_limits()
end

return M
