local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')
local stand_in = dofile('tests/helpers/office_stand_in.lua')

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

--- Stops the child, once the fake Claude Code it runs, if any, has ended by a
--- hangup (`END_TERMINALS`).
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
      child.o.termguicolors = true
    end,
    post_once = stop_the_child,
  },
})

--- The recorded turn, whose first five lines end with a call that runs.
local RECORDED_TURN = fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl')

--- A session of the form Claude Code gives that the case's tab does not run.
local OTHER_SESSION = 'c9d64d84-5f2b-4c3e-9a1d-2b7e8f0a6c31'

--- Opens the layout in the child with aineo running the fake `claude` in its
--- `ready` mode under `name`, and waits until Claude Code is ready.
---
---@param name string the case's own name for its files, starting `office-`
local function open_layout(name)
  entry.use_fake(child, claude_session.fake(name, 'ready'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
end

--- Runs `lua` in the child, then waits until the callbacks scheduled by then
--- have run, and those they scheduled in turn, as the hook relay's
--- notifications are handled.
---
---@param lua string
---@param arguments? any[]
local function run_and_settle(lua, arguments)
  child.lua(lua, arguments or {})
  child.lua([[
    _G.settled = false
    vim.schedule(function()
      vim.schedule(function()
        _G.settled = true
      end)
    end)
  ]])
  vim.wait(claude_session.PATIENCE_MS, function()
    return child.lua_get('_G.settled')
  end, 20)
end

--- Tells the child's Claude home, as the hook relay does for a `SessionStart`
--- of `session`, that Claude Code writes the transcript of `session` in
--- `path`, the tab's own start token with it.
---
---@param session string
---@param path string
local function tell_transcript(session, path)
  run_and_settle(
    [[
      local claude = require('aineo.claude')
      claude.receive_session_event('SessionStart', ..., 'startup', claude.start_token(), nil, nil, select(2, ...))
    ]],
    { session, path }
  )
end

--- Tells the child's Claude home, as the hook relay does for a
--- `PermissionRequest`, that the agent `agent` of `session` waits for the
--- user, the tab's own start token with it.
---
---@param session string
---@param agent string|userdata the subagent that asks, or `vim.NIL`
local function tell_permission_wait(session, agent)
  run_and_settle(
    [[
      local claude = require('aineo.claude')
      claude.receive_permission_wait(claude.start_token(), ...)
    ]],
    { session, agent }
  )
end

--- The session the child's tab runs.
---
---@return string
local function tab_session()
  return child.lua_get([[require('aineo.claude').session_id()]])
end

--- Writes `lines` as a transcript in a file of its own, where Claude Code's
--- folder rule would not look for it, and returns its path.
---
---@param session string
---@param lines string[]
---@return string
local function write_transcript_elsewhere(session, lines)
  local directory = vim.fs.joinpath(child.lua_get([[vim.env.CLAUDE_CONFIG_DIR]]), 'elsewhere')
  vim.fn.mkdir(directory, 'p')
  local path = vim.fs.joinpath(directory, session .. '.jsonl')
  fake_transcript.append(path, lines)
  return path
end

T['the transcript a SessionStart hook named'] = MiniTest.new_set()

T['the transcript a SessionStart hook named']['is the one the office follows, wherever Claude Code wrote it'] = function()
  open_layout('office-hook-path')
  local session = tab_session()
  tell_transcript(session, write_transcript_elsewhere(session, vim.list_slice(RECORDED_TURN, 1, 5)))

  entry.command(child, 'Aineo office')

  eq(
    vim.wait(5000, function()
      return office_cells.is_at(child, 'file_cabinet')
    end, 50),
    true
  )
end

T['the transcript a SessionStart hook named']['wins over one Claude Code’s folder rule finds for the session'] = function()
  open_layout('office-hook-wins')
  local session = tab_session()
  local stale = vim.fs.joinpath(
    child.lua_get([[vim.env.CLAUDE_CONFIG_DIR]]),
    'projects',
    'stale',
    session .. '.jsonl'
  )
  vim.fn.mkdir(vim.fs.dirname(stale), 'p')
  fake_transcript.append(stale, RECORDED_TURN)
  tell_transcript(session, write_transcript_elsewhere(session, vim.list_slice(RECORDED_TURN, 1, 5)))

  entry.command(child, 'Aineo office')

  eq(
    vim.wait(5000, function()
      return office_cells.is_at(child, 'file_cabinet')
    end, 50),
    true
  )
end

T['the transcript a SessionStart hook named']['is followed to the session it says Claude Code went on in'] = function()
  open_layout('office-hook-continued')
  child.lua([[
    local office_states = require('aineo.office_states')
    local new_tracker = office_states.new_tracker
    _G.taken = {}
    office_states.new_tracker = function(options)
      local tracker = new_tracker(options)
      local take = tracker.take
      tracker.take = function(signal, now)
        table.insert(_G.taken, signal.kind)
        return take(signal, now)
      end
      return tracker
    end
  ]])
  local session = tab_session()
  local continued_in = '22222222-2222-4222-8222-222222222222'
  local named = write_transcript_elsewhere(session, {
    vim.json.encode({
      type = 'continued-in',
      timestamp = '2026-01-01T00:00:03.000Z',
      sessionId = session,
      continuedInSessionId = continued_in,
    }),
  })
  write_transcript_elsewhere(continued_in, vim.list_slice(RECORDED_TURN, 1, 5))
  tell_transcript(session, named)

  entry.command(child, 'Aineo office')

  eq(child.lua_get('_G.taken'), { 'prompt', 'tool_started' })
end

T['the transcript a SessionStart hook named']['is not followed for a session the tab does not run'] = function()
  open_layout('office-hook-other')
  tell_transcript(
    OTHER_SESSION,
    write_transcript_elsewhere(OTHER_SESSION, vim.list_slice(RECORDED_TURN, 1, 5))
  )

  entry.command(child, 'Aineo office')

  eq(office_cells.is_on_the_sofa(child), true)
end

--- Opens the layout as `open_layout()` does, with the office module a
--- stand-in (`tests/helpers/office_stand_in.lua`) from before the tab opens.
---
---@param name string
local function open_layout_with_stand_in_offices(name)
  stand_in.install(child)
  open_layout(name)
end

--- A session of the form Claude Code gives that the tab switches to, one for
--- each case: the session a start last followed is kept for the folder, and
--- the cases share the folder's state.
---
---@param number integer the case's own number
---@return string
local function new_session_numbered(number)
  return ('1f1c5b0e-7a3d-4d52-8f0b-6d2e9a7c%04d'):format(number)
end

--- Tells the child's Claude home, as the hook relay does when the session
--- Claude Code runs switches to `new` (a `/resume`, say): the `SessionEnd`
--- of the session followed, then the `SessionStart` of `new`, the tab's own
--- start token with both.
---
---@param new string
local function tell_switch_to(new)
  run_and_settle(
    [[
      local claude = require('aineo.claude')
      local left, new = ...
      claude.receive_session_event('SessionEnd', left, 'resume', claude.start_token(), 1, nil, nil)
      claude.receive_session_event('SessionStart', new, 'resume', claude.start_token(), 2, nil, nil)
    ]],
    { tab_session(), new }
  )
end

T['a switch of the tab’s session'] = MiniTest.new_set()

T['a switch of the tab’s session']['is told to the office of the tab'] = function()
  local new_session = new_session_numbered(1)
  open_layout_with_stand_in_offices('office-switch')
  local at_start = stand_in.told(child).session_changed

  tell_switch_to(new_session)

  eq(tab_session(), new_session)
  eq(stand_in.told(child).session_changed - at_start, 1)
end

T['a switch of the tab’s session']['is not told to the office by a hook of the session the tab runs, which names no transcript'] = function()
  open_layout_with_stand_in_offices('office-switch-same')
  local at_start = stand_in.told(child).session_changed

  run_and_settle([[
    local claude = require('aineo.claude')
    claude.receive_session_event('SessionStart', claude.session_id(), 'compact', claude.start_token(), nil, nil, nil)
  ]])

  eq(stand_in.told(child).session_changed - at_start, 0)
end

T['a switch of the tab’s session']['is told again when a hook then names another transcript for the session the tab runs now'] = function()
  local new_session = new_session_numbered(3)
  open_layout_with_stand_in_offices('office-switch-path')
  local at_start = stand_in.told(child).session_changed
  tell_switch_to(new_session)

  tell_transcript(new_session, '/named/by/the/hook.jsonl')

  eq(stand_in.told(child).session_changed - at_start, 2)
end

T['a switch of the tab’s session']['is not told again when a hook names a transcript for a session the tab does not run'] = function()
  local new_session = new_session_numbered(4)
  open_layout_with_stand_in_offices('office-switch-path-other')
  local at_start = stand_in.told(child).session_changed
  tell_switch_to(new_session)

  tell_transcript(OTHER_SESSION, '/named/by/the/hook.jsonl')

  eq(stand_in.told(child).session_changed - at_start, 1)
end

T['a switch of the tab’s session']['is not told again when a hook names the transcript the office follows already'] = function()
  local new_session = new_session_numbered(5)
  open_layout_with_stand_in_offices('office-switch-path-twice')
  local at_start = stand_in.told(child).session_changed
  tell_switch_to(new_session)
  tell_transcript(new_session, '/named/by/the/hook.jsonl')

  tell_transcript(new_session, '/named/by/the/hook.jsonl')

  eq(stand_in.told(child).session_changed - at_start, 2)
end

--- Has the tracker of every office the child makes keep the kinds of the
--- signals it takes in `_G.taken`.
local KEEP_THE_SIGNALS_TAKEN = [[
  local office_states = require('aineo.office_states')
  local new_tracker = office_states.new_tracker
  _G.taken = {}
  office_states.new_tracker = function(options)
    local tracker = new_tracker(options)
    local take = tracker.take
    tracker.take = function(signal, now)
      table.insert(_G.taken, signal.kind)
      return take(signal, now)
    end
    return tracker
  end
]]

--- A session of the form Claude Code gives that a case's tab claims, one for
--- each case: the session a claim leaves is kept for the folder.
---
---@param number integer the case's own number
---@return string
local function claimed_session_numbered(number)
  return ('5c1a1ed0-7a3d-4d52-8f0b-6d2e9a7c%04d'):format(number)
end

--- Writes `lines` as the transcript of `session` where Claude Code keeps it.
---
---@param session string
---@param lines string[]
local function write_transcript_of(session, lines)
  local directory =
    vim.fs.joinpath(child.lua_get([[vim.env.CLAUDE_CONFIG_DIR]]), 'projects', 'other')
  vim.fn.mkdir(directory, 'p')
  fake_transcript.append(vim.fs.joinpath(directory, session .. '.jsonl'), lines)
end

T['a claimed session'] = MiniTest.new_set()

T['a claimed session']['is the one the office acts out, in place of the session of the tab’s own Claude Code'] = function()
  local claimed = claimed_session_numbered(1)
  open_layout('office-claim')
  child.lua(KEEP_THE_SIGNALS_TAKEN)
  write_transcript_of(claimed, vim.list_slice(RECORDED_TURN, 1, 5))
  write_transcript_of(tab_session(), RECORDED_TURN)
  child.cmd('Aineo claim ' .. claimed)

  entry.command(child, 'Aineo office')

  eq(child.lua_get('_G.taken'), { 'prompt', 'tool_started' })
end

T['a claimed session']['is acted out from the moment it is claimed, by an office that shows'] = function()
  local claimed = claimed_session_numbered(2)
  open_layout('office-claim-shown')
  child.lua(KEEP_THE_SIGNALS_TAKEN)
  write_transcript_of(claimed, vim.list_slice(RECORDED_TURN, 1, 5))
  write_transcript_of(tab_session(), RECORDED_TURN)
  entry.command(child, 'Aineo office')
  child.lua('_G.taken = {}')

  child.cmd('Aineo claim ' .. claimed)

  eq(child.lua_get('_G.taken'), { 'prompt', 'tool_started' })
end

T['a claimed session']['is told to the office once, not again by a claim of the session the panes follow already'] = function()
  local claimed = claimed_session_numbered(3)
  open_layout_with_stand_in_offices('office-claim-twice')
  local at_start = stand_in.told(child).session_changed

  child.cmd('Aineo claim ' .. claimed)
  child.cmd('Aineo claim ' .. claimed)

  eq(stand_in.told(child).session_changed - at_start, 1)
end

T['a permission wait'] = MiniTest.new_set()

T['a permission wait']['reaches the office of the tab, as the main agent or as the subagent that asks'] = function()
  open_layout_with_stand_in_offices('office-wait')
  local session = tab_session()

  tell_permission_wait(session, vim.NIL)
  tell_permission_wait(session, 'a0000000000000001')

  eq(stand_in.told(child).waits, { 'main', 'a0000000000000001' })
end

T['a permission wait']['is not told to the office when it is of a session the tab does not run'] = function()
  open_layout_with_stand_in_offices('office-wait-other')

  tell_permission_wait(OTHER_SESSION, vim.NIL)

  eq(stand_in.told(child).waits, {})
end

T['a permission wait']['reaches the office the tab made as it opened, before the office was asked to show'] = function()
  open_layout_with_stand_in_offices('office-wait-early')

  tell_permission_wait(tab_session(), vim.NIL)

  eq(stand_in.told(child).made, 1)
  eq(stand_in.told(child).waits, { 'main' })
end

T['a permission wait']['raises nothing in the real office, shown or not'] = function()
  open_layout('office-wait-real')
  tell_permission_wait(tab_session(), vim.NIL)
  entry.command(child, 'Aineo office')

  tell_permission_wait(tab_session(), vim.NIL)

  eq(entry.messages(child), {})
end

return T
