--- The diff an entry of the changes pane stands for: how it is read, what
--- its buffer is named, and what the user is told it is called.

local git = require('aineo.git')
local landed = require('aineo.changes.landed')
local lines = require('aineo.changes.lines')

local M = {}

--- Where an entry's diff is read from.
---@class aineo.changes.DiffSource
---@field repository aineo.git.Repository the editor's repository
---@field base string|nil the session's base
---@field landed? aineo.changes.Landed what the commits window last read of the working branch
---@field options? aineo.git.Options how the git home runs git
---@field context? aineo.git.DiffContext how much of a file the diff shows around a change; three lines when not given

--- Reads, for `source`, a diff between the session's base and the commit
--- the working branch named when the commits window last read it, with
--- `read(tip)`; calls `done(failure)` when that read has no commit
--- (`landed.unreadable()`).
---
---@param source aineo.changes.DiffSource
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
---@param read fun(tip: string)
local function with_landed_tip(source, done, read)
  if source.landed and source.landed.tip then
    read(source.landed.tip)
  else
    done(landed.unreadable(source.landed))
  end
end

--- How the diff of an entry of the editor's own worktree is read, by the
--- kind of the filter it is listed under and by what it is: a file in the
--- files window, or the whole line of the commits window.
---@type table<string, { file: fun(source: aineo.changes.DiffSource, entry: aineo.changes.Entry, done: fun(failure: aineo.git.Failure|nil, diff: string|nil)), whole: fun(source: aineo.changes.DiffSource, entry: aineo.changes.Entry, done: fun(failure: aineo.git.Failure|nil, diff: string|nil)) }>
local OWN_READS = {
  session_work = {
    file = function(source, entry, done)
      git.file_diff(source.repository, source.base, entry.change, done, source.options)
    end,
    whole = function(source, _, done)
      git.diff_since(source.repository, source.base, done, source.options)
    end,
  },
  uncommitted = {
    file = function(source, entry, done)
      git.uncommitted_file_diff(source.repository, entry.change, done, source.options)
    end,
    whole = function(source, _, done)
      git.uncommitted_diff(source.repository, done, source.options)
    end,
  },
  landed = {
    file = function(source, entry, done)
      with_landed_tip(source, done, function(tip)
        git.file_diff_between(
          source.repository,
          source.base,
          tip,
          entry.change,
          done,
          source.options
        )
      end)
    end,
    whole = function(source, _, done)
      with_landed_tip(source, done, function(tip)
        git.diff_between(source.repository, source.base, tip, done, source.options)
      end)
    end,
  },
  commit = {
    file = function(source, entry, done)
      git.commit_file_diff(
        source.repository,
        entry.filter.commit.id,
        entry.change,
        done,
        source.options
      )
    end,
    whole = function(source, entry, done)
      git.commit_diff(source.repository, entry.commit.id, done, source.options)
    end,
  },
}

--- What a diff of another worktree fails with when the worktree has no
--- repository and no failure says why.
---@type aineo.git.Failure
local WORKTREE_UNREAD = { reason = 'failed', message = 'the worktree could not be read' }

--- Reads the diff of `entry`, an entry of another worktree, in that
--- worktree's repository: a file's change in the commit it is listed under,
--- or from the worktree's base; a commit's own; the whole change of the
--- worktree from its base to its working tree, for its heading. A worktree
--- with no repository, because its read failed, gives that failure.
---
---@param entry aineo.changes.Entry
---@param options aineo.git.DiffOptions
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
local function read_in_worktree(entry, options, done)
  local worktree = entry.worktree
  local repository = worktree.repository
  if not repository then
    done(worktree.failure or WORKTREE_UNREAD)
  elseif entry.change and entry.filter.kind == 'commit' then
    git.commit_file_diff(repository, entry.filter.commit.id, entry.change, done, options)
  elseif entry.change then
    git.file_diff(repository, worktree.base, entry.change, done, options)
  elseif entry.commit then
    git.commit_diff(repository, entry.commit.id, done, options)
  else
    git.diff_since(repository, worktree.base, done, options)
  end
end

