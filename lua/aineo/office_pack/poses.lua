--- The poses of a character: a pose that is like another takes the fields of
--- the pose it is like, unless it gives its own, along a chain of poses of
--- bounded length.

local entries = require('aineo.office_pack.entries')

local M = {}

--- A pose of a character: the art it is drawn with and how it is held.
---@class aineo.office_pack.Pose
---@field art string[] the pieces drawn for it, bottom first
---@field sitting boolean whether it is drawn seated: its feet hidden behind what stands in front
---@field effect? string the effect it shows while held
---@field screen? string the piece the character's own monitor shows while it holds the pose
---@field holding? string a prop drawn at the art's `hand` area
---@field rises? number[] pixels it rises by, one number per frame

--- How many poses a pose may be like, one after another: a pose like a pose
--- like a pose, and so on.
local MAX_LIKE_CHAIN = 8

--- The poses `name` is like, from the pose itself to the one that is like none.
---
--- `nil` and what is wrong when a pose of the chain is not described, is
--- like itself through the chain, or the chain is longer than
--- `MAX_LIKE_CHAIN` poses beyond the first.
---
---@param poses table<string, table>
---@param name string
---@return table[]|nil chain
---@return string|nil problem
local function like_chain(poses, name)
  local chain = {}
  local seen = {}
  local current = name
  while current do
    local pose = poses[current]
    if type(pose) ~= 'table' then
      return nil, ('is like “%s”, which the pack does not describe'):format(current)
    end
    if seen[current] then
      return nil, 'is like itself'
    end
    if #chain > MAX_LIKE_CHAIN then
      return nil, ('is like a chain of more than %d poses'):format(MAX_LIKE_CHAIN)
    end
    seen[current] = true
    table.insert(chain, pose)
    current = pose.like
  end
  return chain
end

--- The pose `name` of `poses`, with the fields of the poses it is like taken
--- unless it gives its own, the pose furthest along the chain first.
---
---@param poses table<string, table>
---@param name string
---@return table|nil pose
---@return string|nil problem
local function resolve_pose(poses, name)
  local chain, problem = like_chain(poses, name)
  if not chain then
    return nil, problem
  end
  local resolved = {}
  for index = #chain, 1, -1 do
    resolved = vim.tbl_extend('force', resolved, vim.deepcopy(chain[index]))
  end
  resolved.like = nil
  resolved.sitting = resolved.sitting == true
  return resolved
end

--- The poses of `inherited` — already resolved — and of `own` — as read,
--- some of them like others — as one table of resolved poses. A pose of `own`
--- with a problem is left out, so that the pose of its name in `inherited`
--- shows through, and the problem is told at the pose's line.
---
---@param inherited table<string, aineo.office_pack.Pose>
---@param own table<string, table> the poses read, without a problem each
---@param path string the path of the poses, such as `characters.agent.poses`
---@param context aineo.office_pack.SchemaContext
---@param poses_table table|nil the table `own` was read from, whose lines the problems are told at
---@return table<string, aineo.office_pack.Pose>
function M.resolve(inherited, own, path, context, poses_table)
  local raw = entries.overlaid(inherited, own)
  local resolved = vim.deepcopy(inherited)
  local lines = poses_table and context.lines[poses_table] or {}
  for _, name in ipairs(entries.sorted_keys(own)) do
    local pose, problem = resolve_pose(raw, name)
    if pose then
      resolved[name] = pose
    else
      context.report(lines[name], ('%s.%s %s'):format(path, name, problem))
    end
  end
  return resolved
end

return M
