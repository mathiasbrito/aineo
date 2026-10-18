local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The winbar the arrangements below hand the layout for the run pane's
--- windows.
local RUN_WINBAR = '%f'

--- Starts the child and opens the layout in it with the stand-ins, the changes
--- pane's stand-ins and `count` terminals for the run pane; returns every
--- buffer the layout was handed or made, by name, and the arrangement.
---
---@param count? integer how many terminals the run pane stacks, 3 by default
---@return table buffers `claude`, `report`, `input`, `files`, `commits`, `shell` and `run`
---@return table arrangement
local function open_every_pane(count)
  layout.start(child)
  local buffers = layout.stand_ins(child)
  buffers.files = layout.named_scratch(child, 'aineo://changes-files')
  buffers.commits = layout.named_scratch(child, 'aineo://changes-commits')
  buffers.shell = layout.terminal(child)
  buffers.run = {}
  for index = 1, count or 3 do
    buffers.run[index] = layout.terminal(child)
  end
  local arrangement = layout.arrangement(buffers)
  arrangement.changes = { files = buffers.files, commits = buffers.commits }
  arrangement.shell = buffers.shell
  arrangement.run = { buffers = buffers.run, winbar = RUN_WINBAR }
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  return buffers, arrangement
end

--- Shows `pane` in the child's right column.
---
---@param pane string
---@param arrangement table
local function show_pane(pane, arrangement)
  child.lua([[require('aineo.layout').show_pane(...)]], { pane, arrangement })
end

--- What the layout tells the user when the cursor is in none of the right
--- column's windows.
local NOT_IN_THE_COLUMN =
  'aineo: nothing zoomed — zoom takes a window of the right column, and the cursor is in another window'

--- Toggles the zoom of the window the child's cursor is in and returns what
--- the layout told the user meanwhile through `vim.notify()`, each
--- notification as its message and level, and the error it raised, if it did.
---
---@return { message: string?, level: integer?, error: string? }[] told
local function toggle_zoom()
  return child.lua_get([[(function()
    local told = {}
    local notify = vim.notify
    vim.notify = function(message, level)
      table.insert(told, { message = message, level = level })
    end
    local succeeded, failure = pcall(require('aineo.layout').toggle_zoom)
    vim.notify = notify
    if not succeeded then
      table.insert(told, { error = failure })
    end
    return told
  end)()]])
end

--- Puts the child's cursor in the first window showing `buffer`.
---
---@param buffer integer
local function enter(buffer)
  layout.enter_window_showing(child, buffer)
end

--- The text heights of the first windows showing `buffers`, in the order
--- given: the lines each shows, a winbar not counted.
---
---@param buffers integer[]
---@return integer[] heights
local function heights_of(buffers)
  return child.lua_get(
    [[vim.tbl_map(function(buffer)
      return vim.fn.winheight(vim.fn.bufwinid(buffer))
    end, ...)]],
    { buffers }
  )
end

