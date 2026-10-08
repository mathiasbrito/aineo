--- The changes pane's content, `require('aineo.changes')`: the session's
--- base, its files changed since — the user's saves marked — and its
--- commits, each listed in a buffer of the pane, then each other worktree
--- of its repository's files and commits since that worktree's own base
--- (`aineo.changes.worktrees`), and read again as the repository changes
--- once the pane has been shown. Once told which Claude Code session the
--- pane is for, the base and the saves are that session's, kept under the
--- editor's state directory (`aineo.changes.kept`).

local git = require('aineo.git')
local diffs = require('aineo.changes.diffs')
local kept = require('aineo.changes.kept')
local lines = require('aineo.changes.lines')
local pages = require('aineo.changes.pages')
local scratch = require('aineo.changes.scratch')
local serial = require('aineo.changes.serial')
local worktrees = require('aineo.changes.worktrees')

local M = {}

--- What the composition root hands the home as the session begins.
---@class aineo.changes.SessionSettings
---@field directory string the directory whose repository the session is about: Claude Code's working directory at its first start
---@field show_diff fun(diff: integer): integer|nil shows `diff` in the middle column, the cursor left where it is, and returns its window, or nil when there is no room
---@field git? aineo.git.WatchOptions how the git home runs git; its defaults when not given

--- The session, from `M.begin_session()` on.
---@class aineo.changes.Session
---@field settings aineo.changes.SessionSettings
---@field repository? aineo.git.Repository
---@field absence? aineo.git.Failure why no repository was found for the directory, while none is
---@field base? string
---@field followed? aineo.changes.FollowedSession the Claude Code session the pane is for, once the home is told one
---@field keeps_followed? boolean whether the base and the saves are kept for the session followed: not when what was kept for it is another repository's or cannot be read, which is never written over
---@field looking_for_head? boolean whether git looks for `HEAD`, the base of the session followed, while it runs
---@field head_look_failed? boolean whether the last look for the base of the session followed failed
---@field keeping_failure_told? boolean whether the user was told that the base and the saves could not be kept
---@field keeping_failed? boolean whether the last write of the base and the saves of the session followed failed
---@field changes? aineo.git.Change[] the files changed since the base, as last read
---@field files_failure? aineo.git.Failure why the last read of the files failed, when it did
---@field commits? aineo.git.CommitsSince the commits since the base, as last read
---@field commits_failure? aineo.git.Failure why the last read of the commits failed, when it did
---@field files_others aineo.changes.OtherWorktrees what the files window knows of the other worktrees
---@field commits_others aineo.changes.OtherWorktrees what the commits window knows of the other worktrees
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
--- session again brings them back: held for the editor's life when what
--- was kept for it is another repository's or cannot be read, and until a
--- write of them succeeds when their write failed (`hold_unkept_base()`).
---@type table<string, { base: string|nil, saved: table<string, true>, keeps: boolean|nil }>
local held_bases = {}

--- The pane's buffers, by window.
---@type { files: integer|nil, commits: integer|nil }
local buffers = {}

--- The files window's page for what the session knows: why it has no
--- repository, when it has none, or its files.
---
---@return aineo.changes.Page
local function files_page()
  if session.absence then
    return lines.no_repository(session.absence, session.settings.directory)
  end
  return lines.files_window({
    changes = session.changes,
    failure = session.files_failure or session.watch_failure,
    saved = session.saved,
    unwatched_subdirectories = session.watch ~= nil and not session.watch.watches_subdirectories,
    worktrees = session.files_others,
  })
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
    since = session.commits,
    base = session.base,
    failure = session.commits_failure or session.watch_failure,
    worktrees = session.commits_others,
  })
end

