local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')

local eq = MiniTest.expect.equality

--- Each key that follows the prefix, with the `<Plug>` mapping it runs.
local PREFIX_KEYS = {
  { 's', '<Plug>(aineo-send)' },
  { 'o', '<Plug>(aineo-open)' },
  { 'r', '<Plug>(aineo-report)' },
  { 'i', '<Plug>(aineo-input)' },
  { 'c', '<Plug>(aineo-claude)' },
}

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

T['the prefix'] = MiniTest.new_set({ parametrize = PREFIX_KEYS })

T['the prefix']['is \\ by default, each key running its <Plug> mapping'] = function(key, plug)
  children.restart(child)

  eq(child.fn.maparg('\\' .. key, 'n'), plug)
end

T['the prefix']['is the one vim.g.aineo names'] = function(key, plug)
  children.restart(child, { '--cmd', "let g:aineo = { 'prefix': ',' }" })

  eq(child.fn.maparg(',' .. key, 'n'), plug)
  eq(child.fn.maparg('\\' .. key, 'n'), '')
end

T['the prefix']['is the one setup() records before the editor has started'] = function(key, plug)
  children.restart(child, { '-c', "lua require('aineo').setup({ prefix = ',' })" })

  eq(child.fn.maparg(',' .. key, 'n'), plug)
  eq(child.fn.maparg('\\' .. key, 'n'), '')
end

T['the prefix']['maps nothing, and says nothing, when it is false'] = function(key)
  children.restart(child, { '--cmd', 'lua vim.g.aineo = { prefix = false }' })

  eq(child.fn.maparg('\\' .. key, 'n'), '')
  eq(child.cmd_capture('messages'), '')
end

T['the prefix']['is the one setup() records right after the file is sourced late'] = function(
  key,
  plug
)
  children.restart(child, { '--cmd', 'let g:loaded_aineo = 1' })

  child.lua([[
    vim.g.loaded_aineo = nil
    vim.cmd.runtime('plugin/aineo.lua')
    require('aineo').setup({ prefix = ',' })
  ]])

  eq(
    vim.wait(1000, function()
      return child.fn.maparg(',' .. key, 'n') == plug
    end, 10),
    true
  )
  eq(child.fn.maparg('\\' .. key, 'n'), '')
end

T["the user's own mapping"] = MiniTest.new_set()

T["the user's own mapping"]['of a key sequence stays, and the other keys are mapped'] = function()
  children.restart(child, { '--cmd', 'nnoremap \\o <Cmd>let g:mine = 1<CR>' })

  eq(child.fn.maparg('\\o', 'n'), '<Cmd>let g:mine = 1<CR>')
  eq(child.fn.maparg('\\s', 'n'), '<Plug>(aineo-send)')
end

T['a wrong setting at startup'] = MiniTest.new_set()

T['a wrong setting at startup']['is told to the user, naming it, and nothing is mapped'] = function()
  children.restart(child, { '--cmd', 'lua vim.g.aineo = { prefix = 1 }' })

  eq(child.cmd_capture('messages'), 'aineo: prefix: expected a string, or false, got 1')
  eq(child.fn.maparg('\\o', 'n'), '')
end

return T
