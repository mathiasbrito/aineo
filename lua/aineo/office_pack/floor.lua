--- The reader of a pack's floor plan, drawn as text: one character per cell.
---
--- ```
--- # Comment lines start with # and come first.
---  ~~~~
---  ####
---  D..#
--- ~..s.
--- ```
---
--- The first line after the comments marks with `~` the columns that repeat to
--- fill the width. The first character of every row after it is the rows'
--- marker column and is not part of the plan: `~` marks a row that repeats to
--- fill the height, a space one that does not. `.` is floor to walk on, `#`
--- wall, a space floor nobody walks on, and any other character a letter of
--- the pack's legend.

local M = {}

local REPEAT_MARK = '~'

--- The largest plan the reader takes, in cells.
local MAX_WIDTH = 400
local MAX_HEIGHT = 200

--- The characters of a plan that are no letter of the legend.
local PLAIN_CELLS = { ['.'] = true, ['#'] = true, [' '] = true }

---@class aineo.office_pack.Block
---@field first integer the first column or row of the block, counted from 1
---@field last integer the last

---@class aineo.office_pack.FloorPlan
---@field rows string[] the plan's rows, without the marker column, all of one width
---@field row_lines integer[] the file line of each row
---@field repeated_columns? aineo.office_pack.Block the columns that repeat
---@field repeated_rows? aineo.office_pack.Block the rows that repeat

--- The blocks of consecutive marks that are `REPEAT_MARK`, in order.
---
---@param marks string[] one mark for each column or row
---@return aineo.office_pack.Block[]
local function blocks_of(marks)
  local blocks = {}
  for position, mark in ipairs(marks) do
    local block = blocks[#blocks]
    if mark == REPEAT_MARK then
      if block and block.last == position - 1 then
        block.last = position
      else
        table.insert(blocks, { first = position, last = position })
      end
    end
  end
  return blocks
end

--- The block `blocks` holds, or `nil` when it holds none; when it holds more
--- than one, tells it at the line of the second's start, `line_of(position)`,
--- and gives none.
---
---@param blocks aineo.office_pack.Block[]
---@param line_of fun(position: integer): integer
---@param message string
---@param report aineo.office_pack.Report
---@return aineo.office_pack.Block|nil
local function the_only_block(blocks, line_of, message, report)
  if #blocks > 1 then
    report(line_of(blocks[2].first), message)
    return nil
  end
  return blocks[1]
end

--- The characters of `text`, one for each byte.
---
---@param text string
---@return string[]
local function bytes_of(text)
  local bytes = {}
  for position = 1, #text do
    bytes[position] = text:sub(position, position)
  end
  return bytes
end

--- Pads every row of `rows` with spaces to the width of the widest.
---
---@param rows string[]
---@return string[]
local function padded(rows)
  local width = 0
  for _, row in ipairs(rows) do
    width = math.max(width, #row)
  end
  return vim.tbl_map(function(row)
    return row .. (' '):rep(width - #row)
  end, rows)
end

--- The lines of `text` from its marker line on — the first line after the
--- comments at its top, trailing empty lines left out — and the file line of
--- the marker line.
---
---@param text string
---@return string[] lines
---@return integer marker_line_number
local function lines_from_marker_line(text)
  local lines = vim.split(text:gsub('\r', ''), '\n', { plain = true })
  local marker_line_number = 1
  while lines[marker_line_number] and vim.startswith(lines[marker_line_number], '#') do
    marker_line_number = marker_line_number + 1
  end
  while lines[#lines] == '' do
    table.remove(lines)
  end
  return vim.list_slice(lines, marker_line_number), marker_line_number
end

--- Tells the rows whose marker column is neither a space nor `~`.
---
---@param rows string[] the rows as written, marker column first
---@param first_line integer the file line of `rows[1]`
---@param report aineo.office_pack.Report
local function check_markers(rows, first_line, report)
  for index, row in ipairs(rows) do
    local marker = row:sub(1, 1)
    if marker ~= ' ' and marker ~= REPEAT_MARK and row ~= '' then
      report(first_line + index - 1, 'a row starts with a space, or with ~ when it repeats')
    end
  end
end

--- The width in cells of the widest of `rows`, written with the marker column.
---
---@param rows string[]
---@return integer
local function widest_of(rows)
  local widest = 0
  for _, row in ipairs(rows) do
    widest = math.max(widest, #row - 1)
  end
  return widest
end

--- Reads the plan `text`, telling every problem to `report` with its line.
---
--- `nil` when the text holds no marker line or no row, or the plan is over
--- 400 cells wide or 200 rows tall. A row shorter than the widest is read as
--- if it ended in spaces, which an editor may have taken off; a marker line or
--- rows that mark more than one block to repeat are told, and none repeats.
---
---@param text string
---@param report aineo.office_pack.Report
---@return aineo.office_pack.FloorPlan|nil plan
function M.parse(text, report)
  local lines, marker_line_number = lines_from_marker_line(text)
  local marker_line = table.remove(lines, 1)
  if not marker_line or #lines == 0 then
    report(1, 'the plan has no rows')
    return nil
  end
  local first_row_line = marker_line_number + 1
  if #lines > MAX_HEIGHT then
    report(first_row_line, ('the plan is taller than %d rows'):format(MAX_HEIGHT))
    return nil
  end
  if widest_of(lines) > MAX_WIDTH then
    report(first_row_line, ('the plan is wider than %d cells'):format(MAX_WIDTH))
    return nil
  end
  check_markers(lines, first_row_line, report)
  local repeated_columns = the_only_block(
    blocks_of(vim.list_slice(bytes_of(marker_line), 2)),
    function()
      return marker_line_number
    end,
    'the marker line marks one block of columns that repeat',
    report
  )
  local repeated_rows = the_only_block(
    blocks_of(vim.tbl_map(function(row)
      return row:sub(1, 1)
    end, lines)),
    function(position)
      return first_row_line + position - 1
    end,
    'the rows that repeat are one block',
    report
  )
  local row_lines = {}
  for index in ipairs(lines) do
    row_lines[index] = first_row_line + index - 1
  end
  return {
    rows = padded(vim.tbl_map(function(row)
      return row:sub(2)
    end, lines)),
    row_lines = row_lines,
    repeated_columns = repeated_columns,
    repeated_rows = repeated_rows,
  }
end

--- Tells each letter of `plan` that `legend` does not have, once, at the
--- first row it stands on.
---
---@param plan aineo.office_pack.FloorPlan
---@param legend table<string, table>
---@param report aineo.office_pack.Report
function M.check_letters(plan, legend, report)
  local told = {}
  for index, row in ipairs(plan.rows) do
    for letter in row:gmatch('.') do
      if not PLAIN_CELLS[letter] and not legend[letter] and not told[letter] then
        told[letter] = true
        report(
          plan.row_lines[index],
          ('the letter “%s” is not in the floor legend'):format(letter)
        )
      end
    end
  end
end

return M
