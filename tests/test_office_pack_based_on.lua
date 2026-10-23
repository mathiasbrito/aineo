local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local fixture = dofile('tests/helpers/fixture.lua')
local files = dofile('tests/helpers/office_pack_files.lua')
local office_pack = require('aineo.office_pack')

--- The states the tests' packs are checked against.
local STATE_NAMES = { 'standing', 'working', 'resting', 'idle' }

--- The directory the packs of one case are written in, emptied.
---
---@return string
local function pack_root()
  return fixture.directory('office_pack_based_on')
end

--- Writes the pack `base`, the smallest pack, and the pack `child`, based on
--- it, with only `fields` in its description and `extra_files` over its
--- files, which are none: it has no floor plan and no art of its own.
---
---@param fields? table the fields of the child's pack.lua
---@param extra_files? table<string, string|false> the child's files
---@return string folder
---@return string text the text of the child's pack.lua
local function pack_with_child(fields, extra_files)
  local root = pack_root()
  files.write_pack(root, 'base', { ['pack.lua'] = files.pack_text({ name = 'base' }) })
  local text = files.description_text(
    vim.tbl_extend('force', { format = 1, name = 'child', based_on = 'base' }, fields or {})
  )
  local folder = files.write_pack(
    root,
    'child',
    vim.tbl_extend('force', {
      ['pack.lua'] = text,
      ['floor.txt'] = false,
      ['art/person.txt'] = false,
    }, extra_files or {})
  )
  return folder, text
end

--- Loads the pack `name` from `folder`.
---
---@param name string
---@param folder string
---@return aineo.office_pack.Pack|nil pack
---@return aineo.office_pack.Problem[] problems
local function load_pack(name, folder)
  return office_pack.load({ name = name, folders = { folder }, state_names = STATE_NAMES })
end

--- The problems as `{ pack, file, line, message }`.
---
---@param problems aineo.office_pack.Problem[]
---@return table[]
local function told(problems)
  return vim.tbl_map(function(problem)
    return { problem.pack, problem.file, problem.line, problem.message }
  end, problems)
end

local T = MiniTest.new_set({
  hooks = {
    post_once = function()
      vim.fn.delete(pack_root(), 'rf')
    end,
  },
})

T['a pack based on another'] = MiniTest.new_set()

T['a pack based on another']['has what it leaves out from the pack it is based on'] = function()
  local folder = pack_with_child()

  local pack, problems = load_pack('child', folder)

  eq(problems, {})
  eq(pack.name, 'child')
  eq(vim.tbl_keys(pack.pieces), { 'person' })
  eq(pack.floor.rows, { '####', 'D..#', '..s.' })
  eq(pack.state_activity.working, 'work')
  eq(pack.agent.poses.typing.effect, 'busy_dots')
  eq(pack.effects.busy_dots.text, { '.', '..', '...' })
end

T['a pack based on another']['has a piece of its own in place of the one of its name'] = function()
  local folder = pack_with_child({}, { ['art/person.txt'] = 'colours: A = ink\n---\nA\n' })

  local pack = load_pack('child', folder)

  eq(pack.pieces.person.frames, { { 'A' } })
end

T['a pack based on another']['has the activities of both, and maps a state over the pack’s'] = function()
  local folder = pack_with_child({
    activities = { rest = { steps = { { at = 'desk', pose = 'sitting' } } } },
    states = { resting = 'rest' },
  })

  local pack, problems = load_pack('child', folder)

  eq(problems, {})
  eq(pack.activities.stand ~= nil and pack.activities.rest ~= nil, true)
  eq(pack.state_activity.idle, 'rest')
  eq(pack.state_activity.standing, 'stand')
end

T['a pack based on another']['has the colours of both, its own over the other’s'] = function()
  local folder = pack_with_child({
    colours = { mud = '#112233', wall = '#000000' },
    text_colours = { thought = '#b4befe' },
  })

  local pack = load_pack('child', folder)

  eq(pack.colours.mud, '#112233')
  eq(pack.colours.wall, '#000000')
  eq(pack.colours.floor, '#303446')
  eq(pack.text_colours.thought, '#b4befe')
  eq(pack.text_colours.name, 'Comment')
