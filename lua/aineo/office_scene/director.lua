--- The director of the office: where each agent is and what it is doing. An
--- agent plays the activity its state maps to, or the one a trigger of the
--- pack chose for what it is doing. It plays the activity's steps in order:
--- it goes to the spot a step names, walking there over the floor, takes the
--- step's pose, and stays for the step's time before the next step begins. As
--- a step ends it may leave a thing on the floor or remove one.
---
--- The last step of an activity lasts until the agent's activity changes, or,
--- when it has a time, until that is over: the agent then plays an activity
--- picked at random among those that name its state, never the one it has just
--- played, alone or together with the agents the activity needs.
---
--- A thing on the floor can upset the agents near it, who play what upsets
--- them, and calls for the nearest idle agent, who cleans it up; each plays
--- that as an interlude, after which it goes back to what its state asks for.
---
--- An agent has a place among the agents from the moment it arrives to the
--- moment it leaves: the lowest number no other agent has. Its colour, its
--- desk and its monitor go by its place.

local named_spots = require('aineo.office_scene.named_spots')
local parties = require('aineo.office_scene.parties')
local paths = require('aineo.office_scene.paths')
local random_life = require('aineo.office_scene.random_life')
local roles = require('aineo.office_scene.roles')
local spots = require('aineo.office_scene.spots')
local things = require('aineo.office_scene.things')
local walking = require('aineo.office_scene.walking')

local M = {}

--- The spot a character that has no place yet is put on when its first step
--- names none.
local ENTRANCE = 'door'

--- How many steps an agent begins in one update; the rest it begins in the
--- updates after, so that an activity of steps that take no time cannot hold
--- the editor.
local MOST_STEPS_BEGUN_AN_UPDATE = 8

--- How many seconds an agent whose step's spots are all taken waits before it
--- looks again, and a performer whose activity is over waits before it looks
--- again for an activity it can pick.
local SECONDS_BETWEEN_LOOKS = 1

--- What a performer's activity is: the one its state asks for, one it
--- picked at random once that was over, or an interlude, which it plays
--- because of something that happened and after which it goes back to the one
--- its state asks for.
local WANTED, RANDOM, INTERLUDE = 'wanted', 'random', 'interlude'

---@class aineo.office_scene.Character
---@field id string the agent's id
---@field kind string 'agent' for the main agent, 'subagent' for the others
---@field place integer the agent's place among the agents, from 1, kept while it stays
---@field column number the cell column it is at, between cells while it walks
---@field row number the cell row its feet are at
---@field facing string 'left' or 'right'
---@field pose string the pose it holds
---@field pose_since number when it took the pose, on the stage's clock
---@field at_a_seat boolean whether it stands at a spot where characters sit
---@field effect? string the effect its step names, shown in place of its pose's

---@class aineo.office_scene.Performer : aineo.office_scene.Character
---@field state string the state of the agent it is, as of the last update
---@field state_changed boolean whether the state changed in the last update
---@field wanted_name? string the activity its state, or a trigger, asks for
---@field activity_name string
---@field activity table the activity it plays
---@field playing string `WANTED` when it plays the activity its state asks for, `RANDOM` when it plays one it picked at random, `INTERLUDE` when it plays one because of something that happened
---@field party? aineo.office_scene.Party the party it plays its activity in with others; none when it plays alone
---@field cleaning? aineo.office_scene.LyingThing the thing it has gone to clean up
---@field looks_for_life_at? number when a performer whose activity is over looks again for an activity to pick; none when it is not waiting for one
---@field step_index integer the step it is on
---@field step_seconds? number how long the step lasts from its arrival; none when it lasts until the activity changes
---@field arrived_at? number when it arrived for the step; none while it walks or waits
---@field spot? aineo.office_scene.Spot the spot it has taken
---@field path aineo.office_scene.Cell[] the cells it has still to walk over, the next first
---@field clock number the time the character has been brought up to
---@field steps_begun integer how many steps it has begun in this update
---@field looks_again_at? number when an agent waiting for a spot looks for one again; none when it is not waiting

