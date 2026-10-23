--- What a performer whose activity is over plays next, picked at random:
--- the activity, and the characters that play it with it.

local following = require('aineo.office_scene.following')
local named_spots = require('aineo.office_scene.named_spots')
local parties = require('aineo.office_scene.parties')
local performers = require('aineo.office_scene.performers')
local random_life = require('aineo.office_scene.random_life')

local M = {}

--- The characters that could join `performer` in `activity`: the other
--- agents, or the other cats, placed on the plan, in a state the activity
--- names.
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
      and other.playing ~= performers.INTERLUDE
      and other.activity ~= activity
      and (other.party == nil or other.looks_for_life_at ~= nil)
  end, performer.kind == performers.CAT and context.cats or context.agents)
end

--- Whether the plan has the spots for `activity`: as many open spots as
--- players for its first step with a spot, and a spot for each step after;
--- and, for a step that follows someone, someone on the move.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param activity table
---@return boolean
local function has_the_spots_for(context, performer, activity)
  local needed = activity.players
  for _, step in ipairs(activity.steps) do
    if following.is_followed_by(step) and not following.nearest_walker(context, performer) then
      return false
    end
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

--- The activity `performer`, whose activity is over, plays next, and the
--- characters that play it with it: picked at random among those that name
--- its state, other than the one it played last, that it can play now.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@return aineo.office_scene.Life|nil life nil when none can be picked
---@return aineo.office_scene.Performer[]|nil partners
function M.choose(context, performer)
  local life = random_life.pick(
    performer.kind == performers.CAT and context.lives.cat or context.lives.agents,
    performer.state,
    performer.activity_name,
    function(candidate)
      return can_play(context, performer, candidate.activity)
    end,
    context.random
  )
  if not life then
    return nil, nil
  end
  local partners = parties.draw(
    possible_partners(context, performer, life.activity),
    life.activity.players - 1,
    context.random
  )
  return life, partners or {}
end

return M
