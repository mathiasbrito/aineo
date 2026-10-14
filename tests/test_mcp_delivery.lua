local MiniTest = require('mini.test')
local mcp = require('aineo.mcp')
local fixture = dofile('tests/helpers/fixture.lua')
local mcp_messages = dofile('tests/helpers/mcp_messages.lua')
local mcp_relay = dofile('tests/helpers/mcp_relay.lua')
local children = dofile('tests/helpers/child.lua')
local report_editor = dofile('tests/helpers/report_editor.lua')

local eq = MiniTest.expect.equality
local get = vim.tbl_get
local decoded = mcp_relay.decoded

--- Whether `text` is a string that begins with `prefix`.
---
---@param text any
---@param prefix string
---@return boolean
local function begins_with(text, prefix)
  return type(text) == 'string' and vim.startswith(text, prefix)
end

--- The child Neovim a relay delivers to: the user's editor.
local editor = MiniTest.new_child_neovim()

--- Starts the editor with its report home's clock at 09:05, a fresh state
--- directory and the working directory `/projects/alpha`.
local function start_editor()
  report_editor.start(editor, {
    times = { '2026-09-24T09:05:00' },
    state_directory = fixture.directory('mcp-delivery-state'),
    working_directory = '/projects/alpha',
  })
end

--- The sockets and timers of the stand-in editors, closed after each case.
---@type (uv.uv_pipe_t|uv.uv_timer_t)[]
local stand_in_handles = {}

--- How long a stand-in editor waits between its notification and its answer,
--- so that the relay reads them apart.
local ANSWER_DELAY_MS = 50

--- The msgpack-RPC message types a stand-in editor reads and writes (`:h rpc`).
local REQUEST, RESPONSE, NOTIFICATION = 0, 1, 2

--- Listens at a new socket path in place of the user's editor, and hands
--- each msgpack-RPC request it receives there to `answer`, with the
--- connection to write to; any other message it receives is ignored, as an
--- editor answers requests only.
---
---@param answer fun(connection: uv.uv_pipe_t, request: table)
---@return string address
local function start_stand_in_editor(answer)
  local address = vim.fn.tempname() .. '.sock'
  local server = assert(vim.uv.new_pipe(false))
  table.insert(stand_in_handles, server)
  server:bind(address)
  server:listen(1, function()
    local connection = assert(vim.uv.new_pipe(false))
    table.insert(stand_in_handles, connection)
    server:accept(connection)
    local unpack = vim.mpack.Unpacker()
    connection:read_start(function(_, data)
      local message = data and unpack(data)
      if message and message[1] == REQUEST then
        answer(connection, message)
      end
    end)
  end)
  return address
end

--- A stand-in editor (`start_stand_in_editor()`) that answers the request
--- with success — after first writing a notification, what an editor sends
--- when a plugin broadcasts to every channel (`rpcnotify(0, …)`) while a
--- report is received.
---
---@return string address
local function start_editor_notifying_first()
  local answer_later = assert(vim.uv.new_timer())
  table.insert(stand_in_handles, answer_later)
  return start_stand_in_editor(function(connection, request)
    connection:write(vim.mpack.encode({ NOTIFICATION, 'aineo_test_broadcast', {} }))
    answer_later:start(ANSWER_DELAY_MS, 0, function()
      connection:write(vim.mpack.encode({ RESPONSE, request[2], vim.NIL, vim.NIL }))
    end)
  end)
end

--- A stand-in editor (`start_stand_in_editor()`) that refuses the request
--- with `reason`, as an editor answers a request that raised an error.
---
---@param reason string
---@return string address
local function start_editor_refusing(reason)
  return start_stand_in_editor(function(connection, request)
    connection:write(vim.mpack.encode({ RESPONSE, request[2], { 0, reason }, vim.NIL }))
  end)
end

