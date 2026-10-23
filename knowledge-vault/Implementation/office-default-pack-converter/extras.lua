-- What a monitor shows, the office cat, and the pieces the mock did not have:
-- the baseboard, the table-tennis table and what the cat leaves.

local art = require('art')
local palette = require('palette')

local M = {}

local TICK = 1 / 12

--- The screens a pose shows on its agent's monitor, 10 pixels wide and 4 tall,
--- sampled from the mock's functions of time at 12 frames a second.
---
---@param sprites table
---@return table<string, converter.Piece>
function M.screens(sprites)
  local names = art.names_of(sprites.SCREEN_PAL)
  local function screen_piece(about, rows_at, ticks, seconds_per_frame)
    local frames = {}
    for _, tick in ipairs(ticks) do
      local rows = rows_at(tick)
      local padded = {}
      for index = 1, 4 do
        padded[index] = rows[index] or ('.'):rep(10)
      end
      frames[#frames + 1] = art.from_rows(padded, names, 0, 0)
    end
    return {
      about = about,
      frames = frames,
      anchor = { 0, 0 },
      seconds_per_frame = seconds_per_frame or TICK,
    }
  end
  local function range(first, last, step)
    local out = {}
    for tick = first, last, step or 1 do
      out[#out + 1] = tick
    end
    return out
  end
  local pieces = {}

  pieces.screen_cursor = screen_piece(
    'A blinking cursor on an empty screen.',
    function(tick)
      return sprites.screen_v3('idle', tick)
    end,
    { 0, 6 },
    0.5
  )
  pieces.screen_code = screen_piece(
    'Code typed line by line, then scrolling.',
    function(tick)
      return sprites.screen_v3('type', tick)
    end,
    range(0, 59)
  )
  pieces.screen_command = screen_piece(
    'A command typed, then its output scrolling.',
    function(tick)
      return sprites.screen_v3('command', tick)
    end,
    range(0, 23)
  )
  local tests = {}
  for tick = 0, 27, 3 do
    table.insert(tests, tick)
  end
  for _ = 1, 54 do
    table.insert(tests, 27)
  end
  pieces.screen_tests = screen_piece(
    'A test run: a title and a row of dots filling in.',
    function(tick)
      local rows = sprites.screen_v3('tests_pass', tick)
      return { rows[1], (rows[2]:gsub('g', 'c')), rows[3], rows[4] }
    end,
    tests,
    0.25
  )
  pieces.screen_error = screen_piece(
    'The screen flashing red.',
    function(tick)
      return sprites.screen_v3('error', tick)
    end,
    range(0, 5)
  )
  pieces.screen_permission = screen_piece(
    'A yellow screen asking, its last row blinking.',
    function(tick)
      return sprites.screen_v3('permission', tick)
    end,
    range(0, 7)
  )
  pieces.screen_interrupted = screen_piece(
    'The screen flashing yellow, then a cursor.',
    function(tick)
      return sprites.screen_v3('interrupted', tick)
    end,
    range(0, 23)
  )
  pieces.screen_web = {
    about = 'A browser: an address bar, and a globe beside the page.',
    frames = {
      art.from_rows(
        { 'iiiiiiiiii', 'iiiiiiiiii', '.cbbc.mmm.', '.cbbc.mm..' },
        {
          i = palette.name_of('45475a'),
          c = palette.name_of('89dceb'),
          b = palette.name_of('1e66f5'),
          m = palette.name_of('cba6f7'),
        },
        0,
        0
      ),
    },
    anchor = { 0, 0 },
  }
  return pieces
end

--- The baseboard along the wall's foot, two pixels tall, walked over.
---
---@return converter.Piece
function M.baseboard()
  local canvas = art.new_canvas(0, 0, 0, 1)
  canvas:set(0, 0, 'baseboard')
  canvas:set(0, 1, 'baseboard')
  palette.name_of('414559')
  return {
    about = 'The strip along the foot of the wall, stretched to the length of the plan\'s run of it.',
    frames = { canvas },
    stretch = { 1, 1 },
  }
end

--- The table-tennis table and its game.
---
---@return table<string, converter.Piece>
function M.table_tennis()
  local width = 26
  local function table_canvas(ball_x, ball_y)
    local canvas = art.new_canvas(0, 0, width - 1, 8)
    for x = 0, width - 1 do
      canvas:set(x, 3, 'white')
      canvas:set(x, 4, 'blue')
      canvas:set(x, 5, 'blue')
      canvas:set(x, 6, 'iron')
    end
    for y = 0, 2 do
      canvas:set(12, y, 'shine')
      canvas:set(13, y, 'shine')
    end
    for y = 7, 8 do
      canvas:set(1, y, 'iron')
      canvas:set(2, y, 'iron')
      canvas:set(width - 3, y, 'iron')
      canvas:set(width - 2, y, 'iron')
    end
    if ball_x then
      canvas:set(ball_x, ball_y, 'orange')
    end
    return canvas
  end
  palette.name_of('fe640b')
  palette.name_of('45475a')
  palette.name_of('1e66f5')
  palette.name_of('eff1f5')
  palette.name_of('cdd6f4')
  local playing = {
    about = 'The table while two agents play: a ball crosses it and comes back.',
    frames = {},
    seconds_per_frame = 0.1,
  }
  local steps = 24
  for step = 0, steps - 1 do
    local progress = (step % (steps / 2)) / (steps / 2)
    local going = step < steps / 2
    local x = math.floor((going and progress or 1 - progress) * (width - 5) + 2 + 0.5)
    local lift = math.floor(5 * math.abs(math.sin(math.pi * progress * 2)) + 0.5)
    playing.frames[#playing.frames + 1] = table_canvas(x, 2 - math.min(lift, 2) - 0)
  end
  return {
    table_tennis = {
      about = 'A table-tennis table: a blue top, a net and four legs.',
      frames = { table_canvas() },
    },
    table_tennis_playing = playing,
  }
end

--- What the cat leaves.
---
---@return converter.Piece
function M.mess()
  local canvas = art.new_canvas(0, 0, 3, 1)
  canvas:set(1, 0, 'door_frame')
  canvas:set(2, 0, 'door_frame')
  for x = 0, 3 do
    canvas:set(x, 1, 'door_frame')
  end
  palette.name_of('6b4f3f')
  return { about = 'What the cat left on the floor.', frames = { canvas } }
end

--- What the cat leaves besides the mess: a puddle.
---
---@return converter.Piece
function M.puddle()
  local canvas = art.new_canvas(0, 0, 5, 1)
  for x = 1, 4 do
    canvas:set(x, 0, 'gold')
  end
  for x = 0, 5 do
    canvas:set(x, 1, 'gold')
  end
  palette.name_of('e6c384')
  return { about = 'What the cat left on the floor: a puddle.', frames = { canvas } }
end

--- The office cat's poses, 11 pixels wide and 6 tall, in the cat's colour.
---
---@param sprites table
---@return table<string, converter.Piece>
function M.cat(sprites)
  local names = { k = 'agent', e = palette.name_of('a6e3a1'), n = palette.name_of('f5c2e7') }
  local function frames_of(rows_list, padding)
    local frames = {}
    for _, rows in ipairs(rows_list) do
      local canvas = art.new_canvas(0, 0, 10, 5 + (padding or 0))
      canvas:blit(rows, names, 0, 0)
      frames[#frames + 1] = canvas
    end
    return frames
  end
  local function piece(about, rows_list, seconds_per_frame, padding)
    local frames = frames_of(rows_list, padding)
    return {
      about = about,
      frames = frames,
      anchor = { 5, frames[1].bottom },
      seconds_per_frame = seconds_per_frame,
    }
  end
  local cat = sprites.cat
  local pieces = {
    cat_walk = piece('The cat walking, two frames.', cat.walk, 0.25),
    cat_sit = piece('The cat sitting.', { cat.sit }, 1),
    cat_wash = piece('The cat sitting and washing.', cat.wash, 0.5),
    cat_sleep = piece('The cat curled up asleep.', { cat.sleep }, 1),
    cat_sit_on_a_desk = piece(
      'The cat sitting on a desk, its feet three pixels above where it is placed.',
      { cat.sit },
      1,
      3
    ),
    cat_sleep_on_a_seat = piece(
      'The cat asleep on a sofa seat, its feet four pixels above where it is placed so that the cushion of the sofa front does not cover it.',
      { cat.sleep },
      1,
      4
    ),
  }
  -- Rubbing against someone's legs: the walk, and a pixel to the side every
  -- other two frames.
  local rub = {}
  for index, rows in ipairs({ cat.walk[1], cat.walk[2], cat.walk[1], cat.walk[2] }) do
    local canvas = art.new_canvas(0, 0, 11, 5)
    canvas:blit(rows, names, index > 2 and 1 or 0, 0)
    table.insert(rub, canvas)
  end
  pieces.cat_rub = { about = 'The cat rubbing against legs.', frames = rub, anchor = { 5, 5 }, seconds_per_frame = 1 / 3 }
  return pieces
end

return M
