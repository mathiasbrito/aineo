local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local transcript = require('aineo.transcript')

local T = MiniTest.new_set()

--- The recorded turn's lines: the header, one line of a kind the office does
--- not read, the user's prompt, the `Bash` call, its result and the turn's
--- end.
local RECORDED_TURN = fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl')

--- The first line of the recorded turn that holds `needle`.
---
---@param needle string
---@return string line
local function recorded_line(needle)
  return vim.iter(RECORDED_TURN):find(function(line)
    return line:find(needle, 1, true) ~= nil
  end)
end

T['signals_of_line()'] = MiniTest.new_set()

T['signals_of_line()']['reads a tool call as a tool started'] = function()
  local line = recorded_line('"type": "tool_use"')

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, {
    {
      agent = 'main',
      kind = 'tool_started',
      tool = 'Bash',
      input = { command = 'grep -rn "TODO" /project', description = 'scrubbed' },
      call = 'toolu_fixture0002',
    },
  })
end

T['signals_of_line()']['reads a tool result as a tool finished'] = function()
  local line = recorded_line('"type": "tool_result"')

  local signals = transcript.signals_of_line(line, 'main')

  eq(
    signals,
    { { agent = 'main', kind = 'tool_finished', call = 'toolu_fixture0002', failed = false } }
  )
end

T['signals_of_line()']['reads a failed tool result as a failed tool finished'] = function()
  local line = vim.json.encode({
    type = 'user',
    message = {
      role = 'user',
      content = {
        { type = 'tool_result', tool_use_id = 'toolu_a', content = 'x', is_error = true },
      },
    },
  })

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, { { agent = 'main', kind = 'tool_finished', call = 'toolu_a', failed = true } })
end

T['signals_of_line()']['reads the end of a turn'] = function()
  local line = recorded_line('"subtype": "turn_duration"')

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, { { agent = 'main', kind = 'turn_ended' } })
end

T['signals_of_line()']['names the agent it is told the line belongs to'] = function()
  local line = recorded_line('"subtype": "turn_duration"')

  local signals = transcript.signals_of_line(line, 'a0000000000000001')

  eq(signals[1].agent, 'a0000000000000001')
end

T['signals_of_line()']['gives no signal for the lines the office does not read'] =
  MiniTest.new_set({
    parametrize = {
      { '"type": "fixture-header"' },
      { '"type": "mode"' },
      { '"type": "attachment"' },
      { '"subtype": "stop_hook_summary"' },
      { '"role": "user", "content": "scrubbed"' },
      { '"type": "text"' },
    },
  })

T['signals_of_line()']['gives no signal for the lines the office does not read']['line'] = function(
  needle
)
  local line = recorded_line(needle)

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, {})
end

T['signals_of_line()']['passes over a type it does not know'] = function()
  local signals = transcript.signals_of_line('{"type":"quantum-entanglement","x":1}', 'main')

  eq(signals, {})
end

T['signals_of_line()']['returns nothing and says why for a line that is not JSON'] = function()
  local signals, problem = transcript.signals_of_line('{"type": "assist', 'main')

  eq(signals, nil)
  eq(problem, 'not JSON')
end

T['signals_of_line()']['takes a null where it expected a value as an absent one'] =
  MiniTest.new_set({
    parametrize = {
      { '{"type":"assistant","message":null}' },
      { '{"type":"assistant","message":{"content":null}}' },
      { '{"type":"user","message":{"content":null}}' },
      { '{"type":"user","message":null}' },
      { '{"type":"system","subtype":null}' },
      { '{"type":null}' },
      { 'null' },
      { '[]' },
      { '"text"' },
      { '{"type":"assistant","message":{"content":[null,1,"a",[]]}}' },
    },
  })

T['signals_of_line()']['takes a null where it expected a value as an absent one']['line'] = function(
  line
)
  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, {})
end

T['signals_of_line()']['takes a null input, call and failure flag as absent'] = function()
  local started = transcript.signals_of_line(
    '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","id":null,"input":null}]}}',
    'main'
  )
  local finished = transcript.signals_of_line(
    '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":null,"is_error":null}]}}',
    'main'
  )

  eq(started, { { agent = 'main', kind = 'tool_started', tool = 'Bash', input = {} } })
  eq(finished, { { agent = 'main', kind = 'tool_finished', failed = false } })
end

T['signals_of_line()']['reads each of several blocks of one line'] = function()
  local line = vim.json.encode({
    type = 'assistant',
    message = {
      content = {
        { type = 'tool_use', id = 'a', name = 'Read', input = { file_path = '/p' } },
        { type = 'text', text = 'x' },
        { type = 'tool_use', id = 'b', name = 'Bash', input = { command = 'ls' } },
      },
    },
  })

  local signals = transcript.signals_of_line(line, 'main')

  eq(
    vim.tbl_map(function(signal)
      return signal.call
    end, signals),
    { 'a', 'b' }
  )
end

return T
