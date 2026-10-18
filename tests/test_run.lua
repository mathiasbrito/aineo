local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The program the child's `'shell'` is set to: a POSIX shell that reads no
--- startup file of the user's, so a case never runs the user's own shell.
local TEST_SHELL = '/bin/sh'

--- How long a case waits for the child to reach a state, in milliseconds.
local PATIENCE_MS = 10000

--- Starts `child` afresh with `'shell'` set to `TEST_SHELL`.
local function start_child()
  children.restart(child)
  child.o.shell = TEST_SHELL
end

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

--- Waits until a line of the terminal `buffer` holds `text`, and says whether
--- one did.
---
---@param buffer integer
---@param text string
---@return boolean
local function shows(buffer, text)
  return wait_until(
    [[(function(buffer, text)
      if not vim.api.nvim_buf_is_valid(buffer) then
        return false
      end
      for _, line in ipairs(vim.api.nvim_buf_get_lines(buffer, 0, -1, false)) do
        if line:find(text, 1, true) then
          return true
        end
      end
      return false
    end)(...)]],
    { buffer, text }
  )
end

--- The settings a process starts with: a fresh folder named for the case, and
--- the variable the shell pane sets.
---
---@param name string
---@return { cwd: string, env: table<string, string>, shell: string[] }
local function settings_for(name)
  return {
    cwd = fixture.directory('run/' .. name),
    env = { AINEO_CHILD = '1' },
    shell = { TEST_SHELL },
  }
end

--- Starts `command` in `child` through the module's home with `settings`, and
--- returns its buffer.
---
---@param command string
---@param settings table
---@return integer buffer
local function start_command(command, settings)
  return child.lua_get([[require('aineo.run').start_command(...)]], { command, settings })
end

T['start_command()'] = MiniTest.new_set()

T['start_command()']['runs the command through the shell, in the folder, with AINEO_CHILD set'] = function()
  start_child()
  local settings = settings_for('start')

  local buffer = start_command('printf "in:%s:%s" "$(basename "$PWD")" "$AINEO_CHILD"', settings)

  eq(shows(buffer, 'in:start:1'), true)
end

--- What the winbar the home names (`WINBAR`) draws for the process of
--- `buffer` shown in a window of `child`.
---
---@param buffer integer
---@return string
local function winbar_of(buffer)
  return child.lua_get(
    [[(function(buffer)
      local window = vim.api.nvim_open_win(buffer, false, { split = 'below', win = 0 })
      local drawn = vim.api.nvim_eval_statusline(
        require('aineo.run').WINBAR,
        { winid = window, use_winbar = true }
      )
      vim.api.nvim_win_close(window, true)
      return drawn.str
    end)(...)]],
    { buffer }
  )
end

T['the winbar'] = MiniTest.new_set()

T['the winbar']['names the command and says that it runs'] = function()
  start_child()

  local buffer = start_command('sleep 30', settings_for('winbar-running'))

  eq(winbar_of(buffer), 'sleep 30 — running')
end

T['the winbar']['says how the process exited once it has ended, whatever the status'] =
  MiniTest.new_set({ parametrize = { { 0 }, { 3 } } })

T['the winbar']['says how the process exited once it has ended, whatever the status']['status'] = function(
  status
)
  start_child()
  local command = 'exit ' .. status

  local buffer = start_command(command, settings_for('winbar-exited-' .. status))

  eq(
    wait_until(
      [[vim.b[(...)].aineo_run_title == (select(2, ...))]],
      { buffer, command .. ' — exited ' .. status }
    ),
    true
  )
end

T['buffers()'] = MiniTest.new_set()

T['buffers()']['lists the terminal of every process, the oldest first'] = function()
  start_child()
  local first = start_command('sleep 30', settings_for('buffers-order'))
  local second = start_command('sleep 31', settings_for('buffers-order'))
  local third = start_command('sleep 32', settings_for('buffers-order'))

  local buffers = child.lua_get("require('aineo.run').buffers()")

  eq(buffers, { first, second, third })
end

T['running()'] = MiniTest.new_set()

T['running()']['lists the commands of the processes that run, not those that ended'] = function()
  start_child()
  start_command('sleep 30', settings_for('running'))
  local ended = start_command('exit 0', settings_for('running'))
  start_command('sleep 31', settings_for('running'))
  wait_until([[vim.b[(...)].aineo_run_title == 'exit 0 — exited 0']], { ended })

  local commands = child.lua_get("require('aineo.run').running()")

  eq(commands, { 'sleep 30', 'sleep 31' })
end

T['start_shell()'] = MiniTest.new_set()

T['start_shell()']['starts the shell it is given, in the folder, with AINEO_CHILD set, and calls it shell'] = function()
  start_child()
  local settings = settings_for('shell')

  local buffer = child.lua_get([[require('aineo.run').start_shell(...)]], { settings })
  child.lua(
    [[vim.fn.chansend(vim.b[(...)].terminal_job_id, 'echo "in:$(basename "$PWD"):$AINEO_CHILD"\n')]],
    { buffer }
  )

  eq(shows(buffer, 'in:shell:1'), true)
  eq(winbar_of(buffer), 'shell — running')
  eq(child.lua_get("require('aineo.run').running()"), { 'shell' })
