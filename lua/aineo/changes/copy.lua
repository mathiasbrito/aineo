--- One changes home: the session of one changes pane, and everything the
--- pane keeps of it — its base and saves, its two buffers, the filter
--- selected, the diffs shown, the watch of its repository — behind the
--- functions `require('aineo.changes')` offers. What the pane shows is
--- told there.

local git = require('aineo.git')
local branch = require('aineo.changes.branch')
local commit_file = require('aineo.changes.commit_file')
local diff_position = require('aineo.changes.diff_position')
local diffs = require('aineo.changes.diffs')
local entry_diff = require('aineo.changes.entry_diff')
local filter = require('aineo.changes.filter')
local full_context = require('aineo.changes.full_context')
local graph = require('aineo.changes.graph')
local head_diff = require('aineo.changes.head_diff')
local kept = require('aineo.changes.kept')
local landed = require('aineo.changes.landed')
local lines = require('aineo.changes.lines')
local open_file = require('aineo.changes.open_file')
local pages = require('aineo.changes.pages')
local pause = require('aineo.changes.pause')
local reports = require('aineo.changes.reports')
local scope = require('aineo.changes.scope')
local scratch = require('aineo.changes.scratch')
local serial = require('aineo.changes.serial')
local tree_commits = require('aineo.changes.tree_commits')
local worktrees = require('aineo.changes.worktrees')

local M = {}

--- How long the cursor must stay in the commits window before the files
--- window is read for the line under it.
local SELECTION_PAUSE_MS = 150

--- How long the cursor must stay on a line of the files window before the
--- diff of the file listed there is shown in the middle column.
local FOLLOW_PAUSE_MS = 120

--- How many commits the commit graph draws when the session's settings name
--- no limit: as `changes.graph_limit` is by default.
local DEFAULT_GRAPH_LIMIT = 1000

--- How long a report git does not list yet is matched again at every read,
--- from the call: 60 s, time enough for an agent that reports a worktree a
--- moment before git lists it, and short enough that a mistyped report
--- does not change the pane long after.
local REPORT_WAIT_MS = 60000

--- How many distinct reports may wait at once in one home: far more than
--- the worktrees and branches an agent and its subagents start together,
--- and a bound on the timers, reads and messages a flood of reports git
--- never lists can make.
local MOST_WAITING = 32

--- How long each git run that resolves a reported base may take before it
--- is stopped: far longer than `rev-parse` takes, and short enough that the
--- four runs a resolution may make end before the editor, which waits for
--- the answer before it answers the agent, stops waiting at 4 s, inside
--- the 5 s the report server waits for it.
local BASE_RESOLUTION_LIMIT_MS = 900

--- Starts a `vim.uv` timer that runs `act` once, on the main loop, after
--- `milliseconds`, and returns what stops and closes it.
---
---@param milliseconds integer
---@param act fun()
---@return fun() stop
local function start_uv_timer(milliseconds, act)
  local timer = assert(vim.uv.new_timer())
  local function stop()
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end
  timer:start(
    milliseconds,
    0,
    vim.schedule_wrap(function()
      stop()
      act()
    end)
  )
  return stop
end

--- What the focused view shows alone, first of all: the worktree picked, or
--- the first reported, by its top level; or the local branch picked, or the
--- first reported, by its name; with its heading in the commits window.
---@class aineo.changes.FocusedWork
---@field top? string the worktree's top level
---@field branch? string the branch's name
---@field heading string

--- A changes home, whose functions are called as fields, never as methods.
---@class aineo.changes.Home
---@field begin_session fun(settings: aineo.changes.SessionSettings)
---@field follow_changes_session fun(followed: aineo.changes.FollowedSession)
---@field hand_over_changes_session fun(hand_over: aineo.changes.HandOver)
---@field refresh_shown_pane fun()
---@field toggle_focused_view fun() reads the shown pane again, and, with the cursor in one of its windows, switches it between its default view and the focused view
---@field add_reported_work fun(work: aineo.changes.ReportedWork, tell: fun(message: string)): boolean whether the home took the report
---@field resolve_reported_work fun(work: aineo.changes.ReportedWork, done: fun(resolved: aineo.changes.ReportedWork|nil, refusal: string|nil)) checks a report's branches are local branches and resolves each base to its full id in the worktree's folder, else in the session's repository, or says why it is refused
---@field pane_buffers fun(): { files: integer, commits: integer }
---@field close_shown_diff fun() closes the windows of the current tab page that show a diff the home showed, and tells once when none was closed
---@field focused_work fun(): aineo.changes.FocusedWork|nil what the focused view shows alone, nil for the default view
---@field watch_focused_work fun(watcher: fun()) calls `watcher` each time what `focused_work()` gives changes
---@field offer_scopes fun() what `s` does in the pane: offers the worktrees, branches and reported work to show alone
---@field let_go? fun() only on a home `require('aineo.changes').new()` made: stops its watch, removes its handlers and wipes its buffers

