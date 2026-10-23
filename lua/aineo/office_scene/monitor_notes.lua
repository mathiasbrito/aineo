--- What a monitor shows of its agent's work beyond the screen art its pose
--- gives: the clue of what the agent looks up on the web, written into the
--- monitor's `query` area, and the verdict of its last test run, written at
--- the top left of the monitor's `screen` area for a while.

local areas = require('aineo.office_scene.areas')
local cell_text = require('aineo.office_scene.cell_text')

local M = {}

--- The state of an agent looking something up on the web.
local ON_THE_WEB = 'on_the_web'

--- How long the verdict of a test run shows on the screen, in seconds.
M.VERDICT_SECONDS = 3

local PASSED = { glyph = '✓', colour = '#a6e3a1' }
local FAILED = { glyph = '✗', colour = '#f38ba8' }

--- The agent whose monitor `placed` is.
---
---@param drawing aineo.office_scene.Drawing
---@param placed aineo.office_scene.PlacedPiece
---@return aineo.office_states.Agent|nil
local function owner_of(drawing, placed)
  return placed.owner_place
    and vim.iter(drawing.agents):find(function(agent)
      return drawing.places[agent.id] == placed.owner_place
    end)
end

--- Writes the verdict of the last test run of `owner` at the top left of the
--- monitor's `screen` area, while it is less than `VERDICT_SECONDS` old.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param owner aineo.office_states.Agent
---@param screen aineo.office_scene.PixelArea the monitor's screen on the canvas
local function write_test_verdict(canvas, drawing, owner, screen)
  local verdict = owner.details and owner.details.test_verdict
  if not (verdict and drawing.now - verdict.at < M.VERDICT_SECONDS) then
    return
  end
  local shown = verdict.passed and PASSED or FAILED
  areas.write_text_above_the_list(
    canvas,
    drawing,
    { column = screen.column, row = math.floor(screen.row / 2) },
    shown.glyph,
    { foreground = shown.colour }
  )
end

--- Writes the notes of the owner of the monitor `placed`: the clue of what it
--- looks up on the web, no wider than the monitor's `query` area, while it is
--- on the web, and the verdict of its last test run.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param placed aineo.office_scene.PlacedPiece
---@param monitor aineo.office_pack.Piece the art the monitor is drawn in
function M.paint(canvas, drawing, placed, monitor)
  local owner = owner_of(drawing, placed)
  if not owner then
    return
  end
  local area = areas.on_canvas(placed, monitor, 'query')
  local clue = owner.state == ON_THE_WEB and owner.details and owner.details.web_clue
  if area and clue then
    areas.write_text_above_the_list(
      canvas,
      drawing,
      { column = area.column, row = math.floor(area.row / 2) },
      cell_text.cut_to(clue, area.width),
      { foreground = drawing.pack.text_colours.status }
    )
  end
  local screen = areas.on_canvas(placed, monitor, 'screen')
  if screen then
    write_test_verdict(canvas, drawing, owner, screen)
  end
end

return M
