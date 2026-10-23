--- The spot a piece is used from: the one nearest to it. A piece with `in_use`
--- art shows it while a character is at its spot or walks over it.

local M = {}

--- How far `value` is from the range `low` to `high`; 0 inside it.
---
---@param value integer
---@param low integer
---@param high integer
---@return integer
local function distance_from_range(value, low, high)
  if value < low then
    return low - value
  end
  return math.max(0, value - high)
end

---@alias aineo.office_scene.UseSpotFinder fun(placed: aineo.office_scene.PlacedPiece, piece: aineo.office_pack.Piece): aineo.office_scene.Spot|nil

--- A finder of the spot nearest to a piece, over `spots`, which it sorts into
--- rows once so that a piece looks at the rows near it and not at every spot.
---
--- The nearest is the one fewest cells apart, across and down, from the cells
--- the piece covers; the first of `spots` (by its `order`) when several are as
--- near.
---
---@param spots aineo.office_scene.Spot[] every spot of the plan
---@return aineo.office_scene.UseSpotFinder
function M.new_finder(spots)
  ---@type table<integer, aineo.office_scene.Spot[]>
  local by_row = {}
  local first_row, last_row = math.huge, -math.huge
  for _, spot in ipairs(spots) do
    by_row[spot.row] = by_row[spot.row] or {}
    table.insert(by_row[spot.row], spot)
    first_row, last_row = math.min(first_row, spot.row), math.max(last_row, spot.row)
  end

  return function(placed, piece)
    local left = placed.column - piece.anchor.column
    local right = left + (placed.columns or piece.width) - 1
    local top = math.floor((2 * placed.row + 1 - piece.anchor.row) / 2)
    local bottom = placed.row
    local nearest, fewest_cells = nil, math.huge

    local function consider(row, rows_apart)
      for _, spot in ipairs(by_row[row] or {}) do
        local cells = rows_apart + distance_from_range(spot.column, left, right)
        if cells < fewest_cells or (cells == fewest_cells and spot.order < nearest.order) then
          nearest, fewest_cells = spot, cells
        end
      end
    end

    for row = math.max(top, first_row), math.min(bottom, last_row) do
      consider(row, 0)
    end
    local rows_apart = 1
    while
      rows_apart <= fewest_cells
      and (top - rows_apart >= first_row or bottom + rows_apart <= last_row)
    do
      consider(top - rows_apart, rows_apart)
      consider(bottom + rows_apart, rows_apart)
      rows_apart = rows_apart + 1
    end
    return nearest
  end
end

return M
