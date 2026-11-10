local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality
local expect = MiniTest.expect

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The width the explorer column is handed unless a test chooses another.
local WIDTH = 30

--- The arrangement the layout opens with in a fresh child: the stand-ins, an
--- explorer buffer, the explorer column on `column` at `width` when `column`
--- is given, and Claude's column on `claude_side` when given.
---
---@param column? string|false
---@param claude_side? string
---@param width? integer
---@return table buffers `claude`, `report` and `explorer`
---@return table arrangement
local function arrangement_with_column(column, claude_side, width)
  layout.start(child)
  local buffers = layout.stand_ins(child)
  buffers.explorer = layout.named_scratch(child, 'aineo://explorer')
  local arrangement = layout.arrangement(buffers, claude_side)
  arrangement.explorer = buffers.explorer
  arrangement.explorer_column = column
  arrangement.explorer_width = width or WIDTH
  return buffers, arrangement
end

--- Opens the layout in a fresh child as `arrangement_with_column()` shapes it;
--- returns the buffers of the layout's windows and the explorer's.
---
---@param column? string|false
---@param claude_side? string
---@param width? integer
---@return table buffers `claude`, `report`, `input` and `explorer`
local function open_with_column(column, claude_side, width)
  local buffers, arrangement = arrangement_with_column(column, claude_side, width)
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  return buffers
end

--- The box of the window showing `buffer` in the child's current tab.
---
---@param buffer integer
---@return table box
local function box_of(buffer)
  return layout.box(child, layout.window_showing(child, buffer))
end

T['open() with the explorer column'] = MiniTest.new_set()

T['open() with the explorer column']['puts the explorer at the far left, full height, at the width handed'] = function()
  local buffers = open_with_column('left')

  local explorer, claude = box_of(buffers.explorer), box_of(buffers.claude)
  eq({ explorer.row, explorer.col, explorer.width }, { 0, 0, WIDTH })
  eq(explorer.height, claude.height)
  eq(layout.window_count(child), 4)
end

T['open() with the explorer column']['puts the explorer at the far right, full height, at the width handed'] = function()
  local buffers = open_with_column('right', nil, 24)

  local explorer, claude = box_of(buffers.explorer), box_of(buffers.claude)
  eq({ explorer.row, explorer.col + explorer.width, explorer.width }, { 0, layout.COLUMNS, 24 })
  eq(explorer.height, claude.height)
end

T['open() with the explorer column']['is outermost whichever side Claude and the explorer are on'] =
  MiniTest.new_set({
    parametrize = {
      { 'left', 'left', { 'explorer', 'claude', 'report' } },
      { 'left', 'right', { 'explorer', 'report', 'claude' } },
      { 'right', 'left', { 'claude', 'report', 'explorer' } },
      { 'right', 'right', { 'report', 'claude', 'explorer' } },
    },
  })

T['open() with the explorer column']['is outermost whichever side Claude and the explorer are on']['in order'] = function(
  column,
  claude_side,
  order
)
  local buffers = open_with_column(column, claude_side)

  local columns_in_order = vim.deepcopy(order)
  table.sort(columns_in_order, function(a, b)
    return box_of(buffers[a]).col < box_of(buffers[b]).col
  end)
  eq(columns_in_order, order)
end

T['open() with the explorer column']['keeps the explorer’s width and shares the rest by halves without a file column'] = function()
  local buffers = open_with_column('left')

  local rest = layout.COLUMNS - WIDTH - 1
  layout.expect_near(box_of(buffers.explorer).width, WIDTH)
  layout.expect_near(box_of(buffers.claude).width, rest / 2)
end

T['open() with the explorer column']['shares the rest by thirds with a file column'] = function()
  local buffers, arrangement = arrangement_with_column('right', 'left')
  child.cmd('edit ' .. layout.file('first.txt'))

  layout.open(child, arrangement)

  local rest = layout.COLUMNS - WIDTH - 1
  layout.expect_near(box_of(buffers.explorer).width, WIDTH)
  layout.expect_near(box_of(buffers.claude).width, (rest - 2) / 3)
  layout.expect_near(box_of(buffers.report).width, (rest - 2) / 3)
