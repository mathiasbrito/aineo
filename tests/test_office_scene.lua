local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local fixture = dofile('tests/helpers/fixture.lua')
local files = dofile('tests/helpers/office_pack_files.lua')
local office_pack = require('aineo.office_pack')
local office_scene = require('aineo.office_scene')

local FLOOR = '#404040'
local WALL = '#202020'
local AGENT = '#ff00ff'

--- The text of an art file of one cell: two pixels of `letter`, which is
--- the colour `colour`, with its anchor at the bottom left.
---
---@param letter string
---@param colour string
---@return string
local function cell_art(letter, colour)
  return ('colours: %s = %s\nanchor: 0, 1\n---\n%s\n%s\n'):format(letter, colour, letter, letter)
end

--- The art files of the scene tests' packs: one cell of a colour each, a
--- person who is one cell and takes the agent's colour, and a walker of two
--- cells, the agent's and a blue one.
local ART = {
  ['art/person.txt'] = cell_art('A', 'agent'),
  ['art/walker.txt'] = 'colours: A = agent, B = blue\nanchor: 0, 1\n---\nAB\nAB\n',
  ['art/left.txt'] = cell_art('R', 'red'),
  ['art/dot.txt'] = 'colours: R = red\nanchor: 0, 0\n---\nR\n',
  ['art/first.txt'] = cell_art('G', 'green'),
  ['art/second.txt'] = cell_art('Y', 'yellow'),
  ['art/right.txt'] = cell_art('B', 'blue'),
  ['art/desk.txt'] = cell_art('W', 'brown'),
  ['art/blink.txt'] = 'colours: R = red, G = green\nanchor: 0, 1\nseconds per frame: 1\n---\nR\nR\n---\nG\nG\n',
  ['art/shades.txt'] = 'colours: L = agent_light, S = agent_shade, P = agent_blush\nanchor: 0, 1\n---\nLSP\nLSP\n',
}

--- The pack.lua fields of the scene tests' packs.
---@type table
local PACK_FIELDS = {
  name = 'scene',
  colours = {
    wall = WALL,
    floor = FLOOR,
    red = '#ff0000',
    green = '#00ff00',
    yellow = '#ffff00',
    blue = '#0000ff',
    brown = '#885500',
  },
  characters = {
    agent = {
      colours = { AGENT, '#00ffff' },
      poses = {
        standing = { art = { 'person' } },
        walking = { art = { 'walker' } },
        sitting = { art = { 'person' }, sitting = true },
        typing = { like = 'sitting', effect = 'dots' },
      },
    },
  },
  effects = { dots = { text = { '.', '..' }, colour = '#ffffff', seconds_per_frame = 1 } },
  activities = {
    stand = { steps = { { at = 'aside', pose = 'standing' } } },
    work = { steps = { { at = 'seat', pose = 'typing' } } },
  },
  states = { standing = 'stand', working = 'work' },
}

--- Loads a pack from `plan` and `legend` (the plan text and what its letters
--- are), with the scene tests' art and the fields `changes` replace.
---
---@param plan string the plan's text, comment and marker lines included
---@param legend table
---@param changes? table fields of pack.lua replaced
---@return aineo.office_pack.Pack
local function scene_pack(plan, legend, changes)
  local fields = vim.tbl_extend('force', PACK_FIELDS, {
    floor = { floor_colour = 'floor', wall_colour = 'wall', legend = legend },
  }, changes or {})
  local folder = files.write_pack(
    fixture.directory('office_scene'),
    'scene',
    vim.tbl_extend('force', ART, {
      ['pack.lua'] = files.pack_text(fields),
      ['floor.txt'] = plan,
    })
  )
  return assert(office_pack.load({ name = 'scene', folders = { folder } }))
end

--- The group of the pixel pair of one colour, top and bottom alike.
---
---@param colour string `#rrggbb`
---@return string
local function solid(colour)
  return ('AineoOfficePixel_%s_%s'):format(colour:sub(2), colour:sub(2))
end

--- The group drawing the cell at `column` of the row `row`, both from 0, in
--- a picture where every cell is a pixel pair (three bytes of text).
---
---@param picture aineo.office_scene.Picture
---@param column integer
---@param row integer
---@return string|nil group
local function group_at(picture, column, row)
  local from = 3 * column
  local found = vim.iter(picture.rows[row + 1].runs):find(function(run)
    return run.from <= from and from < run.to
  end)
  return found and found.group
end

