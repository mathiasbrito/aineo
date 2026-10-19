--- One tab of aineo (`make_tab()`): a Claude Code session with the layout,
--- Report, Input, changes pane and shell that follow it, in a tab page, and
--- every action that acts on it.

local busy_watch = require('aineo.entry.busy_watch')
local closing = require('aineo.entry.closing')
local editors = require('aineo.entry.editors')
local errors = require('aineo.entry.errors')
local folder_tabs = require('aineo.entry.folder_tabs')
local links = require('aineo.entry.links')
local places = require('aineo.entry.places')
local prompt = require('aineo.entry.prompt')
local registry = require('aineo.entry.registry')
local run_pane = require('aineo.entry.run_pane')

local M = {}

--- aineo's configuration, resolved from `vim.g.aineo` and the options
--- `require('aineo').setup()` recorded (`aineo.config`'s `resolve_config()`).
--- Raises its error naming the setting that is wrong.
---
---@return table
local function resolved_config()
  local config = require('aineo.config')
  return (config.resolve_config(vim.g.aineo, config.recorded_setup_options()))
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

--- What `:Aineo new` begins its warnings with when it does nothing.
local NO_NEW_SESSION = 'aineo: no new session — '

--- What `:Aineo new` tells the user, as a warning, when the prompt of
--- Claude Code shows text.
local NEW_PROMPT_HOLDS_TEXT = NO_NEW_SESSION
  .. 'the prompt holds text; clear it, then press the key again'

--- The buffer number Send is given for a tab whose Input does not exist yet,
--- and for a selection outside every tab: no buffer has it, so Send refuses,
--- saying there is no Input or that Visual Send works in Input only, rather
--- than read the Input of another tab.
local NO_INPUT_BUFFER = -1

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

--- The homes one tab is made of: its layout, the Claude Code session home it
--- starts and follows, its Report, Input's draft and changes pane, its shell
--- and the processes of its run pane. The first tab's are the homes' own
--- module-level copies; every tab after it is given the copies each home's
--- `new()` makes.
---@class aineo.entry.Homes
---@field layout aineo.layout.Layout
---@field claude aineo.claude.Session
---@field report aineo.report.Home
---@field draft aineo.draft.Home
---@field changes aineo.changes.Home
---@field shell aineo.shell.Home
---@field run aineo.run.Home

--- One tab of aineo, as the composition root holds it: what a tab does is
--- called as fields, and acts on that tab's homes alone.
---@class aineo.entry.Tab
---@field key string? what tells the tab's entry in the list of running editors from the editor's other tabs; nil for the first tab, whose entry keeps the name it has always had
---@field homes aineo.entry.Homes
---@field running_processes fun(): string[] the names of the processes the tab's run pane runs, the oldest first
---@field start_in_run_stack fun(command: string, options: { name: string, directory: string? }): integer starts `command` at the bottom of the tab's run stack as a call of a run tool asks, the pane left as it is (`aineo.entry.run_pane`'s `start_in_stack()`)
---@field actions table<string, fun()> what each of `:Aineo`'s arguments that acts on a tab does, by the argument
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
---@field is_busy fun(): boolean whether the Claude Code on the tab's terminal is busy
---@field page fun(): integer? the tab page the tab is in, nil before its layout opens
---@field is_bound fun(): boolean whether the tab page it is in still exists
---@field release fun() lets the tab's homes go as its tab page closes, at once
---@field finish fun(already_stopped: boolean) stops the tab's Claude Code as quitting stops it unless it was stopped, and ends the tab
---@field reopen fun() takes the first tab up again, with nothing of what it held

--- What a tab is given of the editor it is in (`opening.lua`'s
--- `tab_callbacks()`), which this file does not require: `opening.lua` makes
--- the tabs, and requires this file.
---@class aineo.entry.TabCallbacks
---@field on_bound fun(tab: aineo.entry.Tab) called with the tab each time its layout opens in a tab page it was not in
---@field open_new_tab fun(start?: fun(tab: aineo.entry.Tab), after_current?: boolean) see `opening.lua`'s `open_new_tab()`

