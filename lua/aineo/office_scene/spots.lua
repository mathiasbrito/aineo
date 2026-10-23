--- The way to a spot a character has chosen: the nearest one by walking of
--- those open to it.

local paths = require('aineo.office_scene.paths')

local M = {}

--- Why a character has no route to the spot it wants: every spot of the name
--- is taken by others, or the plan has none of the name, or none that can be
--- walked to.
M.TAKEN = 'taken'
M.UNREACHABLE = 'unreachable'

---@class aineo.office_scene.Route
---@field spot aineo.office_scene.Spot
---@field path aineo.office_scene.Cell[] the cells to walk over to it, the next first; empty when the character is there or has not been placed yet

--- Where the character goes among the spots `choice` holds, and the way
--- there. A character not yet placed is put on the first open spot, without
--- a walk.
---
---@param layout aineo.office_scene.FloorLayout
---@param choice aineo.office_scene.SpotChoice
---@param character { column?: number, row?: number }
---@return aineo.office_scene.Route|nil route nil when no spot is open and can be walked to
---@return string|nil why `TAKEN` when the plan has spots of the name that other characters have, `UNREACHABLE` otherwise; none with a route
function M.route(layout, choice, character)
  local open = choice.open
  if #open == 0 then
    return nil, choice.any and M.TAKEN or M.UNREACHABLE
  end
  if not character.column then
    return { spot = open[1], path = {} }
  end
  local route = paths.nearest(layout, {
    column = math.floor(character.column + 0.5),
    row = math.floor(character.row + 0.5),
  }, open)
  if route then
    return route
  end
  return nil, M.UNREACHABLE
end

return M
