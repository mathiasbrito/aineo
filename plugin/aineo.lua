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
--- What the autostart decided, and why, is recorded in the editor variable
--- `vim.g.aineo_startup` for `:checkhealth aineo` to report.
---
--- It runs once. Setting `vim.g.loaded_aineo` before startup turns it off, and
--- sourcing it again does nothing.

if vim.g.loaded_aineo then
  return
end
vim.g.loaded_aineo = true

--- `:Aineo`'s subcommands, in the order it offers them.
local SUBCOMMANDS = { 'send', 'open', 'report', 'input', 'claude', 'claude-numbers', 'pane' }

--- The words each subcommand that takes one is followed by, in the order
--- `:Aineo` offers them: `pane` takes the pane to show.
local SUBCOMMAND_WORDS = { pane = { 'agent', 'changes' } }

--- What `:Aineo` tells the user when it is not given one of its subcommands.
local USAGE = 'aineo: :Aineo takes one of ' .. table.concat(SUBCOMMANDS, ', ')

--- What `:Aineo` tells the user when `words`, its arguments, run no action:
--- for a subcommand that takes words (`SUBCOMMAND_WORDS`), which ones it
--- takes, and `USAGE` otherwise.
---
---@param words string[]
---@return string
local function usage(words)
  local subcommand_words = SUBCOMMAND_WORDS[words[1]]
  if not subcommand_words then
    return USAGE
  end
  return ('aineo: :Aineo %s takes one of %s'):format(words[1], table.concat(subcommand_words, ', '))
end

--- `:Aineo`'s arguments that each run an action, in `SUBCOMMANDS`' order:
--- each subcommand alone, or followed by each of its words
--- (`SUBCOMMAND_WORDS`), as `pane agent`.
local ACTION_ARGUMENTS = vim
  .iter(SUBCOMMANDS)
  :map(function(subcommand)
    local words = SUBCOMMAND_WORDS[subcommand]
    if not words then
      return { subcommand }
    end
    return vim.tbl_map(function(word)
      return subcommand .. ' ' .. word
    end, words)
  end)
  :flatten()
  :totable()

--- The words `:Aineo` offers after `typed`, the words before the one the
--- cursor is in, the command's name first: its subcommands after the name
--- alone, the words of a subcommand that takes them (`SUBCOMMAND_WORDS`)
--- after that subcommand, and nothing otherwise.
---
---@param typed string[]
---@return string[]
local function offered_words(typed)
  if #typed == 1 then
    return SUBCOMMANDS
  end
  if #typed == 2 then
    return SUBCOMMAND_WORDS[typed[2]] or {}
  end
  return {}
end

