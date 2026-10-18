--- The heights of a column of windows while one of them is zoomed: the
--- zoomed window takes every row the others can spare, and the others keep
--- `'winminheight'` lines each (one by default). The heights the windows had
--- are kept, to give back.

local M = {}

--- A zoomed column.
---@class aineo.layout.Zoom
---@field window integer the zoomed window
---@field windows integer[] the column's windows, top to bottom
---@field heights integer[] the height each of `windows` had before the zoom, by position

--- Gives `zoomed` the rows the other windows of `windows` can spare: each
--- keeps `'winminheight'` lines (one by default, none at 0), a window's winbar
--- besides, and gives the rest. Asking for exactly those rows, and no more,
--- keeps Neovim from taking rows from a window outside the column, such as one
--- across the whole width below it.
---
---@param zoomed integer
---@param windows integer[] the column's windows, `zoomed` among them
local function take_rows(zoomed, windows)
  local rows = vim.api.nvim_win_get_height(zoomed)
  for _, window in ipairs(windows) do
    if window ~= zoomed then
      rows = rows + math.max(0, vim.fn.winheight(window) - vim.o.winminheight)
    end
  end
  vim.api.nvim_win_set_height(zoomed, rows)
end

--- Zooms `zoomed` in the column of `windows`, and keeps the heights the
--- windows had.
---
---@param windows integer[] the column's windows, top to bottom, `zoomed` among them
---@param zoomed integer
---@return aineo.layout.Zoom zoom
function M.start(windows, zoomed)
  local heights = vim.tbl_map(vim.api.nvim_win_get_height, windows)
  take_rows(zoomed, windows)
  return { window = zoomed, windows = windows, heights = heights }
end

--- Zooms the window of `zoom` again, as the rows of the column changed under
--- it, such as when the editor is resized.
---
---@param zoom aineo.layout.Zoom
function M.keep(zoom)
  take_rows(zoom.window, zoom.windows)
end

--- Gives the windows of `zoom` the heights they had before it, each but the
--- last in turn from the top; the last takes the rows that remain. When the
--- windows hold as many rows together as they did, those are the heights they
--- had; when the editor was resized since, the heights they had are scaled to
--- the rows they hold now.
---
---@param zoom aineo.layout.Zoom
function M.restore(zoom)
  local recorded, rows = 0, 0
  for index, window in ipairs(zoom.windows) do
    recorded = recorded + zoom.heights[index]
    rows = rows + vim.api.nvim_win_get_height(window)
  end
  for index = 1, #zoom.windows - 1 do
    local height = zoom.heights[index]
    if rows ~= recorded then
      height = math.floor(height * rows / recorded + 0.5)
    end
    vim.api.nvim_win_set_height(zoom.windows[index], height)
  end
end

return M
