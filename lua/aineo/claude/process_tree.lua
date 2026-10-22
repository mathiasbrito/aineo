--- Where a process stands in the tree of processes the system runs: whether
--- it runs apart from another, neither it nor any process it descends from
--- being that one.

local M = {}

--- How many processes a walk up the tree reads at most: more than any chain
--- of programs between a terminal's job and the Claude Code it starts.
local MAX_DEPTH = 64

--- Whether the process `pid` runs outside the tree of the process `root`:
--- both run, and neither `pid` nor any process it descends from, read by
--- their parents' pids (`nvim_get_proc()`), is `root`. False when either
--- does not run, and when the walk reads `MAX_DEPTH` processes without
--- reaching one with no parent.
---
---@param pid integer
---@param root integer
---@return boolean
function M.runs_outside(pid, root)
  local process = vim.api.nvim_get_proc(pid)
  if not (process and vim.api.nvim_get_proc(root)) then
    return false
  end
  for _ = 1, MAX_DEPTH do
    if process.pid == root then
      return false
    end
    process = process.ppid ~= 0 and vim.api.nvim_get_proc(process.ppid) or nil
    if not process then
      return true
    end
  end
  return false
end

return M
