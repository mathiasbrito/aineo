local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local default = dofile('tests/helpers/office_default.lua')

--- A room wide and tall enough for every spot of the default plan: the second
--- lounge, the table-tennis table, the wall's decorations and the corner plant.
local ROOM = { 260, 80 }

--- The rows the status list takes of the bottom of the window.
local LIST_ROWS = 5

--- The pack with only the activities of random life `wanted` names left;
--- what the states play is left as it is.
---
---@param wanted string[]
---@return aineo.office_pack.Pack
local function pack_with_life(wanted)
  local pack = default.load_pack()
  for name, activity in pairs(pack.activities) do
    if (activity.during or activity.who == 'cat') and not vim.list_contains(wanted, name) then
      pack.activities[name] = nil
    end
  end
  return pack
end

--- Everything the status list says over `seconds` of the agents in `agents`
--- on a stage of `pack`, looked at every half second: one long line.
---
---@param pack aineo.office_pack.Pack
---@param agents aineo.office_states.Agent[]
---@param seconds number
---@return string listed
local function listed_over(pack, agents, seconds)
  local stage = default.stage(pack, ROOM[1], ROOM[2])
  local said = {}
  for step = 0, seconds * 4 do
    stage.advance(agents, step / 4)
    if step % 2 == 0 then
      vim.list_extend(said, default.text_rows(stage.picture(), ROOM[2] - LIST_ROWS + 2))
    end
  end
  return table.concat(said, '\n')
end

--- The names of the spots nearest to the agent `index` over `seconds`, one
--- for each half second it is drawn.
---
---@param pack aineo.office_pack.Pack
---@param agents aineo.office_states.Agent[]
---@param seconds number
---@param colour string `#rrggbb` the agent or the cat is drawn in
---@param size? integer[] the room, `ROOM` by default
---@return table<string, true> names
local function spots_visited(pack, agents, seconds, colour, size)
  size = size or ROOM
  local spots = default.spots(pack, size[1], size[2] - LIST_ROWS)
  local stage = default.stage(pack, size[1], size[2])
  local names = {}
  for step = 0, seconds * 4 do
    stage.advance(agents, step / 4)
    if step % 2 == 0 then
      local place = default.where_is(default.pixels(stage.picture(), size[1]), colour)
      if place then
        names[default.nearest_spot(spots, place)] = true
      end
    end
  end
  return names
end

local T = MiniTest.new_set()

T['an idle agent'] = MiniTest.new_set()

T['an idle agent']['does one thing after another, many different ones'] = function()
  local pack = default.load_pack()

  local listed = listed_over(pack, default.agents(2, 'idle'), 240)

  local seen = {}
  for _, label in ipairs({
    'stretches',
    'yawns',
    'spins in the chair',
    'looks out of the window',
    'reads a book on the sofa',
    'waters the plant',
    'throws a paper ball at the bin',
    'chats at the water cooler',
    'doodles on the whiteboard',
    'tidies the desk',
    'naps on the sofa',
    'plays table tennis',
  }) do
    seen[label] = listed:find(label, 1, true) ~= nil
  end
  eq(vim.tbl_count(vim.tbl_filter(function(ok)
    return ok
  end, seen)) >= 8, true)
end

T['an idle agent']['plays each of the things the mock has it do'] = MiniTest.new_set({
  parametrize = {
    { 'stretch', 'stretches' },
    { 'yawn', 'yawns' },
    { 'spin_in_the_chair', 'spins in the chair' },
    { 'look_out_of_the_window', 'looks out of the window' },
    { 'read_a_book_on_the_sofa', 'reads a book on the sofa' },
    { 'water_the_snake_plant', 'waters the plant' },
    { 'throw_a_paper_ball_in_the_bin', 'throws a paper ball at the bin' },
    { 'throw_a_paper_ball_and_miss', 'throws a paper ball at the bin' },
    { 'get_a_drink_at_the_water_cooler', 'chats at the water cooler' },
    { 'doodle_on_the_whiteboard', 'doodles on the whiteboard' },
    { 'tidy_the_desk', 'tidies the desk' },
    { 'nap_on_the_sofa', 'naps on the sofa' },
    { 'play_table_tennis', 'plays table tennis' },
  },
})

T['an idle agent']['plays each of the things the mock has it do']['activity and label'] = function(
  name,
  label
)
  local listed = listed_over(pack_with_life({ name }), default.agents(2, 'idle'), 90)

  eq(listed:find(label, 1, true) ~= nil, true)
