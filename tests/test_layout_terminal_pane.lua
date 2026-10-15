local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The program the child's `'shell'` is set to: a POSIX shell that reads no
--- startup file of the user's, so a case never runs the user's own shell.
local TEST_SHELL = '/bin/sh'

--- The buffers the child's windows show, by window ID.
local SHOWN_BY_WINDOW = [[(function()
  local shown = {}
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    shown[tostring(window)] = vim.api.nvim_win_get_buf(window)
  end
  return shown
end)()]]

--- Where each of the child's windows sits and how large it is, by window ID.
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

--- Makes, in the child, the stand-ins for the changes pane's two buffers:
--- named scratch buffers holding one line, as the Report’s stand-in is.
---
---@return { files: integer, commits: integer } changes
local function changes_stand_ins()
  return {
    files = layout.named_scratch(child, 'aineo://changes-files'),
    commits = layout.named_scratch(child, 'aineo://changes-commits'),
  }
end

--- Starts the child, with `'shell'` set to `TEST_SHELL`, and opens the layout
--- in it with the stand-ins, the changes pane's stand-ins and the terminal
--- of a shell the shell home started; returns every buffer the layout was
--- handed or made, by name.
---
---@param user_setup? string Lua the user's configuration would run in the child before aineo starts a shell
---@param shell? string the child's `'shell'`; `TEST_SHELL` without it
---@return { claude: integer, report: integer, input: integer, files: integer, commits: integer, shell: integer } buffers
local function open_with_panes(user_setup, shell)
  layout.start(child)
  child.o.shell = shell or TEST_SHELL
  child.lua(user_setup or '')
  local buffers = layout.stand_ins(child)
  local changes = changes_stand_ins()
  buffers.shell = child.lua_get([[require('aineo.shell').start({ cwd = vim.uv.cwd() })]])
  local arrangement = layout.arrangement(buffers)
  arrangement.changes = changes
  arrangement.shell = buffers.shell
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  buffers.files = changes.files
  buffers.commits = changes.commits
  return buffers
end

--- Starts the child, with `'shell'` set to `TEST_SHELL`, and opens the layout
--- in it with the stand-ins alone; returns the buffers it was handed or made,
--- by name, and a shell the shell home started, not handed to the layout.
---
---@return { claude: integer, report: integer, input: integer, shell: integer } buffers
local function open_without_a_shell()
  layout.start(child)
  child.o.shell = TEST_SHELL
  local buffers = layout.stand_ins(child)
  layout.open(child, layout.arrangement(buffers))
  buffers.input = layout.input_buffer(child)
  buffers.shell = child.lua_get([[require('aineo.shell').start({ cwd = vim.uv.cwd() })]])
  return buffers
end

--- Shows `pane` in the child's right column, opening the layout with
--- `arrangement` first when it must.
---
---@param pane string `'agent'`, `'changes'` or `'terminal'`
---@param arrangement? table
local function show_pane(pane, arrangement)
  child.lua([[require('aineo.layout').show_pane(...)]], { pane, arrangement })
end

--- How long a case waits for the child to reach a state, in milliseconds.
local PATIENCE_MS = 10000

--- Waits, at most `PATIENCE_MS`, until `expression` is true in `child`, and
--- says whether it became true.
---
---@param expression string a Lua expression, with `...` standing for `args`
---@param args? table
---@return boolean became_true
local function wait_until(expression, args)
  return vim.wait(PATIENCE_MS, function()
    return child.lua_get(expression, args or {})
  end, 20)
end

--- Types `command` into the terminal job of `buffer` in `child`, as the user
--- would, ending the line.
---
---@param buffer integer
---@param command string
local function type_into_shell(buffer, command)
  child.lua(
    [[vim.fn.chansend(vim.b[(...)].terminal_job_id, (select(2, ...)) .. '\n')]],
    { buffer, command }
  )
end

--- What each pane shows in the Report’s window and in Input’s, named as the
--- buffers `open_with_panes()` returns.
local PANE_BUFFERS = {
  agent = { report = 'report', input = 'input' },
  changes = { report = 'files', input = 'commits' },
  terminal = { report = 'shell', input = 'input' },
}

T['the terminal pane'] = MiniTest.new_set()

