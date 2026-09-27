local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- Enough bytes to read a line of a fixture whole.
local LINE_READ_BYTES = 64

local T = MiniTest.new_set()

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

return T