end

T['an idle agent']['waters the plant in the corner too'] = function()
  local visited = spots_visited(
    pack_with_life({ 'water_the_corner_plant' }),
    default.agents(1, 'idle'),
    90,
    default.AGENT_COLOURS[1]
  )

  eq(visited.corner_plant, true)
end

T['an idle agent']['pets the cat, standing right beside it'] = function()
  local pack = pack_with_life({ 'pet_the_cat', 'wander_the_aisles' })
  local stage = default.stage(pack, ROOM[1], ROOM[2])
  local agents = default.agents(1, 'idle')
  local closest_while_petting = math.huge

  for step = 0, 4 * 120 do
    stage.advance(agents, step / 4)
    local picture = stage.picture()
    local petting = table.concat(default.text_rows(picture, ROOM[2] - LIST_ROWS + 2), '\n')
    local pixels = default.pixels(picture, ROOM[1])
    local agent = default.where_is(pixels, default.AGENT_COLOURS[1])
    local cat = default.where_is(pixels, default.CAT_COLOUR)
    if petting:find('pets the cat', 1, true) and agent and cat then
      closest_while_petting = math.min(closest_while_petting, math.abs(agent.column - cat.column))
    end
  end

  eq(closest_while_petting <= 16, true)
end

--- The pack with the cat's whole life and only the activities of idle
--- agents `wanted` names.
---
---@param wanted string[]
---@return aineo.office_pack.Pack
local function pack_with_the_cats_life_and(wanted)
  local pack = default.load_pack()
  for name, activity in pairs(pack.activities) do
    if activity.during and activity.who ~= 'cat' and not vim.list_contains(wanted, name) then
      pack.activities[name] = nil
    end
  end
  return pack
end

--- How many quarter seconds from the moment an agent stands still beside the
--- cat the cat is surely still held, the agent petting it for at least two
--- seconds.
local QUARTER_SECONDS_SURELY_PETTING = 6

--- How many pixels apart the middle of the one idle agent of an office with
--- the cat's whole life and the middle of the cat are in each quarter second,
--- over 900 s, in which the agent has stood still under the label 'pets the
--- cat' for no more than `QUARTER_SECONDS_SURELY_PETTING`.
---
---@return number[] distances
local function pixels_apart_while_petting()
  local stage = default.stage(
    pack_with_the_cats_life_and({ 'pet_the_cat', 'water_the_corner_plant' }),
    ROOM[1],
    ROOM[2]
  )
  local agents = default.agents(1, 'idle')
  local distances, before, standing_for = {}, nil, 0
  for step = 0, 4 * 900 do
    stage.advance(agents, step / 4)
    local picture = stage.picture()
    local pixels = default.pixels(picture, ROOM[1])
    local agent = default.where_is(pixels, default.AGENT_COLOURS[1])
    local cat = default.where_is(pixels, default.CAT_COLOUR)
    local label = table.concat(default.text_rows(picture, ROOM[2] - LIST_ROWS + 2), '\n')
    local stands_still = agent ~= nil
      and before ~= nil
      and agent.column == before.column
      and agent.bottom == before.bottom
    local pets = label:find('pets the cat', 1, true) ~= nil
    standing_for = (stands_still and pets) and standing_for + 1 or 0
    if standing_for > 0 and standing_for <= QUARTER_SECONDS_SURELY_PETTING and cat then
      table.insert(distances, math.abs(agent.column - cat.column))
    end
    before = agent
  end
  return distances
end

--- The most pixels apart an agent's middle and the cat's may be for the agent
--- to be beside the cat.
local MOST_PIXELS_BESIDE = 16

