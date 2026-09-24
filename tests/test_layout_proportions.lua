local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

T['the layout'] = MiniTest.new_set()

T['the layout']['keeps its sizes through :wincmd ='] = function()
  local buffers = layout.open_with_stand_ins(child)
  local before = layout.boxes(child, buffers)

  child.cmd('wincmd =')

  eq(layout.boxes(child, buffers), before)
end

T['the layout']['puts its sizes back when a window split from Input closes'] = MiniTest.new_set({
  parametrize = { { 'split' }, { 'vsplit' }, { 'topleft vnew' }, { 'vertical botright new' } },
})

T['the layout']['puts its sizes back when a window split from Input closes']['with'] = function(
  split
)
  local buffers = layout.open_with_stand_ins(child)
  local before = layout.boxes(child, buffers)
  layout.enter_window_showing(child, buffers.input)
  child.cmd(split)

  child.cmd('close')

  eq(layout.boxes(child, buffers), before)
end

T['the layout']['with the file column, puts its sizes back when a new window closes'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('edit ' .. layout.file('first.txt'))
  local file_window = child.lua_get('vim.api.nvim_get_current_win()')
  local before = { layout.boxes(child, buffers), layout.box(child, file_window) }
  child.cmd('vertical botright new')

  child.cmd('close')

  eq({ layout.boxes(child, buffers), layout.box(child, file_window) }, before)
end

--- The windows of the current tab.
local WINDOWS = 'vim.api.nvim_tabpage_list_wins(0)'

T['opening the layout again'] = MiniTest.new_set()

T['opening the layout again']['creates no window'] = function()
  local buffers = layout.open_with_stand_ins(child)
  local windows = child.lua_get(WINDOWS)
  layout.enter_window_showing(child, buffers.claude)

  layout.open(child, layout.arrangement(buffers))

  eq(child.lua_get(WINDOWS), windows)
end

T['opening the layout again']['brings back its closed windows, in their places'] =
  MiniTest.new_set({
    parametrize = { { { 'claude' } }, { { 'report' } }, { { 'input' } }, { { 'report', 'input' } } },
  })

T['opening the layout again']['brings back its closed windows, in their places']['closed'] = function(
  closed
)
  local buffers = layout.open_with_stand_ins(child)
  local before = layout.boxes(child, buffers)
  layout.close_windows(child, buffers, closed)

  layout.open(child, layout.arrangement(buffers))

  eq(layout.boxes(child, buffers), before)
end

T['opening the layout again']['shows the Claude buffer it is handed, as after a restart'] = function()
  local buffers = layout.open_with_stand_ins(child)
  local claude_window = layout.window_showing(child, buffers.claude)
  local restarted = layout.terminal(child)

  layout.open(child, layout.arrangement({ claude = restarted, report = buffers.report }))

  eq(child.lua_get('vim.api.nvim_win_get_buf(...)', { claude_window }), restarted)
end

T['opening the layout again']['shows the Report buffer it is handed'] = function()
  local buffers = layout.open_with_stand_ins(child)
  local report_window = layout.window_showing(child, buffers.report)
  local another_report = layout.named_scratch(child, 'aineo://another-report')

  layout.open(child, layout.arrangement({ claude = buffers.claude, report = another_report }))

  eq(child.lua_get('vim.api.nvim_win_get_buf(...)', { report_window }), another_report)
end

T['opening the layout again']['shows Input again where another buffer took its window'] = function()
  local buffers = layout.open_with_stand_ins(child)
  local input_window = layout.window_showing(child, buffers.input)
  child.lua('vim.api.nvim_win_set_buf(...)', { input_window, layout.terminal(child) })

  layout.open(child, layout.arrangement(buffers))

  eq(child.lua_get('vim.api.nvim_win_get_buf(...)', { input_window }), buffers.input)
end

T['opening the layout again']['gives a restarted Claude buffer back after a file leaves its window'] = function()
  local buffers = layout.open_with_stand_ins(child)
  local claude_window = layout.window_showing(child, buffers.claude)
  local restarted = layout.terminal(child)
  child.lua('vim.api.nvim_win_set_buf(...)', { claude_window, restarted })
  layout.open(child, layout.arrangement({ claude = restarted, report = buffers.report }))
  child.lua('vim.api.nvim_set_current_win(...)', { claude_window })

  child.cmd('edit ' .. layout.file('first.txt'))

  eq(child.lua_get('vim.api.nvim_win_get_buf(...)', { claude_window }), restarted)
end

T['opening the layout again']['leaves the cursor where it is'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.claude)
  local claude_window = child.lua_get('vim.api.nvim_get_current_win()')
  layout.close_windows(child, buffers, { 'report' })

  layout.open(child, layout.arrangement(buffers))

  eq(child.lua_get('vim.api.nvim_get_current_win()'), claude_window)
end

T['opening the layout again']['puts its proportions back after a resize'] = function()
  local buffers = layout.open_with_stand_ins(child)
  local before = layout.boxes(child, buffers)
  layout.enter_window_showing(child, buffers.claude)
  child.cmd('vertical resize 20')
  layout.enter_window_showing(child, buffers.report)
  child.cmd('resize 5')

  layout.open(child, layout.arrangement(buffers))

  eq(layout.boxes(child, buffers), before)
end

--- The screen the editor is resized to.
local RESIZED_COLUMNS = 120
local RESIZED_LINES = 36

T['after the editor is resized'] = MiniTest.new_set()

T['after the editor is resized']['Claude has half the columns and the Report its share'] = function()
  local buffers = layout.open_with_stand_ins(child)

  child.o.columns = RESIZED_COLUMNS
  child.o.lines = RESIZED_LINES

  local boxes = layout.boxes(child, buffers)
  layout.expect_near(boxes.claude.width, RESIZED_COLUMNS / 2)
  layout.expect_near(
    boxes.report.height,
    layout.REPORT_HEIGHT * (boxes.report.height + boxes.input.height)
  )
end

T['after the editor is resized']['with the file column, the three columns have a third each'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('edit ' .. layout.file('first.txt'))
  local file_window = child.lua_get('vim.api.nvim_get_current_win()')

  child.o.columns = RESIZED_COLUMNS

  local third = (RESIZED_COLUMNS - 2) / 3
  local boxes = layout.boxes(child, buffers)
  layout.expect_near(boxes.claude.width, third)
  layout.expect_near(layout.box(child, file_window).width, third)
  layout.expect_near(boxes.report.width, third)
end

local AINEO_WINDOWS = { { 'claude' }, { 'report' }, { 'input' } }

T['closing one of the three windows'] = MiniTest.new_set({ parametrize = AINEO_WINDOWS })

T['closing one of the three windows']['reports no error'] = function(window)
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers[window])

  child.cmd('close')

  eq(child.lua_get('vim.v.errmsg'), '')
end

return T
