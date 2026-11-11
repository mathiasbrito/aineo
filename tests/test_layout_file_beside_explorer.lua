local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality
local expect = MiniTest.expect

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The width the explorer column is handed.
local WIDTH = 30

--- The columns from the left of the screen, with the file column beside the
--- explorer column, by the explorer column's side and Claude's: `{
--- explorer_side, claude_side, order }`.
local PLACES = {
  { 'left', 'left', { 'explorer', 'files', 'claude', 'report' } },
  { 'left', 'right', { 'explorer', 'files', 'report', 'claude' } },
  { 'right', 'left', { 'claude', 'report', 'files', 'explorer' } },
  { 'right', 'right', { 'report', 'claude', 'files', 'explorer' } },
}

--- The same, with the file column between Claude's column and the panes column.
local CENTRES = {
  { 'left', 'left', { 'explorer', 'claude', 'files', 'report' } },
  { 'left', 'right', { 'explorer', 'report', 'files', 'claude' } },
  { 'right', 'left', { 'claude', 'files', 'report', 'explorer' } },
  { 'right', 'right', { 'report', 'files', 'claude', 'explorer' } },
}

--- Starts the child and returns the layout's stand-in buffers, an explorer
--- buffer among them, and an arrangement putting the explorer column on
--- `column`, Claude's column on `claude_side` and the file column beside the
--- explorer column as `beside` says (nothing when `nil`).
---
---@param column string|false
---@param claude_side string
---@param beside? boolean
---@return table buffers
---@return table arrangement
local function arrangement_with(column, claude_side, beside)
  layout.start(child)
  local buffers = layout.stand_ins(child)
  buffers.explorer = layout.named_scratch(child, 'aineo://explorer')
  local arrangement = layout.arrangement(buffers, claude_side)
  arrangement.explorer = buffers.explorer
  arrangement.explorer_column = column
  arrangement.explorer_width = WIDTH
  arrangement.file_beside_explorer = beside
  return buffers, arrangement
end

--- Opens the layout in a fresh child, with a file in the starting window when
--- `with_file`, so that the file column exists from the start; returns the
--- buffers, the file's among them when there is one.
---
---@param column string|false
---@param claude_side string
---@param beside? boolean
---@param with_file? boolean
---@return table buffers
local function open_with(column, claude_side, beside, with_file)
  local buffers, arrangement = arrangement_with(column, claude_side, beside)
  if with_file then
    child.cmd('edit ' .. layout.file('first.txt'))
    buffers.files = child.lua_get('vim.api.nvim_get_current_buf()')
  end
  layout.open(child, arrangement)
  return buffers
end

--- A loaded buffer holding the fixture file `name`, shown in no window.
---
---@param name string
---@return integer buffer
local function loaded_file(name)
  return child.lua_get(
    [[(function(path)
      local buffer = vim.fn.bufadd(path)
      vim.fn.bufload(buffer)
      return buffer
    end)(...)]],
    { layout.file(name) }
  )
end

--- The box of the window showing `buffer` in the child's current tab.
---
---@param buffer integer
---@return table box
local function box_of(buffer)
  return layout.box(child, layout.window_showing(child, buffer))
end

--- The names of `buffers` in the order their windows lie from the left.
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

local COLUMN_NAMES = { 'explorer', 'files', 'claude', 'report' }

T['a file column built with the layout'] = MiniTest.new_set({ parametrize = PLACES })

T['a file column built with the layout']['lies beside the explorer column'] = function(
  column,
  claude_side,
  expected
)
  local buffers = open_with(column, claude_side, true, true)

  eq(from_the_left(buffers, COLUMN_NAMES), expected)
end

T['a file column built with the layout']['keeps the explorer outermost and its width'] = function(
  column,
  claude_side
)
  local buffers = open_with(column, claude_side, true, true)

  eq(box_of(buffers.explorer).width, WIDTH)
  eq(box_of(buffers.explorer).height, box_of(buffers.files).height)
end

T['a file column shown after the layout opened'] = MiniTest.new_set({ parametrize = PLACES })

T['a file column shown after the layout opened']['opens beside the explorer column'] = function(
  column,
  claude_side,
  expected
)
  local buffers = open_with(column, claude_side, true)
  buffers.files = loaded_file('first.txt')

  child.lua([[require('aineo.layout').show_file(...)]], { buffers.files })

  eq(from_the_left(buffers, COLUMN_NAMES), expected)
  eq(layout.window_count(child), 5)
