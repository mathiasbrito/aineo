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

--- The layout's windows and the buffers they show, by role.
local state = {
  ---@type table<aineo.layout.Role, integer>
  windows = {},
  ---@type table<aineo.layout.Role, integer>
  buffers = {},
  ---@type integer|nil
  input_buffer = nil,
  ---@type integer|nil the file column's window
  file_window = nil,
  ---@type number|nil the Report's share of the right column's height
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

--- Whether `buffer` holds a file: a buffer with an empty `'buftype'`.
---
---@param buffer integer
---@return boolean
local function is_file(buffer)
  return vim.bo[buffer].buftype == ''
end

--- Whether the file column is open.
---
---@return boolean
local function has_file_column()
  return state.file_window ~= nil and vim.api.nvim_win_is_valid(state.file_window)
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

--- Puts the layout's proportions back.
local function apply_proportions()
  size_columns()
  size_right_column()
end

--- Moves `file` from the layout's `window` to the file column — opened right
--- of Claude's column when it is not open — with the cursor there on the
--- position it had in `window`, gives `window` its own buffer back, and puts
--- the proportions back.
---
---@param window integer
---@param file integer
local function redirect(window, file)
  local cursor = vim.api.nvim_win_get_cursor(window)
  local file_window = state.file_window
  if file_window and vim.api.nvim_win_is_valid(file_window) then
    vim.api.nvim_win_set_buf(file_window, file)
    vim.api.nvim_set_current_win(file_window)
  else
    file_window = vim.api.nvim_open_win(file, true, { split = 'right', win = state.windows.claude })
    state.file_window = file_window
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

--- The buffer shown in `window` when it has no name, or a new buffer, made
--- Input: a named scratch buffer, unlisted, kept when hidden, with no swap
--- file.
---
---@param window integer
---@return integer buffer
local function take_input_buffer(window)
  local buffer = vim.api.nvim_win_get_buf(window)
  if vim.api.nvim_buf_get_name(buffer) ~= '' then
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

--- Opens the layout in the current tab: `arrangement.claude` in a column on
--- the left taking half the columns, `arrangement.report` above the Input
--- buffer in a column on the right, the Report taking
--- `arrangement.report_height` of its rows, and the cursor in Input. The tab's
--- other windows close; their buffers stay loaded. An unnamed buffer in the
--- current window, such as the empty one Neovim starts with, becomes Input.
---
--- From then on a file shown in one of the three windows moves to a file
--- column between Claude's and the right one, and the three columns take a
--- third of the screen each while it is open; the proportions are put back
--- whenever a window closes.
---
---@param arrangement aineo.layout.Arrangement
function M.open(arrangement)
  local input_window = vim.api.nvim_get_current_win()
  hide_other_windows(input_window)
  state.input_buffer = take_input_buffer(input_window)
  vim.api.nvim_win_set_buf(input_window, state.input_buffer)
  local report_window =
    vim.api.nvim_open_win(arrangement.report, false, { split = 'above', win = input_window })
  local claude_window =
    vim.api.nvim_open_win(arrangement.claude, false, { split = 'left', win = -1 })
  state.windows = { claude = claude_window, report = report_window, input = input_window }
  state.buffers =
    { claude = arrangement.claude, report = arrangement.report, input = state.input_buffer }
  state.report_height = arrangement.report_height
  apply_proportions()

  local group = vim.api.nvim_create_augroup('aineo.layout', {})
  vim.api.nvim_create_autocmd('BufWinEnter', { group = group, callback = redirect_when_file })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = group,
    callback = function()
      vim.schedule(apply_proportions)
    end,
  })
end

--- The Input buffer, or `nil` before the layout was first opened.
---
---@return integer|nil buffer
function M.input_buffer()
  return state.input_buffer
end

return M
