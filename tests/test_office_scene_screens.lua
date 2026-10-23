local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_screens')

local BROWN = '#885500'

--- Two monitors, `m`, in the top row and a seat, `s`, below the left side of
--- each. A monitor is two cells wide and its screen is the one pixel at its
--- upper right.
local MONITOR_PLAN = '# plan\n \n ..m..m....\n .s..s.....\n'

local MONITOR_ART = {
  ['art/monitor.txt'] = 'colours: M = brown\nanchor: 0, 1\narea screen: 1, 0, 1 x 1\n---\nMM\nMM\n',
  ['art/glow.txt'] = 'colours: G = green\nanchor: 0, 0\n---\nGG\nGG\n',
}

--- The pack of the monitors, whose agents sit at a seat and, in the state
--- `working`, type with a screen showing the glow.
---
---@return aineo.office_pack.Pack
local function monitor_pack()
  return scene.people_pack(MONITOR_PLAN, { m = { piece = 'monitor' }, s = { spot = 'seat' } }, {
    characters = {
      agent = {
        colours = { scene.AGENT, scene.SECOND_AGENT },
        poses = {
          standing = { art = { 'person' } },
          walking = { art = { 'person' } },
          typing = { art = { 'person' }, screen = 'glow' },
        },
      },
    },
    activities = {
      stand = { steps = { { at = 'seat' } } },
      work = { steps = { { at = 'seat', pose = 'typing' } } },
    },
    states = { standing = 'stand', working = 'work' },
  }, MONITOR_ART)
end

--- The groups of the top row of the picture after the agents given were
--- advanced to the time 0.
---
---@param ... string the states of the agents
---@return string[]
local function top_row_with(...)
  local stage = scene.stage_of(monitor_pack(), 10, 2)
  stage.advance(scene.agents_in(...), 0)
  return scene.row_groups(stage.picture(), 0, 10)
end

local ON_BROWN = 'AineoOfficePixel_00ff00_885500'

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['a screen'] = MiniTest.new_set()

T['a screen']['shows its own art while its agent holds a pose with no screen'] = function()
  local floor, brown = scene.solid(scene.FLOOR), scene.solid(BROWN)

  eq(top_row_with('standing', 'standing'), {
    floor,
    floor,
    brown,
    brown,
    floor,
    brown,
    brown,
    floor,
    floor,
    floor,
  })
end

T['a screen']['shows the piece the pose of its agent names, in the area of the screen only'] = function()
  local floor, brown = scene.solid(scene.FLOOR), scene.solid(BROWN)

  eq(top_row_with('working', 'standing'), {
    floor,
    floor,
    brown,
    ON_BROWN,
    floor,
    brown,
    brown,
    floor,
    floor,
    floor,
  })
end

T['a screen']['belongs to the agent whose place among the agents is the monitor’s among the monitors'] = function()
  local floor, brown = scene.solid(scene.FLOOR), scene.solid(BROWN)

  eq(top_row_with('standing', 'working'), {
    floor,
    floor,
    brown,
    brown,
    floor,
    brown,
    ON_BROWN,
    floor,
    floor,
    floor,
  })
end

T['a screen']['stays the monitor of its agent when an agent before it leaves'] = function()
  local stage = scene.stage_of(monitor_pack(), 10, 2)
  stage.advance(scene.agents_in('standing', 'working'), 0)

  stage.advance({ { id = 'agent2', state = 'working' } }, 1)
  local row = scene.row_groups(stage.picture(), 0, 10)

  eq({ row[4], row[7] }, { scene.solid(BROWN), ON_BROWN })
end

T['a screen']['begins at its first frame when its agent takes the pose'] = function()
  local pack = scene.people_pack(
    '# plan\n \n ..m.......\n .s........\n',
    { m = { piece = 'monitor' }, s = { spot = 'seat' } },
    {
      characters = {
        agent = {
          colours = { scene.AGENT },
          poses = {
            standing = { art = { 'person' } },
            walking = { art = { 'person' } },
            typing = { art = { 'person' }, screen = 'flash' },
          },
        },
      },
      activities = {
        stand = { steps = { { at = 'seat' } } },
        work = { steps = { { at = 'seat', pose = 'typing' } } },
      },
      states = { standing = 'stand', working = 'work' },
    },
    {
      ['art/monitor.txt'] = MONITOR_ART['art/monitor.txt'],
      ['art/flash.txt'] = 'colours: R = red, G = green\nanchor: 0, 0\nseconds per frame: 1\n---\nRR\nRR\n---\nGG\nGG\n',
    }
  )
  local stage = scene.stage_of(pack, 10, 2)
  stage.advance(scene.agents_in('standing'), 0)
  stage.advance(scene.agents_in('standing'), 1.4)
  stage.advance(scene.agents_in('working'), 1.5)

  stage.advance(scene.agents_in('working'), 1.6)

  eq(scene.group_at(stage.picture(), 3, 0), 'AineoOfficePixel_ff0000_885500')
end

return T
