--- Putting a performer in a new layout of the same plan.

local paths = require('aineo.office_scene.paths')

local M = {}

--- Puts the performer in a new layout of the same plan: at the spot of the
--- same name and number when the plan has it, walking there on from where it
--- is; on its cell when it had no spot and the cell can be walked on;
--- otherwise without a position, to find one again.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
function M.move_into_layout(context, performer)
  local old = performer.spot
  performer.spot = nil
  local named = old and context.layout.spots[old.name]
  local spot = named and named[old.number]
  if spot then
    performer.spot = spot
    context.taken[spot] = performer.id
    local route = performer.column
      and #performer.path > 0
      and paths.nearest(context.layout, {
        column = math.floor(performer.column + 0.5),
        row = math.floor(performer.row + 0.5),
      }, { spot })
    performer.path = route and route.path or {}
    if not route then
      performer.column, performer.row = spot.column, spot.row
    end
    return
  end
  performer.path = {}
  local at_a_cell = performer.column
    and context.layout.is_walkable(
      math.floor(performer.column + 0.5),
      math.floor(performer.row + 0.5)
    )
  if not at_a_cell then
    performer.column, performer.row = nil, nil
  end
end

return M
