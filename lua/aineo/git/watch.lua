--- Watches a repository for what changes its list of files or commits.
---
--- A file of the working tree is seen by a watch on the top level. The
--- branch is seen through the git directories: every event there makes the
--- watch read `HEAD` again and compare its commit and branch with the ones
--- it knew, since no single file of git's is written by every move — a
--- reflog can be replaced, missing, or not kept at all.

local repository = require('aineo.git.repository')

local M = {}

--- How long a watch waits after the last event of a burst before it calls
--- back: git, an editor's save or a checkout writes many files within a few
--- milliseconds, and one burst gives one call.
local SETTLE_MS = 200

--- The platforms, as `vim.uv.os_uname().sysname` names them, where libuv
--- watches a directory's subdirectories when asked to (libuv's
--- `uv_fs_event_start()`, `UV_FS_EVENT_RECURSIVE`).
local RECURSIVE_PLATFORMS = { Darwin = true, Windows_NT = true }

--- What changed in a repository during one burst of events.
---@class aineo.git.RepositoryChange
---@field files_changed boolean a file of the working tree was written, created, removed or renamed
---@field branch_moved boolean `HEAD` names another commit or another branch than before

--- A running watch.
---@class aineo.git.Watch
---@field watches_subdirectories boolean whether a change in a subdirectory of the working tree is seen
---@field stop fun() stops the watch, and releases every handle it holds and every git it runs; stopping it again does nothing

--- What a running watch keeps.
---@class aineo.git.WatchState
---@field run aineo.git.Run
---@field top string the top level of the repository watched
---@field on_change fun(failure: aineo.git.Failure|nil, change: aineo.git.RepositoryChange|nil)
---@field known { head: string?, branch: string? } `HEAD`'s commit and branch when last read
---@field pending { files: boolean, git: boolean } what the events since the last call touched: the working tree, the git directories
---@field timer uv.uv_timer_t the timer that ends a burst
---@field reading boolean whether a read of `HEAD` is running
---@field cancel_read fun() cancels the git the last read of `HEAD` ran
---@field stopped boolean

--- Whether `name`, a path an event on the top level gave, is in the
--- repository's own `.git` rather than in its working tree.
---
---@param name string|nil
---@return boolean
local function is_in_dot_git(name)
  return name == '.git' or vim.startswith(name or '', '.git/')
end

--- Stops and closes each of `handles`.
---
---@param handles (uv.uv_fs_event_t|uv.uv_timer_t)[]
local function release(handles)
  for _, handle in ipairs(handles) do
    handle:stop()
    handle:close()
  end
end

--- Starts one file system watch for each directory of `directories` (its
--- path, and the callback its events go to), recursive when asked, and
--- returns them; or, when one cannot start, releases those that did and
--- returns nil and why.
---
---@param directories { path: string, on_event: function }[]
---@param recursive boolean
---@return uv.uv_fs_event_t[]|nil handles
---@return aineo.git.Failure|nil failure
local function start_watches(directories, recursive)
  local handles = {}
  for _, directory in ipairs(directories) do
    local handle = assert(vim.uv.new_fs_event())
    table.insert(handles, handle)
    local started, start_error =
      handle:start(directory.path, { recursive = recursive }, directory.on_event)
    if not started then
      release(handles)
      return nil,
        { reason = 'failed', message = ('cannot watch %s: %s'):format(directory.path, start_error) }
    end
  end
  return handles
end

local settle

--- Reads `HEAD` for the burst `burst`, which touched the git directories,
--- and calls back when the branch moved — its commit or its branch is not
--- the one `state` knew — or a file changed too; or with the failure when
--- `HEAD` cannot be read. Nothing is called once the watch is stopped. A
--- burst that ended while it read is settled after it.
---
---@param state aineo.git.WatchState
---@param burst { files: boolean, git: boolean }
local function read_branch(state, burst)
  state.reading = true
  repository.read_head(
    function(request, done)
      state.cancel_read = state.run(request, done)
      return state.cancel_read
    end,
    state.top,
    function(failure, head, branch)
      state.reading = false
      if failure then
        state.on_change(failure)
      else
        local moved = head ~= state.known.head or branch ~= state.known.branch
        state.known = { head = head, branch = branch }
        if moved or burst.files then
          state.on_change(nil, { files_changed = burst.files, branch_moved = moved })
        end
      end
      settle(state)
    end
  )
end

--- Ends the burst `state` has pending, unless the watch is stopped, nothing
--- is pending, or a read of `HEAD` is still running: calls back for a burst
--- that touched the working tree alone, and reads `HEAD` for one that
--- touched the git directories.
---
---@param state aineo.git.WatchState
function settle(state)
  if state.stopped or state.reading or not (state.pending.files or state.pending.git) then
    return
  end
  local burst = state.pending
  state.pending = { files = false, git = false }
  if not burst.git then
    state.on_change(nil, { files_changed = true, branch_moved = false })
    return
  end
  read_branch(state, burst)
end

--- Notes an event that touched `kind` — `files` or `git` — and starts the
--- burst's time again. Runs in a fast event.
---
---@param state aineo.git.WatchState
---@param kind 'files'|'git'
local function note(state, kind)
  state.pending[kind] = true
  state.timer:stop()
  state.timer:start(
    SETTLE_MS,
    0,
    vim.schedule_wrap(function()
      settle(state)
    end)
  )
end

--- Starts watching `found`, and calls `on_change(nil, change)` on the main
--- loop once per burst of changes, or `on_change(failure)` when the branch
--- cannot be read. Returns the watch, or nil and why it could not start. On
--- `system_name`, the platform as libuv names it, a watch sees the
--- subdirectories of what it watches only where libuv watches recursively;
--- elsewhere, Linux included, libuv takes the request and watches the top
--- directory alone, so the watch says it cannot.
---
---@param run aineo.git.Run
---@param found aineo.git.Repository
---@param on_change fun(failure: aineo.git.Failure|nil, change: aineo.git.RepositoryChange|nil)
---@param system_name string
---@return aineo.git.Watch|nil watch
---@return aineo.git.Failure|nil failure
function M.watch_repository(run, found, on_change, system_name)
  local recursive = RECURSIVE_PLATFORMS[system_name] == true
  ---@type aineo.git.WatchState
  local state = {
    run = run,
    top = found.top,
    on_change = on_change,
    known = { head = found.head, branch = found.branch },
    pending = { files = false, git = false },
    timer = assert(vim.uv.new_timer()),
    reading = false,
    cancel_read = function() end,
    stopped = false,
  }
  local handles, failure = start_watches({
    {
      path = found.top,
      on_event = function(_, name)
        if not is_in_dot_git(name) then
          note(state, 'files')
        end
      end,
    },
    {
      path = found.common_directory,
      on_event = function()
        note(state, 'git')
      end,
    },
  }, recursive)
  if not handles then
    release({ state.timer })
    return nil, failure
  end
  return {
    watches_subdirectories = recursive,
    stop = function()
      if state.stopped then
        return
      end
      state.stopped = true
      state.cancel_read()
      release(handles)
      release({ state.timer })
    end,
  }
end

return M
