--- The words of a tab page's title.

local M = {}

--- What a title says for a buffer with no name.
local NO_NAME = '[No Name]'

--- The fewest display cells a name is cut to, its ellipsis included.
M.SHORTEST_CUT_CELLS = 8

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

--- `name` cut to at most `cap` display cells: whole when it fills no more,
--- else its longest prefix of whole characters that leaves room for `…`,
--- then `…`. A character is never cut in two, nor parted from its composing
--- characters, so a wide one that would cross the edge is left out. A `cap`
--- below `SHORTEST_CUT_CELLS` is taken as that many cells, so that a name is
--- never cut to little more than its ellipsis.
---
---@param name string text with no NUL in it
---@param cap number the most display cells the result fills; `math.huge` for no cut
---@return string
function M.cut(name, cap)
  local cells = math.max(cap, M.SHORTEST_CUT_CELLS)
  if vim.fn.strdisplaywidth(name) <= cells then
    return name
  end
  local room = cells - vim.fn.strdisplaywidth(ELLIPSIS)
  return longest_prefix_within(name, room) .. ELLIPSIS
end

--- The title of the tab page in place `number`: `<number>: <name>`, then a
--- space and `indicator` when there is one, so that a title with none has no
--- trailing space.
---
---@param number integer
---@param name string
---@param indicator string|nil
---@return string
function M.title_of(number, name, indicator)
  local title = ('%d: %s'):format(number, name)
  return indicator and ('%s %s'):format(title, indicator) or title
end

--- The tail of the name of the buffer in the current window of the tab page
--- `tab` (the last part of the path, without a closing `/`), or `[No Name]`
--- when the buffer has none. Whole: `cut()` shortens a name.
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