end

T['open() with the explorer column']['fixes the explorer window’s width'] = function()
  local buffers = open_with_column('left')

  local window = layout.window_showing(child, buffers.explorer)
  eq(child.lua_get('vim.wo[...].winfixwidth', { window }), true)
end

T['open() with the explorer column']['adds no window when the column is false'] = function()
  open_with_column(false)

  eq(layout.window_count(child), 3)
end

T['open() with the explorer column']['adds no window when no column is handed'] = function()
  open_with_column(nil)

  eq(layout.window_count(child), 3)
end

T['open() with the explorer column']['refuses a column that is neither a side nor false, naming the setting'] = function()
  local _, arrangement = arrangement_with_column('middle')

  expect.error(function()
    layout.open(child, arrangement)
  end, 'arrangement%.explorer_column')
end

T['open() with the explorer column']['refuses a width that is not a positive whole number, naming the setting'] =
  MiniTest.new_set({
    parametrize = { { 0 }, { 1.5 }, { -3 }, { 'wide' } },
  })

T['open() with the explorer column']['refuses a width that is not a positive whole number, naming the setting']['as'] = function(
  width
)
  local _, arrangement = arrangement_with_column('left')
  arrangement.explorer_width = width

  expect.error(function()
    layout.open(child, arrangement)
  end, 'arrangement%.explorer_width')
end

T['open() with the explorer column']['refuses a column without a width, naming it'] = function()
  local _, arrangement = arrangement_with_column('left')
  arrangement.explorer_width = nil

  expect.error(function()
    layout.open(child, arrangement)
  end, 'arrangement%.explorer_width')
end

T['open() with the explorer column']['refuses a column without the explorer’s buffer, naming it'] = function()
  local _, arrangement = arrangement_with_column('left')
  arrangement.explorer = nil

  expect.error(function()
    layout.open(child, arrangement)
  end, 'arrangement%.explorer:')
end

--- Moves Claude's column to `claude_side` in the child's layout.
---
---@param claude_side string
local function set_claude_side(claude_side)
  child.lua([[require('aineo.layout').set_claude_side(...)]], { claude_side })
end

--- The names of `buffers` in the order their windows lie from the left of the
--- screen.
---
---@param buffers table
---@param names string[]
---@return string[] names
local function from_the_left(buffers, names)
  local ordered = vim.deepcopy(names)
  table.sort(ordered, function(a, b)
    return box_of(buffers[a]).col < box_of(buffers[b]).col
  end)
  return ordered
end

T['swapping Claude’s side with the explorer column'] = MiniTest.new_set()

T['swapping Claude’s side with the explorer column']['leaves the explorer outermost where it is and mirrors the other columns'] =
  MiniTest.new_set({
    parametrize = {
      { 'left', 'left', { 'explorer', 'report', 'claude' } },
      { 'right', 'left', { 'report', 'claude', 'explorer' } },
      { 'left', 'right', { 'explorer', 'claude', 'report' } },
      { 'right', 'right', { 'claude', 'report', 'explorer' } },
    },
  })

T['swapping Claude’s side with the explorer column']['leaves the explorer outermost where it is and mirrors the other columns']['in order'] = function(
  column,
  from,
  expected
)
  local buffers = open_with_column(column, from)
  local window = layout.window_showing(child, buffers.explorer)

  set_claude_side(from == 'left' and 'right' or 'left')

  eq(from_the_left(buffers, { 'explorer', 'claude', 'report' }), expected)
  eq(layout.window_showing(child, buffers.explorer), window)
  eq(box_of(buffers.explorer).width, WIDTH)
end

