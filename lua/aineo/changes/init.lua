--- The changes pane's content, `require('aineo.changes')`: the session's
--- base, its files changed since — the user's saves marked — and its
--- commits, each listed in a buffer of the pane, and read again as the
--- repository changes once the pane has been shown.

local git = require('aineo.git')
local lines = require('aineo.changes.lines')
local pages = require('aineo.changes.pages')
local scratch = require('aineo.changes.scratch')
local serial = require('aineo.changes.serial')

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
---@field changes? aineo.git.Change[] the files changed since the base, as last read
---@field files_failure? aineo.git.Failure why the last read of the files failed, when it did
---@field commits? aineo.git.CommitsSince the commits since the base, as last read
---@field commits_failure? aineo.git.Failure why the last read of the commits failed, when it did
---@field saved table<string, true> the files the user saved since the base, by path relative to the top level
---@field shown boolean whether the pane has been shown
---@field watch? aineo.git.Watch the running watch, from the pane's first showing; nil once it failed
---@field watch_failure? aineo.git.Failure why the watch failed, until one starts again

---@type aineo.changes.Session|nil
local session = nil

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
  })
end

--- Writes the files buffer for what the session knows (`files_page()`).
local function show_files()
  if buffers.files and session then
    pages.write_page(buffers.files, files_page())
  end
end

--- Writes the commits buffer for what the session knows (`commits_page()`).
local function show_commits()
  if buffers.commits and session then
    pages.write_page(buffers.commits, commits_page())
  end
end

--- Reads the files changed since the base, and shows them; one read at a
--- time (`aineo.changes.serial`).
local read_files = serial.one_at_a_time(function(ended)
  git.changed_files(session.repository, session.base, function(failure, changes)
    session.changes = changes or session.changes
    session.files_failure = failure
    show_files()
    ended()
  end, session.settings.git)
end)

--- Reads the commits since the base, and shows them; one read at a time
--- (`aineo.changes.serial`).
local read_commits = serial.one_at_a_time(function(ended)
  git.commits_since(session.repository, session.base, function(failure, commits)
    session.commits = commits or session.commits
    session.commits_failure = failure
    show_commits()
    ended()
  end, session.settings.git)
end)

--- Reads again what `change`, a call of the watch, may have changed: the
--- files when they may differ, and the commits and the files when the
--- branch moved.
---
---@param change aineo.git.RepositoryChange
local function follow_change(change)
  if change.files_changed or change.branch_moved then
    read_files()
  end
  if change.branch_moved then
    read_commits()
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
--- repository is found or the pane first shown.
local function follow_repository()
  if not (session.repository and session.shown) then
    return
  end
  if not session.watch then
    watch()
  end
  read_files()
  read_commits()
end

--- Looks for the repository of the session's directory, one look at a time
--- (`aineo.changes.serial`). The first found is the session's for the
--- editor's life: its `HEAD` is the base, the saves count from then, and it
--- is followed once the pane has been shown (`follow_repository()`). While
--- none is found, both windows say why.
local find = serial.one_at_a_time(function(ended)
  git.find_repository(session.settings.directory, function(failure, repository)
    if not session.repository then
      session.absence = failure
      if repository then
        session.repository = repository
        session.base = repository.head
        follow_repository()
      end
      show_files()
      show_commits()
    end
    ended()
  end, session.settings.git)
end)

--- Looks for the repository again (`find`) when none was found.
local function look_again()
  if session.absence then
    find()
  end
end

--- Notes that the pane is shown, and follows the repository from then on
--- (`follow_repository()`), or looks for it again while there is none
--- (`look_again()`).
local function pane_shown()
  if not session then
    return
  end
  session.shown = true
  look_again()
  follow_repository()
end

--- `path` with every symbolic link it leads through resolved, or as it is
--- when it cannot be resolved.
---
---@param path string
---@return string
local function resolved(path)
  return vim.uv.fs_realpath(path) or path
end

--- Marks the file a save wrote, `written`, when it lies under the
--- repository's top level, both resolved — a file opened through a
--- symbolic link to the repository counts — and reads the files again once
--- the pane has been shown, whether the watch saw the save or not. While
--- there is no repository, the save marks nothing and aineo looks for one
--- again (`look_again()`).
---
---@param written string the written file's absolute path, as it was opened
local function note_save(written)
  if not session.repository then
    look_again()
    return
  end
  local top = resolved(session.repository.top) .. '/'
  local file = resolved(written)
  if not vim.startswith(file, top) then
    return
  end
  session.saved[file:sub(#top + 1)] = true
  if session.shown then
    read_files()
  end
end

--- Begins the session for `settings.directory`: finds its repository, whose
--- `HEAD` is the session's base, and marks the files the user saves from
--- then on.
---
---@param settings aineo.changes.SessionSettings
function M.begin_session(settings)
  session = { settings = settings, shown = false, saved = {} }
  vim.api.nvim_create_autocmd({ 'BufWritePost', 'FileWritePost', 'FileAppendPost' }, {
    group = vim.api.nvim_create_augroup('aineo_changes', {}),
    desc = 'aineo: mark a file saved in the changes pane',
    callback = function(event)
      note_save(event.match)
    end,
  })
  find()
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
  return buffer
end

--- The changes pane's two buffers, each written for what the session
--- knows: the files buffer, `aineo://changes-files`, and the commits
--- buffer, `aineo://changes-commits`. Each is a scratch buffer, not
--- modifiable, made once and made anew once it is no longer loaded — wiped,
--- or unloaded, as `:bdelete` unloads it — taking its name from any buffer
--- holding it; `:edit` and `:edit!` write it again. Whenever either enters
--- a window, the pane is shown: the first time, the watch starts, and each
--- time both lists are read again.
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
