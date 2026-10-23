local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_cost')

--- The most an update of the stage, one agent or many, may take, in
--- milliseconds: well under the 83 ms between two frames.
local MOST_MILLISECONDS_AN_UPDATE = 50

--- The most a picture of the stage may take, in milliseconds.
local MOST_MILLISECONDS_A_PICTURE = 20

--- The most laying a stage out may take, at its first size or a new one.
local MOST_MILLISECONDS_TO_LAY_OUT = 100

--- How long `work` takes, in milliseconds.
---
---@param work fun()
---@return number
local function milliseconds_of(work)
  local started = vim.uv.hrtime()
  work()
  return (vim.uv.hrtime() - started) / 1e6
end

--- `count` agents, the first `main`, all in `state`.
---
---@param count integer
---@param state string
---@return aineo.office_states.Agent[]
local function crowd(count, state)
  local agents = {}
  for index = 1, count do
    agents[index] = { id = index == 1 and 'main' or ('sub' .. index), state = state }
  end
  return agents
end

--- A plan of an open floor, two cells wide, that repeats to any size, with
--- a spot `a` in its top left corner.
local OPEN_FLOOR = '# plan\n  ~\n a.\n~..\n ..\n'

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['an update'] = MiniTest.new_set()

T['an update']['of an activity of 400 steps of no length at one spot is cheap on the largest stage'] = function()
  local steps = {}
  for index = 1, 400 do
    steps[index] = { at = 'aside', for_seconds = { 0, 0 } }
  end
  local pack = scene.people_pack(OPEN_FLOOR, { a = { spot = 'aside' } }, {
    activities = {
      stand = { steps = { { at = 'aside' } } },
      work = { steps = steps },
    },
  })
  local stage = scene.stage_of(pack, 220, 80)
  stage.advance(crowd(1, 'standing'), 0)

  local milliseconds = milliseconds_of(function()
    stage.advance(crowd(1, 'working'), 0.083)
  end)

  eq(milliseconds < MOST_MILLISECONDS_AN_UPDATE, true)
end

T['an update']['in which 65 agents change their activity is cheap on the largest stage'] = function()
  local pack = scene.people_pack('# plan\n  ~\n aa\n~..\n ff\n', {
    a = { spot = 'aside' },
    f = { spot = 'far' },
  }, {
    activities = {
      stand = { steps = { { at = 'aside' } } },
      work = { steps = { { at = 'far', pose = 'sitting' } } },
    },
  })
  local stage = scene.stage_of(pack, 220, 80)
  stage.advance(crowd(65, 'standing'), 0)

  local milliseconds = milliseconds_of(function()
    stage.advance(crowd(65, 'working'), 0.083)
  end)

  eq(milliseconds < MOST_MILLISECONDS_AN_UPDATE, true)
end

T['a frame'] = MiniTest.new_set()

T['a frame']['of 2,000 pieces of the largest art, hung from their tops, costs under 20 ms'] = function()
  local rows = (('R'):rep(400) .. '\n'):rep(200)
  local pack = scene.people_pack('# plan\n ~\n~P\n', { P = { piece = 'huge' } }, nil, {
    ['art/huge.txt'] = 'colours: R = red\nanchor: 0, 0\n---\n' .. rows,
  })
  local stage = scene.stage_of(pack, 220, 80)
  stage.advance({}, 0)

  local milliseconds = milliseconds_of(function()
    stage.picture()
  end)

  eq(milliseconds < MOST_MILLISECONDS_A_PICTURE, true)
end

T['a stage'] = MiniTest.new_set()

--- A pack whose every cell is a monitor with `in_use` art and a spot.
---
---@return aineo.office_pack.Pack
local function pack_with_a_spot_in_every_cell()
  return scene.people_pack(
    '# plan\n ~\n~P\n',
    {
      P = { piece = 'monitor', in_use = 'monitor_on', spot = 'seat' },
    },
    nil,
    {
      ['art/monitor.txt'] = 'colours: R = red\nanchor: 0, 1\n---\nR\nR\n',
      ['art/monitor_on.txt'] = 'colours: G = green\nanchor: 0, 1\n---\nG\nG\n',
    }
  )
end

T['a stage']['is made in under 100 ms from a plan with a spot and a piece in use in every cell'] = function()
  local pack = pack_with_a_spot_in_every_cell()

  local milliseconds = milliseconds_of(function()
    scene.stage_of(pack, 220, 80)
  end)

  eq(milliseconds < MOST_MILLISECONDS_TO_LAY_OUT, true)
end

T['a stage']['is laid out again in under 100 ms for a new size'] = function()
  local stage = scene.stage_of(pack_with_a_spot_in_every_cell(), 220, 80)

  local milliseconds = milliseconds_of(function()
    stage.resize(219, 80)
  end)

  eq(milliseconds < MOST_MILLISECONDS_TO_LAY_OUT, true)
end

T['an update']['begins at most eight steps of an agent, the rest in the updates after'] = function()
  local draws = 0
  local steps = {}
  for index = 1, 20 do
    steps[index] = { at = 'aside', for_seconds = { 0, 0 } }
  end
  local pack = scene.people_pack('# plan\n \n a...\n', { a = { spot = 'aside' } }, {
    activities = { stand = { steps = steps } },
  })
  local stage = scene.stage_of(pack, 4, 1, {
    random = function()
      draws = draws + 1
      return 0
    end,
  })

  stage.advance(scene.agents_in('standing'), 0)
  local after_one = draws
  stage.advance(scene.agents_in('standing'), 1)
  local after_two = draws
  stage.advance(scene.agents_in('standing'), 2)

  eq({ after_one, after_two, draws }, { 8, 16, 20 })
end

return T
