local MiniTest = require('mini.test')
local office_cells = dofile('tests/helpers/office_cells.lua')
local office_child = dofile('tests/helpers/office_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- What `show_now()` tells the user, as a warning, when the editor draws no
--- true colours.
local NEEDS_TRUE_COLOUR =
  "aineo: the office needs 'termguicolors' to draw its pixels, and it is off, so it does not show"

--- Whether the office shows.
---
---@return boolean
local function shows()
  return office_cells.window(child) ~= vim.NIL
end

T['without true colours'] = MiniTest.new_set()

T['without true colours']['the office does not show when it is asked to, and says why'] = function()
  office_child.open_layout(child)
  office_child.make_office(child)
  child.o.termguicolors = false

  child.lua([[_G.office.show_now()]])

  eq(shows(), false)
  eq(child.lua_get([[_G.told]]), { { message = NEEDS_TRUE_COLOUR, level = 3 } })
end

T['without true colours']['the office does not show when the idle time passes, and says nothing'] = function()
  office_child.open_layout(child)
  office_child.enter_the_left_window(child)
  office_child.make_office(
    child,
    "{ pack = 'default', pieces = {}, idle_ms = 1000 }",
    office_child.WAIT_THROUGH_STAND_IN
  )
  child.o.termguicolors = false

  office_child.let_time_pass(child)

  eq(shows(), false)
  eq(child.lua_get([[_G.told]]), {})
end

T['without true colours']['the office shows when it is asked to once the option is on'] = function()
  office_child.open_layout(child)
  office_child.make_office(child)
  child.o.termguicolors = false
  child.lua([[_G.office.show_now()]])

  child.o.termguicolors = true
  child.lua([[_G.office.show_now()]])

  eq(shows(), true)
end

return T
