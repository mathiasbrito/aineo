--- The performers of the office: the agents and the cats, each a character
--- the director moves, with what it is doing.

local random_life = require('aineo.office_scene.random_life')
local roles = require('aineo.office_scene.roles')

local M = {}

--- The kind of the cat.
M.CAT = 'cat'

--- What a performer's activity is: the one its state asks for, one it
--- picked at random once that was over, or an interlude, which it plays
--- because of something that happened and after which it goes back to the one
--- its state asks for.
M.WANTED, M.RANDOM, M.INTERLUDE = 'wanted', 'random', 'interlude'

--- How many cats there are at most, whatever the pack asks for.
local MOST_CATS = 4

---@class aineo.office_scene.Character
---@field id string the agent's id
---@field kind string 'agent' for the main agent, 'subagent' for the others
---@field place? integer the agent's place among the agents, from 1, kept while it stays; none for the cat
---@field colour_index integer which of its kind's colours it takes: its place for an agent, its number for a cat
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
---@field following? aineo.office_scene.Performer the character on the move it follows, until its step is over
---@field displaces? string the id of the character that has the spot it is going to, which it takes from it on arriving
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
---@field stands_aside? boolean whether it has stepped aside beside a desk, standing, its step's desk taken back by its owner, until it finds a desk again or begins another step

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
function M.new_agent(context, agent, now)
  local place = lowest_free_place(context)
  context.places_taken[place] = true
  return {
    id = agent.id,
    kind = roles.kind_of(agent),
    place = place,
    colour_index = place,
    clock = now,
    path = {},
    step_index = 1,
    steps_begun = 0,
  }
end

--- The cats of the office, a performer for each: as many as the pack says,
--- and none when it draws no cat or has no activity for one.
---
---@param context aineo.office_scene.DirectorContext
---@param now number
---@return aineo.office_scene.Performer[]
function M.new_cats(context, now)
  local cats = {}
  local looks = context.pack.cat
  if not looks or #context.lives.cat == 0 then
    return cats
  end
  for number = 1, math.min(looks.how_many, MOST_CATS) do
    cats[number] = {
      id = M.CAT .. number,
      kind = M.CAT,
      colour_index = number,
      state = random_life.ALWAYS,
      playing = M.RANDOM,
      clock = now,
      path = {},
      step_index = 1,
      steps_begun = 0,
    }
  end
  return cats
end

return M
