--- The status list: a rule and a line for each agent on the last rows of the
--- picture, below the plan. A line is a dot in the agent's colour, its name
--- and what it is doing; the agents that do not fit are counted on the last
--- line.

local colours = require('aineo.office_scene.colours')
local roles = require('aineo.office_scene.roles')

local M = {}

--- How many lines of the list are for agents.
local LINES_FOR_AGENTS = 4

--- The rows the list takes: its rule and its lines.
local ROWS = 1 + LINES_FOR_AGENTS

--- The fewest rows of a stage that shows the list: the office is not shown
--- below 24 rows, and a stage shorter than that shows the plan alone.
local SMALLEST_HEIGHT = 24

--- Where each part of a line begins, in cells, and how wide a name may be.
local DOT_COLUMN = 1
local NAME_COLUMN = 3
local NAME_CELLS = 9
local LABEL_COLUMN = 13

local DOT = '●'
local RULE = '─'

--- How many rows the status list takes of a stage `height` rows tall.
---
---@param height integer
---@return integer rows 0 when the stage is shorter than the office is shown at
function M.rows_taken(height)
  return height >= SMALLEST_HEIGHT and ROWS or 0
end

--- The first `cells` characters of `text`, with each character that is not
--- exactly one cell wide on the screen (a control character, a wide or a
--- combining one) replaced by `?`, so that a line is as many cells wide as it
--- has characters.
---
---@param text string
---@param cells integer
---@return string
local function cut_to(text, cells)
  local starts = vim.str_utf_pos(text)
  local kept = {}
  for index = 1, math.min(#starts, math.max(0, cells)) do
    local character = text:sub(starts[index], (starts[index + 1] or #text + 1) - 1)
    local is_one_cell = not character:find('%c') and vim.fn.strdisplaywidth(character) == 1
    kept[index] = is_one_cell and character or '?'
  end
  return table.concat(kept)
end

--- What the agent is doing, in words: the label of the activity it plays (the
--- one its state asks for until it picks another), otherwise the words given
--- for its state, otherwise its state's name.
---
---@param drawing aineo.office_scene.Drawing
---@param agent aineo.office_states.Agent
---@return string
local function label_of(drawing, agent)
  local _, asked_for = roles.activity_of(drawing.pack, agent)
  local activity = drawing.activities_played[agent.id] or asked_for
  return (activity and activity.label)
    or drawing.state_labels[agent.state]
    or (agent.state:gsub('_', ' '))
end

--- Writes the line of the agent at `index` on `row`.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param row integer
---@param index integer the agent's position in the list
local function write_line(canvas, drawing, row, index)
  local pack, agent = drawing.pack, drawing.agents[index]
  local own_colours = pack[roles.kind_of(agent)].colours
  local place = drawing.places[agent.id]
  canvas.write_text(DOT_COLUMN, row, DOT, { foreground = colours.of_agent(own_colours, place) })
  canvas.write_text(
    NAME_COLUMN,
    row,
    cut_to(agent.id, NAME_CELLS),
    { foreground = pack.text_colours.name }
  )
  canvas.write_text(
    LABEL_COLUMN,
    row,
    cut_to(label_of(drawing, agent), drawing.width - LABEL_COLUMN - 1),
    { foreground = pack.text_colours.status }
  )
end

--- Writes the status list on the rows below the plan.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
function M.paint(canvas, drawing)
  local first_row = drawing.plan_height
  canvas.write_text(
    0,
    first_row,
    RULE:rep(drawing.width),
    { foreground = drawing.pack.text_colours.name }
  )
  local overflows = #drawing.agents > LINES_FOR_AGENTS
  local listed = overflows and LINES_FOR_AGENTS - 1 or #drawing.agents
  for index = 1, listed do
    write_line(canvas, drawing, first_row + index, index)
  end
  if overflows then
    canvas.write_text(
      NAME_COLUMN,
      first_row + LINES_FOR_AGENTS,
      ('+%d more'):format(#drawing.agents - listed),
      { foreground = drawing.pack.text_colours.name }
    )
  end
end

return M
