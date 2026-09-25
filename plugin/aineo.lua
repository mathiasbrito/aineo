--- aineo's composition root, sourced by Neovim at every startup: `:Aineo`, the
--- `<Plug>(aineo-…)` mappings, and, once the editor has started, the prefix
--- mappings and the autostart. It stays cheap: sourcing it requires no aineo
--- module; once the editor has started it loads the configuration alone, to
--- read the prefix and `autostart`, and the other homes load when a command,
--- a mapping or the autostart first needs them.
---
--- The prefix is mapped, and the autostart decided, from the configuration
--- as it stands when the editor has started (`VimEnter`) — after the user's
--- init, and so after a plugin manager has run `setup()`. When this file is
--- sourced later, the prefix is mapped in the first scheduled callback after
--- it, once the plugin manager that sourced it has run `setup()` in the same
--- tick, as lazy.nvim does, and nothing starts by itself.
---
--- It runs once. Setting `vim.g.loaded_aineo` before startup turns it off, and
--- sourcing it again does nothing.

if vim.g.loaded_aineo then
  return
end
vim.g.loaded_aineo = true

--- `:Aineo`'s subcommands, in the order it offers them.
local SUBCOMMANDS = { 'send', 'open', 'report', 'input', 'claude' }

--- What `:Aineo` tells the user when it is not given one of its subcommands.
local USAGE = 'aineo: :Aineo takes one of ' .. table.concat(SUBCOMMANDS, ', ')

--- The subcommands that begin with `argument_lead`, what the user has typed
--- of `:Aineo`'s argument.
---
---@param argument_lead string
---@return string[]
local function complete_subcommand(argument_lead)
  return vim.tbl_filter(function(subcommand)
    return vim.startswith(subcommand, argument_lead)
  end, SUBCOMMANDS)
end

--- aineo's configuration, resolved from `vim.g.aineo` and the options
--- `require('aineo').setup()` recorded (`aineo.config`'s `resolve_config()`).
--- Raises its error naming the setting that is wrong.
---
---@return table
local function resolved_config()
  local config = require('aineo.config')
  return (config.resolve_config(vim.g.aineo, config.recorded_setup_options()))
end

--- Whether the report home has been given its environment yet.
local report_environment_given = false

--- Gives the report home the editor's clock, state directory and working
--- directory, the first time only.
local function give_report_environment()
  if report_environment_given then
    return
  end
  require('aineo.report').set_report_environment({
    clock = function()
      return os.date('%Y-%m-%dT%H:%M:%S')
    end,
    state_directory = vim.fn.stdpath('state'),
    working_directory = vim.fn.getcwd(),
  })
  report_environment_given = true
end

--- The terminal of the Claude session aineo started last, or `nil` before
--- it has started one.
---@type integer|nil
local claude_terminal = nil

--- Starts the Claude session with `config` when none runs — a new one once
--- the last has exited — and returns its terminal, which it keeps as
--- `claude_terminal`. While one runs it starts nothing and returns that
--- session's terminal (`aineo.claude`'s `start_session()`).
---
---@param config table the resolved configuration
---@return integer terminal
local function started_claude_terminal(config)
  local report = require('aineo.report')
  local mcp = require('aineo.mcp')
  claude_terminal = require('aineo.claude').start_session({
    cmd = config.claude.cmd,
    cwd = vim.fn.getcwd(),
    mcp_servers = mcp.mcp_servers(vim.v.servername, vim.v.progpath),
    allowed_tools = mcp.allowed_mcp_tools(),
    instructions = report.report_instructions(mcp.report_tool_name()),
  })
  return claude_terminal
end

--- The terminal of the Claude session as it is, running or exited, while it
--- exists; else — before any session has started, or once its terminal has
--- been wiped — the terminal of a session started with `config`.
---
---@param config table the resolved configuration
---@return integer terminal
local function current_claude_terminal(config)
  if claude_terminal and vim.api.nvim_buf_is_valid(claude_terminal) then
    return claude_terminal
  end
  return started_claude_terminal(config)
end

