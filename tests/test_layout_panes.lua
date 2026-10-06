local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- Makes, in the child, the stand-ins for the changes pane's two buffers:
--- named scratch buffers holding one line, as the Report's stand-in is.
---
---@return { files: integer, commits: integer } changes
local function changes_stand_ins()
  return {
    files = layout.named_scratch(child, 'aineo://changes-files'),
    commits = layout.named_scratch(child, 'aineo://changes-commits'),
  }
end

--- Starts the child and opens the layout in it with the stand-ins and the
--- changes pane's stand-ins; returns every buffer the layout was handed or
--- made, by name.
---
---@return { claude: integer, report: integer, input: integer, files: integer, commits: integer } buffers
local function open_with_panes()
  layout.start(child)
  local buffers = layout.stand_ins(child)
  local changes = changes_stand_ins()
  local arrangement = layout.arrangement(buffers)
  arrangement.changes = changes
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  buffers.files = changes.files
  buffers.commits = changes.commits
  return buffers
end

--- Shows `pane` in the child's right column, opening the layout with
--- `arrangement` first when it must.
---
---@param pane string `'agent'` or `'changes'`
---@param arrangement? table
local function show_pane(pane, arrangement)
  child.lua([[require('aineo.layout').show_pane(...)]], { pane, arrangement })
end

--- The buffers the child's windows show, by window ID.
local SHOWN_BY_WINDOW = [[(function()
  local shown = {}
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    shown[tostring(window)] = vim.api.nvim_win_get_buf(window)
  end
  return shown
end)()]]

--- The buffers the child's windows show, left to right and then top to
--- bottom.
local SHOWN_LEFT_TO_RIGHT = [[(function()
  local windows = vim.api.nvim_tabpage_list_wins(0)
  table.sort(windows, function(a, b)
    local a_position, b_position = vim.fn.win_screenpos(a), vim.fn.win_screenpos(b)
    return a_position[2] < b_position[2]
      or (a_position[2] == b_position[2] and a_position[1] < b_position[1])
  end)
  return vim.tbl_map(vim.api.nvim_win_get_buf, windows)
end)()]]

T['the changes pane'] = MiniTest.new_set()

T['the changes pane']['shows its files in the Report’s window and its commits in Input’s'] = function()
  local buffers = open_with_panes()
  local report_window = layout.window_showing(child, buffers.report)
  local input_window = layout.window_showing(child, buffers.input)

  show_pane('changes')

  eq(child.lua_get(SHOWN_BY_WINDOW), {
    [tostring(layout.window_showing(child, buffers.claude))] = buffers.claude,
    [tostring(report_window)] = buffers.files,
    [tostring(input_window)] = buffers.commits,
  })
end

--- Where each of the child's windows sits and how large it is, by window
--- ID, as `layout.box()` gives it.
local BOXES_BY_WINDOW = [[(function()
  local boxes = {}
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local position = vim.api.nvim_win_get_position(window)
    boxes[tostring(window)] = {
      row = position[1],
      col = position[2],
      width = vim.api.nvim_win_get_width(window),
      height = vim.api.nvim_win_get_height(window),
    }
  end
  return boxes
end)()]]

--- Opens a file from Input's window of the child, which moves it to a file
--- column, and puts the cursor back in Input's window.
---
---@param buffers { input: integer }
local function open_file_column(buffers)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('edit ' .. fixture.write('panes-layout/first.txt', { 'line 1', 'line 2' }))
  layout.enter_window_showing(child, buffers.input)
end

T['a switch to the changes pane and back'] = MiniTest.new_set()

T['a switch to the changes pane and back']['keeps every window, by ID, in its place and at its size, the file column’s included'] = function()
  local buffers = open_with_panes()
  open_file_column(buffers)
  local before = child.lua_get(BOXES_BY_WINDOW)

  show_pane('changes')
  local between = child.lua_get(BOXES_BY_WINDOW)
  show_pane('agent')

  eq(vim.tbl_count(before), 4)
  eq(between, before)
  eq(child.lua_get(BOXES_BY_WINDOW), before)
