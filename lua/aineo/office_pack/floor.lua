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
--- fill the width; the first column of every row after it is the rows' marker
--- column and is not part of the plan. Rows marked `~` are read as plain rows:
--- the plan is not repeated down the height. `.` is floor to walk on, `#` wall,
--- a space floor nobody walks on, and any other character a letter of the
--- pack's legend.

local M = {}

local REPEAT_MARK = '~'

---@class aineo.office_pack.FloorPlan
---@field rows string[] the plan's rows, without the marker column, all of one width
---@field repeated_columns? { first: integer, last: integer } the columns that repeat, counted from 1 at the plan's left

--- The columns the marker line marks with `~`, counted from the plan's own
--- first column (the marker line's first character belongs to the marker
--- column); `nil` when it marks none.
---
---@param marker_line string
---@return { first: integer, last: integer }|nil
local function repeated_columns_of(marker_line)
  local first = marker_line:find(REPEAT_MARK, 2, true)
  if not first then
    return nil
  end
  local last = first
  for position = first, #marker_line do
    if marker_line:sub(position, position) == REPEAT_MARK then
      last = position
    end
  end
  return { first = first - 1, last = last - 1 }
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

--- Reads the plan `text`: its marker line, its rows without the marker
--- column, trailing empty lines left out.
---
--- `nil` and the problem when the text holds no marker line or no row.
---
---@param text string
---@return aineo.office_pack.FloorPlan|nil plan
---@return string|nil problem
function M.parse(text)
  local lines = vim.split(text:gsub('\r', ''), '\n', { plain = true })
  while lines[1] and vim.startswith(lines[1], '#') do
    table.remove(lines, 1)
  end
  while lines[#lines] == '' do
    table.remove(lines)
  end
  local marker_line = table.remove(lines, 1)
  if not marker_line or #lines == 0 then
    return nil, 'the plan has no rows'
  end
  local rows = vim.tbl_map(function(line)
    return line:sub(2)
  end, lines)
  return { rows = padded(rows), repeated_columns = repeated_columns_of(marker_line) }
end

return M
