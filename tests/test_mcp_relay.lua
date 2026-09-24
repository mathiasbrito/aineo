local MiniTest = require('mini.test')
local mcp_messages = dofile('tests/helpers/mcp_messages.lua')
local mcp_relay = dofile('tests/helpers/mcp_relay.lua')

local eq = MiniTest.expect.equality
local get = vim.tbl_get
local decoded = mcp_relay.decoded
local holds = mcp_relay.holds

--- The longest line the relay reads, in bytes, its newline not counted: 1 MiB.
local LINE_LIMIT = 1024 * 1024

local T = MiniTest.new_set({ hooks = { post_case = mcp_relay.stop_all } })

T['the relay'] = MiniTest.new_set()

T['the relay']['exits 0 when its input closes'] = function()
  local relay = mcp_relay.start_relay()
  relay:send('{"jsonrpc":"2.0","id":1,"method":"ping"}')
  relay:next_line()

  local exit = relay:close()

  eq({ exit.code, exit.signal }, { 0, 0 })
end

T['initialize'] = MiniTest.new_set()

T['initialize']['answers the recorded request with its protocol version, a tools object and the server'] = function()
  local relay = mcp_relay.start_relay()

  relay:send(mcp_messages.recorded('initialize'))

  local answer = relay:next_line()
  eq(holds(answer, '"tools":{}'), true)
  eq({
    get(decoded(answer), 'id'),
    get(decoded(answer), 'result', 'protocolVersion'),
    get(decoded(answer), 'result', 'serverInfo', 'name'),
  }, { 0, '2025-11-25', 'aineo' })
end

T['initialize']['answers a protocol version it does not speak with the one it speaks'] = function()
  local relay = mcp_relay.start_relay()
  local request = vim.json.decode(mcp_messages.recorded('initialize'))
  request.params.protocolVersion = '2024-11-05'

  relay:send(vim.json.encode(request))

  eq(get(decoded(relay:next_line()), 'result', 'protocolVersion'), '2025-11-25')
end

T['a notification'] = MiniTest.new_set()

T['a notification']['gets no answer'] = function()
  local relay = mcp_relay.start_relay()

  relay:send(mcp_messages.recorded('notifications/initialized'))
  relay:send('{"jsonrpc":"2.0","id":7,"method":"ping"}')

  eq(get(decoded(relay:next_line()), 'id'), 7)
end

T['ping'] = MiniTest.new_set()

T['ping']['is answered with an empty object'] = function()
  local relay = mcp_relay.start_relay()

  relay:send('{"jsonrpc":"2.0","id":"123","method":"ping"}')

  local answer = relay:next_line()
  eq({ get(decoded(answer), 'id'), holds(answer, '"result":{}') }, { '123', true })
end

T['a request'] = MiniTest.new_set()

T['a request']['is answered with its id unchanged'] = MiniTest.new_set({
  parametrize = { { '0' }, { '"request-7"' }, { '9007199254740991' }, { '-3' } },
})

T['a request']['is answered with its id unchanged']['for the id'] = function(id)
  local relay = mcp_relay.start_relay()

  relay:send(('{"jsonrpc":"2.0","id":%s,"method":"ping"}'):format(id))

  eq(holds(relay:next_line(), ('"id":%s'):format(id)), true)
end

T['tools/list'] = MiniTest.new_set()

T['tools/list']['lists one tool, report, whose input schema is the report format'] = function()
  local relay = mcp_relay.start_relay()

  relay:send(mcp_messages.recorded('tools/list'))

  local answer = decoded(relay:next_line())
  eq(get(answer, 'id'), 1)
  eq(get(answer, 'result', 'tools'), {
    {
      name = 'report',
      description = "Reports your work on a task to the user's Agent Report in Neovim.",
      inputSchema = {
        type = 'object',
        properties = {
          task = { type = 'string', minLength = 1 },
          status = {
            type = 'string',
            enum = { 'started', 'progress', 'blocked', 'done', 'failed' },
          },
          summary = { type = 'string', minLength = 1 },
          details = { type = 'string' },
        },
        required = { 'task', 'status', 'summary' },
        additionalProperties = false,
      },
    },
  })
end

T['tools/call'] = MiniTest.new_set()

T['tools/call']['of another tool is answered with error -32602'] = function()
  local relay = mcp_relay.start_relay()

  relay:send(mcp_messages.tools_call('ping', { note = 't2' }, 3))

  local answer = decoded(relay:next_line())
  eq({ get(answer, 'id'), get(answer, 'error', 'code'), get(answer, 'result') }, { 3, -32602, nil })
end

T['tools/call']['of a refused report is a tool error naming the field'] = function()
  local relay = mcp_relay.start_relay()

  relay:send(
    mcp_messages.tools_call(
      'report',
      { task = 'Task', status = 'finished', summary = 'Summary' },
      4
    )
  )

  local answer = decoded(relay:next_line())
  eq({ get(answer, 'id'), get(answer, 'result') }, {
    4,
    {
      isError = true,
      content = {
        {
          type = 'text',
          text = 'aineo refused the report: status: expected one of started, progress, blocked, done, failed',
        },
      },
    },
  })
