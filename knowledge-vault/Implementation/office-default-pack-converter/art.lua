-- Pixel canvases of colour names and the writer of art files.
--
-- A canvas covers the rectangle `left..right` by `top..bottom` of some
-- coordinate system the caller picks (the mock's, a bean's own) and holds a
-- colour name for each pixel it paints. A piece is a list of canvases of one
-- rectangle, its frames; the writer gives each colour a letter, the same in
-- every frame, and writes the art file.

local palette = require('palette')

local M = {}

local Canvas = {}
Canvas.__index = Canvas

--- A canvas of the pixels `left..right` by `top..bottom`, all transparent.
---
---@param left integer
---@param top integer
---@param right integer
---@param bottom integer
function M.new_canvas(left, top, right, bottom)
  return setmetatable({ left = left, top = top, right = right, bottom = bottom, pixels = {} }, Canvas)
end

--- A canvas of `rows` of the mock's art, `names` giving each letter's colour
--- name; the top left pixel is at `x`, `y`.
---
---@param rows string[]
---@param names table<string, string> colour name by letter
---@param x? integer
---@param y? integer
function M.from_rows(rows, names, x, y)
  local width = 0
  for _, row in ipairs(rows) do
    width = math.max(width, #row)
  end
  x, y = x or 0, y or 0
  local canvas = M.new_canvas(x, y, x + width - 1, y + #rows - 1)
  canvas:blit(rows, names, x, y)
  return canvas
end

--- Names the colours of a mock palette: colour name by letter.
---
---@param mock_palette table<string, string> hex by letter
---@return table<string, string>
function M.names_of(mock_palette)
  local names = {}
  for letter, hex in pairs(mock_palette) do
    if type(hex) == 'string' then
      names[letter] = palette.name_of(hex)
    end
  end
  return names
end

--- Paints one pixel.
---
---@param x integer
---@param y integer
---@param name string a colour name
function Canvas:set(x, y, name)
  assert(
    x >= self.left and x <= self.right and y >= self.top and y <= self.bottom,
    ('pixel %d,%d is outside %d..%d by %d..%d'):format(
      x,
      y,
      self.left,
      self.right,
      self.top,
      self.bottom
    )
  )
  self.pixels[y] = self.pixels[y] or {}
  self.pixels[y][x] = name
end

--- The colour name of the pixel, nil when transparent.
---
---@param x integer
---@param y integer
---@return string|nil
function Canvas:get(x, y)
  return self.pixels[y] and self.pixels[y][x]
end

--- Paints `rows` of the mock's art with their top left at `x`, `y`; a `.` and
--- a letter `names` does not know are transparent. `mirrored` flips them left
--- to right within their own width.
---
---@param rows string[]
---@param names table<string, string>
---@param x integer
---@param y integer
---@param mirrored? boolean
function Canvas:blit(rows, names, x, y, mirrored)
  for row_index, row in ipairs(rows) do
    for column = 1, #row do
      local name = names[row:sub(column, column)]
      if name then
        local at = mirrored and (x + #row - column) or (x + column - 1)
        self:set(at, y + row_index - 1, name)
      end
    end
  end
end

--- Paints another canvas over this one, its pixel `x`, `y` at `dx`, `dy` further.
---
---@param other table a canvas
---@param dx? integer
---@param dy? integer
function Canvas:overlay(other, dx, dy)
  dx, dy = dx or 0, dy or 0
  for y = other.top, other.bottom do
    for x = other.left, other.right do
      local name = other:get(x, y)
      if name then
        self:set(x + dx, y + dy, name)
      end
    end
  end
end

--- A copy of the canvas.
function Canvas:copy()
  local copy = M.new_canvas(self.left, self.top, self.right, self.bottom)
  copy:overlay(self)
  return copy
end

--- The canvas flipped left to right about the column `about`.
---
---@param about integer
function Canvas:mirrored(about)
  local flipped = M.new_canvas(
    2 * about - self.right,
    self.top,
    2 * about - self.left,
    self.bottom
  )
  for y = self.top, self.bottom do
    for x = self.left, self.right do
      local name = self:get(x, y)
      if name then
        flipped:set(2 * about - x, y, name)
      end
    end
  end
  return flipped
end

--- The same pixels on a canvas that covers the given rectangle.
---
---@param left integer
---@param top integer
---@param right integer
---@param bottom integer
function Canvas:covering(left, top, right, bottom)
  local wider = M.new_canvas(left, top, right, bottom)
  wider:overlay(self)
  return wider
end

--- Whether no pixel is painted.
function Canvas:is_empty()
  for _, row in pairs(self.pixels) do
    if next(row) then
      return false
    end
  end
  return true
end

local LETTER_POOL = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

--- A letter for each colour name the frames use, mnemonic where the name has
--- one, in the order the colours first appear.
---
---@param frames table[]
---@return table<string, string> letter by colour name
---@return string[] names in the order of their letters
local function letters_for(frames)
  local order, seen = {}, {}
  for _, frame in ipairs(frames) do
    for y = frame.top, frame.bottom do
      for x = frame.left, frame.right do
        local name = frame:get(x, y)
        if name and not seen[name] then
          seen[name] = true
          table.insert(order, name)
        end
      end
    end
  end
  local letter_of, taken = {}, {}
  for _, name in ipairs(order) do
    local wanted = palette.MNEMONIC[name]
    if wanted and not taken[wanted] then
      letter_of[name], taken[wanted] = wanted, true
    end
  end
  local pool_index = 1
  for _, name in ipairs(order) do
    if not letter_of[name] then
      local letter
      repeat
        letter = LETTER_POOL:sub(pool_index, pool_index)
        pool_index = pool_index + 1
      until not taken[letter]
      letter_of[name], taken[letter] = letter, true
    end
  end
  return letter_of, order
end

---@class converter.Piece
---@field about string
---@field frames table[] canvases of one rectangle
---@field anchor? { [1]: integer, [2]: integer } the pixel that stands on the cell, in the coordinates of the canvases
---@field faces? string
---@field stretch? { [1]: integer, [2]: integer } the columns that repeat, from 1, in the art
---@field areas? table<string, { [1]: integer, [2]: integer, [3]: integer, [4]: integer }> column, row, width, height in the coordinates of the canvases
---@field seconds_per_frame? number

--- The text of the art file of `piece`.
---
---@param piece converter.Piece
---@return string
function M.text_of(piece)
  local first = piece.frames[1]
  local left, top = first.left, first.top
  local width, height = first.right - left + 1, first.bottom - top + 1
  for _, frame in ipairs(piece.frames) do
    assert(
      frame.left == left and frame.top == top and frame.right == first.right and frame.bottom == first.bottom,
      'the frames of a piece cover different rectangles: ' .. piece.about
    )
  end
  local letter_of, order = letters_for(piece.frames)
  local colours = {}
  for _, name in ipairs(order) do
    table.insert(colours, ('%s = %s'):format(letter_of[name], name))
  end
  table.sort(colours)
  local lines = { 'about: ' .. piece.about }
  if #colours > 0 then
    table.insert(lines, 'colours: ' .. table.concat(colours, ', '))
  else
    table.insert(lines, 'colours: B = agent')
  end
  local anchor = piece.anchor or { left, first.bottom }
  local anchor_column, anchor_row = anchor[1] - left, anchor[2] - top
  assert(
    anchor_column >= 0 and anchor_column < width and anchor_row >= 0 and anchor_row < height,
    ('the anchor of “%s” lies outside the art (%d, %d of %d x %d)'):format(
      piece.about,
      anchor_column,
      anchor_row,
      width,
      height
    )
  )
  table.insert(lines, ('anchor: %d, %d'):format(anchor_column, anchor_row))
  if piece.faces then
    table.insert(lines, 'faces: ' .. piece.faces)
  end
  if piece.stretch then
    table.insert(lines, ('stretch: columns %d-%d'):format(piece.stretch[1], piece.stretch[2]))
  end
  local area_names = vim.tbl_keys(piece.areas or {})
  table.sort(area_names)
  for _, name in ipairs(area_names) do
    local area = piece.areas[name]
    assert(
      area[1] - left >= 0
        and area[2] - top >= 0
        and area[1] - left + area[3] <= width
        and area[2] - top + area[4] <= height,
      ('the area %s of “%s” lies outside the art'):format(name, piece.about)
    )
    table.insert(
      lines,
      ('area %s: %d, %d, %d x %d'):format(name, area[1] - left, area[2] - top, area[3], area[4])
    )
  end
  if piece.seconds_per_frame then
    table.insert(lines, ('seconds per frame: %s'):format(('%.4g'):format(piece.seconds_per_frame)))
  end
  table.insert(lines, '---')
  for index, frame in ipairs(piece.frames) do
    if index > 1 then
      table.insert(lines, '---')
    end
    for y = top, first.bottom do
      local cells = {}
      for x = left, first.right do
        local name = frame:get(x, y)
        cells[#cells + 1] = name and letter_of[name] or '.'
      end
      table.insert(lines, table.concat(cells))
    end
  end
  return table.concat(lines, '\n') .. '\n'
end

return M
