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
--- processes of the run pane have ended by a hangup (`END_TERMINALS`).
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
      child.lua([[
        _G.run_prompts = {}
        _G.run_answers = {}
        vim.ui.input = function(options, on_confirm)
          table.insert(_G.run_prompts, options)
          on_confirm(table.remove(_G.run_answers, 1))
        end
      ]])
    end,
    post_once = stop_the_child,
  },
})

--- What the layout's windows show under the agent pane, as `entry.windows()`
--- lists them.
local AGENT_PANE = { 'terminal', 'aineo://report', 'aineo://input' }

--- What the layout's windows show under the run pane with `count` processes,
--- as `entry.windows()` lists them: Claude's terminal and each process's.
---
---@param count integer
---@return string[]
local function run_pane(count)
  return vim.fn['repeat']({ 'terminal' }, count + 1)
end

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, and waits until Claude Code has launched.
---
---@param name string the case's own name for its files, starting `run-pane-`
---@return table fake
local function open_layout(name)
  local fake = claude_session.fake(name, 'ready')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_start(fake)
  return fake
end

--- Answers the next prompts of the run pane with `answers`, in order; an
--- answer of `false` is Esc.
---
---@param answers (string|boolean)[]
local function answer_prompts(answers)
  child.lua(
    [[
      for _, answer in ipairs(...) do
        table.insert(_G.run_answers, answer ~= false and answer or nil)
      end
    ]],
    { answers }
  )
end

--- The options the run pane has prompted with since the case began.
---
---@return table[]
local function prompts()
  return child.lua_get('_G.run_prompts')
end

--- The expression, run in a Neovim, that lists the windows right of the first
--- column of its current tab, top to bottom: the stack of the run pane, each
--- with the buffer it shows, the winbar it draws and its height.
local STACK = [[(function()
  local stack = {}
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local position = vim.api.nvim_win_get_position(window)
    if position[2] > 0 and vim.api.nvim_win_get_config(window).relative == '' then
      table.insert(stack, {
        row = position[1],
        window = window,
        buffer = vim.api.nvim_win_get_buf(window),
        height = vim.api.nvim_win_get_height(window),
        winbar = vim.api.nvim_eval_statusline(
          vim.wo[window].winbar,
          { winid = window, use_winbar = true }
        ).str,
      })
    end
  end
  table.sort(stack, function(a, b)
    return a.row < b.row
  end)
  return stack
end)()]]

--- The stack of the run pane in the child (`STACK`).
---
---@return { window: integer, buffer: integer, height: integer, winbar: string }[]
local function stack()
  return child.lua_get(STACK)
end

--- Each door to the run pane, as a set's `parametrize`: its name, and the
--- function that opens it.
local DOORS = {
  {
    'pressing \\x',
    function()
      entry.press(child, '\\x')
    end,
  },
  {
    'pressing <Plug>(aineo-pane-run)',
    function()
      entry.press(child, '<Plug>(aineo-pane-run)')
    end,
  },
  {
    'running :Aineo pane run',
    function()
      entry.command(child, 'Aineo pane run')
    end,
  },
}

T['the prompt'] = MiniTest.new_set()

T['the prompt']['asks for a command, completing shell commands, when the tab runs nothing, by'] =
  MiniTest.new_set({ parametrize = DOORS })

