local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_frame')

--- A letter for each colour of the pictures here.
local LETTERS = {
  [scene.WALL] = '#',
  [scene.FLOOR] = '.',
  [scene.AGENT] = 'A',
  ['#ff0000'] = 'R',
  ['#00ff00'] = 'G',
  ['#885500'] = 'W',
}

--- An office of ten cells by four: a wall, a door and a board on the wall's
--- row below, and a desk with a seat to the right of the door's spot.
local OFFICE_PLAN = '# plan\n \n ##########\n ..D.B.....\n ..d.....s.\n ..........\n'

local OFFICE_LEGEND = {
  D = { piece = 'left' },
  B = { piece = 'first' },
  d = { spot = 'door' },
  s = { spot = 'seat', sitting = true, piece = 'desk' },
}

--- The pack of the office, whose agent comes in at the door, stays two
--- seconds, if the random source is 0.5, between one and three, and then
--- sits at the seat and types.
---
---@return aineo.office_pack.Pack
local function office_pack()
  return scene.people_pack(OFFICE_PLAN, OFFICE_LEGEND, {
    characters = {
      agent = {
        colours = { scene.AGENT },
        poses = {
          standing = { art = { 'person' } },
          walking = { art = { 'person' } },
          typing = { art = { 'person' }, sitting = true, effect = 'dots' },
        },
      },
    },
    effects = { dots = { text = { '.' } } },
    activities = {
      work = {
        steps = {
          { at = 'door', for_seconds = { 1, 3 } },
          { at = 'seat', pose = 'typing' },
        },
      },
    },
    states = { standing = 'work', working = 'work' },
  })
end

--- The picture of the office at `time`, after the agent was advanced there
--- from the time 0.
---
---@param time number
---@return string[]
local function sketch_at(time)
  local stage = scene.stage_of(office_pack(), 10, 4, {
    random = function()
      return 0.5
    end,
  })
  local agents = scene.agents_in('working')
  stage.advance(agents, 0)
  stage.advance(agents, time)
  return scene.sketch(stage.picture(), 10, LETTERS)
end

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['a frame'] = MiniTest.new_set()

T['a frame']['shows the agent at the door when it comes in'] = function()
  eq(sketch_at(0), {
    '##########',
    '..R.G.....',
    '..A.....W.',
    '..........',
  })
end

T['a frame']['shows the agent on its way to the desk a tenth of a second after it left the door'] = function()
  eq(sketch_at(2.1), {
    '##########',
    '..R.G.....',
    '...A....W.',
    '..........',
  })
end

T['a frame']['shows the agent behind its desk, its dots over it, once it has sat down'] = function()
  eq(sketch_at(3), {
    '##########',
    '..R.G...t.',
    '........W.',
    '..........',
  })
end

return T