end

T['a switch to the changes pane and back']['shows the same Report and Input again, Input’s text unchanged'] = function()
  local buffers = open_with_panes()
  child.lua(
    'vim.api.nvim_buf_set_lines(..., 0, -1, true, { "my next message" })',
    { buffers.input }
  )
  local report_window = layout.window_showing(child, buffers.report)
  local input_window = layout.window_showing(child, buffers.input)

  show_pane('changes')
  show_pane('agent')

  eq(child.lua_get(SHOWN_BY_WINDOW), {
    [tostring(layout.window_showing(child, buffers.claude))] = buffers.claude,
    [tostring(report_window)] = buffers.report,
    [tostring(input_window)] = buffers.input,
  })
  eq(child.api.nvim_buf_get_lines(buffers.input, 0, -1, true), { 'my next message' })
end

T['a switch'] = MiniTest.new_set({ parametrize = { { 'claude' }, { 'report' }, { 'input' } } })

T['a switch']['leaves the cursor in the window it was in'] = function(role)
  local buffers = open_with_panes()
  local window = layout.window_showing(child, buffers[role])
  layout.enter_window_showing(child, buffers[role])

  show_pane('changes')
  local after_changes = child.api.nvim_get_current_win()
  show_pane('agent')

  eq({ after_changes, child.api.nvim_get_current_win() }, { window, window })
end

--- Fills the child's Report stand-in with a hundred numbered lines and puts
--- the cursor of the Report's window on line 50.
---
---@param buffers { report: integer }
local function read_the_report_halfway(buffers)
  child.lua(
    [[
      local report, window = ...
      local lines = {}
      for number = 1, 100 do
        lines[number] = 'report line ' .. number
      end
      vim.api.nvim_buf_set_lines(report, 0, -1, true, lines)
      vim.api.nvim_win_set_cursor(window, { 50, 0 })
    ]],
    { buffers.report, layout.window_showing(child, buffers.report) }
  )
end

--- Appends thirty lines to the child's Report stand-in, as reports arriving
--- do.
---
---@param buffers { report: integer }
local function receive_reports(buffers)
  child.lua(
    [[vim.api.nvim_buf_set_lines(..., -1, -1, true, vim.fn['repeat']({ 'a new report' }, 30))]],
    { buffers.report }
  )
end

--- The cursor's line in the child's window showing `buffer`.
---
---@param buffer integer
---@return integer line
local function cursor_line_in_window_showing(buffer)
  return child.api.nvim_win_get_cursor(layout.window_showing(child, buffer))[1]
end

T['the agent pane shown again'] = MiniTest.new_set()

T['the agent pane shown again']['keeps the Report’s cursor where it was when no report arrived'] = function()
  local buffers = open_with_panes()
  read_the_report_halfway(buffers)

  show_pane('changes')
  show_pane('agent')

  eq(cursor_line_in_window_showing(buffers.report), 50)
end

T['the agent pane shown again']['puts the Report’s cursor on its last line when a report arrived while it was hidden'] = function()
  local buffers = open_with_panes()
  read_the_report_halfway(buffers)

  show_pane('changes')
  receive_reports(buffers)
  show_pane('agent')

  eq(cursor_line_in_window_showing(buffers.report), 130)
end

--- Fills the child's `buffer` with two hundred numbered lines and scrolls
--- its window so that line 100 is at its top, the cursor on it.
---
---@param buffer integer
local function scroll_to_line_100(buffer)
  child.lua(
    [[
      local buffer, window = ...
      local lines = {}
      for number = 1, 200 do
        lines[number] = 'line ' .. number
      end
      vim.api.nvim_buf_set_lines(buffer, 0, -1, true, lines)
      vim.api.nvim_win_call(window, function()
        vim.fn.winrestview({ topline = 100, lnum = 100 })
      end)
    ]],
    { buffer, layout.window_showing(child, buffer) }
  )
