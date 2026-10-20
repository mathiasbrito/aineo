--- The rules of the reports of the changes pane's reported set, pure
--- functions of what was reported: the order the Reported section and `s`
--- list them in, and what a report made again for the same work keeps.

local M = {}

--- `entries`, reports of the reported set in the order they joined it, as
--- the Reported section and `s` list them: newest first; a report kept
--- before reports were timed after every timed one; of two taken at the
--- same second, or both untimed, the one that joined later first. A new
--- list; `entries` is left as it is.
---
---@param entries aineo.changes.ReportedEntry[]
---@return aineo.changes.ReportedEntry[]
function M.newest_first(entries)
  local positions = {}
  for position, entry in ipairs(entries) do
    positions[entry] = position
  end
  local ordered = vim.list_slice(entries)
  table.sort(ordered, function(left, right)
    local left_at, right_at = left.report.at or -math.huge, right.report.at or -math.huge
    if left_at ~= right_at then
      return left_at > right_at
    end
    return positions[left] > positions[right]
  end)
  return ordered
end

--- What git says of a reported base, the tip of its work and the pane's own
--- base for that work.
---@class aineo.changes.BaseAncestry
---@field reported_in_tip boolean whether the reported base is an ancestor of the tip, or the tip itself
---@field own_before_reported boolean whether the pane's own base is an ancestor of the reported base, or that base itself

--- The base a reported worktree or branch is read from, of `reported`, the
--- base its report gave, and `own`, the one the pane reads for it without a
--- report: the reported base while it is behind the tip and descends from
--- the pane's own, or the pane has none; else the pane's own — the reported
--- base older than the pane's, unrelated to it, or no longer behind the tip
--- after a rebase, so that a pick never lists commits the agent did not make.
--- The pane's own for a report that gave no base.
---
---@param reported string|nil
---@param own string|nil
---@param ancestry aineo.changes.BaseAncestry
---@return string|nil
function M.effective_base(reported, own, ancestry)
  if not (reported and ancestry.reported_in_tip) then
    return own
  end
  if own == nil or ancestry.own_before_reported then
    return reported
  end
  return own
end

--- The report a worktree or branch keeps when `again` is reported of it
--- after `before`, nil when nothing was: an agent's call replaces whatever
--- was before, its base and label with it; a report of aineo's own hook
--- keeps the one before, the agent's or the hook's own first.
---
---@param before aineo.changes.Report|nil
---@param again aineo.changes.Report
---@return aineo.changes.Report
function M.merged(before, again)
  if before and again.by_hook then
    return before
  end
  return again
end

return M