T['the terminal pane']['shows the shell in the Report’s window and keeps Input in its own, every window in its place and at its size'] = function()
  local buffers = open_with_panes()
  local report_window = layout.window_showing(child, buffers.report)
  local input_window = layout.window_showing(child, buffers.input)
  local claude_window = layout.window_showing(child, buffers.claude)
  local boxes_before = child.lua_get(BOXES_BY_WINDOW)
  layout.enter_window_showing(child, buffers.claude)

  show_pane('terminal')

  eq(child.lua_get(SHOWN_BY_WINDOW), {
    [tostring(claude_window)] = buffers.claude,
    [tostring(report_window)] = buffers.shell,
    [tostring(input_window)] = buffers.input,
  })
  eq(child.lua_get(BOXES_BY_WINDOW), boxes_before)
  eq(child.api.nvim_get_current_buf(), buffers.claude)
end

T['the terminal pane']['shows a shell the call’s arrangement hands, the layout open without one'] = function()
  local buffers = open_without_a_shell()
  local report_window = layout.window_showing(child, buffers.report)

  show_pane('terminal', {
    claude = buffers.claude,
    report = buffers.report,
    report_height = layout.REPORT_HEIGHT,
    shell = buffers.shell,
  })

  eq(child.api.nvim_win_get_buf(report_window), buffers.shell)
end

T['the terminal pane']['keeps the shell handed last when a later arrangement hands none'] = function()
  local buffers = open_with_panes()
  local report_window = layout.window_showing(child, buffers.report)

  layout.open(child, layout.arrangement(buffers))
  local shown = pcall(child.lua, [[require('aineo.layout').show_pane('terminal')]])

  eq(shown, true)
  eq(child.api.nvim_win_get_buf(report_window), buffers.shell)
end

T['the terminal pane']['is refused, naming arrangement.shell, when no shell was handed, after opening the layout and before switching anything'] = function()
  layout.start(child)
  local buffers = layout.stand_ins(child)

  local shown, message = pcall(
    child.lua,
    [[require('aineo.layout').show_pane('terminal', ...)]],
    { layout.arrangement(buffers) }
  )

  eq(shown, false)
  eq(message:find('arrangement.shell', 1, true) ~= nil, true)
  eq(layout.window_count(child), 3)
  eq(child.api.nvim_win_get_buf(layout.window_showing(child, buffers.report)), buffers.report)
end

T['focusing the terminal pane'] = MiniTest.new_set()

T['focusing the terminal pane']['shows it and moves the cursor into the shell’s window, entering no mode, hidden or shown before'] = function()
  local buffers = open_with_panes()
  layout.enter_window_showing(child, buffers.claude)

  child.lua([[require('aineo.layout').focus_pane('terminal')]])
  local first = { child.api.nvim_get_current_buf(), child.api.nvim_get_mode().mode }
  layout.enter_window_showing(child, buffers.claude)
  child.lua([[require('aineo.layout').focus_pane('terminal')]])

  eq(first, { buffers.shell, 'nt' })
  eq({ child.api.nvim_get_current_buf(), child.api.nvim_get_mode().mode }, first)
end

T['the terminal pane asked for again'] = MiniTest.new_set()

T['the terminal pane asked for again']['changes nothing, a buffer shown in the Report’s window by hand included'] = function()
  local buffers = open_with_panes()
  show_pane('terminal')
  local report_window = layout.window_showing(child, buffers.shell)
  local input_window = layout.window_showing(child, buffers.input)
  local by_hand = layout.named_scratch(child, 'aineo://shown-by-hand')
  child.api.nvim_win_set_buf(report_window, by_hand)
  child.api.nvim_buf_set_lines(buffers.input, 0, -1, false, { 'one', 'two', 'three' })
  child.api.nvim_win_set_cursor(input_window, { 2, 1 })
  local shown_before = child.lua_get(SHOWN_BY_WINDOW)
  local input_view =
    child.lua_get('vim.api.nvim_win_call(..., vim.fn.winsaveview)', { input_window })

  show_pane('terminal')

  eq(child.lua_get(SHOWN_BY_WINDOW), shown_before)
  eq(child.lua_get('vim.api.nvim_win_call(..., vim.fn.winsaveview)', { input_window }), input_view)
end

