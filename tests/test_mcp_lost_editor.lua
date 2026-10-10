local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local mcp_messages = dofile('tests/helpers/mcp_messages.lua')
local mcp_relay = dofile('tests/helpers/mcp_relay.lua')
local report_editor = dofile('tests/helpers/report_editor.lua')
local report_tui = dofile('tests/helpers/report_tui.lua')

local eq = MiniTest.expect.equality
local get = vim.tbl_get
local decoded = mcp_relay.decoded

--- The Neovims a case runs: the editor that started Claude Code, and two
--- more that may show its session.
local starting = MiniTest.new_child_neovim()
local first = MiniTest.new_child_neovim()
local second = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    post_case = function()
      mcp_relay.stop_all()
      report_tui.stop_all()
    end,
    post_once = function()
      starting.stop()
      first.stop()
      second.stop()
    end,
  },
})

--- Session ids of the form Claude Code gives.
local SESSION_ID = 'c9d64d84-5f2b-4c3e-9a1d-2b7e8f0a6c31'
local OTHER_SESSION_ID = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'

--- The start token of the Claude Code whose report server a case runs.
local TOKEN = '5b1c0f5e-2d7a-4c1b-9e3f-6a8d2c4b1e07'

--- What the report tool answers for each way a report went.
local DELIVERED = 'Delivered to the Agent Report.'
local SHOWN_ELSEWHERE = 'Delivered to the Agent Report of another Neovim that shows this session,'
  .. ' because the one Claude Code started in is gone or follows another session.'

--- How each Report shows the recorded report (`mcp_messages.recorded()`).
local SHOWN = { '09:05 [done] Refactor the parser — All tests pass' }

--- A case's own state: the `XDG_STATE_HOME` its relay and editors share,
--- and the state directory under it, `stdpath('state')` for each.
---
---@param name string
---@return { home: string, directory: string }
local function case_state(name)
  local home = fixture.directory(name)
  return { home = home, directory = vim.fs.joinpath(home, 'nvim') }
end

--- An address no Neovim listens on any more, under `state`.
---
---@param state { home: string }
---@return string
local function gone_address(state)
  return vim.fs.joinpath(state.home, 'gone.sock')
end

--- Starts `child` as an aineo editor whose report home keeps its reports
--- under `state` and follows `session`, its Report made at once from the
--- records kept then, and lists it among the running editors there, last
--- used at `used`.
---
---@param child table
---@param state { directory: string }
---@param session string
---@param used integer
local function start_follower(child, state, session, used)
  report_editor.start(child, {
    times = { '2026-09-24T09:05:00' },
    state_directory = state.directory,
    working_directory = '/projects/alpha',
  })
  child.lua(
    [[
      local state, session, used = ...
      require('aineo.report').follow_report_session(session)
      require('aineo.report').report_buffer()
      require('aineo.mcp').write_editor_entry(state, {
        address = vim.v.servername,
        working_directory = '/projects/alpha',
        session = session,
        own = true,
        used = used,
      })
    ]],
    { state.directory, session, used }
  )
end

--- Starts a user's editor with a UI (`report_tui.start()`) whose report
--- home keeps its reports under `state` and follows `session`, lists it
--- among the running editors there, last used at `used`, and puts it at a
--- hit-enter prompt.
---
---@param state { directory: string }
---@param session string
---@param used integer
---@return aineo.test.TuiEditor
local function start_follower_at_prompt(state, session, used)
  local editor = report_tui.start({
    time = '2026-09-24T09:05:00',
    state_directory = state.directory,
    working_directory = '/projects/alpha',
  })
  vim.rpcrequest(
    editor.channel,
    'nvim_exec_lua',
    [[
      local state, session, used = ...
      require('aineo.report').follow_report_session(session)
      require('aineo.report').report_buffer()
      require('aineo.mcp').write_editor_entry(state, {
        address = vim.v.servername,
        working_directory = '/projects/alpha',
        session = session,
        own = true,
        used = used,
      })
    ]],
    { state.directory, session, used }
  )
  editor:type(':echo "one\\ntwo\\nthree"\r')
  assert(editor:waits_at_hit_enter(), 'the editor is not at a hit-enter prompt')
  return editor
