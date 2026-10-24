local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_named_spots')

--- A stage of `plan` and `legend`, `width` cells wide, whose agents stand at
--- the spot `aside` for a second, and then, when idle, go to the spot `goes_to`
--- names; the state `working` makes an agent sit at its own desk. The random
--- source gives `random_value` every time.
---
---@param plan string
---@param legend table
---@param width integer
---@param goes_to string
---@param random_value? number
---@return aineo.office_scene.Stage
local function stage_of_a_visit(plan, legend, width, goes_to, random_value)
  local pack = scene.people_pack(plan, legend, {
    activities = {
      stand = { steps = { { at = 'aside', for_seconds = 1 } } },
      work = { steps = { { at = 'desk', pose = 'sitting' } } },
      visit = { during = { 'idle' }, steps = { { at = goes_to } } },
    },
    states = { standing = 'stand', idle = 'stand', working = 'work' },
  })
  return scene.stage_of(pack, width, 1, { random = scene.always(random_value or 0) })
end

--- Where the agents with the colours of the first and the second place are,
--- as `column,row` or 'nowhere'.
---
---@param stage aineo.office_scene.Stage
---@param width integer
---@return string[]
local function where_the_two_are(stage, width)
  local picture = stage.picture()
  return {
    scene.agent_cell(picture, width, 1),
    scene.agent_cell(picture, width, 1, scene.SECOND_AGENT),
  }
end

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['a step that goes anywhere'] = MiniTest.new_set()

T['a step that goes anywhere']['goes to a floor cell the random source picks'] = function()
  local legend = { a = { spot = 'aside' } }
  local in_the_middle = stage_of_a_visit('# plan\n \n a.......\n', legend, 8, 'anywhere', 0.5)
  local at_the_end = stage_of_a_visit('# plan\n \n a.......\n', legend, 8, 'anywhere', 0.99)
  local idle = scene.agents_in('idle')
  in_the_middle.advance(idle, 0)
  at_the_end.advance(idle, 0)

  in_the_middle.advance(idle, 3)
  at_the_end.advance(idle, 3)

  eq(
    { where_the_two_are(in_the_middle, 8)[1], where_the_two_are(at_the_end, 8)[1] },
    { '4,0', '7,0' }
  )
end

T['a step whose spot the plan lacks'] = MiniTest.new_set()

local BARE_FLOOR = '# plan\n \n ........\n'

T['a step whose spot the plan lacks']['is played on a floor cell the random source picks by an agent not yet placed'] =
  MiniTest.new_set({ parametrize = { { 0.5, '4,0' }, { 0.99, '7,0' } } })

T['a step whose spot the plan lacks']['is played on a floor cell the random source picks by an agent not yet placed']['random value and cell'] = function(
  random_value,
  cell
)
  local stage = stage_of_a_visit(BARE_FLOOR, {}, 8, 'anywhere', random_value)

  stage.advance(scene.agents_in('standing'), 0)

  eq(where_the_two_are(stage, 8)[1], cell)
end

T['a step whose spot the plan lacks']['is played by two agents on different cells'] = function()
  local stage = stage_of_a_visit(BARE_FLOOR, {}, 8, 'anywhere', 0)

  stage.advance(scene.agents_in('standing', 'standing'), 0)

  eq(where_the_two_are(stage, 8), { '0,0', '1,0' })
end

T['a step whose spot the plan lacks']['is played on the free floor cells nearest the door by agents not yet placed'] = function()
  local stage =
    stage_of_a_visit('# plan\n \n d.......\n', { d = { spot = 'door' } }, 8, 'anywhere', 0.99)

  stage.advance(scene.agents_in('standing', 'standing'), 0)

  eq(where_the_two_are(stage, 8), { '0,0', '1,0' })
end

T['a step whose spot the plan lacks']['is played where an agent already placed stands'] = function()
  local pack = scene.people_pack('# plan\n \n a.......\n', { a = { spot = 'aside' } }, {
    activities = {
      stand = { steps = { { at = 'aside', for_seconds = 1 }, { at = 'nowhere_at_all' } } },
    },
    states = { standing = 'stand' },
  })
  local stage = scene.stage_of(pack, 8, 1, { random = scene.always(0.99) })
  local crew = scene.agents_in('standing')
  stage.advance(crew, 0)

  stage.advance(crew, 3)

  eq(where_the_two_are(stage, 8)[1], '0,0')
end

T['a step that goes to an empty desk'] = MiniTest.new_set()

local DESKS = '# plan\n \n a.d.d.d\n'
local DESKS_LEGEND = { a = { spot = 'aside' }, d = { spot = 'desk', sitting = true } }

T['a step that goes to an empty desk']['goes to the nearest desk no agent has'] = function()
  local stage = stage_of_a_visit(DESKS, DESKS_LEGEND, 8, 'an_empty_desk')
  local crew = scene.agents_in('idle', 'working')
  stage.advance(crew, 0)

  stage.advance(crew, 3)

  eq(where_the_two_are(stage, 8), { '6,0', '4,0' })
