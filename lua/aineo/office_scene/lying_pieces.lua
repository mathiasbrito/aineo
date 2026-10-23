--- The things that lie on the floor, as items to paint: each under everything
--- that stands on its cell.

local items = require('aineo.office_scene.items')

local M = {}

--- The depth of a thing on the floor: above no cell of the canvas.
local ON_THE_FLOOR = -1

--- The items for the things that lie on the plan.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@return aineo.office_scene.Item[]
function M.items(canvas, drawing)
  local made = {}
  for _, thing in ipairs(drawing.things) do
    local piece = drawing.pack.pieces[thing.piece]
    if piece and thing.row < drawing.plan_height then
      table.insert(made, {
        depth = ON_THE_FLOOR,
        rank = items.RANK.on_the_floor,
        paint = function()
          canvas.paint_art(piece, {
            frame = items.frame_after(piece, drawing.now),
            column = thing.column,
            row = 2 * thing.row + 1,
            colours = drawing.pack.colours,
            clip = items.plan_area(drawing),
          })
        end,
      })
    end
  end
  return made
end

return M
