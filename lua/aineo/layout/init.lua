--- aineo's layout, `require('aineo.layout')`: the Claude terminal in a column
--- on the left, the Report above Input in a column on the right.
---
--- The layout shows the Claude and Report buffers it is handed and never
--- creates, writes or deletes them; the Input buffer is its own.

local M = {}

---@class aineo.layout.Arrangement
---@field claude integer the Claude session's terminal buffer
---@field report integer the Report buffer
---@field report_height number the Report's share of the right column's height, strictly between 0 and 1

---@alias aineo.layout.Role 'claude'|'report'|'input'

--- The layout's windows and the buffers they show, by role, and the
--- Report's share of the right column's height.
local state = {
  ---@type table<aineo.layout.Role, integer>
  windows = {},
  ---@type table<aineo.layout.Role, integer>
  buffers = {},
  ---@type number|nil
  report_height = nil,
}

--- The role of `window` in the layout, or `nil` when it is not one of its
--- three windows.
---
---@param window integer
---@return aineo.layout.Role|nil role
local function role_of(window)
  for role, layout_window in pairs(state.windows) do
    if layout_window == window then
      return role
    end
  end
  return nil
end

---@type aineo.layout.Role[]
local ROLES = { 'claude', 'report', 'input' }

--- Whether the layout's window for `role` exists.
---
---@param role aineo.layout.Role
---@return boolean
local function has_window(role)
  local window = state.windows[role]
  return window ~= nil and vim.api.nvim_win_is_valid(window)
end

--- Whether the layout is open: its three windows exist.
---
---@return boolean
local function is_open()
  return vim.iter(ROLES):all(has_window)
end

--- Whether any of the layout's three windows exists.
---
---@return boolean
local function has_any_window()
  return vim.iter(ROLES):any(has_window)
end

--- Whether `buffer` holds a file: a buffer with an empty `'buftype'`.
---
---@param buffer integer
---@return boolean
local function is_file(buffer)
  return vim.bo[buffer].buftype == ''
end

--- The windows of a node of `winlayout()`'s tree, left to right and top to
--- bottom.
---
---@param node table a `{ 'leaf', window }`, `{ 'row', nodes }` or `{ 'col', nodes }` node
---@return integer[] windows
local function windows_of(node)
  if node[1] == 'leaf' then
    return { node[2] }
  end
  local windows = {}
  for _, child in ipairs(node[2]) do
    vim.list_extend(windows, windows_of(child))
  end
  return windows
end

--- The file column's windows: those of the columns between Claude's column
--- and the right one, top to bottom; none when the file column is not open.
---
---@return integer[] windows
local function file_column_windows()
  local tab = vim.api.nvim_win_get_tabpage(state.windows.claude)
  local screen = vim.fn.winlayout(vim.api.nvim_tabpage_get_number(tab))
  if screen[1] ~= 'row' then
    return {}
  end
  local windows = {}
  local past_claude = false
  for _, column in ipairs(screen[2]) do
    local column_windows = windows_of(column)
    if vim.list_contains(column_windows, state.windows.report) then
      break
    end
    if past_claude then
      vim.list_extend(windows, column_windows)
    end
    past_claude = past_claude or vim.list_contains(column_windows, state.windows.claude)
  end
  return windows
end

--- Whether the file column is open.
---
---@return boolean
local function has_file_column()
  return #file_column_windows() > 0
end

--- Sizes the columns. With the file column open, Claude's column and the right
--- one take a third each of the screen's columns, the two separators taken
--- out, and the file column the rest; without it, Claude's column takes half
--- and the right one the rest.
local function size_columns()
  if has_file_column() then
    local third = math.floor((vim.o.columns - 2) / 3)
    vim.api.nvim_win_set_width(state.windows.claude, third)
    vim.api.nvim_win_set_width(state.windows.report, third)
  else
    vim.api.nvim_win_set_width(state.windows.claude, math.floor(vim.o.columns / 2))
  end
end

--- Gives the Report its share of the rows the Report and Input hold together.
local function size_right_column()
  local rows = vim.api.nvim_win_get_height(state.windows.report)
    + vim.api.nvim_win_get_height(state.windows.input)
  vim.api.nvim_win_set_height(state.windows.report, math.floor(rows * state.report_height + 0.5))
end

--- Keeps Neovim from resizing the layout's three windows when it makes
--- windows equal (`:wincmd =`, `'equalalways'`).
local function pin_windows()
  for _, window in pairs(state.windows) do
    vim.wo[window].winfixwidth = true
    vim.wo[window].winfixheight = true
  end
end

--- Puts the layout's proportions back.
local function apply_proportions()
  size_columns()
  size_right_column()