end

T['tools/call']['whose params are no object names no tool, and is answered with error -32602'] =
  MiniTest.new_set({ parametrize = { { '42' }, { 'null' } } })

T['tools/call']['whose params are no object names no tool, and is answered with error -32602']['as'] = function(
  params
)
  local relay = mcp_relay.start_relay()

  relay:send(('{"jsonrpc":"2.0","id":6,"method":"tools/call","params":%s}'):format(params))

  local answer = decoded(relay:next_line())
  eq({ get(answer, 'id'), get(answer, 'error', 'code') }, { 6, -32602 })
end

T['a request for another method'] = MiniTest.new_set()

T['a request for another method']['is answered with error -32601'] = function()
  local relay = mcp_relay.start_relay()

  relay:send('{"jsonrpc":"2.0","id":5,"method":"resources/list"}')

  local answer = decoded(relay:next_line())
  eq({ get(answer, 'id'), get(answer, 'error', 'code'), get(answer, 'result') }, { 5, -32601, nil })
end

T['a line'] = MiniTest.new_set()

T['a line']['that is not JSON is answered with error -32700 and no id, and the relay keeps serving'] = function()
  local relay = mcp_relay.start_relay()

  relay:send('{"jsonrpc":"2.0","id":9,"method":')
  relay:send('{"jsonrpc":"2.0","id":8,"method":"ping"}')

  local answers = relay:next_lines(2)
  eq({
    get(decoded(answers[1]), 'error', 'code'),
    holds(answers[1], '"id"'),
    get(decoded(answers[2]), 'id'),
  }, { -32700, false, 8 })
end

T['a line']['that is JSON but no object is answered with error -32600 and no id'] =
  MiniTest.new_set({ parametrize = { { '42' }, { '"ping"' }, { '[1,2]' }, { 'null' } } })

T['a line']['that is JSON but no object is answered with error -32600 and no id']['as'] = function(
  line
)
  local relay = mcp_relay.start_relay()

  relay:send(line)
  relay:send('{"jsonrpc":"2.0","id":8,"method":"ping"}')

  local answers = relay:next_lines(2)
  eq({
    get(decoded(answers[1]), 'error', 'code'),
    holds(answers[1], '"id"'),
    get(decoded(answers[2]), 'id'),
  }, { -32600, false, 8 })
end

T['a line']['written in two parts is answered once, when its newline arrives'] = function()
  local relay = mcp_relay.start_relay()

  relay:write('{"jsonrpc":"2.0","id":11,')
  local silent = relay:is_silent_for(200)
  relay:write('"method":"ping"}\n')

  local answer = decoded(relay:next_line())
  eq({ silent, get(answer, 'id'), get(answer, 'error') }, { true, 11, nil })
end

T['a line']['split inside a multibyte character is answered whole'] = function()
  local relay = mcp_relay.start_relay()

  relay:write('{"jsonrpc":"2.0","id":"caf\195')
  local silent = relay:is_silent_for(200)
  relay:write('\169","method":"ping"}\n')

  eq({ silent, get(decoded(relay:next_line()), 'id') }, { true, 'café' })
end

T['a line']['that is empty gets no answer'] = function()
  local relay = mcp_relay.start_relay()

  relay:send('')
  relay:send('{"jsonrpc":"2.0","id":12,"method":"ping"}')

  eq(get(decoded(relay:next_line()), 'id'), 12)
end

T['a line']['longer than 1 MiB is refused with error -32600 and no id, before its newline arrives'] = function()
  local relay = mcp_relay.start_relay()

  relay:write(('x'):rep(LINE_LIMIT + 1))

  local answer = relay:next_line()
  eq({ get(decoded(answer), 'error', 'code'), holds(answer, '"id"') }, { -32600, false })
end

T['a line']['longer than 1 MiB is dropped up to its newline, and the next message answered'] = function()
  local relay = mcp_relay.start_relay()
  relay:write(('x'):rep(LINE_LIMIT + 1))
  relay:next_line()

  relay:write('the rest of the long line\n')
  relay:send('{"jsonrpc":"2.0","id":14,"method":"ping"}')

  eq(get(decoded(relay:next_line()), 'id'), 14)
end

T['a line']['of exactly 1 MiB is read and answered'] = function()
  local relay = mcp_relay.start_relay()
  local head, tail = '{"jsonrpc":"2.0","id":13,"method":"ping","params":{"padding":"', '"}}'
  local line = head .. ('x'):rep(LINE_LIMIT - #head - #tail) .. tail

  relay:send(line)

  local answer = decoded(relay:next_line())
  eq({ #line, get(answer, 'id'), get(answer, 'error') }, { LINE_LIMIT, 13, nil })
end

return T