T['swapping Claude’s side with the explorer column']['keeps the thirds of the remaining width with a file column'] = function()
  local buffers, arrangement = arrangement_with_column('left', 'left')
  child.cmd('edit ' .. layout.file('first.txt'))
  layout.open(child, arrangement)

  set_claude_side('right')

  local rest = layout.COLUMNS - WIDTH - 1
  layout.expect_near(box_of(buffers.claude).width, (rest - 2) / 3)
  layout.expect_near(box_of(buffers.report).width, (rest - 2) / 3)
  eq(box_of(buffers.explorer).width, WIDTH)
end

--- Commands that open a window across the whole screen below the columns.
local WINDOWS_ACROSS_THE_SCREEN = {
  { 'botright 6new' },
  { 'botright copen 6' },
  { 'topleft 6new' },
  { 'help' },
}

--- The row, width and height of each window of the child's current tab that
--- does not float and is as wide as the screen, top to bottom.
local ACROSS_THE_SCREEN = [[(function()
  local across = {}
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if
      vim.api.nvim_win_get_config(window).relative == ''
      and vim.api.nvim_win_get_width(window) == vim.o.columns
    then
      table.insert(across, {
        row = vim.api.nvim_win_get_position(window)[1],
        width = vim.api.nvim_win_get_width(window),
        height = vim.api.nvim_win_get_height(window),
      })
    end
  end
  table.sort(across, function(a, b)
    return a.row < b.row
  end)
  return across
end)()]]

--- The windows of the child's current tab as wide as the screen
--- (`ACROSS_THE_SCREEN`).
---
---@return table[] boxes
local function windows_across_the_screen()
  return child.lua_get(ACROSS_THE_SCREEN)
end

--- The rows 'cmdheight' gives the command line in the child.
---
---@return integer
local function command_line_rows()
  return child.lua_get('vim.o.cmdheight')
end

T['the explorer column with a window across the screen'] = MiniTest.new_set({
  parametrize = WINDOWS_ACROSS_THE_SCREEN,
})

T['the explorer column with a window across the screen']['is not spanned by the window'] = function(
  command
)
  local buffers = open_with_column('left')

  child.cmd(command)

  local explorer, claude = box_of(buffers.explorer), box_of(buffers.claude)
  eq(explorer.height, claude.height)
  expect.equality(explorer.height < layout.LINES - 2, true)
end

T['the explorer column with a window across the screen']['stays outermost through a swap'] = function(
  command
)
  local buffers = open_with_column('right', 'left')
  child.cmd(command)
  local count = layout.window_count(child)

  set_claude_side('right')

  eq(from_the_left(buffers, { 'explorer', 'claude', 'report' }), { 'report', 'claude', 'explorer' })
  eq(layout.window_count(child), count)
end

T['the explorer column with a window across the screen']['keeps the window across the screen, and the command line, through a swap'] = function(
  command
)
  local buffers = open_with_column('right', 'left')
  child.cmd(command)
  local across, rows = windows_across_the_screen(), command_line_rows()

  set_claude_side('right')

  eq(windows_across_the_screen(), across)
  eq(command_line_rows(), rows)
  local explorer, claude = box_of(buffers.explorer), box_of(buffers.claude)
  eq(explorer.height, claude.height)
  expect.equality(explorer.height < layout.LINES - 2, true)
end

T['the explorer column with a window across the screen']['keeps the window across the screen when it opens again'] = function(
  command
)
  local buffers, arrangement = arrangement_with_column('left')
  layout.open(child, arrangement)
  child.lua('vim.api.nvim_win_close(vim.fn.win_findbuf(...)[1], false)', { buffers.explorer })
  child.cmd(command)
  local across = windows_across_the_screen()

  layout.open(child, arrangement)

  eq(windows_across_the_screen(), across)
  local explorer, claude = box_of(buffers.explorer), box_of(buffers.claude)
  eq(explorer.height, claude.height)
  expect.equality(explorer.height < layout.LINES - 2, true)