--- What `:Aineo` completes the word the cursor is in to: the words it offers
--- there (`offered_words()`) that begin with `argument_lead`, what the user
--- has typed of that word. The words before it are read from `command_line`
--- up to `cursor_position`.
---
---@param argument_lead string
---@param command_line string
---@param cursor_position integer
---@return string[]
local function complete_subcommand(argument_lead, command_line, cursor_position)
  local before = command_line:sub(1, cursor_position - #argument_lead)
  local typed = vim.split(before, '%s+', { trimempty = true })
  return vim.tbl_filter(function(word)
    return vim.startswith(word, argument_lead)
  end, offered_words(typed))
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

--- Where aineo keeps what it keeps for a working directory — the Reports
--- and Input's draft — once `kept_places()` has taken it.
---@type { state_directory: string, working_directory: string }|nil
local places = nil

--- The editor's state directory and working directory, as they are the
--- first time this is called: the Reports and Input's draft are kept there,
--- for that directory, whatever `:cd` does later.
---
---@return { state_directory: string, working_directory: string }
local function kept_places()
  places = places
    or { state_directory = vim.fn.stdpath('state'), working_directory = vim.fn.getcwd() }
  return places
end

--- Whether the report home has been given its environment yet.
local report_environment_given = false

--- Gives the report home the editor's clock, and the state directory and
--- working directory of `kept_places()`, the first time only.
local function give_report_environment()
  if report_environment_given then
    return
  end
  require('aineo.report').set_report_environment({
    clock = function()
      return os.date('%Y-%m-%dT%H:%M:%S')
    end,
    state_directory = kept_places().state_directory,
    working_directory = kept_places().working_directory,
  })
  report_environment_given = true
end

--- Whether the draft home has been given its environment yet.
local draft_environment_given = false

--- Hands the layout's Input to the draft home, which keeps its text as the
--- draft of the working directory of `kept_places()` and restores that
--- draft into it when it is new and empty (`aineo.draft`'s `keep_draft()`);
--- gives the draft home that environment the first time. Raises nothing.
local function keep_input_draft()
  local draft = require('aineo.draft')
  if not draft_environment_given then
    draft.set_draft_environment(kept_places())
    draft_environment_given = true
  end
  draft.keep_draft(require('aineo.layout').input_buffer())
end

--- The terminal of the Claude session aineo started last — the new
--- session's once one took the place of a resume Claude Code found no
--- conversation for — or `nil` before it has started one.
---@type integer|nil
local claude_terminal = nil

--- Starts Claude Code with `config` when none runs — again once the last
--- has exited — and returns its terminal, which it keeps as
--- `claude_terminal`. While one runs it starts nothing and returns that
--- session's terminal (`aineo.claude`'s `start_session()`). Claude Code
--- starts in the editor's working directory, resuming the session kept for
--- it under the state directory of `kept_places()`. When the session puts a
--- new terminal in place of one whose resume found no conversation, that
--- terminal becomes `claude_terminal` and the layout's Claude terminal
--- (`aineo.layout`'s `follow_claude_terminal()`).
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
    state_directory = kept_places().state_directory,
    on_terminal_replaced = function(terminal)
      claude_terminal = terminal
      require('aineo.layout').follow_claude_terminal(terminal)
    end,
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

--- What the changes pane's two windows show until aineo lists the
--- session's changes there: for each, the name of its buffer, which is no
--- file path, and the one line it holds, which says the window shows
--- nothing yet and claims nothing about the repository.
local CHANGES_PLACEHOLDERS = {
  files = {
    name = 'aineo://changes-files',
    line = "aineo does not list the session's changed files here yet",
  },
  commits = {
    name = 'aineo://changes-commits',
    line = "aineo does not list the session's commits here yet",
  },
}

--- The changes pane's buffers `changes_pane()` made, by window.
---@type { files: integer|nil, commits: integer|nil }
local changes_buffers = {}

--- A new buffer holding `placeholder`'s line under its name: a scratch
--- buffer, as the Report is — no file, unlisted, kept when hidden, no swap
--- file — and not modifiable, written whatever `'modifiable'` a new buffer
--- gets, as under `nvim -M`.
---
---@param placeholder { name: string, line: string }
---@return integer buffer
local function placeholder_buffer(placeholder)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buffer, placeholder.name)
  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, 0, -1, true, { placeholder.line })
  vim.bo[buffer].modifiable = false
  return buffer
end

--- Whether `buffer`, a placeholder `changes_pane()` made, still holds its
--- line: it was neither wiped nor unloaded, as `:bdelete` unloads it,
--- emptied and no longer a scratch buffer.
---
---@param buffer integer|nil
---@return boolean
local function holds_placeholder(buffer)
  return buffer ~= nil and vim.api.nvim_buf_is_loaded(buffer)
end

