local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local default = dofile('tests/helpers/office_default.lua')

local SMALL, MEDIUM, LARGE = { 60, 24 }, { 100, 40 }, { 220, 80 }

--- The rows the status list takes of the bottom of the window.
local LIST_ROWS = 5

--- The 24 states, in the vocabulary's order, and the spot each is played at
--- first: the scenes of the approved mock.
local FIRST_SPOT = {
  { 'arriving', 'door' },
  { 'getting_a_task', 'desk' },
  { 'thinking', 'whiteboard' },
  { 'planning', 'whiteboard' },
  { 'reading', 'file_cabinet' },
  { 'searching', 'file_cabinet' },
  { 'writing_code', 'desk' },
  { 'running_a_command', 'desk' },
  { 'running_tests', 'desk' },
  { 'background_job', 'desk' },
  { 'on_the_web', 'desk' },
  { 'delegating', 'beside_desk' },
  { 'waiting_for_subagents', 'beside_desk' },
  { 'needs_permission', 'desk' },
  { 'asking_you', 'desk' },
  { 'reporting', 'printer' },
  { 'committing', 'desk' },
  { 'compacting', 'desk' },
  { 'error', 'desk' },
  { 'interrupted', 'desk' },
  { 'done', 'beside_desk' },
  { 'idle', 'sofa' },
  { 'asleep', 'sofa' },
  { 'leaving', 'beside_desk' },
}

--- The spot each state's agent stays at once its activity has gone through
--- its steps: the states that go on with a random life after, and so leave
--- the spot, are not here.
local LAST_SPOT = {
  { 'arriving', 'desk' },
  { 'getting_a_task', 'desk' },
  { 'thinking', 'whiteboard' },
  { 'planning', 'whiteboard' },
  { 'reading', 'file_cabinet' },
  { 'searching', 'file_cabinet' },
  { 'writing_code', 'desk' },
  { 'running_a_command', 'desk' },
  { 'running_tests', 'desk' },
  { 'background_job', 'desk' },
  { 'on_the_web', 'desk' },
  { 'delegating', 'beside_desk' },
  { 'needs_permission', 'desk' },
  { 'asking_you', 'desk' },
  { 'reporting', 'printer' },
  { 'committing', 'desk' },
  { 'compacting', 'desk' },
  { 'error', 'desk' },
  { 'interrupted', 'desk' },
  { 'done', 'sofa' },
  { 'asleep', 'sofa' },
  { 'leaving', 'door' },
}

--- A stage of the default pack `size` big with the main agent in `state`,
--- advanced through `seconds` in quarter seconds, and the place of the agent
--- in its picture and the spots of the plan.
---
---@param size integer[]
---@param state string
---@param seconds number
---@return string nearest the name of the spot nearest to the agent, 'nowhere' when it is not drawn
local function spot_of_agent_after(size, state, seconds)
  local pack = default.load_pack()
  local spots = default.spots(pack, size[1], size[2] - LIST_ROWS)
  local stage = default.stage(pack, size[1], size[2])
  local agents = default.agents(1, state)
  for time = 0, seconds, 0.25 do
    stage.advance(agents, time)
  end
  local place = default.where_is(default.pixels(stage.picture(), size[1]), default.AGENT_COLOURS[1])
  return place and default.nearest_spot(spots, place) or 'nowhere'
end

--- The cases of `pairs` in each of `sizes`: the size, the state, the spot.
---
---@param sizes integer[][]
---@param pairs_of_state_and_spot string[][]
---@return table[]
local function in_each_size(sizes, pairs_of_state_and_spot)
  local cases = {}
  for _, size in ipairs(sizes) do
    for _, pair in ipairs(pairs_of_state_and_spot) do
      table.insert(cases, { size, pair[1], pair[2] })
    end
  end
  return cases
end

local T = MiniTest.new_set()

T['the states'] = MiniTest.new_set()

T['the states']['that start at a spot the plan lacks in 60 columns by 24 rows are those at a desk, the sofa or the printer'] = function()
  local spots = default.spots(default.load_pack(), SMALL[1], SMALL[2] - LIST_ROWS)

  local lacking = vim.tbl_map(
    function(pair)
      return pair[1]
    end,
    vim.tbl_filter(function(pair)
      return spots[pair[2]] == nil
    end, FIRST_SPOT)
  )

  eq(lacking, {
    'getting_a_task',
    'writing_code',
    'running_a_command',
    'running_tests',
    'background_job',
    'on_the_web',
    'needs_permission',
    'asking_you',
    'reporting',
    'committing',
    'compacting',
    'error',
    'interrupted',
    'idle',
    'asleep',
  })