end

--- What the relay answers when an editor has not confirmed a report in time.
local NOT_CONFIRMED = 'aineo sent the report, but the editor did not confirm it within 5 s:'
  .. ' it may be waiting for the user, at a hit-enter prompt for one.'
  .. ' The report is sent, not confirmed; do not send it again.'

--- Starts the report relay of a Claude Code whose editor is at `address`,
--- on its first session `session`, with the state of `state`.
---
---@param state { home: string }
---@param address string?
---@param session string?
---@return aineo.test.Relay
local function start_relay(state, address, session)
  return mcp_relay.start_relay({
    XDG_STATE_HOME = state.home,
    AINEO_EDITOR_ADDRESS = address,
    AINEO_START_TOKEN = TOKEN,
    CLAUDE_CODE_SESSION_ID = session,
  })
end

--- The text of the tool's answer to the report the relay was sent last, and
--- whether it is a tool error.
---
---@param relay aineo.test.Relay
---@return { text: string?, error: boolean? }
local function answer(relay)
  local result = get(decoded(relay:next_line()), 'result')
  return { text = get(result or {}, 'content', 1, 'text'), error = get(result or {}, 'isError') }
end

--- The task of each report the records file at `path` keeps, in order; nil
--- when there is no such file.
---
---@param path string
---@return string[]?
local function kept_tasks(path)
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local text = file:read('*a')
  file:close()
  return vim.tbl_map(function(line)
    return vim.json.decode(line).report.task
  end, vim.split(text, '\n', { trimempty = true }))
end

--- The records file of `session` under `state`.
---
---@param state { directory: string }
---@param session string
---@return string
local function session_records(state, session)
  return vim.fs.joinpath(
    state.directory,
    'aineo',
    'reports',
    'session-' .. vim.fn.sha256(session) .. '.jsonl'
  )
end

--- The records file of the working directory `/projects/alpha` under
--- `state`.
---
---@param state { directory: string }
---@return string
local function directory_records(state)
  return vim.fs.joinpath(
    state.directory,
    'aineo',
    'reports',
    vim.fn.sha256('/projects/alpha') .. '.jsonl'
  )
end

--- What the Kept answer says.
local KEPT = "Kept in this session's Agent Report on disk, because no Neovim shows the session now;"
  .. ' it shows when aineo next shows the session.'

T['a report whose starting editor answers'] = MiniTest.new_set()

T['a report whose starting editor answers']['goes there alone, though a Neovim showing its session was used later'] = function()
  local state = case_state('mcp-lost-starting-answers')
  start_follower(starting, state, SESSION_ID, 1000)
  start_follower(first, state, SESSION_ID, 2000)
  local relay = start_relay(state, starting.v.servername, SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))

  eq(
    { answer(relay), report_editor.lines(starting), report_editor.lines(first) },
    { { text = DELIVERED, error = false }, SHOWN, { '' } }
  )
end

T['a report whose starting editor is gone'] = MiniTest.new_set()

T['a report whose starting editor is gone']['and whose session no Neovim shows is kept in that session’s records alone, and says so'] = function()
  local state = case_state('mcp-lost-kept')
  start_follower(first, state, OTHER_SESSION_ID, 1000)
  local relay = start_relay(state, gone_address(state), SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))

  eq({
    answer = answer(relay),
    session = kept_tasks(session_records(state, SESSION_ID)),
    other = kept_tasks(session_records(state, OTHER_SESSION_ID)),
    directory = kept_tasks(directory_records(state)),
    shown_by_other = report_editor.lines(first),
  }, {
    answer = { text = KEPT, error = false },
    session = { 'Refactor the parser' },
    shown_by_other = { '' },
  })
end

T['a report whose starting editor is gone']['kept on disk shows in a Neovim that then follows its session'] = function()
  local state = case_state('mcp-lost-kept-shown')
  local relay = start_relay(state, gone_address(state), SESSION_ID)
  relay:send(mcp_messages.recorded('tools/call'))
  answer(relay)

  start_follower(second, state, SESSION_ID, 1000)

  eq(
    vim.tbl_map(function(line)
      return (line:gsub('^%d%d:%d%d ', 'HH:MM '))
    end, report_editor.lines(second)),
    { 'HH:MM [done] Refactor the parser — All tests pass' }
  )
