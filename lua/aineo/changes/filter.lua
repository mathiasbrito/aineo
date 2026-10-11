--- The filters the commits window selects and the files window lists
--- under: *Uncommitted*, *Session work*, or one commit of the session.

local M = {}

--- What the files window lists the files of.
---@class aineo.changes.Filter
---@field kind 'uncommitted'|'session_work'|'commit' what differs from `HEAD`; what differs from the session's base; or what one commit changed
---@field commit? aineo.git.Commit the commit, for a `commit` filter

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

--- What tells `filter` apart from every other: the key of the entry that
--- lists it in the commits window. A commit's is its id; the others' begin
--- with a byte no id holds.
---
---@param filter aineo.changes.Filter
---@return string
function M.key(filter)
  if filter.kind == 'commit' then
    return filter.commit.id
  end
  return '\0' .. filter.kind
end

--- Whether `first` and `second` are the same filter: both given, and the
--- same kind, the same commit for a commit.
---
---@param first aineo.changes.Filter|nil
---@param second aineo.changes.Filter|nil
---@return boolean
function M.same(first, second)
  return first ~= nil and second ~= nil and M.key(first) == M.key(second)
end

return M
