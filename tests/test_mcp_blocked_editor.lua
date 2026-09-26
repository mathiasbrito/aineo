local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local mcp_messages = dofile('tests/helpers/mcp_messages.lua')
local mcp_relay = dofile('tests/helpers/mcp_relay.lua')
local report_tui = dofile('tests/helpers/report_tui.lua')

local eq = MiniTest.expect.equality
local get = vim.tbl_get
local decoded = mcp_relay.decoded

--- What the relay answers when the editor has not confirmed a report in time.
local NOT_CONFIRMED = 'aineo sent the report, but the editor did not confirm it within 5 s:'
  .. ' it may be waiting for the user, at a hit-enter prompt for one.'
  .. ' The report is sent, not confirmed; do not send it again.'

--- Starts a user's editor with a UI, its clock at 09:05, the state directory
--- `.tests/fixtures/<state>` and the working directory `/projects/alpha`.
---
---@param state string
---@return aineo.test.TuiEditor
local function start_editor(state)
  return report_tui.start({
    time = '2026-09-24T09:05:00',
    state_directory = fixture.directory(state),
    working_directory = '/projects/alpha',
  })
end

local T = MiniTest.new_set({
  hooks = {
    post_case = function()
      mcp_relay.stop_all()
      report_tui.stop_all()
    end,
  },
})

T['a user’s editor'] = MiniTest.new_set()

T['a user’s editor']['loads aineo’s report home as it starts'] = function()
  local editor
  MiniTest.expect.no_error(function()
    editor = start_editor('mcp-tui-loads')
  end)

  local loaded = vim.rpcrequest(
    editor.channel,
    'nvim_exec_lua',
    [[return package.loaded['aineo.report'] ~= nil]],
    {}
  )

  eq(loaded, true)
end

T['a user’s editor']['starts with no message, as in a terminal that answers its queries'] = function()
  local editor = start_editor('mcp-tui-messages')

  local messages = vim.rpcrequest(editor.channel, 'nvim_exec2', 'messages', { output = true })

  eq(messages.output, '')
end

T['a report that opens a Report with a warning'] = MiniTest.new_set()

T['a report that opens a Report with a warning']['is confirmed before the warning can hold the editor'] = function()
  local environment = {
    time = '2026-09-24T09:05:00',
    state_directory = fixture.directory('mcp-tui-warning'),
    working_directory = '/projects/alpha',
  }
  local first = report_tui.start(environment)
  local first_relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = first.address })
  first_relay:send(mcp_messages.recorded('tools/call'))
  first:report_lines({ '✓ 09:05 [done] Refactor the parser — All tests pass' })
  first:stop()
  local records = vim.fs.find(function()
    return true
  end, { path = environment.state_directory, type = 'file' })[1]
  vim.fn.writefile({ 'not JSON' }, records, 'a')
  local editor = report_tui.start(environment)
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = editor.address })

  relay:send(mcp_messages.recorded('tools/call'))

  eq(get(decoded(relay:next_line(4000)), 'result'), {
    isError = false,
    content = { { type = 'text', text = 'Delivered to the Agent Report.' } },
  })
end

T['a report for an editor at a hit-enter prompt'] = MiniTest.new_set()

T['a report for an editor at a hit-enter prompt']['is answered in time, the relay keeps serving, and the report shows once the user is done'] = function()
  local editor = start_editor('mcp-tui-state')
  editor:type(':echo "one\\ntwo\\nthree"\r')
  local waiting = editor:waits_at_hit_enter()
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = editor.address })

  relay:send(mcp_messages.recorded('tools/call'))
  local waited = relay:is_silent_for(500)
  relay:send('{"jsonrpc":"2.0","id":3,"method":"ping"}')
  local answers = relay:next_lines(2, 6000)
  editor:type('\r')

  eq({
    waiting,
    waited,
    get(decoded(answers[1]), 'id'),
    get(decoded(answers[1]), 'result'),
    get(decoded(answers[2]), 'id'),
  }, {
    true,
    true,
    2,
    { isError = false, content = { { type = 'text', text = NOT_CONFIRMED } } },
    3,
  })
  eq(
    editor:report_lines({ '✓ 09:05 [done] Refactor the parser — All tests pass' }),
    { '✓ 09:05 [done] Refactor the parser — All tests pass' }
  )
end

T['a report for an editor at a hit-enter prompt']['is a tool error at once when the editor dies before it answers'] = function()
  local editor = start_editor('mcp-tui-state')
  editor:type(':echo "one\\ntwo\\nthree"\r')
  local waiting = editor:waits_at_hit_enter()
  local relay = mcp_relay.start_relay({ AINEO_EDITOR_ADDRESS = editor.address })
  relay:send(mcp_messages.recorded('tools/call'))
  local unanswered = relay:is_silent_for(500)

  editor:kill()

  local result = get(decoded(relay:next_line(2000)), 'result')
  eq({ waiting, unanswered, result }, {
    true,
    true,
    {
      isError = true,
      content = {
        {
          type = 'text',
          text = ('the editor at %s closed the connection before it answered'):format(
            editor.address
          ),
        },
      },
    },
  })
end

return T