end

--- The command that starts a background child that ignores the hangup a
--- closed terminal sends, writes its process id to `child.pid` in the folder
--- the process runs in, and waits for it.
local SERVICE_WITH_CHILD = 'nohup sleep 300 >/dev/null 2>&1 & echo $! > child.pid; wait'

--- The process id the service of `SERVICE_WITH_CHILD`, run in `folder`, wrote
--- for its child, once it has.
---
---@param folder string
---@return integer|nil pid
local function child_pid_in(folder)
  local pid
  vim.wait(PATIENCE_MS, function()
    local lines = vim.fn.filereadable(folder .. '/child.pid') == 1
        and vim.fn.readfile(folder .. '/child.pid')
      or {}
    pid = tonumber(lines[1])
    return pid ~= nil
  end, 20)
  return pid
end

--- Waits until the process `pid` has ended, and says whether it had within
--- `PATIENCE_MS`.
---
---@param pid integer
---@return boolean
local function has_ended(pid)
  local ended = vim.wait(PATIENCE_MS, function()
    return vim.uv.kill(pid, 0) ~= 0
  end, 20)
  return ended
end

--- Ends `pids` by a kill, whatever a case did before, so that no process
--- outlives it.
---
---@param pids integer[]
local function kill_all(pids)
  for _, pid in ipairs(pids) do
    pcall(vim.uv.kill, pid, 'sigkill')
  end
end

T['a process the user deletes'] = MiniTest.new_set()

T['a process the user deletes']['is stopped with its children and leaves the stack'] = function()
  start_child()
  local settings = settings_for('delete')
  local buffer = start_command(SERVICE_WITH_CHILD, settings)
  local child_pid = child_pid_in(settings.cwd)
  local pid = child.lua_get('vim.fn.jobpid(vim.b[...].terminal_job_id)', { buffer })

  child.cmd('bdelete! ' .. buffer)
  local ended = { has_ended(pid), has_ended(child_pid) }
  kill_all({ pid, child_pid })

  eq(ended, { true, true })
  eq(child.lua_get("require('aineo.run').buffers()"), {})
end

--- The command that ignores the termination and hangup signals, as does the
--- child it starts and waits for, and writes the child's process id to
--- `child.pid`.
local STUBBORN_SERVICE = "trap '' TERM HUP; sleep 300 & echo $! > child.pid; wait"

T['stop_all()'] = MiniTest.new_set()

T['stop_all()']['stops every process with its children, those that ignore signals included, and empties the stack'] = function()
  start_child()
  local polite = settings_for('stop-all-polite')
  local stubborn = settings_for('stop-all-stubborn')
  local buffers = {
    start_command(SERVICE_WITH_CHILD, polite),
    start_command(STUBBORN_SERVICE, stubborn),
  }
  local pids = {
    child_pid_in(polite.cwd),
    child_pid_in(stubborn.cwd),
    child.lua_get('vim.fn.jobpid(vim.b[...].terminal_job_id)', { buffers[1] }),
    child.lua_get('vim.fn.jobpid(vim.b[...].terminal_job_id)', { buffers[2] }),
  }

  child.lua("require('aineo.run').stop_all()")
  local remaining = vim.tbl_filter(function(pid)
    return not has_ended(pid)
  end, pids)
  kill_all(pids)

  eq(remaining, {})
  eq(child.lua_get("require('aineo.run').buffers()"), {})
end

T['start_command()']['raises, naming the folder, starts nothing and leaves no buffer when the folder is not there'] = function()
  start_child()
  local settings = { cwd = '/no/such/folder/for/run', env = {}, shell = { TEST_SHELL } }
  local buffers_before = child.lua_get('#vim.api.nvim_list_bufs()')

  local started, message = pcall(start_command, 'sleep 30', settings)

  eq(started, false)
  eq(message:find('/no/such/folder/for/run', 1, true) ~= nil, true)
  eq(
    { child.lua_get("require('aineo.run').buffers()"), child.lua_get('#vim.api.nvim_list_bufs()') },
    { {}, buffers_before }
  )
end

T['start_command()']['raises, naming the program, and leaves no buffer when the shell is not executable'] = function()
  start_child()
  local settings = settings_for('no-shell')
  settings.shell = { '/no/such/shell' }
  local buffers_before = child.lua_get('#vim.api.nvim_list_bufs()')

  local started, message = pcall(start_command, 'sleep 30', settings)

  eq(started, false)
  eq(message:find('/no/such/shell', 1, true) ~= nil, true)
  eq(
    { child.lua_get("require('aineo.run').buffers()"), child.lua_get('#vim.api.nvim_list_bufs()') },
    { {}, buffers_before }
  )
end

T['discard_ended()'] = MiniTest.new_set()