--- The buffers aineo's layout shows: `claude_buffer`, the Claude session's
--- terminal, and the Report, taken from the report home, which this gives
--- its environment the first time it is called (`give_report_environment()`);
--- with the Report's share from `config`.
---
---@param config table the resolved configuration
---@param claude_buffer integer
---@return aineo.layout.Arrangement
local function arrangement(config, claude_buffer)
  give_report_environment()
  return {
    claude = claude_buffer,
    report = require('aineo.report').report_buffer(),
    report_height = config.layout.report_height,
  }
end

--- Opens aineo's layout around the Claude session, starting it when none
--- runs — a new one once the last has exited — or restores the layout while
--- it is open. The session's terminal is shown in the tick it starts in
--- (`aineo.claude`'s `start_session()`).
local function open()
  local config = resolved_config()
  require('aineo.layout').open(arrangement(config, started_claude_terminal(config)))
end

--- Moves the cursor to the layout's window for `role`. When that window is
--- gone it opens the layout first, as `open()` does, but around the Claude
--- session's terminal as it is, the exit on screen when Claude Code has
--- exited: a focus starts a session only when the layout must open and
--- there is no terminal to show (`current_claude_terminal()`).
---
---@param role aineo.layout.Role
local function focus(role)
  local config = resolved_config()
  require('aineo.layout').focus(role, function()
    return arrangement(config, current_claude_terminal(config))
  end)
end

--- What each of `:Aineo`'s subcommands does.
---@type table<string, fun()>
local ACTIONS = {
  send = function()
    require('aineo.send').send()
  end,
  open = open,
  report = function()
    focus('report')
  end,
  input = function()
    focus('input')
  end,
  claude = function()
    focus('claude')
  end,
}

--- What Neovim puts before an error it passes on, outermost first: the
--- words it wraps an error raised in a Lua callback in, the
--- `<file>.lua:<line>: ` position of the Lua code that raised it, and the
--- mark of an error a Vim function raised.
local ERROR_FRAMING = { '^Error executing lua: ', '^.-%.lua:%d+: ', '^Vim:' }

--- The error `message` tells, on one line: its first line, without the
--- stack traceback that may follow it and without what Neovim put before it
--- (`ERROR_FRAMING`).
---
---@param message string
---@return string
local function error_line(message)
  local line = message:match('^[^\n]*')
  for _, framing in ipairs(ERROR_FRAMING) do
    line = line:gsub(framing, '')
  end
  return line
end

--- Runs `action`, and tells the user once, with one error notification, the
--- error it raises.
---
---@param action fun()
local function run(action)
  local succeeded, failure = pcall(action)
  if not succeeded then
    vim.notify('aineo: ' .. error_line(tostring(failure)), vim.log.levels.ERROR)
  end
end

--- The `<Plug>` mapping that does what the subcommand `subcommand` does.
---
---@param subcommand string
---@return string
local function plug_mapping(subcommand)
  return ('<Plug>(aineo-%s)'):format(subcommand)
end

for _, subcommand in ipairs(SUBCOMMANDS) do
  vim.keymap.set('n', plug_mapping(subcommand), function()
    run(ACTIONS[subcommand])
  end, { desc = 'aineo: ' .. subcommand })
end

--- The key that follows the prefix for each subcommand.
local PREFIX_KEYS = { send = 's', open = 'o', report = 'r', input = 'i', claude = 'c' }

--- Whether `keys`, written as in a mapping, have a global Normal-mode
--- mapping. A mapping local to a buffer does not count: it wins in its own
--- buffer only. A mapping's keys are compared in both the forms Neovim
--- records: `lhsraw`, and `lhsrawalt`, where a Ctrl key such as `<C-a>` has
--- the one byte `nvim_replace_termcodes()` gives it.
---
---@param keys string
---@return boolean
local function has_global_mapping(keys)
  local typed = vim.api.nvim_replace_termcodes(keys, true, true, true)
  return vim.iter(vim.api.nvim_get_keymap('n')):any(function(mapping)
    return mapping.lhsraw == typed or mapping.lhsrawalt == typed
  end)
end

--- Maps `prefix` followed by each subcommand's key, in Normal mode, to the
--- subcommand's `<Plug>` mapping, but for each key sequence the user has
--- mapped globally already; maps nothing when `prefix` is `false`.
---
---@param prefix string|false
local function map_prefix(prefix)
  if prefix == false then
    return
  end
  for _, subcommand in ipairs(SUBCOMMANDS) do
    local keys = prefix .. PREFIX_KEYS[subcommand]
    if not has_global_mapping(keys) then
      vim.keymap.set('n', keys, plug_mapping(subcommand), { desc = 'aineo: ' .. subcommand })
    end
  end
end

--- Whether Neovim read its standard input into a buffer as it started
--- (`StdinReadPost`), as `echo text | nvim` does.
local read_stdin = false

--- A short option that gives the editor something to do besides edit, alone
--- or after other short options in one argument, its value attached or not
--- (`-c`, `-clet x = 1`, `-Rc`): `-c` a command to run, `-S` a session to
--- restore, `-e` Ex mode, `-E` improved Ex mode, `-s` keys to type from a
--- script.
local TASK_OPTION = '^%-%a*[cSesE]'

--- Whether the editor was started with something to do besides edit: a
--- `TASK_OPTION`, or a command given as `+…`. The value of an option such
--- as `--cmd` counts too when it looks like one.
---
---@param argv string[] the editor's start arguments, `v:argv`
---@return boolean
local function has_startup_task(argv)
  return vim.iter(argv):skip(1):any(function(argument)
    return argument:match(TASK_OPTION) ~= nil or vim.startswith(argument, '+')
  end)
end

--- Whether the editor has started as a bare, interactive `nvim`: with a user
--- interface attached, no file to edit, its standard input not read and
--- nothing else to do (`has_startup_task()`) — and not inside aineo's own
--- Claude terminal, which sets `$AINEO_CHILD`.
---
---@return boolean
local function is_bare_interactive_start()
  return #vim.api.nvim_list_uis() > 0
    and vim.fn.argc() == 0
    and not read_stdin
    and not has_startup_task(vim.v.argv)
    and vim.env.AINEO_CHILD == nil
end

--- Opens the layout as `open()` does, unless a session has been restored
--- (`v:this_session` is set), as a plugin such as auto-session or
--- persistence.nvim restores one from its own `VimEnter` autocommand: the
--- session's windows are the user's to keep.
local function open_unless_session_restored()
  if vim.v.this_session == '' then
    run(open)
  end
end

--- Opens the layout as `open_unless_session_restored()` does, once a
--- startup dashboard has shown: two scheduled callbacks after the one that
--- calls this at `VimEnter`, so after whatever the `VimEnter` and `UIEnter`
--- autocommands show, directly or from a callback they schedule —
--- snacks.nvim's, alpha's, dashboard-nvim's and mini.starter's dashboards
--- among them. The layout then replaces the dashboard's window.
local function open_after_dashboards()
  vim.schedule(function()
    vim.schedule(open_unless_session_restored)
  end)
end

--- What the editor does once it has started: maps the prefix the
--- configuration names, and opens the layout when `autostart` is set and the
--- start is bare and interactive (`open_after_dashboards()`).
local function start_up()
  local config = resolved_config()
  map_prefix(config.prefix)
  if config.autostart and is_bare_interactive_start() then
    open_after_dashboards()
  end
end

if vim.v.vim_did_enter == 1 then
  vim.schedule(function()
    run(function()
      map_prefix(resolved_config().prefix)
    end)
  end)
else
  local group = vim.api.nvim_create_augroup('aineo', {})
  vim.api.nvim_create_autocmd('StdinReadPost', {
    group = group,
    once = true,
    callback = function()
      read_stdin = true
    end,
  })
  vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    once = true,
    callback = function()
      run(start_up)
    end,
  })
end

vim.api.nvim_create_user_command('Aineo', function(command)
  local action = ACTIONS[command.args]
  if action then
    run(action)
    return
  end
  vim.notify(USAGE, vim.log.levels.ERROR)
end, {
  nargs = '?',
  bar = true,
  complete = complete_subcommand,
  desc = 'aineo: send, open, report, input or claude',
})
