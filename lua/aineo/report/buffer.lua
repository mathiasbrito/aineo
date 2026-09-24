--- The Report buffer: where reports are shown.

local M = {}

--- The Report buffer's name. Not a file path: a named buffer is never reused
--- by `:edit` the way an unnamed, empty one is.
local REPORT_BUFFER_NAME = 'aineo://report'

--- Wipes out every buffer named `REPORT_BUFFER_NAME`: one a restored session
--- or the user made (`:edit aineo://report`) is not the Report, and holds the
--- name the Report needs.
local function free_report_buffer_name()
  for _, other in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(other) == REPORT_BUFFER_NAME then
      vim.api.nvim_buf_delete(other, { force = true })
    end
  end
end

--- A new Report buffer: unlisted, named `REPORT_BUFFER_NAME` from the start,
--- no file (`'buftype'` `nofile`), no swap file, kept when hidden, and
--- read-only to the user (`'modifiable'` off; `append_lines()` still writes).
--- Any other buffer holding the name is wiped out first.
---
--- `:edit` in the Report empties it, as it does any buffer that is no file;
--- `fill` is then called with the emptied buffer to show its reports again.
--- The autocommand doing so belongs to the buffer, in the group `aineo_report`,
--- which is never cleared: a Report's handler must outlive the next Report's
--- creation.
---
---@param fill fun(buffer: integer) shows the reports in the emptied buffer
---@return integer buffer
function M.create_report_buffer(fill)
  free_report_buffer_name()
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buffer, REPORT_BUFFER_NAME)
  vim.bo[buffer].modifiable = false
  vim.api.nvim_create_autocmd('BufReadCmd', {
    group = vim.api.nvim_create_augroup('aineo_report', { clear = false }),
    buffer = buffer,
    callback = function(event)
      fill(event.buf)
    end,
  })
  return buffer
end

--- Whether `buffer` can still show reports: it exists and is still no file.
--- A deleted (`:bdelete`) Report loses its `'buftype'`, and one the user
--- shows again (`:buffer #`) comes back as an ordinary buffer, which a report
--- would leave modified and `:qall` would then refuse to leave (E37).
---
---@param buffer integer
---@return boolean
function M.is_showing(buffer)
  return vim.api.nvim_buf_is_valid(buffer) and vim.bo[buffer].buftype == 'nofile'
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