end

T['a report whose starting editor is gone']['goes to the more recently used of two Neovims showing its session'] = function()
  local state = case_state('mcp-lost-recent')
  start_follower(first, state, SESSION_ID, 2000)
  start_follower(second, state, SESSION_ID, 1000)
  local relay = start_relay(state, gone_address(state), SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))

  eq(
    { answer(relay), report_editor.lines(first), report_editor.lines(second) },
    { { text = SHOWN_ELSEWHERE, error = false }, SHOWN, { '' } }
  )
end

T['a report whose starting editor is gone']['passes a listed Neovim that follows another session now to the next'] = function()
  local state = case_state('mcp-lost-stale')
  start_follower(first, state, SESSION_ID, 2000)
  first.lua("require('aineo.report').follow_report_session(...)", { OTHER_SESSION_ID })
  start_follower(second, state, SESSION_ID, 1000)
  local relay = start_relay(state, gone_address(state), SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))

  eq({
    answer = answer(relay),
    stale = report_editor.lines(first),
    stale_kept = kept_tasks(session_records(state, OTHER_SESSION_ID)),
    next = report_editor.lines(second),
  }, { answer = { text = SHOWN_ELSEWHERE, error = false }, stale = { '' }, next = SHOWN })
end

T['a report whose starting editor is gone']['skips a listed Neovim that cannot be reached, removes its entry, and goes to the next'] = function()
  local state = case_state('mcp-lost-unreachable-entry')
  start_follower(first, state, SESSION_ID, 1000)
  local gone = gone_address(state)
  local gone_entry =
    vim.fs.joinpath(state.directory, 'aineo', 'editors', vim.fn.sha256(gone) .. '.json')
  vim.fn.writefile({
    vim.json.encode({
      address = gone,
      working_directory = '/projects/alpha',
      session = SESSION_ID,
      own = true,
      used = 2000,
    }),
  }, gone_entry)
  local relay = start_relay(state, vim.fs.joinpath(state.home, 'starting.sock'), SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))

  eq({
    answer = answer(relay),
    shown = report_editor.lines(first),
    gone_entry = vim.uv.fs_stat(gone_entry),
  }, { answer = { text = SHOWN_ELSEWHERE, error = false }, shown = SHOWN })
end

T['a report whose starting editor is gone']['held by a listed Neovim at a hit-enter prompt is unconfirmed, goes nowhere else, and shows there once the user is done'] = function()
  local state = case_state('mcp-lost-prompt')
  local held = start_follower_at_prompt(state, SESSION_ID, 2000)
  start_follower(first, state, SESSION_ID, 1000)
  local relay = start_relay(state, gone_address(state), SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))
  local answered = answer(relay)
  held:type('\r')

  eq({
    answer = answered,
    elsewhere = report_editor.lines(first),
    held = held:report_lines(SHOWN),
    kept = kept_tasks(session_records(state, SESSION_ID)),
  }, {
    answer = { text = NOT_CONFIRMED, error = false },
    elsewhere = { '' },
    held = SHOWN,
    kept = { 'Refactor the parser' },
  })
end

T['a report whose starting editor is gone']['never tries a Neovim of another session, though it waits at a hit-enter prompt, and keeps the report'] = function()
  local state = case_state('mcp-lost-prompt-other')
  local other = start_follower_at_prompt(state, OTHER_SESSION_ID, 2000)
  local relay = start_relay(state, gone_address(state), SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))
  local answered = answer(relay)
  other:type('\r')

  eq({
    answer = answered,
    kept = kept_tasks(session_records(state, SESSION_ID)),
  }, { answer = { text = KEPT, error = false }, kept = { 'Refactor the parser' } })
end

T['the session of a report'] = MiniTest.new_set()