end

T['a pack based on another']['has a floor of its own in place of the other’s'] = function()
  local folder = pack_with_child({
    floor = { legend = { s = { spot = 'desk' } } },
  }, { ['floor.txt'] = '# plan\n \n s.\n' })

  local pack, problems = load_pack('child', folder)

  eq(problems, {})
  eq(pack.floor.rows, { 's.' })
end

T['a pack based on another']['tries its triggers before the other’s'] = function()
  local root = pack_root()
  local base_triggers = { { when = { tool = 'Bash' }, play = 'work' } }
  local child_triggers = { { when = { tool = 'Edit' }, play = 'stand' } }
  files.write_pack(root, 'base', {
    ['pack.lua'] = files.pack_text({ name = 'base', triggers = base_triggers }),
  })
  local folder = files.write_pack(root, 'child', {
    ['pack.lua'] = files.description_text({
      format = 1,
      name = 'child',
      based_on = 'base',
      triggers = child_triggers,
    }),
    ['floor.txt'] = false,
    ['art/person.txt'] = false,
  })

  local pack = load_pack('child', folder)

  eq(pack.triggers, { child_triggers[1], base_triggers[1] })
end

T['a pack based on another']['gives its subagent the poses of the other’s with colours of its own'] = function()
  local folder = pack_with_child({
    characters = { subagent = { colours = { '#cba6f7' } } },
  })

  local pack, problems = load_pack('child', folder)

  eq(problems, {})
  eq(pack.subagent.colours, { '#cba6f7' })
  eq(pack.subagent.poses, pack.agent.poses)
end

T['a pack based on the default pack when it says nothing'] = MiniTest.new_set()

T['a pack based on the default pack when it says nothing']['has what it leaves out from the default pack'] = function()
  local root = pack_root()
  files.write_pack(root, 'default', { ['pack.lua'] = files.pack_text({ name = 'default' }) })
  local folder = files.write_pack(root, 'child', {
    ['pack.lua'] = files.description_text({ format = 1, name = 'child' }),
    ['floor.txt'] = false,
    ['art/person.txt'] = false,
  })

  local pack, problems = load_pack('child', folder)

  eq(problems, {})
  eq(pack.name, 'child')
  eq(pack.floor.rows, { '####', 'D..#', '..s.' })
end

T['a pack based on the default pack when it says nothing']['has nothing from it when it says it is based on none'] = function()
  local root = pack_root()
  files.write_pack(root, 'default', { ['pack.lua'] = files.pack_text({ name = 'default' }) })
  local folder = files.write_pack(root, 'child', {
    ['pack.lua'] = files.description_text({ format = 1, name = 'child', based_on = false }),
    ['floor.txt'] = false,
    ['art/person.txt'] = false,
  })

  local pack, problems = load_pack('child', folder)

  eq(pack.name, 'default')
  eq(problems[1].pack, 'child')
end

T['a pack with something wrong'] = MiniTest.new_set()

T['a pack with something wrong']['takes a piece of the pack it is based on for one with a problem, with one problem'] = function()
  local folder = pack_with_child({}, { ['art/person.txt'] = 'colours: A = agent\n---\nAA\nA\n' })

  local pack, problems = load_pack('child', folder)

  eq(pack.pieces.person.frames, { { 'Ak', 'AA', 'kk' } })
  eq(told(problems), {
    { 'child', 'art/person.txt', 4, 'this row is 1 pixels wide, and the first row is 2' },
  })
end

T['a pack with something wrong']['takes an effect of the pack it is based on for one with a problem'] = function()
  local folder, text = pack_with_child({ effects = { busy_dots = { text = {} } } })

  local pack, problems = load_pack('child', folder)

  eq(pack.effects.busy_dots.text, { '.', '..', '...' })
  eq(told(problems), {
    {
      'child',
      'pack.lua',
      files.line_of(text, 'effects'),
      'effects.busy_dots.text must be a list of at least 1',
    },
  })
