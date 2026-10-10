local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude = dofile('tests/helpers/claude_session.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local report_tui = dofile('tests/helpers/report_tui.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

--- Gives the child, and so its Claude Code and the hooks that runs, the
--- `XDG_STATE_HOME` `.tests/fixtures/<name>`, emptied; returns the state
--- directory under it, `stdpath('state')` for each.
---
---@param name string
---@return string
local function state_of(name)
  local home = fixture.directory(name)
  child.lua('vim.env.XDG_STATE_HOME = ...', { home })
  return vim.fs.joinpath(home, 'nvim')
end

--- The session the record of the fake's process names for its first start,
--- once its `SessionStart` hook has run, waiting for that at most
--- `claude.PATIENCE_MS`; nil when none does by then.
---
---@param state string
---@param fake { record: string }
---@return string?
local function recorded_session(state, fake)
  local token = claude.start_token(fake, 1)
  local pid = claude.wait_for_start(fake).pid
  local session
  vim.wait(claude.PATIENCE_MS, function()
    session = require('aineo.mcp').process_session(state, pid, token)
    return session ~= nil
  end, 20)
  return session
end

--- The id the fake's first start was started on, as a new session.
---
---@param fake { record: string }
---@return string
local function first_session_id(fake)
  return claude.words_after(claude.arguments(fake), '--session-id')[1]
end

T['the hook relay'] = MiniTest.new_set()

T['the hook relay']['records the session under the pid of Claude Code’s process, whatever shell runs the hook'] =
  MiniTest.new_set({ parametrize = { { 'alone' }, { 'wrapped' } } })

T['the hook relay']['records the session under the pid of Claude Code’s process, whatever shell runs the hook']['with the command'] = function(
  shell
)
  local state = state_of('hook-record-' .. shell)
  local fake = claude.fake(
    'hook-record-' .. shell,
    'ready',
    { AINEO_FAKE_CLAUDE_HOOKS = '1', AINEO_FAKE_CLAUDE_HOOK_SHELL = shell }
  )

  claude.start(child, fake, { state_directory = state })

  eq(recorded_session(state, fake), first_session_id(fake))
end

T['the hook relay']['records nothing when the pid the shell gave is not all digits'] = function()
  local state = fixture.directory('hook-record-no-pid')
  local relay = vim.fs.joinpath(vim.fn.getcwd(), 'lua', 'aineo', 'claude', 'hook_relay.lua')

  local ended = vim
    .system({
      vim.v.progpath,
      '--headless',
      '--clean',
      '--cmd',
      'set noloadplugins',
      '-l',
      relay,
      vim.fs.joinpath(state, 'gone.sock'),
      'a-token',
      'SessionStart',
      '0x10',
      '/projects/alpha',
    }, {
      stdin = claude.hook_input('SessionStart', 'c9d64d84-5f2b-4c3e-9a1d-2b7e8f0a6c31', 'startup'),
      env = { XDG_STATE_HOME = state },
    })
    :wait(claude.PATIENCE_MS)

  eq({
    ended.code,
    vim.fn.glob(vim.fs.joinpath(state, 'nvim', 'aineo', 'claude-processes', '*'), true, true),
  }, { 0, {} })
end

--- The session id kept under `state` for the working directory `cwd`, as the
--- session the next start there resumes; nil when none is kept.
---
---@param state string
---@param cwd string
---@return string?
local function kept_session(state, cwd)
  local path = vim.fs.joinpath(state, 'aineo', 'claude-sessions', vim.fn.sha256(cwd) .. '.txt')
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local id = file:read('*a')
  file:close()
  return id
end

--- The session the fake's last `SessionStart` hook told, once it has run
--- `count` of them, waiting for that at most `claude.PATIENCE_MS`.
---
---@param fake { record: string }
---@param count integer
---@return string?
local function started_session(fake, count)
  local starts = {}
  vim.wait(claude.PATIENCE_MS, function()
    starts = vim.tbl_filter(function(entry)
      return entry.hook == 'SessionStart'
    end, claude.record(fake))
    return #starts >= count
  end, 20)
  return starts[count] and starts[count].session_id
end

--- The session kept for `cwd` under `state` once it is `expected`, waiting
--- for that at most `claude.PATIENCE_MS`; else what is kept when the wait
--- runs out.
---
---@param state string
---@param cwd string
---@param expected string?
---@return string?
local function kept_once(state, cwd, expected)
  vim.wait(claude.PATIENCE_MS, function()
    return kept_session(state, cwd) == expected
  end, 20)
  return kept_session(state, cwd)
end

T['a switch whose editor is gone'] = MiniTest.new_set()

T['a switch whose editor is gone']['is kept for the directory, as the session the next start there resumes'] = function()
  local state = state_of('hook-record-switch-kept')
  local fake = claude.fake('hook-record-switch-kept', 'ready', { AINEO_FAKE_CLAUDE_HOOKS = '1' })
  local buffer = claude.start(child, fake, {
    state_directory = state,
    editor_address = vim.fs.joinpath(state, 'gone.sock'),
  })
  started_session(fake, 1)

  claude.press_keys(child, buffer, '/clear\r')

  local new = started_session(fake, 2)
  eq({ type(new), kept_once(state, child.fn.getcwd(), new) }, { 'string', new })
end

T['a switch whose editor is gone']['is not made by a SessionStart of another session with no SessionEnd before it'] = function()
  local state = state_of('hook-record-unpaired')
  local fake = claude.fake('hook-record-unpaired', 'ready', { AINEO_FAKE_CLAUDE_HOOKS = '1' })
  claude.start(child, fake, {
    state_directory = state,
    editor_address = vim.fs.joinpath(state, 'gone.sock'),
  })
  local first = started_session(fake, 1)
  local command = claude
    .hook_command(fake, 1, 'SessionStart')
    :gsub('"%$PPID"', tostring(claude.wait_for_start(fake).pid))

  vim
    .system({ 'sh', '-c', command }, {
      stdin = claude.hook_input('SessionStart', '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852', 'fork'),
      env = { XDG_STATE_HOME = vim.fs.dirname(state) },
    })
    :wait(claude.PATIENCE_MS)

  eq({
    kept = kept_once(state, child.fn.getcwd(), '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'),
    recorded = recorded_session(state, fake),
  }, { kept = first, recorded = first })
end

T['a switch told to the Neovims that follow the session left'] = MiniTest.new_set({
  hooks = {
    post_case = function()
      report_tui.stop_all()
    end,
  },
})

T['a switch told to the Neovims that follow the session left']['reaches the claimant while the editor that started Claude Code waits at a hit-enter prompt'] = function()
  local state = state_of('hook-record-tell-claimant')
  local left = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'
  local new = '7d0e3a4f-8e1a-4d2f-b5c7-91d0e3a4f853'
  child.cmd('Aineo claim ' .. left)
  local starting = report_tui.start({
    time = '2026-10-10T09:05:00',
    state_directory = state,
    working_directory = '/projects/alpha',
  })
  starting:type(':echo "one\\ntwo\\nthree"\r')
  local waiting = starting:waits_at_hit_enter()
  local relay = vim.fs.joinpath(vim.fn.getcwd(), 'lua', 'aineo', 'claude', 'hook_relay.lua')
  local deliverer = vim.system({
    vim.v.progpath,
    '--headless',
    '--clean',
    '--cmd',
    'set noloadplugins',
    '-l',
    relay,
    '--deliver',
    starting.address,
    'a-token',
    'SessionStart',
    new,
    'clear',
    '1000',
    left,
    new,
    '/projects/alpha',
  }, { env = { XDG_STATE_HOME = vim.fs.dirname(state) } })
  MiniTest.finally(function()
    deliverer:kill('sigkill')
  end)

  local claimed_new = vim.wait(claude.PATIENCE_MS, function()
    return require('aineo.mcp').session_claimant(state, new) == child.v.servername
  end, 20)
  starting:type('\r')

  eq({ waiting = waiting, claimed_new = claimed_new }, { waiting = true, claimed_new = true })
end

return T
