local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local fixture = dofile('tests/helpers/fixture.lua')
local files = dofile('tests/helpers/office_pack_files.lua')
local office_pack = require('aineo.office_pack')

--- The states the tiny pack maps.
local TINY_STATES = {
  'standing',
  'arriving',
  'working',
  'thinking',
  'waiting',
  'resting',
  'leaving',
  'idle',
}

--- The `aineo-office` folder holding the tiny pack.
local TINY_FOLDER =
  vim.fn.fnamemodify('tests/fixtures/office_packs/aineo-office', ':p'):gsub('/$', '')

--- The directory the packs of one case are written in, emptied.
---
---@return string
local function pack_root()
  return fixture.directory('office_pack_checks')
end

--- The problems of the pack `small` made of `changes` to the smallest pack
--- and `extra_files`, each as `{ file, line, message }`, and the text of its
--- `pack.lua`.
---
---@param changes table
---@param extra_files? table<string, string|false>
---@return table[] problems
---@return string text
local function pack_problems(changes, extra_files)
  local text = files.pack_text(changes)
  local folder = files.write_pack(
    pack_root(),
    'small',
    vim.tbl_extend('force', { ['pack.lua'] = text }, extra_files or {})
  )
  local told = {}
  for _, problem in ipairs(office_pack.check({ name = 'small', folders = { folder } })) do
    table.insert(told, { problem.file, problem.line, problem.message })
  end
  return told, text
end

local DOOR_LEGEND = {
  d = { spot = 'door' },
  s = { spot = 'desk', sitting = true },
  D = { piece = 'person' },
  w = { spot = 'sofa', walk_over = true, piece = 'person' },
}

local T = MiniTest.new_set({
  hooks = {
    post_once = function()
      vim.fn.delete(pack_root(), 'rf')
    end,
  },
})

T['the tiny pack'] = MiniTest.new_set()

T['the tiny pack']['has no problem'] = function()
  eq(office_pack.check({ name = 'tiny', folders = { TINY_FOLDER }, state_names = TINY_STATES }), {})
end

T['the tiny pack']['is loaded whole'] = function()
  local pack, problems =
    office_pack.load({ name = 'tiny', folders = { TINY_FOLDER }, state_names = TINY_STATES })

  eq(problems, {})
  eq(pack.name, 'tiny')
  eq(vim.tbl_count(pack.pieces), 6)
  eq(pack.floor.repeated_columns, { first = 19, last = 32 })
  eq(pack.floor.repeated_rows, { first = 7, last = 9 })
  eq(pack.state_activity.working, 'work_at_the_desk')
  eq(pack.state_activity.idle, 'sit_back')
  eq(pack.agent.poses.thinking.effect, 'thought_bubble')
  eq(pack.cat, nil)
  eq(#pack.triggers, 1)
  eq(pack.pieces.whiteboard.stretch, { first = 2, last = 5 })
  eq(pack.pieces.desk.areas.name, { column = 1, row = 2, width = 10, height = 2 })
end

T['spots'] = MiniTest.new_set()

T['spots']['are told when they cannot be reached from the door, at the row they are on'] = function()
  local told = pack_problems({
    floor = { floor_colour = 'floor', legend = DOOR_LEGEND },
  }, { ['floor.txt'] = '# plan\n \n ####\n d.#s\n ####\n' })

  eq(told, { { 'floor.txt', 4, 'the spot “desk” cannot be reached from the door' } })
end

T['spots']['are reached over the floor, and over a piece lying on it that is walked over'] = function()
  local told = pack_problems({
    floor = { floor_colour = 'floor', legend = DOOR_LEGEND },
  }, { ['floor.txt'] = '# plan\n \n ######\n d.ws.#\n ######\n' })

  eq(told, {})
end

T['spots']['are not reached over a piece that stands on the floor'] = function()
  local told = pack_problems({
    floor = { floor_colour = 'floor', legend = DOOR_LEGEND },
  }, { ['floor.txt'] = '# plan\n \n ######\n d.Ds.#\n ######\n' })

  eq(told, { { 'floor.txt', 4, 'the spot “desk” cannot be reached from the door' } })
end

T['spots']['are not checked when the plan has no door'] = function()
  local told = pack_problems({
    floor = { floor_colour = 'floor', legend = { s = { spot = 'desk' } } },
  }, { ['floor.txt'] = '# plan\n \n ####\n .#s.\n ####\n' })

  eq(told, {})
end

T['an activity'] = MiniTest.new_set()

--- The smallest pack's activities, and `more`.
---
---@param more table
---@return table
local function activities_with(more)
  return vim.tbl_extend('force', {
    stand = { steps = { { at = 'desk', pose = 'standing' } } },
    work = { steps = { { at = 'desk', pose = 'typing' } } },
  }, more)
end

T['an activity']['is told never to play when the floor lacks a spot of its steps, at the step'] = function()
  local text = files.pack_text({
    activities = activities_with({ spare = { steps = { { at = 'desk' }, { at = 'sofa' } } } }),
  })
  local folder = files.write_pack(pack_root(), 'small', { ['pack.lua'] = text })

  local problems = office_pack.check({ name = 'small', folders = { folder } })

  eq(#problems, 1)
  eq(problems[1].line, files.line_of(text, 'activities'))
  eq(problems[1].message, 'activity “spare” never plays: the floor has no spot “sofa”')
end

T['an activity']['is not told when the spot is one aineo knows, a thing’s name, or a decoration'] = function()
  local told = pack_problems({
    activities = activities_with({
      spare = {
        steps = {
          { at = 'anywhere' },
          { at = 'an_empty_desk' },
          { at = 'an_idle_agents_desk' },
          { at = 'next_to_an_agent' },
          { at = 'next_to_the_cat' },
          { at = 'mess' },
          { at = 'person' },
        },
      },
    }),
    things = { mess = { piece = 'person' } },
    floor = {
      legend = {
        D = { decorations = { 'person' } },
        s = { spot = 'desk', sitting = true },
      },
    },
  })

  eq(told, {})
end

T['an activity']['of the pack it is based on is told at the floor of the pack that lacks its spot'] = function()
  local root = pack_root()
  files.write_pack(root, 'base', { ['pack.lua'] = files.pack_text({ name = 'base' }) })
  local text = files.description_text({
    format = 1,
    name = 'child',
    based_on = 'base',
    floor = { floor_colour = 'floor', legend = { d = { spot = 'door' } } },
  })
  local folder = files.write_pack(root, 'child', {
    ['pack.lua'] = text,
    ['floor.txt'] = '# plan\n \n ###\n d..\n',
    ['art/person.txt'] = false,
  })

  local problems = office_pack.check({ name = 'child', folders = { folder } })

  eq(#problems, 2)
  eq(problems[1].line, files.line_of(text, 'floor'))
  eq(problems[1].message, 'activity “stand” never plays: the floor has no spot “desk”')
  eq(problems[2].message, 'activity “work” never plays: the floor has no spot “desk”')
end

return T
