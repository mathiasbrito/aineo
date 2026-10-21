local MiniTest = require('mini.test')
local mcp = require('aineo.mcp')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local mcp_messages = dofile('tests/helpers/mcp_messages.lua')
local mcp_relay = dofile('tests/helpers/mcp_relay.lua')

local eq = MiniTest.expect.equality
local get = vim.tbl_get
local decoded = mcp_relay.decoded

--- The commit each valid announcement says its branches were made from.
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

--- A valid announcement of the worktree `path` on the branch `feature/x`.
---
---@param path string
---@return table
local function work_in(path)
  return { worktree = path, label = 'T111', branches = { { name = 'feature/x', base = BASE } } }
end

T['announce_work']['is offered to the editor that started Claude Code, the work and the start token as the arguments of a constant chunk'] = function()
  local requests = {}
  local relay = relay_for(start_recording_editor(requests, true))
  local second = {
    worktree = '/projects/beta-wt',
    label = 'T112',
    branches = { { name = 'feature/y', base = 'HEAD' }, { name = 'feature/z', base = BASE } },
  }

  relay:send(announce(work_in('/projects/alpha-wt')))
  relay:next_line()
  relay:send(announce(second))
  relay:next_line()

  eq(
    vim.tbl_map(function(request)
      return request.arguments
    end, requests),
    { { work_in('/projects/alpha-wt'), TOKEN }, { second, TOKEN } }
  )
  eq(requests[1].lua, requests[2].lua)
  eq(requests[1].lua:find('alpha-wt', 1, true), nil)
end

--- `work_in('/w')` with `changes` laid over it, a JSON null removing nothing.
---
---@param changes table
---@return table
local function work_with(changes)
  return vim.tbl_extend('force', work_in('/w'), changes)
end

--- `work_in('/w')` without the field `field`.
---
---@param field string
---@return table
local function work_without(field)
  local work = work_in('/w')
  work[field] = nil
  return work
end

--- The branch `name` made from `BASE`.
---
---@param name string
---@return table
local function branch(name)
  return { name = name, base = BASE }
end

--- The branches `branch-1` to `branch-<count>`.
---
---@param count integer
---@return table[]
local function branches_up_to(count)
  local branches = {}
  for index = 1, count do
    branches[index] = branch('branch-' .. index)
  end
  return branches
end

