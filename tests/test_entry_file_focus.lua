local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local entry_shell = dofile('tests/helpers/entry_shell.lua')
local find_pickers = dofile('tests/helpers/find_pickers.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
local tabs = dofile('tests/helpers/entry_tabs.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- How long a case waits for the child to reach a state, in milliseconds.
local PATIENCE_MS = 10000

--- How long a case watches a cursor for a move that should not come, in
--- milliseconds: longer than the explorer takes to read its tree again.
local CURSOR_SETTLE_MS = 1500

--- The Lua that ends, in the child, the process of every terminal by a
--- hangup, and waits for each to end, at most 5 s each.
local END_TERMINALS = [[
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      local job = vim.b[buffer].terminal_job_id
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 5000)
    end
  end
]]

--- Stops the child, once the fake Claude Code it runs, if any, and the
--- processes of the run pane have ended by a hangup (`END_TERMINALS`).
local function stop_the_child()
  if child.is_running() then
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

--- Takes on the git isolation of the git home's suites
--- (`git_repo.ENVIRONMENT`) in this file's own Neovim, which every child it
--- starts inherits.
local function isolate_git()
  for name, value in pairs(git_repo.ENVIRONMENT) do
    vim.env[name] = value
  end
end

local T = MiniTest.new_set({
  hooks = {
    pre_once = isolate_git,
    pre_case = function()
      stop_the_child()
      entry.restart(child)
      child.o.shell = entry_shell.TEST_SHELL
      child.lua([[
        _G.run_answers = {}
        vim.ui.input = function(_, on_confirm)
          on_confirm(table.remove(_G.run_answers, 1))
        end
      ]])
    end,
    post_once = stop_the_child,
  },
})

--- The files of the repository the cases explore.
local FILES = {
  ['README.md'] = { 'readme' },
  ['NOTES.md'] = { 'notes' },
  ['src/main.lua'] = { 'main' },
}

--- Makes the repository `file-focus-<name>` of `FILES`, moves the child's
--- working directory there and opens the layout with aineo running the fake
--- `claude` in its `ready` mode and `settings` as `vim.g.aineo`, a fake file
--- picker opening `picked` when there is one, once Claude Code is ready;
--- returns the repository's top.
---
---@param name string
---@param settings? table
---@param picked? string the path, from the repository's top, the fake picker opens
---@return string top
local function open_in_repository(name, settings, picked)
  local top = git_repo.create('file-focus-' .. name, FILES)
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake('file-focus-' .. name, 'ready'), settings)
  find_pickers.install(child, { 'snacks' }, picked and vim.fs.joinpath(top, picked) or false)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  return top
end

--- Waits, at most `PATIENCE_MS`, until the explorer's tree is read: its
--- buffer holds more than its header and a first row.
local function wait_for_tree()
  vim.wait(PATIENCE_MS, function()
    return child.lua_get([[(function()
      local buffer = vim.fn.bufnr('aineo://explorer')
      return buffer ~= -1 and vim.api.nvim_buf_line_count(buffer) > 2
    end)()]])
  end, 20)
end

--- Opens the layout as `open_in_repository()` does, with the explorer column
--- on `column`, and moves the cursor into it once its tree is read.
---
---@param name string
---@param column 'left'|'right'
---@param picked? string
---@return string top
local function open_with_column(name, column, picked)
  local top = open_in_repository(name, { layout = { explorer_column = column } }, picked)
  entry.press(child, '\\e')
  wait_for_tree()
  return top
end

--- Puts the cursor of the child's current window on the line that ends with
--- `text`.
---
---@param text string
local function put_cursor_on(text)
  child.lua(
    [[
      local text = ...
      for line, shown in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        if vim.endswith(shown, text) then
          vim.api.nvim_win_set_cursor(0, { line, 0 })
          return
        end
      end
      error('no line ends with ' .. text)
    ]],
    { text }
  )
end

--- The lines of the explorer's buffer in the child, the header first.
---
---@return string[]
local function explorer_lines()
  return child.lua_get(
    [[vim.api.nvim_buf_get_lines(vim.fn.bufnr('aineo://explorer'), 0, -1, false)]]
  )