end

T['the explorer column with a window across the screen']['keeps the window across the screen as Claude’s window opens beyond the column'] = function(
  command
)
  local buffers, arrangement = arrangement_with_column('left', 'left')
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  layout.close_windows(child, buffers, { 'claude' })
  child.cmd(command)
  local across = windows_across_the_screen()

  layout.focus(child, 'claude', arrangement)

  eq(from_the_left(buffers, { 'explorer', 'claude', 'report' }), { 'explorer', 'claude', 'report' })
  eq(windows_across_the_screen(), across)
end

T['claude_side() with a window across the screen and no explorer column'] = MiniTest.new_set({
  parametrize = WINDOWS_ACROSS_THE_SCREEN,
})

T['claude_side() with a window across the screen and no explorer column']['keeps the window and the command line through a swap'] = function(
  command
)
  open_with_column(false)
  child.cmd(command)
  local across, rows = windows_across_the_screen(), command_line_rows()

  set_claude_side('right')

  eq(windows_across_the_screen(), across)
  eq(command_line_rows(), rows)
end

T['the explorer column'] = MiniTest.new_set()

T['the explorer column']['stays outermost as Claude’s closed window opens again'] =
  MiniTest.new_set({
    parametrize = {
      { 'left', 'left', { 'explorer', 'claude', 'report' } },
      { 'right', 'right', { 'report', 'claude', 'explorer' } },
    },
  })

T['the explorer column']['stays outermost as Claude’s closed window opens again']['in order'] = function(
  column,
  claude_side,
  expected
)
  local buffers, arrangement = arrangement_with_column(column, claude_side)
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  layout.close_windows(child, buffers, { 'claude' })

  layout.focus(child, 'claude', arrangement)

  eq(from_the_left(buffers, { 'explorer', 'claude', 'report' }), expected)
end

--- Opens the layout again in the child as `arrangement` is, with `column` and
--- `width` in place of the ones it carries.
---
---@param arrangement table
---@param column string|false
---@param width? integer
local function open_again(arrangement, column, width)
  local changed = vim.deepcopy(arrangement)
  changed.explorer_column = column
  changed.explorer_width = width or arrangement.explorer_width
  layout.open(child, changed)
end

T['opening the layout again'] = MiniTest.new_set()

T['opening the layout again']['opens the column when it is handed one now'] = function()
  local buffers, arrangement = arrangement_with_column(false)
  layout.open(child, arrangement)

  open_again(arrangement, 'left')

  eq({ box_of(buffers.explorer).col, layout.window_count(child) }, { 0, 4 })
end

T['opening the layout again']['closes the column when it is handed false now'] = function()
  local buffers, arrangement = arrangement_with_column('left')
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  local current = child.lua_get('vim.api.nvim_get_current_win()')

  open_again(arrangement, false)

  eq(layout.window_count(child), 3)
  eq(child.lua_get('vim.api.nvim_get_current_win()'), current)
  layout.expect_near(box_of(buffers.claude).width, layout.COLUMNS / 2)
  eq(child.lua_get([[require('aineo.layout').explorer_column()]]), false)
end

T['opening the layout again']['moves the column to the side it is handed now, the window staying'] = function()
  local buffers, arrangement = arrangement_with_column('left')
  layout.open(child, arrangement)
  local window = layout.window_showing(child, buffers.explorer)

  open_again(arrangement, 'right')

  local explorer = box_of(buffers.explorer)
  eq(layout.window_showing(child, buffers.explorer), window)
  eq(explorer.col + explorer.width, layout.COLUMNS)
  eq(layout.window_count(child), 4)
end

T['opening the layout again']['gives the column the width it is handed now'] = function()
  local buffers, arrangement = arrangement_with_column('left')
  layout.open(child, arrangement)

  open_again(arrangement, 'left', 20)

  layout.expect_near(box_of(buffers.explorer).width, 20)
  layout.expect_near(box_of(buffers.claude).width, (layout.COLUMNS - 20 - 1) / 2)
