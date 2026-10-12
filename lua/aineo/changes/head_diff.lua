--- The diff of a file the files window lists against `HEAD`: how it is
--- read, by the filter the file is listed under, and what its buffer is
--- named. The counterpart of the diffs `aineo.changes.entry_diff` reads
--- against the file's previous version.

local git = require('aineo.git')
local landed = require('aineo.changes.landed')
local lines = require('aineo.changes.lines')

local M = {}

--- An entry of the files window, marked as standing for the diff of its
--- file against `HEAD`.
---@class aineo.changes.HeadEntry : aineo.changes.Entry
---@field against_head true

--- `entry`, a file of the files window, as the entry standing for that
--- file's diff against `HEAD`; `entry` itself is left as it was.
---
---@param entry aineo.changes.Entry an entry listing a file
---@return aineo.changes.HeadEntry
function M.of(entry)
  return vim.tbl_extend('force', entry, { against_head = true })
end

--- Whether `entry` stands for a diff against `HEAD` (`M.of()`).
---
---@param entry aineo.changes.Entry
---@return boolean
function M.is_against_head(entry)
  return entry.against_head == true
end

--- What a diff against `HEAD` fails with when `HEAD` names no commit.
---@type aineo.git.Failure
local NO_HEAD = { reason = 'failed', message = 'HEAD names no commit' }

--- Reads the full id of `HEAD` in the repository of `source` and calls
--- `use(head)`, or `done(failure)`: git's, or `NO_HEAD` when `HEAD` names no
--- commit yet, under every kind of filter.
---
---@param source aineo.changes.DiffSource
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param use fun(head: string)
local function with_head(source, done, use)
  git.resolve_commit(source.repository, 'HEAD', function(failure, head)
    if failure then
      done(failure)
    elseif not head then
      done(NO_HEAD)
    else
      use(head)
    end
  end, source.options)
end

--- Reads the diff of the file `entry` lists from `HEAD` to the working tree.
---
---@param source aineo.changes.DiffSource
---@param entry aineo.changes.Entry
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
local function read_from_head_to_working_tree(source, entry, done)
  git.uncommitted_file_diff(source.repository, entry.change, done, source.options)
end

--- How a file's diff against `HEAD` is read, by the kind of the filter the
--- file is listed under: from the commit it is listed under straight to
--- `HEAD`; from `HEAD` straight to the commit the working branch named when
--- the commits window last read it; from `HEAD` to the working tree.
---@type table<string, fun(source: aineo.changes.DiffSource, entry: aineo.changes.Entry, done: fun(failure: aineo.git.Failure|nil, diff: string|nil))>
local READS = {
  commit = function(source, entry, done)
    with_head(source, done, function(head)
      git.file_diff_straight(
        source.repository,
        entry.filter.commit.id,
        head,
        entry.change,
        done,
        source.options
      )
    end)
  end,
  landed = function(source, entry, done)
    if not (source.landed and source.landed.tip) then
      done(landed.unreadable(source.landed))
      return
    end
    with_head(source, done, function(head)
      git.file_diff_straight(
        source.repository,
        head,
        source.landed.tip,
        entry.change,
        done,
        source.options
      )
    end)
  end,
  session_work = read_from_head_to_working_tree,
  uncommitted = read_from_head_to_working_tree,
  worktree = read_from_head_to_working_tree,
}

--- `source`, read in the repository of the worktree that lists `entry`'s
--- file when it is another worktree's: the repository the worktree's
--- listing was read in, which every file it lists comes from.
---
---@param entry aineo.changes.Entry
---@param source aineo.changes.DiffSource
---@return aineo.changes.DiffSource
local function source_in_worktree_of(entry, source)
  if not entry.worktree then
    return source
  end
  local in_worktree = {}
  for key, value in pairs(source) do
    in_worktree[key] = value
  end
  in_worktree.repository = entry.worktree.repository
  return in_worktree
end

--- Reads the diff of `entry`, an entry marked by `M.of()`, and calls
--- `done(nil, diff)`, or `done(failure)`. A file `HEAD` lacks is wholly
--- added or removed, as git gives it. For a file of another worktree,
--- `HEAD` is that worktree's.
---
---@param entry aineo.changes.HeadEntry
---@param source aineo.changes.DiffSource with `options` as `aineo.changes.entry_diff`'s `read()` gives them
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
function M.read(entry, source, done)
  READS[entry.filter.kind](source_in_worktree_of(entry, source), entry, done)
end

--- The folders, after `aineo://`, of the names of the diffs against `HEAD`,
--- by the kind of the filter the file is listed under: one folder for the
--- files of a commit, one for those under *Landed*, the folder *Uncommitted*
--- shows its diffs in for those read from `HEAD` to the working tree, and
--- one for another worktree's whole change.
---@type table<string, fun(entry: aineo.changes.Entry): string>
local FOLDERS = {
  commit = function(entry)
    return 'head/commit/' .. entry.filter.commit.id
  end,
  landed = function()
    return 'head/landed'
  end,
  session_work = function()
    return 'uncommitted'
  end,
  uncommitted = function()
    return 'uncommitted'
  end,
  worktree = function()
    return 'head'
  end,
}

--- The name of the buffer showing `entry`'s diff against `HEAD`, after
--- `aineo://`: `head/commit/<id>/<path>` for a file in a commit,
--- `head/landed/<path>` under *Landed*, `uncommitted/<path>` — the diff
--- *Uncommitted* shows — under *Uncommitted* and *Session work*, and
--- `head/<path>` under another worktree's whole change; the path quoted as
--- the files window shows it. For a file of another worktree, after
--- `worktree<top>//`, as that worktree's other diffs are named, the top
--- level quoted too.
---
---@param entry aineo.changes.HeadEntry
---@return string
function M.name(entry)
  local name = FOLDERS[entry.filter.kind](entry) .. '/' .. lines.quoted_path(entry.change.path)
  if not entry.worktree then
    return 'aineo://' .. name
  end
  return ('aineo://worktree%s//%s'):format(lines.quoted_path(entry.worktree.top), name)
end

return M
