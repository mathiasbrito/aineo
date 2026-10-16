--- The git home: what a repository holds, asked of git — the files changed
--- since a base commit, the commits since it or between two commits, their
--- diffs, a file as a commit has it, a name resolved to a commit, its
--- worktrees and the base of each, its local branches — and a watch that
--- calls back when the branch moves, a reference is written or a
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

local branches = require('aineo.git.branches')
local changes = require('aineo.git.changes')
local content = require('aineo.git.content')
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

--- How a diff is read: as the home runs git, and with as much of each file
--- around a change as `context` says. A diff raises an error, called with
--- a `context` it has no name for.
---@class aineo.git.DiffOptions: aineo.git.Options
---@field context? aineo.git.DiffContext three lines (`'three_lines'`) when not given, or the whole file (`'whole_file'`)

--- The context `options` ask a diff for, nil when they ask for none.
---
---@param options aineo.git.DiffOptions|nil
---@return aineo.git.DiffContext|nil
local function context_of(options)
  return options and options.context
end

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

--- Lists the files of `found` that differ from `HEAD` as it is now — staged
--- or not — and the untracked files its ignore rules leave in, with paths
--- relative to its top level; calls `done(nil, changes)`, or `done(failure)`.
--- Before the first commit every file counts as new.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param done fun(failure: aineo.git.Failure|nil, changes: aineo.git.Change[]|nil)
---@param options? aineo.git.Options
function M.uncommitted_files(found, done, options)
  changes.uncommitted_files(process.runner(options), found, done)
end

--- Lists the files the commit `commit` changed in `found`, against its
--- first parent — a merge lists what it brought in — with paths relative to
--- its top level; calls `done(nil, changes)`, or `done(failure)`. A root
--- commit lists its files as added, an empty commit none.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param commit string the commit's id
---@param done fun(failure: aineo.git.Failure|nil, changes: aineo.git.Change[]|nil)
---@param options? aineo.git.Options
function M.commit_files(found, commit, done, options)
  changes.commit_files(process.runner(options), found, commit, done)
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

--- Lists the commits of `found` reachable from the commit `to` and not from
--- the commit `from`, newest first, and calls `done(nil, commits)`, or
--- `done(failure)`. A commit a rebase merge made counts under its new id,
--- not the id the commit it copied has.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param from string|nil the full id of the commit the commits are counted from; nil counts every commit of `to`
---@param to string the full id of the commit the commits are counted to
---@param done fun(failure: aineo.git.Failure|nil, commits: aineo.git.Commit[]|nil)
---@param options? aineo.git.Options
function M.commits_between(found, from, to, done, options)
  history.commits_between(process.runner(options), found, from, to, done)
end

--- Lists the files of `found` that differ between the merge base of the
--- commits `from` and `to`, and `to` — git's `from...to`: what `to` gained
--- since the two forked, all of `to` when `from` is behind it — with paths
--- relative to its top level, renames found; calls `done(nil, changes)`, or
--- `done(failure)`. Only the commits are read, never the working tree or the
--- index.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param from string|nil the full id of the first commit; nil counts every file of `to` as new
---@param to string the full id of the second commit
---@param done fun(failure: aineo.git.Failure|nil, changes: aineo.git.Change[]|nil)
---@param options? aineo.git.Options
function M.files_between(found, from, to, done, options)
  changes.files_between(process.runner(options), found, from, to, done)
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
---@param options? aineo.git.DiffOptions
function M.file_diff(found, base, change, done, options)
  diffs.file_diff(process.runner(options), found, base, change, done, context_of(options))
end

--- Gives the unified diff of the file `change` names in `found`, from `HEAD`
--- as it is now to the working tree, as `M.file_diff()` gives it from a
--- base, and calls `done(nil, diff)`, or `done(failure)`.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param change aineo.git.Change one of the changes `M.uncommitted_files()` gave
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param options? aineo.git.DiffOptions
function M.uncommitted_file_diff(found, change, done, options)
  diffs.uncommitted_file_diff(process.runner(options), found, change, done, context_of(options))
end

--- Gives the unified diff of every file of `found` from the commit `base` to
--- the working tree — the untracked files the ignore rules leave in wholly
--- added, without touching the repository's index — and calls
--- `done(nil, diff)`, or `done(failure)`.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param base string|nil the full id of the commit the diff runs from; nil runs it from nothing
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param options? aineo.git.DiffOptions
function M.diff_since(found, base, done, options)
  diffs.diff_since(process.runner(options), found, base, done, context_of(options))
end

