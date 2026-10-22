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

--- The recorded session: sixteen turns of the main agent.
local RECORDED_SESSION = fake_transcript.lines_of('session-2.1.308.jsonl')

--- The first line of the recorded session that holds `needle`.
---
---@param needle string
---@return string line
local function session_line(needle)
  return vim.iter(RECORDED_SESSION):find(function(line)
    return line:find(needle, 1, true) ~= nil
  end)
end

--- The recorded subagent's lines: a read, and the answer that ends its turn.
local RECORDED_SUBAGENT = fake_transcript.lines_of('subagent-explore-2.1.308.jsonl')

--- A recorded subagent's id.
local SUBAGENT = 'a0000000000000001'

--- The line of the recorded subagent that ends its turn, and the one before
--- it, which carries the same stop reason on a block of thinking.
local SUBAGENT_ANSWER = RECORDED_SUBAGENT[#RECORDED_SUBAGENT]
local SUBAGENT_LAST_THOUGHT = RECORDED_SUBAGENT[#RECORDED_SUBAGENT - 1]

--- How many signals of each kind the lines of the recording `name` give when
--- they are the lines of `agent`, and how many of its lines are not JSON.
---
---@param name string
---@param agent string
---@return table<string, integer> counts
---@return integer unreadable
local function signals_by_kind_of(name, agent)
  local counts = {}
  local unreadable = 0
  for _, line in ipairs(fake_transcript.lines_of(name)) do
    local signals = transcript.signals_of_line(line, agent)
    unreadable = unreadable + (signals and 0 or 1)
    for _, signal in ipairs(signals or {}) do
      counts[signal.kind] = (counts[signal.kind] or 0) + 1
    end
  end
  return counts, unreadable
end

--- A line of the type `line_type` stamped `timestamp`, holding `message`.
---
---@param line_type string
---@param timestamp any
---@param message table
---@return string
local function stamped_line(line_type, timestamp, message)
  return vim.json.encode({ type = line_type, timestamp = timestamp, message = message })
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
      at = 1767225627 + 0.545,
    },
  })
end

T['signals_of_line()']['reads a tool result as a tool finished'] = function()
  local line = recorded_line('"type": "tool_result"')

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, {
    {
      agent = 'main',
      kind = 'tool_finished',
      call = 'toolu_fixture0002',
      failed = false,
      at = 1767225628 + 0.773,
    },
  })
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

T['signals_of_line()']["reads the user's prompt as a prompt"] = function()
  local line = recorded_line('"role": "user", "content": "scrubbed"')

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, { { agent = 'main', kind = 'prompt', at = 1767225625 + 0.946 } })
end

T['signals_of_line()']['gives no prompt for a text that is a notice or a bracketed message'] =
  MiniTest.new_set({
    parametrize = {
      { '<bash-input>ls</bash-input>' },
      { '<bash-stdout>x</bash-stdout>' },
      { '[Request interrupted by user]' },
      { '' },
    },
  })

T['signals_of_line()']['gives no prompt for a text that is a notice or a bracketed message']['text'] = function(
  text
)
  local line = vim.json.encode({ type = 'user', message = { role = 'user', content = text } })

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, {})
end

T['signals_of_line()']['gives no prompt for the summary a compaction leaves'] = function()
  local line = vim.json.encode({
    type = 'user',
    isCompactSummary = true,
    message = { role = 'user', content = 'This session is being continued' },
  })

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, {})
end

T['signals_of_line()']['reads the notice of a finished background task as a background done'] = function()
  local line = stamped_line('user', '2026-01-01T00:00:30Z', {
    role = 'user',
    content = '<task-notification><task-id>b1</task-id></task-notification>',
  })

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, { { agent = 'main', kind = 'background_done', at = 1767225630 } })
end

T['signals_of_line()']['reads a thinking block as thinking'] = function()
  local line = session_line('"type": "thinking"')

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, { { agent = 'main', kind = 'thinking', at = 1767225662 + 0.046 } })
end

T['signals_of_line()']["reads the user's interruption as interrupted"] = function()
  local line = session_line('[Request interrupted by user for tool use]')

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, { { agent = 'main', kind = 'interrupted', at = 1767226167 + 0.85 } })
end

T['signals_of_line()']['gives no signal for a text block of the user that is not an interruption'] = function()
  local line = stamped_line('user', '2026-01-01T00:00:30Z', {
    role = 'user',
    content = { { type = 'text', text = 'look at this' }, { type = 'text' } },
  })

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, {})
end

T['signals_of_line()']['reads the boundary a compaction writes as compacted'] = function()
  local line = vim.json.encode({
    type = 'system',
    subtype = 'compact_boundary',
    timestamp = '2026-01-01T00:00:30Z',
    compactMetadata = { trigger = 'auto', preTokens = 150000 },
  })

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, { { agent = 'main', kind = 'compacted', at = 1767225630 } })
end

