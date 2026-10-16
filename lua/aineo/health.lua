--- aineo's health check, `:checkhealth aineo`. It reads the configuration
--- and the editor's state and reports on them, running only
--- `claude.cmd --version`; it starts no Claude session, opens no layout and
--- maps no key.

local claude = require('aineo.claude')
local config = require('aineo.config')

local M = {}

--- The position Lua puts before an error it raises: `<file>.lua:<line>: `
--- for Lua code loaded from a file, and `vim/<module>:<line>: ` for those of
--- Neovim's own modules that 0.12 names without the `.lua`
--- (`vim/_core/system`). The `[string "vim/<module>"]:<line>: ` form other
--- modules of 0.12 give (`vim/keymap`) is not stripped: none of them raises
--- inside the check.
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

--- The oldest Neovim aineo supports, as `has()` names a version.
local OLDEST_SUPPORTED_NEOVIM = '0.12'

--- Reports the version of the Neovim that runs the check (`vim.version()`),
--- or an error naming `OLDEST_SUPPORTED_NEOVIM` when that Neovim is older
--- than it.
local function check_neovim()
  vim.health.start('Neovim')
  if vim.fn.has('nvim-' .. OLDEST_SUPPORTED_NEOVIM) == 0 then
    vim.health.error(
      ('Neovim is older than %s, the oldest version aineo supports'):format(OLDEST_SUPPORTED_NEOVIM),
      ('Update Neovim to %s or later: :help aineo-install'):format(OLDEST_SUPPORTED_NEOVIM)
    )
    return
  end
  vim.health.ok('Neovim ' .. tostring(vim.version()))
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

