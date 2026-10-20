local MiniTest = require('mini.test')
local mcp = require('aineo.mcp')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local mcp_messages = dofile('tests/helpers/mcp_messages.lua')
local mcp_relay = dofile('tests/helpers/mcp_relay.lua')

local eq = MiniTest.expect.equality
local get = vim.tbl_get
local decoded = mcp_relay.decoded

--- The commit each valid announcement says its work was made from.
local BASE = 'origin/dev'

--- The child Neovim a relay offers announcements to: the user's editor.
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
--- arguments, to `requests`, and answers it with `taken`.
---
---@param requests { lua: string, arguments: table }[]
---@param taken boolean
---@return string address
local function start_recording_editor(requests, taken)
  return start_stand_in_editor(function(connection, request)
    table.insert(requests, { lua = request[4][1], arguments = request[4][2] })
    connection:write(vim.mpack.encode({ RESPONSE, request[2], vim.NIL, taken }))
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

--- The `tools/call` line of `announce_work` with `arguments`, its id 7.
---
---@param arguments any
---@return string
local function announce(arguments)
  return mcp_messages.tools_call('announce_work', arguments, 7)
end

--- The `tools/call` result of one text item, a tool error when `is_error`.
---
---@param text string
---@param is_error boolean
---@return table
local function result_of(text, is_error)
  return { isError = is_error, content = { { type = 'text', text = text } } }
end

T['announce_work'] = MiniTest.new_set()

T['announce_work']['is offered to the editor that started Claude Code, the work and the start token as the arguments of a constant chunk'] = function()
  local requests = {}
  local relay = relay_for(start_recording_editor(requests, true))

  relay:send(announce({ kind = 'worktree', path = '/projects/alpha-wt', base = BASE }))
  relay:next_line()
  relay:send(announce({ kind = 'branch', branch = 'feature/x', base = BASE }))
  relay:next_line()

  eq(
    vim.tbl_map(function(request)
      return request.arguments
    end, requests),
    {
      { { kind = 'worktree', path = '/projects/alpha-wt', base = BASE }, TOKEN },
      { { kind = 'branch', branch = 'feature/x', base = BASE }, TOKEN },
    }
  )
  eq(requests[1].lua, requests[2].lua)
  eq(requests[1].lua:find('alpha-wt', 1, true), nil)
end

T['announce_work']['whose arguments are refused is a tool error naming the field, and no editor is asked'] =
  MiniTest.new_set({
    parametrize = {
      { 42, 'arguments: expected an object' },
      { vim.NIL, 'arguments: expected an object' },
      { { 'worktree' }, 'arguments: expected an object' },
      { vim.empty_dict(), 'kind: expected one of worktree, branch' },
      { { kind = vim.NIL, path = '/w' }, 'kind: expected one of worktree, branch' },
      { { kind = 'tree', path = '/w' }, 'kind: expected one of worktree, branch' },
      { { kind = 'worktree' }, 'path: expected a non-empty string' },
      { { kind = 'worktree', path = vim.NIL }, 'path: expected a non-empty string' },
      { { kind = 'worktree', path = '' }, 'path: expected a non-empty string' },
      { { kind = 'worktree', path = 42 }, 'path: expected a non-empty string' },
      { { kind = 'branch' }, 'branch: expected a non-empty string' },
      { { kind = 'branch', branch = vim.NIL }, 'branch: expected a non-empty string' },
      {
        { kind = 'worktree', path = '/w', branch = 'b', base = 'main' },
        'branch: not given with kind worktree',
      },
      {
        { kind = 'worktree', path = '/w', branch = vim.NIL, base = 'main' },
        'branch: not given with kind worktree',
      },
      {
        { kind = 'branch', branch = 'b', path = '/w', base = 'main' },
        'path: not given with kind branch',
      },
      { { kind = 'branch', branch = 'b' }, 'base: expected a non-empty string' },
      { { kind = 'worktree', path = '/w', base = vim.NIL }, 'base: expected a non-empty string' },
      { { kind = 'worktree', path = '/w', base = '' }, 'base: expected a non-empty string' },
      { { kind = 'branch', branch = 'b', base = 'a\nb' }, 'base: holds a NUL or a line break' },
      {
        { kind = 'branch', branch = 'b', base = 'main', note = 'x' },
        'note: not a field of the announcement',
      },
      { { kind = 'worktree', path = '/' .. ('a'):rep(4096) }, 'path: longer than 4096 bytes' },
      { { kind = 'branch', branch = 'a\0b' }, 'branch: holds a NUL or a line break' },
      { { kind = 'branch', branch = 'a\nb' }, 'branch: holds a NUL or a line break' },
      { { kind = 'worktree', path = '/w\r' }, 'path: holds a NUL or a line break' },
      {
        { kind = 'branch', branch = 'b', base = 'main', label = vim.NIL },
        'label: expected a non-empty string',
      },
      {
        { kind = 'branch', branch = 'b', base = 'main', label = '' },
        'label: expected a non-empty string',
      },
      {
        { kind = 'branch', branch = 'b', base = 'main', label = 7 },
        'label: expected a non-empty string',
      },
      {
        { kind = 'branch', branch = 'b', base = 'main', label = 'a\rb' },
        'label: holds a NUL or a line break',
      },
    },
  })

T['announce_work']['whose arguments are refused is a tool error naming the field, and no editor is asked']['given'] = function(
  arguments,
  refusal
)
  local requests = {}
  local relay = relay_for(start_recording_editor(requests, true))

  relay:send(announce(arguments))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of('aineo refused the announcement: ' .. refusal, true)
  )
  eq(requests, {})
