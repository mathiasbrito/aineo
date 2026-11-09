--- What the editor's loaded buffers say of the files the explorer shows:
--- which have unsaved edits, and how many errors and warnings the editor's
--- diagnostics hold for each.

local M = {}

--- What the loaded buffers say, by the file's path in the tree.
---@class aineo.explorer.OpenBuffers
---@field modified table<string, true> the files with unsaved edits
---@field diagnostics table<string, aineo.explorer.DiagnosticCount> the files with an error or a warning

--- The errors and the warnings of `buffer`.
---
---@param buffer integer
---@return aineo.explorer.DiagnosticCount
local function diagnostic_count(buffer)
  local counts = vim.diagnostic.count(buffer)
  return {
    error = counts[vim.diagnostic.severity.ERROR] or 0,
    warn = counts[vim.diagnostic.severity.WARN] or 0,
  }
end

--- Reads the loaded buffers that hold a file, `path_in_tree` turning a
--- file's full name into its path in the tree, nil or empty when it lies
--- outside; a buffer that is no file, and one that is not loaded, are left
--- out.
---
---@param path_in_tree fun(file: string): string|nil
---@return aineo.explorer.OpenBuffers
function M.read(path_in_tree)
  local read = { modified = {}, diagnostics = {} }
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buffer)
    if vim.api.nvim_buf_is_loaded(buffer) and vim.bo[buffer].buftype == '' and name ~= '' then
      local path = path_in_tree(name)
      if path and path ~= '' then
        read.modified[path] = vim.bo[buffer].modified or nil
        local count = diagnostic_count(buffer)
        if count.error + count.warn > 0 then
          read.diagnostics[path] = count
        end
      end
    end
  end
  return read
end

return M
