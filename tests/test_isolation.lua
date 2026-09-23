local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local make = dofile('tests/helpers/make.lua')

local eq = MiniTest.expect.equality

local TEST_HOME = vim.fs.joinpath(vim.uv.cwd(), '.tests')

--- The expression, run in a Neovim, that lists the names of its Claude Code
--- variables other than `CLAUDE_CONFIG_DIR`.
local OTHER_CLAUDE_VARIABLES = "vim.tbl_filter(function(name) return vim.startswith(name, 'CLAUDE')"
  .. " and name ~= 'CLAUDE_CONFIG_DIR' end, vim.tbl_keys(vim.fn.environ()))"

--- A test file whose cases pass only in a runner isolated inside `.tests/`,
--- whose child Neovims are isolated too.
local ISOLATION_PROBE_FILE = {
  "local MiniTest = require('mini.test')",
  'local eq = MiniTest.expect.equality',
  ('local HOME = %q'):format(TEST_HOME),
  ('local children = dofile(%q)'):format(
    vim.fs.joinpath(vim.uv.cwd(), 'tests', 'helpers', 'child.lua')
  ),
  'local child = MiniTest.new_child_neovim()',
  'local T = MiniTest.new_set()',
  ('T["no other Claude Code variable"] = function() eq(%s, {}) end'):format(OTHER_CLAUDE_VARIABLES),
  'T["no other Claude Code variable in a child"] = function()',
  '  children.restart(child)',
  ('  eq(child.lua_get(%q), {})'):format(OTHER_CLAUDE_VARIABLES),
  '  child.stop()',
  'end',
  "T['config'] = function() eq(vim.fn.stdpath('config'), HOME .. '/config/nvim') end",
  "T['data'] = function() eq(vim.fn.stdpath('data'), HOME .. '/data/nvim') end",
  "T['state'] = function() eq(vim.fn.stdpath('state'), HOME .. '/state/nvim') end",
  "T['cache'] = function() eq(vim.fn.stdpath('cache'), HOME .. '/cache/nvim') end",
  "T['claude'] = function() eq(vim.env.CLAUDE_CONFIG_DIR, HOME .. '/claude') end",
  "T['log'] = function() eq(vim.env.NVIM_LOG_FILE, HOME .. '/state/nvim/log') end",
  'return T',
}

local PINNED_MINI_TEST =
  vim.fs.joinpath(vim.uv.cwd(), 'deps', 'mini.nvim', 'lua', 'mini', 'test.lua')

--- A test file whose case passes only when mini.test was loaded from the pin.
local PINNED_MINI_TEST_PROBE_FILE = {
  "local MiniTest = require('mini.test')",
  'local T = MiniTest.new_set()',
  "T['runs the pinned mini.test'] = function()",
  ("  MiniTest.expect.equality(debug.getinfo(MiniTest.collect, 'S').source, %q)"):format(
    '@' .. PINNED_MINI_TEST
  ),
  'end',
  'return T',
}

--- `make test_file` on the isolation probe, started as `run` says.
---
---@param run aineo_tests.MakeRun
---@return vim.SystemCompleted
local function probe_isolation(run)
  local path = fixture.write('isolation_probe.lua', ISOLATION_PROBE_FILE)
  return make.run(
    'test_file',
    vim.tbl_extend('force', run, {
      assignments = vim.list_extend({ 'FILE=' .. path }, run.assignments or {}),
    })
  )
end

--- The developer's own Neovim configuration, where Neovim looks without XDG_CONFIG_HOME.
local DEVELOPER_CONFIG = vim.fs.joinpath(vim.uv.os_homedir(), '.config', 'nvim')

--- Whether `path` is `directory` or lies inside it.
---
---@param path string
---@param directory string
---@return boolean
local function is_within(path, directory)
  return path == directory or vim.startswith(path, directory .. '/')
end

--- Expects `path` to lie inside `directory`.
local expect_inside = MiniTest.new_expectation('path inside directory', function(path, directory)
  return type(path) == 'string' and vim.startswith(path, directory .. '/')
end, function(path, directory)
  return ('Path:      %s\nDirectory: %s'):format(vim.inspect(path), directory)
end)

--- Expects no path of `paths` to be `directory` or to lie inside it.
local expect_none_within = MiniTest.new_expectation(
  'no path within directory',
  function(paths, directory)
    return #vim.tbl_filter(function(path)
      return is_within(path, directory)
    end, paths) == 0
  end,
  function(paths, directory)
    return ('Paths:     %s\nDirectory: %s'):format(vim.inspect(paths), directory)
  end
)

