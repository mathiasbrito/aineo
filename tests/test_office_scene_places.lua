local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_places')

local YELLOW = '#ffff00'
local LIME = '#00ff00'

--- The people of the packs here: one cell wide, in four colours, which the
--- agents take by their places, the first the agent's.
local FOUR_COLOURS = {
  agent = {
    colours = { scene.AGENT, scene.SECOND_AGENT, YELLOW, LIME },
    poses = {
      standing = { art = { 'person' } },
      walking = { art = { 'person' } },
      sitting = { art = { 'person' }, sitting = true },
    },
  },
}

--- Where the agents with the colours of the first four places are, as
--- `{ first, second, third, fourth }`, each `column,row` or 'nowhere'.
---
---@param stage aineo.office_scene.Stage
---@param width integer
---@return string[]
local function where_are(stage, width)
  local picture = stage.picture()
  return vim.tbl_map(function(colour)
    return scene.agent_cell(picture, width, 1, colour)
  end, { scene.AGENT, scene.SECOND_AGENT, YELLOW, LIME })
end

--- A stage of `plan` and `legend`, 6 cells wide, whose agents think at the
--- board and work at a seat, in four colours.
---
---@param plan string
---@param legend table
---@return aineo.office_scene.Stage
local function seats_and_a_board(plan, legend)
  local pack = scene.people_pack(plan, legend, {
    characters = FOUR_COLOURS,
    activities = {
      think = { steps = { { at = 'board' } } },
      work = { steps = { { at = 'seat' } } },
    },
    states = { standing = 'think', working = 'work' },
  })
  return scene.stage_of(pack, 6, 1)
end

local SEATS_AND_A_BOARD = '# plan\n \n s.b..s\n'

local SEATS_AND_A_BOARD_LEGEND = {
  s = { spot = 'seat', sitting = true },
  b = { spot = 'board' },
}

--- The agents `main`, `two` and `three` in the states given, in that order.
---
---@param ... string
---@return aineo.office_states.Agent[]
local function crew(...)
  local agents = {}
  for index, state in ipairs({ ... }) do
    agents[index] = { id = ({ 'main', 'two', 'three' })[index], state = state }
  end
  return agents
end

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['an agent whose spot is taken'] = MiniTest.new_set()

T['an agent whose spot is taken']['keeps the spot it stands on, which no other agent then takes'] = function()
  local stage = seats_and_a_board(SEATS_AND_A_BOARD, SEATS_AND_A_BOARD_LEGEND)
  stage.advance(crew('standing', 'working'), 0)
  stage.advance(crew('standing', 'standing'), 1)

  stage.advance(crew('standing', 'standing', 'working'), 2)
  stage.advance(crew('standing', 'standing', 'working'), 4)

  eq(where_are(stage, 6), { '2,0', '0,0', '5,0', 'nowhere' })
end

T['an agent whose spot is taken']['goes to the spot when it is let go, and the agent leaving it finds another seat'] = function()
  local stage = seats_and_a_board(SEATS_AND_A_BOARD, SEATS_AND_A_BOARD_LEGEND)
  stage.advance(crew('standing', 'working'), 0)
  stage.advance(crew('standing', 'standing'), 1)

  stage.advance(crew('working', 'standing'), 2)
  stage.advance(crew('working', 'standing'), 2.5)
  local half_a_second_after = where_are(stage, 6)
  stage.advance(crew('working', 'standing'), 6)

  eq(half_a_second_after, { '5,0', '2,0', 'nowhere', 'nowhere' })
  eq(where_are(stage, 6), { '5,0', '2,0', 'nowhere', 'nowhere' })
end

T['an agent whose spot is taken']['stays seated behind the desk of its seat while it waits'] = function()
  local stage = seats_and_a_board(SEATS_AND_A_BOARD, {
    s = { spot = 'seat', sitting = true, piece = 'desk' },
    b = { spot = 'board' },
  })
  stage.advance(crew('standing', 'working'), 0)

  stage.advance(crew('standing', 'standing'), 1)

  eq(where_are(stage, 6), { '2,0', 'nowhere', 'nowhere', 'nowhere' })
end

T['an agent'] = MiniTest.new_set()

