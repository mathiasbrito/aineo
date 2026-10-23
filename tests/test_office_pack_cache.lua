local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local fixture = dofile('tests/helpers/fixture.lua')
local files = dofile('tests/helpers/office_pack_files.lua')
local office_pack = require('aineo.office_pack')

--- The states the tests' packs are checked against.
local STATE_NAMES = { 'standing', 'working', 'resting', 'idle' }

--- Loads the pack `small` from `folder`, with `more` over the options.
---
---@param folder string
---@param more? table
---@return aineo.office_pack.Pack|nil pack
---@return aineo.office_pack.Problem[] problems
local function load_pack(folder, more)
  return office_pack.load(
    vim.tbl_extend(
      'force',
      { name = 'small', folders = { folder }, state_names = STATE_NAMES },
      more or {}
    )
  )
end

--- Makes every file under `folder` unreadable, so that a load that reads
--- one of them tells it.
---
---@param folder string
local function make_unreadable(folder)
  for path, type in vim.fs.dir(folder, { depth = 4 }) do
    if type == 'file' then
      assert(vim.uv.fs_chmod(vim.fs.joinpath(folder, path), tonumber('000', 8)))
    end
  end
end

local T = MiniTest.new_set()

T['loading a pack again'] = MiniTest.new_set()

T['loading a pack again']['reads no file when none has changed, and gives what the first load gave'] = function()
  local folder = files.write_pack(fixture.directory('cache_same'), 'small')
  local first, first_problems = load_pack(folder)
  make_unreadable(folder)

  local second, second_problems = load_pack(folder)

  eq(second_problems, first_problems)
  eq(second, first)
end

T['loading a pack again']['reads the pack again when a file has a size it had not'] = function()
  local folder = files.write_pack(fixture.directory('cache_size'), 'small')
  load_pack(folder)
  local art = vim.fs.joinpath(folder, 'small', 'art', 'person.txt')
  vim.fn.writefile({ 'colours: A = agent, k = ink', '---', 'Ak', 'AA', 'kk', 'kk' }, art)

  local pack = load_pack(folder)

  eq(#pack.pieces.person.frames[1], 4)
end

T['loading a pack again']['reads the pack again when a file has only a time it had not'] = function()
  local folder = files.write_pack(fixture.directory('cache_time'), 'small')
  load_pack(folder)
  local art = vim.fs.joinpath(folder, 'small', 'art', 'person.txt')
  local stat = assert(vim.uv.fs_stat(art))
  make_unreadable(folder)

  assert(vim.uv.fs_utime(art, stat.atime.sec, stat.mtime.sec + 10))
  local _, problems = load_pack(folder)

  eq(#problems > 0, true)
end

T['loading a pack again']['sees an art file that was added, and one that was taken away'] = function()
  local folder = files.write_pack(fixture.directory('cache_files'), 'small')
  load_pack(folder)
  local extra = vim.fs.joinpath(folder, 'small', 'art', 'extra.txt')
  vim.fn.writefile({ 'colours: A = ink', '---', 'A' }, extra)

  local added = load_pack(folder)
  vim.fn.delete(extra)
  local removed = load_pack(folder)

  eq({ added.pieces.extra ~= nil, removed.pieces.extra }, { true, nil })
end

T['loading a pack again']['sees a pack that appeared in an earlier folder'] = function()
  local root = fixture.directory('cache_folders')
  local second = files.write_pack(vim.fs.joinpath(root, 'two'), 'small')
  local first_folder = vim.fs.joinpath(root, 'one', 'aineo-office')
  vim.fn.mkdir(first_folder, 'p')
  local before = office_pack.load({
    name = 'small',
    folders = { first_folder, second },
    state_names = STATE_NAMES,
  })
  files.write_pack(vim.fs.joinpath(root, 'one'), 'small', {
    ['pack.lua'] = files.pack_text({ about = 'the first folder’s' }),
  })

  local after = office_pack.load({
    name = 'small',
    folders = { first_folder, second },
    state_names = STATE_NAMES,
  })

  eq({ before.about, after.about }, { 'The smallest pack that loads.', 'the first folder’s' })
end

T['loading a pack again']['gives a pack that what a caller does to the text colours does not reach'] = function()
  local folder = files.write_pack(fixture.directory('cache_copy'), 'small')
  local first = load_pack(folder)
  first.text_colours.status = '#000000'
  first.effects.busy_dots.colour = '#000000'

  local second = load_pack(folder)

  eq(second.text_colours.status, 'Normal')
  eq(second.effects.busy_dots.colour, 'status')
end

T['loading a pack again']['with other options is another load'] = function()
  local root = fixture.directory('cache_options')
  local folder = files.write_pack(root, 'small')
  local mine = vim.fs.joinpath(root, 'mine.txt')
  vim.fn.writefile({ 'colours: A = wood', '---', 'AAA' }, mine)
  local plain = load_pack(folder)

  local replaced = load_pack(folder, { replaced_pieces = { person = mine } })

  eq({ #plain.pieces.person.frames[1], #replaced.pieces.person.frames[1] }, { 3, 1 })
end

return T
