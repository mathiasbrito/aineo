local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local fixture = dofile('tests/helpers/fixture.lua')
local office_pack = require('aineo.office_pack')

--- The `aineo-office` folder of the repository, which holds the default pack.
local SHIPPED_FOLDER = vim.fn.fnamemodify('aineo-office', ':p'):gsub('/$', '')

--- The folder a user's own packs are made in, emptied.
---
---@return string
local function own_folder()
  return vim.fs.joinpath(fixture.directory('office_pack_start'), 'aineo-office')
end

--- The names of the files under `folder`, relative to it, sorted.
---
---@param folder string
---@return string[]
local function files_under(folder)
  local names = {}
  for name, type in vim.fs.dir(folder, { depth = 4 }) do
    if type == 'file' then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

--- Starts the pack `name` in `into`, with the shipped folder to copy from and
--- `more_folders` among the folders packs are found in.
---
---@param name string
---@param into string
---@param more_folders? string[]
---@return string|nil directory
---@return string|nil refusal
local function start(name, into, more_folders)
  return office_pack.start_from_default({
    name = name,
    folders = vim.list_extend({ SHIPPED_FOLDER }, more_folders or {}),
    into = into,
  })
end

local T = MiniTest.new_set()

T['starting a pack from the default'] = MiniTest.new_set()

T['starting a pack from the default']['copies every file of the default pack into a folder of the new name'] = function()
  local into = own_folder()

  local directory = start('mine', into)

  eq(directory, vim.fs.joinpath(into, 'mine'))
  eq(files_under(directory), files_under(vim.fs.joinpath(SHIPPED_FOLDER, 'default')))
end

T['starting a pack from the default']['gives the copy its own name, and no problem'] = function()
  local into = own_folder()
  start('mine', into)

  local pack, problems = office_pack.load({ name = 'mine', folders = { into } })

  eq(pack.name, 'mine')
  eq(problems, {})
  eq(office_pack.check({ name = 'mine', folders = { into } }), {})
end

T['starting a pack from the default']['copies the art as it is'] = function()
  local into = own_folder()
  local directory = start('mine', into)

  local copied = vim.fn.readfile(vim.fs.joinpath(directory, 'art', 'door.txt'))
  local shipped = vim.fn.readfile(vim.fs.joinpath(SHIPPED_FOLDER, 'default', 'art', 'door.txt'))

  eq(copied, shipped)
end

T['starting a pack from the default']['refuses a folder that exists, and leaves it as it is'] = function()
  local into = own_folder()
  local existing = vim.fs.joinpath(into, 'mine')
  vim.fn.mkdir(existing, 'p')
  vim.fn.writefile({ 'my own work' }, vim.fs.joinpath(existing, 'notes.txt'))

  local directory, refusal = start('mine', into)

  eq(directory, nil)
  eq(refusal, ('there is already a folder %s'):format(existing))
  eq(files_under(existing), { 'notes.txt' })
end

T['starting a pack from the default']['refuses a name a pack on the folders already has'] = function()
  local into = own_folder()
  local elsewhere = fixture.directory('office_pack_start_elsewhere')
  vim.fn.mkdir(vim.fs.joinpath(elsewhere, 'taken'), 'p')
  vim.fn.writefile({ 'return {}' }, vim.fs.joinpath(elsewhere, 'taken', 'pack.lua'))

  local directory, refusal = start('taken', into, { elsewhere })

  eq(directory, nil)
  eq(
    refusal,
    ('there is already a pack named “taken”, in %s'):format(vim.fs.joinpath(elsewhere, 'taken'))
  )
  eq(vim.uv.fs_stat(vim.fs.joinpath(into, 'taken')), nil)
end

T['starting a pack from the default']['refuses the name default, which every pack falls back to'] = function()
  local into = own_folder()

  local directory, refusal = start('default', into)

  eq(directory, nil)
  eq(vim.startswith(refusal, 'there is already a pack named “default”'), true)
end

T['starting a pack from the default']['refuses a name that is not letters, digits, _ and -'] = function()
  local into = own_folder()

  local directory, refusal = start('../outside', into)

  eq(directory, nil)
  eq(refusal, 'the pack name “../outside” is not letters, digits, _ and -')
  eq(vim.uv.fs_stat(vim.fs.joinpath(vim.fs.dirname(into), 'outside')), nil)
end

T['starting a pack from the default']['says so when the default pack is not among the folders'] = function()
  local into = own_folder()

  local directory, refusal = office_pack.start_from_default({
    name = 'mine',
    folders = { fixture.directory('office_pack_start_empty') },
    into = into,
  })

  eq(directory, nil)
  eq(refusal, 'the default pack is not on the folders packs are in')
end

return T
