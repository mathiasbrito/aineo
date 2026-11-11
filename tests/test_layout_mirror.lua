local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality
local expect = MiniTest.expect

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The width the explorer column is handed.
local WIDTH = 30

--- The names of the columns, in the order the default layout reads them.
local COLUMN_NAMES = { 'claude', 'report', 'files', 'explorer' }

--- Opens the layout in a fresh child as the default layout reads it: Claude
--- Code on the left, the panes column, the file column beside the explorer
--- column at the right edge, with a file in the file column; returns the
--- buffers and the arrangement. `explorer_column` and `beside` replace the
--- explorer column's side and the file column's place.
---
---@param explorer_column? string|false
---@param beside? boolean
---@return table buffers
---@return table arrangement
local function open_default_layout(explorer_column, beside)
  layout.start(child)
  local buffers = layout.stand_ins(child)
  buffers.explorer = layout.named_scratch(child, 'aineo://explorer')
  local arrangement = layout.arrangement(buffers, 'left')
  arrangement.explorer = buffers.explorer
  arrangement.explorer_column = explorer_column == nil and 'right' or explorer_column
  arrangement.explorer_width = WIDTH
  arrangement.file_beside_explorer = beside ~= false
  child.cmd('edit ' .. layout.file('first.txt'))
  buffers.files = child.lua_get('vim.api.nvim_get_current_buf()')
  layout.open(child, arrangement)
  return buffers, arrangement
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

--- Mirrors the child's layout: Claude Code's column on `claude_side` and the
--- explorer column, when there is one, on `explorer_side`, in one pass.
---
---@param claude_side string
---@param explorer_side? string
local function set_column_sides(claude_side, explorer_side)
  child.lua(
    [[(function(claude_side, explorer_side)
      require('aineo.layout').set_column_sides(claude_side, explorer_side)
    end)(...)]],
    { claude_side, explorer_side }
  )
end

T['set_column_sides()'] = MiniTest.new_set()

T['set_column_sides()']['reads the default layout end to end the other way round'] = function()
  local buffers = open_default_layout()

  set_column_sides('right', 'left')

  eq(from_the_left(buffers, COLUMN_NAMES), { 'explorer', 'files', 'report', 'claude' })
end

T['set_column_sides()']['flips back to the layout it started from'] = function()
  local buffers = open_default_layout()

  set_column_sides('right', 'left')
  set_column_sides('left', 'right')

  eq(from_the_left(buffers, COLUMN_NAMES), COLUMN_NAMES)
end

T['set_column_sides()']['keeps the windows, buffers, current window and cursors'] = function()
  local buffers = open_default_layout()
  local windows = {
    explorer = layout.window_showing(child, buffers.explorer),
    files = layout.window_showing(child, buffers.files),
    claude = layout.window_showing(child, buffers.claude),
    report = layout.window_showing(child, buffers.report),
  }
  child.lua([[vim.api.nvim_win_set_cursor(..., { 3, 2 })]], { windows.files })
  layout.enter_window_showing(child, buffers.report)
  local current = child.lua_get('vim.api.nvim_get_current_win()')

  set_column_sides('right', 'left')

  eq({
    explorer = layout.window_showing(child, buffers.explorer),
    files = layout.window_showing(child, buffers.files),
    claude = layout.window_showing(child, buffers.claude),
    report = layout.window_showing(child, buffers.report),
  }, windows)
  eq(child.lua_get('vim.api.nvim_get_current_win()'), current)
  eq(child.lua_get([[vim.api.nvim_win_get_cursor(...)]], { windows.files }), { 3, 2 })
  eq(layout.window_count(child), 5)
end

T['set_column_sides()']['gives the columns the widths of the layout, the file column too'] = function()
  local buffers = open_default_layout()

  set_column_sides('right', 'left')

  local rest = layout.COLUMNS - WIDTH - 1
  local third = math.floor((rest - 2) / 3)
  eq(box_of(buffers.explorer).width, WIDTH)
  layout.expect_near(box_of(buffers.claude).width, third)
  layout.expect_near(box_of(buffers.report).width, third)
  layout.expect_near(box_of(buffers.files).width, rest - 2 - 2 * third)
end

