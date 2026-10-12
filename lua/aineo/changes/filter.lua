--- The filters the commits window selects and the files window lists
--- under: *Uncommitted*, *Session work*, one commit of the session, or
--- another worktree's whole change or one of its commits.

local M = {}

--- What the files window lists the files of.
---@class aineo.changes.Filter
---@field kind 'uncommitted'|'session_work'|'commit'|'worktree' what differs from `HEAD`; what differs from the session's base; what one commit changed; or what differs in another worktree from its own base
---@field commit? aineo.git.Commit the commit, for a `commit` filter
---@field worktree? aineo.changes.WorktreeSection the worktree other than the editor's that the files are read in, for a `worktree` filter and for a `commit` filter of one of its commits; nil for the editor's own

--- The filter of the files that differ from `HEAD`, staged or not, and the
--- untracked ones.
---@type aineo.changes.Filter
M.UNCOMMITTED = { kind = 'uncommitted' }

--- The filter of the files that differ from the session's base.
---@type aineo.changes.Filter
M.SESSION_WORK = { kind = 'session_work' }

--- The filter of the files `commit` changed.
---
---@param commit aineo.git.Commit
---@return aineo.changes.Filter
function M.of_commit(commit)
  return { kind = 'commit', commit = commit }
end

--- The filter of the files that differ, in the worktree `worktree`, from
--- that worktree's own base.
---
---@param worktree aineo.changes.WorktreeSection
---@return aineo.changes.Filter
function M.of_worktree(worktree)
  return { kind = 'worktree', worktree = worktree }
end

--- The filter of the files `commit` changed, read in the worktree
--- `worktree`.
---
---@param worktree aineo.changes.WorktreeSection
---@param commit aineo.git.Commit
---@return aineo.changes.Filter
function M.of_worktree_commit(worktree, commit)
  return { kind = 'commit', commit = commit, worktree = worktree }
end

--- `selected`, a filter of another worktree, as that worktree's section
--- `worktree` now reads: the same filter, told by the same key.
---
---@param selected aineo.changes.Filter a filter with a `worktree`
---@param worktree aineo.changes.WorktreeSection
---@return aineo.changes.Filter
function M.in_worktree(selected, worktree)
  return vim.tbl_extend('force', selected, { worktree = worktree })
end

--- What tells `filter` apart from every other: the key of the entry that
--- lists it in the commits window. A commit's is its id; a fixed line's
--- begins with a byte no id holds. Another worktree's are told from the
--- editor's own, and from each other, by the worktree's top level and a
--- byte no path holds, then the commit's id, or two such bytes and the
--- kind for the worktree's whole change.
---
---@param filter aineo.changes.Filter
---@return string
function M.key(filter)
  local worktree = filter.worktree and filter.worktree.top .. '\0' or ''
  if filter.kind == 'commit' then
    return worktree .. filter.commit.id
  end
  return worktree .. '\0' .. filter.kind
end

--- Whether `first` and `second` are the same filter: both given, and the
--- same kind, the same commit for a commit, the same worktree for another
--- worktree's.
---
---@param first aineo.changes.Filter|nil
---@param second aineo.changes.Filter|nil
---@return boolean
function M.same(first, second)
  return first ~= nil and second ~= nil and M.key(first) == M.key(second)
end

return M
