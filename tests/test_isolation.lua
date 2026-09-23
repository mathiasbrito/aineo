local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')

local TEST_HOME = vim.fs.joinpath(vim.uv.cwd(), '.tests')

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

return T
