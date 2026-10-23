local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_life')

--- An aisle of eight cells with the standing spot `a`, the seat `s` and the
--- far end `f`.
local AISLE = '# plan\n \n a...s..f\n'

local AISLE_LEGEND = {
  a = { spot = 'aside' },
  s = { spot = 'seat', sitting = true },
  f = { spot = 'far' },
}

--- A watched stage of the aisle whose agent plays `activities`, the states
--- `standing` and `idle` playing `stand`; the random source gives
--- `random_value` every time.
---
---@param activities table
---@param random_value number
local function watch_life(activities, random_value)
  local pack = scene.people_pack(AISLE, AISLE_LEGEND, {
    activities = activities,
    states = { standing = 'stand', idle = 'stand' },
  })
  return scene.watch(pack, 8, 1, { random = scene.always(random_value) })
end

local IDLE = scene.agents_in('idle')

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['an agent whose activity is over'] = MiniTest.new_set()

T['an agent whose activity is over']['plays an activity that names its state in during'] = function()
  local watched = watch_life({
    stand = { steps = { { at = 'aside', for_seconds = 1 } } },
    sit_a_while = { during = { 'idle' }, steps = { { at = 'seat', pose = 'sitting' } } },
  }, 0)

  eq({
    watched.cell_at(IDLE, 0),
    watched.cell_at(IDLE, 0.9),
    watched.cell_at(IDLE, 2),
  }, { '0,0', '0,0', '4,0' })
end

T['an agent whose activity is over']['picks among the activities by their chance'] = function()
  local activities = {
    stand = { steps = { { at = 'aside', for_seconds = 1 } } },
    go_far = { during = { 'idle' }, chance = 3, steps = { { at = 'far' } } },
    go_seat = { during = { 'idle' }, chance = 1, steps = { { at = 'seat', pose = 'sitting' } } },
  }
  local before_the_weight = watch_life(activities, 0.5)
  local after_the_weight = watch_life(activities, 0.8)
  before_the_weight.cell_at(IDLE, 0)
  after_the_weight.cell_at(IDLE, 0)

  eq({ before_the_weight.cell_at(IDLE, 3), after_the_weight.cell_at(IDLE, 3) }, { '7,0', '4,0' })
end

T['an agent whose activity is over']['never picks the activity it has just played, and plays another'] = function()
  local watched = watch_life({
    stand = { steps = { { at = 'aside', for_seconds = 1 } } },
    a_seat = { during = { 'idle' }, steps = { { at = 'seat', pose = 'sitting', for_seconds = 1 } } },
    b_far = { during = { 'idle' }, steps = { { at = 'far' } } },
  }, 0)
  watched.cell_at(IDLE, 0)

  eq({ watched.cell_at(IDLE, 2), watched.cell_at(IDLE, 6) }, { '4,0', '7,0' })
end

T['an agent whose activity is over']['keeps its last pose when the only activity it could pick is the one it played'] = function()
  local watched = watch_life({
    stand = { steps = { { at = 'aside', for_seconds = 1 } } },
    a_trip = {
      during = { 'idle' },
      steps = {
        { at = 'seat', pose = 'sitting', for_seconds = 1 },
        { at = 'far', for_seconds = 1 },
      },
    },
  }, 0)
  watched.cell_at(IDLE, 0)

  eq({ watched.cell_at(IDLE, 5), watched.cell_at(IDLE, 12) }, { '7,0', '7,0' })
end

T['an agent whose activity is over']['picks nothing in a state its activities do not name'] = function()
  local watched = watch_life({
    stand = { steps = { { at = 'aside', for_seconds = 1 } } },
    go_far = { during = { 'idle' }, steps = { { at = 'far' } } },
  }, 0)
  local STANDING = scene.agents_in('standing')
  watched.cell_at(STANDING, 0)

  eq(watched.cell_at(STANDING, 5), '0,0')
end

T['an agent whose activity is over']['goes back to the activity its state asks for when the state changes'] = function()
  local watched = watch_life({
    stand = { steps = { { at = 'aside', for_seconds = 1 } } },
    go_far = { during = { 'idle' }, steps = { { at = 'far' } } },
  }, 0)
  watched.cell_at(IDLE, 0)
  watched.cell_at(IDLE, 3)

  eq(watched.cell_at(scene.agents_in('standing'), 6), '0,0')
end

T['an agent whose activity is over']['never picks an activity whose spot the plan lacks'] = function()
  local watched = watch_life({
    stand = { steps = { { at = 'aside', for_seconds = 1 } } },
    a_nowhere = { during = { 'idle' }, steps = { { at = 'nowhere' } } },
    b_far = { during = { 'idle' }, steps = { { at = 'far' } } },
  }, 0)
  watched.cell_at(IDLE, 0)

  eq(watched.cell_at(IDLE, 3), '7,0')
end

