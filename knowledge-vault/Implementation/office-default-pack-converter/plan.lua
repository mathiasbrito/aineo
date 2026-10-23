-- The default office's floor plan, drawn by code so that every column and row
-- lines up with the art, and its legend.
--
-- The plan is built seven desk slots wide, each 28 columns (a desk 26 wide and
-- two of gap) from column 15, and cut into three parts: a left part of the
-- first four slots and the wall's fixtures (127 columns), one slot that
-- repeats to fill the width, and a right part of two slots (56). Rows: the wall
-- and the first desk row (29), one desk row (16) that repeats to fill the
-- height, and a strip (11) with the second lounge and the table-tennis table.
--
-- Positions are the mock's pixels: a cell is one pixel wide and two tall, the
-- cell row `r` has its bottom pixel at `2 * r + 1`, and a piece stands on the
-- cell its anchor is placed on.

local M = {}

M.SLOT_COLUMNS = 28
M.FIRST_DESK_COLUMN = 15
M.LEFT_SLOTS = 5
M.RIGHT_SLOTS = 2
M.LEFT = 155
M.RIGHT = 56
M.WIDTH = M.LEFT + M.SLOT_COLUMNS + M.RIGHT

--- The rows of the first desk row, its aisle first.
M.FIRST_DESK_ROW_LENGTH = 16
--- The rows of the wall, above the baseboard's.
M.WALL_ROWS = 13
--- The rows of the block of rows that repeats.
M.DESK_ROW_LENGTH = 16
--- The rows of the strip under the desk rows.
M.STRIP_LENGTH = 11

--- The column a decoration run starts at, past the fixtures of the wall.
local DECORATION_START = 113
--- How far into the right part the run goes.
local DECORATION_RIGHT_END = 38

--- Where the fixtures of the wall stand.
M.FIXTURES = {
  door = 0,
  board = 12,
  board_width = 26,
  cabinet = 41,
  bin = 56,
  clock = 55,
  coffee = 66,
  printer = 86,
  calendar = 89,
  ceiling_lamp = 57,
}

local function new_row(char)
  local cells = {}
  for index = 1, M.WIDTH do
    cells[index] = char
  end
  return cells
end

local function put(row, column, char)
  assert(column >= 0 and column < M.WIDTH, 'column out of the plan: ' .. column)
  row[column + 1] = char
end

local function slot_column(slot)
  return M.FIRST_DESK_COLUMN + slot * M.SLOT_COLUMNS
end

--- Lays the desk of `slot` into the rows of a desk row, `rows[r + 1]` being
--- the row `r` counted from the aisle.
---
---@param rows string[][]
---@param slot integer
---@param on_the_wall boolean whether the aisle is the wall's, with a baseboard
local function lay_desk(rows, slot, on_the_wall)
  local x = slot_column(slot)
  local letters = on_the_wall and { beside = 'e', left = 'x', right = 'y' }
    or { beside = 'a', left = 'w', right = 'v' }
  put(rows[1], x + 7, letters.beside)
  put(rows[1], x + 15, letters.right)
  put(rows[1], x - 1, letters.left)
  for r = 2, 6 do
    for column = x + 14, x + 25 do
      put(rows[r + 1], column, ' ')
    end
  end
  put(rows[7], x + 14, 'V')
  for r = 7, 9 do
    for column = x, x + 25 do
      put(rows[r + 1], column, ' ')
    end
  end
  put(rows[8], x, 'T')
  put(rows[8], x + 7, 's')
end

--- Lays a lounge into the rows of a desk row: the sofa behind its seats, the
--- seats, the sofa's front, the rug, the low table and the lamp.
---
---@param rows string[][]
---@param column integer the left edge of the rug
function M.lay_lounge(rows, column)
  local sofa = column + 2
  for r = 1, 7 do
    for at = sofa, sofa + 43 do
      put(rows[r + 1], at, ' ')
    end
  end
  put(rows[7], sofa, 'u')
  put(rows[9], sofa, 'f')
  put(rows[8], sofa + 9, 'Q')
  put(rows[8], sofa + 21, 'q')
  put(rows[8], sofa + 33, 'q')
  for at = column, column + 49 do
    put(rows[10], at, 'r')
  end
  put(rows[10], sofa + 15, 't')
  put(rows[9], column + 50, 'L')
end

