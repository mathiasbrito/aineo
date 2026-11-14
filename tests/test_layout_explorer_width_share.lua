local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The explorer column's setting when a test hands the layout a share: a
--- quarter of the screen.
local QUARTER = 1 / 4

--- Opens the layout in a fresh child whose screen is `columns` wide, the
--- explorer column on the right at `explorer_width`, and, when `with_file`,
--- a file in the file column; returns the buffers by name.
---
---@param columns integer
---@param explorer_width number the setting: a count or a share
---@param with_file? boolean
---@return table buffers `claude`, `report`, `explorer` and, with a file, `file`
local function open_at(columns, explorer_width, with_file)
  layout.start(child)
  child.o.columns = columns
  local buffers = layout.stand_ins(child)
  buffers.explorer = layout.named_scratch(child, 'aineo://explorer')
  buffers.files = layout.named_scratch(child, 'aineo://changes-files')
  buffers.commits = layout.named_scratch(child, 'aineo://changes-commits')
  if with_file then
    child.cmd('edit ' .. layout.file('first.txt'))
    buffers.file = child.lua_get('vim.api.nvim_get_current_buf()')
  end
  local arrangement = layout.arrangement(buffers, 'left')
  arrangement.explorer = buffers.explorer
  arrangement.explorer_column = 'right'
  arrangement.explorer_width = explorer_width
  arrangement.changes = { files = buffers.files, commits = buffers.commits }
  layout.open(child, arrangement)
  return buffers
end

--- The width of the window showing `buffer` in the child's current tab.
---
---@param buffer integer
---@return integer
local function width_of(buffer)
  return layout.box(child, layout.window_showing(child, buffer)).width
end

T['an explorer width that is a share'] = MiniTest.new_set()

T['an explorer width that is a share']['takes that share of a wide screen'] = function()
  local buffers = open_at(240, QUARTER)

  eq(width_of(buffers.explorer), 60)
end

T['an explorer width that is a share']['never takes fewer than 40 columns'] = function()
  local buffers = open_at(120, QUARTER)

  eq(width_of(buffers.explorer), 40)
end

T['an explorer width that is a share']['rounds the columns down'] = function()
  local buffers = open_at(250, 1 / 3)

  eq(width_of(buffers.explorer), 83)
end

T['an explorer width that is a count'] = MiniTest.new_set()

T['an explorer width that is a count']['is used as it is, whatever the screen'] = function()
  local buffers = open_at(240, 50)

  eq(width_of(buffers.explorer), 50)
end

T['an explorer width that is a count']['of 1 is one column, not the whole screen'] = function()
  local buffers = open_at(240, 1)

  eq(width_of(buffers.explorer), 1)
end

T['an explorer width that is a share']['follows the screen as it is resized'] = function()
  local buffers = open_at(240, QUARTER)

  child.o.columns = 200

  eq(width_of(buffers.explorer), 50)
end

T['an explorer width that is a share']['follows the screen as it is resized while the file focus is on'] = function()
  local buffers = open_at(240, QUARTER, true)
  child.lua([[require('aineo.layout').start_file_focus()]])

  child.o.columns = 200

  eq(width_of(buffers.explorer), 50)
end

T['an explorer width that is a share']['is resolved again as a full zoom ends after a resize'] = function()
  local buffers = open_at(240, QUARTER)
  child.lua('require("aineo.layout").toggle_full_zoom()')

  child.o.columns = 200
  child.lua('require("aineo.layout").toggle_full_zoom()')

  eq(width_of(buffers.explorer), 50)
end

T['an explorer width that is a share']['is taken by set_explorer_column()'] = function()
  local buffers = open_at(240, 30)

  child.lua([[require('aineo.layout').set_explorer_column('right', ...)]], { QUARTER })

  eq(width_of(buffers.explorer), 60)
end

T['an explorer width that is a share']['is refused by the arrangement when it is not between 0 and 1'] = function()
  layout.start(child)
  local buffers = layout.stand_ins(child)
  buffers.explorer = layout.named_scratch(child, 'aineo://explorer')
  local arrangement = layout.arrangement(buffers, 'left')
  arrangement.explorer = buffers.explorer
  arrangement.explorer_column = 'right'
  arrangement.explorer_width = -0.2

  MiniTest.expect.error(function()
    layout.open(child, arrangement)
  end, 'arrangement%.explorer_width')
end

return T
