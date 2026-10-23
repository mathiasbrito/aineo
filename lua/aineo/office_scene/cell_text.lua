--- Text cut to the cells a piece of the office has for it. Pure.

local M = {}

--- The most bytes of one character, which bounds how much of a text is read.
local MOST_BYTES_A_CHARACTER = 4

--- Whether `character` is exactly one cell wide on the screen after another
--- character: a control character, a wide one and a combining mark (which
--- takes none after its base) are not.
---
---@param character string
---@return boolean
local function is_one_cell(character)
  return not character:find('%c') and vim.fn.strdisplaywidth('a' .. character) == 2
end

--- The first `cells` characters of `text`, with each character that is not
--- exactly one cell wide on the screen (a control character, a wide or a
--- combining one) replaced by `?`, so that a line is as many cells wide as it
--- has characters. Only the bytes the cells can hold are read, so the cost
--- does not grow with the length of `text`.
---
---@param text string
---@param cells integer
---@return string
function M.cut_to(text, cells)
  text = text:sub(1, MOST_BYTES_A_CHARACTER * math.max(0, cells))
  local starts = vim.str_utf_pos(text)
  local kept = {}
  for index = 1, math.min(#starts, math.max(0, cells)) do
    local character = text:sub(starts[index], (starts[index + 1] or #text + 1) - 1)
    kept[index] = is_one_cell(character) and character or '?'
  end
  return table.concat(kept)
end

return M