end

T['announce_work']['whose string is exactly 4096 bytes long is offered'] = function()
  local requests = {}
  local relay = relay_for(start_recording_editor(requests, true))
  local path = '/' .. ('a'):rep(4095)

  relay:send(announce({ kind = 'worktree', path = path, base = BASE }))

  eq(get(decoded(relay:next_line()), 'result'), result_of('ok', false))
  eq(requests[1].arguments[1], { kind = 'worktree', path = path, base = BASE })
end

T['announce_work']['offers the base and the label as the agent gave them'] = function()
  local requests = {}
  local relay = relay_for(start_recording_editor(requests, true))

  relay:send(announce({ kind = 'branch', branch = 'feature/x', base = 'HEAD~1', label = 'T108' }))
  relay:next_line()

  eq(
    requests[1].arguments[1],
    { kind = 'branch', branch = 'feature/x', base = 'HEAD~1', label = 'T108' }
  )
end

T['announce_work']['offers a path made absolute against the relay’s working directory, and normalised'] =
  MiniTest.new_set({
    parametrize = {
      { 'sub/../agent-wt', vim.fs.joinpath(vim.uv.cwd(), 'agent-wt') },
      { '~/agent-wt', vim.fs.joinpath(vim.uv.cwd(), '~/agent-wt') },
      { '$HOME/agent-wt', vim.fs.joinpath(vim.uv.cwd(), '$HOME/agent-wt') },
      { '/projects/./alpha/../agent-wt/', '/projects/agent-wt' },
    },
  })

T['announce_work']['offers a path made absolute against the relay’s working directory, and normalised']['given'] = function(
  path,
  offered
)
  local requests = {}
  local relay = relay_for(start_recording_editor(requests, true))

  relay:send(announce({ kind = 'worktree', path = path, base = BASE }))
  relay:next_line()

  eq(requests[1].arguments[1], { kind = 'worktree', path = offered, base = BASE })
end

T['the words'] = MiniTest.new_set()

T['the words']['name the tool as Claude Code names it'] = function()
  local name = mcp.announce_tool_name()

  eq(name, 'mcp__aineo__announce_work')
end

