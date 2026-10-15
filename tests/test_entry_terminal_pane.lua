local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local entry_shell = dofile('tests/helpers/entry_shell.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local tabs = dofile('tests/helpers/entry_tabs.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

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
--- shell have ended by a hangup (`END_TERMINALS`): Neovim quitting then has
--- no Claude Code for aineo to stop by its keys, a stop that waits some 4.4 s
--- for the fake to exit once it reads its keys.
local function stop_the_child()
  if child.is_running() then
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      stop_the_child()
      entry.restart(child)
      child.o.shell = entry_shell.TEST_SHELL
    end,
    post_once = stop_the_child,
  },
})

--- What the layout's windows show under the terminal pane, as
--- `entry.windows()` lists them: Claude's terminal, the shell's, Input.
local TERMINAL_PANE = { 'terminal', 'terminal', 'aineo://input' }

--- What the layout's windows show under the agent pane, as `entry.windows()`
--- lists them.
local AGENT_PANE = { 'terminal', 'aineo://report', 'aineo://input' }

--- What the layout's windows show under the changes pane, as
--- `entry.windows()` lists them.
local CHANGES_PANE = { 'terminal', 'aineo://changes-files', 'aineo://changes-commits' }

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, and waits until Claude Code has launched.
---
---@param name string the case's own name for its files, starting `terminal-pane-`
---@return table fake
local function open_layout(name)
  local fake = claude_session.fake(name, 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
  return fake
end

--- Each door to the terminal pane, as a set's `parametrize`: its name, and
--- the function that opens it.
local DOORS = {
  {
    'pressing \\pt',
    function()
      entry.press(child, '\\pt')
    end,
  },
  {
    'pressing <Plug>(aineo-pane-terminal)',
    function()
      entry.press(child, '<Plug>(aineo-pane-terminal)')
    end,
  },
  {
    'running :Aineo pane terminal',
    function()
      entry.command(child, 'Aineo pane terminal')
    end,
  },
}

T['the terminal pane'] = MiniTest.new_set()

T['the terminal pane']['shows a shell in the Report’s window, telling the user nothing, by'] =
  MiniTest.new_set({ parametrize = DOORS })

T['the terminal pane']['shows a shell in the Report’s window, telling the user nothing, by']['a door'] = function(
  _,
  door
)
  open_layout('terminal-pane-doors')

  door()

  eq({ entry.windows(child), entry.messages(child) }, { TERMINAL_PANE, {} })
end

T['the terminal pane']['leaves the cursor in the shell, in Terminal mode, by'] = MiniTest.new_set({
  parametrize = DOORS,
})

T['the terminal pane']['leaves the cursor in the shell, in Terminal mode, by']['a door'] = function(
  _,
  door
)
  open_layout('terminal-pane-mode')

  door()

  eq(
    { tabs.mode_once(child, 't'), child.lua_get('vim.api.nvim_get_current_buf()') },
    { 't', entry_shell.first_tab_buffer(child) }
  )
end

T['the terminal pane']['shows the same shell again, with its output, and starts none, after \\pa hid it'] = function()
  open_layout('terminal-pane-again')
  entry.press(child, '\\pt')
  local shell = entry_shell.first_tab_buffer(child)
  entry_shell.type_into(child, shell, 'echo kept-output')
  eq(entry_shell.shows(child, shell, 'kept-output'), true)
  entry.press(child, '\\pa')

  entry.press(child, '\\pt')

  eq(entry_shell.first_tab_buffer(child), shell)
  eq(entry_shell.buffer_of_window(child, 2), shell)
  eq(entry_shell.shows(child, shell, 'kept-output'), true)
  eq(child.lua_get(entry_shell.TERMINAL_JOBS), 2)
end

T['the terminal pane']['starts the shell in the folder, whatever :tcd says'] = function()
  open_layout('terminal-pane-folder')
  local elsewhere = fixture.directory('terminal-pane/elsewhere')
  child.cmd('tcd ' .. vim.fn.fnameescape(elsewhere))

  entry.press(child, '\\pt')

  local shell = entry_shell.first_tab_buffer(child)
  entry_shell.type_into(child, shell, 'echo "in=[$(basename "$(pwd -P)")]"')
  eq(entry_shell.shows(child, shell, 'in=[' .. vim.fs.basename(vim.fn.getcwd()) .. ']'), true)
end

T['the terminal pane']['opens the layout first, around a Claude Code it starts, when none is open'] = function()
  local fake = claude_session.fake('terminal-pane-first', 'ready')
  entry.use_fake(child, fake)

  entry.press(child, '\\pt')

  claude_session.wait_for_start(fake)
  eq(entry.windows(child), TERMINAL_PANE)
end

T['the terminal pane']['is shown again by \\o once the layout’s windows are gone, while the shell lives'] = function()
  open_layout('terminal-pane-restore')
  entry.press(child, '\\pt')
  local shell = entry_shell.first_tab_buffer(child)
  child.cmd('only')

  entry.press(child, '\\o')

  eq(entry.windows(child), TERMINAL_PANE)
  eq(entry_shell.buffer_of_window(child, 2), shell)
end

--- What the terminal pane tells the user when `'shell'` names a program that
--- is not executable.
local NOT_EXECUTABLE = "aineo: 'shell': '/nonexistent/aineo-t70-shell' is not executable"

T['the terminal pane']["when 'shell' is not executable"] = MiniTest.new_set()

T['the terminal pane']["when 'shell' is not executable"]['tells the user once, naming it, and changes no pane'] = function()
  open_layout('terminal-pane-refused')
  child.o.shell = '/nonexistent/aineo-t70-shell'
  local current = child.lua_get('vim.api.nvim_get_current_win()')

  entry.press(child, '\\pt')

  eq(
    { entry.messages(child), entry.windows(child), child.lua_get('vim.api.nvim_get_current_win()') },
    {
      { { message = NOT_EXECUTABLE, level = vim.log.levels.ERROR } },
      AGENT_PANE,
      current,
    }
  )
end

T['the terminal pane']["when 'shell' is not executable"]['opens no layout when none is open'] = function()
  entry.use_fake(child, claude_session.fake('terminal-pane-refused-closed', 'ready'))
  child.o.shell = '/nonexistent/aineo-t70-shell'

  entry.press(child, '\\pt')

  eq(
    { entry.messages(child), entry.windows(child) },
    { { { message = NOT_EXECUTABLE, level = vim.log.levels.ERROR } }, { '' } }
  )
end

--- The expression, run in the child, that tells the mode it is in, as
--- `nvim_get_mode()` names it.
local MODE = 'vim.api.nvim_get_mode().mode'

--- How each mode the twin is pressed in is entered, by its name in
--- `nvim_get_mode()`.
local ENTER = {
  t = function()
    entry.press(child, '\\c')
  end,
  i = function()
    entry.press(child, '\\i')
    child.cmd('startinsert')
  end,
}

T['the twin <C-\\>pt'] = MiniTest.new_set({ parametrize = { { 't' }, { 'i' } } })

T['the twin <C-\\>pt']['shows the shell and leaves the cursor in it, in Terminal mode, from Terminal and Insert mode'] = function(
  mode
)
  open_layout('terminal-pane-twin-' .. mode)
  ENTER[mode]()
  eq(child.lua_get(MODE), mode)

  child.type_keys('<C-\\>pt')

  eq({
    entry.windows(child),
    tabs.mode_once(child, 't'),
    child.lua_get('vim.api.nvim_get_current_buf()'),
  }, { TERMINAL_PANE, 't', entry_shell.first_tab_buffer(child) })
end

T['the terminal pane']['moves to the aineo tab used last, from a tab page that is none of aineo’s'] = function()
  open_layout('terminal-pane-other-page')
  child.cmd('tabnew')

  entry.press(child, '\\pt')

  eq({
    child.lua_get('vim.api.nvim_tabpage_get_number(vim.api.nvim_get_current_tabpage())'),
    entry.windows(child),
  }, { 1, TERMINAL_PANE })
end

T['while the terminal pane shows'] = MiniTest.new_set()

T['while the terminal pane shows']['the key of another pane or window acts as it does, and the shell runs on, for'] =
  MiniTest.new_set({
    parametrize = {
      { '\\pa', AGENT_PANE, 'aineo://report' },
      { '\\g', CHANGES_PANE, 'aineo://changes-commits' },
      { '\\r', AGENT_PANE, 'aineo://report' },
      { '\\i', TERMINAL_PANE, 'aineo://input' },
      { '\\c', TERMINAL_PANE, 'terminal' },
    },
  })

T['while the terminal pane shows']['the key of another pane or window acts as it does, and the shell runs on, for']['the key'] = function(
  keys,
  windows,
  current
)
  open_layout('terminal-pane-keys')
  entry.press(child, '\\pt')
  local shell = entry_shell.first_tab_buffer(child)
  local pid = entry_shell.pid_of(child, shell)

  entry.press(child, keys)

  eq(
    { entry.windows(child), entry.current_window(child), entry_shell.is_running(pid) },
    { windows, current, true }
  )
end

T['a shell that ends'] = MiniTest.new_set()

T['a shell that ends']['gives the Report back to its window, with the cursor in it, telling the user nothing'] = function()
  open_layout('terminal-pane-exit')
  entry.press(child, '\\pt')
  local shell = entry_shell.first_tab_buffer(child)

  entry_shell.type_into(child, shell, 'exit')

  eq(
    entry_shell.wait_until(
      child,
      'vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()) == "aineo://report"'
    ),
    true
  )
  eq(
    { entry.windows(child), entry_shell.first_tab_buffer(child), entry.messages(child) },
    { AGENT_PANE, vim.NIL, {} }
  )
end

--- Opens the first tab of aineo and a second one after it in the child, for a
--- case named `name`, and waits until both Claude Codes are ready. Returns the
--- first tab's fake.
---
---@param name string
---@return table first
local function open_two_tabs(name)
  local state, first = tabs.open_first_tab(child, name)
  tabs.use_next_fake(child, tabs.fake(name .. '-second'))
  child.cmd('Aineo tab new')
  tabs.session_of_tab(state, child, tabs.FIRST_TAB)
  tabs.session_of_tab(state, child, '2')
  return first
end

T['each tab'] = MiniTest.new_set()

T['each tab']['has a shell of its own, which the key of the other tab leaves as it was'] = function()
  open_two_tabs('terminal-pane-own')
  entry.press(child, '\\pt')
  local second_shell = child.lua_get('vim.api.nvim_get_current_buf()')
  child.cmd('1tabnext')

  entry.press(child, '\\pt')

  local first_shell = child.lua_get('vim.api.nvim_get_current_buf()')
  eq(first_shell ~= second_shell, true)
  eq(entry_shell.first_tab_buffer(child), first_shell)
  eq(tabs.windows_of_tab(child, 1), TERMINAL_PANE)
  eq(tabs.windows_of_tab(child, 2), TERMINAL_PANE)
  eq(child.lua_get(entry_shell.TERMINAL_JOBS), 4)
  eq(child.lua_get('vim.api.nvim_win_get_buf(vim.api.nvim_tabpage_list_wins(2)[2])'), second_shell)
end

T['each tab']['leaves the other tab’s pane as it was when its own shell starts'] = function()
  open_two_tabs('terminal-pane-other-pane')

  entry.press(child, '\\pt')

  eq(tabs.windows_of_tab(child, 1), AGENT_PANE)
  eq(tabs.windows_of_tab(child, 2), TERMINAL_PANE)
end

--- Each way the current tab page closes that the cases run, as a set's
--- `parametrize`: its name, and the function that closes the tab page.
local CLOSE_WAYS = {
  {
    ':tabclose',
    function()
      child.cmd('tabclose')
    end,
  },
  {
    '\\Q',
    function()
      entry.press(child, '\\Q')
    end,
  },
}

T['a tab that closes'] = MiniTest.new_set({ parametrize = CLOSE_WAYS })

T['a tab that closes']['stops its shell and wipes its buffer, and the other tab’s shell runs on'] = function(
  _,
  close_the_tab
)
  open_two_tabs('terminal-pane-close')
  entry.press(child, '\\pt')
  local second_shell = child.lua_get('vim.api.nvim_get_current_buf()')
  local second_pid = entry_shell.pid_of(child, second_shell)
  child.cmd('1tabnext')
  entry.press(child, '\\pt')
  local first_shell = entry_shell.first_tab_buffer(child)
  local first_pid = entry_shell.pid_of(child, first_shell)
  child.cmd('2tabnext')

  close_the_tab()

  eq(entry_shell.has_ended(second_pid), true)
  eq({
    entry_shell.is_running(first_pid),
    child.lua_get('vim.api.nvim_buf_is_valid(...)', { second_shell }),
    child.lua_get('vim.api.nvim_buf_is_valid(...)', { first_shell }),
  }, { true, false, true })
end

T['a tab that closes']['stops its shell before its Claude Code, which ignores its keys, has stopped'] = function(
  _,
  close_the_tab
)
  local state = tabs.open_first_tab(child, 'terminal-pane-close-order')
  local deaf = tabs.fake('terminal-pane-close-order-second', 'deaf')
  entry.use_fake(child, deaf, { claude = { cmd = claude_session.deaf_fake_command() } })
  child.cmd('Aineo tab new')
  local claude_pid = claude_session.wait_for_start(deaf).pid
  MiniTest.finally(function()
    pcall(vim.uv.kill, -claude_pid, 'sigkill')
  end)
  tabs.session_of_tab(state, child, '2')
  entry.press(child, '\\pt')
  local shell_pid = entry_shell.pid_of(child, child.lua_get('vim.api.nvim_get_current_buf()'))

  close_the_tab()

  eq(entry_shell.has_ended(shell_pid), true)
  eq(entry_shell.is_running(claude_pid), true)
end

T['the first tab that closes'] = MiniTest.new_set()

--- What the windows of a tab page the first tab was taken up again in show
--- under the agent pane and under the terminal pane: the empty window the tab
--- page was opened with sits left of the Report's window.
local TAKEN_UP_AGAIN_AGENT_PANE = { 'terminal', '', 'aineo://report', 'aineo://input' }
local TAKEN_UP_AGAIN_TERMINAL_PANE = { 'terminal', '', 'terminal', 'aineo://input' }

T['the first tab that closes']['stops its shell, and the tab opened in its place starts a new one under the agent pane'] = function()
  local first = open_two_tabs('terminal-pane-first')
  child.cmd('1tabnext')
  entry.press(child, '\\pt')
  local old_pid = entry_shell.pid_of(child, entry_shell.first_tab_buffer(child))
  child.cmd('1tabclose')
  eq(entry_shell.has_ended(old_pid), true)
  eq(tabs.ended_how(first) ~= nil, true)
  tabs.use_next_fake(child, tabs.fake('terminal-pane-first-third'))

  child.cmd('Aineo tab new')

  eq(entry.windows(child), TAKEN_UP_AGAIN_AGENT_PANE)
  entry.press(child, '\\pt')
  local new_pid = entry_shell.pid_of(child, entry_shell.first_tab_buffer(child))
  eq(
    { entry.windows(child), new_pid ~= old_pid, entry_shell.is_running(new_pid) },
    { TAKEN_UP_AGAIN_TERMINAL_PANE, true, true }
  )
end

T['the first tab that closes']['stops its shell before its Claude Code, which ignores its keys, has stopped'] = function()
  local state = tabs.use_own_state(child, 'terminal-pane-first-order')
  local deaf = tabs.fake('terminal-pane-first-order-first', 'deaf')
  entry.use_fake(child, deaf, { claude = { cmd = claude_session.deaf_fake_command() } })
  child.cmd('Aineo open')
  local claude_pid = claude_session.wait_for_start(deaf).pid
  MiniTest.finally(function()
    pcall(vim.uv.kill, -claude_pid, 'sigkill')
  end)
  entry.press(child, '\\pt')
  local shell_pid = entry_shell.pid_of(child, entry_shell.first_tab_buffer(child))
  tabs.use_next_fake(child, tabs.fake('terminal-pane-first-order-second'))
  child.cmd('Aineo tab new')
  tabs.session_of_tab(state, child, '2')

  child.cmd('1tabclose')

  eq(entry_shell.has_ended(shell_pid), true)
  eq(entry_shell.is_running(claude_pid), true)
end

T['quitting'] = MiniTest.new_set()

T['quitting']['with a shell running quits, and leaves no shell process'] = function()
  open_layout('terminal-pane-quit')
  entry.press(child, '\\pt')
  local pid = entry_shell.pid_of(child, entry_shell.first_tab_buffer(child))

  claude_session.quit(child)

  eq(entry_shell.has_ended(pid), true)
end

return T
