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

--- The pieces stretched so far, by the piece and the width, so that a frame
--- of the office stretches nothing it stretched before. Weak in the pieces: a
--- pack that is loaded again drops the stretches of the pack it replaced.
---@type table<aineo.office_pack.Piece, table<integer, aineo.office_pack.Piece>>
local stretched_before = setmetatable({}, { __mode = 'k' })

--- `piece` stretched to `width` pixels wide; the piece itself when it does
--- not stretch or is as wide as asked, or wider. A piece stretched to a width
--- once is the same piece the next time.
---
---@param piece aineo.office_pack.Piece
---@param width integer
---@return aineo.office_pack.Piece
function M.to_width(piece, width)
  if not piece.stretch or width <= piece.width then
    return piece
  end
  stretched_before[piece] = stretched_before[piece] or {}
  local stretched = stretched_before[piece][width]
  if not stretched then
    stretched = vim.deepcopy(piece)
    stretched.frames = vim.tbl_map(function(rows)
      return vim.tbl_map(function(row)
        return stretched_row(row, piece.stretch, width)
      end, rows)
    end, piece.frames)
    stretched.width = width
    stretched_before[piece][width] = stretched
  end
  return stretched
end

return M
