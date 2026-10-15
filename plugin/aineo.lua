--- aineo's composition root, sourced by Neovim at every startup: `:Aineo`, the
--- `<Plug>(aineo-…)` mappings, and, once the editor has started, the prefix
--- mappings, their twins in Terminal and Insert mode, and the autostart. It
--- stays cheap: sourcing it requires no aineo module; once the editor has
--- started it loads the configuration alone, to read the prefixes and
--- `autostart`, and the other homes load when a command, a mapping or the
--- autostart first needs them. `aineo.entry`, the body of this composition
--- root, loads with the first command or mapping, and at startup only to
--- tell the user an error (a wrong setting) or when a session plugin has
--- restored a session.
---
--- The prefixes are mapped, and the autostart decided, from the configuration
--- as it stands when the editor has started (`VimEnter`) — after the user's
--- init, and so after a plugin manager has run `setup()`. When this file is
--- sourced later, the prefixes are mapped in the first scheduled callback
--- after it, once the plugin manager that sourced it has run `setup()` in the
--- same tick, as lazy.nvim does, and nothing starts by itself.
---
--- What the autostart decided, and why, is recorded in the editor variable
--- `vim.g.aineo_startup` for `:checkhealth aineo` to report.
---
--- What each command and mapping does — the tabs of aineo and their actions —
--- is the body of this composition root, `aineo.entry`, which a callback
--- requires when it first runs; this file holds the registrations and the
--- keys.
---
--- It runs once. Setting `vim.g.loaded_aineo` before startup turns it off, and
--- sourcing it again does nothing.

if vim.g.loaded_aineo then
  return
end
vim.g.loaded_aineo = true

--- `:Aineo`'s subcommands, in the order it offers them.
local SUBCOMMANDS = {
  'send',
  'open',
  'report',
  'input',
  'claude',
  'claude-numbers',
  'sessions',
  'new',
  'pane',
  'claim',
  'tab',
}

