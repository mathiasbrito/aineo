local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')

local eq = MiniTest.expect.equality

local LOADED_AINEO_MODULES = [[vim.tbl_filter(function(name)
  return vim.startswith(name, 'aineo')
end, vim.tbl_keys(package.loaded))]]

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

T['plugin/aineo.lua'] = MiniTest.new_set()

T['plugin/aineo.lua']['is sourced at startup and loads no aineo module'] = function()
  children.restart(child)

  eq(child.lua_get('vim.g.loaded_aineo'), true)
  eq(child.lua_get(LOADED_AINEO_MODULES), {})
end

T['plugin/aineo.lua']['does nothing when vim.g.loaded_aineo is already set'] = function()
  children.restart(child, { '--cmd', "let g:loaded_aineo = 'set before startup'" })

  eq(child.lua_get('vim.g.loaded_aineo'), 'set before startup')
end

return T
