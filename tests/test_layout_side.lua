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

--- Moves Claude's column to `claude_side` in the child's layout.
---
---@param claude_side string
local function set_claude_side(claude_side)
  child.lua([[require('aineo.layout').set_claude_side(...)]], { claude_side })
end

--- The window the child's cursor is in.
---@return integer window
local function current_window()
  return child.lua_get('vim.api.nvim_get_current_win()')
end

--- Opens the file the child shows before the layout opens, with Claude's
--- column on `claude_side`, so that the layout has a file column between its
--- two; returns the buffers of the layout's windows and the file's.
---
---@param claude_side string
---@return table buffers `claude`, `report`, `input` and `file`
local function open_with_a_file_column(claude_side)
  layout.start(child)
  local buffers = layout.stand_ins(child)
  child.cmd('edit ' .. layout.file('first.txt'))
  buffers.file = child.lua_get('vim.api.nvim_get_current_buf()')
  layout.open(child, layout.arrangement(buffers, claude_side))
  buffers.input = layout.input_buffer(child)
  return buffers
end

--- Whether the window showing `buffer` lies left of the window showing
--- `other` in the child's current tab.
---
---@param buffer integer
---@param other integer
---@return boolean
local function lies_left_of(buffer, other)
  return layout.box(child, layout.window_showing(child, buffer)).col
    < layout.box(child, layout.window_showing(child, other)).col
end

T['set_claude_side()'] = MiniTest.new_set()

T['set_claude_side()']['moves Claude to the right and the Report above Input to the left'] = function()
  local buffers = layout.open_with_stand_ins(child)

  set_claude_side('right')

  local boxes = layout.boxes(child, buffers)
  eq({ boxes.report.row, boxes.report.col }, { 0, 0 })
  eq({ boxes.input.row, boxes.input.col }, { boxes.report.height + 1, 0 })
  eq({ boxes.claude.row, boxes.claude.col }, { 0, boxes.report.width + 1 })
  eq(layout.window_count(child), 3)
end

T['set_claude_side()']['moves the file column’s neighbours either side of it, the file staying between'] = function()
  local buffers = open_with_a_file_column('left')

  set_claude_side('right')

  local report = layout.box(child, layout.window_showing(child, buffers.report))
  local file = layout.box(child, layout.window_showing(child, buffers.file))
  local claude = layout.box(child, layout.window_showing(child, buffers.claude))
  eq(report.col, 0)
  eq(file.col, report.width + 1)
  eq(claude.col, file.col + file.width + 1)
  layout.expect_near(report.width, (layout.COLUMNS - 2) / 3)
  layout.expect_near(claude.width, (layout.COLUMNS - 2) / 3)
end

T['set_claude_side()']['moves back to the left as it moved to the right'] = function()
  local buffers = open_with_a_file_column('left')
  local before = layout.boxes(child, buffers)

  set_claude_side('right')
  set_claude_side('left')

  eq(layout.boxes(child, buffers), before)
end

T['set_claude_side()']['keeps every window, its buffer, the Claude job and the cursor'] = function()
  local buffers = open_with_a_file_column('left')
  local windows = {
    claude = layout.window_showing(child, buffers.claude),
    report = layout.window_showing(child, buffers.report),
    input = layout.window_showing(child, buffers.input),
    file = layout.window_showing(child, buffers.file),
  }
  local job = child.lua_get('vim.bo[...].channel', { buffers.claude })
  child.lua('vim.api.nvim_win_set_cursor(..., { 3, 2 })', { windows.file })
  child.lua('vim.api.nvim_set_current_win(...)', { windows.report })

  set_claude_side('right')

  for role, window in pairs(windows) do
    eq(child.lua_get('vim.api.nvim_win_get_buf(...)', { window }), buffers[role])
  end
  eq(child.lua_get('vim.bo[...].channel', { buffers.claude }), job)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(...)', { windows.file }), { 3, 2 })
  eq(current_window(), windows.report)
end

T['set_claude_side()']['keeps the cursor in Claude’s window when it was there'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.claude)
  local claude_window = current_window()

  set_claude_side('right')

  eq(current_window(), claude_window)
