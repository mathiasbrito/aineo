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
---@return string|nil problem
local function load_pack(name, folders)
  return office_pack.load({ name = name, folders = folders })
end

local T = MiniTest.new_set({
  hooks = {
    post_once = function()
      vim.fn.delete(pack_root(), 'rf')
    end,
  },
})

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
      'anchor: 1, 2',
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
    colours = { A = 'agent', k = 'ink' },
    anchor = { column = 1, row = 2 },
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

T['load()']['gives no pieces to a pack without art files'] = function()
  local folder = files.write_pack(pack_root(), 'small', { ['art/person.txt'] = false })

  local pack = load_pack('small', { folder })

  eq(pack.pieces, {})
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
  eq(pack.floor.legend, { D = { piece = 'person' }, s = { spot = 'desk', sitting = true } })
end

T['load()']['gives the poses of the agent, a pose taking what it is like from the pose it names'] = function()
  local folder = files.write_pack(pack_root(), 'small')

  local pack = load_pack('small', { folder })

  eq(pack.agent.poses.typing, { art = { 'person' }, sitting = true, effect = 'busy_dots' })
  eq(pack.agent.poses.standing, { art = { 'person' } })
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
  eq(pack.text_colours.status, '#cdd6f4')
end

T['load()']['gives each state the activity of the first state it falls back through that the pack maps'] = function()
  local folder = files.write_pack(pack_root(), 'small')

  local pack = load_pack('small', { folder })

  eq(pack.state_activity.standing, 'stand')
  eq(pack.state_activity.working, 'work')
  eq(pack.state_activity.resting, 'stand')
  eq(pack.state_activity.idle, 'stand')
  eq(pack.state_activity.reading, 'work')
  eq(pack.state_activity.asleep, 'stand')
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

  eq(pack.activities.work, { steps = { { at = 'desk', pose = 'typing' } } })
end

T['load()']['finds the pack in the first folder that holds it'] = function()
  local first = files.write_pack(fixture.directory('office_pack/first'), 'other')
  local second = files.write_pack(fixture.directory('office_pack/second'), 'small')

  local pack = load_pack('small', { first, second })

  eq(pack.name, 'small')
end

T['load()']['says which pack was not found and where it looked'] = function()
  local folder = files.write_pack(pack_root(), 'small')

  local pack, problem = load_pack('missing', { folder })

  eq(pack, nil)
  eq(problem, ('there is no pack “missing” in %s'):format(folder))
end

T['load()']['says there is no pack when it is given no folder'] = function()
  local pack, problem = load_pack('small', {})

  eq(pack, nil)
  eq(problem, 'there is no pack “small” in any folder')
end

T['load()']['says which line of pack.lua is not data'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = 'return {\n  format = 1,\n  name = os.getenv("HOME"),\n}\n',
  })

  local pack, problem = load_pack('small', { folder })

  eq(pack, nil)
  eq(problem, 'pack.lua, line 3: `os` is not data')
end

T['load()']['refuses a pack written for another format'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({ format = 2 }),
  })

  local pack, problem = load_pack('small', { folder })

  eq(pack, nil)
  eq(problem, 'pack.lua: the pack is written for format 2, and aineo reads format 1')
end

T['load()']['says which file is missing'] = function()
  local folder = files.write_pack(pack_root(), 'small', { ['floor.txt'] = false })

  local pack, problem = load_pack('small', { folder })

  eq(pack, nil)
  eq(vim.startswith(problem, 'floor.txt: '), true)
end

T['load()']['says when the pack maps no activity to standing'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({ states = { working = 'work' } }),
  })

  local pack, problem = load_pack('small', { folder })

  eq(pack, nil)
  eq(problem, 'pack.lua: states must give standing an activity')
end

T['load()']['says which art file has no frame'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['art/empty.txt'] = 'colours: A = agent\n---\n',
  })

  local pack, problem = load_pack('small', { folder })

  eq(pack, nil)
  eq(problem, 'art/empty.txt: the piece has no pixels')
end

--- The characters of a pack whose agent has `count` poses, `p0` drawn and each
--- of the others like the one before it.
---
---@param count integer
---@return table characters
local function characters_with_a_chain_of_poses(count)
  local poses = { p0 = { art = { 'person' } } }
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

  eq(pack.agent.poses.p8, { art = { 'person' } })
end

T['load()']['refuses a pose like a chain of more than eight others, naming the pose'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({ characters = characters_with_a_chain_of_poses(10) }),
  })

  local pack, problem = load_pack('small', { folder })

  eq(pack, nil)
  eq(problem, 'pack.lua: the pose “p9” is like a chain of more than 8 poses')
end

T['load()']['refuses a long chain of poses at once, not after minutes'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({ characters = characters_with_a_chain_of_poses(6000) }),
  })
  local started = vim.uv.hrtime()

  local pack = load_pack('small', { folder })

  eq(pack, nil)
  eq((vim.uv.hrtime() - started) / 1e6 < 1000, true)
end

T['load()']['refuses a pose that is like itself, naming it'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({
      characters = { agent = { poses = { standing = { like = 'standing' } } } },
    }),
  })

  local pack, problem = load_pack('small', { folder })

  eq(pack, nil)
  eq(problem, 'pack.lua: the pose “standing” is like itself')
end

T['load()']['refuses poses that are like each other in a ring'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({
      characters = { agent = { poses = { a = { like = 'b' }, b = { like = 'a' } } } },
    }),
  })

  local pack, problem = load_pack('small', { folder })

  eq(pack, nil)
  eq(vim.endswith(problem, 'is like itself'), true)
end

T['load()']['refuses a pose like a pose the pack does not describe, naming that pose'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({
      characters = { agent = { poses = { standing = { like = 'floating' } } } },
    }),
  })

  local raised, pack, problem = pcall(load_pack, 'small', { folder })

  eq(raised, true)
  eq(pack, nil)
  eq(problem, 'pack.lua: the pose “floating” is not described')
end

T['load()']['gives an agent with no colours one grey'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({
      characters = { agent = { poses = { standing = { art = { 'person' } } } } },
    }),
  })

  local pack = load_pack('small', { folder })

  eq(pack.agent.colours, { '#a6adc8' })
end

T['load()']['refuses a file over 256 KiB, naming it'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['floor.txt'] = ('.'):rep(256 * 1024 + 1),
  })

  local pack, problem = load_pack('small', { folder })

  eq(pack, nil)
  eq(problem, 'floor.txt: the file is longer than 256 KiB')
end

T['load()']['takes a file of exactly 256 KiB'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['floor.txt'] = ' \n ' .. ('.'):rep(256 * 1024 - 3),
  })

  local pack = load_pack('small', { folder })

  eq(#pack.floor.rows, 1)
end

T['load()']['says a folder named like a file is no file'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['floor.txt'] = false,
    ['floor.txt/inner'] = 'x',
  })

  local raised, pack, problem = pcall(load_pack, 'small', { folder })

  eq(raised, true)
  eq(pack, nil)
  eq(problem, 'floor.txt: the file is missing')
end

return T
