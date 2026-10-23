--- Where the areas of a placed piece lie on the canvas. Pure.

local M = {}

--- The area of `piece` named `name`, as the pixels of the canvas it covers
--- when the piece is placed as `placed`.
---
---@param placed aineo.office_scene.PlacedPiece
---@param piece aineo.office_pack.Piece the art the piece is drawn in
---@param name string
---@return aineo.office_scene.PixelArea|nil area none when the piece has no area of that name
function M.on_canvas(placed, piece, name)
  local area = piece.areas[name]
  if not area then
    return nil
  end
  return {
    column = placed.column - piece.anchor.column + area.column,
    row = 2 * placed.row + 1 - piece.anchor.row + area.row,
    width = area.width,
    height = area.height,
  }
end

return M
