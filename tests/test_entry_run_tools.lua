local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- How long a case waits for the child to reach a state, in milliseconds.
local PATIENCE_MS = 10000

--- The program the child's run home starts its commands with: a POSIX shell
--- that reads no startup file of the user's.
local TEST_SHELL = '/bin/sh'

local T = MiniTest.new_set({
  hooks = { post_once = child.stop },
})

--- The repository of the case `name` with a worktree `agent-1` beside it;
--- starts the child in it, with the git isolation of the git home's suites,
--- and gives it a stand-in for a tab: a run home of its own, whose
--- `start_in_run_stack()` starts what it is asked to in the directory it is
--- given, in the folder otherwise, and keeps what it was asked in
--- `_G.started`; and `_G.told`, what the tool tells the user.
---
---@param name string
---@return string folder the repository's top level
---@return string worktree the worktree's top level
local function start_child_in_repository(name)
  local top = git_repo.create(name, { ['notes.txt'] = { 'one' } })
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), 'agent-1')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'feature/a', worktree })
  children.restart(child)
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', { git_repo.ENVIRONMENT })
  child.o.shell = TEST_SHELL
  child.lua(
    [[
      local folder = ...
      _G.folder = folder
      _G.told = {}
      _G.started = {}
      _G.stub_tab = { homes = { run = require('aineo.run').new() } }
      _G.stub_tab.start_in_run_stack = function(command, options)
        table.insert(_G.started, { command = command, options = options })
        return _G.stub_tab.homes.run.start_command(command, {
          cwd = options.directory or _G.folder,
          env = { AINEO_CHILD = '1' },
          shell = { '/bin/sh' },
          name = options.name,
        })
      end
    ]],
    { top }
  )
  return top, worktree
end

--- Calls the run tool `tool` with `arguments` as the tab of the child's
--- stand-in is called, and returns the words it answers and whether they are
--- an error.
---
---@param tool string
---@param arguments table
---@return { text: string, is_error: boolean }
local function call(tool, arguments)
  return child.lua_get(
    [[require('aineo.entry.run_tools').call(
      _G.stub_tab,
      { tool = (...), arguments = select(2, ...) },
      {
        folder = _G.folder,
        tell = function(message)
          table.insert(_G.told, message)
        end,
      }
    )]],
    { tool, arguments }
  )
end

--- The names of the processes of the child's stand-in tab, the oldest first.
---
---@return string[]
local function process_names()
  return child.lua_get([[vim.tbl_map(function(entry)
    return entry.name
  end, _G.stub_tab.homes.run.entries())]])
end

--- Waits until a line of the terminal of the process called `name` holds
--- `text`.
---
---@param name string
---@param text string
local function wait_for_line(name, text)
  local shown = vim.wait(PATIENCE_MS, function()
    return child.lua_get(
      [[(function(name, text)
        for _, entry in ipairs(_G.stub_tab.homes.run.entries()) do
          if entry.name == name then
            local lines = vim.api.nvim_buf_get_lines(entry.buffer, 0, -1, false)
            return vim.tbl_contains(lines, text)
          end
        end
        return false
      end)(...)]],
      { name, text }
    )
  end, 20)
  eq(shown, true)
end

T['run'] = MiniTest.new_set()

T['run']['starts the command in the stack, named by its first word, and answers at once'] = function()
  start_child_in_repository('run-tools-start')

  local answer = call('run', { command = 'sleep 30' })

  eq(answer, {
    text = 'Started "sleep" in the run pane, which is now shown, the cursor staying where it is.'
      .. ' Read what it prints with run_output, name "sleep".',
    is_error = false,
  })
  eq(process_names(), { 'sleep' })
  eq(child.lua_get('_G.started[1].command'), 'sleep 30')
end

T['run']['starts the command under the name it is given'] = function()
  start_child_in_repository('run-tools-named')

  call('run', { command = 'sleep 30', name = 'backend' })

  eq(process_names(), { 'backend' })
end

T['run']['gives a name the stack holds already a numeric suffix'] = function()
  start_child_in_repository('run-tools-suffix')

  call('run', { command = 'sleep 30' })
  call('run', { command = 'sleep 31' })
  local third = call('run', { command = 'sleep 32', name = 'sleep' })

  eq(process_names(), { 'sleep', 'sleep-2', 'sleep-3' })
  eq(third.text:find('Started "sleep-3"', 1, true), 1)
end

