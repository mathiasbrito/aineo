--- aineo's composition root, sourced by Neovim at every startup: `:Aineo`, the
--- `<Plug>(aineo-…)` mappings, and, once the editor has started, the prefix
--- mappings, their twins in Terminal and Insert mode, and the autostart. It
--- stays cheap: sourcing it requires no aineo module; once the editor has
--- started it loads the configuration alone, to read the prefixes and
--- `autostart`, and the other homes load when a command, a mapping or the
--- autostart first needs them.
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
--- One tab of aineo (`make_tab()`) is a Claude Code session with the layout,
--- Report, Input and changes pane that follow it, in a tab page. The first
--- tab is made of the homes the modules themselves are, and every tab after
--- it of the copies each home's `new()` makes. What an action does it does to
--- a tab (`acting_tab()`), and what the editor shares — the folder, the
--- configuration, the keys, the list of running editors, the report home's
--- router (`route_report()`) — is held here, once.
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
--- (`jump_to_tab()`).
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

--- The sessions that have a running Claude Code in the directory this
--- Neovim started in, which `:Aineo claim` offers. Defined below, with the
--- places aineo keeps what it keeps.
---@type fun(): string[]
local running_sessions_here

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
--- after `claim` (`running_sessions_here()`), `new`, `close` and the numbers
--- of the tab pages after `tab` (`tab_words()`), and nothing otherwise.
---
---@param typed string[]
---@return string[]
local function offered_words(typed)
  if #typed == 1 then
    return SUBCOMMANDS
  end
  if #typed == 2 and typed[2] == 'claim' then
    return running_sessions_here()
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

--- Where aineo keeps what it keeps — the Reports, Input's draft, the
--- changes pane's kept bases and the session id Claude Code resumes — once
--- `kept_places()` has taken it.
---@type { state_directory: string, working_directory: string }|nil
local places = nil

--- The editor's state directory and working directory, as they are the
--- first time this is called: the Reports and Input's draft are kept under
--- that state directory — for that working directory until the panes follow
--- a Claude session (`follow_session()`), then per session — whatever `:cd`
--- does later.
---
---@return { state_directory: string, working_directory: string }
local function kept_places()
  places = places
    or { state_directory = vim.fn.stdpath('state'), working_directory = vim.fn.getcwd() }
  return places
end

running_sessions_here = function()
  return require('aineo.mcp').running_sessions(
    kept_places().state_directory,
    kept_places().working_directory
  )
end

--- The wall clock now, in microseconds: when a tab of this Neovim was last
--- used, as its entry in the list of running editors keeps it.
---
---@return integer
local function microseconds_now()
  local now = vim.uv.clock_gettime('realtime')
  return now.sec * 1000000 + math.floor(now.nsec / 1000)
end

--- What the terminal pane tells the user, as an error, when the folder aineo
--- started in (`kept_places()`) is gone: the folder, in `%s`.
local FOLDER_GONE = 'the folder aineo started in is gone, so no shell started: %s'

--- What `:Aineo claim` tells the user, as a warning, when the tab's own
--- Claude terminal runs no session — Claude Code never started in it — so
--- that it has no session of its own to claim or return to.
local NO_OWN_SESSION = 'aineo: Claude Code has not started in this Neovim;'
  .. ' :Aineo claim {id} follows a session, :Aineo open starts Claude Code here'

--- What `:Aineo claim` tells the user, as a warning, while the start of
--- the tab's Claude Code has not been confirmed: its session may never be
--- one.
local NOT_READY_TO_CLAIM = 'aineo: Claude Code is not ready yet; nothing claimed'

--- What `:Aineo sessions` tells the user, as a warning, by the status of
--- the Claude session (`aineo.claude`'s `session_status()`; `not_started`
--- when there is none) when it does nothing because Claude Code is not ready.
local NOT_READY = {
  not_started = 'Claude has not started',
  starting = 'Claude is not ready: it is starting, or a dialog in its window awaits your answer',
  exited = 'Claude has exited',
}

--- What the messages of `:Aineo sessions` begin with when it lists nothing,
--- and when a pick opens no tab.
local NO_LIST = 'aineo: no session list — '
local NOT_SWITCHED = 'aineo: not switched — '

--- What the command `:Aineo new` writes begins and ends a bracketed paste
--- with: the bytes Send pastes with (`aineo.send`), so that Claude Code takes
--- the command as text typed in one piece.
local PASTE_START = '\27[200~'
local PASTE_END = '\27[201~'

--- What `:Aineo sessions` tells the user, as a warning, when a pick
--- switches nothing because another process runs the session picked, in
--- Claude Code's background service with no short id for `claude attach`
--- to take, and a switch would pull it away from there.
---
---@param name string
---@return string
local function runs_elsewhere(name)
  return (
    NOT_SWITCHED
    .. '%s runs in another terminal or in Claude Code’s background service,'
    .. ' and a switch would pull it away from there'
  ):format(name)
end

--- What `:Aineo sessions` tells the user, as a warning, when a pick
--- switches nothing because the session picked started in a directory other
--- than the folder listed, where Claude Code would resume it into another
--- project.
---
---@param name string
---@param started_in string? the directory the entry names
---@return string
local function started_elsewhere(name, started_in)
  return (NOT_SWITCHED .. '%s was started in another folder%s'):format(
    name,
    started_in and (', ' .. started_in) or ''
  )
end

--- How long a command written into Claude Code waits, after it asks for
--- Terminal mode in Claude's window, for Neovim to enter it.
local TERMINAL_MODE_PATIENCE_MS = 1000

--- Calls `callback` from a scheduled callback once Terminal mode is entered
--- in `terminal`, Claude's terminal: at once, scheduled, when it is
--- entered already; else at the next `TermEnter` in it, which must come
--- within `TERMINAL_MODE_PATIENCE_MS`. Past that time `callback` is never
--- called, `on_timeout` is, and the user is told with a warning that
--- begins `outcome`, the words of what was not done, and ends `Claude’s
--- window did not enter Terminal mode`.
---
---@param terminal integer
---@param outcome string
---@param callback fun()
---@param on_timeout fun()
local function after_entering_terminal_mode(terminal, outcome, callback, on_timeout)
  if vim.api.nvim_get_current_buf() == terminal and vim.api.nvim_get_mode().mode == 't' then
    vim.schedule(callback)
    return
  end
  local entered = false
  local autocommand = vim.api.nvim_create_autocmd('TermEnter', {
    buffer = terminal,
    once = true,
    callback = function()
      entered = true
      vim.schedule(callback)
    end,
  })
  vim.defer_fn(function()
    if not entered then
      vim.api.nvim_del_autocmd(autocommand)
      on_timeout()
      vim.notify(outcome .. 'Claude’s window did not enter Terminal mode', vim.log.levels.WARN)
    end
  end, TERMINAL_MODE_PATIENCE_MS)
end

--- Puts the cursor back where it was before a command written into Claude
--- Code moved it: in the window `origin` names, out of Terminal mode when
--- that window is Claude's and was in Normal mode, and in Insert mode when it
--- was in Insert mode. Moving to another window ends Terminal mode, and
--- Insert mode is asked for once it has ended: asked for sooner, it is lost
--- to it.
---
---@param origin { window: integer, mode: string }
local function return_to(origin)
  if origin.window == vim.api.nvim_get_current_win() and origin.mode ~= 't' then
    vim.cmd.stopinsert()
  end
  if vim.api.nvim_win_is_valid(origin.window) then
    vim.api.nvim_set_current_win(origin.window)
  end
  if vim.startswith(origin.mode, 'i') then
    vim.api.nvim_create_autocmd('ModeChanged', {
      pattern = 't:*',
      once = true,
      callback = function()
        vim.schedule(vim.cmd.startinsert)
      end,
    })
  end
end

--- What `:Aineo new` begins its warnings with when it does nothing.
local NO_NEW_SESSION = 'aineo: no new session — '

--- What `:Aineo new` tells the user, as a warning, when the prompt of
--- Claude Code shows text.
local NEW_PROMPT_HOLDS_TEXT = NO_NEW_SESSION
  .. 'the prompt holds text; clear it, then press the key again'