--- The rows of the plan, each a list of cells, and the numbers of the first
--- and the last row of the block that repeats, from 1.
---
---@return string[][] rows
---@return integer first_repeating
---@return integer last_repeating
function M.rows()
  local rows = {}
  local fixtures = M.FIXTURES

  -- The wall.
  for _ = 0, M.WALL_ROWS - 1 do
    rows[#rows + 1] = new_row('#')
  end
  local function wall(row)
    return rows[row + 1]
  end
  put(wall(12), fixtures.door, 'D')
  put(wall(12), fixtures.cabinet, 'C')
  put(wall(12), fixtures.bin, 'N')
  put(wall(12), fixtures.coffee, 'M')
  put(wall(12), fixtures.printer, 'P')
  for column = fixtures.board, fixtures.board + fixtures.board_width - 1 do
    put(wall(9), column, 'B')
  end
  put(wall(7), fixtures.clock, 'K')
  put(wall(6), fixtures.calendar, 'A')
  put(wall(2), fixtures.ceiling_lamp, 'l')
  put(wall(2), M.LEFT + 14, 'l')
  for column = DECORATION_START, M.LEFT + M.SLOT_COLUMNS + DECORATION_RIGHT_END - 1 do
    put(wall(8), column, '*')
  end
  put(wall(12), M.LEFT + M.SLOT_COLUMNS + 46, 'G')

  -- The first desk row: row 0 is the wall's aisle.
  local first = {}
  for r = 0, M.FIRST_DESK_ROW_LENGTH - 1 do
    first[r + 1] = new_row(r == 0 and 'z' or '.')
  end
  for _, slot in ipairs({ 0, 3, 4, 5, 6, 7 }) do
    lay_desk(first, slot, false)
    local x = slot_column(slot)
    put(first[1], x + 7, 'e')
    put(first[1], x + 15, 'y')
    put(first[1], x - 1, 'x')
  end
  M.lay_lounge(first, slot_column(1))
  put(first[1], 5, 'd')
  put(first[1], 28, 'b')
  put(first[1], 34, 'c')
  put(first[1], 48, 'n')
  put(first[1], 59, 'm')
  put(first[1], 87, 'p')
  put(first[1], M.LEFT + M.SLOT_COLUMNS + 40, 'o')
  for _, row in ipairs(first) do
    rows[#rows + 1] = row
  end

  -- The block of rows that repeats: a desk row.
  local first_repeating = #rows + 1
  local block = {}
  for r = 0, M.DESK_ROW_LENGTH - 1 do
    block[r + 1] = new_row('.')
  end
  for slot = 0, M.LEFT_SLOTS + 1 + M.RIGHT_SLOTS - 1 do
    lay_desk(block, slot, false)
  end
  for _, row in ipairs(block) do
    rows[#rows + 1] = row
  end
  local last_repeating = #rows

  -- The strip: the second lounge, and the table-tennis table.
  local strip = {}
  for r = 0, M.STRIP_LENGTH - 1 do
    strip[r + 1] = new_row('.')
  end
  M.lay_lounge(strip, slot_column(0))
  local table_left = 80
  put(strip[10], table_left, 'X')
  for offset = 1, 25 do
    put(strip[10], table_left + offset, ' ')
  end
  put(strip[10], table_left - 8, 'i')
  put(strip[10], table_left + 25 + 8, 'j')
  for _, row in ipairs(strip) do
    rows[#rows + 1] = row
  end
  return rows, first_repeating, last_repeating
end

--- The text of the plan's file.
---
---@return string
function M.text()
  local rows, first_repeating, last_repeating = M.rows()
  local marks = (' '):rep(M.LEFT) .. ('~'):rep(M.SLOT_COLUMNS) .. (' '):rep(M.RIGHT)
  local lines = {
    '# The default office: the wall along the top, a lounge, and rows of desks.',
    '# The line after the comments marks with ~ the columns that repeat to fill the width,',
    '# and the first column the rows that repeat to fill the height.',
    '# . floor  # wall  space: floor nobody walks on  letters: floor.legend in pack.lua',
    ' ' .. marks,
  }
  for index, row in ipairs(rows) do
    local marker = (index >= first_repeating and index <= last_repeating) and '~' or ' '
    table.insert(lines, marker .. table.concat(row))
  end
  return table.concat(lines, '\n') .. '\n'
end

--- The spots of the plan, by the letter that marks them.
---
---@return table<string, table> legend entries, as the pack's legend reads them
function M.legend()
  local baseboard = { piece = 'baseboard', walk_over = true }
  local function on_the_baseboard(entry)
    return vim.tbl_extend('force', baseboard, entry)
  end
  return {
    D = { piece = 'door', in_use = 'door_open' },
    z = baseboard,
    d = on_the_baseboard({ spot = 'door' }),
    B = { piece = 'whiteboard', shows = 'plan' },
    b = on_the_baseboard({ spot = 'whiteboard', facing = 'left' }),
    C = { piece = 'file_cabinet', in_use = 'file_cabinet_open' },
    c = on_the_baseboard({ spot = 'file_cabinet' }),
    N = { piece = 'trash_bin' },
    n = on_the_baseboard({ spot = 'trash_bin' }),
    K = { piece = 'wall_clock', shows = 'time' },
    A = { piece = 'wall_calendar', shows = 'date' },
    l = { piece = 'ceiling_lamp' },
    M = { piece = 'coffee_machine', in_use = 'coffee_machine_brewing' },
    m = on_the_baseboard({ spot = 'coffee_machine' }),
    P = { piece = 'printer', shows = 'printing' },
    p = on_the_baseboard({ spot = 'printer' }),
    G = { piece = 'corner_plant' },
    o = on_the_baseboard({ spot = 'corner_plant' }),
    ['*'] = {
      decorations = require('furniture').PREFERENCE,
      shows = 'sky',
    },
    T = { piece = 'desk', shows = 'name' },
    V = { piece = 'monitor' },
    s = { spot = 'desk' },
    e = on_the_baseboard({ spot = 'beside_desk' }),
    x = on_the_baseboard({ spot = 'left_of_desk' }),
    y = on_the_baseboard({ spot = 'right_of_desk' }),
    a = { spot = 'beside_desk' },
    w = { spot = 'left_of_desk' },
    v = { spot = 'right_of_desk' },
    u = { piece = 'sofa_back' },
    f = { piece = 'sofa_front' },
    Q = { spot = 'sofa', sitting = true, facing = 'left' },
    q = { spot = 'sofa', sitting = true },
    r = { piece = 'rug', walk_over = true },
    t = { piece = 'low_table' },
    L = { piece = 'floor_lamp' },
    X = { piece = 'table_tennis', in_use = 'table_tennis_playing' },
    i = { spot = 'table_tennis' },
    j = { spot = 'table_tennis', facing = 'left' },
  }
end

return M