T['signals_of_line()']['reads the answer that stops a subagent as the end of its turn'] = function()
  local signals = transcript.signals_of_line(SUBAGENT_ANSWER, SUBAGENT)

  eq(signals, { { agent = SUBAGENT, kind = 'turn_ended', at = 1767225698 + 0.973 } })
end

T['signals_of_line()']['gives no end of turn for a thought of a subagent that carries the stop reason'] = function()
  local signals = transcript.signals_of_line(SUBAGENT_LAST_THOUGHT, SUBAGENT)

  eq(
    vim.tbl_map(function(signal)
      return signal.kind
    end, signals),
    { 'thinking' }
  )
end

T['signals_of_line()']["leaves the end of the main agent's turn to the line that times it"] = function()
  local signals = transcript.signals_of_line(SUBAGENT_ANSWER, 'main')

  eq(signals, {})
end

T['signals_of_line()']['reads the end of a turn'] = function()
  local line = recorded_line('"subtype": "turn_duration"')

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, { { agent = 'main', kind = 'turn_ended', at = 1767225630 + 0.509 } })
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
      { '{"type":"user","message":{"content":[{"type":"text","text":null}]}}' },
      { '{"type":"user","message":{"content":[{"type":"text","text":5}]}}' },
      { '{"type":"user","message":{"content":""}}' },
      { '{"type":"system","subtype":["compact_boundary"]}' },
    },
  })

T['signals_of_line()']['takes a null where it expected a value as an absent one']['line'] = function(
  line
)
  local signals = transcript.signals_of_line(line, 'main')

  eq(signals, {})
end

T['signals_of_line()']["takes a null stop reason of a subagent's text as no end of turn"] = function()
  local signals = transcript.signals_of_line(
    '{"type":"assistant","message":{"stop_reason":null,"content":[{"type":"text"}]}}',
    SUBAGENT
  )

  eq(signals, {})
end

T['signals_of_line()']['takes a null compaction flag as no compaction'] = function()
  local signals = transcript.signals_of_line(
    '{"type":"user","isCompactSummary":null,"message":{"content":"go on"}}',
    'main'
  )

  eq(signals, { { agent = 'main', kind = 'prompt' } })
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

T['signals_of_line()']['takes a call id that is not a string as no id'] = function()
  local signals = transcript.signals_of_line(
    '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","id":5,"input":{}}]}}',
    'main'
  )

  eq(signals, { { agent = 'main', kind = 'tool_started', tool = 'Bash', input = {} } })
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

T['signals_of_line()']['gives a tool call the time of its line, in seconds since 1970'] = function()
  local line = stamped_line('assistant', '2026-01-01T00:00:30.5Z', {
    content = { { type = 'tool_use', id = 'a', name = 'Bash', input = {} } },
  })

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals[1].at, 1767225630.5)
end

T['signals_of_line()']['reads a time without a fraction on a leap day'] = function()
  local line = stamped_line('assistant', '2024-02-29T12:30:15Z', {
    content = { { type = 'tool_use', id = 'a', name = 'Bash', input = {} } },
  })

  local signals = transcript.signals_of_line(line, 'main')

  eq(signals[1].at, 1709209815)
end

T['signals_of_line()']['gives no time to a line whose timestamp is not an ISO time'] =
  MiniTest.new_set({
    parametrize = {
      { vim.NIL },
      { 5 },
      { 'garbage' },
      { '2026-01-01T00:00:30509Z' },
      { '2026-13-01T00:00:30Z' },
      { '2026-01-01T24:00:30Z' },
    },
  })

T['signals_of_line()']['gives no time to a line whose timestamp is not an ISO time']['line'] = function(
  timestamp
)
  local line = stamped_line('assistant', timestamp, {
    content = { { type = 'tool_use', id = 'a', name = 'Bash', input = {} } },
  })

  local signals = transcript.signals_of_line(line, 'main')

  eq(#signals, 1)
  eq(signals[1].at, nil)
end

T['the recordings'] = MiniTest.new_set({
  parametrize = {
    {
      'session-2.1.308.jsonl',
      'main',
      {
        interrupted = 1,
        prompt = 16,
        thinking = 10,
        tool_finished = 18,
        tool_started = 18,
        turn_ended = 16,
      },
    },
    {
      'subagent-explore-2.1.308.jsonl',
      SUBAGENT,
      { prompt = 1, thinking = 1, tool_finished = 1, tool_started = 1, turn_ended = 1 },
    },
  },
})

T['the recordings']['give every line a reading and the signals the agent did'] = function(
  recording,
  agent,
  signals_by_kind
)
  local kinds, unreadable = signals_by_kind_of(recording, agent)

  eq(unreadable, 0)
  eq(kinds, signals_by_kind)
end

return T
