--- A file the files window lists under a commit, as that commit has it: at
--- which commit and in which repository it is read, what its buffer is
--- named, and what the user is told when it cannot be read.

local git = require('aineo.git')
local landed = require('aineo.changes.landed')
local lines = require('aineo.changes.lines')

local M = {}

--- The commit a file is read at.
---@class aineo.changes.Revision
---@field repository aineo.git.Repository the repository that holds the commit
---@field commit string the commit's full id
---@field told string what the user is told the commit is called

--- Whether `entry`, a line of the files window, lists a file under a
--- commit: one of the session's, one that landed in the working branch, or
--- one of another worktree; or under *Landed*, which the working branch's
--- own commit stands for.
---
---@param entry aineo.changes.Entry
---@return boolean
function M.lists_file_at_a_commit(entry)
  return entry.change ~= nil and (entry.filter.kind == 'commit' or entry.filter.kind == 'landed')
end

--- What the user is told the commit `entry` is listed under is called: its
--- abbreviated id, followed by `in the worktree <folder>` for a commit of
--- another worktree.
---
---@param entry aineo.changes.Entry an entry listed under a commit
---@return string
local function told_commit(entry)
  local told = 'commit ' .. entry.filter.commit.id:sub(1, lines.ABBREVIATED_ID_LENGTH)
  if not entry.worktree then
    return told
  end
  return ('%s in the worktree %s'):format(
    told,
    lines.quoted_path(vim.fs.basename(entry.worktree.top))
  )
end

--- The commit the file `entry` lists is read at: the commit it is listed
--- under, or, under *Landed*, the commit the working branch named when the
--- commits window last read it (`source.landed`). A commit of another
--- worktree is read in that worktree's repository, as its other diffs are.
--- Returns nil and the failure when the working branch names no commit
--- (`aineo.changes.landed`'s `unreadable()`).
---
---@param entry aineo.changes.Entry an entry for which `M.lists_file_at_a_commit()` holds
---@param source aineo.changes.DiffSource
---@return aineo.changes.Revision|nil
---@return aineo.git.Failure|nil failure
function M.revision_of(entry, source)
  if entry.filter.kind == 'landed' then
    if not (source.landed and source.landed.tip) then
      return nil, landed.unreadable(source.landed)
    end
    return {
      repository = source.repository,
      commit = source.landed.tip,
      told = 'the working branch ' .. lines.quoted_path(source.landed.name),
    }
  end
  return {
    repository = entry.worktree and entry.worktree.repository or source.repository,
    commit = entry.filter.commit.id,
    told = told_commit(entry),
  }
end

--- The name of the buffer showing the file `path` as `revision` has it,
--- after `aineo://`: `show/<commit>/<path>`, the commit by its full id and
--- the path quoted as the files window shows it.
---
---@param revision aineo.changes.Revision
---@param path string
---@return string
function M.name(revision, path)
  return ('aineo://show/%s/%s'):format(revision.commit, lines.quoted_path(path))
end

--- Reads the file `path` as `revision` has it and calls `done(nil, text, size)`,
--- the bytes git printed, at most the first `first_bytes` of them, and the
--- file's whole size, or `done(failure)`.
---
---@param revision aineo.changes.Revision
---@param path string relative to the repository's top level
---@param options? aineo.git.Options how the git home runs git
---@param first_bytes integer how many bytes of the file are wanted
---@param done fun(failure: aineo.git.Failure|nil, text: string|nil, size: integer|nil)
function M.read(revision, path, options, first_bytes, done)
  git.file_at_commit(revision.repository, revision.commit, path, done, options, first_bytes)
end

--- What the user is told when the file `path` could not be read as
--- `revision` has it, because of `failure`: that the commit deleted it,
--- when it has nothing at the path; git's words otherwise.
---
---@param revision aineo.changes.Revision
---@param path string
---@param failure aineo.git.Failure
---@return string
function M.told_failure(revision, path, failure)
  local file = lines.quoted_path(path)
  if failure.reason == 'path_missing' then
    return ('aineo: %s was deleted in %s'):format(file, revision.told)
  end
  return ('aineo: %s could not be read in %s: %s'):format(
    file,
    revision.told,
    lines.words_of(failure)
  )
end

return M