--- The text height a zoomed window of the stack showing `buffers` takes: the
--- lines the stack shows together, less the one line each of the others keeps.
--- The lines the windows show together do not change as one is zoomed: the
--- winbars and the status lines stay.
---
---@param buffers integer[]
---@return integer height
local function zoomed_height(buffers)
  local lines = 0
  for _, height in ipairs(heights_of(buffers)) do
    lines = lines + height
  end
  return lines - (#buffers - 1)
end

--- The buffers the windows of each pane show, top to bottom, by the pane.
---
---@param buffers table as `open_every_pane()` returns them
---@return table<string, integer[]>
local function stacks_of(buffers)
  return {
    agent = { buffers.report, buffers.input },
    changes = { buffers.files, buffers.commits },
    terminal = { buffers.shell },
    run = buffers.run,
  }
end

--- The heights the windows of a stack of `count` take while the one at
--- `position` is zoomed: `zoomed` for it, one line for each of the others.
---
---@param count integer
---@param position integer
---@param zoomed integer
---@return integer[] heights
local function heights_zoomed_at(count, position, zoomed)
  local heights = {}
  for index = 1, count do
    heights[index] = index == position and zoomed or 1
  end
  return heights
end

T['zooming a window'] = MiniTest.new_set()

for _, case in ipairs({
  { pane = 'agent', position = 1 },
  { pane = 'agent', position = 2 },
  { pane = 'changes', position = 1 },
  { pane = 'changes', position = 2 },
  { pane = 'terminal', position = 1 },
  { pane = 'run', position = 1 },
  { pane = 'run', position = 2 },
  { pane = 'run', position = 3 },
}) do
  T['zooming a window'][('gives the window %d of the %s pane the column’s height, the others one line'):format(
    case.position,
    case.pane
  )] = function()
    local buffers, arrangement = open_every_pane()
    show_pane(case.pane, arrangement)
    local stack = stacks_of(buffers)[case.pane]
    local height = zoomed_height(stack)
    enter(stack[case.position])

    local told = toggle_zoom()

    eq(told, {})
    eq(heights_of(stack), heights_zoomed_at(#stack, case.position, height))
  end
end

T['zooming a window']['leaves the others at the height of ’winminheight’ when that is above one line'] = function()
  local buffers = open_every_pane()
  child.o.winheight = 4
  child.o.winminheight = 4
  local lines = heights_of({ buffers.report, buffers.input })
  enter(buffers.report)

  toggle_zoom()

  eq(heights_of({ buffers.report, buffers.input }), { lines[1] + lines[2] - 4, 4 })
end

T['toggling the zoom'] = MiniTest.new_set()

for _, pane in ipairs({ 'agent', 'changes', 'run' }) do
  T['toggling the zoom'][('gives the %s pane’s windows back the heights they had, a manual resize included'):format(
    pane
  )] = function()
    local buffers, arrangement = open_every_pane()
    show_pane(pane, arrangement)
    local stack = stacks_of(buffers)[pane]
    enter(stack[1])
    child.lua(
      [[local window = vim.fn.bufwinid(...)
      vim.api.nvim_win_set_height(window, vim.api.nvim_win_get_height(window) - 3)]],
      { stack[1] }
    )
    local resized = heights_of(stack)

    toggle_zoom()
    toggle_zoom()

    eq(heights_of(stack), resized)
  end
end

T['moving the cursor while zoomed'] = MiniTest.new_set()

T['moving the cursor while zoomed']['keeps the zoom on the window that was zoomed'] = function()
  local buffers = open_every_pane()
  enter(buffers.report)
  toggle_zoom()
  local zoomed = heights_of({ buffers.report, buffers.input })

  enter(buffers.input)
  enter(buffers.claude)

  eq(heights_of({ buffers.report, buffers.input }), zoomed)
end

T['moving the cursor while zoomed']['lets the zoom move to the window the cursor is in'] = function()
  local buffers = open_every_pane()
  local height = zoomed_height({ buffers.report, buffers.input })
  enter(buffers.report)
  toggle_zoom()
  enter(buffers.input)

  toggle_zoom()

  eq(heights_of({ buffers.report, buffers.input }), { 1, height })
end

T['moving the cursor while zoomed']['gives back the heights from before the first zoom when the moved zoom is toggled off'] = function()
  local buffers = open_every_pane()
  local before = heights_of({ buffers.report, buffers.input })
  enter(buffers.report)
  toggle_zoom()
  enter(buffers.input)
  toggle_zoom()

  toggle_zoom()

  eq(heights_of({ buffers.report, buffers.input }), before)
end

T['toggling the zoom outside the right column'] = MiniTest.new_set()

T['toggling the zoom outside the right column']['tells the user once and changes no height'] = function()
  local buffers = open_every_pane()
  local before = heights_of({ buffers.report, buffers.input })
  enter(buffers.claude)

  local told = toggle_zoom()

  eq(told, { { message = NOT_IN_THE_COLUMN, level = 3 } })
  eq(heights_of({ buffers.report, buffers.input }), before)
end

T['switching the pane while zoomed'] = MiniTest.new_set()

for _, switch in ipairs({
  { from = 'agent', to = 'changes' },
  { from = 'changes', to = 'agent' },
  { from = 'agent', to = 'run' },
  { from = 'agent', to = 'terminal' },
}) do
  T['switching the pane while zoomed'][('ends the zoom of the %s pane as the %s pane shows'):format(
    switch.from,
    switch.to
  )] = function()
    local buffers, arrangement = open_every_pane()
    show_pane(switch.from, arrangement)
    local stack = stacks_of(buffers)[switch.from]
    local before = heights_of(stack)
    enter(stack[1])
    toggle_zoom()

    show_pane(switch.to, arrangement)
    show_pane(switch.from, arrangement)

    eq(heights_of(stack), before)
  end
end

T['switching the pane while zoomed']['leaves the zoom as it is when the pane asked for is the one shown'] = function()
  local buffers, arrangement = open_every_pane()
  enter(buffers.report)
  toggle_zoom()
  local zoomed = heights_of({ buffers.report, buffers.input })

  show_pane('agent', arrangement)

  eq(heights_of({ buffers.report, buffers.input }), zoomed)
end

T['switching the pane while zoomed']['makes the next toggle zoom again rather than end a zoom that was over'] = function()
  local buffers, arrangement = open_every_pane()
  enter(buffers.report)
  toggle_zoom()
  local zoomed = heights_of({ buffers.report, buffers.input })
  show_pane('changes', arrangement)
  show_pane('agent', arrangement)
  enter(buffers.report)

  toggle_zoom()

  eq(heights_of({ buffers.report, buffers.input }), zoomed)
end

--- Expects the next toggle of the zoom, with the cursor in the first window
--- showing the first of `stack`, to zoom that window of the stack: the zoom
--- the stack had was over.
---
---@param stack integer[]
local function expect_next_toggle_to_zoom(stack)
  local height = zoomed_height(stack)
  enter(stack[1])

  toggle_zoom()

  eq(heights_of(stack), heights_zoomed_at(#stack, 1, height))
end

--- The arrangement of `arrangement` with `buffers` as the run pane's
--- terminals.
---
---@param arrangement table
---@param buffers integer[]
---@return table
local function with_run_terminals(arrangement, buffers)
  return vim.tbl_extend('force', arrangement, { run = { buffers = buffers, winbar = RUN_WINBAR } })
end

T['changing the windows of the run pane while zoomed'] = MiniTest.new_set()

T['changing the windows of the run pane while zoomed']['ends the zoom as a process’s window opens, the windows sharing the column'] = function()
  local buffers, arrangement = open_every_pane(2)
  show_pane('run', arrangement)
  enter(buffers.run[1])
  toggle_zoom()
  local added = layout.terminal(child)
  local grown = vim.list_extend(vim.list_slice(buffers.run), { added })

  show_pane('run', with_run_terminals(arrangement, grown))

  local heights = heights_of(grown)
  layout.expect_near(heights[1], heights[2])
  layout.expect_near(heights[2], heights[3])
  expect_next_toggle_to_zoom(grown)
end

T['changing the windows of the run pane while zoomed']['ends the zoom as a process’s window closes, the windows sharing the column'] = function()
  local buffers, arrangement = open_every_pane(3)
  show_pane('run', arrangement)
  enter(buffers.run[1])
  toggle_zoom()
  local shrunk = vim.list_slice(buffers.run, 1, 2)

  show_pane('run', with_run_terminals(arrangement, shrunk))

  local heights = heights_of(shrunk)
  layout.expect_near(heights[1], heights[2])
  expect_next_toggle_to_zoom(shrunk)
end

T['changing the windows of the run pane while zoomed']['keeps the zoom when the processes are the same'] = function()
  local buffers, arrangement = open_every_pane(3)
  show_pane('run', arrangement)
  enter(buffers.run[2])
  toggle_zoom()
  local zoomed = heights_of(buffers.run)

  show_pane('run', arrangement)

  eq(heights_of(buffers.run), zoomed)
end

T['closing a window of the column while zoomed'] = MiniTest.new_set()

T['closing a window of the column while zoomed']['ends the zoom, the windows left sharing the column'] = function()
  local buffers, arrangement = open_every_pane(3)
  show_pane('run', arrangement)
  enter(buffers.run[1])
  toggle_zoom()

  child.lua('vim.api.nvim_win_close(vim.fn.bufwinid(...), false)', { buffers.run[3] })

  local heights = heights_of({ buffers.run[1], buffers.run[2] })
  layout.expect_near(heights[1], heights[2])
  expect_next_toggle_to_zoom({ buffers.run[1], buffers.run[2] })
end

T['resizing the editor while zoomed'] = MiniTest.new_set()

for _, pane in ipairs({ 'agent', 'run' }) do
  T['resizing the editor while zoomed'][('keeps the %s pane’s window zoomed, taking the rows the editor gained'):format(
    pane
  )] = function()
    local buffers, arrangement = open_every_pane()
    show_pane(pane, arrangement)
    local stack = stacks_of(buffers)[pane]
    enter(stack[1])
    toggle_zoom()
    local zoomed = heights_of(stack)[1]

    child.o.lines = layout.LINES + 6

    eq(heights_of(stack), heights_zoomed_at(#stack, 1, zoomed + 6))
  end
end

T['closing a window of the column while zoomed']['leaves a later toggle to zoom the window left, when the layout is open no more'] = function()
  local buffers = open_every_pane()
  enter(buffers.report)
  toggle_zoom()
  layout.close_windows(child, buffers, { 'claude', 'report' })
  enter(buffers.input)

  local told = toggle_zoom()

  eq(told, {})
end

T['closing a window of the column while zoomed']['zooms the window the cursor is in, not ends a zoom that was over, when the layout is open no more'] = function()
  local buffers, arrangement = open_every_pane(3)
  show_pane('run', arrangement)
  enter(buffers.run[1])
  toggle_zoom()
  layout.close_windows(
    child,
    { claude = buffers.claude, run3 = buffers.run[3] },
    { 'claude', 'run3' }
  )
  local left = { buffers.run[1], buffers.run[2] }
  local height = zoomed_height(left)

  toggle_zoom()

  eq(heights_of(left), { height, 1 })
end

return T
