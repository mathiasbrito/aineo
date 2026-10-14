--- The words of a tab page's title.

local M = {}

--- What a title says for a buffer with no name.
local NO_NAME = '[No Name]'

--- The most display cells a name keeps whole in a title.
local MAX_NAME_CELLS = 24

--- What a name cut short ends with.
local ELLIPSIS = '…'

--- `name` as a title shows it: whole when it fills at most 24 display cells,
--- else its first characters that fill at most 23, then `…`. A character is
--- never cut in two, so a wide one that would cross the edge is left out.
---
---@param name string
---@return string
function M.cut(name)
  if vim.fn.strdisplaywidth(name) <= MAX_NAME_CELLS then
    return name
  end
  local room = MAX_NAME_CELLS - vim.fn.strdisplaywidth(ELLIPSIS)
  local starts = vim.str_utf_pos(name)
  local kept_bytes = 0
  for index, start in ipairs(starts) do
    local stop = (starts[index + 1] or #name + 1) - 1
    room = room - vim.fn.strdisplaywidth(name:sub(start, stop))
    if room < 0 then
      break
    end
    kept_bytes = stop
  end
  return name:sub(1, kept_bytes) .. ELLIPSIS
end

--- The tail of the name of the buffer in the current window of the tab page
--- `tab`, or `[No Name]` when the buffer has none.
---
---@param tab integer a tab page handle of a tab page that exists
---@return string
function M.buffer_tail(tab)
  local window = vim.api.nvim_tabpage_get_win(tab)
  local buffer = vim.api.nvim_win_get_buf(window)
  local tail = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ':t')
  if tail == '' then
    return NO_NAME
  end
  return M.cut(tail)
end

return M