end

--- Whether the first tab's layout has the file focus on, in the child.
---
---@return boolean
local function is_focused()
  return child.lua_get([[require('aineo.layout').is_file_focused()]])
end

--- Waits, at most `PATIENCE_MS`, until the windows of the child's current
--- tab show `expected`, left to right and then top to bottom, and returns
--- what they show then.
---
---@param expected string[]
---@return string[]
local function wait_for_windows(expected)
  local windows
  vim.wait(PATIENCE_MS, function()
    windows = entry.windows(child)
    return vim.deep_equal(windows, expected)
  end, 20)
  return windows
end

--- Waits, at most `PATIENCE_MS`, until the child's current window shows a
--- buffer named `name`, and returns what it shows then.
---
---@param name string
---@return string
local function wait_for_current_window(name)
  vim.wait(PATIENCE_MS, function()
    return entry.current_window(child) == name
  end, 20)
  return entry.current_window(child)
end

--- The width of the terminal's window and of the explorer's in the child's
--- current tab.
---
---@return { terminal: integer, explorer: integer }
local function side_widths()
  return child.lua_get([[(function()
    local widths = {}
    for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local buffer = vim.api.nvim_win_get_buf(window)
      if vim.bo[buffer].buftype == 'terminal' then
        widths.terminal = widths.terminal or vim.api.nvim_win_get_width(window)
      elseif vim.api.nvim_buf_get_name(buffer):find('aineo://explorer', 1, true) then
        widths.explorer = vim.api.nvim_win_get_width(window)
      end
    end
    return widths
  end)()]])
end

--- Opens `path`, a file, in the child's current window, which the layout
--- moves to the file column, and waits until a window shows it.
---
---@param path string
local function open_file(path)
  child.cmd('edit ' .. vim.fn.fnameescape(path))
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('vim.fn.bufwinid(vim.fn.bufnr(...)) ~= -1', { path })
      and entry.current_window(child) ~= path
  end, 20)
end

--- `names`, a list of what windows show, with the word `FILE` in it turned
--- into `file`.
---
---@param names string[]
---@param file string
---@return string[]
local function with_file(names, file)
  return vim.tbl_map(function(name)
    return name == 'FILE' and file or name
  end, names)
end

--- Whether the focus is on in each tab of the child, the first tab first.
---
---@return boolean[]
local function focused_tabs()
  return child.lua_get([[vim.tbl_map(function(tab)
    return tab.homes.layout.is_file_focused()
  end, require('aineo.entry.registry').tab_list)]])
end

--- The windows of a layout with the explorer column on the right, the panes
--- column closed by the file focus and the file `name` of the repository
--- `top` in the file column.
---
---@param top string
---@param name string
---@return string[]
local function focused_on(top, name)
  return { 'terminal', vim.fs.joinpath(top, name), 'aineo://explorer' }
end

--- The windows of the same layout with the file focus off, the file column
--- beside the explorer column as the layout has it by default.
---
---@param top string
---@param name string
---@return string[]
local function unfocused_on(top, name)
  return {
    'terminal',
    'aineo://report',
    'aineo://input',
    vim.fs.joinpath(top, name),
    'aineo://explorer',
  }
end

--- Opens the layout with the explorer column on the right, shows `README.md`
--- with `<C-l>` and waits for the file focus; returns the repository's top.
---
---@param name string
---@param picked? string
---@return string top
local function focus_on_readme(name, picked)
  local top = open_with_column(name, 'right', picked)
  put_cursor_on('README.md')
  entry.press(child, '<C-l>')
  wait_for_windows(focused_on(top, 'README.md'))
  return top
end

T['<C-l> in the explorer column'] = MiniTest.new_set()

T['<C-l> in the explorer column']['on a file shows it and closes the panes column, the cursor staying in the tree'] = function()
  local top = open_with_column('on-file', 'right')
  put_cursor_on('README.md')

  entry.press(child, '<C-l>')

  eq(wait_for_windows(focused_on(top, 'README.md')), focused_on(top, 'README.md'))
  eq(wait_for_current_window('aineo://explorer'), 'aineo://explorer')
  eq(child.lua_get('vim.api.nvim_get_current_line()'), '    README.md')
  eq(is_focused(), true)
  eq(entry.messages(child), {})
