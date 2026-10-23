--- The pieces the floor plan places, as items to paint: walls' decoration,
--- desks, doors and the rest, stretched to the width the plan draws them. A
--- piece with `in_use` art shows it while a character is at the piece's spot,
--- and a piece laid on the floor is under everything that stands on it.

local items = require('aineo.office_scene.items')
local live_text = require('aineo.office_scene.live_text')
local poses = require('aineo.office_scene.poses')
local stretch = require('aineo.office_scene.stretch')

local M = {}

--- The depth of a piece laid on the floor: above no cell of the canvas.
local ON_THE_FLOOR = -1

--- Whether any row of `piece`, placed with its anchor on the cell row `row`,
--- lies on a canvas `height` cells tall.
---
---@param piece aineo.office_pack.Piece
---@param row integer
---@param height integer
---@return boolean
local function is_on_canvas(piece, row, height)
  local top = 2 * row + 1 - piece.anchor.row
  return top < 2 * height and top + piece.height > 0
end

--- Whether a character is at the spot the placed piece is used from, standing
--- on it or walking over it.
---
---@param placed aineo.office_scene.PlacedPiece
---@param characters aineo.office_scene.Character[]
---@return boolean
local function is_in_use(placed, characters)
  local spot = placed.used_at
  return spot ~= nil
    and vim.iter(characters):any(function(character)
      return items.round(character.column) == spot.column and items.round(character.row) == spot.row
    end)
end

--- The piece to draw for `placed`: its `in_use` art while it is in use, its
--- own otherwise, stretched to the width the plan draws it.
---
---@param drawing aineo.office_scene.Drawing
---@param placed aineo.office_scene.PlacedPiece
---@return aineo.office_pack.Piece|nil
local function piece_shown(drawing, placed)
  local name = is_in_use(placed, drawing.characters) and placed.in_use or placed.piece
  local piece = drawing.pack.pieces[name]
  if piece and placed.columns then
    return stretch.to_width(piece, placed.columns)
  end
  return piece
end

--- Paints what the pose of the agent who owns the monitor `placed` says the
--- screen shows, into the monitor's screen area only.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param placed aineo.office_scene.PlacedPiece
---@param monitor aineo.office_pack.Piece the art the monitor is drawn in
local function paint_screen(canvas, drawing, placed, monitor)
  local area = monitor.areas.screen
  local owner = vim.iter(drawing.characters):find(function(character)
    return character.index == placed.owner_index
  end)
  local pose = owner and poses.of(drawing.pack, owner)
  local content = pose and pose.screen and drawing.pack.pieces[pose.screen]
  if not (area and content) then
    return
  end
  local left = placed.column - monitor.anchor.column + area.column
  local top = 2 * placed.row + 1 - monitor.anchor.row + area.row
  canvas.paint_art(content, {
    frame = items.frame_after(content, math.max(0, drawing.now - owner.pose_since)),
    column = left + content.anchor.column,
    row = top + content.anchor.row,
    colours = drawing.pack.colours,
    clip = items.common_to(
      { column = left, row = top, width = area.width, height = area.height },
      items.plan_area(drawing)
    ),
  })
end

--- Writes the live text a piece that shows content of the wall clock gives,
--- into the piece's area of that name, no more of it than the area holds.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param placed aineo.office_scene.PlacedPiece
---@param piece aineo.office_pack.Piece the art the piece is drawn in
local function write_live_text(canvas, drawing, placed, piece)
  local text = placed.shows and drawing.wall_time and live_text.of(placed.shows, drawing.wall_time)
  local area = piece.areas[placed.shows or '']
  if not (text and area) then
    return
  end
  local column = placed.column - piece.anchor.column + area.column
  local row = math.floor((2 * placed.row + 1 - piece.anchor.row + area.row) / 2)
  canvas.write_text(
    column,
    row,
    vim.fn.strcharpart(text, 0, area.width),
    { foreground = drawing.pack.text_colours.status }
  )
end

--- The items for the pieces the plan places that lie on the canvas.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@return aineo.office_scene.Item[]
function M.items(canvas, drawing)
  local made = {}
  for _, placed in ipairs(drawing.layout.pieces) do
    local piece = piece_shown(drawing, placed)
    if piece and is_on_canvas(piece, placed.row, drawing.plan_height) then
      table.insert(made, {
        depth = placed.walk_over and ON_THE_FLOOR or 2 * placed.row + 1,
        rank = placed.walk_over and items.RANK.on_the_floor or items.RANK.piece,
        paint = function()
          canvas.paint_art(piece, {
            frame = items.frame_after(piece, drawing.now),
            column = placed.column,
            row = 2 * placed.row + 1,
            colours = drawing.pack.colours,
            clip = items.plan_area(drawing),
          })
          paint_screen(canvas, drawing, placed, piece)
          write_live_text(canvas, drawing, placed, piece)
        end,
      })
    end
  end
  return made
end

return M