T['run']['names the process by the first word of the command without its control characters'] = function()
  start_child_in_repository('run-tools-name-controls')

  call('run', { command = '\27[2J\7evil; sleep 20' })

  eq(process_names(), { '[2Jevil;' })
end

T['run']['names the process by a word of its own when the first word is all control characters'] = function()
  start_child_in_repository('run-tools-name-only-controls')

  call('run', { command = '\7 sleep 20' })

  eq(process_names(), { 'command' })
end

T['run']['gives a command called shell a suffix, as the interactive shell holds the name'] = function()
  start_child_in_repository('run-tools-name-shell')
  child.lua(
    [[_G.stub_tab.homes.run.start_shell({ cwd = _G.folder, env = { A = '1' }, shell = { '/bin/sh' } })]]
  )

  call('run', { command = 'shell-script.sh', name = 'shell' })

  eq(process_names(), { 'shell', 'shell-2' })
end

T['run']['tells the user once that it started the process in the run pane'] = function()
  start_child_in_repository('run-tools-told')

  call('run', { command = 'sleep 30', name = 'backend' })

  eq(child.lua_get('_G.told'), { 'aineo: started backend in the run pane' })
end

T['run']['starts in the project folder by default, and in the directory it is given when that is the folder or a worktree'] =
  MiniTest.new_set({
    parametrize = { { 'folder' }, { 'dot' }, { 'worktree' } },
  })

T['run']['starts in the project folder by default, and in the directory it is given when that is the folder or a worktree']['given'] = function(
  which
)
  local folder, worktree = start_child_in_repository('run-tools-directory-' .. which)
  local arguments = {
    folder = { command = 'sleep 30', directory = folder },
    dot = { command = 'sleep 30', directory = '.' },
    worktree = { command = 'sleep 30', directory = worktree },
  }

  local answer = call('run', arguments[which])

  eq(answer.is_error, false)
  eq(
    child.lua_get('_G.started[1].options.directory'),
    vim.uv.fs_realpath(({ folder = folder, dot = folder, worktree = worktree })[which])
  )
end

T['run']['starts in the folder when it is given no directory'] = function()
  start_child_in_repository('run-tools-no-directory')

  call('run', { command = 'sleep 30' })

  eq(child.lua_get('_G.started[1].options.directory'), vim.NIL)
end

T['run']['refuses a directory that is neither the folder nor a worktree, and starts nothing'] =
  MiniTest.new_set({
    parametrize = {
      { 'inside' },
      { 'outside' },
      { 'missing' },
      { 'worktree_sibling' },
      { 'folder_sibling' },
    },
  })

T['run']['refuses a directory that is neither the folder nor a worktree, and starts nothing']['given'] = function(
  which
)
  local folder, worktree = start_child_in_repository('run-tools-refused-' .. which)
  vim.fn.mkdir(vim.fs.joinpath(folder, 'sub'))
  vim.fn.mkdir(worktree .. '-evil')
  vim.fn.mkdir(folder .. '-evil')
  local directories = {
    inside = 'sub',
    outside = vim.fs.dirname(folder),
    missing = vim.fs.joinpath(folder, 'nowhere'),
    worktree_sibling = worktree .. '-evil',
    folder_sibling = folder .. '-evil',
  }

  local answer = call('run', { command = 'sleep 30', directory = directories[which] })

  eq(answer.is_error, true)
  eq(answer.text:find('refused: directory ', 1, true), 1)
  eq(process_names(), {})
  eq(child.lua_get('_G.told'), {})
end

T['run']['says in the refusal which directories it accepts'] = function()
  local folder, worktree = start_child_in_repository('run-tools-accepts')

  local answer = call('run', { command = 'sleep 30', directory = '/' })

  eq(
    answer.text,
    'refused: directory "/" is neither the project folder nor a worktree of its repository'
      .. (' (allowed: %s, %s)'):format(vim.uv.fs_realpath(folder), vim.uv.fs_realpath(worktree))
  )
end

T['run']['is refused, saying why, when the stack cannot start the process'] = function()
  start_child_in_repository('run-tools-cannot-start')
  child.lua([[_G.stub_tab.start_in_run_stack = function()
    error('the folder aineo started in is gone', 0)
  end]])

  local answer = call('run', { command = 'sleep 30' })

  eq(answer, { text = 'refused: the folder aineo started in is gone', is_error = true })
  eq(child.lua_get('_G.told'), {})
end

--- The lines the process of the reading cases prints, in order.
local PRINTED = {
  'start',
  'GET /api/users 200',
  'POST /api/login 500',
  'DEBUG cache miss',
  'warn: slow query',
  'ERROR boom 404',
  'DEBUG tick',
  'GET /health 200',
  'end',
}

