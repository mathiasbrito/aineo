--- How much of a file the diffs the changes home shows have around their
--- changes: three lines, or the whole file. The choice is the editor's, kept
--- for its life and never on disk: it starts at three lines, and
--- `M.use()` changes it.

local M = {}

--- The context the diffs are read in now (`aineo.git.DiffContext`).
---@type aineo.git.DiffContext
local current = 'three_lines'

--- The context the diffs are read in now.
---
---@return aineo.git.DiffContext
function M.current()
  return current
end

--- Reads the diffs from now on in `context`.
---
---@param context aineo.git.DiffContext
function M.use(context)
  current = context
end

--- The context a diff read in `context` is turned into by the toggle: the
--- whole file for three lines, three lines for the whole file.
---
---@param context aineo.git.DiffContext
---@return aineo.git.DiffContext
function M.other(context)
  return context == 'whole_file' and 'three_lines' or 'whole_file'
end

return M