end

T['a pack with something wrong']['takes a pose of the pack it is based on for one with a problem'] = function()
  local folder, text = pack_with_child({
    characters = { agent = { poses = { sitting = { art = { 'nothing' } } } } },
  })

  local pack, problems = load_pack('child', folder)

  eq(pack.agent.poses.sitting.art, { 'person' })
  eq(told(problems), {
    {
      'child',
      'pack.lua',
      files.line_of(text, 'characters'),
      'characters.agent.poses.sitting.art[1] names the piece “nothing”, which the pack does not have',
    },
  })
end

T['a pack with something wrong']['takes a pose of the pack it is based on for one that is like itself'] = function()
  local folder, text = pack_with_child({
    characters = { agent = { poses = { sitting = { like = 'sitting' } } } },
  })

  local pack, problems = load_pack('child', folder)

  eq(pack.agent.poses.sitting, { art = { 'person' }, sitting = true })
  eq(told(problems), {
    {
      'child',
      'pack.lua',
      files.line_of(text, 'characters'),
      'characters.agent.poses.sitting is like itself',
    },
  })
end

T['a pack with something wrong']['takes an activity of the pack it is based on for one with a problem'] = function()
  local folder, text = pack_with_child({ activities = { work = {} } })

  local pack, problems = load_pack('child', folder)

  eq(pack.activities.work.steps[1].pose, 'typing')
  eq(told(problems), {
    { 'child', 'pack.lua', files.line_of(text, 'activities'), 'activities.work is missing steps' },
  })
end

T['a pack with something wrong']['takes a state of the pack it is based on for one with a problem'] = function()
  local folder, text = pack_with_child({ states = { working = 'nowhere' } })

  local pack, problems = load_pack('child', folder)

  eq(pack.state_activity.working, 'work')
  eq(told(problems), {
    {
      'child',
      'pack.lua',
      files.line_of(text, 'states'),
      'states.working names the activity “nowhere”, which the pack does not have',
    },
  })
end

T['a pack with something wrong']['gives the default pack in its place when it cannot be used, with its problem'] = function()
  local root = pack_root()
  files.write_pack(root, 'default', { ['pack.lua'] = files.pack_text({ name = 'default' }) })
  local folder = files.write_pack(root, 'broken', {
    ['pack.lua'] = files.pack_text({ name = 'broken' }),
    ['floor.txt'] = false,
  })

  local pack, problems = load_pack('broken', folder)

  eq(pack.name, 'default')
  eq(told(problems), { { 'broken', 'floor.txt', nil, 'the file is missing' } })
end

