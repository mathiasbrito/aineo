--- The spots a step's `at` names: the spots of the plan's legend, and, with
--- no legend, the places aineo knows by name.
---
--- The spot called `desk` is each agent's own: the agent with the first place
--- has the first desk of the plan, the agent with the second place the second.
--- Any other name is every spot of the name, and the character may go to the
--- ones no other character has taken.

local M = {}

--- The name of the spots that belong to one agent each.
local OWN_DESK = 'desk'

---@class aineo.office_scene.SpotChoice
---@field open aineo.office_scene.Spot[] the spots the character may go to
---@field any boolean whether the plan has a spot of the name, taken or not

---@class aineo.office_scene.SpotWorld
---@field layout aineo.office_scene.FloorLayout
---@field taken table<aineo.office_scene.Spot, string> the id of the character that has each spot taken

--- The spots named `name` there are, whoever has them.
---
---@param world aineo.office_scene.SpotWorld
---@param name string
---@return aineo.office_scene.Spot[]
local function spots_called(world, name)
  return world.layout.spots[name] or {}
end

--- The spots named `name` that `character` may go to, and whether there are
--- any of the name.
---
---@param world aineo.office_scene.SpotWorld
---@param name string
---@param character { id: string, place: integer }
---@param even_if_taken boolean whether the spots other characters have are open too
---@return aineo.office_scene.SpotChoice
function M.choose(world, name, character, even_if_taken)
  if name == OWN_DESK then
    local own = spots_called(world, name)[character.place]
    return { open = { own }, any = own ~= nil }
  end
  local all = spots_called(world, name)
  local open = vim.tbl_filter(function(spot)
    return even_if_taken or world.taken[spot] == nil or world.taken[spot] == character.id
  end, all)
  return { open = open, any = #all > 0 }
end

return M
