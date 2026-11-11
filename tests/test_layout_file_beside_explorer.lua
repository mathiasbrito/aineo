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

T['open() with the file beside the explorer']['refuses a value that is not a boolean, naming it'] = function()
  local _, arrangement = arrangement_with('left', 'left')
  arrangement.file_beside_explorer = 'yes'

  expect.error(function()
    layout.open(child, arrangement)
  end, 'arrangement%.file_beside_explorer:')
end

return T
