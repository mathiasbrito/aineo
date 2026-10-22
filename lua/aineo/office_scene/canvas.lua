--- The canvas of the office: a grid of cells, each holding two square pixels
--- one above the other, and text drawn over the cells.
---
--- A cell with a pixel is drawn as a half block: an upper half block `▀` with
--- the top pixel as the foreground and the bottom pixel as the background, or
--- a lower half block `▄` when only the bottom pixel is set. A cell with text
--- shows the character over the pixels beneath it. Pure: it makes the rows of
--- text and the runs of highlight a window shows, and names each highlight by
--- its colours; making the highlight groups is the window's.

local M = {}

local UPPER_HALF_BLOCK = '▀'
local LOWER_HALF_BLOCK = '▄'
local BLANK = ' '

--- The colour of nothing in a highlight group's name.
local NO_COLOUR = 'none'

--- How a highlight is made: its colours as `#rrggbb`.
---@class aineo.office_scene.Look
---@field foreground string
---@field background? string
---@field bold? boolean

--- The text of one row of the picture and the highlight of its parts.
---@class aineo.office_scene.PictureRow
---@field text string
---@field runs aineo.office_scene.Run[] in order, none touching another of the same group

--- A stretch of a row drawn in one highlight group.
---@class aineo.office_scene.Run
---@field from integer the first byte of the row's text, from 0
---@field to integer the byte after the last
---@field group string the highlight group's name; `Picture.looks` says how it is made

--- What the canvas shows.
---@class aineo.office_scene.Picture
---@field rows aineo.office_scene.PictureRow[] from the top
---@field looks table<string, aineo.office_scene.Look> every group a run uses

---@class aineo.office_scene.TextStyle
---@field foreground string `#rrggbb`
---@field bold? boolean

--- Where and how a piece of art is painted.
---@class aineo.office_scene.Placement
---@field frame integer which frame of the piece, from 1
---@field column integer the pixel column the piece's anchor stands on
---@field row integer the pixel row the piece's anchor stands on
---@field colours table<string, string> `#rrggbb` by the colour names the piece's letters stand for
---@field mirrored? boolean drawn facing the other way, about the anchor

---@class aineo.office_scene.Canvas
---@field paint_pixel fun(column: integer, row: integer, colour: string) paints the pixel at a pixel column and row, from 0; outside the canvas it paints nothing
---@field paint_art fun(piece: aineo.office_pack.Piece, placement: aineo.office_scene.Placement) paints a frame of a piece; `.` is transparent, and so is a letter whose colour is not in `placement.colours`
---@field write_text fun(column: integer, row: integer, text: string, style: aineo.office_scene.TextStyle) writes text from a cell column and row, from 0, one cell to a character; spaces leave what is there
---@field fill fun(colour: string) paints every pixel
---@field picture fun(): aineo.office_scene.Picture

--- The colour without its `#`, for a group's name.
---
---@param colour string `#rrggbb`
---@return string
local function digits(colour)
  return colour:sub(2)
end

