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
