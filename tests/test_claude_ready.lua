local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude = dofile('tests/helpers/claude_session.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The settings overrides that make a session keep its id under the state
--- directory `.tests/fixtures/<name>`, emptied.
---
---@param name string
---@return table
local function kept_in(name)
  return { state_directory = fixture.directory(name) }
end

--- The Lua, run in a child, that starts the session with the stand-in
--- settings overridden by `...`'s second value and an `on_session_ready`
--- that appends each id it is called with to `_G.ready_sessions`, emptied
--- first; and returns its terminal.
local START_NOTING_READINESS = [[
  local helper, overrides = dofile(...), select(2, ...)
  _G.ready_sessions = {}
  local settings = helper.stand_in_settings(overrides)
  settings.on_session_ready = function(id)
    table.insert(_G.ready_sessions, id)
  end
  return require('aineo.claude').start_session(settings)
]]

--- Starts the session in `child` with `fake`'s environment and the stand-in
--- settings overridden by `overrides`, with an `on_session_ready` that notes
--- each id it is called with in the child's `_G.ready_sessions`; shows its
--- terminal in the current window at once, as the layout does, and returns
--- it.
---
---@param fake { environment: table<string, string> }
---@param overrides table
---@return integer
local function start_noting_readiness(fake, overrides)
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', { fake.environment })
  local terminal =
    child.lua(START_NOTING_READINESS, { 'tests/helpers/claude_session.lua', overrides })
  child.api.nvim_win_set_buf(0, terminal)
  return terminal
end

--- The Lua, run in a child, that starts the session with the stand-in
--- settings overridden by `...`'s second value and an `on_session_ready`
--- that writes each id it is called with to the file `...`'s third value
--- names, and shows its terminal in the current window.
local START_WRITING_READINESS = [[
  local helper, overrides, path = dofile(...), select(2, ...)
  local settings = helper.stand_in_settings(overrides)
  settings.on_session_ready = function(id)
    vim.fn.writefile({ id }, path, 'a')
  end
  vim.api.nvim_win_set_buf(0, require('aineo.claude').start_session(settings))
]]

--- The Lua, run in a child, that keeps every notification from then on in
--- `_G.notified`, as `{ message, level }`, starts the session with the
--- stand-in settings overridden by `...`'s second value and an
--- `on_session_ready` that raises, and shows its terminal in the current
--- window.
local START_WITH_RAISING_CALLBACK = [[
  local helper, overrides = dofile(...), select(2, ...)
  _G.notified = {}
  vim.notify = function(message, level)
    table.insert(_G.notified, { message = message, level = level })
  end
  local settings = helper.stand_in_settings(overrides)
  settings.on_session_ready = function()
    error('a callback that raises', 0)
  end
  vim.api.nvim_win_set_buf(0, require('aineo.claude').start_session(settings))
]]

--- The ids `on_session_ready` has been called with in `child`, in order.
---
---@return string[]
local function ready_sessions()
  return child.lua_get('_G.ready_sessions')
end

--- The id the fake's `count`th start was started on as a new session.
---
---@param fake { record: string }
---@param count integer
---@return string
local function new_session_id(fake, count)
  return claude.words_after(claude.start_arguments(fake, count), '--session-id')[1]
end

--- How long a case waits, after the fake's first screen, for a call that
--- must not come: twice the 1.5 s the input box must show for before
--- Claude Code counts as ready, so that a call its settling would make has
--- come by then.
local NO_CALL_PATIENCE_MS = 3000

--- Waits until `on_session_ready` has been called in `child`, at most
--- `patience_ms`, and returns the ids it was called with.
---
---@param patience_ms integer
---@return string[]
local function ready_sessions_within(patience_ms)
  vim.wait(patience_ms, function()
    return #ready_sessions() > 0
  end, 20)
  return ready_sessions()
end

--- A stand-in for a Claude Code that draws its input box and then ignores
--- the hangup and SIGTERM, as a process whose event loop is stuck would, so
--- that it outlives the wipe of its terminal for a while: the POSIX sh
--- script `.tests/fixtures/<name>/claude.sh`, which it writes, run by `sh`.
--- It ends after 30 s, so that none outlives a failed test for long.
---
---@param name string
---@return string[] the command that runs it, as `claude.cmd`
local function box_drawing_claude_deaf_to_hangups(name)
  local script = vim.fs.joinpath(fixture.directory(name), 'claude.sh')
  local rule = ('─'):rep(40)
  assert(vim.fn.writefile({
    "trap '' HUP TERM INT",
    ("printf '%%s\\r\\n' '%s' '❯ ' '%s'"):format(rule, rule),
    'sleep 30',
  }, script) == 0, 'cannot write ' .. script)
  return { 'sh', script }
end

--- A session id of the form Claude Code gives, kept for a directory by a test.
local KEPT_SESSION_ID = 'c9d64d84-5f2b-4c3e-9a1d-2b7e8f0a6c31'

--- Keeps `id` as the session id of the child's working directory under
--- `state_directory`, as the Claude home names its file there:
--- `aineo/claude-sessions/<the directory's SHA-256>.txt`.
---
---@param state_directory string
---@param id string
local function keep_session_id(state_directory, id)
  local directory = vim.fs.joinpath(state_directory, 'aineo', 'claude-sessions')
  vim.fn.mkdir(directory, 'p')
  local file = vim.fs.joinpath(directory, vim.fn.sha256(child.fn.getcwd()) .. '.txt')
  assert(vim.fn.writefile({ id }, file, 'b') == 0, 'cannot write ' .. file)
end

--- A fake `claude` for one test, in `mode`, that keeps conversations as
--- Claude Code does (`AINEO_FAKE_CLAUDE_CONVERSATIONS`), in a directory of
--- its own under `.tests/fixtures/`, holding one for each of `ids`.
---
---@param name string the test's own name for its files
---@param mode string one of the fake's modes
---@param ids string[] the sessions that have a conversation
---@return { record: string, environment: table<string, string> }
local function fake_with_conversations(name, mode, ids)
  local conversations = fixture.directory(name .. '-conversations')
  for _, id in ipairs(ids) do
    local conversation = vim.fs.joinpath(conversations, id)
    assert(vim.fn.writefile({}, conversation) == 0, 'cannot write ' .. conversation)
  end
  return claude.fake(name, mode, { AINEO_FAKE_CLAUDE_CONVERSATIONS = conversations })
end

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

--- Stops the child, once the fake Claude Code it runs, if any, has ended by
--- a hangup (`END_TERMINALS`): quitting then waits for no stop by keys. A
--- child that has quit by itself is only cleaned up after.
local function stop_the_child()
  if child.is_running() and vim.fn.jobwait({ child.job.id }, 0)[1] == -1 then
    child.lua(END_TERMINALS)
  end
  child.stop()
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      stop_the_child()
      children.restart(child)
    end,
    post_once = stop_the_child,
  },
})

