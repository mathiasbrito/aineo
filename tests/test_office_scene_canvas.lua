local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local office_scene = require('aineo.office_scene')

--- The row `row` of the picture of `canvas`.
---
---@param canvas aineo.office_scene.Canvas
---@param row integer from 1
---@return aineo.office_scene.PictureRow
local function row_of(canvas, row)
  return canvas.picture().rows[row]
end

local TOP = '#a6e3a1'
local BOTTOM = '#303446'

local T = MiniTest.new_set()

T['a cell with pixels'] = MiniTest.new_set()

T['a cell with pixels']['shows the top pixel as the foreground and the bottom one as the background of an upper half block'] = function()
  local canvas = office_scene.new_canvas(1, 1)
  canvas.paint_pixel(0, 0, TOP)
  canvas.paint_pixel(0, 1, BOTTOM)

  local picture = canvas.picture()

  eq(picture.rows[1].text, '▀')
  eq(picture.rows[1].runs, { { from = 0, to = 3, group = 'AineoOfficePixel_a6e3a1_303446' } })
  eq(
    picture.looks.AineoOfficePixel_a6e3a1_303446,
    { foreground = '#a6e3a1', background = '#303446' }
  )
end

T['a cell with pixels']['shows a top pixel alone as an upper half block with no background'] = function()
  local canvas = office_scene.new_canvas(1, 1)
  canvas.paint_pixel(0, 0, TOP)

  local picture = canvas.picture()

  eq(picture.rows[1].text, '▀')
  eq(picture.rows[1].runs[1].group, 'AineoOfficePixel_a6e3a1_none')
  eq(picture.looks.AineoOfficePixel_a6e3a1_none, { foreground = '#a6e3a1' })
end

T['a cell with pixels']['shows a bottom pixel alone as a lower half block with no background'] = function()
  local canvas = office_scene.new_canvas(1, 1)
  canvas.paint_pixel(0, 1, BOTTOM)

  local picture = canvas.picture()

  eq(picture.rows[1].text, '▄')
  eq(picture.rows[1].runs[1].group, 'AineoOfficePixel_303446_none')
  eq(picture.looks.AineoOfficePixel_303446_none, { foreground = '#303446' })
end

T['a cell with pixels']['stays a space with no highlight when neither pixel is set'] = function()
  local canvas = office_scene.new_canvas(2, 1)

  local picture = canvas.picture()

  eq(picture.rows[1], { text = '  ', runs = {} })
  eq(picture.looks, {})
end

T['a cell with pixels']['shows a pixel painted later over one painted before'] = function()
  local canvas = office_scene.new_canvas(1, 1)
  canvas.paint_pixel(0, 0, BOTTOM)
  canvas.paint_pixel(0, 0, TOP)

  eq(row_of(canvas, 1).runs[1].group, 'AineoOfficePixel_a6e3a1_none')
end

T['a cell with pixels']['joins neighbouring cells of one look into one run, counted in bytes'] = function()
  local canvas = office_scene.new_canvas(3, 1)
  for column = 0, 2 do
    canvas.paint_pixel(column, 0, TOP)
  end

  eq(row_of(canvas, 1).runs, { { from = 0, to = 9, group = 'AineoOfficePixel_a6e3a1_none' } })
end

T['a cell with pixels']['ends a run where the look changes, and starts one after a blank cell'] = function()
  local canvas = office_scene.new_canvas(4, 1)
  canvas.paint_pixel(0, 0, TOP)
  canvas.paint_pixel(1, 1, BOTTOM)
  canvas.paint_pixel(3, 1, BOTTOM)

  eq(row_of(canvas, 1).runs, {
    { from = 0, to = 3, group = 'AineoOfficePixel_a6e3a1_none' },
    { from = 3, to = 6, group = 'AineoOfficePixel_303446_none' },
    { from = 7, to = 10, group = 'AineoOfficePixel_303446_none' },
  })
end

T['a cell with pixels']['counts the rows of a canvas two pixels to a cell'] = function()
  local canvas = office_scene.new_canvas(1, 2)
  canvas.paint_pixel(0, 2, TOP)
  canvas.paint_pixel(0, 3, BOTTOM)

  local picture = canvas.picture()

  eq(picture.rows[1], { text = ' ', runs = {} })
  eq(picture.rows[2].text, '▀')
end

T['a cell with pixels']['ignores a pixel outside the canvas'] = function()
  local canvas = office_scene.new_canvas(1, 1)
  canvas.paint_pixel(-1, 0, TOP)
  canvas.paint_pixel(1, 0, TOP)
  canvas.paint_pixel(0, -1, TOP)
  canvas.paint_pixel(0, 2, TOP)

  eq(canvas.picture().rows[1], { text = ' ', runs = {} })
end

T['a cell with pixels']['fills every pixel with one colour'] = function()
  local canvas = office_scene.new_canvas(2, 1)

  canvas.fill(BOTTOM)

  eq(row_of(canvas, 1).runs[1].group, 'AineoOfficePixel_303446_303446')
end

T['text'] = MiniTest.new_set()

