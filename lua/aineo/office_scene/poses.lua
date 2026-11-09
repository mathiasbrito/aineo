--- The pose a character holds, as its pack describes it.

local walking = require('aineo.office_scene.walking')

local M = {}

--- The pose `character` walks in: the pose its last pose before the walk
--- says (`walks_as`), when the pack describes it; nil when its last pose says
--- none.
---
---@param looks table the pack's description of the character's kind
---@param character aineo.office_scene.Character
---@return aineo.office_pack.Pose|nil
local function pose_walked_in(looks, character)
  local before = character.walks_from and looks.poses[character.walks_from]
  return before and before.walks_as and looks.poses[before.walks_as] or nil
end

--- The pose of `character` in the pack: the pose it holds, or standing when
--- the pack does not describe it; while it walks, the pose its last pose
--- before the walk says it walks in (`walks_as`); nil when the pack has none
--- of them.
---
---@param pack aineo.office_pack.Pack
---@param character aineo.office_scene.Character
---@return aineo.office_pack.Pose|nil
function M.of(pack, character)
  local looks = pack[character.kind]
  if character.pose == walking.POSE then
    local walked_in = pose_walked_in(looks, character)
    if walked_in then
      return walked_in
    end
  end
  return looks.poses[character.pose] or looks.poses.standing
end

return M
