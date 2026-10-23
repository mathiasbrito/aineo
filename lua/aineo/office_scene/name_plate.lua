--- The name plate of a desk: the name of the agent whose desk it is, written
--- into the `name` area of the piece, no wider than the area.

local areas = require('aineo.office_scene.areas')
local cell_text = require('aineo.office_scene.cell_text')

local M = {}

--- The agent whose desk `placed` is: the one with the place the desk was
--- given.
---
---@param drawing aineo.office_scene.Drawing
---@param placed aineo.office_scene.PlacedPiece
---@return aineo.office_states.Agent|nil
local function owner_of(drawing, placed)
  return placed.owner_place
    and vim.iter(drawing.agents):find(function(agent)
      return drawing.places[agent.id] == placed.owner_place
    end)
end

--- Writes the name of the owner of the desk `placed` into its `name` area.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param placed aineo.office_scene.PlacedPiece
---@param piece aineo.office_pack.Piece the art the desk is drawn in
function M.paint(canvas, drawing, placed, piece)
  local owner = owner_of(drawing, placed)
  local plate = areas.on_canvas(placed, piece, 'name')
  if not (owner and plate) then
    return
  end
  areas.write_text_above_the_list(
    canvas,
    drawing,
    { column = plate.column, row = math.floor(plate.row / 2) },
    cell_text.cut_to(owner.id, plate.width),
    { foreground = drawing.pack.text_colours.name }
  )
end

return M
