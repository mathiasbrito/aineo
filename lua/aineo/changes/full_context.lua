--- How much of a file the diffs the changes home shows have around their
--- changes: three lines, or the whole file. The choice is the editor's, kept
--- for its life and never on disk: it starts at three lines, and `M.flip()`
--- changes it.

local M = {}

--- Whether the diffs show the whole file.
local shows_whole_file = false

--- The context the diffs are read in now (`aineo.git.DiffContext`).
---
---@return aineo.git.DiffContext
function M.current()
  return shows_whole_file and 'whole_file' or 'three_lines'
end

--- Changes the context the diffs are read in, from three lines to the whole
--- file or back, and returns the one they are now read in.
---
---@return aineo.git.DiffContext
function M.flip()
  shows_whole_file = not shows_whole_file
  return M.current()
end

return M