end

--- The top line and the cursor's line of the child's window showing
--- `buffer`.
---
---@param buffer integer
---@return { topline: integer, lnum: integer }
local function view_of_window_showing(buffer)
  return child.lua_get(
    [[vim.api.nvim_win_call(..., function()
      local view = vim.fn.winsaveview()
      return { topline = view.topline, lnum = view.lnum }
    end)]],
    { layout.window_showing(child, buffer) }
  )
end

T['the agent pane shown again']['shows the Report and Input as they were scrolled, no report arrived:'] =
  MiniTest.new_set({ parametrize = { { 'report' }, { 'input' } } })

T['the agent pane shown again']['shows the Report and Input as they were scrolled, no report arrived:']['the'] = function(
  role
)
  local buffers = open_with_panes()
  scroll_to_line_100(buffers[role])

  show_pane('changes')
  show_pane('agent')

  eq(view_of_window_showing(buffers[role]), { topline = 100, lnum = 100 })
end

T['the pane shown'] = MiniTest.new_set({ parametrize = { { 'agent' }, { 'changes' } } })

T['the pane shown']['asked for again changes nothing, a buffer shown in its window by hand included'] = function(
  pane
)
  local buffers = open_with_panes()
  local report_window = layout.window_showing(child, buffers.report)
  show_pane(pane)
  child.api.nvim_win_set_buf(report_window, layout.named_scratch(child, 'panes://other'))
  local before = { child.lua_get(SHOWN_BY_WINDOW), child.api.nvim_get_current_win() }

  show_pane(pane)

  eq({ child.lua_get(SHOWN_BY_WINDOW), child.api.nvim_get_current_win() }, before)
end

--- Every window-local option of the child's window that is the argument,
--- by name.
local WINDOW_OPTIONS = [[(function(window)
  local values = {}
  for name, info in pairs(vim.api.nvim_get_all_options_info()) do
    if info.scope == 'win' then
      values[name] = vim.api.nvim_get_option_value(name, { win = window })
    end
  end
  return values
end)(...)]]

T['a switch to the changes pane and back']['leaves every option of Claude’s window as it was'] = function()
  local buffers = open_with_panes()
  local claude_window = layout.window_showing(child, buffers.claude)
  local before = child.lua_get(WINDOW_OPTIONS, { claude_window })

  show_pane('changes')
  local between = child.lua_get(WINDOW_OPTIONS, { claude_window })
  show_pane('agent')

  eq({ between, child.lua_get(WINDOW_OPTIONS, { claude_window }) }, { before, before })
end

--- The arrangement the child's layout was opened with by `open_with_panes()`,
--- the changes pane's buffers included.
---
---@param buffers { claude: integer, report: integer, files: integer, commits: integer }
---@return table arrangement
local function arrangement_with_panes(buffers)
  local arrangement = layout.arrangement(buffers)
  arrangement.changes = { files = buffers.files, commits = buffers.commits }
  return arrangement
end

T['open() while the changes pane shows'] = MiniTest.new_set()

T['open() while the changes pane shows']['reopens a closed window of the right column on the changes pane’s buffer, at the Report’s share'] = function()
  local buffers = open_with_panes()
  show_pane('changes')
  child.api.nvim_win_close(layout.window_showing(child, buffers.commits), false)

  layout.open(child, arrangement_with_panes(buffers))

  eq(child.lua_get(SHOWN_LEFT_TO_RIGHT), { buffers.claude, buffers.files, buffers.commits })
  local files = layout.box(child, layout.window_showing(child, buffers.files))
  local commits = layout.box(child, layout.window_showing(child, buffers.commits))
  eq({ commits.row, commits.col }, { files.height + 1, files.col })
  layout.expect_near(files.height, layout.REPORT_HEIGHT * (files.height + commits.height))
