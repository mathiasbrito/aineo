--- Text as the office draws it: on one line, no wider than the cells it has,
--- and put over the cells of a row of the picture.

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

--- The byte of `text` that the character `index` begins, with `index` from 0.
---
---@param text string
---@param index integer
---@return integer
local function byte_of(text, index)
  return vim.str_byteindex(text, 'utf-32', index)
end

--- `row` with `cells` cells of it, from the cell `first`, replaced by `text`
--- drawn in `group`. The row has a character to each cell, and `text` as many
--- cells as `cells`.
---
---@param row aineo.office_scene.PictureRow
---@param first integer the first cell replaced, from 0
---@param cells integer
---@param text string
---@param group string
---@return aineo.office_scene.PictureRow
function M.put_over(row, first, cells, text, group)
  local from = byte_of(row.text, first)
  local to = byte_of(row.text, first + cells)
  local moved_by = #text - (to - from)
  local runs = {}
  for _, run in ipairs(row.runs) do
    if run.from < from then
      table.insert(runs, { from = run.from, to = math.min(run.to, from), group = run.group })
    end
  end
  table.insert(runs, { from = from, to = from + #text, group = group })
  for _, run in ipairs(row.runs) do
    if run.to > to then
      table.insert(
        runs,
        { from = math.max(run.from, to) + moved_by, to = run.to + moved_by, group = run.group }
      )
    end
  end
  return { text = row.text:sub(1, from) .. text .. row.text:sub(to + 1), runs = runs }
end

return M
