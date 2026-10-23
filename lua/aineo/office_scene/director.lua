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

local durations = require('aineo.office_scene.durations')
local following = require('aineo.office_scene.following')
local holding = require('aineo.office_scene.holding')
local named_spots = require('aineo.office_scene.named_spots')
local next_activity = require('aineo.office_scene.next_activity')
local parties = require('aineo.office_scene.parties')
local performers = require('aineo.office_scene.performers')
local random_life = require('aineo.office_scene.random_life')
local reactions = require('aineo.office_scene.reactions')
local relocation = require('aineo.office_scene.relocation')
local roles = require('aineo.office_scene.roles')
local spots = require('aineo.office_scene.spots')
local things = require('aineo.office_scene.things')
local walking = require('aineo.office_scene.walking')

local M = {}

--- The spot a character that has no place yet is put on when its first step
--- names none.
local ENTRANCE = named_spots.ENTRANCE

--- How many steps an agent begins in one update; the rest it begins in the
--- updates after, so that an activity of steps that take no time cannot hold
--- the editor.
local MOST_STEPS_BEGUN_AN_UPDATE = 8

--- How many characters can move one another off their spots in a row, a
--- character that takes a spot moving the one on it, who takes another spot
--- and moves the one on that, and so on; the chain stops there, so that
--- characters whose steps take each other's spots cannot move for ever.
local MOST_MOVED_IN_A_ROW = 4

--- How many seconds an agent whose step's spots are all taken waits before it
--- looks again, and a performer whose activity is over waits before it looks
--- again for an activity it can pick.
local SECONDS_BETWEEN_LOOKS = 1

local WANTED, RANDOM, INTERLUDE = performers.WANTED, performers.RANDOM, performers.INTERLUDE

---@class aineo.office_scene.Director
---@field update fun(agents: aineo.office_states.Agent[], now: number) brings the agents up to `now`, in the states they are in
---@field characters fun(): aineo.office_scene.Character[] the agents with a place on the plan, in the order they were given
---@field things fun(): aineo.office_scene.LyingThing[] what lies on the floor, the oldest first
---@field activities_played fun(): table<string, table> the activity each agent plays now, by its id
---@field places fun(): table<string, integer> the place of every agent the director knows, by its id
---@field use_layout fun(layout: aineo.office_scene.FloorLayout) goes on in a new layout of the same plan: each agent keeps its activity and its step, at the spot of the same name and number, the agents taken in the order they were given so that a random source draws for them in that order

---@class aineo.office_scene.DirectorContext
---@field pack aineo.office_pack.Pack
---@field lives aineo.office_scene.Lives the activities picked at random
---@field things aineo.office_scene.Things what lies on the floor
---@field agents aineo.office_scene.Performer[] the agents' performers, in the order the agents were given
---@field by_id table<string, aineo.office_scene.Performer> every performer, by its id
---@field moved_in_a_row integer how many characters are being moved off their spots, one by another, at this moment
---@field cats aineo.office_scene.Performer[] the cats' performers, none until the office has been advanced
---@field layout aineo.office_scene.FloorLayout
---@field random fun(): number a number from 0 up to, not including, 1
---@field taken table<aineo.office_scene.Spot, string> the id of the character that has each spot taken
---@field places_taken table<integer, true> the places the agents the director knows have

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

--- Has the performer wait for a spot of its step: it keeps the spot it stands
--- on, and looks again after a while.
---
---@param performer aineo.office_scene.Performer
---@param time number
local function wait_for_a_spot(performer, time)
  performer.looks_again_at = time + SECONDS_BETWEEN_LOOKS
end

local settle_at_spot

--- Starts the performer on its step once it has a place on the plan: draws
--- how long the step lasts, and has it walk to its spot or take the pose.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param step table
---@param time number
local function start_step(context, performer, step, time)
  local function draw()
    return durations.seconds_of(step.for_seconds, context.random)
  end
  performer.step_seconds = performer.party
      and parties.seconds_of_step(performer.party, performer.step_index, draw)
    or draw()
  performer.effect = nil
  if #performer.path > 0 then
    performer.pose, performer.pose_since = walking.POSE, time
    performer.at_a_seat = false
  else
    settle_at_spot(context, performer, step, time)
  end
end

