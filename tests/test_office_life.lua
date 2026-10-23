local MiniTest = require('mini.test')
local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')
local office_child = dofile('tests/helpers/office_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- What `show_now()` tells the user, as a warning, when the editor draws no
--- true colours.
local NEEDS_TRUE_COLOUR =
  "aineo: the office needs 'termguicolors' to draw its pixels, and it is off, so it does not show"

--- How long a wait for something that should happen may last, in milliseconds.
local PATIENCE_MS = 4000

--- The recorded turn: a prompt, a call, its result and the turn's end.
local RECORDED_TURN = fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl')

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

--- The text of a transcript, in a directory of the case's own.
---
---@return string path
local function transcript_path()
  return vim.fs.joinpath(fixture.directory('office_life'), 'session.jsonl')
end

--- The repeating timers and the file watches open in the child.
---
---@return { timers: integer, watches: integer }
local function handles()
  return {
    timers = office_cells.open_repeating_timers(child),
    watches = office_cells.open_handles(child, 'fs_event'),
  }
end

T['a tab page left'] = MiniTest.new_set()

T['a tab page left']['pauses the frame timer and the watch of its office, which entering it again starts'] = function()
  local path = transcript_path()
  fake_transcript.append(path, vim.list_slice(RECORDED_TURN, 1, 5))
  office_child.open_layout(child)
  office_child.make_office(child)
  child.lua([[_G.office.follow_session(...)]], { path })
  local hidden = handles()
  child.lua([[_G.office.show_now()]])
  local shown = handles()

  child.cmd('tabnew')
  local away = handles()
  child.cmd('tabprevious')

  eq(away, hidden)
  eq(handles(), shown)
  eq(shown.timers > hidden.timers and shown.watches > hidden.watches, true)
end

T['a tab page left']['keeps the office on screen for when the tab page is entered again'] = function()
  office_child.open_layout(child)
  office_child.make_office(child)
  child.lua([[_G.office.show_now()]])

  child.cmd('tabnew')
  child.cmd('tabprevious')

  eq(shows(), true)
end

T['a tab page left']['has the office catch up with what the session did while it was away'] = function()
  local path = transcript_path()
  fake_transcript.append(path, vim.list_slice(RECORDED_TURN, 1, 5))
  office_child.open_layout(child)
  office_child.make_office(child)
  child.lua([[_G.office.follow_session(...)]], { path })
  child.lua([[_G.office.show_now()]])
  vim.wait(PATIENCE_MS, function()
    return office_cells.is_typing(child)
  end, 10)

  child.cmd('tabnew')
  fake_transcript.append(path, vim.list_slice(RECORDED_TURN, 6, 10))
  child.cmd('tabprevious')

  eq(
    vim.wait(PATIENCE_MS, function()
      return office_cells.is_standing(child)
    end, 10),
    true
  )
end

return T
