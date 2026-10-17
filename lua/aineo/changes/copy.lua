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
local head_diff = require('aineo.changes.head_diff')
local kept = require('aineo.changes.kept')
local landed = require('aineo.changes.landed')
local lines = require('aineo.changes.lines')
local open_file = require('aineo.changes.open_file')
local pages = require('aineo.changes.pages')
local pause = require('aineo.changes.pause')
local scope = require('aineo.changes.scope')
local scratch = require('aineo.changes.scratch')
local serial = require('aineo.changes.serial')
local worktrees = require('aineo.changes.worktrees')

local M = {}

--- How long the cursor must stay in the commits window before the files
--- window is read for the line under it.
local SELECTION_PAUSE_MS = 150

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

--- A changes home, whose functions are called as fields, never as methods.
---@class aineo.changes.Home
---@field begin_session fun(settings: aineo.changes.SessionSettings)
---@field follow_changes_session fun(followed: aineo.changes.FollowedSession)
---@field hand_over_changes_session fun(hand_over: aineo.changes.HandOver)
---@field refresh_shown_pane fun()
---@field toggle_focused_view fun() reads the shown pane again, and, with the cursor in one of its windows, switches it between its default view and the focused view
---@field add_reported_work fun(work: aineo.changes.ReportedWork, tell: fun(message: string)): boolean whether the home took the report
---@field pane_buffers fun(): { files: integer, commits: integer }
---@field close_shown_diff fun() closes the windows of the current tab page that show a diff the home showed, and tells once when none was closed
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
  ---@field start_timer? fun(milliseconds: integer, act: fun()): fun() starts a timer that runs `act` once, on the main loop, after `milliseconds`, and returns what stops it; a `vim.uv` timer when not given

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
  ---@field focused boolean whether the commits window shows the focused view — the scope alone, or the reported set — in place of the default view; false while there is neither
  ---@field reported aineo.changes.ScopeMember[] the reported set: the worktrees and branches the agents of the tab's Claude Code reported and git listed, each once, in the order first reported
  ---@field shows_reported boolean whether the focused view is the reported set, chosen last, rather than the scope
  ---@field waiting aineo.changes.WaitingReport[] the reports git did not list yet, each matched again at every read until its timer lets it go
  ---@field kept_view? aineo.changes.KeptView the view as last kept for the session followed, or as it was when the pane began following it; nil until the pane follows a session in a repository it found, and while it follows none
  ---@field restoring_view? boolean whether the view kept for the session followed is being read back, which keeps what the pane shows from being kept over it
  ---@field saved table<string, true> the files the user saved under the base, by path relative to the top level: since the session began, or the Claude Code session's followed; none saved while no repository was found
  ---@field early_saves string[] the files the user saved, resolved, while the first look for the repository runs
  ---@field shown boolean whether the pane has been shown
  ---@field following_soon boolean whether the pane's showing is followed at the main loop's next turn
  ---@field watch? aineo.git.Watch the running watch, from the pane's first showing; nil once it failed
  ---@field watch_failure? aineo.git.Failure why the watch failed, until one starts again

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
    })
  end

  --- What the commits window shows alone while the focused view is the one
  --- shown: the reported set, when it is the focused view, each member as
  --- the commits window last read it; else the worktree or branch of the
  --- session's scope; nil for the default view.
  ---
  ---@return aineo.changes.ScopeMember[]|nil
  local function scope_shown()
    if not session.focused then
      return nil
    end
    if session.shows_reported then
      return scope.members_reported(session.reported, session.commits_others)
    end
    if not session.scope then
      return nil
    end
    return scope.members_shown(session.scope, session.commits_others, session.branch)
  end

  --- The commits window's page for what the session knows: why it has no
  --- repository, when it has none, or its commits.
  ---
  ---@return aineo.changes.Page
  local function commits_page()
    if session.absence then
      return lines.no_repository(session.absence, session.settings.directory)
    end
    return lines.commits_window({
      scope = scope_shown(),
      since = session.commits,
      base = session.base,
      failure = session.commits_failure or session.watch_failure,
      lists_filters = session.repository ~= nil,
      landed = session.landed,
      worktrees = session.commits_others,
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

  --- Writes the files buffer for what the session knows (`files_page()`,
  --- `show_page()`).
  local function show_files()
    show_page(buffers.files, files_page)
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
      reported = session.reported,
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

  --- Writes the commits buffer for what the session knows (`commits_page()`,
  --- `show_page()`), then puts the cursor on the selected filter's line when
  --- it is still to be put there (`place_commits_cursor()`), and keeps the
  --- view the page shows (`keep_view()`): every change of the view is
  --- shown here.
  local function show_commits()
    show_page(buffers.commits, commits_page, place_commits_cursor)
    keep_view()
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
  --- branch the scope names, or of a branch of the reported set; nil while
  --- it has read none.
  ---
  ---@param name string|nil
  ---@return aineo.changes.BranchSection|nil
  local function branch_named(name)
    if session.branch and session.branch.name == name then
      return session.branch
    end
    for _, member in ipairs(session.reported) do
      local read = member.branch
      if read and read.name == name and (read.tip ~= nil or read.failure ~= nil) then
        return member.branch
      end
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
  --- (`place_commits_cursor()`).
  ---
  ---@param selected aineo.changes.Filter
  local function select_filter(selected)
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
  --- while the reported set is the focused view, which stays, the scope
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
  --- (`aineo.changes.scope`) — but while the reported set is the focused
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
      working_branch = session.settings.working_branch,
      git = session.settings.git,
    }, function(read)
      take_branch(read)
      done(true)
    end)
  end

  --- Reads, one after another, each branch of the reported set
  --- (`aineo.changes.branch`) and keeps what was read in its member, then
  --- calls `done(read)`, whether there was any to read.
  ---
  ---@param done fun(read: boolean)
  local function read_reported_branches(done)
    local members = vim.tbl_filter(function(member)
      return member.branch ~= nil
    end, session.reported)
    local function read_from(index)
      local member = members[index]
      if not member then
        done(#members > 0)
        return
      end
      branch.read({
        found = session.repository,
        name = member.branch.name,
        before = member.branch,
        working_branch = session.settings.working_branch,
        git = session.settings.git,
      }, function(read)
        local before = member.branch
        member.branch = read
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

  --- Reads what reports are matched against and matches them; made below,
  --- as it adds what it matches to the reported set and reads the commits
  --- window again for it.
  ---@type fun(done?: fun())
  local read_reported

  --- What the commits window reads after the other worktrees: the branch
  --- the scope names (`read_branch_scope()`), then the reported set's
  --- branches (`read_reported_branches()`), then, while a report waits,
  --- what reports are matched against (`read_reported()`); calls
  --- `done(read)`, whether any of these read anything the window shows.
  ---
  ---@param done fun(read: boolean)
  local function read_scope_and_reported(done)
    read_branch_scope(function(read_pick)
      read_reported_branches(function(read_reported_any)
        if #session.waiting == 0 and #session.reported == 0 then
          done(read_pick or read_reported_any)
          return
        end
        read_reported(function()
          done(true)
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
  --- names one, and the reported set's branches, are read after the
  --- worktrees, and the reports matched again (`read_scope_and_reported()`).
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
    took_others = reselect_in_worktrees,
    read_scope = read_scope_and_reported,
    show = show_commits,
  })

  --- Reads again what `change`, a call of the watch, may have changed: the
  --- other worktrees' commits at every call, as a commit in one of them
  --- moves no branch of the editor's, and their files when the files window
  --- lists one's whole change; the editor's own files when they may differ,
  --- and its commits and files when its branch moved; the editor's own
  --- commits and what landed in the working branch when a reference was
  --- written, as a fetch does.
  ---
  ---@param change aineo.git.RepositoryChange
  local function follow_change(change)
    read_files(change.files_changed or change.branch_moved)
    read_commits(change.branch_moved or change.references_changed)
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
  --- watch, when none runs, and a read of each list; does nothing before the
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
      and #session.reported == 0
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
    local current = { focused = false, shows_reported = false, reported = {} }
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
      local restored = scope.restored_view(on_disk, candidates)
      session.scope, session.focused = restored.scope, restored.focused
      session.reported, session.shows_reported = restored.reported, restored.shows_reported
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
      reported = {},
      shows_reported = false,
      waiting = {},
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
  --- before clears the scope and empties the reported set, the reports
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
      session.reported, session.shows_reported = {}, false
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

  --- Records that `buffer` holds the diff of `entry` read in `context`, and
  --- maps F in it, in Normal mode, to read that diff again in the other context
  --- (`reread_diff()`); the buffers of diffs since wiped are forgotten.
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

  --- Reads the diff of `diffed(listed)`, `listed` the entry the line under the
  --- cursor lists in `buffer` (`aineo.changes.entry_diff`), and shows it
  --- (`show_last()`), the cursor moving to it as `moving_cursor_of` says
  --- (`aineo.changes.Selection`), unless a key asked for another diff or
  --- file meanwhile: only the last key's is shown, or its failure told. A
  --- diff against `HEAD` that is empty is not shown: the user is told, once,
  --- that the file is as `HEAD` has it, and the focus stays. On the heading of
  --- a branch the commits window has not read yet, tells the user, at `INFO`,
  --- that aineo is reading the repository, and reads nothing. Does nothing on
  --- a line that lists none.
  ---
  ---@param buffer integer
  ---@param diffed fun(listed: aineo.changes.Entry): aineo.changes.Entry the entry standing for the diff to show
  ---@param moving_cursor_of fun(pressed_in: integer): integer|nil the window whose cursor moves to the diff, given the window the key was pressed in (`cursor_follows_the_key()`, `cursor_stays()`)
  local function show_diff_at_cursor(buffer, diffed, moving_cursor_of)
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
          vim.notify(head_diff.told_unchanged(entry), vim.log.levels.INFO)
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
    show_diff_at_cursor(buffer, as_listed, cursor_follows_the_key)
  end

  --- Shows the diff of the file the line under the cursor lists in `buffer`
  --- against its previous version, the cursor staying in the pane
  --- (`show_diff_at_cursor()`).
  ---
  ---@param buffer integer
  local function preview_entry(buffer)
    show_diff_at_cursor(buffer, as_listed, cursor_stays)
  end

  --- Shows the diff of the file the line under the cursor lists in `buffer`
  --- against `HEAD` (`aineo.changes.head_diff`), the cursor staying in the
  --- pane.
  ---
  ---@param buffer integer
  local function preview_entry_against_head(buffer)
    show_diff_at_cursor(buffer, head_diff.of, cursor_stays)
  end

  --- Shows, in the middle column, the file `entry` lists as the commit it is
  --- listed under has it (`aineo.changes.commit_file`), read-only, in a buffer
  --- named for the commit and the file (`aineo.changes.diffs`' `file_buffer()`),
  --- the current window kept as the one the key was pressed in, unless a key
  --- asked for another diff or file meanwhile: only the last key's is shown,
  --- or its failure told, once, naming the file.
  ---
  ---@param entry aineo.changes.Entry an entry for which `commit_file.lists_file_at_a_commit()` holds
  local function show_commit_file(entry)
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

  --- Maps `gf` in `buffer`, the files buffer, in Normal mode, to open the
  --- file the line under the cursor lists (`open_file_at_cursor()`).
  ---
  ---@param buffer integer
  local function map_open_file(buffer)
    vim.keymap.set('n', 'gf', function()
      open_file_at_cursor(buffer)
    end, { buffer = buffer, desc = 'aineo: open the file of the entry under the cursor' })
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

  --- Shows the worktree `item` names alone, and chooses its whole change
  --- (`select_filter()`), which the files window then lists. A worktree the
  --- commits window no longer lists is told gone, and nothing changes.
  ---
  ---@param item aineo.changes.ScopeItem
  local function show_worktree_alone(item)
    local section = scope.section_on(session.commits_others, item.top)
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

  --- A report git has not listed yet, and how the user is told of it.
  ---@class aineo.changes.WaitingReport
  ---@field work aineo.changes.ReportedWork
  ---@field tell fun(message: string) tells the user, as the tab the report is for says it
  ---@field stop_timer fun() stops the timer that lets the report go

  --- Adds `member` to the reported set, unless it is there already: the set
  --- becomes the focused view, shown at once, `member`'s whole change
  --- chosen, the cursor on its heading, and the user is told once with
  --- `tell`. The other worktrees are read again while the pane has been
  --- shown, so that `member`'s commits show.
  ---
  ---@param member aineo.changes.ScopeMember
  ---@param tell fun(message: string)
  local function add_member(member, tell)
    local key = scope.member_key(member)
    for _, listed in ipairs(session.reported) do
      if scope.member_key(listed) == key then
        return
      end
    end
    table.insert(session.reported, member)
    session.shows_reported, session.focused = true, true
    select_filter(
      scope.whole_change_of(scope.members_reported({ member }, session.commits_others)[1])
    )
    show_commits()
    read_files(true)
    if session.shown then
      read_commits(false)
    end
    tell(scope.started_work(member))
  end

  --- Keeps of the reported set what `candidates`, what git now lists, still
  --- lists (`scope.still_listed()`), telling nothing of a member dropped.
  --- Once the set is empty, the focused view is the scope again, when there
  --- is one; and when the set was the view shown, the default view shows,
  --- chosen again for what it lists, and the user is told once.
  ---
  ---@param candidates aineo.changes.BranchCandidates
  local function keep_reported_listed_in(candidates)
    local still = scope.still_listed(session.reported, candidates)
    local dropped = #still < #session.reported
    session.reported = still
    if not dropped then
      return
    end
    if #still == 0 and session.shows_reported then
      session.shows_reported = false
      if session.focused then
        session.focused = false
        vim.notify(scope.REPORTED_GONE, vim.log.levels.INFO)
      end
    end
    choose_for_shown_view()
    show_commits()
  end

  --- Resolves, off the main loop, the path of each report of `waitings` that
  --- has one, every link in it followed (`vim.uv.fs_realpath()` with a
  --- callback, so that a path under a mount that does not answer holds no
  --- keystroke), and calls `done(real_paths)` on the main loop once all
  --- have answered: each report's real path, none for a path that resolves
  --- to nothing.
  ---
  ---@param waitings aineo.changes.WaitingReport[]
  ---@param done fun(real_paths: table<aineo.changes.WaitingReport, string>)
  local function resolve_real_paths(waitings, done)
    local real_paths = {}
    local with_paths = vim.tbl_filter(function(waiting)
      return waiting.work.path ~= nil
    end, waitings)
    local pending = #with_paths
    if pending == 0 then
      done(real_paths)
      return
    end
    for _, waiting in ipairs(with_paths) do
      vim.uv.fs_realpath(waiting.work.path, function(_, real_path)
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

  --- Matches each report still waiting against `candidates`, what git now
  --- lists of the worktrees and the branches (`scope.match_report()`): a
  --- match joins the reported set (`add_member()`), the editor's own work is
  --- let go untold, each with its timer stopped, and anything else waits on.
  --- A worktree's report is compared by `real_paths`, its path with every
  --- link resolved; one with none there, as one made since they were
  --- resolved, waits on.
  ---
  ---@param candidates aineo.changes.BranchCandidates
  ---@param real_paths table<aineo.changes.WaitingReport, string> `resolve_real_paths()`
  local function take_reported(candidates, real_paths)
    keep_reported_listed_in(candidates)
    local still_waiting = {}
    for _, waiting in ipairs(session.waiting) do
      local real_path = real_paths[waiting]
      local matched =
        scope.match_report(waiting.work, real_path, candidates, session.repository.top)
      if not matched then
        table.insert(still_waiting, waiting)
      else
        waiting.stop_timer()
        if matched ~= scope.OWN_WORK then
          add_member(matched, waiting.tell)
        end
      end
    end
    session.waiting = still_waiting
  end

  --- Lets `waiting` go, once its time to wait is over, when it still waits,
  --- and tells the user once that git does not list what it reported.
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
    waiting.tell(scope.unlisted_report(waiting.work))
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

  --- Takes `work`, a worktree or a branch an agent of the tab's Claude Code
  --- reported, to be told with `tell`, and starts at once a read of the
  --- worktrees and the branches, whether or not the pane shows or was ever
  --- shown (`read_reported()`). What git does not list yet waits, matched
  --- again at every read of the commits window, for `REPORT_WAIT_MS` from
  --- the call, then is let go (`let_report_go()`). Returns whether the home
  --- took it: a report the same as one waiting is taken, reads again and
  --- adds nothing; one more than `MOST_WAITING` distinct reports waiting is
  --- not taken, nor is any before the session has begun, and nothing is
  --- told of either.
  ---
  ---@param work aineo.changes.ReportedWork
  ---@param tell fun(message: string)
  ---@return boolean taken
  function home.add_reported_work(work, tell)
    if not session then
      return false
    end
    local waits_already = vim.iter(session.waiting):any(function(other)
      return other.work.kind == work.kind
        and other.work.path == work.path
        and other.work.branch == work.branch
    end)
    if waits_already then
      read_reported()
      return true
    end
    if #session.waiting >= MOST_WAITING then
      return false
    end
    local waiting = { work = work, tell = tell }
    local start_timer = session.settings.start_timer or start_uv_timer
    waiting.stop_timer = start_timer(REPORT_WAIT_MS, function()
      let_report_go(waiting)
    end)
    table.insert(session.waiting, waiting)
    read_reported()
    return true
  end

  --- Makes the reported set the focused view again, shown at once, its first
  --- member's whole change chosen; the scope picked, if any, is kept behind
  --- it. A set emptied since the picker opened changes nothing.
  local function show_reported()
    if #session.reported == 0 then
      return
    end
    session.shows_reported, session.focused = true, true
    select_filter(scope.whole_change_of(scope_shown()[1]))
    show_commits()
    read_files(true)
  end

  --- Opens `vim.ui.select` on `items`, what `s` offers
  --- (`aineo.changes.scope`); a pick is shown alone (`show_worktree_alone()`,
  --- `show_branch_alone()`) or the reported set (`show_reported()`), an
  --- answer that is no item offered is ignored.
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
    }, function(item)
      if type(item) ~= 'table' then
        return
      end
      if type(item.top) == 'string' then
        show_worktree_alone(item)
      elseif type(item.branch) == 'string' then
        show_branch_alone(item)
      elseif item.reported == true then
        show_reported()
      end
    end)
    if not asked then
      vim.notify(scope.picker_failed(failure), vim.log.levels.ERROR)
    end
  end

  --- Whether `s` is reading what it offers: a second press waits for the
  --- first.
  local offering = false

  --- Offers the other worktrees the commits window last listed and the local
  --- branches no worktree has checked out (`pick_among()`), the branches read
  --- when `s` is pressed (`aineo.changes.branch`), off the main loop: the
  --- picker opens once they are. Branches that cannot be read leave the
  --- worktrees alone, the failure told once. While the session has no
  --- repository, or the other worktrees are unread or unlisted, tells why
  --- instead (`aineo.changes.scope`).
  local function offer_scopes()
    if not session then
      vim.notify(lines.READING, vim.log.levels.INFO)
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
      pick_among(scope.items_of(session.commits_others, candidates, session.reported))
    end)
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
      open_entry(buffer)
    end, { buffer = buffer, desc = 'aineo: show the diff of the entry under the cursor' })
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

  --- Selects the filter the line under the cursor of the window whose cursor
  --- last moved in the commits buffer lists, when it is a filter other than
  --- the selected one (`other_filter_at_cursor()`), and reads the files window
  --- for it.
  local function select_filter_at_cursor()
    local at_cursor = other_filter_at_cursor(window_moved)
    if not at_cursor then
      return
    end
    session.selected = at_cursor
    read_files(true)
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
  --- picked or the reported set, whichever was chosen last, kept while the
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
    local has_focused_view = session.scope ~= nil or #session.reported > 0
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
  --- its cursor to be put there when it is shown (`select_view_default()`).
  ---
  ---@return { files: integer, commits: integer }
  function home.pane_buffers()
    if not (buffers.files and vim.api.nvim_buf_is_loaded(buffers.files)) then
      buffers.files = pane_buffer(own_name('aineo://changes-files'), files_page)
      map_open_file(buffers.files)
      map_compare_keys(buffers.files)
    end
    if not (buffers.commits and vim.api.nvim_buf_is_loaded(buffers.commits)) then
      buffers.commits = pane_buffer(own_name('aineo://changes-commits'), commits_page)
      select_filters_from(buffers.commits)
      if session then
        select_view_default()
      end
    end
    return { files = buffers.files, commits = buffers.commits }
  end

  --- Lets the home go, as its tab page closes: stops its watch and closes the
  --- timer of the pause its commits window's cursor starts, removes its
  --- handlers, by deleting their groups (a group the home never made is no
  --- error), and wipes its pane's two buffers and the diffs it showed. The
  --- bases and the saves it kept on disk stay. Nothing follows its repository
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
