--- What a piece that `shows` live content draws into its areas: the time and
--- the date of the wall clock, the sky outside the window, the tasks on the
--- whiteboard, the page a printer prints, the name on a desk's plate. Each paints into the area of the
--- piece named for the content, and nowhere else.

local areas = require('aineo.office_scene.areas')
local items = require('aineo.office_scene.items')
local live_text = require('aineo.office_scene.live_text')
local name_plate = require('aineo.office_scene.name_plate')
local printing = require('aineo.office_scene.printing')
local sky = require('aineo.office_scene.sky')
local whiteboard = require('aineo.office_scene.whiteboard')

local M = {}

--- Writes the text of the content `placed` shows, at the wall clock's time,
--- into the piece's area of that name, no more of it than the area holds.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param placed aineo.office_scene.PlacedPiece
---@param piece aineo.office_pack.Piece the art the piece is drawn in
local function write_wall_text(canvas, drawing, placed, piece)
  local text = drawing.wall_time and live_text.of(placed.shows, drawing.wall_time)
  local area = text and areas.on_canvas(placed, piece, placed.shows)
  if not area then
    return
  end
  areas.write_text_above_the_list(
    canvas,
    drawing,
    { column = area.column, row = math.floor(area.row / 2) },
    vim.fn.strcharpart(text, 0, area.width),
    { foreground = drawing.pack.text_colours.status }
  )
end

--- Paints the pack's sky for the hour of the wall clock into the glass of
--- the piece, its `sky` area.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param placed aineo.office_scene.PlacedPiece
---@param piece aineo.office_pack.Piece the art the piece is drawn in
local function paint_sky(canvas, drawing, placed, piece)
  local glass = areas.on_canvas(placed, piece, 'sky')
  local view = drawing.wall_time and drawing.pack.pieces[sky.piece_at(drawing.wall_time.hour)]
  if not (glass and view) then
    return
  end
  canvas.paint_art(view, {
    frame = items.frame_after(view, drawing.now),
    column = glass.column + view.anchor.column,
    row = glass.row + view.anchor.row,
    colours = drawing.pack.colours,
    clip = items.common_to(glass, items.plan_area(drawing)),
  })
end

---@type table<string, fun(canvas: aineo.office_scene.Canvas, drawing: aineo.office_scene.Drawing, placed: aineo.office_scene.PlacedPiece, piece: aineo.office_pack.Piece)>
local PAINTERS = {
  time = write_wall_text,
  date = write_wall_text,
  sky = paint_sky,
  plan = whiteboard.paint,
  name = name_plate.paint,
  printing = printing.paint,
}

--- Draws the live content `placed` shows, if it shows any, into the areas of
--- `piece`.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param placed aineo.office_scene.PlacedPiece
---@param piece aineo.office_pack.Piece the art the piece is drawn in
function M.paint(canvas, drawing, placed, piece)
  local paint = placed.shows and PAINTERS[placed.shows]
  if paint then
    paint(canvas, drawing, placed, piece)
  end
end

return M
