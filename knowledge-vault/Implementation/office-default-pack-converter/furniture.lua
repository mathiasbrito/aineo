-- The furniture and the decoration: pieces converted from the mock's sprite
-- tables, each placed in the mock's pixel coordinates (x from the piece's left
-- column, y from the top of the office) and then given the anchor that puts it
-- where the mock drew it when the plan places it on a cell row.
--
-- A cell row `r` has its bottom pixel at `2 * r + 1`, and a piece stands with
-- its anchor pixel there. A piece the mock stood on the baseboard (its feet at
-- pixel 27) is placed on row 12 and its last two rows hang over the row below,
-- where the aisle is.

local art = require('art')
local palette = require('palette')

local M = {}

--- The pixel row the anchor of a piece placed on cell row `row` stands on.
---
---@param row integer
---@return integer
local function pixel_row_of(row)
  return 2 * row + 1
end

--- Finishes a piece for a plan that places it on the cell row `row`: its
--- anchor on that row's bottom pixel, the art lengthened with transparent rows
--- when the anchor is below it.
---
---@param piece converter.Piece
---@param row integer
---@param anchor_x? integer the column of the anchor, the art's left by default
---@return converter.Piece
local function placed_on_row(piece, row, anchor_x)
  local anchor_y = pixel_row_of(row)
  local first = piece.frames[1]
  assert(anchor_y >= first.top, 'the piece starts below the row: ' .. piece.about)
  if anchor_y > first.bottom then
    for index, frame in ipairs(piece.frames) do
      piece.frames[index] = frame:covering(frame.left, frame.top, frame.right, anchor_y)
    end
  end
  piece.anchor = { anchor_x or piece.frames[1].left, anchor_y }
  return piece
end

--- A piece of one frame from the mock's rows, its top left at `x`, `y`.
---
---@param about string
---@param rows string[]
---@param mock_palette table<string, string>
---@param y integer
---@param x? integer
---@return converter.Piece
local function from_mock(about, rows, mock_palette, y, x)
  return { about = about, frames = { art.from_rows(rows, art.names_of(mock_palette), x or 0, y) } }
end

--- `frame` with `rows` of the mock painted over it at `x`, `y`.
---
---@param frame table a canvas
---@param rows string[]
---@param mock_palette table<string, string>
---@param x integer
---@param y integer
---@param mirrored? boolean
local function paint(frame, rows, mock_palette, x, y, mirrored)
  frame:blit(rows, art.names_of(mock_palette), x, y, mirrored)
end

--- The columns of empty art a piece that is used from a spot beside it has on
--- the side of the spot, so that the spot lies within the piece's columns and
--- is the nearest spot to the piece: the scene shows a piece's `in_use` art
--- while a character stands on the spot nearest to it.
local SPOT_SIDE = 7

--- `piece` with `SPOT_SIDE` empty columns added on its left, the anchor still
--- on the piece's own left column.
---
---@param piece converter.Piece
---@return converter.Piece
local function with_the_spot_side(piece)
  for index, frame in ipairs(piece.frames) do
    piece.frames[index] = frame:covering(math.min(frame.left, 0) - SPOT_SIDE, frame.top, frame.right, frame.bottom)
  end
  return piece
end

