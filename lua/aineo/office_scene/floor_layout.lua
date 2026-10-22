--- The floor plan of a pack laid out to a size: the columns the plan marks
--- repeat to fill the width, what each cell is, and where the plan's letters
--- put pieces and spots.

local M = {}

local WALL = '#'
local FLOOR = '.'
local UNWALKED_FLOOR = ' '

--- The cells of a plan that are no letter of the legend.
local PLAIN_CELLS = { [WALL] = true, [FLOOR] = true, [UNWALKED_FLOOR] = true }

---@class aineo.office_scene.PlacedPiece
---@field piece string the piece's name
---@field column integer the cell its bottom left corner stands on, from 0
---@field row integer

---@class aineo.office_scene.Spot
---@field column integer
---@field row integer
---@field sitting boolean whether a character at the spot sits
---@field facing string 'left' or 'right'

---@class aineo.office_scene.FloorLayout
---@field width integer
---@field is_wall fun(column: integer, row: integer): boolean whether the cell is wall; false below the plan
---@field pieces aineo.office_scene.PlacedPiece[] in the order the plan reads, row by row from the top and left to right
---@field spots table<string, aineo.office_scene.Spot[]> by name, each in the order the plan reads

--- `row` laid out `width` cells wide: its repeated columns repeated as many
--- whole times as fit, what is left padded with the row's last cell when that
--- is wall or floor and with floor otherwise, and cut at `width`.
---
---@param row string
---@param repeated_columns? { first: integer, last: integer }
---@param width integer
---@return string
local function lay_out_row(row, repeated_columns, width)
  local text = row
  local block = repeated_columns and row:sub(repeated_columns.first, repeated_columns.last) or ''
  if #block > 0 then
    local left = row:sub(1, repeated_columns.first - 1)
    local right = row:sub(repeated_columns.last + 1)
    local times = math.max(1, math.floor((width - #left - #right) / #block))
    text = left .. block:rep(times) .. right
  end
  local last = text:sub(-1)
  local padding = PLAIN_CELLS[last] and last or FLOOR
  return (text .. padding:rep(width - #text)):sub(1, width)
end

--- Whether the cell at `column` of `row` is wall: a wall cell is; a letter's
--- cell is what the nearest wall or floor cell of its row is, the one to its
--- left first; with none, floor.
---
---@param row string
---@param column integer from 1
---@return boolean
local function is_wall_cell(row, column)
  for distance = 0, #row do
    for _, position in ipairs({ column - distance, column + distance }) do
      local cell = row:sub(position, position)
      if position >= 1 and PLAIN_CELLS[cell] then
        return cell == WALL
      end
    end
  end
  return false
end

--- Lays `floor` out `width` cells wide.
---
---@param floor aineo.office_pack.Floor
---@param width integer cells
---@return aineo.office_scene.FloorLayout
function M.lay_out(floor, width)
  local walls = {}
  local pieces = {}
  local spots = {}
  for row_index, plan_row in ipairs(floor.rows) do
    local row = row_index - 1
    local text = lay_out_row(plan_row, floor.repeated_columns, width)
    walls[row] = {}
    for column = 0, width - 1 do
      local cell = text:sub(column + 1, column + 1)
      walls[row][column] = is_wall_cell(text, column + 1)
      local entry = floor.legend[cell]
      if entry and entry.piece then
        table.insert(pieces, { piece = entry.piece, column = column, row = row })
      end
      if entry and entry.spot then
        spots[entry.spot] = spots[entry.spot] or {}
        table.insert(spots[entry.spot], {
          column = column,
          row = row,
          sitting = entry.sitting == true,
          facing = entry.facing or 'right',
        })
      end
    end
  end
  return {
    width = width,
    is_wall = function(column, row)
      return walls[row] ~= nil and walls[row][column] == true
    end,
    pieces = pieces,
    spots = spots,
  }
end

return M