---@class aineo.office_scene.Director
---@field update fun(agents: aineo.office_states.Agent[], now: number) brings the agents up to `now`, in the states they are in
---@field characters fun(): aineo.office_scene.Character[] the agents with a place on the plan, in the order they were given
---@field things fun(): aineo.office_scene.LyingThing[] what lies on the floor, the oldest first
---@field places fun(): table<string, integer> the place of every agent the director knows, by its id
---@field use_layout fun(layout: aineo.office_scene.FloorLayout) goes on in a new layout of the same plan: each agent keeps its activity and its step, at the spot of the same name and number

---@class aineo.office_scene.DirectorContext
---@field pack aineo.office_pack.Pack
---@field lives aineo.office_scene.Lives the activities picked at random
---@field things aineo.office_scene.Things what lies on the floor
---@field agents aineo.office_scene.Performer[] the agents' performers, in the order the agents were given
---@field layout aineo.office_scene.FloorLayout
---@field random fun(): number a number from 0 up to, not including, 1
---@field taken table<aineo.office_scene.Spot, string> the id of the character that has each spot taken
---@field places_taken table<integer, true> the places the agents the director knows have

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

--- Has the performer wait for a spot of its step: it keeps the spot it stands
--- on, and looks again after a while.
---
---@param performer aineo.office_scene.Performer
---@param time number
local function wait_for_a_spot(performer, time)
  performer.looks_again_at = time + SECONDS_BETWEEN_LOOKS
end

--- Starts the performer on its step once it has a place on the plan: draws
--- how long the step lasts, and has it walk to its spot or take the pose.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param step table
---@param time number
local function start_step(context, performer, step, time)
  local function draw()
    return seconds_of(step.for_seconds, context.random)
  end
  performer.step_seconds = performer.party
      and parties.seconds_of_step(performer.party, performer.step_index, draw)
    or draw()
  performer.effect = nil
  if #performer.path > 0 then
    performer.pose, performer.pose_since = walking.POSE, time
    performer.at_a_seat = false
  else
    arrive(performer, step, time)
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
  performer.steps_begun = performer.steps_begun + 1
  performer.step_index = index
  performer.step_seconds = nil
  performer.arrived_at = nil
  performer.looks_again_at = nil
  performer.path = {}
  local spot_name = step.at or (not performer.column and ENTRANCE) or nil
  local route, why
  if spot_name then
    route, why = spots.route(
      context.layout,
      named_spots.choose(context, spot_name, performer, step.even_if_taken),
      performer
    )
  end
  if route then
    take_route(context, performer, route)
  end
  if not performer.column then
    return
  end
  if spot_name and not route and why == spots.TAKEN then
    wait_for_a_spot(performer, time)
    return
  end
  start_step(context, performer, step, time)
end

--- Looks again for a spot of the step the performer waits for, when it is
--- time, and goes to it when there is one.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param now number
local function look_again(context, performer, now)
  if not (performer.looks_again_at and performer.looks_again_at <= now) then
    return
  end
  local step = performer.activity.steps[performer.step_index]
  local route = spots.route(
    context.layout,
    named_spots.choose(context, step.at, performer, step.even_if_taken),
    performer
  )
  if route then
    take_route(context, performer, route)
    performer.looks_again_at = nil
    start_step(context, performer, step, now)
  else
    wait_for_a_spot(performer, now)
  end
end

--- When the performer's step ended, if it has by `time`.
---
---@param performer aineo.office_scene.Performer
---@param time number
---@return number|nil ends_at nil when the step has not ended, or lasts until the activity changes
local function step_end_before(performer, time)
  if not (performer.arrived_at and performer.step_seconds) then
    return nil
  end
  local ends_at = performer.arrived_at + performer.step_seconds
  return ends_at <= time and ends_at or nil