T['an agent']['keeps its place, and so its desk and colour, while others come and go'] = function()
  local pack = scene.people_pack(
    '# plan\n \n d.d.d.\n',
    { d = { spot = 'desk', sitting = true } },
    {
      characters = FOUR_COLOURS,
      activities = { work = { steps = { { at = 'desk', pose = 'sitting' } } } },
      states = { standing = 'work', working = 'work' },
    }
  )
  local stage = scene.stage_of(pack, 6, 1)
  local main, two, three =
    { id = 'main', state = 'working' },
    { id = 'two', state = 'working' },
    { id = 'three', state = 'working' }
  local four = { id = 'four', state = 'working' }
  stage.advance({ main, two, three }, 0)

  stage.advance({ main, three }, 1)
  stage.advance({ main, three, four }, 2)

  eq(where_are(stage, 6), { '0,0', '2,0', '4,0', 'nowhere' })
end

T['an agent']['draws random times only once it has a place, however many frames it waited for one'] = function()
  local draws = 0
  local pack = scene.people_pack('# plan\n \n a...\n', { a = { spot = 'aside' } }, {
    activities = {
      stand = { steps = { { at = 'aside', for_seconds = { 1, 2 } }, { at = 'aside' } } },
    },
  })
  local stage = scene.stage_of(pack, 4, 1, {
    random = function()
      draws = draws + 1
      return 0.5
    end,
  })
  local agents = scene.agents_in('standing', 'standing')

  for frame = 0, 23 do
    stage.advance(agents, frame / 12)
  end

  eq(draws, 1)
end

T['a stage'] = MiniTest.new_set()

--- A stage of a long aisle whose agent stands at one end for a second and
--- then walks to the other.
---
---@return { stage: aineo.office_scene.Stage, cell_at: fun(agents: aineo.office_states.Agent[], time: number): string }
local function aisle_to_walk()
  local pack = scene.people_pack(
    '# plan\n \n a.........s\n',
    { a = { spot = 'aside' }, s = { spot = 'seat', sitting = true } },
    {
      activities = {
        stand = { steps = { { at = 'aside' } } },
        work = { steps = { { at = 'aside', for_seconds = 1 }, { at = 'seat', pose = 'sitting' } } },
      },
    }
  )
  return scene.watch(pack, 11, 1)
end

T['a stage']['keeps an agent walking where it was when it is resized'] = function()
  local watched = aisle_to_walk()
  watched.cell_at(scene.agents_in('working'), 0)
  local before = watched.cell_at(scene.agents_in('working'), 1.3)

  watched.stage.resize(12, 1)

  eq({ before, watched.cell_at(scene.agents_in('working'), 1.4) }, { '4,0', '6,0' })
end

T['a stage']['keeps a seated agent seated when it is resized'] = function()
  local watched = aisle_to_walk()
  watched.cell_at(scene.agents_in('working'), 0)
  watched.cell_at(scene.agents_in('working'), 1.2)
  local seated = watched.cell_at(scene.agents_in('working'), 3)

  watched.stage.resize(12, 1)

  eq({ seated, watched.cell_at(scene.agents_in('working'), 3.05) }, { '10,0', '10,0' })
end

T['a stage']['draws for the agents that lose their way in a resize in the order they were given'] = function()
  local colours = { scene.AGENT, scene.SECOND_AGENT, YELLOW, LIME, '#ff8800', '#0088ff' }
  local pack = scene.people_pack('# plan\n \n aaaaaa..............\n', { a = { spot = 'aside' } }, {
    characters = {
      agent = {
        colours = colours,
        poses = { standing = { art = { 'person' } }, walking = { art = { 'person' } } },
      },
    },
    activities = {
      stand = {
        steps = { { at = 'aside', for_seconds = 1 }, { at = 'anywhere', for_seconds = 5 } },
      },
    },
    states = { standing = 'stand' },
  })
  local first_draws = { 0.99, 0.99, 0.99, 0.99, 0.99, 0.99 }
  local draws = vim.list_extend(first_draws, { 0.11, 0.21, 0.31, 0.41, 0.51, 0.61 })
  local stage = scene.stage_of(pack, 20, 1, { random = scene.sequence(draws, 0) })
  local six =
    scene.agents_in('standing', 'standing', 'standing', 'standing', 'standing', 'standing')
  stage.advance(six, 0)
  stage.advance(six, 1.05)

  stage.resize(20, 1)
  stage.advance(six, 4)

  local picture = stage.picture()
  eq(
    vim.tbl_map(function(colour)
      return scene.agent_cell(picture, 20, 1, colour)
    end, colours),
    { '2,0', '4,0', '6,0', '8,0', '10,0', '12,0' }
  )
end

return T