T['the prompt']['asks for a command, completing shell commands, when the tab runs nothing, by']['a door'] = function(
  _,
  door
)
  open_layout('run-pane-prompt')
  answer_prompts({ false })

  door()

  eq(#prompts(), 1)
  eq(prompts()[1].completion, 'shellcmd')
  eq(type(prompts()[1].prompt), 'string')
end

T['the prompt']['starts nothing and shows no pane when the answer is empty, blank or Esc'] =
  MiniTest.new_set({ parametrize = { { '' }, { '   ' }, { false } } })

T['the prompt']['starts nothing and shows no pane when the answer is empty, blank or Esc']['answer'] = function(
  answer
)
  open_layout('run-pane-empty')
  answer_prompts({ answer })

  entry.press(child, '\\x')

  eq(
    { entry.windows(child), entry.messages(child), child.lua_get("require('aineo.run').buffers()") },
    { AGENT_PANE, {}, {} }
  )
end

--- The buffers of the first aineo tab's processes, oldest first.
---
---@return integer[]
local function process_buffers()
  return child.lua_get("require('aineo.run').buffers()")
end

T['starting a command'] = MiniTest.new_set()

T['starting a command']['shows the run pane with one window that names the command and says it runs, by'] =
  MiniTest.new_set({ parametrize = DOORS })

T['starting a command']['shows the run pane with one window that names the command and says it runs, by']['a door'] = function(
  _,
  door
)
  open_layout('run-pane-start')
  answer_prompts({ 'sleep 30' })

  door()

  eq(entry.windows(child), run_pane(1))
  eq(
    vim.tbl_map(function(window)
      return window.winbar
    end, stack()),
    { 'sleep 30 — running' }
  )
  eq(stack()[1].buffer, process_buffers()[1])
end

T['starting a command']['leaves the cursor in the new window, in Normal mode'] = function()
  open_layout('run-pane-cursor')
  answer_prompts({ 'sleep 30' })

  entry.press(child, '\\x')

  eq(child.lua_get('vim.api.nvim_get_current_buf()'), process_buffers()[1])
  eq(tabs.normal_mode_once(child), 'nt')
end

T['starting a command']['runs it through the shell, in the folder aineo started in, with AINEO_CHILD set'] = function()
  open_layout('run-pane-environment')
  local started_in = vim.uv.fs_realpath(child.lua_get('vim.fn.getcwd()'))
  local elsewhere = fixture.directory('run-pane/elsewhere')
  child.cmd('tcd ' .. vim.fn.fnameescape(elsewhere))
  answer_prompts({ 'echo "in=[$(basename "$(pwd -P)")] child=[$AINEO_CHILD]"' })

  entry.press(child, '\\x')

  local expected = 'in=[' .. vim.fs.basename(started_in) .. '] child=[1]'
  eq(entry_shell.shows(child, process_buffers()[1], expected), true)
end

--- Runs each of `commands` in the child by `\x`, answering the prompt, the
--- cursor in the stack as the second and later ones need.
---
---@param commands string[]
local function run_all(commands)
  for _, command in ipairs(commands) do
    answer_prompts({ command })
    entry.press(child, '\\x')
  end
end

--- The winbars of the stack in the child, top to bottom.
---
---@return string[]
local function winbars()
  return vim.tbl_map(function(window)
    return window.winbar
  end, stack())
end

T['the stack'] = MiniTest.new_set()

T['the stack']['adds each new process at the bottom, asking again as \\x is pressed in the stack'] = function()
  open_layout('run-pane-stack')

  run_all({ 'sleep 31', 'sleep 32', 'sleep 33' })

  eq(#prompts(), 3)
  eq(winbars(), { 'sleep 31 — running', 'sleep 32 — running', 'sleep 33 — running' })
  eq(
    vim.tbl_map(function(window)
      return window.buffer
    end, stack()),
    process_buffers()
  )
  eq(entry.windows(child), run_pane(3))
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), process_buffers()[3])
end

T['the stack']['gives the windows equal heights, filling the right column'] = function()
  open_layout('run-pane-heights')

  run_all({ 'sleep 31', 'sleep 32', 'sleep 33' })
  local heights = vim.tbl_map(function(window)
    return window.height
  end, stack())

  eq(math.abs(heights[1] - heights[2]) <= 1 and math.abs(heights[2] - heights[3]) <= 1, true)
  eq(heights[1] > 3, true)
end

T['the stack']['says exited with the status in the winbar of a process that ended'] = function()
  open_layout('run-pane-exited')

  run_all({ 'sleep 31', 'exit 7' })

  eq(
    vim.wait(entry_shell.PATIENCE_MS, function()
      return winbars()[2] == 'exit 7 — exited 7'
    end, 20),
    true
  )
  eq(winbars()[1], 'sleep 31 — running')
