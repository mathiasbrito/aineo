local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The number of the tab page holding the window whose id is the argument.
local TAB_OF_WINDOW = 'vim.api.nvim_tabpage_get_number(vim.api.nvim_win_get_tabpage(...))'

--- The number of the current tab page.
local CURRENT_TAB = 'vim.api.nvim_tabpage_get_number(0)'

T['opening the layout from another tab'] = MiniTest.new_set()

T['opening the layout from another tab']['reopens a closed window in the tab of the layout'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.close_windows(child, buffers, { 'claude' })
  child.cmd('tabnew')

  layout.open(child, layout.arrangement(buffers))

  eq(
    child.lua_get(
      TAB_OF_WINDOW,
      { child.lua_get('vim.fn.win_findbuf(...)[1]', { buffers.claude }) }
    ),
    1
  )
end

T['opening the layout from another tab']['shows the tab of the layout, with no window made'] = function()
  local buffers = layout.open_with_stand_ins(child)
  child.cmd('tabnew')
  local tab_windows = child.lua_get('vim.api.nvim_tabpage_list_wins(0)')

  layout.open(child, layout.arrangement(buffers))

  eq(child.lua_get(CURRENT_TAB), 1)
  eq(layout.window_count(child), 3)
  eq(child.lua_get('vim.api.nvim_tabpage_list_wins(vim.api.nvim_list_tabpages()[2])'), tab_windows)
end

T['focus() from another tab'] = MiniTest.new_set()

T['focus() from another tab']['reopens its closed window in the tab of the layout, with the cursor there'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.close_windows(child, buffers, { 'claude' })
  child.cmd('tabnew')

  layout.focus(child, 'claude', layout.arrangement(buffers))

  eq(child.lua_get(CURRENT_TAB), 1)
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), buffers.claude)
end

T['the editor resized while another tab is shown'] = MiniTest.new_set()

T['the editor resized while another tab is shown']['leaves the layout at its proportions once its tab is back'] = function()
  local buffers = layout.open_with_stand_ins(child)
  child.cmd('tabnew')
  child.o.columns = 120
  child.o.lines = 40

  child.cmd('tabprevious')

  local boxes = layout.boxes(child, buffers)
  layout.expect_near(boxes.claude.width, 120 / 2)
  layout.expect_near(
    boxes.report.height,
    layout.REPORT_HEIGHT * (boxes.report.height + boxes.input.height)
  )
end

T['a file opened in Input after the layout was reopened from another tab'] = MiniTest.new_set()

T['a file opened in Input after the layout was reopened from another tab']['leaves that tab alone'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.close_windows(child, buffers, { 'claude' })
  child.cmd('tabnew ' .. layout.file('second.txt'))
  child.cmd('vsplit ' .. layout.file('third.txt'))
  local tab_buffers =
    child.lua_get('vim.tbl_map(vim.api.nvim_win_get_buf, vim.api.nvim_tabpage_list_wins(0))')
  layout.open(child, layout.arrangement(buffers))
  layout.enter_window_showing(child, buffers.input)

  child.cmd('edit ' .. layout.file('first.txt'))

  eq(
    child.lua_get(
      'vim.tbl_map(vim.api.nvim_win_get_buf, vim.api.nvim_tabpage_list_wins(vim.api.nvim_list_tabpages()[2]))'
    ),
    tab_buffers
  )
  eq(child.lua_get(CURRENT_TAB), 1)
end

return T