end

T['opening the layout again']['opens a column that was closed by hand, in place'] = function()
  local buffers, arrangement = arrangement_with_column('right', 'left')
  layout.open(child, arrangement)
  child.lua('vim.api.nvim_win_close(vim.fn.win_findbuf(...)[1], false)', { buffers.explorer })

  layout.open(child, arrangement)

  local explorer = box_of(buffers.explorer)
  eq(explorer.col + explorer.width, layout.COLUMNS)
  eq(layout.window_count(child), 4)
end

T['opening the layout again']['gives way the explorer pane to the agent pane when the column opens'] = function()
  local buffers, arrangement = arrangement_with_column(false)
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  child.lua([[require('aineo.layout').show_pane('explorer', ...)]], { arrangement })

  open_again(arrangement, 'left')

  eq(child.lua_get([[require('aineo.layout').shown_pane()]]), 'agent')
  eq(layout.window_count(child), 4)
  eq(
    child.lua_get('vim.api.nvim_win_get_buf(...)', { layout.window_showing(child, buffers.report) }),
    buffers.report
  )
  expect.equality(layout.window_showing(child, buffers.input) ~= nil, true)
end

--- The window the child's cursor is in.
---
---@return integer window
local function current_window()
  return child.lua_get('vim.api.nvim_get_current_win()')
end

--- Moves the child's layout cursor into the explorer column.
---
---@param arrangement table|string a table, or the Lua of a function that returns one
local function focus_explorer_column(arrangement)
  child.lua([[require('aineo.layout').focus_explorer_column(...)]], { arrangement })
end

--- Whether moving the child's cursor into the explorer column with
--- `arrangement` raised no error.
---
---@param arrangement table
---@return boolean
local function focuses_explorer_column(arrangement)
  return child.lua_get(
    [[(pcall(require('aineo.layout').focus_explorer_column, ...))]],
    { arrangement }
  )
end

T['focus_explorer_column()'] = MiniTest.new_set()

T['focus_explorer_column()']['moves the cursor into the column'] = function()
  local buffers, arrangement = arrangement_with_column('left')
  layout.open(child, arrangement)

  focus_explorer_column(arrangement)

  eq(current_window(), layout.window_showing(child, buffers.explorer))
  eq(layout.window_count(child), 4)
end

T['focus_explorer_column()']['opens a column that was closed, in place, and moves the cursor into it'] = function()
  local buffers, arrangement = arrangement_with_column('right')
  layout.open(child, arrangement)
  child.lua('vim.api.nvim_win_close(vim.fn.win_findbuf(...)[1], false)', { buffers.explorer })

  local focused = focuses_explorer_column(arrangement)

  eq(focused, true)
  local explorer = box_of(buffers.explorer)
  eq(explorer.col + explorer.width, layout.COLUMNS)
  eq(current_window(), layout.window_showing(child, buffers.explorer))
end

T['focus_explorer_column()']['does nothing with the cursor in the column already'] = function()
  local _, arrangement = arrangement_with_column('left')
  layout.open(child, arrangement)
  focus_explorer_column(arrangement)
  local window = current_window()

  focus_explorer_column(arrangement)

  eq({ current_window(), layout.window_count(child) }, { window, 4 })
end

T['focus_explorer_column()']['opens the layout first when none is open, with the arrangement it is handed'] = function()
  local buffers, arrangement = arrangement_with_column('left')

  local focused = child.lua_get(
    [[(function(arrangement)
      return (pcall(require('aineo.layout').focus_explorer_column, function()
        return arrangement
      end))
    end)(...)]],
    { arrangement }
  )

  eq(focused, true)
  eq(current_window(), layout.window_showing(child, buffers.explorer))
  eq(layout.window_count(child), 4)
end