end

T['the states']['all start at a spot the plan has in 100 columns by 40 rows and in 220 by 80'] =
  MiniTest.new_set({
    parametrize = { { MEDIUM }, { LARGE } },
  })

T['the states']['all start at a spot the plan has in 100 columns by 40 rows and in 220 by 80']['size'] = function(
  size
)
  local spots = default.spots(default.load_pack(), size[1], size[2] - LIST_ROWS)

  local lacking = vim.tbl_filter(function(pair)
    return spots[pair[2]] == nil
  end, FIRST_SPOT)

  eq(lacking, {})
end

T['an agent'] = MiniTest.new_set()

T['an agent']['is drawn in every state, in 60 columns by 24 rows and in 100 by 40'] =
  MiniTest.new_set({
    parametrize = in_each_size({ SMALL, MEDIUM }, FIRST_SPOT),
  })

T['an agent']['is drawn in every state, in 60 columns by 24 rows and in 100 by 40']['size, state and spot'] = function(
  size,
  state
)
  eq(spot_of_agent_after(size, state, 0) ~= 'nowhere', true)
end

T['an agent']['is put at the spot its state starts at'] = MiniTest.new_set({
  parametrize = in_each_size({ MEDIUM, LARGE }, FIRST_SPOT),
})

T['an agent']['is put at the spot its state starts at']['size, state and spot'] = function(
  size,
  state,
  spot
)
  eq(spot_of_agent_after(size, state, 0), spot)
end

T['an agent']['is put at the spot its state starts at in 60 columns by 24 rows, where the plan has it'] =
  MiniTest.new_set({
    parametrize = {
      { 'arriving', 'door' },
      { 'thinking', 'whiteboard' },
      { 'planning', 'whiteboard' },
      { 'reading', 'file_cabinet' },
      { 'searching', 'file_cabinet' },
      { 'delegating', 'beside_desk' },
      { 'waiting_for_subagents', 'beside_desk' },
      { 'done', 'beside_desk' },
      { 'leaving', 'beside_desk' },
    },
  })

T['an agent']['is put at the spot its state starts at in 60 columns by 24 rows, where the plan has it']['state and spot'] = function(
  state,
  spot
)
  eq(spot_of_agent_after(SMALL, state, 0), spot)
end

T['an agent']["stays at the spot its state's activity ends at"] = MiniTest.new_set({
  parametrize = in_each_size({ MEDIUM, LARGE }, LAST_SPOT),
})

T['an agent']["stays at the spot its state's activity ends at"]['size, state and spot'] = function(
  size,
  state,
  spot
)
  eq(spot_of_agent_after(size, state, 30), spot)
end

T['an agent']['reaches every state in turn on a pass through the 24, at the spot each ends at'] = function()
  local pack = default.load_pack()
  local size = LARGE
  local spots = default.spots(pack, size[1], size[2] - LIST_ROWS)
  local stage = default.stage(pack, size[1], size[2])
  local reached = {}
  local time = 0

  for _, pair in ipairs(LAST_SPOT) do
    local agents = default.agents(1, pair[1])
    for _ = 1, 60 do
      stage.advance(agents, time)
      time = time + 0.25
    end
    local place =
      default.where_is(default.pixels(stage.picture(), size[1]), default.AGENT_COLOURS[1])
    reached[pair[1]] = place and default.nearest_spot(spots, place) or 'nowhere'
  end

  eq(reached, {
    arriving = 'desk',
    getting_a_task = 'desk',
    thinking = 'whiteboard',
    planning = 'whiteboard',
    reading = 'file_cabinet',
    searching = 'file_cabinet',
    writing_code = 'desk',
    running_a_command = 'desk',
    running_tests = 'desk',
    background_job = 'desk',
    on_the_web = 'desk',
    delegating = 'beside_desk',
    needs_permission = 'desk',
    asking_you = 'desk',
    reporting = 'printer',
    committing = 'desk',
    compacting = 'desk',
    error = 'desk',
    interrupted = 'desk',
    done = 'sofa',
    asleep = 'sofa',
    leaving = 'door',
  })
end

return T
