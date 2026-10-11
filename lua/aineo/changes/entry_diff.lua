--- The diff an entry of the changes pane stands for: how it is read, what
--- its buffer is named, and what the user is told it is called.

local git = require('aineo.git')
local lines = require('aineo.changes.lines')

local M = {}

--- Where an entry's diff is read from.
---@class aineo.changes.DiffSource
---@field repository aineo.git.Repository the editor's repository
---@field base string|nil the session's base
---@field options? aineo.git.Options how the git home runs git

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

--- Reads the diff of `entry` and calls `done(failure, diff)`: for an entry
--- of the editor's own worktree, within the filter it is listed under — a
--- file's from the session's base, from `HEAD` or in its commit; the whole
--- of *Session work*, of *Uncommitted* or of a commit — in `source`'s
--- repository; for an entry of another worktree, a file's from that
--- worktree's base or a commit's, in that worktree.
---
---@param entry aineo.changes.Entry
---@param source aineo.changes.DiffSource
---@param done fun(failure: aineo.git.Failure|nil, diff: string|nil)
function M.read(entry, source, done)
  if entry.worktree then
    local worktree_source = {
      repository = entry.worktree.repository,
      base = entry.worktree.base,
      options = source.options,
    }
    if entry.commit then
      git.commit_diff(worktree_source.repository, entry.commit.id, done, source.options)
    else
      git.file_diff(
        worktree_source.repository,
        worktree_source.base,
        entry.change,
        done,
        source.options
      )
    end
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
  commit = function(entry)
    return ('commit/%s/%s'):format(entry.filter.commit.id, lines.quoted_path(entry.change.path))
  end,
}

--- The name of the buffer showing `entry`'s diff, after `aineo://`:
--- `diff/<path>` for a file read from the session's base, `uncommitted/<path>`
--- from `HEAD`, `commit/<id>/<path>` in a commit, its path quoted as the
--- files window shows it; `session-work`, `uncommitted` and `commit/<id>`
--- for the whole diffs, a commit by its full id. For an entry of another
--- worktree, `worktree<top>//diff/<path>` and `worktree<top>//commit/<id>`,
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
  local diff = entry.commit and 'commit/' .. entry.commit.id
    or 'diff/' .. lines.quoted_path(entry.change.path)
  return ('aineo://worktree%s//%s'):format(lines.quoted_path(entry.worktree.top), diff)
end

--- What the diff of `entry` is called in what aineo tells the user: the
--- diff of a file's path, quoted as the files window shows it, or of the
--- commit's abbreviated id, or of *Uncommitted* or *Session work*; for an
--- entry of another worktree, followed by `in the worktree <folder>`, its
--- folder's name as its heading gives it.
---
---@param entry aineo.changes.Entry
---@return string
function M.told_name(entry)
  local name
  if entry.change then
    name = lines.quoted_path(entry.change.path)
  elseif entry.commit then
    name = 'commit ' .. entry.commit.id:sub(1, lines.ABBREVIATED_ID_LENGTH)
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
