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
local SUBCOMMANDS =
  { 'send', 'open', 'report', 'input', 'claude', 'claude-numbers', 'pane', 'claim' }

--- The words each subcommand that takes one is followed by, in the order
--- `:Aineo` offers them: `pane` takes the pane to show.
local SUBCOMMAND_WORDS = { pane = { 'agent', 'changes' } }

--- What `:Aineo` tells the user when it is not given one of its subcommands.
local USAGE = 'aineo: :Aineo takes one of ' .. table.concat(SUBCOMMANDS, ', ')

--- What `:Aineo claim` tells the user when it is given more than one word.
local CLAIM_USAGE = 'aineo: :Aineo claim takes at most one Claude session id'

--- What `:Aineo` tells the user when `words`, its arguments, run no action:
--- for `claim`, that it takes at most one word; for a subcommand that takes
--- words (`SUBCOMMAND_WORDS`), which ones it takes; and `USAGE` otherwise.
---
---@param words string[]
---@return string
local function usage(words)
  if words[1] == 'claim' then
    return CLAIM_USAGE
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

--- The words `:Aineo` offers after `typed`, the words before the one the
--- cursor is in, the command's name first: its subcommands after the name
--- alone, the words of a subcommand that takes them (`SUBCOMMAND_WORDS`)
--- after that subcommand, the running sessions of this Neovim's directory
--- after `claim` (`running_sessions_here()`), and nothing otherwise.
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
--- draft of the Claude session the panes follow (`follow_session()`) — of
--- the working directory of `kept_places()` until they follow one — and
--- restores that draft into it when it is new and empty (`aineo.draft`'s
--- `keep_draft()`); gives the draft home that environment the first time.
--- Raises nothing.
local function keep_input_draft()
  local draft = require('aineo.draft')
  if not draft_environment_given then
    draft.set_draft_environment(kept_places())
    draft_environment_given = true
  end
  draft.keep_draft(require('aineo.layout').input_buffer())
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
  require('aineo.report').follow_report_session(id, options)
  require('aineo.draft').follow_draft_session(id, options)
  require('aineo.changes').follow_changes_session({
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
--- session of this Neovim's own Claude terminal.
---@type string?
local claimed_by_id = nil

--- The session whose claim file this Neovim wrote, while it may still name
--- it; nil when it claims none.
---@type string?
local claimed = nil

--- Whether a claim of another session holds: the panes follow a session
--- that `:Aineo claim <id>` made them follow, or that a switch moved that
--- claim to, and it is not the session of this Neovim's own Claude terminal
--- (`aineo.claude`'s `session_id()`).
---
---@return boolean
local function holds_other_claim()
  return claimed_by_id ~= nil and claimed_by_id ~= require('aineo.claude').session_id()
end

--- The wall clock now, in microseconds: when this Neovim was last used, as
--- its entry in the list of running editors keeps it.
---
---@return integer
local function microseconds_now()
  local now = vim.uv.clock_gettime('realtime')
  return now.sec * 1000000 + math.floor(now.nsec / 1000)
end

--- Whether this Neovim's entry's handlers have been made
--- (`make_entry_handlers()`).
local entry_handlers_made = false

--- Lets go this Neovim's claim (`claimed`), if its claim file still names
--- it (`aineo.mcp`'s `release_claim()`).
local function release_claim()
  if claimed then
    require('aineo.mcp').release_claim(kept_places().state_directory, claimed, vim.v.servername)
    claimed = nil
  end
end

--- Writes, unless Neovim is quitting (`v:exiting`), this Neovim's entry in
--- the list of running editors (`aineo.mcp`'s `write_editor_entry()`): its
--- address, the directory it started in, the session the panes follow,
--- whether that is its own terminal's (`holds_other_claim()`), and now as
--- its last use. It writes none before the panes follow a session, nor for
--- a Neovim with no server address. An entry that cannot be written is told
--- to the user as a warning. Defined below, with its handlers.
---@type fun()
local write_entry

--- Makes this Neovim the claimant of `session` (`aineo.mcp`'s
--- `claim_session()`), letting go any session it claimed before, unless
--- Neovim is quitting.
---
---@param session string
local function claim(session)
  if vim.v.exiting ~= vim.NIL then
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

--- Whether this Neovim is the claimant of `session` now, as its claim file
--- names it (`aineo.mcp`'s `session_claimant()`).
---
---@param session string
---@return boolean
local function claims(session)
  local claimant = require('aineo.mcp').session_claimant(kept_places().state_directory, session)
  return claimant == vim.v.servername
end

--- Makes the panes follow `id`, the session of this Neovim's own Claude
--- terminal (`follow_session()`), ending any claim of another session; a
--- claim of a session other than `id` is let go. Writes the entry.
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
end

--- Makes the panes follow `id` as a claim of it, a session this Neovim's own
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

--- What this Neovim does with a switch of a Claude Code it does not run,
--- from `left` to `new`, told by the deliverer of that Claude Code's hook
--- (`aineo.mcp`'s `on_followed_switch()`): when the panes follow `left` by
--- a claim of it, they follow `new` the same way — or as their own, when
--- `new` is this Neovim's own terminal's — and when this Neovim claims
--- `left`, it claims `new`. Anything else does nothing. Once Neovim is
--- quitting, it writes neither an entry nor a claim (`write_entry()`,
--- `claim()`).
---
---@param left string
---@param new string
local function follow_told_switch(left, new)
  local claimant = claims(left)
  if claimed_by_id ~= left and not claimant then
    return
  end
  if new == require('aineo.claude').session_id() then
    follow_own_session(new)
  else
    follow_claimed_session(new)
  end
  if claimant then
    claim(new)
  end
end

--- Makes, once, the handlers this Neovim's entry needs: `FocusGained`
--- writes the entry again, marking this Neovim used; `VimLeavePre` removes
--- the entry and lets go its claim; and a switch told by another Claude
--- Code's hook is followed (`follow_told_switch()`). Made at the first
--- entry write, so that sourcing this file makes none.
local function make_entry_handlers()
  if entry_handlers_made then
    return
  end
  entry_handlers_made = true
  local group = vim.api.nvim_create_augroup('aineo.editors', {})
  vim.api.nvim_create_autocmd('FocusGained', {
    group = group,
    desc = 'aineo: mark this editor used in the list of running editors',
    callback = function()
      write_entry()
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    desc = 'aineo: take this editor off the list of running editors',
    callback = function()
      require('aineo.mcp').remove_editor_entry(kept_places().state_directory, vim.v.servername)
      release_claim()
    end,
  })
  require('aineo.mcp').on_followed_switch(follow_told_switch)
end

write_entry = function()
  if vim.v.exiting ~= vim.NIL or not panes_session or vim.v.servername == '' then
    return
  end
  make_entry_handlers()
  local written, failure =
    pcall(require('aineo.mcp').write_editor_entry, kept_places().state_directory, {
      address = vim.v.servername,
      working_directory = kept_places().working_directory,
      session = panes_session,
      own = not holds_other_claim(),
      used = microseconds_now(),
    })
  if not written then
    vim.notify('aineo: ' .. tostring(failure), vim.log.levels.WARN)
  end
end

--- Whether the Claude Code aineo started last has been confirmed: it has
--- been ready for input once (`aineo.claude`'s `on_session_ready`). Until
--- then the panes stay on the session they followed before it, and no
--- switch it tells is followed.
local start_confirmed = false

--- Forgets that a start was confirmed (`start_confirmed`) when no Claude
--- Code runs — none has started, or the last has exited — and so the next
--- start launches a new one, which must be confirmed in turn. Called before
--- that start: the switch to a session another than the one followed,
--- which `aineo.claude`'s `start_session()` tells before it returns, is
--- then not followed.
local function forget_confirmation_unless_running()
  local status = require('aineo.claude').session_status()
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
--- confirmed (`start_confirmed`), and moves this Neovim's claim of `left`,
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
--- it under the state directory of `kept_places()`, its session hooks told
--- the editor's address and program. When the session puts a
--- new terminal in place of one whose resume found no conversation, that
--- terminal becomes `claude_terminal` and the layout's Claude terminal
--- (`aineo.layout`'s `follow_claude_terminal()`). The panes follow the
--- session the start is on once Claude Code is first ready for input — the
--- new session's that takes the place of a resume with no conversation —
--- and then each session Claude Code switches to; not before, and nothing
--- for a start that never becomes ready (`follow_confirmed_start()`,
--- `follow_switch_once_confirmed()`). Once a start has
--- succeeded, the changes home is told the session began there
--- (`aineo.changes`'s `begin_session()`, which heeds its first call alone),
--- in Claude Code's working directory, with the layout's `show_diff()` to
--- show its diffs in the middle column.
---
---@param config table the resolved configuration
---@return integer terminal
local function started_claude_terminal(config)
  local report = require('aineo.report')
  local mcp = require('aineo.mcp')
  local working_directory = vim.fn.getcwd()
  forget_confirmation_unless_running()
  claude_terminal = require('aineo.claude').start_session({
    cmd = config.claude.cmd,
    cwd = working_directory,
    mcp_servers = mcp.mcp_servers(vim.v.servername, vim.v.progpath),
    allowed_tools = mcp.allowed_mcp_tools(),
    instructions = report.report_instructions(mcp.report_tool_name()),
    state_directory = kept_places().state_directory,
    editor_address = vim.v.servername,
    editor_program = vim.v.progpath,
    on_terminal_replaced = function(terminal)
      claude_terminal = terminal
      require('aineo.layout').follow_claude_terminal(terminal)
    end,
    on_session_ready = follow_confirmed_start,
    on_session_switched = follow_switch_once_confirmed,
  })
  require('aineo.changes').begin_session({
    directory = working_directory,
    show_diff = function(diff)
      return require('aineo.layout').show_diff(diff)
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

--- The changes pane's two buffers, from the changes home (`aineo.changes`'s
--- `pane_buffers()`), which lists the session's files and commits there.
--- While either is shown in a window, as when `\o` restores the layout with
--- the changes pane shown, the home reads both lists again first
--- (`refresh_shown_pane()`).
---
---@return aineo.layout.ChangesPane
local function changes_pane()
  local changes = require('aineo.changes')
  changes.refresh_shown_pane()
  return changes.pane_buffers()
end

--- The buffers aineo's layout shows: `claude_buffer`, the Claude session's
--- terminal, the Report, taken from the report home, which this gives its
--- environment the first time it is called (`give_report_environment()`),
--- and the changes pane's (`changes_pane()`); with the Report's share from
--- `config`, and the status line of Claude's window, which draws the
--- session's name and folder (`aineo.claude`'s `session_statusline()`).
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
    claude_statusline = require('aineo.claude').session_statusline(),
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
--- then handed to the draft home (`keep_input_draft()`). The changes pane,
--- already shown, is read again first (`aineo.changes`'s
--- `refresh_shown_pane()`), as showing it anew reads it.
---
---@param pane aineo.layout.Pane
local function show_pane(pane)
  local config = resolved_config()
  if pane == 'changes' then
    require('aineo.changes').refresh_shown_pane()
  end
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

--- What `:Aineo claim` tells the user, as a warning, when this Neovim's own
--- Claude terminal runs no session — Claude Code never started here — so
--- that it has no session of its own to claim or return to.
local NO_OWN_SESSION = 'aineo: Claude Code has not started in this Neovim;'
  .. ' :Aineo claim {id} follows a session, :Aineo open starts Claude Code here'

--- What `:Aineo claim` tells the user, as a warning, while the start of
--- this Neovim's Claude Code has not been confirmed: its session may never
--- be one.
local NOT_READY_TO_CLAIM = 'aineo: Claude Code is not ready yet; nothing claimed'

--- Makes the panes follow the session of this Neovim's own Claude terminal
--- (`aineo.claude`'s `session_id()`), as its own, and claims that session
--- (`claim()`): what `:Aineo claim` with no argument does, whether a claim
--- of another session holds or not. In a Neovim whose terminal runs no
--- session (`NO_OWN_SESSION`), or before the running start is confirmed
--- (`NOT_READY_TO_CLAIM`), it warns once and changes nothing.
local function claim_own_session()
  local own = require('aineo.claude').session_id()
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
--- before aineo's layout has opened. The id of this Neovim's own terminal's
--- session claims it as `claim_own_session()` does.
---
--- Raises an error naming `id` when it is not a session id of the form
--- Claude Code gives (`aineo.claude`'s `is_session_id()`), and changes
--- nothing then.
---
---@param id string
local function claim_session(id)
  local claude = require('aineo.claude')
  if not claude.is_session_id(id) then
    error((':Aineo claim takes a Claude session id, not %s'):format(id), 0)
  end
  if id == claude.session_id() then
    claim_own_session()
    return
  end
  give_report_environment()
  follow_claimed_session(id)
  claim(id)
end

--- Whether Send is refused while a claim of another session holds
--- (`holds_other_claim()`): Input then holds the claimed session's draft,
--- which this Neovim's own Claude terminal, running another session, must
--- not get. Tells the user why once, with one warning, naming the claimed
--- session and what returns this Neovim to its own, or, when its terminal
--- runs no session, what else works here.
---
---@return boolean refused
local function refuses_send_while_claimed()
  if not holds_other_claim() then
    return false
  end
  local way_out = require('aineo.claude').session_id()
      and ':Aineo claim with no argument returns this Neovim to its own session'
    or ':Aineo claim {id} follows another session, :Aineo open starts Claude Code here'
  vim.notify(
    ('aineo: nothing sent — Input holds the draft of the claimed session %s; %s'):format(
      claimed_by_id,
      way_out
    ),
    vim.log.levels.WARN
  )
  return true
end

--- What each of `:Aineo`'s arguments in `ACTION_ARGUMENTS` does.
---@type table<string, fun()>
local ACTIONS = {
  send = function()
    if not refuses_send_while_claimed() then
      require('aineo.send').send()
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
--- argument in `ACTION_ARGUMENTS`: Send sends the selection alone, unless a
--- claim of another session refuses it (`refuses_send_while_claimed()`),
--- which ends Visual mode as Vim ends it after a command that fails, the
--- selection kept for `gv`.
---@type table<string, fun()>
local VISUAL_ACTIONS = {
  send = function()
    if holds_other_claim() then
      vim.cmd.normal({ args = { vim.keycode('<Esc>') }, bang = true })
      refuses_send_while_claimed()
      return
    end
    require('aineo.send').send_selection()
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
  ['pane agent'] = 'pa',
  ['pane changes'] = 'pc',
}

--- Whether `keys`, written as in a mapping, have a global mapping in
--- `mode`, `n` for Normal mode or `x` for Visual mode. A mapping local to a
--- buffer does not count: it wins in its own buffer only. A mapping's keys
--- are compared in both the forms Neovim records: `lhsraw`, and
--- `lhsrawalt`, where a Ctrl key such as `<C-a>` has the one byte
--- `nvim_replace_termcodes()` gives it.
---
---@param mode 'n'|'x'
---@param keys string
---@return boolean
local function has_global_mapping(mode, keys)
  local typed = vim.api.nvim_replace_termcodes(keys, true, true, true)
  return vim.iter(vim.api.nvim_get_keymap(mode)):any(function(mapping)
    return mapping.lhsraw == typed or mapping.lhsrawalt == typed
  end)
end

--- Maps `keys` in `mode` to `argument`'s `<Plug>` mapping, unless the user
--- has mapped `keys` globally in `mode` already (`has_global_mapping()`).
---
---@param mode 'n'|'x'
---@param keys string
---@param argument string
local function map_unless_mapped(mode, keys, argument)
  if not has_global_mapping(mode, keys) then
    vim.keymap.set(mode, keys, plug_mapping(argument), { desc = 'aineo: ' .. argument })
  end
end

--- Maps `prefix` followed by each action's keys (`PREFIX_KEYS`) to the
--- action's `<Plug>` mapping, in Normal mode, and in Visual mode for each
--- action that has a Visual-mode form (`VISUAL_ACTIONS`), but for each key
--- sequence the user has mapped globally in that mode already — a mapping
--- of only the start of a sequence, of a longer one, or in the other mode,
--- does not count; maps nothing when `prefix` is `false`. An action with no
--- keys there, `claim`, gets none: any key after the `c` of `claude` would
--- make that key wait for 'timeoutlen'.
---
---@param prefix string|false
local function map_prefix(prefix)
  if prefix == false then
    return
  end
  for _, argument in ipairs(ACTION_ARGUMENTS) do
    if PREFIX_KEYS[argument] then
      map_unless_mapped('n', prefix .. PREFIX_KEYS[argument], argument)
    end
  end
  for argument in pairs(VISUAL_ACTIONS) do
    map_unless_mapped('x', prefix .. PREFIX_KEYS[argument], argument)
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
  if command.fargs[1] == 'claim' and #command.fargs == 2 then
    run(function()
      claim_session(command.fargs[2])
    end)
    return
  end
  vim.notify(usage(command.fargs), vim.log.levels.ERROR)
end, {
  nargs = '*',
  bar = true,
  complete = complete_subcommand,
  desc = 'aineo: send, open, report, input, claude, claude-numbers, pane agent|changes or claim [id]',
})