--- A stand-in editor (`start_stand_in_editor()`) that appends the arguments
--- of each request it receives to `requests` and answers it with `taken`:
--- `true` takes the report, `false` declines it.
---
---@param requests table[]
---@param taken boolean
---@return string address
local function start_recording_editor(requests, taken)
  return start_stand_in_editor(function(connection, request)
    table.insert(requests, request[4][2])
    connection:write(vim.mpack.encode({ RESPONSE, request[2], vim.NIL, taken }))
  end)
end

--- Closes every socket and timer a stand-in editor opened.
local function close_stand_in_handles()
  for _, handle in ipairs(stand_in_handles) do
    if not handle:is_closing() then
      handle:close()
    end
  end
  stand_in_handles = {}
end

local T = MiniTest.new_set({
  hooks = {
    post_case = function()
      mcp_relay.stop_all()
      close_stand_in_handles()
    end,
    post_once = editor.stop,
  },
})

T['the server entry'] = MiniTest.new_set()

T['the server entry']['started as Claude Code starts it, completes the recorded handshake and relays a report'] = function()
  start_editor()
  local entry = mcp.mcp_servers(editor.job.address, vim.v.progpath).aineo
  local relay = mcp_relay.start(vim.list_extend({ entry.command }, entry.args), entry.env)

  relay:send(mcp_messages.recorded('initialize'))
  relay:send(mcp_messages.recorded('notifications/initialized'))
  relay:send(mcp_messages.recorded('tools/list'))
  relay:send(mcp_messages.recorded('tools/call'))

  local answers = relay:next_lines(3)
  eq({
    get(decoded(answers[1]), 'id'),
    get(decoded(answers[1]), 'result', 'protocolVersion'),
    get(decoded(answers[2]), 'id'),
    get(decoded(answers[2]), 'result', 'tools', 1, 'name'),
    get(decoded(answers[3]), 'id'),
    get(decoded(answers[3]), 'result', 'isError'),
  }, { 0, '2025-11-25', 1, 'report', 2, false })
  eq(report_editor.lines(editor), { '09:05 [done] Refactor the parser — All tests pass' })
end

T['the relay script'] = MiniTest.new_set()

T['the relay script']['loaded inside an editor serves nothing'] = function()
  children.restart(editor)

  vim.rpcnotify(
    editor.job.channel,
    'nvim_exec_lua',
    [[
      local entry = require('aineo.mcp').mcp_servers('', vim.v.progpath).aineo
      dofile(entry.args[#entry.args])
    ]],
    {}
  )

  eq(
    editor.lua_get([[#vim.tbl_filter(function(channel)
      return channel.stream == 'stdio'
    end, vim.api.nvim_list_chans())]]),
    0
  )
end

T['a report'] = MiniTest.new_set()

T['a report']['reaches the editor the relay was given, and renders in its Report'] = function()
  start_editor()
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = editor.job.address })

  relay:send(mcp_messages.recorded('tools/call'))

  local answer = decoded(relay:next_line())
  eq({ get(answer, 'id'), get(answer, 'result') }, {
    2,
    { isError = false, content = { { type = 'text', text = 'Delivered to the Agent Report.' } } },
  })
  eq(report_editor.lines(editor), { '09:05 [done] Refactor the parser — All tests pass' })
  eq(
    editor.lua_get([[vim.wait(1000, function()
      return #vim.tbl_filter(function(channel)
        return channel.stream == 'socket'
      end, vim.api.nvim_list_chans()) == 1
    end, 10)]]),
    true
  )
end

T['a report']['is confirmed by an editor that writes a notification before its answer'] = function()
  local address = start_editor_notifying_first()
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = address })

  relay:send(mcp_messages.recorded('tools/call'))

  eq(get(decoded(relay:next_line()), 'result'), {
    isError = false,
    content = { { type = 'text', text = 'Delivered to the Agent Report.' } },
  })
end

T['a report']['that the editor refuses is a tool error with the reason, at once, whatever its length'] =
  MiniTest.new_set({ parametrize = { { 255 }, { 256 }, { 300 }, { 512 }, { 513 } } })

