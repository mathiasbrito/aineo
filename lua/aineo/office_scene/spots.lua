--- Choosing the spot a character goes to, and the way there.
---
--- The spot called `desk` is each agent's own: the agent with the first place
--- has the first desk of the plan, the agent with the second place the second.
--- Any other spot is the nearest one by walking that no other character has
--- taken.

local paths = require('aineo.office_scene.paths')

local M = {}

--- The name of the spots that belong to one agent each.
local OWN_DESK = 'desk'

--- Why a character has no route to the spot it wants: every spot of the name
--- is taken by others, or the plan has none of the name, or none that can be
--- walked to.
M.TAKEN = 'taken'
M.UNREACHABLE = 'unreachable'

---@class aineo.office_scene.Route
---@field spot aineo.office_scene.Spot
---@field path aineo.office_scene.Cell[] the cells to walk over to it, the next first; empty when the character is there or has not been placed yet

--- The spots of `name` the character may go to: its own desk, or those no
--- other character has taken.
---
---@param layout aineo.office_scene.FloorLayout
---@param name string
---@param who { id: string, place: integer }
---@param taken table<aineo.office_scene.Spot, string> the id of the character that has each spot taken
---@return aineo.office_scene.Spot[]
local function open_spots(layout, name, who, taken)
  local named = layout.spots[name] or {}
  if name == OWN_DESK then
    return { named[who.place] }
  end
  return vim.tbl_filter(function(spot)
    return taken[spot] == nil or taken[spot] == who.id
  end, named)
end

--- Where the character goes for a step that names the spot `name`: the spot
--- and the way there. A character not yet placed is put on the first spot of
--- the plan that is open to it, without a walk.
---
---@param layout aineo.office_scene.FloorLayout
---@param name string
---@param character { id: string, place: integer, column?: number, row?: number }
---@param taken table<aineo.office_scene.Spot, string> the id of the character that has each spot taken
---@return aineo.office_scene.Route|nil route nil when no spot of the name is open and can be walked to
---@return string|nil why `TAKEN` when the plan has spots of the name that other characters have, `UNREACHABLE` otherwise; none with a route
function M.route(layout, name, character, taken)
  local open = open_spots(layout, name, character, taken)
  if #open == 0 then
    local others_have_them = name ~= OWN_DESK and #(layout.spots[name] or {}) > 0
    return nil, others_have_them and M.TAKEN or M.UNREACHABLE
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