end

T['starting a command']['opens the layout first, around a Claude Code it starts, when none is open'] = function()
  local fake = claude_session.fake('run-pane-first', 'ready')
  entry.use_fake(child, fake)
  answer_prompts({ 'sleep 30' })

  entry.press(child, '\\x')

  claude_session.wait_for_start(fake)
  eq(entry.windows(child), run_pane(1))
  eq(winbars(), { 'sleep 30 — running' })
end

T['showing the pane again'] = MiniTest.new_set()

T['showing the pane again']['is done by \\o once the layout’s windows are gone, the processes running on'] = function()
  open_layout('run-pane-restore')
  run_all({ 'sleep 31', 'sleep 32' })
  local pid = entry_shell.pid_of(child, process_buffers()[1])
  child.cmd('only')

  entry.press(child, '\\o')

  eq(entry.windows(child), run_pane(2))
  eq(winbars(), { 'sleep 31 — running', 'sleep 32 — running' })
  eq(entry_shell.is_running(pid), true)
end

T['showing the pane again']['shows the stack and moves the cursor to the bottom window, asking nothing, when processes run'] = function()
  open_layout('run-pane-again')
  run_all({ 'sleep 31', 'sleep 32' })
  entry.press(child, '\\pa')

  entry.press(child, '\\x')

  eq(#prompts(), 2)
  eq(entry.windows(child), run_pane(2))
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), process_buffers()[2])
end

T['showing the pane again']['moves the cursor to the bottom window, asking nothing, from a window outside the stack'] = function()
  open_layout('run-pane-outside')
  run_all({ 'sleep 31', 'sleep 32' })
  child.lua('vim.api.nvim_set_current_win(vim.fn.win_getid(1))')

  entry.press(child, '\\x')

  eq(#prompts(), 2)
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), process_buffers()[2])
end

--- Each key that gives the right column to another pane, with what the
--- layout's windows show after it, as a set's `parametrize`.
local OTHER_PANES = {
  { '\\pa', AGENT_PANE },
  { '\\g', { 'terminal', 'aineo://changes-files', 'aineo://changes-commits' } },
  { '\\r', AGENT_PANE },
  { '\\i', AGENT_PANE },
}

T['showing the pane again']['hides the stack for another pane, the processes running on, and shows it with its output again'] =
  MiniTest.new_set({ parametrize = OTHER_PANES })

