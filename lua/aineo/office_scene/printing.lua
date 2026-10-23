--- The page a printer prints when an agent reports: it grows out of the
--- top of the piece's `page` area while the print lasts, and is gone when the
--- print is over.

local areas = require('aineo.office_scene.areas')
local items = require('aineo.office_scene.items')

local M = {}

--- How long a print lasts, in seconds.
M.PRINT_SECONDS = 4

--- The name of the piece of the pack that is the page.
local PAGE_PIECE = 'printed_page'

--- How many seconds ago the latest report of `agents` was heard, at `now`;
--- nothing when no agent reported.
---
---@param agents aineo.office_states.Agent[]
---@param now number
---@return number|nil
local function seconds_since_latest_report(agents, now)
  local latest
  for _, agent in ipairs(agents) do
    local reported_at = agent.details and agent.details.reported_at
    if reported_at and (not latest or reported_at > latest) then
      latest = reported_at
    end
  end
  return latest and now - latest
end

--- How many pixel rows of a page `height` pixels tall have come out of the
--- printer `seconds` into the print.
---
---@param seconds number
---@param height integer
---@return integer
local function rows_printed(seconds, height)
  if seconds < 0 or seconds >= M.PRINT_SECONDS then
    return 0
  end
  return math.floor(height * seconds / M.PRINT_SECONDS)
end

--- Paints the page the printer is printing, if it is printing, into the
--- `page` area of `piece`.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param placed aineo.office_scene.PlacedPiece
---@param piece aineo.office_pack.Piece the art the printer is drawn in
function M.paint(canvas, drawing, placed, piece)
  local tray = areas.on_canvas(placed, piece, 'page')
  local page = drawing.pack.pieces[PAGE_PIECE]
  local seconds = seconds_since_latest_report(drawing.agents, drawing.now)
  if not (tray and page and seconds) then
    return
  end
  local printed = {
    column = tray.column,
    row = tray.row,
    width = tray.width,
    height = rows_printed(seconds, tray.height),
  }
  canvas.paint_art(page, {
    frame = items.frame_after(page, drawing.now),
    column = tray.column + page.anchor.column,
    row = tray.row + page.anchor.row,
    colours = drawing.pack.colours,
    clip = items.common_to(printed, items.plan_area(drawing)),
  })
end

return M