--- The pieces of the furniture, by name.
---
---@param sprites table the mock's sprites module
---@return table<string, converter.Piece>
function M.pieces(sprites)
  local pieces = {}

  -- The wall's fixtures, standing on the baseboard.
  pieces.door = placed_on_row(
    from_mock('The office door, closed.', sprites.door_closed, sprites.DOOR_PAL, 4),
    12
  )
  pieces.door_open = placed_on_row(
    from_mock(
      'The office door, open: the hall dark, the light spilling on the floor. Shown while someone is at the door.',
      sprites.door_open,
      sprites.DOOR_PAL,
      4
    ),
    12
  )

  local board_width = 26
  local board = from_mock(
    'The whiteboard. The session\'s tasks are written in its plan area.',
    sprites.whiteboard(board_width),
    sprites.BOARD_PAL,
    4
  )
  board.stretch = { 15, 16 }
  board.areas = { plan = { 2, 6, board_width - 4, 10 } }
  pieces.whiteboard = placed_on_row(board, 9)

  pieces.file_cabinet = placed_on_row(
    with_the_spot_side(
      from_mock('A tall file cabinet, four drawers.', sprites.cabinet, sprites.CABINET_PAL, 4)
    ),
    12,
    0
  )
  local cabinet_open = {
    about = 'The file cabinet with one drawer pulled out, each drawer in turn.',
    frames = {},
    seconds_per_frame = 1,
  }
  for drawer = 1, 4 do
    local frame = art.new_canvas(-1, 4, 14, 27)
    paint(frame, sprites.cabinet, sprites.CABINET_PAL, 0, 4)
    paint(frame, sprites.drawer_open, sprites.CABINET_PAL, -1, 4 + sprites.drawer_row(drawer))
    cabinet_open.frames[drawer] = frame
  end
  pieces.file_cabinet_open = placed_on_row(with_the_spot_side(cabinet_open), 12, 0)

  pieces.trash_bin = placed_on_row(
    from_mock('A waste bin.', sprites.bin, sprites.BIN_PAL, 21),
    12
  )

  pieces.coffee_machine = (function()
    local piece = {
      about = 'The coffee machine, its light blinking green while it waits.',
      frames = {},
      seconds_per_frame = 0.5,
    }
    for index = 1, 2 do
      local frame = art.new_canvas(0, 2, 17, 27)
      paint(frame, sprites.coffee_machine, sprites.COFFEE_PAL, 0, 2)
      paint(frame, sprites.coffee_display(nil, (index - 1) * 6), sprites.COFFEE_PAL, 3, 10)
      piece.frames[index] = frame
    end
    return placed_on_row(with_the_spot_side(piece), 12, 0)
  end)()
  pieces.coffee_machine_brewing = (function()
    local ticks = 31
    local piece = {
      about = 'The coffee machine brewing a cup: the bar fills, the coffee pours, the cup steams.',
      frames = {},
      seconds_per_frame = 1 / 12,
    }
    for tick = 0, ticks - 1 do
      local frame = art.new_canvas(0, 2, 17, 27)
      paint(frame, sprites.coffee_machine, sprites.COFFEE_PAL, 0, 2)
      local progress = math.min(1, tick / (ticks - 8))
      paint(frame, sprites.coffee_display(progress, tick), sprites.COFFEE_PAL, 3, 10)
      paint(frame, sprites.coffee_cup, sprites.COFFEE_PAL, 7, 18)
      if tick >= 4 and tick < ticks - 8 then
        paint(frame, sprites.coffee_stream(tick), sprites.COFFEE_PAL, 8, 16)
      elseif tick >= ticks - 8 then
        paint(frame, sprites.steam_px(tick), sprites.COFFEE_PAL, 8, 15)
      end
      piece.frames[#piece.frames + 1] = frame
    end
    return placed_on_row(with_the_spot_side(piece), 12, 0)
  end)()

  local printer = from_mock(
    'A printer on a stand; a page comes out of it when an agent reports.',
    sprites.printer,
    sprites.PRINTER_PAL,
    14
  )
  printer.areas = { page = { 3, 19, 8, 4 } }
  pieces.printer = placed_on_row(printer, 12)
  pieces.printed_page = {
    about = 'The page the printer prints, drawn from the top of its page area.',
    frames = { art.from_rows(sprites.printer_page(1), art.names_of(sprites.PROP2_PAL), 0, 0) },
    anchor = { 0, 0 },
  }

  local desk =
    from_mock('A desk; the agent sits behind it.', sprites.desk26, sprites.FURNITURE, 39)
  desk.areas = { name = { 3, 42, 20, 2 } }
  pieces.desk = placed_on_row(desk, 20)

  local monitor = from_mock(
    'A monitor on a desk. Its owner\'s pose gives its screen; a web search writes its clue in the query area.',
    sprites.monitor,
    sprites.FURNITURE,
    31
  )
  monitor.areas = { screen = { 1, 32, 10, 4 }, query = { 1, 32, 10, 2 } }
  pieces.monitor = placed_on_row(monitor, 19)

  -- The lounge: the three-seat sofa in two parts, so that agents sit between
  -- them, the rug, the low table and the floor lamp.
  pieces.sofa_back = placed_on_row(
    from_mock('The back of a three-seat sofa, behind the agents who sit on it.', sprites.sofa3_back, sprites.SOFA_PAL, 28),
    19
  )
  pieces.sofa_front = placed_on_row(
    from_mock('The arms and seat of a three-seat sofa, in front of the agents who sit on it.', sprites.sofa3_front, sprites.SOFA_PAL, 28),
    21
  )
  local rug = from_mock('A rug under a lounge, walked over.', sprites.rug(50), sprites.RUG_PAL, 40)
  rug.stretch = { 5, 8 }
  pieces.rug = placed_on_row(rug, 22)
  pieces.low_table = placed_on_row(
    from_mock('A low table in front of a sofa.', sprites.low_table_wide, sprites.TABLE_PAL, 40),
    22
  )
  pieces.floor_lamp = placed_on_row(
    from_mock('A floor lamp.', sprites.floor_lamp, sprites.FLOOR_LAMP_PAL, 23),
    21
  )
  pieces.ceiling_lamp = placed_on_row(
    from_mock('A lamp hung from the top of the wall.', sprites.ceiling_lamp, sprites.LAMP_PAL, 2),
    2
  )

  pieces.corner_plant = placed_on_row(
    from_mock('A plant in a pot, in the corner.', sprites.plant, sprites.FURNITURE, 16),
    12
  )

  -- The wall clock shows the time as text, and the calendar the date.
  local clock = art.new_canvas(0, 7, 8, 15)
  for y = 0, 8 do
    for x = 0, 8 do
      local distance = math.sqrt((x - 4) ^ 2 + (y - 4) ^ 2)
      if distance <= 4.6 then
        clock:set(x, 7 + y, distance > 3.9 and 'steel' or 'ink')
      end
    end
  end
  pieces.wall_clock = placed_on_row({
    about = 'A wall clock; the time is written in its time area.',
    frames = { clock },
    areas = { time = { 2, 10, 5, 2 } },
  }, 7)
  palette.name_of('585b70')
  palette.name_of('1e1e2e')

  local calendar = from_mock(
    'A wall calendar; the date is written in its date area.',
    sprites.calendar,
    { R = '#e64553', k = '#1e1e2e', w = '#303446', g = '#303446' },
    4
  )
  calendar.areas = { date = { 1, 8, 6, 2 } }
  pieces.wall_calendar = placed_on_row(calendar, 6)

  return pieces
end

--- The padding on each side of a decoration, so that decorations a plan places
--- side by side keep their distance, and the agent that goes to one stands in
--- front of its middle.
M.DECORATION_PADDING = 4

--- A decoration: the mock's rows with transparent padding on both sides, its
--- anchor at the middle, placed on cell row 8.
---
---@param piece converter.Piece one whose canvases cover the art, unpadded
---@return converter.Piece
local function as_decoration(piece)
  local first = piece.frames[1]
  local padding = M.DECORATION_PADDING
  local width = first.right - first.left + 1
  for index, frame in ipairs(piece.frames) do
    piece.frames[index] =
      frame:covering(frame.left - padding, frame.top, frame.right + padding, frame.bottom)
  end
  piece.areas = piece.areas or {}
  return placed_on_row(piece, 8, first.left + math.floor(width / 2))
end

--- The window's width: its frame has no padding, so that the window stands
--- where the wall's fixed window did, and its anchor is at its middle.
local WINDOW_WIDTH = 24

--- The decorations of the wall, by name.
---
---@param sprites table
---@return table<string, converter.Piece>
function M.decorations(sprites)
  local pieces = {}

  -- The window's frame, 24 wide, the first of the decorations; the sky it
  -- shows is the pack's own pieces, painted into the glass.
  local frame = art.new_canvas(0, 5, WINDOW_WIDTH - 1, 16)
  for y = 5, 16 do
    for x = 0, WINDOW_WIDTH - 1 do
      if y == 5 or y == 16 or x == 0 or x == WINDOW_WIDTH - 1 then
        frame:set(x, y, 'slate')
      else
        frame:set(x, y, 'night_low')
      end
    end
  end
  palette.name_of('6c7086')
  palette.name_of('1e2a4a')
  pieces.window = placed_on_row({
    about = 'A window; the sky outside follows the time of day (sky_night, sky_dawn, sky_day, sky_dusk).',
    frames = { frame },
    areas = { sky = { 1, 6, 22, 10 } },
  }, 8, math.floor(WINDOW_WIDTH / 2))

  pieces.poster = as_decoration(
    from_mock('A framed picture of mountains under a sun.', sprites.poster, sprites.POSTER_PAL, 5)
  )
  pieces.bookshelf = as_decoration(
    from_mock('A bookshelf of four shelves.', sprites.bookshelf(false), sprites.SHELF_PAL, 6)
  )
  pieces.water_cooler = as_decoration(
    from_mock('A water cooler.', sprites.cooler, sprites.COOLER_PAL, 6)
  )
  pieces.snake_plant = as_decoration(
    from_mock('A tall snake plant in a pot.', sprites.plant_snake, sprites.PLANT2_PAL, 9)
  )

  local tank = {
    about = 'A fish tank on a stand; two fish swim in it and a bubble rises.',
    frames = {},
    seconds_per_frame = 0.25,
  }
  local names = art.names_of(sprites.TANK_PAL)
  for tick = 0, 143, 3 do
    local canvas = art.new_canvas(0, 10, 17, 27)
    canvas:blit(sprites.fish_tank, names, 0, 10)
    for fish = 1, 2 do
      local span = 12
      local at = (tick / (fish == 1 and 2 or 3) + fish * 7) % (2 * span)
      local going_right = at < span
      local fish_x = 2 + math.floor(going_right and at or 2 * span - at)
      local fish_names = art.names_of(sprites.FISH_PAL[fish])
      canvas:blit(sprites.fish, fish_names, fish_x, 10 + 2 + fish * 2, not going_right)
    end
    canvas:set(14, 10 + 7 - math.floor(tick / 3) % 6, palette.name_of(sprites.FISH_PAL.bubble))
    tank.frames[#tank.frames + 1] = canvas
  end
  pieces.fish_tank = as_decoration(tank)

  return pieces
end

--- The sky of a window, 22 pixels wide and 10 tall, for the part of the day
--- `hour` falls in, as the frames the window shows.
---
---@param sprites table
---@param hour integer
---@return converter.Piece
function M.sky(sprites, hour)
  local phases = { [0] = 'night', [6] = 'dawn', [12] = 'day', [18] = 'dusk' }
  local bands = sprites.window_sky_pal(hour)
  local names = art.names_of(bands)
  local frames = {}
  local ticks = { 0 }
  local seconds = 1
  if hour == 0 then
    ticks, seconds = { 0, 9, 18 }, 0.75
  elseif hour == 12 then
    ticks, seconds = {}, 2
    for step = 0, 23 do
      table.insert(ticks, step * 24)
    end
  end
  for _, tick in ipairs(ticks) do
    local rows = sprites.window_sky(24, tick, hour)
    local canvas = art.new_canvas(0, 0, 21, 9)
    for row = 1, 10 do
      local text = rows[row + 1]:sub(2, 23)
      canvas:blit({ text }, names, 0, row - 1)
    end
    table.insert(frames, canvas)
  end
  return {
    about = ('The sky in the %s, painted into the glass of a window.'):format(phases[hour]),
    frames = frames,
    anchor = { 0, 0 },
    seconds_per_frame = seconds,
  }
end

--- The names a plan's decorations take, in the order of preference.
M.PREFERENCE = { 'window', 'water_cooler', 'snake_plant', 'bookshelf', 'poster', 'fish_tank' }

return M
