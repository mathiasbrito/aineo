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
  eq({ scene.group_at(picture, 0, 59), scene.group_at(picture, 79, 59) }, { floor, floor })
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