T['the session of a report']['is the one its Claude Code process’s hooks last recorded'] = function()
  local state = case_state('mcp-lost-recorded')
  start_follower(first, state, SESSION_ID, 2000)
  start_follower(second, state, OTHER_SESSION_ID, 1000)
  local relay = start_relay(state, gone_address(state), SESSION_ID)
  relay:send('{"jsonrpc":"2.0","id":1,"method":"ping"}')
  relay:next_line()
  local mcp = require('aineo.mcp')
  for _, told in ipairs({
    { event = 'SessionEnd', session = SESSION_ID, ran = 2000 },
    { event = 'SessionStart', session = OTHER_SESSION_ID, ran = 3000 },
  }) do
    mcp.record_session_event(state.directory, {
      pid = vim.fn.getpid(),
      token = TOKEN,
      event = told.event,
      session = told.session,
      ran = told.ran,
      working_directory = '/projects/alpha',
    })
  end

  relay:send(mcp_messages.recorded('tools/call'))

  eq(
    { answer(relay), report_editor.lines(first), report_editor.lines(second) },
    { { text = SHOWN_ELSEWHERE, error = false }, { '' }, SHOWN }
  )
end

T['the session of a report']['is the server’s own first session when no record names it'] = function()
  local state = case_state('mcp-lost-first-session')
  start_follower(first, state, SESSION_ID, 1000)
  local relay = mcp_relay.start_relay({
    XDG_STATE_HOME = state.home,
    AINEO_EDITOR_ADDRESS = gone_address(state),
    CLAUDE_CODE_SESSION_ID = SESSION_ID,
  })

  relay:send(mcp_messages.recorded('tools/call'))

  eq(
    { answer(relay), report_editor.lines(first) },
    { { text = SHOWN_ELSEWHERE, error = false }, SHOWN }
  )
end

T['the session of a report']['unknown leaves a report whose editor is gone a tool error, saying no session was known'] = function()
  local state = case_state('mcp-lost-no-session')
  local gone = gone_address(state)
  local relay = mcp_relay.start_relay({
    XDG_STATE_HOME = state.home,
    AINEO_EDITOR_ADDRESS = gone,
    AINEO_START_TOKEN = TOKEN,
  })

  relay:send(mcp_messages.recorded('tools/call'))

  eq(answer(relay), {
    text = ('aineo could not reach the editor at %s: ENOENT; no session was known to keep the report for'):format(
      gone
    ),
    error = true,
  })
end

T['a report whose starting editor follows another session'] = MiniTest.new_set()

T['a report whose starting editor follows another session']['is neither shown nor kept there, and goes to a Neovim that shows its session'] = function()
  local state = case_state('mcp-lost-starting-other')
  start_follower(starting, state, OTHER_SESSION_ID, 3000)
  start_follower(first, state, SESSION_ID, 1000)
  local relay = start_relay(state, starting.v.servername, SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))

  eq({
    answer = answer(relay),
    starting = report_editor.lines(starting),
    starting_kept = kept_tasks(session_records(state, OTHER_SESSION_ID)),
    shown = report_editor.lines(first),
  }, { answer = { text = SHOWN_ELSEWHERE, error = false }, starting = { '' }, shown = SHOWN })
end

T['a report whose starting editor follows another session']['is kept on disk when no Neovim shows its session'] = function()
  local state = case_state('mcp-lost-starting-other-kept')
  start_follower(starting, state, OTHER_SESSION_ID, 3000)
  local relay = start_relay(state, starting.v.servername, SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))

  eq(
    {
      answer = answer(relay),
      starting = report_editor.lines(starting),
      kept = kept_tasks(session_records(state, SESSION_ID)),
    },
    { answer = { text = KEPT, error = false }, starting = { '' }, kept = { 'Refactor the parser' } }
  )
end

T['a report whose starting editor is older than its relay'] = MiniTest.new_set()

T['a report whose starting editor is older than its relay']['shows there once, as before'] = function()
  local state = case_state('mcp-lost-older')
  start_follower(starting, state, OTHER_SESSION_ID, 3000)
  starting.lua("require('aineo.report').receive_session_report = nil")
  local relay = start_relay(state, starting.v.servername, SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))

  eq(
    { answer(relay), report_editor.lines(starting) },
    { { text = DELIVERED, error = false }, SHOWN }
  )
end

T['a report with no editor address'] = MiniTest.new_set()

