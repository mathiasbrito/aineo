--- The Report buffer: where reports are shown.

local colours = require('aineo.report.colours')
local render = require('aineo.report.render')

local M = {}

--- The namespace of the colours the Report shows, its web links' and its
--- paths' included.
local REPORT_COLOURS = vim.api.nvim_create_namespace('aineo_report_colours')

--- The Report buffer's name. Not a file path: a named buffer is never reused
--- by `:edit` the way an unnamed, empty one is.
local REPORT_BUFFER_NAME = 'aineo://report'

--- The `'breakindentopt'` of a window showing the Report: a wrapped line
--- continues after the part of its line that `'formatlistpat'` matches, and
--- further left only where that would leave it fewer than 10 columns of text.
local CONTINUE_UNDER_LIST_MATCH = 'list:-1,min:10'

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

--- The text of the path the Report draws, in `colours.PATH_GROUP`, over byte
--- `column` of line `line` of `buffer`, both from 0, or nil when it draws
--- none there.
---
---@param buffer integer
---@param line integer
---@param column integer
---@return string?
local function path_drawn_at(buffer, line, column)
  local marks = vim.api.nvim_buf_get_extmarks(
    buffer,
    REPORT_COLOURS,
    { line, column },
    { line, column },
    { details = true, overlap = true }
  )
  for _, mark in ipairs(marks) do
    local first_column, details = mark[3], mark[4]
    if
      details.hl_group == colours.PATH_GROUP
      and first_column <= column
      and column < details.end_col
    then
      return vim.api.nvim_buf_get_text(buffer, line, first_column, line, details.end_col, {})[1]
    end
  end
  return nil
end

--- The text of the path the Report `buffer` draws where the mouse was last
--- clicked (`getmousepos()`), or nil when it draws none there or the click
--- was not on it.
---
---@param buffer integer
---@return string?
local function path_under_mouse(buffer)
  local mouse = vim.fn.getmousepos()
  if mouse.winid == 0 or mouse.line == 0 or vim.api.nvim_win_get_buf(mouse.winid) ~= buffer then
    return nil
  end
  return path_drawn_at(buffer, mouse.line - 1, mouse.column - 1)
end

--- What a double-click does in the Report `buffer`: on a path it draws, ends
--- Insert mode and hands `open_path` the path's text; anywhere else, it does
--- what Neovim's own double-click does (`<2-LeftMouse>`, typed as if no
--- mapping had it), which selects the word under the mouse.
---
---@param buffer integer
---@param open_path fun(path: string)
local function double_click(buffer, open_path)
  local path = path_under_mouse(buffer)
  if not path then
    vim.api.nvim_feedkeys(vim.keycode('<2-LeftMouse>'), 'ni', false)
    return
  end
  vim.cmd.stopinsert()
  open_path(path)
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
--- autocommands of any Report before it, which by then is wiped out, or kept
--- unnamed for the text the user typed into it.
---
--- A window showing the Report wraps a long line under the text it starts
--- (`render.CONTINUATION_PATTERN` as its `'formatlistpat'`): each time it
--- shows the Report, the autocommand of the same group sets its
--- `'breakindentopt'` to `CONTINUE_UNDER_LIST_MATCH` as `:setlocal` does, so
--- another buffer shown in that window, or in a window split from it, keeps
--- its own.
---
--- A double-click (`<2-LeftMouse>`), in Normal or Insert mode, does what
--- `double_click()` says: on a path the Report draws, it hands `open_path`
--- the path's text, as the Report shows it. The mapping belongs to the
--- buffer, so each new Report gets its own.
---
---@param fill fun(buffer: integer) shows the reports in the emptied buffer
---@param open_path fun(path: string) opens the file a path the Report draws names
---@return integer buffer
function M.create_report_buffer(fill, open_path)
  free_report_buffer_name()
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buffer, REPORT_BUFFER_NAME)
  vim.bo[buffer].modifiable = false
  vim.bo[buffer].formatlistpat = render.CONTINUATION_PATTERN
  local group = vim.api.nvim_create_augroup('aineo_report', {})
  vim.api.nvim_create_autocmd('BufReadCmd', {
    group = group,
    buffer = buffer,
    callback = function(event)
      fill(event.buf)
    end,
  })
  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = group,
    buffer = buffer,
    callback = function()
      vim.wo[0][0].breakindentopt = CONTINUE_UNDER_LIST_MATCH
    end,
  })
  vim.keymap.set({ 'n', 'i' }, '<2-LeftMouse>', function()
    double_click(buffer, open_path)
  end, { buffer = buffer, desc = 'aineo: open the file a path in the Report names' })
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
--- does, and its colours on them, a web link's carrying its address (an
--- extmark's `url`, which the terminal is given as a hyperlink and `gx`
--- opens). The colours are placed in their order, at one priority, so where
--- two cover the same text the later shows over the earlier. An empty
--- `buffer` first loses every colour still on it: `:edit` empties the Report
--- of its text, not of its colours.
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
        url = colour.url,
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
