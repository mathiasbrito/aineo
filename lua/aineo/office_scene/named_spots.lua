--- The spots a step's `at` names: the spots of the plan's legend, and the
--- places aineo knows by name without a legend.
---
--- The spot called `desk` is each agent's own: the agent with the first place
--- has the first desk of the plan, the agent with the second place the second.
--- `anywhere` is a floor cell at random; `an_empty_desk` a desk no agent has;
--- `an_idle_agents_desk` the desk of another agent in the state `idle`;
--- `next_to_an_agent` a cell beside another agent who stands still,
--- `next_to_the_cat` a cell beside a cat that stands still. A thing
--- that lies on the floor is a spot of its own name. Any other name is every
--- spot of the name, and the character may go to the ones no
--- other character has taken.

local roles = require('aineo.office_scene.roles')

local M = {}

--- The name of the spots that belong to one agent each.
local OWN_DESK = 'desk'

--- The name of a floor cell drawn at random when a character goes there.
M.ANYWHERE = 'anywhere'

--- The name of the cells beside agents.
local NEXT_TO_AN_AGENT = 'next_to_an_agent'

--- The name of the cells beside cats.
local NEXT_TO_THE_CAT = 'next_to_the_cat'

---@class aineo.office_scene.SpotChoice
---@field open aineo.office_scene.Spot[] the spots the character may go to
---@field any boolean whether the plan has a spot of the name, taken or not

---@class aineo.office_scene.SpotAvailability
---@field free integer how many spots the character may go to
---@field any boolean whether the plan has a spot of the name, taken or not

---@class aineo.office_scene.SpotWorld
---@field layout aineo.office_scene.FloorLayout
---@field taken table<aineo.office_scene.Spot, string> the id of the character that has each spot taken
---@field random fun(): number a number from 0 up to, not including, 1
---@field places_taken table<integer, true> the places the agents have
---@field things aineo.office_scene.Things what lies on the floor
---@field agents { id: string, place: integer, state: string, column?: number, row?: number, path: aineo.office_scene.Cell[] }[] the agents
---@field cats? { id: string, column?: number, row?: number, path: aineo.office_scene.Cell[] }[] the cats

---@type table<aineo.office_scene.FloorLayout, integer[]>
local walkable_keys_of = setmetatable({}, { __mode = 'k' })

--- The cells characters walk on in `layout`, as `row * width + column`, in
--- increasing order so that a random source picks the same cell on every run.
---
---@param layout aineo.office_scene.FloorLayout
---@return integer[]
local function walkable_keys(layout)
  if not walkable_keys_of[layout] then
    local keys = vim.tbl_keys(layout.walkable_cells)
    table.sort(keys)
    walkable_keys_of[layout] = keys
  end
  return walkable_keys_of[layout]
end

--- The cells, as `row * width + column`, the characters stand on.
---
---@param world aineo.office_scene.SpotWorld
---@return table<integer, true>
local function cells_characters_stand_on(world)
  local occupied = {}
  for _, group in ipairs({ world.agents, world.cats or {} }) do
    for _, other in ipairs(group) do
      if other.column then
        local column, row = math.floor(other.column + 0.5), math.floor(other.row + 0.5)
        occupied[row * world.layout.width + column] = true
      end
    end
  end
  return occupied
end

