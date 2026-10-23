--- The agents the director placed, as items to paint: each in the pose it
--- holds, its layers of art bottom first and mirrored together to face the
--- way it faces, rising when its pose rises, holding the prop its pose gives
--- it, and the effect its pose or its step shows above its head.

local colours = require('aineo.office_scene.colours')
local items = require('aineo.office_scene.items')
local poses = require('aineo.office_scene.poses')

local M = {}

--- The pieces of art a pose draws that the pack has, bottom first.
---
---@param pack aineo.office_pack.Pack
---@param pose aineo.office_pack.Pose
---@return aineo.office_pack.Piece[]
local function layers_of(pack, pose)
  local layers = {}
  for _, name in ipairs(pose.art or {}) do
    table.insert(layers, pack.pieces[name])
  end
  return layers
end

--- The pixel row `character`'s feet are on: the bottom of its cell.
---
---@param character aineo.office_scene.Character
---@return integer
local function feet_row_of(character)
  return 2 * items.round(character.row) + 1
end

--- The colours the art of the agent in its place names: the pack's, and the
--- agent's own and its shades.
---
---@param pack aineo.office_pack.Pack
---@param character aineo.office_scene.Character
---@return table<string, string>
local function art_colours(pack, character)
  local own = colours.of_agent(pack[character.kind].colours, character.colour_index)
  return vim.tbl_extend('force', pack.colours, colours.agent_shades(own))
end

--- How many pixels the pose lifts `character` at `now`: the number of its
--- `rises` for the frame of the pose's first layer, counted from when the
--- character took the pose.
---
---@param pose aineo.office_pack.Pose
---@param layers aineo.office_pack.Piece[]
---@param character aineo.office_scene.Character
---@param now number
---@return integer
local function rise_of(pose, layers, character, now)
  if not (pose.rises and layers[1]) then
    return 0
  end
  local frame = math.floor((now - character.pose_since) / layers[1].seconds_per_frame)
  return items.round(pose.rises[frame % #pose.rises + 1])
end

--- Whether a piece of art is drawn mirrored for an agent that faces left, or
--- not: art is mirrored when the agent faces the other way than it does.
---
---@param facing_left boolean
---@param piece aineo.office_pack.Piece
---@return boolean
local function is_mirrored(facing_left, piece)
  return facing_left ~= (piece.faces == 'left')
end

--- Paints the prop the pose holds at the hand area of the first layer that
--- has one, mirrored with the layers when the character faces left.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param pose aineo.office_pack.Pose
---@param layers aineo.office_pack.Piece[]
---@param placement { column: integer, row: integer, colours: table<string, string>, facing_left: boolean } where the layers are painted: the pixel their anchors stand on, and the way the agent faces
local function paint_prop(canvas, drawing, pose, layers, placement)
  local prop = pose.holding and drawing.pack.pieces[pose.holding]
  local layer = vim.iter(layers):find(function(candidate)
    return candidate.areas.hand ~= nil
  end)
  if not (prop and layer) then
    return
  end
  local hand = layer.areas.hand
  local across = hand.column - layer.anchor.column
  local layer_mirrored = is_mirrored(placement.facing_left, layer)
  local column = layer_mirrored and placement.column - across or placement.column + across
  canvas.paint_art(prop, {
    frame = 1,
    column = column,
    row = placement.row - layer.anchor.row + hand.row,
    colours = placement.colours,
    mirrored = is_mirrored(placement.facing_left, prop),
    clip = items.plan_area(drawing),
  })
end

--- The item that paints `character` in its pose.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param character aineo.office_scene.Character
---@param pose aineo.office_pack.Pose
---@return aineo.office_scene.Item
local function item_of(canvas, drawing, character, pose)
  local layers = layers_of(drawing.pack, pose)
  local elapsed = math.max(0, drawing.now - character.pose_since)
  local feet_row = feet_row_of(character)
  return {
    depth = feet_row,
    rank = (pose.sitting or character.at_a_seat) and items.RANK.seated or items.RANK.standing,
    paint = function()
      local lift = rise_of(pose, layers, character, drawing.now)
      local colours_named = art_colours(drawing.pack, character)
      local facing_left = character.facing == 'left'
      for _, layer in ipairs(layers) do
        canvas.paint_art(layer, {
          frame = items.frame_after(layer, elapsed),
          column = items.round(character.column),
          row = feet_row - lift,
          colours = colours_named,
          mirrored = is_mirrored(facing_left, layer),
          clip = items.plan_area(drawing),
        })
      end
      paint_prop(canvas, drawing, pose, layers, {
        column = items.round(character.column),
        row = feet_row - lift,
        colours = colours_named,
        facing_left = facing_left,
      })
    end,
  }
end

--- The items for the agents the director placed, each in the pose it holds.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@return aineo.office_scene.Item[]
function M.items(canvas, drawing)
  local made = {}
  for _, character in ipairs(drawing.characters) do
    local pose = poses.of(drawing.pack, character)
    if pose then
      table.insert(made, item_of(canvas, drawing, character, pose))
    end
  end
  return made
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

--- Writes the effect the pose or the step of `character` shows, if it shows
--- one, above the character's head.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
---@param character aineo.office_scene.Character
local function write_effect(canvas, drawing, character)
  local pack = drawing.pack
  local pose = poses.of(pack, character)
  local effect_name = character.effect or (pose and pose.effect)
  local effect = effect_name and pack.effects[effect_name]
  if not (pose and effect) then
    return
  end
  local layers = layers_of(pack, pose)
  local feet_row = feet_row_of(character) - rise_of(pose, layers, character, drawing.now)
  local top_pixel = feet_row
  for _, layer in ipairs(layers) do
    top_pixel = math.min(top_pixel, feet_row - layer.anchor.row)
  end
  local elapsed = math.max(0, drawing.now - character.pose_since)
  local text = effect.text[math.floor(elapsed / effect.seconds_per_frame) % #effect.text + 1]
  local place = PLACES[effect.place] or PLACES.above
  local column, row =
    place(items.round(character.column), math.floor(top_pixel / 2), #vim.str_utf_pos(text))
  if row >= drawing.plan_height then
    return
  end
  canvas.write_text(
    column,
    row,
    text,
    { foreground = text_colour(pack, effect.colour), bold = effect.bold }
  )
end

--- Writes the effect each agent shows.
---
---@param canvas aineo.office_scene.Canvas
---@param drawing aineo.office_scene.Drawing
function M.write_effects(canvas, drawing)
  for _, character in ipairs(drawing.characters) do
    write_effect(canvas, drawing, character)
  end
end

return M