T['on_session_ready'] = MiniTest.new_set()

T['on_session_ready']['is called once, with the new session’s id, by the time the session is ready'] = function()
  local fake = claude.fake('ready-new', 'ready')
  start_noting_readiness(fake, kept_in('ready-new-state'))

  claude.wait_for_status(child, 'ready')

  eq(ready_sessions(), { new_session_id(fake, 1) })
end

T['on_session_ready']['is called once, with the resumed session’s id, by the time a resume that finds its conversation is ready'] = function()
  local fake = fake_with_conversations('ready-resumed', 'ready', { KEPT_SESSION_ID })
  local settings = kept_in('ready-resumed-state')
  keep_session_id(settings.state_directory, KEPT_SESSION_ID)
  start_noting_readiness(fake, settings)

  claude.wait_for_status(child, 'ready')

  eq(ready_sessions(), { KEPT_SESSION_ID })
end

T['on_session_ready']['is not called for a resume that finds no conversation, and is called once, with the new id, for the session that takes its place'] = function()
  local fake = fake_with_conversations('ready-dead', 'ready', {})
  local settings = kept_in('ready-dead-state')
  keep_session_id(settings.state_directory, KEPT_SESSION_ID)
  start_noting_readiness(fake, settings)
  claude.wait_for_starts(fake, 2)

  claude.wait_for_status(child, 'ready')

  eq(ready_sessions(), { new_session_id(fake, 2) })