end

--- Whether the performer is on the last step of its activity.
---
---@param performer aineo.office_scene.Performer
---@return boolean
local function is_on_last_step(performer)
  return performer.activity.steps[performer.step_index + 1] == nil
end

--- Has the performer play the activity `name` from `time`.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param name string
---@param how string `WANTED` or `RANDOM`
---@param time number
---@param party? aineo.office_scene.Party the party it plays with others in
local function play(context, performer, name, how, time, party)
  performer.activity_name, performer.activity = name, context.pack.activities[name]
  performer.playing = how
  performer.party = party
  performer.cleaning = nil
  performer.looks_for_life_at = nil
  performer.step_index = 1
  begin_step(context, performer, 1, time)
end

--- Has `other`, who is not the one whose update this is, play the activity
--- `name` from `time` on.
---
---@param context aineo.office_scene.DirectorContext
---@param other aineo.office_scene.Performer
---@param name string
---@param how string `RANDOM` or `INTERLUDE`
---@param time number
---@param party? aineo.office_scene.Party
local function make_play(context, other, name, how, time, party)
  other.clock = math.max(time, other.clock)
  play(context, other, name, how, other.clock, party)
end

--- Whether the performer is within `cells` cells of the cell `column`, `row`.
---
---@param performer aineo.office_scene.Performer
---@param column integer
---@param row integer
---@param cells integer
---@return boolean
local function is_within(performer, column, row, cells)
  local across, down = performer.column - column, performer.row - row
  return across * across + down * down <= cells * cells
end

--- Whether an agent has gone to clean up `thing`.
---
---@param thing aineo.office_scene.LyingThing
---@return boolean
local function has_a_cleaner(thing)
  return thing.cleaner ~= nil and thing.cleaner.cleaning == thing
end

--- Has the idle agent nearest to `thing` go to clean it up, if the pack says
--- what cleans it and an agent is idle; an agent that has only just become
--- idle is asked in the next update. Does nothing for a thing that has a
--- cleaner.
---
---@param context aineo.office_scene.DirectorContext
---@param thing aineo.office_scene.LyingThing
---@param time number
---@param busy? aineo.office_scene.Performer an agent in the middle of its update, who is not sent
local function send_cleaner_to(context, thing, time, busy)
  local activity_name = context.pack.things[thing.name].cleaned_up_by
  if not activity_name or has_a_cleaner(thing) then
    return
  end
  local nearest, nearest_distance = nil, math.huge
  for _, agent in ipairs(context.agents) do
    if
      agent ~= busy
      and agent.column
      and roles.is_idle(agent)
      and not agent.state_changed
      and agent.playing ~= INTERLUDE
    then
      local distance = math.abs(agent.column - thing.column) + math.abs(agent.row - thing.row)
      if distance < nearest_distance then
        nearest, nearest_distance = agent, distance
      end
    end
  end
  if nearest then
    make_play(context, nearest, activity_name, INTERLUDE, time)
    nearest.cleaning, thing.cleaner = thing, nearest
  end
end

--- Has the agents near a thing that has just been left play what upsets
--- them. The one who left it is not upset.
---
---@param context aineo.office_scene.DirectorContext
---@param thing aineo.office_scene.LyingThing
---@param leaver aineo.office_scene.Performer
---@param time number
local function upset_agents_near(context, thing, leaver, time)
  local definition = context.pack.things[thing.name]
  local activity_name = definition.upset_agents_play
  if not (activity_name and definition.upsets_agents_within) then
    return
  end
  for _, agent in ipairs(context.agents) do
    if
      agent ~= leaver
      and agent.column
      and agent.playing ~= INTERLUDE
      and is_within(agent, thing.column, thing.row, definition.upsets_agents_within)
    then
      make_play(context, agent, activity_name, INTERLUDE, time)
    end
  end
