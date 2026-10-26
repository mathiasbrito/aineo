--- The text of the cheatsheet: the groups of keys written as lines for a window
--- of a given width, with the highlight of each part. Pure: it reads nothing
--- from the editor but how wide a text is drawn.

local look = require('aineo.cheatsheet.look')

local M = {}

--- The widest window, in cells, that gets one column; from `TWO_COLUMNS_FROM`
--- on there are two.
local TWO_COLUMNS_FROM = 80

--- The cells between the two columns.
local GAP = 3

--- The cells a key row is indented by, and that lie between its key and its
--- phrase.
local INDENT = 2
local KEY_TO_PHRASE = 2

--- The least cells of a row's phrase that its key leaves.
local LEAST_PHRASE = 12

--- The cells the command of a row is apart from its phrase at least, when
--- they share a line.
local PHRASE_TO_COMMAND = 2

--- What marks a text cut short.
local ELLIPSIS = '…'

--- What the sheet is called, in its first line.
local TITLE = 'aineo — keys'

---@class aineo.cheatsheet.Row
---@field key string the key as the user types it, or the `<Plug>` mapping that runs the action when none is mapped
---@field phrase string what the key does
---@field command? string the `:Aineo` command that does the same, as it is typed

---@class aineo.cheatsheet.Group
---@field title string
---@field rows aineo.cheatsheet.Row[]

---@class aineo.cheatsheet.Highlight
---@field line integer the line, from 0
---@field from integer the first byte of the line it covers, from 0
---@field to integer the byte after the last it covers
---@field group string

---@class aineo.cheatsheet.Sheet
---@field lines string[]
---@field highlights aineo.cheatsheet.Highlight[]

--- A piece of a line: its text, and the highlight group it is drawn in, none
--- for the text of the editor.
---@class aineo.cheatsheet.Segment
---@field text string
---@field group? string

--- How many cells `text` takes on the screen.
---
---@param text string
---@return integer
local function cells(text)
  return vim.fn.strdisplaywidth(text)
end

--- How many cells the segments of a line take.
---
---@param segments aineo.cheatsheet.Segment[]
---@return integer
local function line_cells(segments)
  local total = 0
  for _, segment in ipairs(segments) do
    total = total + cells(segment.text)
  end
  return total
end

--- `text`, cut at the last character that leaves room for an ellipsis when it
--- takes more than `room` cells; empty when `room` is less than 1.
---
---@param text string
---@param room integer
---@return string
local function cut_to(text, room)
  if room < 1 then
    return ''
  end
  if cells(text) <= room then
    return text
  end
  local kept = ''
  for _, character in ipairs(vim.fn.split(text, '\\zs')) do
    if cells(kept .. character) > room - cells(ELLIPSIS) then
      break
    end
    kept = kept .. character
  end
  return kept .. ELLIPSIS
end

--- `text` followed by spaces up to `width` cells.
---
---@param text string
---@param width integer
---@return string
local function padded(text, width)
  return text .. string.rep(' ', width - cells(text))
end

--- The lines of one key of a group: the key, its phrase and its command,
--- in a column `width` cells wide whose keys take `key_cells`. The command
--- shares the line with the phrase, at the column's right edge, when both fit;
--- otherwise it has a line of its own under the phrase.
---
---@param row aineo.cheatsheet.Row
---@param key_cells integer
---@param width integer
---@param accent integer
---@return aineo.cheatsheet.Segment[][]
local function row_lines(row, key_cells, width, accent)
  local phrase_at = INDENT + key_cells + KEY_TO_PHRASE
  local phrase = cut_to(row.phrase, width - phrase_at)
  local first = {
    { text = string.rep(' ', INDENT) },
    { text = padded(cut_to(row.key, key_cells), key_cells), group = look.key_group(accent) },
    { text = string.rep(' ', KEY_TO_PHRASE) },
    { text = phrase, group = look.PHRASE_GROUP },
  }
  if not row.command then
    return { first }
  end
  local free = width - phrase_at - cells(phrase)
  if free >= PHRASE_TO_COMMAND + cells(row.command) then
    table.insert(first, { text = string.rep(' ', free - cells(row.command)) })
    table.insert(first, { text = row.command, group = look.COMMAND_GROUP })
    return { first }
  end
  return {
    first,
    {
      { text = string.rep(' ', phrase_at) },
      { text = cut_to(row.command, width - phrase_at), group = look.COMMAND_GROUP },
    },
  }
end

