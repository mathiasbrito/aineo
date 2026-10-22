--- The office's window: a floating window with a scratch buffer, placed over a
--- rectangle of the screen. The window is not entered when it opens, so the
--- user's cursor stays where it was.

local M = {}

--- The filetype of the office's buffer.
local FILETYPE = 'aineo-office'

---@class aineo.office.Float
---@field buffer integer
---@field window integer

--- Opens the office's window over `area` with a buffer of its own.
---
--- The buffer is a scratch buffer no one edits, wiped when its window closes,
--- named `aineo://office-<buffer number>`: the number keeps the names of the
--- offices of several tab pages apart. The window shows only that buffer
--- (`'winfixbuf'`), draws no line numbers, sign column or cursor line, and
--- takes the colours of the editor's text.
---
---@param area aineo.layout.Area
---@return aineo.office.Float float
function M.open(area)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].bufhidden = 'wipe'
  vim.bo[buffer].undolevels = -1
  vim.bo[buffer].filetype = FILETYPE
  vim.bo[buffer].modifiable = false
  vim.api.nvim_buf_set_name(buffer, ('aineo://office-%d'):format(buffer))
  local window = vim.api.nvim_open_win(buffer, false, {
    relative = 'editor',
    row = area.row,
    col = area.col,
    width = area.width,
    height = area.height,
    style = 'minimal',
    focusable = true,
  })
  vim.wo[window].winfixbuf = true
  vim.wo[window].wrap = false
  vim.wo[window].winhighlight = 'NormalFloat:Normal'
  return { buffer = buffer, window = window }
end

--- Closes the window of `float`, which wipes its buffer, if it is open.
---
---@param float aineo.office.Float
function M.close(float)
  if vim.api.nvim_win_is_valid(float.window) then
    vim.api.nvim_win_close(float.window, true)
  end
end

--- Whether the window `window` lies in the cells the office's window covers:
--- its top left cell is inside them.
---
---@param float aineo.office.Float
---@param window integer
---@return boolean
function M.covers(float, window)
  local covered = vim.api.nvim_win_get_position(float.window)
  local width = vim.api.nvim_win_get_width(float.window)
  local height = vim.api.nvim_win_get_height(float.window)
  local position = vim.api.nvim_win_get_position(window)
  return position[1] >= covered[1]
    and position[1] < covered[1] + height
    and position[2] >= covered[2]
    and position[2] < covered[2] + width
end

return M
