--- The Report buffer: where reports are shown.

local M = {}

--- The namespace of the colours the Report shows.
local REPORT_COLOURS = vim.api.nvim_create_namespace('aineo_report_colours')

--- The Report buffer's name. Not a file path: a named buffer is never reused
--- by `:edit` the way an unnamed, empty one is.
local REPORT_BUFFER_NAME = 'aineo://report'

--- Frees the name `buffer` holds: wipes `buffer` out, unless the user
--- changed its text, which is then kept in `buffer`, unnamed (`:0file`).
---
---@param buffer integer
local function free_name_held_by(buffer)
  if vim.bo[buffer].modified then
    vim.api.nvim_buf_call(buffer, function()
      vim.cmd('0file')
    end)
  else
    vim.api.nvim_buf_delete(buffer, { force = true })
  end
end

--- Frees `REPORT_BUFFER_NAME` from every buffer holding it
--- (`free_name_held_by()`): one a restored session or the user made
--- (`:edit aineo://report`) is not the Report, and holds the name the Report
--- needs.
local function free_report_buffer_name()
  for _, other in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(other) == REPORT_BUFFER_NAME then
      free_name_held_by(other)
    end
  end
end

--- A new Report buffer: unlisted, named `REPORT_BUFFER_NAME` from the start,
--- no file (`'buftype'` `nofile`), no swap file, kept when hidden, and
--- read-only to the user (`'modifiable'` off; `append_rendering()` still
--- writes).
--- Any other buffer holding the name gives it up first: it is wiped out, or
--- kept unnamed when the user changed its text.
---
--- `:edit` in the Report empties it, as it does any buffer that is no file;
--- `fill` is then called with the emptied buffer to show its reports again.
--- The autocommand doing so belongs to the buffer, in the group
--- `aineo_report`, created anew with each Report: that clears the
--- autocommand of any Report before it, which by then is wiped out, or kept
--- unnamed for the text the user typed into it.
---
---@param fill fun(buffer: integer) shows the reports in the emptied buffer
---@return integer buffer
function M.create_report_buffer(fill)
  free_report_buffer_name()
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buffer, REPORT_BUFFER_NAME)
  vim.bo[buffer].modifiable = false
  vim.api.nvim_create_autocmd('BufReadCmd', {
    group = vim.api.nvim_create_augroup('aineo_report', {}),
    buffer = buffer,
    callback = function(event)
      fill(event.buf)
    end,
  })
  return buffer
end

--- Whether `buffer` can still show reports: it exists, is loaded, and is
--- still no file. An unloaded (`:bunload`) Report keeps its `'buftype'`, but
--- a report written into it loads it, which shows every record again before
--- the report is added. A deleted (`:bdelete`) Report loses its `'buftype'`,
--- and one the user shows again (`:buffer #`) comes back as an ordinary
--- buffer, which a report would leave modified and `:qall` would then refuse
--- to leave (E37).
---
---@param buffer integer
---@return boolean
function M.is_showing(buffer)
  return vim.api.nvim_buf_is_valid(buffer)
    and vim.api.nvim_buf_is_loaded(buffer)
    and vim.bo[buffer].buftype == 'nofile'
end

--- Frees the name `buffer` holds when it still exists: wipes it out, or
--- keeps it unnamed when the user changed its text (`free_name_held_by()`).
---
---@param buffer integer
function M.discard(buffer)
  if vim.api.nvim_buf_is_valid(buffer) then
    free_name_held_by(buffer)
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
local function append_lines(buffer, lines)
  local start = is_empty(buffer) and 0 or -1
  local modifiable = vim.bo[buffer].modifiable
  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, start, -1, false, lines)
  vim.bo[buffer].modifiable = modifiable
end

--- Adds `rendering` to the end of `buffer`: its lines, as `append_lines()`
--- does, and its colours on them. An empty `buffer` first loses every colour
--- still on it: `:edit` empties the Report of its text, not of its colours.
---
---@param buffer integer
---@param rendering aineo.report.Rendering
function M.append_rendering(buffer, rendering)
  local first_line = vim.api.nvim_buf_line_count(buffer)
  if is_empty(buffer) then
    first_line = 0
    vim.api.nvim_buf_clear_namespace(buffer, REPORT_COLOURS, 0, -1)
  end
  append_lines(buffer, rendering.lines)
  for _, colour in ipairs(rendering.colours) do
    vim.api.nvim_buf_set_extmark(
      buffer,
      REPORT_COLOURS,
      first_line + colour.line,
      colour.first_column,
      {
        end_col = colour.end_column,
        hl_group = colour.group,
      }
    )
  end
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