end

T['the file column beside the explorer'] = MiniTest.new_set()

T['the file column beside the explorer']['takes the next file in its window rather than open another'] = function()
  local buffers = open_with('left', 'left', true, true)
  local second = loaded_file('second.txt')
  local window = layout.window_showing(child, buffers.files)

  child.lua([[require('aineo.layout').show_file(...)]], { second })

  eq(layout.window_showing(child, second), window)
  eq(layout.window_count(child), 5)
end

T['the file column beside the explorer']['takes a diff in its window as a file'] = function()
  local buffers = open_with('right', 'left', true, true)
  local diff = layout.named_scratch(child, 'aineo://a-diff')
  local window = layout.window_showing(child, buffers.files)

  child.lua([[require('aineo.layout').show_diff(...)]], { diff })

  buffers.files = diff
  eq(layout.window_showing(child, diff), window)
  eq(from_the_left(buffers, COLUMN_NAMES), { 'claude', 'report', 'files', 'explorer' })
end

T['the file column beside the explorer']['is the file column the layout reports'] = function()
  local buffers = open_with('left', 'right', true, true)

  eq(
    child.lua_get(
      [[require('aineo.layout').is_file_column_window(...)]],
      { layout.window_showing(child, buffers.files) }
    ),
    true
  )
  eq(
    child.lua_get(
      [[require('aineo.layout').is_file_column_window(...)]],
      { layout.window_showing(child, buffers.explorer) }
    ),
    false
  )
end

T['the file column beside the explorer']['opens again beside it once its last window closed'] = function()
  local buffers = open_with('right', 'right', true, true)
  child.lua([[vim.api.nvim_win_close(..., false)]], { layout.window_showing(child, buffers.files) })
  buffers.files = loaded_file('first.txt')

  child.lua([[require('aineo.layout').show_file(...)]], { buffers.files })

  eq(from_the_left(buffers, COLUMN_NAMES), { 'report', 'claude', 'files', 'explorer' })
end

T['a file column with the option off'] = MiniTest.new_set({ parametrize = CENTRES })

T['a file column with the option off']['built with the layout stays between Claude and the panes column'] = function(
  column,
  claude_side,
  expected
)
  local buffers = open_with(column, claude_side, false, true)

  eq(from_the_left(buffers, COLUMN_NAMES), expected)
end

T['a file column with the option off']['shown later stays between Claude and the panes column'] = function(
  column,
  claude_side,
  expected
)
  local buffers = open_with(column, claude_side, false)
  buffers.files = loaded_file('first.txt')
  child.lua([[require('aineo.layout').show_file(...)]], { buffers.files })

  eq(from_the_left(buffers, COLUMN_NAMES), expected)
end

T['a file column without the option handed'] = MiniTest.new_set()

T['a file column without the option handed']['stays between Claude and the panes column'] = function()
  local buffers = open_with('left', 'left', nil, true)

  eq(from_the_left(buffers, COLUMN_NAMES), { 'explorer', 'claude', 'files', 'report' })
end

T['a file column without an explorer column'] = MiniTest.new_set()

T['a file column without an explorer column']['stays between Claude and the panes column'] = function()
  local buffers = open_with(false, 'left', true, true)

  eq(from_the_left(buffers, { 'files', 'claude', 'report' }), { 'claude', 'files', 'report' })
end

T['open() with the file beside the explorer'] = MiniTest.new_set()
T['set_explorer_column()'] = MiniTest.new_set()

T['open() with the file beside the explorer']['refuses a value that is not a boolean, naming it'] = function()
  local _, arrangement = arrangement_with('left', 'left')
  arrangement.file_beside_explorer = 'yes'

  expect.error(function()
    layout.open(child, arrangement)
  end, 'arrangement%.file_beside_explorer:')
end

--- Calls `set_explorer_column()` in the child.
---
---@param column string|false
---@param beside? boolean
local function set_explorer_column(column, beside)
  child.lua(
    [[(function(column, width, beside)
      require('aineo.layout').set_explorer_column(column, width, beside)
    end)(...)]],
    { column, WIDTH, beside }
  )
end