T['the terminal pane asked for again']['shows the shell again in the Report’s window where the agent pane’s Report was put by hand'] = function()
  local buffers = open_with_panes()
  show_pane('terminal')
  local report_window = layout.window_showing(child, buffers.shell)
  child.api.nvim_win_set_buf(report_window, buffers.report)

  show_pane('terminal')

  eq(child.api.nvim_win_get_buf(report_window), buffers.shell)
end

local SWITCHES = {}
for _, from in ipairs({ 'agent', 'changes', 'terminal' }) do
  for _, to in ipairs({ 'agent', 'changes', 'terminal' }) do
    if from ~= to then
      table.insert(SWITCHES, { from, to })
    end
  end
end

T['a switch among the three panes'] = MiniTest.new_set({ parametrize = SWITCHES })

T['a switch among the three panes']['shows the buffers of the pane in the same windows, at their sizes, from'] = function(
  from,
  to
)
  local buffers = open_with_panes()
  local windows = {
    claude = layout.window_showing(child, buffers.claude),
    report = layout.window_showing(child, buffers.report),
    input = layout.window_showing(child, buffers.input),
  }
  show_pane(from)
  local boxes_before = child.lua_get(BOXES_BY_WINDOW)

  show_pane(to)

  eq(child.lua_get(SHOWN_BY_WINDOW), {
    [tostring(windows.claude)] = buffers.claude,
    [tostring(windows.report)] = buffers[PANE_BUFFERS[to].report],
    [tostring(windows.input)] = buffers[PANE_BUFFERS[to].input],
  })
  eq(child.lua_get(BOXES_BY_WINDOW), boxes_before)
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

T['the agent pane shown again after the terminal pane'] = MiniTest.new_set()

T['the agent pane shown again after the terminal pane']['shows the Report and Input as they were scrolled'] =
  MiniTest.new_set({
    parametrize = { { 'report' }, { 'input' } },
  })

T['the agent pane shown again after the terminal pane']['shows the Report and Input as they were scrolled']['the'] = function(
  role
)
  local buffers = open_with_panes()
  scroll_to_line_100(buffers[role])

  show_pane('terminal')
  show_pane('agent')

  eq(view_of_window_showing(buffers[role]), { topline = 100, lnum = 100 })
end

T['the agent pane shown again after the terminal pane']['shows the shell as it was scrolled when the terminal pane shows again'] = function()
  local buffers = open_with_panes()
  show_pane('terminal')
  child.lua([[vim.fn.chansend(vim.b[(...)].terminal_job_id, 'seq 1 150\n')]], { buffers.shell })
  eq(layout.wait_until(child, 'vim.api.nvim_buf_line_count(...) >= 150', { buffers.shell }), true)
  child.lua(
    [[vim.api.nvim_win_call(..., function()
      vim.fn.winrestview({ topline = 60, lnum = 70 })
    end)]],
    { layout.window_showing(child, buffers.shell) }
  )

  show_pane('agent')
  show_pane('terminal')

  eq(view_of_window_showing(buffers.shell), { topline = 60, lnum = 70 })
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

T['the agent pane shown again after the terminal pane']['keeps the Report’s cursor where it was when no report arrived'] = function()
  local buffers = open_with_panes()
  read_the_report_halfway(buffers)

  show_pane('terminal')
  show_pane('agent')

  eq(cursor_line_in_window_showing(buffers.report), 50)
end

T['the agent pane shown again after the terminal pane']['puts the Report’s cursor on its last line when a report arrived while it was hidden'] = function()
  local buffers = open_with_panes()
  read_the_report_halfway(buffers)

  show_pane('terminal')
  receive_reports(buffers)
  show_pane('agent')

  eq(cursor_line_in_window_showing(buffers.report), 130)
end

--- The word-wrap options of a window, by name.
local WRAPPING = [[(function(window)
  return {
    wrap = vim.wo[window].wrap,
    linebreak = vim.wo[window].linebreak,
    breakindent = vim.wo[window].breakindent,
  }
end)(...)]]

T['the agent pane shown again after the terminal pane']['wraps a Report new to its window'] = function()
  local buffers = open_with_panes()
  child.cmd('set nowrap nolinebreak nobreakindent')
  show_pane('terminal')
  child.cmd('bwipeout! ' .. buffers.report)
  local report = layout.named_scratch(child, 'aineo://report')

  show_pane('agent', {
    claude = buffers.claude,
    report = report,
    report_height = layout.REPORT_HEIGHT,
  })

  eq(
    child.lua_get(WRAPPING, { layout.window_showing(child, report) }),
    { wrap = true, linebreak = true, breakindent = true }
  )
