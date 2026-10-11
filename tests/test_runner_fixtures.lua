local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local make = dofile('tests/helpers/make.lua')

local eq = MiniTest.expect.equality
local expect = MiniTest.expect

--- Enough bytes to read a line of a fixture whole.
local LINE_READ_BYTES = 64

--- Makes `vim.fn.mkdir()` lose `races` races in a row until the case ends, as
--- this Neovim does when another test file's Neovim makes a directory of the
--- same path at the same moment: each of those calls makes the directory, as
--- the other Neovim did, then fails with E739 as `mkdir()` does then. The
--- calls after them are `mkdir()`'s own.
---
---@param races integer
local function lose_races_to_make_directories(races)
  local make_directory = vim.fn.mkdir
  MiniTest.finally(function()
    vim.fn.mkdir = make_directory
  end)
  vim.fn.mkdir = function(directory, ...)
    if races == 0 then
      return make_directory(directory, ...)
    end
    races = races - 1
    make_directory(directory, ...)
    error('Vim:E739: Cannot create directory ' .. directory .. ': file already exists', 0)
  end
end

local T = MiniTest.new_set()

T['fixture.directory'] = MiniTest.new_set()

T['fixture.directory']['makes its directory although another Neovim made it first'] = function()
  lose_races_to_make_directories(1)

  local path
  expect.no_error(function()
    path = fixture.directory('made_by_another_first')
  end)

  eq(vim.fn.isdirectory(path), 1)
end

T['fixture.directory']['makes its directory after losing two races in a row'] = function()
  lose_races_to_make_directories(2)

  local path
  expect.no_error(function()
    path = fixture.directory('two_races_lost')
  end)

  eq(vim.fn.isdirectory(path), 1)
end

T['fixture.directory']['raises when a file stands where a directory of its path would be'] = function()
  fixture.write('file_in_the_way', { 'a file, not a directory' })

  expect.error(function()
    fixture.directory('file_in_the_way/leaf')
  end, 'E739')
end

T['fixture.write'] = MiniTest.new_set()

T['fixture.write']['replaces a file whole, leaving a reader of the old one its content'] = function()
  local path = fixture.write('replaced_whole/file.txt', { 'old' })
  local reader = assert(vim.uv.fs_open(path, 'r', 0))
  MiniTest.finally(function()
    vim.uv.fs_close(reader)
  end)

  fixture.write('replaced_whole/file.txt', { 'new' })

  eq(vim.uv.fs_read(reader, LINE_READ_BYTES, 0), 'old\n')
end

T['fixture.write']['writes its file although another Neovim made its directory first'] = function()
  lose_races_to_make_directories(1)

  local path
  expect.no_error(function()
    path = fixture.write('directory_made_by_another/file.txt', { 'written' })
  end)

  eq(vim.fn.readfile(path), { 'written' })
end

T['make.run'] = MiniTest.new_set()

T['make.run']['runs its target although another Neovim made its empty directory first'] = function()
  local makefile = fixture.write('make_run_race/Makefile', { 'succeeds:', '\t@true' })
  lose_races_to_make_directories(1)

  local result
  expect.no_error(function()
    result = make.run('succeeds', { makefile = makefile })
  end)

  eq(result.code, 0)
end

return T
