local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_steps')

--- An aisle of eight cells with the standing spot `a` and the seat `s`.
local AISLE = '# plan\n \n a...s...\n'

local AISLE_LEGEND = {
  a = { spot = 'aside' },
  s = { spot = 'seat', sitting = true },
}

--- A watched stage of an aisle whose agent plays `activities`, which the
--- state `working` maps to `play`.
---
---@param activities table
---@param options? table more options of the stage
local function watch_activity(activities, options)
  local pack = scene.people_pack(AISLE, AISLE_LEGEND, {
    activities = activities,
    states = { standing = 'play', working = 'play' },
  })
  return scene.watch(pack, 8, 1, options)
end

local WORKING = scene.agents_in('working')

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['a step'] = MiniTest.new_set()

T['a step']['lasts its for_seconds from the agent’s arrival, and then the next one begins'] = function()
  local watched = watch_activity({
    play = {
      steps = {
        { at = 'aside', for_seconds = 2 },
        { at = 'seat', pose = 'sitting' },
      },
    },
  })

  eq({
    watched.cell_at(WORKING, 0),
    watched.cell_at(WORKING, 1.9),
    watched.cell_at(WORKING, 2.5),
  }, { '0,0', '0,0', '4,0' })
end

T['a step']['lasts a time between its two for_seconds numbers, by the random source'] = function()
  local steps = {
    { at = 'aside', for_seconds = { 2, 4 } },
    { at = 'seat', pose = 'sitting' },
  }
  local shortest = watch_activity({ play = { steps = steps } }, {
    random = function()
      return 0
    end,
  })
  local middle = watch_activity({ play = { steps = steps } }, {
    random = function()
      return 0.5
    end,
  })

  eq({
    shortest.cell_at(WORKING, 0),
    shortest.cell_at(WORKING, 2.5),
    middle.cell_at(WORKING, 0),
    middle.cell_at(WORKING, 2.5),
    middle.cell_at(WORKING, 3.5),
  }, { '0,0', '4,0', '0,0', '0,0', '4,0' })
end

--- The people of the packs that point: one cell wide, but for `pointing`,
--- which is two cells wide, the agent's cell and a blue one beside it.
local POINTING_PEOPLE = {
  agent = {
    colours = { scene.AGENT, scene.SECOND_AGENT },
    poses = {
      standing = { art = { 'person' } },
      walking = { art = { 'person' } },
      sitting = { art = { 'person' }, sitting = true },
      pointing = { art = { 'walker' } },
    },
  },
}

--- The groups of the cells around the seat at column 4 of the aisle, in
--- the picture of an agent who points there for the step `step` gives.
---
---@param step table
---@return string[]
local function cells_around_pointing(step)
  local pack = scene.people_pack(AISLE, AISLE_LEGEND, {
    characters = POINTING_PEOPLE,
    activities = {
      play = { steps = { vim.tbl_extend('force', { at = 'seat', pose = 'pointing' }, step) } },
    },
    states = { standing = 'play', working = 'play' },
  })
  local stage = scene.stage_of(pack, 8, 1)
  stage.advance(WORKING, 0)
  return vim.list_slice(scene.row_groups(stage.picture(), 0, 8), 4, 6)
end

T['a step']['faces the way its spot does, to the right unless the spot says left'] = function()
  eq(cells_around_pointing({}), {
    scene.solid(scene.FLOOR),
    scene.solid(scene.AGENT),
    scene.solid('#0000ff'),
  })
end

T['a step']['faces the way its facing says, over its spot’s'] = function()
  eq(cells_around_pointing({ facing = 'left' }), {
    scene.solid('#0000ff'),
    scene.solid(scene.AGENT),
    scene.solid(scene.FLOOR),
  })
end

--- The text of the row above the agent at the seat of a two row aisle, for
--- an agent whose activity is `play`.
---
---@param activity table
---@return string
local function row_above_seat(activity)
  local pack = scene.people_pack('# plan\n \n ........\n a...s...\n', AISLE_LEGEND, {
    characters = {
      agent = {
        colours = { scene.AGENT },
        poses = {
          standing = { art = { 'person' } },
          walking = { art = { 'person' } },
          typing = { art = { 'person' }, effect = 'dots' },
        },
      },
    },
    effects = { dots = { text = { '.' } }, bang = { text = { '!' } } },
    activities = { play = activity },
    states = { standing = 'play', working = 'play' },
  })
  local stage = scene.stage_of(pack, 8, 2)
  stage.advance(WORKING, 0)
  return vim.fn.strcharpart(stage.picture().rows[1].text, 4, 1)
end

T['a step']['shows the effect it names above the agent’s head'] = function()
  eq(row_above_seat({ steps = { { at = 'seat', pose = 'standing', effect = 'bang' } } }), '!')