T['a report with no editor address']['goes to a Neovim that shows its session when its session is known'] = function()
  local state = case_state('mcp-lost-no-address')
  start_follower(first, state, SESSION_ID, 1000)
  local relay = start_relay(state, nil, SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))

  eq(
    { answer(relay), report_editor.lines(first) },
    { { text = SHOWN_ELSEWHERE, error = false }, SHOWN }
  )
end

--- What the answer says when the claimant took the report.
local CLAIMANT_TOOK = 'Delivered to the Agent Report of another Neovim that claimed this session.'

--- Makes the editor at `address` the claimant of `session` under `state`.
---
---@param state { directory: string }
---@param session string
---@param address string
local function claim(state, session, address)
  require('aineo.mcp').claim_session(state.directory, session, address, 5000)
end

--- The claim file of `session` under `state`, decoded; nil when there is
--- none.
---
---@param state { directory: string }
---@param session string
---@return table?
local function claim_of(state, session)
  local path =
    vim.fs.joinpath(state.directory, 'aineo', 'claims', vim.fn.sha256(session) .. '.json')
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local text = file:read('*a')
  file:close()
  return vim.json.decode(text)
end

T['a report of a claimed session'] = MiniTest.new_set()

T['a report of a claimed session']['goes to the claimant alone while the starting editor answers, and says so'] = function()
  local state = case_state('mcp-lost-claimant')
  start_follower(starting, state, SESSION_ID, 3000)
  start_follower(first, state, SESSION_ID, 1000)
  claim(state, SESSION_ID, first.v.servername)
  local relay = start_relay(state, starting.v.servername, SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))
  local answered = answer(relay)
  local starting_lines = report_editor.lines(starting)
  starting.lua("require('aineo.report').follow_report_session(...)", { OTHER_SESSION_ID })
  starting.lua("require('aineo.report').follow_report_session(...)", { SESSION_ID })

  eq({
    answer = answered,
    claimant = report_editor.lines(first),
    starting = starting_lines,
    starting_next_follow = report_editor.lines(starting),
  }, {
    answer = { text = CLAIMANT_TOOK, error = false },
    claimant = SHOWN,
    starting = { '' },
    starting_next_follow = SHOWN,
  })
end

T['a report of a claimed session']['whose claimant cannot be reached goes to the starting editor, the claim and the entry removed'] = function()
  local state = case_state('mcp-lost-claimant-gone')
  start_follower(starting, state, SESSION_ID, 3000)
  local gone = gone_address(state)
  local gone_entry =
    vim.fs.joinpath(state.directory, 'aineo', 'editors', vim.fn.sha256(gone) .. '.json')
  vim.fn.writefile({
    vim.json.encode({
      address = gone,
      working_directory = '/projects/alpha',
      session = SESSION_ID,
      own = false,
      used = 4000,
    }),
  }, gone_entry)
  claim(state, SESSION_ID, gone)
  local relay = start_relay(state, starting.v.servername, SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))

  eq({
    answer = answer(relay),
    starting = report_editor.lines(starting),
    claim = claim_of(state, SESSION_ID),
    entry = vim.uv.fs_stat(gone_entry),
  }, { answer = { text = DELIVERED, error = false }, starting = SHOWN })
end

T['a report of a claimed session']['whose claimant follows another session now goes to the starting editor, the claim removed'] = function()
  local state = case_state('mcp-lost-claimant-stale')
  start_follower(starting, state, SESSION_ID, 3000)
  start_follower(first, state, SESSION_ID, 1000)
  claim(state, SESSION_ID, first.v.servername)
  first.lua("require('aineo.report').follow_report_session(...)", { OTHER_SESSION_ID })
  local relay = start_relay(state, starting.v.servername, SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))

  eq({
    answer = answer(relay),
    starting = report_editor.lines(starting),
    claimant = report_editor.lines(first),
    claim = claim_of(state, SESSION_ID),
  }, { answer = { text = DELIVERED, error = false }, starting = SHOWN, claimant = { '' } })
end

