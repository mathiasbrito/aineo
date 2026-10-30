--- The folder a request about a file runs in: the project holding the file.

local M = {}

--- The nearest folder that exists among the folders holding `path`: its
--- own, else the first of its parents, which a file not written yet may lack.
---
---@param path string a file's absolute path
---@return string
local function nearest_existing_folder(path)
  local folder = vim.fs.dirname(path)
  while not vim.uv.fs_stat(folder) do
    local parent = vim.fs.dirname(folder)
    if parent == folder then
      break
    end
    folder = parent
  end
  return folder
end

--- The folder Claude Code runs in for the file at `path`: the top level of
--- the git repository holding it, else the nearest folder of the file that
--- exists (`nearest_existing_folder()`).
---
---@param path string the file's absolute path
---@return string
function M.project_of(path)
  return vim.fs.root(path, '.git') or nearest_existing_folder(path)
end

return M
