--- The painter of the office: draws the floor, the pieces of the plan and the
--- agents the director placed onto a canvas, back to front, and gives the
--- canvas's picture.

local canvas_module = require('aineo.office_scene.canvas')
local colours = require('aineo.office_scene.colours')

local M = {}

--- The colours of the floor and the wall when a pack names none.
local DEFAULT_FLOOR_COLOUR = '#303446'
local DEFAULT_WALL_COLOUR = '#292c3c'

--- What stands in front of what at the same depth: a character seated behind
--- a piece comes first, then the pieces, then a character standing on them.
local RANK = { seated = 0, piece = 1, standing = 2 }

---@class aineo.office_scene.Drawing
---@field pack aineo.office_pack.Pack
---@field layout aineo.office_scene.FloorLayout
---@field characters aineo.office_scene.Character[]
---@field width integer cells
---@field height integer cells
---@field now number seconds

--- `value` rounded to the nearest whole number.
---
---@param value number
---@return integer
local function round(value)
  return math.floor(value + 0.5)
end

--- The frame of `piece` showing at `now`.
---
---@param piece aineo.office_pack.Piece
---@param now number
---@return integer frame from 1
local function frame_of(piece, now)
  return math.floor(now / piece.seconds_per_frame) % #piece.frames + 1
end

--- Paints the floor everywhere and the wall where the layout has it.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
local function paint_backdrop(canvas, drawing)
  local pack = drawing.pack
  local floor_colour = pack.colours[pack.floor.floor_colour or ''] or DEFAULT_FLOOR_COLOUR
  local wall_colour = pack.colours[pack.floor.wall_colour or ''] or DEFAULT_WALL_COLOUR
  canvas.fill(floor_colour)
  for row = 0, drawing.height - 1 do
    for column = 0, drawing.width - 1 do
      if drawing.layout.is_wall(column, row) then
        canvas.paint_pixel(column, 2 * row, wall_colour)
        canvas.paint_pixel(column, 2 * row + 1, wall_colour)
      end
    end
  end
end

--- The pose of `character` in the pack: the pose it holds, or standing when
--- the pack does not describe it; nil when the pack has neither.
---
---@param pack aineo.office_pack.Pack
---@param character aineo.office_scene.Character
---@return aineo.office_pack.Pose|nil
local function pose_of(pack, character)
  return pack.agent.poses[character.pose] or pack.agent.poses.standing
end

--- The pieces of art a pose draws that the pack has, bottom first.
---
---@param pack aineo.office_pack.Pack
---@param pose aineo.office_pack.Pose
---@return aineo.office_pack.Piece[]
local function pieces_of(pack, pose)
  local pieces = {}
  for _, name in ipairs(pose.art or {}) do
    table.insert(pieces, pack.pieces[name])
  end
  return pieces
end

--- The pixel row `character`'s feet are on: the bottom of its cell.
---
---@param character aineo.office_scene.Character
---@return integer
local function feet_row_of(character)
  return 2 * round(character.row) + 1
end

