--- What a thing on the floor does to the agents: the ones near it are
--- upset, and the nearest idle one cleans it up. Both are interludes the
--- caller has the agent play.

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

--- Has the idle agent nearest to `thing` go to clean it up, if the pack says
--- what cleans it and an agent is idle; an agent that has only just become
--- idle is asked in the next update. Does nothing for a thing that has a
--- cleaner.
---
---@param context aineo.office_scene.DirectorContext
---@param thing aineo.office_scene.LyingThing
---@param time number
---@param busy? aineo.office_scene.Performer an agent in the middle of its update, who is not sent
---@param make_play aineo.office_scene.MakePlay has an agent play an interlude
function M.send_cleaner_to(context, thing, time, busy, make_play)
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
