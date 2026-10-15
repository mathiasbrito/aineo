local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude = dofile('tests/helpers/claude_session.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The child's screen: windows side by side each hold a Claude Code screen as
--- the recordings drew it.
local SCREEN_COLUMNS = 241
local SCREEN_LINES = 42

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
      child.o.columns = SCREEN_COLUMNS
      child.o.lines = SCREEN_LINES
      child.lua('_G.copies = {}; _G.stopped = {}')
    end,
    post_once = child.stop,
  },
})

--- The most a call that must not wait for a stop may take: a stop of the
--- fake takes about 4.5 s.
local RETURNS_AT_ONCE_MS = 1000

--- The most two stops started together may take, with the slack a loaded
--- host needs: one stop of the fake takes about 4.5 s, two one after the
--- other about 9 s.
local ONE_STOP_PLUS_SLACK_MS = 7500

--- Starts a Claude Code on `fake` in the session home copy number `number`
--- of `child` (`require('aineo.claude').new()`) and shows it in a window of
--- its own; returns its terminal buffer.
---
---@param number integer
---@param fake { record: string, environment: table<string, string> }
---@param overrides? table more of the copy's settings
---@return integer terminal
local function start_copy(number, fake, overrides)
  local terminal = child.lua(
    [[
      local helper, number, environment, overrides = dofile(...), select(2, ...)
      for name, value in pairs(environment) do
        vim.env[name] = value
      end
      _G.copies[number] = require('aineo.claude').new()
      local settings = helper.stand_in_settings(vim.tbl_extend('force', { new_session = true }, overrides))
      local buffer = _G.copies[number].start_session(settings)
      vim.cmd.vnew()
      vim.api.nvim_win_set_buf(0, buffer)
      return buffer
    ]],
    { 'tests/helpers/claude_session.lua', number, fake.environment, overrides or vim.empty_dict() }
  )
  claude.wait_for_start(fake)
  return terminal
end

--- What `session_status()` of copy number `number` says.
---
---@param number integer
---@return string
local function status_of_copy(number)
  return child.lua_get('_G.copies[...].session_status()', { number })
end

--- Waits, at most `claude.PATIENCE_MS`, until the session of copy number
--- `number` of the child is ready.
---
---@param number integer
local function wait_until_ready(number)
  vim.wait(claude.PATIENCE_MS, function()
    return child.lua_get('_G.copies[...].session_status()', { number }) == 'ready'
  end, 20)
end

--- Starts, in the child, the background stop of the copies numbered
--- `numbers`, counting in `_G.stopped` the times it is done.
---
---@param numbers integer[]
local function stop_in_background(numbers)
  child.lua(
    [[
      local numbers = ...
      local sessions = vim.tbl_map(function(number)
        return _G.copies[number]
      end, numbers)
      require('aineo.claude').stop_sessions_in_background(sessions, function()
        table.insert(_G.stopped, vim.uv.hrtime())
      end)
    ]],
    { numbers }
  )
end

--- How many times the background stop of the child has been done.
---
---@return integer
local function times_stopped()
  return child.lua_get('#_G.stopped')
end

--- Waits, at most `claude.STOP_PATIENCE_MS`, until the background stop of the
--- child has been done `count` times, and returns how many times it has been.
---
---@param count integer
---@return integer
local function wait_until_stopped(count)
  vim.wait(claude.STOP_PATIENCE_MS, function()
    return times_stopped() >= count
  end, 50)
  return times_stopped()
end

T['stop_sessions_in_background()'] = MiniTest.new_set()

T['stop_sessions_in_background()']['returns at once, and the editor answers while the Claude Code stops'] = function()
  local fake = claude.fake('stop-bg-at-once', 'ready')
  start_copy(1, fake)
  wait_until_ready(1)

  local before = vim.uv.hrtime()
  stop_in_background({ 1 })
  local called_ms = (vim.uv.hrtime() - before) / 1e6

  eq(called_ms < RETURNS_AT_ONCE_MS, true)
  eq(times_stopped(), 0)
  eq(status_of_copy(1), 'ready')
end

T['stop_sessions_in_background()']['stops the Claude Code by its keys and is done once it has exited'] = function()
  local fake = claude.fake('stop-bg-keys', 'ready')
  start_copy(1, fake)
  wait_until_ready(1)

  stop_in_background({ 1 })

  eq(wait_until_stopped(1), 1)
  eq(claude.wait_for_end(fake), { { ended = 'keys', code = 0 } })
  eq(status_of_copy(1), 'exited')
end

