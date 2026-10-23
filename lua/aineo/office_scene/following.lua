--- A character that follows another on the move: the cat that trails
--- someone walking.

local durations = require('aineo.office_scene.durations')
local holding = require('aineo.office_scene.holding')
local paths = require('aineo.office_scene.paths')
local walking = require('aineo.office_scene.walking')

local M = {}

--- The only thing a step's `follow` can name: the nearest character on the
--- move.
M.SOMEONE_WALKING = 'someone_walking'

--- Whether `step` has its character follow someone on the move.
---
---@param step table
---@return boolean
function M.is_followed_by(step)
  return step.follow == M.SOMEONE_WALKING
end

--- The character on the move that is nearest to `performer`, other than it.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@return aineo.office_scene.Performer|nil
function M.nearest_walker(context, performer)
  local nearest, nearest_distance = nil, math.huge
  for _, group in ipairs({ context.agents, context.cats }) do
    for _, other in ipairs(group) do
      if other ~= performer and other.column and #other.path > 0 then
        local distance = math.abs(other.column - performer.column)
          + math.abs(other.row - performer.row)
        if distance < nearest_distance then
          nearest, nearest_distance = other, distance
        end
      end
    end
  end
  return nearest
end

--- Has the performer follow the nearest character on the move for the time
--- of `step`; a performer with no one to follow has the step over at once.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
---@param step table
---@param time number
function M.start(context, performer, step, time)
  holding.let_go_of_spot(context, performer)
  local target = M.nearest_walker(context, performer)
  performer.following = target
  performer.step_seconds = target and durations.seconds_of(step.for_seconds, context.random) or 0
  performer.arrived_at = time
  performer.effect = nil
  performer.pose, performer.pose_since = walking.POSE, time
  performer.at_a_seat = false
end

--- Has the performer that follows a character go the way to where it is now;
--- when that one has stopped or is gone, the performer's step is over.
---
---@param context aineo.office_scene.DirectorContext
---@param performer aineo.office_scene.Performer
function M.chase(context, performer)
  local target = performer.following
  if not target then
    return
  end
  if context.by_id[target.id] ~= target or #target.path == 0 then
    performer.path = {}
    performer.arrived_at, performer.step_seconds = performer.clock, 0
    return
  end
  local route = paths.nearest(context.layout, {
    column = math.floor(performer.column + 0.5),
    row = math.floor(performer.row + 0.5),
  }, { { column = math.floor(target.column + 0.5), row = math.floor(target.row + 0.5) } })
  performer.path = route and route.path or {}
end

return M