--- Whether `buffer`, a buffer of the pane once made, can be written: it is
--- loaded. One wiped, or unloaded as `:bdelete` unloads it, is made anew
--- and written the next time the pane is shown (`M.pane_buffers()`).
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
--- the session knows then.
---
---@param buffer integer|nil
---@param page fun(): aineo.changes.Page
local function show_page(buffer, page)
  if not (session and is_writable(buffer)) then
    return
  end
  if pages.write_page(buffer, page()) or refused[buffer] then
    return
  end
  refused[buffer] = true
  vim.api.nvim_create_autocmd('SafeState', {
    once = true,
    desc = 'aineo: write the changes pane once the editor allows it',
    callback = function()
      refused[buffer] = nil
      show_page(buffer, page)
    end,
  })
end

--- Writes the files buffer for what the session knows (`files_page()`,
--- `show_page()`).
local function show_files()
  show_page(buffers.files, files_page)
end

--- Writes the commits buffer for what the session knows (`commits_page()`,
--- `show_page()`).
local function show_commits()
  show_page(buffers.commits, commits_page)
end

--- Whether the session's base is the one a read was asked from: not once
--- the session has another, nor while it looks for one
--- (`M.follow_changes_session()`).
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
---@field read_list aineo.changes.ReadList asks git for another worktree's list
---@field others_field 'files_others'|'commits_others' the field of the session that keeps what the window knows of the other worktrees
---@field show fun() writes the window for what the session knows