T['text']['takes the place of the pixels of its cells and shows over their colour'] = function()
  local canvas = office_scene.new_canvas(3, 1)
  canvas.paint_pixel(1, 0, TOP)
  canvas.paint_pixel(1, 1, BOTTOM)

  canvas.write_text(0, 0, 'ab', { foreground = '#ffffff' })
  local picture = canvas.picture()

  eq(picture.rows[1].text, 'ab ')
  eq(picture.rows[1].runs, {
    { from = 0, to = 1, group = 'AineoOfficeText_ffffff_none' },
    { from = 1, to = 2, group = 'AineoOfficeText_ffffff_a6e3a1' },
  })
  eq(
    picture.looks.AineoOfficeText_ffffff_a6e3a1,
    { foreground = '#ffffff', background = '#a6e3a1' }
  )
end

T['text']['takes its background from the bottom pixel when the top one is not set'] = function()
  local canvas = office_scene.new_canvas(1, 1)
  canvas.paint_pixel(0, 1, BOTTOM)

  canvas.write_text(0, 0, 'x', { foreground = '#ffffff' })

  eq(row_of(canvas, 1).runs[1].group, 'AineoOfficeText_ffffff_303446')
end

T['text']['is bold in a group of its own when asked'] = function()
  local canvas = office_scene.new_canvas(1, 1)

  canvas.write_text(0, 0, '!', { foreground = '#ffffff', bold = true })
  local picture = canvas.picture()

  eq(picture.rows[1].runs[1].group, 'AineoOfficeText_ffffff_none_bold')
  eq(picture.looks.AineoOfficeText_ffffff_none_bold, { foreground = '#ffffff', bold = true })
end

T['text']['counts a character of many bytes as one cell'] = function()
  local canvas = office_scene.new_canvas(4, 1)

  canvas.write_text(1, 0, '·∘', { foreground = '#ffffff' })
  local row = row_of(canvas, 1)

  eq(row.text, ' ·∘ ')
  eq(row.runs, { { from = 1, to = 6, group = 'AineoOfficeText_ffffff_none' } })
end

T['text']['leaves a space of the text transparent'] = function()
  local canvas = office_scene.new_canvas(3, 1)
  canvas.paint_pixel(1, 0, TOP)

  canvas.write_text(0, 0, 'a b', { foreground = '#ffffff' })

  eq(row_of(canvas, 1).text, 'a▀b')
end

T['text']['is cut where the canvas ends'] = function()
  local canvas = office_scene.new_canvas(2, 1)

  canvas.write_text(1, 0, 'abc', { foreground = '#ffffff' })
  canvas.write_text(-1, 0, 'xyz', { foreground = '#ffffff' })

  eq(row_of(canvas, 1).text, 'yz')
end

T['text']['is not drawn on a row the canvas lacks'] = function()
  local canvas = office_scene.new_canvas(2, 1)

  canvas.write_text(0, 1, 'ab', { foreground = '#ffffff' })
  canvas.write_text(0, -1, 'ab', { foreground = '#ffffff' })

  eq(row_of(canvas, 1).text, '  ')
end

T['a piece of art'] = MiniTest.new_set()

--- A piece of two columns and two rows of pixels: `Ak` over `kA`.
---@type aineo.office_pack.Piece
local PIECE = {
  name = 'tile',
  colours = { A = 'green', k = 'dark' },
  anchor = { column = 0, row = 1 },
  seconds_per_frame = 0.25,
  frames = { { 'A.', 'kA' } },
  width = 2,
  height = 2,
}

local COLOURS = { green = '#a6e3a1', dark = '#1e1e2e' }

T['a piece of art']['paints its pixels with the colours its letters name, a dot being transparent'] = function()
  local canvas = office_scene.new_canvas(2, 1)

  canvas.paint_art(PIECE, { frame = 1, column = 0, row = 1, colours = COLOURS })
  local picture = canvas.picture()

  eq(picture.rows[1].text, '▀▄')
  eq(picture.rows[1].runs, {
    { from = 0, to = 3, group = 'AineoOfficePixel_a6e3a1_1e1e2e' },
    { from = 3, to = 6, group = 'AineoOfficePixel_a6e3a1_none' },
  })
end

T['a piece of art']['puts its anchor on the pixel it is placed at'] = function()
  local canvas = office_scene.new_canvas(3, 1)

  canvas.paint_art(
    vim.tbl_extend('force', PIECE, { anchor = { column = 1, row = 1 } }),
    { frame = 1, column = 2, row = 1, colours = COLOURS }
  )

  eq(row_of(canvas, 1).text, ' ▀▄')
end

T['a piece of art']['mirrors about its anchor'] = function()
  local lean = vim.tbl_extend('force', PIECE, {
    frames = { { 'A.', 'A.' } },
    anchor = { column = 1, row = 1 },
  })
  local plain = office_scene.new_canvas(4, 1)
  local mirrored = office_scene.new_canvas(4, 1)

  plain.paint_art(lean, { frame = 1, column = 2, row = 1, colours = COLOURS })
  mirrored.paint_art(lean, { frame = 1, column = 2, row = 1, colours = COLOURS, mirrored = true })

  eq(row_of(plain, 1).text, ' ▀  ')
  eq(row_of(mirrored, 1).text, '   ▀')
end

T['a piece of art']['leaves a pixel transparent when its letter names no colour'] = function()
  local canvas = office_scene.new_canvas(2, 1)

  canvas.paint_art(PIECE, { frame = 1, column = 0, row = 1, colours = {} })

  eq(row_of(canvas, 1).text, '  ')
end

return T
