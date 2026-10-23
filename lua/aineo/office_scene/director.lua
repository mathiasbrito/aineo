--- The director of the office: where each agent is and what it is doing. An
--- agent plays the activity its state maps to, or the one a trigger of the
--- pack chose for what it is doing. It plays the activity's steps in order:
--- it goes to the spot a step names, walking there over the floor, takes the
--- step's pose, and stays for the step's time before the next step begins. The
--- last step lasts until the agent's activity changes.

local roles = require('aineo.office_scene.roles')
local spots = require('aineo.office_scene.spots')
local walking = require('aineo.office_scene.walking')

local M = {}

--- The spot a character that has no place yet is put on when its first step
--- names none.
local ENTRANCE = 'door'

---@class aineo.office_scene.Character
---@field id string the agent's id
---@field kind string 'agent' for the main agent, 'subagent' for the others
---@field index integer the agent's place among the agents given, from 1
---@field column number the cell column it is at, between cells while it walks
---@field row number the cell row its feet are at
---@field facing string 'left' or 'right'
---@field pose string the pose it holds
---@field pose_since number when it took the pose, on the stage's clock
---@field at_a_seat boolean whether it stands at a spot where characters sit
---@field effect? string the effect its step names, shown in place of its pose's

---@class aineo.office_scene.Performer : aineo.office_scene.Character
---@field activity_name string
---@field activity table the activity it plays
---@field step_index integer the step it is on
---@field step_seconds? number how long the step lasts from its arrival; none when it lasts until the activity changes
---@field arrived_at? number when it arrived for the step; none while it walks
---@field spot? aineo.office_scene.Spot the spot it has taken
---@field path aineo.office_scene.Cell[] the cells it has still to walk over, the next first
---@field clock number the time the character has been brought up to

---@class aineo.office_scene.Director
---@field update fun(agents: aineo.office_states.Agent[], now: number) brings the agents up to `now`, in the states they are in
---@field characters fun(): aineo.office_scene.Character[] the agents with a place, in the order they were given

---@class aineo.office_scene.DirectorContext
---@field pack aineo.office_pack.Pack
---@field layout aineo.office_scene.FloorLayout
---@field random fun(): number a number from 0 up to, not including, 1
---@field taken table<aineo.office_scene.Spot, string> the id of the character that has each spot taken

--- How long a step lasts: its `for_seconds`, or a time between its two
--- numbers.
---
---@param for_seconds? number|number[]
---@param random fun(): number
---@return number|nil seconds nil for a step that lasts until the activity changes
local function seconds_of(for_seconds, random)
  if type(for_seconds) == 'table' then
    return for_seconds[1] + (for_seconds[2] - for_seconds[1]) * random()
  end
  return for_seconds
end

--- Lets go of the spot the performer has taken.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
local function let_go_of_spot(context, performer)
  if performer.spot then
    context.taken[performer.spot] = nil
    performer.spot = nil
  end
end

--- Puts the performer in the pose of `step`, facing the way the step or its
--- spot says, at `time`.
---
---@param performer aineo.office_scene.Performer
---@param step table
---@param time number
local function arrive(performer, step, time)
  performer.pose = step.pose
  performer.facing = step.facing or (performer.spot and performer.spot.facing) or performer.facing
  performer.effect = step.effect
  performer.arrived_at = time
  performer.pose_since = time
  performer.at_a_seat = performer.spot ~= nil and performer.spot.sitting
end

--- Sends the performer to the spot `route` leads to, and has it walk the way.
--- A performer with no place yet is put on the spot.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param route aineo.office_scene.Route
local function take_route(context, performer, route)
  let_go_of_spot(context, performer)
  performer.spot = route.spot
  context.taken[route.spot] = performer.id
  performer.path = route.path
  if not performer.column then
    performer.column, performer.row = route.spot.column, route.spot.row
    performer.facing = route.spot.facing
  end
end

--- Begins step `index` of the performer's activity at `time`.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param index integer
---@param time number
local function begin_step(context, performer, index, time)
  local step = performer.activity.steps[index]
  performer.step_index = index
  performer.step_seconds = seconds_of(step.for_seconds, context.random)
  performer.arrived_at = nil
  performer.effect = nil
  performer.at_a_seat = false
  performer.path = {}
  local spot_name = step.at or (not performer.column and ENTRANCE) or nil
  local route = spot_name and spots.route(context.layout, spot_name, performer, context.taken)
  if route then
    take_route(context, performer, route)
  elseif spot_name then
    let_go_of_spot(context, performer)
  end
  if not performer.column then
    return
  end
  if #performer.path > 0 then
    performer.pose, performer.pose_since = walking.POSE, time
  else
    arrive(performer, step, time)
  end
end

--- Whether the performer's step is over at `time` and there is a step after
--- it.
---
---@param performer aineo.office_scene.Performer
---@param time number
---@return number|nil ends_at when the step ended; nil when it has not or none follows
local function step_end_before(performer, time)
  local next_step = performer.activity.steps[performer.step_index + 1]
  if not (next_step and performer.arrived_at and performer.step_seconds) then
    return nil
  end
  local ends_at = performer.arrived_at + performer.step_seconds
  return ends_at <= time and ends_at or nil
end

--- Brings the performer up to `now`: walks it, and goes on to the next step
--- whenever a step ends on the way.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param now number
local function bring_up_to(context, performer, now)
  if not performer.column then
    begin_step(context, performer, performer.step_index, now)
  end
  local clock = performer.clock
  while performer.column do
    if #performer.path > 0 then
      clock = clock + walking.advance(performer, now - clock)
      if #performer.path > 0 then
        break
      end
      arrive(performer, performer.activity.steps[performer.step_index], clock)
    end
    local ends_at = step_end_before(performer, now)
    if not ends_at then
      break
    end
    clock = ends_at
    begin_step(context, performer, performer.step_index + 1, clock)
  end
  performer.clock = now
end

--- A performer for `agent` that has no activity and no place yet.
---
---@param agent aineo.office_states.Agent
---@param now number
---@return aineo.office_scene.Performer
local function new_performer(agent, now)
  return {
    id = agent.id,
    kind = roles.kind_of(agent),
    clock = now,
    path = {},
    step_index = 1,
  }
end

--- A director of the agents of `pack`'s office, laid out as `layout`.
---
---@param pack aineo.office_pack.Pack
---@param layout aineo.office_scene.FloorLayout
---@param random fun(): number the source of the random times of steps
---@return aineo.office_scene.Director
function M.new_director(pack, layout, random)
  ---@type aineo.office_scene.DirectorContext
  local context = { pack = pack, layout = layout, random = random, taken = {} }
  ---@type table<string, aineo.office_scene.Performer>
  local known = {}
  ---@type aineo.office_scene.Performer[]
  local placed = {}

  local director = {}

  function director.update(agents, now)
    local present = {}
    placed = {}
    for index, agent in ipairs(agents) do
      local name, activity = roles.activity_of(pack, agent)
      local performer = known[agent.id] or new_performer(agent, now)
      known[agent.id] = performer
      performer.index = index
      if activity and performer.activity_name ~= name then
        performer.activity_name, performer.activity, performer.step_index = name, activity, 1
        begin_step(context, performer, 1, performer.clock)
      end
      if performer.activity then
        bring_up_to(context, performer, now)
      end
      present[agent.id] = true
      if performer.column then
        table.insert(placed, performer)
      end
    end
    for id, performer in pairs(known) do
      if not present[id] then
        let_go_of_spot(context, performer)
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
