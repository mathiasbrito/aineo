local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality
local expect = MiniTest.expect

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

T['open() with Claude on the right'] = MiniTest.new_set()

T['open() with Claude on the right']['shows the Report above Input in the left column and Claude in the right one'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')

  local boxes = layout.boxes(child, buffers)
  eq(layout.window_count(child), 3)
  eq({ boxes.report.row, boxes.report.col }, { 0, 0 })
  eq({ boxes.input.row, boxes.input.col }, { boxes.report.height + 1, 0 })
  eq({ boxes.claude.row, boxes.claude.col }, { 0, boxes.report.width + 1 })
  eq(boxes.claude.height, boxes.report.height + 1 + boxes.input.height)
end

T['open() with Claude on the right']['gives Claude half the columns'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')

  local claude = layout.box(child, layout.window_showing(child, buffers.claude))
  layout.expect_near(claude.width, layout.COLUMNS / 2)
end

T['open() with Claude on the right']['gives the Report its share of the left column'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')

  local boxes = layout.boxes(child, buffers)
  layout.expect_near(
    boxes.report.height,
    layout.REPORT_HEIGHT * (boxes.report.height + boxes.input.height)
  )
end

T['open() with Claude on the right']['keeps the file the current window shows as the column between'] = function()
  layout.start(child)
  local buffers = layout.stand_ins(child)
  local path = layout.file('first.txt')
  child.cmd('edit ' .. path)

  layout.open(child, layout.arrangement(buffers, 'right'))

  local file_window = layout.window_showing(child, child.lua_get('vim.fn.bufnr(...)', { path }))
  local file = layout.box(child, file_window)
  local report = layout.box(child, layout.window_showing(child, buffers.report))
  local claude = layout.box(child, layout.window_showing(child, buffers.claude))
  eq(report.col, 0)
  eq(file.col, report.width + 1)
  eq(claude.col, file.col + file.width + 1)
  layout.expect_near(report.width, (layout.COLUMNS - 2) / 3)
  layout.expect_near(claude.width, (layout.COLUMNS - 2) / 3)
end

T['open() with Claude on the right']['refuses a side that is neither left nor right, naming the setting'] = function()
  layout.start(child)
  local buffers = layout.stand_ins(child)

  expect.error(function()
    child.lua([[require('aineo.layout').open(...)]], { layout.arrangement(buffers, 'middle') })
  end, 'arrangement%.claude_side')
end

return T
