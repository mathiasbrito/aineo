--- Where the areas of a placed piece lie on the canvas, and writing text
--- into them. Pure.

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

--- Writes `text` on the text row `row` from the cell `column`, unless the row
--- is below the plan: the rows under it are the status list's, which nothing
--- else writes on.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param place { column: integer, row: integer }
---@param text string
---@param style aineo.office_scene.TextStyle
function M.write_text_above_the_list(canvas, drawing, place, text, style)
  if place.row < drawing.plan_height then
    canvas.write_text(place.column, place.row, text, style)
  end
end

return M
