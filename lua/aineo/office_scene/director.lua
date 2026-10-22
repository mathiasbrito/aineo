--- The director of the office: where each agent is and what it is doing. An
--- agent plays the activity its state maps to; it goes to the spot its
--- activity's step names, walking there in a straight line, and takes the
--- step's pose when it arrives. The step is the activity's first; an agent
--- takes the spots of that name in the order the plan reads them, the first
--- agent the first spot, and is not drawn when the plan has none left for it.

local M = {}

--- How fast an agent walks, in cells a second.
local WALK_CELLS_PER_SECOND = 14

--- The pose an agent holds while it walks.
local WALKING_POSE = 'walking'

--- The pose a step gives when it names none.
local DEFAULT_POSE = 'standing'

--- An agent in the scene, as the director places it.
---@class aineo.office_scene.Character
---@field id string the agent's id
---@field index integer the agent's place among the agents given, from 1
---@field column number the cell column its anchor is at, between cells while it walks
---@field row number the cell row its feet are at
---@field facing string 'left' or 'right'
---@field pose string the pose it holds

---@class aineo.office_scene.Director
---@field update fun(agents: aineo.office_states.Agent[], now: number) moves the agents to where their states put them, for the seconds since the last update
---@field characters fun(): aineo.office_scene.Character[] the agents with a place, in the order they were given

---@class aineo.office_scene.Target
---@field spot aineo.office_scene.Spot
---@field pose string

--- Where the agent at `index` is to be, and in which pose, for its state.
---
---@param pack aineo.office_pack.Pack
---@param layout aineo.office_scene.FloorLayout
---@param agent aineo.office_states.Agent
---@param index integer
---@return aineo.office_scene.Target|nil target nil when the activity has no step or the plan no spot for it
local function target_of(pack, layout, agent, index)
  local activity_name = pack.state_activity[agent.state] or pack.state_activity.standing
  local activity = pack.activities[activity_name]
  local step = activity and activity.steps and activity.steps[1]
  local spots = step and step.at and layout.spots[step.at]
  local spot = spots and spots[index]
  if not spot then
    return nil
  end
  return { spot = spot, pose = step.pose or DEFAULT_POSE }
end

---@param id string
---@param index integer
---@param target aineo.office_scene.Target
---@return aineo.office_scene.Character
local function placed_at(id, index, target)
  return {
    id = id,
    index = index,
    column = target.spot.column,
    row = target.spot.row,
    facing = target.spot.facing,
    pose = target.pose,
  }
end

--- Moves `character` towards `target` by what `elapsed` seconds of walking
--- cover; it takes the target's pose and facing on reaching it, and holds the
--- walking pose, facing the way it goes, until then.
---
---@param character aineo.office_scene.Character
---@param target aineo.office_scene.Target
---@param elapsed number seconds
local function walk(character, target, elapsed)
  local across = target.spot.column - character.column
  local down = target.spot.row - character.row
  local distance = math.sqrt(across * across + down * down)
  local reach = WALK_CELLS_PER_SECOND * elapsed
  if distance <= reach then
    character.column, character.row = target.spot.column, target.spot.row
    character.pose, character.facing = target.pose, target.spot.facing
    return
  end
  character.column = character.column + across / distance * reach
  character.row = character.row + down / distance * reach
  character.pose = WALKING_POSE
  if across ~= 0 then
    character.facing = across > 0 and 'right' or 'left'
  end
end

--- A director of the agents of `pack`'s office, laid out as `layout`.
---
---@param pack aineo.office_pack.Pack
---@param layout aineo.office_scene.FloorLayout
---@return aineo.office_scene.Director
function M.new_director(pack, layout)
  ---@type table<string, aineo.office_scene.Character>
  local known = {}
  ---@type aineo.office_scene.Character[]
  local placed = {}
  local last_time = nil

  local director = {}

  function director.update(agents, now)
    local elapsed = last_time and math.max(0, now - last_time) or 0
    last_time = now
    local present = {}
    placed = {}
    for index, agent in ipairs(agents) do
      local target = target_of(pack, layout, agent, index)
      if target then
        local character = known[agent.id]
        if character then
          character.index = index
          walk(character, target, elapsed)
        else
          character = placed_at(agent.id, index, target)
          known[agent.id] = character
        end
        present[agent.id] = true
        table.insert(placed, character)
      end
    end
    for id in pairs(known) do
      if not present[id] then
        known[id] = nil
      end
    end
  end

  function director.characters()
    return placed
  end

  return director
end

return M
