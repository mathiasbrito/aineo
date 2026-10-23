--- The things the painter paints, and the order it paints them in: the
--- deeper one, the one whose base stands lower on the canvas, is in front.

local M = {}

--- What stands in front of what at the same depth: a piece laid on the floor
--- is under everything, then a character seated behind a piece, then the
--- pieces, then a character standing on them.
M.RANK = { on_the_floor = 0, seated = 1, piece = 2, standing = 3 }

---@class aineo.office_scene.Drawing
---@field pack aineo.office_pack.Pack
---@field layout aineo.office_scene.FloorLayout
---@field characters aineo.office_scene.Character[]
---@field agents aineo.office_states.Agent[] every agent, whether it has a place on the plan or not
---@field state_labels table<string, string> what the status list says of each state, in words
---@field width integer cells
---@field height integer cells, the status list's rows among them
---@field plan_height integer cells, the rows of the plan: the height less the status list's rows
---@field now number seconds
---@field wall_time? aineo.office_scene.WallTime the time on the wall outside the office; none, and the pieces that show it show their art alone

---@class aineo.office_scene.Item
---@field depth integer the pixel row it stands on; the deeper is in front
---@field rank integer which comes first at one depth (`RANK`)
---@field order? integer the order the items were made in, which breaks a tie of depth and rank
---@field paint fun() draws it

--- `value` rounded to the nearest whole number.
---
---@param value number
---@return integer
function M.round(value)
  return math.floor(value + 0.5)
end

--- The frame of `piece` showing `elapsed` seconds after it began to show.
---
---@param piece aineo.office_pack.Piece
---@param elapsed number
---@return integer frame from 1
function M.frame_after(piece, elapsed)
  return math.floor(elapsed / piece.seconds_per_frame) % #piece.frames + 1
end

--- The pixels of the plan: the whole of the picture but the rows of the status
--- list, which nothing but the list is painted on.
---
---@param drawing aineo.office_scene.Drawing
---@return aineo.office_scene.PixelArea
function M.plan_area(drawing)
  return { column = 0, row = 0, width = drawing.width, height = 2 * drawing.plan_height }
end

--- The pixels that lie in both `area` and `other`.
---
---@param area aineo.office_scene.PixelArea
---@param other aineo.office_scene.PixelArea
---@return aineo.office_scene.PixelArea
function M.common_to(area, other)
  local column = math.max(area.column, other.column)
  local row = math.max(area.row, other.row)
  return {
    column = column,
    row = row,
    width = math.max(0, math.min(area.column + area.width, other.column + other.width) - column),
    height = math.max(0, math.min(area.row + area.height, other.row + other.height) - row),
  }
end

--- Paints `items` back to front: the deeper one is in front, and at one
--- depth the one of the higher rank, and then the one made later.
---
---@param items aineo.office_scene.Item[]
function M.paint_in_depth_order(items)
  for order, item in ipairs(items) do
    item.order = order
  end
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

return M