end

T['focus() while the terminal pane shows'] = MiniTest.new_set()

T['focus() while the terminal pane shows']['moves the cursor to Input and leaves the shell shown'] = function()
  local buffers = open_with_panes()
  show_pane('terminal')
  local report_window = layout.window_showing(child, buffers.shell)
  layout.enter_window_showing(child, buffers.claude)

  layout.focus(child, 'input', layout.arrangement(buffers))

  eq(child.api.nvim_get_current_buf(), buffers.input)
  eq(child.api.nvim_win_get_buf(report_window), buffers.shell)
end

T['focus() while the terminal pane shows']['shows the agent pane, then moves the cursor to the Report'] = function()
  local buffers = open_with_panes()
  show_pane('terminal')
  local report_window = layout.window_showing(child, buffers.shell)
  layout.enter_window_showing(child, buffers.claude)

  layout.focus(child, 'report', layout.arrangement(buffers))

  eq(child.api.nvim_get_current_buf(), buffers.report)
  eq(child.api.nvim_win_get_buf(report_window), buffers.report)
end

T['focus() while the terminal pane shows']['moves the cursor to Claude and leaves the shell shown'] = function()
  local buffers = open_with_panes()
  show_pane('terminal')
  local report_window = layout.window_showing(child, buffers.shell)
  layout.enter_window_showing(child, buffers.input)

  layout.focus(child, 'claude', layout.arrangement(buffers))

  eq(child.api.nvim_get_current_buf(), buffers.claude)
  eq(child.api.nvim_win_get_buf(report_window), buffers.shell)
end

T['focus() while the terminal pane shows']['opens nothing for Input when the Report was wiped, which the pane does not show'] = function()
  local buffers = open_with_panes()
  show_pane('terminal')
  child.cmd('bwipeout! ' .. buffers.report)
  child.lua('_G.arrangement_made = false')

  child.lua([[require('aineo.layout').focus('input', function()
    _G.arrangement_made = true
  end)]])

  eq(child.lua_get('_G.arrangement_made'), false)
  eq(child.api.nvim_get_current_buf(), buffers.input)
end

T['a shell that ends while the terminal pane shows'] = MiniTest.new_set()

T['a shell that ends while the terminal pane shows']['gives the Report’s window back to the Report, the same window at the same size, before its buffer goes'] = function()
  local buffers = open_with_panes()
  show_pane('terminal')
  local windows = {
    claude = layout.window_showing(child, buffers.claude),
    report = layout.window_showing(child, buffers.shell),
    input = layout.window_showing(child, buffers.input),
  }
  local boxes_before = child.lua_get(BOXES_BY_WINDOW)

  type_into_shell(buffers.shell, 'exit 3')

  eq(wait_until('not vim.api.nvim_buf_is_valid(...)', { buffers.shell }), true)
  eq(child.lua_get(SHOWN_BY_WINDOW), {
    [tostring(windows.claude)] = buffers.claude,
    [tostring(windows.report)] = buffers.report,
    [tostring(windows.input)] = buffers.input,
  })
  eq(child.lua_get(BOXES_BY_WINDOW), boxes_before)
end

--- The ways the shell's buffer goes while the terminal pane shows it, each
--- closing the Report's window before any buffer event: a shell run as
--- `'shell'` alone exiting with status 0, which Neovim's own handler wipes,
--- and the commands that wipe a running terminal.
local WIPES = { { 'exit 0' }, { 'bdelete!' }, { 'bwipeout!' } }

--- Makes the shell's buffer go in `child`, or its shell end, as `how` says: a
--- line typed into the shell, or an Ex command run on the buffer.
---
---@param how string `'exit 0'`, `'exit 3'`, `'bdelete!'` or `'bwipeout!'`
---@param shell integer the shell's buffer
local function end_shell(how, shell)
  if vim.startswith(how, 'exit') then
    type_into_shell(shell, how)
  else
    child.cmd(how .. ' ' .. shell)
  end
end