--- Reports, when `command` gives Claude Code a `--settings`, whether aineo
--- can add its session hooks to them, read from the editor's working
--- directory as a start of Claude Code reads them
--- (`aineo.claude`'s `given_settings_verdict()`): a warning naming
--- why when it cannot.
---
---@param command string[] `claude.cmd`
local function check_claude_settings(command)
  local verdict = claude.given_settings_verdict(command, vim.fn.getcwd())
  if verdict == nil then
    return
  end
  if verdict.problem then
    vim.health.warn(
      "claude.cmd's --settings cannot take aineo's session hooks: " .. verdict.problem,
      "Claude Code starts with them as they are, without aineo's hooks, so a session switch inside it is not followed: :help aineo-config-claude.cmd"
    )
    return
  end
  vim.health.ok("claude.cmd's --settings takes aineo's session hooks")
end

--- Reports on the command that runs Claude Code, `claude.cmd`: an error when
--- its first word is not executable (`executable()`), in the words the
--- Claude session uses when it refuses to start; else the version it prints
--- (`check_claude_version()`) and what becomes of a `--settings` it gives
--- (`check_claude_settings()`).
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
  check_claude_settings(command)
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

--- Reports the 'shell' the terminal pane runs, and warns when its program
--- (`aineo.shell`'s `shell_program()`) is not executable (`executable()`), in
--- the words the shell home uses when it refuses to start.
local function check_shell()
  vim.health.start('Shell terminal')
  local shell = vim.o.shell
  local program = require('aineo.shell').shell_program()
  if vim.fn.executable(program) == 0 then
    vim.health.warn(
      ("'shell' is %s: '%s' is not executable, so the terminal pane cannot start a shell"):format(
        shell,
        program
      ),
      "Set 'shell' to a program that exists: :help 'shell'"
    )
    return
  end
  vim.health.ok(("the terminal pane runs 'shell': %s"):format(shell))
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

--- The keys that follow the prefix for each of aineo's actions, with the
--- `<Plug>` mapping each runs and the mode it is mapped in — `n`, Normal
--- mode, or `x`, Visual mode — in the order `plugin/aineo.lua` maps them.
--- Each `n` key but Send's also has a twin in Terminal and Insert mode
--- (`TERMINAL_MODES`).
local PREFIX_KEYS = {
  { key = 's', plug = '<Plug>(aineo-send)', mode = 'n' },
  { key = 'o', plug = '<Plug>(aineo-open)', mode = 'n' },
  { key = 'r', plug = '<Plug>(aineo-report)', mode = 'n' },
  { key = 'i', plug = '<Plug>(aineo-input)', mode = 'n' },
  { key = 'c', plug = '<Plug>(aineo-claude)', mode = 'n' },
  { key = 'tcn', plug = '<Plug>(aineo-claude-numbers)', mode = 'n' },
  { key = 'S', plug = '<Plug>(aineo-sessions)', mode = 'n' },
  { key = 'N', plug = '<Plug>(aineo-new)', mode = 'n' },
  { key = 'pa', plug = '<Plug>(aineo-pane-agent)', mode = 'n' },
  { key = 'g', plug = '<Plug>(aineo-pane-changes)', mode = 'n' },
  { key = 'pt', plug = '<Plug>(aineo-pane-terminal)', mode = 'n' },
  { key = 'T', plug = '<Plug>(aineo-tab-new)', mode = 'n' },
  { key = 'Q', plug = '<Plug>(aineo-tab-close)', mode = 'n' },
  { key = '1', plug = '<Plug>(aineo-tab-1)', mode = 'n' },
  { key = '2', plug = '<Plug>(aineo-tab-2)', mode = 'n' },
  { key = '3', plug = '<Plug>(aineo-tab-3)', mode = 'n' },
  { key = '4', plug = '<Plug>(aineo-tab-4)', mode = 'n' },
  { key = '5', plug = '<Plug>(aineo-tab-5)', mode = 'n' },
  { key = '6', plug = '<Plug>(aineo-tab-6)', mode = 'n' },
  { key = '7', plug = '<Plug>(aineo-tab-7)', mode = 'n' },
  { key = '8', plug = '<Plug>(aineo-tab-8)', mode = 'n' },
  { key = '9', plug = '<Plug>(aineo-tab-9)', mode = 'n' },
  { key = 's', plug = '<Plug>(aineo-send)', mode = 'x' },
}

--- The prefix keys that have no twin in Terminal and Insert mode, by their
--- `<Plug>` mapping: Send acts on a selection or on Normal mode's line.
local HAS_NO_TWIN = { ['<Plug>(aineo-send)'] = true }

--- The modes a twin is mapped in, with how the Terminal prefix mappings
--- section names each: Terminal mode first.
local TERMINAL_MODES = {
  { mode = 't', name = 'Terminal mode' },
  { mode = 'i', name = 'Insert mode' },
}

--- The keys a twin runs before its `<Plug>` mapping, by the mode it is
--- pressed in, to leave that mode for Normal mode (as `plugin/aineo.lua`'s
--- `LEAVE_MODE` maps them).
local LEAVE_MODE = { t = '<C-\\><C-n>', i = '<C-]><Esc>' }

--- How the Prefix mappings section names a key sequence in each mode it
--- maps: as it is in Normal mode, and followed by `in Visual mode` in
--- Visual mode.
local IN_MODE = { n = '%s', x = '%s in Visual mode' }

--- The keys `keys`, written as in a mapping, stand for when typed.
---
---@param keys string
---@return string
local function typed_keys(keys)
  return vim.api.nvim_replace_termcodes(keys, true, true, true)
end

--- The global mapping of `keys`, written as in a mapping, in `mode` — `n`,
--- `x`, `t` or `i` — if any, compared in both the forms Neovim records, as
--- `plugin/aineo.lua` compares them when it decides whether the user has
--- mapped a key.
---
---@param mode 'n'|'x'|'t'|'i'
---@param keys string
---@return table|nil mapping as `nvim_get_keymap()` gives it
local function global_mapping(mode, keys)
  local typed = typed_keys(keys)
  return vim.iter(vim.api.nvim_get_keymap(mode)):find(function(mapping)
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

--- Reports what `keys`, written as in a mapping and named `label` in the
--- report, runs in `mode`: ok when it runs `runs`, a warning when it runs
--- anything else or is not mapped at all. The warning tells the user to map
--- `plug`, the `<Plug>` mapping `runs` ends with, to a key of their own, or
--- gives `not_mapped_advice`.
---
---@param label string
---@param mode 'n'|'x'|'t'|'i'
---@param keys string
---@param runs string
---@param plug string
---@param not_mapped_advice string
local function check_key(label, mode, keys, runs, plug, not_mapped_advice)
  local mapping = global_mapping(mode, keys)
  if mapping == nil then
    vim.health.warn(('%s is not mapped'):format(label), not_mapped_advice)
  elseif typed_keys(mapping.rhs or '') == typed_keys(runs) then
    vim.health.ok(('%s runs %s'):format(label, runs))
  else
    vim.health.warn(
      ('%s runs %s, not %s'):format(label, what_mapping_runs(mapping), runs),
      ('aineo leaves a key you mapped alone; map %s to a key of your own: :help aineo-mappings'):format(
        plug
      )
    )
  end
end

--- Reports what the key sequence `prefix` followed by `prefix_key.key`
--- runs in `prefix_key.mode`, naming the mode when it is Visual mode
--- (`IN_MODE`): ok when it runs its `<Plug>` mapping, `prefix_key.plug`, a
--- warning when it runs anything else or is not mapped at all.
---
---@param prefix string
---@param prefix_key { key: string, plug: string, mode: 'n'|'x' }
local function check_prefix_key(prefix, prefix_key)
  check_key(
    IN_MODE[prefix_key.mode]:format(prefix .. prefix_key.key),
    prefix_key.mode,
    prefix .. prefix_key.key,
    prefix_key.plug,
    prefix_key.plug,
    'aineo maps its keys once, when the editor has started; a prefix changed or a key unmapped since stays so until the next start: :help aineo-config-prefix'
  )
end

--- Reports what the key sequence `terminal_prefix` followed by
--- `prefix_key.key` runs in `terminal_mode.mode`, Terminal or Insert mode:
--- ok when it runs the keys that leave that mode (`LEAVE_MODE`) and then
--- `prefix_key.plug`, a warning when it runs anything else or is not mapped
--- at all.
---
---@param terminal_prefix string
---@param prefix_key { key: string, plug: string }
---@param terminal_mode { mode: 't'|'i', name: string }
local function check_terminal_key(terminal_prefix, prefix_key, terminal_mode)
  local keys = terminal_prefix .. prefix_key.key
  check_key(
    ('%s in %s'):format(keys, terminal_mode.name),
    terminal_mode.mode,
    keys,
    LEAVE_MODE[terminal_mode.mode] .. prefix_key.plug,
    prefix_key.plug,
    'aineo maps its keys once, when the editor has started; a terminal_prefix changed or a key unmapped since stays so until the next start: :help aineo-config-terminal_prefix'
  )
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
    text = "the autostart did not run: this Neovim runs inside aineo's own Claude terminal or shell terminal ($AINEO_CHILD is set)",
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

--- What the Terminal prefix mappings section says in place of a line per key
--- while aineo's record (`startup_record()`) says it has not mapped them yet,
--- by the record's reason.
local TERMINAL_PREFIX_KEYS_PENDING = {
  starting = 'the terminal prefix keys are not mapped: aineo maps them from its VimEnter handler, which has not run — the editor is still starting, or a VimEnter autocommand before it threw an exception',
  ['mapping-late'] = 'the terminal prefix keys are not mapped yet: aineo was loaded after startup, and maps them in the next event-loop tick',
}

--- The numbers of the buffers that have a mapping of `keys`, written as in
--- a mapping, local to them in `mode`.
---
---@param mode 't'|'i'
---@param keys string
---@return integer[]
local function buffers_mapping(mode, keys)
  local typed = typed_keys(keys)
  return vim.tbl_filter(function(buffer)
    return vim.iter(vim.api.nvim_buf_get_keymap(buffer, mode)):any(function(mapping)
      return mapping.lhsraw == typed or mapping.lhsrawalt == typed
    end)
  end, vim.api.nvim_list_bufs())
end

--- Warns of each mode in `TERMINAL_MODES` where `terminal_prefix` alone is
--- mapped: globally, so that aineo maps no twin there, and local to
--- buffers, so that the key waits for 'timeoutlen' and a twin's letter typed
--- then runs aineo's action. Returns the modes aineo maps no twin in.
---
---@param terminal_prefix string
---@return table<string, boolean> skipped
local function check_terminal_prefix_mapped_alone(terminal_prefix)
  local skipped = {}
  for _, terminal_mode in ipairs(TERMINAL_MODES) do
    if global_mapping(terminal_mode.mode, terminal_prefix) then
      skipped[terminal_mode.mode] = true
      vim.health.warn(
        ('%s is mapped in %s: aineo maps no twin there'):format(terminal_prefix, terminal_mode.name),
        'A key you mapped alone makes the twins ambiguous with it, and aineo leaves it yours; set terminal_prefix to another key to have twins in that mode: :help aineo-terminal-keys'
      )
    end
    local buffers = buffers_mapping(terminal_mode.mode, terminal_prefix)
    if #buffers > 0 then
      vim.health.warn(
        ("%s is mapped in %s, local to buffers %s: it waits for 'timeoutlen', and a twin's letter typed then runs aineo's action"):format(
          terminal_prefix,
          terminal_mode.name,
          table.concat(buffers, ', ')
        ),
        'Set terminal_prefix to another key, or map the keys of your buffer yourself: :help aineo-terminal-keys'
      )
    end
  end
  return skipped
end

--- Warns when `terminal_prefix` is a printable key, which Insert mode would
--- run twins on while typing, or starts with `<C-\><C-n>` or `<C-\><C-o>`,
--- which Neovim would then no longer act on at once.
---
---@param terminal_prefix string
local function check_terminal_prefix_risks(terminal_prefix)
  local typed = typed_keys(terminal_prefix)
  if typed:match('^[%g ]$') then
    vim.health.warn(
      ('terminal_prefix is %s, a printable key: typing it in Insert mode runs a twin'):format(
        terminal_prefix
      ),
      'Choose a key with a modifier, such as <C-\\>: :help aineo-config-terminal_prefix'
    )
  end
  for _, neovims in ipairs({ typed_keys('<C-\\><C-n>'), typed_keys('<C-\\><C-o>') }) do
    if vim.startswith(typed, neovims) then
      vim.health.warn(
        ('terminal_prefix %s starts with a key pair of Neovim: it waits for the next key'):format(
          terminal_prefix
        ),
        "Neovim's own <C-\\><C-n> and <C-\\><C-o> would no longer act at once: :help aineo-config-terminal_prefix"
      )
      return
    end
  end
end

--- Reports on the twins of the prefix keys `resolved_config`'s
--- `terminal_prefix` names, in Terminal and Insert mode: a warning for each
--- mode where `terminal_prefix` alone is mapped
--- (`check_terminal_prefix_mapped_alone()`), then each key in each mode
--- aineo maps twins in — or, while aineo's record says it has not mapped
--- them yet, one line saying why (`TERMINAL_PREFIX_KEYS_PENDING`) — then the
--- risks of the prefix (`check_terminal_prefix_risks()`).
---
---@param resolved_config table|nil the configuration, `nil` when it is wrong
local function check_terminal_prefix_mappings(resolved_config)
  vim.health.start('Terminal prefix mappings')
  if resolved_config == nil then
    vim.health.info('the terminal prefix mappings are not checked while the configuration is wrong')
    return
  end
  local terminal_prefix = resolved_config.terminal_prefix
  if terminal_prefix == false then
    vim.health.info('terminal_prefix is false: aineo maps no key in Terminal and Insert mode')
    return
  end
  local record = startup_record()
  local pending = record and TERMINAL_PREFIX_KEYS_PENDING[record.reason]
  if pending then
    vim.health.info(pending)
    return
  end
  local skipped = check_terminal_prefix_mapped_alone(terminal_prefix)
  for _, prefix_key in ipairs(PREFIX_KEYS) do
    if prefix_key.mode == 'n' and not HAS_NO_TWIN[prefix_key.plug] then
      for _, terminal_mode in ipairs(TERMINAL_MODES) do
        if not skipped[terminal_mode.mode] then
          check_terminal_key(terminal_prefix, prefix_key, terminal_mode)
        end
      end
    end
  end
  check_terminal_prefix_risks(terminal_prefix)
end

--- What a 'tabline' that is aineo's begins with: the expression `aineo.tabs`
--- sets (`draw_tabline()`), which health does not require.
local AINEO_TABLINE_PREFIX = "%!v:lua.require'aineo.tabs'."

--- The values Claude Code 2.1.301 reads as true in a variable that is a flag,
--- compared in lower case and without surrounding white space.
local CLAUDE_CODE_TRUE_VALUES = { '1', 'true', 'yes', 'on' }

--- Whether `value`, a variable's value, is true as Claude Code reads a flag:
--- `1`, `true`, `yes` or `on`, in any case, with white space around it.
---
---@param value string
---@return boolean
local function is_claude_code_flag_on(value)
  return vim.tbl_contains(CLAUDE_CODE_TRUE_VALUES, vim.trim(value):lower())
end

--- Whether `value`, a variable's value, is more than white space: Claude
--- Code 2.1.301 reads a blank value as the variable being unset.
---
---@param value string
---@return boolean
local function is_not_blank(value)
  return vim.trim(value) ~= ''
end

--- The variables of the editor's environment under which Claude Code gives
--- its terminal no title, or keeps it still, so that no tab shows activity
--- (the activity indicator of `aineo.tabs` reads that title): what each
--- means, what the user can do, which of its values Claude Code acts on
--- (read from its 2.1.301 binary, not run), and whether aineo hides it from
--- Claude Code while `claude.hide_multiplexer` holds. A variable Neovim holds
--- is handed to every job it starts, Claude Code's included, except where
--- aineo hides it.
local SILENT_TITLE_VARIABLES = {
  {
    name = 'CLAUDE_CODE_DISABLE_TERMINAL_TITLE',
    is_acted_on = is_claude_code_flag_on,
    meaning = 'Claude Code sets no terminal title',
    advice = 'unset CLAUDE_CODE_DISABLE_TERMINAL_TITLE before starting Neovim',
  },
  {
    name = 'TMUX',
    is_hidden_by_aineo = true,
    is_acted_on = is_not_blank,
    meaning = 'Claude Code keeps its terminal title still under a terminal multiplexer',
    advice = 'set claude.hide_multiplexer to true, or start Neovim outside tmux, screen and zellij',
  },
  {
    name = 'STY',
    is_hidden_by_aineo = true,
    is_acted_on = is_not_blank,
    meaning = 'Claude Code keeps its terminal title still under a terminal multiplexer',
    advice = 'set claude.hide_multiplexer to true, or start Neovim outside tmux, screen and zellij',
  },
  {
    name = 'ZELLIJ',
    is_hidden_by_aineo = true,
    is_acted_on = is_not_blank,
    meaning = 'Claude Code keeps its terminal title still under a terminal multiplexer',
    advice = 'set claude.hide_multiplexer to true, or start Neovim outside tmux, screen and zellij',
  },
}

--- Says what the activity indicator on a tab reads and, while
--- `resolved_config.claude.hide_multiplexer` holds, that aineo starts Claude
--- Code without the multiplexer's variables; and warns, naming the variable,
--- for each of `SILENT_TITLE_VARIABLES` the editor's environment holds with a
--- value Claude Code acts on, and aineo does not hide: no tab shows activity
--- then.
---
---@param resolved_config table|nil the configuration, `nil` when it is wrong
local function check_activity_indicator(resolved_config)
  vim.health.info(
    'the activity indicator on a tab reads the title Claude Code sets on its terminal: :help aineo-tabs'
  )
  local is_hiding = resolved_config ~= nil and resolved_config.claude.hide_multiplexer
  if is_hiding then
    vim.health.info(
      'aineo starts Claude Code without TMUX, TMUX_PANE, STY and ZELLIJ (claude.hide_multiplexer), so the activity indicator works inside tmux, screen and zellij: :help aineo-limits'
    )
  end
  for _, variable in ipairs(SILENT_TITLE_VARIABLES) do
    local value = vim.env[variable.name]
    local is_hidden = is_hiding and variable.is_hidden_by_aineo
    if not is_hidden and value ~= nil and variable.is_acted_on(value) then
      vim.health.warn(
        ('%s is set: %s, so no tab shows activity'):format(variable.name, variable.meaning),
        ('%s for the tabs to show activity: :help aineo-limits'):format(variable.advice)
      )
    end
  end
end

--- Reports which tab line is in use: aineo's, which it draws while the user's
--- 'tabline' is empty when the first aineo tab opens; the user's own, which
--- aineo leaves in place; or Neovim's own, before aineo has drawn its own.
--- Then what the activity indicator reads (`check_activity_indicator()`).
---
---@param resolved_config table|nil the configuration, `nil` when it is wrong
local function check_tab_line(resolved_config)
  vim.health.start('Tab line')
  local tabline = vim.o.tabline
  if vim.startswith(tabline, AINEO_TABLINE_PREFIX) then
    vim.health.ok(
      'aineo draws the tab line: each tab shows its place and, for an aineo tab, its session’s name'
    )
  elseif tabline ~= '' then
    vim.health.info(
      ("the tab line is yours ('tabline' is %s): aineo draws none; require('aineo').tab_title({n}) gives the title it would draw for a tab page: :help aineo-tabs"):format(
        tabline
      )
    )
  else
    vim.health.info(
      "the tab line is Neovim's own: aineo draws its own when the first aineo tab opens, while 'tabline' is empty: :help aineo-tabs"
    )
  end
  check_activity_indicator(resolved_config)
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
  check_neovim()
  local resolved_config = check_configuration()
  check_claude(resolved_config)
  check_shell()
  check_server_socket()
  check_prefix_mappings(resolved_config)
  check_terminal_prefix_mappings(resolved_config)
  check_tab_line(resolved_config)
  check_autostart()
  name_limits()
end

return M