T['focus_explorer_column()']['raises an error naming the setting when the layout has no column to focus'] = function()
  local _, arrangement = arrangement_with_column(false)
  layout.open(child, arrangement)

  expect.error(function()
    focus_explorer_column(arrangement)
  end, 'arrangement%.explorer_column')
end

T['opening the layout again']['builds around the explorer column when it is the only window left, the cursor in it'] = function()
  local buffers, arrangement = arrangement_with_column('left')
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  focus_explorer_column(arrangement)
  layout.close_windows(child, buffers, { 'claude', 'report', 'input' })

  layout.open(child, arrangement)

  eq(layout.window_count(child), 4)
  eq(#child.lua_get('vim.fn.win_findbuf(...)', { buffers.explorer }), 1)
  eq(box_of(buffers.explorer).col, 0)
  eq(box_of(buffers.explorer).width, WIDTH)
end

T['opening the layout again']['keeps the explorer, the column and its width when it is handed none of them'] = function()
  local buffers, arrangement = arrangement_with_column('right', 'left', 24)
  layout.open(child, arrangement)
  local kept = vim.deepcopy(arrangement)
  kept.explorer = nil
  kept.explorer_column = nil
  kept.explorer_width = nil

  local opened = child.lua_get([[(pcall(require('aineo.layout').open, ...))]], { kept })

  eq(opened, true)
  local explorer = box_of(buffers.explorer)
  eq({ explorer.col + explorer.width, explorer.width }, { layout.COLUMNS, 24 })
end

--- Sets the explorer column of the child's layout to `column` at `width`.
---
---@param column string|false
---@param width integer
local function set_explorer_column(column, width)
  child.lua([[require('aineo.layout').set_explorer_column(...)]], { column, width })
end

T['set_explorer_column()'] = MiniTest.new_set()

T['set_explorer_column()']['opens the column of a layout that is open, the cursor staying'] = function()
  local buffers, arrangement = arrangement_with_column(false)
  layout.open(child, arrangement)
  local current = current_window()

  set_explorer_column('left', 24)

  local explorer = box_of(buffers.explorer)
  eq({ explorer.col, explorer.width, layout.window_count(child) }, { 0, 24, 4 })
  eq(current_window(), current)
  eq(child.lua_get([[require('aineo.layout').explorer_column()]]), 'left')
end

T['set_explorer_column()']['closes the column, the other columns taking its cells'] = function()
  local buffers, arrangement = arrangement_with_column('left')
  layout.open(child, arrangement)

  set_explorer_column(false, WIDTH)

  eq(layout.window_count(child), 3)
  layout.expect_near(box_of(buffers.claude).width, layout.COLUMNS / 2)
  eq(child.lua_get([[require('aineo.layout').explorer_column()]]), false)
end

T['set_explorer_column()']['moves the column to the other side and gives it the width'] = function()
  local buffers, arrangement = arrangement_with_column('left')
  layout.open(child, arrangement)
  local window = layout.window_showing(child, buffers.explorer)

  set_explorer_column('right', 20)

  local explorer = box_of(buffers.explorer)
  eq(layout.window_showing(child, buffers.explorer), window)
  eq({ explorer.col + explorer.width, explorer.width }, { layout.COLUMNS, 20 })
end

T['set_explorer_column()']['gives the explorer pane’s place to the agent pane while the column is set'] = function()
  local buffers, arrangement = arrangement_with_column(false)
  layout.open(child, arrangement)
  child.lua([[require('aineo.layout').show_pane('explorer', ...)]], { arrangement })

  set_explorer_column('left', WIDTH)

  eq(child.lua_get([[require('aineo.layout').shown_pane()]]), 'agent')
  eq(layout.window_count(child), 4)
  eq(
    child.lua_get('vim.api.nvim_win_get_buf(...)', { layout.window_showing(child, buffers.report) }),
    buffers.report
  )
end

T['set_explorer_column()']['changes the layout of a tab page that is not shown, leaving the shown one alone'] = function()
  local buffers, arrangement = arrangement_with_column(false)
  layout.open(child, arrangement)
  child.cmd('tabnew')
  local shown = child.lua_get('vim.api.nvim_get_current_tabpage()')
  local windows_shown = child.lua_get('#vim.api.nvim_tabpage_list_wins(0)')

  set_explorer_column('left', WIDTH)

  eq(child.lua_get('vim.api.nvim_get_current_tabpage()'), shown)
  eq(child.lua_get('#vim.api.nvim_tabpage_list_wins(0)'), windows_shown)
  eq(#child.lua_get('vim.fn.win_findbuf(...)', { buffers.explorer }), 1)
  eq(
    child.lua_get(
      '#vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(vim.fn.win_findbuf(...)[1]))',
      { buffers.explorer }
    ),
    4
  )
end

T['set_explorer_column()']['only records the column while no window of the layout is open'] = function()
  local buffers, arrangement = arrangement_with_column(false)
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  child.cmd('botright new')
  layout.close_windows(child, buffers, { 'claude', 'report', 'input' })
  arrangement.explorer_column = nil

  set_explorer_column('right', WIDTH)
  layout.open(child, arrangement)

  eq(child.lua_get([[require('aineo.layout').explorer_column()]]), 'right')
  local explorer = box_of(buffers.explorer)
  eq(explorer.col + explorer.width, layout.COLUMNS)
end

T['set_explorer_column()']['refuses a column that is neither a side nor false, naming it'] = function()
  local _, arrangement = arrangement_with_column(false)
  layout.open(child, arrangement)

  expect.error(function()
    set_explorer_column('middle', WIDTH)
  end, "explorer_column: expected 'left', 'right' or false")
end

T['set_explorer_column()']['refuses a width that is not a positive whole number, naming it'] = function()
  local _, arrangement = arrangement_with_column(false)
  layout.open(child, arrangement)

  expect.error(function()
    set_explorer_column('left', 0)
  end, 'explorer_width: expected a positive whole number')
end

T['a full zoom of the layout with the explorer column'] = MiniTest.new_set()

T['a full zoom of the layout with the explorer column']['gives the column its width back when it ends after a resize'] = function()
  local buffers, arrangement = arrangement_with_column('left')
  layout.open(child, arrangement)
  child.lua('require("aineo.layout").toggle_full_zoom()')

  child.o.columns = 120
  child.lua('require("aineo.layout").toggle_full_zoom()')

  eq(box_of(buffers.explorer).width, WIDTH)
end

T['a file opened in the explorer column'] = MiniTest.new_set()

T['a file opened in the explorer column']['moves to the file column, the column showing the explorer again'] = function()
  local buffers, arrangement = arrangement_with_column('left')
  layout.open(child, arrangement)
  focus_explorer_column(arrangement)
  local explorer_window = current_window()

  child.cmd('edit ' .. layout.file('first.txt'))
  local file = child.lua_get('vim.fn.bufnr(...)', { layout.file('first.txt') })
  layout.wait_until(child, '#vim.api.nvim_tabpage_list_wins(0) == 5')

  eq(child.lua_get('vim.api.nvim_win_get_buf(...)', { explorer_window }), buffers.explorer)
  local explorer, file_box = box_of(buffers.explorer), box_of(file)
  eq(explorer.col, 0)
  expect.equality(file_box.col > box_of(buffers.claude).col, true)
  expect.equality(file_box.col < box_of(buffers.report).col, true)
  eq(layout.window_count(child), 5)
end

T['explorer_column()'] = MiniTest.new_set()

T['explorer_column()']['is false before a column was handed and the side after'] = function()
  open_with_column(false)
  local before = child.lua_get([[require('aineo.layout').explorer_column()]])
  open_with_column('right')
  local after = child.lua_get([[require('aineo.layout').explorer_column()]])

  eq({ before, after }, { false, 'right' })
end

return T
