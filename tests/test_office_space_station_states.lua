local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local default = dofile('tests/helpers/office_default.lua')
local office_signals = dofile('tests/helpers/office_signals.lua')

local PACK = 'space_station'

local SMALL, MEDIUM, LARGE = { 60, 24 }, { 100, 40 }, { 220, 80 }
local ALL_SIZES = { SMALL, MEDIUM, LARGE }

--- The rows the status list takes of the bottom of the window.
local LIST_ROWS = 5

--- The 24 states, in the vocabulary's order, and the spot each is played at
--- first.
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

--- A stage of the space station `size` big with `agents`, advanced through
--- `seconds` in quarter seconds, and the name of the spot of the plan nearest
--- to the first agent.
---
---@param size integer[]
---@param agents aineo.office_states.Agent[]
---@param seconds number
---@return string nearest the name of the spot nearest to the agent, 'nowhere' when it is not drawn
local function spot_of_first_agent_after(size, agents, seconds)
  local pack = default.load_pack(PACK)
  local spots = default.spots(pack, size[1], size[2] - LIST_ROWS)
  local stage = default.stage(pack, size[1], size[2])
  for time = 0, seconds, 0.25 do
    stage.advance(agents, time)
  end
  local place = default.where_is(default.pixels(stage.picture(), size[1]), default.AGENT_COLOURS[1])
  return place and default.nearest_spot(spots, place) or 'nowhere'
end

--- The same for the main agent alone, in `state`, playing `activity` when one
--- is given.
---
---@param size integer[]
---@param state string
---@param seconds number
---@param activity? string
---@return string nearest
local function spot_of_agent_after(size, state, seconds, activity)
  return spot_of_first_agent_after(
    size,
    { { id = 'main', state = state, activity = activity } },
    seconds
  )
end

--- The cases of `pairs_of_state_and_spot` in each of `sizes`: the size, the
--- state, the spot.
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

T['the plan'] = MiniTest.new_set({ parametrize = { { SMALL }, { MEDIUM }, { LARGE } } })

T['the plan']['has the spot every state starts at, at 60 columns by 24 rows, 100 by 40 and 220 by 80'] = function(
  size
)
  local spots = default.spots(default.load_pack(PACK), size[1], size[2] - LIST_ROWS)

  local lacking = vim.tbl_filter(function(pair)
    return spots[pair[2]] == nil
  end, FIRST_SPOT)

  eq(lacking, {})
end

T['the plan']['has the comms console, where the trigger sends an agent, at every size'] = function(
  size
)
  local spots = default.spots(default.load_pack(PACK), size[1], size[2] - LIST_ROWS)

  eq(spots.comms_console ~= nil, true)
end

T['an agent'] = MiniTest.new_set()

T['an agent']['is put at the spot its state starts at, at every size'] = MiniTest.new_set({
  parametrize = in_each_size(ALL_SIZES, FIRST_SPOT),
})

T['an agent']['is put at the spot its state starts at, at every size']['size, state and spot'] = function(
  size,
  state,
  spot
)
  eq(spot_of_agent_after(size, state, 0), spot)
end

T['an agent']["stays at the spot its state's activity ends at, at every size"] = MiniTest.new_set({
  parametrize = in_each_size(ALL_SIZES, LAST_SPOT),
})

T['an agent']["stays at the spot its state's activity ends at, at every size"]['size, state and spot'] = function(
  size,
  state,
  spot
)
  eq(spot_of_agent_after(size, state, 30), spot)
end

T['an agent']['reaches 22 of the 24 states in turn on a pass, at the spot each ends at'] =
  MiniTest.new_set({
    parametrize = { { SMALL }, { MEDIUM }, { LARGE } },
  })

T['an agent']['reaches 22 of the 24 states in turn on a pass, at the spot each ends at']['size'] = function(
  size
)
  local pack = default.load_pack(PACK)
  pack.cat = nil
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

T['the trigger'] = MiniTest.new_set()

--- The activity the main agent plays while it runs the Bash command
--- `command`, in an office told of the triggers of the space station.
---
---@param command string
---@return string|nil activity
local function activity_while_running(command)
  local story = office_signals.tell({ triggers = default.load_pack(PACK).triggers })
  story.started('a', 'Bash', { command = command })
  return story.activity()