--- The groups of the cells of a row of a picture, from the left.
---
---@param picture aineo.office_scene.Picture
---@param row integer from 0
---@param width integer
---@return string[]
local function row_groups(picture, row, width)
  local groups = {}
  for column = 0, width - 1 do
    groups[column + 1] = group_at(picture, column, row)
  end
  return groups
end

--- A stage of `pack`, `width` by `height` cells.
---
---@param pack aineo.office_pack.Pack
---@param width integer
---@param height integer
---@return aineo.office_scene.Stage
local function stage_of(pack, width, height)
  return office_scene.new_stage({ pack = pack, width = width, height = height })
end

local T = MiniTest.new_set({
  hooks = {
    post_once = function()
      vim.fn.delete(fixture.directory('office_scene'), 'rf')
    end,
  },
})

--- A plan of a wall row and a row of four letters, the middle two repeating.
local REPEATING_PLAN = '# plan\n  ~~\n ####\n PDEQ\n'

local REPEATING_LEGEND = {
  P = { piece = 'left' },
  D = { piece = 'first' },
  E = { piece = 'second' },
  Q = { piece = 'right' },
}

T['the floor plan'] = MiniTest.new_set()

T['the floor plan']['is laid out once at the width of its own cells'] = function()
  local stage = stage_of(scene_pack(REPEATING_PLAN, REPEATING_LEGEND), 4, 2)
  stage.advance({}, 0)

  eq(row_groups(stage.picture(), 1, 4), {
    solid('#ff0000'),
    solid('#00ff00'),
    solid('#ffff00'),
    solid('#0000ff'),
  })
end

T['the floor plan']['repeats its marked columns to fill a wider width'] = function()
  local stage = stage_of(scene_pack(REPEATING_PLAN, REPEATING_LEGEND), 8, 2)
  stage.advance({}, 0)

  eq(row_groups(stage.picture(), 1, 8), {
    solid('#ff0000'),
    solid('#00ff00'),
    solid('#ffff00'),
    solid('#00ff00'),
    solid('#ffff00'),
    solid('#00ff00'),
    solid('#ffff00'),
    solid('#0000ff'),
  })
end

T['the floor plan']['repeats the block only as many whole times as fit, and pads what is left with floor'] = function()
  local stage = stage_of(scene_pack(REPEATING_PLAN, REPEATING_LEGEND), 7, 2)
  stage.advance({}, 0)

  eq(row_groups(stage.picture(), 1, 7), {
    solid('#ff0000'),
    solid('#00ff00'),
    solid('#ffff00'),
    solid('#00ff00'),
    solid('#ffff00'),
    solid('#0000ff'),
    solid(FLOOR),
  })
end

T['the floor plan']['pads a row that ends in a wall with wall'] = function()
  local stage = stage_of(scene_pack(REPEATING_PLAN, REPEATING_LEGEND), 7, 2)
  stage.advance({}, 0)

  eq(group_at(stage.picture(), 6, 0), solid(WALL))
end

T['the floor plan']['is cut at the width when the width is less than its cells'] = function()
  local stage = stage_of(scene_pack(REPEATING_PLAN, REPEATING_LEGEND), 2, 2)
  stage.advance({}, 0)

  eq(row_groups(stage.picture(), 1, 2), { solid('#ff0000'), solid('#00ff00') })
end

T['the floor plan']['draws walls and floor in the colours the floor names'] = function()
  local stage = stage_of(scene_pack('# plan\n \n ##\n ..\n', {}), 2, 2)
  stage.advance({}, 0)

  eq(row_groups(stage.picture(), 0, 2), { solid(WALL), solid(WALL) })
  eq(row_groups(stage.picture(), 1, 2), { solid(FLOOR), solid(FLOOR) })
end

T['the floor plan']['draws floor below the rows of the plan'] = function()
  local stage = stage_of(scene_pack('# plan\n \n #\n', {}), 1, 3)
  stage.advance({}, 0)

  eq(group_at(stage.picture(), 0, 2), solid(FLOOR))
end

T['the floor plan']['gives a cell of a letter the background of the nearest cell of its row that is wall or floor'] = function()
  local stage = stage_of(
    scene_pack('# plan\n \n #X..Y#\n', { X = { spot = 'here' }, Y = { spot = 'there' } }),
    6,
    1
  )
  stage.advance({}, 0)

  eq(row_groups(stage.picture(), 0, 6), {
    solid(WALL),
    solid(WALL),
    solid(FLOOR),
    solid(FLOOR),
    solid(FLOOR),
    solid(WALL),
  })
end

