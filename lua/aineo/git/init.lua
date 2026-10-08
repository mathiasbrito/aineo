--- The git home: what a repository holds, asked of git — the files changed
--- since a base commit, the commits since it, their diffs, its worktrees and
--- the base of each — and a watch that calls back when the branch moves or a
--- working-tree file changes.
---
--- Every operation returns at once, runs git asynchronously with each process
--- bounded in time, and calls its `done` exactly once, on the main loop, with
--- a failure or an answer; it never raises, called from a fast event
--- included. The bound stops git with every process it started, save one
--- started in a process group of its own, which escapes it and, while it
--- holds git's output, holds `done` back. Its answers do not depend on the
--- user's git settings, save the attributes the user and the repository give
--- files, which say what is text (`diffs`), nor on the `GIT_*` variables of
--- the editor's environment that name another repository or change how git
--- reads a path or where it reads attributes from, and its reads never take
--- the repository's lock nor run its hooks. A diff is exactly what git
--- printed, carriage returns included, and is not bounded in size: a commit
--- that adds a 100 MB file gives a 100 MB diff. The home keeps no state but
--- its watches: the base is its caller's.

local changes = require('aineo.git.changes')
local diffs = require('aineo.git.diffs')
local history = require('aineo.git.history')
local process = require('aineo.git.process')
local repository = require('aineo.git.repository')
local watch = require('aineo.git.watch')
local worktrees = require('aineo.git.worktrees')

local M = {}

--- How a watch runs; every field it leaves out is the home's default.
---@class aineo.git.WatchOptions: aineo.git.Options
---@field system_name? string the platform, as `vim.uv.os_uname().sysname` names it; the editor's own when not given

--- Finds the repository `directory` is in, and calls `done(nil, repository)`,
--- or `done(failure)`: `not_a_repository`, in git's words, when there is
--- none.
---
---@param directory string
---@param done fun(failure: aineo.git.Failure|nil, repository: aineo.git.Repository|nil)
---@param options? aineo.git.Options
function M.find_repository(directory, done, options)
  repository.find_repository(process.runner(options), directory, done)
end

--- Lists the files of `found` that differ from the commit `base` — committed
--- since or not, staged or not — and the untracked files its ignore rules
--- leave in, with paths relative to its top level; calls `done(nil,
--- changes)`, or `done(failure)`.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param base string|nil the full id of the commit the changes are counted from; nil, for a session begun before the first commit, counts every file as new
---@param done fun(failure: aineo.git.Failure|nil, changes: aineo.git.Change[]|nil)
---@param options? aineo.git.Options
function M.changed_files(found, base, done, options)
  changes.changed_files(process.runner(options), found, base, done)
end

--- Lists the commits of `found` reachable from `HEAD` and not from the
--- commit `base`, newest first, and whether `base` is still an ancestor of
--- `HEAD`; calls `done(nil, commits_since)`, or `done(failure)`.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param base string|nil the full id of the commit the commits are counted from; nil counts every commit
---@param done fun(failure: aineo.git.Failure|nil, commits_since: aineo.git.CommitsSince|nil)
---@param options? aineo.git.Options
function M.commits_since(found, base, done, options)
  history.commits_since(process.runner(options), found, base, done)
end

--- Gives the unified diff of the file `change` names in `found`, from the
--- commit `base` to the working tree — an untracked file wholly added, a
--- deleted one wholly removed, a renamed one as its rename — and calls
--- `done(nil, diff)`, or `done(failure)`.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param base string|nil the base `change` was listed for by `M.changed_files()`
---@param change aineo.git.Change one of the changes `M.changed_files()` gave
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param options? aineo.git.Options
function M.file_diff(found, base, change, done, options)
  diffs.file_diff(process.runner(options), found, base, change, done)
end

--- Gives the unified diff of the commit `commit` in `found`, after its
--- header — its id, author, date and message — as `git show` gives it in
--- its default format, and calls `done(nil, diff)`, or `done(failure)`.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param commit string the commit's id
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param options? aineo.git.Options
function M.commit_diff(found, commit, done, options)
  diffs.commit_diff(process.runner(options), found, commit, done)
end

--- Lists the worktrees of the repository `found` is in, and calls
--- `done(nil, worktrees)`, the worktree `found` is first and the others in
--- git's order, or `done(failure)`.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param done fun(failure: aineo.git.Failure|nil, worktrees: aineo.git.Worktree[]|nil)
---@param options? aineo.git.Options
function M.list_worktrees(found, done, options)
  worktrees.list_worktrees(process.runner(options), found, done)
end

--- Reads the base of `worktree`, one of the worktrees of the repository
--- `found` is in other than `found`'s own, as `found`'s `HEAD` is now: its
--- merge base with the upstream of the branch `found` is on; with that
--- branch when it has no upstream, or one whose branch git does not have;
--- with `found`'s `HEAD` when that is detached. Calls `done(nil, base)`,
--- nil when they share no history or either has no commit yet, or
--- `done(failure)`.
---
---@param found aineo.git.Repository the editor's, as `M.find_repository()` gave it
---@param worktree aineo.git.Worktree as `M.list_worktrees()` or `M.find_repository()` gave it
---@param done fun(failure: aineo.git.Failure|nil, base: string|nil)
---@param options? aineo.git.Options
function M.worktree_base(found, worktree, done, options)
  worktrees.worktree_base(process.runner(options), found, worktree, done)
end

--- Starts watching `found`, and calls `on_change(nil, change)` on the main
--- loop once per burst of changes — a burst ends 200 ms after its last event
--- or 1 s after its first: when the branch moves — a commit, even one that
--- changes no file, an amend, a reset, a checkout, a merge, a rebase, a move
--- from another worktree — or when the list of files changed may differ: a
--- file of the working tree is written, created, removed or renamed, by any
--- process, or an index or a submodule changes, as every commit also does;
--- or `on_change(failure)` when the branch cannot be read or a file system
--- watch fails. A change made as the watch starts can be missed, so a caller
--- reads what it shows once the watch has started. Returns the watch, which
--- says whether it sees changes in subdirectories — on Linux it does not,
--- and misses a branch moved by `git update-ref` from another worktree too
--- — or nil and why it could not start; it never raises.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param on_change fun(failure: aineo.git.Failure|nil, change: aineo.git.RepositoryChange|nil)
---@param options? aineo.git.WatchOptions
---@return aineo.git.Watch|nil watch
---@return aineo.git.Failure|nil failure
function M.watch_repository(found, on_change, options)
  local system_name = (options or {}).system_name or vim.uv.os_uname().sysname
  return watch.watch_repository(process.runner(options), found, on_change, system_name)
end

return M