--- Makes one tab of aineo from `homes`: the Claude Code session it starts,
--- and the Report, Input, changes pane and layout that follow that session.
--- Every state a tab keeps — the session its panes follow, the claim of a
--- session, the confirmation of a start — is held here, in this tab, and the
--- homes' module-level functions are not called: a tab acts on `homes` alone.
---
--- `callbacks.on_bound` is called with the tab each time its layout opens in
--- a tab page it was not in, which is the tab page the tab is in from then
--- on: once for a tab of copies, and again for the first tab each time it is
--- taken up after its tab page closed. A pick of `\S` opens its tab with
--- `callbacks.open_new_tab`.
---
---@param homes aineo.entry.Homes
---@param key string? see `aineo.entry.Tab`
---@param callbacks aineo.entry.TabCallbacks
---@return aineo.entry.Tab
local function make_tab(homes, key, callbacks)
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

  --- Gives the report home the editor's clock, the state directory and
  --- working directory of `kept_places()`, and the opening of a file a
  --- double-clicked path names, as a link to it opens (`links.open_file()`),
  --- the first time only.
  local function give_report_environment()
    if report_environment_given then
      return
    end
    homes.report.set_report_environment({
      clock = function()
        return os.date('%Y-%m-%dT%H:%M:%S')
      end,
      state_directory = places.kept_places().state_directory,
      working_directory = places.kept_places().working_directory,
      open_file = links.open_file,
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
      draft.set_draft_environment(places.kept_places())
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
      state_directory = places.kept_places().state_directory,
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
      require('aineo.mcp').release_claim(
        places.kept_places().state_directory,
        claimed,
        vim.v.servername
      )
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
      places.kept_places().state_directory,
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
    local claimant =
      require('aineo.mcp').session_claimant(places.kept_places().state_directory, session)
    return claimant == vim.v.servername
  end

  --- Tells the user, once for each session and tab, that `session`, which the
  --- panes of this tab follow, is followed by the panes of another tab of this
  --- Neovim too.
  ---@type table<string, true>
  local shared_session_told = {}

  ---@param session string
  local function warn_when_open_in_another_tab(session)
    local other = registry.tab_following(session, tab)
    if other and not shared_session_told[session .. (other.key or '')] then
      shared_session_told[session .. (other.key or '')] = true
      vim.notify(
        ('aineo: this session is also open in tab %d'):format(registry.tab_number(other)),
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
    folder_tabs.keep_folder_tabs()
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
    editors.make_editor_handlers()
    local written, failure =
      pcall(require('aineo.mcp').write_editor_entry, places.kept_places().state_directory, {
        address = vim.v.servername,
        working_directory = places.kept_places().working_directory,
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
      require('aineo.mcp').running_sessions(places.kept_places().state_directory, working_directory)
    if vim.tbl_contains(running, dead) then
      return
    end
    homes.report.hand_over_report_session(dead, fresh)
    homes.draft.hand_over_draft_session(dead, fresh)
    homes.changes.hand_over_changes_session({
      from = dead,
      to = fresh,
      state_directory = places.kept_places().state_directory,
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
    folder_tabs.keep_folder_tabs()
  end

  --- The terminal of the Claude session aineo started last — the new
  --- session's once one took the place of a resume Claude Code found no
  --- conversation for — or `nil` before it has started one.
  ---@type integer|nil
  local claude_terminal = nil

  --- Whether the Claude Code on the tab's terminal is busy now
  --- (`b:aineo_session_busy`); false before a terminal exists, and once it is
  --- wiped.
  ---
  ---@return boolean
  local function is_busy()
    return claude_terminal ~= nil
      and vim.api.nvim_buf_is_valid(claude_terminal)
      and vim.b[claude_terminal].aineo_session_busy == true
  end

  --- Tells the tabs home whether the tab's Claude Code is busy, for the tab
  --- page the tab is in; nothing before the tab is in one, which
  --- `callbacks.on_bound` answers by telling it again.
  ---
  ---@param busy boolean
  local function tell_tabs_home_busy(busy)
    if bound_page then
      require('aineo.tabs').set_busy(bound_page, busy)
    end
  end

  --- Follows the link `text` shown in Claude's terminal, naming line `line`
  --- when it names one (`links.open_link()`): a relative path is in the
  --- directory the session's Claude Code started in.
  ---
  ---@param text string
  ---@param line integer?
  local function follow_link(text, line)
    links.open_link(text, line, homes.claude.session_directory())
  end

  --- Follows the Claude Code on `terminal`, now the tab's own: the tab line
  --- is drawn again whenever its session's name changes
  --- (`redraw_tab_line_when_named()`), the tabs home is told whenever it
  --- starts or stops being busy (`busy_watch`), and a link it shows is
  --- followed on a double-click (`links.map_link_keys()`, `follow_link()`).
  ---
  ---@param terminal integer
  local function follow_claude_terminal_activity(terminal)
    redraw_tab_line_when_named(terminal)
    busy_watch.tell_when_busy_changes(terminal, tell_tabs_home_busy)
    links.map_link_keys(terminal, follow_link)
  end

  --- Makes the tab the one in the tab page the current window is in, once its
  --- layout has opened there; and tells `callbacks.on_bound` of it. Does nothing for a
  --- tab bound to a tab page that exists still.
  local function bind_to_current_page()
    if bound_page and vim.api.nvim_tabpage_is_valid(bound_page) then
      return
    end
    bound_page = vim.api.nvim_get_current_tabpage()
    callbacks.on_bound(tab)
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
        follow_claude_terminal_activity(terminal)
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
  --- `claude.cmd` and `claude.hide_multiplexer`, the report server, the tools
  --- that need no approval allowed, the instructions — the report's, then,
  --- after a blank line each, the announcement tool's paragraph and the run
  --- tools' — and the subagents' context for the `SubagentStart` hook
  --- (`aineo.mcp`), the state directory of `kept_places()`, the editor's
  --- address and program for the session hooks, and the callbacks that make
  --- the panes follow the session (`replacement_callbacks()`,
  --- `follow_confirmed_start()`). With `new_session` the start is on a new
  --- session id.
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
      hide_multiplexer = config.claude.hide_multiplexer,
      cwd = working_directory,
      mcp_servers = mcp.mcp_servers(vim.v.servername, vim.v.progpath),
      allowed_tools = mcp.allowed_mcp_tools(),
      instructions = report.report_instructions(mcp.report_tool_name())
        .. '\n\n'
        .. mcp.announce_instructions()
        .. '\n\n'
        .. mcp.run_instructions(),
      subagent_context = mcp.subagent_announce_context(),
      state_directory = places.kept_places().state_directory,
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
    return places.kept_places().working_directory
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
  --- the middle column, the configuration's `changes.working_branch`, and the
  --- files window's key `prefix` followed by `<CR>`, none when `prefix` is
  --- `false`, that opens a file for edition.
  ---
  ---@param config table the resolved configuration
  ---@param new_session boolean? start on a new session id
  ---@param start fun(claude: table, settings: aineo.claude.Settings): integer
  ---@return integer terminal
  local function begin_claude(config, new_session, start)
    local working_directory = start_directory()
    forget_confirmation_unless_running()
    claude_terminal = start(homes.claude, claude_settings(config, working_directory, new_session))
    follow_claude_terminal_activity(claude_terminal)
    homes.changes.begin_session({
      directory = working_directory,
      show_diff = function(diff)
        return homes.layout.show_diff(diff)
      end,
      working_branch = config.changes.working_branch,
      edit_file_key = config.prefix and config.prefix .. '<CR>' or nil,
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

  --- The run pane's terminals for the layout: the tab's processes, the oldest
  --- first, with the winbar that names each one; `nil` while it runs none.
  ---
  ---@return aineo.layout.RunPane|nil
  local function run_stack()
    local buffers = homes.run.buffers()
    if #buffers == 0 then
      return nil
    end
    return { buffers = buffers, winbar = require('aineo.run').WINBAR }
  end

  --- The buffers aineo's layout shows: `claude_buffer`, the Claude session's
  --- terminal, the Report, taken from the report home, which this gives its
  --- environment the first time it is called (`give_report_environment()`),
  --- the changes pane's (`changes_pane()`) and the terminal of the tab's
  --- shell while it runs one (`aineo.shell`'s `shell_buffer()`), none
  --- otherwise; the terminals of the tab's run pane, with the winbar that
  --- names each process (`aineo.run`'s `buffers()`, `WINBAR`), none while it
  --- runs nothing; with the Report's share from `config`, and the status line
  --- of Claude's window, which draws the session's name and folder
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
      run = run_stack(),
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

  --- Calls `show`, which shows a pane through the layout, with the function
  --- that makes the arrangement the layout opens with when it must, around the
  --- Claude session's terminal as it is (`current_claude_terminal()`). When
  --- the layout asked for it, it opened, and the tab is bound to the tab page
  --- and Input is handed to the draft home (`keep_input_draft()`).
  ---
  ---@param show fun(make_arrangement: fun(): aineo.layout.Arrangement)
  local function with_pane_arrangement(show)
    local config = resolved_config()
    local opened = false
    show(function()
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
  --- first (`aineo.changes`'s `toggle_focused_view()`), as showing it anew
  --- reads it, in the view it was left in; pressed with the cursor in one of
  --- its two windows, it switches between its default view and its focused
  --- view as well.
  ---
  ---@param pane aineo.layout.Pane
  local function focus_pane(pane)
    if pane == 'changes' then
      homes.changes.toggle_focused_view()
    end
    with_pane_arrangement(function(make_arrangement)
      homes.layout.focus_pane(pane, make_arrangement)
    end)
  end

  --- Shows `pane` in the layout's right column as `focus_pane()` shows it,
  --- the cursor staying where it is (`aineo.layout`'s `show_pane()`).
  ---
  ---@param pane aineo.layout.Pane
  local function show_pane(pane)
    with_pane_arrangement(function(make_arrangement)
      homes.layout.show_pane(pane, make_arrangement)
    end)
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
    local folder = places.kept_places().working_directory
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
        errors.run(function()
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
    prompt.after_entering_terminal_mode(terminal, outcome, function()
      errors.run(function()
        if claude.prompt_shows_text(vim.api.nvim_get_current_win()) then
          prompt.return_to(origin)
          vim.notify(prompt_holds_text, vim.log.levels.WARN)
          return
        end
        act()
      end)
    end, function()
      prompt.return_to(origin)
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
    follow_claude_terminal_activity(terminal)
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
    local shown = registry.sessions_shown_in_tabs()
    local standing = claude.session_standing(listed, shown, folder)
    if standing == 'shown' then
      local current = registry.tab_of_current_page()
      local page = vim.api.nvim_list_tabpages()[shown[listed.session_id]]
      if page and not (current and current.session_id() == listed.session_id) then
        vim.api.nvim_set_current_tabpage(page)
      end
    elseif closing.stops_in_closed_tab(listed.session_id) then
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
    local folder = places.kept_places().working_directory
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
        callbacks.open_new_tab(function(opened)
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
    local shown = registry.sessions_shown_in_tabs()
    vim.ui.select(listed, {
      prompt = 'Claude sessions',
      format_item = function(session)
        return claude.session_row(session, shown, folder)
      end,
    }, function(picked)
      if picked then
        errors.run(function()
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
    local folder = places.kept_places().working_directory
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

  --- The autocommand group of the tab's run pane handlers, one for each tab
  --- (`run_pane.watch()`).
  local run_group = 'aineo.entry.run.' .. (key or 'first')

  --- The tab's run pane (`aineo.entry.run_pane`): what it does for the tab's
  --- run home and layout.
  local run = run_pane.make({
    run = homes.run,
    layout = homes.layout,
    focus_pane = focus_pane,
    show_pane = show_pane,
    is_current = function()
      return bound_page ~= nil and bound_page == vim.api.nvim_get_current_tabpage()
    end,
  })

  --- What each of `:Aineo`'s arguments that acts on the tab does, by the
  --- argument, its words joined by a space (`pane agent`).
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
    ['pane run'] = run.run_command,
    ['run shell'] = run.run_shell,
    ['diff close'] = function()
      homes.changes.close_shown_diff()
    end,
    zoom = function()
      homes.layout.toggle_zoom()
    end,
    ['zoom full'] = function()
      homes.layout.toggle_full_zoom()
    end,
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
      errors.run(step)
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
      homes.run.let_go or leave_as_it_is,
      key == nil and leave_as_it_is or function()
        pcall(vim.api.nvim_del_augroup_by_name, run_group)
      end,
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

  run.watch(run_group)
  tab.actions = actions
  tab.running_processes = homes.run.running
  tab.start_in_run_stack = run.start_in_stack
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
  tab.is_busy = is_busy
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

M.make_tab = make_tab
M.NO_INPUT_BUFFER = NO_INPUT_BUFFER

return M
