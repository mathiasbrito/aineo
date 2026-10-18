local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local mcp_messages = dofile('tests/helpers/mcp_messages.lua')
local mcp_relay = dofile('tests/helpers/mcp_relay.lua')

local eq = MiniTest.expect.equality
local get = vim.tbl_get
local decoded = mcp_relay.decoded

--- The child Neovim a relay offers calls to: the user's editor.
local editor = MiniTest.new_child_neovim()

--- The start token the relay is told in each case.
local TOKEN = 'start-token-1'

--- The sockets of the stand-in editors, closed after each case.
---@type uv.uv_pipe_t[]
local stand_in_handles = {}

--- The msgpack-RPC message types a stand-in editor reads and writes (`:h rpc`).
local REQUEST, RESPONSE = 0, 1

--- Listens at a new socket path in place of the user's editor, and hands
--- each msgpack-RPC request it receives there to `answer`, with the
--- connection to write to; any other message is ignored.
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

--- A stand-in editor that appends each request it receives, its Lua and its
--- arguments, to `requests`, and answers it with `result`.
---
---@param requests { lua: string, arguments: table }[]
---@param result any
---@return string address
local function start_recording_editor(requests, result)
  return start_stand_in_editor(function(connection, request)
    table.insert(requests, { lua = request[4][1], arguments = request[4][2] })
    connection:write(vim.mpack.encode({ RESPONSE, request[2], vim.NIL, result }))
  end)
end

--- A stand-in editor that answers each request with the error `reason`.
---
---@param reason string
---@return string address
local function start_raising_editor(reason)
  return start_stand_in_editor(function(connection, request)
    connection:write(vim.mpack.encode({ RESPONSE, request[2], { 0, reason }, vim.NIL }))
  end)
end

--- A stand-in editor that never answers what it receives.
---
---@return string address
local function start_silent_editor()
  return start_stand_in_editor(function() end)
end

--- Closes every socket a stand-in editor opened.
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

--- A relay told the editor `address` and the start token `TOKEN`.
---
---@param address string
---@return aineo.test.Relay
local function relay_for(address)
  return mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = address, AINEO_START_TOKEN = TOKEN })
end

--- The `tools/call` line of the tool `name` with `arguments`, its id 7.
---
---@param name string
---@param arguments any
---@return string
local function call(name, arguments)
  return mcp_messages.tools_call(name, arguments, 7)
end

--- The `tools/call` result of one text item, a tool error when `is_error`.
---
---@param text string
---@param is_error boolean
---@return table
local function result_of(text, is_error)
  return { isError = is_error, content = { { type = 'text', text = text } } }
end

--- What the relay answers for a call no tab took.
local NOT_TAKEN = 'not taken: no tab of the editor runs the Claude Code that made the call'

--- The tools of the answer to `tools/list`, by name.
---
---@return table<string, table>
local function listed_tools()
  local relay = mcp_relay.start_relay()
  relay:send(mcp_messages.recorded('tools/list'))
  local by_name = {}
  for _, tool in ipairs(get(decoded(relay:next_line()), 'result', 'tools')) do
    by_name[tool.name] = tool
  end
  return by_name
end

T['tools/list'] = MiniTest.new_set()

T['tools/list']['lists the three run tools after report and announce_work'] = function()
  local relay = mcp_relay.start_relay()

  relay:send(mcp_messages.recorded('tools/list'))

  eq(
    vim.tbl_map(function(tool)
      return tool.name
    end, get(decoded(relay:next_line()), 'result', 'tools')),
    { 'report', 'announce_work', 'run', 'run_output', 'run_stop' }
  )
end

T['tools/list']['says run and run_stop are for what the user explicitly asks, and run_output is not'] = function()
  local tools = listed_tools()

  eq(tools.run.description:find('only when the user explicitly asks', 1, true) ~= nil, true)
  eq(tools.run_stop.description:find('only when the user explicitly asks', 1, true) ~= nil, true)
  eq(tools.run_output.description:find('explicitly asks', 1, true), nil)
end

T['tools/list']['teaches run_output to filter first, and documents the Vim regex it takes'] =
  MiniTest.new_set({
    parametrize = {
      { 'Filter first' },
      { 'error|warn' },
      { '(GET|POST) /api' },
      { '\\d{3}' },
      { '(x)@=' },
      { 'ignore_case' },
      { 'after_line' },
    },
  })

T['tools/list']['teaches run_output to filter first, and documents the Vim regex it takes']['given'] = function(
  taught
)
  local description = listed_tools().run_output.description

  eq(description:find(taught, 1, true) ~= nil, true)
end

