local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local fixture = dofile('tests/helpers/fixture.lua')
local pack_files = dofile('tests/helpers/office_pack_files.lua')
local office_pack = require('aineo.office_pack')
local office_states = require('aineo.office_states')

--- The `aineo-office` folder holding the tiny pack, which maps seven states
--- and one trigger.
local TINY_FOLDER =
  vim.fn.fnamemodify('tests/fixtures/office_packs/aineo-office', ':p'):gsub('/$', '')

--- The tiny pack, loaded.
---
---@return aineo.office_pack.Pack
local function tiny_pack()
  local pack = office_pack.load({ name = 'tiny', folders = { TINY_FOLDER } })
  assert(pack, 'the tiny pack does not load')
  return pack
end

--- The line of `lines` that tells of the state `name`: the one whose
--- state column holds it.
---
---@param lines string[]
---@param name string
---@return string|nil
local function line_of_state(lines, name)
  for _, line in ipairs(lines) do
    if line:match('^%s*%d*%s+' .. name .. '%s') then
      return line
    end
  end
end

local T = MiniTest.new_set()

T['the states a pack draws'] = MiniTest.new_set()

T['the states a pack draws']['names the pack, its author and what it is about first'] = function()
  local lines = office_pack.describe_states(tiny_pack())

  eq(lines[1], 'Office pack “tiny” by aineo')
  eq(lines[2], 'The smallest office: a door, a whiteboard, a server rack and rows of desks.')
end

T['the states a pack draws']['has a line for each of the 24 states and the four parents'] = function()
  local lines = office_pack.describe_states(tiny_pack())

  for _, state in ipairs(office_states.vocabulary()) do
    eq(type(line_of_state(lines, state.name)), 'string')
  end
end

T['the states a pack draws']['numbers the 24 states and leaves the parents without a number'] = function()
  local lines = office_pack.describe_states(tiny_pack())

  eq(line_of_state(lines, 'planning'):match('^%s*(%d+)'), '4')
  eq(line_of_state(lines, 'leaving'):match('^%s*(%d+)'), '24')
  eq(line_of_state(lines, 'working'):match('^%s*(%d+)'), nil)
end

T['the states a pack draws']['says a state the pack maps draws its activity, with what it looks like'] = function()
  local lines = office_pack.describe_states(tiny_pack())

  eq(
    line_of_state(lines, 'arriving'):match('draws .*$'),
    'draws come_in: Walks in through the door and sits down at its desk.'
  )
end

T['the states a pack draws']['says a state the pack does not map falls back, and what draws it'] = function()
  local lines = office_pack.describe_states(tiny_pack())

  eq(
    line_of_state(lines, 'planning'):match('falls back.*$'),
    'falls back to thinking, which draws think_at_the_board: Stands at the whiteboard with a thought bubble.'
  )
end

T['the states a pack draws']['follows the fallbacks as far as the first state the pack maps'] = function()
  local lines = office_pack.describe_states(tiny_pack())

  eq(
    line_of_state(lines, 'asleep'):match('falls back.*$'),
    'falls back to resting, which draws sit_back: Sits at its desk, doing nothing, for a while.'
  )
end

T['the states a pack draws']['lists the pack’s triggers, with the activity each plays'] = function()
  local lines = office_pack.describe_states(tiny_pack())

  eq(lines[#lines - 1], 'Triggers, tried in this order before a state’s own activity:')
  eq(
    lines[#lines],
    '  tool = Bash, command = docker → tend_the_server_rack: Stands at the server rack while a docker command runs.'
  )
end

T['the states a pack draws']['says a pack has no trigger when it has none, and leaves out an author it lacks'] = function()
  local folder = pack_files.write_pack(
    fixture.directory('office_state_list'),
    'small',
    { ['pack.lua'] = pack_files.pack_text({ author = '' }) }
  )
  local pack = office_pack.load({ name = 'small', folders = { folder } })

  local lines = office_pack.describe_states(pack)

  eq(lines[1], 'Office pack “small”')
  eq(lines[#lines], 'No custom triggers.')
end

T['the states a pack draws']['tells a Lua pattern of a trigger as one, after the tool'] = function()
  local folder = pack_files.write_pack(fixture.directory('office_state_list'), 'small', {
    ['pack.lua'] = pack_files.pack_text({
      triggers = {
        { when = { command = { lua_pattern = '^make%s+test' }, tool = 'Bash' }, play = 'work' },
      },
    }),
  })
  local pack = office_pack.load({ name = 'small', folders = { folder } })

  local lines = office_pack.describe_states(pack)

  eq(lines[#lines], '  tool = Bash, command = Lua pattern ^make%s+test → work')
end

return T