--- What the first agent's line of the status list says of what it is doing,
--- in a stage 40 cells wide and 24 rows tall.
---
---@param stage aineo.office_scene.Stage
---@return string
local function listed_line_of(stage)
  local line = stage.picture().rows[21].text:gsub('▀', ' ')
  return vim.trim(line:sub(line:find('main', 1, true) + #'main'):gsub('%s+', ' '))
end

T['an agent whose activity is over']['is listed with the label of the activity it picked'] = function()
  local pack = scene.people_pack(AISLE, AISLE_LEGEND, {
    activities = {
      stand = { steps = { { at = 'aside', for_seconds = 1 } } },
      sit_down = {
        during = { 'idle' },
        label = 'sits down',
        steps = { { at = 'seat', pose = 'sitting' } },
      },
    },
    states = { standing = 'stand', idle = 'stand' },
  })
  local stage =
    scene.stage_of(pack, 40, 24, { random = scene.always(0), state_labels = { idle = 'is idle' } })
  stage.advance(IDLE, 0)
  local before = listed_line_of(stage)

  stage.advance(IDLE, 3)

  eq({ before, listed_line_of(stage) }, { 'is idle', 'sits down' })
end

T['two players'] = MiniTest.new_set()

--- Two cells for the agents to stand in, and the two ends of a table.
local TABLE_PLAN = '# plan\n \n aa..p..q\n'

local TABLE_LEGEND = {
  a = { spot = 'aside' },
  p = { spot = 'table' },
  q = { spot = 'table' },
}

--- A stage whose idle agents stand for a second and then may play a game
--- that needs `players` of them at the table, the random source giving
--- `random_value` every time.
---
---@param players integer
local function stage_of_a_game_for(players)
  local pack = scene.people_pack(TABLE_PLAN, TABLE_LEGEND, {
    activities = {
      stand = { steps = { { at = 'aside', for_seconds = 1 } } },
      game = {
        during = { 'idle' },
        players = players,
        steps = { { at = 'table', pose = 'standing' } },
      },
    },
    states = { standing = 'stand', idle = 'stand' },
  })
  return scene.stage_of(pack, 8, 1, { random = scene.always(0) })
end

--- Where the first and the second agent are, as `column,row` or 'nowhere'.
---
---@param stage aineo.office_scene.Stage
---@return string[]
local function where_the_two_are(stage)
  local picture = stage.picture()
  return {
    scene.agent_cell(picture, 8, 1),
    scene.agent_cell(picture, 8, 1, scene.SECOND_AGENT),
  }
end

T['two players']['start a game for two together, each at a spot of its own'] = function()
  local stage = stage_of_a_game_for(2)
  stage.advance(scene.agents_in('idle'), 0)
  stage.advance(scene.agents_in('idle', 'idle'), 0.5)

  stage.advance(scene.agents_in('idle', 'idle'), 1.6)

  eq(where_the_two_are(stage), { '4,0', '7,0' })
end

T['two players']['do not start a game for two with one agent'] = function()
  local stage = stage_of_a_game_for(2)
  local one_idle = scene.agents_in('idle')
  stage.advance(one_idle, 0)

  stage.advance(one_idle, 3)

  eq(where_the_two_are(stage)[1], '0,0')
end

T['two players']['do not start a game for two at a table with one end'] = function()
  local pack = scene.people_pack('# plan\n \n aa..p...\n', {
    a = { spot = 'aside' },
    p = { spot = 'table' },
  }, {
    activities = {
      stand = { steps = { { at = 'aside', for_seconds = 1 } } },
      game = { during = { 'idle' }, players = 2, steps = { { at = 'table' } } },
    },
    states = { standing = 'stand', idle = 'stand' },
  })
  local stage = scene.stage_of(pack, 8, 1, { random = scene.always(0) })
  local both_idle = scene.agents_in('idle', 'idle')
  stage.advance(both_idle, 0)

  stage.advance(both_idle, 3)

  eq(where_the_two_are(stage), { '0,0', '1,0' })
end

T['two players']['do not take along an agent in a state the game does not name'] = function()
  local stage = stage_of_a_game_for(2)
  local one_idle_one_standing = scene.agents_in('idle', 'standing')
  stage.advance(one_idle_one_standing, 0)

  stage.advance(one_idle_one_standing, 3)

  eq(where_the_two_are(stage)[1], '0,0')
end

T['two players']['do not take along an agent that has no place on the plan yet'] = function()
  local pack = scene.people_pack('# plan\n \n a...p.q.\n', {
    a = { spot = 'aside' },
    p = { spot = 'table' },
    q = { spot = 'table' },
  }, {
    activities = {
      stand = { steps = { { at = 'aside', for_seconds = 1 } } },
      game = { during = { 'idle' }, players = 2, steps = { { at = 'table' } } },
    },
    states = { standing = 'stand', idle = 'stand' },
  })
  local stage = scene.stage_of(pack, 8, 1, { random = scene.always(0) })
  local both_idle = scene.agents_in('idle', 'idle')
  stage.advance(both_idle, 0)

  stage.advance(both_idle, 3)

  eq(where_the_two_are(stage), { '0,0', 'nowhere' })
end

T['two players']['start their game once the second agent is there, the first having looked again'] = function()
  local stage = stage_of_a_game_for(2)
  stage.advance(scene.agents_in('idle'), 0)
  stage.advance(scene.agents_in('idle'), 3)
  stage.advance(scene.agents_in('idle', 'idle'), 3.5)
  stage.advance(scene.agents_in('idle', 'idle'), 6)

  stage.advance(scene.agents_in('idle', 'idle'), 7)

  eq(where_the_two_are(stage), { '4,0', '7,0' })
end

T['two players']['stay at their game for the same time, whenever each arrived'] = function()
  local pack = scene.people_pack(TABLE_PLAN, TABLE_LEGEND, {
    activities = {
      stand = { steps = { { at = 'aside', for_seconds = 1 } } },
      game = {
        during = { 'idle' },
        players = 2,
        steps = { { at = 'table', for_seconds = { 2, 6 } }, { at = 'aside' } },
      },
    },
    states = { standing = 'stand', idle = 'stand' },
  })
  local stage = scene.stage_of(pack, 8, 1, { random = scene.sequence({ 0, 0, 0, 0.99 }, 0) })
  stage.advance(scene.agents_in('idle'), 0)
  stage.advance(scene.agents_in('idle', 'idle'), 0.5)

  stage.advance(scene.agents_in('idle', 'idle'), 3.6)

  eq(where_the_two_are(stage), { '1,0', '5,0' })
end

return T