--- The lines of a group in a column `width` cells wide: its title, then each
--- of its keys, and an empty line after them.
---
---@param group aineo.cheatsheet.Group
---@param accent integer the number of the accent the group is drawn in
---@param width integer
---@return aineo.cheatsheet.Segment[][]
local function group_lines(group, accent, width)
  local widest_key = 0
  for _, row in ipairs(group.rows) do
    widest_key = math.max(widest_key, cells(row.key))
  end
  local key_cells = math.min(widest_key, math.max(1, width - INDENT - KEY_TO_PHRASE - LEAST_PHRASE))
  local lines = {
    { { text = cut_to(group.title, width), group = look.header_group(accent) } },
  }
  for _, row in ipairs(group.rows) do
    vim.list_extend(lines, row_lines(row, key_cells, width, accent))
  end
  table.insert(lines, {})
  return lines
end

--- How the blocks of lines split in two columns so that the taller column is
--- as short as it can be: the number of blocks the left column takes, the
--- first of the splits that does that.
---
---@param blocks aineo.cheatsheet.Segment[][][]
---@return integer
local function left_block_count(blocks)
  local total = 0
  for _, block in ipairs(blocks) do
    total = total + #block
  end
  local best_count, best_height = 0, math.huge
  local left = 0
  for count = 0, #blocks do
    if count > 0 then
      left = left + #blocks[count]
    end
    local taller = math.max(left, total - left)
    if taller < best_height then
      best_count, best_height = count, taller
    end
  end
  return best_count
end

--- The lines of the blocks, one under the other.
---
---@param blocks aineo.cheatsheet.Segment[][][]
---@return aineo.cheatsheet.Segment[][]
local function stacked(blocks)
  local lines = {}
  for _, block in ipairs(blocks) do
    vim.list_extend(lines, block)
  end
  return lines
end

--- The lines of `left` and of `right` side by side, `width` cells to each
--- column.
---
---@param left aineo.cheatsheet.Segment[][]
---@param right aineo.cheatsheet.Segment[][]
---@param width integer
---@return aineo.cheatsheet.Segment[][]
local function side_by_side(left, right, width)
  local lines = {}
  for number = 1, math.max(#left, #right) do
    local line = vim.list_extend({}, left[number] or {})
    if right[number] and #right[number] > 0 then
      table.insert(line, { text = string.rep(' ', width - line_cells(line) + GAP) })
      vim.list_extend(line, right[number])
    end
    table.insert(lines, line)
  end
  return lines
end

--- The text of a line, and the highlights its segments carry, `number` being
--- the line's place from 0.
---
---@param segments aineo.cheatsheet.Segment[]
---@param number integer
---@return string text
---@return aineo.cheatsheet.Highlight[] highlights
local function written(segments, number)
  local text, highlights = '', {}
  for _, segment in ipairs(segments) do
    if segment.group and segment.text ~= '' then
      table.insert(
        highlights,
        { line = number, from = #text, to = #text + #segment.text, group = segment.group }
      )
    end
    text = text .. segment.text
  end
  return text, highlights
end

--- The cheatsheet for a window `width` cells wide: its title, then `groups`,
--- each with a heading of its own accent and a line for each key, in two
--- columns when the window is at least 80 cells wide and in one below that.
--- Groups keep their order, the first ones in the left column, and are split
--- so that the columns are as even as they can be.
---
---@param groups aineo.cheatsheet.Group[]
---@param width integer
---@return aineo.cheatsheet.Sheet
function M.compose(groups, width)
  local two_columns = width >= TWO_COLUMNS_FROM
  local column_width = two_columns and math.floor((width - GAP) / 2) or width
  local blocks = {}
  for index, group in ipairs(groups) do
    table.insert(blocks, group_lines(group, look.accent_of(index), column_width))
  end
  local body
  if two_columns then
    local count = left_block_count(blocks)
    body = side_by_side(
      stacked(vim.list_slice(blocks, 1, count)),
      stacked(vim.list_slice(blocks, count + 1)),
      column_width
    )
  else
    body = stacked(blocks)
  end
  while #body > 0 and #body[#body] == 0 do
    table.remove(body)
  end
  local all = { { { text = cut_to(TITLE, width), group = look.TITLE_GROUP } }, {} }
  vim.list_extend(all, body)
  local sheet = { lines = {}, highlights = {} }
  for number, segments in ipairs(all) do
    local text, highlights = written(segments, number - 1)
    table.insert(sheet.lines, text)
    vim.list_extend(sheet.highlights, highlights)
  end
  return sheet
end

return M