end

T['set_claude_side()']['ends a zoom of the right column without restoring it'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.report)
  child.lua([[require('aineo.layout').toggle_zoom()]])

  set_claude_side('right')

  eq(child.lua_get([[require('aineo.layout').is_zoomed()]]), false)
  local boxes = layout.boxes(child, buffers)
  local rows = boxes.report.height + boxes.input.height
  layout.expect_near(boxes.report.height, layout.REPORT_HEIGHT * rows)
end

T['set_claude_side()']['ends a zoom of a whole window without restoring it'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.claude)
  child.lua([[require('aineo.layout').toggle_full_zoom()]])

  set_claude_side('right')

  eq(child.lua_get([[require('aineo.layout').is_zoomed()]]), false)
  local claude = layout.box(child, layout.window_showing(child, buffers.claude))
  layout.expect_near(claude.width, layout.COLUMNS / 2)
end

T['set_claude_side()']['moves only the right column while Claude’s window is closed'] = function()
  local buffers = open_with_a_file_column('left')
  layout.close_windows(child, buffers, { 'claude' })

  set_claude_side('right')

  eq(lies_left_of(buffers.report, buffers.file), true)
end

T['set_claude_side()']['moves only Claude’s window while the right column is closed'] = function()
  local buffers = open_with_a_file_column('left')
  layout.close_windows(child, buffers, { 'report', 'input' })

  set_claude_side('right')

  eq(lies_left_of(buffers.file, buffers.claude), true)
end

T['set_claude_side()']['moves the layout of a tab page that is not shown, leaving the shown one alone'] = function()
  local buffers = layout.open_with_stand_ins(child)
  child.cmd('tabnew')
  local shown = current_window()

  set_claude_side('right')

  eq(child.lua_get('#vim.api.nvim_tabpage_list_wins(0)'), 1)
  eq(current_window(), shown)
  child.cmd('tabprevious')
  eq(lies_left_of(buffers.report, buffers.claude), true)
end

T['set_claude_side()']['moves the windows of the run pane’s stack with the right column'] = function()
  local buffers = layout.open_with_stand_ins(child)
  local stack = { layout.terminal(child), layout.terminal(child) }
  local arrangement = layout.arrangement(buffers)
  arrangement.run = { buffers = stack, winbar = '%f' }
  child.lua([[require('aineo.layout').show_pane('run', ...)]], { arrangement })

  set_claude_side('right')

  local first = layout.box(child, layout.window_showing(child, stack[1]))
  local second = layout.box(child, layout.window_showing(child, stack[2]))
  eq({ first.col, second.col }, { 0, 0 })
  eq(second.row > first.row, true)
  eq(lies_left_of(stack[1], buffers.claude), true)
end

T['set_claude_side()']['refuses a side that is neither left nor right'] = function()
  layout.open_with_stand_ins(child)

  expect.error(function()
    set_claude_side('middle')
  end, 'claude_side')
end

T['claude_side()'] = MiniTest.new_set()

T['claude_side()']['is the left before any side was handed and the side handed after'] = function()
  layout.start(child)
  local sides = {}
  table.insert(sides, child.lua_get([[require('aineo.layout').claude_side()]]))

  layout.open(child, layout.arrangement(layout.stand_ins(child), 'right'))
  table.insert(sides, child.lua_get([[require('aineo.layout').claude_side()]]))
  set_claude_side('left')
  table.insert(sides, child.lua_get([[require('aineo.layout').claude_side()]]))

  eq(sides, { 'left', 'right', 'left' })
end

T['claude_side()']['is set before any window exists, and the layout then opens on it'] = function()
  layout.start(child)
  set_claude_side('right')
  local buffers = layout.stand_ins(child)

  layout.open(child, layout.arrangement(buffers))

  eq(lies_left_of(buffers.report, buffers.claude), true)
end

T['open() on a layout that is open'] = MiniTest.new_set()