T['tools/list']['describes the arguments of each run tool as an object with no other property'] = function()
  local tools = listed_tools()

  eq(tools.run.inputSchema, {
    type = 'object',
    properties = {
      command = { type = 'string', minLength = 1 },
      name = { type = 'string', minLength = 1 },
      directory = { type = 'string', minLength = 1 },
    },
    required = { 'command' },
    additionalProperties = false,
  })
  eq(tools.run_stop.inputSchema, {
    type = 'object',
    properties = { name = { type = 'string', minLength = 1 } },
    required = { 'name' },
    additionalProperties = false,
  })
  eq(tools.run_output.inputSchema.properties, {
    name = { type = 'string', minLength = 1 },
    pattern = { type = 'string' },
    exclude = { type = 'string' },
    ignore_case = { type = 'boolean' },
    last = { type = 'integer', minimum = 1 },
    after_line = { type = 'integer', minimum = 0 },
    context = { type = 'integer', minimum = 0 },
  })
  eq(tools.run_output.inputSchema.required, { 'name' })
  eq(tools.run_output.inputSchema.additionalProperties, false)
end

T['a call'] = MiniTest.new_set()

T['a call']['whose arguments are refused is a tool error naming the field, and no editor is asked'] =
  MiniTest.new_set({
    parametrize = {
      { 'run', 42, 'arguments: expected an object' },
      { 'run', vim.NIL, 'arguments: expected an object' },
      { 'run', { 'ls' }, 'arguments: expected an object' },
      { 'run', vim.empty_dict(), 'command: expected a non-empty string' },
      { 'run', { command = '' }, 'command: expected a non-empty string' },
      { 'run', { command = 5 }, 'command: expected a non-empty string' },
      { 'run', { command = vim.NIL }, 'command: expected a non-empty string' },
      { 'run', { command = 'ls', name = '' }, 'name: expected a non-empty string' },
      { 'run', { command = 'ls', name = 5 }, 'name: expected a non-empty string' },
      { 'run', { command = 'ls', name = 'a\nb' }, 'name: holds a control character' },
      { 'run', { command = 'ls', directory = '' }, 'directory: expected a non-empty string' },
      { 'run', { command = 'ls', directory = 'a\27b' }, 'directory: holds a control character' },
      { 'run', { command = 'a\0b' }, 'command: holds a NUL' },
      { 'run', { command = ('a'):rep(16385) }, 'command: longer than 16384 bytes' },
      { 'run', { command = 'ls', name = ('a'):rep(4097) }, 'name: longer than 4096 bytes' },
      { 'run', { command = 'ls', cwd = '/' }, 'cwd: not a field of run' },
      { 'run_output', vim.empty_dict(), 'name: expected a non-empty string' },
      { 'run_output', { name = 'x', pattern = 5 }, 'pattern: expected a string' },
      { 'run_output', { name = 'x', exclude = true }, 'exclude: expected a string' },
      {
        'run_output',
        { name = 'x', pattern = ('a'):rep(4097) },
        'pattern: longer than 4096 bytes',
      },
      { 'run_output', { name = 'x', pattern = 'a\0b' }, 'pattern: holds a NUL' },
      { 'run_output', { name = 'x', ignore_case = 'yes' }, 'ignore_case: expected true or false' },
      { 'run_output', { name = 'x', last = 0 }, 'last: expected an integer of at least 1' },
      { 'run_output', { name = 'x', last = 1.5 }, 'last: expected an integer of at least 1' },
      { 'run_output', { name = 'x', last = '5' }, 'last: expected an integer of at least 1' },
      {
        'run_output',
        { name = 'x', after_line = -1 },
        'after_line: expected an integer of at least 0',
      },
      { 'run_output', { name = 'x', context = -1 }, 'context: expected an integer of at least 0' },
      { 'run_output', { name = 'x', limit = 5 }, 'limit: not a field of run_output' },
      { 'run_stop', vim.empty_dict(), 'name: expected a non-empty string' },
      { 'run_stop', { name = 'x', force = true }, 'force: not a field of run_stop' },
    },
  })

T['a call']['whose arguments are refused is a tool error naming the field, and no editor is asked']['given'] = function(
  tool,
  arguments,
  refusal
)
  local requests = {}
  local relay = relay_for(start_recording_editor(requests, { text = 'ok', is_error = false }))

  relay:send(call(tool, arguments))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of('aineo refused the call: ' .. refusal, true)
  )
  eq(requests, {})
end

--- What an editor that took a call answers: the words for Claude, and
--- whether they are an error.
---
---@param text string
---@param is_error boolean
---@return table
local function answer_of(text, is_error)
  return { text = text, is_error = is_error }
end

T['a valid call'] = MiniTest.new_set()

T['a valid call']['is offered to the editor that started Claude Code, the tool, its given arguments and the start token as the arguments of a constant chunk'] = function()
  local requests = {}
  local relay = relay_for(start_recording_editor(requests, answer_of('ok', false)))

  relay:send(call('run', { command = 'npm start', name = vim.NIL }))
  relay:next_line()
  relay:send(call('run_output', { name = 'npm', last = 5, ignore_case = false }))
  relay:next_line()

  eq(
    vim.tbl_map(function(request)
      return request.arguments
    end, requests),
    {
      { { tool = 'run', arguments = { command = 'npm start' } }, TOKEN },
      {
        { tool = 'run_output', arguments = { name = 'npm', last = 5, ignore_case = false } },
        TOKEN,
      },
    }
  )
  eq(requests[1].lua, requests[2].lua)
  eq(requests[1].lua:find('npm', 1, true), nil)
