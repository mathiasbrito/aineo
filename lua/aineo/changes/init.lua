--- The changes pane's content, `require('aineo.changes')`: the session's
--- base, its files changed since — the user's saves marked — and its
--- commits, each listed in a buffer of the pane, and read again as the
--- repository changes once the pane has been shown.

local git = require('aineo.git')
local lines = require('aineo.changes.lines')
local pages = require('aineo.changes.pages')
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
---@field base? string
---@field changes? aineo.git.Change[]
---@field commits? aineo.git.CommitsSince
---@field saved table<string, true> the files the user saved since the base, by path relative to the top level
---@field shown boolean whether the pane has been shown
---@field watch? aineo.git.Watch

---@type aineo.changes.Session|nil
local session = nil

--- The pane's buffers, by window.
---@type { files: integer|nil, commits: integer|nil }
local buffers = {}

--- Writes the files buffer for what the session knows: its files, or that
--- aineo is reading the repository until git has answered.
local function show_files()
  if not (buffers.files and session) then
    return
  end
  pages.write_page(
    buffers.files,
    lines.files_window({
      changes = session.changes,
      saved = session.saved,
      unwatched_subdirectories = session.watch ~= nil and not session.watch.watches_subdirectories,
    })
  )
end

--- Writes the commits buffer for what the session knows: its commits, or
--- that aineo is reading the repository until git has answered.
local function show_commits()
  if not (buffers.commits and session) then
    return
  end
  pages.write_page(buffers.commits, lines.commits_window({ since = session.commits }))
end

--- Reads the files changed since the base, and shows them; one read at a
--- time (`aineo.changes.serial`).
local read_files = serial.one_at_a_time(function(ended)
  git.changed_files(session.repository, session.base, function(failure, changes)
    if not failure then
      session.changes = changes
      show_files()
    end
    ended()
  end, session.settings.git)
end)

--- Reads the commits since the base, and shows them; one read at a time
--- (`aineo.changes.serial`).
local read_commits = serial.one_at_a_time(function(ended)
  git.commits_since(session.repository, session.base, function(failure, commits)
    if not failure then
      session.commits = commits
      show_commits()
    end
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

--- Starts watching the session's repository.
local function watch()
  session.watch = git.watch_repository(session.repository, function(failure, change)
    if not failure then
      follow_change(change)
    end
  end, session.settings.git)
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

--- Notes that the pane is shown, and follows the repository from then on
--- (`follow_repository()`).
local function pane_shown()
  if not session then
    return
  end
  session.shown = true
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
--- the pane has been shown, whether the watch saw the save or not.
---
---@param written string the written file's absolute path, as it was opened
local function note_save(written)
  if not session.repository then
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
  git.find_repository(settings.directory, function(failure, repository)
    if not failure then
      session.repository = repository
      session.base = repository.head
      follow_repository()
    end
  end, settings.git)
end

--- A scratch buffer named `name`, which tells the session the pane is shown
--- whenever it enters a window (`pane_shown()`).
---
---@param name string
---@return integer buffer
local function scratch_buffer(name)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buffer, name)
  vim.bo[buffer].modifiable = false
  vim.api.nvim_create_autocmd('BufWinEnter', {
    buffer = buffer,
    desc = 'aineo: read the changes pane again',
    callback = function()
      pane_shown()
    end,
  })
  return buffer
end

--- The changes pane's two buffers, made once, each written for what the
--- session knows: the files buffer, `aineo://changes-files`, and the
--- commits buffer, `aineo://changes-commits`. Whenever either enters a
--- window, the pane is shown: the first time, the watch starts, and each
--- time both lists are read again.
---
---@return { files: integer, commits: integer }
function M.pane_buffers()
  buffers.files = buffers.files or scratch_buffer('aineo://changes-files')
  buffers.commits = buffers.commits or scratch_buffer('aineo://changes-commits')
  show_files()
  show_commits()
  return { files = buffers.files, commits = buffers.commits }
end

return M
