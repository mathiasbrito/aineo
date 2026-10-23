--- The spots the characters hold: a character that goes to a spot takes it,
--- and lets go of the one it was on.

local M = {}

--- Lets go of the spot the performer has taken.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
function M.let_go_of_spot(context, performer)
  if performer.spot then
    if context.taken[performer.spot] == performer.id then
      context.taken[performer.spot] = nil
    end
    performer.spot = nil
  end
end

--- Sends the performer to the spot `route` leads to, and has it walk the way.
--- A performer with no place yet is put on the spot.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param route aineo.office_scene.Route
function M.take_route(context, performer, route)
  M.let_go_of_spot(context, performer)
  local holder = context.taken[route.spot]
  performer.displaces = holder ~= performer.id and holder or nil
  performer.spot = route.spot
  context.taken[route.spot] = performer.id
  performer.path = route.path
  if not performer.column then
    performer.column, performer.row = route.spot.column, route.spot.row
    performer.facing = route.spot.facing
  end
end

return M