T['a report']['that the editor refuses is a tool error with the reason, at once, whatever its length']['of'] = function(
  length
)
  local reason = 'E' .. ('x'):rep(length - 1)
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = start_editor_refusing(reason) })

  relay:send(mcp_messages.recorded('tools/call'))

  eq(get(decoded(relay:next_line(2000)), 'result'), {
    isError = true,
    content = { { type = 'text', text = 'the editor did not take the report: ' .. reason } },
  })
end

T['a report']['reaches an editor listening on a TCP address'] = function()
  start_editor()
  local address = editor.lua_get([[vim.fn.serverstart('127.0.0.1:0')]])
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = address })

  relay:send(mcp_messages.recorded('tools/call'))

  eq(get(decoded(relay:next_line()), 'result', 'isError'), false)
  eq(report_editor.lines(editor), { '09:05 [done] Refactor the parser — All tests pass' })
end

T['a report']['reaches the editor as data: fields holding code render literally and run nothing'] = function()
  start_editor()
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = editor.job.address })
  local witness = vim.fs.joinpath(fixture.directory('mcp-delivery-witness'), 'ran')
  local shell_line = ('$(touch %s) `touch %s` ${HOME}'):format(witness, witness)
  local report = {
    task = "')) vim.g.aineo_ran = 'task' --",
    status = 'done',
    summary = "\"]] vim.g.aineo_ran = 'summary' [[",
    details = "') os.exit(3) --\n" .. shell_line,
  }

  relay:send(mcp_messages.tools_call('report', report, 5))

  eq(get(decoded(relay:next_line()), 'result', 'isError'), false)
  eq(report_editor.lines(editor), {
    "09:05 [done] ')) vim.g.aineo_ran = 'task' -- — \"]] vim.g.aineo_ran = 'summary' [[",
    "      - ') os.exit(3) --",
    '      - ' .. shell_line,
  })
  eq({ editor.lua_get('vim.g.aineo_ran == nil'), vim.uv.fs_stat(witness) == nil }, { true, true })
end

T['a report']['whose details are null renders without details'] = function()
  start_editor()
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = editor.job.address })

  relay:send(
    mcp_messages.tools_call(
      'report',
      { task = 'Task', status = 'done', summary = 'Summary', details = vim.NIL },
      6
    )
  )

  eq(get(decoded(relay:next_line()), 'result', 'isError'), false)
  eq(report_editor.lines(editor), { '09:05 [done] Task — Summary' })
end

T['a report']['for an editor that is gone is a tool error saying so, and the relay keeps serving'] = function()
  start_editor()
  local address = editor.job.address
  editor.stop()
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = address })

  relay:send(mcp_messages.recorded('tools/call'))
  relay:send('{"jsonrpc":"2.0","id":3,"method":"ping"}')

  local answers = relay:next_lines(2)
  eq({
    get(decoded(answers[1]), 'result', 'isError'),
    begins_with(
      get(decoded(answers[1]), 'result', 'content', 1, 'text'),
      'aineo could not reach the editor at ' .. address
    ),
    get(decoded(answers[2]), 'id'),
  }, { true, true, 3 })
end

T['a report']['for a TCP address that cannot be dialled is a tool error saying so'] =
  MiniTest.new_set({ parametrize = { { '127.0.0.1:99999' }, { '127.0.0.1:0' } } })

T['a report']['for a TCP address that cannot be dialled is a tool error saying so']['such as'] = function(
  address
)
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = address })

  relay:send(mcp_messages.recorded('tools/call'))

  local answer = decoded(relay:next_line(2000))
  eq({
    get(answer, 'result', 'isError'),
    begins_with(
      get(answer, 'result', 'content', 1, 'text'),
      'aineo could not reach the editor at ' .. address .. ': '
    ),
  }, { true, true })
end

T['a report']['that the editor does not take is a tool error with the reason it gave'] = function()
  children.restart(editor)
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = editor.job.address })

  relay:send(mcp_messages.recorded('tools/call'))

  eq(get(decoded(relay:next_line()), 'result'), {
    isError = true,
    content = {
      {
        type = 'text',
        text = 'the editor did not take the report: aineo.report has no environment: call set_report_environment() first',
      },
    },
  })
end

