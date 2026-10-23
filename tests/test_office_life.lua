local MiniTest = require('mini.test')
local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local layout = dofile('tests/helpers/layout.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')
local office_child = dofile('tests/helpers/office_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- What `show_now()` tells the user, as a warning, when the editor draws no
--- true colours.
local NEEDS_TRUE_COLOUR =
  "aineo: the office needs 'termguicolors' to draw its pixels, and it is off, so it does not show"

--- What `show_now()` tells the user, as a warning, when the editor draws the
--- half blocks two cells wide.
local NEEDS_SINGLE_CELL_BLOCKS =
  "aineo: the office needs 'ambiwidth' to be single to draw its half blocks one cell wide, and it is double, so it does not show"

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

T['with double-width ambiguous characters'] = MiniTest.new_set()

T['with double-width ambiguous characters']['the office does not show when it is asked to, and says why'] = function()
  office_child.open_layout(child)
  office_child.make_office(child)
  child.o.ambiwidth = 'double'

  child.lua([[_G.office.show_now()]])

  eq(shows(), false)
  eq(child.lua_get([[_G.told]]), { { message = NEEDS_SINGLE_CELL_BLOCKS, level = 3 } })
end

T['with double-width ambiguous characters']['the office does not show when the idle time passes, and says nothing'] = function()
  office_child.open_layout(child)
  office_child.enter_the_left_window(child)
  office_child.make_office(
    child,
    "{ pack = 'default', pieces = {}, idle_ms = 1000 }",
    office_child.WAIT_THROUGH_STAND_IN
  )
  child.o.ambiwidth = 'double'

  office_child.let_time_pass(child)

  eq(shows(), false)
  eq(child.lua_get([[_G.told]]), {})
end

T['with double-width ambiguous characters']['the office shows when it is asked to once the option is single'] = function()
  office_child.open_layout(child)
  office_child.make_office(child)
  child.o.ambiwidth = 'double'
  child.lua([[_G.office.show_now()]])

  child.o.ambiwidth = 'single'
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
  office_child.follow_transcript(child, path)
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

T['a tab page left']['has the office ask again which transcript to follow when it starts following again'] = function()
  office_child.open_layout(child)
  office_child.make_office(
    child,
    nil,
    [[{ transcript = function()
      _G.asked = (_G.asked or 0) + 1
      return nil
    end }]]
  )
  child.lua([[_G.office.show_now()]])
  eq(child.lua_get('_G.asked'), 1)

  child.cmd('tabnew')
  child.cmd('tabprevious')

  eq(child.lua_get('_G.asked'), 2)
end

T['a tab page left']['keeps the office on screen for when the tab page is entered again'] = function()
  office_child.open_layout(child)
  office_child.make_office(child)
  child.lua([[_G.office.show_now()]])

  child.cmd('tabnew')
  child.cmd('tabprevious')

  eq(shows(), true)
end

T['a tab page left']['keeps the office on screen when the cursor was in the right side it covers'] = function()
  local buffers = office_child.open_layout(child)
  office_child.make_office(child)
  layout.enter_window_showing(child, buffers.input)
  child.lua([[_G.office.show_now()]])

  child.cmd('tabnew')
  child.cmd('tabprevious')

  eq(shows(), true)
end

T['a tab page left']['has the office run again, with its agent where it was, when the cursor was in the right side it covers'] = function()
  local path = transcript_path()
  fake_transcript.append(path, RECORDED_TURN)
  local buffers = office_child.open_layout(child)
  office_child.make_office(child)
  office_child.follow_transcript(child, path)
  layout.enter_window_showing(child, buffers.input)
  child.lua([[_G.office.show_now()]])
  local running = handles()
  eq(office_cells.is_on_the_sofa(child), true)

  child.cmd('tabnew')
  child.cmd('tabprevious')

  eq(handles(), running)
  eq(office_cells.is_on_the_sofa(child), true)
end

T['a tab page left']['still closes the office when the cursor enters the right side after the tab page was entered again'] = function()
  local buffers = office_child.open_layout(child)
  office_child.make_office(child)
  layout.enter_window_showing(child, buffers.input)
  child.lua([[_G.office.show_now()]])
  child.cmd('tabnew')
  child.cmd('tabprevious')
  layout.enter_window_showing(child, buffers.claude)

  layout.enter_window_showing(child, buffers.report)

  eq(
    vim.wait(PATIENCE_MS, function()
      return not shows()
    end, 10),
    true
  )
end

T['a tab page left']['has the office catch up with what the session did while it was away'] = function()
  local path = transcript_path()
  fake_transcript.append(path, vim.list_slice(RECORDED_TURN, 1, 5))
  office_child.open_layout(child)
  office_child.make_office(child)
  office_child.follow_transcript(child, path)
  child.lua([[_G.office.show_now()]])
  vim.wait(PATIENCE_MS, function()
    return office_cells.is_typing(child)
  end, 10)

  child.cmd('tabnew')
  fake_transcript.append(path, vim.list_slice(RECORDED_TURN, 6, 10))
  child.cmd('tabprevious')

  eq(
    vim.wait(2 * PATIENCE_MS, function()
      return office_cells.is_on_the_sofa(child)
    end, 10),
    true
  )
end

--- The source of the options that give the office the right side `_G.area`
--- holds in the child, which a case sets.
local RIGHT_SIDE_OF_THE_CASE = '{ right_side = function() return vim.deepcopy(_G.area) end }'

--- Shows an office over an area of `width` by `height` cells.
---
---@param width integer
---@param height integer
local function show_over_an_area_of(width, height)
  office_child.open_layout(child)
  child.lua(
    [[_G.area = { row = 0, col = 0, width = ..., height = select(2, ...) }]],
    { width, height }
  )
  office_child.make_office(child, nil, RIGHT_SIDE_OF_THE_CASE)
  child.lua([[_G.office.show_now()]])
end

--- The lines of the office's buffer.
---
---@return string[]
local function office_lines()
  return child.lua_get(
    [[vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(...), 0, -1, false)]],
    { office_cells.window(child) }
  )
