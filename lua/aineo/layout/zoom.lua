--- The heights of a column of windows while one of them is zoomed: the
--- zoomed window takes every row the others can spare, and the others keep one
--- line each. The heights the windows had are kept, to give back.

local M = {}

--- The height the windows that are not zoomed are given.
local ONE_LINE = 1

--- A zoomed column.
---@class aineo.layout.Zoom
---@field window integer the zoomed window
---@field windows integer[] the column's windows, top to bottom
---@field heights integer[] the height each of `windows` had before the zoom, by position

--- Gives `zoomed` every row the other windows of `windows` can spare, those
--- shrunk to one line each. Neovim keeps a window at the height of
--- `'winminheight'` at least, with the window's winbar besides, so with that
--- option above one, or a winbar, the others keep that height and `zoomed`
--- takes the rest.
---
---@param windows integer[]
---@param zoomed integer
local function take_rows(windows, zoomed)
  for _, window in ipairs(windows) do
    if window ~= zoomed then
      vim.api.nvim_win_set_height(window, ONE_LINE)
    end
  end
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
  take_rows(windows, zoomed)
  return { window = zoomed, windows = windows, heights = heights }
end

--- Zooms the window of `zoom` again, as the rows of the column changed under
--- it, such as when the editor is resized.
---
---@param zoom aineo.layout.Zoom
function M.keep(zoom)
  take_rows(zoom.windows, zoom.window)
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