--- The reason the stand-in editors in the framing cases refuse a report with.
local REFUSAL_REASON = 'aineo.report has no environment: call set_report_environment() first'

T['a report']['that the editor refuses is a tool error with its reason, without Neovim’s framing'] = function()
  local refusal = 'Lua: ' .. REFUSAL_REASON .. '\nstack traceback:\n\t[C]: in ?'
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = start_editor_refusing(refusal) })

  relay:send(mcp_messages.recorded('tools/call'))

  eq(get(decoded(relay:next_line(2000)), 'result'), {
    isError = true,
    content = { { type = 'text', text = 'the editor did not take the report: ' .. REFUSAL_REASON } },
  })
end

T['a report']['that the editor refuses after the position of the Lua that raised it is a tool error with its reason alone'] =
  MiniTest.new_set({
    parametrize = {
      { '/home/user/aineo/lua/aineo/report/buffer.lua:15: Lua: ' },
      { 'Lua: vim/_core/shared:21: ' },
      { 'Lua: [string "vim/_core/editor"]:353: ' },
    },
  })

T['a report']['that the editor refuses after the position of the Lua that raised it is a tool error with its reason alone']['framed as'] = function(
  framing
)
  local relay = mcp_relay.start_relay({
    AINEO_EDITOR_ADDRESS = start_editor_refusing(framing .. REFUSAL_REASON),
  })

  relay:send(mcp_messages.recorded('tools/call'))

  eq(get(decoded(relay:next_line(2000)), 'result'), {
    isError = true,
    content = { { type = 'text', text = 'the editor did not take the report: ' .. REFUSAL_REASON } },
  })
end

T['a report']['that the editor refuses keeps words of its reason that only look like framing'] = function()
  local reason = 'Error executing lua: the reason quotes Lua: in its own words'
  local relay =
    mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = start_editor_refusing('Lua: ' .. reason) })

  relay:send(mcp_messages.recorded('tools/call'))

  eq(get(decoded(relay:next_line(2000)), 'result'), {
    isError = true,
    content = { { type = 'text', text = 'the editor did not take the report: ' .. reason } },
  })
end

--- The reason an editor gives when the user edited a buffer named as its
--- Report and their BufFilePre autocommand fails as the Report takes the
--- name: the first line of the error, in Neovim 0.12's words for an error
--- raised in a Lua callback.
local BUFFILEPRE_REASON =
  'nvim_exec2()[1]..BufFilePre Autocommands for "*": Vim(append):Lua callback: [string "<nvim>"]:7: the user autocommand fails'

T['a report']['that the editor refuses with words naming a position keeps them all'] = function()
  local reason = 'nvim_exec2()[1]..BufFilePost Autocommands for "*": Vim(append):Lua callback:'
    .. ' user/bufs.lua:7: the user hook failed: user/util.lua:4: the setting is missing'
  local relay =
    mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = start_editor_refusing('Lua: ' .. reason) })

  relay:send(mcp_messages.recorded('tools/call'))

  eq(get(decoded(relay:next_line(2000)), 'result'), {
    isError = true,
    content = { { type = 'text', text = 'the editor did not take the report: ' .. reason } },
  })
end

T['a report']['whose refusal the editor framed after a position is a tool error with the reason alone'] = function()
  start_editor()
  editor.lua([[
    local edited = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(edited, 'aineo://report')
    vim.api.nvim_buf_set_lines(edited, 0, -1, false, { 'the user typed this' })
    vim.api.nvim_create_autocmd('BufFilePre', {
      callback = function(event)
        if event.file == 'aineo://report' then
          error('the user autocommand fails')
        end
      end,
    })
  ]])
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = editor.job.address })

  relay:send(mcp_messages.recorded('tools/call'))

  eq(get(decoded(relay:next_line()), 'result'), {
    isError = true,
    content = {
      { type = 'text', text = 'the editor did not take the report: ' .. BUFFILEPRE_REASON },
    },
  })
end

T['a report']['with no editor address is a tool error saying so, and the relay keeps serving'] =
  MiniTest.new_set({ parametrize = { { {} }, { { AINEO_EDITOR_ADDRESS = '' } } } })

