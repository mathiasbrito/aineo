local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local fixture = dofile('tests/helpers/fixture.lua')
local files = dofile('tests/helpers/office_pack_files.lua')
local office_pack = require('aineo.office_pack')

--- The directory the packs of one case are written in, emptied.
---
---@return string
local function pack_root()
  return fixture.directory('office_pack')
end

--- Loads the pack `name` from the `aineo-office` folders `folders`.
---
---@param name string
---@param folders string[]
---@return aineo.office_pack.Pack|nil pack
local function load_pack(name, folders)
  return (office_pack.load({ name = name, folders = folders }))
end

--- What is wrong with the pack `name` in the `aineo-office` folders `folders`,
--- each problem as `{ file, line, message }`.
---
---@param name string
---@param folders string[]
---@return table[]
local function problems_of(name, folders)
  local told = {}
  for _, problem in ipairs(office_pack.check({ name = name, folders = folders })) do
    table.insert(told, { problem.file, problem.line, problem.message })
  end
  return told
end

local T = MiniTest.new_set({
  hooks = {
    post_once = function()
      vim.fn.delete(pack_root(), 'rf')
    end,
  },
})

T['find()'] = MiniTest.new_set()

T['find()']['lists the packs of the folders, by name, each with the folder it is in'] = function()
  local root = pack_root()
  local first = files.write_pack(vim.fs.joinpath(root, 'one'), 'beta')
  local second = files.write_pack(vim.fs.joinpath(root, 'two'), 'alpha')

  eq(office_pack.find({ first, second }), {
    { name = 'alpha', directory = vim.fs.joinpath(second, 'alpha') },
    { name = 'beta', directory = vim.fs.joinpath(first, 'beta') },
  })
end

T['find()']['lists a pack of two folders once, as the first folder has it'] = function()
  local root = pack_root()
  local first = files.write_pack(vim.fs.joinpath(root, 'one'), 'small')
  local second = files.write_pack(vim.fs.joinpath(root, 'two'), 'small')

  eq(office_pack.find({ first, second }), {
    { name = 'small', directory = vim.fs.joinpath(first, 'small') },
  })
end

T['find()']['passes over a folder that is missing and a folder that holds no pack.lua'] = function()
  local root = pack_root()
  local folder = files.write_pack(root, 'empty', { ['pack.lua'] = false })

  eq(office_pack.find({ folder, vim.fs.joinpath(root, 'nothing') }), {})
end

T['load()'] = MiniTest.new_set()

T['load()']['gives the pack’s name, description and author'] = function()
  local folder = files.write_pack(pack_root(), 'small')

  local pack = load_pack('small', { folder })

  eq(pack.name, 'small')
  eq(pack.about, 'The smallest pack that loads.')
  eq(pack.author, 'the tests')
end

T['load()']['gives the colours the pack names'] = function()
  local folder = files.write_pack(pack_root(), 'small')

  local pack = load_pack('small', { folder })

  eq(pack.colours.wall, '#292c3c')
  eq(pack.colours.floor, '#303446')
end

T['load()']['reads an art file as a piece with its colours, anchor, speed and frames'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['art/blinker.txt'] = table.concat({
      'about: Two frames.',
      'colours: A = agent, k = ink',
      'anchor: 1, 1',
      'seconds per frame: 0.5',
      '---',
      'Ak',
      'kA',
      '---',
      'AA',
      'kk',
      '',
    }, '\n'),
  })

  local pack = load_pack('small', { folder })

  eq(pack.pieces.blinker, {
    name = 'blinker',
    about = 'Two frames.',
    colours = { A = 'agent', k = 'ink' },
    anchor = { column = 1, row = 1 },
    faces = 'right',
    areas = {},
    seconds_per_frame = 0.5,
    frames = { { 'Ak', 'kA' }, { 'AA', 'kk' } },
    width = 2,
    height = 2,
  })
end

T['load()']['gives an art file without an anchor or a speed the bottom left corner and a quarter second'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['art/plain.txt'] = 'colours: A = agent\n---\nAAA\nAAA\n',
  })

  local pack = load_pack('small', { folder })

  eq(pack.pieces.plain.anchor, { column = 0, row = 1 })
  eq(pack.pieces.plain.seconds_per_frame, 0.25)
end

T['load()']['reads every art file of the pack'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['art/other.txt'] = 'colours: A = agent\n---\nA\n',
  })

  local pack = load_pack('small', { folder })

  local names = vim.tbl_keys(pack.pieces)
  table.sort(names)
  eq(names, { 'other', 'person' })
end

T['load()']['reads the floor plan without its marker column, with the columns that repeat'] = function()
  local folder = files.write_pack(pack_root(), 'small')

  local pack = load_pack('small', { folder })

  eq(pack.floor.rows, { '####', 'D..#', '..s.' })
  eq(pack.floor.repeated_columns, { first = 1, last = 2 })
end