--- Whether the child's Report is shown in a window.
local REPORT_SHOWN = 'vim.fn.win_findbuf(...)[1] ~= nil'

T['a shell wiped while the terminal pane shows'] = MiniTest.new_set({ parametrize = WIPES })

T['a shell wiped while the terminal pane shows']['gives the Report a window again in its place above Input, at the proportions, raising nothing, for'] = function(
  wipe
)
  local buffers = open_with_panes()
  local boxes_before = layout.boxes(child, buffers)
  show_pane('terminal')

  end_shell(wipe, buffers.shell)

  eq(wait_until(REPORT_SHOWN, { buffers.report }), true)
  eq(layout.boxes(child, buffers), boxes_before)
  eq(layout.window_count(child), 3)
  eq(child.lua_get('vim.v.errmsg'), '')
end

--- The ways the shell ends or goes, for the cases on where the cursor lands.
local ENDS = { { 'exit 3' }, { 'exit 0' }, { 'bwipeout!' } }

T['the cursor as the shell ends or goes'] = MiniTest.new_set({ parametrize = ENDS })

T['the cursor as the shell ends or goes']['lands in the Report when it was in the shell’s window, for'] = function(
  how
)
  local buffers = open_with_panes()
  show_pane('terminal')
  layout.enter_window_showing(child, buffers.shell)

  end_shell(how, buffers.shell)

  eq(wait_until(REPORT_SHOWN, { buffers.report }), true)
  eq(child.api.nvim_get_current_buf(), buffers.report)
end

T['the cursor as the shell ends or goes']['stays in Claude’s window when it was there, for'] = function(
  how
)
  local buffers = open_with_panes()
  show_pane('terminal')
  layout.enter_window_showing(child, buffers.claude)
  local claude_window = child.api.nvim_get_current_win()

  end_shell(how, buffers.shell)

  eq(wait_until(REPORT_SHOWN, { buffers.report }), true)
  eq(child.api.nvim_get_current_win(), claude_window)
end

T['the cursor as the shell ends or goes']['stays in its window and tab page when it was in another tab page, for'] = function(
  how
)
  local buffers = open_with_panes()
  show_pane('terminal')
  child.cmd('tabnew')
  local window, tab = child.api.nvim_get_current_win(), child.api.nvim_get_current_tabpage()

  end_shell(how, buffers.shell)

  eq(wait_until(REPORT_SHOWN, { buffers.report }), true)
  eq({ child.api.nvim_get_current_win(), child.api.nvim_get_current_tabpage() }, { window, tab })
end

local HIDDEN_ENDS = {}
for _, pane in ipairs({ 'agent', 'changes' }) do
  for _, how in ipairs({ 'exit 3', 'exit 0', 'bwipeout!' }) do
    table.insert(HIDDEN_ENDS, { pane, how })
  end
end

T['a shell that ends or goes while another pane shows'] = MiniTest.new_set({
  parametrize = HIDDEN_ENDS,
})

T['a shell that ends or goes while another pane shows']['changes no window, and is forgotten, for'] = function(
  pane,
  how
)
  local buffers = open_with_panes()
  show_pane(pane)
  local shown_before, boxes_before = child.lua_get(SHOWN_BY_WINDOW), child.lua_get(BOXES_BY_WINDOW)

  end_shell(how, buffers.shell)

  eq(wait_until('not vim.api.nvim_buf_is_valid(...)', { buffers.shell }), true)
  local shown, message = pcall(
    child.lua,
    [[require('aineo.layout').show_pane('terminal', ...)]],
    { layout.arrangement(buffers) }
  )
  eq(shown, false)
  eq(message:find('arrangement.shell', 1, true) ~= nil, true)
  eq(child.lua_get(SHOWN_BY_WINDOW), shown_before)
  eq(child.lua_get(BOXES_BY_WINDOW), boxes_before)
end

T['open() while the terminal pane shows'] = MiniTest.new_set()

T['open() while the terminal pane shows']['shows the shell again in a Report’s window reopened, at the Report’s share'] = function()
  local buffers = open_with_panes()
  local boxes_before = layout.boxes(child, buffers)
  show_pane('terminal')
  child.lua('vim.api.nvim_win_close(vim.fn.win_findbuf(...)[1], false)', { buffers.shell })

  layout.open(child, layout.arrangement(buffers))

  eq(child.api.nvim_win_get_buf(layout.window_showing(child, buffers.shell)), buffers.shell)
  eq(layout.box(child, layout.window_showing(child, buffers.shell)), boxes_before.report)
