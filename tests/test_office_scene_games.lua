local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_games')

local YELLOW = '#ffff00'

--- The people of the packs here: one cell wide, in three colours.
local THREE_PEOPLE = {
  agent = {
    colours = { scene.AGENT, scene.SECOND_AGENT, YELLOW },
    poses = {
      standing = { art = { 'person' } },
      walking = { art = { 'person' } },
      sitting = { art = { 'person' }, sitting = true },
    },
  },
}

--- Where the first, the second and the third agent are, as `column,row`
--- or 'nowhere'.
---
---@param stage aineo.office_scene.Stage
---@param width integer
---@return string[]
local function where_the_three_are(stage, width)
  local picture = stage.picture()
  return {
    scene.agent_cell(picture, width, 1),
    scene.agent_cell(picture, width, 1, scene.SECOND_AGENT),
    scene.agent_cell(picture, width, 1, YELLOW),
  }
end

--- Advances `stage` every tenth of a second from `from` to `to` seconds, the
--- agents being those `agents_at` gives for the time.
---
---@param stage aineo.office_scene.Stage
---@param agents_at fun(time: number): aineo.office_states.Agent[]
---@param from number
---@param to number
local function advance_every_tenth_second(stage, agents_at, from, to)
  for tenths = math.floor(from * 10 + 0.5), math.floor(to * 10 + 0.5) do
    stage.advance(agents_at(tenths / 10), tenths / 10)
  end
end

--- The agents `main`, `agent2` and `agent3` in the states given.
---
---@param first string
---@param second? string
---@param third? string
---@return aineo.office_states.Agent[]
local function crew(first, second, third)
  local agents = { { id = 'main', state = first } }
  if second then
    table.insert(agents, { id = 'agent2', state = second })
  end
  if third then
    table.insert(agents, { id = 'agent3', state = third })
  end
  return agents
end

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['a game for two'] = MiniTest.new_set()

--- A stage with three standing places and four ends of tables, whose idle
--- agents stand for a second and then may play a game for two.
---
---@param random? fun(): number
---@return aineo.office_scene.Stage
local function stage_of_a_game_with_three_agents(random)
  local pack = scene.people_pack('# plan\n \n aaa.p.q.r.s\n', {
    a = { spot = 'aside' },
    p = { spot = 'table' },
    q = { spot = 'table' },
    r = { spot = 'table' },
    s = { spot = 'table' },
  }, {
    characters = THREE_PEOPLE,
    activities = {
      stand = { steps = { { at = 'aside', for_seconds = 1 } } },
      work = { steps = { { at = 'aside' } } },
      game = { during = { 'idle' }, players = 2, steps = { { at = 'table', for_seconds = 10 } } },
    },
    states = { standing = 'stand', idle = 'stand', working = 'work' },
  })
  return scene.stage_of(pack, 11, 1, { random = random or scene.always(0) })
end

T['a game for two']['is not left by a player for a third agent whose activity is over'] = function()
  local stage = stage_of_a_game_with_three_agents()
  local all_idle = crew('idle', 'idle', 'idle')
  advance_every_tenth_second(stage, function()
    return all_idle
  end, 0, 3)

  eq(where_the_three_are(stage, 11), { '4,0', '6,0', '2,0' })
end

T['a game for two']['is played by the partner drawn at random'] = function()
  local stage = stage_of_a_game_with_three_agents(scene.sequence({ 0, 0.99 }, 0))
  local all_idle = crew('idle', 'idle', 'idle')
  stage.advance(all_idle, 0)

  stage.advance(all_idle, 3)

  eq(where_the_three_are(stage, 11), { '4,0', '1,0', '6,0' })
end

T['a game for two']['ends for the other player when one is called away to work'] = function()
  local stage = stage_of_a_game_with_three_agents()
  advance_every_tenth_second(stage, function(time)
    return time < 3.1 and crew('idle', 'idle') or crew('idle', 'working')
  end, 0, 9)

  eq(where_the_three_are(stage, 11)[1], '1,0')
end

T['a game for two']['ends for the other player when one leaves the office'] = function()
  local stage = stage_of_a_game_with_three_agents()
  advance_every_tenth_second(stage, function(time)
    return time < 3.1 and crew('idle', 'idle') or crew('idle')
  end, 0, 9)

  eq(where_the_three_are(stage, 11)[1], '2,0')
end

T['a game for two']['does not take along the agent sent to clean up a mess, who is done with it on time'] = function()
  local pack = scene.people_pack('# plan\n \n d.d.d.s.......p.q\n', {
    d = { spot = 'desk', sitting = true },
    s = { spot = 'seat', sitting = true },
    p = { spot = 'table' },
    q = { spot = 'table' },
  }, {
    characters = THREE_PEOPLE,
    activities = {
      stand = { steps = { { at = 'desk', for_seconds = 1.5 } } },
      messy = {
        steps = {
          { at = 'seat', pose = 'sitting', for_seconds = 1, leave = 'mess' },
          { at = 'desk' },
        },
      },
      game = { during = { 'idle' }, players = 2, steps = { { at = 'table', for_seconds = 10 } } },
      clean_up = { steps = { { at = 'mess', for_seconds = 3, remove = 'mess' } } },
    },
    things = { mess = { piece = 'left', cleaned_up_by = 'clean_up' } },
    states = { standing = 'stand', idle = 'stand', working = 'messy' },
  })
  local stage = scene.stage_of(pack, 17, 1, { random = scene.always(0) })
  local one_works_two_are_idle = crew('working', 'idle', 'idle')
  advance_every_tenth_second(stage, function()
    return one_works_two_are_idle
  end, 0, 4.3)

  eq(where_the_three_are(stage, 17), { '0,0', '2,0', '4,0' })
end

return T