--- Gives the unified diff of every file of `found` from `HEAD` as it is now
--- to the working tree, as `M.diff_since()` gives it from a base, and calls
--- `done(nil, diff)`, or `done(failure)`.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param options? aineo.git.DiffOptions
function M.uncommitted_diff(found, done, options)
  diffs.uncommitted_diff(process.runner(options), found, done, context_of(options))
end

--- Gives the unified diff of the commit `commit` in `found`, after its
--- header — its id, author, date and message — as `git show` gives it in
--- its default format, a merge's against its first parent, and calls
--- `done(nil, diff)`, or `done(failure)`.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param commit string the commit's id
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param options? aineo.git.DiffOptions
function M.commit_diff(found, commit, done, options)
  diffs.commit_diff(process.runner(options), found, commit, done, context_of(options))
end

--- Gives the diff of the commit `commit` in `found`, after its header, as
--- `M.commit_diff()` gives it, limited to the file `change` names, and calls
--- `done(nil, diff)`, or `done(failure)`.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param commit string the commit's id
---@param change aineo.git.Change one of the changes `M.commit_files()` gave
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param options? aineo.git.DiffOptions
function M.commit_file_diff(found, commit, change, done, options)
  diffs.commit_file_diff(process.runner(options), found, commit, change, done, context_of(options))
end

--- Reads the full id of the commit the name `name` gives in `found`, as git
--- reads a name — a branch, a remote-tracking branch such as `origin/dev`, a
--- tag (an annotated one gives the commit it tags), a reference by its full
--- path, an id — and calls `done(nil, commit)`, nil when the name gives no
--- commit, or `done(failure)`. A name that begins with `-` is a name, never
--- an option.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param name string
---@param done fun(failure: aineo.git.Failure|nil, commit: string|nil)
---@param options? aineo.git.Options
function M.resolve_commit(found, name, done, options)
  repository.resolve_commit(process.runner(options), found.top, name, done)
end

--- Reads the short name of the branch the remote `origin`'s `HEAD` points at
--- in `found` — `origin/main` — and calls `done(nil, name)`, nil when `found`
--- has no `origin/HEAD`, or `done(failure)`. It is the remote's own default
--- branch, as of the last fetch or clone, whatever branch `found` is on.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param done fun(failure: aineo.git.Failure|nil, name: string|nil)
---@param options? aineo.git.Options
function M.remote_default_branch(found, done, options)
  repository.read_remote_default_branch(process.runner(options), found.top, done)
end

--- Reads the file at `path` as the commit `commit` of `found` has it, and
--- calls `done(nil, text, size)`, the bytes exactly as git printed them and
--- the file's whole size in bytes, or `done(failure)`: a `path_missing` one
--- when the commit has nothing at `path` — a file deleted in it, say — told
--- apart from any other failure, a directory at `path` included. The path
--- is taken whole and as the commit names it, never as a pattern or an
--- option: `.`, a trailing slash and `./x` name nothing. A commit of
--- another worktree is read in `found`, which shares its object store.
---
--- With `first_bytes`, `text` is the file's first `first_bytes` bytes when
--- the file is larger, and git is stopped once they have come, with every
--- process it started, so that the editor holds no more than `first_bytes`
--- bytes of it, whatever its size; git itself may unpack a file stored in a
--- pack whole before it prints a byte. `text` is the whole file otherwise.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param commit string the commit's id
---@param path string relative to the repository's top level
---@param done fun(failure: aineo.git.Failure|nil, text: string|nil, size: integer|nil)
---@param options? aineo.git.Options
---@param first_bytes? integer how many bytes of the file are wanted, at least 1
function M.file_at_commit(found, commit, path, done, options, first_bytes)
  content.file_at_commit(process.runner(options), found, commit, path, done, first_bytes)
end

--- Gives the unified diff of every file of `found` between the merge base of
--- the commits `from` and `to`, and `to` — what `M.files_between()` lists —
--- without a commit header, and calls `done(nil, diff)`, or `done(failure)`.
--- Only the commits are read.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param from string|nil the full id of the first commit; nil runs the diff from nothing
---@param to string the full id of the second commit
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param options? aineo.git.DiffOptions
function M.diff_between(found, from, to, done, options)
  diffs.diff_between(process.runner(options), found, from, to, done, context_of(options))
end

--- Gives the unified diff of the file `change` names in `found` between the
--- merge base of the commits `from` and `to`, and `to`, as
--- `M.diff_between()` gives it — a renamed file asked with both its paths —
--- and calls `done(nil, diff)`, or `done(failure)`.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param from string|nil the full id of the first commit; nil runs the diff from nothing
---@param to string the full id of the second commit
---@param change aineo.git.Change one of the changes `M.files_between()` gave
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param options? aineo.git.DiffOptions
function M.file_diff_between(found, from, to, change, done, options)
  diffs.file_diff_between(
    process.runner(options),
    found,
    from,
    to,
    change,
    done,
    context_of(options)
  )
