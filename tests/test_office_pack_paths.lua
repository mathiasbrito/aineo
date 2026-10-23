local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local bounded = dofile('tests/helpers/bounded.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local files = dofile('tests/helpers/office_pack_files.lua')
local office_pack = require('aineo.office_pack')

--- The states the tests' packs are checked against.
local STATE_NAMES = { 'standing', 'working', 'resting', 'idle' }

--- The problems of the pack `name` in `folder` as `{ file, line, message }`.
---
---@param name string
---@param folder string
---@return table[]
local function problems_of(name, folder)
  local told = {}
  for _, problem in
    ipairs(office_pack.check({ name = name, folders = { folder }, state_names = STATE_NAMES }))
  do
    table.insert(told, { problem.file, problem.line, problem.message })
  end
  return told
end

local T = MiniTest.new_set()

T['a pack’s name'] = MiniTest.new_set()

local NOT_NAMES =
  { { '../outside/evil' }, { 'a/b' }, { '.' }, { '..' }, { '' }, { 'a b' }, { 'a\1' } }

T['a pack’s name']['is letters, digits, _ and -, and nothing that leads to another folder'] =
  MiniTest.new_set({
    parametrize = NOT_NAMES,
  })

T['a pack’s name']['is letters, digits, _ and -, and nothing that leads to another folder']['name'] = function(
  name
)
  local root = fixture.directory('paths_names')
  local folder = files.write_pack(root, 'small')
  files.write_pack(vim.fs.joinpath(root, 'outside'), 'evil')

  local pack, problems = office_pack.load({
    name = name,
    folders = { folder },
    state_names = STATE_NAMES,
  })

  eq(pack, nil)
  eq(problems[1].message:find('is not letters, digits, _ and -', 1, true) ~= nil, true)
end

T['a pack’s name']['in based_on is told at its line, and the pack it names is not read'] = function()
  local root = fixture.directory('paths_based_on')
  files.write_pack(vim.fs.joinpath(root, 'q'), 'evil')
  local text = files.pack_text({ name = 'small', based_on = '../q/aineo-office/evil' })
  local folder = files.write_pack(root, 'small', { ['pack.lua'] = text })

  local pack, problems = office_pack.load({
    name = 'small',
    folders = { folder },
    state_names = STATE_NAMES,
  })

  eq(pack.name, 'small')
  eq(#problems, 2)
  eq(problems[2].message, 'the pack “../q/aineo-office/evil” it is based on cannot be used')
  eq(problems[2].line, files.line_of(text, 'based_on'))
end

T['a file of a pack'] = MiniTest.new_set()

T['a file of a pack']['the floor plan names lies in the pack’s folder'] = function()
  local root = fixture.directory('paths_plan')
  local text = files.pack_text({
    floor = { plan = '../floor_outside.txt', legend = { D = { piece = 'person' } } },
  })
  local folder = files.write_pack(root, 'small', { ['pack.lua'] = text })
  vim.fn.writefile({ ' ', ' D..' }, vim.fs.joinpath(folder, 'floor_outside.txt'))

  eq(problems_of('small', folder), {
    { '../floor_outside.txt', nil, 'the file lies outside the pack’s folder' },
  })
end

T['a file of a pack']['a link to a file of the pack’s folder is read'] = function()
  local root = fixture.directory('paths_link_inside')
  local folder = files.write_pack(root, 'small')
  local art = vim.fs.joinpath(folder, 'small', 'art')
  assert(vim.uv.fs_symlink(vim.fs.joinpath(art, 'person.txt'), vim.fs.joinpath(art, 'copy.txt')))

  local pack = office_pack.load({ name = 'small', folders = { folder }, state_names = STATE_NAMES })

  eq(pack.pieces.copy.frames, pack.pieces.person.frames)
end

T['a file of a pack']['a link to a file outside the pack’s folder is told, and not read'] = function()
  local root = fixture.directory('paths_link_outside')
  local folder = files.write_pack(root, 'small')
  local outside = vim.fs.joinpath(root, 'outside.txt')
  vim.fn.writefile({ 'colours: A = ink', '---', 'A' }, outside)
  local link = vim.fs.joinpath(folder, 'small', 'art', 'copy.txt')
  assert(vim.uv.fs_symlink(outside, link))

  local pack = office_pack.load({ name = 'small', folders = { folder }, state_names = STATE_NAMES })

  eq(problems_of('small', folder), {
    { 'art/copy.txt', nil, 'the file lies outside the pack’s folder' },
  })
  eq(pack.pieces.copy, nil)
end

T['a file of a pack']['a link that loops is told as a file that is missing'] = function()
  local root = fixture.directory('paths_link_loop')
  local folder = files.write_pack(root, 'small')
  local link = vim.fs.joinpath(folder, 'small', 'art', 'loop.txt')
  assert(vim.uv.fs_symlink(link, link))

  eq(problems_of('small', folder), { { 'art/loop.txt', nil, 'the file is missing' } })
end

T['a file of a pack']['that is a FIFO is told once and never opened'] = function()
  local directory = fixture.directory('paths_fifo')
  local source = ([[
    local files = dofile('tests/helpers/office_pack_files.lua')
    local folder = files.write_pack(%q, 'small')
    vim.system({ 'mkfifo', folder .. '/small/art/pipe.txt' }):wait()
    local problems = require('aineo.office_pack').check({
      name = 'small',
      folders = { folder },
      state_names = { 'standing', 'working', 'resting', 'idle' },
    })
    print(#problems, problems[1] and problems[1].file, problems[1] and problems[1].message)
  ]]):format(directory)

  local run = bounded.run(source, 10000)

  eq(run.finished, true)
  eq(vim.trim(run.stdout), '1\tart/pipe.txt\tthe file is not a regular file')
end

T['finding packs'] = MiniTest.new_set()

T['finding packs']['lists a pack whose folder is a link'] = function()
  local root = fixture.directory('paths_find_link')
  local folder = files.write_pack(vim.fs.joinpath(root, 'real'), 'small')
  local linked = vim.fs.joinpath(root, 'linked', 'aineo-office')
  vim.fn.mkdir(linked, 'p')
  assert(vim.uv.fs_symlink(vim.fs.joinpath(folder, 'small'), vim.fs.joinpath(linked, 'small')))

  eq(office_pack.find({ linked }), {
    { name = 'small', directory = vim.fs.joinpath(linked, 'small') },
  })
end

T['finding packs']['loads a pack whose folder is a link'] = function()
  local root = fixture.directory('paths_load_link')
  local folder = files.write_pack(vim.fs.joinpath(root, 'real'), 'small')
  local linked = vim.fs.joinpath(root, 'linked', 'aineo-office')
  vim.fn.mkdir(linked, 'p')
  assert(vim.uv.fs_symlink(vim.fs.joinpath(folder, 'small'), vim.fs.joinpath(linked, 'small')))

  local pack, problems =
    office_pack.load({ name = 'small', folders = { linked }, state_names = STATE_NAMES })

  eq(problems, {})
  eq(pack.name, 'small')
end

return T