T['load()']['gives a floor plan without a marked block no repeated columns'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['floor.txt'] = '# plan\n  \n ##\n D.\n',
  })

  local pack = load_pack('small', { folder })

  eq(pack.floor.repeated_columns, nil)
  eq(pack.floor.rows, { '##', 'D.' })
end

T['load()']['gives the floor its colours and the legend of what each letter is'] = function()
  local folder = files.write_pack(pack_root(), 'small')

  local pack = load_pack('small', { folder })

  eq(pack.floor.floor_colour, 'floor')
  eq(pack.floor.wall_colour, 'wall')
  eq(pack.floor.legend, {
    D = { piece = 'person', sitting = false, facing = 'right', walk_over = false },
    s = { spot = 'desk', sitting = true, facing = 'right', walk_over = false },
  })
end

T['load()']['gives the poses of the agent, a pose taking what it is like from the pose it names'] = function()
  local folder = files.write_pack(pack_root(), 'small')

  local pack = load_pack('small', { folder })

  eq(pack.agent.poses.typing, { art = { 'person' }, sitting = true, effect = 'busy_dots' })
  eq(pack.agent.poses.standing, { art = { 'person' }, sitting = false })
  eq(pack.agent.colours, { '#a6e3a1' })
end

T['load()']['gives an effect its colour, place, speed and weight when the pack leaves them out'] = function()
  local folder = files.write_pack(pack_root(), 'small')

  local pack = load_pack('small', { folder })

  eq(pack.effects.busy_dots, {
    text = { '.', '..', '...' },
    colour = 'status',
    place = 'above',
    seconds_per_frame = 0.25,
    bold = false,
  })
end

T['load()']['gives the colours of the office’s text by role'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({ text_colours = { thought = '#b4befe' } }),
  })

  local pack = load_pack('small', { folder })

  eq(pack.text_colours.thought, '#b4befe')
  eq(pack.text_colours.status, 'Normal')
end

T['load()']['gives each state the activity of the first state it falls back through that the pack maps'] = function()
  local folder = files.write_pack(pack_root(), 'small')

  local pack = load_pack('small', { folder })

  eq(pack.state_activity, {
    standing = 'stand',
    working = 'work',
    resting = 'stand',
    idle = 'stand',
  })
end

T['load()']['prefers the activity a pack maps to a state over the one it falls back to'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({
      states = { standing = 'stand', idle = 'work' },
    }),
  })

  local pack = load_pack('small', { folder })

  eq(pack.state_activity.idle, 'work')
  eq(pack.state_activity.resting, 'stand')
end

T['load()']['gives the activities of the pack'] = function()
  local folder = files.write_pack(pack_root(), 'small')

  local pack = load_pack('small', { folder })

  eq(pack.activities.work, {
    about = '',
    who = 'agents',
    chance = 1,
    players = 1,
    steps = { { at = 'desk', pose = 'typing', even_if_taken = false } },
  })
end

T['load()']['finds the pack in the first folder that holds it'] = function()
  local first = files.write_pack(fixture.directory('office_pack/first'), 'other')
  local second = files.write_pack(fixture.directory('office_pack/second'), 'small')

  local pack = load_pack('small', { first, second })

  eq(pack.name, 'small')
end

T['load()']['says which pack was not found and where it looked'] = function()
  local folder = files.write_pack(pack_root(), 'small')

  eq(problems_of('missing', { folder }), {
    { 'pack.lua', nil, ('there is no pack “missing” in %s'):format(folder) },
  })
end

T['load()']['says there is no pack when it is given no folder'] = function()
  eq(problems_of('small', {}), {
    { 'pack.lua', nil, 'there is no pack “small” in any folder' },
  })
end

T['load()']['says which line of pack.lua is not data'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = 'return {\n  format = 1,\n  name = os.getenv("HOME"),\n}\n',
  })

  eq(problems_of('small', { folder }), { { 'pack.lua', 3, '`os` is not data' } })
end

T['load()']['refuses a pack written for another format'] = function()
  local text = files.pack_text({ format = 2 })
  local folder = files.write_pack(pack_root(), 'small', { ['pack.lua'] = text })

  eq(problems_of('small', { folder }), {
    {
      'pack.lua',
      files.line_of(text, 'format'),
      'the pack is written for format 2, and aineo reads format 1',
    },
  })
end

T['load()']['says which file is missing'] = function()
  local folder = files.write_pack(pack_root(), 'small', { ['floor.txt'] = false })

  eq(problems_of('small', { folder }), { { 'floor.txt', nil, 'the file is missing' } })
end

T['load()']['says when the pack maps no activity to standing'] = function()
  local text = files.pack_text({ states = { working = 'work' } })
  local folder = files.write_pack(pack_root(), 'small', { ['pack.lua'] = text })

  eq(problems_of('small', { folder }), {
    { 'pack.lua', files.line_of(text, 'states'), 'states must give standing an activity' },
  })
end