end

T['open() while the terminal pane shows']['opens on the agent pane when its shell is gone'] = function()
  local buffers = open_with_panes()
  show_pane('terminal')
  layout.enter_window_showing(child, buffers.input)
  child.cmd('edit ' .. fixture.write('terminal-pane/first.txt', { 'line 1', 'line 2' }))
  child.cmd('only')
  child.cmd('bwipeout! ' .. buffers.shell)

  layout.open(child, layout.arrangement(buffers))

  eq(
    child.lua_get(SHOWN_BY_WINDOW)[tostring(layout.window_showing(child, buffers.report))],
    buffers.report
  )
  eq(child.lua_get('vim.fn.win_findbuf(...)', { buffers.shell }), {})
end

--- The buffers shown in the windows of the child's tab page number `number`,
--- by window ID.
local SHOWN_IN_TAB = [[(function(number)
  local shown = {}
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(vim.api.nvim_list_tabpages()[number])) do
    shown[tostring(window)] = vim.api.nvim_win_get_buf(window)
  end
  return shown
end)(...)]]

--- Opens, in a second tab page of the child, a layout of its own
--- (`aineo.layout`'s `new()`) held as `_G.second`, with a shell of a shell
--- home of its own (`aineo.shell`'s `new()`), under the terminal pane in
--- both tab pages' layouts: the module's in the first, with the buffers
--- `open_with_panes()` made.
---
---@return { first: table, second: table } buffers the buffers of each layout, by name
local function open_two_layouts_under_the_terminal_pane()
  local first = open_with_panes()
  show_pane('terminal')
  local second = {
    claude = layout.terminal(child),
    report = layout.named_scratch(child, 'aineo://report-second'),
  }
  second.shell = child.lua_get([[(function()
    _G.second_shell = require('aineo.shell').new()
    return _G.second_shell.start({ cwd = vim.uv.cwd() })
  end)()]])
  local arrangement = layout.arrangement(second)
  arrangement.shell = second.shell
  child.cmd('tabnew')
  child.lua(
    [[_G.second = require('aineo.layout').new(); _G.second.open(...); _G.second.show_pane('terminal')]],
    { arrangement }
  )
  second.input = child.lua_get('_G.second.input_buffer()')
  return { first = first, second = second }
end

T['two layouts'] = MiniTest.new_set()

--- `list` sorted in place, returned.
---
---@param list integer[]
---@return integer[] list
local function sorted(list)
  table.sort(list)
  return list
end

T['two layouts']['show each its own shell under the terminal pane, in the windows of its own tab page'] = function()
  local buffers = open_two_layouts_under_the_terminal_pane()

  eq(
    sorted(vim.tbl_values(child.lua_get(SHOWN_IN_TAB, { 1 }))),
    sorted({ buffers.first.claude, buffers.first.shell, buffers.first.input })
  )
  eq(
    sorted(vim.tbl_values(child.lua_get(SHOWN_IN_TAB, { 2 }))),
    sorted({ buffers.second.claude, buffers.second.shell, buffers.second.input })
  )
end

T['two layouts']['react to the end or wipe of their own shell only'] = MiniTest.new_set({
  parametrize = { { 'exit 3' }, { 'exit 0' }, { 'bwipeout!' } },
})

T['two layouts']['react to the end or wipe of their own shell only']['as'] = function(how)
  local buffers = open_two_layouts_under_the_terminal_pane()
  local first_tab_before = child.lua_get(SHOWN_IN_TAB, { 1 })

  end_shell(how, buffers.second.shell)

  eq(wait_until(REPORT_SHOWN, { buffers.second.report }), true)
  eq(child.lua_get(SHOWN_IN_TAB, { 1 }), first_tab_before)
  eq(child.lua_get('vim.api.nvim_buf_is_valid(...)', { buffers.first.shell }), true)
end

T['the layout reopened after a shell was wiped'] = MiniTest.new_set()

T['the layout reopened after a shell was wiped']['shows the agent pane again as the next shell ends'] = function()
  local buffers = open_with_panes()
  show_pane('terminal')
  child.cmd('bwipeout! ' .. buffers.shell)
  eq(wait_until(REPORT_SHOWN, { buffers.report }), true)
  local arrangement = layout.arrangement(buffers)
  arrangement.shell = child.lua_get([[require('aineo.shell').start({ cwd = vim.uv.cwd() })]])

  show_pane('terminal', arrangement)
  local report_window = layout.window_showing(child, arrangement.shell)
  type_into_shell(arrangement.shell, 'exit 3')

  eq(wait_until('not vim.api.nvim_buf_is_valid(...)', { arrangement.shell }), true)
  eq(child.api.nvim_win_get_buf(report_window), buffers.report)
end

--- Makes, in the child, a terminal whose process ends with status 3 once it is
--- sent a line, and that nothing wipes: the stand-in for a shell without the
--- shell home, which wipes the buffer of a shell that ended. `_G.ended`
--- becomes true in the child once Neovim has told that the process ended.
---
---@return integer buffer
local function unwiped_terminal()
  return child.lua_get([[(function()
    _G.ended = false
    local buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_call(buffer, function()
      vim.fn.jobstart({ '/bin/sh', '-c', 'read line; exit 3' }, { term = true })
    end)
    vim.api.nvim_create_autocmd('TermClose', {
      buffer = buffer,
      callback = function()
        _G.ended = true
      end,
    })
    return buffer
  end)()]])
end

T['a shell that ends and is not wiped'] = MiniTest.new_set({
  parametrize = { { 'agent' }, { 'changes' }, { 'terminal' } },
})

T['a shell that ends and is not wiped']['is forgotten, whichever pane showed, so that the terminal pane is refused without a new shell, for'] = function(
  pane
)
  local buffers = open_with_panes()
  buffers.shell = unwiped_terminal()
  local arrangement = layout.arrangement(buffers)
  arrangement.shell = buffers.shell
  layout.open(child, arrangement)
  show_pane(pane)

  type_into_shell(buffers.shell, '')
  eq(wait_until('_G.ended'), true)

  local shown, message = pcall(
    child.lua,
    [[require('aineo.layout').show_pane('terminal', ...)]],
    { layout.arrangement(buffers) }
  )
  eq(shown, false)
  eq(message:find('arrangement.shell', 1, true) ~= nil, true)
end

--- Runs, in the child, the scheduled callbacks queued so far, and those they
--- queue in turn.
local function flush_scheduled()
  child.lua([[
    local done = false
    vim.schedule(function()
      vim.schedule(function()
        done = true
      end)
    end)
    vim.wait(1000, function()
      return done
    end)
  ]])
end

--- The ways a shell goes where no handler of aineo's sees it, which a
--- command run in an autocommand that is not nested does: a user's `TermClose`
--- handler that deletes the terminal, written in Lua and in Vimscript (with a
--- `'shell'` that Neovim's own handler leaves alone), each with what ends the
--- shell.
local UNSEEN_WIPES = {
  {
    [[vim.api.nvim_create_autocmd('TermClose', {
      callback = function(event)
        vim.api.nvim_buf_delete(event.buf, { force = true })
      end,
    })]],
    TEST_SHELL,
    'exit 3',
  },
  {
    [[vim.cmd("autocmd TermClose * if !v:event.status | exe 'bdelete! '..expand('<abuf>') | endif")]],
    'sh',
    'exit 0',
  },
}

T['a shell wiped where no handler sees it'] = MiniTest.new_set({ parametrize = UNSEEN_WIPES })

T['a shell wiped where no handler sees it']['leaves the Report shown again and the layout working, for a user’s handler'] = function(
  user_setup,
  shell,
  ending
)
  local buffers = open_with_panes(user_setup, shell)
  show_pane('terminal')

  type_into_shell(buffers.shell, ending)

  eq(wait_until(REPORT_SHOWN, { buffers.report }), true)
  eq(child.lua_get([[require('aineo.shell').shell_buffer()]]), vim.NIL)
  local focused = pcall(layout.focus, child, 'report', layout.arrangement(buffers))
  eq(focused, true)
  eq(layout.window_count(child), 3)
end

--- The calls that must work after a shell was stopped where no handler saw
--- it, each written as a Lua chunk that is given the arrangement.
local CALLS_AFTER_AN_UNSEEN_STOP = {
  { [[require('aineo.layout').open(...)]] },
  { [[require('aineo.layout').focus('report', ...)]] },
  { [[require('aineo.layout').show_pane('agent', ...)]] },
}

T['a shell stopped where no handler sees it'] = MiniTest.new_set({
  parametrize = CALLS_AFTER_AN_UNSEEN_STOP,
})

T['a shell stopped where no handler sees it']['leaves the layout working on the agent pane, for the call'] = function(
  call
)
  local buffers = open_with_panes()
  show_pane('terminal')
  child.lua([[
    vim.api.nvim_create_autocmd('User', {
      pattern = 'AineoTestStop',
      callback = function()
        require('aineo.shell').stop()
      end,
    })
    vim.api.nvim_exec_autocmds('User', { pattern = 'AineoTestStop' })
  ]])

  local worked = pcall(child.lua, call, { layout.arrangement(buffers) })

  eq(worked, true)
  eq(child.api.nvim_win_get_buf(layout.window_showing(child, buffers.report)), buffers.report)
  eq(layout.window_count(child), 3)
end

T['a shell that ends while the user closed windows of the layout'] = MiniTest.new_set()

T['a shell that ends while the user closed windows of the layout']['leaves the Report’s window closed'] = function()
  local buffers = open_with_panes()
  show_pane('terminal')
  child.lua('vim.api.nvim_win_close(vim.fn.win_findbuf(...)[1], false)', { buffers.shell })

  type_into_shell(buffers.shell, 'exit 3')
  eq(wait_until('not vim.api.nvim_buf_is_valid(...)', { buffers.shell }), true)
  flush_scheduled()

  eq(child.lua_get('vim.fn.win_findbuf(...)', { buffers.report }), {})
  eq(layout.window_count(child), 2)
end

T['a shell that ends while the user closed windows of the layout']['reopens the Report’s window when its wipe closed it, and leaves Input’s closed'] = function()
  local buffers = open_with_panes()
  show_pane('terminal')
  child.lua('vim.api.nvim_win_close(vim.fn.win_findbuf(...)[1], false)', { buffers.input })

  type_into_shell(buffers.shell, 'exit 0')
  eq(wait_until(REPORT_SHOWN, { buffers.report }), true)
  flush_scheduled()

  eq(child.lua_get('vim.fn.win_findbuf(...)', { buffers.input }), {})
  eq(layout.window_count(child), 2)
end

--- Records, in the child, what `vim.notify()` is told, in `_G.notices`.
local function record_notices()
  child.lua([[
    _G.notices = {}
    vim.notify = function(message)
      table.insert(_G.notices, message)
    end
  ]])
end

T['a shell that ends in a window that refuses another buffer'] = MiniTest.new_set()

T['a shell that ends in a window that refuses another buffer']['tells nothing when its wipe, a tick later, shows the agent pane'] = function()
  local buffers = open_with_panes()
  show_pane('terminal')
  record_notices()
  child.api.nvim_set_option_value(
    'winfixbuf',
    true,
    { win = layout.window_showing(child, buffers.shell) }
  )

  type_into_shell(buffers.shell, 'exit 3')
  eq(wait_until(REPORT_SHOWN, { buffers.report }), true)
  flush_scheduled()

  eq(child.lua_get('_G.notices'), {})
end

T['a shell that ends in a window that refuses another buffer']['tells once, without a file or a line of aineo’s, when the agent pane still cannot show'] = function()
  local buffers = open_with_panes()
  buffers.shell = unwiped_terminal()
  local arrangement = layout.arrangement(buffers)
  arrangement.shell = buffers.shell
  layout.open(child, arrangement)
  show_pane('terminal')
  record_notices()
  child.api.nvim_set_option_value(
    'winfixbuf',
    true,
    { win = layout.window_showing(child, buffers.shell) }
  )

  type_into_shell(buffers.shell, '')
  eq(wait_until('#_G.notices > 0'), true)
  flush_scheduled()

  local notices = child.lua_get('_G.notices')
  eq(#notices, 1)
  eq(notices[1]:find('winfixbuf', 1, true) ~= nil, true)
  eq(notices[1]:find('.lua', 1, true), nil)
end

return T
