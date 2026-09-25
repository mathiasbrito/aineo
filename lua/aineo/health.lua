--- aineo's health check, `:checkhealth aineo`. It reads the configuration
--- and the editor's state and reports on them, running only
--- `claude.cmd --version`; it starts no Claude session, opens no layout and
--- maps no key.

local config = require('aineo.config')

local M = {}

--- The error `message` tells, on one line: its first line, without the
--- `<file>.lua:<line>: ` position of the Lua code that raised it.
---
---@param message any
---@return string
local function error_line(message)
  return (tostring(message):match('^[^\n]*'):gsub('^.-%.lua:%d+: ', ''))
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
  return trimmed:match('^[^\n]*')
end

--- How long `claude.cmd --version` may run before it is killed.
local VERSION_BOUND_MS = 3000

--- The exit code `vim.system()`'s `wait()` gives a command it killed at its
--- time limit (`:h vim.system()`). When the killed command's output stays
--- open — held by a process it started — `wait()` gives up after as long
--- again and returns no result at all.
local TIMED_OUT = 124

--- Reports the version `command` prints when run whole with `--version`
--- appended — as a list of words, never through a shell — or warns when it
--- cannot start, runs past `VERSION_BOUND_MS`, fails, or prints nothing.
---
---@param command string[] `claude.cmd`
local function check_claude_version(command)
  local started, process =
    pcall(vim.system, vim.list_extend(vim.list_slice(command), { '--version' }), { text = true })
  if not started then
    vim.health.warn('claude.cmd --version could not run: ' .. error_line(process))
    return
  end
  local result = process:wait(VERSION_BOUND_MS)
  if result == nil or result.code == TIMED_OUT then
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

--- The key `<LocalLeader>` stands for: `maplocalleader`, or a backslash when
--- it is not set or empty (`:h <LocalLeader>`, `:h <Leader>`).
---
---@return string
local function local_leader()
  local configured = vim.g.maplocalleader
  if configured == nil or configured == '' then
    return '\\'
  end
  return configured
end

--- Warns when the local leader is `prefix`: a filetype plugin's
--- `<LocalLeader>` mapping local to a buffer would then shadow aineo's key
--- in that buffer.
---
---@param prefix string
local function check_local_leader(prefix)
  if typed_keys(local_leader()) == typed_keys(prefix) then
    vim.health.warn(
      'the local leader is the prefix, ' .. prefix,
      "A filetype plugin's <LocalLeader> mapping shadows aineo's key in its buffer; set maplocalleader to another key: :help aineo-config-prefix"
    )
  end
end

--- Reports on the prefix mappings `resolved_config`'s `prefix` names.
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
  for _, prefix_key in ipairs(PREFIX_KEYS) do
    check_prefix_key(resolved_config.prefix, prefix_key)
  end
  check_local_leader(resolved_config.prefix)
end

--- What the health check says of each reason `plugin/aineo.lua` records for
--- the autostart's decision: the `vim.health` function it reports with, and
--- its words.
---@type table<string, { level: 'ok'|'info'|'warn', text: string }>
local AUTOSTART_FINDINGS = {
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
  ['sourced-late'] = {
    level = 'info',
    text = 'the autostart did not run: aineo was loaded after startup, as a plugin manager that loads it lazily does',
  },
  ['open-failed'] = {
    level = 'warn',
    text = 'the autostart tried to open the layout and failed',
  },
  ['wrong-setting'] = {
    level = 'warn',
    text = 'the autostart did not run: a setting was wrong at startup',
  },
}

--- Reports what the autostart decided when the editor started, and why, from
--- the record `plugin/aineo.lua` keeps in `vim.g.aineo_startup`.
local function check_autostart()
  vim.health.start('Autostart')
  local record = vim.g.aineo_startup
  local finding = type(record) == 'table' and AUTOSTART_FINDINGS[record.reason]
  if not finding then
    vim.health.info(
      'no record of the autostart: plugin/aineo.lua did not run at startup (vim.g.loaded_aineo set before it, or --noplugin)'
    )
    return
  end
  vim.health[finding.level](finding.text .. (record.failure and ': ' .. record.failure or ''))
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
