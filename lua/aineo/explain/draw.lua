--- How a band of virtual lines of the explain home is drawn: its rows
--- wrapped to a window's text width, and each row's gutter, indent and
--- text in the highlight groups of a style (`aineo.explain.Style`).

local M = {}

--- What starts the text of every virtual line, after the line's indent.
M.MARK = '┊ '

--- What marks the gutter of every virtual line but a marked issue's.
M.GUTTER_MARK = '▎'

--- The fewest characters of a label worth showing in the gutter.
local SHORTEST_LABEL = 2

--- The bytes of the longest start of `word` no wider than `width` display
--- columns, and at least its first character. Walks the characters of that
--- start alone, so that a long word costs its length, not its length per row.
---
---@param word string
---@param width integer
---@return integer
local function fitting_bytes(word, width)
  local bytes, used = 0, 0
  while bytes < #word do
    local character = word:sub(bytes + 1, bytes + 1 + vim.str_utf_end(word, bytes + 1))
    local wide = vim.fn.strdisplaywidth(character)
    if used + wide > width and bytes > 0 then
      break
    end
    bytes = bytes + #character
    used = used + wide
  end
  return bytes
end

--- `text` broken into rows no wider than `width` display columns: between
--- words, a word wider than `width` cut into rows of its own, and a new row
--- at each line break.
---
---@param text string
---@param width integer
---@return string[]
function M.wrapped(text, width)
  local rows = {}
  for _, paragraph in ipairs(vim.split(text, '\n', { plain = true })) do
    local row = ''
    for word in paragraph:gmatch('%S+') do
      while vim.fn.strdisplaywidth(word) > width do
        if row ~= '' then
          table.insert(rows, row)
          row = ''
        end
        local cut = fitting_bytes(word, width)
        table.insert(rows, word:sub(1, cut))
        word = word:sub(cut + 1)
      end
      local longer = row == '' and word or row .. ' ' .. word
      if vim.fn.strdisplaywidth(longer) <= width then
        row = longer
      else
        table.insert(rows, row)
        row = word
      end
    end
    table.insert(rows, row)
  end
  return rows
end

--- Where a window shows a buffer's text: its width, and the columns before
--- the text that its number, sign and fold columns take.
---@class aineo.explain.Geometry
---@field width integer the window's columns
---@field textoff integer the columns before the text

--- The geometry of a window showing `buffer`: `window`'s when it still shows
--- `buffer`, else the first such window's, else the screen's, with no
--- columns before the text, when none shows it.
---
---@param buffer integer
---@param window integer
---@return aineo.explain.Geometry
function M.geometry_of(buffer, window)
  if not (vim.api.nvim_win_is_valid(window) and vim.api.nvim_win_get_buf(window) == buffer) then
    window = vim.fn.bufwinid(buffer)
  end
  local info = vim.fn.getwininfo(window)[1]
  if not info then
    return { width = vim.o.columns, textoff = 0 }
  end
  return { width = info.width, textoff = info.textoff }
end

--- The indent of `line` of `buffer`, from 1, as the spaces that fill it, at
--- most `most` of them.
---
---@param buffer integer
---@param line integer
---@param most? integer no limit when absent
---@return string
function M.indent_of(buffer, line, most)
  local indent = vim.api.nvim_buf_call(buffer, function()
    return vim.fn.indent(line)
  end)
  return (' '):rep(math.min(indent, most or indent))
end

--- How a band is drawn: the character that marks its gutter and the
--- highlight groups of its text, gutter and the columns the gutter fills.
---@class aineo.explain.Style
---@field gutter_mark string
---@field text string
---@field gutter string
---@field fill string

--- The chunks that fill the columns before the text, `textoff` of them: the
--- style's mark, then spaces, and `label` right-aligned with a space after
--- it, cut to the cells left by the mark and that space, and left out when
--- fewer than `SHORTEST_LABEL` fit; the mark and the label in the style's
--- gutter group and the spaces in its fill group; none when there are no
--- such columns.
---
---@param textoff integer
---@param label string
---@param style aineo.explain.Style
---@return table[] chunks
function M.gutter(textoff, label, style)
  if textoff == 0 then
    return {}
  end
  local mark_width = vim.fn.strdisplaywidth(style.gutter_mark)
  local room = textoff - mark_width - 1
  label = room >= SHORTEST_LABEL and label:sub(1, room) or ''
  local chunks = { { style.gutter_mark, style.gutter } }
  local spaces = textoff - mark_width - (label == '' and 0 or #label + 1)
  if spaces > 0 then
    table.insert(chunks, { (' '):rep(spaces), style.fill })
  end
  if label ~= '' then
    table.insert(chunks, { label, style.gutter })
    table.insert(chunks, { ' ', style.fill })
  end
  return chunks
end

--- The virtual line that shows `row`: the gutter (`gutter()`, with
--- `label`), `indent` unhighlighted, then `MARK` and `row` padded with
--- spaces to the end of the window, in the text group of `style`.
---
---@param row string
---@param indent string
---@param geometry aineo.explain.Geometry
---@param label string
---@param style aineo.explain.Style
---@return table[] chunks
function M.row(row, indent, geometry, label, style)
  local body = M.MARK .. row
  local padding = geometry.width - geometry.textoff - #indent - vim.fn.strdisplaywidth(body)
  local chunks = M.gutter(geometry.textoff, label, style)
  if indent ~= '' then
    table.insert(chunks, { indent })
  end
  table.insert(chunks, { body .. (' '):rep(math.max(padding, 0)), style.text })
  return chunks
end

return M
