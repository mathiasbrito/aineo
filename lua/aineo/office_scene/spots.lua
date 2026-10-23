--- Choosing the spot a character goes to, and the way there.
---
--- The spot called `desk` is each agent's own: the agent given first has the
--- first desk of the plan, the next the next. Any other spot is the nearest
--- one by walking that no other character has taken.

local paths = require('aineo.office_scene.paths')

local M = {}

--- The name of the spots that belong to one agent each.
local OWN_DESK = 'desk'

---@class aineo.office_scene.Route
---@field spot aineo.office_scene.Spot
---@field path aineo.office_scene.Cell[] the cells to walk over to it, the next first; empty when the character is there or has not been placed yet

--- The spots of `name` the character may go to: its own desk, or those no
--- other character has taken.
---
---@param layout aineo.office_scene.FloorLayout
---@param name string
---@param who { id: string, index: integer }
---@param taken table<aineo.office_scene.Spot, string> the id of the character that has each spot taken
---@return aineo.office_scene.Spot[]
local function open_spots(layout, name, who, taken)
  local named = layout.spots[name] or {}
  if name == OWN_DESK then
    return { named[who.index] }
  end
  return vim.tbl_filter(function(spot)
    return taken[spot] == nil or taken[spot] == who.id
  end, named)
end

--- The route to the nearest of `spots` by walking from the cell the character
--- is at.
---
---@param layout aineo.office_scene.FloorLayout
---@param character { column: number, row: number }
---@param spots aineo.office_scene.Spot[]
---@return aineo.office_scene.Route|nil route nil when none of the spots can be walked to
local function nearest_route(layout, character, spots)
  local reach = paths.reach_from(layout, {
    column = math.floor(character.column + 0.5),
    row = math.floor(character.row + 0.5),
  })
  local nearest, fewest_steps = nil, math.huge
  for _, spot in ipairs(spots) do
    local steps = reach.distance(spot.column, spot.row)
    if steps and steps < fewest_steps then
      nearest, fewest_steps = spot, steps
    end
  end
  return nearest and { spot = nearest, path = reach.path_to(nearest.column, nearest.row) }
end

--- Where the character goes for a step that names the spot `name`: the spot
--- and the way there. A character not yet placed is put on the first spot of
--- the plan that is open to it, without a walk.
---
---@param layout aineo.office_scene.FloorLayout
---@param name string
---@param character { id: string, index: integer, column?: number, row?: number }
---@param taken table<aineo.office_scene.Spot, string> the id of the character that has each spot taken
---@return aineo.office_scene.Route|nil route nil when no spot of the name is open and can be walked to
function M.route(layout, name, character, taken)
  local spots = open_spots(layout, name, character, taken)
  if not character.column then
    return spots[1] and { spot = spots[1], path = {} }
  end
  return nearest_route(layout, character, spots)
end

return M