end

T['<C-l> in the explorer column']['on a file with the explorer column on the left does the same'] = function()
  local top = open_with_column('on-file-left', 'left')
  put_cursor_on('README.md')

  entry.press(child, '<C-l>')

  local expected = { 'aineo://explorer', vim.fs.joinpath(top, 'README.md'), 'terminal' }
  eq(wait_for_windows(expected), expected)
  eq(is_focused(), true)
end

T['<C-l> in the explorer column']['on a folder arms the focus: nothing closes, opens or changes size'] = function()
  open_with_column('on-folder', 'right')
  local tree = vim.list_slice(explorer_lines(), 2)
  local windows, widths = entry.windows(child), side_widths()
  put_cursor_on('src/')

  entry.press(child, '<C-l>')

  vim.wait(PATIENCE_MS, is_focused, 20)
  eq(is_focused(), true)
  eq(entry.windows(child), windows)
  eq(side_widths(), widths)
  eq(vim.list_slice(explorer_lines(), 2), tree)
  eq(entry.messages(child), {})
end

T['<C-l> in the explorer column']['armed on a folder, a file opened starts it and the file column closed brings the panes back, the widths of Claude and the explorer never changing'] = function()
  local top = open_with_column('armed-widths', 'right')
  local windows, widths = entry.windows(child), side_widths()
  put_cursor_on('src/')
  entry.press(child, '<C-l>')
  vim.wait(PATIENCE_MS, is_focused, 20)
  local armed = side_widths()
  put_cursor_on('README.md')

  entry.press(child, 'l')
  wait_for_windows(focused_on(top, 'README.md'))
  local applied = side_widths()
  child.lua(
    'vim.api.nvim_win_close(vim.fn.bufwinid(vim.fn.bufnr(...)), false)',
    { vim.fs.joinpath(top, 'README.md') }
  )
  wait_for_windows(windows)

  eq({ armed, applied, side_widths() }, { widths, widths, widths })
  eq(is_focused(), true)
end

T['<C-l> in the explorer column']['of a second tab turns the focus on for that tab alone'] = function()
  tabs.use_own_state(child, 'file-focus-explorer-tabs')
  local top = git_repo.create('file-focus-explorer-tabs', FILES)
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  local settings = { layout = { explorer_column = 'right' } }
  entry.use_fake(child, tabs.fake('file-focus-explorer-tabs-first'), settings)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.use_fake(child, tabs.fake('file-focus-explorer-tabs-second'), settings)
  child.cmd('Aineo tab new')
  claude_session.wait_for_status(child, 'ready')
  entry.press(child, '\\e')

  entry.press(child, '<C-l>')

  vim.wait(PATIENCE_MS, function()
    return focused_tabs()[2]
  end, 20)
  eq(focused_tabs(), { false, true })
end

T['<C-l> in the explorer column']['again, on a file, turns the focus off and opens nothing'] = function()
  local top = focus_on_readme('again')
  put_cursor_on('NOTES.md')

  entry.press(child, '<C-l>')

  eq(wait_for_windows(unfocused_on(top, 'README.md')), unfocused_on(top, 'README.md'))
  eq(is_focused(), false)
  eq(entry.current_window(child), 'aineo://explorer')
  eq(child.lua_get('vim.api.nvim_get_current_line()'), '    NOTES.md')
end

T['<C-l> in the explorer column']['again, on a folder, turns the focus off'] = function()
  local top = focus_on_readme('again-folder')
  put_cursor_on('src/')

  entry.press(child, '<C-l>')

  eq(wait_for_windows(unfocused_on(top, 'README.md')), unfocused_on(top, 'README.md'))
  eq(is_focused(), false)
end