--- Makes a changes home: its own session, base and saves, pane buffers,
--- selection, diffs and watch. What the editor shares between homes is the
--- diffs' context (`aineo.changes.full_context`), which `F` toggles for the
--- editor's life. Every buffer name, autocommand group and handler the home
--- makes is one no other home makes, as `label` says: the module's own home
--- is made without one and keeps the names it has always had, and a home
--- made with one names its buffers `aineo://<label>/…` and its groups
--- `…_<label>`. Two homes made with one label would share them, so each
--- label is given to one home.
---
---@param label? string what tells this home's names from every other's; nil for the module's own home
---@return aineo.changes.Home
function M.new(label)
  local home = {}

  --- `name`, an `aineo://` buffer name, as this home names its buffers: as
  --- it is for the module's own home, and under `aineo://<label>/` for any
  --- other, so that no buffer of another home holds it.
  ---
  ---@param name string
  ---@return string
  local function own_name(name)
    if not label then
      return name
    end
    return 'aineo://' .. label .. '/' .. name:sub(#'aineo://' + 1)
  end

  --- `group`, the name of an autocommand group, as this home names its
  --- groups: as it is for the module's own home, and followed by `_<label>`
  --- for any other, so that making this home's group clears no other home's.
  ---
  ---@param group string
  ---@return string
  local function own_group(group)
    if not label then
      return group
    end
    return group .. '_' .. label
  end
  --- What the composition root hands the home as the session begins.
  ---@class aineo.changes.SessionSettings
  ---@field directory string the directory whose repository the session is about: Claude Code's working directory at its first start
  ---@field show_diff fun(diff: integer): integer|nil shows `diff` in the middle column, the cursor left where it is, and returns its window, or nil when there is no room
  ---@field git? aineo.git.WatchOptions how the git home runs git; its defaults when not given
  ---@field working_branch? string the branch work lands in, as the user's setting names it; the remote's default branch when not given
  ---@field edit_file_key? string a Normal-mode key, written as in a mapping, that opens the file under the cursor in the files buffer for edition as `<S-CR>` does; none when not given. Mapped when the files buffer is made, so a session holds it when begun before the buffer
  ---@field show_changes_pane? fun() shows the changes pane in the layout's right column, the cursor staying where it is; the pane stays hidden when not given
  ---@field start_timer? fun(milliseconds: integer, act: fun()): fun() starts a timer that runs `act` once, on the main loop, after `milliseconds`, and returns what stops it; a `vim.uv` timer when not given
  ---@field now? fun(): integer the time the pane tells the ages of commits at, in seconds since the epoch; `os.time` when not given
  ---@field graph_limit? integer how many commits the commit graph draws, at least 1; `DEFAULT_GRAPH_LIMIT` when not given

  --- The session, from `begin_session()` on.
  ---@class aineo.changes.Session
  ---@field settings aineo.changes.SessionSettings
  ---@field repository? aineo.git.Repository
  ---@field absence? aineo.git.Failure why no repository was found for the directory, while none is
  ---@field base? string
  ---@field followed? aineo.changes.FollowedSession the Claude Code session the pane is for, once the home is told one
  ---@field keeps_followed? boolean whether the base and the saves are kept for the session followed: not when what was kept for it is another repository's or cannot be read, which is never written over
  ---@field looking_for_head? boolean whether git looks for `HEAD`, the base of the session followed, while it runs
  ---@field head_look_failed? boolean whether the last look for the base of the session followed failed
  ---@field keeping_failed? boolean whether the last write of the base and the saves of the session followed failed
  ---@field selected aineo.changes.Filter the filter the commits window's cursor last selected: *Session work* until it selects another
  ---@field cursor_unplaced boolean whether the commits window's cursor is still to be put on the selected filter's line, which it is until the commits window lists that line in a window
  ---@field listed? aineo.changes.Listing what the files window lists, as last read
  ---@field files_failure? aineo.git.Failure why the last read of the files failed, when it did
  ---@field commits? aineo.git.CommitsSince the commits since the base, as last read
  ---@field commits_failure? aineo.git.Failure why the last read of the commits failed, when it did
  ---@field landed? aineo.changes.Landed what landed in the working branch, as last read; nil while unread, and when there is no working branch
  ---@field commits_others aineo.changes.OtherWorktrees what the commits window knows of the other worktrees
  ---@field scope? aineo.changes.Scope the other worktree or the local branch the user picked to show alone, kept while the default view is shown too
  ---@field branch? aineo.changes.BranchSection what the commits window last read of the branch the scope names; nil while it has read none, and for any other scope
  ---@field focused boolean whether the commits window shows the focused view — the scope alone, or the reported work — in place of the default view; false while there is neither
  ---@field nodes aineo.changes.ReportedNode[] the Reported section's worktrees, the agents of the tab's Claude Code reported and git lists, in the order their last reports were taken (`aineo.changes.reports`)
  ---@field reported_branches table<string, aineo.changes.BranchSection> what the commits window last read of each reported branch no reported worktree has checked out, by name
  ---@field tree_commits table<string, aineo.git.Commit[]> what the commits window last read of the commits each branch's line of the Reported section lists, by branch and base (`aineo.changes.tree_commits`)
  ---@field shows_reported boolean whether the focused view is the reported work, chosen last, rather than the scope
  ---@field shown_label? string while the focused view is the reported work, the label of the worktrees it shows, `''` for those with none; nil for every worktree
  ---@field waiting aineo.changes.WaitingReport[] the reports git did not list yet, by worktree, each matched again at every read until its timer lets it go
  ---@field kept_view? aineo.changes.KeptView the view as last kept for the session followed, or as it was when the pane began following it; nil until the pane follows a session in a repository it found, and while it follows none
  ---@field restoring_view? boolean whether the view kept for the session followed is being read back, which keeps what the pane shows from being kept over it
  ---@field saved table<string, true> the files the user saved under the base, by path relative to the top level: since the session began, or the Claude Code session's followed; none saved while no repository was found
  ---@field early_saves string[] the files the user saved, resolved, while the first look for the repository runs
  ---@field shown boolean whether the pane has been shown
  ---@field following_soon boolean whether the pane's showing is followed at the main loop's next turn
  ---@field watch? aineo.git.Watch the running watch, from the pane's first showing; nil once it failed
  ---@field watch_failure? aineo.git.Failure why the watch failed, until one starts again
  ---@field graph_shown boolean whether the commits window shows the commit graph in place of its sections, which `t` switches
  ---@field graph? aineo.git.CommitGraph the commit graph, as last read; nil while none was read
  ---@field graph_failure? aineo.git.Failure why the last read of the commit graph failed, when it did
  ---@field graph_cursor_unplaced boolean whether the commits window's cursor is still to be put on a commit of the graph, as it is once `t` shows the graph, until the graph lists one in a window
  ---@field selected_before_graph? aineo.changes.Filter the filter selected when `t` showed the graph, selected again when `t` shows the sections

  ---@type aineo.changes.Session|nil
  local session = nil

  --- The Claude Code session the pane was told to follow before the session
  --- began, followed once it does.
  ---@type aineo.changes.FollowedSession|nil
  local followed_before_beginning = nil

  --- The base and the saves of each Claude Code session the pane followed
  --- whose own could not be kept, by session id, so that following the
  --- session again brings them back: held for the home's life when what
  --- was kept for it is another repository's or cannot be read, and until a
  --- write of them succeeds when their write failed (`hold_unkept_base()`).
  ---@type table<string, { base: string|nil, saved: table<string, true>, keeps: boolean|nil }>
  local held_bases = {}

  --- What the files window lists.
  ---@class aineo.changes.Listing
  ---@field filter aineo.changes.Filter the filter whose files these are
  ---@field changes? aineo.git.Change[] its files, as last read; none when the read of them failed
  ---@field worktree? aineo.changes.WorktreeSection for a filter of another worktree, that worktree as the read of the files found it

  --- The pane's buffers, by window.
  ---@type { files: integer|nil, commits: integer|nil }
  local buffers = {}

  --- `worktree`, a worktree other than the editor's, as the commits window
  --- last read it: the section of `session.commits_others` with its top
  --- level, or `worktree` itself when the window lists none.
  ---
  ---@param worktree aineo.changes.WorktreeSection
  ---@return aineo.changes.WorktreeSection
  local function section_as_last_read(worktree)
    for _, section in ipairs(session.commits_others.sections) do
      if section.top == worktree.top then
        return section
      end
    end
    return worktree
  end

  --- The filter the files window names: `listed`'s, the selected one before
  --- any list was read, and, for another worktree's, with the worktree as the
  --- commits window last read it, its branch included.
  ---
  ---@param listed aineo.changes.Listing|nil
  ---@return aineo.changes.Filter
  local function filter_named(listed)
    local named = listed and listed.filter or session.selected
    if named.worktree then
      return filter.in_worktree(named, section_as_last_read(named.worktree))
    end
    return named
  end

  --- The time the pane tells the ages of commits at: the session's own
  --- clock (`aineo.changes.SessionSettings`' `now`).
  ---
  ---@return integer seconds since the epoch
  local function clock_now()
    return (session.settings.now or os.time)()
  end

  --- The files window's page for what the session knows: why it has no
  --- repository, when it has none, or the files of the one filter it lists
  --- (`filter_named()`).
  ---
  ---@return aineo.changes.Page
  local function files_page()
    if session.absence then
      return lines.no_repository(session.absence, session.settings.directory)
    end
    local listed = session.listed
    return lines.files_window({
      filter = session.repository and filter_named(listed) or nil,
      changes = listed and listed.changes,
      failure = session.files_failure or session.watch_failure,
      worktree = listed and listed.worktree,
      saved = session.saved,
      unwatched_subdirectories = session.watch ~= nil and not session.watch.watches_subdirectories,
      now = clock_now(),
    })
  end

  --- The top level of the editor's own worktree, nil before the session's
  --- repository is found.
  ---
  ---@return string|nil
  local function own_top()
    return session.repository and session.repository.top
  end

  --- The node of the Reported section whose worktree's top level is `top`;
  --- nil when none is.
  ---
  ---@param top string
  ---@return aineo.changes.ReportedNode|nil
  local function node_at(top)
    return vim.iter(session.nodes):find(function(node)
      return node.worktree.top == top
    end)
  end

  --- What the focused view shows of the reported work, each worktree as the
  --- commits window last listed it, else as git listed it when it was
  --- reported, and each branch read alone as the commits window last read
  --- it (`reports.work_of()`): every worktree's, or, while `shown_label`
  --- names one, those of that label alone.
  ---
  ---@param shown_label string|nil
  ---@return aineo.changes.ScopeMember[]
  local function reported_members(shown_label)
    local nodes = shown_label and reports.labelled(session.nodes, shown_label) or session.nodes
    return vim.tbl_map(function(pick)
      if pick.top then
        local section = scope.section_on(session.commits_others, pick.top)
        return { worktree = section or node_at(pick.top).worktree }
      end
      return { branch = session.reported_branches[pick.branch] or { name = pick.branch } }
    end, reports.work_of(nodes, own_top()))
  end

  --- What the commits window shows alone while the focused view is the one
  --- shown: the reported work, when it is the focused view
  --- (`reported_members()`); else the worktree or branch of the session's
  --- scope; nil for the default view, and for reported work that shows
  --- nothing alone.
  ---
  ---@return aineo.changes.ScopeMember[]|nil
  local function scope_shown()
    if not session.focused then
      return nil
    end
    if session.shows_reported then
      local members = reported_members(session.shown_label)
      return #members > 0 and members or nil
    end
    if not session.scope then
      return nil
    end
    return scope.members_shown(session.scope, session.commits_others, session.branch)
  end

  --- The base the work of `line`, a branch's line of the Reported section,
  --- is read from where its line picks it: on the editor's own worktree,
  --- while it has that branch checked out, the session's base, which the
  --- default view reads; on another worktree that has it checked out, that
  --- worktree's, as the commits window last listed it; else the branch's
  --- own, as the commits window last read it alone; nil while it has read
  --- neither.
  ---
  ---@param line aineo.changes.TreeLine
  ---@return string|nil
  local function read_base_of(line)
    if line.checked_out and line.node.worktree.top == own_top() then
      return session.base
    end
    if line.checked_out then
      local section = scope.section_on(session.commits_others, line.node.worktree.top)
      return section and section.listed and section.base or nil
    end
    local read = session.reported_branches[line.branch.name]
    return read and read.tip and read.base or nil
  end

  --- The lines of the Reported section (`reports.tree_lines()`), each
  --- branch's with the base its work was last read from
  --- (`read_base_of()`) and the commits last read from that base
  --- (`aineo.changes.tree_commits`).
  ---
  ---@return aineo.changes.TreeLine[]
  local function reported_lines()
    return vim.tbl_map(function(line)
      if line.branch then
        line.read_base = read_base_of(line)
        line.commits = tree_commits.commits_of(session.tree_commits, line)
      end
      return line
    end, reports.tree_lines(session.nodes, own_top()))
  end

  --- The commits window's page for what the session knows: why it has no
  --- repository, when it has none; the commit graph, while it is shown
  --- (`aineo.changes.graph`), in place of the whole list, the Reported
  --- section included; or its commits, under the Reported section in the
  --- default view (`reported_lines()`).
  ---
  ---@return aineo.changes.Page
  local function commits_page()
    if session.absence then
      return lines.no_repository(session.absence, session.settings.directory)
    end
    if session.graph_shown and session.repository then
      return graph.page({
        graph = session.graph,
        failure = session.graph_failure or session.watch_failure,
      })
    end
    return lines.commits_window({
      reported = reported_lines(),
      scope = scope_shown(),
      since = session.commits,
      base = session.base,
      failure = session.commits_failure or session.watch_failure,
      lists_filters = session.repository ~= nil,
      landed = session.landed,
      worktrees = session.commits_others,
      now = clock_now(),
    })
  end

  --- Whether `buffer`, a buffer of the pane once made, can be written: it is
  --- loaded. One wiped, or unloaded as `:bdelete` unloads it, is made anew
  --- and written the next time the pane is shown (`pane_buffers()`).
  ---
  ---@param buffer integer|nil
  ---@return boolean
  local function is_writable(buffer)
    return buffer ~= nil and vim.api.nvim_buf_is_loaded(buffer)
  end

  --- The buffers of the pane whose page Neovim refused, each to be written at
  --- the editor's next `SafeState`.
  ---@type table<integer, true>
  local refused = {}

  --- Writes `buffer`, a buffer of the pane, with `page()`, the page for what
  --- the session knows, while it can be written (`is_writable()`). A page
  --- Neovim refuses, as it does while textlock holds, is written again at the
  --- editor's next `SafeState`, once whatever was refused meanwhile, with what
  --- the session knows then. Calls `written()`, when given, each time a page
  --- was written.
  ---
  ---@param buffer integer|nil
  ---@param page fun(): aineo.changes.Page
  ---@param written? fun()
  local function show_page(buffer, page, written)
    if not (session and is_writable(buffer)) then
      return
    end
    if pages.write_page(buffer, page()) then
      if written then
        written()
      end
      return
    end
    if refused[buffer] then
      return
    end
    refused[buffer] = true
    vim.api.nvim_create_autocmd('SafeState', {
      once = true,
      desc = 'aineo: write the changes pane once the editor allows it',
      callback = function()
        refused[buffer] = nil
        show_page(buffer, page, written)
      end,
    })
  end

  --- The key of the filter whose files the cursor of the files window goes
  --- to the first of once the window lists them (`move_to_files_window()`);
  --- nil while the cursor waits for none.
  ---@type string|nil
  local awaited_files_key = nil

  --- Whether the files window lists the files of the selected filter, as
  --- read.
  ---
  ---@return boolean
  local function lists_selected_files()
    return session.listed ~= nil and filter.same(session.listed.filter, session.selected)
  end

  --- Puts the cursor of `window`, showing the files buffer, on a line that
  --- lists a file: where it is when it is on one, else the first such line.
  --- A page that lists no file leaves it where it is.
  ---
  ---@param window integer
  local function put_cursor_on_a_file(window)
    local at_cursor = pages.entry_at(buffers.files, vim.api.nvim_win_get_cursor(window)[1])
    local first = pages.first_file_line(buffers.files)
    if first and not (at_cursor and at_cursor.change) then
      vim.api.nvim_win_set_cursor(window, { first, 0 })
    end
  end

  --- Carries out the wait for the files of a filter that `move_to_files_window()`
  --- began, once the files window lists the files of the selected filter and
  --- that filter is the one awaited: the cursor of each window showing the
  --- files buffer goes to a file (`put_cursor_on_a_file()`), and the wait ends.
  local function place_awaited_files_cursor()
    if
      not (
        awaited_files_key
        and is_writable(buffers.files)
        and lists_selected_files()
        and filter.key(session.selected) == awaited_files_key
      )
    then
      return
    end
    awaited_files_key = nil
    for _, window in ipairs(vim.fn.win_findbuf(buffers.files)) do
      put_cursor_on_a_file(window)
    end
  end

  --- Writes the files buffer for what the session knows (`files_page()`,
  --- `show_page()`), then keeps the wait of the cursor for its files
  --- (`place_awaited_files_cursor()`).
  local function show_files()
    show_page(buffers.files, files_page, place_awaited_files_cursor)
  end

  --- Puts the cursor of each window showing the commits buffer on the line of
  --- the selected filter, while the session says it is still to be put there
  --- (`aineo.changes.Session`'s `cursor_unplaced`) and the buffer lists that
  --- line in a window.
  local function place_commits_cursor()
    if not (session.cursor_unplaced and is_writable(buffers.commits)) then
      return
    end
    local line = pages.line_of(buffers.commits, filter.key(session.selected))
    local windows = vim.fn.win_findbuf(buffers.commits)
    if not line or #windows == 0 then
      return
    end
    for _, window in ipairs(windows) do
      vim.api.nvim_win_set_cursor(window, { line, 0 })
    end
    session.cursor_unplaced = false
  end

  --- Whether the user was told that a session's view could not be kept
  --- (`tell_view_failure()`).
  local view_failure_told = false

  --- Tells the user, as a warning, that a session's view could not be kept,
  --- and why: `failure`. Told once for the home's life; the pane goes on
  --- from what it holds.
  ---
  ---@param failure string
  local function tell_view_failure(failure)
    if view_failure_told then
      return
    end
    view_failure_told = true
    vim.notify(
      ("aineo: the changes pane cannot keep this session's view, and goes on without: %s"):format(
        failure
      ),
      vim.log.levels.WARN
    )
  end

  --- Keeps the view the pane shows for the Claude Code session it follows
  --- (`aineo.changes.kept`), when it differs from the view last kept or
  --- taken: a view that did not change is not written again, and a write
  --- that fails is told once (`tell_view_failure()`) and tried again when
  --- the view next changes. Keeps nothing while the pane follows no session,
  --- before its repository is found, or while the view kept is read back
  --- (`begin_view()`).
  local function keep_view()
    local followed = session.followed
    if not (followed and session.repository and session.kept_view) or session.restoring_view then
      return
    end
    local view = scope.kept_view_of(session.repository.top, {
      scope = session.scope,
      focused = session.focused,
      nodes = session.nodes,
      shows_reported = session.shows_reported,
    })
    if vim.deep_equal(view, session.kept_view) then
      return
    end
    session.kept_view = view
    local failure = kept.keep_view(followed.state_directory, followed.id, view)
    if failure then
      tell_view_failure(failure)
    end
  end

  --- What the focused view shows alone (`home.focused_work()`); nil for the
  --- default view, and before the session has begun.
  ---
  ---@return aineo.changes.FocusedWork|nil
  local function focused_work()
    if not (session and session.focused) then
      return nil
    end
    if session.shows_reported then
      local first = reported_members(session.shown_label)[1]
      if not first then
        return nil
      end
      if first.worktree then
        return { top = first.worktree.top, heading = lines.worktree_heading(first.worktree) }
      end
      local name = first.branch.name
      return { branch = name, heading = scope.of_branch(name).heading }
    end
    local picked = session.scope
    if not picked then
      return nil
    end
    return { top = picked.top, branch = picked.branch, heading = picked.heading }
  end

  --- The functions told each time what the focused view shows alone changes
  --- (`home.watch_focused_work()`), and what they were told last.
  ---@type fun()[]
  local focused_work_watchers = {}
  ---@type aineo.changes.FocusedWork|nil
  local focused_work_told = nil

  --- Calls each function `home.watch_focused_work()` was given when what the
  --- focused view shows alone is no longer what they were told last.
  local function tell_focused_work()
    local now = focused_work()
    if vim.deep_equal(now, focused_work_told) then
      return
    end
    focused_work_told = now
    for _, watcher in ipairs(focused_work_watchers) do
      watcher()
    end
  end

  --- Puts the commits window's cursor on a commit of the graph once the
  --- graph is written (`aineo.changes.graph`); defined with the keys of the
  --- graph, as it selects what the cursor is put on.
  ---@type fun()
  local place_graph_cursor

  --- Puts the commits window's cursor where the page just written asks:
  --- on a commit of the graph while it is shown (`place_graph_cursor()`),
  --- else on the selected filter's line when it is still to be put there
  --- (`place_commits_cursor()`).
  local function place_cursor_after_writing()
    if session.graph_shown then
      place_graph_cursor()
    else
      place_commits_cursor()
    end
  end

  --- Writes the commits buffer for what the session knows (`commits_page()`,
  --- `show_page()`), then puts the cursor where the page asks
  --- (`place_cursor_after_writing()`), keeps the
  --- view the page shows (`keep_view()`) and tells those who watch what the
  --- focused view shows alone (`tell_focused_work()`): every change of the
  --- view is shown here.
  local function show_commits()
    show_page(buffers.commits, commits_page, place_cursor_after_writing)
    keep_view()
    tell_focused_work()
  end

  --- Whether the session's base is the one a read was asked from: not once
  --- the session has another, nor while it looks for one
  --- (`follow_changes_session()`).
  ---
  ---@param base string|nil
  ---@return boolean
  local function is_current_base(base)
    return not session.looking_for_head and session.base == base
  end

  --- Whether `others`, what a window knows of the other worktrees, shows
  --- anything in it: a section, or the line saying they could not be listed.
  ---
  ---@param others aineo.changes.OtherWorktrees
  ---@return boolean
  local function shows_any(others)
    return #others.sections > 0 or others.failure ~= nil
  end

  --- The base reported for the branch `name` in `node`, nil when the node
  --- holds no such branch or its report gave no base.
  ---
  ---@param node aineo.changes.ReportedNode|nil
  ---@param name string|nil
  ---@return string|nil
  local function base_in_node(node, name)
    local reported = node
      and vim.iter(node.branches):find(function(listed)
        return listed.name == name
      end)
    return reported and reported.base
  end

  --- The base reported for the branch `worktree`, a worktree as git lists
  --- it, has checked out, in the node of that worktree, which the pane reads
  --- it from in place of its own (`aineo.changes.worktrees`' `base_of`);
  --- nil when none was reported.
  ---
  ---@param worktree aineo.git.Worktree
  ---@return string|nil
  local function reported_base_of_worktree(worktree)
    return base_in_node(node_at(worktree.top), worktree.branch)
  end

  --- The base reported for the local branch `name` in the newest node that
  --- holds it, which the pane reads it from in place of its own
  --- (`aineo.changes.branch`'s `base`); nil when none was reported.
  ---
  ---@param name string
  ---@return string|nil
  local function reported_base_of_branch(name)
    for _, group in ipairs(reports.groups(session.nodes)) do
      for _, node in ipairs(group.nodes) do
        local base = base_in_node(node, name)
        if base then
          return base
        end
      end
    end
    return nil
  end

  --- What one window of the pane reads, and how it keeps and shows it.
  ---@class aineo.changes.WindowReads
  ---@field read_own fun(base: string|nil, done: fun(failure: aineo.git.Failure|nil, answer: any)) asks git for the editor's own list from the session's base
  ---@field take_own fun(failure: aineo.git.Failure|nil, answer: any) keeps what that read answered
  ---@field read_list? aineo.changes.ReadList asks git for another worktree's list; nil for a window that lists no other worktree
  ---@field others_field? 'commits_others' the field of the session that keeps what the window knows of the other worktrees; nil for a window that lists no other worktree
  ---@field took_others? fun(others: aineo.changes.OtherWorktrees) told what the window now knows of the other worktrees, before it is shown
  ---@field read_scope? fun(done: fun(shown: boolean)) reads what the scope shows besides the worktrees, after theirs, and calls `done(true)` when it read something the window shows; nil for a window that has none
  ---@field show fun() writes the window for what the session knows

  --- Returns the function that asks for one read of a window as `reads`
  --- describes it, one git at a time (`aineo.changes.serial`): the window's
  --- own list from the session's base, when asked with `with_own`, kept and
  --- shown as soon as git answers, then, for a window that lists them, the
  --- other worktrees' (`aineo.changes.worktrees`), kept and told to
  --- `reads.took_others`, then what `reads.read_scope` reads, and shown once
  --- all are read, when the window shows any of them, or did, or shows what
  --- the scope read. A read asked for with the own list while another
  --- runs reads it before the next other worktree's, or, when none is left,
  --- once more after; a read asked for without it runs once more after. The
  --- own list is not read while the session looks for its base, and an
  --- answer for a base that is no longer current (`is_current_base()`) is
  --- dropped, the read for the new one asked for already. What follows the
  --- own list starts before the list is shown, so that an error showing it
  --- stops no read, and the read ends before the other worktrees' are
  --- shown.
  ---
  ---@param reads aineo.changes.WindowReads
  ---@return fun(with_own: boolean) ask
  local function window_read(reads)
    local own_asked = false
    local function read_own_then(proceed)
      local base = session.base
      local with_own = own_asked
      own_asked = false
      if not (with_own and is_current_base(base)) then
        proceed()
        return
      end
      reads.read_own(base, function(failure, answer)
        if not is_current_base(base) then
          proceed()
          return
        end
        reads.take_own(failure, answer)
        proceed()
        reads.show()
      end)
    end
    local ask = serial.one_at_a_time(function(ended)
      read_own_then(function()
        if not reads.others_field then
          ended()
          return
        end
        local before = session[reads.others_field]
        worktrees.read_other_worktrees({
          found = session.repository,
          before = before,
          read_list = reads.read_list,
          base_of = reported_base_of_worktree,
          before_each_worktree = read_own_then,
          working_branch = session.settings.working_branch,
          git = session.settings.git,
        }, function(others)
          session[reads.others_field] = others
          if reads.took_others then
            reads.took_others(others)
          end
          local function finish(shows_scope)
            ended()
            if shows_scope or shows_any(before) or shows_any(others) then
              reads.show()
            end
          end
          if reads.read_scope then
            reads.read_scope(finish)
          else
            finish(false)
          end
        end)
      end)
    end)
    return function(with_own)
      own_asked = own_asked or with_own
      ask()
    end
  end

  --- What the files of a worktree fail with when its directory is gone by the
  --- time they are read.
  ---@type aineo.git.Failure
  local WORKTREE_GONE = { reason = 'failed', message = 'the worktree is gone' }

  --- Reads the files of the selected filter, a filter of another worktree,
  --- in that worktree, and calls `done(failure, listing)`: a commit's files in
  --- the repository the commits window found for the worktree; its whole
  --- change from its base, read again now (`aineo.changes.worktrees`'
  --- `read_worktree()`), which fails with `WORKTREE_GONE` when the worktree's
  --- directory is gone. The listing names the worktree as the read found it.
  ---
  ---@param selected aineo.changes.Filter a filter with a `worktree`
  ---@param done fun(failure: aineo.git.Failure|nil, listing: aineo.changes.Listing)
  local function read_worktree_files(selected, done)
    local options = session.settings.git
    local section = section_as_last_read(selected.worktree)
    if selected.kind == 'commit' then
      git.commit_files(section.repository, selected.commit.id, function(failure, changes)
        done(failure, { filter = selected, changes = changes, worktree = section })
      end, options)
      return
    end
    worktrees.read_worktree(
      {
        found = session.repository,
        before = worktrees.NONE,
        read_list = function(repository, base, listed)
          git.changed_files(repository, base, listed, options)
        end,
        base_of = reported_base_of_worktree,
        working_branch = session.settings.working_branch,
        git = options,
      },
      selected.worktree,
      function(read)
        if not read then
          done(WORKTREE_GONE, { filter = selected, worktree = section })
          return
        end
        done(read.failure, { filter = selected, changes = read.listed, worktree = read })
      end
    )
  end

  --- Reads the files that landed in the working branch: those that differ
  --- between the merge base of `base` and the commit the working branch
  --- named when the commits window last read it, and that commit. Calls
  --- `done(failure, changes)`; with the working branch not read yet, with no
  --- change and no failure, which the window shows as still reading; with a
  --- name that names no commit, with the failure saying so.
  ---
  ---@param base string|nil
  ---@param done fun(failure: aineo.git.Failure|nil, changes: aineo.git.Change[]|nil)
  local function read_landed_files(base, done)
    local read = session.landed
    if not read then
      done(nil, nil)
    elseif not read.tip then
      done(landed.unreadable(read), nil)
    else
      git.files_between(session.repository, base, read.tip, done, session.settings.git)
    end
  end

  --- What the commits window last read of the local branch `name`: of the
  --- branch the scope names, or of a reported branch read alone; nil while
  --- it has read none.
  ---
  ---@param name string|nil
  ---@return aineo.changes.BranchSection|nil
  local function branch_named(name)
    if session.branch and session.branch.name == name then
      return session.branch
    end
    local read = name and session.reported_branches[name]
    if read and (read.tip ~= nil or read.failure ~= nil) then
      return read
    end
    return nil
  end

  --- Reads the files of the local branch shown alone: those that differ
  --- between its base and its tip, as the commits window last read them,
  --- committed files only. Calls `done(failure, changes)`; with the branch not
  --- read yet, with no change and no failure, which the window shows as still
  --- reading; after a first read that failed, with that failure.
  ---
  ---@param done fun(failure: aineo.git.Failure|nil, changes: aineo.git.Change[]|nil)
  local function read_branch_files(done)
    local read = branch_named(session.selected.branch)
    if not read then
      done(nil, nil)
    elseif not read.tip then
      done(branch.unreadable(read), nil)
    else
      git.files_between(session.repository, read.base, read.tip, done, session.settings.git)
    end
  end

  --- Reads the files of the selected filter, in the editor's own repository
  --- or in the worktree it belongs to, and calls `done(failure, listing)`: the
  --- listing of the filter asked for, with no files on a failure. The
  --- session's base is the one *Session work* is read from.
  ---
  ---@param base string|nil
  ---@param done fun(failure: aineo.git.Failure|nil, listing: aineo.changes.Listing)
  local function read_selected_files(base, done)
    local selected = session.selected
    if selected.worktree then
      read_worktree_files(selected, done)
      return
    end
    local repository, options = session.repository, session.settings.git
    local function listing_of(failure, changes)
      done(failure, { filter = selected, changes = changes })
    end
    if selected.kind == 'uncommitted' then
      git.uncommitted_files(repository, listing_of, options)
    elseif selected.kind == 'landed' then
      read_landed_files(base, listing_of)
    elseif selected.kind == 'branch' then
      read_branch_files(listing_of)
    elseif selected.kind == 'commit' then
      git.commit_files(repository, selected.commit.id, listing_of, options)
    else
      git.changed_files(repository, base, listing_of, options)
    end
  end

  --- Asks for one read of the selected filter's files (`window_read()`).
  --- A read that fails keeps the files shown when they are those of the
  --- filter read; for another filter, the window lists that filter with no
  --- files, under the failure's line.
  local ask_for_files = window_read({
    read_own = read_selected_files,
    take_own = function(failure, listing)
      local listed = session.listed
      if not failure or not (listed and filter.same(listed.filter, listing.filter)) then
        session.listed = listing
      end
      session.files_failure = failure
    end,
    show = show_files,
  })

  --- Reads the files of the selected filter again, and shows them
  --- (`ask_for_files()`), when asked with `with_own` — the editor's own
  --- files may differ — or, always, when the filter is another worktree's
  --- whole change, which a commit in that worktree changes whatever the
  --- editor's own files do.
  ---
  ---@param with_own boolean
  local function read_files(with_own)
    ask_for_files(with_own or session.selected.kind == 'worktree')
  end

  --- Selects `selected`, the commits window's cursor to be put on its line
  --- (`place_commits_cursor()`). While the commit graph is shown, whose
  --- cursor chooses, it is selected once `t` shows the sections again, in
  --- place of what was selected before the graph.
  ---
  ---@param selected aineo.changes.Filter
  local function select_filter(selected)
    if session.graph_shown then
      session.selected_before_graph = selected
      return
    end
    session.selected = selected
    session.cursor_unplaced = true
  end

  --- Selects *Session work* again, the commits window's cursor to be put on
  --- its line (`place_commits_cursor()`).
  local function select_session_work()
    select_filter(filter.SESSION_WORK)
  end

  --- Selects what the commits window's view chooses when nothing else
  --- does — a commits buffer made anew, a session followed with a scope
  --- kept: the whole change of the worktree or branch shown alone, in the
  --- focused view (`scope_shown()`); else *Session work*
  --- (`select_session_work()`).
  local function select_view_default()
    local shown = scope_shown()
    if shown then
      select_filter(scope.whole_change_of(shown[1]))
    else
      select_session_work()
    end
  end

  --- Whether `commits`, as last read, still list the commit `selected` names.
  ---
  ---@param selected aineo.changes.Filter a `commit` filter
  ---@param commits aineo.git.Commit[]
  ---@return boolean
  local function lists_commit(selected, commits)
    return vim.iter(commits):any(function(commit)
      return commit.id == selected.commit.id
    end)
  end

  --- Keeps the scope, when it is a worktree's, as `others`, what the commits
  --- window now knows of the other worktrees, lists its worktree, or, when it
  --- lists it no more, clears the scope with the focused view and tells the
  --- user, once, that the worktree is gone (`aineo.changes.scope`) — but
  --- while the reported work is the focused view, which stays, the scope
  --- behind it is cleared untold. A branch's scope is kept by what is read
  --- of the branch (`take_branch()`).
  ---
  ---@param others aineo.changes.OtherWorktrees
  local function keep_scope_listed_in(others)
    if not (session.scope and session.scope.top) then
      return
    end
    local still_listed, gone = scope.after_read(session.scope, others)
    session.scope = still_listed
    if gone and not session.shows_reported then
      session.focused = false
      vim.notify(gone, vim.log.levels.INFO)
    end
  end

  --- Offers what `s` offers, when `s` was pressed before the other worktrees
  --- were read (`home.offer_scopes()`); does nothing otherwise. Defined
  --- with `home.offer_scopes()`.
  ---@type fun()
  local offer_once_read

  --- Selects again, and reads the files window for it, what the selection
  --- comes to when `others`, what the commits window now knows of the other
  --- worktrees, no longer lists what it names: *Session work* when the
  --- selected filter's worktree is gone; that worktree's whole change when it
  --- lists the worktree but not the selected commit any more — after an
  --- amend, a rebase. A worktree still listed becomes the selected filter's
  --- as it was last read, and the files window is written again when its
  --- branch changed, for its first line names it. The scope is kept or
  --- cleared first (`keep_scope_listed_in()`).
  ---
  ---@param others aineo.changes.OtherWorktrees
  local function reselect_in_worktrees(others)
    keep_scope_listed_in(others)
    local selected = session.selected
    if not selected.worktree then
      return
    end
    local section = vim.iter(others.sections):find(function(listed)
      return listed.top == selected.worktree.top
    end)
    if not section then
      select_session_work()
      read_files(true)
    elseif
      selected.kind == 'commit'
      and section.listed
      and not lists_commit(selected, section.listed.commits)
    then
      select_filter(filter.of_worktree(section))
      read_files(true)
    else
      session.selected = filter.in_worktree(selected, section)
      if section.branch ~= selected.worktree.branch then
        show_files()
      end
    end
  end

  --- Keeps `read`, what the commits window read of the local branch shown
  --- alone, unless the scope is no longer that branch's. A branch that names
  --- no commit is gone: the scope is cleared with the focused view and what
  --- was kept of the branch, *Session work* is selected again when the
  --- selection was the branch's, and the user is told once
  --- (`aineo.changes.scope`) — but while the reported work is the focused
  --- view, which stays, the scope behind it is cleared untold. Otherwise,
  --- when the selection is a commit of the
  --- branch it no longer lists — the branch was reset or rebased — the
  --- branch's whole change is selected; and the files window is read again
  --- when the whole change is selected and the tip or the base moved, the
  --- first read included.
  ---
  ---@param read aineo.changes.BranchSection
  local function take_branch(read)
    local current = session.scope
    if not (current and current.branch == read.name) then
      return
    end
    if read.names_no_commit then
      session.scope, session.branch = nil, nil
      if session.shows_reported then
        return
      end
      session.focused = false
      if session.selected.branch then
        select_session_work()
        read_files(true)
      end
      vim.notify(scope.gone(current), vim.log.levels.INFO)
      return
    end
    local before = session.branch
    session.branch = read
    local selected = session.selected
    if selected.kind == 'commit' and selected.branch and read.commits then
      if not lists_commit(selected, read.commits) then
        select_filter(filter.of_branch(read.name))
        read_files(true)
      end
    elseif selected.kind == 'branch' then
      if not (before and before.tip == read.tip and before.base == read.base) then
        read_files(true)
      end
    end
  end

  --- Reads the local branch the scope names, when it names one
  --- (`aineo.changes.branch`), keeps what it read (`take_branch()`), and
  --- calls `done(true)`; calls `done(false)` at once for any other scope or
  --- none. The branch is read at every read of the commits window, shown
  --- alone or not, so that a branch deleted behind the default view is
  --- noticed too.
  ---
  ---@param done fun(read: boolean)
  local function read_branch_scope(done)
    local current = session.scope
    if not (current and current.branch) then
      done(false)
      return
    end
    branch.read({
      found = session.repository,
      name = current.branch,
      before = session.branch,
      base = reported_base_of_branch(current.branch),
      working_branch = session.settings.working_branch,
      git = session.settings.git,
    }, function(read)
      take_branch(read)
      done(true)
    end)
  end

  --- Reads, one after another, each reported branch no reported worktree
  --- has checked out (`reports.work_of()`, `aineo.changes.branch`) and keeps
  --- what was read of it, by name, letting go what was read of a branch no
  --- longer among them; then calls `done(read)`, whether there was any to
  --- read.
  ---
  ---@param done fun(read: boolean)
  local function read_reported_branches(done)
    local names = {}
    for _, pick in ipairs(reports.work_of(session.nodes, own_top())) do
      if pick.branch then
        table.insert(names, pick.branch)
      end
    end
    local kept_reads = {}
    for _, name in ipairs(names) do
      kept_reads[name] = session.reported_branches[name]
    end
    session.reported_branches = kept_reads
    local function read_from(index)
      local name = names[index]
      if not name then
        done(#names > 0)
        return
      end
      local before = session.reported_branches[name] or { name = name }
      branch.read({
        found = session.repository,
        name = name,
        before = before,
        base = reported_base_of_branch(name),
        working_branch = session.settings.working_branch,
        git = session.settings.git,
      }, function(read)
        session.reported_branches[name] = read
        local selected = session.selected
        local moved = not (before.tip == read.tip and before.base == read.base)
        if selected.kind == 'branch' and selected.branch == read.name and moved then
          read_files(true)
        end
        read_from(index + 1)
      end)
    end
    read_from(1)
  end

  --- Keeps `kept_reads`, what was read of the commits the Reported section
  --- lists below its branches' lines. A commit of a branch that the files
  --- window lists and the default view no longer lists — the branch moved,
  --- was reset or rebased — gives way to *Session work*, and the files
  --- window is read for it, unless the focused view or the commit graph
  --- shows. Returns whether what was kept differs from what the window
  --- listed.
  ---
  ---@param kept_reads table<string, aineo.git.Commit[]>
  ---@return boolean changed
  local function take_tree_commits(kept_reads)
    local changed = not vim.deep_equal(session.tree_commits, kept_reads)
    session.tree_commits = kept_reads
    local selected = session.selected
    if
      selected.kind == 'commit'
      and selected.branch
      and not session.graph_shown
      and not scope_shown()
      and not scope.page_lists(commits_page(), selected)
    then
      select_session_work()
      read_files(true)
    end
    return changed
  end

  --- Reads the commits the Reported section lists below the lines of the
  --- branches the pane has read the work of (`tree_commits.wanted()`), off
  --- the main loop, keeps them (`take_tree_commits()`) unless the session
  --- ended meanwhile, and calls `done(changed)`: whether they differ from
  --- what the window listed.
  ---
  ---@param done fun(changed: boolean)
  local function read_tree_commits(done)
    local reading = session
    if not reading.repository then
      done(false)
      return
    end
    tree_commits.read(
      { found = reading.repository, git = reading.settings.git },
      tree_commits.wanted(reported_lines()),
      function(kept_reads)
        done(session == reading and take_tree_commits(kept_reads))
      end
    )
  end

  --- Reads what reports are matched against and matches them; made below,
  --- as it adds what it matches to the Reported section and reads the commits
  --- window again for it.
  ---@type fun(done?: fun())
  local read_reported

  --- What the commits window reads after the other worktrees: the branch
  --- the scope names (`read_branch_scope()`), then the reported
  --- branches (`read_reported_branches()`), then, while a report waits or
  --- the Reported section holds a worktree, what reports are matched
  --- against (`read_reported()`); calls `done(read)`, whether any of these
  --- read anything the window shows.
  ---
  ---@param done fun(read: boolean)
  local function read_scope_and_reported(done)
    read_branch_scope(function(read_pick)
      read_reported_branches(function(read_reported_any)
        read_tree_commits(function(read_tree_commits_any)
          if #session.waiting == 0 and #session.nodes == 0 then
            done(read_pick or read_reported_any or read_tree_commits_any)
            return
          end
          read_reported(function()
            done(true)
          end)
        end)
      end)
    end)
  end

  --- Whether `read`, what the commits window read of the working branch,
  --- still lists what `selected`, a filter of what landed, names: the heading
  --- while there is a working branch, a commit while it is among the
  --- commits that landed.
  ---
  ---@param selected aineo.changes.Filter a filter with a `landed`
  ---@param read aineo.changes.Landed|nil
  ---@return boolean
  local function lists_landed(selected, read)
    if not read then
      return false
    end
    return selected.kind == 'landed' or lists_commit(selected, read.commits or {})
  end

  --- Keeps `read`, what the commits window read of the working branch. When it
  --- no longer lists what the selected filter of what landed names — a
  --- working branch reset or pushed over, or none any more — *Session work* is
  --- selected again, and the files window read for it; when the heading is
  --- selected and the working branch is another one or names another commit
  --- than before, the heading selected is that branch's, and the files window
  --- is read again.
  ---
  ---@param read aineo.changes.Landed|nil
  local function take_landed(read)
    local tip_before = session.landed and session.landed.tip
    local selected = session.selected
    session.landed = read
    if selected.landed and not lists_landed(selected, read) then
      select_session_work()
      read_files(true)
    elseif
      selected.kind == 'landed' and (read.name ~= selected.landed or read.tip ~= tip_before)
    then
      session.selected = filter.of_landed(read.name)
      read_files(true)
    end
  end

  --- How many reads of what landed in the working branch were started
  --- (`read_landed()`).
  local landed_reads = 0

  --- Reads what landed in the working branch since `base`
  --- (`aineo.changes.landed`) beside the read of the commits that asked for
  --- it, and shows it (`take_landed()`, `show_commits()`) once the answer
  --- comes and differs from what the window knew, unless a later read was
  --- started or the session has another base by then (`is_current_base()`).
  --- A read that fails keeps what landed as it was, with the failure, which the
  --- commits window tells under the Landed heading.
  ---
  ---@param base string|nil
  local function read_landed(base)
    landed_reads = landed_reads + 1
    local this_read = landed_reads
    landed.read({
      repository = session.repository,
      base = base,
      working_branch = session.settings.working_branch,
      before = session.landed,
      git = session.settings.git,
    }, function(read)
      if this_read ~= landed_reads or not is_current_base(base) then
        return
      end
      local unchanged = vim.deep_equal(session.landed, read)
      take_landed(read)
      if not unchanged then
        show_commits()
      end
    end)
  end

  --- Reads the commits since the base, and those of each other worktree
  --- since its own, and shows them (`window_read()`), with what landed in the
  --- working branch read beside them (`read_landed()`). When the editor's own
  --- commit the files window lists is no longer among the commits — after a
  --- reset, a rebase — *Session work* is selected again, and the files window
  --- read for it; when it is another worktree's, or that worktree is, see
  --- `reselect_in_worktrees()`. The local branch the scope names, when it
  --- names one, and the reported branches, are read after the
  --- worktrees, and the reports matched again (`read_scope_and_reported()`).
  --- Once the other worktrees are read, the list `s` asked for before they
  --- were is offered (`offer_once_read()`).
  local read_commits = window_read({
    read_own = function(base, done)
      read_landed(base)
      git.commits_since(session.repository, base, done, session.settings.git)
    end,
    take_own = function(failure, since)
      session.commits = since or session.commits
      session.commits_failure = failure
      if
        since
        and session.selected.kind == 'commit'
        and not session.selected.worktree
        and not session.selected.landed
        and not session.selected.branch
        and not session.selected.graph
        and not lists_commit(session.selected, since.commits)
      then
        select_session_work()
        read_files(true)
      end
    end,
    read_list = function(repository, base, done)
      git.commits_since(repository, base, done, session.settings.git)
    end,
    others_field = 'commits_others',
    took_others = function(others)
      reselect_in_worktrees(others)
      offer_once_read()
    end,
    read_scope = read_scope_and_reported,
    show = show_commits,
  })

  --- Reads the commit graph (`aineo.git`'s `commit_graph()`), of as many
  --- commits as the session's settings say, one read at a time
  --- (`aineo.changes.serial`), while the commits window shows it, and shows
  --- it (`show_commits()`) once git answers, unless the graph is no longer
  --- shown by then. A read that fails keeps the graph last read, with the
  --- failure, which the window tells above it.
  local read_graph = serial.one_at_a_time(function(ended)
    if not (session.graph_shown and session.repository) then
      ended()
      return
    end
    local limit = session.settings.graph_limit or DEFAULT_GRAPH_LIMIT
    git.commit_graph(session.repository, limit, function(failure, drawn)
      ended()
      session.graph = drawn or session.graph
      session.graph_failure = failure
      if session.graph_shown then
        show_commits()
      end
    end, session.settings.git)
  end)

  --- Reads again what `change`, a call of the watch, may have changed: the
  --- other worktrees' commits at every call, as a commit in one of them
  --- moves no branch of the editor's, and their files when the files window
  --- lists one's whole change; the editor's own files when they may differ,
  --- and its commits and files when its branch moved; the editor's own
  --- commits and what landed in the working branch when a reference was
  --- written, as a fetch does; and the commit graph, while it is shown, when
  --- the branch moved or a reference was written (`read_graph()`).
  ---
  ---@param change aineo.git.RepositoryChange
  local function follow_change(change)
    read_files(change.files_changed or change.branch_moved)
    read_commits(change.branch_moved or change.references_changed)
    if change.branch_moved or change.references_changed then
      read_graph()
    end
  end

  --- Tells both windows that `failure` stopped the watch, under the lists
  --- they show; the watch, which may see nothing more, is stopped, to be
  --- started again the next time the pane is shown.
  ---
  ---@param failure aineo.git.Failure
  local function watch_failed(failure)
    if session.watch then
      session.watch.stop()
      session.watch = nil
    end
    session.watch_failure = failure
    show_files()
    show_commits()
  end

  --- Starts watching the session's repository: each call reads again what it
  --- may have changed (`follow_change()`), and a failure stops it
  --- (`watch_failed()`), as one that cannot start is told.
  local function watch()
    local started, failure = git.watch_repository(
      session.repository,
      function(change_failure, change)
        if change_failure then
          watch_failed(change_failure)
        else
          follow_change(change)
        end
      end,
      session.settings.git
    )
    session.watch = started
    if failure then
      watch_failed(failure)
    else
      session.watch_failure = nil
    end
  end

  --- Whether the home has been let go (`home.let_go()`): nothing follows its
  --- repository any more.
  local released = false

  --- Starts what follows the repository once the pane has been shown: the
  --- watch, when none runs, and a read of each list, the commit graph's
  --- while it is shown (`read_graph()`); does nothing before the
  --- repository is found or the pane first shown, nor once the home has been
  --- let go, nor once the editor is quitting (`v:exiting`): a look answered
  --- then, while a later `VimLeavePre` waits, starts no watch and no read
  --- after the quit has stopped the watch.
  local function follow_repository()
    if not (session.repository and session.shown) or released or vim.v.exiting ~= vim.NIL then
      return
    end
    if not session.watch then
      watch()
    end
    read_files(true)
    read_commits(true)
    read_graph()
  end

  --- `path` with every symbolic link it leads through resolved, or as it is
  --- when it cannot be resolved.
  ---
  ---@param path string
  ---@return string
  local function resolved(path)
    return vim.uv.fs_realpath(path) or path
  end

  --- Adds to the session's saves those of `on_disk`, what is kept for the
  --- Claude Code session the pane follows, when it was kept for this
  --- repository and this base: another editor following the same session
  --- marked them.
  ---
  ---@param on_disk aineo.changes.KeptBase|nil
  local function merge_kept_saves(on_disk)
    if not (on_disk and on_disk.top == session.repository.top and on_disk.base == session.base) then
      return
    end
    for _, path in ipairs(on_disk.saved) do
      session.saved[path] = true
    end
  end

  --- Reads both lists again for the session's new base, from nothing: until
  --- they are read, each window says aineo is reading the repository, and
  --- the commits window lists nothing of what landed in the working branch,
  --- which it counts from the base.
  local function read_for_new_base()
    session.listed, session.files_failure = nil, nil
    session.commits, session.commits_failure = nil, nil
    session.landed = nil
    show_files()
    show_commits()
    follow_repository()
  end

  --- Whether the user was told that a session's base and saves could not be
  --- kept (`tell_keeping_failure()`).
  local keeping_failure_told = false

  --- Tells the user, as a warning, that a session's base and saves could not
  --- be kept, and why: `failure`. Told once for the home's life; the pane
  --- goes on from what it holds.
  ---
  ---@param failure string
  local function tell_keeping_failure(failure)
    if keeping_failure_told then
      return
    end
    keeping_failure_told = true
    vim.notify(
      ("aineo: the changes pane cannot keep this session's base and saves, and goes on without: %s"):format(
        failure
      ),
      vim.log.levels.WARN
    )
  end

  --- Writes the session's base and saves for `followed`, the Claude Code
  --- session the pane follows (`aineo.changes.kept`). A write that fails is
  --- told once (`tell_keeping_failure()`).
  ---
  ---@param followed aineo.changes.FollowedSession
  local function write_kept_base(followed)
    local saved = vim.tbl_keys(session.saved)
    table.sort(saved)
    local failure = kept.keep_base(
      followed.state_directory,
      followed.id,
      { top = session.repository.top, base = session.base, saved = saved }
    )
    session.keeping_failed = failure ~= nil
    if failure then
      tell_keeping_failure(failure)
    end
  end

  --- Keeps the session's base and saves for the Claude Code session the pane
  --- follows (`write_kept_base()`), with what another editor kept for it in
  --- this repository meanwhile: its saves (`merge_kept_saves()`), and its
  --- base when it differs — the first base kept for a session wins, and both
  --- lists are read again for it (`read_for_new_base()`). Keeps nothing
  --- before it follows one, while git looks for the session's base
  --- (`take_head()`), or when what was kept for the session is another
  --- repository's or cannot be read as the pane began following it
  --- (`use_kept_base()`), or is another repository's now, as it reads what is
  --- kept before writing: the session is then never kept again in this
  --- editor. What is kept that cannot be read now is not written over, and
  --- counts as a failed write: it is tried again at the next save, and as
  --- the session is followed again.
  local function keep()
    local followed = session.followed
    if not (followed and session.keeps_followed) or session.looking_for_head then
      return
    end
    local on_disk, unreadable = kept.read_kept_base(followed.state_directory, followed.id)
    if unreadable then
      session.keeping_failed = true
      return
    end
    if on_disk and on_disk.top ~= session.repository.top then
      session.keeps_followed = false
      return
    end
    local rebased = on_disk ~= nil and on_disk.base ~= session.base
    if rebased then
      session.base = on_disk.base
    end
    merge_kept_saves(on_disk)
    write_kept_base(followed)
    if rebased then
      read_for_new_base()
    end
  end

  --- `paths` as a set.
  ---
  ---@param paths string[]
  ---@return table<string, true>
  local function set_of(paths)
    local set = {}
    for _, path in ipairs(paths) do
      set[path] = true
    end
    return set
  end

  --- Takes the base and the saves kept for the Claude Code session the pane
  --- follows (`aineo.changes.kept`), when they were kept for this
  --- repository, and returns whether it did. Otherwise the saves are none
  --- from then on, and are kept (`keep()`) only when nothing was kept for the
  --- session: what was kept for another repository, or what cannot be read
  --- and may be, is never written over.
  ---
  ---@return boolean
  local function use_kept_base()
    local followed = session.followed
    local kept_base, unreadable = nil, false
    if followed then
      kept_base, unreadable = kept.read_kept_base(followed.state_directory, followed.id)
    end
    session.keeps_followed = not unreadable
      and (not kept_base or kept_base.top == session.repository.top)
    if not (kept_base and session.keeps_followed) then
      session.saved = {}
      return false
    end
    session.base = kept_base.base
    session.saved = set_of(kept_base.saved)
    return true
  end

  --- Holds the base and the saves of the Claude Code session the pane
  --- follows, as it leaves it, when they could not be kept for it — what was
  --- kept for it is another repository's, or its last write failed
  --- (`held_bases`) — and lets go of what was held for it once they were.
  --- Does nothing while git still looks for its base.
  local function hold_unkept_base()
    local leaving = session.followed
    if not (leaving and session.repository) or session.looking_for_head then
      return
    end
    if session.keeps_followed == false or session.keeping_failed then
      held_bases[leaving.id] =
        { base = session.base, saved = session.saved, keeps = session.keeps_followed }
    else
      held_bases[leaving.id] = nil
    end
  end

  --- Takes the base and the saves held for the Claude Code session the pane
  --- follows (`hold_unkept_base()`), when they are, and returns whether it
  --- did. A session held because its write failed, or was refused over what
  --- could not be read, is written again at once (`keep()`), with the saves
  --- another editor kept for it since, and at each save until a write
  --- succeeds; one held because what was kept for it is another
  --- repository's, or could not be read as the pane began following it,
  --- never is.
  ---
  ---@return boolean
  local function use_held_base()
    local held = held_bases[session.followed.id]
    if not held then
      return false
    end
    session.base, session.saved = held.base, held.saved
    session.keeps_followed = held.keeps
    keep()
    return true
  end

  --- Marks `file`, a written file's resolved path, as saved when it lies
  --- under the repository's top level, resolved too, keeps the marks when
  --- this one is new or the last write of them failed (`keep()`), and
  --- returns whether it lies there.
  ---
  ---@param file string
  ---@return boolean
  local function mark_saved(file)
    local top = resolved(session.repository.top) .. '/'
    if not vim.startswith(file, top) then
      return false
    end
    local path = file:sub(#top + 1)
    if not session.saved[path] or session.keeping_failed then
      session.saved[path] = true
      keep()
    end
    return true
  end

  --- Whether the pane shows the default view and has picked and reported
  --- nothing.
  ---
  ---@return boolean
  local function has_no_view()
    return session.scope == nil
      and not session.focused
      and not session.shows_reported
      and #session.nodes == 0
  end

  --- Begins keeping the view for the Claude Code session the pane follows,
  --- once it follows one in a repository it found. When a view was kept for
  --- the session in this repository and the pane has picked and reported
  --- nothing since, the pane shows it as git now allows it
  --- (`scope.restored_view()`), telling nothing of what is gone, once the
  --- worktrees and branches are read; until then nothing is kept. A view
  --- that is missing, malformed, another repository's, or cannot be read
  --- back, leaves the pane as it is, and the view kept is written over once
  --- the view changes.
  local function begin_view()
    local followed = session.followed
    if not (followed and session.repository) then
      return
    end
    local repository = session.repository.top
    local current = { focused = false, shows_reported = false, nodes = {} }
    session.kept_view = scope.kept_view_of(repository, current)
    local on_disk = kept.read_kept_view(followed.state_directory, followed.id)
    if not (on_disk and on_disk.repository == repository and has_no_view()) then
      return
    end
    session.kept_view, session.restoring_view = on_disk, true
    branch.read_candidates({
      repository = session.repository,
      working_branch = session.settings.working_branch,
      git = session.settings.git,
    }, function(_, candidates)
      if released or session.followed ~= followed then
        return
      end
      session.restoring_view = false
      if not candidates or not has_no_view() then
        session.kept_view = scope.kept_view_of(repository, current)
        keep_view()
        return
      end
      local restored = scope.restored_view(on_disk, candidates, repository)
      session.scope, session.focused = restored.scope, restored.focused
      session.nodes, session.shows_reported = restored.nodes, restored.shows_reported
      if restored.selected then
        select_filter(restored.selected)
        read_files(true)
      end
      show_commits()
      if session.shown then
        read_commits(false)
      end
    end)
  end

  --- Looks for the repository of the session's directory, one look at a time
  --- (`aineo.changes.serial`). The first found is the session's for the
  --- editor's life: its `HEAD` is the base — or the base kept for the Claude
  --- Code session the pane follows, when one was kept for this repository
  --- (`use_kept_base()`), `HEAD` being kept for it when nothing was — the saves
  --- count from then — those made while the first look ran included — and it
  --- is followed once the pane has been shown (`follow_repository()`), and
  --- the reports made before it was found are matched against it
  --- (`read_reported()`). While none is found, both windows say why. Each
  --- look is ended before what it found is followed and shown.
  local find = serial.one_at_a_time(function(ended)
    git.find_repository(session.settings.directory, function(failure, repository)
      if session.repository then
        ended()
        return
      end
      session.absence = failure
      if repository then
        session.repository = repository
        if not use_kept_base() then
          session.base = repository.head
          keep()
        end
        begin_view()
        for _, file in ipairs(session.early_saves) do
          mark_saved(file)
        end
      end
      session.early_saves = {}
      ended()
      follow_repository()
      if repository and #session.waiting > 0 then
        read_reported()
      end
      show_files()
      show_commits()
    end, session.settings.git)
  end)

  --- Looks for the repository again (`find`) when none was found.
  local function look_again()
    if session.absence then
      find()
    end
  end

  --- The Claude Code session the changes pane is for, as the composition
  --- root tells it.
  ---@class aineo.changes.FollowedSession
  ---@field id string Claude Code's session id
  ---@field state_directory string the editor's state directory, `stdpath('state')`, under which the session's base and saves are kept

  --- Takes `HEAD` now, looked for from the session's repository's top level
  --- — not from the directory `begin_session()` was given, which may since
  --- hold a repository of its own, or be gone — as the base of the Claude
  --- Code session the pane follows, and keeps it (`keep()`). No list is read
  --- while git looks. When the look fails, both windows say why, and the
  --- next showing of the pane looks again (`pane_shown()`).
  local function take_head()
    local followed = session.followed
    session.looking_for_head = true
    session.head_look_failed = false
    read_for_new_base()
    git.find_repository(session.repository.top, function(failure, repository)
      if session.followed ~= followed then
        return
      end
      if failure then
        session.head_look_failed = true
        session.files_failure, session.commits_failure = failure, failure
        show_files()
        show_commits()
        return
      end
      session.looking_for_head = false
      session.base = repository.head
      keep()
      read_for_new_base()
    end, session.settings.git)
  end

  --- Looks for `HEAD` again when the last look for the base of the session
  --- followed failed (`take_head()`).
  local function take_head_again()
    if session.head_look_failed then
      take_head()
    end
  end

  --- Notes that the pane is shown, and, at the main loop's next turn, follows
  --- the repository from then on (`follow_repository()`), or looks for it
  --- again while there is none (`look_again()`), and looks again for the
  --- base of the Claude Code session followed when its last look failed
  --- (`take_head_again()`): once for every showing in one turn, as both of
  --- the pane's buffers entering their windows are one showing. Once the
  --- editor is quitting (`v:exiting`) when that turn comes, it does none of
  --- these: no look for the repository starts as the editor quits.
  local function pane_shown()
    if not session then
      return
    end
    session.shown = true
    if session.following_soon then
      return
    end
    session.following_soon = true
    vim.schedule(function()
      session.following_soon = false
      if vim.v.exiting ~= vim.NIL then
        return
      end
      look_again()
      take_head_again()
      follow_repository()
    end)
  end

  --- Marks the file a save wrote, `written`, when it lies under the
  --- repository's top level, both resolved — a file opened through a
  --- symbolic link to the repository counts (`mark_saved()`) — and reads the
  --- files again once the pane has been shown, whether the watch saw the save
  --- or not. A save made while the first look for the repository runs is
  --- marked once it is found (`find`). While no repository was found, the
  --- save marks nothing and aineo looks for one again (`look_again()`).
  ---
  ---@param written string the written file's absolute path, as it was opened
  local function note_save(written)
    if session.absence then
      look_again()
    elseif not session.repository then
      table.insert(session.early_saves, resolved(written))
    elseif mark_saved(resolved(written)) and session.shown then
      read_files(true)
    end
  end

  --- Begins the session for `settings.directory`: finds its repository, whose
  --- `HEAD` is the session's base until the home follows a Claude Code
  --- session (`follow_changes_session()`), and marks the files the user
  --- saves from then on (`note_save()`). The session lasts the home's
  --- life: once begun, a call does nothing, as a restart of Claude Code calls
  --- it again.
  ---
  ---@param settings aineo.changes.SessionSettings
  function home.begin_session(settings)
    if session then
      return
    end
    session = {
      settings = settings,
      followed = followed_before_beginning,
      selected = filter.SESSION_WORK,
      cursor_unplaced = true,
      shown = false,
      following_soon = false,
      saved = {},
      early_saves = {},
      commits_others = worktrees.NONE,
      focused = false,
      nodes = {},
      reported_branches = {},
      tree_commits = {},
      shows_reported = false,
      waiting = {},
      graph_shown = false,
      graph_cursor_unplaced = false,
    }
    local group = vim.api.nvim_create_augroup(own_group('aineo_changes'), {})
    vim.api.nvim_create_autocmd({ 'BufWritePost', 'FileWritePost', 'FileAppendPost' }, {
      group = group,
      desc = 'aineo: mark a file saved in the changes pane',
      callback = function(event)
        note_save(event.match)
      end,
    })
    vim.api.nvim_create_autocmd('VimLeavePre', {
      group = group,
      desc = "aineo: stop watching the changes pane's repository",
      callback = function()
        if session.watch then
          session.watch.stop()
        end
      end,
    })
    find()
  end

  --- Drops every report still waiting, untold, each with its timer stopped.
  local function drop_waiting()
    for _, waiting in ipairs(session.waiting) do
      waiting.stop_timer()
    end
    session.waiting = {}
  end

  --- Makes the changes pane the Claude Code session `followed`'s, its
  --- buffers written for it and its lists read again: the base and the saves
  --- this editor held for it, when it followed it before and could not keep
  --- them (`use_held_base()`); else those kept for it in this repository,
  --- read back; else, for a session with nothing kept, `HEAD` at this moment
  --- in the session's repository and no saves, both kept from then on
  --- (`take_head()`) — unless another editor keeps a base for it first, which
  --- the pane then takes (`keep()`); else — what was kept for it is another
  --- repository's, or cannot be read — `HEAD` and no saves too, held in
  --- memory for the home's life, what was kept left as it was. Following the session
  --- already followed does nothing. Told before the session has begun, or
  --- before its repository is found, the home holds the session and takes
  --- its base once the repository is found (`find`); while no repository is
  --- found, nothing is kept. The home keeps a copy of `followed`, whose id a
  --- hand-over renames (`hand_over_changes_session()`), and never changes
  --- the table it is given. Following another session than one followed
  --- before clears the scope and empties the Reported section, the reports
  --- still waiting dropped (`drop_waiting()`), and says nothing; the first
  --- session followed keeps the scope picked before it. The view kept for the
  --- session followed, in the repository found, is shown again once read
  --- (`begin_view()`), and kept from then on as it changes (`keep_view()`).
  --- Called on the main loop only: from a fast event (a `vim.uv` callback) it
  --- raises E5560, as the Vimscript functions it calls do there.
  ---
  ---@param followed aineo.changes.FollowedSession
  function home.follow_changes_session(followed)
    followed = { id = followed.id, state_directory = followed.state_directory }
    if not session then
      followed_before_beginning = followed
      return
    end
    if session.followed and session.followed.id == followed.id then
      return
    end
    hold_unkept_base()
    if session.followed then
      session.scope, session.focused, session.branch = nil, false, nil
      session.nodes, session.reported_branches, session.tree_commits = {}, {}, {}
      session.shows_reported, session.shown_label = false, nil
      drop_waiting()
    end
    session.followed = followed
    session.kept_view, session.restoring_view = nil, false
    select_view_default()
    session.looking_for_head, session.head_look_failed, session.keeping_failed = false, false, false
    if not session.repository then
      return
    end
    begin_view()
    if use_held_base() or use_kept_base() then
      read_for_new_base()
      return
    end
    take_head()
  end

  --- A hand-over, as the composition root tells it.
  ---@class aineo.changes.HandOver
  ---@field from string the Claude Code session id Claude Code found no conversation for
  ---@field to string the Claude Code session id that took its place
  ---@field state_directory string the editor's state directory, `stdpath('state')`, under which the sessions' bases and saves are kept

  --- Hands the base and the saves of the Claude Code session `hand_over.from`,
  --- which Claude Code found no conversation for, over to `hand_over.to`,
  --- which took its place, under `hand_over.state_directory`.
  ---
  --- When the pane follows `from`, its base and saves are kept for `from`
  --- first (`keep()`), a write that failed before included. Then, when `to`
  --- has nothing kept of its own, what is kept for `from` becomes `to`'s,
  --- whole and unread, whatever repository it names — a file that cannot be
  --- read included, which `to` then meets as `from` would have — and no file
  --- is left under `from`'s name (`aineo.changes.kept`'s `move_kept_base()`);
  --- the view kept for `from` moves to `to` the same way (`move_kept_view()`).
  --- Nothing is made when neither has a file. What this editor holds in
  --- memory for `from` (`held_bases`) is held for `to`. When `to` has a file
  --- of its own, nothing moves, and the pane goes on following `from`.
  ---
  --- A pane that follows `from`, or was told it before the session began,
  --- follows `to` from then on, with no swap and no list read again: its
  --- base, its `*` marks and its lists stay, its next new mark is kept for
  --- `to`, a look for `HEAD` under way completes for `to`, and a later follow
  --- of `to` changes nothing. A pane that follows another session only has
  --- the file moved.
  ---
  --- A move that fails is told to the user as a warning, as a failed keep is,
  --- once for the home's life, and nothing is raised for it.
  ---
  --- Raises an error naming the field when `hand_over` is not a hand-over.
  ---
  ---@param hand_over aineo.changes.HandOver
  function home.hand_over_changes_session(hand_over)
    vim.validate('hand_over', hand_over, 'table')
    vim.validate('hand_over.from', hand_over.from, 'string')
    vim.validate('hand_over.to', hand_over.to, 'string')
    vim.validate('hand_over.state_directory', hand_over.state_directory, 'string')
    local followed = followed_before_beginning
    if session then
      followed = session.followed
    end
    local follows_from = followed ~= nil and followed.id == hand_over.from
    if follows_from and session then
      keep()
    end
    if vim.uv.fs_lstat(kept.kept_base_file(hand_over.state_directory, hand_over.to)) then
      return
    end
    local failure = kept.move_kept_base(hand_over.state_directory, hand_over.from, hand_over.to)
    if failure then
      tell_keeping_failure(failure)
    end
    local view_failure =
      kept.move_kept_view(hand_over.state_directory, hand_over.from, hand_over.to)
    if view_failure then
      tell_view_failure(view_failure)
    end
    held_bases[hand_over.to], held_bases[hand_over.from] = held_bases[hand_over.from], nil
    if follows_from then
      followed.id = hand_over.to
    end
  end

  --- An entry the user selected, the window whose cursor moves to its diff
  --- once shown (none when the key leaves the cursor in the pane), and the
  --- context the diff was read in.
  ---@class aineo.changes.Selection
  ---@field entry aineo.changes.Entry
  ---@field window integer|nil
  ---@field context aineo.git.DiffContext

  --- What a diff buffer the home showed is the diff of, the context its text
  --- is in, and the context F last asked it to be read in, which is the
  --- context its text will be in once that read arrives.
  ---@class aineo.changes.ShownDiff
  ---@field entry aineo.changes.Entry
  ---@field context aineo.git.DiffContext
  ---@field asked aineo.git.DiffContext

  --- The diff each buffer the home showed holds, by buffer.
  ---@type table<integer, aineo.changes.ShownDiff>
  local shown_diffs = {}

  --- Where the diff of `entry` is read from now, in the context the diffs
  --- are read in now (`aineo.changes.full_context`): the branch it is listed
  --- under, when it is, as the commits window last read it
  --- (`branch_named()`).
  ---
  ---@param entry aineo.changes.Entry
  ---@return aineo.changes.DiffSource
  local function diff_source(entry)
    return {
      repository = session.repository,
      base = session.base,
      landed = session.landed,
      branch = branch_named(entry.filter and entry.filter.branch),
      options = session.settings.git,
      context = full_context.current(),
    }
  end

  --- Tells the user, once, that the diff of `entry` could not be read.
  ---
  ---@param entry aineo.changes.Entry
  ---@param failure aineo.git.Failure
  local function tell_diff_unreadable(entry, failure)
    vim.notify(
      ('aineo: the diff of %s could not be read: %s'):format(
        entry_diff.told_name(entry),
        lines.words_of(failure)
      ),
      vim.log.levels.ERROR
    )
  end

  --- How many times F has asked for a diff to be read again (`reread_diff()`).
  local rereads = 0

  --- Writes `diff`, the text git printed for `entry` in `context` for the
  --- re-read numbered `this_reread`, into `buffer`, the buffer that showed the
  --- entry's diff, while that re-read is the last and the buffer exists
  --- still; then puts the cursor of each window showing the buffer on the line
  --- of the file it was on, or on the first line when the diff no longer shows
  --- that line. A text Neovim refuses for now, as it does while textlock holds,
  --- is written at the editor's next `SafeState`.
  ---
  ---@param this_reread integer
  ---@param buffer integer
  ---@param entry aineo.changes.Entry
  ---@param context aineo.git.DiffContext
  ---@param diff string
  local function write_reread(this_reread, buffer, entry, context, diff)
    if this_reread ~= rereads or not vim.api.nvim_buf_is_valid(buffer) then
      return
    end
    local before = vim.api.nvim_buf_get_lines(buffer, 0, -1, true)
    local cursors = {}
    for _, window in ipairs(vim.fn.win_findbuf(buffer)) do
      local cursor = vim.api.nvim_win_get_cursor(window)
      cursors[window] = { cursor = cursor, position = diff_position.at(before, cursor[1]) }
    end
    if not diffs.diff_buffer(own_name(entry_diff.name(entry)), diff) then
      vim.api.nvim_create_autocmd('SafeState', {
        once = true,
        desc = 'aineo: show the diff F read again once the editor allows it',
        callback = function()
          write_reread(this_reread, buffer, entry, context, diff)
        end,
      })
      return
    end
    shown_diffs[buffer] = { entry = entry, context = context, asked = context }
    local shown = vim.api.nvim_buf_get_lines(buffer, 0, -1, true)
    for window, before_write in pairs(cursors) do
      if vim.api.nvim_win_is_valid(window) and vim.api.nvim_win_get_buf(window) == buffer then
        local row = before_write.position and diff_position.row_of(shown, before_write.position)
          or 1
        local column = math.min(before_write.cursor[2], math.max(#shown[row] - 1, 0))
        vim.api.nvim_win_set_cursor(window, { row, column })
      end
    end
  end

  --- Reads the diff `buffer` shows again in the context other than the one it
  --- was last asked to be read in, and reads the diffs from now on in that
  --- context (`aineo.changes.full_context`); only the last F's read is
  --- written, or its failure told, once, the buffer then asked for the context
  --- its text is in.
  ---
  ---@param buffer integer
  local function reread_diff(buffer)
    local shown = shown_diffs[buffer]
    if not shown or not session then
      return
    end
    local context = full_context.other(shown.asked)
    shown.asked = context
    full_context.use(context)
    rereads = rereads + 1
    local this_reread = rereads
    entry_diff.read(shown.entry, diff_source(shown.entry), function(failure, diff)
      if this_reread ~= rereads then
        return
      end
      if failure then
        shown.asked = shown.context
        tell_diff_unreadable(shown.entry, failure)
        return
      end
      write_reread(this_reread, buffer, shown.entry, context, diff)
    end)
  end

  --- The first window of the current tab page that shows `buffer`, a buffer
  --- of the pane; nil when none does.
  ---
  ---@param buffer integer|nil
  ---@return integer|nil
  local function window_showing(buffer)
    if not (buffer and vim.api.nvim_buf_is_valid(buffer)) then
      return nil
    end
    local current_tab = vim.api.nvim_get_current_tabpage()
    return vim.tbl_filter(function(window)
      return vim.api.nvim_win_get_tabpage(window) == current_tab
    end, vim.fn.win_findbuf(buffer))[1]
  end

  --- Moves the cursor from `buffer`, a diff the home showed, to the files
  --- window, onto the line that lists the file the diff shows, when the files
  --- window still lists it; the window keeps its line otherwise. When the tab
  --- page shows no files window, the settings' `show_changes_pane()` shows
  --- the pane first. Does nothing when there is still none.
  ---
  ---@param buffer integer
  local function move_back_to_files_window(buffer)
    local files = window_showing(buffers.files)
    if not files and session and session.settings.show_changes_pane then
      session.settings.show_changes_pane()
      files = window_showing(buffers.files)
    end
    if not files then
      return
    end
    vim.api.nvim_set_current_win(files)
    local shown = shown_diffs[buffer]
    local line = shown and pages.line_of(buffers.files, shown.entry.key)
    if line then
      vim.api.nvim_win_set_cursor(files, { line, 0 })
    end
  end

  --- Records that `buffer` holds the diff of `entry` read in `context`, and
  --- maps F in it, in Normal mode, to read that diff again in the other context
  --- (`reread_diff()`), and `<BS>` to move back to the files window
  --- (`move_back_to_files_window()`); the buffers of diffs since wiped are
  --- forgotten.
  ---
  ---@param buffer integer
  ---@param entry aineo.changes.Entry
  ---@param context aineo.git.DiffContext
  local function remember_diff(buffer, entry, context)
    for remembered in pairs(shown_diffs) do
      if not vim.api.nvim_buf_is_valid(remembered) then
        shown_diffs[remembered] = nil
      end
    end
    shown_diffs[buffer] = { entry = entry, context = context, asked = context }
    vim.keymap.set('n', 'F', function()
      reread_diff(buffer)
    end, {
      buffer = buffer,
      desc = 'aineo: show this diff with the whole file as context, or with three lines',
    })
    vim.keymap.set('n', '<BS>', function()
      move_back_to_files_window(buffer)
    end, {
      buffer = buffer,
      desc = 'aineo: move back to the files window, onto the line of this diff’s file',
    })
  end

  --- The windows of the current tab page that show a diff the home showed.
  ---
  ---@return integer[]
  local function windows_showing_a_diff()
    return vim.tbl_filter(function(window)
      return shown_diffs[vim.api.nvim_win_get_buf(window)] ~= nil
    end, vim.api.nvim_tabpage_list_wins(0))
  end

  --- Puts the cursor in the window of the current tab page that shows the
  --- files buffer, on the line it was on; nowhere when none does.
  local function return_cursor_to_the_files_window()
    local files = vim.tbl_filter(function(window)
      return vim.api.nvim_win_get_tabpage(window) == vim.api.nvim_get_current_tabpage()
    end, vim.fn.win_findbuf(buffers.files))
    if files[1] then
      vim.api.nvim_set_current_win(files[1])
    end
  end

  --- What the user is told when there is no diff to close.
  local NO_DIFF_TO_CLOSE = 'aineo: no diff to close'

  --- Closes the windows of the current tab page that show a diff the home
  --- showed (`windows_showing_a_diff()`), the diff buffer with each, wiped once
  --- hidden, and no other window; the cursor stays where it was, unless it was
  --- in one of them, and then goes to the files window
  --- (`return_cursor_to_the_files_window()`), when the tab page shows it.
  --- A window that is the only one of its tab page is not closed. Tells the
  --- user, once, when no window was closed.
  function home.close_shown_diff()
    local was_in = vim.api.nvim_get_current_win()
    local closed = vim.tbl_filter(function(window)
      if #vim.api.nvim_tabpage_list_wins(0) == 1 then
        return false
      end
      vim.api.nvim_win_close(window, false)
      return true
    end, windows_showing_a_diff())
    if #closed == 0 then
      vim.notify(NO_DIFF_TO_CLOSE, vim.log.levels.INFO)
    elseif vim.tbl_contains(closed, was_in) then
      return_cursor_to_the_files_window()
    end
  end

  --- Shows `buffer`, a buffer of what git gave (`aineo.changes.diffs`),
  --- through the session's `show_diff`, then moves the cursor to the window
  --- showing it, in the mode the user is in, while the cursor is still in
  --- `pressed_in`, the window the key was pressed in: the move answers that
  --- key, and a user who has gone elsewhere since stays there. A nil
  --- `pressed_in` is a key that leaves the cursor where it is. When the
  --- middle column has no room for it, the buffer is wiped and the user
  --- warned, once; when showing it raises an error, the buffer is wiped and
  --- the user told the error, once; the cursor then stays where it is.
  --- `told` is what the user is told the buffer shows. Returns false, having
  --- told nothing, when Neovim refuses the wipe of a buffer it did not show,
  --- as it does while textlock holds and in the command-line window, where a
  --- window refuses the buffer too (`aineo.changes.scratch`' `wipe()`): the
  --- buffer is then kept, shown nowhere, for the next call to show. Returns
  --- true otherwise.
  ---
  ---@param buffer integer
  ---@param pressed_in integer|nil
  ---@param told string
  ---@return boolean allowed
  local function show_buffer(buffer, pressed_in, told)
    local shown, window = pcall(session.settings.show_diff, buffer)
    if shown and window then
      if pressed_in and vim.api.nvim_get_current_win() == pressed_in then
        vim.api.nvim_set_current_win(window)
      end
      return true
    end
    if not scratch.wipe(buffer) then
      return false
    end
    if not shown then
      vim.notify(
        ('aineo: %s could not be shown: %s'):format(told, tostring(window)),
        vim.log.levels.ERROR
      )
      return true
    end
    vim.notify(
      ('aineo: the middle column has no room for %s, which is not shown'):format(told),
      vim.log.levels.WARN
    )
    return true
  end

  --- Shows `diff`, the text git printed for the `selection`'s entry, in a
  --- diff buffer named for it (`entry_diff.name()`, `aineo.changes.diffs`)
  --- through the session's `show_diff` (`show_buffer()`), the `selection`'s
  --- window the one whose cursor moves to it. Returns false, having told
  --- nothing, when Neovim refuses for now the diff buffer its text, as it
  --- does while textlock holds, or the wipe of a diff it did not show; true
  --- otherwise. Once the buffer holds the diff it records the entry the
  --- buffer shows and the context the diff was read in, and maps F in the
  --- buffer (`remember_diff()`).
  ---
  ---@param selection aineo.changes.Selection
  ---@param diff string
  ---@return boolean allowed
  local function show_diff(selection, diff)
    local entry = selection.entry
    local buffer = diffs.diff_buffer(own_name(entry_diff.name(entry)), diff)
    if not buffer then
      return false
    end
    remember_diff(buffer, entry, selection.context)
    return show_buffer(buffer, selection.window, 'the diff of ' .. entry_diff.told_name(entry))
  end

  --- How many times a key of the files window has asked for a diff to be
  --- shown in the middle column, or for a file to be opened or shown
  --- (`show_diff_at_cursor()`, `show_commit_file()`, `open_file_at_cursor()`):
  --- what a key read is shown only while no later key has asked.
  local enters = 0

  --- What a key asked to show in the middle column.
  ---@class aineo.changes.Showing
  ---@field name string the name of the buffer that shows it
  ---@field show fun(text: string): boolean makes the buffer hold `text` and shows it, returning false when Neovim refuses for now (`show_buffer()`)

  --- Shows `text`, what the `showing` stands for, which the key numbered
  --- `this_enter` read, while that key is the last. A text Neovim refused for
  --- now, as it does while textlock holds and, for a buffer it cannot show,
  --- in the command-line window, is shown at the editor's next `SafeState`,
  --- if that key is the last still; otherwise the buffer made for it, shown
  --- nowhere, is wiped (`aineo.changes.diffs`' `wipe_unshown()`), at the next
  --- `SafeState` again while Neovim refuses the wipe.
  ---
  ---@param this_enter integer
  ---@param showing aineo.changes.Showing
  ---@param text string
  local function show_last(this_enter, showing, text)
    if this_enter ~= enters then
      if diffs.wipe_unshown(showing.name) then
        return
      end
    elseif showing.show(text) then
      return
    end
    vim.api.nvim_create_autocmd('SafeState', {
      once = true,
      desc = 'aineo: show what a key read once the editor allows it',
      callback = function()
        show_last(this_enter, showing, text)
      end,
    })
  end

  --- The window whose cursor moves to the diff a key shows, given the window
  --- the key was pressed in (`show_diff_at_cursor()`): Enter's, the one it was
  --- pressed in.
  ---
  ---@param pressed_in integer
  ---@return integer
  local function cursor_follows_the_key(pressed_in)
    return pressed_in
  end

  --- The same for a key that shows a diff and leaves the cursor in the pane,
  --- as `l` and `h` do: none.
  ---
  ---@return nil
  local function cursor_stays()
    return nil
  end

  --- Tells the user that the file `entry` stands for, a diff against `HEAD`,
  --- is as `HEAD` has it.
  ---
  ---@param entry aineo.changes.HeadEntry
  local function tell_file_is_as_head_has_it(entry)
    vim.notify(head_diff.told_unchanged(entry), vim.log.levels.INFO)
  end

  --- Tells the user nothing of a diff that has nothing to show, as the diff
  --- that follows the cursor does.
  ---
  ---@param _ aineo.changes.HeadEntry
  local function tell_nothing(_) end

  --- Reads the diff of `diffed(listed)`, `listed` the entry the line under the
  --- cursor lists in `buffer` (`aineo.changes.entry_diff`), and shows it
  --- (`show_last()`), the cursor moving to it as `moving_cursor_of` says
  --- (`aineo.changes.Selection`), unless a key asked for another diff or
  --- file meanwhile: only the last key's is shown, or its failure told. A
  --- diff against `HEAD` that is empty is not shown, and the focus stays:
  --- `tell_unchanged` is called with its entry. On the heading of
  --- a branch the commits window has not read yet, tells the user, at `INFO`,
  --- that aineo is reading the repository, and reads nothing. Does nothing on
  --- a line that lists none.
  ---
  ---@param buffer integer
  ---@param diffed fun(listed: aineo.changes.Entry): aineo.changes.Entry the entry standing for the diff to show
  ---@param moving_cursor_of fun(pressed_in: integer): integer|nil the window whose cursor moves to the diff, given the window the key was pressed in (`cursor_follows_the_key()`, `cursor_stays()`)
  ---@param tell_unchanged fun(entry: aineo.changes.HeadEntry) what is done when the diff against `HEAD` is empty (`tell_file_is_as_head_has_it()`, `tell_nothing()`)
  local function show_diff_at_cursor(buffer, diffed, moving_cursor_of, tell_unchanged)
    local listed = pages.entry_at(buffer, vim.api.nvim_win_get_cursor(0)[1])
    if not listed then
      return
    end
    local entry = diffed(listed)
    if entry.filter and entry.filter.kind == 'branch' and not branch_named(entry.filter.branch) then
      vim.notify(lines.READING, vim.log.levels.INFO)
      return
    end
    enters = enters + 1
    local this_enter = enters
    local window = moving_cursor_of(vim.api.nvim_get_current_win())
    local function read_in_current_context()
      local source = diff_source(entry)
      entry_diff.read(entry, source, function(failure, diff)
        if this_enter ~= enters then
          return
        end
        if source.context ~= full_context.current() then
          read_in_current_context()
          return
        end
        if failure then
          tell_diff_unreadable(entry, failure)
          return
        end
        if head_diff.is_against_head(entry) and diff == '' then
          tell_unchanged(entry)
          return
        end
        local selection = { entry = entry, window = window, context = source.context }
        show_last(this_enter, {
          name = own_name(entry_diff.name(entry)),
          show = function(text)
            return show_diff(selection, text)
          end,
        }, diff)
      end)
    end
    read_in_current_context()
  end

  --- The entry itself: the diff of a file against its previous version.
  ---
  ---@param listed aineo.changes.Entry
  ---@return aineo.changes.Entry
  local function as_listed(listed)
    return listed
  end

  --- Shows the diff of the entry under the cursor in `buffer` and moves the
  --- cursor to it (`show_diff_at_cursor()`): what Enter does.
  ---
  ---@param buffer integer
  local function open_entry(buffer)
    show_diff_at_cursor(buffer, as_listed, cursor_follows_the_key, tell_file_is_as_head_has_it)
  end

  --- The entry standing for the diff that follows the cursor of the files
  --- window (`show_diff_following_the_cursor()`), given the entry a line
  --- lists: the kind of diff `l` or `h` showed last, against the previous
  --- version until one of them is pressed.
  ---@type fun(listed: aineo.changes.Entry): aineo.changes.Entry
  local followed_diffed = as_listed

  --- Shows the diff of the file the line under the cursor lists in `buffer`
  --- against its previous version, the cursor staying in the pane
  --- (`show_diff_at_cursor()`), and makes it the kind of diff that follows the
  --- cursor from then on.
  ---
  ---@param buffer integer
  local function preview_entry(buffer)
    followed_diffed = as_listed
    show_diff_at_cursor(buffer, as_listed, cursor_stays, tell_file_is_as_head_has_it)
  end

  --- Shows the diff of the file the line under the cursor lists in `buffer`
  --- against `HEAD` (`aineo.changes.head_diff`), the cursor staying in the
  --- pane, and makes it the kind of diff that follows the cursor from then on.
  ---
  ---@param buffer integer
  local function preview_entry_against_head(buffer)
    followed_diffed = head_diff.of
    show_diff_at_cursor(buffer, head_diff.of, cursor_stays, tell_file_is_as_head_has_it)
  end

  --- Shows, in the middle column, the file `entry` lists as the commit it is
  --- listed under has it (`aineo.changes.commit_file`), read-only, in a buffer
  --- named for the commit and the file (`aineo.changes.diffs`' `file_buffer()`),
  --- the current window kept as the one the key was pressed in, unless a key
  --- asked for another diff or file meanwhile: only the last key's is shown,
  --- or its failure told, once, naming the file.
  ---
  ---@param entry aineo.changes.Entry an entry for which `commit_file.lists_file_at_a_commit()` holds
  ---@param note? string what the user is told once the file was read, before it is shown, unless a later key asked for another
  local function show_commit_file(entry, note)
    local path = entry.change.path
    enters = enters + 1
    local this_enter = enters
    local revision, unreadable = commit_file.revision_of(entry, diff_source(entry))
    if not revision then
      ---@cast unreadable aineo.git.Failure
      vim.notify(
        ('aineo: %s could not be read: %s'):format(
          lines.quoted_path(path),
          lines.words_of(unreadable)
        ),
        vim.log.levels.ERROR
      )
      return
    end
    local name = own_name(commit_file.name(revision, path))
    local told = ('%s in %s'):format(lines.quoted_path(path), revision.told)
    local window = vim.api.nvim_get_current_win()
    commit_file.read(
      revision,
      path,
      session.settings.git,
      diffs.BYTES_NEEDED_OF_A_FILE,
      function(failure, text, size)
        if this_enter ~= enters then
          return
        end
        if failure then
          local deleted = failure.reason == 'path_missing'
          vim.notify(
            commit_file.told_failure(revision, path, failure),
            deleted and vim.log.levels.WARN or vim.log.levels.ERROR
          )
          return
        end
        if note then
          vim.notify(note, vim.log.levels.INFO)
        end
        show_last(this_enter, {
          name = name,
          show = function(content)
            local buffer = diffs.file_buffer(name, path, content, size)
            return buffer ~= nil and show_buffer(buffer, window, told)
          end,
        }, text)
      end
    )
  end

  --- Opens the file the line under the cursor lists in `buffer`, the files
  --- buffer: the file as the commit it is listed under has it, shown in the
  --- middle column (`show_commit_file()`), or the working tree's file
  --- (`aineo.changes.open_file`).
  ---
  ---@param buffer integer
  local function open_file_at_cursor(buffer)
    local entry = pages.entry_at(buffer, vim.api.nvim_win_get_cursor(0)[1])
    if not entry then
      return
    end
    if commit_file.lists_file_at_a_commit(entry) then
      show_commit_file(entry)
      return
    end
    enters = enters + 1
    open_file.open_listed_file(entry, session.repository.top)
  end

  --- Opens for edition the file the line under the cursor lists in `buffer`,
  --- the files buffer, as it is now in the working tree its line belongs to
  --- (`open_file.edit_place()`), whatever filter lists it. A file of a local
  --- branch that no worktree has checked out cannot be edited: the file is
  --- shown as the branch's tip has it, read-only, and the user is told so
  --- (`open_file.branch_checked_out_nowhere()`) once the tip's file was read
  --- (`show_commit_file()`); a file the tip no longer has is told as deleted
  --- there, and nothing else.
  --- Where a branch is checked out is read when the key is pressed, as the
  --- editor's own worktree may have checked it out since; only the last
  --- key's file is opened, and none when the cursor has left the window the
  --- key was pressed in by the time git answers. A read that fails is told
  --- as an error and opens nothing.
  ---
  ---@param buffer integer
  local function edit_file_at_cursor(buffer)
    local entry = pages.entry_at(buffer, vim.api.nvim_win_get_cursor(0)[1])
    if not entry then
      return
    end
    enters = enters + 1
    local this_key = enters
    local pressed_in = vim.api.nvim_get_current_win()
    local top = session.repository.top
    local function edit_in(place)
      if place.top then
        open_file.open_working_file(place.top, entry.change.path)
        return
      end
      show_commit_file(
        vim.tbl_extend('force', entry, { filter = filter.of_branch(place.branch) }),
        open_file.branch_checked_out_nowhere(place.branch, entry.change.path)
      )
    end
    if not open_file.branch_of(entry) then
      edit_in(open_file.edit_place(entry, top, {}))
      return
    end
    git.list_worktrees(session.repository, function(failure, listed)
      if released or this_key ~= enters or vim.api.nvim_get_current_win() ~= pressed_in then
        return
      end
      if failure then
        vim.notify(
          ('aineo: the worktrees could not be listed: %s'):format(lines.words_of(failure)),
          vim.log.levels.ERROR
        )
        return
      end
      edit_in(open_file.edit_place(entry, top, listed))
    end, session.settings.git)
  end

  --- Maps `gf` and `<S-CR>` in `buffer`, the files buffer, in Normal mode:
  --- `gf` to open the file the line under the cursor lists
  --- (`open_file_at_cursor()`), `<S-CR>` to open it for edition
  --- (`edit_file_at_cursor()`), and the session's `edit_file_key` to do the
  --- same, when it names one.
  ---
  ---@param buffer integer
  local function map_open_file(buffer)
    vim.keymap.set('n', 'gf', function()
      open_file_at_cursor(buffer)
    end, { buffer = buffer, desc = 'aineo: open the file of the entry under the cursor' })
    local keys = { '<S-CR>' }
    if session and session.settings.edit_file_key then
      table.insert(keys, session.settings.edit_file_key)
    end
    for _, key in ipairs(keys) do
      vim.keymap.set('n', key, function()
        edit_file_at_cursor(buffer)
      end, {
        buffer = buffer,
        desc = 'aineo: edit the file of the entry under the cursor as it is in its working tree',
      })
    end
  end

  --- Maps `l` and `h` in `buffer`, the files buffer, in Normal mode: `l` to
  --- show the diff of the file the line under the cursor lists against its
  --- previous version (`preview_entry()`), `h` against `HEAD`
  --- (`preview_entry_against_head()`), the cursor staying in the pane.
  ---
  ---@param buffer integer
  local function map_compare_keys(buffer)
    vim.keymap.set('n', 'l', function()
      preview_entry(buffer)
    end, {
      buffer = buffer,
      desc = 'aineo: show the diff of the file under the cursor against its previous version',
    })
    vim.keymap.set('n', 'h', function()
      preview_entry_against_head(buffer)
    end, {
      buffer = buffer,
      desc = 'aineo: show the diff of the file under the cursor against HEAD',
    })
  end

  --- Whether a window of the current tab page shows a diff the home showed
  --- in the buffer named `name`.
  ---
  ---@param name string
  ---@return boolean
  local function is_diff_shown(name)
    return vim.iter(windows_showing_a_diff()):any(function(window)
      return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(window)) == name
    end)
  end

  --- Whether a window of the current tab page shows a diff the home showed:
  --- none does while the file column holds another buffer, as a file opened
  --- for edition, or nothing, as after `close_shown_diff()`.
  ---
  ---@return boolean
  local function is_a_diff_open()
    return #windows_showing_a_diff() > 0
  end

  --- Shows the diff of the file the line under the cursor lists in `buffer`
  --- as `l` or `h` showed last (`followed_diffed`), the cursor staying in the
  --- pane (`show_diff_at_cursor()`). Does nothing when the cursor is not in
  --- `buffer`, when no diff is open (`is_a_diff_open()`), on a line that
  --- lists no file, or when a window of the tab page shows that diff already.
  ---
  ---@param buffer integer
  local function show_diff_following_the_cursor(buffer)
    if vim.api.nvim_get_current_buf() ~= buffer or not is_a_diff_open() then
      return
    end
    local listed = pages.entry_at(buffer, vim.api.nvim_win_get_cursor(0)[1])
    if not listed then
      return
    end
    if is_diff_shown(own_name(entry_diff.name(followed_diffed(listed)))) then
      return
    end
    show_diff_at_cursor(buffer, followed_diffed, cursor_stays, tell_nothing)
  end

  --- Makes the files buffer `buffer` show the diff of the file its cursor
  --- stays on for a pause (`FOLLOW_PAUSE_MS`), restarted at each move of the
  --- cursor, while a diff is open (`show_diff_following_the_cursor()`). The
  --- pause is closed when `buffer` is wiped.
  ---
  ---@param buffer integer
  local function follow_cursor_of(buffer)
    local following = pause.restartable(FOLLOW_PAUSE_MS, function()
      show_diff_following_the_cursor(buffer)
    end)
    vim.api.nvim_create_autocmd('CursorMoved', {
      buffer = buffer,
      desc = 'aineo: show the diff of the file under the cursor after a pause',
      callback = function()
        following.restart()
      end,
    })
    vim.api.nvim_create_autocmd('BufWipeout', {
      buffer = buffer,
      once = true,
      desc = 'aineo: stop the pause before the diff follows the cursor',
      callback = function()
        following.close()
      end,
    })
  end

  --- Shows the worktree `item` names alone, and chooses its whole change
  --- (`select_filter()`), which the files window then lists: as the commits
  --- window last listed it, or, for one of the Reported section it has not
  --- listed yet, as git listed it when it was reported (`node_at()`). Any
  --- other worktree the commits window no longer lists is told gone, and
  --- nothing changes.
  ---
  ---@param item aineo.changes.ScopeItem
  local function show_worktree_alone(item)
    local reported = node_at(item.top)
    local section = scope.section_on(session.commits_others, item.top)
      or (reported and reported.worktree)
    if not section then
      vim.notify(scope.picked_gone(item), vim.log.levels.INFO)
      return
    end
    session.scope, session.focused, session.branch = scope.of(section), true, nil
    session.shows_reported = false
    select_filter(filter.of_worktree(section))
    show_commits()
    read_files(true)
  end

  --- Shows the local branch `item` names alone, and chooses its whole change
  --- (`select_filter()`), which the files window then lists once the commits
  --- window has read the branch (`take_branch()`), the reads asked for
  --- without the editor's own lists. A branch deleted since the picker
  --- opened is found gone by that read, and told so.
  ---
  ---@param item aineo.changes.ScopeItem
  local function show_branch_alone(item)
    session.scope, session.focused, session.branch = scope.of_branch(item.branch), true, nil
    session.shows_reported = false
    select_filter(filter.of_branch(item.branch))
    show_commits()
    read_files(true)
    read_commits(false)
  end

  --- Chooses again, after the focused view was switched on or off, what the
  --- commits window now shows: the filter selected stays, the cursor put on
  --- its line, as the default view lists every filter the focused view lists
  --- but a local branch's. In the focused view, a filter it does not list
  --- gives way to the whole change of the worktree or branch shown alone; in
  --- the default view, a filter of a branch gives way to *Session work*; the
  --- files window is read again either way.
  local function choose_for_shown_view()
    local shown = scope_shown()
    if shown and not scope.page_lists(commits_page(), session.selected) then
      select_filter(scope.whole_change_of(shown[1]))
      read_files(true)
      return
    end
    if not shown and session.selected.branch then
      select_session_work()
      read_files(true)
      return
    end
    session.cursor_unplaced = true
  end

  --- The reports of one worktree git has not listed yet, by the folder
  --- they name, and how the user is told of them.
  ---@class aineo.changes.WaitingReport
  ---@field path string the worktree's folder, as the reports name it
  ---@field works { work: aineo.changes.ReportedWork, at: integer }[] each report, in the order taken, with when it was taken, in seconds since the epoch (`clock_now()`)
  ---@field tell fun(message: string) tells the user, as the tab the reports are for says it
  ---@field stop_timer fun() stops the timer that lets the reports go

  --- Settles the focused view once the reported work changed: while it is
  --- the reported work and shows nothing alone any more, the default view
  --- shows, chosen again for what it lists, and, when `tell_gone`, the user
  --- is told once that the reported work is gone.
  ---
  ---@param tell_gone boolean
  local function settle_reported_view(tell_gone)
    if not session.shows_reported or #reported_members(session.shown_label) > 0 then
      return
    end
    session.shows_reported, session.shown_label = false, nil
    if session.focused then
      session.focused = false
      if tell_gone then
        vim.notify(scope.REPORTED_GONE, vim.log.levels.INFO)
      end
    end
    choose_for_shown_view()
  end

  --- Takes into the Reported section the reports `waiting` holds, of
  --- `worktree`, the worktree git lists at the folder they name, one after
  --- another as `reports.with_report()` lays each over the nodes. A worktree
  --- new to the section, other than the editor's own, makes every reported
  --- worktree the focused view, shown at once, that worktree's whole change
  --- chosen, the cursor on its heading, and the user is told once with
  --- `waiting.tell`, the worktree named with the branches reported of it
  --- (`scope.started_work()`); any other change is written and read again, the
  --- focused view settled (`settle_reported_view()`). The other worktrees
  --- are read again while the pane has been shown, so that the work's
  --- commits show.
  ---
  ---@param worktree aineo.git.Worktree
  ---@param waiting aineo.changes.WaitingReport
  local function take_waiting(worktree, waiting)
    local was_reported = node_at(worktree.top) ~= nil
    for _, taken in ipairs(waiting.works) do
      session.nodes = reports.with_report(session.nodes, {
        worktree = worktree,
        label = taken.work.label,
        branches = taken.work.branches,
        at = taken.at,
        by_hook = taken.work.by_hook,
      })
    end
    local node = node_at(worktree.top)
    local joined = not was_reported and node ~= nil
    if joined and worktree.top ~= own_top() then
      session.shows_reported, session.shown_label, session.focused = true, nil, true
      local section = scope.section_on(session.commits_others, worktree.top) or worktree
      select_filter(filter.of_worktree(section))
      show_commits()
      read_files(true)
      local reported_names = vim.tbl_map(function(reported)
        return reported.name
      end, node.branches)
      waiting.tell(scope.started_work(worktree.top, reported_names))
    else
      settle_reported_view(false)
      show_commits()
    end
    if session.shown then
      read_commits(false)
    end
  end

  --- Keeps of the Reported section what `candidates`, what git now lists,
  --- still lists (`reports.still_listed()`), each worktree as git now lists
  --- it, telling nothing of what was dropped. Once the reported work the
  --- focused view shows is gone, the default view shows, chosen again for
  --- what it lists, and the user is told once (`settle_reported_view()`).
  ---
  ---@param candidates aineo.changes.BranchCandidates
  local function keep_reported_listed_in(candidates)
    local kept_nodes, dropped = reports.still_listed(session.nodes, candidates)
    session.nodes = kept_nodes
    if not dropped then
      return
    end
    settle_reported_view(true)
    show_commits()
  end

  --- Resolves, off the main loop, the folder each report of `waitings`
  --- names, every link in it followed (`vim.uv.fs_realpath()` with a
  --- callback, so that a path under a mount that does not answer holds no
  --- keystroke), and calls `done(real_paths)` on the main loop once all
  --- have answered: each report's real path, none for a path that resolves
  --- to nothing.
  ---
  ---@param waitings aineo.changes.WaitingReport[]
  ---@param done fun(real_paths: table<aineo.changes.WaitingReport, string>)
  local function resolve_real_paths(waitings, done)
    local real_paths = {}
    local pending = #waitings
    if pending == 0 then
      done(real_paths)
      return
    end
    for _, waiting in ipairs(waitings) do
      vim.uv.fs_realpath(waiting.path, function(_, real_path)
        real_paths[waiting] = real_path
        pending = pending - 1
        if pending == 0 then
          vim.schedule(function()
            done(real_paths)
          end)
        end
      end)
    end
  end

  --- Matches the reports still waiting, each worktree's in the order first
  --- reported, against `candidates`, what git now lists of the worktrees
  --- and the branches: those of a worktree git lists at their folder's real
  --- path, `real_paths`, join the Reported section (`take_waiting()`), their
  --- timer stopped, and any other waits on, one with no real path there, as
  --- one made since they were resolved, among them. The Reported section is
  --- kept as git lists it first (`keep_reported_listed_in()`).
  ---
  ---@param candidates aineo.changes.BranchCandidates
  ---@param real_paths table<aineo.changes.WaitingReport, string> `resolve_real_paths()`
  local function take_reported(candidates, real_paths)
    keep_reported_listed_in(candidates)
    local still_waiting = {}
    for _, waiting in ipairs(session.waiting) do
      local real_path = real_paths[waiting]
      local listed = real_path
        and vim.iter(candidates.worktrees):find(function(worktree)
          return worktree.top == real_path
        end)
      if listed then
        waiting.stop_timer()
        take_waiting(listed, waiting)
      else
        table.insert(still_waiting, waiting)
      end
    end
    session.waiting = still_waiting
  end

  --- Lets `waiting` go, once its time to wait is over, when it still waits,
  --- and tells the user once that git does not list the worktree it named —
  --- unless none of its reports listed a branch: an agent done with a
  --- worktree it already removed asked for nothing git could list.
  ---
  ---@param waiting aineo.changes.WaitingReport
  local function let_report_go(waiting)
    local still_waiting = vim.tbl_filter(function(other)
      return other ~= waiting
    end, session.waiting)
    if #still_waiting == #session.waiting then
      return
    end
    session.waiting = still_waiting
    local lists_branches = vim.iter(waiting.works):any(function(taken)
      return #taken.work.branches > 0
    end)
    if lists_branches then
      waiting.tell(scope.unlisted_report(waiting.path))
    end
  end

  --- How many reads of what reports are matched against were started
  --- (`read_reported()`).
  local reported_reads = 0

  --- Reads what git lists of the worktrees and the branches, as `s` reads it
  --- (`aineo.changes.branch`), and matches the reports against it
  --- (`take_reported()`), unless a later read was started by then, the home
  --- was let go, or the read failed; then calls `done()`, when given. Does
  --- nothing but call it while no repository was found.
  ---
  ---@param done? fun()
  function read_reported(done)
    done = done or function() end
    if not session.repository then
      done()
      return
    end
    reported_reads = reported_reads + 1
    local this_read = reported_reads
    branch.read_candidates({
      repository = session.repository,
      working_branch = session.settings.working_branch,
      git = session.settings.git,
    }, function(failure, candidates)
      if failure or released or this_read ~= reported_reads then
        done()
        return
      end
      resolve_real_paths(session.waiting, function(real_paths)
        if not released and this_read == reported_reads then
          take_reported(candidates, real_paths)
        end
        done()
      end)
    end)
  end

  --- Takes `work`, the report of a worktree an agent of the tab's Claude
  --- Code works in, or that aineo's hook saw work made in, to be told with
  --- `tell`, and starts at once a read of the worktrees and the branches,
  --- whether or not the pane shows or was ever shown (`read_reported()`).
  --- A report waits until git lists a worktree at its folder, matched again
  --- at every read of the commits window, for `REPORT_WAIT_MS` from the first
  --- report of that folder, then is let go (`let_report_go()`). Each report is
  --- timed as it is taken (`clock_now()`), the age the Reported section
  --- shows. Returns whether the home took it: a report of a folder another
  --- waits for is taken, after it, and reads again; one more than
  --- `MOST_WAITING` distinct folders waiting is not taken, nor is any report
  --- before the session has begun, and nothing is told of either.
  ---
  ---@param work aineo.changes.ReportedWork
  ---@param tell fun(message: string)
  ---@return boolean taken
  function home.add_reported_work(work, tell)
    if not session then
      return false
    end
    local at = clock_now()
    local same = vim.iter(session.waiting):find(function(other)
      return other.path == work.worktree
    end)
    if same then
      table.insert(same.works, { work = work, at = at })
      read_reported()
      return true
    end
    if #session.waiting >= MOST_WAITING then
      return false
    end
    local waiting = { path = work.worktree, works = { { work = work, at = at } }, tell = tell }
    local start_timer = session.settings.start_timer or start_uv_timer
    waiting.stop_timer = start_timer(REPORT_WAIT_MS, function()
      let_report_go(waiting)
    end)
    table.insert(session.waiting, waiting)
    read_reported()
    return true
  end

  --- Resolves `reported`, the item at `position` of a report's branches,
  --- one of the local branches `found` lists, the repository of the
  --- reported worktree's folder, when it is one, else the session's
  --- repository: its base, as git reads a name (`aineo.git`'s
  --- `resolve_commit()`), names a commit there — so that `HEAD` is the
  --- agent's own — or, when it does not or git fails there, in the session's
  --- repository, whose own answer, a failure included, is the one given;
  --- each git run stopped after `BASE_RESOLUTION_LIMIT_MS`. Calls
  --- `done(commit)` with the full id of the base, or `done(nil, refusal)`
  --- with why it is refused, in words for the agent that name the item.
  ---
  ---@param found aineo.git.Repository|nil
  ---@param reported aineo.changes.ReportedBranch
  ---@param position integer
  ---@param done fun(commit: string|nil, refusal: string|nil)
  local function resolve_base(found, reported, position, done)
    local repository = session.repository
    local options = vim.tbl_extend('force', session.settings.git or {}, {
      limit_ms = BASE_RESOLUTION_LIMIT_MS,
    })
    local item = ('branches[%d]'):format(position)
    local base = lines.quoted_path(reported.base)
    local function in_repository(tried_top)
      git.resolve_commit(repository, reported.base, function(failure, commit)
        if failure then
          done(nil, item .. '.base: ' .. lines.words_of(failure))
        elseif commit then
          done(commit)
        elseif tried_top and tried_top ~= repository.top then
          done(
            nil,
            ('%s.base: %s names no commit in %s, nor in %s'):format(
              item,
              base,
              lines.quoted_path(tried_top),
              lines.quoted_path(repository.top)
            )
          )
        else
          done(
            nil,
            ('%s.base: %s names no commit in %s'):format(
              item,
              base,
              lines.quoted_path(repository.top)
            )
          )
        end
      end, options)
    end
    if not found then
      in_repository(nil)
      return
    end
    git.resolve_commit(found, reported.base, function(_, commit)
      if commit then
        done(commit)
      else
        in_repository(found.top)
      end
    end, options)
  end

  --- Why the branches of `work` are refused, in words for the agent that
  --- name the first item whose name is not exactly one of `local_names`,
  --- the local branches git lists in `listed_in`; nil when every one is.
  --- A revision of a branch, `main~1` or `feature/a^0`, is no branch.
  ---
  ---@param work aineo.changes.ReportedWork
  ---@param local_names table<string, true>
  ---@param listed_in string the top level of the repository the names were listed in
  ---@return string|nil
  local function unknown_branch_refusal(work, local_names, listed_in)
    for position, reported in ipairs(work.branches) do
      if not local_names[reported.name] then
        return ('branches[%d].name: %s is no local branch in %s'):format(
          position,
          lines.quoted_path(reported.name),
          lines.quoted_path(listed_in)
        )
      end
    end
    return nil
  end

  --- Resolves the bases of the branches of `work`, as `resolve_base()` does
  --- each, all at once, in `found`, and calls `done(resolved)` with `work`,
  --- each branch's base its full id, or `done(nil, refusal)` with the
  --- refusal of the first item at fault.
  ---
  ---@param work aineo.changes.ReportedWork
  ---@param found aineo.git.Repository|nil
  ---@param done fun(resolved: aineo.changes.ReportedWork|nil, refusal: string|nil)
  local function resolve_bases(work, found, done)
    local results, pending = {}, #work.branches
    for position, reported in ipairs(work.branches) do
      resolve_base(found, reported, position, function(commit, refusal)
        results[position] = { commit = commit, refusal = refusal }
        pending = pending - 1
        if pending > 0 then
          return
        end
        local first_refused = vim.iter(results):find(function(result)
          return result.refusal ~= nil
        end)
        if first_refused then
          done(nil, first_refused.refusal)
          return
        end
        done(vim.tbl_extend('force', work, {
          branches = vim
            .iter(ipairs(work.branches))
            :map(function(index, listed)
              return { name = listed.name, base = results[index].commit }
            end)
            :totable(),
        }))
      end)
    end
  end

  --- Resolves the branches of `work`, the report of a worktree, in the
  --- repository of the worktree's folder when git finds one there, else in
  --- the session's repository: each must be exactly one of the local
  --- branches git lists there (`unknown_branch_refusal()`), and each base is
  --- resolved as `resolve_base()` does, all at once. Calls `done(resolved)`
  --- with `work`, each branch's base its full id, or `done(nil, refusal)`
  --- with why it is refused, in words for the agent that name the first
  --- item at fault: also with no session yet, no repository found for it,
  --- or the local branches git cannot list. A report of no branch is given
  --- back as it is.
  ---
  ---@param work aineo.changes.ReportedWork
  ---@param done fun(resolved: aineo.changes.ReportedWork|nil, refusal: string|nil)
  function home.resolve_reported_work(work, done)
    if not (session and session.repository) then
      done(nil, 'worktree: aineo has found no repository for this session to read it in')
      return
    end
    if #work.branches == 0 then
      done(work)
      return
    end
    local options = vim.tbl_extend('force', session.settings.git or {}, {
      limit_ms = BASE_RESOLUTION_LIMIT_MS,
    })
    git.find_repository(work.worktree, function(failure, found)
      local found_repository = not failure and found or nil
      local listed_in = found_repository or session.repository
      git.list_branches(listed_in, function(list_failure, branches)
        if list_failure then
          done(nil, 'branches: ' .. lines.words_of(list_failure))
          return
        end
        local local_names = {}
        for _, listed in ipairs(branches) do
          local_names[listed.name] = true
        end
        local refusal = unknown_branch_refusal(work, local_names, listed_in.top)
        if refusal then
          done(nil, refusal)
          return
        end
        resolve_bases(work, found_repository, done)
      end, options)
    end, options)
  end

  --- Shows the editor's own work: the default view, *Session work* chosen.
  local function show_own_work()
    session.focused, session.shows_reported, session.shown_label = false, false, nil
    select_filter(filter.SESSION_WORK)
    show_commits()
    read_files(true)
  end

  --- Makes the reported work the focused view, shown at once, its first
  --- worktree's or branch's whole change chosen: every worktree's, or, with
  --- `shown_label`, those of that label alone (`reported_members()`); the scope
  --- picked, if any, is kept behind it. Reported work that shows nothing
  --- alone — the editor's own worktree's alone — shows the editor's own
  --- work (`show_own_work()`), and work gone since the picker opened
  --- changes nothing.
  ---
  ---@param shown_label string|nil
  local function show_reported(shown_label)
    local nodes = shown_label and reports.labelled(session.nodes, shown_label) or session.nodes
    if #nodes == 0 then
      return
    end
    local members = reported_members(shown_label)
    if #members == 0 then
      show_own_work()
      return
    end
    session.shows_reported, session.shown_label, session.focused = true, shown_label, true
    select_filter(scope.whole_change_of(members[1]))
    show_commits()
    read_files(true)
  end

  --- Shows what `item`, a choice of the list `s` offers or of a line of the
  --- Reported section, names: a worktree or a branch alone
  --- (`show_worktree_alone()`, `show_branch_alone()`), the editor's own work
  --- (`show_own_work()`), the reported work of one label, or every
  --- worktree's (`show_reported()`); anything else is ignored.
  ---
  ---@param item any
  local function show_item(item)
    if type(item) ~= 'table' then
      return
    end
    if type(item.top) == 'string' then
      show_worktree_alone(item)
    elseif type(item.branch) == 'string' then
      show_branch_alone(item)
    elseif item.own == true then
      show_own_work()
    elseif type(item.group) == 'string' then
      show_reported(item.group)
    elseif item.reported == true then
      show_reported(nil)
    end
  end

  --- Opens `vim.ui.select` on `items`, what `s` offers
  --- (`aineo.changes.scope`), and shows the item picked (`show_item()`).
  --- With no item, tells the user there is none.
  ---
  ---@param items aineo.changes.ScopeItem[]
  local function pick_among(items)
    if #items == 0 then
      vim.notify(scope.NONE_TO_SHOW, vim.log.levels.INFO)
      return
    end
    local asked, failure = pcall(vim.ui.select, items, {
      prompt = scope.PROMPT,
      format_item = function(item)
        return item.text
      end,
    }, show_item)
    if not asked then
      vim.notify(scope.picker_failed(failure), vim.log.levels.ERROR)
    end
  end

  --- Whether `s` is reading what it offers: a second press waits for the
  --- first.
  local offering = false

  --- Whether `s` was pressed before the other worktrees were read, and waits
  --- for them (`offer_once_read()`).
  local offer_asked = false

  --- Offers the other worktrees the commits window last listed and the local
  --- branches no worktree has checked out (`pick_among()`), the branches read
  --- when `s` is pressed (`aineo.changes.branch`), off the main loop: the
  --- picker opens once they are. Branches that cannot be read leave the
  --- worktrees alone, the failure told once. With the repository found and
  --- the other worktrees not read yet, as before the pane was first shown,
  --- it tells the user they are being read, reads them as a showing of the
  --- pane does (`pane_shown()`) and offers the list once they are. While the
  --- session has no repository, or the other worktrees are unlisted, tells
  --- why instead (`aineo.changes.scope`).
  local function offer_scopes()
    if not session then
      vim.notify(lines.READING, vim.log.levels.INFO)
      return
    end
    if session.repository and session.commits_others == worktrees.NONE then
      vim.notify(lines.READING, vim.log.levels.INFO)
      offer_asked = true
      pane_shown()
      return
    end
    local why_not = scope.why_not_ready({
      has_repository = session.repository ~= nil,
      absence = session.absence,
      directory = session.settings.directory,
      others = session.commits_others,
      others_read = session.commits_others ~= worktrees.NONE,
    })
    if why_not then
      vim.notify(why_not, vim.log.levels.INFO)
      return
    end
    if offering then
      return
    end
    offering = true
    branch.read_candidates({
      repository = session.repository,
      working_branch = session.settings.working_branch,
      git = session.settings.git,
    }, function(failure, candidates)
      offering = false
      if released then
        return
      end
      if failure then
        vim.notify(scope.branches_unlisted(failure), vim.log.levels.WARN)
      end
      pick_among(
        scope.items_of(
          session.commits_others,
          candidates,
          #session.nodes,
          vim.tbl_map(function(line)
            return lines.report_item(line, clock_now())
          end, reported_lines())
        )
      )
    end)
  end

  offer_once_read = function()
    if offer_asked then
      offer_asked = false
      vim.schedule(offer_scopes)
    end
  end

  home.offer_scopes = offer_scopes
  home.focused_work = focused_work

  --- Calls `watcher` each time what the focused view shows alone
  --- (`home.focused_work()`) changes: a pick of `s`, the switch between the
  --- default view and the focused view, a worktree joining the reported work,
  --- and a worktree or branch shown alone that is gone.
  ---
  ---@param watcher fun()
  function home.watch_focused_work(watcher)
    table.insert(focused_work_watchers, watcher)
  end

  --- A scratch buffer of the pane named `name` (`aineo.changes.scratch`),
  --- written with `page()` whenever it is made or read, which tells the
  --- session the pane is shown whenever it enters a window (`pane_shown()`).
  --- Enter shows the diff of the entry under the cursor (`open_entry()`), and
  --- `s` offers the worktrees and branches to show alone (`offer_scopes()`),
  --- in Normal mode, in this buffer alone.
  ---
  ---@param name string
  ---@param page fun(): aineo.changes.Page
  ---@return integer buffer
  local function pane_buffer(name, page)
    local buffer = scratch.named_scratch_buffer(name, 'hide', function(made)
      if session then
        pages.write_page(made, page())
      end
    end)
    vim.api.nvim_create_autocmd('BufWinEnter', {
      buffer = buffer,
      desc = 'aineo: read the changes pane again',
      callback = function()
        pane_shown()
      end,
    })
    vim.keymap.set('n', '<CR>', function()
      local picked = pages.entry_at(buffer, vim.api.nvim_win_get_cursor(0)[1])
      if picked and picked.picks then
        show_item(picked.picks)
      else
        open_entry(buffer)
      end
    end, {
      buffer = buffer,
      desc = 'aineo: show the diff of the entry under the cursor, or the work its report names alone',
    })
    vim.keymap.set('n', 's', offer_scopes, {
      buffer = buffer,
      nowait = true,
      desc = 'aineo: show one worktree or branch alone in the changes pane',
    })
    return buffer
  end

  --- The window whose cursor last moved in the commits buffer.
  ---@type integer|nil
  local window_moved = nil

  --- The filter the line under the cursor of `window` lists, when `window`
  --- shows the commits buffer and the filter is another than the selected one;
  --- nil otherwise. A line that lists no filter — a note — gives none, and so
  --- does a cursor not yet put on the selected filter's line
  --- (`place_commits_cursor()`), which a commits page written before git
  --- answered shows on its first line.
  ---
  ---@param window integer|nil
  ---@return aineo.changes.Filter|nil
  local function other_filter_at_cursor(window)
    if
      not (
        session
        and not session.cursor_unplaced
        and window
        and vim.api.nvim_win_is_valid(window)
        and buffers.commits
        and vim.api.nvim_win_get_buf(window) == buffers.commits
      )
    then
      return nil
    end
    local entry = pages.entry_at(buffers.commits, vim.api.nvim_win_get_cursor(window)[1])
    local at_cursor = entry and entry.filter
    if not at_cursor or filter.same(at_cursor, session.selected) then
      return nil
    end
    return at_cursor
  end

  --- Selects the filter the line under the cursor of `window`, a window
  --- showing the commits buffer, lists, when it is a filter other than the
  --- selected one (`other_filter_at_cursor()`), and reads the files window
  --- for it.
  ---
  ---@param window integer|nil
  local function select_filter_at_cursor_of(window)
    local at_cursor = other_filter_at_cursor(window)
    if not at_cursor then
      return
    end
    session.selected = at_cursor
    read_files(true)
  end

  --- Selects the filter the line under the cursor of the window whose cursor
  --- last moved in the commits buffer lists (`select_filter_at_cursor_of()`).
  local function select_filter_at_cursor()
    select_filter_at_cursor_of(window_moved)
  end

  --- The pause after the last move of the cursor in the commits buffer, at
  --- whose end the selection follows the cursor (`select_filter_at_cursor()`).
  local selection_pause = pause.restartable(SELECTION_PAUSE_MS, select_filter_at_cursor)

  --- Makes the commits buffer `buffer` choose the filter of the files window:
  --- its cursor, once it has stayed on a line for a pause
  --- (`selection_pause`), whether the cursor moved in the current window or a
  --- scroll made from another window carried it.
  ---
  ---@param buffer integer
  local function select_filters_from(buffer)
    vim.api.nvim_create_autocmd('CursorMoved', {
      buffer = buffer,
      desc = 'aineo: select the filter of the files window after a pause',
      callback = function()
        window_moved = vim.api.nvim_get_current_win()
        selection_pause.restart()
      end,
    })
    vim.api.nvim_create_autocmd('WinScrolled', {
      group = vim.api.nvim_create_augroup(own_group('aineo_changes_commits_scroll'), {}),
      desc = 'aineo: select the filter of the files window after a pause, as a scroll carries the cursor',
      callback = function()
        for key in pairs(vim.v.event) do
          local window = tonumber(key)
          if other_filter_at_cursor(window) then
            window_moved = window
            selection_pause.restart()
            return
          end
        end
      end,
    })
  end

  --- Moves the cursor from the commits window to the files window, the choice
  --- the line under the cursor makes kept: it is made at once, without the
  --- pause (`select_filter_at_cursor_of()`), and the cursor of the files
  --- window goes to a file once the window lists the choice's files
  --- (`place_awaited_files_cursor()`). Does nothing when the tab page shows
  --- no files window; on a line that lists no filter it only moves.
  local function move_to_files_window()
    local files = window_showing(buffers.files)
    if not (session and files) then
      return
    end
    select_filter_at_cursor_of(vim.api.nvim_get_current_win())
    vim.api.nvim_set_current_win(files)
    awaited_files_key = filter.key(session.selected)
    place_awaited_files_cursor()
  end

  --- Moves the cursor from the files window to the commits window, onto the
  --- line that chose what the files window lists, the selected filter's, when
  --- the commits window lists it. Does nothing when the tab page shows no
  --- commits window.
  local function move_to_commits_window()
    local commits = window_showing(buffers.commits)
    if not (session and commits) then
      return
    end
    awaited_files_key = nil
    vim.api.nvim_set_current_win(commits)
    local line = pages.line_of(buffers.commits, filter.key(session.selected))
    if line then
      vim.api.nvim_win_set_cursor(commits, { line, 0 })
    end
  end

  --- Maps `l` in `buffer`, the commits buffer, in Normal mode, to move the
  --- cursor to the files window (`move_to_files_window()`).
  ---
  ---@param buffer integer
  local function map_move_to_files(buffer)
    vim.keymap.set('n', 'l', move_to_files_window, {
      buffer = buffer,
      desc = 'aineo: move to the files window, the choice under the cursor kept',
    })
  end

  --- The keys of the commit graph that move the cursor, each with the line
  --- it goes to from a line of the graph's page, given a count
  --- (`aineo.changes.graph`).
  ---@type { key: string, target: fun(page: aineo.changes.Page, line: integer, count: integer): integer|nil, desc: string }[]
  local GRAPH_MOVES = {
    {
      key = 'j',
      target = graph.commit_line_below,
      desc = 'aineo: move to the next commit line of the commit graph',
    },
    {
      key = 'k',
      target = graph.commit_line_above,
      desc = 'aineo: move to the previous commit line of the commit graph',
    },
  }

  --- Moves the cursor of the current window, showing the commits buffer, to
  --- the line `target` gives from the line it is on with the count typed,
  --- one when none was; leaves it where it is when `target` gives none.
  ---
  ---@param target fun(page: aineo.changes.Page, line: integer, count: integer): integer|nil
  local function move_in_graph(target)
    local page = pages.page_of(buffers.commits)
    local line = page and target(page, vim.api.nvim_win_get_cursor(0)[1], vim.v.count1)
    if line then
      vim.api.nvim_win_set_cursor(0, { line, 0 })
    end
  end

  --- Maps `j` and `k` in `buffer`, the commits buffer, in Normal mode, to
  --- move from commit line to commit line of the graph (`GRAPH_MOVES`,
  --- `move_in_graph()`) while the graph is shown, and unmaps them while it
  --- is not, so that they are Vim's own over the sections.
  ---
  ---@param buffer integer
  local function map_graph_moves(buffer)
    for _, move in ipairs(GRAPH_MOVES) do
      if session.graph_shown then
        vim.keymap.set('n', move.key, function()
          move_in_graph(move.target)
        end, { buffer = buffer, desc = move.desc })
      else
        pcall(vim.keymap.del, 'n', move.key, { buffer = buffer })
      end
    end
  end

  --- The line each window showing the commits buffer had its cursor on
  --- when the graph last kept it on a commit line (`keep_on_a_commit_line()`),
  --- by window: where its next move comes from.
  ---@type table<integer, integer>
  local graph_line_left = {}

  --- Puts the cursor of `window`, showing the commits buffer while the graph
  --- is shown, on the commit line it comes to rest on
  --- (`aineo.changes.graph`'s `commit_line_reached()`): moved up onto a line
  --- of the graph alone or a note, on the commit line above; moved down, on
  --- the one below; when it did not move, on the nearest. It never rests on
  --- a line of the graph alone, nor on a note. Leaves it where it is on a
  --- page that lists no commit.
  ---
  ---@param window integer
  local function keep_on_a_commit_line(window)
    local page = pages.page_of(buffers.commits)
    local cursor = vim.api.nvim_win_get_cursor(window)
    local line = page and graph.commit_line_reached(page, cursor[1], graph_line_left[window])
    if line and line ~= cursor[1] then
      vim.api.nvim_win_set_cursor(window, { line, 0 })
    end
    graph_line_left[window] = line or cursor[1]
  end

  --- Makes the cursor of the commits buffer `buffer` go on to a commit
  --- line whenever it moves while the graph is shown — a click, `G`, a
  --- search — so that it never rests on a line of the graph alone
  --- (`keep_on_a_commit_line()`).
  ---
  ---@param buffer integer
  local function keep_cursor_on_commits(buffer)
    vim.api.nvim_create_autocmd('CursorMoved', {
      buffer = buffer,
      desc = 'aineo: keep the cursor of the commit graph on a commit line',
      callback = function()
        if session and session.graph_shown then
          keep_on_a_commit_line(vim.api.nvim_get_current_win())
        end
      end,
    })
  end

  --- Selects again the filter selected when `t` showed the graph, the
  --- commits window's cursor to be put on its line (`select_filter()`), and
  --- reads the files window for it when the graph chose another meanwhile.
  local function choose_again_before_graph()
    local before = session.selected_before_graph or filter.SESSION_WORK
    session.selected_before_graph = nil
    local chose_another = not filter.same(before, session.selected)
    select_filter(before)
    if chose_another then
      read_files(true)
    end
  end

  --- Switches the commits window between its sections and the commit graph
  --- (`aineo.changes.graph`), for the home's life, and writes it again, with
  --- `j` and `k` mapped to the graph's moves while it shows
  --- (`map_graph_moves()`). The graph is read anew each time it is shown
  --- (`read_graph()`), the cursor to be put on a commit
  --- (`place_graph_cursor()`); the sections are shown with the filter
  --- selected before the graph selected again (`choose_again_before_graph()`).
  --- Does nothing before the session's repository is found.
  local function toggle_graph()
    if not (session and session.repository) then
      return
    end
    session.graph_shown = not session.graph_shown
    map_graph_moves(buffers.commits)
    if session.graph_shown then
      session.selected_before_graph = session.selected
      session.graph_cursor_unplaced = true
      read_graph()
    else
      choose_again_before_graph()
    end
    show_commits()
  end

  --- The line of `page`, the commit graph the commits buffer shows, that
  --- the cursor goes to once `t` shows it: the line of the commit the
  --- selected filter names, when the graph lists it, else the first commit
  --- line; nil while the graph lists none.
  ---
  ---@param page aineo.changes.Page
  ---@return integer|nil
  local function graph_line_chosen(page)
    local selected = session.selected
    local line = selected.kind == 'commit'
      and pages.line_of(buffers.commits, filter.key(filter.of_graph_commit(selected.commit)))
    return line or graph.commit_line_below(page, 0, 1)
  end

  --- Puts the cursor of each window showing the commits buffer, current or
  --- not, on a commit of the graph just written, and selects the commit
  --- under the first one's cursor, whose files the files window then lists
  --- (`select_filter_at_cursor_of()`): on the line `graph_line_chosen()`
  --- gives while the session says the cursor is still to be put there
  --- (`aineo.changes.Session`'s `graph_cursor_unplaced`), else on the commit
  --- line its cursor comes to rest on (`keep_on_a_commit_line()`), as when a
  --- read dropped the commit it was on. Does nothing while no window shows
  --- the buffer or the graph lists no commit.
  place_graph_cursor = function()
    local page = pages.page_of(buffers.commits)
    local windows = vim.fn.win_findbuf(buffers.commits)
    if not page or #windows == 0 then
      return
    end
    if session.graph_cursor_unplaced then
      local line = graph_line_chosen(page)
      if not line then
        return
      end
      for _, window in ipairs(windows) do
        vim.api.nvim_win_set_cursor(window, { line, 0 })
      end
      session.graph_cursor_unplaced, session.cursor_unplaced = false, false
    else
      for _, window in ipairs(windows) do
        keep_on_a_commit_line(window)
      end
    end
    select_filter_at_cursor_of(windows[1])
  end

  --- Maps `t` in `buffer`, the commits buffer, in Normal mode, to switch
  --- between the sections and the commit graph (`toggle_graph()`).
  ---
  ---@param buffer integer
  local function map_toggle_graph(buffer)
    vim.keymap.set('n', 't', toggle_graph, {
      buffer = buffer,
      nowait = true,
      desc = 'aineo: show the commit graph in the commits window, or its sections again',
    })
  end

  --- Maps `<BS>` in `buffer`, the files buffer, in Normal mode, to move the
  --- cursor back to the commits window (`move_to_commits_window()`).
  ---
  ---@param buffer integer
  local function map_move_to_commits(buffer)
    vim.keymap.set('n', '<BS>', move_to_commits_window, {
      buffer = buffer,
      desc = 'aineo: move back to the commit that chose the files listed',
    })
  end

  --- Whether `buffer`, a buffer of the pane once made, is shown in a window
  --- of any tab page.
  ---
  ---@param buffer integer|nil
  ---@return boolean
  local function is_shown(buffer)
    return buffer ~= nil and vim.api.nvim_buf_is_valid(buffer) and #vim.fn.win_findbuf(buffer) > 0
  end

  --- Reads both lists again, as a showing of the pane does, while either of
  --- the pane's buffers is shown in a window of any tab page (`is_shown()`);
  --- does nothing otherwise, or before the session has begun.
  function home.refresh_shown_pane()
    if is_shown(buffers.files) or is_shown(buffers.commits) then
      pane_shown()
    end
  end

  --- Reads both lists again, as a showing of the pane does, while the pane
  --- is shown in a window of any tab page (`is_shown()`); and, when the
  --- current buffer is one of the pane's two, switches the commits window
  --- between the default view and the focused view — the scope the user
  --- picked or the reported work, whichever was chosen last, kept while the
  --- default view shows — chosen again for what the new view lists
  --- (`choose_for_shown_view()`). With the cursor anywhere else — Claude's
  --- window, Input, the Report, a diff — or with neither a scope picked nor
  --- a set reported, it only reads them again, as `refresh_shown_pane()` does. Does
  --- nothing while the pane is not shown, or before the session has begun:
  --- the pane is then shown, and read, in the view it was left in.
  function home.toggle_focused_view()
    if not (session and (is_shown(buffers.files) or is_shown(buffers.commits))) then
      return
    end
    local current = vim.api.nvim_get_current_buf()
    local has_focused_view = session.scope ~= nil or #reported_members(nil) > 0
    if has_focused_view and (current == buffers.files or current == buffers.commits) then
      session.focused = not session.focused
      choose_for_shown_view()
      show_commits()
    end
    pane_shown()
  end

  --- The changes pane's two buffers, each written for what the session
  --- knows: the files buffer, `aineo://changes-files`, and the commits
  --- buffer, `aineo://changes-commits`, as the module's home names them
  --- (`own_name()`). Each is a scratch buffer, not modifiable, made once
  --- and made anew once it is no longer loaded — wiped, or unloaded, as
  --- `:bdelete` unloads it — taking its name from any buffer
  --- holding it; `:edit` and `:edit!` write it again. Whenever either enters
  --- a window, the pane is shown: the first time, the watch starts, and each
  --- time both lists are read again, once for every showing in one turn of
  --- the main loop (`pane_shown()`). A commits buffer made anew selects
  --- *Session work* again, or the whole change of the worktree or branch shown alone,
  --- its cursor to be put there when it is shown (`select_view_default()`);
  --- while the commit graph is shown, it shows the graph, its `j` and `k`
  --- mapped (`map_graph_moves()`), its cursor to be put on a commit
  --- (`place_graph_cursor()`). `t` in it switches between the sections and
  --- the graph (`toggle_graph()`).
  ---
  ---@return { files: integer, commits: integer }
  function home.pane_buffers()
    if not (buffers.files and vim.api.nvim_buf_is_loaded(buffers.files)) then
      buffers.files = pane_buffer(own_name('aineo://changes-files'), files_page)
      map_open_file(buffers.files)
      map_compare_keys(buffers.files)
      follow_cursor_of(buffers.files)
      map_move_to_commits(buffers.files)
    end
    if not (buffers.commits and vim.api.nvim_buf_is_loaded(buffers.commits)) then
      buffers.commits = pane_buffer(own_name('aineo://changes-commits'), commits_page)
      select_filters_from(buffers.commits)
      map_move_to_files(buffers.commits)
      map_toggle_graph(buffers.commits)
      keep_cursor_on_commits(buffers.commits)
      if session and session.graph_shown then
        map_graph_moves(buffers.commits)
        session.graph_cursor_unplaced = true
      elseif session then
        select_view_default()
      end
    end
    return { files = buffers.files, commits = buffers.commits }
  end

  --- Lets the home go, as its tab page closes: stops its watch and closes the
  --- timer of the pause its commits window's cursor starts, removes its
  --- handlers, by deleting their groups (a group the home never made is no
  --- error), and wipes its pane's two buffers and the diffs it showed. The
  --- bases, the saves and the views it kept on disk stay (`aineo.changes.kept`).
  --- Nothing follows its repository
  --- afterwards, whether a look for the repository is answered after this or
  --- not. Only a home with a label, as `M.new()` makes them, has it. A home
  --- let go is called no more.
  ---
  --- Raises what Neovim raises when a buffer cannot be wiped.
  local function let_go()
    released = true
    selection_pause.close()
    if session and session.watch then
      session.watch.stop()
      session.watch = nil
    end
    if session then
      drop_waiting()
    end
    pcall(vim.api.nvim_del_augroup_by_name, own_group('aineo_changes'))
    pcall(vim.api.nvim_del_augroup_by_name, own_group('aineo_changes_commits_scroll'))
    local to_wipe = vim.tbl_keys(shown_diffs)
    table.insert(to_wipe, buffers.files)
    table.insert(to_wipe, buffers.commits)
    for _, buffer in ipairs(to_wipe) do
      if vim.api.nvim_buf_is_valid(buffer) then
        vim.api.nvim_buf_delete(buffer, { force = true })
      end
    end
    shown_diffs, buffers = {}, {}
  end
  if label then
    home.let_go = let_go
  end

  return home
end

return M
