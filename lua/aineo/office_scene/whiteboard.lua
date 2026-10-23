--- The tasks of the session on a whiteboard: a row for each, a tick before
--- the ones done, written into the `plan` area of the piece.

local areas = require('aineo.office_scene.areas')
local cell_text = require('aineo.office_scene.cell_text')
local roles = require('aineo.office_scene.roles')

local M = {}

local TICK = '✓ '
local BULLET = '○ '

--- The tasks of the main agent, the one whose session the board shows.
---
---@param agents aineo.office_states.Agent[]
---@return aineo.office_states.Task[]
local function tasks_of_main(agents)
  local main = vim.iter(agents):find(function(agent)
    return roles.kind_of(agent) == 'agent'
  end)
  return main and main.details and main.details.tasks or {}
end

--- The tasks of `tasks` that fit `rows` rows: from the first not done, so
--- that the board shows the work ahead, but never so few of the last that
--- rows stay empty.
---
---@param tasks aineo.office_states.Task[]
---@param rows integer
---@return aineo.office_states.Task[]
local function visible_tasks(tasks, rows)
  local first_not_done = #tasks + 1
  for index, task in ipairs(tasks) do
    if not task.done then
      first_not_done = index
      break
    end
  end
  local first = math.max(1, math.min(first_not_done, #tasks - rows + 1))
  return vim.list_slice(tasks, first, first + rows - 1)
end

--- Writes the row of `task` on the text row `row`, from the cell `column`, no
--- wider than `cells`.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param task aineo.office_states.Task
---@param place { column: integer, row: integer, cells: integer }
local function write_task(canvas, drawing, task, place)
  local text_colours = drawing.pack.text_colours
  canvas.write_text(
    place.column,
    place.row,
    cell_text.cut_to((task.done and TICK or BULLET) .. task.subject, place.cells),
    { foreground = task.done and text_colours.name or text_colours.status }
  )
end

--- Writes the tasks of the main agent into the `plan` area of `piece`, a row
--- each from the area's top.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param placed aineo.office_scene.PlacedPiece
---@param piece aineo.office_pack.Piece the art the board is drawn in
function M.paint(canvas, drawing, placed, piece)
  local area = areas.on_canvas(placed, piece, 'plan')
  if not area then
    return
  end
  local rows = math.max(1, math.floor(area.height / 2))
  for index, task in ipairs(visible_tasks(tasks_of_main(drawing.agents), rows)) do
    write_task(canvas, drawing, task, {
      column = area.column,
      row = math.floor(area.row / 2) + index - 1,
      cells = area.width,
    })
  end
end

return M
