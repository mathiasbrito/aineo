local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

--- The `claude` the suites' init puts first on `PATH`, which refuses to run.
local GUARD_CLAUDE = vim.fs.joinpath(vim.uv.cwd(), 'tests', 'helpers', 'entry_guard', 'claude')

local child = MiniTest.new_child_neovim()

--- The runner's environment as the case found it, put back after it.
local saved_environment = {}

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      saved_environment = { PATH = vim.env.PATH, AINEO_CHILD = vim.env.AINEO_CHILD }
    end,
    post_case = function()
      vim.env.PATH = saved_environment.PATH
      vim.env.AINEO_CHILD = saved_environment.AINEO_CHILD
    end,
    post_once = child.stop,
  },
})

T['the suites'] = MiniTest.new_set()

T['the suites']['run the guard as claude'] = function()
  eq(vim.fn.exepath('claude'), GUARD_CLAUDE)
end

T['the suites']['run the guard as claude in a child whose PATH starts with another claude'] = function()
  local other = fixture.directory('entry-guard-other-claude')
  local other_claude = fixture.write('entry-guard-other-claude/claude', { '#!/bin/sh', 'exit 0' })
  vim.uv.fs_chmod(other_claude, tonumber('755', 8))
  vim.env.PATH = other .. ':' .. vim.env.PATH

  children.restart(child)

  eq(child.lua_get("vim.fn.exepath('claude')"), GUARD_CLAUDE)
end

T['the suites']['remove AINEO_CHILD from a child'] = function()
  vim.env.AINEO_CHILD = '1'

  children.restart(child)

  eq(child.lua_get('vim.env.AINEO_CHILD'), vim.NIL)
end

return T