end

--- Puts the layout's proportions back while it is open, and does nothing
--- once one of its three windows is gone.
local function keep_proportions()
  if is_open() then
    apply_proportions()
  end
end

--- Moves `file` from the layout's `window` to the file column — opened right
--- of Claude's column when it is not open — with the cursor there on the
--- position it had in `window`, gives `window` its own buffer back, and puts
--- the proportions back. Does nothing when the layout is not open, or
--- `window` no longer shows `file`.
---
---@param window integer
---@param file integer
local function redirect(window, file)
  if not is_open() or vim.api.nvim_win_get_buf(window) ~= file then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(window)
  local file_window = file_column_windows()[1]
  if file_window then
    vim.api.nvim_win_set_buf(file_window, file)
    vim.api.nvim_set_current_win(file_window)
  else
    file_window = vim.api.nvim_open_win(file, true, { split = 'right', win = state.windows.claude })
  end
  vim.api.nvim_win_set_cursor(file_window, cursor)
  vim.api.nvim_win_set_buf(window, state.buffers[role_of(window)])
  apply_proportions()
end

--- Redirects a file shown in one of the layout's windows, once the command
--- that showed it has finished with that window.
---
---@param event { buf: integer }
local function redirect_when_file(event)
  local window = vim.api.nvim_get_current_win()
  if not role_of(window) or not is_file(event.buf) then
    return
  end
  vim.schedule(function()
    redirect(window, event.buf)
  end)
end

--- The Input buffer's name: not a file path, so `:edit` never takes the
--- buffer for one.
local INPUT_NAME = 'aineo://input'

--- Whether `buffer` has no name and holds no text, as the buffer Neovim
--- starts with.
---
---@param buffer integer
---@return boolean
local function is_unnamed_and_empty(buffer)
  return vim.api.nvim_buf_get_name(buffer) == ''
    and vim.api.nvim_buf_line_count(buffer) == 1
    and vim.api.nvim_buf_get_lines(buffer, 0, 1, true)[1] == ''
end

--- The Input buffer: the one the layout made before, while it exists; else
--- `shown` when it has no name and holds no text, or else a new buffer, made
--- Input: a named scratch buffer, unlisted, kept when hidden, with no swap
--- file.
---
---@param shown integer the buffer of the window the layout opens from
---@return integer input
local function take_input_buffer(shown)
  local existing = state.buffers.input
  if existing and vim.api.nvim_buf_is_valid(existing) then
    return existing
  end
  local buffer = shown
  if not is_unnamed_and_empty(buffer) then
    buffer = vim.api.nvim_create_buf(false, true)
  end
  vim.bo[buffer].buftype = 'nofile'
  vim.bo[buffer].bufhidden = 'hide'
  vim.bo[buffer].buflisted = false
  vim.bo[buffer].swapfile = false
  vim.api.nvim_buf_set_name(buffer, INPUT_NAME)
  return buffer
end

--- Closes every window of the current tab but `kept`, hiding their buffers,
--- which stay loaded.
---
---@param kept integer the window to keep
local function hide_other_windows(kept)
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if window ~= kept then
      vim.api.nvim_win_hide(window)
    end
  end
end

--- Makes the layout's three windows in the current tab, closing its other
--- windows, with the cursor in Input. The current window becomes Input's,
--- unless it shows a file, which it keeps as the file column.
---
---@param arrangement aineo.layout.Arrangement
local function build(arrangement)
  local current_window = vim.api.nvim_get_current_win()
  local shown = vim.api.nvim_win_get_buf(current_window)
  hide_other_windows(current_window)
  local input = take_input_buffer(shown)
  local input_window = current_window
  if shown ~= input and is_file(shown) then
    input_window = vim.api.nvim_open_win(input, true, { split = 'right', win = -1 })
  else
    vim.api.nvim_win_set_buf(input_window, input)
  end
  local report_window =
    vim.api.nvim_open_win(arrangement.report, false, { split = 'above', win = input_window })
  local claude_window =
    vim.api.nvim_open_win(arrangement.claude, false, { split = 'left', win = -1 })
  state.windows = { claude = claude_window, report = report_window, input = input_window }
  state.buffers = { claude = arrangement.claude, report = arrangement.report, input = input }
end

