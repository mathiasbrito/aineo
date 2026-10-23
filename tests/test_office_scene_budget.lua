local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_budget')

--- The time between two frames of the office, which runs at 12 frames a second.
local MILLISECONDS_BETWEEN_FRAMES = 83

--- A plan of a piece in every cell of every row, whatever the size.
local EVERY_CELL = '# plan\n ~\n~P\n'

--- A stage of `width` by `height` cells with a piece of art in every cell.
---
---@param width integer
---@param height integer
---@param art? table<string, string> more art files
---@return aineo.office_scene.Stage
local function stage_full_of_pieces(width, height, art)
  local pack = scene.people_pack(EVERY_CELL, { P = { piece = 'left' } }, nil, art)
  return scene.stage_of(pack, width, height)
end

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['a frame'] = MiniTest.new_set()

T['a frame']['paints the first pieces of the plan and not those beyond the cap on placements'] = function()
  local stage = stage_full_of_pieces(80, 60)
  stage.advance({}, 0)
  local picture = stage.picture()
  local red, floor = scene.solid('#ff0000'), scene.solid(scene.FLOOR)

  eq({ scene.group_at(picture, 0, 0), scene.group_at(picture, 79, 0) }, { red, red })
  eq({ scene.group_at(picture, 79, 24), scene.group_at(picture, 0, 25) }, { red, floor })
end

--- The number of pieces the stage told it left out, as a list of the numbers
--- it was told, and the stage.
---
---@param pack aineo.office_pack.Pack
---@param width integer
---@param height integer
---@return integer[] told
---@return aineo.office_scene.Stage
local function stage_telling(pack, width, height)
  local told = {}
  local stage = scene.stage_of(pack, width, height, {
    on_left_out = function(count)
      table.insert(told, count)
    end,
  })
  return told, stage
end

T['a frame']['tells how many pieces it left out beyond the cap, and nothing when all are placed'] = function()
  local told_of_many =
    stage_telling(scene.people_pack(EVERY_CELL, { P = { piece = 'left' } }), 80, 60)
  local told_of_few =
    stage_telling(scene.people_pack(EVERY_CELL, { P = { piece = 'left' } }), 10, 30)

  eq({ told_of_many, told_of_few }, { { 2400 }, {} })
end

--- A plan of a row of decorations, then rows of furniture and a row of
--- pieces that have a spot, on a stage 50 cells wide and 60 tall, whose
--- plan takes 55 rows: 2,650 pieces of furniture, 50 with a spot and one
--- decoration, 2,701 in all.
local CROWDED_PLAN = '# plan\n ~\n *\n~P\n E\n'

local CROWDED_LEGEND = {
  ['*'] = { decorations = { 'first' } },
  P = { piece = 'left' },
  E = { piece = 'right', spot = 'seat' },
}

--- The picture of the crowded plan, and the numbers of pieces it was told
--- were left out.
---
---@return aineo.office_scene.Picture
---@return integer[]
local function crowded_picture()
  local told, stage = stage_telling(scene.people_pack(CROWDED_PLAN, CROWDED_LEGEND), 50, 60)
  stage.advance({}, 0)
  return stage.picture(), told
end

T['a frame']['leaves out decorations before furniture when it places too many pieces'] = function()
  local picture, told = crowded_picture()

  eq(scene.group_at(picture, 0, 0), scene.solid(scene.FLOOR))
  eq(told, { 701 })
end

--- The art, besides the pack's usual, of the pieces that matter most.
local MATTERS_MOST_ART = {
  ['art/dial.txt'] = 'colours: B = blue\nanchor: 0, 1\narea time: 0, 0, 1 x 1\n---\nB\nB\n',
  ['art/monitor.txt'] = 'colours: B = blue\nanchor: 0, 1\narea screen: 0, 0, 1 x 1\n---\nB\nB\n',
}

T['a frame']['keeps'] = MiniTest.new_set({
  parametrize = {
    { 'the pieces that stand on a spot', { piece = 'right', spot = 'seat' } },
    { 'the pieces that have art for when they are in use', { piece = 'right', in_use = 'left' } },
    { 'the pieces that show the time', { piece = 'dial', shows = 'time' } },
    { 'the pieces that have a screen', { piece = 'monitor' } },
  },
})

T['a frame']['keeps'][' when it places too many pieces'] = function(_, entry)
  local pack = scene.people_pack(
    CROWDED_PLAN,
    vim.tbl_extend('force', CROWDED_LEGEND, { E = entry }),
    nil,
    MATTERS_MOST_ART
  )
  local _, stage = stage_telling(pack, 50, 60)
  stage.advance({}, 0)

  eq(scene.group_at(stage.picture(), 0, 54), scene.solid('#0000ff'))
end

T['a frame']['leaves out the last pieces the plan reads first of the same kind'] = function()
  local picture = crowded_picture()

  eq({ scene.group_at(picture, 0, 1), scene.group_at(picture, 0, 53) }, {
    scene.solid('#ff0000'),
    scene.solid(scene.FLOOR),
  })
end

T['a frame']['leaves out pieces that would paint more than sixteen times the stage'] = function()
  local slab = 'colours: R = red\nanchor: 0, 19\n---\n' .. (('R'):rep(8) .. '\n'):rep(20)
  local pack = scene.people_pack(EVERY_CELL, { P = { piece = 'slab' } }, nil, {
    ['art/slab.txt'] = slab,
  })
  local told = stage_telling(pack, 8, 10)

  eq(told, { 18 })
end

T['a frame']['of the largest office, full of pieces, costs less than the time between frames'] = function()
  local art = {
    ['art/left.txt'] = 'colours: R = red\nanchor: 0, 23\n---\n' .. (('R'):rep(24) .. '\n'):rep(24),
  }
  local stage = stage_full_of_pieces(220, 80, art)
  local agents = scene.agents_in('working', 'working', 'working', 'working')
  stage.advance(agents, 0)

  local started = vim.uv.hrtime()
  for frame = 1, 5 do
    stage.advance(agents, frame / 12)
    stage.picture()
  end
  local milliseconds_a_frame = (vim.uv.hrtime() - started) / 5e6

  eq(milliseconds_a_frame < MILLISECONDS_BETWEEN_FRAMES, true)
end

return T