T['announce_work']['whose arguments are refused is a tool error naming the field, and no editor is asked'] =
  MiniTest.new_set({
    parametrize = {
      { 42, 'arguments: expected an object' },
      { vim.NIL, 'arguments: expected an object' },
      { { 'worktree' }, 'arguments: expected an object' },
      { vim.empty_dict(), 'worktree: expected a non-empty string' },
      { work_without('worktree'), 'worktree: expected a non-empty string' },
      { work_with({ worktree = vim.NIL }), 'worktree: expected a non-empty string' },
      { work_with({ worktree = '' }), 'worktree: expected a non-empty string' },
      { work_with({ worktree = 42 }), 'worktree: expected a non-empty string' },
      { work_with({ worktree = '/' .. ('a'):rep(4096) }), 'worktree: longer than 4096 bytes' },
      { work_with({ worktree = '/w\r' }), 'worktree: holds a NUL or a line break' },
      { work_without('label'), 'label: expected a non-empty string' },
      { work_with({ label = vim.NIL }), 'label: expected a non-empty string' },
      { work_with({ label = '' }), 'label: expected a non-empty string' },
      { work_with({ label = 7 }), 'label: expected a non-empty string' },
      { work_with({ label = 'a\rb' }), 'label: holds a NUL or a line break' },
      { work_without('branches'), 'branches: expected an array' },
      { work_with({ branches = vim.NIL }), 'branches: expected an array' },
      { work_with({ branches = 'feature/x' }), 'branches: expected an array' },
      { work_with({ branches = { name = 'feature/x' } }), 'branches: expected an array' },
      { work_with({ branches = branches_up_to(33) }), 'branches: more than 32 items' },
      { work_with({ branches = { 'feature/x' } }), 'branches[1]: expected an object' },
      { work_with({ branches = { vim.NIL } }), 'branches[1]: expected an object' },
      {
        work_with({ branches = { branch('a'), { base = BASE } } }),
        'branches[2].name: expected a non-empty string',
      },
      {
        work_with({ branches = { { name = vim.NIL, base = BASE } } }),
        'branches[1].name: expected a non-empty string',
      },
      {
        work_with({ branches = { { name = 'a\0b', base = BASE } } }),
        'branches[1].name: holds a NUL or a line break',
      },
      {
        work_with({ branches = { { name = 'a' } } }),
        'branches[1].base: expected a non-empty string',
      },
      {
        work_with({ branches = { { name = 'a', base = '' } } }),
        'branches[1].base: expected a non-empty string',
      },
      {
        work_with({ branches = { { name = 'a', base = 'a\nb' } } }),
        'branches[1].base: holds a NUL or a line break',
      },
      {
        work_with({ branches = { branch('a'), branch('b'), branch('a') } }),
        'branches[3].name: listed at branches[1] already',
      },
      {
        work_with({ branches = { { name = 'a', base = BASE, kind = 'branch' } } }),
        'branches[1].kind: not a field of a branch',
      },
      { work_with({ note = 'x' }), 'note: not a field of the announcement' },
      { work_with({ kind = 'worktree' }), 'kind: not a field of the announcement' },
      { work_with({ path = '/w' }), 'path: not a field of the announcement' },
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

T['announce_work']['listing no branch is offered, as the agent is done with that worktree'] = function()
  local requests = {}
  local relay = relay_for(start_recording_editor(requests, true))

  relay:send(announce(work_with({ branches = {} })))

  eq(get(decoded(relay:next_line()), 'result'), result_of('ok', false))
  eq(requests[1].arguments[1], { worktree = '/w', label = 'T111', branches = {} })
end

T['announce_work']['listing 32 branches, and strings exactly 4096 bytes long, is offered'] = function()
  local requests = {}
  local relay = relay_for(start_recording_editor(requests, true))
  local path = '/' .. ('a'):rep(4095)
  local branches = branches_up_to(32)
  branches[1].name = ('b'):rep(4096)

  relay:send(announce({ worktree = path, label = ('l'):rep(4096), branches = branches }))

  eq(get(decoded(relay:next_line()), 'result'), result_of('ok', false))
  eq(requests[1].arguments[1], { worktree = path, label = ('l'):rep(4096), branches = branches })
end

T['announce_work']['offers each branch’s base and the label as the agent gave them'] = function()
  local requests = {}
  local relay = relay_for(start_recording_editor(requests, true))
  local work = {
    worktree = '/projects/alpha-wt',
    label = 'T111',
    branches = { { name = 'feature/x', base = 'HEAD~1' }, { name = 'feature/y', base = 'main' } },
  }

  relay:send(announce(work))
  relay:next_line()

  eq(requests[1].arguments[1], work)
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

  relay:send(announce(work_in(path)))
  relay:next_line()

  eq(requests[1].arguments[1], work_in(offered))
end

T['the words'] = MiniTest.new_set()

T['the words']['name the tool as Claude Code names it'] = function()
  local name = mcp.announce_tool_name()

  eq(name, 'mcp__aineo__announce_work')
end

T['the words']['appended to the system prompt are one paragraph of 478 bytes, the tool’s rule and a refusal corrected'] = function()
  local paragraph = mcp.announce_instructions()

  eq(
    paragraph,
    'Required for every agent and subagent: call `mcp__aineo__announce_work` once per worktree you work in,'
      .. ' right after you create the worktree or a branch in it, and again whenever the set of'
      .. " branches you are working on there changes, with the worktree's folder, a short label,"
      .. ' and every branch you are working on there with the commit it was created from.'
      .. ' It only informs aineo: if it refuses, correct the call as the refusal says and call again;'
      .. ' otherwise do not act on its reply.'
  )
  eq(#paragraph, 478)
end

T['the words']['for a subagent are the paragraph and one sentence, 654 bytes'] = function()
  local context = mcp.subagent_announce_context()

  eq(
    context,
    mcp.announce_instructions()
      .. ' If you started in a git worktree made for your task, call it once, now,'
      .. " with that worktree's folder, a short label, and the branch you are on"
      .. ' with the commit it was made from.'
  )
  eq(#context, 654)
end

T['in the editor'] = MiniTest.new_set()

T['in the editor']['an announcement reaches the handler aineo.mcp registered, which takes it'] = function()
  children.restart(editor)
  editor.lua([[require('aineo.mcp').on_work_announced(function(work, start_token)
    _G.announced = { work, start_token }
    return true
  end)]])
  local relay = relay_for(editor.job.address)

  relay:send(announce(work_in('/projects/alpha-wt')))

  eq(get(decoded(relay:next_line()), 'result'), result_of('ok', false))
  eq(editor.lua_get('_G.announced'), { work_in('/projects/alpha-wt'), TOKEN })
end

T['in the editor']['an announcement the handler declines is not taken'] = function()
  children.restart(editor)
  editor.lua([[require('aineo.mcp').on_work_announced(function()
    return false
  end)]])
  local relay = relay_for(editor.job.address)

  relay:send(announce(work_in('/projects/alpha-wt')))

  eq(get(decoded(relay:next_line()), 'result'), result_of('not taken', true))
end

T['in the editor']['an announcement the handler refuses is a tool error in the handler’s words'] = function()
  children.restart(editor)
  editor.lua([[require('aineo.mcp').on_work_announced(function()
    return 'base: "nowhere" names no commit'
  end)]])
  local relay = relay_for(editor.job.address)

  relay:send(announce(work_in('/projects/alpha-wt')))

  eq(
    get(decoded(relay:next_line()), 'result'),
    result_of('aineo refused the announcement: base: "nowhere" names no commit', true)
  )
end

T['in the editor']['an announcement with no handler registered is not taken'] = function()
  children.restart(editor)
  local relay = relay_for(editor.job.address)

  relay:send(announce(work_in('/projects/alpha-wt')))

  eq(get(decoded(relay:next_line()), 'result'), result_of('not taken', true))
end

T['in the editor']['an announcement to an aineo older than the relay is not taken'] = function()
  children.restart(editor)
  editor.lua([[require('aineo.mcp').receive_work_announcement = nil]])
  local relay = relay_for(editor.job.address)

  relay:send(announce(work_in('/projects/alpha-wt')))

  eq(get(decoded(relay:next_line()), 'result'), result_of('not taken', true))
end

T['announce_work']['taken by the editor is answered ok, nothing more'] = function()
  local relay = relay_for(start_recording_editor({}, true))

  relay:send(announce(work_in('/projects/alpha-wt')))

  local answer = decoded(relay:next_line())
  eq({ get(answer, 'id'), get(answer, 'result') }, { 7, result_of('ok', false) })
end

T['announce_work']['declined by the editor is a tool error, not taken, nothing more'] = function()
  local relay = relay_for(start_recording_editor({}, false))

  relay:send(announce(work_in('/projects/alpha-wt')))

  eq(get(decoded(relay:next_line()), 'result'), result_of('not taken', true))
end

T['announce_work']['with no start token is not taken, and no editor is asked'] = function()
  local requests = {}
  local relay = mcp_relay.start_relay({
    AINEO_EDITOR_ADDRESS = start_recording_editor(requests, true),
    AINEO_START_TOKEN = '',
  })

  relay:send(announce(work_in('/projects/alpha-wt')))

  eq(get(decoded(relay:next_line()), 'result'), result_of('not taken', true))
  eq(requests, {})
end

T['announce_work']['with no editor address is not taken'] = function()
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = '', AINEO_START_TOKEN = TOKEN })

  relay:send(announce(work_in('/projects/alpha-wt')))

  eq(get(decoded(relay:next_line()), 'result'), result_of('not taken', true))
end

T['announce_work']['for an editor that cannot be reached is not taken'] = function()
  local relay = relay_for(vim.fn.tempname() .. '.sock')

  relay:send(announce(work_in('/projects/alpha-wt')))

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

  relay:send(announce(work_in('/projects/alpha-wt')))

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

  relay:send(announce(work_in(path)))
  relay:send(announce(work_in('/projects/agent-wt')))

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

  relay:send(announce(work_in('/projects/alpha-wt')))

  eq(get(decoded(relay:next_line(10000)), 'result'), result_of('not taken', true))
end

return T
