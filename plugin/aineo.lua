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
}

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
--- and the panes stay on the claimed session. This Neovim's claim of `dead`
--- is let go (`release_claim()`), and a claim made with `dead`'s id ends:
--- the panes then follow `fresh` as this Neovim's own. When the panes
--- followed `dead`, they follow `fresh` (`panes_session`), and this
--- Neovim's entry in the list of running editors is written for it
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
  require('aineo.report').hand_over_report_session(dead, fresh)
  require('aineo.draft').hand_over_draft_session(dead, fresh)
  require('aineo.changes').hand_over_changes_session({
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
end

--- The terminal of the Claude session aineo started last — the new
--- session's once one took the place of a resume Claude Code found no
--- conversation for — or `nil` before it has started one.
---@type integer|nil
local claude_terminal = nil

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
      replacing_session = require('aineo.claude').session_id()
      claude_terminal = terminal
      require('aineo.layout').follow_claude_terminal(terminal)
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

--- Starts Claude Code with `config` when none runs — again once the last
--- has exited — and returns its terminal, which it keeps as
--- `claude_terminal`. While one runs it starts nothing and returns that
--- session's terminal (`aineo.claude`'s `start_session()`). Claude Code
--- starts in the editor's working directory, resuming the session kept for
--- it under the state directory of `kept_places()`, its session hooks told
--- the editor's address and program. When the session puts a
--- new terminal in place of one whose resume found no conversation, that
--- terminal becomes `claude_terminal` and the layout's Claude terminal,
--- and the new session is handed what aineo kept for the dead one at once
--- (`replacement_callbacks()`). The panes follow the session the start is
--- on once Claude Code is first ready for input — the new session's that
--- takes the place of a resume with no conversation, which they show from
--- the hand-over on when they showed the dead one — and then each session
--- Claude Code switches to; not before, and nothing for a start that never
--- becomes ready (`follow_confirmed_start()`,
--- `follow_switch_once_confirmed()`). With `new_session` the start is on a
--- new session id, not the kept one, and lists no sessions (`aineo.claude`'s
--- `start_session()`). Once a start has succeeded, the
--- changes home is told the session began there (`aineo.changes`'s
--- `begin_session()`, which heeds its first call alone), in Claude Code's
--- working directory, with the layout's `show_diff()` to show its diffs in
--- the middle column and the configuration's `changes.working_branch`.
---
---@param config table the resolved configuration
---@param new_session? boolean start on a new session id rather than resume the kept one
---@return integer terminal
local function started_claude_terminal(config, new_session)
  local working_directory = vim.fn.getcwd()
  forget_confirmation_unless_running()
  claude_terminal =
    require('aineo.claude').start_session(claude_settings(config, working_directory, new_session))
  require('aineo.changes').begin_session({
    directory = working_directory,
    show_diff = function(diff)
      return require('aineo.layout').show_diff(diff)
    end,
    working_branch = config.changes.working_branch,
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

--- Opens aineo's layout around `terminal`, Claude's, or restores the layout
--- while it is open. Input is then handed to the draft home
--- (`keep_input_draft()`).
---
---@param config table the resolved configuration
---@param terminal integer
local function open_layout_around(config, terminal)
  require('aineo.layout').open(arrangement(config, terminal))
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
  require('aineo.layout').focus(role, function()
    opened = true
    return arrangement(config, current_claude_terminal(config))
  end)
  if opened then
    keep_input_draft()
  end
end

--- Shows `pane` in the layout's right column and moves the cursor into it
--- (`aineo.layout`'s `focus_pane()`): into the Report under the agent pane,
--- into the commits window under the changes pane, though the pane was
--- shown already. When the layout must open first, it opens as `focus()`
--- opens it, around the Claude session's terminal as it is, and Input is
--- then handed to the draft home (`keep_input_draft()`). The changes pane,
--- already shown, is read again first (`aineo.changes`'s
--- `refresh_shown_pane()`), as showing it anew reads it.
---
---@param pane aineo.layout.Pane
local function focus_pane(pane)
  local config = resolved_config()
  if pane == 'changes' then
    require('aineo.changes').refresh_shown_pane()
  end
  local opened = false
  require('aineo.layout').focus_pane(pane, function()
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
--- it; another buffer shown in Claude's window is not Claude's to type to,
--- nor is the empty buffer a start that waits for the list of sessions shows
--- until Claude Code launches in it.
---
---@return boolean
local function can_type_to_claude()
  return vim.api.nvim_get_current_buf() == claude_terminal
    and vim.bo.buftype == 'terminal'
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

--- What tells the user how to leave a claim of another session
--- (`holds_other_claim()`): what returns this Neovim to its own session, or,
--- when its Claude terminal runs no session, what else works here.
---
---@return string
local function way_out_of_claim()
  return require('aineo.claude').session_id()
      and ':Aineo claim with no argument returns this Neovim to its own session'
    or ':Aineo claim {id} follows another session, :Aineo open starts Claude Code here'
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
--- session, which this Neovim's own Claude terminal does not run, and a
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

--- What `:Aineo sessions` tells the user, as a warning, by the status of
--- the Claude session (`aineo.claude`'s `session_status()`; `not_started`
--- when there is none) when it does nothing because Claude Code is not ready.
local NOT_READY = {
  not_started = 'Claude has not started',
  starting = 'Claude is not ready: it is starting, or a dialog in its window awaits your answer',
  exited = 'Claude has exited',
}

--- Whether `:Aineo sessions` must do nothing because Claude Code is not
--- ready for input (`NOT_READY`). Tells the user why once, with one warning
--- that begins `outcome`, the words of what was not done.
---
---@param outcome string
---@return boolean refused
local function refuses_while_not_ready(outcome)
  local status = require('aineo.claude').session_status()
  if status == 'ready' then
    return false
  end
  vim.notify(outcome .. NOT_READY[status or 'not_started'], vim.log.levels.WARN)
  return true
end

--- Runs an action and tells the user, once, the error it raises. Defined
--- below, with the framing it strips from the error.
---@type fun(action: fun()): boolean, string|nil
local run

--- What the messages of `:Aineo sessions` begin with when it lists nothing,
--- and when a pick switches nothing.
local NO_LIST = 'aineo: no session list — '
local NOT_SWITCHED = 'aineo: not switched — '

--- What the session list's write begins and ends a bracketed paste with: the
--- bytes Send pastes with (`aineo.send`), so that Claude Code takes the
--- command as text typed in one piece.
local PASTE_START = '\27[200~'
local PASTE_END = '\27[201~'

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

--- What `:Aineo sessions` tells the user, as a warning, when a pick
--- switches nothing because the session picked is the one Claude's
--- terminal already shows.
---
---@param name string
---@return string
local function already_shown(name)
  return (NOT_SWITCHED .. '%s is the session Claude’s terminal already shows'):format(name)
end

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

--- How long a switch waits, after it asks for Terminal mode in Claude's
--- window, for Neovim to enter it.
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

--- What `:Aineo sessions` tells the user, as a warning, when a pick
--- switches nothing because the prompt of Claude Code shows text.
local PROMPT_HOLDS_TEXT = NOT_SWITCHED
  .. 'the prompt holds text; clear it, then pick the session again'

--- Puts the cursor back where it was before a switch moved it: in the
--- window `origin` names, out of Terminal mode when that window is Claude's
--- and was in Normal mode, and in Insert mode when it was in Insert mode.
--- Moving to another window ends Terminal mode, and Insert mode is asked for
--- once it has ended: asked for sooner, it is lost to it.
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
  local claude = require('aineo.claude')
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
    require('aineo.claude').write_to_session(PASTE_START .. command .. PASTE_END .. '\r')
  end)
end

--- Switches Claude Code to `listed`, a session whose id is a session id:
--- writes `/resume {session id}` at Claude's empty prompt
--- (`write_command_at_empty_prompt()`), which Claude Code answers by
--- switching and aineo follows (`aineo.claude`'s `on_session_switched`).
--- Does nothing, and tells the user why, when Claude Code is not ready
--- (`refuses_while_not_ready()`), when a claim of another session holds
--- (`refuses_while_claimed()`), when the prompt shows text, and when
--- Terminal mode is not entered; then it also puts the cursor back where it
--- was (`return_to()`).
---
---@param listed aineo.claude.ListedSession
local function switch_to_session(listed)
  if refuses_while_not_ready(NOT_SWITCHED) or refuses_while_claimed(NOT_SWITCHED) then
    return
  end
  write_command_at_empty_prompt(NOT_SWITCHED, PROMPT_HOLDS_TEXT, '/resume ' .. listed.session_id)
end

--- Puts the terminal `replace` makes in Claude's window in place of the one
--- that ran: `replace` is called with `aineo.claude` and the settings of a
--- start in the session's directory (`claude_settings()`), built first so that
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
  local claude = require('aineo.claude')
  local settings = claude_settings(resolved_config(), claude.session_directory())
  local was_confirmed = start_confirmed
  start_confirmed = false
  local replaced, terminal = pcall(replace, claude, settings)
  if not replaced then
    start_confirmed = was_confirmed
    error(terminal, 0)
  end
  claude_terminal = terminal
  require('aineo.layout').follow_claude_terminal(claude_terminal)
  vim.api.nvim_create_autocmd('ModeChanged', {
    pattern = 't:*',
    once = true,
    callback = function()
      vim.schedule(focus_claude)
    end,
  })
end

--- Replaces Claude's window's Claude Code with one on `listed`, a session
--- another process runs and aineo can join (`aineo.claude`'s
--- `join_session()`, given `sessions`, the list just read): attached to it, or
--- resumed where it is open in another interactive Claude Code only. Only at
--- an empty prompt (`at_empty_prompt()`), since the running Claude Code is
--- stopped and its prompt's text would be lost (`replace_claude_terminal()`).
--- Does nothing, and tells the user why, when Claude Code is not ready
--- (`refuses_while_not_ready()`), when a claim of another session holds
--- (`refuses_while_claimed()`), when the prompt shows text, and when Terminal
--- mode is not entered.
---
---@param listed aineo.claude.ListedSession
---@param sessions aineo.claude.ListedSession[]
local function join_running_session(listed, sessions)
  if refuses_while_not_ready(NOT_SWITCHED) or refuses_while_claimed(NOT_SWITCHED) then
    return
  end
  at_empty_prompt(NOT_SWITCHED, PROMPT_HOLDS_TEXT, function()
    replace_claude_terminal(function(claude, settings)
      return claude.join_session(settings, listed, sessions)
    end)
  end)
end

--- Replaces Claude's window's Claude Code, which is attached to a background
--- session, with a start of aineo's own (`aineo.claude`'s `replace_session()`):
--- a new session when `choice` is nil, else the session it names, resumed. A
--- command written into an attached Claude Code would reach the background
--- session. Only at an empty prompt (`at_empty_prompt()`), as a join is.
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

--- Whether a pick of `listed` must switch nothing for where the session
--- stands (`aineo.claude`'s `session_standing()`): the session of Claude's
--- terminal, one another process runs and aineo cannot join
--- (`aineo.claude`'s `can_join_session()`, which also needs it to have started
--- in the folder), one started in another folder. Tells the user why once,
--- with one warning.
---
---@param listed aineo.claude.ListedSession
---@return boolean refused
local function refuses_by_standing(listed)
  local claude = require('aineo.claude')
  local name = claude.listed_session_name(listed)
  local standing = claude.session_standing(listed, claude.session_id(), claude.session_directory())
  if standing == 'own' then
    vim.notify(already_shown(name), vim.log.levels.WARN)
  elseif standing == 'elsewhere' then
    if claude.can_join_session(listed, claude.session_directory()) then
      return false
    end
    if claude.can_join_session(listed) then
      vim.notify(started_elsewhere(name, listed.cwd), vim.log.levels.WARN)
    else
      vim.notify(runs_elsewhere(name), vim.log.levels.WARN)
    end
  elseif standing == 'another_folder' then
    vim.notify(started_elsewhere(name, listed.cwd), vim.log.levels.WARN)
  end
  return standing ~= 'switchable'
end

--- Takes Claude's window to `listed`, a session that stands for a pick
--- (`refuses_by_standing()` said no): joins it where another process runs
--- it (`join_running_session()`, given `sessions`, the list just read),
--- else replaces an attached Claude Code with a resume of it
--- (`replace_attached_session()`), else switches Claude Code to it
--- (`switch_to_session()`).
---
---@param listed aineo.claude.ListedSession
---@param sessions aineo.claude.ListedSession[]
local function take_listed_session(listed, sessions)
  local claude = require('aineo.claude')
  if
    claude.session_standing(listed, claude.session_id(), claude.session_directory()) == 'elsewhere'
  then
    join_running_session(listed, sessions)
  elseif claude.is_attached() then
    if refuses_while_not_ready(NOT_SWITCHED) or refuses_while_claimed(NOT_SWITCHED) then
      return
    end
    replace_attached_session(
      NOT_SWITCHED,
      PROMPT_HOLDS_TEXT,
      { id = listed.session_id, resumed = true }
    )
  else
    switch_to_session(listed)
  end
end

--- Acts on the pick of `listed`, a session of the list `list_sessions()`
--- offered. Switches nothing, and tells the user why, when `listed` is not a
--- session id — a menu is another plugin's, and the id is typed into Claude
--- Code's terminal — and when it stands for no switch and no join
--- (`refuses_by_standing()`). Otherwise reads the list again, since the menu
--- may have been open for long, and takes Claude's window to the session
--- (`take_listed_session()`) only if it is still listed and still stands for
--- a switch or a join.
---
---@param listed aineo.claude.ListedSession
local function pick_listed_session(listed)
  local claude = require('aineo.claude')
  if not claude.is_session_id(listed.session_id) then
    vim.notify(NOT_SWITCHED .. 'what was picked is not a Claude session id', vim.log.levels.WARN)
    return
  end
  if refuses_by_standing(listed) or refuses_while_reading_sessions(NOT_SWITCHED) then
    return
  end
  local name = claude.listed_session_name(listed)
  read_sessions(claude.session_directory(), function(now, problem)
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
    if not refuses_by_standing(current) then
      take_listed_session(current, now)
    end
  end)
end

--- Offers `listed`, the sessions Claude Code lists for `directory`, in
--- `vim.ui.select`; a pick is acted on by `pick_listed_session()`, which
--- reports an error it raises once. Offers nothing, and tells the user why,
--- when Claude Code could not list them (`problem`) or lists none.
---
---@param listed aineo.claude.ListedSession[]?
---@param problem string?
---@param directory string
local function offer_sessions(listed, problem, directory)
  if problem then
    vim.notify(NO_LIST .. problem, vim.log.levels.WARN)
    return
  end
  if #listed == 0 then
    vim.notify(NO_LIST .. 'Claude Code lists no session for ' .. directory, vim.log.levels.WARN)
    return
  end
  local claude = require('aineo.claude')
  vim.ui.select(listed, {
    prompt = 'Claude sessions',
    format_item = function(session)
      return claude.session_row(session, claude.session_id(), directory)
    end,
  }, function(picked)
    if picked then
      run(function()
        pick_listed_session(picked)
      end)
    end
  end)
end

--- Reads the sessions Claude Code lists for the directory it started in,
--- without waiting for them (`read_sessions()`), and offers them
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
  local directory = require('aineo.claude').session_directory()
  read_sessions(directory, function(listed, problem)
    offer_sessions(listed, problem, directory)
  end)
end

--- What `:Aineo new` begins its warnings with when it does nothing.
local NO_NEW_SESSION = 'aineo: no new session — '

--- What `:Aineo new` tells the user, as a warning, when the prompt of
--- Claude Code shows text.
local NEW_PROMPT_HOLDS_TEXT = NO_NEW_SESSION
  .. 'the prompt holds text; clear it, then press the key again'

--- Starts Claude Code on a new session id (`aineo.claude`'s
--- `start_session()` with a new session asked for) in the place of the one
--- that has exited, or in a layout opened around it, and moves the cursor
--- to Claude's window in Terminal mode (`focus_claude()`).
local function start_new_session()
  local config = resolved_config()
  open_layout_around(config, started_claude_terminal(config, true))
  focus_claude()
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
  local status = require('aineo.claude').session_status()
  if status == nil or status == 'exited' then
    start_new_session()
    return
  end
  if refuses_while_not_ready(NO_NEW_SESSION) then
    return
  end
  if require('aineo.claude').is_attached() then
    replace_attached_session(NO_NEW_SESSION, NEW_PROMPT_HOLDS_TEXT)
    return
  end
  write_command_at_empty_prompt(NO_NEW_SESSION, NEW_PROMPT_HOLDS_TEXT, '/clear')
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
  sessions = list_sessions,
  new = new_session,
  ['pane agent'] = function()
    focus_pane('agent')
  end,
  ['pane changes'] = function()
    focus_pane('changes')
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
run = function(action)
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
  sessions = 'S',
  new = 'N',
  ['pane agent'] = 'pa',
  ['pane changes'] = 'g',
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
      claim_session(command.fargs[2])
    end)
    return
  end
  vim.notify(usage(command.fargs), vim.log.levels.ERROR)
end, {
  nargs = '*',
  bar = true,
  complete = complete_subcommand,
  desc = 'aineo: send, open, report, input, claude, claude-numbers, sessions, new, pane agent|changes or claim [id]',
})