--- The command that prints `PRINTED` and then waits, so that it runs while
--- the cases read it.
local PRINTING = "printf '%s\\n' '" .. table.concat(PRINTED, "' '") .. "'; sleep 300"

--- Starts `PRINTING` as the process `printing` and waits until its last
--- line is on the terminal.
local function start_printing()
  call('run', { command = PRINTING, name = 'printing' })
  wait_for_line('printing', 'end')
end

T['run_output'] = MiniTest.new_set()

T['run_output']['reads every line, numbered, under a header that gives the state and the total'] = function()
  start_child_in_repository('run-tools-output-all')
  start_printing()

  local answer = call('run_output', { name = 'printing' })

  eq(answer, {
    text = 'printing: running; 9 lines in total\n'
      .. '1: start\n2: GET /api/users 200\n3: POST /api/login 500\n4: DEBUG cache miss\n'
      .. '5: warn: slow query\n6: ERROR boom 404\n7: DEBUG tick\n8: GET /health 200\n9: end',
    is_error = false,
  })
end

T['run_output']['reads what its arguments ask for'] = MiniTest.new_set({
  parametrize = {
    {
      { pattern = 'error|warn' },
      'printing: running; 9 lines in total\n5: warn: slow query\n6: ERROR boom 404',
    },
    {
      { pattern = 'error', ignore_case = false },
      'printing: running; 9 lines in total\n(no matching lines)',
    },
    {
      { pattern = '\\d{3}', exclude = '404' },
      'printing: running; 9 lines in total\n2: GET /api/users 200\n3: POST /api/login 500\n--\n8: GET /health 200',
    },
    {
      { pattern = 'GET|POST', last = 1 },
      'printing: running; 9 lines in total\n(2 earlier matching lines left out)\n8: GET /health 200',
    },
    {
      { after_line = 7 },
      'printing: running; 9 lines in total\n8: GET /health 200\n9: end',
    },
    {
      { after_line = 9 },
      'printing: running; 9 lines in total\n(no matching lines)',
    },
    {
      { pattern = 'POST', context = 1 },
      'printing: running; 9 lines in total\n2- GET /api/users 200\n3: POST /api/login 500\n4- DEBUG cache miss',
    },
    {
      { pattern = 'start|end', context = 1 },
      'printing: running; 9 lines in total\n1: start\n2- GET /api/users 200\n--\n8- GET /health 200\n9: end',
    },
  },
})

T['run_output']['reads what its arguments ask for']['given'] = function(arguments, text)
  start_child_in_repository('run-tools-output-asked')
  start_printing()

  local answer = call('run_output', vim.tbl_extend('force', { name = 'printing' }, arguments))

  eq(answer, { text = text, is_error = false })
end

T['run_output']['says the rows were renumbered when after_line is past the last row'] = function()
  start_child_in_repository('run-tools-output-renumbered')
  start_printing()

  local answer = call('run_output', { name = 'printing', after_line = 50 })

  eq(answer, {
    text = 'printing: running; 9 lines in total\n'
      .. '(after_line 50 is past the last line, 9: the rows were renumbered, by a resize of the pane'
      .. " or by 'scrollback'; read again without after_line)\n"
      .. '(no matching lines)',
    is_error = false,
  })
end

T['run_output']['answers a nested counted repetition that crashes the regex compiler, the editor staying alive'] =
  MiniTest.new_set({ parametrize = { { 'pattern' }, { 'exclude' } } })

T['run_output']['answers a nested counted repetition that crashes the regex compiler, the editor staying alive']['field'] = function(
  field
)
  start_child_in_repository('run-tools-output-crash-' .. field)
  start_printing()

  local answered, answer =
    pcall(call, 'run_output', { name = 'printing', [field] = '(((a{1,1000}){1,1000}){1,1000})' })
  local is_running = child.is_running()

  eq({ answered, is_running }, { true, true })
  eq(answer.is_error, false)
end

T['run_output']['answers a pattern that is no regex with the error, as an error'] = function()
  start_child_in_repository('run-tools-output-invalid')
  start_printing()

  local answer = call('run_output', { name = 'printing', pattern = '(' })

  eq(answer, { text = 'pattern: Vim:E54: Unmatched (', is_error = true })
end