T['discard_ended()']['wipes the terminal of a process that ended and takes it out of the stack'] = function()
  start_child()
  local running = start_command('sleep 30', settings_for('discard-running'))
  local ended = start_command('exit 2', settings_for('discard-ended'))
  wait_until([[vim.b[(...)].aineo_run_title == 'exit 2 — exited 2']], { ended })

  local discarded = child.lua_get("require('aineo.run').discard_ended(...)", { ended })

  eq(discarded, true)
  eq(child.lua_get('vim.api.nvim_buf_is_valid(...)', { ended }), false)
  eq(child.lua_get("require('aineo.run').buffers()"), { running })
end

T['discard_ended()']['leaves a process that runs, and a buffer that is none of its processes'] = function()
  start_child()
  local running = start_command('sleep 30', settings_for('discard-keeps'))
  local other = child.lua_get('vim.api.nvim_create_buf(false, true)')

  local discarded = child.lua_get(
    "{ require('aineo.run').discard_ended(...), require('aineo.run').discard_ended(select(2, ...)) }",
    { running, other }
  )

  eq(discarded, { false, false })
  eq(child.lua_get('vim.api.nvim_buf_is_valid(...)', { running }), true)
  eq(child.lua_get("require('aineo.run').running()"), { 'sleep 30' })
end

T['stop()'] = MiniTest.new_set()

T['stop()']['stops the process of a terminal with its children and leaves the others running'] = function()
  start_child()
  local settings = settings_for('stop-one')
  local stopped = start_command(SERVICE_WITH_CHILD, settings)
  local kept = start_command('sleep 30', settings_for('stop-one-kept'))
  local child_pid = child_pid_in(settings.cwd)
  local pid = child.lua_get('vim.fn.jobpid(vim.b[...].terminal_job_id)', { stopped })
  local kept_pid = child.lua_get('vim.fn.jobpid(vim.b[...].terminal_job_id)', { kept })

  child.lua("require('aineo.run').stop(...)", { stopped })
  local ended = { has_ended(pid), has_ended(child_pid) }
  local kept_runs = vim.uv.kill(kept_pid, 0) == 0
  kill_all({ pid, child_pid, kept_pid })

  eq(ended, { true, true })
  eq(kept_runs, true)
  eq(child.lua_get("require('aineo.run').buffers()"), { kept })
end

T['new()'] = MiniTest.new_set()

T['new()']['gives a home of its own, with a stack of its own, that is let go with its processes'] = function()
  start_child()
  local first = start_command('sleep 30', settings_for('new-module'))
  local second = child.lua_get(
    [[(function(settings)
      _G.second_home = require('aineo.run').new()
      return _G.second_home.start_command('sleep 31', settings)
    end)(...)]],
    { settings_for('new-copy') }
  )
  local pid = child.lua_get('vim.fn.jobpid(vim.b[...].terminal_job_id)', { second })

  child.lua('_G.second_home.let_go()')
  local ended = has_ended(pid)
  kill_all({ pid })

  eq(ended, true)
  eq(child.lua_get("require('aineo.run').buffers()"), { first })
  eq(child.lua_get('_G.second_home.buffers()'), {})
  eq(child.lua_get("require('aineo.run').let_go"), vim.NIL)
end

--- Makes the module's home count, in `_G.run_leavings`, each time a process
--- leaves the stack of itself.
local function count_leavings()
  child.lua([[
    _G.run_leavings = 0
    require('aineo.run').watch_leaving(function()
      _G.run_leavings = _G.run_leavings + 1
    end)
  ]])
end

T['watch_leaving()'] = MiniTest.new_set()

T['watch_leaving()']['calls back once when the user deletes a process, and for no other reason'] = function()
  start_child()
  count_leavings()
  local first = start_command('sleep 30', settings_for('leaving-delete'))
  start_command('sleep 31', settings_for('leaving-delete'))
  start_command('exit 0', settings_for('leaving-delete'))
  child.lua('vim.wait(300)')
  local before = child.lua_get('_G.run_leavings')

  child.cmd('bdelete! ' .. first)
  wait_until('_G.run_leavings > 0')

  eq({ before, child.lua_get('_G.run_leavings') }, { 0, 1 })
end

T['watch_leaving()']['calls back when the interactive shell ends with status 0 and Neovim wipes it'] = function()
  start_child()
  count_leavings()
  local buffer =
    child.lua_get("require('aineo.run').start_shell(...)", { settings_for('leaving-shell') })

  child.lua([[vim.fn.chansend(vim.b[(...)].terminal_job_id, 'exit\n')]], { buffer })

  eq(wait_until('_G.run_leavings == 1'), true)
  eq(child.lua_get("require('aineo.run').buffers()"), {})
end

T['watch_leaving()']['does not call back when stop_all() empties the stack'] = function()
  start_child()
  count_leavings()
  start_command('sleep 30', settings_for('leaving-stop-all'))

  child.lua("require('aineo.run').stop_all()")
  child.lua('vim.wait(300)')

  eq(child.lua_get('_G.run_leavings'), 0)
end

return T
