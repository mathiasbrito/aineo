--- What the office shows in a window too small for its scene: one line saying
--- so.

local text = require('aineo.office.text')

local M = {}

--- The smallest window the office draws its scene in, in cells.
M.SMALLEST_WIDTH = 60
M.SMALLEST_HEIGHT = 24

--- What the line says.
local SENTENCE = ('This window is too small for the office: it needs %d by %d cells.'):format(
  M.SMALLEST_WIDTH,
  M.SMALLEST_HEIGHT
)

--- Whether a window of `width` by `height` cells is too small for the
--- office's scene.
---
---@param width integer
---@param height integer
---@return boolean
function M.holds(width, height)
  return width < M.SMALLEST_WIDTH or height < M.SMALLEST_HEIGHT
end

--- The picture of a window of `width` by `height` cells too small for the
--- scene: its first row says so, cut to the width; the others are empty.
---
---@param width integer
---@param height integer
---@return aineo.office_scene.Picture
function M.picture(width, height)
  local rows = {}
  for index = 1, height do
    rows[index] = { text = index == 1 and text.cut_to_cells(SENTENCE, width) or '', runs = {} }
  end
  return { rows = rows, looks = {} }
end

return M
