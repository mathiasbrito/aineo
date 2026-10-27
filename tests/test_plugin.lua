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

--- The names of the modules a Neovim has loaded, sorted.
local LOADED_MODULES = [[(function()
  local names = vim.tbl_keys(package.loaded)
  table.sort(names)
  return names
end)()]]

T['plugin/aineo.lua']['loads no module as it is sourced that Neovim has not loaded without it'] = function()
  local before_vim_enter = { '-c', 'lua _G.loaded_before_vim_enter = ' .. LOADED_MODULES }
  children.restart(child, vim.list_extend({ '--cmd', 'let g:loaded_aineo = 1' }, before_vim_enter))
  local without_the_file = child.lua_get('_G.loaded_before_vim_enter')

  children.restart(child, before_vim_enter)

  eq(child.lua_get('_G.loaded_before_vim_enter'), without_the_file)
end

T['plugin/aineo.lua']['loads the configuration and the table of keys alone in a headless start'] = function()
  children.restart(child, { '--cmd', 'lua vim.g.aineo = {}' })

  eq(child.lua_get('vim.fn.sort(' .. LOADED_AINEO_MODULES .. ')'), { 'aineo.config', 'aineo.keys' })
end

--- What a Neovim has defined: the names of its user commands, its mappings
--- in every mode as `<mode> <lhs>`, and its autocommands as
--- `<group> <event>`, each list sorted.
local DEFINITIONS = [[(function()
  local commands = vim.tbl_keys(vim.api.nvim_get_commands({}))
  local keymaps = {}
  for _, mode in ipairs({ 'n', 'x', 's', 'o', 'i', 'c', 't', 'l' }) do
    for _, keymap in ipairs(vim.api.nvim_get_keymap(mode)) do
      table.insert(keymaps, mode .. ' ' .. keymap.lhs)
    end
  end
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

T['plugin/aineo.lua']['defines :Aineo, their <Plug> mappings, the prefix mappings, their twins in Insert and Terminal mode and, once started, the StdinReadPost autocommand alone'] = function()
  children.restart(child, { '--cmd', 'let g:loaded_aineo = 1' })
  local without_the_file = child.lua_get(DEFINITIONS)

  children.restart(child)

  eq(added(child.lua_get(DEFINITIONS), without_the_file), {
    commands = { 'Aineo' },
    keymaps = {
      'i <C-Bslash>1',
      'i <C-Bslash>2',
      'i <C-Bslash>3',
      'i <C-Bslash>4',
      'i <C-Bslash>5',
      'i <C-Bslash>6',
      'i <C-Bslash>7',
      'i <C-Bslash>8',
      'i <C-Bslash>9',
      'i <C-Bslash>N',
      'i <C-Bslash>O',
      'i <C-Bslash>Q',
      'i <C-Bslash>S',
      'i <C-Bslash>T',
      'i <C-Bslash>X',
      'i <C-Bslash>Z',
      'i <C-Bslash>c',
      'i <C-Bslash>d',
      'i <C-Bslash>e',
      'i <C-Bslash>f',
      'i <C-Bslash>g',
      'i <C-Bslash>i',
      'i <C-Bslash>o',
      'i <C-Bslash>pa',
      'i <C-Bslash>pt',
      'i <C-Bslash>r',
      'i <C-Bslash>tcn',
      'i <C-Bslash>x',
      'i <C-Bslash>z',
      'n <Plug>(aineo-cheatsheet)',
      'n <Plug>(aineo-claim)',
      'n <Plug>(aineo-claude)',
      'n <Plug>(aineo-claude-numbers)',
      'n <Plug>(aineo-diff-close)',
      'n <Plug>(aineo-explain)',
      'n <Plug>(aineo-explain-clean)',
      'n <Plug>(aineo-explain-deep)',
      'n <Plug>(aineo-explain-deep-issues)',
      'n <Plug>(aineo-explain-fix)',
      'n <Plug>(aineo-explain-fix-steered)',
      'n <Plug>(aineo-explain-issues)',
      'n <Plug>(aineo-explain-issues-tools)',
      'n <Plug>(aineo-explain-mark)',
      'n <Plug>(aineo-explain-next)',
      'n <Plug>(aineo-explain-previous)',
      'n <Plug>(aineo-explain-tools)',
      'n <Plug>(aineo-find)',
      'n <Plug>(aineo-fix-accept)',
      'n <Plug>(aineo-fix-diff)',
      'n <Plug>(aineo-fix-reject)',
      'n <Plug>(aineo-input)',
      'n <Plug>(aineo-new)',
      'n <Plug>(aineo-office)',
      'n <Plug>(aineo-open)',
      'n <Plug>(aineo-pane-agent)',
      'n <Plug>(aineo-pane-changes)',
      'n <Plug>(aineo-pane-explorer)',
      'n <Plug>(aineo-pane-run)',
      'n <Plug>(aineo-pane-terminal)',
      'n <Plug>(aineo-report)',
      'n <Plug>(aineo-run-shell)',
      'n <Plug>(aineo-send)',
      'n <Plug>(aineo-sessions)',
      'n <Plug>(aineo-tab-1)',
      'n <Plug>(aineo-tab-2)',
      'n <Plug>(aineo-tab-3)',
      'n <Plug>(aineo-tab-4)',
      'n <Plug>(aineo-tab-5)',
      'n <Plug>(aineo-tab-6)',
      'n <Plug>(aineo-tab-7)',
      'n <Plug>(aineo-tab-8)',
      'n <Plug>(aineo-tab-9)',
      'n <Plug>(aineo-tab-close)',
      'n <Plug>(aineo-tab-new)',
      'n <Plug>(aineo-write)',
      'n <Plug>(aineo-write-deep)',
      'n <Plug>(aineo-zoom)',
      'n <Plug>(aineo-zoom-full)',
      'n \\1',
      'n \\2',
      'n \\3',
      'n \\4',
      'n \\5',
      'n \\6',
      'n \\7',
      'n \\8',
      'n \\9',
      'n \\?',
      'n \\N',
      'n \\O',
      'n \\Q',
      'n \\S',
      'n \\T',
      'n \\V',
      'n \\VI',
      'n \\VV',
      'n \\VVI',
      'n \\VVf',
      'n \\Vf',
      'n \\W',
      'n \\X',
      'n \\Z',
      'n \\c',
      'n \\d',
      'n \\e',
      'n \\f',
      'n \\g',
      'n \\i',
      'n \\o',
      'n \\pa',
      'n \\pt',
      'n \\r',
      'n \\s',
      'n \\tcn',
      'n \\v',
      'n \\vc',
      'n \\vi',
      'n \\vm',
      'n \\w',
      'n \\x',
      'n \\z',
      'o <Plug>(aineo-explain-next)',
      'o <Plug>(aineo-explain-previous)',
      't <C-Bslash>1',
      't <C-Bslash>2',
      't <C-Bslash>3',
      't <C-Bslash>4',
      't <C-Bslash>5',
      't <C-Bslash>6',
      't <C-Bslash>7',
      't <C-Bslash>8',
      't <C-Bslash>9',
      't <C-Bslash>N',
      't <C-Bslash>O',
      't <C-Bslash>Q',
      't <C-Bslash>S',
      't <C-Bslash>T',
      't <C-Bslash>X',
      't <C-Bslash>Z',
      't <C-Bslash>c',
      't <C-Bslash>d',
      't <C-Bslash>e',
      't <C-Bslash>f',
      't <C-Bslash>g',
      't <C-Bslash>i',
      't <C-Bslash>o',
      't <C-Bslash>pa',
      't <C-Bslash>pt',
      't <C-Bslash>r',
      't <C-Bslash>tcn',
      't <C-Bslash>x',
      't <C-Bslash>z',
      'x <Plug>(aineo-explain)',
      'x <Plug>(aineo-explain-deep)',
      'x <Plug>(aineo-explain-deep-issues)',
      'x <Plug>(aineo-explain-issues)',
      'x <Plug>(aineo-explain-issues-tools)',
      'x <Plug>(aineo-explain-mark)',
      'x <Plug>(aineo-explain-next)',
      'x <Plug>(aineo-explain-previous)',
      'x <Plug>(aineo-explain-tools)',
      'x <Plug>(aineo-send)',
      'x <Plug>(aineo-write)',
      'x <Plug>(aineo-write-deep)',
      'x \\V',
      'x \\VI',
      'x \\VV',
      'x \\VVI',
      'x \\W',
      'x \\s',
      'x \\v',
      'x \\vi',
      'x \\vm',
      'x \\w',
    },
    autocmds = { 'aineo StdinReadPost' },
  })
end

T['plugin/aineo.lua']['does nothing when vim.g.loaded_aineo is already set'] = function()
  children.restart(child, { '--cmd', "let g:loaded_aineo = 'set before startup'" })

  eq(child.lua_get('vim.g.loaded_aineo'), 'set before startup')
  eq(child.lua_get(LOADED_AINEO_MODULES), {})
end

return T