--- Returns the function that asks for one read of a window as `reads`
--- describes it, one read at a time (`aineo.changes.serial`): the editor's
--- own list from the session's base, when asked with `with_own`, kept and
--- shown as soon as git answers, then the other worktrees' (`aineo.changes.
--- worktrees`), shown once all are read, when the window shows any of them,
--- or did. A read asked for with the editor's own list while another runs
--- reads it after. The editor's own list is not read while the session
--- looks for its base, and an answer for a base that is no longer current
--- (`is_current_base()`) is dropped, the read for the new one asked for
--- already. The other worktrees' read starts before the editor's own list
--- is shown, so that an error showing it stops no read, and the read ends
--- before the other worktrees' are shown.
---
---@param reads aineo.changes.WindowReads
---@return fun(with_own: boolean) ask
local function window_read(reads)
  local own_asked = false
  local ask = serial.one_at_a_time(function(ended)
    local with_own = own_asked
    own_asked = false
    local function read_others()
      local before = session[reads.others_field]
      worktrees.read_other_worktrees({
        found = session.repository,
        before = before,
        read_list = reads.read_list,
        git = session.settings.git,
      }, function(others)
        session[reads.others_field] = others
        ended()
        if shows_any(before) or shows_any(others) then
          reads.show()
        end
      end)
    end
    local base = session.base
    if not (with_own and is_current_base(base)) then
      read_others()
      return
    end
    reads.read_own(base, function(failure, answer)
      if not is_current_base(base) then
        read_others()
        return
      end
      reads.take_own(failure, answer)
      read_others()
      reads.show()
    end)
  end)
  return function(with_own)
    own_asked = own_asked or with_own
    ask()
  end
end

--- Reads the files changed since the base, and those of each other
--- worktree since its own, and shows them (`window_read()`).
local read_files = window_read({
  read_own = function(base, done)
    git.changed_files(session.repository, base, done, session.settings.git)
  end,
  take_own = function(failure, changes)
    session.changes = changes or session.changes
    session.files_failure = failure
  end,
  read_list = function(repository, base, done)
    git.changed_files(repository, base, done, session.settings.git)
  end,
  others_field = 'files_others',
  show = show_files,
})

--- Reads the commits since the base, and those of each other worktree
--- since its own, and shows them (`window_read()`).
local read_commits = window_read({
  read_own = function(base, done)
    git.commits_since(session.repository, base, done, session.settings.git)
  end,
  take_own = function(failure, commits)
    session.commits = commits or session.commits
    session.commits_failure = failure
  end,
  read_list = function(repository, base, done)
    git.commits_since(repository, base, done, session.settings.git)
  end,
  others_field = 'commits_others',
  show = show_commits,
})

--- Reads again what `change`, a call of the watch, may have changed: the
--- other worktrees' files and commits at every call, as a commit in one of
--- them moves no branch of the editor's; the editor's own files when they
--- may differ, and its commits and files when its branch moved.
---
---@param change aineo.git.RepositoryChange
local function follow_change(change)
  read_files(change.files_changed or change.branch_moved)
  read_commits(change.branch_moved)
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
  local started, failure = git.watch_repository(session.repository, function(change_failure, change)
    if change_failure then
      watch_failed(change_failure)
    else
      follow_change(change)
    end
  end, session.settings.git)
  session.watch = started
  if failure then
    watch_failed(failure)
  else
    session.watch_failure = nil
  end
end

--- Starts what follows the repository once the pane has been shown: the
--- watch, when none runs, and a read of each list; does nothing before the
--- repository is found or the pane first shown, nor once the editor is
--- quitting (`v:exiting`): a look answered then, while a later
--- `VimLeavePre` waits, starts no watch and no read after the quit has
--- stopped the watch.
local function follow_repository()
  if not (session.repository and session.shown) or vim.v.exiting ~= vim.NIL then
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
--- they are read, each window says aineo is reading the repository.
local function read_for_new_base()
  session.changes, session.files_failure = nil, nil
  session.commits, session.commits_failure = nil, nil
  show_files()
  show_commits()
  follow_repository()
end

--- Writes the session's base and saves for `followed`, the Claude Code
--- session the pane follows (`aineo.changes.kept`). A write that fails is
--- told once, as a warning, for the editor's life; the pane goes on from
--- what it holds.
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
  if failure and not session.keeping_failure_told then
    session.keeping_failure_told = true
    vim.notify(
      ("aineo: the changes pane cannot keep this session's base and saves, and goes on without: %s"):format(
        failure
      ),
      vim.log.levels.WARN
    )
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

--- Looks for the repository of the session's directory, one look at a time
--- (`aineo.changes.serial`). The first found is the session's for the
--- editor's life: its `HEAD` is the base — or the base kept for the Claude
--- Code session the pane follows, when one was kept for this repository
--- (`use_kept_base()`), `HEAD` being kept for it when nothing was — the saves
--- count from then — those made while the first look ran included — and it
--- is followed once the pane has been shown (`follow_repository()`). While
--- none is found, both windows say why. Each look is ended before what it
--- found is followed and shown, as `read_files()`'s.
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
      for _, file in ipairs(session.early_saves) do
        mark_saved(file)
      end
    end
    session.early_saves = {}
    ended()
    follow_repository()
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
--- — not from the directory `M.begin_session()` was given, which may since
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
--- session (`M.follow_changes_session()`), and marks the files the user
--- saves from then on (`note_save()`). The session lasts the editor's
--- life: once begun, a call does nothing, as a restart of Claude Code calls
--- it again.
---
---@param settings aineo.changes.SessionSettings
function M.begin_session(settings)
  if session then
    return
  end
  session = {
    settings = settings,
    followed = followed_before_beginning,
    shown = false,
    following_soon = false,
    saved = {},
    early_saves = {},
    files_others = worktrees.NONE,
    commits_others = worktrees.NONE,
  }
  local group = vim.api.nvim_create_augroup('aineo_changes', {})
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

--- Makes the changes pane the Claude Code session `followed`'s, its
--- buffers written for it and its lists read again: the base and the saves
--- this editor held for it, when it followed it before and could not keep
--- them (`use_held_base()`); else those kept for it in this repository,
--- read back; else, for a session with nothing kept, `HEAD` at this moment
--- in the session's repository and no saves, both kept from then on
--- (`take_head()`) — unless another editor keeps a base for it first, which
--- the pane then takes (`keep()`); else — what was kept for it is another
--- repository's, or cannot be read — `HEAD` and no saves too, held in
--- memory for the editor's life, what was kept left as it was. Following the session
--- already followed does nothing. Told before the session has begun, or
--- before its repository is found, the home holds the session and takes
--- its base once the repository is found (`find`); while no repository is
--- found, nothing is kept. Called on the main loop only: from a fast event
--- (a `vim.uv` callback) it raises E5560, as the Vimscript functions it
--- calls do there.
---
---@param followed aineo.changes.FollowedSession
function M.follow_changes_session(followed)
  if not session then
    followed_before_beginning = followed
    return
  end
  if session.followed and session.followed.id == followed.id then
    return
  end
  hold_unkept_base()
  session.followed = followed
  session.looking_for_head, session.head_look_failed, session.keeping_failed = false, false, false
  if not session.repository then
    return
  end
  if use_held_base() or use_kept_base() then
    read_for_new_base()
    return
  end
  take_head()
end

--- The name of the buffer showing `entry`'s diff: `aineo://diff/<path>` for
--- a file, its path quoted as the files window shows it, and
--- `aineo://commit/<id>` for a commit, by its full id; for an entry of
--- another worktree, `aineo://worktree<top>/diff/<path>` and
--- `aineo://worktree<top>/commit/<id>`, the worktree's top level quoted too,
--- so that two worktrees' diffs of one path are two buffers.
---
---@param entry aineo.changes.Entry
---@return string
local function diff_name(entry)
  local diff = entry.commit and 'commit/' .. entry.commit.id
    or 'diff/' .. lines.quoted_path(entry.change.path)
  if entry.worktree then
    return ('aineo://worktree%s/%s'):format(lines.quoted_path(entry.worktree.top), diff)
  end
  return 'aineo://' .. diff
