local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- What makes a buffer Input rather than a file, for the buffer whose number
--- is the argument.
local SCRATCH_OPTIONS = [[(function(buffer)
  return {
    name = vim.api.nvim_buf_get_name(buffer),
    buftype = vim.bo[buffer].buftype,
    bufhidden = vim.bo[buffer].bufhidden,
    buflisted = vim.bo[buffer].buflisted,
    swapfile = vim.bo[buffer].swapfile,
  }
end)(...)]]

--- The scratch options Input has from the moment it is made.
local INPUT_SCRATCH_OPTIONS = {
  name = 'aineo://input',
  buftype = 'nofile',
  bufhidden = 'hide',
  buflisted = false,
  swapfile = false,
}

T['Input deleted with :bdelete'] = MiniTest.new_set()

T['Input deleted with :bdelete']['is its named scratch buffer again when the layout opens'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('bdelete')

  layout.open(child, layout.arrangement(buffers))

  eq(child.lua_get(SCRATCH_OPTIONS, { buffers.input }), INPUT_SCRATCH_OPTIONS)
end

--- Deletes Input with `:bdelete`, opens the layout again and types a prompt
--- into Input, leaving the cursor in Input.
---
---@param buffers { claude: integer, report: integer, input: integer }
local function delete_input_then_type_into_it(buffers)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('bdelete')
  layout.open(child, layout.arrangement(buffers))
  child.lua('vim.api.nvim_buf_set_lines(..., 0, -1, false, { "a new prompt" })', { buffers.input })
  layout.enter_window_showing(child, buffers.input)
end

T['Input deleted with :bdelete']['keeps its window when a file is opened in it afterwards'] = function()
  local buffers = layout.open_with_stand_ins(child)
  delete_input_then_type_into_it(buffers)
  local input_window = layout.window_showing(child, buffers.input)
  local path = layout.file('first.txt')

  child.cmd('edit ' .. path)

  eq(child.lua_get('vim.api.nvim_win_get_buf(...)', { input_window }), buffers.input)
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), child.lua_get('vim.fn.bufnr(...)', { path }))
end

T['Input wiped with :bwipeout'] = MiniTest.new_set()

T['Input wiped with :bwipeout']['is made anew when the layout opens'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('bwipeout')

  MiniTest.expect.no_error(function()
    layout.open(child, layout.arrangement(buffers))
  end)

  eq(layout.window_count(child), 3)
  eq(child.lua_get(SCRATCH_OPTIONS, { layout.input_buffer(child) }), INPUT_SCRATCH_OPTIONS)
end

T['Input wiped with :bwipeout']['is made anew when focus() asks for Input'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('bwipeout')

  MiniTest.expect.no_error(function()
    layout.focus(child, 'input', layout.arrangement(buffers))
  end)

  eq(child.lua_get('vim.api.nvim_get_current_buf()'), layout.input_buffer(child))
  eq(child.lua_get('vim.api.nvim_buf_get_name(0)'), 'aineo://input')
end

T['a buffer named aineo://input before the layout, as a restored session makes'] =
  MiniTest.new_set()

T['a buffer named aineo://input before the layout, as a restored session makes']['becomes Input when the layout opens'] = function()
  layout.start(child)
  child.cmd('edit aineo://input')
  local named = child.lua_get('vim.api.nvim_get_current_buf()')
  child.cmd('edit ' .. layout.file('first.txt'))
  local buffers = layout.stand_ins(child)

  MiniTest.expect.no_error(function()
    layout.open(child, layout.arrangement(buffers))
  end)

  eq(layout.window_count(child), 4)
  eq(layout.input_buffer(child), named)
  eq(child.lua_get(SCRATCH_OPTIONS, { named }), INPUT_SCRATCH_OPTIONS)
end

T['a buffer named aineo://input after Input was wiped'] = MiniTest.new_set()

T['a buffer named aineo://input after Input was wiped']['becomes Input when the layout opens again'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('bwipeout')
  local named = child.lua_get('vim.fn.bufadd(...)', { 'aineo://input' })
  child.lua('vim.fn.bufload(...)', { named })

  MiniTest.expect.no_error(function()
    layout.open(child, layout.arrangement(buffers))
  end)

  eq(layout.window_count(child), 3)
  eq(layout.input_buffer(child), named)
  eq(child.lua_get(SCRATCH_OPTIONS, { named }), INPUT_SCRATCH_OPTIONS)
end

T['Input edited again with a bare :edit'] = MiniTest.new_set()

T['Input edited again with a bare :edit']['stays its named scratch buffer'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.input)

  child.cmd('edit')

  eq(child.lua_get(SCRATCH_OPTIONS, { buffers.input }), INPUT_SCRATCH_OPTIONS)
end

--- Quits the child with `:qall` and says whether it quit: a refusal returns
--- its message, and a child that quit answers nothing.
local QUIT = 'select(2, pcall(vim.cmd.qall))'

T['Input deleted with :bdelete']['holding typed text lets Neovim quit'] = function()
  local buffers = layout.open_with_stand_ins(child)
  delete_input_then_type_into_it(buffers)

  local answered = pcall(child.lua_get, QUIT)

  eq(answered, false)
end

return T