T['a report']['with no editor address is a tool error saying so, and the relay keeps serving']['in the environment'] = function(
  environment
)
  local relay = mcp_relay.start_relay(environment)

  relay:send(mcp_messages.recorded('tools/call'))
  relay:send('{"jsonrpc":"2.0","id":3,"method":"ping"}')

  local answers = relay:next_lines(2)
  eq({ get(decoded(answers[1]), 'result'), get(decoded(answers[2]), 'id') }, {
    {
      isError = true,
      content = { { type = 'text', text = 'aineo has no editor address to deliver the report to' } },
    },
    3,
  })
end

--- Session ids of the form Claude Code gives.
local SESSION_ID = 'c9d64d84-5f2b-4c3e-9a1d-2b7e8f0a6c31'
local OTHER_SESSION_ID = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'

--- The start token of the Claude Code whose report server a case runs.
local TOKEN = '5b1c0f5e-2d7a-4c1b-9e3f-6a8d2c4b1e07'

--- A case's own state: the `XDG_STATE_HOME` its relay reads, and the state
--- directory under it, `stdpath('state')` for the relay.
---
---@param name string
---@return { home: string, directory: string }
local function case_state(name)
  local home = fixture.directory(name)
  return { home = home, directory = vim.fs.joinpath(home, 'nvim') }
end

--- Starts the report relay of a Claude Code, its first session `SESSION_ID`
--- and its start token `token` (none when nil), whose editor is at
--- `address`, with the state of `state`.
---
---@param state { home: string }
---@param address string?
---@param token string?
---@return aineo.test.Relay
local function start_relay_of(state, address, token)
  return mcp_relay.start_relay({
    XDG_STATE_HOME = state.home,
    AINEO_EDITOR_ADDRESS = address,
    AINEO_START_TOKEN = token,
    CLAUDE_CODE_SESSION_ID = SESSION_ID,
  })
end

--- Sends the relay a report and waits for its answer.
---
---@param relay aineo.test.Relay
local function send_report_and_wait(relay)
  relay:send(mcp_messages.recorded('tools/call'))
  relay:next_line()
end

T['an offer'] = MiniTest.new_set()