--- Opens again, in their places, those of the layout's three windows that
--- were closed, each showing its buffer: Claude's as the leftmost column, the
--- Report above Input, or as the rightmost column when Input is closed too,
--- and Input below the Report.
local function reopen_closed_windows()
  if not has_window('claude') then
    state.windows.claude =
      vim.api.nvim_open_win(state.buffers.claude, false, { split = 'left', win = -1 })
  end
  if not has_window('report') then
    local place = has_window('input') and { split = 'above', win = state.windows.input }
      or { split = 'right', win = -1 }
    state.windows.report = vim.api.nvim_open_win(state.buffers.report, false, place)
  end
  if not has_window('input') then
    state.windows.input = vim.api.nvim_open_win(
      state.buffers.input,
      false,
      { split = 'below', win = state.windows.report }
    )
  end
end

--- Shows each of the layout's buffers in its window, where another took its
--- place.
local function show_buffers()
  for _, role in ipairs(ROLES) do
    local window = state.windows[role]
    if vim.api.nvim_win_get_buf(window) ~= state.buffers[role] then
      vim.api.nvim_win_set_buf(window, state.buffers[role])
    end
  end
end

--- Redirects the files shown in the layout's windows, and puts the
--- proportions back whenever a window closes or the editor is resized,
--- replacing what an earlier call set up. A window is still in the layout
--- while `WinClosed` runs, so the proportions are put back after it.
local function watch_windows()
  local group = vim.api.nvim_create_augroup('aineo.layout', {})
  vim.api.nvim_create_autocmd('BufWinEnter', { group = group, callback = redirect_when_file })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = group,
    callback = function()
      vim.schedule(keep_proportions)
    end,
  })
  vim.api.nvim_create_autocmd('VimResized', { group = group, callback = keep_proportions })
end

--- Whether `value` is the number of an existing buffer.
---
---@param value any
---@return boolean
local function is_buffer(value)
  return type(value) == 'number' and vim.api.nvim_buf_is_valid(value)
end

--- Whether `value` is a share: a number strictly between 0 and 1.
---
---@param value any
---@return boolean
local function is_share(value)
  return type(value) == 'number' and value > 0 and value < 1
end

--- Raises an error naming the first setting of `arrangement` the layout
--- cannot show.
---
---@param arrangement any
local function validate_arrangement(arrangement)
  vim.validate('arrangement', arrangement, 'table')
  vim.validate('arrangement.claude', arrangement.claude, is_buffer, false, 'a buffer')
  vim.validate('arrangement.report', arrangement.report, is_buffer, false, 'a buffer')
  vim.validate(
    'arrangement.report_height',
    arrangement.report_height,
    is_share,
    false,
    'a number strictly between 0 and 1'
  )
end

--- Opens the layout in the current tab: `arrangement.claude` in a column on
--- the left taking half the columns, `arrangement.report` above the Input
--- buffer in a column on the right, the Report taking
--- `arrangement.report_height` of its rows, and the cursor in Input. The tab's
--- other windows close; their buffers stay loaded. A file the current window
--- shows stays there, as the file column. Input is made once and kept: from
--- the unnamed, empty buffer the current window shows, such as the one Neovim
--- starts with, or else a new buffer.
---
--- While any of the three windows exists, opening again restores the layout
--- instead: it creates only the windows that were closed, in their places,
--- shows in each window its buffer — the Claude and Report buffers it is
--- handed this time — and puts the proportions back; the cursor stays where
--- it is.
---
--- From then on a file shown in one of the three windows moves to a file
--- column between Claude's and the right one, and the three columns take a
--- third of the screen each while it is open; the proportions are put back
--- whenever a window closes or the editor is resized.
---
--- Raises an error naming the setting, before changing anything, when
--- `arrangement` is not a table, `claude` or `report` is not an existing
--- buffer, or `report_height` is not a number strictly between 0 and 1.
---
---@param arrangement aineo.layout.Arrangement
function M.open(arrangement)
  validate_arrangement(arrangement)
  if has_any_window() then
    state.buffers.claude = arrangement.claude
    state.buffers.report = arrangement.report
    reopen_closed_windows()
    show_buffers()
  else
    build(arrangement)
  end
  state.report_height = arrangement.report_height
  pin_windows()
  apply_proportions()
  watch_windows()
end

--- Moves the cursor to the layout's window for `role`, opening the layout
--- with `arrangement` first when that window is gone (see `open()`).
---
--- Raises an error naming `role` when it is not one of the three windows.
---
---@param role aineo.layout.Role
---@param arrangement aineo.layout.Arrangement
function M.focus(role, arrangement)
  vim.validate('role', role, function(value)
    return vim.list_contains(ROLES, value)
  end, false, "'claude', 'report' or 'input'")
  if not has_window(role) then
    M.open(arrangement)
  end
  vim.api.nvim_set_current_win(state.windows[role])
end

--- The Input buffer, or `nil` before the layout was first opened.
---
---@return integer|nil buffer
function M.input_buffer()
  return state.buffers.input
end

return M
