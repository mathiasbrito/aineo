--- The pieces the floor plan places, as items to paint: walls' decoration,
--- desks, doors and the rest, stretched to the width the plan draws them.

local items = require('aineo.office_scene.items')
local stretch = require('aineo.office_scene.stretch')

local M = {}

--- Whether any row of `piece`, placed with its anchor on the cell row `row`,
--- lies on a canvas `height` cells tall.
---
---@param piece aineo.office_pack.Piece
---@param row integer
---@param height integer
---@return boolean
local function is_on_canvas(piece, row, height)
  local top = 2 * row + 1 - piece.anchor.row
  return top < 2 * height and top + piece.height > 0
end

--- The items for the pieces the plan places that lie on the canvas.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@return aineo.office_scene.Item[]
function M.items(canvas, drawing)
  local made = {}
  for _, placed in ipairs(drawing.layout.pieces) do
    local piece = drawing.pack.pieces[placed.piece]
    if piece and placed.columns then
      piece = stretch.to_width(piece, placed.columns)
    end
    if piece and is_on_canvas(piece, placed.row, drawing.height) then
      table.insert(made, {
        depth = 2 * placed.row + 1,
        rank = items.RANK.piece,
        paint = function()
          canvas.paint_art(piece, {
            frame = items.frame_after(piece, drawing.now),
            column = placed.column,
            row = 2 * placed.row + 1,
            colours = drawing.pack.colours,
          })
        end,
      })
    end
  end
  return made
end

return M