--- The way to a spot named `spot_name` for the performer: to the spot of the
--- name nearest by walking; or, when the plan has no such spot that can be
--- walked to, or the other characters have them all, and the performer has no
--- place yet, to a free floor cell, so that a character is drawn in a room too
--- small to hold the spot or its agents. A performer that has a place keeps it.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param spot_name string
---@param even_if_taken boolean|nil
---@return aineo.office_scene.Route|nil route
---@return string|nil why
local function route_to_spot(context, performer, spot_name, even_if_taken)
  local route, why = spots.route(
    context.layout,
    named_spots.choose(context, spot_name, performer, even_if_taken),
    performer
  )
  if route or performer.column then
    return route, why
  end
  return spots.route(context.layout, named_spots.choose_free_floor_cell(context), performer)
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
  performer.following = nil
  if following.is_followed_by(step) and performer.column then
    following.start(context, performer, step, time)
    return
  end
  local spot_name = step.at or (not performer.column and ENTRANCE) or nil
  local route, why
  if spot_name then
    route, why = route_to_spot(context, performer, spot_name, step.even_if_taken)
  end
  if route then
    holding.take_route(context, performer, route)
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
--- time, and goes to it when there is one; when the spots of the name are
--- gone, the step goes on where the performer stands.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param now number
local function look_again(context, performer, now)
  if not (performer.looks_again_at and performer.looks_again_at <= now) then
    return
  end
  local step = performer.activity.steps[performer.step_index]
  local route, why = spots.route(
    context.layout,
    named_spots.choose(context, step.at, performer, step.even_if_taken),
    performer
  )
  if route then
    holding.take_route(context, performer, route)
  elseif why == spots.TAKEN then
    wait_for_a_spot(performer, now)
    return
  end
  performer.looks_again_at = nil
  start_step(context, performer, step, now)
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
---@param party? aineo.office_scene.Party the party it plays with others in; the performer's own, if it has one, is broken: its other players stop
local function play(context, performer, name, how, time, party)
  if performer.party and performer.party ~= party then
    performer.party.broken = true
  end
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

--- Does what the step does as it ends: removes the thing it removes from the
--- cell the performer stands on, and leaves its thing there, to the dismay of
--- the agents near it.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param step table
---@param time number
local function finish_step(context, performer, step, time)
  if performer.following then
    performer.following, performer.path = nil, {}
    arrive(performer, step, time)
  end
  local column, row = math.floor(performer.column + 0.5), math.floor(performer.row + 0.5)
  if step.remove then
    context.things.remove_at(step.remove, column, row)
  end
  if step.leave then
    local thing = context.things.leave(step.leave, column, row)
    if thing then
      reactions.send_cleaner_to(context, thing, time, performer, make_play)
      reactions.upset_agents_near(context, thing, performer, time, make_play)
    end
  end
end

--- Has the performer take the pose of `step` at the spot it has come to; if it
--- took the spot from a character that was on it, that one is moved: it plays
--- what the step says, or looks for another spot and, finding none, has its
--- step over at once. A chain of characters that move one another stops after
--- `MOST_MOVED_IN_A_ROW`: the last is left where it stands.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param step table
---@param time number
function settle_at_spot(context, performer, step, time)
  arrive(performer, step, time)
  local occupant = performer.displaces and context.by_id[performer.displaces]
  performer.displaces = nil
  if not (occupant and occupant.spot == performer.spot) then
    return
  end
  occupant.spot = nil
  if context.moved_in_a_row >= MOST_MOVED_IN_A_ROW then
    return
  end
  context.moved_in_a_row = context.moved_in_a_row + 1
  local activity_name = step.the_one_moved_plays
  if activity_name and context.pack.activities[activity_name] then
    make_play(context, occupant, activity_name, INTERLUDE, time)
  else
    local since = math.max(time, occupant.clock)
    begin_step(context, occupant, occupant.step_index, since)
    if occupant.spot == nil and occupant.column then
      occupant.looks_again_at = nil
      occupant.arrived_at, occupant.step_seconds = since, 0
    end
  end
  context.moved_in_a_row = context.moved_in_a_row - 1
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
  local life, partners = next_activity.choose(context, performer)
  if not life then
    performer.looks_for_life_at = time + SECONDS_BETWEEN_LOOKS
    return false
  end
  performer.looks_for_life_at = nil
  local party = #partners > 0 and parties.new_party() or nil
  play(context, performer, life.name, RANDOM, time, party)
  for _, partner in ipairs(partners) do
    make_play(context, partner, life.name, RANDOM, time, party)
  end
  return true
end