end

T['a step']['shows the effect it names in place of its pose’s'] = function()
  eq(row_above_seat({ steps = { { at = 'seat', pose = 'typing', effect = 'bang' } } }), '!')
  eq(row_above_seat({ steps = { { at = 'seat', pose = 'typing' } } }), '.')
end

T['an agent'] = MiniTest.new_set()

T['an agent']['plays the activity a trigger chose for what it is doing, in place of its state’s'] = function()
  local pack = scene.people_pack(AISLE, AISLE_LEGEND)
  local watched = scene.watch(pack, 8, 1)

  eq({
    watched.cell_at({ { id = 'main', state = 'standing' } }, 0),
    watched.cell_at({ { id = 'main', state = 'standing', activity = 'work' } }, 1),
    watched.cell_at({ { id = 'main', state = 'standing', activity = 'no_such_activity' } }, 2),
  }, { '0,0', '4,0', '0,0' })
end

T['an agent']['stays in an activity that its new state plays too, without beginning it again'] = function()
  local pack = scene.people_pack(AISLE, AISLE_LEGEND, {
    activities = {
      play = { steps = { { at = 'aside', for_seconds = 1 }, { at = 'seat', pose = 'sitting' } } },
    },
    states = { standing = 'play', working = 'play' },
  })
  local watched = scene.watch(pack, 8, 1)

  eq({
    watched.cell_at(scene.agents_in('standing'), 0),
    watched.cell_at(scene.agents_in('working'), 1.5),
  }, { '0,0', '4,0' })
end

--- A plan of an aisle with two benches, a spot `b` at columns 2 and 6, and
--- the spots `a` at column 0 and `c` at column 4.
local BENCH_AISLE = '# plan\n \n a.b.c.b..\n'

local BENCH_LEGEND = {
  a = { spot = 'aside' },
  b = { spot = 'bench' },
  c = { spot = 'start' },
}

T['an agent']['goes to the nearest spot of the name that no other agent has taken'] = function()
  local pack = scene.people_pack(BENCH_AISLE, BENCH_LEGEND, {
    activities = {
      stand = { steps = { { at = 'aside' } } },
      rest = { steps = { { at = 'start' } } },
      sit = { steps = { { at = 'bench' } } },
    },
    states = { standing = 'stand', resting = 'rest', working = 'sit' },
  })
  local stage = scene.stage_of(pack, 9, 1)
  stage.advance(scene.agents_in('standing', 'resting'), 0)

  stage.advance(scene.agents_in('working', 'working'), 0.1)
  stage.advance(scene.agents_in('working', 'working'), 5)
  local picture = stage.picture()

  eq(scene.agent_cell(picture, 9, 1), '2,0')
  eq(scene.agent_cell(picture, 9, 1, scene.SECOND_AGENT), '6,0')
end

T['an agent']['has its own desk, the one in its place among the agents, even when the first is free'] = function()
  local pack = scene.people_pack('# plan\n \n .d.d.\n', { d = { spot = 'desk' } }, {
    states = { standing = 'stand', working = 'play' },
    activities = {
      stand = { steps = { { at = 'aside' } } },
      play = { steps = { { at = 'desk' } } },
    },
  })
  local stage = scene.stage_of(pack, 5, 1)

  stage.advance({ { id = 'main', state = 'standing' }, { id = 'agent2', state = 'working' } }, 0)

  eq(scene.agent_cell(stage.picture(), 5, 1, scene.SECOND_AGENT), '3,0')
end

T['an agent']['appears once the agent that had its spot is gone'] = function()
  local pack = scene.people_pack('# plan\n \n a...s...\n', AISLE_LEGEND)
  local stage = scene.stage_of(pack, 8, 1)
  stage.advance(scene.agents_in('standing', 'standing'), 0)

  stage.advance({ { id = 'agent2', state = 'standing' } }, 1)
  stage.advance({ { id = 'agent2', state = 'standing' } }, 2)

  eq(scene.agent_cell(stage.picture(), 8, 1), '0,0')
end

T['an agent']['appears once a spot it had none for is let go'] = function()
  local pack = scene.people_pack('# plan\n \n a...s...\n', AISLE_LEGEND)
  local stage = scene.stage_of(pack, 8, 1)
  stage.advance(scene.agents_in('standing', 'standing'), 0)
  local before = scene.agent_cell(stage.picture(), 8, 1, scene.SECOND_AGENT)

  stage.advance(scene.agents_in('working', 'standing'), 1)
  stage.advance(scene.agents_in('working', 'standing'), 2)

  eq({ before, scene.agent_cell(stage.picture(), 8, 1, scene.SECOND_AGENT) }, { 'nowhere', '0,0' })
end

return T