end

--- Gives the unified diff of the file `change` names in `found` straight
--- from the commit `from` to the commit `to`, as `M.file_diff_between()`
--- gives it from their merge base. Where `to` is behind `from`, the merge
--- base would hide what `to` lacks and this shows it. Calls `done(nil,
--- diff)`, or `done(failure)`.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param from string|nil the full id of the first commit; nil runs the diff from nothing
---@param to string the full id of the second commit
---@param change aineo.git.Change
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param options? aineo.git.DiffOptions
function M.file_diff_straight(found, from, to, change, done, options)
  diffs.file_diff_straight(
    process.runner(options),
    found,
    from,
    to,
    change,
    done,
    context_of(options)
  )
end

--- Lists the worktrees of the repository `found` is in, and calls
--- `done(nil, worktrees)`, the worktree `found` is first, by `found.top`,
--- and the others in git's order, each by its path with every link
--- resolved; or `done(failure)`. A worktree git marks `prunable` or `bare`
--- is left out, and so is one whose directory does not exist, locked or
--- not.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param done fun(failure: aineo.git.Failure|nil, worktrees: aineo.git.Worktree[]|nil)
---@param options? aineo.git.Options
function M.list_worktrees(found, done, options)
  worktrees.list_worktrees(process.runner(options), found, done)
end

--- Reads the commit the bases of the other worktrees of the repository
--- `found` is in are taken against (`M.worktree_base()`), as `found`'s
--- `HEAD` is now: the upstream of the branch `found` is on; that branch
--- when it has no upstream, or one whose branch git does not have;
--- `found`'s `HEAD` when that is detached. Calls `done(nil, commit)`, nil
--- while `found` has no commit yet, or `done(failure)`.
---
---@param found aineo.git.Repository the editor's, as `M.find_repository()` gave it
---@param done fun(failure: aineo.git.Failure|nil, commit: string|nil)
---@param options? aineo.git.Options
function M.comparison_commit(found, done, options)
  worktrees.comparison_commit(process.runner(options), found, done)
end

--- Reads the base of `worktree`, a worktree of the repository other than
--- the editor's: the merge base of its `HEAD` and the commit `comparison`,
--- any commit: the one the working branch names, or the one
--- `M.comparison_commit()` read from the editor's worktree. Calls `done(nil,
--- base)`, nil when they share no history or either has no commit yet, or
--- `done(failure)`.
---
---@param worktree aineo.git.Worktree as `M.list_worktrees()` or `M.find_repository()` gave it
---@param comparison string|nil the full id of the commit, nil when there is no commit to compare with
---@param done fun(failure: aineo.git.Failure|nil, base: string|nil)
---@param options? aineo.git.Options
function M.worktree_base(worktree, comparison, done, options)
  worktrees.worktree_base(process.runner(options), worktree, comparison, done)
end

--- Lists the local branches of the repository `found` is in, newest commit
--- first, those whose commits are equally new in name order, each by its
--- short name and the full id of the commit it names, and calls
--- `done(nil, branches)`, or `done(failure)`. A repository with no commit
--- yet lists none, and no remote-tracking branch is listed.
---
---@param found aineo.git.Repository as `M.find_repository()` gave it
---@param done fun(failure: aineo.git.Failure|nil, branches: aineo.git.Branch[]|nil)
---@param options? aineo.git.Options
function M.list_branches(found, done, options)
  branches.list_branches(process.runner(options), found, done)
end

--- Starts watching `found`, and calls `on_change(nil, change)` on the main
--- loop once per burst of changes — a burst ends 200 ms after its last event
--- or 1 s after its first: when the branch moves — a commit, even one that
--- changes no file, an amend, a reset, a checkout, a merge, a rebase, a move
--- from another worktree — or when the list of files changed may differ: a
--- file of the working tree is written, created, removed or renamed, by any
--- process, or an index or a submodule changes, as every commit also does;
--- or `on_change(failure)` when the branch cannot be read or a file system
--- watch fails. A burst that wrote a reference of the repository — a commit,
--- a branch or a tag made or deleted, a fetch, from this worktree or
--- another — calls back too, even when `HEAD` did not move and no file
--- changed (`references_changed`). A change made as the watch starts can be
--- missed, so a caller reads what it shows once the watch has started.
--- Returns the watch, which says whether it sees changes in subdirectories
--- — on Linux it does not, and misses a branch moved by `git update-ref`
--- from another worktree too, and every reference written under `refs/`,
--- so that `references_changed` is true there only for `packed-refs` and a
--- fetch of this worktree — or nil and why it could not start; it never
--- raises.
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
