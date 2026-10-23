local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_things')

--- An aisle of eight cells with the standing spot `a` and the seat `s`.
local AISLE = '# plan\n \n a...s...\n'

local AISLE_LEGEND = {
  a = { spot = 'aside' },
  s = { spot = 'seat', sitting = true },
}

--- The colour of the thing the tests' agents leave: the red of the piece
--- `left`.
local RED = '#ff0000'

--- A stage of the aisle whose agent plays `steps` when it works, with the
--- things `things`, the random source giving 0 every time.
---
---@param steps table[]
---@param things? table
---@return aineo.office_scene.Stage
local function stage_of_an_agent_who(steps, things)
  local pack = scene.people_pack(AISLE, AISLE_LEGEND, {
    activities = { play = { steps = steps } },
    things = things or { mess = { piece = 'left' } },
    states = { standing = 'play', working = 'play' },
  })
  return scene.stage_of(pack, 8, 1, { random = scene.always(0) })
end

--- The group the cell at `column` of the only row is drawn in.
---
---@param stage aineo.office_scene.Stage
---@param column integer
---@return string|nil
local function group_at(stage, column)
  return scene.group_at(stage.picture(), column, 0)
end

local WORKING = scene.agents_in('working')

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['a step that leaves a thing'] = MiniTest.new_set()

T['a step that leaves a thing']['leaves it at the agent’s feet as the step ends'] = function()
  local stage = stage_of_an_agent_who({
    { at = 'seat', pose = 'sitting', for_seconds = 1, leave = 'mess' },
    { at = 'aside' },
  })
  stage.advance(WORKING, 0)
  stage.advance(WORKING, 0.9)
  local while_it_sits = group_at(stage, 4)

  stage.advance(WORKING, 3)

  eq({ while_it_sits, group_at(stage, 4) }, { scene.solid(scene.AGENT), scene.solid(RED) })
end

T['a step that removes a thing'] = MiniTest.new_set()

T['a step that removes a thing']['removes it from the cell the agent stands on, having gone to it by its name'] = function()
  local stage = stage_of_an_agent_who({
    { at = 'seat', pose = 'sitting', for_seconds = 1, leave = 'mess' },
    { at = 'aside', for_seconds = 1 },
    { at = 'mess', for_seconds = 1, remove = 'mess' },
    { at = 'aside' },
  })
  stage.advance(WORKING, 0)
  stage.advance(WORKING, 2)
  local while_it_lies = group_at(stage, 4)

  stage.advance(WORKING, 5)

  eq({ while_it_lies, group_at(stage, 4) }, { scene.solid(RED), scene.solid(scene.FLOOR) })
end

T['a thing that upsets agents'] = MiniTest.new_set()

local YELLOW = '#ffff00'

--- The people of the packs here, in three colours.
local THREE_COLOURS = {
  agent = {
    colours = { scene.AGENT, scene.SECOND_AGENT, YELLOW },
    poses = {
      standing = { art = { 'person' } },
      walking = { art = { 'person' } },
      sitting = { art = { 'person' }, sitting = true },
    },
  },
}

local MESSY_PLAN = '# plan\n \n a.a..s.....h\n'

local MESSY_LEGEND = {
  a = { spot = 'aside' },
  s = { spot = 'seat', sitting = true },
  h = { spot = 'huff' },
}

--- A stage of a plan where the agent that works leaves a mess at the seat
--- after a second, and the other agents stand about; the mess is a thing of
--- `mess`.
---
---@param mess table the thing's fields besides its piece
---@return aineo.office_scene.Stage
local function stage_of_a_messy_agent(mess)
  local pack = scene.people_pack(MESSY_PLAN, MESSY_LEGEND, {
    characters = THREE_COLOURS,
    activities = {
      stand = { steps = { { at = 'aside' } } },
      messy = {
        steps = {
          { at = 'seat', pose = 'sitting', for_seconds = 1, leave = 'mess' },
          { at = 'seat', pose = 'sitting' },
        },
      },
      grumble = { steps = { { at = 'huff', for_seconds = 1 } } },
    },
    things = { mess = vim.tbl_extend('force', { piece = 'left' }, mess) },
    states = { standing = 'stand', working = 'messy' },
  })
  return scene.stage_of(pack, 12, 1, { random = scene.always(0) })
end

--- Where the second and the third agent are, as `column,row` or 'nowhere'.
---
---@param stage aineo.office_scene.Stage
---@return string[]
local function where_the_others_are(stage)
  local picture = stage.picture()
  return {
    scene.agent_cell(picture, 12, 1, scene.SECOND_AGENT),
    scene.agent_cell(picture, 12, 1, YELLOW),
  }
end

local ONE_WORKS_TWO_STAND = scene.agents_in('working', 'standing', 'standing')

