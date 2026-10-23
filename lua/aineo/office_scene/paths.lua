--- Ways over the floor: the shortest walks from one cell to the cells
--- characters walk on, one cell up, down, left or right at a time. A walk
--- never crosses a cell the layout does not let characters walk on.

local M = {}

---@class aineo.office_scene.Cell
---@field column integer from 0
---@field row integer from 0

---@class aineo.office_scene.Reach
---@field distance fun(column: integer, row: integer): integer|nil the steps of the shortest walk to the cell; nil when it cannot be reached
---@field path_to fun(column: integer, row: integer): aineo.office_scene.Cell[]|nil the cells of the shortest walk to the cell, the first step first and the cell last; empty at the start; nil when it cannot be reached

--- The steps from a cell to its neighbours, as `{ across, down }`.
local STEPS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

--- Every cell that can be walked to from `start`, with the steps it takes.
---
---@param layout aineo.office_scene.FloorLayout
---@param start aineo.office_scene.Cell
---@return table<integer, integer> steps by the cell's key
---@return table<integer, integer> came_from the key of the cell before it, by the cell's key
local function walk_everywhere(layout, start)
  local function key_of(column, row)
    return row * layout.width + column
  end
  local start_key = key_of(start.column, start.row)
  local steps, came_from = { [start_key] = 0 }, {}
  local queue, head = { start }, 1
  while head <= #queue do
    local cell = queue[head]
    head = head + 1
    local cell_key = key_of(cell.column, cell.row)
    for _, step in ipairs(STEPS) do
      local column, row = cell.column + step[1], cell.row + step[2]
      local key = key_of(column, row)
      if layout.is_walkable(column, row) and steps[key] == nil then
        steps[key] = steps[cell_key] + 1
        came_from[key] = cell_key
        table.insert(queue, { column = column, row = row })
      end
    end
  end
  return steps, came_from
end

--- What can be walked to from `start` over `layout`'s floor.
---
---@param layout aineo.office_scene.FloorLayout
---@param start aineo.office_scene.Cell where the walk begins, walkable or not
---@return aineo.office_scene.Reach
function M.reach_from(layout, start)
  local steps, came_from = walk_everywhere(layout, start)
  local reach = {}

  function reach.distance(column, row)
    return steps[row * layout.width + column]
  end

  function reach.path_to(column, row)
    local key = row * layout.width + column
    if steps[key] == nil then
      return nil
    end
    local path = {}
    while came_from[key] do
      table.insert(path, 1, { column = key % layout.width, row = math.floor(key / layout.width) })
      key = came_from[key]
    end
    return path
  end

  return reach
end

return M
