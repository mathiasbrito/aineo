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
  children.restart(child, { '-c', 'lua _G.loaded_before_vim_enter = ' .. LOADED_AINEO_MODULES })

  eq(child.lua_get('vim.g.loaded_aineo'), true)
  eq(child.lua_get('_G.loaded_before_vim_enter'), {})
end

T['plugin/aineo.lua']['loads the configuration alone in a headless start'] = function()
  children.restart(child)

  eq(child.lua_get(LOADED_AINEO_MODULES), { 'aineo.config' })
end

--- What a Neovim has defined: the names of its user commands, the left-hand
--- sides of its Normal-mode mappings, and its autocommands as `<group> <event>`,
--- each list sorted.
local DEFINITIONS = [[(function()
  local commands = vim.tbl_keys(vim.api.nvim_get_commands({}))
  local keymaps = vim.tbl_map(function(keymap)
    return keymap.lhs
  end, vim.api.nvim_get_keymap('n'))
  local autocmds = vim.tbl_map(function(autocmd)
    return (autocmd.group_name or '') .. ' ' .. autocmd.event
  end, vim.api.nvim_get_autocmds({}))
  table.sort(commands)
  table.sort(keymaps)
  table.sort(autocmds)
  return { commands = commands, keymaps = keymaps, autocmds = autocmds }
end)()]]

--- `definitions` without what `before` holds already, kind by kind.
---
---@param definitions { commands: string[], keymaps: string[], autocmds: string[] }
---@param before { commands: string[], keymaps: string[], autocmds: string[] }
---@return { commands: string[], keymaps: string[], autocmds: string[] }
local function added(definitions, before)
  return vim.tbl_map(function(kind)
    return vim.tbl_filter(function(definition)
      return not vim.tbl_contains(before[kind], definition)
    end, definitions[kind])
  end, { commands = 'commands', keymaps = 'keymaps', autocmds = 'autocmds' })
end

T['plugin/aineo.lua']['defines :Aineo, its <Plug> mappings and the prefix mappings, and no autocommand once started'] = function()
  children.restart(child, { '--cmd', 'let g:loaded_aineo = 1' })
  local without_the_file = child.lua_get(DEFINITIONS)

  children.restart(child)

  eq(added(child.lua_get(DEFINITIONS), without_the_file), {
    commands = { 'Aineo' },
    keymaps = {
      '<Plug>(aineo-claude)',
      '<Plug>(aineo-input)',
      '<Plug>(aineo-open)',
      '<Plug>(aineo-report)',
      '<Plug>(aineo-send)',
      '\\c',
      '\\i',
      '\\o',
      '\\r',
      '\\s',
    },
    autocmds = {},
  })
end

T['plugin/aineo.lua']['does nothing when vim.g.loaded_aineo is already set'] = function()
  children.restart(child, { '--cmd', "let g:loaded_aineo = 'set before startup'" })

  eq(child.lua_get('vim.g.loaded_aineo'), 'set before startup')
  eq(child.lua_get(LOADED_AINEO_MODULES), {})
end

return T