--- The first of `keys`, from the one at `index` on and round again, that is
--- not in `occupied`; the one at `index` when all are.
---
---@param keys integer[]
---@param index integer
---@param occupied table<integer, true>
---@return integer
local function first_free_key_from(keys, index, occupied)
  for offset = 0, #keys - 1 do
    local key = keys[(index - 1 + offset) % #keys + 1]
    if not occupied[key] then
      return key
    end
  end
  return keys[index]
end

--- A spot on a floor cell that is no spot of the plan.
---
---@param name string
---@param key integer the cell as `row * width + column`
---@param width integer
---@return aineo.office_scene.Spot
local function spot_on_cell(name, key, width)
  return {
    name = name,
    number = 1,
    order = 0,
    column = key % width,
    row = math.floor(key / width),
    sitting = false,
    facing = 'right',
  }
end

--- The floor cell the random source picks, or the first one after it that is
--- not in `avoided`, as the one open spot.
---
---@param world aineo.office_scene.SpotWorld
---@param avoided table<integer, true> cells as `row * width + column`
---@return aineo.office_scene.SpotChoice
local function floor_cell_choice(world, avoided)
  local keys = walkable_keys(world.layout)
  if #keys == 0 then
    return { open = {}, any = false }
  end
  local drawn = math.floor(world.random() * #keys) + 1
  local key = first_free_key_from(keys, drawn, avoided)
  return { open = { spot_on_cell(M.ANYWHERE, key, world.layout.width) }, any = true }
end

--- The desks of the plan no agent has.
---
---@param world aineo.office_scene.SpotWorld
---@return aineo.office_scene.Spot[]
local function empty_desks(world)
  return vim.tbl_filter(function(desk)
    return not world.places_taken[desk.number]
  end, world.layout.spots[OWN_DESK] or {})
end

--- The desks of the agents, other than `character`, that are idle.
---
---@param world aineo.office_scene.SpotWorld
---@param character { id: string }
---@return aineo.office_scene.Spot[]
local function idle_agents_desks(world, character)
  local desks = world.layout.spots[OWN_DESK] or {}
  local found = {}
  for _, agent in ipairs(world.agents) do
    if agent.id ~= character.id and roles.is_idle(agent) and desks[agent.place] then
      table.insert(found, desks[agent.place])
    end
  end
  return found
end

--- The cells beside the `beside` characters, other than `character`, who
--- stand still, each facing the one it is beside.
---
---@param world aineo.office_scene.SpotWorld
---@param character { id: string }
---@param beside { id: string, column?: number, row?: number, path: aineo.office_scene.Cell[] }[]
---@param name string the name of the spots found
---@return aineo.office_scene.Spot[]
local function cells_beside(world, character, beside, name)
  local layout, found = world.layout, {}
  for _, other in ipairs(beside) do
    if other.id ~= character.id and other.column and #other.path == 0 then
      local column, row = math.floor(other.column + 0.5), math.floor(other.row + 0.5)
      for _, across in ipairs({ -1, 1 }) do
        if layout.is_walkable(column + across, row) then
          local spot = spot_on_cell(name, row * layout.width + column + across, layout.width)
          spot.facing = across < 0 and 'right' or 'left'
          spot.beside = other.id
          table.insert(found, spot)
        end
      end
    end
  end
  return found
end

--- The cells beside agents, other than `character`, who stand still.
---
---@param world aineo.office_scene.SpotWorld
---@param character { id: string }
---@return aineo.office_scene.Spot[]
local function cells_beside_agents(world, character)
  return cells_beside(world, character, world.agents, NEXT_TO_AN_AGENT)
end

--- The cells beside cats that stand still.
---
---@param world aineo.office_scene.SpotWorld
---@param character { id: string }
---@return aineo.office_scene.Spot[]
local function cells_beside_cats(world, character)
  return cells_beside(world, character, world.cats or {}, NEXT_TO_THE_CAT)
end

--- The spots, besides the plan's own, that aineo knows by name, each found
--- from the state of the office.
---
---@type table<string, fun(world: aineo.office_scene.SpotWorld, character: table): aineo.office_scene.Spot[]>
local KNOWN_SPOTS = {
  an_empty_desk = empty_desks,
  an_idle_agents_desk = idle_agents_desks,
  next_to_an_agent = cells_beside_agents,
  next_to_the_cat = cells_beside_cats,
}

--- The spots named `name`, whoever has them: those of the plan, and the
--- spots of the things of that name that lie on the floor.
---
---@param world aineo.office_scene.SpotWorld
---@param name string
---@param character table
---@return aineo.office_scene.Spot[]
local function spots_called(world, name, character)
  local known = KNOWN_SPOTS[name]
  if known then
    return known(world, character)
  end
  local called = vim.list_slice(world.layout.spots[name] or {})
  return vim.list_extend(called, world.things.spots_named(name))
end

--- Whether `character` may go to `spot`.
---
---@param world aineo.office_scene.SpotWorld
---@param spot aineo.office_scene.Spot
---@param character { id: string }
---@param even_if_taken boolean
---@return boolean
local function is_open(world, spot, character, even_if_taken)
  return even_if_taken or world.taken[spot] == nil or world.taken[spot] == character.id
end

--- How many spots named `name` `character` may go to, and whether the plan
--- has any: what it takes to know whether a step can be played, drawing
--- nothing.
---
---@param world aineo.office_scene.SpotWorld
---@param name string
---@param character { id: string, place: integer }
---@param even_if_taken boolean whether the spots other characters have are open too
---@return aineo.office_scene.SpotAvailability
function M.availability(world, name, character, even_if_taken)
  if name == M.ANYWHERE then
    local cells = #walkable_keys(world.layout)
    return { free = cells, any = cells > 0 }
  end
  local choice = M.choose(world, name, character, even_if_taken)
  return { free = #choice.open, any = choice.any }
end

--- The floor cell, where no character stands, that the random source picks:
--- where a character goes whose step names a spot the plan lacks and who has
--- no place yet.
---
---@param world aineo.office_scene.SpotWorld
---@return aineo.office_scene.SpotChoice
function M.choose_free_floor_cell(world)
  return floor_cell_choice(world, cells_characters_stand_on(world))
end

--- The spots named `name` that `character` may go to, and whether there are
--- any of the name. For `anywhere`, the one floor cell the random source
--- picks.
---
---@param world aineo.office_scene.SpotWorld
---@param name string
---@param character { id: string, place: integer }
---@param even_if_taken boolean whether the spots other characters have are open too
---@return aineo.office_scene.SpotChoice
function M.choose(world, name, character, even_if_taken)
  if name == M.ANYWHERE then
    return floor_cell_choice(world, {})
  end
  if name == OWN_DESK then
    local own = spots_called(world, name, character)[character.place]
    return { open = { own }, any = own ~= nil }
  end
  local all = spots_called(world, name, character)
  local open = vim.tbl_filter(function(spot)
    return is_open(world, spot, character, even_if_taken)
  end, all)
  return { open = open, any = #all > 0 }
end

return M