T['a pack with something wrong']['gives no pack, and the problems of both, when the default pack cannot be used either'] = function()
  local folder = files.write_pack(pack_root(), 'broken', { ['floor.txt'] = false })

  local pack, problems = load_pack('broken', folder)

  eq(pack, nil)
  eq(#problems, 2)
  eq(problems[2].pack, 'default')
end

T['a pack with something wrong']['tells a name that is not the name of its folder'] = function()
  local text = files.pack_text({ name = 'other' })
  local folder = files.write_pack(pack_root(), 'small', { ['pack.lua'] = text })

  local _, problems = load_pack('small', folder)

  eq(told(problems), {
    {
      'small',
      'pack.lua',
      files.line_of(text, 'name'),
      'name is “other”, and the pack’s folder is “small”',
    },
  })
end

T['a pack with something wrong']['tells more than 64 colours'] = function()
  local colours = {}
  for index = 1, 65 do
    colours['colour_' .. index] = '#112233'
  end
  local text = files.pack_text({ colours = vim.tbl_extend('force', colours, { ink = '#1e1e2e' }) })
  local folder = files.write_pack(pack_root(), 'small', { ['pack.lua'] = text })

  local _, problems = load_pack('small', folder)

  local found = vim.iter(told(problems)):find(function(problem)
    return problem[4] == 'colours has more than 64 entries'
  end)
  eq(
    found,
    { 'small', 'pack.lua', files.line_of(text, 'colours'), 'colours has more than 64 entries' }
  )
end

T['a pack that is based on another'] = MiniTest.new_set()

T['a pack that is based on another']['tells the pack it is based on when that is not found, and goes on without it'] = function()
  local text = files.pack_text({ name = 'small', based_on = 'nothing' })
  local folder = files.write_pack(pack_root(), 'small', { ['pack.lua'] = text })

  local pack, problems = load_pack('small', folder)

  eq(pack.name, 'small')
  eq(told(problems), {
    { 'nothing', 'pack.lua', nil, ('there is no pack “nothing” in %s'):format(folder) },
    {
      'small',
      'pack.lua',
      files.line_of(text, 'based_on'),
      'the pack “nothing” it is based on cannot be used',
    },
  })
end

T['a pack that is based on another']['tells packs based on each other, once, and loads them'] = function()
  local root = pack_root()
  local text_b = files.pack_text({ name = 'b', based_on = 'a' })
  files.write_pack(root, 'a', { ['pack.lua'] = files.pack_text({ name = 'a', based_on = 'b' }) })
  local folder = files.write_pack(root, 'b', { ['pack.lua'] = text_b })

  local pack, problems = load_pack('a', folder)

  eq(pack.name, 'a')
  eq(told(problems), {
    {
      'b',
      'pack.lua',
      files.line_of(text_b, 'based_on'),
      'based_on loops back to the pack “a”',
    },
  })
end

T['a pack that is based on another']['tells a chain of more than eight packs, once, where it is cut'] = function()
  local root = pack_root()
  local folder
  for index = 0, 9 do
    folder = files.write_pack(root, 'p' .. index, {
      ['pack.lua'] = files.pack_text({
        name = 'p' .. index,
        based_on = index > 0 and ('p' .. (index - 1)) or false,
      }),
    })
  end

  local pack, problems = load_pack('p9', folder)

  eq(pack.name, 'p9')
  eq(#problems, 1)
  eq(problems[1].pack, 'p2')
  eq(problems[1].message, 'the pack is based on more than 8 packs, one after another')
end

T['pieces of the user’s own'] = MiniTest.new_set()

T['pieces of the user’s own']['replace the pieces of their names'] = function()
  local folder = pack_with_child()
  local replacement = vim.fs.joinpath(vim.fs.dirname(folder), 'mine.txt')
  vim.fn.writefile({ 'colours: A = wood', '---', 'AAA' }, replacement)

  local pack, problems = office_pack.load({
    name = 'child',
    folders = { folder },
    state_names = STATE_NAMES,
    replaced_pieces = { person = replacement },
  })

  eq(problems, {})
  eq(pack.pieces.person.frames, { { 'AAA' } })
end

T['pieces of the user’s own']['keep the piece of the pack when they have a problem, and tell it with the file'] = function()
  local folder = pack_with_child()
  local replacement = vim.fs.joinpath(vim.fs.dirname(folder), 'mine.txt')
  vim.fn.writefile({ 'colours: A = wood', '---', 'AAA', 'AA' }, replacement)

  local pack, problems = office_pack.load({
    name = 'child',
    folders = { folder },
    state_names = STATE_NAMES,
    replaced_pieces = { person = replacement },
  })

  eq(pack.pieces.person.frames, { { 'Ak', 'AA', 'kk' } })
  eq(#problems, 1)
  eq(problems[1].path, replacement)
  eq(problems[1].line, 4)
end

T['pieces of the user’s own']['tell a file that is missing'] = function()
  local folder = pack_with_child()
  local replacement = vim.fs.joinpath(vim.fs.dirname(folder), 'absent.txt')

  local _, problems = office_pack.load({
    name = 'child',
    folders = { folder },
    state_names = STATE_NAMES,
    replaced_pieces = { person = replacement },
  })

  eq(#problems, 1)
  eq(problems[1].message, 'the file is missing')
end

return T