T['the words']['appended to the system prompt are one paragraph of 351 bytes, the tool’s rule and a refusal corrected'] = function()
  local paragraph = mcp.announce_instructions()

  eq(
    paragraph,
    'Required for every agent and subagent: call `mcp__aineo__announce_work` once right after you create'
      .. ' a git branch or worktree for new work, with kind, its path or branch,'
      .. ' the base commit it was created from, and a short label.'
      .. ' It only informs aineo: if it refuses, correct the call as the refusal says and call again;'
      .. ' otherwise do not act on its reply.'
  )
  eq(#paragraph, 351)
end

T['the words']['for a subagent are the paragraph and one sentence, 482 bytes'] = function()
  local context = mcp.subagent_announce_context()

  eq(
    context,
    mcp.announce_instructions()
      .. ' If you started in a git worktree made for your task, call it once, now,'
      .. " with that worktree's path and the commit it was made from."
  )
  eq(#context, 482)
end

T['in the editor'] = MiniTest.new_set()

T['in the editor']['an announcement reaches the handler aineo.mcp registered, which takes it'] = function()
  children.restart(editor)
  editor.lua([[require('aineo.mcp').on_work_announced(function(work, start_token)
    _G.announced = { work, start_token }
    return true
  end)]])
  local relay = relay_for(editor.job.address)

  relay:send(announce({ kind = 'branch', branch = 'feature/x', base = BASE }))

  eq(get(decoded(relay:next_line()), 'result'), result_of('ok', false))
  eq(
    editor.lua_get('_G.announced'),
    { { kind = 'branch', branch = 'feature/x', base = BASE }, TOKEN }
  )
end

T['in the editor']['an announcement the handler declines is not taken'] = function()
  children.restart(editor)
  editor.lua([[require('aineo.mcp').on_work_announced(function()
    return false
  end)]])
  local relay = relay_for(editor.job.address)

  relay:send(announce({ kind = 'branch', branch = 'feature/x', base = BASE }))

  eq(get(decoded(relay:next_line()), 'result'), result_of('not taken', true))
end

T['in the editor']['an announcement the handler refuses is a tool error in the handler’s words'] = function()
  children.restart(editor)
  editor.lua([[require('aineo.mcp').on_work_announced(function()
    return 'base: "nowhere" names no commit'
  end)]])
  local relay = relay_for(editor.job.address)

  relay:send(announce({ kind = 'branch', branch = 'feature/x', base = 'nowhere' }))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of('aineo refused the announcement: base: "nowhere" names no commit', true)
  )
end

T['in the editor']['an announcement with no handler registered is not taken'] = function()
  children.restart(editor)
  local relay = relay_for(editor.job.address)

  relay:send(announce({ kind = 'branch', branch = 'feature/x', base = BASE }))

  eq(get(decoded(relay:next_line()), 'result'), result_of('not taken', true))
end

T['in the editor']['an announcement to an aineo older than the relay is not taken'] = function()
  children.restart(editor)
  editor.lua([[require('aineo.mcp').receive_work_announcement = nil]])
  local relay = relay_for(editor.job.address)

  relay:send(announce({ kind = 'branch', branch = 'feature/x', base = BASE }))

  eq(get(decoded(relay:next_line()), 'result'), result_of('not taken', true))
end

T['announce_work']['taken by the editor is answered ok, nothing more'] = function()
  local relay = relay_for(start_recording_editor({}, true))

  relay:send(announce({ kind = 'worktree', path = '/projects/alpha-wt', base = BASE }))

  local answer = decoded(relay:next_line())
  eq({ get(answer, 'id'), get(answer, 'result') }, { 7, result_of('ok', false) })
end

T['announce_work']['declined by the editor is a tool error, not taken, nothing more'] = function()
  local relay = relay_for(start_recording_editor({}, false))

  relay:send(announce({ kind = 'branch', branch = 'feature/x', base = BASE }))

  eq(get(decoded(relay:next_line()), 'result'), result_of('not taken', true))
end

T['announce_work']['with no start token is not taken, and no editor is asked'] = function()
  local requests = {}
  local relay = mcp_relay.start_relay({
    AINEO_EDITOR_ADDRESS = start_recording_editor(requests, true),
    AINEO_START_TOKEN = '',
  })

  relay:send(announce({ kind = 'branch', branch = 'feature/x', base = BASE }))

  eq(get(decoded(relay:next_line()), 'result'), result_of('not taken', true))
  eq(requests, {})
end

T['announce_work']['with no editor address is not taken'] = function()
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = '', AINEO_START_TOKEN = TOKEN })

  relay:send(announce({ kind = 'branch', branch = 'feature/x', base = BASE }))

  eq(get(decoded(relay:next_line()), 'result'), result_of('not taken', true))
