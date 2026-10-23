--- Text cut to the cells a piece of the office has for it. Pure.

local M = {}

--- The first `cells` characters of `text`, with each character that is not
--- exactly one cell wide on the screen (a control character, a wide or a
--- combining one) replaced by `?`, so that a line is as many cells wide as it
--- has characters.
---
---@param text string
---@param cells integer
---@return string
function M.cut_to(text, cells)
  local starts = vim.str_utf_pos(text)
  local kept = {}
  for index = 1, math.min(#starts, math.max(0, cells)) do
    local character = text:sub(starts[index], (starts[index + 1] or #text + 1) - 1)
    local is_one_cell = not character:find('%c') and vim.fn.strdisplaywidth(character) == 1
    kept[index] = is_one_cell and character or '?'
  end
  return table.concat(kept)
end

return M
