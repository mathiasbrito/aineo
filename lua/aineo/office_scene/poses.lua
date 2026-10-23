--- The pose a character holds, as its pack describes it.

local M = {}

--- The pose of `character` in the pack: the pose it holds, or standing when
--- the pack does not describe it; nil when the pack has neither.
---
---@param pack aineo.office_pack.Pack
---@param character aineo.office_scene.Character
---@return aineo.office_pack.Pose|nil
function M.of(pack, character)
  local looks = pack[character.kind]
  return looks.poses[character.pose] or looks.poses.standing
end

return M