end

T['announce_work']['for an editor that cannot be reached is not taken'] = function()
  local relay = relay_for(vim.fn.tempname() .. '.sock')

  relay:send(announce({ kind = 'branch', branch = 'feature/x', base = BASE }))

  eq(get(decoded(relay:next_line()), 'result'), result_of('not taken', true))
end

--- A session id of the form Claude Code gives.
local SESSION_ID = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'

T['announce_work']['declined by the starting editor is offered to no other, though another claims the session and would take it'] = function()
  local home = fixture.directory('mcp-announce-other-editor')
  local state = vim.fs.joinpath(home, 'nvim')
  local others = {}
  local other = start_recording_editor(others, true)
  mcp.claim_session(state, SESSION_ID, other, 5000)
  mcp.write_editor_entry(state, {
    address = other,
    working_directory = vim.uv.cwd(),
    session = SESSION_ID,
    own = true,
    used = 1000,
  })
  local relay = mcp_relay.start_relay({
    XDG_STATE_HOME = home,
    AINEO_EDITOR_ADDRESS = start_recording_editor({}, false),
    AINEO_START_TOKEN = TOKEN,
    CLAUDE_CODE_SESSION_ID = SESSION_ID,
  })

  relay:send(announce({ kind = 'branch', branch = 'feature/x', base = BASE }))

  eq(get(decoded(relay:next_line()), 'result'), result_of('not taken', true))
  eq(others, {})
end

--- A relay told the editor `address` and the start token `TOKEN`, started in
--- a directory removed once it is there, so that it cannot read its working
--- directory.
---
---@param address string
---@return aineo.test.Relay
local function relay_with_no_working_directory(address)
  local entry = mcp.mcp_servers('', vim.v.progpath).aineo
  local gone = vim.fs.joinpath(fixture.directory('mcp-announce-gone-cwd'), 'gone')
  return mcp_relay.start(
    vim.list_extend({
      'sh',
      '-c',
      'mkdir -p "$1" && cd "$1" && rmdir "$1" && shift && exec "$@"',
      'sh',
      gone,
      entry.command,
    }, entry.args),
    { AINEO_EDITOR_ADDRESS = address, AINEO_START_TOKEN = TOKEN }
  )
end

T['announce_work']['with a relative path is not taken, and no editor asked, when the relay has no working directory'] =
  MiniTest.new_set({
    parametrize = { { 'agent-wt' }, { '~/agent-wt' } },
  })

T['announce_work']['with a relative path is not taken, and no editor asked, when the relay has no working directory']['given'] = function(
  path
)
  local requests = {}
  local relay = relay_with_no_working_directory(start_recording_editor(requests, true))

  relay:send(announce({ kind = 'worktree', path = path, base = BASE }))
  relay:send(announce({ kind = 'worktree', path = '/projects/agent-wt', base = BASE }))

  eq(
    vim.tbl_map(function(line)
      return get(decoded(line), 'result')
    end, relay:next_lines(2)),
    { result_of('not taken', true), result_of('ok', false) }
  )
  eq(#requests, 1)
end

T['announce_work']['for an editor that does not answer in time is not taken, nothing more'] = function()
  local relay = relay_for(start_silent_editor())

  relay:send(announce({ kind = 'branch', branch = 'feature/x', base = BASE }))

  eq(get(decoded(relay:next_line(10000)), 'result'), result_of('not taken', true))
end

return T