--- What Neovim puts before an error it passes on, outermost first: the
--- words it wraps an error raised in Lua in (`Lua: `), the position of the
--- Lua code that raised it — `<file>.lua:<line>: `, the file's path holding
--- no white space, or for Neovim's own modules `vim/<module>:<line>: ` or
--- `[string "vim/<module>"]:<line>: ` — and the mark of an error a Vim
--- function raised. A file's position is never looked for past a space, so
--- the words of an error before a position they name are kept.
local ERROR_FRAMING = {
  '^Lua: ',
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

--- The buffer number Send is given for a tab whose Input does not exist yet,
--- and for a selection outside every tab: no buffer has it, so Send refuses,
--- saying there is no Input or that Visual Send works in Input only, rather
--- than read the Input of another tab.
local NO_INPUT_BUFFER = -1

--- The tabs of this editor, in the order they were made (`new_tab()`): the
--- tabs whose layout has opened in a tab page of their own, and at most one
--- that has none yet, which a claim made before aineo opened uses.
---@type aineo.entry.Tab[]
local tab_list = {}

--- The aineo tab the user used last: the one the current tab page is in when
--- it is one, else the last one the user was in or an action moved to
--- (`acting_tab()`, the `TabEnter` handler). Nil before there is one.
---@type aineo.entry.Tab?
local last_used_tab = nil

--- The place of `tab`'s tab page among the editor's tab pages, as `{n}gt`
--- counts it (`aineo.tabs`' `number()`).
---
---@param tab aineo.entry.Tab
---@return integer
local function tab_number(tab)
  return require('aineo.tabs').number(tab.page())
end

--- The first tab of `tab_list` but `except` whose panes follow `session`, in
--- a tab page that exists; nil when there is none.
---
---@param session string
---@param except aineo.entry.Tab
---@return aineo.entry.Tab?
local function tab_following(session, except)
  return vim.iter(tab_list):find(function(other)
    return other ~= except and other.is_bound() and other.panes_session() == session
  end)
end

--- The tab whose tab page the current window is in; nil when it is in none.
---
---@return aineo.entry.Tab?
local function tab_of_current_page()
  local current = vim.api.nvim_get_current_tabpage()
  return vim.iter(tab_list):find(function(tab)
    return tab.page() == current
  end)
end

--- Whether the tabs of the folder's list are being reopened
--- (`reopen_folder_tabs()`): the list is kept once, when the last has opened,
--- so that the list being restored is never replaced by a part of itself.
local tabs_reopening = false

--- Keeps the folder's list of tabs as the tabs stand (`aineo.tabs`'
--- `keep_tabs()`): the session of each tab whose layout is in a tab page, in
--- the order of the tab pages, and the place of the tab whose tab page is
--- current, or of the tab used last (`last_used_tab`) when the current tab
--- page is none of aineo's. `not_opened` are sessions a reopening has not
--- opened (cut off, or not tried): they follow those of the tabs in the list.
--- Keeps nothing when no tab and none of `not_opened` has a session; a list
--- that cannot be kept is told the user once (`run()`).
---
--- When the session kept for the folder (the one the next start without a
--- list lands in) is not in the list, the session at the list's place is kept
--- in its stead (`aineo.claude`'s `keep_session()`): a tab closed whose
--- session was the kept one is not brought back alone by the next start.
---
---@param not_opened? string[]
local function write_folder_tabs(not_opened)
  local current = tab_of_current_page()
  if not current and last_used_tab and last_used_tab.is_bound() then
    current = last_used_tab
  end
  local bound = vim
    .iter(tab_list)
    :filter(function(tab)
      return tab.is_bound()
    end)
    :totable()
  table.sort(bound, function(left, right)
    return tab_number(left) < tab_number(right)
  end)
  local tabs = require('aineo.tabs')
  local list = tabs.list_of_tabs(vim.tbl_map(function(tab)
    return { session = tab.session_id(), current = tab == current }
  end, bound))
  list = list or (not_opened and #not_opened > 0 and { sessions = {}, current = 1 }) or nil
  if not list then
    return
  end
  for _, session in ipairs(not_opened or {}) do
    if not vim.tbl_contains(list.sessions, session) then
      table.insert(list.sessions, session)
    end
  end
  local folder = kept_places()
  run(function()
    tabs.keep_tabs(folder.state_directory, folder.working_directory, list)
    local claude = require('aineo.claude')
    local kept = claude.kept_session(folder.state_directory, folder.working_directory)
    if not vim.tbl_contains(list.sessions, kept) then
      claude.keep_session(
        folder.state_directory,
        folder.working_directory,
        list.sessions[list.current]
      )
    end
  end)
end

--- Keeps the folder's list of tabs (`write_folder_tabs()`) as a tab opens or
--- closes or a tab's session changes. Does nothing while tabs reopen, and
--- once Neovim is quitting: the list is kept at the quit, before the Claude
--- Codes are stopped (`keep_folder_tabs_at_quit()`). `not_opened` as
--- `write_folder_tabs()` takes it.
---
---@param not_opened? string[]
local function keep_folder_tabs(not_opened)
  if tabs_reopening or vim.v.exiting ~= vim.NIL then
    return
  end
  write_folder_tabs(not_opened)
end

--- The place of each tab page of this editor that shows a Claude session,
--- by the session's id: the session of the Claude Code of each tab
--- (`aineo.entry.Tab`'s `session_id()`), and, where several tabs show one, the
--- lowest place. What the list of sessions marks and a pick moves to, unless
--- the current tab shows the session itself (`settles_by_standing()`).
---
---@return aineo.claude.ShownInTabs
local function sessions_shown_in_tabs()
  local shown = {}
  for _, tab in ipairs(tab_list) do
    local id = tab.is_bound() and tab.session_id()
    if id then
      shown[id] = math.min(shown[id] or math.huge, tab_number(tab))
    end
  end
  return shown
end

--- Opens a tab page at the end, after the last tab page, with a tab of
--- aineo's in it, which `start` starts Claude Code in (`aineo.entry.Tab`'s
--- `start_in_new_tab()` when none is given); `after_current` puts it after
--- the current tab page instead. Defined below, with the tabs it makes.
---@type fun(start?: fun(tab: aineo.entry.Tab), after_current?: boolean)
local open_new_tab

--- Whether the Claude Code of a tab that has closed and has yet to stop
--- (`closing`, `stopping`) is on the session `id`. Defined below, with the
--- tabs that close.
---@type fun(id: string): boolean
local stops_in_closed_tab

--- Has the tab line drawn again whenever the session's name on `terminal`,
--- the terminal of a tab's Claude Code, changes: a title shows in the tab
--- line, which Neovim draws again by itself on none of the name's changes.
--- The watcher is a dictionary watcher on `b:aineo_session_name`, added from
--- Vimscript, which alone can name a buffer's own `b:` (as `aineo.claude`
--- watches the terminal's title), once for each terminal.
---
---@param terminal integer
local function redraw_tab_line_when_named(terminal)
  if vim.b[terminal].aineo_tab_line_watched then
    return
  end
  vim.b[terminal].aineo_tab_line_watched = true
  vim.api.nvim_buf_call(terminal, function()
    vim.b.aineo_name_watcher = function()
      vim.schedule(function()
        vim.cmd.redrawtabline()
      end)
    end
    vim.cmd([[call dictwatcheradd(b:, 'aineo_session_name', b:aineo_name_watcher)]])
    vim.cmd.unlet('b:aineo_name_watcher')
  end)
end

--- Whether the editor's handlers have been made (`make_editor_handlers()`).
local editor_handlers_made = false

--- Makes, once, the handlers this Neovim's entries in the list of running
--- editors need: `FocusGained` writes the entry of the tab used last again,
--- marking it used; `TabEnter` writes the entry of an aineo tab entered;
--- `VimLeavePre` takes every entry of this Neovim off the list and lets go
--- every tab's claim; and a switch told by another Claude Code's hook is
--- followed by each tab it concerns (`aineo.entry.Tab`'s
--- `follow_told_switch()`). Made at the first entry write, so that sourcing
--- this file makes none.
local function make_editor_handlers()
  if editor_handlers_made then
    return
  end
  editor_handlers_made = true
  local group = vim.api.nvim_create_augroup('aineo.editors', {})
  vim.api.nvim_create_autocmd('FocusGained', {
    group = group,
    desc = 'aineo: mark the tab used last used in the list of running editors',
    callback = function()
      local tab = tab_of_current_page() or last_used_tab or tab_list[1]
      if tab then
        tab.write_entry()
      end
    end,
  })
  vim.api.nvim_create_autocmd('TabEnter', {
    group = group,
    desc = 'aineo: mark the aineo tab entered used in the list of running editors',
    callback = function()
      local tab = tab_of_current_page()
      if tab then
        last_used_tab = tab
        tab.write_entry()
      end
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    desc = 'aineo: take this editor off the list of running editors',
    callback = function()
      require('aineo.mcp').remove_editor_entry(kept_places().state_directory, vim.v.servername)
      for _, tab in ipairs(tab_list) do
        tab.release_claim()
      end
    end,
  })
  require('aineo.mcp').on_followed_switch(function(left, new)
    for _, tab in ipairs(tab_list) do
      tab.follow_told_switch(left, new)
    end
  end)
end

--- The homes one tab is made of: its layout, the Claude Code session home it
--- starts and follows, its Report, Input's draft and changes pane, and its
--- shell. The first tab's are the homes' own module-level copies; every tab
--- after it is given the copies each home's `new()` makes.
---@class aineo.entry.Homes
---@field layout aineo.layout.Layout
---@field claude aineo.claude.Session
---@field report aineo.report.Home
---@field draft aineo.draft.Home
---@field changes aineo.changes.Home
---@field shell aineo.shell.Home

--- One tab of aineo, as the composition root holds it: what a tab does is
--- called as fields, and acts on that tab's homes alone.
---@class aineo.entry.Tab
---@field key string? what tells the tab's entry in the list of running editors from the editor's other tabs; nil for the first tab, whose entry keeps the name it has always had
---@field homes aineo.entry.Homes
---@field actions table<string, fun()> what each of `:Aineo`'s arguments that acts on a tab does (`ACTION_ARGUMENTS`)
---@field send_selection fun() what Send does in Visual mode
---@field claim_session fun(id: string) what `:Aineo claim {id}` does
---@field follow_told_switch fun(left: string, new: string)
---@field write_entry fun()
---@field release_claim fun()
---@field panes_session fun(): string? the session the tab's panes follow
---@field runs_session fun(id: string): boolean whether the tab's Claude Code runs the session `id`
---@field start_token fun(): string? see `aineo.claude.Session`'s `start_token()`
---@field start_in_new_tab fun() what `:Aineo tab new` does once the tab page exists
---@field start_on_session fun(listed: aineo.claude.ListedSession, sessions: aineo.claude.ListedSession[]) what a pick of `\S` does once the tab page exists: starts Claude Code on that session
---@field open_on_session fun(id: string) what reopening the folder's tabs does for each tab once its tab page exists: starts Claude Code on the session `id`, resumed or attached to where it runs in the background, in a layout of its own
---@field session_id fun(): string? the session the tab's Claude Code follows, nil before it has started
---@field session_name fun(): string? the name of the session the tab's Claude terminal shows (`b:aineo_session_name`), nil before it has one
---@field page fun(): integer? the tab page the tab is in, nil before its layout opens
---@field is_bound fun(): boolean whether the tab page it is in still exists
---@field release fun() lets the tab's homes go as its tab page closes, at once
---@field finish fun(already_stopped: boolean) stops the tab's Claude Code as quitting stops it unless it was stopped, and ends the tab
---@field reopen fun() takes the first tab up again, with nothing of what it held

--- Makes one tab of aineo from `homes`: the Claude Code session it starts,
--- and the Report, Input, changes pane and layout that follow that session.
--- Every state a tab keeps — the session its panes follow, the claim of a
--- session, the confirmation of a start — is held here, in this tab, and the
--- homes' module-level functions are not called: a tab acts on `homes` alone.
---
--- `on_bound` is called with the tab each time its layout opens in a tab page
--- it was not in, which is the tab page the tab is in from then on: once for
--- a tab of copies, and again for the first tab each time it is taken up
--- after its tab page closed.
---
---@param homes aineo.entry.Homes
---@param key string? see `aineo.entry.Tab`
---@param on_bound fun(tab: aineo.entry.Tab)
---@return aineo.entry.Tab
local function make_tab(homes, key, on_bound)
  ---@type aineo.entry.Tab
  local tab = { key = key, homes = homes }

  --- The tab page the tab is in, once its layout has opened in it; nil before.
  ---@type integer?
  local bound_page = nil

  --- Whether the tab has been released (`release()`): what its Claude Code
  --- tells it while it stops writes nothing. Cleared when the first tab is
  --- opened again (`reopen()`).
  local is_released = false

  --- Whether the first tab has been opened again after it closed
  --- (`reopen()`): it starts in the folder, as every tab after the first.
  local is_reopened = false

  --- Whether the report home has been given its environment yet.
  local report_environment_given = false

  --- Gives the report home the editor's clock, and the state directory and
  --- working directory of `kept_places()`, the first time only.
  local function give_report_environment()
    if report_environment_given then
      return
    end
    homes.report.set_report_environment({
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
  --- draft of the Claude session the panes follow (`follow_session()`) — of
  --- the working directory of `kept_places()` until they follow one — and
  --- restores that draft into it when it is new and empty (`aineo.draft`'s
  --- `keep_draft()`); gives the draft home that environment the first time.
  --- Raises nothing.
  local function keep_input_draft()
    local draft = homes.draft
    if not draft_environment_given then
      draft.set_draft_environment(kept_places())
      draft_environment_given = true
    end
    draft.keep_draft(homes.layout.input_buffer())
  end

  --- Makes the Report, Input's draft and the changes pane the Claude session
  --- `id`'s: tells the report home (`aineo.report`'s
  --- `follow_report_session()`), then the draft home (`aineo.draft`'s
  --- `follow_draft_session()`), then the changes home (`aineo.changes`'s
  --- `follow_changes_session()`, its base and saves kept under the state
  --- directory of `kept_places()`). Each home changes nothing for the session
  --- it follows already, and shows the new session's content in the windows
  --- that show its buffers at once, or when they are next shown.
  ---
  --- A follow told `{ claim = true }` is a claim's: the report and draft homes
  --- then move nothing of the working directory's (their `claim` option).
  ---
  ---@param id string Claude Code's session id
  ---@param options? { claim: boolean? }
  local function follow_session(id, options)
    homes.report.follow_report_session(id, options)
    homes.draft.follow_draft_session(id, options)
    homes.changes.follow_changes_session({
      id = id,
      state_directory = kept_places().state_directory,
    })
  end

  --- The session the panes follow, as `follow_session()` was last told it
  --- through this file's own follows; nil before the first.
  ---@type string?
  local panes_session = nil

  --- The session `:Aineo claim <id>`, or a switch of the session it claimed,
  --- made the panes follow, as a claim of it; nil while they follow the
  --- session of the tab's own Claude terminal.
  ---@type string?
  local claimed_by_id = nil

  --- The session whose claim file this Neovim wrote for this tab, while it may
  --- still name it; nil when the tab claims none.
  ---@type string?
  local claimed = nil

  --- Whether a claim of another session holds: the panes follow a session
  --- that `:Aineo claim <id>` made them follow, or that a switch moved that
  --- claim to, and it is not the session of the tab's own Claude terminal
  --- (`aineo.claude`'s `session_id()`).
  ---
  ---@return boolean
  local function holds_other_claim()
    return claimed_by_id ~= nil and claimed_by_id ~= homes.claude.session_id()
  end

  --- Lets go the tab's claim (`claimed`), if its claim file still names this
  --- Neovim (`aineo.mcp`'s `release_claim()`).
  local function release_claim()
    if claimed then
      require('aineo.mcp').release_claim(kept_places().state_directory, claimed, vim.v.servername)
      claimed = nil
    end
  end

  --- Writes, unless Neovim is quitting (`v:exiting`), the tab's entry in the
  --- list of running editors (`aineo.mcp`'s `write_editor_entry()`): the
  --- editor's address, the directory it started in, the session the panes
  --- follow, whether that is its own terminal's (`holds_other_claim()`), now as
  --- its last use, and the tab's key. It writes none before the panes follow a
  --- session, nor for a Neovim with no server address. An entry that cannot be
  --- written is told to the user as a warning. Defined below, with the
  --- handlers it makes.
  ---@type fun()
  local write_entry

  --- Makes this Neovim the claimant of `session` (`aineo.mcp`'s
  --- `claim_session()`) for the tab, letting go any session the tab claimed
  --- before, unless Neovim is quitting.
  ---
  ---@param session string
  local function claim(session)
    if is_released or vim.v.exiting ~= vim.NIL then
      return
    end
    if claimed ~= session then
      release_claim()
    end
    require('aineo.mcp').claim_session(
      kept_places().state_directory,
      session,
      vim.v.servername,
      microseconds_now()
    )
    claimed = session
  end

  --- Whether the tab claims `session` now: it wrote the claim file, and that
  --- file still names this Neovim (`aineo.mcp`'s `session_claimant()`).
  ---
  ---@param session string
  ---@return boolean
  local function claims(session)
    if claimed ~= session then
      return false
    end
    local claimant = require('aineo.mcp').session_claimant(kept_places().state_directory, session)
    return claimant == vim.v.servername
  end

  --- Tells the user, once for each session and tab, that `session`, which the
  --- panes of this tab follow, is followed by the panes of another tab of this
  --- Neovim too.
  ---@type table<string, true>
  local shared_session_told = {}

  ---@param session string
  local function warn_when_open_in_another_tab(session)
    local other = tab_following(session, tab)
    if other and not shared_session_told[session .. (other.key or '')] then
      shared_session_told[session .. (other.key or '')] = true
      vim.notify(
        ('aineo: this session is also open in tab %d'):format(tab_number(other)),
        vim.log.levels.WARN
      )
    end
  end

  --- Makes the panes follow `id`, the session of the tab's own Claude terminal
  --- (`follow_session()`), ending any claim of another session; a claim of a
  --- session other than `id` is let go. Writes the entry, and warns when
  --- another tab follows the session too (`warn_when_open_in_another_tab()`).
  ---
  ---@param id string
  local function follow_own_session(id)
    follow_session(id)
    panes_session = id
    claimed_by_id = nil
    if claimed and claimed ~= id then
      release_claim()
    end
    write_entry()
    warn_when_open_in_another_tab(id)
    keep_folder_tabs()
  end

  --- Makes the panes follow `id` as a claim of it, a session the tab's own
  --- Claude terminal does not run (`follow_session()` told a claim's, which
  --- moves nothing), and writes the entry.
  ---
  ---@param id string
  local function follow_claimed_session(id)
    follow_session(id, { claim = true })
    panes_session = id
    claimed_by_id = id
    write_entry()
  end

  --- What the tab does with a switch of a Claude Code it does not run, from
  --- `left` to `new`, told by the deliverer of that Claude Code's hook
  --- (`aineo.mcp`'s `on_followed_switch()`): when the panes follow `left` by
  --- a claim of it, they follow `new` the same way — or as their own, when
  --- `new` is the tab's own terminal's — and when the tab claims `left`, it
  --- claims `new`. Anything else does nothing. Once Neovim is quitting, it
  --- writes neither an entry nor a claim (`write_entry()`, `claim()`).
  ---
  ---@param left string
  ---@param new string
  local function follow_told_switch(left, new)
    local claimant = claims(left)
    if claimed_by_id ~= left and not claimant then
      return
    end
    if new == homes.claude.session_id() then
      follow_own_session(new)
    else
      follow_claimed_session(new)
    end
    if claimant then
      claim(new)
    end
  end

  write_entry = function()
    if is_released or vim.v.exiting ~= vim.NIL or not panes_session or vim.v.servername == '' then
      return
    end
    make_editor_handlers()
    local written, failure =
      pcall(require('aineo.mcp').write_editor_entry, kept_places().state_directory, {
        address = vim.v.servername,
        working_directory = kept_places().working_directory,
        session = panes_session,
        own = not holds_other_claim(),
        used = microseconds_now(),
        tab = key,
      })
    if not written then
      vim.notify('aineo: ' .. tostring(failure), vim.log.levels.WARN)
    end
  end

  --- Whether the Claude Code aineo started last has been confirmed: it has
  --- been ready for input once (`aineo.claude`'s `on_session_ready`). Until
  --- then the panes stay on the session they followed before it, except that
  --- a hand-over at a resume with no conversation moves panes that showed the
  --- dead session to the new one (`hand_over_dead_session()`); no other
  --- switch it tells is followed.
  local start_confirmed = false

  --- Forgets that a start was confirmed (`start_confirmed`) when no Claude
  --- Code runs — none has started, or the last has exited — and so the next
  --- start launches a new one, which must be confirmed in turn. Called before
  --- that start: the switch to a session another than the one followed,
  --- which `aineo.claude` tells before `start_session()` returns for a start on
  --- a new id, and when Claude Code launches for a start that resumes, is then
  --- not followed.
  local function forget_confirmation_unless_running()
    local status = homes.claude.session_status()
    if status == nil or status == 'exited' then
      start_confirmed = false
    end
  end

  --- Confirms the start of Claude Code that has become ready for input
  --- (`start_confirmed`), and makes the panes the session `id`'s, the one it
  --- is on then (`follow_own_session()`) — unless a claim of another session
  --- holds (`holds_other_claim()`), which keeps them where they are.
  ---
  ---@param id string
  local function follow_confirmed_start(id)
    start_confirmed = true
    if not holds_other_claim() then
      follow_own_session(id)
    end
  end

  --- Makes the panes the session `id`'s (`follow_own_session()`), Claude Code
  --- having switched to it from `left`, once the start that runs has been
  --- confirmed (`start_confirmed`), and moves the tab's claim of `left`,
  --- if it still claims it, to `id`; before the confirmation, and while a
  --- claim of another session holds (`holds_other_claim()`), does nothing:
  --- the confirmation follows the session the start is on then, and a claim
  --- keeps the panes where they are.
  ---
  ---@param id string
  ---@param _ string? how Claude Code started `id`
  ---@param left string the session left
  local function follow_switch_once_confirmed(id, _, left)
    if not start_confirmed or holds_other_claim() then
      return
    end
    local moves_claim = claimed == left and claims(left)
    follow_own_session(id)
    if moves_claim then
      claim(id)
    end
  end

  --- Hands what aineo keeps for the Claude session `dead`, whose resume
  --- Claude Code found no conversation for, over to `fresh`, the session
  --- that took its place: the Report's records, then Input's draft, then the
  --- changes pane's base and saves, kept under the state directory of
  --- `kept_places()` (`aineo.report`'s `hand_over_report_session()`,
  --- `aineo.draft`'s `hand_over_draft_session()`, `aineo.changes`'s
  --- `hand_over_changes_session()`). A pane that showed `dead` shows the same
  --- under `fresh` from then on, before `fresh` is ready.
  ---
  --- Hands nothing over while a Claude Code aineo knows of runs on `dead`
  --- (`aineo.mcp`'s `running_sessions()`, asked with `working_directory`, the
  --- directory the resume started in, which a record of a Claude Code on
  --- `dead` names): another Neovim's Claude Code that has sent nothing yet
  --- makes a resume of its session find no conversation too.
  ---
  --- A claim of another session does not hold the hand-over: the files move,
  --- and the panes stay on the claimed session. The tab's claim of `dead`
  --- is let go (`release_claim()`), and a claim made with `dead`'s id ends:
  --- the panes then follow `fresh` as the tab's own. When the panes
  --- followed `dead`, they follow `fresh` (`panes_session`), and the tab's
  --- entry in the list of running editors is written for it
  --- (`write_entry()`).
  ---
  ---@param dead string
  ---@param fresh string
  ---@param working_directory string
  local function hand_over_dead_session(dead, fresh, working_directory)
    local running =
      require('aineo.mcp').running_sessions(kept_places().state_directory, working_directory)
    if vim.tbl_contains(running, dead) then
      return
    end
    homes.report.hand_over_report_session(dead, fresh)
    homes.draft.hand_over_draft_session(dead, fresh)
    homes.changes.hand_over_changes_session({
      from = dead,
      to = fresh,
      state_directory = kept_places().state_directory,
    })
    if claimed == dead then
      release_claim()
    end
    if claimed_by_id == dead then
      claimed_by_id = nil
    end
    if panes_session == dead then
      panes_session = fresh
      write_entry()
    end
    keep_folder_tabs()
  end

  --- The terminal of the Claude session aineo started last — the new
  --- session's once one took the place of a resume Claude Code found no
  --- conversation for — or `nil` before it has started one.
  ---@type integer|nil
  local claude_terminal = nil

  --- Makes the tab the one in the tab page the current window is in, once its
  --- layout has opened there; and tells `on_bound` of it. Does nothing for a
  --- tab bound to a tab page that exists still.
  local function bind_to_current_page()
    if bound_page and vim.api.nvim_tabpage_is_valid(bound_page) then
      return
    end
    bound_page = vim.api.nvim_get_current_tabpage()
    on_bound(tab)
  end

  --- The two callbacks a start of Claude Code in `working_directory` hands
  --- the claude home (`aineo.claude`'s `start_session()`) for a resume Claude
  --- Code finds no conversation for. `on_terminal_replaced`, which the claude
  --- home calls only then, makes the new terminal `claude_terminal` and the
  --- layout's Claude terminal (`aineo.layout`'s `follow_claude_terminal()`),
  --- and notes the new session's id (`aineo.claude`'s `session_id()`, which
  --- names it there). The switch told next whose id is that note and whose
  --- source is `startup` is that new session taking the dead one's place: it
  --- is handed what aineo kept for the dead one (`hand_over_dead_session()`)
  --- and is not followed now. Every other switch goes to
  --- `follow_switch_once_confirmed()`.
  ---
  --- The note is the new id, not a flag, and each start has its own: a
  --- handler that raised before its switch was told leaves the note set, and
  --- a later switch of the same start told with the source `startup` — a
  --- session hook relayed to this editor, say — then hands nothing over
  --- unless its id is that new session's.
  ---
  ---@param working_directory string
  ---@return { on_terminal_replaced: fun(terminal: integer), on_session_switched: fun(id: string, source: string?, left: string) }
  local function replacement_callbacks(working_directory)
    local replacing_session = nil
    return {
      on_terminal_replaced = function(terminal)
        replacing_session = homes.claude.session_id()
        claude_terminal = terminal
        redraw_tab_line_when_named(terminal)
        homes.layout.follow_claude_terminal(terminal)
      end,
      on_session_switched = function(id, source, left)
        if id == replacing_session and source == 'startup' then
          replacing_session = nil
          hand_over_dead_session(left, id, working_directory)
          return
        end
        follow_switch_once_confirmed(id, source, left)
      end,
    }
  end

  --- The settings a start of Claude Code in `working_directory` is given
  --- (`aineo.claude`'s `start_session()` and `join_session()`): `config`'s
  --- `claude.cmd`, the report server and instructions, the state directory of
  --- `kept_places()`, the editor's address and program for the session hooks,
  --- and the callbacks that make the panes follow the session
  --- (`replacement_callbacks()`, `follow_confirmed_start()`). With
  --- `new_session` the start is on a new session id.
  ---
  ---@param config table the resolved configuration
  ---@param working_directory string
  ---@param new_session? boolean
  ---@return aineo.claude.Settings
  local function claude_settings(config, working_directory, new_session)
    local report = require('aineo.report')
    local mcp = require('aineo.mcp')
    local replacement = replacement_callbacks(working_directory)
    return {
      cmd = config.claude.cmd,
      cwd = working_directory,
      mcp_servers = mcp.mcp_servers(vim.v.servername, vim.v.progpath),
      allowed_tools = mcp.allowed_mcp_tools(),
      instructions = report.report_instructions(mcp.report_tool_name()),
      state_directory = kept_places().state_directory,
      new_session = new_session,
      editor_address = vim.v.servername,
      editor_program = vim.v.progpath,
      on_terminal_replaced = replacement.on_terminal_replaced,
      on_session_ready = follow_confirmed_start,
      on_session_switched = replacement.on_session_switched,
    }
  end

  --- Whether the tab was opened from the folder's list (`open_on_session()`):
  --- it starts in the folder, as every tab after the first.
  local opened_from_list = false

  --- The directory a start of the tab's Claude Code runs in. The first tab
  --- starts where the editor is, as it always has: Claude Code follows `:cd`
  --- there, each directory resuming its own session. Every tab after it, and
  --- the first tab opened again after it closed, starts in the folder, the working directory of `kept_places()`, whatever
  --- `:cd` and `:tcd` say later, since a tab holds a session of the folder
  --- alone.
  ---
  ---@return string
  local function start_directory()
    if key == nil and not is_reopened and not opened_from_list then
      return vim.fn.getcwd()
    end
    return kept_places().working_directory
  end

  --- Starts Claude Code as `start` does, in the directory `start_directory()`
  --- names, and returns its terminal, which it keeps as `claude_terminal`.
  --- `start` is called with the tab's Claude session home and the settings of
  --- the start (`claude_settings()`, a new session id when `new_session`).
  --- The panes follow the session the start is on once Claude Code is first
  --- ready for input, and then each session it switches to; not before, and
  --- nothing for a start that never becomes ready (`follow_confirmed_start()`,
  --- `follow_switch_once_confirmed()`). Once the start has succeeded, the
  --- changes home is told the session began there (`aineo.changes`'s
  --- `begin_session()`, which heeds its first call alone), in Claude Code's
  --- working directory, with the layout's `show_diff()` to show its diffs in
  --- the middle column and the configuration's `changes.working_branch`.
  ---
  ---@param config table the resolved configuration
  ---@param new_session boolean? start on a new session id
  ---@param start fun(claude: table, settings: aineo.claude.Settings): integer
  ---@return integer terminal
  local function begin_claude(config, new_session, start)
    local working_directory = start_directory()
    forget_confirmation_unless_running()
    claude_terminal = start(homes.claude, claude_settings(config, working_directory, new_session))
    redraw_tab_line_when_named(claude_terminal)
    homes.changes.begin_session({
      directory = working_directory,
      show_diff = function(diff)
        return homes.layout.show_diff(diff)
      end,
      working_branch = config.changes.working_branch,
    })
    return claude_terminal
  end

  --- Starts Claude Code with `config` when none runs — again once the last
  --- has exited — and returns its terminal, which it keeps as
  --- `claude_terminal`. While one runs it starts nothing and returns that
  --- session's terminal (`aineo.claude`'s `start_session()`). Claude Code
  --- starts in the directory `start_directory()` names, resuming the session
  --- kept for it under the state directory of `kept_places()`, its session
  --- hooks told the editor's address and program. When the session puts a
  --- new terminal in place of one whose resume found no conversation, that
  --- terminal becomes `claude_terminal` and the layout's Claude terminal,
  --- and the new session is handed what aineo kept for the dead one at once
  --- (`replacement_callbacks()`). With `new_session` the start is on a new
  --- session id, not the kept one, and lists no sessions. The rest is
  --- `begin_claude()`'s.
  ---
  ---@param config table the resolved configuration
  ---@param new_session? boolean start on a new session id rather than resume the kept one
  ---@return integer terminal
  local function started_claude_terminal(config, new_session)
    return begin_claude(config, new_session, function(claude, settings)
      return claude.start_session(settings)
    end)
  end

  --- Starts Claude Code on `listed`, a session a pick of `\S` chose
  --- (`begin_claude()`): joined where another process runs it and aineo can
  --- (`aineo.claude`'s `join_session()`, given `sessions`, the list just
  --- read) — attached to in Claude Code's background service, or resumed with
  --- the warning where it is open in another interactive Claude Code — else
  --- resumed (`aineo.claude`'s `replace_session()`). The tab's Claude Code has
  --- none running, so both are a start; the session is kept for the folder.
  ---
  ---@param config table the resolved configuration
  ---@param listed aineo.claude.ListedSession
  ---@param sessions aineo.claude.ListedSession[]
  ---@return integer terminal
  local function claude_terminal_on_session(config, listed, sessions)
    return begin_claude(config, false, function(claude, settings)
      if claude.can_join_session(listed) then
        return claude.join_session(settings, listed, sessions)
      end
      return claude.replace_session(settings, { id = listed.session_id, resumed = true })
    end)
  end

  --- Starts Claude Code on the session `id` (`begin_claude()`): resumed
  --- (`aineo.claude`'s `start_session()` with `resume_session`), attached to
  --- where the list of the folder's sessions shows it in Claude Code's
  --- background service, else as `start_session()` starts any resume. Keeps
  --- no session for the folder.
  ---
  ---@param config table the resolved configuration
  ---@param id string
  ---@return integer terminal
  local function claude_terminal_resuming(config, id)
    return begin_claude(config, false, function(claude, settings)
      return claude.start_session(vim.tbl_extend('force', settings, { resume_session = id }))
    end)
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

  --- The changes pane's two buffers, from the changes home (`aineo.changes`'s
  --- `pane_buffers()`), which lists the session's files and commits there.
  --- While either is shown in a window, as when `\o` restores the layout with
  --- the changes pane shown, the home reads both lists again first
  --- (`refresh_shown_pane()`).
  ---
  ---@return aineo.layout.ChangesPane
  local function changes_pane()
    local changes = homes.changes
    changes.refresh_shown_pane()
    return changes.pane_buffers()
  end

  --- The buffers aineo's layout shows: `claude_buffer`, the Claude session's
  --- terminal, the Report, taken from the report home, which this gives its
  --- environment the first time it is called (`give_report_environment()`),
  --- the changes pane's (`changes_pane()`) and the terminal of the tab's
  --- shell while it runs one (`aineo.shell`'s `shell_buffer()`), none
  --- otherwise; with the Report's share from `config`, and the status line of
  --- Claude's window, which draws the session's name and folder
  --- (`aineo.claude`'s `session_statusline()`).
  ---
  ---@param config table the resolved configuration
  ---@param claude_buffer integer
  ---@return aineo.layout.Arrangement
  local function arrangement(config, claude_buffer)
    give_report_environment()
    return {
      claude = claude_buffer,
      report = homes.report.report_buffer(),
      report_height = config.layout.report_height,
      changes = changes_pane(),
      shell = homes.shell.shell_buffer(),
      claude_statusline = require('aineo.claude').session_statusline(),
    }
  end

  --- Opens aineo's layout around `terminal`, Claude's, or restores the layout
  --- while it is open. The tab is in the tab page the layout opened in from
  --- then on (`bind_to_current_page()`). Input is then handed to the draft home
  --- (`keep_input_draft()`).
  ---
  ---@param config table the resolved configuration
  ---@param terminal integer
  local function open_layout_around(config, terminal)
    homes.layout.open(arrangement(config, terminal))
    bind_to_current_page()
    keep_input_draft()
  end

  --- Opens aineo's layout around the Claude session, starting it when none
  --- runs — a new one once the last has exited — or restores the layout while
  --- it is open. The session's terminal is shown in the tick it starts in
  --- (`aineo.claude`'s `start_session()`).
  local function open()
    local config = resolved_config()
    open_layout_around(config, started_claude_terminal(config))
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
    homes.layout.focus(role, function()
      opened = true
      return arrangement(config, current_claude_terminal(config))
    end)
    if opened then
      bind_to_current_page()
      keep_input_draft()
    end
  end

  --- Shows `pane` in the layout's right column and moves the cursor into it
  --- (`aineo.layout`'s `focus_pane()`): into the Report under the agent pane,
  --- into the commits window under the changes pane, into the Report's window
  --- under the terminal pane, which shows the shell there (Terminal mode is
  --- `focus_terminal()`'s), though the pane was shown already. When the layout
  --- must open first, it opens as `focus()` opens it, around the Claude
  --- session's terminal as it is, and Input is then handed to the draft home
  --- (`keep_input_draft()`). The changes pane, already shown, is read again
  --- first (`aineo.changes`'s `refresh_shown_pane()`), as showing it anew
  --- reads it.
  ---
  ---@param pane aineo.layout.Pane
  local function focus_pane(pane)
    local config = resolved_config()
    if pane == 'changes' then
      homes.changes.refresh_shown_pane()
    end
    local opened = false
    homes.layout.focus_pane(pane, function()
      opened = true
      return arrangement(config, current_claude_terminal(config))
    end)
    if opened then
      bind_to_current_page()
      keep_input_draft()
    end
  end

  --- Shows the tab's shell in the layout's terminal pane and moves the cursor
  --- into it, in Terminal mode, starting the shell in the folder
  --- (`kept_places()`'s working directory, whatever `:cd` or `:tcd` says) when
  --- the tab runs none (`aineo.shell`'s `start()`), which starts nothing while
  --- the shell lives. The shell starts before the layout is touched, so that a
  --- `'shell'` that cannot run, which raises, changes no pane; and a layout
  --- that cannot open, as when Claude Code cannot start, stops the shell this
  --- call started and raises the layout's error, so that no shell runs that
  --- nothing shows. Raises `FOLDER_GONE` when the folder no longer exists.
  --- Terminal mode is asked for as `focus_claude()` asks for it: Neovim enters
  --- it once the outermost mapping or command around it has ended, in the
  --- window current then, the shell's.
  local function focus_terminal()
    local folder = kept_places().working_directory
    if vim.fn.isdirectory(folder) == 0 then
      error(FOLDER_GONE:format(folder), 0)
    end
    local ran_one = homes.shell.shell_buffer() ~= nil
    homes.shell.start({ cwd = folder })
    local shown, failure = pcall(focus_pane, 'terminal')
    if not shown then
      if not ran_one then
        homes.shell.stop()
      end
      error(failure, 0)
    end
    vim.cmd.startinsert()
  end

  --- Whether the current buffer is the Claude session's terminal and that
  --- session has not ended: where a key typed in Terminal mode reaches Claude
  --- Code. A key typed in Terminal mode on an ended session's terminal closes
  --- it; another buffer shown in Claude's window is not Claude's to type to,
  --- nor is the empty buffer a start that waits for the list of sessions shows
  --- until Claude Code launches in it.
  ---
  ---@return boolean
  local function can_type_to_claude()
    return vim.api.nvim_get_current_buf() == claude_terminal
      and vim.bo.buftype == 'terminal'
      and homes.claude.session_status() ~= 'exited'
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

  --- Makes the panes follow the session of the tab's own Claude terminal
  --- (`aineo.claude`'s `session_id()`), as its own, and claims that session
  --- (`claim()`): what `:Aineo claim` with no argument does, whether a claim
  --- of another session holds or not. In a Neovim whose terminal runs no
  --- session (`NO_OWN_SESSION`), or before the running start is confirmed
  --- (`NOT_READY_TO_CLAIM`), it warns once and changes nothing.
  local function claim_own_session()
    local own = homes.claude.session_id()
    if not own then
      vim.notify(NO_OWN_SESSION, vim.log.levels.WARN)
      return
    end
    if not start_confirmed then
      vim.notify(NOT_READY_TO_CLAIM, vim.log.levels.WARN)
      return
    end
    follow_own_session(own)
    claim(own)
    write_entry()
  end

  --- Makes the panes follow the session `id` as a claim of it, and claims it
  --- (`claim()`): what `:Aineo claim {id}` does, and what a session picker
  --- calls. Nothing is sent to Claude Code, whose terminal runs on its own
  --- session. The report home is given its environment first
  --- (`give_report_environment()`), so that it takes the session's reports
  --- before aineo's layout has opened. The id of the tab's own terminal's
  --- session claims it as `claim_own_session()` does.
  ---
  --- Raises an error naming `id` when it is not a session id of the form
  --- Claude Code gives (`aineo.claude`'s `is_session_id()`), and changes
  --- nothing then.
  ---
  ---@param id string
  local function claim_session(id)
    if not require('aineo.claude').is_session_id(id) then
      error((':Aineo claim takes a Claude session id, not %s'):format(id), 0)
    end
    if id == homes.claude.session_id() then
      claim_own_session()
      return
    end
    give_report_environment()
    follow_claimed_session(id)
    claim(id)
  end

  --- What tells the user how to leave a claim of another session
  --- (`holds_other_claim()`): what returns the tab to its own session, or,
  --- when its Claude terminal runs no session, what else works here.
  ---
  ---@return string
  local function way_out_of_claim()
    return homes.claude.session_id()
        and ':Aineo claim with no argument returns this Neovim to its own session'
      or ':Aineo claim {id} follows another session, :Aineo open starts Claude Code here'
  end

  --- Whether Send is refused while a claim of another session holds
  --- (`holds_other_claim()`): Input then holds the claimed session's draft,
  --- which the tab's own Claude terminal, running another session, must
  --- not get. Tells the user why once, with one warning, naming the claimed
  --- session and what returns the tab to its own, or, when its terminal
  --- runs no session, what else works here.
  ---
  ---@return boolean refused
  local function refuses_send_while_claimed()
    if not holds_other_claim() then
      return false
    end
    vim.notify(
      ('aineo: nothing sent — Input holds the draft of the claimed session %s; %s'):format(
        claimed_by_id,
        way_out_of_claim()
      ),
      vim.log.levels.WARN
    )
    return true
  end

  --- Whether `:Aineo sessions` must do nothing while a claim of another
  --- session holds (`holds_other_claim()`): the panes follow the claimed
  --- session, which the tab's own Claude terminal does not run, and a
  --- switch would change that terminal's session behind them. Tells the user
  --- why once, with one warning that begins `outcome`, the words of what was
  --- not done, naming the claimed session and the way out
  --- (`way_out_of_claim()`).
  ---
  ---@param outcome string
  ---@return boolean refused
  local function refuses_while_claimed(outcome)
    if not holds_other_claim() then
      return false
    end
    vim.notify(
      (
        outcome
        .. 'the panes follow the claimed session %s, which this Neovim’s Claude terminal does not run; %s'
      ):format(claimed_by_id, way_out_of_claim()),
      vim.log.levels.WARN
    )
    return true
  end

  --- Whether `:Aineo sessions` must do nothing because Claude Code is not
  --- ready for input (`NOT_READY`). Tells the user why once, with one warning
  --- that begins `outcome`, the words of what was not done.
  ---
  ---@param outcome string
  ---@return boolean refused
  local function refuses_while_not_ready(outcome)
    local status = homes.claude.session_status()
    if status == 'ready' then
      return false
    end
    vim.notify(outcome .. NOT_READY[status or 'not_started'], vim.log.levels.WARN)
    return true
  end

  --- Whether a read of the sessions Claude Code lists is running
  --- (`read_sessions()`).
  local session_read_in_flight = false

  --- Whether `:Aineo sessions` must start nothing because a read of the
  --- sessions is running: tells the user once, with one warning that begins
  --- `outcome`, the words of what was not done.
  ---
  ---@param outcome string
  ---@return boolean refused
  local function refuses_while_reading_sessions(outcome)
    if not session_read_in_flight then
      return false
    end
    vim.notify(outcome .. 'a session list is still being read', vim.log.levels.WARN)
    return true
  end

  --- Reads the sessions Claude Code lists for `directory` without waiting for
  --- them (`aineo.claude`'s `list_sessions()`), and calls `on_read` with them,
  --- or with the problem to tell the user, from a callback that tells the user
  --- once an error it raises (`run()`). Only one read runs at a time
  --- (`refuses_while_reading_sessions()`).
  ---
  ---@param directory string
  ---@param on_read fun(listed: aineo.claude.ListedSession[]?, problem: string?)
  local function read_sessions(directory, on_read)
    require('aineo.claude').list_sessions(
      resolved_config().claude.cmd,
      directory,
      function(listed, problem)
        session_read_in_flight = false
        run(function()
          on_read(listed, problem)
        end)
      end
    )
    session_read_in_flight = true
  end

  --- Moves to Claude's window in Terminal mode (`focus_claude()`) and, once
  --- there, calls `act`, unless the prompt shows text (`aineo.claude`'s
  --- `prompt_shows_text()`, read in Terminal mode). When it shows text it
  --- acts on nothing, puts the cursor back where it was (`return_to()`) and
  --- tells the user `prompt_holds_text`, as a warning. When Terminal mode is
  --- not entered it acts on nothing either, puts the cursor back, and tells
  --- the user so with a warning that begins `outcome`. Claude Code must be
  --- running and ready (`refuses_while_not_ready()`).
  ---
  ---@param outcome string the words that begin a warning of what was not done
  ---@param prompt_holds_text string
  ---@param act fun() what to do at the empty prompt, from Claude's window
  local function at_empty_prompt(outcome, prompt_holds_text, act)
    local claude = homes.claude
    local terminal = claude_terminal
    local origin = { window = vim.api.nvim_get_current_win(), mode = vim.api.nvim_get_mode().mode }
    focus_claude()
    after_entering_terminal_mode(terminal, outcome, function()
      run(function()
        if claude.prompt_shows_text(vim.api.nvim_get_current_win()) then
          return_to(origin)
          vim.notify(prompt_holds_text, vim.log.levels.WARN)
          return
        end
        act()
      end)
    end, function()
      return_to(origin)
    end)
  end

  --- Moves to Claude's window in Terminal mode and, at an empty prompt there
  --- (`at_empty_prompt()`), writes `command` as a bracketed paste followed by
  --- Enter, in one write as Send writes (`aineo.send`).
  ---
  ---@param outcome string the words that begin a warning of what was not done
  ---@param prompt_holds_text string
  ---@param command string
  local function write_command_at_empty_prompt(outcome, prompt_holds_text, command)
    at_empty_prompt(outcome, prompt_holds_text, function()
      homes.claude.write_to_session(PASTE_START .. command .. PASTE_END .. '\r')
    end)
  end

  --- Puts the terminal `replace` makes in Claude's window in place of the one
  --- that ran: `replace` is called with the tab's Claude session home and the
  --- settings of a start in the session's directory (`claude_settings()`), built first so that
  --- an error building them changes nothing, and returns the new terminal. The
  --- new terminal becomes Claude's (`claude_terminal`, the layout's). The start
  --- is not confirmed until the new Claude Code is ready, so that the panes
  --- follow it then (`follow_confirmed_start()`); when `replace` raises, the
  --- confirmation stays as it was, since the Claude Code that ran goes on, and
  --- the error is raised again. Terminal mode is asked for in Claude's window
  --- once the swap has left it: swapping the buffer ends Terminal mode, and the
  --- old terminal's exit ends it again.
  ---
  ---@param replace fun(claude: table, settings: aineo.claude.Settings): integer
  local function replace_claude_terminal(replace)
    local claude = homes.claude
    local settings = claude_settings(resolved_config(), claude.session_directory())
    local was_confirmed = start_confirmed
    start_confirmed = false
    local replaced, terminal = pcall(replace, claude, settings)
    if not replaced then
      start_confirmed = was_confirmed
      error(terminal, 0)
    end
    claude_terminal = terminal
    redraw_tab_line_when_named(terminal)
    homes.layout.follow_claude_terminal(claude_terminal)
    vim.api.nvim_create_autocmd('ModeChanged', {
      pattern = 't:*',
      once = true,
      callback = function()
        vim.schedule(focus_claude)
      end,
    })
  end

  --- Replaces Claude's window's Claude Code, which is attached to a background
  --- session, with a start of aineo's own (`aineo.claude`'s `replace_session()`):
  --- a new session when `choice` is nil, else the session it names, resumed. A
  --- command written into an attached Claude Code would reach the background
  --- session. Only at an empty prompt (`at_empty_prompt()`).
  ---
  ---@param outcome string the words that begin a warning of what was not done
  ---@param prompt_holds_text string
  ---@param choice? aineo.claude.SessionChoice
  local function replace_attached_session(outcome, prompt_holds_text, choice)
    at_empty_prompt(outcome, prompt_holds_text, function()
      replace_claude_terminal(function(claude, settings)
        return claude.replace_session(settings, choice)
      end)
    end)
  end

  --- Whether a pick of `listed` opens no tab for where the session stands
  --- (`aineo.claude`'s `session_standing()`), the pick being settled here: a
  --- session a tab of this editor shows moves to that tab, the lowest numbered
  --- of those that show it, and starts nothing, or stays where it is when the
  --- current tab shows it itself; one another process runs and aineo
  --- cannot join (`aineo.claude`'s `can_join_session()`, which also needs it to
  --- have started in the folder), one started in another folder, and one
  --- whose Claude Code a closed tab still stops (`stops_in_closed_tab()`) are
  --- refused with one warning that says why.
  ---
  ---@param listed aineo.claude.ListedSession
  ---@param folder string
  ---@return boolean settled
  local function settles_by_standing(listed, folder)
    local claude = require('aineo.claude')
    local session = homes.claude
    local name = claude.listed_session_name(listed)
    local shown = sessions_shown_in_tabs()
    local standing = claude.session_standing(listed, shown, folder)
    if standing == 'shown' then
      local current = tab_of_current_page()
      local page = vim.api.nvim_list_tabpages()[shown[listed.session_id]]
      if page and not (current and current.session_id() == listed.session_id) then
        vim.api.nvim_set_current_tabpage(page)
      end
    elseif stops_in_closed_tab(listed.session_id) then
      vim.notify(
        NOT_SWITCHED .. name .. ' still stops in a closed tab; pick it again in a moment',
        vim.log.levels.WARN
      )
      return true
    elseif standing == 'elsewhere' then
      if session.can_join_session(listed, folder) then
        return false
      end
      if session.can_join_session(listed) then
        vim.notify(started_elsewhere(name, listed.cwd), vim.log.levels.WARN)
      else
        vim.notify(runs_elsewhere(name), vim.log.levels.WARN)
      end
    elseif standing == 'another_folder' then
      vim.notify(started_elsewhere(name, listed.cwd), vim.log.levels.WARN)
    end
    return standing ~= 'switchable'
  end

  --- Acts on the pick of `listed`, a session of the list `list_sessions()`
  --- offered. Opens no tab, and tells the user why, when `listed` is not a
  --- session id — a menu is another plugin's, and the id is typed into Claude
  --- Code's command — and when it stands for no new tab
  --- (`settles_by_standing()`). Otherwise reads the list again, since the menu
  --- may have been open for long, and opens a tab at the end on the
  --- session (`open_new_tab()`) only if it is still listed and still stands for
  --- one: resumed, attached to, or resumed with a warning. The current tab's
  --- Claude Code, prompt and panes are not touched.
  ---
  ---@param listed aineo.claude.ListedSession
  local function pick_listed_session(listed)
    local claude = require('aineo.claude')
    if not claude.is_session_id(listed.session_id) then
      vim.notify(NOT_SWITCHED .. 'what was picked is not a Claude session id', vim.log.levels.WARN)
      return
    end
    local folder = kept_places().working_directory
    if settles_by_standing(listed, folder) or refuses_while_reading_sessions(NOT_SWITCHED) then
      return
    end
    local name = claude.listed_session_name(listed)
    read_sessions(folder, function(now, problem)
      if problem then
        vim.notify(NOT_SWITCHED .. problem, vim.log.levels.WARN)
        return
      end
      local current = vim.iter(now):find(function(session)
        return session.session_id == listed.session_id
      end)
      if not current then
        vim.notify(NOT_SWITCHED .. name .. ' is no longer listed', vim.log.levels.WARN)
        return
      end
      if not settles_by_standing(current, folder) then
        open_new_tab(function(opened)
          opened.start_on_session(current, now)
        end)
      end
    end)
  end

  --- Offers `listed`, the sessions Claude Code lists for `folder`, in
  --- `vim.ui.select`, each row marking the sessions the editor's tabs show;
  --- a pick is acted on by `pick_listed_session()`, which reports an error it
  --- raises once. Offers nothing, and tells the user why, when Claude Code
  --- could not list them (`problem`) or lists none.
  ---
  ---@param listed aineo.claude.ListedSession[]?
  ---@param problem string?
  ---@param folder string
  local function offer_sessions(listed, problem, folder)
    if problem then
      vim.notify(NO_LIST .. problem, vim.log.levels.WARN)
      return
    end
    if #listed == 0 then
      vim.notify(NO_LIST .. 'Claude Code lists no session for ' .. folder, vim.log.levels.WARN)
      return
    end
    local claude = require('aineo.claude')
    local shown = sessions_shown_in_tabs()
    vim.ui.select(listed, {
      prompt = 'Claude sessions',
      format_item = function(session)
        return claude.session_row(session, shown, folder)
      end,
    }, function(picked)
      if picked then
        run(function()
          pick_listed_session(picked)
        end)
      end
    end)
  end

  --- Reads the sessions Claude Code lists for the editor's folder, without
  --- waiting for them (`read_sessions()`), and offers them
  --- (`offer_sessions()`). Reads and offers nothing, and tells the user why,
  --- while Claude Code is not ready (`refuses_while_not_ready()`), a claim of
  --- another session holds (`refuses_while_claimed()`), or a read is running
  --- (`refuses_while_reading_sessions()`).
  local function list_sessions()
    if
      refuses_while_not_ready(NO_LIST)
      or refuses_while_claimed(NO_LIST)
      or refuses_while_reading_sessions(NO_LIST)
    then
      return
    end
    local folder = kept_places().working_directory
    read_sessions(folder, function(listed, problem)
      offer_sessions(listed, problem, folder)
    end)
  end

  --- Starts Claude Code on a new session id (`aineo.claude`'s
  --- `start_session()` with a new session asked for) in the place of the one
  --- that has exited, or in a layout opened around it, and moves the cursor
  --- to Claude's window in Terminal mode (`focus_claude()`).
  local function start_new_session()
    local config = resolved_config()
    open_layout_around(config, started_claude_terminal(config, true))
    focus_claude()
  end

  --- Starts Claude Code on `listed` (`claude_terminal_on_session()`) in a
  --- layout opened around it, and moves the cursor to Claude's window in
  --- Terminal mode (`focus_claude()`).
  ---
  ---@param listed aineo.claude.ListedSession
  ---@param sessions aineo.claude.ListedSession[]
  local function start_session_on(listed, sessions)
    local config = resolved_config()
    open_layout_around(config, claude_terminal_on_session(config, listed, sessions))
    focus_claude()
  end

  --- Starts Claude Code on the session `id` (`claude_terminal_resuming()`) in
  --- a layout opened around it, as the first open does for the kept session:
  --- what the reopening of the folder's tabs does for each tab.
  ---
  ---@param id string
  local function open_on_session(id)
    opened_from_list = true
    local config = resolved_config()
    open_layout_around(config, claude_terminal_resuming(config, id))
  end

  --- What `:Aineo new` does: a new Claude Code session. When Claude Code
  --- runs no session in this editor — it has not started, has exited, or its
  --- terminal was wiped — it starts one on a new id (`start_new_session()`);
  --- when it runs and is ready it writes `/clear` at its empty prompt
  --- (`write_command_at_empty_prompt()`), unless it is attached to a background
  --- session, which a `/clear` would clear: it is then replaced by a new
  --- session (`replace_attached_session()`). Does nothing, and tells the user
  --- why, with one warning that begins `NO_NEW_SESSION`, when a claim of
  --- another session holds, when Claude Code is starting or behind a dialog,
  --- when the prompt shows text, and when Terminal mode is not entered.
  local function new_session()
    if refuses_while_claimed(NO_NEW_SESSION) then
      return
    end
    local status = homes.claude.session_status()
    if status == nil or status == 'exited' then
      start_new_session()
      return
    end
    if refuses_while_not_ready(NO_NEW_SESSION) then
      return
    end
    if homes.claude.is_attached() then
      replace_attached_session(NO_NEW_SESSION, NEW_PROMPT_HOLDS_TEXT)
      return
    end
    write_command_at_empty_prompt(NO_NEW_SESSION, NEW_PROMPT_HOLDS_TEXT, '/clear')
  end

  --- What Send is handed: the tab's Input and the tab's Claude Code session.
  ---
  ---@return aineo.send.Target
  local function send_target()
    return { input = homes.layout.input_buffer() or NO_INPUT_BUFFER, session = homes.claude }
  end

  --- What each of `:Aineo`'s arguments that acts on the tab does, by the
  --- argument (`ACTION_ARGUMENTS`).
  ---@type table<string, fun()>
  local actions = {
    send = function()
      if not refuses_send_while_claimed() then
        require('aineo.send').send(send_target())
      end
    end,
    claim = claim_own_session,
    open = open,
    report = function()
      focus('report')
    end,
    input = function()
      focus('input')
    end,
    claude = focus_claude,
    ['claude-numbers'] = function()
      homes.layout.toggle_claude_numbers()
    end,
    sessions = list_sessions,
    new = new_session,
    ['pane agent'] = function()
      focus_pane('agent')
    end,
    ['pane changes'] = function()
      focus_pane('changes')
    end,
    ['pane terminal'] = focus_terminal,
  }

  --- What Send does in Visual mode: sends the selection alone, unless a claim
  --- of another session refuses it (`refuses_send_while_claimed()`), which
  --- ends Visual mode as Vim ends it after a command that fails, the
  --- selection kept for `gv`.
  local function send_selection()
    if holds_other_claim() then
      vim.cmd.normal({ args = { vim.keycode('<Esc>') }, bang = true })
      refuses_send_while_claimed()
      return
    end
    require('aineo.send').send_selection(send_target())
  end

  --- Whether the tab's Claude Code runs the session `id`: it follows it, and
  --- has neither exited nor never started.
  ---
  ---@param id string
  ---@return boolean
  local function runs_session(id)
    local status = homes.claude.session_status()
    return homes.claude.session_id() == id and status ~= nil and status ~= 'exited'
  end

  --- Runs each of `steps`, a function that lets a home of the tab go, and
  --- tells the user once the error each that raises gives (`run()`): a home
  --- that cannot be let go does not keep the others from it.
  ---
  ---@param steps fun()[]
  local function let_each_go(steps)
    for _, step in ipairs(steps) do
      run(step)
    end
  end

  --- Wipes `claude_terminal`, the terminal of the tab's Claude Code, when it
  --- exists still.
  local function wipe_claude_terminal()
    if claude_terminal and vim.api.nvim_buf_is_valid(claude_terminal) then
      vim.api.nvim_buf_delete(claude_terminal, { force = true })
    end
  end

  --- Does nothing: stands for what the first tab, made of the homes the
  --- modules themselves are, leaves as it is when it closes (`close()`): the
  --- `let_go()` those homes lack, and its terminal.
  local function leave_as_it_is() end

  --- Lets the tab's homes go as its tab page has closed, at once: its claim
  --- is let go, Input's draft is saved first (`aineo.draft`'s `let_go()`),
  --- then the layout, the shell, the changes pane and the Report are let go,
  --- the shell after the layout, whose handlers must not see its wipe. What
  --- its Claude Code tells it afterwards writes nothing. The first tab is made
  --- of the homes the modules themselves are, which have no `let_go()`: it
  --- leaves them as they are, and is in no tab page any more. Its shell is
  --- stopped by `finish_closing()`, and its Claude Code by `finish()`.
  local function release()
    is_released = true
    let_each_go({
      release_claim,
      homes.draft.let_go or leave_as_it_is,
      homes.layout.let_go or leave_as_it_is,
      homes.shell.let_go or leave_as_it_is,
      homes.changes.let_go or leave_as_it_is,
      homes.report.let_go or leave_as_it_is,
    })
    if key == nil then
      bound_page = nil
    end
  end

  --- Ends what `release()` left of the tab: stops its Claude Code as quitting
  --- stops it (`aineo.claude`'s `stop_session()`, which presses Ctrl+Z alone
  --- to one attached to a background session) unless the caller stopped it
  --- together with others (`already_stopped`), wipes its terminal and lets
  --- its Claude home go. The first tab keeps its terminal and its Claude
  --- home, which cannot be let go; the next tab opened takes them up.
  ---
  ---@param already_stopped boolean
  local function finish(already_stopped)
    let_each_go({
      already_stopped and leave_as_it_is or homes.claude.stop_session,
      key == nil and leave_as_it_is or wipe_claude_terminal,
      homes.claude.let_go or leave_as_it_is,
    })
  end

  --- Takes up the first tab again, as the tab the next tab opened is made of
  --- once it has closed: what the closed tab held — the session its panes
  --- followed, its claim, the confirmation of its start, the sessions it
  --- warned of — is forgotten, so that it follows its new session at once
  --- (`start_in_new_tab()`) and starts in the folder.
  local function reopen()
    is_released = false
    is_reopened = true
    panes_session = nil
    claimed_by_id = nil
    start_confirmed = false
    shared_session_told = {}
  end

  --- What opening a tab does once the tab page exists: `start` starts Claude
  --- Code in the layout (`start_new_session()`, `start_session_on()`). A tab
  --- taken up again follows its new session at once, so that Input and the
  --- Report do not keep the closed tab's, and shows the agent pane, not the
  --- pane the closed tab showed.
  ---
  ---@param start fun()
  local function start_in_new_tab(start)
    start()
    if not is_reopened then
      return
    end
    if not panes_session then
      follow_own_session(homes.claude.session_id())
    end
    homes.layout.show_pane('agent', function()
      return arrangement(resolved_config(), claude_terminal)
    end)
  end

  tab.actions = actions
  tab.send_selection = send_selection
  tab.claim_session = claim_session
  tab.follow_told_switch = follow_told_switch
  tab.write_entry = write_entry
  tab.release_claim = release_claim
  tab.panes_session = function()
    return panes_session
  end
  tab.runs_session = runs_session
  tab.start_token = function()
    return homes.claude.start_token()
  end
  tab.start_in_new_tab = function()
    start_in_new_tab(start_new_session)
  end
  tab.start_on_session = function(listed, sessions)
    start_in_new_tab(function()
      start_session_on(listed, sessions)
    end)
  end
  tab.open_on_session = function(id)
    start_in_new_tab(function()
      open_on_session(id)
    end)
  end
  tab.session_id = function()
    return homes.claude.session_id()
  end
  tab.session_name = function()
    if claude_terminal and vim.api.nvim_buf_is_valid(claude_terminal) then
      return vim.b[claude_terminal].aineo_session_name
    end
  end
  tab.page = function()
    return bound_page
  end
  tab.is_bound = function()
    return bound_page ~= nil and vim.api.nvim_tabpage_is_valid(bound_page)
  end
  tab.release = release
  tab.finish = finish
  tab.reopen = reopen
  return tab
end

--- The first tab: made of the homes the modules themselves are, and kept for
--- the editor's life from the first call of `new_tab()` on. Those homes
--- cannot be let go, so when the tab closes it is left as it stands, out of
--- `tab_list`, and `new_tab()` gives it again to the next tab opened, as
--- today's single composition goes on when the layout's tab page has closed
--- and the layout opens again.
---@type aineo.entry.Tab?
local module_tab = nil

--- Takes the entry of `tab` off the list of running editors. The first tab's
--- has no key, and taking off an entry with none takes off every entry of
--- this Neovim, so the entries of the tabs that remain are written again.
---
---@param tab aineo.entry.Tab
local function remove_entry_of(tab)
  if vim.v.servername == '' then
    return
  end
  local mcp = require('aineo.mcp')
  mcp.remove_editor_entry(kept_places().state_directory, vim.v.servername, tab.key)
  if tab.key == nil then
    for _, remaining in ipairs(tab_list) do
      remaining.write_entry()
    end
  end
end

--- The tabs released (`release_tab()`) whose Claude Code has yet to stop
--- (`finish_closing()`).
---@type aineo.entry.Tab[]
local closing = {}

--- The tabs whose Claude Code a background stop is stopping now
--- (`finish_closing()`), until it has stopped.
---@type aineo.entry.Tab[]
local stopping = {}

stops_in_closed_tab = function(id)
  return vim.iter({ closing, stopping }):flatten():any(function(tab)
    return tab.session_id() == id
  end)
end

--- Releases `tab`, whose tab page has closed: out of `tab_list` first, so
--- that no report or switch is told to it, then its entry off the list of
--- running editors, then its homes (`aineo.entry.Tab`'s `release()`). It
--- waits in `closing` for its Claude Code to stop.
---
---@param tab aineo.entry.Tab
local function release_tab(tab)
  for index, listed in ipairs(tab_list) do
    if listed == tab then
      table.remove(tab_list, index)
      break
    end
  end
  if last_used_tab == tab then
    last_used_tab = nil
  end
  remove_entry_of(tab)
  tab.release()
  table.insert(closing, tab)
end

--- Stops the shells of the tabs in `closing` that run one still
--- (`aineo.shell`'s `stop()`): the first tab's, whose module has no
--- `let_go()`, which a wipe inside `TabClosed` would hide from the layout's
--- handlers; those of the other tabs were let go when their tab pages
--- closed (`aineo.entry.Tab`'s `release()`). Then stops their Claude Codes
--- together, as quitting stops them (`aineo.claude`'s
--- `stop_sessions_in_background()`), without holding the editor, and ends
--- the tabs (`aineo.entry.Tab`'s `finish()`) once each Claude Code has
--- stopped. A shell stops at once, before the wait for a Claude Code that may
--- take seconds. Does nothing while Neovim quits: the quit stops every Claude
--- Code that runs, those of the tabs in `closing` and those still stopping
--- among them, and Neovim hangs up every shell.
local function finish_closing()
  if #closing == 0 or vim.v.exiting ~= vim.NIL then
    return
  end
  local finishing = closing
  closing = {}
  vim.list_extend(stopping, finishing)
  for _, tab in ipairs(finishing) do
    run(tab.homes.shell.stop)
  end
  local function finish_each(already_stopped)
    for _, tab in ipairs(finishing) do
      for index, listed in ipairs(stopping) do
        if listed == tab then
          table.remove(stopping, index)
          break
        end
      end
      tab.finish(already_stopped)
    end
  end
  local started = run(function()
    require('aineo.claude').stop_sessions_in_background(
      vim.tbl_map(function(tab)
        return tab.homes.claude
      end, finishing),
      function()
        finish_each(true)
      end
    )
  end)
  if not started then
    finish_each(false)
  end
end

--- Releases each tab whose tab page has closed (`aineo.tabs`' `closed()`), as
--- `:tabclose`, `:tabonly` and the close of a tab page's last window close
--- one, and has their Claude Codes stopped together once the command that
--- closed them has ended (`finish_closing()`): the editor is not held inside
--- `TabClosed`, and a command that closes several tab pages stops them once.
--- Does nothing while Neovim quits.
local function close_tabs_of_closed_pages()
  if vim.v.exiting ~= vim.NIL then
    return
  end
  local released = false
  for _, page in ipairs(require('aineo.tabs').closed()) do
    local tab = vim.iter(tab_list):find(function(listed)
      return listed.page() == page
    end)
    if tab then
      release_tab(tab)
      released = true
    end
  end
  if released then
    keep_folder_tabs()
  end
  vim.schedule(finish_closing)
end

--- Whether the handler of closed tab pages has been made (`hold_tab()`).
local tab_close_handler_made = false

--- Has the tabs home hold the tab page `tab` is in, called with the tab as
--- its layout opens there for the first time: its title says the name of the
--- session its Claude terminal shows; aineo's tab line is drawn while the
--- user's own is empty; a tab page that closes closes the tab
--- (`close_tabs_of_closed_pages()`).
---
---@param tab aineo.entry.Tab
local function hold_tab(tab)
  local tabs = require('aineo.tabs')
  tabs.hold(tab.page(), tab.session_name)
  tabs.draw_tabline()
  last_used_tab = tab
  keep_folder_tabs()
  if not tab_close_handler_made then
    tab_close_handler_made = true
    vim.api.nvim_create_autocmd('TabClosed', {
      group = vim.api.nvim_create_augroup('aineo.tabs', {}),
      desc = 'aineo: close the tab of a tab page that closed',
      callback = close_tabs_of_closed_pages,
    })
  end
end

--- How many tabs have been made (`new_tab()`), the first included; each tab
--- made of copies is keyed by the number it was made as.
local tabs_made = 0

--- The homes the modules themselves are: the first tab's.
---
---@return aineo.entry.Homes
local function module_homes()
  return {
    layout = require('aineo.layout'),
    claude = require('aineo.claude'),
    report = require('aineo.report'),
    draft = require('aineo.draft'),
    changes = require('aineo.changes'),
    shell = require('aineo.shell'),
  }
end

--- The copies each home's `new()` makes, for a tab made while the first tab
--- is in `tab_list`.
---
---@return aineo.entry.Homes
local function copied_homes()
  return {
    layout = require('aineo.layout').new(),
    claude = require('aineo.claude').new(),
    report = require('aineo.report').new(),
    draft = require('aineo.draft').new(),
    changes = require('aineo.changes').new(),
    shell = require('aineo.shell').new(),
  }
end

--- The tab of `tab_list` the report `session_id` of the Claude Code with the
--- start token `options.start_token` is for, or nil when it is for none, in
--- the order of the rules the report home's router gives (D63):
---
--- 1. the tab whose Claude Code has the token and whose panes follow the
---    session;
--- 2. else a tab whose panes follow the session;
--- 3. else, offered `at_start`, the tab whose Claude Code has the token, which
---    the tab's report home then takes or declines by its own rules: it takes
---    the report while its panes follow no session yet, and, offered to keep
---    it with the directory's records, while a claim holds them elsewhere;
--- 4. a report of no known session (`session_id` nil): the tab whose Claude
---    Code has the token.
---
---@param session_id string?
---@param options { at_start: boolean?, start_token: string? }
---@return aineo.entry.Tab?
local function tab_for_report(session_id, options)
  local token = options.start_token
  local function find(matches)
    return vim.iter(tab_list):find(matches)
  end
  local function has_token(tab)
    return token ~= nil and tab.start_token() == token
  end
  if session_id == nil then
    return find(has_token)
  end
  return find(function(tab)
    return has_token(tab) and tab.panes_session() == session_id
  end) or find(function(tab)
    return tab.panes_session() == session_id
  end) or (options.at_start and find(has_token) or nil)
end

--- What the report home's router answers (`aineo.report`'s
--- `set_report_router()`): the report home of the tab a report is for
--- (`tab_for_report()`), nil when it is for none.
---
---@param session_id string?
---@param options table
---@return aineo.report.Home?
local function route_report(session_id, options)
  local tab = tab_for_report(session_id, options)
  return tab and tab.homes.report
end

--- Whether the report home has been given its router yet.
local report_router_given = false

--- Whether the first tab (`module_tab`) can be taken up again: it is in no
--- tab page, and its Claude Code has ended or never started, so that a tab
--- made of its homes starts a Claude Code of its own and none is left running.
---
---@return boolean
local function first_tab_can_be_taken_up_again()
  if vim.tbl_contains(tab_list, module_tab) then
    return false
  end
  local status = module_tab.homes.claude.session_status()
  return status == nil or status == 'exited'
end

--- Whether the handler that keeps the folder's list of tabs at the quit has
--- been made (`keep_folder_tabs_at_quit()`).
local quit_keeper_made = false

--- Makes, once, the handler that keeps the folder's list of tabs when Neovim
--- quits (`write_folder_tabs()`), with the tab current then. Made when the
--- first tab is made, before its Claude Code starts, so that it runs before
--- the handler that stops every Claude Code (handlers run in the order they
--- were made).
local function keep_folder_tabs_at_quit()
  if quit_keeper_made then
    return
  end
  quit_keeper_made = true
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('aineo.tab_list', {}),
    desc = "aineo: keep the folder's list of tabs before Claude Code is stopped",
    callback = function()
      write_folder_tabs()
    end,
  })
end

--- Makes a tab and adds it to `tab_list`: the first tab, made of the homes the
--- modules themselves are (`module_tab`), when it is not in `tab_list` and its
--- Claude Code has stopped (`first_tab_can_be_taken_up_again()`); else a tab
--- of copies (`copied_homes()`), keyed by the number it is made as, and held
--- in the tabs home once its layout opens (`hold_tab()`). The first tab made
--- has the report home route a report to the tab it is for (`route_report()`).
--- The Claude Codes of the tabs closed so far are stopped first
--- (`finish_closing()`), while the first tab's homes still hold the start they
--- stop, so that taking them up again in the command that closed the first
--- tab does not give its new Claude Code a stop meant for the old.
---
---@return aineo.entry.Tab
local function new_tab()
  finish_closing()
  keep_folder_tabs_at_quit()
  tabs_made = tabs_made + 1
  local tab
  if module_tab == nil then
    module_tab = make_tab(module_homes(), nil, hold_tab)
    tab = module_tab
  elseif first_tab_can_be_taken_up_again() then
    tab = module_tab
    tab.reopen()
  else
    tab = make_tab(copied_homes(), tostring(tabs_made), hold_tab)
  end
  table.insert(tab_list, tab)
  if not report_router_given then
    report_router_given = true
    require('aineo.report').set_report_router(route_report)
  end
  return tab
end

--- The tab an action acts on: the tab whose tab page the current window is
--- in; from a tab page that is none of aineo's, the aineo tab used last,
--- which the cursor moves to (O5); with no aineo tab at all, the tab a
--- claim made before aineo opened (`aineo.entry.Tab`'s `claim_session()`),
--- else a new one, whose layout opens in the current tab page.
---
---@return aineo.entry.Tab
local function acting_tab()
  local current = tab_of_current_page()
  if current then
    last_used_tab = current
    return current
  end
  local to_return_to = (last_used_tab and last_used_tab.is_bound() and last_used_tab)
    or vim.iter(tab_list):find(function(tab)
      return tab.is_bound()
    end)
  if to_return_to then
    vim.api.nvim_set_current_tabpage(to_return_to.page())
    last_used_tab = to_return_to
    return to_return_to
  end
  return vim.iter(tab_list):find(function(tab)
    return not tab.is_bound()
  end) or new_tab()
end

--- Opens a tab page at the end, after the last tab page, so that no tab
--- changes its number, and a tab of aineo's in it, which `start` starts Claude
--- Code in (`aineo.entry.Tab`'s `start_in_new_tab()`, on a new session id in
--- the folder, when none is given): its layout around the Claude Code, the
--- cursor in Claude's window in Terminal mode. With `after_current` the tab
--- page is after the current one, as a reopening of the folder's tabs puts
--- each after the one before it. With no aineo tab yet, it opens the first one
--- in the current tab page. When the tab cannot start, the tab page it made is
--- closed again and the error raised.
---
---@param start? fun(tab: aineo.entry.Tab)
---@param after_current? boolean
open_new_tab = function(start, after_current)
  start = start or function(tab)
    tab.start_in_new_tab()
  end
  if not vim.iter(tab_list):any(function(tab)
    return tab.is_bound()
  end) then
    start(acting_tab())
    return
  end
  local tab = new_tab()
  vim.cmd(after_current and 'tabnew' or '$tabnew')
  local made_page = vim.api.nvim_get_current_tabpage()
  local started, failure = pcall(start, tab)
  if started then
    return
  end
  for index, listed in ipairs(tab_list) do
    if listed == tab then
      table.remove(tab_list, index)
      break
    end
  end
  tab.release()
  tab.finish(false)
  if vim.api.nvim_tabpage_is_valid(made_page) and #vim.api.nvim_list_tabpages() > 1 then
    vim.cmd.tabclose(vim.api.nvim_tabpage_get_number(made_page))
  end
  error(failure, 0)
end

--- What `:Aineo tab {n}` tells the user, as a warning, when there is no tab
--- page `n`: the number as the user typed it.
---
---@param typed string
---@return string
local function no_such_tab(typed)
  return ('aineo: no tab %s'):format(typed)
end

--- Moves to the tab page `number`, as `{n}gt` counts them, an aineo tab or
--- not; the cursor lands where it was in that tab page. With no such tab page
--- it moves nowhere and warns the user, naming the number as `typed`, which
--- is `number` as it is written when not given.
---
---@param number number
---@param typed? string
local function jump_to_tab(number, typed)
  local page = vim.api.nvim_list_tabpages()[number]
  if not page then
    vim.notify(no_such_tab(typed or tostring(number)), vim.log.levels.WARN)
    return
  end
  vim.api.nvim_set_current_tabpage(page)
end

--- What `:Aineo claim {id}` does: claims the session in the current tab
--- (`aineo.entry.Tab`'s `claim_session()`); but when another tab of this
--- Neovim runs that session, moves to that tab instead and claims nothing.
---
---@param id string
local function claim_in_current_tab(id)
  if not require('aineo.claude').is_session_id(id) then
    error((':Aineo claim takes a Claude session id, not %s'):format(id), 0)
  end
  local tab = acting_tab()
  local running = vim.iter(tab_list):find(function(other)
    return other ~= tab and other.is_bound() and other.runs_session(id)
  end)
  if running then
    vim.api.nvim_set_current_tabpage(running.page())
    last_used_tab = running
    return
  end
  tab.claim_session(id)
end

--- What `:Aineo tab close` tells the user, as a warning, from a tab page
--- that is none of aineo's.
local NO_TAB_TO_CLOSE = 'aineo: this tab holds no Claude Code session'

--- What `:Aineo tab close` does. In an aineo tab, while another aineo tab
--- remains, it closes the tab page, which releases the tab and stops its
--- Claude Code as quitting stops it (`close_tabs_of_closed_pages()`). In the
--- last aineo tab it quits Neovim as `:qa` does, which refuses while a buffer
--- has unsaved changes, and nothing is stopped then, and otherwise stops every
--- Claude Code as quitting stops it. From a tab page that is none
--- of aineo's it closes nothing and tells the user so.
local function close_current_tab()
  if not tab_of_current_page() then
    vim.notify(NO_TAB_TO_CLOSE, vim.log.levels.WARN)
    return
  end
  local remaining = vim
    .iter(tab_list)
    :filter(function(tab)
      return tab.is_bound()
    end)
    :totable()
  if #remaining > 1 then
    vim.cmd.tabclose()
  else
    vim.cmd.qall()
  end
end

--- Whether the editor's first open has yet to use the folder's list of tabs
--- (`reopen_folder_tabs()`). The first run of `:Aineo open` clears it, and so
--- does a session restored by a session plugin
--- (`open_unless_session_restored()`).
local first_open_pending = true

--- The list of tabs to reopen in the editor's folder: the list kept for it
--- when it holds the session kept for the folder (`aineo.tabs`'
--- `tabs_to_reopen()`), cut to the most tabs a reopening opens, and the
--- sessions cut off; nil when there is none.
---
---@return aineo.tabs.TabList|nil
---@return string[]|nil left
local function folder_tabs_to_reopen()
  local folder = kept_places()
  local kept =
    require('aineo.claude').kept_session(folder.state_directory, folder.working_directory)
  return require('aineo.tabs').tabs_to_reopen(
    folder.state_directory,
    folder.working_directory,
    kept
  )
end

--- The editor's first open, when the folder keeps a list of tabs that holds
--- its kept session and no aineo tab exists yet: opens every tab of the list in
--- its order, the first in the current tab page and each next one after the
--- tab before it (`open_new_tab()`), each with its Claude Code started on its
--- session at once (`aineo.entry.Tab`'s `open_on_session()`), and moves to the
--- tab at the list's place among them. The list is kept once all have opened,
--- with the sessions cut off by the most tabs a reopening opens, which the user
--- is told of. The first open uses the list once: later runs, and an open that
--- finds no such list, open as they always have (returns false). A tab that
--- cannot start raises an error that names its session and those not tried,
--- leaves the tabs opened before it, and keeps the sessions not tried in the
--- list; a list of one session that cannot start raises that start's own
--- error.
---
---@return boolean reopened
local function reopen_folder_tabs()
  if not first_open_pending then
    return false
  end
  first_open_pending = false
  if vim.iter(tab_list):any(function(tab)
    return tab.is_bound()
  end) then
    return false
  end
  local list, left = folder_tabs_to_reopen()
  if not list then
    return false
  end
  local opened, failed_at = {}, nil
  tabs_reopening = true
  local reopened, failure = pcall(function()
    for index, session in ipairs(list.sessions) do
      failed_at = index
      open_new_tab(function(tab)
        tab.open_on_session(session)
        table.insert(opened, tab)
      end, true)
    end
    failed_at = nil
  end)
  tabs_reopening = false
  local untried = vim.list_slice(list.sessions, (failed_at or #list.sessions) + 1)
  vim.list_extend(untried, left)
  local current = opened[list.current]
  if current and current.is_bound() then
    vim.api.nvim_set_current_tabpage(current.page())
  end
  keep_folder_tabs(untried)
  if not reopened then
    if #untried == 0 and #opened == 0 then
      error(failure, 0)
    end
    local cause = tostring(failure):match('^[^\n]*')
    error(
      ('reopening stopped at %s: %s%s'):format(
        list.sessions[failed_at],
        cause,
        #untried > 0 and '; not tried: ' .. table.concat(untried, ', ') or ''
      ),
      0
    )
  end
  if #left > 0 then
    vim.notify(
      ('aineo: reopened the first %d tabs of the list; %d more stay in the list'):format(
        #list.sessions,
        #left
      ),
      vim.log.levels.WARN
    )
  end
  return true
end

--- The arguments of `:Aineo` that open a tab's pieces when none is open: the
--- first run of one in an editor reopens the folder's tabs first
--- (`reopen_folder_tabs()`), so that the list is not replaced by the one
--- session it opens.
local REOPENS_TABS_FIRST = {
  claude = true,
  report = true,
  input = true,
  ['pane agent'] = true,
  ['pane changes'] = true,
}

--- What each of `:Aineo`'s arguments in `ACTION_ARGUMENTS` does: the actions
--- that act on a tab (`aineo.entry.Tab`'s `actions`) on the tab to act on
--- (`acting_tab()`), and the actions of tabs themselves.
---@type table<string, fun()>
local ACTIONS = {}

for _, argument in ipairs({
  'send',
  'claim',
  'report',
  'input',
  'claude',
  'claude-numbers',
  'sessions',
  'new',
  'pane agent',
  'pane changes',
  'pane terminal',
}) do
  ACTIONS[argument] = function()
    if REOPENS_TABS_FIRST[argument] then
      reopen_folder_tabs()
    end
    acting_tab().actions[argument]()
  end
end

--- What `:Aineo open` does: the first run in an editor reopens the folder's
--- tabs when it keeps a list of them (`reopen_folder_tabs()`); any other run,
--- and a first run that finds none, opens the layout in the current tab, or
--- restores it, as the tab to act on does.
ACTIONS.open = function()
  if not reopen_folder_tabs() then
    acting_tab().actions.open()
  end
end

ACTIONS['tab new'] = function()
  reopen_folder_tabs()
  open_new_tab()
end

ACTIONS['tab close'] = close_current_tab

for number = 1, 9 do
  ACTIONS['tab ' .. number] = function()
    jump_to_tab(number)
  end
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

--- What each action that has a Visual-mode form does in Visual mode, by its
--- argument in `ACTION_ARGUMENTS`: Send sends the selection alone, in the
--- tab the selection is in (`aineo.entry.Tab`'s `send_selection()`). A
--- selection in a tab page that is not an aineo tab's is in no Input: Send
--- says so, and the cursor stays where it is.
---@type table<string, fun()>
local VISUAL_ACTIONS = {
  send = function()
    local tab = tab_of_current_page()
    if tab then
      tab.send_selection()
      return
    end
    require('aineo.send').send_selection({
      input = NO_INPUT_BUFFER,
      session = require('aineo.claude'),
    })
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

--- Opens the layout as `open()` does, unless a session has been restored
--- (`v:this_session` is set), as a plugin such as auto-session or
--- persistence.nvim restores one from its own `VimEnter` autocommand: the
--- session's windows are the user's to keep. Records which it was, and
--- whether the open failed (`record_startup()`).
local function open_unless_session_restored()
  if vim.v.this_session ~= '' then
    first_open_pending = false
    record_startup('session-restored')
    return
  end
  local opened, failure = run(ACTIONS.open)
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
  local action = ACTIONS[table.concat(command.fargs, ' ')]
  if action then
    run(action)
    return
  end
  if command.fargs[1] == 'claim' and #command.fargs == 2 then
    run(function()
      claim_in_current_tab(command.fargs[2])
    end)
    return
  end
  if command.fargs[1] == 'tab' and #command.fargs == 2 and command.fargs[2]:match('^%d+$') then
    run(function()
      jump_to_tab(tonumber(command.fargs[2]), command.fargs[2])
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