--- The colours the art of the agent at `index` names: the pack's, and the
--- agent's own and its shades.
---
---@param pack aineo.office_pack.Pack
---@param index integer
---@return table<string, string>
local function agent_colours(pack, index)
  local own = pack.agent.colours[(index - 1) % #pack.agent.colours + 1]
  return vim.tbl_extend('force', pack.colours, colours.agent_shades(own))
end

---@class aineo.office_scene.Item
---@field depth integer the pixel row it stands on; the deeper is in front
---@field rank integer which comes first at one depth (`RANK`)
---@field order? integer the order the items were made in, which breaks a tie of depth and rank
---@field paint fun() draws it

--- The items for the pieces the plan places.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@return aineo.office_scene.Item[]
local function piece_items(canvas, drawing)
  local items = {}
  for _, placed in ipairs(drawing.layout.pieces) do
    local piece = drawing.pack.pieces[placed.piece]
    if piece then
      table.insert(items, {
        depth = 2 * placed.row + 1,
        rank = RANK.piece,
        paint = function()
          canvas.paint_art(piece, {
            frame = frame_of(piece, drawing.now),
            column = placed.column,
            row = 2 * placed.row + 1,
            colours = drawing.pack.colours,
          })
        end,
      })
    end
  end
  return items
end

--- The items for the agents the director placed, each in the pose it holds.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@return aineo.office_scene.Item[]
local function character_items(canvas, drawing)
  local items = {}
  for _, character in ipairs(drawing.characters) do
    local pose = pose_of(drawing.pack, character)
    if pose then
      local art_colours = agent_colours(drawing.pack, character.index)
      table.insert(items, {
        depth = feet_row_of(character),
        rank = pose.sitting and RANK.seated or RANK.standing,
        paint = function()
          for _, piece in ipairs(pieces_of(drawing.pack, pose)) do
            canvas.paint_art(piece, {
              frame = frame_of(piece, drawing.now),
              column = round(character.column),
              row = feet_row_of(character),
              colours = art_colours,
              mirrored = character.facing == 'left',
            })
          end
        end,
      })
    end
  end
  return items
end

--- The items to paint: each piece of the plan and each character.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@return aineo.office_scene.Item[]
local function items_of(canvas, drawing)
  local items = piece_items(canvas, drawing)
  vim.list_extend(items, character_items(canvas, drawing))
  for order, item in ipairs(items) do
    item.order = order
  end
  return items
end

--- Paints `items` back to front: the deeper one is in front.
---
---@param items aineo.office_scene.Item[]
local function paint_in_depth_order(items)
  table.sort(items, function(first, second)
    if first.depth ~= second.depth then
      return first.depth < second.depth
    end
    if first.rank ~= second.rank then
      return first.rank < second.rank
    end
    return first.order < second.order
  end)
  for _, item in ipairs(items) do
    item.paint()
  end
end

--- The colour an effect's text is drawn in: a role of the office's text, or a
--- colour as `#rrggbb`; the status role otherwise.
---
---@param pack aineo.office_pack.Pack
---@param colour string
---@return string
local function text_colour(pack, colour)
  if pack.text_colours[colour] then
    return pack.text_colours[colour]
  end
  if colour:match('^#%x%x%x%x%x%x$') then
    return colour
  end
  return pack.text_colours.status
end

--- Where the text of an effect starts, as `{ column, row }` in cells, for a
--- figure whose anchor is at cell column `column` and whose top is at cell
--- row `top`, the text `length` cells long.
---
---@type table<string, fun(column: integer, top: integer, length: integer): integer, integer>
local PLACES = {
  above = function(column, top, length)
    return column - math.floor((length - 1) / 2), top - 1
  end,
  above_left = function(column, top, length)
    return column - length + 1, top - 1
  end,
  above_right = function(column, top)
    return column, top - 1
  end,
  beside = function(column, top)
    return column + 1, top
  end,
}

--- Writes the effect the pose of `character` shows, if it shows one, above the
--- character's head.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param character aineo.office_scene.Character
local function write_effect(canvas, drawing, character)
  local pack = drawing.pack
  local pose = pose_of(pack, character)
  local effect = pose and pose.effect and pack.effects[pose.effect]
  if not effect then
    return
  end
  local top_pixel = feet_row_of(character)
  for _, piece in ipairs(pieces_of(pack, pose)) do
    top_pixel = math.min(top_pixel, feet_row_of(character) - piece.anchor.row)
  end
  local text = effect.text[math.floor(drawing.now / effect.seconds_per_frame) % #effect.text + 1]
  local place = PLACES[effect.place] or PLACES.above
  local column, row =
    place(round(character.column), math.floor(top_pixel / 2), vim.fn.strchars(text))
  canvas.write_text(
    column,
    row,
    text,
    { foreground = text_colour(pack, effect.colour), bold = effect.bold }
  )
end

--- The picture of the office as `drawing` describes it.
---
---@param drawing aineo.office_scene.Drawing
---@return aineo.office_scene.Picture
function M.paint(drawing)
  local canvas = canvas_module.new_canvas(drawing.width, drawing.height)
  paint_backdrop(canvas, drawing)
  paint_in_depth_order(items_of(canvas, drawing))
  for _, character in ipairs(drawing.characters) do
    write_effect(canvas, drawing, character)
  end
  return canvas.picture()
end

return M
