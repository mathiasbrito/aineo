--- What a transcript signal says about the files an agent edits. Pure: it holds
--- no editor state.

local M = {}

--- The tools that change a file, each with the fields of its input that name
--- the file, in the order they are tried.
---@type table<string, string[]>
local EDITING_TOOLS = {
  Edit = { 'file_path' },
  Write = { 'file_path' },
  NotebookEdit = { 'notebook_path', 'file_path' },
}

--- The absolute path of the file the call `signal` edits: the path an `Edit`,
--- `Write` or `NotebookEdit` call gives. Nil for a signal that is no call of
--- those tools, for a call that gives no path, one that is not text, and one
--- that is not absolute: a relative path names no checkout.
---
---@param signal aineo.transcript.Signal
---@return string|nil path
function M.edited_path(signal)
  local fields = signal.kind == 'tool_started' and signal.tool and EDITING_TOOLS[signal.tool]
  if not fields then
    return nil
  end
  for _, field in ipairs(fields) do
    local path = signal.input and signal.input[field]
    if type(path) == 'string' and vim.startswith(path, '/') then
      return path
    end
  end
  return nil
end

return M
