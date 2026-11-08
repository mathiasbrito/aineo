--- A character walking along the path it has: how far it gets in the time it
--- has, and which way it faces on the way.

local M = {}

--- How fast a character walks, in cells a second.
local CELLS_PER_SECOND = 14

--- The pose a character holds while it walks.
M.POSE = 'walking'

---@class aineo.office_scene.Walker
---@field column number the cell column it is at, between cells while it walks
---@field row number the cell row it is at
---@field facing string 'left' or 'right'
---@field path aineo.office_scene.Cell[] the cells it has still to walk over, the next first
---@field pose string the pose it holds
---@field pose_since number when it took the pose
---@field walks_from? string the pose it held when it began to walk; none before it first walks
---@field rests_at? aineo.office_scene.Spot the spot it has come to rest at; none while it walks
---@field rests_since? number when it came to rest at that spot

--- Has `walker` begin to walk at `time`: it takes the walking pose, and is
--- at rest nowhere. The pose it held is kept in `walks_from` unless it was
--- walking already.
---
---@param walker aineo.office_scene.Walker
---@param time number
function M.begin(walker, time)
  if walker.pose ~= M.POSE then
    walker.walks_from = walker.pose
  end
  walker.pose, walker.pose_since = M.POSE, time
  walker.rests_at = nil
end

--- Moves `walker` along its path for at most `available` seconds, and turns
--- it to face the way it goes. It stops at the end of the path.
---
---@param walker aineo.office_scene.Walker
---@param available number seconds
---@return number used the seconds the walk took, `available` when the path is longer
function M.advance(walker, available)
  local reach = CELLS_PER_SECOND * available
  while #walker.path > 0 do
    local next_cell = walker.path[1]
    local across = next_cell.column - walker.column
    local down = next_cell.row - walker.row
    local distance = math.sqrt(across * across + down * down)
    if across ~= 0 then
      walker.facing = across > 0 and 'right' or 'left'
    end
    if distance > reach then
      walker.column = walker.column + across / distance * reach
      walker.row = walker.row + down / distance * reach
      return available
    end
    walker.column, walker.row = next_cell.column, next_cell.row
    reach = reach - distance
    table.remove(walker.path, 1)
  end
  return available - reach / CELLS_PER_SECOND
end

return M