end

--- Does what the step does as it ends: removes the thing it removes from the
--- cell the performer stands on, and leaves its thing there, to the dismay of
--- the agents near it.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param step table
---@param time number
local function finish_step(context, performer, step, time)
  local column, row = math.floor(performer.column + 0.5), math.floor(performer.row + 0.5)
  if step.remove then
    context.things.remove_at(step.remove, column, row)
  end
  if step.leave and context.layout.is_walkable(column, row) then
    local thing = context.things.leave(step.leave, column, row)
    if thing then
      send_cleaner_to(context, thing, time, performer)
      upset_agents_near(context, thing, performer, time)
    end
  end
end

--- The characters that could join `performer` in `activity`: the others of
--- its kind, placed on the plan, in a state the activity names.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param activity table
---@return aineo.office_scene.Performer[]
local function possible_partners(context, performer, activity)
  return vim.tbl_filter(function(other)
    return other ~= performer
      and other.column ~= nil
      and vim.list_contains(activity.during, other.state)
  end, context.agents)
end

--- Whether the plan has the spots for `activity`: as many open spots as
--- players for its first step with a spot, and a spot for each step after.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param activity table
---@return boolean
local function has_the_spots_for(context, performer, activity)
  local needed = activity.players
  for _, step in ipairs(activity.steps) do
    if step.at then
      local choice = named_spots.availability(context, step.at, performer, step.even_if_taken)
      if choice.free < needed or not choice.any then
        return false
      end
      needed = 1
    end
  end
  return true
end

--- Whether the performer could play `activity` now: the plan has the spots
--- for it, and enough characters are free to play it together.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param activity table
---@return boolean
local function can_play(context, performer, activity)
  return has_the_spots_for(context, performer, activity)
    and #possible_partners(context, performer, activity) >= activity.players - 1
end

--- Has the performer, whose activity is over, go back to the activity its
--- state asks for when it played an interlude, or else play an activity
--- picked at random among those that name its state, and the characters it
--- plays with begin it too; when none can be picked, it keeps its last pose
--- and looks again after a while.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param time number
---@return boolean played whether a new activity began
local function start_next_activity(context, performer, time)
  local wanted = performer.wanted_name
  if performer.playing == INTERLUDE and wanted and context.pack.activities[wanted] then
    play(context, performer, wanted, WANTED, time)
    return true
  end
  local life = random_life.pick(
    context.lives.agents,
    performer.state,
    performer.activity_name,
    function(candidate)
      return can_play(context, performer, candidate.activity)
    end,
    context.random
  )
  if not life then
    performer.looks_for_life_at = time + SECONDS_BETWEEN_LOOKS
    return false
  end
  performer.looks_for_life_at = nil
  local partners = parties.draw(
    possible_partners(context, performer, life.activity),
    life.activity.players - 1,
    context.random
  ) or {}
  local party = #partners > 0 and parties.new_party() or nil
  play(context, performer, life.name, RANDOM, time, party)
  for _, partner in ipairs(partners) do
    make_play(context, partner, life.name, RANDOM, time, party)
  end
  return true
end

--- Brings the performer up to `now`: walks it, and goes on to the next step,
--- or the next activity, whenever a step ends on the way.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param now number
local function bring_up_to(context, performer, now)
  if not performer.column then
    begin_step(context, performer, performer.step_index, now)
  end
  look_again(context, performer, now)
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
    if not ends_at or performer.steps_begun >= MOST_STEPS_BEGUN_AN_UPDATE then
      break
    end
    if not is_on_last_step(performer) then
      clock = ends_at
      finish_step(context, performer, performer.activity.steps[performer.step_index], clock)
      begin_step(context, performer, performer.step_index + 1, clock)
    elseif performer.looks_for_life_at and performer.looks_for_life_at > now then
      break
    else
      local looked_before = performer.looks_for_life_at ~= nil
      if not looked_before then
        finish_step(context, performer, performer.activity.steps[performer.step_index], ends_at)
      end
      local started_at = looked_before and now or ends_at
      if not start_next_activity(context, performer, started_at) then
        break
      end
      clock = started_at
    end
  end
  performer.clock = now
