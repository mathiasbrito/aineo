--- Stretching a piece of art to a width: the columns its `stretch` header
--- names repeat until the piece is as wide as asked.

local M = {}

--- `row` stretched to `width` pixels: the columns before the stretch, the
--- stretched columns repeated as many times as needed and cut, and the
--- columns after it.
---
---@param row string
---@param stretch aineo.office_pack.Stretch
---@param width integer
---@return string
local function stretched_row(row, stretch, width)
  local before = row:sub(1, stretch.first - 1)
  local repeating = row:sub(stretch.first, stretch.last)
  local after = row:sub(stretch.last + 1)
  local room = width - #before - #after
  return before .. repeating:rep(math.ceil(room / #repeating)):sub(1, room) .. after
end

--- `piece` stretched to `width` pixels wide; the piece itself when it does
--- not stretch or is as wide as asked, or wider.
---
---@param piece aineo.office_pack.Piece
---@param width integer
---@return aineo.office_pack.Piece
function M.to_width(piece, width)
  if not piece.stretch or width <= piece.width then
    return piece
  end
  local stretched = vim.deepcopy(piece)
  stretched.frames = vim.tbl_map(function(rows)
    return vim.tbl_map(function(row)
      return stretched_row(row, piece.stretch, width)
    end, rows)
  end, piece.frames)
  stretched.width = width
  return stretched
end

return M