T['run_output']['says how a process that ended exited, and counts one line as one'] = function()
  start_child_in_repository('run-tools-output-exited')
  call('run', { command = 'echo done; exit 3', name = 'short' })
  wait_for_line('short', 'done')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get([[_G.stub_tab.homes.run.entries()[1].status == 3]])
  end, 20)

  local answer = call('run_output', { name = 'short' })

  eq(answer, { text = 'short: exited 3; 1 line in total\n1: done', is_error = false })
end

T['run_output']['refuses the interactive shell, whose screen may hold what the user typed'] = function()
  start_child_in_repository('run-tools-output-shell')
  child.lua(
    [[_G.stub_tab.homes.run.start_shell({ cwd = _G.folder, env = { A = '1' }, shell = { '/bin/sh' } })]]
  )

  local answer = call('run_output', { name = 'shell' })

  eq(answer, {
    text = '"shell" is an interactive shell; its screen is not read, as it may hold what you typed',
    is_error = true,
  })
end

T['run_output']['reads a command that is an interactive program, as the command it is'] = function()
  start_child_in_repository('run-tools-output-interactive-program')
  call('run', { command = 'echo hi; sh -i', name = 'repl' })
  wait_for_line('repl', 'hi')

  local answer = call('run_output', { name = 'repl', pattern = '^hi$' })

  eq(answer.is_error, false)
  eq(answer.text:find('1: hi', 1, true) ~= nil, true)
end

T['run_output']['answers a name no process has with the names there are'] = function()
  start_child_in_repository('run-tools-output-unknown')
  call('run', { command = 'sleep 30', name = 'one' })
  call('run', { command = 'sleep 31', name = 'two' })

  local answer = call('run_output', { name = 'three' })

  eq(
    answer,
    { text = 'no process called "three" in the run pane (processes: one, two)', is_error = true }
  )
end

T['run_output']['answers a name no process has, with none there, saying so'] = function()
  start_child_in_repository('run-tools-output-none')

  local answer = call('run_output', { name = 'three' })

  eq(
    answer,
    { text = 'no process called "three" in the run pane (processes: none)', is_error = true }
  )
end

T['run_output']['answers a name that two processes have, naming neither'] = function()
  start_child_in_repository('run-tools-output-ambiguous')
  child.lua([[
    _G.stub_tab.homes.run.start_command('sleep 30', { cwd = _G.folder, env = { A = '1' }, shell = { '/bin/sh' } })
    _G.stub_tab.homes.run.start_command('sleep 30', { cwd = _G.folder, env = { A = '1' }, shell = { '/bin/sh' } })
  ]])

  local answer = call('run_output', { name = 'sleep 30' })

  eq(
    answer,
    { text = '2 processes are called "sleep 30" in the run pane; none was read', is_error = true }
  )
end

T['run_stop'] = MiniTest.new_set()

T['run_stop']['stops the process named and takes it out of the stack'] = function()
  start_child_in_repository('run-tools-stop')
  call('run', { command = 'sleep 30', name = 'one' })
  call('run', { command = 'sleep 31', name = 'two' })
  local pid = child.lua_get(
    [[vim.fn.jobpid(vim.b[_G.stub_tab.homes.run.entries()[1].buffer].terminal_job_id)]]
  )

  local answer = call('run_stop', { name = 'one' })
  local ended = vim.wait(PATIENCE_MS, function()
    return vim.uv.kill(pid, 0) ~= 0
  end, 20)
  pcall(vim.uv.kill, pid, 'sigkill')

  eq(answer, { text = 'Stopped "one".', is_error = false })
  eq(ended, true)
  eq(process_names(), { 'two' })
end

T['run_stop']['answers a name no process has with the names there are, and stops nothing'] = function()
  start_child_in_repository('run-tools-stop-unknown')
  call('run', { command = 'sleep 30', name = 'one' })

  local answer = call('run_stop', { name = 'nine' })

  eq(
    answer,
    { text = 'no process called "nine" in the run pane (processes: one)', is_error = true }
  )
  eq(process_names(), { 'one' })
end

T['run_stop']['answers a name that two processes have, naming neither, and stops neither'] = function()
  start_child_in_repository('run-tools-stop-ambiguous')
  child.lua([[
    for _ = 1, 2 do
      _G.stub_tab.homes.run.start_command('sleep 30', { cwd = _G.folder, env = { A = '1' }, shell = { '/bin/sh' } })
    end
  ]])

  local answer = call('run_stop', { name = 'sleep 30' })

  eq(answer, {
    text = '2 processes are called "sleep 30" in the run pane; none was stopped',
    is_error = true,
  })
  eq(process_names(), { 'sleep 30', 'sleep 30' })
end

return T