--- Opens the layout in a fresh child with Claude's column on `claude_side` and
--- a file in its file column, `column` the explorer column the arrangement
--- hands, and `beside` the option; the cursor is put in the Report's window.
---
---@param column string|false
---@param claude_side string
---@param beside boolean
---@return table buffers
local function open_with_file(column, claude_side, beside)
  local buffers = open_with(column, claude_side, beside, true)
  layout.enter_window_showing(child, buffers.report)
  return buffers
end

T['turning the explorer column on'] = MiniTest.new_set({ parametrize = PLACES })

T['turning the explorer column on']['moves the open file column beside it'] = function(
  column,
  claude_side,
  expected
)
  local buffers = open_with_file(false, claude_side, true)
  child.lua([[vim.api.nvim_win_set_cursor(0, { 1, 0 })]])
  local file_window = layout.window_showing(child, buffers.files)
  child.lua([[vim.api.nvim_win_set_cursor(..., { 3, 2 })]], { file_window })

  set_explorer_column(column, true)

  eq(from_the_left(buffers, COLUMN_NAMES), expected)
  eq(layout.window_showing(child, buffers.files), file_window)
  eq(child.lua_get([[vim.api.nvim_win_get_cursor(...)]], { file_window }), { 3, 2 })
  eq(layout.window_showing(child, buffers.report), child.lua_get('vim.api.nvim_get_current_win()'))
end

T['turning the explorer column on']['keeps the file column in the centre with the option off'] = function()
  local buffers = open_with_file(false, 'left', false)

  set_explorer_column('left', false)

  eq(from_the_left(buffers, COLUMN_NAMES), { 'explorer', 'claude', 'files', 'report' })
end

T['turning the explorer column off'] = MiniTest.new_set({
  parametrize = {
    { 'left', 'left', { 'claude', 'files', 'report' } },
    { 'left', 'right', { 'report', 'files', 'claude' } },
    { 'right', 'left', { 'claude', 'files', 'report' } },
    { 'right', 'right', { 'report', 'files', 'claude' } },
  },
})

T['turning the explorer column off']['moves the file column back between Claude and the panes column'] = function(
  column,
  claude_side,
  expected
)
  local buffers = open_with_file(column, claude_side, true)
  local file_window = layout.window_showing(child, buffers.files)

  set_explorer_column(false, true)

  eq(from_the_left(buffers, { 'files', 'claude', 'report' }), expected)
  eq(layout.window_showing(child, buffers.files), file_window)
  eq(layout.window_count(child), 4)
end

T['changing the option'] = MiniTest.new_set()

T['changing the option']['to false moves the file column to the centre, the explorer staying'] = function()
  local buffers = open_with_file('left', 'left', true)
  local explorer_window = layout.window_showing(child, buffers.explorer)

  set_explorer_column('left', false)

  eq(from_the_left(buffers, COLUMN_NAMES), { 'explorer', 'claude', 'files', 'report' })
  eq(layout.window_showing(child, buffers.explorer), explorer_window)
  eq(box_of(buffers.explorer).width, WIDTH)
end

T['changing the option']['to true moves the file column beside the explorer'] = function()
  local buffers = open_with_file('right', 'right', false)

  set_explorer_column('right', true)

  eq(from_the_left(buffers, COLUMN_NAMES), { 'report', 'claude', 'files', 'explorer' })
end

T['changing the option']['by handing the arrangement again moves the file column'] = function()
  local buffers, arrangement = arrangement_with('left', 'left', true)
  child.cmd('edit ' .. layout.file('first.txt'))
  buffers.files = child.lua_get('vim.api.nvim_get_current_buf()')
  layout.open(child, arrangement)

  arrangement.file_beside_explorer = false
  layout.open(child, arrangement)

  eq(from_the_left(buffers, COLUMN_NAMES), { 'explorer', 'claude', 'files', 'report' })
end

T['changing the option']['keeps the option it was handed last when an arrangement hands none'] = function()
  local buffers, arrangement = arrangement_with('left', 'left', true)
  child.cmd('edit ' .. layout.file('first.txt'))
  buffers.files = child.lua_get('vim.api.nvim_get_current_buf()')
  layout.open(child, arrangement)

  arrangement.file_beside_explorer = nil
  layout.open(child, arrangement)

  eq(from_the_left(buffers, COLUMN_NAMES), { 'explorer', 'files', 'claude', 'report' })
end