--- The changes pane's two buffers, each made once (`placeholder_buffer()`)
--- and made anew once it no longer holds its line (`holds_placeholder()`),
--- an unloaded one wiped first so that the new one can take its name.
---
---@return aineo.layout.ChangesPane
local function changes_pane()
  for window, placeholder in pairs(CHANGES_PLACEHOLDERS) do
    local buffer = changes_buffers[window]
    if not holds_placeholder(buffer) then
      if buffer and vim.api.nvim_buf_is_valid(buffer) then
        vim.api.nvim_buf_delete(buffer, { force = true })
      end
      changes_buffers[window] = placeholder_buffer(placeholder)
    end
  end
  return { files = changes_buffers.files, commits = changes_buffers.commits }
end

--- The buffers aineo's layout shows: `claude_buffer`, the Claude session's
--- terminal, the Report, taken from the report home, which this gives its
--- environment the first time it is called (`give_report_environment()`),
--- and the changes pane's (`changes_pane()`); with the Report's share from
--- `config`.
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
    changes = changes_pane(),
  }
end

--- Opens aineo's layout around the Claude session, starting it when none
--- runs — a new one once the last has exited — or restores the layout while
--- it is open. The session's terminal is shown in the tick it starts in
--- (`aineo.claude`'s `start_session()`). Input is then handed to the draft
--- home (`keep_input_draft()`).
local function open()
  local config = resolved_config()
  require('aineo.layout').open(arrangement(config, started_claude_terminal(config)))
  keep_input_draft()
end

--- Moves the cursor to the layout's window for `role`. When that window is
--- gone it opens the layout first, as `open()` does, but around the Claude
--- session's terminal as it is, the exit on screen when Claude Code has
--- exited: a focus starts a session only when the layout must open and
--- there is no terminal to show (`current_claude_terminal()`). When it
--- reopened the role's window, Input is then handed to the draft home
--- (`keep_input_draft()`). It enters no mode itself, and Terminal mode ends
--- as the cursor leaves Claude's window: `focus_claude()` enters Terminal
--- mode in Claude's window.
---
---@param role aineo.layout.Role
local function focus(role)
  local config = resolved_config()
  local opened = false
  require('aineo.layout').focus(role, function()
    opened = true
    return arrangement(config, current_claude_terminal(config))
  end)
  if opened then
    keep_input_draft()
  end
end

--- Shows `pane` in the layout's right column (`aineo.layout`'s
--- `show_pane()`). When the layout must open first, it opens as `focus()`
--- opens it, around the Claude session's terminal as it is, and Input is
--- then handed to the draft home (`keep_input_draft()`).
---
---@param pane aineo.layout.Pane
local function show_pane(pane)
  local config = resolved_config()
  local opened = false
  require('aineo.layout').show_pane(pane, function()
    opened = true
    return arrangement(config, current_claude_terminal(config))
  end)
  if opened then
    keep_input_draft()
  end
end

--- Whether the current buffer is the Claude session's terminal and that
--- session has not ended: where a key typed in Terminal mode reaches Claude
--- Code. A key typed in Terminal mode on an ended session's terminal closes
--- it; another buffer shown in Claude's window is not Claude's to type to.
---
---@return boolean
local function can_type_to_claude()
  return vim.api.nvim_get_current_buf() == claude_terminal
    and require('aineo.claude').session_status() ~= 'exited'
end

--- Moves the cursor to Claude's window, as `focus()` does, and asks for
--- Terminal mode when the keys typed there would reach Claude Code: its
--- prompt, or the dialog it shows as it starts (`can_type_to_claude()`).
--- Neovim enters Terminal mode once the outermost mapping or command around
--- it has ended, in the window current then: Claude's, unless a caller moves
--- the cursor on. Otherwise it stays in Normal mode. What the cursor landed
--- on is read after the move, which starts a new session when the layout
--- must reopen and the ended session's terminal is gone.
local function focus_claude()
  focus('claude')
  if can_type_to_claude() then
    vim.cmd.startinsert()
  end
end