--- The words each subcommand that takes one is followed by, in the order
--- `:Aineo` offers them: `pane` takes the pane to show, and `tab` takes `new`,
--- `close` or the number of a tab page to move to; only the numbers 1 to 9
--- have a `<Plug>` mapping, and `:Aineo tab` takes any number
--- (`aineo.entry`'s `jump_to_tab()`).
local SUBCOMMAND_WORDS = {
  pane = { 'agent', 'changes', 'terminal' },
  tab = { 'new', 'close', '1', '2', '3', '4', '5', '6', '7', '8', '9' },
}

--- What `:Aineo` tells the user when it is not given one of its subcommands.
local USAGE = 'aineo: :Aineo takes one of ' .. table.concat(SUBCOMMANDS, ', ')

--- What `:Aineo claim` tells the user when it is given more than one word.
local CLAIM_USAGE = 'aineo: :Aineo claim takes at most one Claude session id'

--- What `:Aineo tab` tells the user when it is given no word, another word
--- than `new` or `close`, or more than one.
local TAB_USAGE = 'aineo: :Aineo tab takes new, close, or the number of a tab to move to'

--- What `:Aineo` tells the user when `words`, its arguments, run no action:
--- for `claim`, that it takes at most one word; for `tab`, what it takes
--- (`TAB_USAGE`); for a subcommand that takes words (`SUBCOMMAND_WORDS`),
--- which ones it takes; and `USAGE` otherwise.
---
---@param words string[]
---@return string
local function usage(words)
  if words[1] == 'claim' then
    return CLAIM_USAGE
  end
  if words[1] == 'tab' then
    return TAB_USAGE
  end
  local subcommand_words = SUBCOMMAND_WORDS[words[1]]
  if not subcommand_words then
    return USAGE
  end
  return ('aineo: :Aineo %s takes one of %s'):format(words[1], table.concat(subcommand_words, ', '))
end

--- `:Aineo`'s arguments that each run an action, in `SUBCOMMANDS`' order:
--- each subcommand alone, or followed by each of its words
--- (`SUBCOMMAND_WORDS`), as `pane agent`. Built with plain loops, so that
--- sourcing this file loads no module Neovim has not loaded (`vim.iter`).
local ACTION_ARGUMENTS = {}
for _, subcommand in ipairs(SUBCOMMANDS) do
  local words = SUBCOMMAND_WORDS[subcommand]
  if words then
    for _, word in ipairs(words) do
      table.insert(ACTION_ARGUMENTS, subcommand .. ' ' .. word)
    end
  else
    table.insert(ACTION_ARGUMENTS, subcommand)
  end
end

--- The words `:Aineo tab` offers: `new`, `close`, and the number of each tab
--- page that exists.
---
---@return string[]
local function tab_words()
  local words = { 'new', 'close' }
  for number = 1, #vim.api.nvim_list_tabpages() do
    table.insert(words, tostring(number))
  end
  return words
end

--- The words `:Aineo` offers after `typed`, the words before the one the
--- cursor is in, the command's name first: its subcommands after the name
--- alone, the words of a subcommand that takes them (`SUBCOMMAND_WORDS`)
--- after that subcommand, the running sessions of this Neovim's directory
--- after `claim` (`aineo.entry`'s `running_sessions_here()`), `new`,
--- `close` and the numbers of the tab pages after `tab` (`tab_words()`), and
--- nothing otherwise.
---
---@param typed string[]
---@return string[]
local function offered_words(typed)
  if #typed == 1 then
    return SUBCOMMANDS
  end
  if #typed == 2 and typed[2] == 'claim' then
    return require('aineo.entry').running_sessions_here()
  end
  if #typed == 2 and typed[2] == 'tab' then
    return tab_words()
  end
  if #typed == 2 then
    return SUBCOMMAND_WORDS[typed[2]] or {}
  end
  return {}
end

--- Whether `word`, a word of the command line, is `:Aineo`'s name, whole or
--- shortened (`:Ain`), after any range written before it (`5Aineo`).
---
---@param word string
---@return boolean
local function names_the_command(word)
  local name = word:match('(A%a*)$')
  return name ~= nil and vim.startswith('Aineo', name)
end

--- The words of `typed` from the last word that names `:Aineo`
--- (`names_the_command()`) on: what comes before the last `:Aineo` on the
--- line — command modifiers, such as `:silent` or `:vertical`, a range, such
--- as a mark (`'A`), or commands before a bar — left out.
---
---@param typed string[]
---@return string[]
local function words_from_the_name(typed)
  for index = #typed, 1, -1 do
    if names_the_command(typed[index]) then
      return vim.list_slice(typed, index)
    end
  end
  return typed
end

--- What `:Aineo` completes the word the cursor is in to: the words it offers
--- there (`offered_words()`) that begin with `argument_lead`, what the user
--- has typed of that word. The words before it are read from `command_line`
--- up to `cursor_position`, from the last word that names the command on
--- (`words_from_the_name()`), so that a command modifier, a range or a
--- command and a bar before the name change nothing.
---
---@param argument_lead string
---@param command_line string
---@param cursor_position integer
---@return string[]
local function complete_subcommand(argument_lead, command_line, cursor_position)
  local before = command_line:sub(1, cursor_position - #argument_lead)
  local typed = words_from_the_name(vim.split(before, '%s+', { trimempty = true }))
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

--- Runs `action`, and tells the user once, with one error notification, the
--- error it raises (`aineo.entry`'s `tell_error()`, which loads that home only
--- then). Returns whether `action` ran without an error and, when it did not,
--- the line the user was told.
---
---@param action fun()
---@return boolean succeeded
---@return string|nil failure
local function run(action)
  local succeeded, failure = pcall(action)
  if succeeded then
    return true
  end
  return false, require('aineo.entry').tell_error(failure)
end

--- Does what `:Aineo` does with `argument`, one of `ACTION_ARGUMENTS`
--- (`aineo.entry`'s `act()`), and tells the user once the error it raises
--- (`run()`). Returns what `run()` returns.
---
---@param argument string
---@return boolean succeeded
---@return string|nil failure
local function run_action(argument)
  return run(function()
    require('aineo.entry').act(argument)
  end)
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
    run_action(argument)
  end, { desc = 'aineo: ' .. argument })
end

--- What each action that has a Visual-mode form does in Visual mode, by its
--- argument in `ACTION_ARGUMENTS`: Send sends the selection alone, in the
--- tab the selection is in (`aineo.entry`'s `send_visual_selection()`).
---@type table<string, fun()>
local VISUAL_ACTIONS = {
  send = function()
    require('aineo.entry').send_visual_selection()
  end,
}

for argument, action in pairs(VISUAL_ACTIONS) do
  vim.keymap.set('x', plug_mapping(argument), function()
    run(action)
  end, { desc = 'aineo: ' .. argument .. ' the selection' })
end

--- The keys that follow the prefix for each of `:Aineo`'s arguments in
--- `ACTION_ARGUMENTS` but `claim`, which has no prefix key.
local PREFIX_KEYS = {
  send = 's',
  open = 'o',
  report = 'r',
  input = 'i',
  claude = 'c',
  ['claude-numbers'] = 'tcn',
  sessions = 'S',
  new = 'N',
  ['pane agent'] = 'pa',
  ['pane changes'] = 'g',
  ['pane terminal'] = 'pt',
  ['tab new'] = 'T',
  ['tab close'] = 'Q',
  ['tab 1'] = '1',
  ['tab 2'] = '2',
  ['tab 3'] = '3',
  ['tab 4'] = '4',
  ['tab 5'] = '5',
  ['tab 6'] = '6',
  ['tab 7'] = '7',
  ['tab 8'] = '8',
  ['tab 9'] = '9',
}

--- The keys that leave the mode a twin (`map_terminal_prefix()`) is pressed
--- in, Terminal mode (`t`) or Insert mode (`i`), for Normal mode. In Terminal
--- mode Neovim's own, which are not mapped. In Insert mode `<Esc>`'s effect:
--- `<C-]>` first expands an abbreviation before the cursor, and `<Esc>`
--- repeats an insert by its count, which `<C-\><C-n>` does neither.
local LEAVE_MODE = { t = '<C-\\><C-n>', i = '<C-]><Esc>' }

--- The prefix keys that have no twin in Terminal and Insert mode: Send acts
--- on a selection or on Normal mode's line.
local HAS_NO_TWIN = { send = true }

--- Whether `keys`, written as in a mapping, have a global mapping in
--- `mode`: `n` for Normal mode, `x` for Visual mode, `t` for Terminal mode
--- or `i` for Insert mode. A mapping local to a buffer does not count: it
--- wins in its own buffer only. A mapping's keys are compared in both the
--- forms Neovim records: `lhsraw`, and `lhsrawalt`, where a Ctrl key such as
--- `<C-a>` has the one byte `nvim_replace_termcodes()` gives it.
---
---@param mode 'n'|'x'|'t'|'i'
---@param keys string
---@return boolean
local function has_global_mapping(mode, keys)
  local typed = vim.api.nvim_replace_termcodes(keys, true, true, true)
  return vim.iter(vim.api.nvim_get_keymap(mode)):any(function(mapping)
    return mapping.lhsraw == typed or mapping.lhsrawalt == typed
  end)
end

--- Maps `keys` in `mode` to `argument`'s `<Plug>` mapping, typed after
--- `typed_before`, unless the user has mapped `keys` globally in `mode`
--- already (`has_global_mapping()`).
---
---@param mode 'n'|'x'|'t'|'i'
---@param keys string
---@param argument string
---@param typed_before string keys typed before the `<Plug>` mapping, `''` for none
local function map_unless_mapped(mode, keys, argument, typed_before)
  if not has_global_mapping(mode, keys) then
    vim.keymap.set(
      mode,
      keys,
      typed_before .. plug_mapping(argument),
      { desc = 'aineo: ' .. argument }
    )
  end
end

--- Maps `prefix` followed by each action's keys (`PREFIX_KEYS`) to the
--- action's `<Plug>` mapping, in Normal mode, and in Visual mode for each
--- action that has a Visual-mode form (`VISUAL_ACTIONS`), but for each key
--- sequence the user has mapped globally in that mode already — a mapping
--- of only the start of a sequence, of a longer one, or in the other mode,
--- does not count; maps nothing when `prefix` is `false`. An action with no
--- keys there, `claim`, gets none.
---
---@param prefix string|false
local function map_prefix(prefix)
  if prefix == false then
    return
  end
  for _, argument in ipairs(ACTION_ARGUMENTS) do
    if PREFIX_KEYS[argument] then
      map_unless_mapped('n', prefix .. PREFIX_KEYS[argument], argument, '')
    end
  end
  for argument in pairs(VISUAL_ACTIONS) do
    map_unless_mapped('x', prefix .. PREFIX_KEYS[argument], argument, '')
  end
end

--- Maps `terminal_prefix` followed by each action's keys (`PREFIX_KEYS`) in
--- Terminal mode and in Insert mode to the keys that leave that mode for
--- Normal mode (`LEAVE_MODE`) and then the action's `<Plug>` mapping, so that
--- the action runs as it does from Normal mode. Skips each key sequence the
--- user has mapped globally in that mode already (`map_unless_mapped()`) and,
--- in a mode where the user has mapped `terminal_prefix` alone globally, every
--- twin: that key would otherwise wait for the next key, and a twin's letter
--- typed then would run aineo's action. Maps nothing when `terminal_prefix`
--- is `false`. Send, which has no twin (`HAS_NO_TWIN`), and `claim`, which
--- has no keys, get none.
---
---@param terminal_prefix string|false
local function map_terminal_prefix(terminal_prefix)
  if terminal_prefix == false then
    return
  end
  for _, mode in ipairs({ 't', 'i' }) do
    if not has_global_mapping(mode, terminal_prefix) then
      for _, argument in ipairs(ACTION_ARGUMENTS) do
        if PREFIX_KEYS[argument] and not HAS_NO_TWIN[argument] then
          map_unless_mapped(
            mode,
            terminal_prefix .. PREFIX_KEYS[argument],
            argument,
            LEAVE_MODE[mode]
          )
        end
      end
    end
  end
end

--- Maps the keys the configuration `config` names: the prefix's
--- (`map_prefix()`) and the terminal prefix's (`map_terminal_prefix()`).
---
---@param config table the resolved configuration
local function map_keys(config)
  map_prefix(config.prefix)
  map_terminal_prefix(config.terminal_prefix)
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

--- Opens the layout as `:Aineo open` does (`run_action()`), unless a session
--- has been restored (`v:this_session` is set), as a plugin such as
--- auto-session or persistence.nvim restores one from its own `VimEnter`
--- autocommand: the session's windows are the user's to keep, and the first
--- open then reopens no folder's tabs (`aineo.entry`'s
--- `forgo_tab_reopening()`). Records which it was, and whether the open
--- failed (`record_startup()`).
local function open_unless_session_restored()
  if vim.v.this_session ~= '' then
    require('aineo.entry').forgo_tab_reopening()
    record_startup('session-restored')
    return
  end
  local opened, failure = run_action('open')
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
  map_keys(config)
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
      map_keys(resolved_config())
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
  local argument = table.concat(command.fargs, ' ')
  if vim.tbl_contains(ACTION_ARGUMENTS, argument) then
    run_action(argument)
    return
  end
  if command.fargs[1] == 'claim' and #command.fargs == 2 then
    run(function()
      require('aineo.entry').claim_in_current_tab(command.fargs[2])
    end)
    return
  end
  if command.fargs[1] == 'tab' and #command.fargs == 2 and command.fargs[2]:match('^%d+$') then
    run(function()
      require('aineo.entry').jump_to_tab(tonumber(command.fargs[2]), command.fargs[2])
    end)
    return
  end
  vim.notify(usage(command.fargs), vim.log.levels.ERROR)
end, {
  nargs = '*',
  bar = true,
  complete = complete_subcommand,
  desc = 'aineo: send, open, report, input, claude, claude-numbers, sessions, new, pane agent|changes|terminal, claim [id] or tab new|close|{n}',
})