--- Reads the diff of `entry` and calls `done(failure, diff)`: for an entry
--- of the editor's own worktree, within the filter it is listed under — a
--- file's from the session's base, from `HEAD` or in its commit; the whole
--- of *Session work*, of *Uncommitted* or of a commit — in `source`'s
--- repository; for an entry of another worktree, in that worktree
--- (`read_in_worktree()`). Every diff is read in the context `source`
--- names.
---
---@param entry aineo.changes.Entry
---@param source aineo.changes.DiffSource
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
function M.read(entry, source, done)
  source = vim.tbl_extend(
    'force',
    source,
    { options = vim.tbl_extend('force', source.options or {}, { context = source.context }) }
  )
  if entry.worktree then
    read_in_worktree(entry, source.options, done)
    return
  end
  OWN_READS[entry.filter.kind][entry.change and 'file' or 'whole'](source, entry, done)
end

--- The names of the whole diffs of the editor's own worktree, by the kind
--- of the filter.
---@type table<string, fun(entry: aineo.changes.Entry): string>
local OWN_WHOLE_NAMES = {
  session_work = function()
    return 'session-work'
  end,
  uncommitted = function()
    return 'uncommitted'
  end,
  landed = function()
    return 'landed'
  end,
  commit = function(entry)
    return 'commit/' .. entry.commit.id
  end,
}

--- The names of the diffs of a file of the editor's own worktree, by the
--- kind of the filter.
---@type table<string, fun(entry: aineo.changes.Entry): string>
local OWN_FILE_NAMES = {
  session_work = function(entry)
    return 'diff/' .. lines.quoted_path(entry.change.path)
  end,
  uncommitted = function(entry)
    return 'uncommitted/' .. lines.quoted_path(entry.change.path)
  end,
  landed = function(entry)
    return 'landed/' .. lines.quoted_path(entry.change.path)
  end,
  commit = function(entry)
    return ('commit/%s/%s'):format(entry.filter.commit.id, lines.quoted_path(entry.change.path))
  end,
}

--- The name of the diff of `entry`, an entry of another worktree, after
--- `worktree<top>//`: `diff/<path>` for a file read from the worktree's
--- base, `commit/<id>/<path>` for a file in a commit, `commit/<id>` for the
--- commit's own, `since-base` for the worktree's whole change.
---
---@param entry aineo.changes.Entry
---@return string
local function worktree_diff_name(entry)
  if entry.change and entry.filter.kind == 'commit' then
    return ('commit/%s/%s'):format(entry.filter.commit.id, lines.quoted_path(entry.change.path))
  elseif entry.change then
    return 'diff/' .. lines.quoted_path(entry.change.path)
  elseif entry.commit then
    return 'commit/' .. entry.commit.id
  end
  return 'since-base'
end

--- The name of the buffer showing `entry`'s diff, after `aineo://`:
--- `diff/<path>` for a file read from the session's base, `uncommitted/<path>`
--- from `HEAD`, `commit/<id>/<path>` in a commit, its path quoted as the
--- files window shows it; `session-work`, `uncommitted` and `commit/<id>`
--- for the whole diffs, a commit by its full id. For an entry of another
--- worktree, `worktree<top>//` and the name `worktree_diff_name()` gives,
--- the worktree's top level quoted too, so that two worktrees' diffs are
--- two buffers, whatever their paths: a resolved top level holds no `//`,
--- and neither does a path git gives.
---
---@param entry aineo.changes.Entry
---@return string
function M.name(entry)
  if not entry.worktree then
    local names = entry.change and OWN_FILE_NAMES or OWN_WHOLE_NAMES
    return 'aineo://' .. names[entry.filter.kind](entry)
  end
  return ('aineo://worktree%s//%s'):format(
    lines.quoted_path(entry.worktree.top),
    worktree_diff_name(entry)
  )
end

--- What the diff of `entry` is called in what aineo tells the user: the
--- diff of a file's path, quoted as the files window shows it, or of the
--- commit's abbreviated id, or of *Uncommitted* or *Session work*; for an
--- entry of another worktree, followed by `in the worktree <folder>`, its
--- folder's name as its heading gives it, and for its heading the worktree
--- itself, `the worktree <folder>`.
---
---@param entry aineo.changes.Entry
---@return string
function M.told_name(entry)
  local name
  if entry.change then
    name = lines.quoted_path(entry.change.path)
  elseif entry.commit then
    name = 'commit ' .. entry.commit.id:sub(1, lines.ABBREVIATED_ID_LENGTH)
  elseif entry.worktree then
    return 'the worktree ' .. lines.quoted_path(vim.fs.basename(entry.worktree.top))
  else
    name = lines.filter_name(entry.filter)
  end
  if entry.worktree then
    return ('%s in the worktree %s'):format(
      name,
      lines.quoted_path(vim.fs.basename(entry.worktree.top))
    )
  end
  return name
end

return M
