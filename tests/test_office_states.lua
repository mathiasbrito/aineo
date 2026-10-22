local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local office_states = require('aineo.office_states')
local transcript = require('aineo.transcript')

local T = MiniTest.new_set()

--- A signal of `kind` from `agent`, with the fields `changes` add.
---
---@param kind string
---@param changes? table
---@return aineo.transcript.Signal
local function signal(kind, changes)
  return vim.tbl_extend('force', { agent = 'main', kind = kind }, changes or {})
end

--- A tracker that has taken `signals`, in order.
---
---@param signals aineo.transcript.Signal[]
---@return aineo.office_states.Tracker
local function tracker_that_took(signals)
  local tracker = office_states.new_tracker()
  for _, taken in ipairs(signals) do
    tracker.take(taken)
  end
  return tracker
end

--- The state of the agent `id` the tracker gives.
---
---@param tracker aineo.office_states.Tracker
---@param id string
---@return string|nil state
local function state_of(tracker, id)
  local agent = vim.iter(tracker.agents()):find(function(each)
    return each.id == id
  end)
  return agent and agent.state
end

T['the vocabulary'] = MiniTest.new_set()

T['the vocabulary']['names each state with the state it falls back to'] = function()
  local fallbacks = {}
  for _, state in ipairs(office_states.vocabulary()) do
    fallbacks[state.name] = state.fallback or false
  end

  eq(fallbacks, { standing = false, working = 'standing', resting = 'standing', idle = 'resting' })
end

T['the vocabulary']['gives the chain of states a state falls back through, the state first'] = function()
  eq(office_states.fallback_chain('idle'), { 'idle', 'resting', 'standing' })
  eq(office_states.fallback_chain('standing'), { 'standing' })
end

T['the vocabulary']['gives no chain for a name that is no state'] = function()
  eq(office_states.fallback_chain('dancing'), {})
end

T['a tracker'] = MiniTest.new_set()

T['a tracker']['has the main agent standing before it has taken a signal'] = function()
  local tracker = office_states.new_tracker()

  eq(tracker.agents(), { { id = 'main', state = 'standing' } })
end

T['a tracker']['has an agent working while a tool call runs'] = function()
  local tracker = tracker_that_took({ signal('tool_started', { call = 'a' }) })

  eq(state_of(tracker, 'main'), 'working')
end

T['a tracker']['has an agent standing once its tool call finished'] = function()
  local tracker = tracker_that_took({
    signal('tool_started', { call = 'a' }),
    signal('tool_finished', { call = 'a' }),
  })

  eq(state_of(tracker, 'main'), 'standing')
end

T['a tracker']['keeps an agent working while any of its calls runs'] = function()
  local tracker = tracker_that_took({
    signal('tool_started', { call = 'a' }),
    signal('tool_started', { call = 'b' }),
    signal('tool_finished', { call = 'a' }),
  })

  eq(state_of(tracker, 'main'), 'working')
end

T['a tracker']['ignores the result of a call it never saw start'] = function()
  local tracker = tracker_that_took({
    signal('tool_started', { call = 'a' }),
    signal('tool_finished', { call = 'never_started' }),
  })

  eq(state_of(tracker, 'main'), 'working')
end

T['a tracker']['has an agent idle when its turn ended'] = function()
  local tracker = tracker_that_took({
    signal('tool_started', { call = 'a' }),
    signal('tool_finished', { call = 'a' }),
    signal('turn_ended'),
  })

  eq(state_of(tracker, 'main'), 'idle')
end

T['a tracker']['has an agent idle when its turn ended though a call never finished'] = function()
  local tracker = tracker_that_took({
    signal('tool_started', { call = 'a' }),
    signal('turn_ended'),
  })

  eq(state_of(tracker, 'main'), 'idle')
end

T['a tracker']['has an agent working again when a call starts after its turn ended'] = function()
  local tracker = tracker_that_took({
    signal('turn_ended'),
    signal('tool_started', { call = 'b' }),
  })

  eq(state_of(tracker, 'main'), 'working')
end

T['a tracker']['has an agent standing, not idle, once a call that began after its turn ended finished'] = function()
  local tracker = tracker_that_took({
    signal('turn_ended'),
    signal('tool_started', { call = 'b' }),
    signal('tool_finished', { call = 'b' }),
  })

  eq(state_of(tracker, 'main'), 'standing')
end

T['a tracker']['counts a call without an id as a call'] = function()
  local tracker = tracker_that_took({ signal('tool_started') })

  eq(state_of(tracker, 'main'), 'working')
end

T['a tracker']['gives each agent a state of its own, the main agent first'] = function()
  local tracker = tracker_that_took({
    signal('tool_started', { agent = 'a0001', call = 'x' }),
  })

  eq(tracker.agents(), {
    { id = 'main', state = 'standing' },
    { id = 'a0001', state = 'working' },
  })
end

T['a tracker']['reaches the same state from replayed signals as from live ones'] = function()
  local replayed = tracker_that_took({
    signal('tool_started', { call = 'a', replayed = true }),
    signal('tool_finished', { call = 'a', replayed = true }),
    signal('turn_ended', { replayed = true }),
  })

  eq(state_of(replayed, 'main'), 'idle')
end

T['a tracker']['reads the signals of a recorded turn as a turn that ended'] = function()
  local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
  local tracker = office_states.new_tracker()
  for _, line in ipairs(fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl')) do
    for _, taken in ipairs(transcript.signals_of_line(line, 'main')) do
      tracker.take(taken)
    end
  end

  eq(state_of(tracker, 'main'), 'idle')
end

return T