T['<C-l> in the explorer column']['says what it does in its description'] = function()
  open_with_column('description', 'right')

  local description = child.lua_get("vim.fn.maparg('<C-l>', 'n', false, true).desc")

  local rows = vim.tbl_filter(function(row)
    return row.group == 'explorer_pane' and row.key == '<C-l>'
  end, require('aineo.keys').rows())
  eq(#rows, 1)
  eq(description, 'aineo explorer: ' .. rows[1].phrase)
end

T['<C-l> in the explorer pane'] = MiniTest.new_set()

T['<C-l> in the explorer pane']['on a file shows it and closes the panes column, the pane with it'] = function()
  local top = open_in_repository('pane')
  entry.press(child, '\\e')
  wait_for_tree()
  put_cursor_on('README.md')

  entry.press(child, '<C-l>')

  local expected = { 'terminal', vim.fs.joinpath(top, 'README.md') }
  eq(wait_for_windows(expected), expected)
  eq(is_focused(), true)
  eq(entry.messages(child), {})
end

--- Each key that opens a file in the explorer, as a set's `parametrize`.
local OPENING_KEYS = { { 'l' }, { '<CR>' } }

T['a file opened by a key of the explorer while the file focus is on'] =
  MiniTest.new_set({ parametrize = OPENING_KEYS })

T['a file opened by a key of the explorer while the file focus is on']['takes the file column and leaves the panes column closed'] = function(
  key
)
  local top = focus_on_readme('opened-' .. (key == 'l' and 'l' or 'enter'))
  put_cursor_on('NOTES.md')

  entry.press(child, key)

  eq(wait_for_windows(focused_on(top, 'NOTES.md')), focused_on(top, 'NOTES.md'))
  eq(is_focused(), true)
end

T['a file opened with \\f while the file focus is on'] = MiniTest.new_set()

T['a file opened with \\f while the file focus is on']['takes the file column and leaves the panes column closed'] = function()
  local top = focus_on_readme('opened-find', 'src/main.lua')

  entry.press(child, '\\f')

  eq(wait_for_windows(focused_on(top, 'src/main.lua')), focused_on(top, 'src/main.lua'))
  eq(is_focused(), true)
end

--- The windows a layout with the explorer column on the right and `README.md`
--- in the file column shows with `pane` in the panes column.
---
---@param top string
---@param pane 'agent'|'changes'|'terminal'
---@return string[]
local function showing_pane(top, pane)
  local panes = {
    agent = { 'aineo://report', 'aineo://input' },
    changes = { 'aineo://changes-files', 'aineo://changes-commits' },
    terminal = { 'terminal' },
  }
  return vim.list_extend(
    vim.list_extend({ 'terminal' }, panes[pane]),
    { vim.fs.joinpath(top, 'README.md'), 'aineo://explorer' }
  )
end

--- Each key that shows a pane of the panes column, as a set's `parametrize`:
--- the keys, the answer the run pane's command is asked for, the pane that
--- shows once they ran and what the window the cursor is in shows.
local PANE_KEYS = {
  { '\\r', '', 'agent', 'aineo://report' },
  { '\\i', '', 'agent', 'aineo://input' },
  { '\\g', '', 'changes', 'aineo://changes-commits' },
  { '\\pa', '', 'agent', 'aineo://report' },
  { '\\pt', '', 'terminal', 'terminal' },
  { '\\o', '', 'agent', 'aineo://explorer' },
  { '<Plug>(aineo-report)', '', 'agent', 'aineo://report' },
  { '<Plug>(aineo-input)', '', 'agent', 'aineo://input' },
  { '<Plug>(aineo-pane-changes)', '', 'changes', 'aineo://changes-commits' },
  { '\\x', 'sleep 30', 'terminal', 'terminal' },
}

T['a pane key while the file focus is on'] = MiniTest.new_set({ parametrize = PANE_KEYS })

T['a pane key while the file focus is on']['ends it and brings the panes column back with its pane'] = function(
  keys,
  answer,
  pane,
  current
)
  local top = focus_on_readme('pane-key')
  child.o.shell = '/bin/sh'
  child.lua('table.insert(_G.run_answers, ...)', { answer })

  entry.press(child, keys)

  eq(is_focused(), false)
  eq(entry.windows(child), showing_pane(top, pane))
  eq(entry.current_window(child), current)
  eq(entry.messages(child), {})
end

--- Each way to ask for the focus, as a set's `parametrize`: its name and the
--- function that asks.
local FOCUS_DOORS = {
  {
    'running :Aineo focus',
    function()
      entry.command(child, 'Aineo focus')
    end,
  },
  {
    'pressing <Plug>(aineo-focus)',
    function()
      entry.press(child, '<Plug>(aineo-focus)')
    end,
  },
}

T['the file focus asked for'] = MiniTest.new_set({ parametrize = FOCUS_DOORS })

T['the file focus asked for']['is turned on and off from any window, by'] = function(_, door)
  local top = open_in_repository('door', { layout = { explorer_column = 'right' } })
  entry.press(child, '\\r')
  local file = vim.fs.joinpath(top, 'README.md')
  open_file(file)
  local whole = entry.windows(child)

  door()
  local focused = entry.windows(child)
  door()

  eq(focused, { 'terminal', file, 'aineo://explorer' })
  eq(entry.windows(child), whole)
  eq(entry.messages(child), {})
end

T[':Aineo focus'] = MiniTest.new_set()

T[':Aineo focus']['is offered as a word of :Aineo'] = function()
  local offered = child.lua_get([[vim.fn.getcompletion('Aineo fo', 'cmdline')]])

  eq(offered, { 'focus' })
end

T[':Aineo focus']['tells the user, and opens nothing, in a tab page that is no aineo tab'] = function()
  child.cmd('Aineo focus')

  eq(#entry.messages(child), 1)
  eq(#child.lua_get('vim.api.nvim_tabpage_list_wins(0)'), 1)
end

T['the file focus of a tab'] = MiniTest.new_set()

T['the file focus of a tab']['leaves the other tabs alone'] = function()
  tabs.use_own_state(child, 'file-focus-tabs')
  entry.use_fake(child, tabs.fake('file-focus-tabs-first'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.use_fake(child, tabs.fake('file-focus-tabs-second'))
  child.cmd('Aineo tab new')
  claude_session.wait_for_status(child, 'ready')
  local file = fixture.write('file-focus/tabs.txt', { 'a file' })
  child.cmd('tabnext 1')
  open_file(file)
  child.cmd('tabnext 2')
  open_file(file)
  local whole = { tabs.windows_of_tab(child, 1), tabs.windows_of_tab(child, 2) }

  child.cmd('tabnext 1')
  child.cmd('Aineo focus')
  local after_first = { tabs.windows_of_tab(child, 1), tabs.windows_of_tab(child, 2) }
  child.cmd('tabnext 2')
  child.cmd('Aineo focus')
  child.cmd('tabnext 1')
  child.cmd('Aineo focus')
  local after_ending_first = { tabs.windows_of_tab(child, 1), tabs.windows_of_tab(child, 2) }

  eq(after_first, { { 'terminal', file }, whole[2] })
  eq(after_ending_first, { whole[1], { 'terminal', file } })
end

--- Each change of the layout the file focus survives, as a set's
--- `parametrize`: the command, and the windows the layout shows after it,
--- with the explorer column on the right and a file in the file column,
--- which `FILE` stands for.
local LAYOUT_CHANGES = {
  { 'Aineo layout swap', { 'terminal', 'FILE', 'aineo://explorer' } },
  { 'Aineo layout mirror', { 'aineo://explorer', 'FILE', 'terminal' } },
  { 'Aineo layout right', { 'terminal', 'FILE', 'aineo://explorer' } },
  { 'Aineo explorer column', { 'terminal', 'FILE' } },
}

T['a layout changed while the file focus is on'] = MiniTest.new_set({
  parametrize = LAYOUT_CHANGES,
})

T['a layout changed while the file focus is on']['keeps it, the panes column closed, by'] = function(
  command,
  expected
)
  local top = open_in_repository('layout', { layout = { explorer_column = 'right' } })
  local file = vim.fs.joinpath(top, 'README.md')
  open_file(file)
  entry.command(child, 'Aineo focus')

  entry.command(child, command)

  eq(is_focused(), true)
  eq(entry.windows(child), with_file(expected, file))
end

T['a process of the run pane while the file focus is on'] = MiniTest.new_set()

--- The entries of the child's first tab's run home: each process's name and
--- the status it exited with, nil while it runs.
---
---@return { name: string, status: integer? }[]
local function processes()
  return child.lua_get([[vim.tbl_map(function(entry)
    return { name = entry.name, status = entry.status }
  end, require('aineo.run').entries())]])
end

--- Starts `command` in the child's run pane by `\x`, answering its prompt.
---
---@param command string
local function run(command)
  child.lua('table.insert(_G.run_answers, ...)', { command })
  entry.press(child, '\\x')
end

T['a process of the run pane while the file focus is on']['that ended keeps its place in the stack as the focus starts'] = function()
  local top = open_in_repository('run-ended', { layout = { explorer_column = 'right' } })
  run('exit 3')
  vim.wait(PATIENCE_MS, function()
    return processes()[1] ~= nil and processes()[1].status ~= nil
  end, 20)
  open_file(vim.fs.joinpath(top, 'README.md'))

  entry.command(child, 'Aineo focus')

  eq(is_focused(), true)
  eq(processes(), { { name = 'exit 3', status = 3 } })
end

T['a process of the run pane while the file focus is on']['whose terminal is wiped leaves the focus on'] = function()
  local top = open_in_repository('run-wiped', { layout = { explorer_column = 'right' } })
  run('sleep 30')
  local file = vim.fs.joinpath(top, 'README.md')
  open_file(file)
  entry.command(child, 'Aineo focus')

  child.lua([[vim.api.nvim_buf_delete(require('aineo.run').buffers()[1], { force = true })]])

  eq(is_focused(), true)
  eq(entry.windows(child), { 'terminal', file, 'aineo://explorer' })
end

T['a process of the run pane while the file focus is on']["started by the agent's run tool leaves the focus on, the process joining the stack unseen"] = function()
  local top = focus_on_readme('run-tool')

  child.lua(
    [[require('aineo.entry.registry').tab_of_current_page().start_in_run_stack('sleep 30', { name = 'agent-run' })]]
  )

  eq(is_focused(), true)
  eq(entry.windows(child), focused_on(top, 'README.md'))
  eq(processes(), { { name = 'agent-run' } })
end

T['the explorer pane under the file focus'] = MiniTest.new_set()

T['the explorer pane under the file focus']['the explorer column turned on keeps the focus and opens no Input'] = function()
  local top = open_in_repository('pane-then-column', { layout = { explorer_column = false } })
  entry.press(child, '\\e')
  wait_for_tree()
  put_cursor_on('README.md')
  entry.press(child, '<C-l>')
  local file = vim.fs.joinpath(top, 'README.md')
  wait_for_windows({ 'terminal', file })

  entry.command(child, 'Aineo explorer column')

  local expected = { 'aineo://explorer', file, 'terminal' }
  eq(wait_for_windows(expected), expected)
  eq(is_focused(), true)
end

T['the explorer pane under the file focus']['comes back with the cursor on the entry it was on'] = function()
  local top = open_in_repository('pane-cursor', { layout = { explorer_column = false } })
  entry.press(child, '\\e')
  wait_for_tree()
  put_cursor_on('NOTES.md')
  local line = child.lua_get('vim.api.nvim_win_get_cursor(0)[1]')
  entry.press(child, '<C-l>')
  wait_for_windows({ 'terminal', vim.fs.joinpath(top, 'NOTES.md') })

  entry.command(child, 'Aineo focus')

  wait_for_windows({ 'terminal', vim.fs.joinpath(top, 'NOTES.md'), 'aineo://explorer' })
  local explorer_cursor =
    [=[vim.api.nvim_win_get_cursor(vim.fn.win_findbuf(vim.fn.bufnr('aineo://explorer'))[1])[1]]=]
  vim.wait(CURSOR_SETTLE_MS, function()
    return child.lua_get(explorer_cursor) ~= line
  end, 20)
  eq(child.lua_get(explorer_cursor), line)
end

return T