end

T['the trigger']['names the transmission for a git push, whatever follows it'] = MiniTest.new_set({
  parametrize = {
    { 'git push' },
    { 'git push origin main' },
    { 'cd app && git push --force-with-lease' },
    { 'git  push' },
    { 'make && git push' },
    { 'a; git push' },
    { 'x | git push' },
  },
})

T['the trigger']['names the transmission for a git push, whatever follows it']['command'] = function(
  command
)
  eq(activity_while_running(command), 'send_a_transmission')
end

T['the trigger']['names no activity for a command that is not a git push, nor one that only mentions it'] =
  MiniTest.new_set({
    parametrize = {
      { 'git pull' },
      { 'git status' },
      { 'make test' },
      { 'git pushd' },
      { 'git push-something' },
      { 'echo git push' },
      { 'git commit -m "then git push"' },
      { 'grep -rn "git push" docs' },
      { 'git push.sh' },
    },
  })

T['the trigger']['names no activity for a command that is not a git push, nor one that only mentions it']['command'] = function(
  command
)
  eq(activity_while_running(command), nil)
end

T['the trigger']['has an agent that it names the transmission for go to the comms console, at every size'] =
  MiniTest.new_set({
    parametrize = { { SMALL }, { MEDIUM }, { LARGE } },
  })

T['the trigger']['has an agent that it names the transmission for go to the comms console, at every size']['size'] = function(
  size
)
  eq(spot_of_agent_after(size, 'committing', 20, 'send_a_transmission'), 'comms_console')
end

T['the trigger']['has an agent that runs a push go to the comms console, from the tracker to the stage'] = function()
  local story = office_signals.tell({ triggers = default.load_pack(PACK).triggers })
  story.started('a', 'Bash', { command = 'git push origin main' })

  eq(spot_of_first_agent_after(MEDIUM, story.agents_after(0), 20), 'comms_console')
end

T['the trigger']['leaves a commit that is no push at the desk'] = function()
  eq(spot_of_agent_after(MEDIUM, 'committing', 20), 'desk')
end

--- The colours of the sky of the default pack, which the space station
--- replaces with stars at every hour, as six hexadecimal digits.
local DEFAULT_SKY_COLOURS = {
  'a6d8f5',
  '80c2f0',
  '5aa9e6',
  'f5b58a',
  'b06a7a',
  '45325a',
  'f39a5e',
  'a0527a',
  '2d2b55',
  '1e2a4a',
  '18203d',
  '11152a',
}

--- The colour a star is drawn in, as six hexadecimal digits.
local STAR_WHITE = 'f4f8ff'

--- The pixel columns and rows the sky of the viewport is painted in, on the
--- 100 by 40 stage: the viewport's left column, its glass starting two pixels
--- in and 20 wide, its rows 5 to 15.
---
---@param left integer the viewport's left column, from 0
---@return integer first_column
---@return integer last_column
local function glass_columns(left)
  return left + 2, left + 21
end

--- What the glass of the viewport shows at `hour`, `seconds` into the stage,
--- as one colour for each pixel of the glass, rows joined with `/`.
---
---@param hour integer
---@param seconds number
---@return string
local function glass_at(hour, seconds)
  local pack = default.load_pack(PACK)
  pack.cat = nil
  local stage = default.stage(pack, MEDIUM[1], MEDIUM[2], { clock = default.clock_at(hour) })
  local left = default.spots(pack, MEDIUM[1], MEDIUM[2] - LIST_ROWS).viewport[1].column
  local first, last = glass_columns(left)
  local agents = default.agents(1, 'standing')
  for time = 0, seconds, 0.25 do
    stage.advance(agents, time)
  end
  local pixels = default.pixels(stage.picture(), MEDIUM[1])
  local rows = {}
  for y = 5, 15 do
    local row = {}
    for x = first, last do
      table.insert(row, default.pixel_at(pixels, x, y) or 'none')
    end
    table.insert(rows, table.concat(row, ','))
  end
  return table.concat(rows, '/')
end

T['the viewport'] = MiniTest.new_set()

