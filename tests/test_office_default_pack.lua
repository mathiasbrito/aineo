local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local office_pack = require('aineo.office_pack')
local office_states = require('aineo.office_states')
local default = dofile('tests/helpers/office_default.lua')

--- The folders the default pack is searched in: those of 'runtimepath', where
--- the checkout puts `aineo-office`.
local function folders()
  return vim.api.nvim_get_runtime_file('aineo-office', true)
end

--- The names of the states of the vocabulary: the four parents and the 24
--- states, sorted.
---
---@return string[]
local function state_names()
  local names = vim.tbl_map(function(state)
    return state.name
  end, office_states.vocabulary())
  table.sort(names)
  return names
end

--- The `pack.lua` of the default pack, read as data and never run.
---
---@return table
local function description()
  local path = vim.fs.joinpath(folders()[1], 'default', 'pack.lua')
  local data, problems = office_pack.parse_table_literal(table.concat(vim.fn.readfile(path), '\n'))
  assert(data, vim.inspect(problems))
  return data
end

local T = MiniTest.new_set()

T['the default pack'] = MiniTest.new_set()

T['the default pack']['maps every state of the vocabulary, and nothing else, to an activity of its own'] = function()
  local keys = vim.tbl_keys(description().states)

  table.sort(keys)

  eq(keys, state_names())
end

T['the default pack']['gives every state of the vocabulary, and nothing else, an activity'] = function()
  local keys = vim.tbl_keys(default.load_pack().state_activity)

  table.sort(keys)

  eq(keys, state_names())
end

T['the default pack']['has no problem when it is checked'] = function()
  eq(office_pack.check({ name = 'default', folders = folders() }), {})
end

T['the default pack']['loads from the aineo-office folder of the checkout'] = function()
  local pack = default.load_pack()

  eq(pack.name, 'default')
  eq(pack.state_activity.working, 'write_code')
  eq(pack.state_activity.thinking, 'think_at_the_whiteboard')
  eq(pack.state_activity.idle, 'rest_on_the_sofa')
end

T['the default pack']['plays a different activity in each state a scene of the mock tells apart'] = function()
  local pack = default.load_pack()
  local told_apart = {
    'arriving',
    'getting_a_task',
    'thinking',
    'planning',
    'reading',
    'searching',
    'writing_code',
    'running_a_command',
    'running_tests',
    'background_job',
    'on_the_web',
    'delegating',
    'waiting_for_subagents',
    'needs_permission',
    'asking_you',
    'reporting',
    'committing',
    'compacting',
    'error',
    'interrupted',
    'done',
    'asleep',
    'leaving',
  }
  local seen = {}

  for _, state in ipairs(told_apart) do
    seen[pack.state_activity[state]] = (seen[pack.state_activity[state]] or 0) + 1
  end

  eq(vim.tbl_count(seen), #told_apart)
end

T['the default pack']['has a spot in its plan, or one aineo knows, for every spot its activities go to'] = function()
  local pack = default.load_pack()
  local known =
    { anywhere = true, an_empty_desk = true, an_idle_agents_desk = true, next_to_an_agent = true }
  local names = vim.deepcopy(known)
  for name in pairs(pack.things) do
    names[name] = true
  end
  for _, entry in pairs(pack.floor.legend) do
    names[entry.spot or ''] = true
    for _, piece in ipairs(entry.decorations or {}) do
      names[piece] = true
    end
  end
  local lacking = {}

  for name, activity in pairs(pack.activities) do
    for _, step in ipairs(activity.steps) do
      if step.at and not names[step.at] then
        lacking[name] = step.at
      end
    end
  end

  eq(lacking, {})
end

T['the default pack']['has the art for every piece its poses, screens, effects, legend and things name'] = function()
  local pack = default.load_pack()
  local named = {}
  for _, kind in ipairs({ 'agent', 'cat' }) do
    for _, pose in pairs(pack[kind] and pack[kind].poses or {}) do
      vim.list_extend(named, pose.art)
      table.insert(named, pose.screen)
      table.insert(named, pose.holding)
    end
  end
  for _, entry in pairs(pack.floor.legend) do
    table.insert(named, entry.piece)
    table.insert(named, entry.in_use)
    vim.list_extend(named, entry.decorations or {})
  end
  for _, thing in pairs(pack.things) do
    table.insert(named, thing.piece)
  end

  local missing = vim.tbl_filter(function(name)
    return pack.pieces[name] == nil
  end, named)

  eq(missing, {})
end

T['the default pack']['has an effect for every pose and step that shows one'] = function()
  local pack = default.load_pack()
  local missing = {}

  for _, kind in ipairs({ 'agent', 'cat' }) do
    for name, pose in pairs(pack[kind] and pack[kind].poses or {}) do
      if pose.effect and not pack.effects[pose.effect] then
        table.insert(missing, name)
      end
    end
  end
  for name, activity in pairs(pack.activities) do
    for _, step in ipairs(activity.steps) do
      if step.effect and not pack.effects[step.effect] then
        table.insert(missing, name)
      end
    end
  end

  eq(missing, {})
end

T['the default pack']['names at most 64 colours, so that a frame has at most 4,096 pixel pairs'] = function()
  eq(vim.tbl_count(default.load_pack().colours) <= 64, true)
end

T['the default pack']["keeps every effect one cell a character whatever 'ambiwidth' says"] = function()
  local pack = default.load_pack()
  local wide = {}
  local original = vim.o.ambiwidth

  for _, setting in ipairs({ 'single', 'double' }) do
    vim.o.ambiwidth = setting
    for name, effect in pairs(pack.effects) do
      for _, text in ipairs(effect.text) do
        if vim.fn.strdisplaywidth(text) ~= vim.fn.strchars(text) then
          wide[name] = setting
        end
      end
    end
  end
  vim.o.ambiwidth = original

  eq(wide, {})
end

T['the default pack']['draws a cat, the agents and the subagents'] = function()
  local pack = default.load_pack()

  eq({ pack.agent ~= nil, pack.subagent ~= nil, pack.cat ~= nil }, { true, true, true })
end

T['the default pack']['has the pieces the scene looks for by name'] = function()
  local pieces = default.load_pack().pieces

  for _, name in ipairs({ 'sky_night', 'sky_dawn', 'sky_day', 'sky_dusk', 'printed_page' }) do
    eq({ name, pieces[name] ~= nil }, { name, true })
  end
end

T['the default pack']['gives each live piece the area the scene draws into'] = function()
  local pieces = default.load_pack().pieces
  local areas = {
    whiteboard = 'plan',
    monitor = 'screen',
    wall_clock = 'time',
    wall_calendar = 'date',
    window = 'sky',
    printer = 'page',
  }

  for name, area in pairs(areas) do
    eq({ name, area, vim.tbl_get(pieces, name, 'areas', area) ~= nil }, { name, area, true })
  end
  eq(vim.tbl_get(pieces, 'monitor', 'areas', 'query') ~= nil, true)
end

return T
