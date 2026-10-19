--- The sizes of the windows of a tab page while one of them is zoomed fully:
--- the zoomed window takes every column and row the others can spare, and
--- they keep `'winminwidth'` columns or `'winminheight'` lines each, wherever
--- they sit. The sizes the windows had are kept, to give back.

local M = {}

--- A tab page's fully zoomed window.
---@class aineo.layout.FullZoom
---@field window integer the zoomed window
---@field windows integer[] the tab page's windows that are not floating, in the order the tab page lists them
---@field sizes { width: integer, height: integer }[] the size each of `windows` had before the zoom, by position
---@field editor { columns: integer, lines: integer } the size of the editor when the zoom began

--- Gives `zoomed` every column and row the other windows of its tab page can
--- spare: Neovim takes what it asks for beyond the screen's size from the
--- others, down to their least.
---
---@param zoomed integer
local function take_every_cell(zoomed)
  vim.api.nvim_win_set_width(zoomed, vim.o.columns)
  vim.api.nvim_win_set_height(zoomed, vim.o.lines)
end

--- Zooms `zoomed` fully among `windows`.
---
---@param windows integer[] the tab page's windows that are not floating, `zoomed` among them
---@param zoomed integer
---@return aineo.layout.FullZoom zoom
function M.start(windows, zoomed)
  local sizes = vim.tbl_map(function(window)
    return {
      width = vim.api.nvim_win_get_width(window),
      height = vim.api.nvim_win_get_height(window),
    }
  end, windows)
  take_every_cell(zoomed)
  return {
    window = zoomed,
    windows = windows,
    sizes = sizes,
    editor = { columns = vim.o.columns, lines = vim.o.lines },
  }
end

--- Zooms the window of `zoom` again, as the cells of the tab page changed
--- under it, such as when the editor is resized.
---
---@param zoom aineo.layout.FullZoom
function M.keep(zoom)
  take_every_cell(zoom.window)
end

--- How many times `M.restore()` sets every window's size: setting one
--- window's size moves its neighbours', so a window set early may have to be
--- set again once the later ones are.
local RESTORE_PASSES = 2

--- `size` scaled by how much the editor's extent changed, from `was` to `now`;
--- `size` itself when it did not.
---
---@param size integer
---@param was integer
---@param now integer
---@return integer
local function scaled(size, was, now)
  if was == now then
    return size
  end
  return math.max(1, math.floor(size * now / was + 0.5))
end

--- Gives the windows of `zoom` that still exist the sizes they had before the
--- zoom; when the editor was resized since, the sizes they had scaled to the
--- editor's size now, the last windows of each row and column taking the
--- cells that remain.
---
---@param zoom aineo.layout.FullZoom
function M.restore(zoom)
  for _ = 1, RESTORE_PASSES do
    for index, window in ipairs(zoom.windows) do
      if vim.api.nvim_win_is_valid(window) then
        local size = zoom.sizes[index]
        vim.api.nvim_win_set_width(window, scaled(size.width, zoom.editor.columns, vim.o.columns))
        vim.api.nvim_win_set_height(window, scaled(size.height, zoom.editor.lines, vim.o.lines))
      end
    end
  end
end

return M
