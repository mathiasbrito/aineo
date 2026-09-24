local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')

local eq = MiniTest.expect.equality
local expect = MiniTest.expect

--- The options `setup()` recorded, read in the child from the configuration home.
local RECORDED_OPTIONS = "require('aineo.config').recorded_setup_options()"

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

T["require('aineo')"] = MiniTest.new_set()

T["require('aineo')"]['exposes setup() alone'] = function()
  eq(child.lua_get("vim.tbl_keys(require('aineo'))"), { 'setup' })
end

T['setup()'] = MiniTest.new_set()

T['setup()']['leaves no options recorded before it is called'] = function()
  eq(child.lua_get(RECORDED_OPTIONS), {})
end

T['setup()']['records its options for the configuration to resolve'] = function()
  child.lua([[require('aineo').setup({ prefix = ',', claude = { cmd = { 'my-claude' } } })]])

  eq(child.lua_get(RECORDED_OPTIONS), { prefix = ',', claude = { cmd = { 'my-claude' } } })
end

T['setup()']['replaces what an earlier call recorded, without merging'] = function()
  child.lua([[require('aineo').setup({ prefix = ',', claude = { cmd = { 'my-claude' } } })]])
  child.lua([[require('aineo').setup({ autostart = false })]])

  eq(child.lua_get(RECORDED_OPTIONS), { autostart = false })
end

T['setup()']['records empty options when called without any'] = function()
  child.lua([[require('aineo').setup({ prefix = ',' })]])
  child.lua([[require('aineo').setup()]])

  eq(child.lua_get(RECORDED_OPTIONS), {})
end

T['setup()']['records the options as they were when it was called'] = function()
  child.lua([[
    local opts = { claude = { cmd = { 'my-claude' } } }
    require('aineo').setup(opts)
    opts.claude.cmd[1] = 'changed after setup'
  ]])

  eq(child.lua_get(RECORDED_OPTIONS), { claude = { cmd = { 'my-claude' } } })
end

T['setup()']["records the options' own keys, never what their metatable reaches"] = function()
  child.lua([[
    local live = { prefix = ',' }
    require('aineo').setup(setmetatable({ autostart = false }, { __index = live }))
    live.prefix = 'changed after setup()'
  ]])

  eq(child.lua_get(RECORDED_OPTIONS .. '.prefix'), vim.NIL)
end

T['setup()']['hands out its record without a metatable'] = function()
  child.lua([[require('aineo').setup(setmetatable({ prefix = ',' }, { __index = {} }))]])

  eq(child.lua_get('getmetatable(' .. RECORDED_OPTIONS .. ')'), vim.NIL)
end

T['setup()']['keeps its record when a caller edits the options handed out'] = function()
  child.lua([[require('aineo').setup({ prefix = ',' })]])
  child.lua([[require('aineo.config').recorded_setup_options().prefix = 'changed without setup()']])

  eq(child.lua_get(RECORDED_OPTIONS), { prefix = ',' })
end

T['setup()']['refuses options that are not a table, naming them'] = function()
  expect.error(function()
    child.lua([[require('aineo').setup(',')]])
  end, 'opts: expected table, got string')
end

return T