T['changing the option']['by handing the arrangement without a column brings the file column back to the centre'] = function()
  local buffers, arrangement = arrangement_with('left', 'left', true)
  child.cmd('edit ' .. layout.file('first.txt'))
  buffers.files = child.lua_get('vim.api.nvim_get_current_buf()')
  layout.open(child, arrangement)

  arrangement.explorer_column = false
  layout.open(child, arrangement)

  eq(from_the_left(buffers, { 'files', 'claude', 'report' }), { 'claude', 'files', 'report' })
  eq(layout.window_count(child), 4)
end

T['changing the option']['by handing the arrangement another column side takes the file column along'] = function()
  local buffers, arrangement = arrangement_with('left', 'left', true)
  child.cmd('edit ' .. layout.file('first.txt'))
  buffers.files = child.lua_get('vim.api.nvim_get_current_buf()')
  layout.open(child, arrangement)

  arrangement.explorer_column = 'right'
  layout.open(child, arrangement)

  eq(from_the_left(buffers, COLUMN_NAMES), { 'claude', 'report', 'files', 'explorer' })
end

T['with the layout not complete'] = MiniTest.new_set()

T['with the layout not complete']['a file column opens beside the explorer all the same'] = function()
  local buffers = open_with('left', 'left', true)
  layout.close_windows(child, { report = buffers.report }, { 'report' })
  buffers.files = loaded_file('first.txt')

  child.lua([[require('aineo.layout').show_file(...)]], { buffers.files })

  eq(from_the_left(buffers, { 'explorer', 'files', 'claude' }), { 'explorer', 'files', 'claude' })
end

T['with the layout not complete']['a file column in the centre is reused rather than a second one opened beside the explorer'] = function()
  local buffers = open_with(false, 'left', true, true)
  layout.close_windows(child, { report = buffers.report }, { 'report' })
  set_explorer_column('left', true)
  local window = layout.window_showing(child, buffers.files)
  local second = loaded_file('second.txt')

  child.lua([[require('aineo.layout').show_file(...)]], { second })

  eq(layout.window_showing(child, second), window)
  eq(layout.window_count(child), 4)
end

T['changing the explorer column’s side'] = MiniTest.new_set()

T['changing the explorer column’s side']['takes the file column along'] = function()
  local buffers = open_with_file('left', 'left', true)

  set_explorer_column('right', true)

  eq(from_the_left(buffers, COLUMN_NAMES), { 'claude', 'report', 'files', 'explorer' })
end

T['a file column of two windows'] = MiniTest.new_set()