T['load()']['says which art file has no frame'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['art/empty.txt'] = 'colours: A = agent\n---\n',
  })

  eq(problems_of('small', { folder }), { { 'art/empty.txt', 2, 'the piece has no pixels' } })
end

--- The characters of a pack whose agent has no colours, the poses it must
--- have, and `more` poses.
---
---@param more table
---@return table characters
local function characters_with_poses(more)
  local poses = {
    standing = { art = { 'person' } },
    walking = { art = { 'person' } },
    typing = { art = { 'person' } },
  }
  return { agent = { poses = vim.tbl_extend('force', poses, more) } }
end

--- The characters of a pack whose agent has `count` poses, `p0` drawn and each
--- of the others like the one before it.
---
---@param count integer
---@return table characters
local function characters_with_a_chain_of_poses(count)
  local poses = {
    standing = { art = { 'person' } },
    walking = { art = { 'person' } },
    typing = { art = { 'person' } },
    p0 = { art = { 'person' } },
  }
  for index = 1, count - 1 do
    poses['p' .. index] = { like = 'p' .. (index - 1) }
  end
  return { agent = { colours = { '#a6e3a1' }, poses = poses } }
end

T['load()']['takes a pose like a chain of up to eight others'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({ characters = characters_with_a_chain_of_poses(9) }),
  })

  local pack = load_pack('small', { folder })

  eq(pack.agent.poses.p8, { art = { 'person' }, sitting = false })
end

T['load()']['refuses a pose like a chain of more than eight others, naming the pose'] = function()
  local text = files.pack_text({ characters = characters_with_a_chain_of_poses(10) })
  local folder = files.write_pack(pack_root(), 'small', { ['pack.lua'] = text })

  eq(problems_of('small', { folder }), {
    {
      'pack.lua',
      files.line_of(text, 'characters'),
      'characters.agent.poses.p9 is like a chain of more than 8 poses',
    },
  })
end

T['load()']['refuses a long chain of poses at once, not after minutes'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({ characters = characters_with_a_chain_of_poses(6000) }),
  })
  local started = vim.uv.hrtime()

  local told = problems_of('small', { folder })

  eq(#told > 0, true)
  eq((vim.uv.hrtime() - started) / 1e6 < 1000, true)
end

T['load()']['refuses a pose that is like itself, naming it'] = function()
  local text =
    files.pack_text({ characters = characters_with_poses({ spare = { like = 'spare' } }) })
  local folder = files.write_pack(pack_root(), 'small', { ['pack.lua'] = text })

  eq(problems_of('small', { folder }), {
    {
      'pack.lua',
      files.line_of(text, 'characters'),
      'characters.agent.poses.spare is like itself',
    },
  })
end

T['load()']['refuses poses that are like each other in a ring'] = function()
  local text = files.pack_text({
    characters = characters_with_poses({ a = { like = 'b' }, b = { like = 'a' } }),
  })
  local folder = files.write_pack(pack_root(), 'small', { ['pack.lua'] = text })

  local line = files.line_of(text, 'characters')
  eq(problems_of('small', { folder }), {
    { 'pack.lua', line, 'characters.agent.poses.a is like itself' },
    { 'pack.lua', line, 'characters.agent.poses.b is like itself' },
  })
end

T['load()']['refuses a pose like a pose left out for its own problem, naming that pose'] = function()
  local text = files.pack_text({
    characters = characters_with_poses({
      broken = { art = { 'nothing' } },
      spare = { like = 'broken' },
    }),
  })
  local folder = files.write_pack(pack_root(), 'small', { ['pack.lua'] = text })

  local line = files.line_of(text, 'characters')
  eq(problems_of('small', { folder }), {
    {
      'pack.lua',
      line,
      'characters.agent.poses.broken.art[1] names the piece “nothing”, which the pack does not have',
    },
    {
      'pack.lua',
      line,
      'characters.agent.poses.spare is like “broken”, which the pack does not describe',
    },
  })
end

T['load()']['gives an agent with no colours one grey'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({
      characters = characters_with_poses({}),
    }),
  })

  local pack = load_pack('small', { folder })

  eq(pack.agent.colours, { '#a6adc8' })
end

T['load()']['refuses a file over 256 KiB, naming it'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['floor.txt'] = ('.'):rep(256 * 1024 + 1),
  })

  eq(problems_of('small', { folder }), {
    { 'floor.txt', nil, 'the file is longer than 256 KiB' },
  })
end

T['load()']['takes a file of exactly 256 KiB'] = function()
  local rows = '\n \n ..'
  local folder = files.write_pack(pack_root(), 'small', {
    ['floor.txt'] = '#' .. ('c'):rep(256 * 1024 - 1 - #rows) .. rows,
  })

  local pack = load_pack('small', { folder })

  eq(#pack.floor.rows, 1)
end

T['load()']['says a folder named like a file is no file'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['floor.txt'] = false,
    ['floor.txt/inner'] = 'x',
  })

  eq(problems_of('small', { folder }), { { 'floor.txt', nil, 'the file is missing' } })
end

return T
