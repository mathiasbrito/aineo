-- Compares the hand-written activities and effects of the default pack with
-- the mock's own `behaviours.lua` and effect tables, and prints what differs.
--
-- The activities are the pack format's plain fields; the mock's entries have
-- a label, a weight and steps of `go`, `pose`, `wait` and `face`. This turns
-- each mock entry into the activity that plays it and checks the label, the
-- chance and the times; the spots and the poses are named differently and are
-- read by eye.

local M = {}

--- The mock's entry, by pool and name, and the pack's activity that plays it.
local CONVERTED = {
  { 'idle', 'stretch', 'stretch' },
  { 'idle', 'yawn', 'yawn' },
  { 'idle', 'spin', 'spin_in_the_chair' },
  { 'idle', 'window', 'look_out_of_the_window' },
  { 'idle', 'book', 'read_a_book_on_the_sofa' },
  { 'idle', 'water', 'water_the_snake_plant' },
  { 'idle', 'paper_ball', 'throw_a_paper_ball_in_the_bin', 'throw_a_paper_ball_and_miss' },
  { 'idle', 'cooler', 'get_a_drink_at_the_water_cooler' },
  { 'idle', 'doodle', 'doodle_on_the_whiteboard' },
  { 'idle', 'tidy', 'tidy_the_desk' },
  { 'idle', 'nap', 'nap_on_the_sofa' },
  { 'waiting', 'drum', 'drum_its_fingers' },
  { 'waiting', 'watch', 'look_at_its_watch' },
  { 'waiting', 'pace', 'pace_beside_the_desk' },
  { 'waiting', 'glance', 'glance_at_the_door' },
  { 'waiting', 'tap', 'tap_a_foot' },
  { 'permission', 'drum', 'drum_its_fingers_and_wait' },
  { 'permission', 'watch', 'look_at_its_watch_and_wait' },
  { 'permission', 'glance', 'glance_at_the_door_and_wait' },
  { 'cat', 'wander', 'wander_the_aisles' },
  { 'cat', 'wash', 'sit_and_wash' },
  { 'cat', 'nap', 'sleep_on_a_seat' },
  { 'cat', 'desk', 'jump_on_an_empty_desk' },
  { 'cat', 'keyboard', 'sit_on_a_keyboard' },
  { 'cat', 'rub', 'rub_against_legs' },
  { 'cat', 'follow', 'follow_someone' },
  { 'cat', 'tank', 'stare_at_the_fish' },
}

--- What D109 changed from the mock, by activity: the user asked for a lazier
--- cat that sleeps on the sofa seat itself.
local ADJUSTED_BY_D109 = { sleep_on_a_seat = true }

--- The seconds of a mock step, as the pack writes them.
local function seconds_of(step)
  local range = step.secs or step.wait or step.follow
  if not range then
    return nil
  end
  if range[1] == range[2] then
    return range[1]
  end
  return { range[1], range[2] }
end

--- The mock's times of an entry, those of its steps that last, in order.
local function times_of(entry)
  local times = {}
  for _, step in ipairs(entry.steps) do
    local seconds = seconds_of(step)
    if seconds then
      table.insert(times, seconds)
    end
  end
  return times
end

--- The pack's times of an activity, those of its steps that last, in order.
local function pack_times_of(activity)
  local times = {}
  for _, step in ipairs(activity.steps) do
    if step.for_seconds and not (type(step.for_seconds) == 'table' and step.for_seconds[2] == 0) then
      table.insert(times, step.for_seconds)
    end
  end
  return times
end

--- Prints what differs between the mock's behaviours and the pack's activities.
---
---@param behaviours table the mock's `behaviours` module
---@param definitions table
function M.report(behaviours, definitions)
  local by_name = {}
  for _, entry in ipairs(definitions.activities) do
    by_name[entry[1]] = entry[2]
  end
  local differences, compared = {}, 0
  for _, converted in ipairs(CONVERTED) do
    local pool, name = converted[1], converted[2]
    local mock
    for _, entry in ipairs(behaviours[pool]) do
      if entry.name == name then
        mock = entry
      end
    end
    assert(mock, 'the mock has no ' .. pool .. '/' .. name)
    local weight = 0
    for index = 3, #converted do
      local activity = by_name[converted[index]]
      assert(activity, 'the pack has no activity ' .. converted[index])
      weight = weight + activity.chance
      compared = compared + 1
      if activity.label ~= mock.label and not ADJUSTED_BY_D109[converted[index]] then
        table.insert(differences, ('%s: label “%s”, the mock’s “%s”'):format(converted[index], activity.label, mock.label))
      end
      if
        #converted == 3
        and vim.inspect(pack_times_of(activity)) ~= vim.inspect(times_of(mock))
        and not ADJUSTED_BY_D109[converted[index]]
      then
        table.insert(
          differences,
          ('%s: times %s, the mock’s %s'):format(
            converted[index],
            vim.inspect(pack_times_of(activity)):gsub('%s+', ' '),
            vim.inspect(times_of(mock)):gsub('%s+', ' ')
          )
        )
      end
    end
    if weight ~= mock.weight and not ADJUSTED_BY_D109[converted[3]] then
      table.insert(differences, ('%s/%s: chance %s, the mock’s weight %s'):format(pool, name, weight, mock.weight))
    end
  end
  print(('compared %d activities with the mock\'s behaviours: %d differences'):format(compared, #differences))
  for _, line in ipairs(differences) do
    print('  ' .. line)
  end
end

return M
