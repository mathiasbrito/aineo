--- What a plan may place: the pieces of a plan that a frame can afford. A plan
--- places at most `MOST_PLACEMENTS` pieces, and the pieces together paint at
--- most `MOST_PIXELS_IN_STAGES` times the pixels of the plan's area, so that
--- a pack with a piece in every cell, or with art as large as the format
--- allows, cannot make a frame costly.
---
--- When a plan places more, the pieces that matter least go first: first the
--- decorations, then the furniture, last the pieces that stand on a spot, show
--- something or have art for when they are in use; within a kind, the pieces
--- the plan reads last.

local M = {}

--- How many pieces a plan places at most.
local MOST_PLACEMENTS = 2000

--- How many times the pixels of the plan's area the pieces of a plan may
--- paint, together.
local MOST_PIXELS_IN_STAGES = 16

--- What kind of piece goes first and what goes last.
local DECORATION, FURNITURE, ESSENTIAL = 1, 2, 3

--- The pixels of `piece`, placed as `placed`, that lie on an area of `width`
--- cells by `height` rows.
---
---@param placed aineo.office_scene.PlacedPiece
---@param piece aineo.office_pack.Piece
---@param width integer
---@param height integer
---@return integer
local function pixels_on_the_area(placed, piece, width, height)
  local left = placed.column - piece.anchor.column
  local top = 2 * placed.row + 1 - piece.anchor.row
  local across = math.min(width, left + math.max(piece.width, placed.columns or 0))
    - math.max(0, left)
  local down = math.min(2 * height, top + piece.height) - math.max(0, top)
  return math.max(0, across) * math.max(0, down)
end

--- How much a placed piece matters: the pieces a character uses, or that
--- show something, matter most, a decoration least, whatever it shows.
---
---@param placed aineo.office_scene.PlacedPiece
---@param piece aineo.office_pack.Piece|nil
---@return integer kind `DECORATION`, `FURNITURE` or `ESSENTIAL`
local function kind_of(placed, piece)
  if placed.decoration then
    return DECORATION
  end
  if placed.in_use or placed.shows or placed.on_a_spot or (piece and piece.areas.screen) then
    return ESSENTIAL
  end
  return FURNITURE
end

--- The pieces of `pieces` the plan may place on an area of `width` cells by
--- `height` rows, in the order they were given, and how many were left out.
---
---@param pieces aineo.office_scene.PlacedPiece[] in the order the plan reads
---@param pack aineo.office_pack.Pack
---@param width integer
---@param height integer
---@return aineo.office_scene.PlacedPiece[] kept
---@return integer left_out
function M.afford(pieces, pack, width, height)
  local costs, total = {}, 0
  for index, placed in ipairs(pieces) do
    local piece = pack.pieces[placed.piece]
    costs[index] = piece and pixels_on_the_area(placed, piece, width, height) or 0
    total = total + costs[index]
  end
  local budget = MOST_PIXELS_IN_STAGES * width * 2 * height
  if #pieces <= MOST_PLACEMENTS and total <= budget then
    return pieces, 0
  end

  local by_kind = { {}, {}, {} }
  for index, placed in ipairs(pieces) do
    table.insert(by_kind[kind_of(placed, pack.pieces[placed.piece])], index)
  end
  local count, left_out = #pieces, {}
  for _, indices in ipairs(by_kind) do
    for position = #indices, 1, -1 do
      local index = indices[position]
      if count > MOST_PLACEMENTS or total > budget then
        left_out[index] = true
        count, total = count - 1, total - costs[index]
      end
    end
  end

  local kept = {}
  for index, placed in ipairs(pieces) do
    if not left_out[index] then
      table.insert(kept, placed)
    end
  end
  return kept, #pieces - #kept
end

return M