T['a thing that upsets agents']['sends the agents near it to play what upsets them, and they go back to their state after'] = function()
  local stage = stage_of_a_messy_agent({ upsets_agents_within = 3, upset_agents_play = 'grumble' })
  stage.advance(ONE_WORKS_TWO_STAND, 0)

  MiniTest.expect.no_error(function()
    stage.advance(ONE_WORKS_TWO_STAND, 1.8)
  end)
  local while_upset = where_the_others_are(stage)
  stage.advance(ONE_WORKS_TWO_STAND, 6)

  eq({ while_upset, where_the_others_are(stage) }, { { '0,0', '11,0' }, { '0,0', '2,0' } })
end

T['a thing that is cleaned up'] = MiniTest.new_set()

--- Where the second agent is, as `column,row`, every fifth of a second from
--- `from` to `to` seconds, the agents in the states they are given.
---
---@param stage aineo.office_scene.Stage
---@param agents aineo.office_states.Agent[]
---@param from number
---@param to number
---@return string[]
local function second_agents_cells_every_fifth_second(stage, agents, from, to)
  local cells = {}
  for fifths = math.floor(from * 5 + 0.5), math.floor(to * 5 + 0.5) do
    stage.advance(agents, fifths / 5)
    cells[#cells + 1] = where_the_others_are(stage)[1]
  end
  return cells
end

local CLEANING_PLAN = '# plan\n \n d.d.d.s...mh\n'

local CLEANING_LEGEND = {
  d = { spot = 'desk', sitting = true },
  s = { spot = 'seat', sitting = true },
  m = { spot = 'away' },
  h = { spot = 'huff' },
}

--- A stage where the agent that works leaves a mess at the seat after a
--- second and goes away, the agents near it grumble, and the nearest idle
--- agent cleans it up; the random source gives 0 every time.
---
---@param upset_within? integer how far the mess upsets agents, in cells; 3 unless given
---@return aineo.office_scene.Stage
local function stage_of_a_mess_to_clean(upset_within)
  local pack = scene.people_pack(CLEANING_PLAN, CLEANING_LEGEND, {
    characters = THREE_COLOURS,
    activities = {
      stand = { steps = { { at = 'desk' } } },
      messy = {
        steps = {
          { at = 'seat', pose = 'sitting', for_seconds = 1, leave = 'mess' },
          { at = 'away' },
        },
      },
      grumble = { steps = { { at = 'huff', for_seconds = 1 } } },
      clean_up = { steps = { { at = 'mess', for_seconds = 1, remove = 'mess' } } },
    },
    things = {
      mess = {
        piece = 'left',
        upsets_agents_within = upset_within or 3,
        upset_agents_play = 'grumble',
        cleaned_up_by = 'clean_up',
      },
    },
    states = { standing = 'stand', idle = 'stand', working = 'messy' },
  })
  return scene.stage_of(pack, 12, 1, { random = scene.always(0) })
end

T['a thing that is cleaned up']['is cleaned up by the nearest idle agent, while the agents near it grumble'] = function()
  local stage = stage_of_a_mess_to_clean()
  local crew = scene.agents_in('working', 'idle', 'standing')
  stage.advance(crew, 0)

  stage.advance(crew, 1.8)
  local during = where_the_others_are(stage)
  stage.advance(crew, 6)

  eq(
    { during, where_the_others_are(stage), group_at(stage, 6) },
    { { '6,0', '11,0' }, { '2,0', '4,0' }, scene.solid(scene.FLOOR) }
  )
end

T['a thing that is cleaned up']['does not upset the agent sent to clean it up'] = function()
  local stage = stage_of_a_mess_to_clean(5)
  local crew = scene.agents_in('working', 'idle', 'standing')
  stage.advance(crew, 0)

  stage.advance(crew, 1.8)

  eq(where_the_others_are(stage), { '6,0', '11,0' })
end

T['a thing that is cleaned up']['is cleaned up by the nearest idle agent only'] = function()
  local stage = stage_of_a_mess_to_clean(1)
  local crew = scene.agents_in('working', 'idle', 'idle')
  stage.advance(crew, 0)

  stage.advance(crew, 1.8)
  stage.advance(crew, 1.9)

  eq(where_the_others_are(stage), { '2,0', '6,0' })
end

T['a thing that is cleaned up']['does not draft a second idle agent to leave its desk for it'] = function()
  local stage = stage_of_a_mess_to_clean(1)
  local crew = scene.agents_in('working', 'idle', 'idle')
  stage.advance(crew, 0)

  local cells = second_agents_cells_every_fifth_second(stage, crew, 1.8, 6)

  eq(table.concat(cells, ' '), ('2,0 '):rep(22):sub(1, -2))
end

T['a thing that is cleaned up']['waits where it lies while no agent is idle, and is cleaned up when one is'] = function()
  local stage = stage_of_a_mess_to_clean()
  local nobody_idle = scene.agents_in('working', 'standing', 'standing')
  stage.advance(nobody_idle, 0)
  stage.advance(nobody_idle, 6)
  local while_nobody_is_idle = group_at(stage, 6)

  local one_idle = scene.agents_in('working', 'idle', 'standing')
  stage.advance(one_idle, 7)
  stage.advance(one_idle, 8)
  stage.advance(one_idle, 12)

  eq({ while_nobody_is_idle, group_at(stage, 6) }, { scene.solid(RED), scene.solid(scene.FLOOR) })
end

T['a thing that is cleaned up']['is left to another idle agent when the one who went to it stops being idle'] = function()
  local stage = stage_of_a_mess_to_clean()
  local first_cleaner_idle = scene.agents_in('working', 'idle', 'standing')
  stage.advance(first_cleaner_idle, 0)
  stage.advance(first_cleaner_idle, 1.2)

  local second_cleaner_idle = scene.agents_in('working', 'standing', 'idle')
  stage.advance(second_cleaner_idle, 1.5)
  stage.advance(second_cleaner_idle, 2)
  stage.advance(second_cleaner_idle, 10)

  eq(group_at(stage, 6), scene.solid(scene.FLOOR))
end

T['a thing that lies on the floor'] = MiniTest.new_set()

T['a thing that lies on the floor']['no longer keeps an agent waiting for its spot once it is gone'] = function()
  local pack = scene.people_pack(CLEANING_PLAN, CLEANING_LEGEND, {
    activities = {
      stand = { steps = { { at = 'desk' } } },
      messy = {
        steps = {
          { at = 'seat', pose = 'sitting', for_seconds = 1, leave = 'mess' },
          { at = 'away' },
        },
      },
      clean_up = { steps = { { at = 'mess', for_seconds = 1, remove = 'mess' } } },
      inspect = { steps = { { at = 'mess', for_seconds = 1 }, { at = 'huff' } } },
    },
    characters = THREE_COLOURS,
    things = { mess = { piece = 'left', cleaned_up_by = 'clean_up' } },
    states = { standing = 'stand', idle = 'stand', working = 'messy', resting = 'inspect' },
  })
  local stage = scene.stage_of(pack, 12, 1, { random = scene.always(0) })
  local crew = scene.agents_in('working', 'idle', 'standing')
  stage.advance(crew, 0)
  stage.advance(crew, 1.5)

  local inspecting = scene.agents_in('working', 'idle', 'resting')
  stage.advance(inspecting, 2)
  stage.advance(inspecting, 8)
  stage.advance(inspecting, 12)

  eq(where_the_others_are(stage), { '2,0', '11,0' })
end

T['a thing that lies on the floor']['is cleaned up by the idle agent who left it, once its step is over'] = function()
  local pack = scene.people_pack(CLEANING_PLAN, CLEANING_LEGEND, {
    activities = {
      drop = {
        steps = {
          { at = 'seat', pose = 'sitting', for_seconds = 1, leave = 'mess' },
          { at = 'away', for_seconds = 1 },
        },
      },
      clean_up = { steps = { { at = 'mess', for_seconds = 1, remove = 'mess' } } },
      rest = { steps = { { at = 'away' } } },
    },
    things = { mess = { piece = 'left', cleaned_up_by = 'clean_up' } },
    states = { standing = 'rest', idle = 'drop' },
  })
  local stage = scene.stage_of(pack, 12, 1, { random = scene.always(0) })
  local idle = scene.agents_in('idle')
  stage.advance(idle, 0)

  MiniTest.expect.no_error(function()
    stage.advance(idle, 1.5)
  end)
  local while_it_is_sent = group_at(stage, 6)
  stage.advance(idle, 3)
  stage.advance(scene.agents_in('standing'), 3.5)

  eq({ while_it_is_sent, group_at(stage, 6) }, { scene.solid(RED), scene.solid(scene.FLOOR) })
end

T['a thing that lies on the floor']['is still cleaned up by an agent on its way to it when the plan is laid out again'] = function()
  local stage = stage_of_a_mess_to_clean(1)
  local crew = scene.agents_in('working', 'idle', 'standing')
  stage.advance(crew, 0)
  stage.advance(crew, 1.1)

  stage.resize(12, 1)
  stage.advance(crew, 1.2)
  stage.advance(crew, 6)

  eq(group_at(stage, 6), scene.solid(scene.FLOOR))
end

T['a thing that lies on the floor']['is dropped when the plan is laid out again without its cell'] = function()
  local stage = stage_of_a_mess_to_clean()
  local nobody_idle = scene.agents_in('working', 'standing', 'standing')
  stage.advance(nobody_idle, 0)
  stage.advance(nobody_idle, 2)

  stage.resize(6, 1)
  stage.resize(12, 1)

  eq(group_at(stage, 6), scene.solid(scene.FLOOR))
end

return T
