--- The heights of a column of windows while one of them is zoomed: the
--- zoomed window takes every row the others can spare, and the others keep
--- their least height, one line each. The heights the windows had are kept, to
--- give back.

local M = {}

--- A zoomed column.
---@class aineo.layout.Zoom
---@field window integer the zoomed window
---@field windows integer[] the column's windows, top to bottom
---@field heights integer[] the height each of `windows` had before the zoom, by position

--- Gives `zoomed` every row the other windows of its column can spare: asked
--- for more rows than the screen has, Neovim shrinks them to their least
--- height, one line, with the window's winbar besides, or `'winminheight'` where
--- that is above one.
---
---@param zoomed integer
local function take_rows(zoomed)
  vim.api.nvim_win_set_height(zoomed, vim.o.lines)
end

--- Zooms `zoomed` in the column of `windows`, and keeps the heights the
--- windows had.
---
---@param windows integer[] the column's windows, top to bottom, `zoomed` among them
---@param zoomed integer
---@return aineo.layout.Zoom zoom
function M.start(windows, zoomed)
  local heights = vim.tbl_map(vim.api.nvim_win_get_height, windows)
  take_rows(zoomed)
  return { window = zoomed, windows = windows, heights = heights }
end

--- Zooms the window of `zoom` again, as the rows of the column changed under
--- it, such as when the editor is resized.
---
---@param zoom aineo.layout.Zoom
function M.keep(zoom)
  take_rows(zoom.window)
end

--- Gives the windows of `zoom` the heights they had before it, each but the
--- last in turn from the top; the last takes the rows that remain, which are
--- those it had unless the editor was resized since.
---
---@param zoom aineo.layout.Zoom
function M.restore(zoom)
  for index = 1, #zoom.windows - 1 do
    vim.api.nvim_win_set_height(zoom.windows[index], zoom.heights[index])
  end
end

return M