end

--- What the office says in its first line when its window is too small.
local TOO_SMALL = 'This window is too small for the office: it needs 60 by 24 cells.'

--- What the first line of the office says in a window `width` cells wide: the
--- sentence, cut with a mark when the window is narrower than it.
---
---@param width integer
---@return string
local function first_line_in(width)
  if #TOO_SMALL <= width then
    return TOO_SMALL
  end
  return TOO_SMALL:sub(1, width - 1) .. '…'
end

T['a window of the size the office needs'] = MiniTest.new_set()

T['a window too small'] = MiniTest.new_set({
  parametrize = { { 59, 30 }, { 100, 23 }, { 10, 3 } },
})

T['a window too small']['shows one line saying so, and no scene'] = function(width, height)
  show_over_an_area_of(width, height)

  local lines = office_lines()

  eq(#lines, height)
  eq(lines[1], first_line_in(width))
  eq(table.concat(vim.list_slice(lines, 2)), '')
end

T['a window too small']['draws the scene once the window grows to the size the office needs'] = function(
  width,
  height
)
  show_over_an_area_of(width, height)

  child.lua([[_G.area.width = 100; _G.area.height = 30]])
  child.cmd('doautocmd VimResized')

  eq(
    vim.wait(PATIENCE_MS, function()
      return office_lines()[1]:find('▀', 1, true) ~= nil
    end, 10),
    true
  )
end

T['a window of the size the office needs']['draws the scene'] = function()
  show_over_an_area_of(60, 24)

  eq(
    vim.wait(PATIENCE_MS, function()
      return office_lines()[1]:find('▀', 1, true) ~= nil
    end, 10),
    true
  )
end

T['a window of the size the office needs']['says it is too small once it shrinks below'] = function()
  show_over_an_area_of(100, 30)

  child.lua([[_G.area.width = 59]])
  child.cmd('doautocmd VimResized')

  eq(
    vim.wait(PATIENCE_MS, function()
      return office_lines()[1] == first_line_in(59)
    end, 10),
    true
  )
end

return T