T['stop_sessions_in_background()']['stops the Claude Codes it is given together, in about the time of one stop'] = function()
  local first_fake = claude.fake('stop-bg-together-first', 'ready')
  local second_fake = claude.fake('stop-bg-together-second', 'ready')
  start_copy(1, first_fake)
  start_copy(2, second_fake)
  wait_until_ready(1)
  wait_until_ready(2)
  local before = vim.uv.hrtime()

  stop_in_background({ 1, 2 })
  wait_until_stopped(1)
  local stopped_ms = (vim.uv.hrtime() - before) / 1e6

  eq(claude.wait_for_end(first_fake), { { ended = 'keys', code = 0 } })
  eq(claude.wait_for_end(second_fake), { { ended = 'keys', code = 0 } })
  eq(stopped_ms < ONE_STOP_PLUS_SLACK_MS, true)
end

T['stop_sessions_in_background()']['leaves a Claude Code it is not given running'] = function()
  local first_fake = claude.fake('stop-bg-left-first', 'ready')
  local second_fake = claude.fake('stop-bg-left-second', 'ready')
  start_copy(1, first_fake)
  start_copy(2, second_fake)
  wait_until_ready(1)
  wait_until_ready(2)

  stop_in_background({ 1 })
  wait_until_stopped(1)

  eq(status_of_copy(2), 'ready')
  eq(status_of_copy(1), 'exited')
end

T['stop_sessions_in_background()']['is done, at once, for a session that has not started'] = function()
  child.lua('_G.copies[1] = require("aineo.claude").new()')

  stop_in_background({ 1 })

  eq(wait_until_stopped(1), 1)
end

T['stop_sessions_in_background()']['raises, starting no stop, for what is no session home'] = function()
  local failure = child.lua_get([[
    select(2, pcall(require('aineo.claude').stop_sessions_in_background, { {} }, function()
      _G.stopped_by_mistake = true
    end))
  ]])

  eq(failure:find('expected session homes', 1, true) ~= nil, true)
  eq(child.lua_get('_G.stopped_by_mistake'), vim.NIL)
end

T['stop_sessions_in_background()']['marks none of the sessions stopped when one is no session home: a start waiting for the list still launches'] = function()
  local gate = claude.list_gate('stop-bg-marks-none')
  local fake = claude.fake('stop-bg-marks-none', 'ready')
  local state = fixture.directory('stop-bg-marks-none-state')
  local kept = vim.fs.joinpath(state, 'aineo', 'claude-sessions')
  vim.fn.mkdir(kept, 'p')
  vim.fn.writefile(
    { '11111111-2222-4333-8444-555555555555' },
    vim.fs.joinpath(kept, vim.fn.sha256(child.fn.getcwd()) .. '.txt'),
    'b'
  )
  start_copy(1, fake, { cmd = gate.cmd, state_directory = state, new_session = false })
  vim.wait(claude.PATIENCE_MS, function()
    return gate.lists_started() >= 1
  end, 20)

  local failure = child.lua_get([[
    select(2, pcall(require('aineo.claude').stop_sessions_in_background, { _G.copies[1], {} }, function() end))
  ]])
  gate.open()

  eq(failure:find('expected session homes', 1, true) ~= nil, true)
  eq(#claude.wait_for_starts(fake, 1), 1)
  wait_until_ready(1)
  eq(status_of_copy(1), 'ready')
  eq(claude.ctrl_c_count(fake), 0)
end

T['a quit during a background stop'] = MiniTest.new_set()

T['a quit during a background stop']['stops the Claude Code by its keys before Neovim exits'] = function()
  local fake = claude.fake('stop-bg-quit', 'ready')
  start_copy(1, fake)
  wait_until_ready(1)
  stop_in_background({ 1 })

  claude.quit(child)

  eq(claude.wait_for_end(fake)[1].ended, 'keys')
  vim.fn.jobwait({ child.job.id }, claude.STOP_PATIENCE_MS)
  child.stop()
end

T['a quit during a background stop']['goes on without the background stop’s keys, and leaves no deaf Claude running'] = function()
  local fake = claude.fake('stop-bg-quit-deaf', 'deaf')
  start_copy(1, fake, { cmd = claude.deaf_fake_command() })
  local pid = claude.wait_for_start(fake).pid
  stop_in_background({ 1 })
  vim.wait(claude.PATIENCE_MS, function()
    return claude.ctrl_c_count(fake) == 1
  end, 20)

  claude.quit(child)

  eq(claude.wait_for_process_end(pid), true)
  eq(claude.ctrl_c_count(fake), 4)
end

return T
