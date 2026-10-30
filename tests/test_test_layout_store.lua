local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local store = require('aineo.test_layout.store')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

--- What the store keeps of one repository in the cases.
local STORED = {
  agent = { rules = { { preset = 'python.pytest.flat' } }, framework = 'pytest' },
  user = { pairs = { ['pkg/x.py'] = 'spec/x_check.py' }, rules = {} },
}

T['read()'] = MiniTest.new_set()

T['read()']['gives back what write() kept for the same repository'] = function()
  local state = fixture.directory('test-layout-store-round')

  store.write(state, '/work/repo', STORED)

  eq(store.read(state, '/work/repo'), STORED)
end

T['read()']['gives nothing kept for another repository'] = function()
  local state = fixture.directory('test-layout-store-other')
  store.write(state, '/work/repo', STORED)

  local kept = store.read(state, '/work/other')

  eq(kept, {})
end

T['write()'] = MiniTest.new_set()

T['write()']['keeps the layout as JSON under aineo/test_layout/ in the state directory'] = function()
  local state = fixture.directory('test-layout-store-file')

  store.write(state, '/work/repo', STORED)

  local files = vim.fn.glob(vim.fs.joinpath(state, 'aineo', 'test_layout', '*.json'), true, true)
  eq(#files, 1)
  eq(vim.json.decode(table.concat(vim.fn.readfile(files[1]), '\n')).root, '/work/repo')
end

return T
