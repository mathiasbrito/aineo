--- Writes packs of the office into a directory of the test's own, and a small
--- pack that loads, for the tests of the office's homes.

local fixture = dofile('tests/helpers/fixture.lua')

local M = {}

--- The text of a `pack.lua` of the smallest pack that loads: a floor, a
--- character that can stand, walk and sit, one effect and one activity for
--- each of the states it draws. `changes` replace its top-level fields.
---
---@param changes? table
---@return string
function M.pack_text(changes)
  local pack = {
    format = 1,
    name = 'small',
    about = 'The smallest pack that loads.',
    author = 'the tests',
    colours = { wall = '#292c3c', floor = '#303446', ink = '#1e1e2e', wood = '#b4875a' },
    characters = {
      agent = {
        colours = { '#a6e3a1' },
        poses = {
          standing = { art = { 'person' } },
          walking = { art = { 'person' } },
          sitting = { art = { 'person' }, sitting = true },
          typing = { like = 'sitting', effect = 'busy_dots' },
        },
      },
    },
    effects = { busy_dots = { text = { '.', '..', '...' } } },
    floor = {
      plan = 'floor.txt',
      floor_colour = 'floor',
      wall_colour = 'wall',
      legend = { D = { piece = 'person' }, s = { spot = 'desk', sitting = true } },
    },
    activities = {
      stand = { steps = { { at = 'desk', pose = 'standing' } } },
      work = { steps = { { at = 'desk', pose = 'typing' } } },
    },
    states = { standing = 'stand', working = 'work' },
  }
  local text = {}
  for key, value in pairs(vim.tbl_extend('force', pack, changes or {})) do
    table.insert(
      text,
      ('  %s = %s,'):format(key, vim.inspect(value, { newline = ' ', indent = '' }))
    )
  end
  return 'return {\n' .. table.concat(text, '\n') .. '\n}\n'
end

--- The text of the plan of the smallest pack: a wall, a floor and a seat.
M.PLAN_TEXT = table.concat({
  '# The smallest plan.',
  ' ~~',
  ' ####',
  ' D..#',
  '~..s.',
}, '\n') .. '\n'

--- The text of an art file of one person, two pixels wide and three tall.
M.PERSON_ART_TEXT = table.concat({
  'about: A person.',
  'colours: A = agent, k = ink',
  'anchor: 1, 2',
  '---',
  'Ak',
  'AA',
  'kk',
}, '\n') .. '\n'

--- Writes the pack `name` under `root/aineo-office/`, with `files` — file
--- names relative to the pack's folder, and their text — over the smallest
--- pack's `pack.lua`, `floor.txt` and `art/person.txt`; a file given as
--- `false` is left out.
---
---@param root string a directory of the test's own
---@param name string
---@param files? table<string, string|false>
---@return string folder the `aineo-office` directory the pack is in
function M.write_pack(root, name, files)
  local folder = vim.fs.joinpath(root, 'aineo-office')
  local written = vim.tbl_extend('force', {
    ['pack.lua'] = M.pack_text({ name = name }),
    ['floor.txt'] = M.PLAN_TEXT,
    ['art/person.txt'] = M.PERSON_ART_TEXT,
  }, files or {})
  for file, text in pairs(written) do
    if text then
      local path = vim.fs.joinpath(folder, name, file)
      fixture.make_directory(vim.fs.dirname(path))
      local handle = assert(io.open(path, 'wb'))
      handle:write(text)
      handle:close()
    end
  end
  return folder
end

return M
