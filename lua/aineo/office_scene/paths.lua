--- Ways over the floor: the shortest walk from one cell to the nearest of some
--- spots, one cell up, down, left or right at a time. A walk never crosses a
--- cell the layout does not let characters walk on, and the search stops at
--- the end of the step in which the first spot is reached, so that it costs
--- what lies between the walker and the spot, not the size of the floor.

local M = {}

---@class aineo.office_scene.Cell
---@field column integer from 0
---@field row integer from 0

---@class aineo.office_scene.Nearest
---@field spot aineo.office_scene.Spot
---@field path aineo.office_scene.Cell[] the cells of the shortest walk to it, the first step first and the spot's cell last; empty at the start

--- The cells of the shortest walk from the cell `start_key` to the cell `key`,
--- the first step first.
---
---@param came_from table<integer, integer> the key of the cell before it, by the cell's key
---@param start_key integer
---@param key integer
---@param width integer
---@return aineo.office_scene.Cell[]
local function path_to(came_from, start_key, key, width)
  local reversed = {}
  while key ~= start_key do
    reversed[#reversed + 1] = { column = key % width, row = math.floor(key / width) }
    key = came_from[key]
  end
  local path = {}
  for index = #reversed, 1, -1 do
    path[#path + 1] = reversed[index]
  end
  return path
end

--- The nearest of `spots` to walk to from `start`, and the way there: the
--- first of `spots` that is as near when several are.
---
--- Cells are numbered `row * width + column`, and the search goes a step at a
--- time over all the cells that are as far from `start` as the last, so that
--- the cells of a step are found in the order the walks to them were tried.
---
---@param layout aineo.office_scene.FloorLayout
---@param start aineo.office_scene.Cell where the walk begins, walkable or not
---@param spots aineo.office_scene.Spot[]
---@return aineo.office_scene.Nearest|nil nearest nil when none of the spots can be walked to
function M.nearest(layout, start, spots)
  local width, walkable = layout.width, layout.walkable_cells
  local start_key = start.row * width + start.column
  local is_target = {}
  for _, spot in ipairs(spots) do
    local key = spot.row * width + spot.column
    if key == start_key then
      return { spot = spot, path = {} }
    end
    is_target[key] = true
  end

  local came_from = { [start_key] = start_key }
  local frontier, reached_a_spot = { start_key }, false
  while #frontier > 0 and not reached_a_spot do
    local next_frontier, count = {}, 0
    for index = 1, #frontier do
      local key = frontier[index]
      local column = key % width
      for direction = 1, 4 do
        local neighbour
        if direction == 1 then
          neighbour = column < width - 1 and key + 1
        elseif direction == 2 then
          neighbour = column > 0 and key - 1
        elseif direction == 3 then
          neighbour = key + width
        else
          neighbour = key - width
        end
        if neighbour and walkable[neighbour] and came_from[neighbour] == nil then
          came_from[neighbour] = key
          count = count + 1
          next_frontier[count] = neighbour
          reached_a_spot = reached_a_spot or is_target[neighbour] == true
        end
      end
    end
    frontier = next_frontier
  end

  for _, spot in ipairs(spots) do
    local key = spot.row * width + spot.column
    if came_from[key] ~= nil then
      return { spot = spot, path = path_to(came_from, start_key, key, width) }
    end
  end
  return nil
end

return M
