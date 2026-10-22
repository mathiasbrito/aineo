--- A pack's description, `pack.lua` as data, turned into the fields a loaded
--- pack has: defaults filled in, a pose taking what it is like from the pose
--- it names, and each state given the activity of the first state it falls
--- back through that the pack maps.

local office_states = require('aineo.office_states')

local M = {}

--- The colours of the office's text by role, when a pack names none.
local DEFAULT_TEXT_COLOURS = {
  name = '#a6adc8',
  status = '#cdd6f4',
  thought = '#b4befe',
  warning = '#f9e2af',
}

--- The colours an agent takes when a pack gives it none: one grey.
local DEFAULT_AGENT_COLOURS = { '#a6adc8' }

--- What an effect is when its pack leaves a field out.
local EFFECT_DEFAULTS =
  { colour = 'status', place = 'above', seconds_per_frame = 0.25, bold = false }

--- A pose of a character: the art it is drawn with and how it is held.
---@class aineo.office_pack.Pose
---@field art string[] the pieces drawn for it, bottom first
---@field sitting? boolean
---@field effect? string the effect it shows while held

--- An effect: text a character shows.
---@class aineo.office_pack.Effect
---@field text string[] its frames
---@field colour string a role of the office's text, or a colour as `#rrggbb`
---@field place string
---@field seconds_per_frame number
---@field bold boolean

--- The table `value` when it is one, else an empty table.
---
---@param value any
---@return table
local function table_or_empty(value)
  if type(value) == 'table' then
    return value
  end
  return {}
end

--- The pose `name` of `poses`, with the fields of the poses it is like taken
--- unless it gives its own.
---
---@param poses table<string, table>
---@param name string
---@param seen table<string, true> the poses being resolved, to refuse a pose that is like itself
---@return table|nil pose
---@return string|nil problem
local function resolve_pose(poses, name, seen)
  local pose = poses[name]
  if type(pose) ~= 'table' then
    return nil, ('the pose “%s” is not described'):format(name)
  end
  if seen[name] then
    return nil, ('the pose “%s” is like itself'):format(name)
  end
  if not pose.like then
    return vim.deepcopy(pose)
  end
  seen[name] = true
  local base, problem = resolve_pose(poses, pose.like, seen)
  if not base then
    return nil, problem
  end
  local resolved = vim.tbl_extend('force', base, pose)
  resolved.like = nil
  return resolved
end

--- Every pose of `poses`, resolved.
---
---@param poses table<string, table>
---@return table<string, aineo.office_pack.Pose>|nil resolved
---@return string|nil problem
function M.resolve_poses(poses)
  local resolved = {}
  for name in pairs(poses) do
    local pose, problem = resolve_pose(poses, name, {})
    if not pose then
      return nil, problem
    end
    resolved[name] = pose
  end
  return resolved
end

--- The effects of `effects` with the defaults of what a pack leaves out.
---
---@param effects table<string, table>
---@return table<string, aineo.office_pack.Effect>
function M.fill_effects(effects)
  local filled = {}
  for name, effect in pairs(effects) do
    filled[name] = vim.tbl_extend('keep', effect, EFFECT_DEFAULTS)
  end
  return filled
end

--- The colours of the office's text by role: the pack's, and the defaults for
--- the roles it names none for.
---
---@param text_colours table
---@return table<string, string>
function M.fill_text_colours(text_colours)
  return vim.tbl_extend('keep', table_or_empty(text_colours), DEFAULT_TEXT_COLOURS)
end

--- The colours an agent takes, one per agent in turn.
---
---@param colours any
---@return string[]
function M.agent_colours(colours)
  if type(colours) == 'table' and #colours > 0 then
    return colours
  end
  return vim.deepcopy(DEFAULT_AGENT_COLOURS)
end

--- The activity each state of the vocabulary plays: the activity the pack's
--- `states` map to it, or to the first state it falls back to that they map.
---
--- `nil` and the problem when the pack maps nothing to `standing`, which
--- every state falls back to in the end.
---
---@param states table<string, string>
---@return table<string, string>|nil state_activity
---@return string|nil problem
function M.state_activities(states)
  local state_activity = {}
  for _, state in ipairs(office_states.vocabulary()) do
    for _, name in ipairs(office_states.fallback_chain(state.name)) do
      if states[name] then
        state_activity[state.name] = states[name]
        break
      end
    end
  end
  if not state_activity.standing then
    return nil, 'states must give standing an activity'
  end
  return state_activity
end

return M