--- Brings the performer up to `now`: ends the game it plays when a player has
--- left it, walks it, and goes on to the next step, or the next activity,
--- whenever a step ends on the way.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param now number
local function bring_up_to(context, performer, now)
  if performer.party and performer.party.broken then
    performer.party = nil
    if not start_next_activity(context, performer, performer.clock) and performer.wanted_name then
      play(context, performer, performer.wanted_name, WANTED, performer.clock)
    end
  end
  if not performer.column then
    begin_step(context, performer, performer.step_index, now)
  end
  look_again(context, performer, now)
  following.chase(context, performer)
  local clock = performer.clock
  while performer.column do
    if #performer.path > 0 then
      clock = clock + walking.advance(performer, now - clock)
      if #performer.path > 0 and not performer.following then
        break
      end
      if #performer.path == 0 and not performer.following then
        settle_at_spot(context, performer, performer.activity.steps[performer.step_index], clock)
      end
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

--- Has a performer that a new layout left on its way to a spot the layout
--- does not have begin its step again where it stands.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
local function resume_step(context, performer)
  local lost_its_way = performer.activity
    and performer.column
    and #performer.path == 0
    and performer.arrived_at == nil
    and performer.looks_again_at == nil
  if lost_its_way then
    begin_step(context, performer, performer.step_index, performer.clock)
  end
end

--- Whether an agent has gone beside `cat`, or is on its way, and its step is
--- not over at `now`.
---
---@param context aineo.office_scene.DirectorContext
---@param cat aineo.office_scene.Performer
---@param now number
---@return boolean
local function is_visited(context, cat, now)
  return vim.iter(context.agents):any(function(agent)
    return agent.spot ~= nil and agent.spot.beside == cat.id and step_end_before(agent, now) == nil
  end)
end

--- Has the cat keep its pose and its place up to `now`; the time its step has
--- left, and the time it waits before it looks for an activity, are not used
--- up meanwhile.
---
---@param cat aineo.office_scene.Performer
---@param now number
local function hold_still(cat, now)
  local held_for = now - cat.clock
  cat.arrived_at = cat.arrived_at and cat.arrived_at + held_for
  cat.looks_for_life_at = cat.looks_for_life_at and cat.looks_for_life_at + held_for
  cat.clock = now
end

--- Brings the cat up to `now`: it picks the activity of its life when it has
--- none, and plays it; while an agent is beside it, or on its way to be, it
--- holds still.
---
---@param context aineo.office_scene.DirectorContext
---@param cat aineo.office_scene.Performer
---@param now number
local function bring_cat_up_to(context, cat, now)
  cat.steps_begun = 0
  if is_visited(context, cat, now) then
    hold_still(cat, now)
    return
  end
  local waiting = cat.looks_for_life_at ~= nil and cat.looks_for_life_at > now
  if not cat.activity and not waiting then
    start_next_activity(context, cat, now)
  end
  if cat.activity then
    bring_up_to(context, cat, now)
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
    cats = {},
    by_id = {},
    moved_in_a_row = 0,
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
  local cats_arrived = false

  local director = {}

  function director.update(agents, now)
    context.moved_in_a_row = 0
    local present = {}
    context.agents = {}
    for _, agent in ipairs(agents) do
      local performer = known[agent.id] or performers.new_agent(context, agent, now)
      known[agent.id] = performer
      context.by_id[agent.id] = performer
      performer.steps_begun = 0
      performer.state_changed = performer.state ~= nil and performer.state ~= agent.state
      performer.state = agent.state
      present[agent.id] = true
      table.insert(context.agents, performer)
    end
    if not cats_arrived then
      context.cats = performers.new_cats(context, now)
      for _, cat in ipairs(context.cats) do
        context.by_id[cat.id] = cat
      end
      cats_arrived = true
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
    for _, cat in ipairs(context.cats) do
      bring_cat_up_to(context, cat, now)
      if cat.column then
        table.insert(placed, cat)
      end
    end
    for _, thing in ipairs(context.things.all()) do
      reactions.send_cleaner_to(context, thing, now, nil, make_play)
    end
    for id, performer in pairs(known) do
      if not present[id] then
        if performer.party then
          performer.party.broken = true
        end
        holding.let_go_of_spot(context, performer)
        performer.cleaning = nil
        context.by_id[id] = nil
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

  function director.activities_played()
    local played = {}
    for id, performer in pairs(known) do
      played[id] = performer.activity
    end
    return played
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
    for _, performer in ipairs(context.agents) do
      relocation.move_into_layout(context, performer)
      resume_step(context, performer)
    end
    for _, cat in ipairs(context.cats) do
      relocation.move_into_layout(context, cat)
      resume_step(context, cat)
    end
    placed = vim.tbl_filter(function(performer)
      return performer.column ~= nil
    end, placed)
    context.things.keep_on(new_layout.is_walkable)
  end

  return director
end

return M