end

T['on_session_ready']['is called once for a start that a dialog takes from ready and gives back'] = function()
  local fake = claude.fake('ready-dialog', 'asks')
  local terminal = start_noting_readiness(fake, kept_in('ready-dialog-state'))
  claude.wait_for_status(child, 'ready')
  claude.press_keys(child, terminal, '\r')
  claude.wait_for_status(child, 'starting')
  claude.press_keys(child, terminal, '\27')

  claude.wait_for_status(child, 'ready')

  eq(ready_sessions(), { new_session_id(fake, 1) })
end

T['on_session_ready']['is not called for a start whose Claude Code exits before it is ready'] = function()
  local fake = claude.fake('ready-exit', 'exit')
  local terminal = start_noting_readiness(fake, kept_in('ready-exit-state'))
  claude.wait_for_screen(child, terminal, '❯')

  local called = ready_sessions_within(NO_CALL_PATIENCE_MS)

  eq({ called = called, status = claude.wait_for_status(child, 'exited')[1] }, {
    called = {},
    status = 'exited',
  })
end

T['on_session_ready']['is not called for a start whose terminal was wiped before it was ready, once another start has taken its place'] = function()
  local settings = kept_in('ready-wiped-state')
  local wiped = start_noting_readiness(
    claude.fake('ready-wiped-deaf', 'ready'),
    vim.tbl_extend('force', settings, { cmd = box_drawing_claude_deaf_to_hangups('ready-wiped') })
  )
  claude.wait_for_screen(child, wiped, '❯')
  child.cmd('bwipeout! ' .. wiped)
  local fake = claude.fake('ready-wiped', 'ready')

  start_noting_readiness(fake, settings)
  claude.wait_for_status(child, 'ready')

  eq(ready_sessions(), claude.words_after(claude.arguments(fake), '--resume'))
end

T['on_session_ready']['is not called once Neovim is quitting'] = function()
  local fake = claude.fake('ready-quitting', 'ready')
  local written = vim.fs.joinpath(fixture.directory('ready-quitting'), 'ready.txt')
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', { fake.environment })
  child.lua(
    START_WRITING_READINESS,
    { 'tests/helpers/claude_session.lua', kept_in('ready-quitting-state'), written }
  )
  claude.wait_for_screen(child, child.api.nvim_get_current_buf(), '❯')

  claude.quit(child)

  eq(vim.fn.jobwait({ child.job.id }, claude.STOP_PATIENCE_MS), { 0 })
  eq(vim.uv.fs_stat(written), nil)
end

T['on_session_ready']['that raises is told the user as a warning, and the session goes on'] = function()
  local fake = claude.fake('ready-raising', 'ready')
  child.lua('for name, value in pairs(...) do vim.env[name] = value end', { fake.environment })
  child.lua(
    START_WITH_RAISING_CALLBACK,
    { 'tests/helpers/claude_session.lua', kept_in('ready-raising-state') }
  )

  local status = claude.wait_for_status(child, 'ready')

  eq({ status = status, notified = child.lua_get('_G.notified'), errmsg = child.v.errmsg }, {
    status = { 'ready' },
    notified = {
      {
        message = 'aineo: on_session_ready failed: a callback that raises',
        level = vim.log.levels.WARN,
      },
    },
    errmsg = '',
  })
end

T['on_session_ready']['that is not a function is named, and nothing starts'] = function()
  local fake = claude.fake('ready-malformed', 'ready')

  MiniTest.expect.error(function()
    claude.start(child, fake, { on_session_ready = 'a callback' })
  end, 'settings%.on_session_ready')

  eq(child.lua_get("{ require('aineo.claude').session_status() }"), {})
end

return T