T['the floor plan']['gives a cell of a letter no neighbour defines the floor'] = function()
  local stage =
    stage_of(scene_pack('# plan\n \n XY\n', { X = { spot = 'a' }, Y = { spot = 'b' } }), 2, 1)
  stage.advance({}, 0)

  eq(row_groups(stage.picture(), 0, 2), { solid(FLOOR), solid(FLOOR) })
end

T['the floor plan']['is laid out again for the new size when the stage is resized'] = function()
  local stage = stage_of(scene_pack(REPEATING_PLAN, REPEATING_LEGEND), 4, 2)
  stage.advance({}, 0)

  stage.resize(6, 3)
  local picture = stage.picture()

  eq(#picture.rows, 3)
  eq(group_at(picture, 5, 1), solid('#0000ff'))
end

T['the picture'] = MiniTest.new_set()

T['the picture']['has a row for each row of the stage, each of the width of the stage'] = function()
  local stage = stage_of(scene_pack(REPEATING_PLAN, REPEATING_LEGEND), 5, 4)
  stage.advance({}, 0)

  local picture = stage.picture()

  eq(#picture.rows, 4)
  eq(vim.fn.strchars(picture.rows[1].text), 5)
end

T['the picture']['shows a piece with frames at the frame the time calls for'] = function()
  local pack = scene_pack('# plan\n \n b\n', { b = { piece = 'blink' } })
  local stage = stage_of(pack, 1, 1)

  stage.advance({}, 0.5)
  local first = group_at(stage.picture(), 0, 0)
  stage.advance({}, 1.5)
  local second = group_at(stage.picture(), 0, 0)
  stage.advance({}, 2.5)
  local third = group_at(stage.picture(), 0, 0)

  eq({ first, second, third }, { solid('#ff0000'), solid('#00ff00'), solid('#ff0000') })
end

--- A plan of an aisle with a standing spot `a` and a seat `s` that holds a desk.
local DESK_PLAN = '# plan\n \n ..........\n ..........\n .a....s...\n ..........\n'

local DESK_LEGEND = {
  a = { spot = 'aside' },
  s = { spot = 'seat', sitting = true, piece = 'desk' },
}

--- The agents, in the order given, in the states given.
---
---@param ... string states
---@return aineo.office_states.Agent[]
local function agents_in(...)
  local agents = {}
  for index, state in ipairs({ ... }) do
    agents[index] = { id = index == 1 and 'main' or ('agent' .. index), state = state }
  end
  return agents
end

T['an agent'] = MiniTest.new_set()

T['an agent']['stands at the spot its state’s activity names, in the colour it is given'] = function()
  local stage = stage_of(scene_pack(DESK_PLAN, DESK_LEGEND), 10, 4)

  stage.advance(agents_in('standing'), 0)

  eq(group_at(stage.picture(), 1, 2), solid(AGENT))
end

T['an agent']['sits behind the piece that stands in front of its seat'] = function()
  local stage = stage_of(scene_pack(DESK_PLAN, DESK_LEGEND), 10, 4)

  stage.advance(agents_in('working'), 0)

  eq(group_at(stage.picture(), 6, 2), solid('#885500'))
end

T['an agent']['shows the effect of its pose above its head'] = function()
  local stage = stage_of(scene_pack(DESK_PLAN, DESK_LEGEND), 10, 4)

  stage.advance(agents_in('working'), 0)
  local picture = stage.picture()

  eq(vim.fn.strcharpart(picture.rows[2].text, 6, 1), '.')
  eq(group_at(picture, 6, 1), 'AineoOfficeText_ffffff_404040')
end

T['an agent']['shows the next frame of its effect as the time passes'] = function()
  local stage = stage_of(scene_pack(DESK_PLAN, DESK_LEGEND), 10, 4)

  stage.advance(agents_in('working'), 0)
  stage.advance(agents_in('working'), 1.5)

  eq(vim.fn.strcharpart(stage.picture().rows[2].text, 6, 2), '..')
end

T['an agent']['is placed at its spot at once when it first appears, without walking there'] = function()
  local stage = stage_of(scene_pack(DESK_PLAN, DESK_LEGEND), 10, 4)

  stage.advance(agents_in('working'), 100)

  eq(group_at(stage.picture(), 6, 2), solid('#885500'))
  eq(group_at(stage.picture(), 5, 2), solid(FLOOR))
end

T['an agent']['walks to the spot of its new state, in the walking pose, facing the way it goes'] = function()
  local stage = stage_of(scene_pack(DESK_PLAN, DESK_LEGEND), 10, 4)
  stage.advance(agents_in('standing'), 0)

  stage.advance(agents_in('working'), 0.1)
  local picture = stage.picture()

  eq(group_at(picture, 2, 2), solid(AGENT))
  eq(group_at(picture, 3, 2), solid('#0000ff'))
  eq(group_at(picture, 1, 2), solid(FLOOR))
end

T['an agent']['walks the other way mirrored'] = function()
  local stage = stage_of(scene_pack(DESK_PLAN, DESK_LEGEND), 10, 4)
  stage.advance(agents_in('working'), 0)

  stage.advance(agents_in('standing'), 0.1)
  local picture = stage.picture()

  eq(group_at(picture, 5, 2), solid(AGENT))
  eq(group_at(picture, 4, 2), solid('#0000ff'))
end

T['an agent']['takes the pose of its spot once it has arrived'] = function()
  local stage = stage_of(scene_pack(DESK_PLAN, DESK_LEGEND), 10, 4)
  stage.advance(agents_in('standing'), 0)

  stage.advance(agents_in('working'), 0.1)
  stage.advance(agents_in('working'), 5)
  local picture = stage.picture()

  eq(group_at(picture, 6, 2), solid('#885500'))
  eq(group_at(picture, 1, 2), solid(FLOOR))
  eq(vim.fn.strcharpart(picture.rows[2].text, 6, 1), '.')
end

T['an agent']['plays the activity of the state a state falls back to when the pack maps none for it'] = function()
  local stage = stage_of(scene_pack(DESK_PLAN, DESK_LEGEND), 10, 4)

  stage.advance(agents_in('idle'), 0)

  eq(group_at(stage.picture(), 1, 2), solid(AGENT))
end

T['an agent']['plays the activity of standing for a state the vocabulary lacks'] = function()
  local stage = stage_of(scene_pack(DESK_PLAN, DESK_LEGEND), 10, 4)

  stage.advance(agents_in('dancing'), 0)

  eq(group_at(stage.picture(), 1, 2), solid(AGENT))
end

T['an agent']['is drawn in front of a piece it stands on the same row as'] = function()
  local stage = stage_of(
    scene_pack('# plan\n \n .as.\n', {
      a = { spot = 'aside', piece = 'desk' },
      s = { spot = 'seat', sitting = true },
    }),
    4,
    1
  )

  stage.advance(agents_in('standing'), 0)

  eq(group_at(stage.picture(), 1, 0), solid(AGENT))
end

T['an agent']['takes the spots of its name in the order the plan reads them, one agent to a spot'] = function()
  local plan = '# plan\n \n .a.a.a.\n'
  local stage = stage_of(scene_pack(plan, { a = { spot = 'aside' } }), 7, 1)

  stage.advance(agents_in('standing', 'standing'), 0)

  eq(row_groups(stage.picture(), 0, 7), {
    solid(FLOOR),
    solid(AGENT),
    solid(FLOOR),
    solid('#00ffff'),
    solid(FLOOR),
    solid(FLOOR),
    solid(FLOOR),
  })
end

T['an agent']['is not drawn when its activity names a spot the plan lacks'] = function()
  local stage = stage_of(scene_pack('# plan\n \n ....\n', {}), 4, 1)

  stage.advance(agents_in('standing'), 0)

  eq(row_groups(stage.picture(), 0, 4), { solid(FLOOR), solid(FLOOR), solid(FLOOR), solid(FLOOR) })
end

T['an agent']['is not drawn when there are more agents than spots'] = function()
  local stage = stage_of(scene_pack('# plan\n \n .a..\n', { a = { spot = 'aside' } }), 4, 1)

  stage.advance(agents_in('standing', 'standing'), 0)

  eq(row_groups(stage.picture(), 0, 4), { solid(FLOOR), solid(AGENT), solid(FLOOR), solid(FLOOR) })
end

T['an agent']['is forgotten when it is no longer in the agents given'] = function()
  local stage = stage_of(scene_pack(DESK_PLAN, DESK_LEGEND), 10, 4)
  stage.advance(agents_in('standing'), 0)

  stage.advance({}, 1)

  eq(group_at(stage.picture(), 1, 2), solid(FLOOR))
end

T['an agent']['takes the shades of its colour for the letters that name them'] = function()
  local stage = stage_of(
    scene_pack('# plan\n \n .a..\n', { a = { spot = 'aside' } }, {
      characters = {
        agent = {
          colours = { '#808080' },
          poses = { standing = { art = { 'shades' } } },
        },
      },
    }),
    4,
    1
  )

  stage.advance(agents_in('standing'), 0)
  local picture = stage.picture()

  eq(picture.looks[group_at(picture, 1, 0)].foreground, '#a6a6a6')
  eq(picture.looks[group_at(picture, 2, 0)].foreground, '#5a5a5a')
  eq(picture.looks[group_at(picture, 3, 0)].foreground, '#ba8694')
end

T['an effect'] = MiniTest.new_set()

--- The picture of a working agent whose effect `dots` has the fields
--- `effect` give besides a white colour, at the seat of `DESK_PLAN`.
---
---@param effect table
---@return aineo.office_scene.Picture picture
local function picture_with_effect(effect)
  local pack = scene_pack(DESK_PLAN, DESK_LEGEND, {
    effects = { dots = vim.tbl_extend('force', { colour = '#ffffff' }, effect) },
  })
  local stage = stage_of(pack, 10, 4)
  stage.advance(agents_in('working'), 0)
  return stage.picture()
end

--- `count` characters of the row `row` of `picture`, from the cell `column`,
--- both from 0.
---
---@param picture aineo.office_scene.Picture
---@param row integer
---@param column integer
---@param count integer
---@return string
local function text_at(picture, row, column, count)
  return vim.fn.strcharpart(picture.rows[row + 1].text, column, count)
end

--- The names of the groups of `picture` that draw bold text.
---
---@param picture aineo.office_scene.Picture
---@return string[]
local function bold_groups(picture)
  return vim.tbl_filter(function(group)
    return vim.endswith(group, '_bold')
  end, vim.tbl_keys(picture.looks))
end

T['an effect']['is centred over the head by default'] = function()
  local picture = picture_with_effect({ text = { 'abc' } })

  eq(text_at(picture, 1, 5, 3), 'abc')
end

T['an effect']['is centred by its characters, not its bytes'] = function()
  local picture = picture_with_effect({ text = { '·∘○' } })

  eq(text_at(picture, 1, 5, 3), '·∘○')
end

T['an effect']['ends over the head when its place is above_left'] = function()
  local picture = picture_with_effect({ text = { 'abc' }, place = 'above_left' })

  eq(text_at(picture, 1, 4, 3), 'abc')
end

T['an effect']['starts over the head when its place is above_right'] = function()
  local picture = picture_with_effect({ text = { 'abc' }, place = 'above_right' })

  eq(text_at(picture, 1, 6, 3), 'abc')
end

T['an effect']['stands beside the head, a column to the right, when its place is beside'] = function()
  local picture = picture_with_effect({ text = { 'abc' }, place = 'beside' })

  eq(text_at(picture, 2, 7, 3), 'abc')
end

T['an effect']['is above the head when its place is one the engine does not know'] = function()
  local picture = picture_with_effect({ text = { 'abc' }, place = 'nowhere' })

  eq(text_at(picture, 1, 5, 3), 'abc')
end

T['an effect']['is drawn in a group of its own when it is bold'] = function()
  local picture = picture_with_effect({ text = { 'abc' }, bold = true })

  local bold = bold_groups(picture)
  eq(#bold, 1)
  eq(picture.looks[bold[1]].bold, true)
end

T['an effect']['is not bold unless it is asked to be'] = function()
  eq(bold_groups(picture_with_effect({ text = { 'abc' } })), {})
end

T['a piece'] = MiniTest.new_set()

T['a piece']['wholly below the canvas is not painted, though the plan places it'] = function()
  local pack = scene_pack('# plan\n \n P\n P\n P\n P\n', { P = { piece = 'left' } })
  local reads = 0
  pack.pieces.left.colours = setmetatable({}, {
    __index = function()
      reads = reads + 1
      return 'red'
    end,
  })
  local stage = stage_of(pack, 1, 2)

  stage.advance({}, 0)
  stage.picture()

  eq(reads, 4)
end

T['a piece']['partly on the canvas is painted'] = function()
  local pack = scene_pack('# plan\n \n .\n P\n', { P = { piece = 'left' } })
  local stage = stage_of(pack, 1, 2)

  stage.advance({}, 0)

  eq(group_at(stage.picture(), 0, 1), solid('#ff0000'))
end

T['a piece']['one pixel tall on the canvas's last pixel row is painted'] = function()
  local pack = scene_pack('# plan\n \n .\n D\n', { D = { piece = 'dot' } })
  local stage = stage_of(pack, 1, 2)

  stage.advance({}, 0)

  eq(group_at(stage.picture(), 0, 1), 'AineoOfficePixel_404040_ff0000')
end

return T
