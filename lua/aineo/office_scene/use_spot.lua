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

--- How many cells apart, across and down, a piece and a spot are: the spot's
--- distance from the cells the piece covers.
---
---@param placed aineo.office_scene.PlacedPiece
---@param piece aineo.office_pack.Piece
---@param spot aineo.office_scene.Spot
---@return integer
local function cells_between(placed, piece, spot)
  local left = placed.column - piece.anchor.column
  local top = math.floor((2 * placed.row + 1 - piece.anchor.row) / 2)
  return distance_from_range(spot.column, left, left + (placed.columns or piece.width) - 1)
    + distance_from_range(spot.row, top, placed.row)
end

--- The spot nearest to the piece placed as `placed`: the first of `spots` when
--- several are as near.
---
---@param placed aineo.office_scene.PlacedPiece
---@param piece aineo.office_pack.Piece
---@param spots aineo.office_scene.Spot[] every spot of the plan, in the order they were made
---@return aineo.office_scene.Spot|nil spot nil when the plan has no spot
function M.nearest_to(placed, piece, spots)
  local nearest, fewest_cells = nil, math.huge
  for _, spot in ipairs(spots) do
    local cells = cells_between(placed, piece, spot)
    if cells < fewest_cells then
      nearest, fewest_cells = spot, cells
    end
  end
  return nearest
end

return M