T['an offer']['to the editor that started Claude Code carries the start token, and keeps its other options'] = function()
  local state = case_state('mcp-offer-starting')
  local requests = {}
  local relay = start_relay_of(state, start_recording_editor(requests, true), TOKEN)

  send_report_and_wait(relay)

  eq(
    { #requests, requests[1][2], requests[1][3] },
    { 1, SESSION_ID, { at_start = true, start_token = TOKEN } }
  )
end

T['an offer']['to the editor that started Claude Code carries no start token while the server knows none'] = function()
  local state = case_state('mcp-offer-starting-no-token')
  local requests = {}
  local relay = start_relay_of(state, start_recording_editor(requests, true), nil)

  send_report_and_wait(relay)

  eq({ #requests, requests[1][3] }, { 1, { at_start = true } })
end

T['an offer']['kept with the working directory carries the start token, and keeps its other options'] = function()
  local state = case_state('mcp-offer-keep')
  local requests = {}
  local relay = start_relay_of(state, start_recording_editor(requests, false), TOKEN)

  send_report_and_wait(relay)

  eq({ #requests, requests[2][3] }, {
    2,
    { at_start = true, keep_with_directory = true, start_token = TOKEN },
  })
end

--- Makes the editor at `address` the claimant of `SESSION_ID` under `state`.
---
---@param state { directory: string }
---@param address string
local function claim_session_for(state, address)
  mcp.claim_session(state.directory, SESSION_ID, address, 5000)
end

--- Replaces `receive_session_report()` in the report home of the child
--- `editor` with a function that records what it is asked, as
--- `{ session_is_nil, options }`, into `_G.asked`, and answers `taken`.
---
---@param taken boolean
local function stub_session_report_home(taken)
  editor.lua(
    [[
      local taken = ...
      _G.asked = {}
      require('aineo.report').receive_session_report = function(_, session, options)
        table.insert(_G.asked, { session == nil, options })
        return taken
      end
    ]],
    { taken }
  )
end

--- Starts the relay of a Claude Code that knows no session, its editor the
--- child `editor`, and its start token `TOKEN`.
---
---@return aineo.test.Relay
local function start_relay_without_session()
  return mcp_relay.start_relay({
    XDG_STATE_HOME = fixture.directory('mcp-offer-no-session'),
    AINEO_EDITOR_ADDRESS = editor.job.address,
    AINEO_START_TOKEN = TOKEN,
  })
end

T['an offer']['of a report with no known session goes to the editor’s report home with the start token'] = function()
  start_editor()
  stub_session_report_home(true)
  local relay = start_relay_without_session()

  send_report_and_wait(relay)

  eq(editor.lua_get('_G.asked'), { { true, { at_start = true, start_token = TOKEN } } })
end

T['an offer']['of a report with no known session shows in the Report when the report home does not take it'] = function()
  start_editor()
  stub_session_report_home(false)
  local relay = start_relay_without_session()

  relay:send(mcp_messages.recorded('tools/call'))

  eq(
    { get(decoded(relay:next_line()), 'result', 'isError'), report_editor.lines(editor) },
    { false, { '09:05 [done] Refactor the parser — All tests pass' } }
  )
end

T['an offer']['of a report with no known session shows in the Report of a report home older than the relay'] = function()
  start_editor()
  editor.lua("require('aineo.report').receive_session_report = nil")
  local relay = start_relay_without_session()

  relay:send(mcp_messages.recorded('tools/call'))

  eq(
    { get(decoded(relay:next_line()), 'result', 'isError'), report_editor.lines(editor) },
    { false, { '09:05 [done] Refactor the parser — All tests pass' } }
  )
end

T['an offer']['to the claimant carries the start token as its options'] = function()
  local state = case_state('mcp-offer-claimant')
  local requests = {}
  claim_session_for(state, start_recording_editor(requests, true))
  local relay = start_relay_of(state, nil, TOKEN)

  send_report_and_wait(relay)

  eq({ #requests, requests[1][2], requests[1][3] }, { 1, SESSION_ID, { start_token = TOKEN } })
end

T['an offer']['to the claimant carries no options while the server knows no token'] = function()
  local state = case_state('mcp-offer-claimant-no-token')
  local requests = {}
  claim_session_for(state, start_recording_editor(requests, true))
  local relay = start_relay_of(state, nil, nil)

  send_report_and_wait(relay)

  eq({ #requests, #requests[1] }, { 1, 2 })
end

--- Lists the editor at `address` among the running editors under `state`,
--- as one following `session`, last used at `used`, in the tab `tab`.
---
---@param state { directory: string }
---@param address string
---@param session string
---@param used integer
---@param tab string?
local function list_editor(state, address, session, used, tab)
  mcp.write_editor_entry(state.directory, {
    address = address,
    working_directory = '/projects/alpha',
    session = session,
    own = true,
    used = used,
    tab = tab,
  })
end

T['an offer']['to a listed editor carries the start token as its options'] = function()
  local state = case_state('mcp-offer-listed')
  local requests = {}
  list_editor(state, start_recording_editor(requests, true), SESSION_ID, 1000)
  local relay = start_relay_of(state, nil, TOKEN)

  send_report_and_wait(relay)

  eq({ #requests, requests[1][2], requests[1][3] }, { 1, SESSION_ID, { start_token = TOKEN } })
end

T['an offer']['to a listed editor with two tabs on the session is made once'] = function()
  local state = case_state('mcp-offer-listed-two-tabs')
  local requests = {}
  local address = start_recording_editor(requests, false)
  list_editor(state, address, SESSION_ID, 1000, 'a')
  list_editor(state, address, SESSION_ID, 2000, 'b')
  local relay = start_relay_of(state, nil, TOKEN)

  send_report_and_wait(relay)

  eq(#requests, 1)
end

T['an offer']['to a listed editor whose tabs are on other sessions is not made'] = function()
  local state = case_state('mcp-offer-listed-other-tabs')
  local requests = {}
  local address = start_recording_editor(requests, true)
  list_editor(state, address, OTHER_SESSION_ID, 1000, 'a')
  list_editor(state, address, OTHER_SESSION_ID, 2000, 'b')
  local relay = start_relay_of(state, nil, TOKEN)

  send_report_and_wait(relay)

  eq(#requests, 0)
end

--- How many entries the list holds under `state`.
---
---@param state { directory: string }
---@return integer
local function listed_entry_count(state)
  local count = 0
  for _ in vim.fs.dir(vim.fs.joinpath(state.directory, 'aineo', 'editors')) do
    count = count + 1
  end
  return count
end

T['an offer']['to a listed editor that cannot be reached removes every tab’s entry of it'] = function()
  local state = case_state('mcp-offer-listed-gone')
  local gone = vim.fs.joinpath(state.home, 'gone.sock')
  list_editor(state, gone, SESSION_ID, 1000, 'a')
  list_editor(state, gone, SESSION_ID, 2000, 'b')
  local relay = start_relay_of(state, nil, TOKEN)

  send_report_and_wait(relay)

  eq(listed_entry_count(state), 0)
end

--- The tab of each entry of the editor at `address` the list holds under
--- `state`, sorted.
---
---@param state { directory: string }
---@param address string
---@return string[]
local function tabs_listed_for(state, address)
  local folder = vim.fs.joinpath(state.directory, 'aineo', 'editors')
  local tabs = {}
  for name in vim.fs.dir(folder) do
    local entry =
      vim.json.decode(table.concat(vim.fn.readfile(vim.fs.joinpath(folder, name)), '\n'))
    if entry.address == address then
      table.insert(tabs, entry.tab)
    end
  end
  table.sort(tabs)
  return tabs
end

--- Puts the file `file_name` into the list under `state`, an entry of the
--- editor at `address` on `SESSION_ID`, last used at `used`, in the tab
--- `tab` (none when nil), as an editor wrote it, without the pruning an
--- editor's own write makes. The folder `aineo/editors` under
--- `state.directory` exists already, so that a stand-in editor may call this
--- from a fast event.
---
---@param state { directory: string }
---@param file_name string
---@param address string
---@param used integer
---@param tab string?
local function plant_listed(state, file_name, address, used, tab)
  local folder = vim.fs.joinpath(state.directory, 'aineo', 'editors')
  local entry = vim.json.encode({
    address = address,
    working_directory = '/projects/alpha',
    session = SESSION_ID,
    own = true,
    used = used,
    tab = tab,
  })
  local file = assert(io.open(vim.fs.joinpath(folder, file_name), 'wb'))
  file:write(entry)
  file:close()
end

T['an offer']['to a listed editor that cannot be reached leaves an entry written since the list was read'] = function()
  local state = case_state('mcp-offer-listed-gone-rewritten')
  local gone = vim.fs.joinpath(state.home, 'gone.sock')
  vim.fn.mkdir(vim.fs.joinpath(state.directory, 'aineo', 'editors'), 'p')
  local declining = start_stand_in_editor(function(connection, request)
    plant_listed(state, 'late.json', gone, 500, 'new')
    connection:write(vim.mpack.encode({ RESPONSE, request[2], vim.NIL, false }))
  end)
  plant_listed(state, 'declining.json', declining, 3000)
  plant_listed(state, 'old.json', gone, 1000, 'old')
  local relay = start_relay_of(state, nil, TOKEN)

  send_report_and_wait(relay)

  eq(tabs_listed_for(state, gone), { 'new' })
end

T['an offer']['to a listed editor carries no options while the server knows no token'] = function()
  local state = case_state('mcp-offer-listed-no-token')
  local requests = {}
  list_editor(state, start_recording_editor(requests, true), SESSION_ID, 1000)
  local relay = start_relay_of(state, nil, nil)

  send_report_and_wait(relay)

  eq({ #requests, #requests[1] }, { 1, 2 })
end

return T
