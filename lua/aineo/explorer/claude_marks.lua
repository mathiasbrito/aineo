--- What the explorer tells of the work of the Claude Code session between
--- two reads of the tree: which files joined the work, or whose change in it
--- is read anew, so that their lines flash.

local M = {}

--- The signature of each file of `claude`, the files in the work of the
--- session: its git mark and the lines added and removed in it, as one text.
--- Two reads of a file with the same signature saw the same change.
---
---@param claude table<string, true>
---@param marks table<string, string>
---@param line_counts table<string, aineo.git.LineCount>
---@return table<string, string>
function M.signatures(claude, marks, line_counts)
  local signatures = {}
  for path in pairs(claude) do
    local count = line_counts[path]
    signatures[path] = ('%s:%s/%s'):format(
      marks[path] or '',
      count and count.added or '',
      count and count.removed or ''
    )
  end
  return signatures
end

--- The files of `current` that were not in `previous`, or whose signature
--- differs from the one they had; none while there is no `previous`, the
--- first read of a place having nothing to compare with.
---
---@param previous table<string, string>|nil
---@param current table<string, string>
---@return table<string, true>
function M.flashed(previous, current)
  local flashed = {}
  if previous == nil then
    return flashed
  end
  for path, signature in pairs(current) do
    if previous[path] ~= signature then
      flashed[path] = true
    end
  end
  return flashed
end

return M
