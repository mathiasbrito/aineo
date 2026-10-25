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

--- The colour of the pose agents think in at the board, `pondering`, which
--- draws them in it instead of their own.
local PONDERING = '#0000ff'

--- The colour of the pose agents rest in on the sofa, `lounging`, which draws
--- them in it instead of their own.
local LOUNGING = '#ff0000'

--- A corridor between two posts, `p`, with a sofa (`f`) and a seat (`s`)
--- near each end, so that an agent going from the left post to the seat
--- and one going from the right post to the sofa meet halfway, between two
--- shelves (`k`); and, below, a board (`b`) and floor.
local CROSSING_CORRIDOR = '# plan\n \n pfk.ksp\n b......\n'

local CROSSING_CORRIDOR_LEGEND = {
  p = { spot = 'post' },
  f = { spot = 'sofa' },
  k = { spot = 'shelf' },
  s = { spot = 'seat' },
  b = { spot = 'board' },
}

--- A stage of `plan`, `CROSSING_CORRIDOR` by default, whose agents stand at
--- a post, work at the seat, rest on the sofa, `lounging`, and think at the
--- board, `pondering`, in four colours.
---
---@param plan? string a plan of two rows and `CROSSING_CORRIDOR_LEGEND`'s letters
---@param width? integer the plan's width, 7 by default
---@return aineo.office_scene.Stage
local function crossing_corridor(plan, width)
  local pack = scene.people_pack(plan or CROSSING_CORRIDOR, CROSSING_CORRIDOR_LEGEND, {
    characters = vim.tbl_deep_extend(
      'force',
      FOUR_COLOURS,
      { agent = { poses = { pondering = { art = { 'right' } }, lounging = { art = { 'left' } } } } }
    ),
    activities = {
      stand = { steps = { { at = 'post' } } },
      work = { steps = { { at = 'seat' } } },
      rest = { steps = { { at = 'sofa', pose = 'lounging' } } },
      think = { steps = { { at = 'board', pose = 'pondering' } } },
    },
    states = { standing = 'stand', working = 'work', resting = 'rest', thinking = 'think' },
  })
  return scene.stage_of(pack, width or 7, 2)
end

--- Where the first two agents, the one pondering and the one lounging are
--- drawn on the crossing corridor's stage.
---
---@param stage aineo.office_scene.Stage
---@return string[]
local function where_on_the_corridor(stage)
  local picture = stage.picture()
  return vim.tbl_map(function(colour)
    return scene.agent_cell(picture, 7, 2, colour)
  end, { scene.AGENT, scene.SECOND_AGENT, PONDERING, LOUNGING })
end

--- Has the first two agents of `crossing_corridor()` walk towards each other,
--- the third at the board, until they meet on the corridor's middle cell.
---
---@param stage aineo.office_scene.Stage
local function meet_halfway(stage)
  stage.advance(crew('standing', 'standing', 'thinking'), 0)
  stage.advance(crew('working', 'resting', 'thinking'), 0)
  stage.advance(crew('working', 'resting', 'thinking'), 3 / 14)
end

T['agents whose spot is taken on their way'] = MiniTest.new_set()

T['agents whose spot is taken on their way']['never wait for it on one cell: the one that halts second steps to a free cell no spot is on, standing'] = function()
  local stage = crossing_corridor()
  meet_halfway(stage)

  stage.advance(crew('thinking', 'thinking', 'thinking'), 0.5)
  stage.advance(crew('thinking', 'thinking', 'thinking'), 2)

  eq(where_on_the_corridor(stage), { '3,0', '3,1', '0,1', 'nowhere' })
end

T['agents whose spot is taken on their way']['wait where they halt while another only walks over their cell'] = function()
  local stage = crossing_corridor()
  meet_halfway(stage)

  stage.advance(crew('thinking', 'resting', 'thinking'), 0.5)
  stage.advance(crew('thinking', 'resting', 'thinking'), 2)

  eq(where_on_the_corridor(stage), { '3,0', 'nowhere', '0,1', '1,0' })
end

T['agents whose spot is taken on their way']['go to it once it is let go, the one that stepped out of the way in the spot’s pose'] = function()
  local stage = crossing_corridor()
  meet_halfway(stage)
  stage.advance(crew('thinking', 'thinking', 'thinking'), 0.5)

  stage.advance(crew('standing', 'thinking', 'standing'), 1)
  stage.advance(crew('standing', 'thinking', 'standing'), 4)

  eq(where_on_the_corridor(stage), { '0,0', 'nowhere', '0,1', 'nowhere' })
end

T['agents whose spot is taken on their way']['take the pose of a step they begin while stepping out of the way'] = function()
  local stage = crossing_corridor()
  meet_halfway(stage)
  stage.advance(crew('thinking', 'thinking', 'thinking'), 3 / 14 + 0.01)

  stage.advance(crew('thinking', 'resting', 'thinking'), 3 / 14 + 0.02)
  stage.advance(crew('thinking', 'resting', 'thinking'), 2)

  eq(where_on_the_corridor(stage), { '3,0', 'nowhere', '0,1', '1,0' })
end