--- What each of `:Aineo`'s arguments in `ACTION_ARGUMENTS` does.
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
  claude = focus_claude,
  ['claude-numbers'] = function()
    require('aineo.layout').toggle_claude_numbers()
  end,
  ['pane agent'] = function()
    show_pane('agent')
  end,
  ['pane changes'] = function()
    show_pane('changes')
  end,
}

--- What Neovim puts before an error it passes on, outermost first: the
--- words it wraps an error raised in Lua in (`Lua: ` from Neovim 0.12 on,
--- `Error executing lua: ` before), the position of the Lua code that raised
--- it — `<file>.lua:<line>: `, the file's path holding no white space, or
--- for Neovim's own modules from 0.12 on `vim/<module>:<line>: ` or
--- `[string "vim/<module>"]:<line>: ` — and the mark of an error a Vim
--- function raised. A file's position is never looked for past a space, so
--- the words of an error before a position they name are kept.
local ERROR_FRAMING = {
  '^Lua: ',
  '^Error executing lua: ',
  '^%S-%.lua:%d+: ',
  '^vim/[%w_/]+:%d+: ',
  '^%[string "vim/[^"]*"%]:%d+: ',
  '^Vim:',
}

--- The error `message` tells, on one line: its first line, without the
--- stack traceback that may follow it and without what Neovim put before it
--- (`ERROR_FRAMING`), stripped until none is left at its start — Neovim
--- frames an error again after the position of the Lua that called the API
--- function which raised it. An error whose own words begin with such words
--- loses them too.
---
---@param message string
---@return string
local function error_line(message)
  local line = message:match('^[^\n]*')
  repeat
    local before = line
    for _, framing in ipairs(ERROR_FRAMING) do
      line = line:gsub(framing, '')
    end
  until line == before
  return line
end

--- Runs `action`, and tells the user once, with one error notification, the
--- error it raises. Returns whether `action` ran without an error and, when
--- it did not, the line the user was told.
---
---@param action fun()
---@return boolean succeeded
---@return string|nil failure
local function run(action)
  local succeeded, failure = pcall(action)
  if succeeded then
    return true
  end
  local line = error_line(tostring(failure))
  vim.notify('aineo: ' .. line, vim.log.levels.ERROR)
  return false, line
end

--- The `<Plug>` mapping that does what `:Aineo` with the argument
--- `argument` does, its words joined by `-`: `<Plug>(aineo-pane-agent)` for
--- `pane agent`.
---
---@param argument string
---@return string
local function plug_mapping(argument)
  return ('<Plug>(aineo-%s)'):format((argument:gsub(' ', '-')))
end

for _, argument in ipairs(ACTION_ARGUMENTS) do
  vim.keymap.set('n', plug_mapping(argument), function()
    run(ACTIONS[argument])
  end, { desc = 'aineo: ' .. argument })
end

--- The keys that follow the prefix for each of `:Aineo`'s arguments in
--- `ACTION_ARGUMENTS`.
local PREFIX_KEYS = {
  send = 's',
  open = 'o',
  report = 'r',
  input = 'i',
  claude = 'c',
  ['claude-numbers'] = 'tcn',
  ['pane agent'] = 'pa',
  ['pane changes'] = 'pc',
}

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

--- Maps `prefix` followed by each action's keys (`PREFIX_KEYS`), in Normal
--- mode, to the action's `<Plug>` mapping, but for each key sequence the
--- user has mapped globally already — a mapping of only the start of a
--- sequence, or of a longer one, does not count; maps nothing when `prefix`
--- is `false`.
---
---@param prefix string|false
local function map_prefix(prefix)
  if prefix == false then
    return
  end
  for _, argument in ipairs(ACTION_ARGUMENTS) do
    local keys = prefix .. PREFIX_KEYS[argument]
    if not has_global_mapping(keys) then
      vim.keymap.set('n', keys, plug_mapping(argument), { desc = 'aineo: ' .. argument })
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