end

--- The lowest place no agent has.
---
---@param context aineo.office_scene.DirectorContext
---@return integer
local function lowest_free_place(context)
  local place = 1
  while context.places_taken[place] do
    place = place + 1
  end
  return place
end

--- A performer for `agent` that has no activity and no position yet, in the
--- lowest place no agent has.
---
---@param context aineo.office_scene.DirectorContext
---@param agent aineo.office_states.Agent
---@param now number
---@return aineo.office_scene.Performer
local function new_performer(context, agent, now)
  local place = lowest_free_place(context)
  context.places_taken[place] = true
  return {
    id = agent.id,
    kind = roles.kind_of(agent),
    place = place,
    clock = now,
    path = {},
    step_index = 1,
    steps_begun = 0,
  }
end

--- Puts the performer in a new layout of the same plan: at the spot of the
--- same name and number when the plan has it, walking there on from where it
--- is; on its cell when it had no spot and the cell can be walked on;
--- otherwise without a position, to find one again.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
local function move_into_layout(context, performer)
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

--- A director of the agents of `pack`'s office, laid out as `layout`.
---
---@param pack aineo.office_pack.Pack
---@param layout aineo.office_scene.FloorLayout
---@param random fun(): number the source of the random times of steps
---@return aineo.office_scene.Director
function M.new_director(pack, layout, random)
  ---@type aineo.office_scene.DirectorContext
  local context = {
    pack = pack,
    lives = random_life.index(pack),
    agents = {},
    things = things.new_register(pack.things),
    layout = layout,
    random = random,
    taken = {},
    places_taken = {},
  }
  ---@type table<string, aineo.office_scene.Performer>
  local known = {}
  ---@type aineo.office_scene.Performer[]
  local placed = {}

  local director = {}

  function director.update(agents, now)
    local present = {}
    context.agents = {}
    for _, agent in ipairs(agents) do
      local performer = known[agent.id] or new_performer(context, agent, now)
      known[agent.id] = performer
      performer.steps_begun = 0
      performer.state_changed = performer.state ~= nil and performer.state ~= agent.state
      performer.state = agent.state
      present[agent.id] = true
      table.insert(context.agents, performer)
    end
    placed = {}
    for index, agent in ipairs(agents) do
      local performer = context.agents[index]
      local name, activity = roles.activity_of(pack, agent)
      if
        activity
        and (
          performer.wanted_name ~= name or (performer.state_changed and performer.playing ~= WANTED)
        )
      then
        performer.wanted_name = name
        play(context, performer, name, WANTED, performer.clock)
      end
      if performer.activity then
        bring_up_to(context, performer, now)
      end
      if performer.column then
        table.insert(placed, performer)
      end
    end
    for _, thing in ipairs(context.things.all()) do
      send_cleaner_to(context, thing, now)
    end
    for id, performer in pairs(known) do
      if not present[id] then
        let_go_of_spot(context, performer)
        performer.cleaning = nil
        context.places_taken[performer.place] = nil
        known[id] = nil
      end
    end
  end

  function director.characters()
    return placed
  end

  function director.things()
    return context.things.all()
  end

  function director.places()
    local places = {}
    for id, performer in pairs(known) do
      places[id] = performer.place
    end
    return places
  end

  function director.use_layout(new_layout)
    context.layout = new_layout
    context.taken = {}
    for _, performer in pairs(known) do
      move_into_layout(context, performer)
    end
    placed = vim.tbl_filter(function(performer)
      return performer.column ~= nil
    end, placed)
    context.things.keep_on(new_layout.is_walkable)
  end

  return director
end

return M