--- A corridor as `CROSSING_CORRIDOR`, 35 cells wide, whose agents meet on
--- its middle cell, the only cell of floor no spot is on but one, 18 cells
--- away at the end of a row of shelves.
local LONG_CROSSING_CORRIDOR = '# plan\n \n pf'
  .. ('k'):rep(15)
  .. '.'
  .. ('k'):rep(15)
  .. 'sp\n b'
  .. ('k'):rep(33)
  .. '.\n'

T['agents whose spot is taken on their way']['go to it when it is let go while they step out of the way, in the spot’s pose'] = function()
  local stage = crossing_corridor(LONG_CROSSING_CORRIDOR, 35)
  local met = 17 / 14
  stage.advance(crew('standing', 'standing', 'thinking'), 0)
  stage.advance(crew('working', 'resting', 'thinking'), 0)
  stage.advance(crew('working', 'resting', 'thinking'), met)
  stage.advance(crew('thinking', 'thinking', 'thinking'), met + 0.01)

  stage.advance(crew('standing', 'thinking', 'standing'), met + 0.5)
  stage.advance(crew('standing', 'thinking', 'standing'), met + 1.05)
  stage.advance(crew('standing', 'thinking', 'standing'), met + 6)

  local picture = stage.picture()
  eq({
    scene.agent_cell(picture, 35, 2, scene.SECOND_AGENT),
    scene.agent_cell(picture, 35, 2, PONDERING),
  }, { 'nowhere', '0,1' })
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
  local pack = scene.people_pack('# plan\n \n a\n', { a = { spot = 'aside' } }, {
    activities = {
      stand = { steps = { { at = 'aside', for_seconds = { 1, 2 } }, { at = 'aside' } } },
    },
  })
  local stage = scene.stage_of(pack, 1, 1, {
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

T['an agent with no desk of its own'] = MiniTest.new_set()

--- A stage of `plan`, `width` cells wide, whose desks are `d`, whose spots
--- to stand at are `a` and whose spots beside a desk are `b`; an agent
--- stands at `aside` while standing or idle and sits at its `desk` while
--- working, in four colours.
---
---@param plan string
---@param width integer
---@return aineo.office_scene.Stage
local function desks_and_asides(plan, width)
  local pack = scene.people_pack(plan, {
    d = { spot = 'desk', sitting = true },
    a = { spot = 'aside' },
    b = { spot = 'beside_desk' },
  }, {
    characters = FOUR_COLOURS,
    activities = {
      stand = { steps = { { at = 'aside', pose = 'standing' } } },
      work = { steps = { { at = 'desk', pose = 'sitting' } } },
    },
    states = { standing = 'stand', idle = 'stand', working = 'work' },
  })
  return scene.stage_of(pack, width, 1)
end

--- The agents `main`, `two`, `three` and `four`, each in the state given, or
--- left out where `false` is given.
---
---@param ... string|false
---@return aineo.office_states.Agent[]
local function crew_of_four(...)
  local agents = {}
  for index, state in ipairs({ ... }) do
    if state then
      table.insert(agents, { id = ({ 'main', 'two', 'three', 'four' })[index], state = state })
    end
  end
  return agents
end

T['an agent with no desk of its own']['works at a desk no agent has, not at an agent’s own while it is away'] = function()
  local stage = desks_and_asides('# plan\n \n aaa.d.d\n', 7)
  stage.advance(crew_of_four('standing', 'standing', 'standing'), 0)
  stage.advance(crew_of_four('standing', false, 'standing'), 1)

  stage.advance(crew_of_four('standing', false, 'working'), 2)
  stage.advance(crew_of_four('standing', false, 'working'), 8)

  eq(where_are(stage, 7)[3], '6,0')
end

T['an agent with no desk of its own']['works, when no desk is empty, at the desk of an idle agent away from it'] = function()
  local stage = desks_and_asides('# plan\n \n aaa.d.d\n', 7)
  stage.advance(crew_of_four('standing', 'idle', 'standing'), 0)

  stage.advance(crew_of_four('standing', 'idle', 'working'), 1)
  stage.advance(crew_of_four('standing', 'idle', 'working'), 8)

  eq(where_are(stage, 7)[3], '6,0')
end

T['an agent with no desk of its own']['steps off beside the desk when its owner comes back, and the owner sits'] = function()
  local stage = desks_and_asides('# plan\n \n aa.db\n', 5)
  stage.advance(crew_of_four('idle', 'working'), 0)
  stage.advance(crew_of_four('idle', 'working'), 6)

  stage.advance(crew_of_four('working', 'working'), 7)
  stage.advance(crew_of_four('working', 'working'), 14)

  eq(vim.list_slice(where_are(stage, 5), 1, 2), { '3,0', '4,0' })
end

T['an agent with no desk of its own']['leaves the empty desk another such agent is at to it'] = function()
  local stage = desks_and_asides('# plan\n \n aaaa.d.d\n', 8)
  stage.advance(crew_of_four('standing', 'standing', 'standing', 'standing'), 0)
  stage.advance(crew_of_four('standing', false, 'standing', 'standing'), 1)

  stage.advance(crew_of_four('standing', false, 'working', 'working'), 2)
  stage.advance(crew_of_four('standing', false, 'working', 'working'), 10)

  eq(vim.list_slice(where_are(stage, 8), 3, 4), { '7,0', '3,0' })
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
