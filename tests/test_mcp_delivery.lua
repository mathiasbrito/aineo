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
    "      ') os.exit(3) --",
    '      ' .. shell_line,
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

T['a report']['that the editor refuses is a tool error with its reason, without either Neovim’s framing'] =
  MiniTest.new_set({ parametrize = { { 'Lua: ' }, { 'Error executing lua: ' } } })

T['a report']['that the editor refuses is a tool error with its reason, without either Neovim’s framing']['framed as'] = function(
  framing
)
  local refusal = framing .. REFUSAL_REASON .. '\nstack traceback:\n\t[C]: in ?'
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
  local reason = 'the reason quotes Lua: and Error executing lua: in its own words'
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
--- name: the first line of the error, in each Neovim's words for an error
--- raised in a Lua callback.
local BUFFILEPRE_REASON = vim.fn.has('nvim-0.12') == 1
    and 'nvim_exec2()[1]..BufFilePre Autocommands for "*": Vim(append):Lua callback: [string "<nvim>"]:7: the user autocommand fails'
  or 'nvim_exec2()[1]..BufFilePre Autocommands for "*": Vim(append):Error executing lua callback: [string "<nvim>"]:7: the user autocommand fails'

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

return T
