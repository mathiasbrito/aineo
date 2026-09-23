local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')

local eq = MiniTest.expect.equality
local expect = MiniTest.expect

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

T['setup_options()'] = MiniTest.new_set()

T['setup_options()']['is empty before setup() is called'] = function()
  eq(child.lua_get("require('aineo').setup_options()"), {})
end

T['setup()'] = MiniTest.new_set()

T['setup()']['records its options for the configuration to resolve'] = function()
  child.lua([[require('aineo').setup({ prefix = ',', claude = { cmd = { 'my-claude' } } })]])

  eq(
    child.lua_get("require('aineo').setup_options()"),
    { prefix = ',', claude = { cmd = { 'my-claude' } } }
  )
end

T['setup()']['replaces what an earlier call recorded, without merging'] = function()
  child.lua([[require('aineo').setup({ prefix = ',', claude = { cmd = { 'my-claude' } } })]])
  child.lua([[require('aineo').setup({ autostart = false })]])

  eq(child.lua_get("require('aineo').setup_options()"), { autostart = false })
end

T['setup()']['records empty options when called without any'] = function()
  child.lua([[require('aineo').setup({ prefix = ',' })]])
  child.lua([[require('aineo').setup()]])

  eq(child.lua_get("require('aineo').setup_options()"), {})
end

T['setup()']['records the options as they were when it was called'] = function()
  child.lua([[
    local opts = { claude = { cmd = { 'my-claude' } } }
    require('aineo').setup(opts)
    opts.claude.cmd[1] = 'changed after setup'
  ]])

  eq(child.lua_get("require('aineo').setup_options()"), { claude = { cmd = { 'my-claude' } } })
end

T['setup()']['refuses options that are not a table, naming them'] = function()
  expect.error(function()
    child.lua([[require('aineo').setup(',')]])
  end, 'opts: expected table, got string')
end

return T
