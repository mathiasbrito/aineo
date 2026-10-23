--- Checks of a pack that look at its floor and its activities together: whether
--- every spot can be walked to from the door, and whether every activity has
--- the spots its steps go to.

local entries = require('aineo.office_pack.entries')

local M = {}

--- The spot of the door: where characters come in and go out.
local DOOR = 'door'

--- The spots aineo knows without a legend.
local KNOWN_SPOTS = {
  anywhere = true,
  an_empty_desk = true,
  an_idle_agents_desk = true,
  next_to_an_agent = true,
  next_to_the_cat = true,
}

--- The steps from one cell to the next.
local STEPS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

--- Whether a character can stand on `cell` of the plan: floor, a spot, or a
--- piece that lies on the floor and is walked over.
---
---@param cell string
---@param legend table<string, table>
---@return boolean
local function is_walkable(cell, legend)
  local entry = legend[cell]
  return cell == '.' or (entry ~= nil and (entry.spot ~= nil or entry.walk_over == true))
end

--- The cells of `rows` that can be walked to from the cells in `starts`, as
--- `reached[row][column]`, rows and columns from 1.
---
---@param rows string[]
---@param legend table<string, table>
---@param starts { row: integer, column: integer }[]
---@return table<integer, table<integer, true>>
local function reached_from(rows, legend, starts)
  local reached = {}
  local queue = {}
  local function visit(row, column)
    local cell = rows[row] and rows[row]:sub(column, column) or ''
    if cell ~= '' and is_walkable(cell, legend) and not (reached[row] and reached[row][column]) then
      reached[row] = reached[row] or {}
      reached[row][column] = true
      table.insert(queue, { row = row, column = column })
    end
  end
  for _, start in ipairs(starts) do
    visit(start.row, start.column)
  end
  local head = 1
  while head <= #queue do
    local at = queue[head]
    head = head + 1
    for _, step in ipairs(STEPS) do
      visit(at.row + step[2], at.column + step[1])
    end
  end
  return reached
end

--- Tells each spot of the plan that cannot be walked to from the door, once
--- by name, at the row of its first cell. A plan with no door is not told.
--- The plan is read as written, a block that repeats once.
---
---@param plan aineo.office_pack.FloorPlan
---@param legend table<string, table>
---@param report aineo.office_pack.Report
function M.check_spots_reachable(plan, legend, report)
  local doors, spots = {}, {}
  for row, text in ipairs(plan.rows) do
    for column = 1, #text do
      local entry = legend[text:sub(column, column)]
      if entry and entry.spot == DOOR then
        table.insert(doors, { row = row, column = column })
      elseif entry and entry.spot then
        table.insert(spots, { row = row, column = column, name = entry.spot })
      end
    end
  end
  if #doors == 0 then
    return
  end
  local reached = reached_from(plan.rows, legend, doors)
  local told = {}
  for _, spot in ipairs(spots) do
    if not told[spot.name] and not (reached[spot.row] and reached[spot.row][spot.column]) then
      told[spot.name] = true
      report(
        plan.row_lines[spot.row],
        ('the spot “%s” cannot be reached from the door'):format(spot.name)
      )
    end
  end
end

--- The names a step may go to on a floor: the spots of its legend, the
--- pieces its decorations place, the spots aineo knows, and the things that
--- lie on it.
---
---@param legend table<string, table>
---@param things table<string, table>
---@return table<string, true>
local function spots_of(legend, things)
  local spots = vim.deepcopy(KNOWN_SPOTS)
  for name in pairs(things) do
    spots[name] = true
  end
  for _, entry in pairs(legend) do
    if entry.spot then
      spots[entry.spot] = true
    end
    for _, piece in ipairs(entry.decorations or {}) do
      spots[piece] = true
    end
  end
  return spots
end

--- The first step of `activity` that goes to a spot `spots` lacks.
---
---@param activity table
---@param spots table<string, true>
---@return table|nil step
local function first_step_to_a_lacking_spot(activity, spots)
  for _, step in ipairs(activity.steps) do
    if step.at and not spots[step.at] then
      return step
    end
  end
  return nil
end

---@class aineo.office_pack.ActivityCheck
---@field activities table<string, table> the activities of the pack
---@field legend table<string, table> the legend of its floor
---@field things table<string, table>
---@field described table<string, table> the activities `pack.lua` describes itself, which the report names the step of
---@field lines table<table, table<string|integer, integer>> the lines of `pack.lua`
---@field floor_line integer|nil the line of the pack's `floor`, where the activities it did not describe are told; none to leave those to the pack they came from
---@field report aineo.office_pack.Report

--- Tells each activity that has a step to a spot the floor lacks: it is
--- never picked. One that `pack.lua` describes is told at the step; one that
--- comes from the pack it is based on, at the pack's floor, if it has one.
---
---@param check aineo.office_pack.ActivityCheck
function M.check_activities_have_spots(check)
  local spots = spots_of(check.legend, check.things)
  for _, name in ipairs(entries.sorted_keys(check.activities)) do
    local activity = check.activities[name]
    local step = first_step_to_a_lacking_spot(activity, spots)
    if step then
      local line = check.floor_line
      if check.described[name] == activity then
        line = (check.lines[step] or {}).at
      end
      if line then
        check.report(
          line,
          ('activity “%s” never plays: the floor has no spot “%s”'):format(name, step.at)
        )
      end
    end
  end
end

return M