end

T['open() while the changes pane shows']['shows the changes pane’s buffer again in a window showing another'] = function()
  local buffers = open_with_panes()
  local report_window = layout.window_showing(child, buffers.report)
  show_pane('changes')
  child.api.nvim_win_set_buf(report_window, layout.named_scratch(child, 'panes://other'))

  layout.open(child, arrangement_with_panes(buffers))

  eq(child.api.nvim_win_get_buf(report_window), buffers.files)
end

--- How the child's window showing the buffer that is the argument wraps
--- long lines: its `'wrap'`, `'linebreak'` and `'breakindent'`.
local WRAPPING = [[(function(window)
  return {
    wrap = vim.wo[window].wrap,
    linebreak = vim.wo[window].linebreak,
    breakindent = vim.wo[window].breakindent,
  }
end)(...)]]

--- Long lines wrapped between words, a wrapped line keeping its indent.
local WRAPPED = { wrap = true, linebreak = true, breakindent = true }

--- Long lines left unwrapped, as the user's `set nowrap` leaves them.
local UNWRAPPED = { wrap = false, linebreak = false, breakindent = false }

--- How the child's window showing `buffer` wraps long lines.
---
---@param buffer integer
---@return { wrap: boolean, linebreak: boolean, breakindent: boolean }
local function wrapping_of_window_showing(buffer)
  return child.lua_get(WRAPPING, { layout.window_showing(child, buffer) })
end

--- Starts the child with the user's configuration turning wrapping off, as
--- `set nowrap` does, and opens the layout with the stand-ins and the changes
--- pane's; returns every buffer it was handed or made, by name.
---
---@return { claude: integer, report: integer, input: integer, files: integer, commits: integer } buffers
local function open_with_panes_under_nowrap()
  layout.start(child)
  child.cmd('set nowrap nolinebreak nobreakindent')
  local buffers = layout.stand_ins(child)
  local changes = changes_stand_ins()
  buffers.files, buffers.commits = changes.files, changes.commits
  layout.open(child, arrangement_with_panes(buffers))
  buffers.input = layout.input_buffer(child)
  return buffers
end

T['open() while the changes pane shows']['leaves the changes pane’s buffers wrapped as the user’s settings say'] = function()
  local buffers = open_with_panes_under_nowrap()
  show_pane('changes')

  layout.open(child, arrangement_with_panes(buffers))

  eq(
    { wrapping_of_window_showing(buffers.files), wrapping_of_window_showing(buffers.commits) },
    { UNWRAPPED, UNWRAPPED }
  )
end

--- Closes every window of the child's layout, leaving a file in the window
--- that remains, as `:only` in the file column does: the file is opened from
--- the window showing `buffer`, which moves it to the file column.
---
---@param buffer integer
---@return integer file the file's buffer
local function close_the_layout(buffer)
  layout.enter_window_showing(child, buffer)
  local path = fixture.write('panes-layout/second.txt', { 'line 1', 'line 2' })
  child.cmd('edit ' .. path)
  child.cmd('only')
  return child.fn.bufnr(path)
end

T['open() after the layout’s windows closed'] = MiniTest.new_set()

T['open() after the layout’s windows closed']['shows the pane shown last'] = function()
  local buffers = open_with_panes()
  show_pane('changes')
  local file = close_the_layout(buffers.commits)

  layout.open(child, arrangement_with_panes(buffers))

  eq(child.lua_get(SHOWN_LEFT_TO_RIGHT), { buffers.claude, file, buffers.files, buffers.commits })
end

--- Each pane, with the names of the buffers it shows in the right column,
--- top first, as a set's `parametrize`.
local PANES = { { 'agent', { 'report', 'input' } }, { 'changes', { 'files', 'commits' } } }

