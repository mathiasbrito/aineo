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

local T = MiniTest.new_set({
  hooks = { post_case = mcp_relay.stop_all, post_once = editor.stop },
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

T['a report']['that the editor does not take is a tool error with the reason it gave'] = function()
  children.restart(editor)
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = editor.job.address })

  relay:send(mcp_messages.recorded('tools/call'))

  eq(get(decoded(relay:next_line()), 'result'), {
    isError = true,
    content = {
      {
        type = 'text',
        text = 'the editor did not take the report: Error executing lua: aineo.report has no environment: call set_report_environment() first',
      },
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
