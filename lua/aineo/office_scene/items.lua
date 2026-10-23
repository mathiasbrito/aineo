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
---@field width integer cells
---@field height integer cells
---@field now number seconds

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