--- The characters of `text`, one entry each, whatever their bytes.
---
---@param text string
---@return string[]
local function characters_of(text)
  local starts = vim.str_utf_pos(text)
  local characters = {}
  for index, start in ipairs(starts) do
    characters[index] = text:sub(start, (starts[index + 1] or #text + 1) - 1)
  end
  return characters
end

--- The glyph and look a cell with pixels is drawn as.
---
---@param top string|nil
---@param bottom string|nil
---@return string glyph
---@return aineo.office_scene.Look|nil look nil for a cell with no pixel
local function half_block(top, bottom)
  if top then
    return UPPER_HALF_BLOCK, { foreground = top, background = bottom }
  elseif bottom then
    return LOWER_HALF_BLOCK, { foreground = bottom }
  end
  return BLANK, nil
end

--- The name of the highlight group that draws `look` as a pixel.
---
---@param look aineo.office_scene.Look
---@return string
local function pixel_group(look)
  return ('AineoOfficePixel_%s_%s'):format(
    digits(look.foreground),
    look.background and digits(look.background) or NO_COLOUR
  )
end

--- The name of the highlight group that draws `look` as text.
---
---@param look aineo.office_scene.Look
---@return string
local function text_group(look)
  return ('AineoOfficeText_%s_%s%s'):format(
    digits(look.foreground),
    look.background and digits(look.background) or NO_COLOUR,
    look.bold and '_bold' or ''
  )
end

--- A canvas of `width` by `height` cells, with no pixel and no text.
---
---@param width integer cells
---@param height integer cells, twice as many pixel rows
---@return aineo.office_scene.Canvas
function M.new_canvas(width, height)
  ---@type table<integer, table<integer, string>>
  local pixels = {}
  for row = 0, 2 * height - 1 do
    pixels[row] = {}
  end
  ---@type table<integer, table<integer, { character: string, look: aineo.office_scene.Look }>>
  local texts = {}
  for row = 0, height - 1 do
    texts[row] = {}
  end

  local canvas = {}

  function canvas.paint_pixel(column, row, colour)
    if column >= 0 and column < width and row >= 0 and row < 2 * height then
      pixels[row][column] = colour
    end
  end

  function canvas.paint_art(piece, placement)
    local left = placement.mirrored and placement.column + piece.anchor.column
      or placement.column - piece.anchor.column
    local top = placement.row - piece.anchor.row
    for row_index, art_row in ipairs(piece.frames[placement.frame]) do
      for column_index = 1, #art_row do
        local colour = placement.colours[piece.colours[art_row:sub(column_index, column_index)]]
        if colour then
          local offset = column_index - 1
          canvas.paint_pixel(
            placement.mirrored and left - offset or left + offset,
            top + row_index - 1,
            colour
          )
        end
      end
    end
  end

  function canvas.write_text(column, row, text, style)
    if row < 0 or row >= height then
      return
    end
    for index, character in ipairs(characters_of(text)) do
      local target = column + index - 1
      if character ~= BLANK and target >= 0 and target < width then
        texts[row][target] = {
          character = character,
          look = { foreground = style.foreground, bold = style.bold },
        }
      end
    end
  end

  function canvas.fill(colour)
    for row = 0, 2 * height - 1 do
      for column = 0, width - 1 do
        pixels[row][column] = colour
      end
    end
  end

  --- The glyph of the cell and the group that draws it, registering the look
  --- of the group in `looks`.
  ---
  ---@param column integer
  ---@param row integer
  ---@param looks table<string, aineo.office_scene.Look>
  ---@return string glyph
  ---@return string|nil group
  local function cell(column, row, looks)
    local top, bottom = pixels[2 * row][column], pixels[2 * row + 1][column]
    local text = texts[row][column]
    if text then
      local look =
        { foreground = text.look.foreground, background = top or bottom, bold = text.look.bold }
      local group = text_group(look)
      looks[group] = look
      return text.character, group
    end
    local glyph, look = half_block(top, bottom)
    if not look then
      return glyph, nil
    end
    local group = pixel_group(look)
    looks[group] = look
    return glyph, group
  end

  function canvas.picture()
    local rows = {}
    local looks = {}
    for row = 0, height - 1 do
      local parts, runs, byte = {}, {}, 0
      local open_run = nil
      for column = 0, width - 1 do
        local glyph, group = cell(column, row, looks)
        if open_run and open_run.group ~= group then
          open_run.to = byte
          open_run = nil
        end
        if group and not open_run then
          open_run = { from = byte, to = byte, group = group }
          table.insert(runs, open_run)
        end
        table.insert(parts, glyph)
        byte = byte + #glyph
        if open_run then
          open_run.to = byte
        end
      end
      rows[row + 1] = { text = table.concat(parts), runs = runs }
    end
    return { rows = rows, looks = looks }
  end

  return canvas
end

return M
