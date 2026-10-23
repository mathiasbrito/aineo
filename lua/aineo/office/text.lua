--- Text as the office draws it: on one line, and no wider than the cells it has.

local M = {}

--- The mark that ends a text cut short.
M.CUT_MARK = '…'

--- `text` on one line: every run of white space and control characters is a
--- single space, and the ends are trimmed.
---
---@param text string
---@return string
function M.on_one_line(text)
  local spaced = text:gsub('[%c%s]+', ' ')
  return vim.trim(spaced)
end

--- `text` cut to at most `cells` cells of the screen, with `M.CUT_MARK` as its
--- last character when it was cut.
---
---@param text string
---@param cells integer
---@return string
function M.cut_to_cells(text, cells)
  if vim.fn.strdisplaywidth(text) <= cells then
    return text
  end
  local kept = ''
  for _, character in ipairs(vim.fn.split(text, '\\zs')) do
    if vim.fn.strdisplaywidth(kept .. character .. M.CUT_MARK) > cells then
      break
    end
    kept = kept .. character
  end
  return kept .. M.CUT_MARK
end

return M