T['set_column_sides()']['keeps a vertical split of the file column'] = function()
  local buffers = open_default_layout()
  layout.enter_window_showing(child, buffers.files)
  child.cmd('vsplit')
  local before = child.lua_get('#vim.api.nvim_tabpage_list_wins(0)')

  set_column_sides('right', 'left')

  eq(layout.window_count(child), before)
  eq(
    child.lua_get(
      [=[(function(buffer)
        local lefts, rows = {}, {}
        for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if vim.api.nvim_win_get_buf(window) == buffer then
            lefts[vim.api.nvim_win_get_position(window)[2]] = true
            rows[vim.api.nvim_win_get_position(window)[1]] = true
          end
        end
        return { #vim.tbl_keys(lefts), #vim.tbl_keys(rows) }
      end)(...)]=],
      { buffers.files }
    ),
    { 2, 1 }
  )
end

T['set_column_sides()']['keeps a window across the screen across the screen'] = function()
  local buffers = open_default_layout()
  child.cmd('botright 6new')
  local across = child.lua_get('vim.api.nvim_get_current_win()')

  set_column_sides('right', 'left')

  local box = layout.box(child, across)
  eq(box.width, layout.COLUMNS)
  expect.equality(box.row > box_of(buffers.files).row, true)
  eq(from_the_left(buffers, COLUMN_NAMES), { 'explorer', 'files', 'report', 'claude' })
end

T['set_column_sides()']['ends a zoom'] = function()
  open_default_layout()
  child.lua('require("aineo.layout").toggle_zoom()')

  set_column_sides('right', 'left')

  eq(child.lua_get('require("aineo.layout").is_zoomed()'), false)
end

T['set_column_sides()']['puts the file column between the other two without the option, the explorer column at its edge'] = function()
  local buffers = open_default_layout('right', false)

  set_column_sides('right', 'left')

  eq(from_the_left(buffers, COLUMN_NAMES), { 'explorer', 'report', 'files', 'claude' })
end

T['set_column_sides()']['makes the explorer column the side it was given, which the layout reports afterwards'] = function()
  open_default_layout()

  set_column_sides('right', 'left')

  eq(child.lua_get([[require('aineo.layout').explorer_column()]]), 'left')
  eq(child.lua_get([[require('aineo.layout').claude_side()]]), 'right')
end

T['set_column_sides()']['acts as a swap of Claude’s side for a layout with no explorer column'] = function()
  local buffers = open_default_layout(false)

  set_column_sides('right', 'left')

  eq(from_the_left(buffers, { 'claude', 'report', 'files' }), { 'report', 'files', 'claude' })
  eq(child.lua_get([[require('aineo.layout').explorer_column()]]), false)
  eq(layout.window_count(child), 4)
end

T['set_column_sides()']['acts as a swap of Claude’s side when no explorer side is given'] = function()
  local buffers = open_default_layout()

  set_column_sides('right')

  eq(from_the_left(buffers, COLUMN_NAMES), { 'report', 'claude', 'files', 'explorer' })
end

T['set_column_sides()']['moves the explorer column alone when Claude’s side is the one it is on'] = function()
  local buffers = open_default_layout()

  set_column_sides('left', 'left')

  eq(from_the_left(buffers, COLUMN_NAMES), { 'explorer', 'files', 'claude', 'report' })
end

T['set_column_sides()']['changes nothing when both sides are those the layout has'] = function()
  local buffers = open_default_layout()
  child.lua('require("aineo.layout").toggle_zoom()')

  set_column_sides('left', 'right')

  eq(child.lua_get('require("aineo.layout").is_zoomed()'), true)
  eq(from_the_left(buffers, COLUMN_NAMES), COLUMN_NAMES)
end

T['set_column_sides()']['changes nothing for a layout with no explorer column asked for its own Claude side'] = function()
  open_default_layout(false)
  child.lua('require("aineo.layout").toggle_zoom()')

  set_column_sides('left', 'left')

  eq(child.lua_get('require("aineo.layout").is_zoomed()'), true)
end

T['set_column_sides()']['only records the sides while no window of the layout is open'] = function()
  layout.start(child)
  local buffers = layout.stand_ins(child)
  buffers.explorer = layout.named_scratch(child, 'aineo://explorer')
  local arrangement = layout.arrangement(buffers, 'left')
  arrangement.explorer = buffers.explorer
  arrangement.explorer_column = 'right'
  arrangement.explorer_width = WIDTH
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  child.cmd('tabnew')
  layout.close_windows(child, buffers, { 'claude', 'report', 'input' })
  child.lua([[vim.api.nvim_win_close(vim.fn.win_findbuf(...)[1], false)]], { buffers.explorer })

  set_column_sides('right', 'left')

  eq(child.lua_get([[require('aineo.layout').claude_side()]]), 'right')
  eq(child.lua_get([[require('aineo.layout').explorer_column()]]), 'left')
end

T['set_column_sides()']['refuses a side that is neither left nor right, naming it'] = function()
  open_default_layout()

  expect.error(function()
    set_column_sides('middle', 'left')
  end, 'claude_side:')
  expect.error(function()
    set_column_sides('right', 'middle')
  end, 'explorer_side:')
end

return T
