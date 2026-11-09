local MiniTest = require('mini.test')
local fake_explorer = dofile('tests/helpers/fake_explorer.lua')

local eq = MiniTest.expect.equality

local world
local explorer

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      world = fake_explorer.new_world({ files = { 'a/b/y.txt', 'top.txt' } })
      explorer = fake_explorer.new(world)
      vim.cmd('only')
      vim.api.nvim_win_set_buf(0, explorer.buffer())
    end,
    post_case = function()
      explorer.let_go()
    end,
  },
})

--- The lines of the explorer's buffer below its header.
---
---@return string[]
local function tree_lines()
  return vim.list_slice(vim.api.nvim_buf_get_lines(explorer.made_buffer(), 0, -1, false), 2)
end

--- Presses `keys` in the explorer's window as typed in Normal mode.
---
---@param keys string
local function press(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'x', false)
end

T['a chain unfolded by a key'] = MiniTest.new_set()

T['a chain unfolded by a key']['stays unfolded, every folder of it, once it breaks'] =
  MiniTest.new_set({
    parametrize = { { 'l' }, { '<CR>' } },
  })

T['a chain unfolded by a key']['stays unfolded, every folder of it, once it breaks']['by'] = function(
  key
)
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  press(key)
  local unfolded = tree_lines()

  world.files = { 'a/b/y.txt', 'a/z.txt', 'top.txt' }
  explorer.refresh()

  eq(unfolded, { '▾   a/b/', '      y.txt', '    top.txt' })
  eq(tree_lines(), {
    '▾   a/',
    '  ▾   b/',
    '        y.txt',
    '      z.txt',
    '    top.txt',
  })
end

return T