T['a file column of two windows']['moves beside the explorer as one column'] = function()
  local buffers = open_with_file(false, 'left', true)
  child.lua([[vim.api.nvim_set_current_win(...)]], { layout.window_showing(child, buffers.files) })
  child.cmd('split')
  local windows = child.lua_get('vim.api.nvim_tabpage_list_wins(0)')

  set_explorer_column('left', true)

  local first = box_of(buffers.files)
  eq(first.col, WIDTH + 1)
  eq(layout.window_count(child), #windows + 1)
  eq(
    child.lua_get(
      [[(function(column)
        local count = 0
        for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if vim.api.nvim_win_get_position(window)[2] == column then
            count = count + 1
          end
        end
        return count
      end)(...)]],
      { WIDTH + 1 }
    ),
    2
  )
end

T['an explorer column closed by hand'] = MiniTest.new_set()

T['an explorer column closed by hand']['sends the file column back to the centre until it opens again'] = function()
  local buffers = open_with_file('left', 'left', true)

  child.lua(
    [[vim.api.nvim_win_close(..., false)]],
    { layout.window_showing(child, buffers.explorer) }
  )
  child.lua([[require('aineo.layout').show_file(...)]], { buffers.files })

  eq(from_the_left(buffers, { 'files', 'claude', 'report' }), { 'claude', 'files', 'report' })
  eq(layout.window_count(child), 3 + 1)

  child.lua([[require('aineo.layout').reopen_explorer_column()]])

  eq(from_the_left(buffers, COLUMN_NAMES), { 'explorer', 'files', 'claude', 'report' })
end

T['set_explorer_column()']['refuses a file_beside_explorer that is not a boolean, naming it'] = function()
  open_with('left', 'left', true)

  expect.error(function()
    child.lua([[require('aineo.layout').set_explorer_column('left', 30, 'yes')]])
  end, 'file_beside_explorer:')
end

--- Moves Claude's column to `claude_side` in the child's layout.
---
---@param claude_side string
local function set_claude_side(claude_side)
  child.lua([[require('aineo.layout').set_claude_side(...)]], { claude_side })
end

T['swapping Claude’s side'] = MiniTest.new_set({
  parametrize = {
    { 'left', 'left', { 'explorer', 'files', 'report', 'claude' } },
    { 'left', 'right', { 'explorer', 'files', 'claude', 'report' } },
    { 'right', 'left', { 'report', 'claude', 'files', 'explorer' } },
    { 'right', 'right', { 'claude', 'report', 'files', 'explorer' } },
  },
})

T['swapping Claude’s side']['keeps the file column beside the explorer'] = function(
  column,
  from,
  expected
)
  local buffers = open_with_file(column, from, true)
  local file_window = layout.window_showing(child, buffers.files)

  set_claude_side(from == 'left' and 'right' or 'left')

  eq(from_the_left(buffers, COLUMN_NAMES), expected)
  eq(layout.window_showing(child, buffers.files), file_window)
  eq(box_of(buffers.explorer).width, WIDTH)
end

T['swapping Claude’s side']['keeps a window across the screen where it is'] = function()
  local buffers = open_with_file('left', 'left', true)
  child.cmd('botright 6new')
  local across = child.lua_get('vim.api.nvim_get_current_win()')

  set_claude_side('right')

  local box = layout.box(child, across)
  eq(box.width, layout.COLUMNS)
  expect.equality(box.row > box_of(buffers.files).row, true)
  eq(from_the_left(buffers, COLUMN_NAMES), { 'explorer', 'files', 'report', 'claude' })
end

--- Expects the columns of the child to have the widths the layout gives them
--- at `layout.COLUMNS` cells with the explorer column open: the explorer
--- `WIDTH`, and of the rest, with the two separators of the other columns
--- taken out, a third each for Claude's column and the Report's, the file
--- column what remains.
---
---@param buffers table the buffers of `explorer`, `files`, `claude` and `report`
local function expect_the_layouts_widths(buffers)
  local rest = layout.COLUMNS - WIDTH - 1
  local third = math.floor((rest - 2) / 3)
  eq(box_of(buffers.explorer).width, WIDTH)
  layout.expect_near(box_of(buffers.claude).width, third)
  layout.expect_near(box_of(buffers.report).width, third)
  layout.expect_near(box_of(buffers.files).width, rest - 2 - 2 * third)
end

T['the file column’s width'] = MiniTest.new_set({ parametrize = PLACES })

T['the file column’s width']['is its share when the layout is built with it beside the explorer'] = function(
  column,
  claude_side
)
  local buffers = open_with(column, claude_side, true, true)

  expect_the_layouts_widths(buffers)
end

T['the file column’s width']['is its share once the explorer column turned on'] = function(
  column,
  claude_side
)
  local buffers = open_with_file(false, claude_side, true)

  set_explorer_column(column, true)

  expect_the_layouts_widths(buffers)
end

T['the file column’s width']['is its share once the explorer column turned on with a window across the screen'] = function(
  column,
  claude_side
)
  local buffers = open_with_file(false, claude_side, true)
  child.cmd('botright copen 6')

  set_explorer_column(column, true)

  expect_the_layouts_widths(buffers)
end

T['the file column’s width']['is its share after a swap'] = function(column, claude_side)
  local buffers = open_with_file(column, claude_side, true)

  set_claude_side(claude_side == 'left' and 'right' or 'left')

  expect_the_layouts_widths(buffers)
end

T['the file column’s width']['is its share after the screen shrank'] = function(
  column,
  claude_side
)
  local buffers, arrangement = arrangement_with(column, claude_side, true)
  child.o.columns = 160
  child.cmd('edit ' .. layout.file('first.txt'))
  buffers.files = child.lua_get('vim.api.nvim_get_current_buf()')
  layout.open(child, arrangement)

  child.o.columns = layout.COLUMNS
  vim.wait(200)

  expect_the_layouts_widths(buffers)
end

T['the file column’s width']['is its share once the explorer column changed sides, which ends a full zoom'] = function(
  column,
  claude_side
)
  local buffers = open_with_file(column, claude_side, true)
  child.lua('require("aineo.layout").toggle_full_zoom()')

  set_explorer_column(column == 'left' and 'right' or 'left', true)

  expect_the_layouts_widths(buffers)
end

return T
