--- The painter of the office: draws the floor, the pieces of the plan and the
--- agents the director placed onto a canvas, back to front, and gives the
--- canvas's picture.

local canvas_module = require('aineo.office_scene.canvas')
local figures = require('aineo.office_scene.figures')
local furniture = require('aineo.office_scene.furniture')
local items = require('aineo.office_scene.items')
local status_list = require('aineo.office_scene.status_list')

local M = {}

--- The colours of the floor and the wall when a pack names none.
local DEFAULT_FLOOR_COLOUR = '#303446'
local DEFAULT_WALL_COLOUR = '#292c3c'

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

--- The picture of the office as `drawing` describes it.
---
---@param drawing aineo.office_scene.Drawing
---@return aineo.office_scene.Picture
function M.paint(drawing)
  local canvas = canvas_module.new_canvas(drawing.width, drawing.height)
  paint_backdrop(canvas, drawing)
  local to_paint = furniture.items(canvas, drawing)
  vim.list_extend(to_paint, figures.items(canvas, drawing))
  items.paint_in_depth_order(to_paint)
  figures.write_effects(canvas, drawing)
  if drawing.plan_height < drawing.height then
    status_list.paint(canvas, drawing)
  end
  local picture = canvas.picture()
  picture.status_list_height = drawing.height - drawing.plan_height
  return picture
end

return M