end

T['a step that goes to its own desk'] = MiniTest.new_set()

T['a step that goes to its own desk']['goes to a desk no one is at when the plan lacks the agent’s own'] = function()
  local stage = stage_of_a_visit('# plan\n \n a.d....\n', DESKS_LEGEND, 8, 'anywhere')
  local crew = scene.agents_in('standing', 'working')
  stage.advance(crew, 0)

  stage.advance(crew, 3)

  eq(where_the_two_are(stage, 8), { '0,0', '2,0' })
end

T['a step that goes to an idle agent’s desk'] = MiniTest.new_set()

T['a step that goes to an idle agent’s desk']['goes to the desk of another idle agent who is away from it'] = function()
  local stage = stage_of_a_visit('# plan\n \n aad.d.d.\n', DESKS_LEGEND, 8, 'an_idle_agents_desk')
  local crew = scene.agents_in('idle', 'idle', 'working')
  stage.advance(crew, 0)

  stage.advance(crew, 3)

  eq(where_the_two_are(stage, 8), { '4,0', '2,0' })
end

T['a step that goes to an idle agent’s desk']['goes nowhere when no other agent is idle'] = function()
  local stage = stage_of_a_visit('# plan\n \n aad.d.d.\n', DESKS_LEGEND, 8, 'an_idle_agents_desk')
  local crew = scene.agents_in('idle', 'standing')
  stage.advance(crew, 0)

  stage.advance(crew, 3)

  eq(where_the_two_are(stage, 8)[1], '0,0')
end

T['a step that goes next to an agent'] = MiniTest.new_set()

T['a step that goes next to an agent']['goes to the nearest free cell beside another agent who stands still'] = function()
  local stage =
    stage_of_a_visit('# plan\n \n a.....a.\n', { a = { spot = 'aside' } }, 8, 'next_to_an_agent')
  local crew = scene.agents_in('idle', 'standing')
  stage.advance(crew, 0)

  stage.advance(crew, 3)

  eq(where_the_two_are(stage, 8), { '5,0', '6,0' })
end

T['a step that goes next to an agent']['does not go beside an agent on the move'] = function()
  local legend = { a = { spot = 'aside' }, f = { spot = 'far' } }
  local pack = scene.people_pack('# plan\n \n aa' .. ('.'):rep(39) .. 'f\n', legend, {
    activities = {
      stand = { steps = { { at = 'aside', for_seconds = 2 } } },
      walk = { steps = { { at = 'aside', for_seconds = 0.5 }, { at = 'far' } } },
      visit = { during = { 'idle' }, steps = { { at = 'next_to_an_agent' } } },
    },
    states = { standing = 'stand', idle = 'stand', working = 'walk' },
  })
  local stage = scene.stage_of(pack, 42, 1, { random = scene.always(0) })
  local crew = scene.agents_in('idle', 'working')
  stage.advance(crew, 0)
  stage.advance(crew, 1)
  stage.advance(crew, 2)

  stage.advance(crew, 2.5)

  eq(where_the_two_are(stage, 42)[1], '0,0')
end

T['a step that goes next to an agent']['does not go to a cell off the plan, which is another row’s'] = function()
  local pack = scene.people_pack('# plan\n \n ......a\n a......\n', { a = { spot = 'aside' } }, {
    activities = {
      stand = { steps = { { at = 'aside', for_seconds = 1 } } },
      visit = { during = { 'idle' }, steps = { { at = 'next_to_an_agent' } } },
    },
    states = { standing = 'stand', idle = 'stand' },
  })
  local stage = scene.stage_of(pack, 7, 2, { random = scene.always(0) })
  local crew = scene.agents_in('idle', 'standing')
  stage.advance(crew, 0)

  stage.advance(crew, 3)

  eq(scene.agent_cell(stage.picture(), 7, 2), '1,1')
end

T['a step that goes next to an agent']['faces the agent it goes beside'] = function()
  local pack = scene.people_pack('# plan\n \n ..a...a.\n', { a = { spot = 'aside' } }, {
    characters = {
      agent = {
        colours = { scene.AGENT, scene.SECOND_AGENT },
        poses = {
          standing = { art = { 'person' } },
          walking = { art = { 'person' } },
          pointing = { art = { 'three' } },
        },
      },
    },
    activities = {
      stand = { steps = { { at = 'aside', for_seconds = 1 } } },
      visit = { during = { 'idle' }, steps = { { at = 'next_to_an_agent', pose = 'pointing' } } },
    },
    states = { standing = 'stand', idle = 'stand' },
  }, {
    ['art/three.txt'] = 'colours: L = red, M = green, R = blue\nanchor: 0, 1\n---\nLMR\nLMR\n',
  })
  local stage = scene.stage_of(pack, 8, 1, { random = scene.always(0) })
  local crew = scene.agents_in('standing', 'idle')
  stage.advance(crew, 0)

  stage.advance(crew, 3)

  eq(scene.group_at(stage.picture(), 1, 0), scene.solid('#0000ff'))
end

return T
