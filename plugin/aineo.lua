--- aineo's composition root, sourced by Neovim at every startup: `:Aineo`, the
--- `<Plug>(aineo-…)` mappings, and, once the editor has started, the prefix
--- mappings. It stays cheap: sourcing it requires no aineo module; once the
--- editor has started it loads the configuration alone, to read the prefix,
--- and the other homes load when a command or mapping first needs them.
---
--- The prefix is mapped from the configuration as it stands when the editor
--- has started (`VimEnter`) — after the user's init, and so after a plugin
--- manager has run `setup()` — or, when this file is sourced later, in the
--- first scheduled callback after it, once the plugin manager that sourced it
--- has run `setup()` in the same tick, as lazy.nvim does.
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

--- The buffers aineo's layout shows, taken from the homes that own them —
--- the Report, and the terminal of the Claude session, which this starts
--- when none runs — with the Report's share from `config`.
---
---@param config table the resolved configuration
---@return aineo.layout.Arrangement
local function arrangement(config)
  local report = require('aineo.report')
  local mcp = require('aineo.mcp')
  give_report_environment()
  local report_buffer = report.report_buffer()
  local claude_buffer = require('aineo.claude').start_session({
    cmd = config.claude.cmd,
    cwd = vim.fn.getcwd(),
    mcp_servers = mcp.mcp_servers(vim.v.servername, vim.v.progpath),
    allowed_tools = mcp.allowed_mcp_tools(),
    instructions = report.report_instructions(mcp.report_tool_name()),
  })
  return {
    claude = claude_buffer,
    report = report_buffer,
    report_height = config.layout.report_height,
  }
end

--- Opens aineo's layout around the Claude session, starting it when none
--- runs, or restores the layout while it is open. The session's terminal is
--- shown in the tick it starts in (`aineo.claude`'s `start_session()`).
local function open()
  require('aineo.layout').open(arrangement(resolved_config()))
end

--- Moves the cursor to the layout's window for `role`, opening the layout
--- first, as `open()` does, when that window is gone.
---
---@param role aineo.layout.Role
local function focus(role)
  require('aineo.layout').focus(role, arrangement(resolved_config()))
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

--- `message` without the position a Lua error prefixes it with, the
--- `<file>.lua:<line>: ` of the code that raised it.
---
---@param message string
---@return string
local function without_position(message)
  return (message:gsub('^.-%.lua:%d+: ', ''))
end

--- Runs `action`, and tells the user once, with one error notification, the
--- error it raises.
---
---@param action fun()
local function run(action)
  local succeeded, failure = pcall(action)
  if not succeeded then
    vim.notify('aineo: ' .. without_position(tostring(failure)), vim.log.levels.ERROR)
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

--- Maps `prefix` followed by each subcommand's key, in Normal mode, to the
--- subcommand's `<Plug>` mapping, but for each key sequence the user has
--- mapped already; maps nothing when `prefix` is `false`.
---
---@param prefix string|false
local function map_prefix(prefix)
  if prefix == false then
    return
  end
  for _, subcommand in ipairs(SUBCOMMANDS) do
    local keys = prefix .. PREFIX_KEYS[subcommand]
    if vim.fn.maparg(keys, 'n') == '' then
      vim.keymap.set('n', keys, plug_mapping(subcommand), { desc = 'aineo: ' .. subcommand })
    end
  end
end

--- What the editor does once it has started: maps the prefix the
--- configuration names.
local function start_up()
  map_prefix(resolved_config().prefix)
end

if vim.v.vim_did_enter == 1 then
  vim.schedule(function()
    run(start_up)
  end)
else
  vim.api.nvim_create_autocmd('VimEnter', {
    group = vim.api.nvim_create_augroup('aineo', {}),
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
  complete = complete_subcommand,
  desc = 'aineo: send, open, report, input or claude',
})
