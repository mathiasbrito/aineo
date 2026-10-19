local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The winbar the arrangements below hand the layout for the run pane's
--- windows.
local RUN_WINBAR = '%f'

--- What the layout tells the user when the cursor is in no window of an
--- aineo tab page, or in a floating window.
local NOTHING_TO_ZOOM =
  'aineo: nothing zoomed — the cursor is in no window of an aineo tab page, or in a floating window'

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

--- Toggles the full zoom of the window the child's cursor is in and returns
--- what the layout told the user meanwhile through `vim.notify()`, each
--- notification as its message and level, and the error it raised, if it did.
---
---@return { message: string?, level: integer?, error: string? }[] told
local function toggle_full_zoom()
  return child.lua_get([[(function()
    local told = {}
    local notify = vim.notify
    vim.notify = function(message, level)
      table.insert(told, { message = message, level = level })
    end
    local succeeded, failure = pcall(require('aineo.layout').toggle_full_zoom)
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

--- The text width and height of every window of the child's current tab, as
--- a list in the order the tab lists its windows.
---
---@return { width: integer, height: integer }[] sizes
local function sizes()
  return child.lua_get([[vim.tbl_map(function(window)
    return { width = vim.api.nvim_win_get_width(window), height = vim.api.nvim_win_get_height(window) }
  end, vim.api.nvim_tabpage_list_wins(0))]])
end

--- The sizes of the windows showing `buffers`, in the order given.
---
---@param buffers integer[]
---@return { width: integer, height: integer }[]
local function sizes_of(buffers)
  return child.lua_get(
    [[vim.tbl_map(function(buffer)
      local window = vim.fn.bufwinid(buffer)
      return { width = vim.api.nvim_win_get_width(window), height = vim.api.nvim_win_get_height(window) }
    end, ...)]],
    { buffers }
  )
end

--- Whether the window showing `buffer` is at the least size Neovim gives a
--- window in one direction at least: the text width `'winminwidth'` or the
--- text height `'winminheight'`, a winbar not counted.
---
---@param buffer integer
---@return boolean
local function is_at_its_least(buffer)
  return child.lua_get(
    [[(function(buffer)
      local window = vim.fn.bufwinid(buffer)
      return vim.fn.winwidth(window) == vim.o.winminwidth
        or vim.fn.winheight(window) == vim.o.winminheight
    end)(...)]],
    { buffer }
  )
end

--- Expects the window showing `buffer` to be zoomed fully in a tab page of two
--- columns: it holds the screen's width less the other column at its least
--- and the separator.
---
---@param buffer integer
local function expect_zoomed(buffer)
  eq(sizes_of({ buffer })[1].width, layout.COLUMNS - child.o.winminwidth - 1)
end

T['zooming a window fully'] = MiniTest.new_set()

for _, case in ipairs({
  { role = 'claude', others = { 'report', 'input' } },
  { role = 'report', others = { 'claude', 'input' } },
  { role = 'input', others = { 'claude', 'report' } },
}) do
  T['zooming a window fully'][('shrinks every other window to its least size when the cursor is in the %s window'):format(
    case.role
  )] = function()
    local buffers = open_every_pane()
    enter(buffers[case.role])

    local told = toggle_full_zoom()

    eq(told, {})
    eq(is_at_its_least(buffers[case.others[1]]), true)
    eq(is_at_its_least(buffers[case.others[2]]), true)
  end
end

for _, case in ipairs({
  { role = 'claude', column = { 'claude' } },
  { role = 'report', column = { 'report', 'input' } },
  { role = 'input', column = { 'report', 'input' } },
}) do
  T['zooming a window fully'][('gives the %s window every column and row the others can spare'):format(
    case.role
  )] = function()
    local buffers = open_every_pane()
    local column = vim.tbl_map(function(role)
      return buffers[role]
    end, case.column)
    local rows = 0
    for _, size in ipairs(sizes_of(column)) do
      rows = rows + size.height
    end
    enter(buffers[case.role])

    toggle_full_zoom()

    eq(sizes_of({ buffers[case.role] }), {
      {
        width = layout.COLUMNS - child.o.winminwidth - 1,
        height = rows - (#column - 1) * child.o.winminheight,
      },
    })
  end
end

T['toggling the full zoom'] = MiniTest.new_set()

T['toggling the full zoom']['gives every window back the size it had, a manual resize included'] = function()
  local buffers = open_every_pane()
  child.lua(
    [[local report = vim.fn.bufwinid(...)
    vim.api.nvim_win_set_height(report, vim.api.nvim_win_get_height(report) - 3)
    vim.api.nvim_win_set_width(report, vim.api.nvim_win_get_width(report) + 5)]],
    { buffers.report }
  )
  local resized = sizes()
  enter(buffers.report)

  toggle_full_zoom()
  expect_zoomed(buffers.report)
  toggle_full_zoom()

  eq(sizes(), resized)
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

--- Shows a scratch buffer in the file column, which opens right of Claude's
--- column, and returns the buffer.
---
---@return integer diff
local function open_file_column()
  local diff = layout.named_scratch(child, 'aineo://full-zoom-file')
  child.lua([[require('aineo.layout').show_diff(...)]], { diff })
  return diff
end

T['zooming a window fully in each pane'] = MiniTest.new_set()

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
  T['zooming a window fully in each pane'][('gives every window back its size after window %d of the %s pane is zoomed'):format(
    case.position,
    case.pane
  )] = function()
    local buffers, arrangement = open_every_pane()
    show_pane(case.pane, arrangement)
    open_file_column()
    local before = sizes()
    enter(stacks_of(buffers)[case.pane][case.position])

    toggle_full_zoom()
    local zoomed = sizes()
    toggle_full_zoom()

    MiniTest.expect.no_equality(zoomed, before)
    eq(sizes(), before)
  end
end

T['zooming a window fully in each pane']['takes the file column’s window to every cell the others can spare'] = function()
  local buffers = open_every_pane()
  local diff = open_file_column()
  enter(diff)

  toggle_full_zoom()

  eq(sizes_of({ diff })[1].width, layout.COLUMNS - 2 * (child.o.winminwidth + 1))
  eq(is_at_its_least(buffers.claude), true)
  eq(is_at_its_least(buffers.report), true)
  eq(is_at_its_least(buffers.input), true)
end

--- Toggles the zoom of the right column's window the cursor is in.
local function toggle_column_zoom()
  child.lua([[require('aineo.layout').toggle_zoom()]])
end

T['a zoomed right column'] = MiniTest.new_set()

T['a zoomed right column']['is zoomed again as it was once the full zoom ends'] = function()
  local buffers = open_every_pane()
  enter(buffers.report)
  toggle_column_zoom()
  local column_zoomed = sizes()
  enter(buffers.claude)

  toggle_full_zoom()
  expect_zoomed(buffers.claude)
  toggle_full_zoom()

  eq(sizes(), column_zoomed)
end

T['a zoomed right column']['is ended by the next \\z once the full zoom has ended'] = function()
  local buffers = open_every_pane()
  local before = sizes()
  enter(buffers.report)
  toggle_column_zoom()
  toggle_full_zoom()
  expect_zoomed(buffers.report)
  toggle_full_zoom()

  toggle_column_zoom()

  eq(sizes(), before)
end

T['toggling the column zoom while a window is zoomed fully'] = MiniTest.new_set()

T['toggling the column zoom while a window is zoomed fully']['ends the full zoom and then zooms the column'] = function()
  local buffers = open_every_pane()
  local before = sizes_of({ buffers.claude, buffers.report, buffers.input })
  local column_rows = before[2].height + before[3].height
  enter(buffers.report)
  toggle_full_zoom()
  expect_zoomed(buffers.report)

  toggle_column_zoom()

  eq(sizes_of({ buffers.claude, buffers.report, buffers.input }), {
    before[1],
    { width = before[2].width, height = column_rows - child.o.winminheight },
    { width = before[3].width, height = child.o.winminheight },
  })
end

T['toggling the column zoom while a window is zoomed fully']['leaves the full zoom as it is when the cursor is in none of the column’s windows'] = function()
  local buffers = open_every_pane()
  enter(buffers.claude)
  toggle_full_zoom()
  local zoomed = sizes()

  child.lua([[vim.notify = function() end]])
  toggle_column_zoom()

  eq(sizes(), zoomed)
  toggle_full_zoom()
  MiniTest.expect.no_equality(sizes(), zoomed)
end

T['toggling the full zoom in another window'] = MiniTest.new_set()

T['toggling the full zoom in another window']['moves the zoom to the window the cursor is in'] = function()
  local buffers = open_every_pane()
  local column = sizes_of({ buffers.report, buffers.input })
  enter(buffers.report)
  toggle_full_zoom()
  enter(buffers.input)

  toggle_full_zoom()

  eq(sizes_of({ buffers.claude, buffers.report, buffers.input }), {
    { width = child.o.winminwidth, height = sizes_of({ buffers.claude })[1].height },
    { width = layout.COLUMNS - child.o.winminwidth - 1, height = child.o.winminheight },
    {
      width = layout.COLUMNS - child.o.winminwidth - 1,
      height = column[1].height + column[2].height - child.o.winminheight,
    },
  })
end

T['toggling the full zoom in another window']['gives every window back its size from before the first zoom when the moved zoom is toggled off'] = function()
  local buffers = open_every_pane()
  local before = sizes()
  enter(buffers.report)
  toggle_full_zoom()
  enter(buffers.input)
  toggle_full_zoom()
  expect_zoomed(buffers.input)

  toggle_full_zoom()

  eq(sizes(), before)
end

T['toggling the full zoom where there is nothing to zoom'] = MiniTest.new_set()

T['toggling the full zoom where there is nothing to zoom']['tells the user once from a tab page that is none of the layout’s, and changes no size'] = function()
  local buffers = open_every_pane()
  child.cmd('tabnew')
  child.cmd('tabprevious')
  local before = sizes_of({ buffers.claude, buffers.report, buffers.input })
  child.cmd('tabnext')

  local told = toggle_full_zoom()
  child.cmd('tabprevious')

  eq(told, { { message = NOTHING_TO_ZOOM, level = 3 } })
  eq(sizes_of({ buffers.claude, buffers.report, buffers.input }), before)
end

T['toggling the full zoom where there is nothing to zoom']['tells the user once from a floating window, and changes no size'] = function()
  local buffers = open_every_pane()
  local before = sizes_of({ buffers.claude, buffers.report, buffers.input })
  child.lua([[vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true,
      { relative = 'editor', row = 2, col = 2, width = 10, height = 3 })]])

  local told = toggle_full_zoom()

  eq(told, { { message = NOTHING_TO_ZOOM, level = 3 } })
  eq(sizes_of({ buffers.claude, buffers.report, buffers.input }), before)
end

T['toggling the full zoom where there is nothing to zoom']['tells the user once while the layout was never opened'] = function()
  layout.start(child)

  local told = toggle_full_zoom()

  eq(told, { { message = NOTHING_TO_ZOOM, level = 3 } })
end

T['zooming a window split off by hand fully'] = MiniTest.new_set()

T['zooming a window split off by hand fully']['takes every cell the others can spare, and gives every window its size back'] = function()
  local buffers = open_every_pane()
  enter(buffers.claude)
  child.cmd('split')
  local before = sizes()
  local hand_split = child.lua_get('vim.api.nvim_get_current_win()')

  local told = toggle_full_zoom()
  local zoomed = child.lua_get('vim.api.nvim_win_get_width(...)', { hand_split })
  toggle_full_zoom()

  eq(told, {})
  eq(zoomed, layout.COLUMNS - child.o.winminwidth - 1)
  eq(sizes(), before)
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

--- Expects the next toggle of the full zoom, with the cursor in the first
--- window showing `buffer`, to zoom that window: the zoom there was is over.
---
---@param buffer integer
local function expect_next_toggle_to_zoom(buffer)
  enter(buffer)

  toggle_full_zoom()

  eq(sizes_of({ buffer })[1].width, layout.COLUMNS - child.o.winminwidth - 1)
end

T['switching the pane while zoomed fully'] = MiniTest.new_set()

for _, switch in ipairs({
  { from = 'agent', to = 'changes' },
  { from = 'changes', to = 'agent' },
  { from = 'agent', to = 'run' },
  { from = 'agent', to = 'terminal' },
}) do
  T['switching the pane while zoomed fully'][('ends the zoom of the %s pane as the %s pane shows'):format(
    switch.from,
    switch.to
  )] = function()
    local buffers, arrangement = open_every_pane()
    show_pane(switch.from, arrangement)
    local stack = stacks_of(buffers)[switch.from]
    local before = sizes()
    enter(stack[1])
    toggle_full_zoom()

    show_pane(switch.to, arrangement)
    show_pane(switch.from, arrangement)

    eq(sizes(), before)
    expect_next_toggle_to_zoom(stack[1])
  end
end

T['switching the pane while zoomed fully']['leaves the zoom as it is when the pane asked for is the one shown'] = function()
  local buffers, arrangement = open_every_pane()
  enter(buffers.report)
  toggle_full_zoom()
  expect_zoomed(buffers.report)
  local zoomed = sizes()

  show_pane('agent', arrangement)

  eq(sizes(), zoomed)
end

T['changing the windows of the run pane while zoomed fully'] = MiniTest.new_set()

T['changing the windows of the run pane while zoomed fully']['ends the zoom as a process’s window opens, the windows sharing the column'] = function()
  local buffers, arrangement = open_every_pane(2)
  show_pane('run', arrangement)
  local claude = sizes_of({ buffers.claude })
  enter(buffers.run[1])
  toggle_full_zoom()
  local added = layout.terminal(child)
  local grown = vim.list_extend(vim.list_slice(buffers.run), { added })

  show_pane('run', with_run_terminals(arrangement, grown))

  eq(sizes_of({ buffers.claude }), claude)
  local run = sizes_of(grown)
  layout.expect_near(run[1].height, run[2].height)
  layout.expect_near(run[2].height, run[3].height)
  expect_next_toggle_to_zoom(buffers.run[1])
end

T['changing the windows of the run pane while zoomed fully']['ends the zoom as a process’s window closes, the windows sharing the column'] = function()
  local buffers, arrangement = open_every_pane(3)
  show_pane('run', arrangement)
  local claude = sizes_of({ buffers.claude })
  enter(buffers.run[1])
  toggle_full_zoom()
  local shrunk = vim.list_slice(buffers.run, 1, 2)

  show_pane('run', with_run_terminals(arrangement, shrunk))

  eq(sizes_of({ buffers.claude }), claude)
  local run = sizes_of(shrunk)
  layout.expect_near(run[1].height, run[2].height)
  expect_next_toggle_to_zoom(buffers.run[1])
end

T['changing the windows of the run pane while zoomed fully']['keeps the zoom when the processes are the same'] = function()
  local buffers, arrangement = open_every_pane(3)
  show_pane('run', arrangement)
  enter(buffers.run[2])
  toggle_full_zoom()
  expect_zoomed(buffers.run[2])
  local zoomed = sizes()

  show_pane('run', arrangement)

  eq(sizes(), zoomed)
end

T['closing a window while zoomed fully'] = MiniTest.new_set()

T['closing a window while zoomed fully']['ends the zoom when the window that is zoomed closes, the layout’s proportions put back'] = function()
  local buffers, arrangement = open_every_pane(3)
  show_pane('run', arrangement)
  local claude = sizes_of({ buffers.claude })
  enter(buffers.run[2])
  toggle_full_zoom()

  child.lua('vim.api.nvim_win_close(vim.fn.bufwinid(...), false)', { buffers.run[2] })

  eq(sizes_of({ buffers.claude }), claude)
  local run = sizes_of({ buffers.run[1], buffers.run[3] })
  layout.expect_near(run[1].height, run[2].height)
end

T['closing a window while zoomed fully']['keeps the zoom when another window closes'] = function()
  local buffers, arrangement = open_every_pane(3)
  show_pane('run', arrangement)
  enter(buffers.run[1])
  toggle_full_zoom()

  child.lua('vim.api.nvim_win_close(vim.fn.bufwinid(...), false)', { buffers.run[3] })

  eq(sizes_of({ buffers.run[1] })[1].width, layout.COLUMNS - child.o.winminwidth - 1)
  eq(is_at_its_least(buffers.claude), true)
  eq(is_at_its_least(buffers.run[2]), true)
end

--- The ’winfixwidth’ and ’winfixheight’ of every window of the child's
--- current tab, as a list in the order the tab lists them.
---
---@return boolean[][] fixed pairs of width and height
local function fixed_sizes()
  return child.lua_get([[vim.tbl_map(function(window)
    return { vim.wo[window].winfixwidth, vim.wo[window].winfixheight }
  end, vim.api.nvim_tabpage_list_wins(0))]])
end

T['zooming a window with fixed sizes fully'] = MiniTest.new_set()

T['zooming a window with fixed sizes fully']['shrinks the layout’s fixed windows and a quickfix list across the tab page, and gives them their sizes back'] = function()
  local buffers = open_every_pane()
  child.lua(
    [[vim.fn.setqflist({ { text = 'x' } }) vim.cmd('botright copen 6') vim.cmd('wincmd p')]]
  )
  local before = sizes()
  enter(buffers.claude)

  toggle_full_zoom()
  local quickfix = child.lua_get([[vim.fn.winheight(vim.fn.getqflist({ winid = 0 }).winid)]])
  toggle_full_zoom()

  eq(quickfix, child.o.winminheight)
  eq(sizes(), before)
end

T['zooming a window with fixed sizes fully']['leaves ’winfixwidth’ and ’winfixheight’ as they were, zoomed and after'] = function()
  local buffers = open_every_pane()
  child.lua(
    [[vim.fn.setqflist({ { text = 'x' } }) vim.cmd('botright copen 6') vim.cmd('wincmd p')]]
  )
  local before = fixed_sizes()
  enter(buffers.report)

  toggle_full_zoom()
  expect_zoomed(buffers.report)
  local zoomed = fixed_sizes()
  toggle_full_zoom()

  eq(zoomed, before)
  eq(fixed_sizes(), before)
end

T['resizing the editor while zoomed fully'] = MiniTest.new_set()

T['resizing the editor while zoomed fully']['keeps the window zoomed, taking the rows the editor gained'] = function()
  local buffers = open_every_pane()
  enter(buffers.report)
  toggle_full_zoom()
  local zoomed = sizes_of({ buffers.report })[1]

  child.o.lines = layout.LINES + 6

  eq(sizes_of({ buffers.report }), { { width = zoomed.width, height = zoomed.height + 6 } })
  eq(is_at_its_least(buffers.claude), true)
  eq(is_at_its_least(buffers.input), true)
end

T['resizing the editor while zoomed fully']['gives the windows back their sizes scaled to the editor’s new size, the command line one line high'] =
  MiniTest.new_set({ parametrize = { { 30 }, { 31 }, { 48 } } })

T['resizing the editor while zoomed fully']['gives the windows back their sizes scaled to the editor’s new size, the command line one line high']['at'] = function(
  lines
)
  local buffers = open_every_pane()
  local before = sizes_of({ buffers.claude, buffers.report, buffers.input })
  enter(buffers.report)
  toggle_full_zoom()
  expect_zoomed(buffers.report)
  child.o.lines = lines
  local gained = lines - layout.LINES

  toggle_full_zoom()

  local after = sizes_of({ buffers.claude, buffers.report, buffers.input })
  eq(child.o.cmdheight, 1)
  eq(after[1], { width = before[1].width, height = before[1].height + gained })
  eq(after[2].width, before[2].width)
  eq(after[2].height + after[3].height, before[2].height + before[3].height + gained)
end

T['a window opened while zoomed fully'] = MiniTest.new_set()

T['a window opened while zoomed fully']['puts the layout’s proportions back as the zoom ends, a file column among them'] = function()
  local buffers = open_every_pane()
  enter(buffers.claude)
  toggle_full_zoom()
  local diff = layout.named_scratch(child, 'aineo://full-zoom-opened-file')
  child.lua([[require('aineo.layout').show_diff(...)]], { diff })
  enter(buffers.claude)

  toggle_full_zoom()

  local widths = sizes_of({ buffers.claude, diff, buffers.report })
  layout.expect_near(widths[1].width, widths[2].width)
  layout.expect_near(widths[2].width, widths[3].width)
  eq(child.o.cmdheight, 1)
end

T['a window opened while zoomed fully']['leaves a quickfix list its height as the zoom ends'] = function()
  local buffers = open_every_pane()
  enter(buffers.claude)
  toggle_full_zoom()
  child.lua(
    [[vim.fn.setqflist({ { text = 'x' } }) vim.cmd('botright copen 6') vim.cmd('wincmd p')]]
  )
  local quickfix = child.lua_get([[vim.fn.getqflist({ winid = 0 }).winid]])

  toggle_full_zoom()

  eq(child.lua_get('vim.fn.winheight(...)', { quickfix }), 6)
end

T['a window opened while zoomed fully']['leaves a split of the zoomed window its rows and puts the columns back as the zoom ends'] = function()
  local buffers = open_every_pane()
  local before = sizes_of({ buffers.claude })
  enter(buffers.claude)
  toggle_full_zoom()
  local zoomed = child.lua_get('vim.api.nvim_get_current_win()')
  child.cmd('split')
  local halves =
    child.lua_get('vim.tbl_map(vim.api.nvim_win_get_height, vim.api.nvim_tabpage_list_wins(0))')
  child.lua('vim.api.nvim_set_current_win(...)', { zoomed })

  toggle_full_zoom()

  local after = child.lua_get([[vim.tbl_map(function(window)
    return { width = vim.api.nvim_win_get_width(window), height = vim.api.nvim_win_get_height(window) }
  end, vim.api.nvim_tabpage_list_wins(0))]])
  eq(after[1].height, halves[1])
  eq(after[2].height, halves[2])
  eq(after[1].width, before[1].width)
end

T['closing the zoomed window of the layout'] = MiniTest.new_set()

for _, role in ipairs({ 'report', 'input' }) do
  T['closing the zoomed window of the layout'][('ends the zoom and puts the proportions back when the %s window closes'):format(
    role
  )] = function()
    local buffers = open_every_pane()
    local before = sizes_of({ buffers.claude })
    enter(buffers[role])
    toggle_full_zoom()

    child.lua('vim.api.nvim_win_close(vim.fn.bufwinid(...), false)', { buffers[role] })

    layout.wait_until(child, 'vim.o.cmdheight == 1')
    eq(sizes_of({ buffers.claude })[1].width, before[1].width)
    eq(child.o.cmdheight, 1)
  end
end

T['changing the pane without a switch while zoomed fully'] = MiniTest.new_set()

T['changing the pane without a switch while zoomed fully']['ends the zoom as the shell’s terminal is wiped under the terminal pane'] = function()
  local buffers, arrangement = open_every_pane()
  show_pane('terminal', arrangement)
  local before = sizes_of({ buffers.claude })
  enter(buffers.claude)
  toggle_full_zoom()
  expect_zoomed(buffers.claude)

  child.lua('vim.api.nvim_buf_delete(..., { force = true })', { buffers.shell })

  layout.wait_until(child, '#vim.api.nvim_tabpage_list_wins(0) == 3')
  eq(sizes_of({ buffers.claude })[1].width, before[1].width)
  expect_next_toggle_to_zoom(buffers.claude)
end

T['changing the pane without a switch while zoomed fully']['ends the zoom as a wiped shell is forgotten when the layout opens again'] = function()
  local buffers, arrangement = open_every_pane()
  show_pane('terminal', arrangement)
  local before = sizes_of({ buffers.claude })
  enter(buffers.claude)
  toggle_full_zoom()
  expect_zoomed(buffers.claude)
  child.lua(
    [[vim.o.eventignore = 'BufWipeout,BufDelete,TermClose'
    vim.api.nvim_buf_delete(..., { force = true })
    vim.o.eventignore = '']],
    { buffers.shell }
  )
  arrangement.shell = nil

  layout.open(child, arrangement)

  eq(child.lua_get([[require('aineo.layout').shown_pane()]]), 'agent')
  eq(sizes_of({ buffers.claude })[1].width, before[1].width)
end

T['moving the cursor while zoomed fully'] = MiniTest.new_set()

T['moving the cursor while zoomed fully']['keeps the zoom on the window that was zoomed'] = function()
  local buffers = open_every_pane()
  local before = sizes()
  enter(buffers.report)
  toggle_full_zoom()
  expect_zoomed(buffers.report)
  local zoomed = sizes()

  enter(buffers.input)
  enter(buffers.claude)
  enter(buffers.report)

  MiniTest.expect.no_equality(zoomed, before)
  eq(sizes(), zoomed)
end

T['moving the cursor while zoomed fully']['lets the next toggle in the zoomed window end the zoom'] = function()
  local buffers = open_every_pane()
  local before = sizes()
  enter(buffers.report)
  toggle_full_zoom()
  expect_zoomed(buffers.report)
  enter(buffers.claude)
  enter(buffers.report)

  toggle_full_zoom()

  eq(sizes(), before)
end

return T