--- What makes a start other than a bare, interactive `nvim`, in the order
--- they are looked for, each named by the reason the autostart records: no
--- user interface attached, a file to edit, its standard input read,
--- something else to do (`has_startup_task()`), and running inside aineo's
--- own Claude terminal, which sets `$AINEO_CHILD`.
---@type { reason: string, holds: fun(): boolean }[]
local NOT_BARE_INTERACTIVE = {
  {
    reason = 'no-ui',
    holds = function()
      return #vim.api.nvim_list_uis() == 0
    end,
  },
  {
    reason = 'file-argument',
    holds = function()
      return vim.fn.argc() > 0
    end,
  },
  {
    reason = 'stdin',
    holds = function()
      return read_stdin
    end,
  },
  {
    reason = 'startup-task',
    holds = function()
      return has_startup_task(vim.v.argv)
    end,
  },
  {
    reason = 'inside-claude',
    holds = function()
      return vim.env.AINEO_CHILD ~= nil
    end,
  },
}

--- Why the editor has not started as a bare, interactive `nvim` — the first
--- of `NOT_BARE_INTERACTIVE` that holds — or `nil` when it has.
---
---@return string|nil reason
local function why_not_bare_interactive()
  local found = vim.iter(NOT_BARE_INTERACTIVE):find(function(condition)
    return condition.holds()
  end)
  return found and found.reason
end

--- Records what the autostart decided at startup, and why, in the editor
--- variable `vim.g.aineo_startup`, which `:checkhealth aineo` reads:
--- `{ reason = reason, failure = failure }`. The reasons: `starting`, from
--- the moment this file is sourced until the editor has started; `opening`,
--- once the autostart has decided to open the layout, until it has tried;
--- then `opened`, `open-failed`, `autostart-off`, `wrong-setting`,
--- `session-restored`, or one of `NOT_BARE_INTERACTIVE`. When this file is
--- sourced after the editor has started: `mapping-late`, until the scheduled
--- callback that maps the prefix has run, then `sourced-late`.
---
---@param reason string
---@param failure? string the error line an open that failed told the user
local function record_startup(reason, failure)
  vim.g.aineo_startup = { reason = reason, failure = failure }
end

--- Opens the layout as `open()` does, unless a session has been restored
--- (`v:this_session` is set), as a plugin such as auto-session or
--- persistence.nvim restores one from its own `VimEnter` autocommand: the
--- session's windows are the user's to keep. Records which it was, and
--- whether the open failed (`record_startup()`).
local function open_unless_session_restored()
  if vim.v.this_session ~= '' then
    record_startup('session-restored')
    return
  end
  local opened, failure = run(open)
  if opened then
    record_startup('opened')
  else
    record_startup('open-failed', failure)
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
--- start is bare and interactive (`open_after_dashboards()`), recording
--- its decision, or why it does not open (`record_startup()`). Raises the
--- configuration's error, recorded as `wrong-setting`, when a setting is
--- wrong.
local function start_up()
  local resolved, config = pcall(resolved_config)
  if not resolved then
    record_startup('wrong-setting')
    error(config, 0)
  end
  map_prefix(config.prefix)
  if not config.autostart then
    record_startup('autostart-off')
    return
  end
  local refusal = why_not_bare_interactive()
  if refusal then
    record_startup(refusal)
    return
  end
  record_startup('opening')
  open_after_dashboards()
end

if vim.v.vim_did_enter == 1 then
  record_startup('mapping-late')
  vim.schedule(function()
    run(function()
      map_prefix(resolved_config().prefix)
    end)
    record_startup('sourced-late')
  end)
else
  record_startup('starting')
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
  local action = ACTIONS[table.concat(command.fargs, ' ')]
  if action then
    run(action)
    return
  end
  vim.notify(usage(command.fargs), vim.log.levels.ERROR)
end, {
  nargs = '*',
  bar = true,
  complete = complete_subcommand,
  desc = 'aineo: send, open, report, input, claude, claude-numbers or pane agent|changes',
})
