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

T['a step that goes to an idle agent’s desk'] = MiniTest.new_set()

T['a step that goes to an idle agent’s desk']['goes to the desk of another idle agent who is away from it'] = function()
  local stage = stage_of_a_visit('# plan\n \n aad.d.d.\n', DESKS_LEGEND, 8, 'an_idle_agents_desk')
  local crew = scene.agents_in('idle', 'idle', 'working')
  stage.advance(crew, 0)

  stage.advance(crew, 3)

  eq(where_the_two_are(stage, 8), { '4,0', '2,0' })
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

return T
