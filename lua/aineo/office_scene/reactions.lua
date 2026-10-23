--- What a thing on the floor does to the agents: the ones near it are
--- upset, and the nearest idle one, or else the nearest other one, cleans it
--- up. Both are interludes the caller has the agent play.

local paths = require('aineo.office_scene.paths')
local performers = require('aineo.office_scene.performers')
local roles = require('aineo.office_scene.roles')

local M = {}

local INTERLUDE = performers.INTERLUDE

---@alias aineo.office_scene.MakePlay fun(context: aineo.office_scene.DirectorContext, other: aineo.office_scene.Performer, name: string, how: string, time: number, party?: aineo.office_scene.Party)

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

--- Whether `agent` can walk to `thing`. The cells that can be walked to from
--- a thing are found once for each layout the thing lies in, and kept with it.
---
---@param context aineo.office_scene.DirectorContext
---@param thing aineo.office_scene.LyingThing
---@param agent aineo.office_scene.Performer
---@return boolean
local function can_walk_to(context, thing, agent)
  local layout = context.layout
  if not (thing.reach and thing.reach.layout == layout) then
    thing.reach = { layout = layout, cells = paths.cells_reachable_from(layout, thing) }
  end
  local key = math.floor(agent.row + 0.5) * layout.width + math.floor(agent.column + 0.5)
  return thing.reach.cells[key] == true
end

--- Whether `agent` can be sent to `thing`: it has a place on the plan, is not
--- in the middle of an interlude or of the update that sends it, and can
--- walk to the thing.
---
---@param context aineo.office_scene.DirectorContext
---@param thing aineo.office_scene.LyingThing
---@param agent aineo.office_scene.Performer
---@param busy? aineo.office_scene.Performer
---@return boolean
local function can_be_sent_to(context, thing, agent, busy)
  return agent ~= busy
    and agent.column ~= nil
    and agent.playing ~= INTERLUDE
    and can_walk_to(context, thing, agent)
end

--- The agent nearest to `thing` among those `is_wanted` accepts that can be
--- sent to it.
---
---@param context aineo.office_scene.DirectorContext
---@param thing aineo.office_scene.LyingThing
---@param busy? aineo.office_scene.Performer
---@param is_wanted fun(agent: aineo.office_scene.Performer): boolean
---@return aineo.office_scene.Performer|nil
local function nearest_agent_to(context, thing, busy, is_wanted)
  local nearest, nearest_distance = nil, math.huge
  for _, agent in ipairs(context.agents) do
    if is_wanted(agent) and can_be_sent_to(context, thing, agent, busy) then
      local distance = math.abs(agent.column - thing.column) + math.abs(agent.row - thing.row)
      if distance < nearest_distance then
        nearest, nearest_distance = agent, distance
      end
    end
  end
  return nearest
end

--- Whether `thing` still lies on the floor.
---
---@param context aineo.office_scene.DirectorContext
---@param thing aineo.office_scene.LyingThing
---@return boolean
local function is_lying(context, thing)
  return vim.list_contains(context.things.all(), thing)
end

--- Has the agent nearest to `thing` that can walk to it go to clean it up, if
--- the pack says what cleans it: the nearest idle agent, or, when no idle
--- agent can, the nearest agent that is in the office and busy with its state's
--- activity. The agent first plays what the thing upsets agents with, when the
--- pack says so, then what cleans it (`begin_cleaning_after_upset`). A thing
--- no agent can walk to stays where it lies. Does nothing for a thing that
--- has a cleaner.
---
---@param context aineo.office_scene.DirectorContext
---@param thing aineo.office_scene.LyingThing
---@param time number
---@param busy? aineo.office_scene.Performer an agent in the middle of its update, who is not sent
---@param make_play aineo.office_scene.MakePlay has an agent play an interlude
function M.send_cleaner_to(context, thing, time, busy, make_play)
  local definition = context.pack.things[thing.name]
  if not definition.cleaned_up_by or has_a_cleaner(thing) then
    return
  end
  local cleaner = nearest_agent_to(context, thing, busy, roles.is_idle)
    or nearest_agent_to(context, thing, busy, roles.is_settled_in)
  if not cleaner then
    return
  end
  local upset_play = definition.upset_agents_play
  make_play(context, cleaner, upset_play or definition.cleaned_up_by, INTERLUDE, time)
  cleaner.cleaning, thing.cleaner = thing, cleaner
end

--- Has `agent`, who has gone to clean a thing up and has just played what the
--- thing upsets agents with, go on to clean it. Does nothing for any other
--- agent, or when the thing is gone.
---
---@param context aineo.office_scene.DirectorContext
---@param agent aineo.office_scene.Performer
---@param time number
---@param play aineo.office_scene.MakePlay has the agent play an interlude
---@return boolean began whether the agent began to clean
function M.begin_cleaning_after_upset(context, agent, time, play)
  local thing = agent.cleaning
  if not (thing and is_lying(context, thing)) then
    return false
  end
  local definition = context.pack.things[thing.name]
  if not (definition.upset_agents_play and agent.activity_name == definition.upset_agents_play) then
    return false
  end
  play(context, agent, definition.cleaned_up_by, INTERLUDE, time)
  agent.cleaning = thing
  return true
end

--- Has the agents near a thing that has just been left play what upsets
--- them. The one who left it is not upset.
---
---@param context aineo.office_scene.DirectorContext
---@param thing aineo.office_scene.LyingThing
---@param leaver aineo.office_scene.Performer
---@param time number
---@param make_play aineo.office_scene.MakePlay has an agent play an interlude
function M.upset_agents_near(context, thing, leaver, time, make_play)
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

return M