T['the viewport']['shows stars, and no daylight of the default pack, at every hour'] =
  MiniTest.new_set({
    parametrize = { { 5 }, { 14 }, { 18 }, { 23 } },
  })

T['the viewport']['shows stars, and no daylight of the default pack, at every hour']['hour'] = function(
  hour
)
  local glass = glass_at(hour, 0)

  eq(glass:find(STAR_WHITE, 1, true) ~= nil, true)
  eq(
    vim.tbl_filter(function(colour)
      return glass:find(colour, 1, true) ~= nil
    end, DEFAULT_SKY_COLOURS),
    {}
  )
end

T['the viewport']['shows other stars a second later'] = function()
  MiniTest.expect.no_equality(glass_at(14, 0), glass_at(14, 1))
end

T['an agent sending a transmission'] = MiniTest.new_set()

--- The text the stage draws over its picture, after `activity` has been
--- played by the main agent in `state` for `seconds`.
---
---@param state string
---@param activity string
---@param seconds number
---@return string
local function text_while_playing(state, activity, seconds)
  local pack = default.load_pack(PACK)
  local stage = default.stage(pack, MEDIUM[1], MEDIUM[2])
  local agents = { { id = 'main', state = state, activity = activity } }
  for time = 0, seconds, 0.25 do
    stage.advance(agents, time)
  end
  return table.concat(default.text_rows(stage.picture(), 1), '\n')
end

T['an agent sending a transmission']['has signal arcs rise over its head'] = function()
  eq(text_while_playing('committing', 'send_a_transmission', 5):find(')', 1, true) ~= nil, true)
end

T['an agent sending a transmission']['is told in the status list to send a transmission'] = function()
  eq(
    text_while_playing('committing', 'send_a_transmission', 5):find('sends a transmission', 1, true)
      ~= nil,
    true
  )
end

T['an agent sending a transmission']['shows no signal arcs when it commits at its desk'] = function()
  eq(text_while_playing('committing', nil, 5):find(')', 1, true), nil)
end

--- The runs of one letter in the plan laid out `size` big that are narrower
--- than the narrowest the piece the letter stands for can be drawn: each as
--- `letter at column,row over length`.
---
---@param pack aineo.office_pack.Pack
---@param size integer[]
---@return string[]
local function runs_narrower_than_their_stretched_piece(pack, size)
  local narrow = {}
  for row_index, text in ipairs(default.laid_out_rows(pack, size[1], size[2] - LIST_ROWS)) do
    local column = 1
    while column <= #text do
      local letter = text:sub(column, column)
      local length = 1
      while text:sub(column + length, column + length) == letter do
        length = length + 1
      end
      local entry = pack.floor.legend[letter]
      local piece = entry and entry.piece and pack.pieces[entry.piece]
      if piece and piece.stretch and length < piece.width then
        table.insert(
          narrow,
          ('%s at %d,%d over %d'):format(letter, column - 1, row_index - 1, length)
        )
      end
      column = column + length
    end
  end
  return narrow
end

T['the plan']['stretches no piece beyond the run of cells it is laid over'] = function(size)
  eq(runs_narrower_than_their_stretched_piece(default.load_pack(PACK), size), {})
end

T['the office'] = MiniTest.new_set({
  parametrize = { { SMALL }, { MEDIUM }, { LARGE }, { { 300, 120 } } },
})

T['the office']['leaves out no piece a frame could not afford, in any size'] = function(size)
  local left_out = {}

  default.stage(default.load_pack(PACK), size[1], size[2], {
    on_left_out = function(count)
      table.insert(left_out, count)
    end,
  })

  eq(left_out, {})
end

T['the pet'] = MiniTest.new_set({ parametrize = { { SMALL }, { MEDIUM }, { LARGE } } })

T['the pet']['is drawn on the floor of every size'] = function(size)
  local pack = default.load_pack(PACK)
  local stage = default.stage(pack, size[1], size[2])

  stage.advance(default.agents(1, 'idle'), 0)

  local pixels = default.pixels(stage.picture(), size[1])
  eq(default.where_is(pixels, default.CAT_COLOUR) ~= nil, true)
end

return T