end

T['a valid call']['is answered with the words the editor gives, an error or not'] =
  MiniTest.new_set({
    parametrize = {
      { answer_of('started npm in the run pane', false) },
      { answer_of('no process called npm', true) },
    },
  })

T['a valid call']['is answered with the words the editor gives, an error or not']['given'] = function(
  answer
)
  local relay = relay_for(start_recording_editor({}, answer))

  relay:send(call('run_stop', { name = 'npm' }))

  eq(get(decoded(relay:next_line()), 'result'), result_of(answer.text, answer.is_error))
end

T['a valid call']['declined by the editor is a tool error, not taken, saying why'] = function()
  local relay = relay_for(start_recording_editor({}, false))

  relay:send(call('run', { command = 'ls' }))

  eq(get(decoded(relay:next_line()), 'result'), result_of(NOT_TAKEN, true))
end

T['a valid call']['with no start token is not taken, and no editor is asked'] = function()
  local requests = {}
  local relay = mcp_relay.start_relay({
    AINEO_EDITOR_ADDRESS = start_recording_editor(requests, answer_of('ok', false)),
    AINEO_START_TOKEN = '',
  })

  relay:send(call('run', { command = 'ls' }))

  eq(get(decoded(relay:next_line()), 'result'), result_of(NOT_TAKEN, true))
  eq(requests, {})
end

T['a valid call']['with no editor address is not taken'] = function()
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = '', AINEO_START_TOKEN = TOKEN })

  relay:send(call('run', { command = 'ls' }))

  eq(get(decoded(relay:next_line()), 'result'), result_of(NOT_TAKEN, true))
end

T['a valid call']['to an editor that cannot be reached is a tool error saying so'] = function()
  local address = vim.fn.tempname() .. '.sock'
  local relay = relay_for(address)

  relay:send(call('run', { command = 'ls' }))

  local result = get(decoded(relay:next_line()), 'result')
  eq(result.isError, true)
  eq(result.content[1].text:find('aineo could not reach the editor at ' .. address, 1, true), 1)
end

T['a valid call']['that the editor refuses is a tool error with its reason, saying call and not report'] = function()
  local relay = relay_for(start_raising_editor('Lua: boom'))

  relay:send(call('run', { command = 'ls' }))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of('the editor did not take the call: boom', true)
  )
end

T['a valid call']['that the editor does not answer in time is a tool error that says it may still run'] = function()
  local relay = relay_for(start_silent_editor())

  relay:send(call('run', { command = 'ls' }))

  local result = get(decoded(relay:next_line(10000)), 'result')
  eq(result.isError, true)
  eq(
    result.content[1].text,
    'aineo sent the call, but the editor did not confirm it within 5 s:'
      .. ' it may be waiting for the user, at a hit-enter prompt for one.'
      .. ' The call is sent, not confirmed; do not send it again.'
  )
end

T['a valid call']['that the editor answers with something that is no answer is a tool error'] = function()
  local relay = relay_for(start_recording_editor({}, 'fine'))

  relay:send(call('run', { command = 'ls' }))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of('the editor answered the call with something aineo cannot read', true)
  )
end

T['in the editor'] = MiniTest.new_set()

T['in the editor']['a call reaches the handler aineo.mcp registered, whose words answer Claude'] = function()
  children.restart(editor)
  editor.lua([[require('aineo.mcp').on_run_called(function(run_call, start_token)
    _G.called = { run_call, start_token }
    return { text = 'started npm', is_error = false }
  end)]])
  local relay = relay_for(editor.job.address)

  relay:send(call('run', { command = 'npm start' }))

  eq(get(decoded(relay:next_line()), 'result'), result_of('started npm', false))
  eq(
    editor.lua_get('_G.called'),
    { { tool = 'run', arguments = { command = 'npm start' } }, TOKEN }
  )
end

T['in the editor']['a call the handler declines is not taken'] = function()
  children.restart(editor)
  editor.lua([[require('aineo.mcp').on_run_called(function()
    return false
  end)]])
  local relay = relay_for(editor.job.address)

  relay:send(call('run', { command = 'npm start' }))

  eq(get(decoded(relay:next_line()), 'result'), result_of(NOT_TAKEN, true))
end

T['in the editor']['a call with no handler registered is not taken'] = function()
  children.restart(editor)
  local relay = relay_for(editor.job.address)

  relay:send(call('run', { command = 'npm start' }))

  eq(get(decoded(relay:next_line()), 'result'), result_of(NOT_TAKEN, true))
end

T['in the editor']['a call to an aineo older than the relay is refused, saying the editor did not take the call'] = function()
  children.restart(editor)
  editor.lua([[require('aineo.mcp').receive_run_call = nil]])
  local relay = relay_for(editor.job.address)

  relay:send(call('run', { command = 'npm start' }))

  local result = get(decoded(relay:next_line()), 'result')
  eq(result.isError, true)
  eq(result.content[1].text:find('the editor did not take the call: ', 1, true), 1)
end

return T