T['open() on a layout that is open']['moves the columns to the side the arrangement hands'] = function()
  local buffers = layout.open_with_stand_ins(child, 'left')

  layout.open(child, layout.arrangement(buffers, 'right'))

  eq(lies_left_of(buffers.report, buffers.claude), true)
end

T['open() on a layout that is open']['keeps the side when the arrangement hands none'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')

  layout.open(child, layout.arrangement(buffers))

  eq(lies_left_of(buffers.report, buffers.claude), true)
end

T['open() on a layout that is open']['opens a closed window on the side the columns are on'] = function()
  local buffers = open_with_a_file_column('left')
  set_claude_side('right')
  layout.close_windows(child, buffers, { 'claude' })

  layout.open(child, layout.arrangement(buffers))

  eq(lies_left_of(buffers.report, buffers.file), true)
  eq(lies_left_of(buffers.file, buffers.claude), true)
end

T['open() on a layout that is open']['rebuilds on the side the layout was set to once every window was closed'] = function()
  local buffers = layout.open_with_stand_ins(child, 'left')
  set_claude_side('right')
  child.cmd('only')
  child.cmd('enew')

  layout.open(child, layout.arrangement(buffers))

  eq(lies_left_of(buffers.report, buffers.claude), true)
end

T['the file column on a swapped layout'] = MiniTest.new_set()

T['the file column on a swapped layout']['takes a file shown with show_file() between the two columns'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')
  local path = layout.file('first.txt')
  child.cmd('badd ' .. path)
  local file = child.lua_get('vim.fn.bufnr(...)', { path })

  child.lua([[require('aineo.layout').show_file(...)]], { file })

  eq(layout.window_count(child), 4)
  eq(lies_left_of(buffers.report, file), true)
  eq(lies_left_of(file, buffers.claude), true)
end

T['the file column on a swapped layout']['takes a diff shown with show_diff() between the two columns'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')
  local diff = layout.named_scratch(child, 'aineo://a-diff')

  child.lua([[require('aineo.layout').show_diff(...)]], { diff })

  eq(lies_left_of(buffers.report, diff), true)
  eq(lies_left_of(diff, buffers.claude), true)
end

T['the file column on a swapped layout']['takes a file opened from Claude’s window, between the two columns'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')
  local path = layout.file('first.txt')
  layout.enter_window_showing(child, buffers.claude)

  child.cmd('edit ' .. path)

  local file = child.lua_get('vim.fn.bufnr(...)', { path })
  eq(layout.wait_until(child, 'vim.fn.bufwinid(...) ~= -1', { file }), true)
  eq(lies_left_of(buffers.report, file), true)
  eq(lies_left_of(file, buffers.claude), true)
end

T['the file column on a swapped layout']['takes a file shown while Claude’s window is closed, on Claude’s side of the right column'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')
  layout.close_windows(child, buffers, { 'claude' })
  local path = layout.file('first.txt')
  child.cmd('badd ' .. path)
  local file = child.lua_get('vim.fn.bufnr(...)', { path })

  child.lua([[require('aineo.layout').show_file(...)]], { file })

  eq(lies_left_of(buffers.report, file), true)
end

T['the file column on a swapped layout']['tells whether a window is in it'] = function()
  local buffers = open_with_a_file_column('right')

  local in_the_column = child.lua_get(
    [[(function(file, report, claude)
      local layout = require('aineo.layout')
      return {
        layout.is_file_column_window(vim.fn.bufwinid(file)),
        layout.is_file_column_window(vim.fn.bufwinid(report)),
        layout.is_file_column_window(vim.fn.bufwinid(claude)),
      }
    end)(...)]],
    { buffers.file, buffers.report, buffers.claude }
  )

  eq(in_the_column, { true, false, false })
end

T['the panes column on a swapped layout'] = MiniTest.new_set()

T['the panes column on a swapped layout']['has the area of the Report and Input, on the left'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')

  local area = child.lua_get([[require('aineo.layout').right_column_area()]])

  local report = layout.box(child, layout.window_showing(child, buffers.report))
  eq(area.col, 0)
  eq(area.width, report.width)
  eq(area.row, 0)
end

T['the panes column on a swapped layout']['has the area of the Report and Input, on the right, once it moved'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')
  set_claude_side('left')

  local area = child.lua_get([[require('aineo.layout').right_column_area()]])

  local report = layout.box(child, layout.window_showing(child, buffers.report))
  eq(area.col, report.col)
end

T['the panes column on a swapped layout']['reopens its Report above Input, on the left'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')
  layout.close_windows(child, buffers, { 'report' })

  layout.open(child, layout.arrangement(buffers))

  local boxes = layout.boxes(child, buffers)
  eq({ boxes.report.col, boxes.report.row }, { 0, 0 })
  eq(boxes.input.row > boxes.report.row, true)
  eq(boxes.claude.col > boxes.report.col, true)
end

T['the panes column on a swapped layout']['reopens the Report and Input on the left once both closed'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')
  layout.close_windows(child, buffers, { 'report', 'input' })

  layout.open(child, layout.arrangement(buffers))

  eq(lies_left_of(buffers.report, buffers.claude), true)
  eq(lies_left_of(buffers.input, buffers.claude), true)
end

T['the panes column on a swapped layout']['reopens Input below the Report'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')
  layout.close_windows(child, buffers, { 'input' })

  layout.open(child, layout.arrangement(buffers))

  local boxes = layout.boxes(child, buffers)
  eq(boxes.input.col, boxes.report.col)
  eq(boxes.input.row > boxes.report.row, true)
end

T['the panes column on a swapped layout']['keeps the Report’s share of its rows'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')

  local boxes = layout.boxes(child, buffers)
  layout.expect_near(
    boxes.report.height,
    layout.REPORT_HEIGHT * (boxes.report.height + boxes.input.height)
  )
end

T['the panes column on a swapped layout']['shows the changes pane in the same two windows'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')
  local files = layout.named_scratch(child, 'aineo://changes-files')
  local commits = layout.named_scratch(child, 'aineo://changes-commits')
  local arrangement = layout.arrangement(buffers)
  arrangement.changes = { files = files, commits = commits }

  child.lua([[require('aineo.layout').show_pane('changes', ...)]], { arrangement })

  eq(lies_left_of(files, buffers.claude), true)
  eq(lies_left_of(commits, buffers.claude), true)
end

T['the panes column on a swapped layout']['gives the terminal pane the whole column on the left and gives Input back'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')
  local shell = layout.terminal(child)
  local arrangement = layout.arrangement(buffers)
  arrangement.shell = shell

  child.lua([[require('aineo.layout').show_pane('terminal', ...)]], { arrangement })
  local alone = layout.window_count(child)
  local shell_is_left = lies_left_of(shell, buffers.claude)
  child.lua([[require('aineo.layout').show_pane('agent', ...)]], { arrangement })

  eq({ alone, shell_is_left }, { 2, true })
  eq(layout.window_count(child), 3)
  eq(lies_left_of(buffers.input, buffers.claude), true)
end

T['the panes column on a swapped layout']['opens Input on the left when the Report’s window was closed under the terminal pane that gives way'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')
  local shell = layout.terminal(child)
  local arrangement = layout.arrangement(buffers)
  arrangement.shell = shell
  child.lua([[require('aineo.layout').show_pane('terminal', ...)]], { arrangement })
  child.lua('vim.api.nvim_win_close(vim.fn.win_findbuf(...)[1], false)', { shell })

  child.cmd('bwipeout! ' .. shell)

  eq(layout.wait_until(child, 'vim.fn.bufwinid(...) ~= -1', { buffers.input }), true)
  eq(lies_left_of(buffers.input, buffers.claude), true)
end

T['the panes column on a swapped layout']['zooms a window of the column to its rows'] = function()
  local buffers = layout.open_with_stand_ins(child, 'right')
  layout.enter_window_showing(child, buffers.input)

  child.lua([[require('aineo.layout').toggle_zoom()]])

  eq(child.lua_get([[require('aineo.layout').is_zoomed()]]), true)
  local boxes = layout.boxes(child, buffers)
  eq(boxes.input.height > boxes.report.height, true)
end

return T