end

--- What the diff of `entry` is called in what aineo tells the user: the
--- diff of the file's path, quoted as the files window shows it, or of the
--- commit's abbreviated id.
---
---@param entry aineo.changes.Entry
---@return string
local function told_name(entry)
  if entry.commit then
    return 'commit ' .. entry.commit.id:sub(1, lines.ABBREVIATED_ID_LENGTH)
  end
  return lines.quoted_path(entry.change.path)
end

--- Shows `diff`, the text git printed for `entry`, in a diff buffer named
--- for it (`diff_name()`, `aineo.changes.diffs`) through the session's
--- `show_diff`. When the middle column has no room for it, the buffer is
--- wiped and the user warned, once; when showing it raises an error, the
--- buffer is wiped and the user told the error, once. Returns false, having
--- told nothing, when Neovim refuses for now the diff buffer its text, as it
--- does while textlock holds, or the wipe of a diff it did not show, as it
--- does while textlock holds and in the command-line window, where a window
--- refuses the diff too (`aineo.changes.scratch`' `wipe()`): the buffer is
--- then kept, shown nowhere, for the next call to show. Returns true
--- otherwise.
---
---@param entry aineo.changes.Entry
---@param diff string
---@return boolean allowed
local function show_diff(entry, diff)
  local buffer = diffs.diff_buffer(diff_name(entry), diff)
  if not buffer then
    return false
  end
  local shown, window = pcall(session.settings.show_diff, buffer)
  if shown and window then
    return true
  end
  if not scratch.wipe(buffer) then
    return false
  end
  if not shown then
    vim.notify(
      ('aineo: the diff of %s could not be shown: %s'):format(told_name(entry), tostring(window)),
      vim.log.levels.ERROR
    )
    return true
  end
  vim.notify(
    ('aineo: the middle column has no room for the diff of %s, which is not shown'):format(
      told_name(entry)
    ),
    vim.log.levels.WARN
  )
  return true
end

--- Reads the diff of `entry` — a file's from the base, or a commit's — and
--- calls `done(failure, diff)`: in the session's repository from its base,
--- or, for an entry of another worktree, in that worktree from the base its
--- list was read from.
---
---@param entry aineo.changes.Entry
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
local function read_diff(entry, done)
  local repository, base = session.repository, session.base
  if entry.worktree then
    repository, base = entry.worktree.repository, entry.worktree.base
  end
  if entry.commit then
    git.commit_diff(repository, entry.commit.id, done, session.settings.git)
  else
    git.file_diff(repository, base, entry.change, done, session.settings.git)
  end
end

--- How many times Enter has asked for a diff (`open_entry()`).
local enters = 0

--- Shows `diff`, the diff of `entry` the Enter numbered `this_enter` read
--- (`show_diff()`), while that Enter is the last. A diff Neovim refused for
--- now, as it does while textlock holds and, for a diff it cannot show, in
--- the command-line window, is shown at the editor's next `SafeState`,
--- if that Enter is the last still; otherwise the buffer made for it, shown
--- nowhere, is wiped (`aineo.changes.diffs`' `wipe_unshown()`), at the next
--- `SafeState` again while Neovim refuses the wipe.
---
---@param this_enter integer
---@param entry aineo.changes.Entry
---@param diff string
local function show_last_diff(this_enter, entry, diff)
  if this_enter ~= enters then
    if diffs.wipe_unshown(diff_name(entry)) then
      return
    end
  elseif show_diff(entry, diff) then
    return
  end
  vim.api.nvim_create_autocmd('SafeState', {
    once = true,
    desc = 'aineo: show the diff Enter read once the editor allows it',
    callback = function()
      show_last_diff(this_enter, entry, diff)
    end,
  })
end

--- Reads the diff of the entry the line under the cursor lists in `buffer`
--- (`read_diff()`) and shows it (`show_last_diff()`), unless Enter asked for
--- another diff meanwhile: only the last Enter's diff is shown, or its
--- failure told. Does nothing on a line that lists none.
---
---@param buffer integer
local function open_entry(buffer)
  local entry = pages.entry_at(buffer, vim.api.nvim_win_get_cursor(0)[1])
  if not entry then
    return
  end
  enters = enters + 1
  local this_enter = enters
  read_diff(entry, function(failure, diff)
    if this_enter ~= enters then
      return
    end
    if failure then
      vim.notify(
        ('aineo: the diff of %s could not be read: %s'):format(
          told_name(entry),
          lines.words_of(failure)
        ),
        vim.log.levels.ERROR
      )
      return
    end
    show_last_diff(this_enter, entry, diff)
  end)
end

--- A scratch buffer of the pane named `name` (`aineo.changes.scratch`),
--- written with `page()` whenever it is made or read, which tells the
--- session the pane is shown whenever it enters a window (`pane_shown()`).
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
  return buffer
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
function M.refresh_shown_pane()
  if is_shown(buffers.files) or is_shown(buffers.commits) then
    pane_shown()
  end
end

--- The changes pane's two buffers, each written for what the session
--- knows: the files buffer, `aineo://changes-files`, and the commits
--- buffer, `aineo://changes-commits`. Each is a scratch buffer, not
--- modifiable, made once and made anew once it is no longer loaded — wiped,
--- or unloaded, as `:bdelete` unloads it — taking its name from any buffer
--- holding it; `:edit` and `:edit!` write it again. Whenever either enters
--- a window, the pane is shown: the first time, the watch starts, and each
--- time both lists are read again, once for every showing in one turn of
--- the main loop (`pane_shown()`).
---
---@return { files: integer, commits: integer }
function M.pane_buffers()
  if not (buffers.files and vim.api.nvim_buf_is_loaded(buffers.files)) then
    buffers.files = pane_buffer('aineo://changes-files', files_page)
  end
  if not (buffers.commits and vim.api.nvim_buf_is_loaded(buffers.commits)) then
    buffers.commits = pane_buffer('aineo://changes-commits', commits_page)
  end
  return { files = buffers.files, commits = buffers.commits }
end

return M