--- Starts the child and makes the stand-ins and the changes pane's, opening
--- nothing; returns them by name.
---
---@return { claude: integer, report: integer, files: integer, commits: integer } buffers
local function start_with_stand_ins()
  layout.start(child)
  local buffers = layout.stand_ins(child)
  local changes = changes_stand_ins()
  buffers.files, buffers.commits = changes.files, changes.commits
  return buffers
end

T['show_pane()'] = MiniTest.new_set({ parametrize = PANES })

T['show_pane()']['opens the layout first, showing the pane, when it was never opened'] = function(
  pane,
  shown
)
  local buffers = start_with_stand_ins()

  show_pane(pane, arrangement_with_panes(buffers))

  buffers.input = layout.input_buffer(child)
  eq(child.lua_get(SHOWN_LEFT_TO_RIGHT), { buffers.claude, buffers[shown[1]], buffers[shown[2]] })
end

--- The other pane, by pane.
local OTHER_PANE = { agent = 'changes', changes = 'agent' }

T['show_pane()']['opens the layout first, showing the pane, when a window of the right column was closed'] = function(
  pane,
  shown
)
  local buffers = open_with_panes()
  show_pane(OTHER_PANE[pane])
  child.api.nvim_win_close(layout.window_showing(child, child.api.nvim_get_current_buf()), false)

  show_pane(pane, arrangement_with_panes(buffers))

  eq(child.lua_get(SHOWN_LEFT_TO_RIGHT), { buffers.claude, buffers[shown[1]], buffers[shown[2]] })
end

T['focus() while the changes pane shows'] = MiniTest.new_set({
  parametrize = { { 'report' }, { 'input' } },
})

T['focus() while the changes pane shows']['shows the agent pane, then moves the cursor to the window of'] = function(
  role
)
  local buffers = open_with_panes()
  layout.enter_window_showing(child, buffers.claude)
  show_pane('changes')

  layout.focus(child, role, arrangement_with_panes(buffers))

  eq(
    { child.lua_get(SHOWN_LEFT_TO_RIGHT), child.api.nvim_get_current_buf() },
    { { buffers.claude, buffers.report, buffers.input }, buffers[role] }
  )
end

T['focus() while the changes pane shows, Input’s window closed,'] = MiniTest.new_set()

T['focus() while the changes pane shows, Input’s window closed,']['shows the Report in its window alone'] = function()
  local buffers = open_with_panes()
  show_pane('changes')
  child.api.nvim_win_close(layout.window_showing(child, buffers.commits), false)

  layout.focus(child, 'report', arrangement_with_panes(buffers))

  eq(
    { child.lua_get(SHOWN_LEFT_TO_RIGHT), child.api.nvim_get_current_buf() },
    { { buffers.claude, buffers.report }, buffers.report }
  )
end

T['focus() while the changes pane shows, the Report’s window closed,'] = MiniTest.new_set()

T['focus() while the changes pane shows, the Report’s window closed,']['shows Input in its window alone after a report arrived'] = function()
  local buffers = open_with_panes()
  show_pane('changes')
  child.api.nvim_win_close(layout.window_showing(child, buffers.files), false)
  receive_reports(buffers)

  layout.focus(child, 'input', arrangement_with_panes(buffers))

  eq(
    { child.lua_get(SHOWN_LEFT_TO_RIGHT), child.api.nvim_get_current_buf() },
    { { buffers.claude, buffers.input }, buffers.input }
  )
end

T['a file opened in a window of the changes pane'] = MiniTest.new_set({
  parametrize = { { 'files' }, { 'commits' } },
})

T['a file opened in a window of the changes pane']['moves to the file column, and the window gets its buffer back, from'] = function(
  window
)
  local buffers = open_with_panes()
  show_pane('changes')
  layout.enter_window_showing(child, buffers[window])
  local path = fixture.write('panes-layout/third.txt', { 'line 1', 'line 2' })

  child.cmd('edit ' .. path)

  eq(
    child.lua_get(SHOWN_LEFT_TO_RIGHT),
    { buffers.claude, child.fn.bufnr(path), buffers.files, buffers.commits }
  )