T['an idle agent']['has the cat beside it for as long as it surely pets it'] = function()
  local distances = pixels_apart_while_petting()

  local too_far = vim.tbl_filter(function(distance)
    return distance > MOST_PIXELS_BESIDE
  end, distances)

  eq({ #distances > 20, #too_far }, { true, 0 })
end

T['two idle agents'] = MiniTest.new_set()

T['two idle agents']['play table tennis together, each at an end of the table'] = function()
  local pack = pack_with_life({ 'play_table_tennis' })
  local spots = default.spots(pack, ROOM[1], ROOM[2] - LIST_ROWS)
  local stage = default.stage(pack, ROOM[1], ROOM[2])
  local agents = default.agents(2, 'idle')
  local at_the_table = {}

  for step = 0, 240 do
    stage.advance(agents, step / 4)
    local pixels = default.pixels(stage.picture(), ROOM[1])
    local first = default.where_is(pixels, default.AGENT_COLOURS[1])
    local second = default.where_is(pixels, default.AGENT_COLOURS[2])
    if
      first
      and second
      and default.nearest_spot(spots, first) == 'table_tennis'
      and default.nearest_spot(spots, second) == 'table_tennis'
      and math.abs(first.column - second.column) > 20
    then
      at_the_table[#at_the_table + 1] = step
    end
  end

  eq(#at_the_table > 0, true)
end

T['two idle agents']['do not play table tennis when only one of them is idle'] = function()
  local visited = spots_visited(
    pack_with_life({ 'play_table_tennis' }),
    default.agents(1, 'idle'),
    240,
    default.AGENT_COLOURS[1]
  )

  eq(visited.table_tennis, nil)
end

T['a waiting agent'] = MiniTest.new_set()

T['a waiting agent']['plays each of the things the mock has it do while it waits for its subagents'] =
  MiniTest.new_set({
    parametrize = {
      { 'drum_its_fingers', 'drums its fingers' },
      { 'look_at_its_watch', 'looks at its watch' },
      { 'pace_beside_the_desk', 'paces beside the desk' },
      { 'glance_at_the_door', 'glances at the door' },
      { 'tap_a_foot', 'taps its foot' },
    },
  })

T['a waiting agent']['plays each of the things the mock has it do while it waits for its subagents']['activity and label'] = function(
  name,
  label
)
  local listed =
    listed_over(pack_with_life({ name }), default.agents(1, 'waiting_for_subagents'), 60)

  eq(listed:find(label, 1, true) ~= nil, true)
end

T['a waiting agent']['drums its fingers at its own desk, going no farther than beside it'] = function()
  local visited = spots_visited(
    pack_with_life({ 'drum_its_fingers' }),
    default.agents(1, 'waiting_for_subagents'),
    60,
    default.AGENT_COLOURS[1]
  )

  eq(visited, { beside_desk = true, desk = true })
end

T['a waiting agent']['plays each of the seated things while it waits for an answer'] =
  MiniTest.new_set({
    parametrize = {
      { 'drum_its_fingers_and_wait', 'drums its fingers' },
      { 'look_at_its_watch_and_wait', 'looks at its watch' },
      { 'glance_at_the_door_and_wait', 'glances at the door' },
    },
  })

T['a waiting agent']['plays each of the seated things while it waits for an answer']['activity and label'] = function(
  name,
  label
)
  local listed = listed_over(pack_with_life({ name }), default.agents(1, 'needs_permission'), 60)

  eq(listed:find(label, 1, true) ~= nil, true)
end

T['the cat'] = MiniTest.new_set()

T['the cat']['is drawn, in the colour the pack gives it'] = function()
  local pack = pack_with_life({ 'wander_the_aisles' })
  local stage = default.stage(pack, ROOM[1], ROOM[2])
  stage.advance(default.agents(1, 'idle'), 0)
  stage.advance(default.agents(1, 'idle'), 10)

  eq(default.where_is(default.pixels(stage.picture(), ROOM[1]), default.CAT_COLOUR) ~= nil, true)
end

T['the cat']['plays each of the things the mock has it do, at the place it does it'] =
  MiniTest.new_set({
    parametrize = {
      { 'sleep_on_a_seat', 'sofa' },
      { 'jump_on_an_empty_desk', 'desk' },
      { 'sit_on_a_keyboard', 'desk' },
    },
  })

T['the cat']['plays each of the things the mock has it do, at the place it does it']['activity and spot'] = function(
  name,
  spot
)
  local pack = pack_with_life({ name })
  local visited = spots_visited(pack, default.agents(2, 'idle'), 240, default.CAT_COLOUR)

  eq(visited[spot], true)
end

T['the cat']['stares at the fish in the tank, in a room wide enough for the tank'] = function()
  local visited = spots_visited(
    pack_with_life({ 'stare_at_the_fish' }),
    default.agents(2, 'idle'),
    240,
    default.CAT_COLOUR,
    { 300, 80 }
  )

  eq(visited.fish_tank, true)
end

T['the cat']['sleeps on a seat of the sofa for a long time'] = function()
  local pack = pack_with_life({ 'sleep_on_a_seat' })
  local spots = default.spots(pack, ROOM[1], ROOM[2] - LIST_ROWS)
  local stage = default.stage(pack, ROOM[1], ROOM[2])
  local asleep_seconds = 0

  for step = 0, 4 * 300 do
    stage.advance({}, step / 4)
    local place = default.where_is(default.pixels(stage.picture(), ROOM[1]), default.CAT_COLOUR)
    if place and default.nearest_spot(spots, place) == 'sofa' then
      asleep_seconds = asleep_seconds + 0.25
    end
  end

  eq(asleep_seconds >= 60, true)
end

--- How the cat looks in each quarter second of 240 s in which it has only
--- slept on a seat of the sofa, in the frames where it is at the sofa: how
--- many of its pixels show, and the pixel row of the lowest of them.
---
---@return { visible: integer, lowest: integer }[] frames
local function cat_frames_asleep_on_the_sofa()
  local pack = pack_with_life({ 'sleep_on_a_seat' })
  local spots = default.spots(pack, ROOM[1], ROOM[2] - LIST_ROWS)
  local stage = default.stage(pack, ROOM[1], ROOM[2])
  local frames = {}
  for step = 0, 4 * 240 do
    stage.advance({}, step / 4)
    local place = default.where_is(default.pixels(stage.picture(), ROOM[1]), default.CAT_COLOUR)
    if place and default.nearest_spot(spots, place) == 'sofa' then
      table.insert(frames, { visible = place.count, lowest = place.bottom })
    end
  end
  return frames
end

--- How many pixels the art of the cat asleep on a seat draws.
---
---@return integer
local function pixels_of_the_cat_asleep_on_a_seat()
  local rows = default.load_pack().pieces.cat_sleep_on_a_seat.frames[1]
  return #table.concat(rows):gsub('%.', '')
end

--- The pixel row of the top of the sofa front's cushion, where it covers
--- whatever is drawn behind it.
local SOFA_CUSHION_TOP = 39

T['the cat']['shows whole while it sleeps on a seat of the sofa'] = function()
  local frames = cat_frames_asleep_on_the_sofa()

  eq({
    #frames > 0,
    vim.iter(frames):all(function(frame)
      return frame.visible == pixels_of_the_cat_asleep_on_a_seat()
    end),
  }, { true, true })
end

T['the cat']['lies above the cushion of the sofa front while it sleeps on a seat'] = function()
  local frames = cat_frames_asleep_on_the_sofa()

  eq({
    #frames > 0,
    vim.iter(frames):all(function(frame)
      return frame.lowest < SOFA_CUSHION_TOP
    end),
  }, { true, true })
end

T['the cat']['stays asleep on a seat of the sofa for a minute before it walks off again'] = function()
  local pack = pack_with_life({ 'sleep_on_a_seat', 'wander_the_aisles' })
  local spots = default.spots(pack, ROOM[1], ROOM[2] - LIST_ROWS)
  local stage = default.stage(pack, ROOM[1], ROOM[2])
  local stay_seconds, longest_stay_seconds = 0, 0

  for step = 0, 4 * 600 do
    stage.advance({}, step / 4)
    local place = default.where_is(default.pixels(stage.picture(), ROOM[1]), default.CAT_COLOUR)
    if place and default.nearest_spot(spots, place) == 'sofa' then
      stay_seconds = stay_seconds + 0.25
    else
      stay_seconds = 0
    end
    longest_stay_seconds = math.max(longest_stay_seconds, stay_seconds)
  end

  eq(longest_stay_seconds >= 60, true)
end

T['the cat']['leaves a mess that an idle agent cleans up'] = function()
  local pack = pack_with_life({ 'leave_a_mess' })

  local listed = listed_over(pack, default.agents(2, 'idle'), 120)

  eq(listed:find('cleans up the mess', 1, true) ~= nil, true)
end

T['the cat']['leaves a puddle that an idle agent mops up'] = function()
  local pack = pack_with_life({ 'leave_a_puddle' })

  local listed = listed_over(pack, default.agents(2, 'idle'), 120)

  eq(listed:find('mops up the puddle', 1, true) ~= nil, true)
end

T['the cat']['angers the agent whose seat it takes, who leaves it in a huff'] = function()
  local pack = pack_with_life({ 'take_an_occupied_seat' })

  local listed = listed_over(pack, default.agents(3, 'idle'), 240)

  eq(listed:find('leaves in a huff', 1, true) ~= nil, true)
end

return T
