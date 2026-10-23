local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local default = dofile('tests/helpers/office_default.lua')

local PACK = 'space_station'

--- A room wide and tall enough for every spot of the plan: the second bench,
--- the holo-game table, the wall's decorations and the hydroponics pod.
local ROOM = { 260, 80 }

--- The rows the status list takes of the bottom of the window.
local LIST_ROWS = 5

--- The pack with only the activities of random life `wanted` names left;
--- what the states play is left as it is.
---
---@param wanted string[]
---@return aineo.office_pack.Pack
local function pack_with_life(wanted)
  local pack = default.load_pack(PACK)
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

--- The names of the spots nearest to the agent or the pet drawn in `colour`
--- over `seconds`, one for each half second it is drawn.
---
---@param pack aineo.office_pack.Pack
---@param agents aineo.office_states.Agent[]
---@param seconds number
---@param colour string `#rrggbb` the agent or the pet is drawn in
---@return table<string, true> names
local function spots_visited(pack, agents, seconds, colour)
  local spots = default.spots(pack, ROOM[1], ROOM[2] - LIST_ROWS)
  local stage = default.stage(pack, ROOM[1], ROOM[2])
  local names = {}
  for step = 0, seconds * 4 do
    stage.advance(agents, step / 4)
    if step % 2 == 0 then
      local place = default.where_is(default.pixels(stage.picture(), ROOM[1]), colour)
      if place then
        names[default.nearest_spot(spots, place)] = true
      end
    end
  end
  return names
end

local T = MiniTest.new_set()

T['an idle crew member'] = MiniTest.new_set()

T['an idle crew member']['tells in the status list what it does on the station'] =
  MiniTest.new_set({
    parametrize = {
      { 'look_out_of_the_window', 'looks out of the viewport' },
      { 'read_a_book_on_the_sofa', 'reads a data slate on the bench' },
      { 'water_the_snake_plant', 'tends the hydroponics' },
      { 'water_the_corner_plant', 'tends the hydroponics' },
      { 'throw_a_paper_ball_in_the_bin', 'throws a wrapper at the chute' },
      { 'throw_a_paper_ball_and_miss', 'throws a wrapper at the chute' },
      { 'get_a_drink_at_the_water_cooler', 'chats at the coolant tap' },
      { 'doodle_on_the_whiteboard', 'sketches on the holo-table' },
      { 'tidy_the_desk', 'tidies the console' },
      { 'nap_on_the_sofa', 'naps on the bench' },
      { 'play_table_tennis', 'plays a holo game' },
    },
  })

T['an idle crew member']['tells in the status list what it does on the station']['activity and label'] = function(
  name,
  label
)
  local listed = listed_over(pack_with_life({ name }), default.agents(2, 'idle'), 90)

  eq(listed:find(label, 1, true) ~= nil, true)
end

T['an idle crew member']['goes to the piece of the station it does something at'] =
  MiniTest.new_set({
    parametrize = {
      { 'look_out_of_the_window', 'viewport' },
      { 'water_the_snake_plant', 'hydroponics_rack' },
      { 'water_the_corner_plant', 'hydroponics_pod' },
      { 'get_a_drink_at_the_water_cooler', 'coolant_tap' },
      { 'throw_a_paper_ball_in_the_bin', 'trash_bin' },
      { 'doodle_on_the_whiteboard', 'whiteboard' },
    },
  })

T['an idle crew member']['goes to the piece of the station it does something at']['activity and spot'] = function(
  name,
  spot
)
  local visited =
    spots_visited(pack_with_life({ name }), default.agents(1, 'idle'), 90, default.AGENT_COLOURS[1])

  eq(visited[spot], true)
end

T['two idle crew members'] = MiniTest.new_set()

T['two idle crew members']['play the holo game together, each at an end of the table'] = function()
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

T['the starhare'] = MiniTest.new_set()

T['the starhare']['stares at the jellies in front of the specimen tank'] = function()
  local visited = spots_visited(
    pack_with_life({ 'stare_at_the_fish' }),
    default.agents(1, 'idle'),
    120,
    default.CAT_COLOUR
  )

  eq(visited.specimen_tank, true)
end

T['an idle crew member']['pets the starhare, which waits still for it'] = function()
  local pack = pack_with_life({ 'pet_the_cat', 'wander_the_aisles' })

  local listed = listed_over(pack, default.agents(1, 'idle'), 240)

  eq(listed:find('pets the starhare', 1, true) ~= nil, true)
end

return T