local T = MiniTest.new_set()

T['the runner'] = MiniTest.new_set()

T['the runner']['resolves each user directory inside .tests/'] = MiniTest.new_set({
  parametrize = { { 'config' }, { 'data' }, { 'state' }, { 'cache' } },
})

T['the runner']['resolves each user directory inside .tests/']['stdpath'] = function(kind)
  expect_inside(vim.fn.stdpath(kind), TEST_HOME)
end

T['the runner']['points Claude Code at a configuration inside .tests/'] = function()
  expect_inside(vim.env.CLAUDE_CONFIG_DIR, TEST_HOME)
end

T['the runner']["has no part of the developer's configuration on 'runtimepath'"] = function()
  expect_none_within(vim.opt.runtimepath:get(), DEVELOPER_CONFIG)
end

local child = MiniTest.new_child_neovim()

T['a child'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

T['a child']['resolves each user directory inside .tests/'] = MiniTest.new_set({
  parametrize = { { 'config' }, { 'data' }, { 'state' }, { 'cache' } },
})

T['a child']['resolves each user directory inside .tests/']['stdpath'] = function(kind)
  expect_inside(child.fn.stdpath(kind), TEST_HOME)
end

T['a child']['points Claude Code at a configuration inside .tests/'] = function()
  expect_inside(child.lua_get('vim.env.CLAUDE_CONFIG_DIR'), TEST_HOME)
end

T['a child']["has no part of the developer's configuration on 'runtimepath'"] = function()
  expect_none_within(child.lua_get('vim.opt.runtimepath:get()'), DEVELOPER_CONFIG)
end

T['make test_file'] = MiniTest.new_set()

T['make test_file']['isolates its runner from the user directories in its environment'] = function()
  local decoy = fixture.directory('decoy')

  local result = probe_isolation({
    environment = {
      XDG_CONFIG_HOME = vim.fs.joinpath(decoy, 'config'),
      XDG_DATA_HOME = vim.fs.joinpath(decoy, 'data'),
      XDG_STATE_HOME = vim.fs.joinpath(decoy, 'state'),
      XDG_CACHE_HOME = vim.fs.joinpath(decoy, 'cache'),
      CLAUDE_CONFIG_DIR = vim.fs.joinpath(decoy, 'claude'),
    },
  })

  eq(result.code, 0)
end

T['make test_file']['keeps its isolation when the command line names other directories'] = function()
  local decoy = fixture.directory('decoy')

  local result = probe_isolation({
    assignments = {
      'XDG_CONFIG_HOME=' .. vim.fs.joinpath(decoy, 'config'),
      'XDG_DATA_HOME=' .. vim.fs.joinpath(decoy, 'data'),
      'XDG_STATE_HOME=' .. vim.fs.joinpath(decoy, 'state'),
      'XDG_CACHE_HOME=' .. vim.fs.joinpath(decoy, 'cache'),
      'CLAUDE_CONFIG_DIR=' .. vim.fs.joinpath(decoy, 'claude'),
      'NVIM_LOG_FILE=' .. vim.fs.joinpath(decoy, 'log'),
    },
  })

  eq(result.code, 0)
end

T['make test_file']["keeps a Claude Code session's variables out of its runner and children"] = function()
  local result = probe_isolation({
    environment = { CLAUDECODE = '1', CLAUDE_CODE_PLANTED_BY_A_TEST = '1' },
  })

  eq(result.code, 0)
end

T['make test_file']['runs the pinned mini.test over a copy in a system site directory'] = function()
  local system_data = fixture.directory('system_data')
  local site_lua = vim.fs.joinpath(system_data, 'nvim', 'site', 'lua', 'mini')
  vim.fn.mkdir(site_lua, 'p')
  assert(vim.uv.fs_copyfile(PINNED_MINI_TEST, vim.fs.joinpath(site_lua, 'test.lua')))
  local path = fixture.write('pinned_mini_test_probe.lua', PINNED_MINI_TEST_PROBE_FILE)

  local result = make.run('test_file', {
    assignments = { 'FILE=' .. path },
    environment = { XDG_DATA_DIRS = system_data },
  })

  eq(result.code, 0)
end

T['make test_file']['keeps the log a parent Neovim hands down out of its runner'] = function()
  local decoy = fixture.directory('decoy')

  local result = probe_isolation({
    environment = { NVIM_LOG_FILE = vim.fs.joinpath(decoy, 'log') },
  })

  eq(result.code, 0)
end

return T
