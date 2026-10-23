--- The things that lie on the office floor: what a step leaves at a
--- character's feet, until a step removes it. A thing lies on a cell, and
--- characters go to it by its name, as to a spot.

local M = {}

--- How many things lie on the floor at most; a step that would leave one more
--- leaves nothing.
local MOST_LYING = 64

---@class aineo.office_scene.LyingThing
---@field name string the name the pack gives the thing
---@field piece string the piece drawn for it
---@field column integer the cell it lies on
---@field row integer
---@field spot aineo.office_scene.Spot where a character stands to deal with it
---@field reach? { layout: aineo.office_scene.FloorLayout, cells: table<integer, true> } the cells that can be walked to from it in a layout, found when an agent is to be sent
---@field cleaner? table the agent that has gone to clean it up, while it is on its way

---@class aineo.office_scene.Things
---@field leave fun(name: string, column: integer, row: integer): aineo.office_scene.LyingThing|nil leaves the thing on the cell; nil when too many lie, or one of the name lies on the cell already
---@field remove_at fun(name: string, column: integer, row: integer): boolean removes the thing of the name on the cell, if one lies there
---@field keep_on fun(is_walkable: fun(column: integer, row: integer): boolean) drops the things that lie on a cell that cannot be walked on
---@field all fun(): aineo.office_scene.LyingThing[] the things that lie, the oldest first
---@field spots_named fun(name: string): aineo.office_scene.Spot[] the spots of the things of the name, the oldest first

--- A register of things that lie on the floor, none yet.
---
---@param definitions table<string, table> the pack's things, by name; each has the `piece` drawn for it
---@return aineo.office_scene.Things
function M.new_register(definitions)
  ---@type aineo.office_scene.LyingThing[]
  local lying = {}

  local function index_at(name, column, row)
    for index, thing in ipairs(lying) do
      if thing.name == name and thing.column == column and thing.row == row then
        return index
      end
    end
    return nil
  end

  local register = {}

  function register.leave(name, column, row)
    local definition = definitions[name]
    if not definition or #lying >= MOST_LYING or index_at(name, column, row) then
      return nil
    end
    local thing = {
      name = name,
      piece = definition.piece,
      column = column,
      row = row,
      spot = {
        name = name,
        number = #lying + 1,
        order = 0,
        column = column,
        row = row,
        sitting = false,
        facing = 'right',
      },
    }
    table.insert(lying, thing)
    return thing
  end

  function register.remove_at(name, column, row)
    local index = index_at(name, column, row)
    if index then
      table.remove(lying, index)
    end
    return index ~= nil
  end

  function register.keep_on(is_walkable)
    for index = #lying, 1, -1 do
      if not is_walkable(lying[index].column, lying[index].row) then
        table.remove(lying, index)
      end
    end
  end

  function register.all()
    return lying
  end

  function register.spots_named(name)
    local spots = {}
    for _, thing in ipairs(lying) do
      if thing.name == name then
        table.insert(spots, thing.spot)
      end
    end
    return spots
  end

  return register
end

return M