T['showing the pane again']['hides the stack for another pane, the processes running on, and shows it with its output again']['key'] = function(
  key,
  windows
)
  open_layout('run-pane-hide')
  run_all({ 'echo kept-output; sleep 30' })
  local buffer = process_buffers()[1]
  local pid = entry_shell.pid_of(child, buffer)
  entry_shell.shows(child, buffer, 'kept-output')

  entry.press(child, key)
  local hidden = { entry.windows(child), entry_shell.is_running(pid) }
  entry.press(child, '\\x')

  eq(hidden, { windows, true })
  eq(entry.windows(child), run_pane(1))
  eq(process_buffers(), { buffer })
  eq(entry_shell.shows(child, buffer, 'kept-output'), true)
  eq(#prompts(), 1)
end

T['showing the pane again']['gives way to the terminal pane, and to the run pane again, the shell and the processes running on'] = function()
  open_layout('run-pane-and-terminal')
  run_all({ 'sleep 31' })

  entry.press(child, '\\pt')
  local terminal_pane = entry.windows(child)
  entry.press(child, '\\x')

  eq(terminal_pane, { 'terminal', 'terminal' })
  eq(entry.windows(child), run_pane(1))
  eq(child.lua_get(entry_shell.TERMINAL_JOBS), 3)
end

--- Waits until the winbar of the stack's `place`-th window reads `text`, and
--- says whether it did.
---
---@param place integer
---@param text string
---@return boolean
local function winbar_becomes(place, text)
  return vim.wait(entry_shell.PATIENCE_MS, function()
    return winbars()[place] == text
  end, 20)
end

--- Closes the stack's `place`-th window as the user does, with `:q` in it.
---
---@param place integer
local function quit_window(place)
  child.lua('vim.api.nvim_set_current_win(...)', { stack()[place].window })
  child.cmd('quit')
end

T['a process that ends'] = MiniTest.new_set()

T['a process that ends']['keeps its window and its output, with the status in the winbar'] = function()
  open_layout('run-pane-ends')
  run_all({ 'echo last-words; exit 3', 'sleep 31' })

  eq(winbar_becomes(1, 'echo last-words; exit 3 — exited 3'), true)

  eq(entry.windows(child), run_pane(2))
  eq(entry_shell.shows(child, process_buffers()[1], 'last-words'), true)
end

T['a process that ends']['leaves the stack when the user closes its window, the other windows sharing the rows'] = function()
  open_layout('run-pane-ended-closed')
  run_all({ 'exit 0', 'sleep 31', 'sleep 32' })
  winbar_becomes(1, 'exit 0 — exited 0')
  local ended = process_buffers()[1]

  quit_window(1)
  local left = vim.wait(entry_shell.PATIENCE_MS, function()
    return #process_buffers() == 2
  end, 20)

  eq(left, true)
  eq(child.lua_get('vim.api.nvim_buf_is_valid(...)', { ended }), false)
  eq(winbars(), { 'sleep 31 — running', 'sleep 32 — running' })
  eq(entry.windows(child), run_pane(2))
end

T['a process that ends']['gives way to the agent pane when it was the last one and its window is closed'] = function()
  open_layout('run-pane-last-closed')
  run_all({ 'exit 0' })
  winbar_becomes(1, 'exit 0 — exited 0')

  quit_window(1)
  local agent = vim.wait(entry_shell.PATIENCE_MS, function()
    return child.lua_get("require('aineo.layout').shown_pane()") == 'agent'
  end, 20)

  eq(agent, true)
  eq(entry.windows(child), AGENT_PANE)
  eq(process_buffers(), {})
end

T['a process that runs'] = MiniTest.new_set()

T['a process that runs']['only hides when the user closes its window with :q, and comes back with the next \\x'] = function()
  open_layout('run-pane-quit-window')
  run_all({ 'sleep 31', 'sleep 32' })
  local buffers = process_buffers()
  local pid = entry_shell.pid_of(child, buffers[1])

  quit_window(1)
  local hidden = { #stack(), process_buffers(), entry_shell.is_running(pid) }
  answer_prompts({ false })
  entry.press(child, '\\x')

  eq(hidden, { 1, buffers, true })
  eq(winbars(), { 'sleep 31 — running', 'sleep 32 — running' })
end

T['a process that runs']['comes back with the next \\x pressed outside the stack, which asks nothing'] = function()
  open_layout('run-pane-quit-window-outside')
  run_all({ 'sleep 31', 'sleep 32' })
  quit_window(2)
  child.lua('vim.api.nvim_set_current_win(vim.fn.win_getid(1))')

  entry.press(child, '\\x')

  eq(winbars(), { 'sleep 31 — running', 'sleep 32 — running' })
  eq(#prompts(), 2)
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), process_buffers()[2])
end

T['a process that runs']['is stopped with its children by :bdelete! on its terminal, and leaves the stack'] = function()
  open_layout('run-pane-bdelete')
  local folder = fixture.directory('run-pane/bdelete')
  run_all({
    'sleep 31',
    'nohup sleep 300 >/dev/null 2>&1 & echo $! > ' .. folder .. '/child.pid; wait',
  })
  local deleted = process_buffers()[2]
  local pid = entry_shell.pid_of(child, deleted)
  local child_pid
  vim.wait(entry_shell.PATIENCE_MS, function()
    local lines = vim.fn.filereadable(folder .. '/child.pid') == 1
        and vim.fn.readfile(folder .. '/child.pid')
      or {}
    child_pid = tonumber(lines[1])
    return child_pid ~= nil
  end, 20)

  child.cmd('bdelete! ' .. deleted)
  local ended = { entry_shell.has_ended(pid), entry_shell.has_ended(child_pid) }
  pcall(vim.uv.kill, child_pid, 'sigkill')

  eq(ended, { true, true })
  eq(
    vim.wait(entry_shell.PATIENCE_MS, function()
      return #stack() == 1
    end, 20),
    true
  )
  eq(winbars(), { 'sleep 31 — running' })
end

--- Each door to the interactive shell of the run pane, as a set's
--- `parametrize`.
local SHELL_DOORS = {
  {
    'pressing \\X',
    function()
      entry.press(child, '\\X')
    end,
  },
  {
    'pressing <Plug>(aineo-run-shell)',
    function()
      entry.press(child, '<Plug>(aineo-run-shell)')
    end,
  },
  {
    'running :Aineo run shell',
    function()
      entry.command(child, 'Aineo run shell')
    end,
  },
}

T['the interactive shell'] = MiniTest.new_set()

T['the interactive shell']['joins the bottom of the stack as `shell`, with the cursor in it in Terminal mode, by'] =
  MiniTest.new_set({ parametrize = SHELL_DOORS })

T['the interactive shell']['joins the bottom of the stack as `shell`, with the cursor in it in Terminal mode, by']['a door'] = function(
  _,
  door
)
  open_layout('run-pane-shell')
  run_all({ 'sleep 31' })

  door()

  eq(winbars(), { 'sleep 31 — running', 'shell — running' })
  eq(entry.windows(child), run_pane(2))
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), process_buffers()[2])
  eq(tabs.mode_once(child, 't'), 't')
  eq(#prompts(), 1)
end

T['the interactive shell']['shows the pane with `shell` alone when the tab runs nothing, asking nothing'] = function()
  open_layout('run-pane-shell-alone')

  entry.press(child, '\\X')

  eq(winbars(), { 'shell — running' })
  eq(#prompts(), 0)
end

T['the interactive shell']['starts in the folder aineo started in, with AINEO_CHILD set'] = function()
  open_layout('run-pane-shell-environment')
  local started_in = vim.uv.fs_realpath(child.lua_get('vim.fn.getcwd()'))
  child.cmd('tcd ' .. vim.fn.fnameescape(fixture.directory('run-pane/shell-elsewhere')))

  entry.press(child, '\\X')
  local buffer = process_buffers()[1]
  entry_shell.type_into(child, buffer, 'echo "in=[$(basename "$(pwd -P)")] child=[$AINEO_CHILD]"')

  eq(entry_shell.shows(child, buffer, 'in=[' .. vim.fs.basename(started_in) .. '] child=[1]'), true)
end

T['the interactive shell']['says how it exited in its winbar when it ends with a failure'] = function()
  open_layout('run-pane-shell-exit')
  entry.press(child, '\\X')
  local buffer = process_buffers()[1]

  entry_shell.type_into(child, buffer, 'exit 4')

  eq(winbar_becomes(1, 'shell — exited 4'), true)
end

--- Ends the fake Claude Code of the child by its keys, so that quitting the
--- child does not spend the whole stop of Claude Code.
---
---@param fake table
local function end_claude(fake)
  claude_session.end_by_keys(child, fake, child.lua_get('vim.fn.winbufnr(1)'))
end

--- Makes the child answer the question of a quit with `answer`, the number
--- of the button (1 quits, 2 cancels), and keep every question it was asked,
--- with its buttons, in `record`, a file: the child may quit.
---
---@param answer integer
---@param record string
local function answer_questions(answer, record)
  child.lua(
    [[
      local answer, record = ...
      vim.fn.confirm = function(message, choices, default)
        vim.fn.writefile({ message, choices, tostring(default) }, record, 'a')
        return answer
      end
    ]],
    { answer, record }
  )
end

--- The lines the child wrote to `record` (`answer_questions()`), empty while
--- it wrote none.
---
---@param record string
---@return string[]
local function questions_asked(record)
  return vim.fn.filereadable(record) == 1 and vim.fn.readfile(record) or {}
end

--- Starts `commands` in the child by `\x`, and each service that starts a
--- child of its own writes that child's process id to a file of its own;
--- returns the process ids of the processes and of those children, once
--- written.
---
---@param folder string
---@return integer[] pids
local function start_services_with_children(folder)
  run_all({
    'nohup sleep 301 >/dev/null 2>&1 & echo $! > ' .. folder .. '/first.pid; wait',
    'nohup sleep 302 >/dev/null 2>&1 & echo $! > ' .. folder .. '/second.pid; wait',
  })
  local pids = {}
  for _, name in ipairs({ 'first', 'second' }) do
    vim.wait(entry_shell.PATIENCE_MS, function()
      return vim.fn.filereadable(folder .. '/' .. name .. '.pid') == 1
        and #vim.fn.readfile(folder .. '/' .. name .. '.pid') == 1
    end, 20)
    table.insert(pids, tonumber(vim.fn.readfile(folder .. '/' .. name .. '.pid')[1]))
  end
  for _, buffer in ipairs(process_buffers()) do
    table.insert(pids, entry_shell.pid_of(child, buffer))
  end
  return pids
end

--- Waits until every process of `pids` has ended, and kills any that has
--- not, so that no case leaves one behind; returns those that had not.
---
---@param pids integer[]
---@return integer[] survivors
local function survivors_of(pids)
  local survivors = vim.tbl_filter(function(pid)
    return not entry_shell.has_ended(pid)
  end, pids)
  for _, pid in ipairs(pids) do
    pcall(vim.uv.kill, pid, 'sigkill')
  end
  return survivors
end

T['quitting'] = MiniTest.new_set()

T['quitting']['asks once, listing the commands, and stops every process with its children when the user quits'] = function()
  local fake = open_layout('run-pane-quit')
  local folder = fixture.directory('run-pane/quit')
  local record = folder .. '/questions'
  answer_questions(1, record)
  local pids = start_services_with_children(folder)
  end_claude(fake)

  claude_session.quit(child)
  vim.fn.jobwait({ child.job.id }, claude_session.STOP_PATIENCE_MS)

  eq(survivors_of(pids), {})
  eq(questions_asked(record), {
    'aineo: 2 processes will be stopped ('
      .. 'nohup sleep 301 >/dev/null 2>&1 & echo $! > '
      .. folder
      .. '/first.pid; wait, '
      .. 'nohup sleep 302 >/dev/null 2>&1 & echo $! > '
      .. folder
      .. '/second.pid; wait) — quit?',
    '&Quit\n&Cancel',
    '2',
  })
  child.stop()
end

T['quitting']['keeps the editor open, the cursor where it was and the processes running, when the user cancels'] = function()
  local fake = open_layout('run-pane-quit-cancel')
  local folder = fixture.directory('run-pane/quit-cancel')
  local record = folder .. '/questions'
  answer_questions(2, record)
  local pids = start_services_with_children(folder)
  local window = child.lua_get('vim.api.nvim_get_current_win()')
  local page_count = child.lua_get('#vim.api.nvim_list_tabpages()')

  claude_session.quit(child)
  vim.wait(entry_shell.PATIENCE_MS, function()
    return #questions_asked(record) == 3
  end, 20)
  local settled = vim.wait(entry_shell.PATIENCE_MS, function()
    return child.is_running() and child.lua_get('#vim.api.nvim_list_tabpages()') == page_count
  end, 20)
  local kept = {
    child.lua_get('vim.api.nvim_get_current_win()'),
    child.lua_get('#vim.api.nvim_list_tabpages()'),
    vim.tbl_map(function(pid)
      return vim.uv.kill(pid, 0) == 0
    end, pids),
    #questions_asked(record),
  }
  end_claude(fake)
  answer_questions(1, record)
  claude_session.quit(child)
  vim.fn.jobwait({ child.job.id }, claude_session.STOP_PATIENCE_MS)
  local survivors = survivors_of(pids)

  eq(settled, true)
  eq(kept, { window, page_count, { true, true, true, true }, 3 })
  eq(survivors, {})
  child.stop()
end

T['quitting']['asks nothing and stops the processes when the quit is forced with :qa!'] = function()
  local fake = open_layout('run-pane-quit-forced')
  local folder = fixture.directory('run-pane/quit-forced')
  local record = folder .. '/questions'
  answer_questions(2, record)
  local pids = start_services_with_children(folder)
  end_claude(fake)

  pcall(child.type_keys, ':qa!<CR>')
  vim.fn.jobwait({ child.job.id }, claude_session.STOP_PATIENCE_MS)

  eq(survivors_of(pids), {})
  eq(questions_asked(record), {})
  child.stop()
end

T['quitting']['asks nothing when no process runs, and counts a process that ended for none'] = function()
  local fake = open_layout('run-pane-quit-none')
  local folder = fixture.directory('run-pane/quit-none')
  local record = folder .. '/questions'
  answer_questions(2, record)
  run_all({ 'exit 0' })
  winbar_becomes(1, 'exit 0 — exited 0')
  end_claude(fake)

  claude_session.quit(child)
  vim.fn.jobwait({ child.job.id }, claude_session.STOP_PATIENCE_MS)

  eq(questions_asked(record), {})
  child.stop()
end

T['quitting']['asks when :q closes the last window, and keeps the editor open on Cancel'] = function()
  open_layout('run-pane-quit-last-window')
  local folder = fixture.directory('run-pane/quit-last-window')
  local record = folder .. '/questions'
  answer_questions(2, record)
  run_all({ 'sleep 301' })
  child.cmd('only')

  child.lua_notify('vim.cmd.quit()')
  vim.wait(entry_shell.PATIENCE_MS, function()
    return #questions_asked(record) == 3
  end, 20)

  eq(#questions_asked(record), 3)
  eq(child.lua_get('#vim.api.nvim_list_tabpages()'), 1)
  eq(child.is_running(), true)
end

T['quitting']['stops the processes when the editor leaves, whatever else runs, and tells the user once when nothing asked'] = function()
  open_layout('run-pane-quit-leave')
  local folder = fixture.directory('run-pane/quit-leave')
  local pids = start_services_with_children(folder)
  child.lua('vim.api.nvim_exec_autocmds("VimLeavePre", {})')

  local messages = entry.messages(child)

  eq(survivors_of(pids), {})
  eq(#messages, 1)
  eq(messages[1].level, vim.log.levels.WARN)
  eq(messages[1].message:find('aineo: stopping 2 processes (', 1, true), 1)
end

T['a process that cannot start'] = MiniTest.new_set()

--- What the run pane tells the user when the shell is not executable.
local NOT_EXECUTABLE =
  "aineo: E475: Invalid value for argument cmd: '/nonexistent/aineo-t91-shell' is not executable"

T['a process that cannot start']['is told once, naming the shell, and starts nothing nor shows the pane'] =
  MiniTest.new_set({ parametrize = { { '\\x' }, { '\\X' } } })

T['a process that cannot start']['is told once, naming the shell, and starts nothing nor shows the pane']['key'] = function(
  key
)
  open_layout('run-pane-refused')
  child.lua("vim.o.shell = '/nonexistent/aineo-t91-shell'")
  answer_prompts({ 'sleep 30' })

  entry.press(child, key)

  eq(
    { entry.messages(child), entry.windows(child), process_buffers() },
    { { { message = NOT_EXECUTABLE, level = vim.log.levels.ERROR } }, AGENT_PANE, {} }
  )
end

--- What the run pane tells the user when the folder aineo started in is gone.
---
---@param folder string
---@return string
local function folder_is_gone(folder)
  return ('aineo: the folder aineo started in is gone, so nothing started: %s'):format(folder)
end

T['a process that cannot start']['is told once, in its own words, when the folder aineo started in is gone'] = function()
  local folder = fixture.directory('run-pane/gone')
  child.cmd('cd ' .. vim.fn.fnameescape(folder))
  open_layout('run-pane-gone')
  vim.fn.delete(folder, 'rf')
  answer_prompts({ 'sleep 30' })

  entry.press(child, '\\x')

  eq(
    { entry.messages(child), entry.windows(child), process_buffers() },
    { { { message = folder_is_gone(folder), level = vim.log.levels.ERROR } }, AGENT_PANE, {} }
  )
end

--- What the run pane tells the user when Claude Code cannot start.
local CLAUDE_CANNOT_START = "aineo: claude.cmd: '/nonexistent/aineo-t91-claude' is not executable"

T['a process that cannot start']['is stopped, telling the user once, when the layout cannot open for it'] = function()
  child.lua([[vim.g.aineo = { claude = { cmd = { '/nonexistent/aineo-t91-claude' } } }]])
  answer_prompts({ 'sleep 30' })

  entry.press(child, '\\x')

  eq(
    { entry.messages(child), process_buffers(), child.lua_get(entry_shell.TERMINAL_JOBS) },
    { { { message = CLAUDE_CANNOT_START, level = vim.log.levels.ERROR } }, {}, 0 }
  )
end

T[':Aineo run'] = MiniTest.new_set()

--- What `:Aineo run` tells the user when it is not given its word.
local RUN_USAGE = 'aineo: :Aineo run takes one of shell'

T[':Aineo run']['tells the user once which word it takes, and does nothing else,'] =
  MiniTest.new_set({
    parametrize = {
      { 'without a word', 'Aineo run' },
      { 'with another word', 'Aineo run command' },
      { 'with more words after shell', 'Aineo run shell now' },
    },
  })

T[':Aineo run']['tells the user once which word it takes, and does nothing else,']['given'] = function(
  _,
  command
)
  open_layout('run-pane-usage')

  entry.command(child, command)

  eq(
    { entry.messages(child), entry.windows(child), process_buffers() },
    { { { message = RUN_USAGE, level = vim.log.levels.ERROR } }, AGENT_PANE, {} }
  )
end

T[':Aineo run']['completes shell, and the run pane among the panes'] = function()
  eq(child.lua_get([[vim.fn.getcompletion('Aineo run ', 'cmdline')]]), { 'shell' })
  eq(child.lua_get([[vim.fn.getcompletion('Aineo pane r', 'cmdline')]]), { 'run' })
end

T['the twins'] = MiniTest.new_set({ parametrize = { { 't' }, { 'i' } } })

T['the twins']['<C-\\>x asks for a command and shows the stack, from Terminal and Insert mode'] = function(
  mode
)
  open_layout('run-pane-twin-' .. mode)
  if mode == 't' then
    entry.press(child, '\\c')
  else
    entry.press(child, '\\i')
    child.cmd('startinsert')
  end
  eq(child.lua_get('vim.api.nvim_get_mode().mode'), mode)
  answer_prompts({ 'sleep 31' })

  child.type_keys('<C-\\>x')

  eq(winbars(), { 'sleep 31 — running' })
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), process_buffers()[1])
  eq(tabs.normal_mode_once(child), 'nt')
end

T['the twins']['<C-\\>X adds the interactive shell, from Terminal and Insert mode'] = function(mode)
  open_layout('run-pane-shell-twin-' .. mode)
  if mode == 't' then
    entry.press(child, '\\c')
  else
    entry.press(child, '\\i')
    child.cmd('startinsert')
  end

  child.type_keys('<C-\\>X')

  eq(winbars(), { 'shell — running' })
  eq(tabs.mode_once(child, 't'), 't')
end

return T
