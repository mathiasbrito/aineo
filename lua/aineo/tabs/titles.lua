--- The words of a tab page's title.

local M = {}

--- What a title says for a buffer with no name.
local NO_NAME = '[No Name]'

--- The most display cells a name keeps whole in a title.
local MAX_NAME_CELLS = 24

--- What a name cut short ends with.
local ELLIPSIS = '…'

--- The longest prefix of `text`, in whole characters, that fills at most
--- `room` display cells. A character keeps its composing characters and
--- modifiers: an accent, a variation selector or a joined emoji is never
--- parted from it.
---
---@param text string
---@param room integer
---@return string
local function longest_prefix_within(text, room)
  local fitting, too_long = 0, vim.fn.strcharlen(text)
  while fitting < too_long do
    local middle = math.ceil((fitting + too_long) / 2)
    if vim.fn.strdisplaywidth(vim.fn.strcharpart(text, 0, middle, 1)) <= room then
      fitting = middle
    else
      too_long = middle - 1
    end
  end
  return vim.fn.strcharpart(text, 0, fitting, 1)
end

--- `name` as a title shows it: whole when it fills at most 24 display cells,
--- else its longest prefix of whole characters that fills at most 23, then
--- `…`. A character is never cut in two, nor parted from its composing
--- characters, so a wide one that would cross the edge is left out.
---
---@param name string text with no NUL in it
---@return string
function M.cut(name)
  if vim.fn.strdisplaywidth(name) <= MAX_NAME_CELLS then
    return name
  end
  local room = MAX_NAME_CELLS - vim.fn.strdisplaywidth(ELLIPSIS)
  return longest_prefix_within(name, room) .. ELLIPSIS
end

--- The tail of the name of the buffer in the current window of the tab page
--- `tab` (the last part of the path, without a closing `/`), or `[No Name]`
--- when the buffer has none. Not cut: `cut()` does that to a whole title.
---
---@param tab integer a tab page handle of a tab page that exists
---@return string
function M.buffer_tail(tab)
  local window = vim.api.nvim_tabpage_get_win(tab)
  local buffer = vim.api.nvim_win_get_buf(window)
  local name = vim.api.nvim_buf_get_name(buffer):gsub('/+$', '')
  local tail = vim.fn.fnamemodify(name, ':t')
  if tail == '' then
    return NO_NAME
  end
  return tail
end

return M
