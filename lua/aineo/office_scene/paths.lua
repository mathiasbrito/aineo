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

--- The cell at `direction` from `column` and `row`: 1 right, 2 left, 3 down,
--- 4 up, the order the search tries them in.
---
---@param direction integer
---@param column integer
---@param row integer
---@return integer column
---@return integer row
local function neighbour(direction, column, row)
  if direction == 1 then
    return column + 1, row
  elseif direction == 2 then
    return column - 1, row
  elseif direction == 3 then
    return column, row + 1
  end
  return column, row - 1
end

--- The cells of the shortest walk from the cell `start_key` to the cell
--- `key`, the first step first.
---
---@param came_from table<integer, integer> the key of the cell before it, by the cell's key
---@param key integer
---@param width integer
---@return aineo.office_scene.Cell[]
local function path_to(came_from, key, width)
  local reversed = {}
  while came_from[key] do
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
---@param layout aineo.office_scene.FloorLayout
---@param start aineo.office_scene.Cell where the walk begins, walkable or not
---@param spots aineo.office_scene.Spot[]
---@return aineo.office_scene.Nearest|nil nearest nil when none of the spots can be walked to
function M.nearest(layout, start, spots)
  local width, is_walkable = layout.width, layout.is_walkable
  local is_target = {}
  for _, spot in ipairs(spots) do
    is_target[spot.row * width + spot.column] = true
  end
  local start_key = start.row * width + start.column
  local steps, came_from = { [start_key] = 0 }, {}
  local columns, rows = { start.column }, { start.row }
  local head, tail = 1, 1
  local found_at = is_target[start_key] and 0 or nil
  while head <= tail and not (found_at and steps[rows[head] * width + columns[head]] >= found_at) do
    local column, row = columns[head], rows[head]
    local key = row * width + column
    head = head + 1
    for direction = 1, 4 do
      local next_column, next_row = neighbour(direction, column, row)
      local next_key = next_row * width + next_column
      if steps[next_key] == nil and is_walkable(next_column, next_row) then
        steps[next_key] = steps[key] + 1
        came_from[next_key] = key
        tail = tail + 1
        columns[tail], rows[tail] = next_column, next_row
        if is_target[next_key] and not found_at then
          found_at = steps[next_key]
        end
      end
    end
  end
  for _, spot in ipairs(spots) do
    local key = spot.row * width + spot.column
    if found_at and steps[key] == found_at then
      return { spot = spot, path = path_to(came_from, key, width) }
    end
  end
  return nil
end

return M
