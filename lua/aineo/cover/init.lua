--- A cover of a rectangle of the screen, `require('aineo.cover')`: a floating
--- window with a scratch buffer of its own, placed over the cells of a part of
--- aineo's layout — the right column, in the office's case and the
--- cheatsheet's — so that what is under it stays as it is and shows again when
--- the cover closes.
---
--- It loads no other module. What a cover shows, and when it opens and
--- closes, is its owner's.

local M = {}

---@class aineo.cover.Cover
---@field buffer integer
---@field window integer

---@class aineo.cover.Options
---@field filetype string the 'filetype' of the cover's buffer
---@field name string the word the buffer's name carries: `aineo://<name>-<buffer number>`
---@field enter boolean whether the cursor moves into the cover's window as it opens
---@field mouse? boolean whether a click or the wheel over it is the cover's; none, and it takes no mouse event, which reaches the window beneath

--- Opens a cover over `area`, with a buffer of its own.
---
--- The buffer is a scratch buffer no one edits, wiped when its window closes,
--- named `aineo://<name>-<buffer number>`: the number keeps the names of the
--- covers of several tab pages apart. The window shows only that buffer
--- (`'winfixbuf'`), draws no line numbers, sign column, cursor line or border,
--- whatever `'winborder'` says, and takes the colours of the editor's text.
--- The cursor moves into it only when `options.enter` says so. Unless
--- `options.mouse` is set it takes no mouse event: a click or the wheel over
--- it reaches the window beneath, so a click enters that window and the wheel
--- never scrolls the picture.
---
---@param area aineo.layout.Area
---@param options aineo.cover.Options
---@return aineo.cover.Cover cover
function M.open(area, options)
  vim.validate('options.filetype', options.filetype, 'string')
  vim.validate('options.name', options.name, 'string')
  vim.validate('options.enter', options.enter, 'boolean')
  vim.validate('options.mouse', options.mouse, 'boolean', true)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].bufhidden = 'wipe'
  vim.bo[buffer].undolevels = -1
  vim.bo[buffer].filetype = options.filetype
  vim.bo[buffer].modifiable = false
  vim.api.nvim_buf_set_name(buffer, ('aineo://%s-%d'):format(options.name, buffer))
  local window = vim.api.nvim_open_win(buffer, options.enter, {
    relative = 'editor',
    row = area.row,
    col = area.col,
    width = area.width,
    height = area.height,
    style = 'minimal',
    border = 'none',
    focusable = true,
    mouse = options.mouse == true,
  })
  vim.wo[window].winfixbuf = true
  vim.wo[window].wrap = false
  vim.wo[window].winhighlight = 'NormalFloat:Normal'
  return { buffer = buffer, window = window }
end

--- Moves and resizes the window of `cover` to cover `area`.
---
---@param cover aineo.cover.Cover
---@param area aineo.layout.Area
function M.place(cover, area)
  vim.api.nvim_win_set_config(cover.window, {
    relative = 'editor',
    row = area.row,
    col = area.col,
    width = area.width,
    height = area.height,
  })
end

--- Closes the window of `cover`, which wipes its buffer, if it is open.
---
---@param cover aineo.cover.Cover
function M.close(cover)
  if vim.api.nvim_win_is_valid(cover.window) then
    vim.api.nvim_win_close(cover.window, true)
  end
end

--- Whether the window `window` lies in `area`: its top left cell is inside.
---
---@param area aineo.layout.Area
---@param window integer
---@return boolean
function M.area_holds(area, window)
  local position = vim.api.nvim_win_get_position(window)
  return position[1] >= area.row
    and position[1] < area.row + area.height
    and position[2] >= area.col
    and position[2] < area.col + area.width
end

--- The first window, in the tab page of `cover`, other than floats, that lies
--- in `area`: the one the cover's window covers first; nil when there is none.
---
---@param cover aineo.cover.Cover
---@param area aineo.layout.Area
---@return integer|nil window
function M.window_under(cover, area)
  local tab_page = vim.api.nvim_win_get_tabpage(cover.window)
  return vim.iter(vim.api.nvim_tabpage_list_wins(tab_page)):find(function(window)
    return vim.api.nvim_win_get_config(window).relative == '' and M.area_holds(area, window)
  end)
end

--- Whether the window `window` lies in the cells the cover's window covers:
--- its top left cell is inside them.
---
---@param cover aineo.cover.Cover
---@param window integer
---@return boolean
function M.covers(cover, window)
  local covered = vim.api.nvim_win_get_position(cover.window)
  return M.area_holds({
    row = covered[1],
    col = covered[2],
    width = vim.api.nvim_win_get_width(cover.window),
    height = vim.api.nvim_win_get_height(cover.window),
  }, window)
end

return M