T['a report of a claimed session']['held by a claimant at a hit-enter prompt is unconfirmed, and not sent to the starting editor'] = function()
  local state = case_state('mcp-lost-claimant-prompt')
  start_follower(starting, state, SESSION_ID, 3000)
  local held = start_follower_at_prompt(state, SESSION_ID, 1000)
  claim(state, SESSION_ID, held.address)
  local relay = start_relay(state, starting.v.servername, SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))
  local answered = answer(relay)
  local starting_lines = report_editor.lines(starting)
  held:type('\r')

  eq({
    answer = answered,
    starting = starting_lines,
    held = held:report_lines(SHOWN),
    kept = kept_tasks(session_records(state, SESSION_ID)),
  }, {
    answer = { text = NOT_CONFIRMED, error = false },
    starting = { '' },
    held = SHOWN,
    kept = { 'Refactor the parser' },
  })
end

T['a report of a claimed session']['goes to the newest claimant, and, once it has let go, to the starting editor, not the claimant it overtook'] = function()
  local state = case_state('mcp-lost-claimants')
  start_follower(starting, state, SESSION_ID, 3000)
  start_follower(first, state, SESSION_ID, 1000)
  start_follower(second, state, SESSION_ID, 2000)
  claim(state, SESSION_ID, first.v.servername)
  claim(state, SESSION_ID, second.v.servername)
  local relay = start_relay(state, starting.v.servername, SESSION_ID)
  relay:send(mcp_messages.recorded('tools/call'))
  local to_newest = answer(relay)
  local newest = report_editor.lines(second)
  require('aineo.mcp').release_claim(state.directory, SESSION_ID, second.v.servername)
  second.stop()

  relay:send(mcp_messages.tools_call('report', {
    task = 'Rename the lexer',
    status = 'done',
    summary = 'All tests pass',
  }, 3))

  eq({
    to_newest = to_newest,
    newest = newest,
    next = answer(relay),
    overtaken = report_editor.lines(first),
    starting = report_editor.lines(starting),
  }, {
    to_newest = { text = CLAIMANT_TOOK, error = false },
    newest = SHOWN,
    next = { text = DELIVERED, error = false },
    overtaken = { '' },
    starting = { '09:05 [done] Rename the lexer — All tests pass' },
  })
end

T['a report of a claimed session']['claimed by the starting editor goes there once, with the usual answer'] = function()
  local state = case_state('mcp-lost-claimant-starting')
  start_follower(starting, state, SESSION_ID, 3000)
  claim(state, SESSION_ID, starting.v.servername)
  local relay = start_relay(state, starting.v.servername, SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))

  eq({
    answer = answer(relay),
    starting = report_editor.lines(starting),
    kept = kept_tasks(session_records(state, SESSION_ID)),
  }, {
    answer = { text = DELIVERED, error = false },
    starting = SHOWN,
    kept = { 'Refactor the parser' },
  })
end

T['a report whose starting editor is gone']['skips a listed Neovim on host:port, keeping its entry, and keeps the report'] = function()
  local state = case_state('mcp-lost-tcp-entry')
  start_follower(first, state, SESSION_ID, 1000)
  local tcp = first.lua_get("vim.fn.serverstart('127.0.0.1:0')")
  local tcp_entry =
    vim.fs.joinpath(state.directory, 'aineo', 'editors', vim.fn.sha256(tcp) .. '.json')
  vim.fn.writefile({
    vim.json.encode({
      address = tcp,
      working_directory = '/projects/alpha',
      session = SESSION_ID,
      own = true,
      used = 2000,
    }),
  }, tcp_entry)
  first.lua("require('aineo.report').follow_report_session(...)", { OTHER_SESSION_ID })
  local relay = start_relay(state, gone_address(state), SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))

  eq({
    answer = answer(relay),
    shown = report_editor.lines(first),
    tcp_entry = vim.uv.fs_stat(tcp_entry) ~= nil,
  }, { answer = { text = KEPT, error = false }, shown = { '' }, tcp_entry = true })
end

T['a report whose starting editor is gone']['goes to the Neovim listed as showing its session, and says so'] = function()
  local state = case_state('mcp-lost-follower')
  start_follower(first, state, SESSION_ID, 1000)
  local relay = start_relay(state, gone_address(state), SESSION_ID)

  relay:send(mcp_messages.recorded('tools/call'))

  eq(
    { answer(relay), report_editor.lines(first) },
    { { text = SHOWN_ELSEWHERE, error = false }, SHOWN }
  )
end

return T