end

T['the changes pane']['keeps its buffers in their windows, whatever their options, the file column’s redirect included'] = function()
  local buffers = open_with_panes()
  child.lua('vim.bo[...].buftype = ""', { buffers.files })

  show_pane('changes')

  eq(child.lua_get(SHOWN_LEFT_TO_RIGHT), { buffers.claude, buffers.files, buffers.commits })
end

T['show_pane()']['shows the changes pane’s new buffers after one of its buffers was wiped'] = function(
  pane
)
  local buffers = open_with_panes()
  show_pane(pane)
  child.cmd('bwipeout! ' .. buffers.files)
  buffers.files = layout.named_scratch(child, 'aineo://changes-files')

  show_pane('changes', arrangement_with_panes(buffers))

  eq(child.lua_get(SHOWN_LEFT_TO_RIGHT), { buffers.claude, buffers.files, buffers.commits })
end

T['show_pane() refuses a pane the layout does not have'] = function()
  local buffers = open_with_panes()

  MiniTest.expect.error(function()
    show_pane('files', arrangement_with_panes(buffers))
  end, "pane: expected 'agent' or 'changes'")
end

T['open() refuses changes it cannot show, naming the setting'] = MiniTest.new_set({
  parametrize = {
    {
      function()
        return 'aineo://changes-files'
      end,
      'arrangement%.changes: expected table',
    },
    {
      function(buffers)
        return { commits = buffers.commits }
      end,
      'arrangement%.changes%.files: expected a buffer',
    },
    {
      function(buffers)
        return { files = 9999, commits = buffers.commits }
      end,
      'arrangement%.changes%.files: expected a buffer',
    },
    {
      function(buffers)
        return { files = buffers.files, commits = 9999 }
      end,
      'arrangement%.changes%.commits: expected a buffer',
    },
  },
})

T['open() refuses changes it cannot show, naming the setting']['given'] = function(changes, refusal)
  local buffers = start_with_stand_ins()
  local arrangement = arrangement_with_panes(buffers)
  arrangement.changes = changes(buffers)

  MiniTest.expect.error(function()
    layout.open(child, arrangement)
  end, refusal)
end

T['show_pane() without the changes pane’s buffers'] = MiniTest.new_set()

T['show_pane() without the changes pane’s buffers']['refuses the changes pane, and the agent pane stays'] = function()
  local buffers = layout.open_with_stand_ins(child)

  MiniTest.expect.error(function()
    show_pane('changes', layout.arrangement(buffers))
  end, "arrangement%.changes: expected the changes pane's buffers")
  eq(child.lua_get(SHOWN_LEFT_TO_RIGHT), { buffers.claude, buffers.report, buffers.input })
  MiniTest.expect.no_error(function()
    layout.open(child, layout.arrangement(buffers))
  end)
end

T['the agent pane shown again']['wraps a Report new to its window'] = function()
  local buffers = open_with_panes_under_nowrap()
  show_pane('changes')
  child.cmd('bwipeout! ' .. buffers.report)
  buffers.report = layout.named_scratch(child, 'aineo://report')

  show_pane('agent', arrangement_with_panes(buffers))

  eq(wrapping_of_window_showing(buffers.report), WRAPPED)
end

T['the agent pane shown again']['once it has shown an arrival, leaves the Report’s cursor to the user when the layout is restored'] = function()
  local buffers = open_with_panes()
  read_the_report_halfway(buffers)
  show_pane('changes')
  receive_reports(buffers)
  show_pane('agent')
  child.api.nvim_win_set_cursor(layout.window_showing(child, buffers.report), { 50, 0 })

  layout.open(child, arrangement_with_panes(buffers))

  eq(cursor_line_in_window_showing(buffers.report), 50)
end

return T
