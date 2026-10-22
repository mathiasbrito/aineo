local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The winbar the arrangement below hands the layout for the run pane's
--- windows.
local RUN_WINBAR = '%f'

--- Starts the child and opens the layout in it with the stand-ins, the changes
--- pane's stand-ins, a shell terminal and two terminals for the run pane;
--- returns every buffer the layout was handed or made, by name, and the
--- arrangement.
---
---@return table buffers `claude`, `report`, `input`, `files`, `commits`, `shell` and `run`
---@return table arrangement
local function open_every_pane()
  layout.start(child)
  local buffers = layout.stand_ins(child)
  buffers.files = layout.named_scratch(child, 'aineo://changes-files')
  buffers.commits = layout.named_scratch(child, 'aineo://changes-commits')
  buffers.shell = layout.terminal(child)
  buffers.run = { layout.terminal(child), layout.terminal(child) }
  local arrangement = layout.arrangement(buffers)
  arrangement.changes = { files = buffers.files, commits = buffers.commits }
  arrangement.shell = buffers.shell
  arrangement.run = { buffers = buffers.run, winbar = RUN_WINBAR }
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  return buffers, arrangement
end

--- The area of the right column the layout gives, as `{ row, col, width,
--- height }` in screen cells from 0, or `vim.NIL` when it gives none.
---
---@return table|userdata area
local function right_column_area()
  return child.lua_get([[require('aineo.layout').right_column_area()]])
end

--- The area the right column takes of the child's screen when it takes every
--- row above the command line and every column right of Claude's column and
--- the separator after it.
---
---@param buffers table
---@param rows_taken integer the rows of the screen the right column does not take besides the command line
---@return table area
local function whole_right_side(buffers, rows_taken)
  local claude = layout.box(child, layout.window_showing(child, buffers.claude))
  local first_column = claude.width + 1
  return {
    row = 0,
    col = first_column,
    width = layout.COLUMNS - first_column,
    height = layout.LINES - 1 - rows_taken,
  }
end

T['right_column_area()'] = MiniTest.new_set()

T['right_column_area()']['gives none before the layout is opened'] = function()
  layout.start(child)

  eq(right_column_area(), vim.NIL)
end

T['right_column_area()']['gives every row and column the right column takes, windows and status lines'] =
  MiniTest.new_set({
    parametrize = { { 'agent' }, { 'changes' }, { 'terminal' }, { 'run' }, { 'explorer' } },
  })

T['right_column_area()']['gives every row and column the right column takes, windows and status lines']['pane'] = function(
  pane
)
  local buffers, arrangement = open_every_pane()
  arrangement.explorer = layout.named_scratch(child, 'aineo://explorer')
  child.lua([[require('aineo.layout').show_pane(...)]], { pane, arrangement })

  eq(right_column_area(), whole_right_side(buffers, 0))
end

T['right_column_area()']['leaves out the global status line, which spans the screen'] = function()
  local buffers = open_every_pane()
  child.o.laststatus = 3

  eq(right_column_area(), whole_right_side(buffers, 1))
end

T['right_column_area()']['counts no status line when there are none'] = function()
  local buffers = open_every_pane()
  child.o.laststatus = 0

  eq(right_column_area(), whole_right_side(buffers, 0))
end

T['right_column_area()']['gives only the right column when a file column lies between it and Claude'] = function()
  local buffers = open_every_pane()
  layout.enter_window_showing(child, buffers.claude)
  child.cmd('edit ' .. layout.file('first.txt'))

  local report = layout.box(child, layout.window_showing(child, buffers.report))

  local area = right_column_area()
  eq({ area.col, area.width, area.row }, { report.col, report.width, 0 })
end

T['right_column_area()']['gives the whole column while a window of it is zoomed'] = function()
  local buffers = open_every_pane()
  local before = right_column_area()
  layout.enter_window_showing(child, buffers.report)

  child.lua([[require('aineo.layout').toggle_zoom()]])

  eq(right_column_area(), before)
end

T['right_column_area()']['gives none while a window is zoomed over the whole tab page'] = function()
  local buffers = open_every_pane()
  layout.enter_window_showing(child, buffers.claude)

  child.lua([[require('aineo.layout').toggle_full_zoom()]])

  eq(right_column_area(), vim.NIL)
end

T['right_column_area()']['gives the area again once the full zoom ends'] = function()
  local buffers = open_every_pane()
  local before = right_column_area()
  layout.enter_window_showing(child, buffers.claude)
  child.lua([[require('aineo.layout').toggle_full_zoom()]])

  child.lua([[require('aineo.layout').toggle_full_zoom()]])

  eq(right_column_area(), before)
end

T['right_column_area()']['gives none when the right column’s windows are closed'] = function()
  local buffers = open_every_pane()

  layout.close_windows(child, buffers, { 'report', 'input' })

  eq(right_column_area(), vim.NIL)
end

T['right_column_area()']['gives none from another tab page, whose cells are not the layout’s'] = function()
  open_every_pane()

  child.cmd('tabnew')

  eq(right_column_area(), vim.NIL)
end

T['right_column_area()']['follows the column as the screen is resized'] = function()
  local buffers = open_every_pane()

  child.o.columns = 100
  child.o.lines = 30

  local claude = layout.box(child, layout.window_showing(child, buffers.claude))
  eq(
    right_column_area(),
    { row = 0, col = claude.width + 1, width = 100 - claude.width - 1, height = 29 }
  )
end

return T
