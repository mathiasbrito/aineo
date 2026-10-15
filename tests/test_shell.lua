local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality
local no_eq = MiniTest.expect.no_equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The program the child's `'shell'` is set to: a POSIX shell that reads no
--- startup file of the user's, so a case never runs the user's own shell.
local TEST_SHELL = '/bin/sh'

--- How long a case waits for the child to reach a state, in milliseconds.
local PATIENCE_MS = 10000

--- The functions a shell home offers as fields, as the module's own do.
local SHELL_FUNCTIONS = {
  { 'start' },
  { 'shell_buffer' },
  { 'stop' },
}

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

--- Starts the module's shell in `child` with `settings`, and returns its
--- buffer.
---
---@param settings table
---@return integer buffer
local function start_shell(settings)
  return child.lua_get([[require('aineo.shell').start(...)]], { settings })
end

--- The number of terminal jobs `child` runs.
local TERMINAL_JOBS = [[#vim.tbl_filter(function(channel)
  return channel.mode == 'terminal'
end, vim.api.nvim_list_chans())]]

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

--- Waits until a line of the terminal `buffer` holds `text`, and says whether
--- one did.
---
---@param buffer integer
---@param text string
---@return boolean
local function shell_shows(buffer, text)
  return wait_until(
    [[(function(buffer, text)
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

--- A fresh, empty directory for the shell to start in, named for the case.
---
---@param name string
---@return string path
local function working_directory(name)
  return fixture.directory('shell/' .. name)
end

T['the module'] = MiniTest.new_set()

T['the module']['gives a home of its own on each new() call, other than the module'] = function()
  start_child()

  eq(
    child.lua_get([[(function()
      local shell = require('aineo.shell')
      local first, second = shell.new(), shell.new()
      return { first ~= second, first ~= shell, second ~= shell }
    end)()]]),
    { true, true, true }
  )
end

T['the module']['offers its functions as fields, on a new home too'] = MiniTest.new_set({
  parametrize = SHELL_FUNCTIONS,
})

T['the module']['offers its functions as fields, on a new home too']['as'] = function(name)
  start_child()

  eq(
    child.lua_get(
      [[{ type(require('aineo.shell')[...]), type(require('aineo.shell').new()[...]) }]],
      { name }
    ),
    { 'function', 'function' }
  )
end

--- The buffer of the module's shell, as `shell_buffer()` gives it.
---
---@return integer|nil buffer
local function current_shell_buffer()
  return child.lua_get([[require('aineo.shell').shell_buffer()]])
end

T['shell_program()'] = MiniTest.new_set()

T['shell_program()']['is the first word of `shell` as `:terminal` reads it, its quotes and escapes resolved'] = function()
  start_child()
  child.o.shell = [[ "/a dir/q\"sh" -l]]

  local program = child.lua_get("require('aineo.shell').shell_program()")

  eq(program, '/a dir/q"sh')
end

T['start()'] = MiniTest.new_set()

T['start()']['returns a terminal buffer that runs the program `shell` names'] = function()
  start_child()

  local buffer = start_shell({ cwd = working_directory('program') })

  eq(
    child.lua_get(
      [[(function(buffer)
        local info = vim.api.nvim_get_chan_info(vim.bo[buffer].channel)
        return { vim.bo[buffer].buftype, table.concat(info.argv, ' ') }
      end)(...)]],
      { buffer }
    ),
    { 'terminal', TEST_SHELL }
  )
end

T['start()']['splits `shell` as `:terminal` does, a double-quoted word keeping its spaces'] = function()
  start_child()
  local program = fixture.write('shell/a program/sh', { '#!/bin/sh', 'exec /bin/sh "$@"' })
  assert(vim.uv.fs_chmod(program, tonumber('755', 8)))
  child.o.shell = '  "' .. program .. '"   -i  '

  local buffer = start_shell({ cwd = working_directory('words') })

  eq(
    child.lua_get('vim.api.nvim_get_chan_info(vim.bo[...].channel).argv', { buffer }),
    { program, '-i' }
  )
end

T['start()']['refuses settings that are not a table, naming them, and starts nothing'] =
  MiniTest.new_set({
    parametrize = { { 'nothing' }, { 'a string' } },
  })

T['start()']['refuses settings that are not a table, naming them, and starts nothing']['given'] = function(
  kind
)
  start_child()
  local settings = ({ ['a string'] = 'a string' })[kind]
  local buffers_before = child.lua_get('#vim.api.nvim_list_bufs()')

  local started, message = pcall(start_shell, settings)

  eq(started, false)
  eq(message:find('settings: expected table', 1, true) ~= nil, true)
  eq(
    { child.lua_get(TERMINAL_JOBS), child.lua_get('#vim.api.nvim_list_bufs()') },
    { 0, buffers_before }
  )
end

T['start()']['refuses a directory the shell cannot enter, naming settings.cwd, and starts nothing'] = function()
  start_child()
  local directory = working_directory('locked')
  assert(vim.uv.fs_chmod(directory, tonumber('600', 8)))
  local buffers_before = child.lua_get('#vim.api.nvim_list_bufs()')

  local started, message = pcall(start_shell, { cwd = directory })

  assert(vim.uv.fs_chmod(directory, tonumber('755', 8)))
  eq(started, false)
  eq(message:find('settings.cwd', 1, true) ~= nil, true)
  eq(
    { child.lua_get(TERMINAL_JOBS), child.lua_get('#vim.api.nvim_list_bufs()') },
    { 0, buffers_before }
  )
end

--- Writes an executable `/bin/sh` wrapper named `name` in the fixtures' directory
--- `shell/<directory>/` and returns its absolute path.
---
---@param directory string
---@param name string
---@return string path
local function program_named(directory, name)
  local program =
    fixture.write('shell/' .. directory .. '/' .. name, { '#!/bin/sh', 'exec /bin/sh "$@"' })
  assert(vim.uv.fs_chmod(program, tonumber('755', 8)))
  return program
end

T['start()']['reads a backslash before a double quote inside double quotes as the quote, as `:terminal` does'] = function()
  start_child()
  local program = program_named('a program', 'q"sh')
  child.o.shell = '"' .. program:gsub('"', '\\"') .. '"'

  local started, buffer = pcall(start_shell, { cwd = working_directory('words') })

  eq(started, true)
  eq(child.lua_get('vim.api.nvim_get_chan_info(vim.bo[...].channel).argv', { buffer }), { program })
end

T['start()']['splits `shell` at spaces and tabs only, a newline staying in its word, as `:terminal` does'] = function()
  start_child()
  local program = program_named('newline', 'n\nsh')
  child.o.shell = program

  local started, buffer = pcall(start_shell, { cwd = working_directory('words') })

  eq(started, true)
  eq(child.lua_get('vim.api.nvim_get_chan_info(vim.bo[...].channel).argv', { buffer }), { program })
end

T['start()']['starts the shell in settings.cwd'] = function()
  start_child()
  local directory = working_directory('cwd')

  local buffer = start_shell({ cwd = directory })
  type_into_shell(buffer, 'echo "in=[$(basename "$(pwd -P)")]"')

  eq(shell_shows(buffer, 'in=[' .. vim.fs.basename(directory) .. ']'), true)
end

T['start()']['gives the shell AINEO_CHILD=1'] = function()
  start_child()

  local buffer = start_shell({ cwd = working_directory('environment') })
  type_into_shell(buffer, 'echo "child=[$AINEO_CHILD]"')

  eq(shell_shows(buffer, 'child=[1]'), true)
end

T['start()']['leaves the editor’s own environment to the shell'] = function()
  start_child()
  child.lua([[vim.fn.setenv('AINEO_T69_OWN', 'kept')]])

  local buffer = start_shell({ cwd = working_directory('environment') })
  type_into_shell(buffer, 'echo "own=[$AINEO_T69_OWN]"')

  eq(shell_shows(buffer, 'own=[kept]'), true)
end

T['start()']['makes an unlisted buffer that stays loaded while hidden, whatever the user’s hidden'] = function()
  start_child()
  child.o.hidden = false

  local buffer = start_shell({ cwd = working_directory('buffer') })

  eq(
    child.lua_get(
      [[{ vim.bo[...].buflisted, vim.bo[...].bufhidden, vim.api.nvim_buf_is_loaded(...) }]],
      { buffer }
    ),
    { false, 'hide', true }
  )
end

T['start()']['shows the buffer in no window'] = function()
  start_child()
  local windows_before = child.lua_get('vim.api.nvim_list_wins()')

  local buffer = start_shell({ cwd = working_directory('buffer') })

  eq(
    child.lua_get('{ vim.api.nvim_list_wins(), vim.fn.win_findbuf(...) }', { buffer }),
    { windows_before, {} }
  )
end

T['start()']['gives the same buffer and starts nothing while the shell lives'] = function()
  start_child()
  local directory = working_directory('twice')
  local first = start_shell({ cwd = directory })
  local jobs_before = child.lua_get(TERMINAL_JOBS)
  local buffers_before = child.lua_get('#vim.api.nvim_list_bufs()')

  local second = start_shell({ cwd = directory })

  eq(
    { second, child.lua_get(TERMINAL_JOBS), child.lua_get('#vim.api.nvim_list_bufs()') },
    { first, jobs_before, buffers_before }
  )
end

T['start()']['raises an error naming shell and the program when the program is not executable, and starts nothing'] = function()
  start_child()
  child.o.shell = '/no/such/aineo-t69-shell -i'
  local buffers_before = child.lua_get('#vim.api.nvim_list_bufs()')

  local started, message = pcall(start_shell, { cwd = working_directory('missing-program') })

  eq(started, false)
  eq(message:find("'shell'", 1, true) ~= nil, true)
  eq(message:find('/no/such/aineo-t69-shell', 1, true) ~= nil, true)
  eq(
    { child.lua_get(TERMINAL_JOBS), child.lua_get('#vim.api.nvim_list_bufs()') },
    { 0, buffers_before }
  )
end

T['start()']['refuses a settings.cwd that is not an existing directory, naming it, and starts nothing'] =
  MiniTest.new_set({
    parametrize = { { 'a path that does not exist' }, { 'a file' }, { 'nothing' } },
  })

T['start()']['refuses a settings.cwd that is not an existing directory, naming it, and starts nothing']['given'] = function(
  kind
)
  start_child()
  local cwd = ({
    ['a path that does not exist'] = '/no/such/aineo-t69-directory',
    ['a file'] = fixture.write('shell/a-file.txt', { 'a file' }),
  })[kind]
  local buffers_before = child.lua_get('#vim.api.nvim_list_bufs()')

  local started, message = pcall(start_shell, { cwd = cwd })

  eq(started, false)
  eq(message:find('settings.cwd', 1, true) ~= nil, true)
  eq(
    { child.lua_get(TERMINAL_JOBS), child.lua_get('#vim.api.nvim_list_bufs()') },
    { 0, buffers_before }
  )
end

T['shell_buffer()'] = MiniTest.new_set()

T['shell_buffer()']['gives nothing before a shell started, and its buffer after'] = function()
  start_child()
  local before = current_shell_buffer()

  local buffer = start_shell({ cwd = working_directory('shell-buffer') })

  eq({ before, current_shell_buffer() }, { vim.NIL, buffer })
end

--- The shells whose end the cases check, and what each is told to end it: a
--- shell as `'shell'` alone, which Neovim's own handler wipes when it exits
--- with status 0, and one with an argument, which it never wipes.
local ENDINGS = {
  { '/bin/sh', 'exit 0' },
  { '/bin/sh', 'exit 3' },
  { '/bin/sh -i', 'exit 0' },
  { '/bin/sh -i', 'exit 3' },
}

T['a shell that ends'] = MiniTest.new_set({ parametrize = ENDINGS })

T['a shell that ends']['has its buffer wiped and is forgotten, whatever the status and the arguments of `shell`'] = function(
  program,
  ending
)
  start_child()
  child.o.shell = program
  local buffer = start_shell({ cwd = working_directory('ends') })

  type_into_shell(buffer, ending)

  eq(wait_until('not vim.api.nvim_buf_is_valid(...)', { buffer }), true)
  eq(current_shell_buffer(), vim.NIL)
end

T['the end of a shell'] = MiniTest.new_set()

T['the end of a shell']['leaves its buffer for the handlers of the TermClose that told of it, which run after the home’s own'] = function()
  start_child()
  child.o.shell = '/bin/sh -i'
  local buffer = start_shell({ cwd = working_directory('ends') })
  child.lua([[
    _G.buffer_valid_in_term_close = nil
    vim.api.nvim_create_autocmd('TermClose', {
      callback = function(event)
        _G.buffer_valid_in_term_close = vim.api.nvim_buf_is_valid(event.buf)
      end,
    })
  ]])

  type_into_shell(buffer, 'exit 3')

  eq(wait_until('_G.buffer_valid_in_term_close ~= nil'), true)
  eq(child.lua_get('_G.buffer_valid_in_term_close'), true)
  eq(wait_until('not vim.api.nvim_buf_is_valid(...)', { buffer }), true)
end

--- Starts a shell in `child` under a user's `TermClose` handler that deletes
--- the terminal, which runs no handler of the shell home's, ends it, and
--- returns its buffer once it is gone.
---
---@return integer buffer the wiped shell's
local function start_and_end_a_shell_wiped_unseen()
  start_child()
  child.lua([[
    vim.api.nvim_create_autocmd('TermClose', {
      callback = function(event)
        vim.api.nvim_buf_delete(event.buf, { force = true })
      end,
    })
  ]])
  local buffer = start_shell({ cwd = working_directory('wiped-unseen') })
  type_into_shell(buffer, 'exit 3')
  wait_until('not vim.api.nvim_buf_is_valid(...)', { buffer })
  return buffer
end

T['a shell wiped where no handler sees it'] = MiniTest.new_set()

T['a shell wiped where no handler sees it']['is no longer the shell_buffer()'] = function()
  start_and_end_a_shell_wiped_unseen()

  eq(current_shell_buffer(), vim.NIL)
end

T['a shell wiped where no handler sees it']['is replaced by a new, live shell at the next start()'] = function()
  local first = start_and_end_a_shell_wiped_unseen()

  local second = start_shell({ cwd = working_directory('wiped-unseen') })

  no_eq(second, first)
  eq(child.lua_get('vim.api.nvim_buf_is_valid(...)', { second }), true)
  eq(child.lua_get(TERMINAL_JOBS), 1)
end

T['a shell whose buffer is wiped'] = MiniTest.new_set({
  parametrize = { { 'bwipeout!' }, { 'bdelete!' } },
})

T['a shell whose buffer is wiped']['is forgotten, raises nothing, and a new shell starts after it, for'] = function(
  command
)
  start_child()
  local directory = working_directory('wiped')
  local first = start_shell({ cwd = directory })
  child.lua('vim.cmd(...)', { command .. ' ' .. first })
  local forgotten = current_shell_buffer()

  local second = start_shell({ cwd = directory })

  eq(forgotten, vim.NIL)
  no_eq(second, first)
  eq(
    { current_shell_buffer(), child.lua_get(TERMINAL_JOBS), child.lua_get('vim.v.errmsg') },
    { second, 1, '' }
  )
end

T['stop()'] = MiniTest.new_set()

T['stop()']['ends the shell’s process and wipes its buffer at once'] = function()
  start_child()
  local buffer = start_shell({ cwd = working_directory('stop') })
  local pid = child.lua_get('vim.b[...].terminal_job_pid', { buffer })

  child.lua([[require('aineo.shell').stop()]])

  eq(child.lua_get('vim.api.nvim_buf_is_valid(...)', { buffer }), false)
  eq({ current_shell_buffer(), child.lua_get(TERMINAL_JOBS) }, { vim.NIL, 0 })
  eq(wait_until('vim.uv.kill(..., 0) == nil', { pid }), true)
end

T['stop()']['called where Neovim refuses the wipe still ends the shell, and no second shell runs'] = function()
  start_child()
  local directory = working_directory('stop-refused')
  local buffer = start_shell({ cwd = directory })
  local pid = child.lua_get('vim.fn.jobpid(vim.b[...].terminal_job_id)', { buffer })

  child.lua([[
    vim.keymap.set('n', 'Q', function()
      _G.stop_failed = not pcall(require('aineo.shell').stop)
      return ''
    end, { expr = true })
    vim.api.nvim_feedkeys('Q', 'x', false)
  ]])

  eq(child.lua_get('_G.stop_failed'), true)
  eq(wait_until('vim.uv.kill(..., 0) == nil', { pid }), true)
  eq(wait_until('not vim.api.nvim_buf_is_valid(...)', { buffer }), true)
  local second = start_shell({ cwd = directory })
  no_eq(second, buffer)
  eq(child.lua_get(TERMINAL_JOBS), 1)
end

T['stop()']['does nothing without a shell, and a shell can start after it'] = function()
  start_child()

  local stopped = pcall(child.lua, [[require('aineo.shell').stop()]])
  local buffer = start_shell({ cwd = working_directory('stop') })

  eq(stopped, true)
  eq(current_shell_buffer(), buffer)
end

--- Starts a shell in each of two homes in `child` — the module's, held as
--- `_G.first`, and a new one's, `_G.second` — and returns their buffers.
---
---@return { first: integer, second: integer } buffers
local function start_two_homes()
  start_child()
  child.lua([[
    _G.first = require('aineo.shell')
    _G.second = require('aineo.shell').new()
  ]])
  return {
    first = child.lua_get('_G.first.start(...)', { { cwd = working_directory('first') } }),
    second = child.lua_get('_G.second.start(...)', { { cwd = working_directory('second') } }),
  }
end

--- The names of the autocommand groups of the shell homes' handlers that
--- watch the terminal `buffer`.
---
---@param buffer integer
---@return string[] groups
local function groups_watching(buffer)
  return child.lua_get(
    [[(function(buffer)
      local groups = {}
      for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ event = { 'TermClose', 'BufWipeout' } })) do
        if autocmd.buflocal and autocmd.buffer == buffer and vim.startswith(autocmd.group_name, 'aineo.shell') then
          groups[autocmd.group_name] = true
        end
      end
      return vim.tbl_keys(groups)
    end)(...)]],
    { buffer }
  )
end

T['two homes'] = MiniTest.new_set()

T['two homes']['run a shell each, in two buffers and two jobs'] = function()
  local buffers = start_two_homes()

  no_eq(buffers.first, buffers.second)
  eq(child.lua_get(TERMINAL_JOBS), 2)
  eq(child.lua_get('{ _G.first.shell_buffer(), _G.second.shell_buffer() }'), {
    buffers.first,
    buffers.second,
  })
end

T['two homes']['watch their shells from groups of their own'] = function()
  local buffers = start_two_homes()

  local first, second = groups_watching(buffers.first), groups_watching(buffers.second)

  eq({ #first, #second }, { 1, 1 })
  no_eq(first[1], second[1])
end

T['two homes']['wipe the buffer of the shell that ended and leave the other’s shell running'] = function()
  local buffers = start_two_homes()

  type_into_shell(buffers.second, 'exit 3')

  eq(wait_until('not vim.api.nvim_buf_is_valid(...)', { buffers.second }), true)
  eq(
    child.lua_get(
      '{ _G.first.shell_buffer(), _G.second.shell_buffer(), vim.api.nvim_buf_is_valid(...) }',
      {
        buffers.first,
      }
    ),
    { buffers.first, vim.NIL, true }
  )
  eq(child.lua_get(TERMINAL_JOBS), 1)
end

T['a home let go'] = MiniTest.new_set()

T['a home let go']['is a field of a home new() made, and not of the module'] = function()
  start_child()

  eq(
    child.lua_get([[(function()
      local shell = require('aineo.shell')
      return { home = type(shell.new().let_go), module = type(shell.let_go) }
    end)()]]),
    { home = 'function', module = 'nil' }
  )
end

T['a home let go']['stops its shell and removes its handlers, leaving the module’s'] = function()
  local buffers = start_two_homes()
  local group = groups_watching(buffers.second)[1]
  local pid = child.lua_get('vim.b[...].terminal_job_pid', { buffers.second })

  child.lua('_G.second.let_go()')

  eq(child.lua_get('vim.api.nvim_buf_is_valid(...)', { buffers.second }), false)
  eq(wait_until('vim.uv.kill(..., 0) == nil', { pid }), true)
  eq(child.lua_get('(pcall(vim.api.nvim_get_autocmds, { group = ... }))', { group }), false)
  eq({ #groups_watching(buffers.first), child.lua_get('_G.first.shell_buffer()') }, {
    1,
    buffers.first,
  })
end

return T
