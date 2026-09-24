--- The Report buffer: where reports are shown.

local M = {}

--- The Report buffer's name. Not a file path: a named buffer is never reused
--- by `:edit` the way an unnamed, empty one is.
local REPORT_BUFFER_NAME = 'aineo://report'

--- A new Report buffer: unlisted, named `REPORT_BUFFER_NAME` from the start,
--- no file (`'buftype'` `nofile`), no swap file, kept when hidden, and
--- read-only to the user (`'modifiable'` off; `append_lines()` still writes).
---
---@return integer buffer
function M.create_report_buffer()
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buffer, REPORT_BUFFER_NAME)
  vim.bo[buffer].modifiable = false
  return buffer
end

--- Whether `buffer` can still show reports: it exists and is loaded. A
--- deleted (`:bdelete`) Report is unloaded, and loading it again would make
--- it an ordinary buffer.
---
---@param buffer integer
---@return boolean
function M.is_showing(buffer)
  return vim.api.nvim_buf_is_valid(buffer) and vim.api.nvim_buf_is_loaded(buffer)
end

--- Wipes `buffer` out when it still exists, freeing its name.
---
---@param buffer integer
function M.discard(buffer)
  if vim.api.nvim_buf_is_valid(buffer) then
    vim.api.nvim_buf_delete(buffer, { force = true })
  end
end

--- Whether `buffer` holds nothing: the one empty line a new buffer starts with.
---
---@param buffer integer
---@return boolean
local function is_empty(buffer)
  return vim.api.nvim_buf_line_count(buffer) == 1
    and vim.api.nvim_buf_get_lines(buffer, 0, 1, true)[1] == ''
end

--- Adds `lines` to the end of `buffer`, replacing the empty line a new buffer
--- starts with. Writes whether or not the user may edit `buffer`, and leaves
--- `'modifiable'` as it found it.
---
---@param buffer integer
---@param lines string[] lines holding no newline
function M.append_lines(buffer, lines)
  local start = is_empty(buffer) and 0 or -1
  local modifiable = vim.bo[buffer].modifiable
  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, start, -1, false, lines)
  vim.bo[buffer].modifiable = modifiable
end

--- Moves the cursor of every window showing `buffer` to its last line.
---
---@param buffer integer
function M.follow_last_line(buffer)
  local last_line = vim.api.nvim_buf_line_count(buffer)
  for _, window in ipairs(vim.fn.win_findbuf(buffer)) do
    vim.api.nvim_win_set_cursor(window, { last_line, 0 })
  end
end

return M
