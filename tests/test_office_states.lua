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

--- The vocabulary as the plan lists it: each state's number (none for a
--- parent, which is no state of its own), name, label and fallback.
local VOCABULARY = {
  { name = 'standing', label = 'standing' },
  { name = 'working', label = 'working', fallback = 'standing' },
  { name = 'waiting', label = 'waiting', fallback = 'standing' },
  { name = 'resting', label = 'resting', fallback = 'standing' },
  { number = 1, name = 'arriving', label = 'arriving', fallback = 'standing' },
  { number = 2, name = 'getting_a_task', label = 'getting a task', fallback = 'thinking' },
  { number = 3, name = 'thinking', label = 'thinking', fallback = 'working' },
  { number = 4, name = 'planning', label = 'planning', fallback = 'thinking' },
  { number = 5, name = 'reading', label = 'reading', fallback = 'working' },
  { number = 6, name = 'searching', label = 'searching', fallback = 'reading' },
  { number = 7, name = 'writing_code', label = 'writing code', fallback = 'working' },
  {
    number = 8,
    name = 'running_a_command',
    label = 'running a command',
    fallback = 'writing_code',
  },
  { number = 9, name = 'running_tests', label = 'running tests', fallback = 'running_a_command' },
  {
    number = 10,
    name = 'background_job',
    label = 'running a background job',
    fallback = 'running_a_command',
  },
  { number = 11, name = 'on_the_web', label = 'on the web', fallback = 'reading' },
  { number = 12, name = 'delegating', label = 'delegating', fallback = 'working' },
  {
    number = 13,
    name = 'waiting_for_subagents',
    label = 'waiting for subagents',
    fallback = 'waiting',
  },
  { number = 14, name = 'needs_permission', label = 'needs permission', fallback = 'waiting' },
  { number = 15, name = 'asking_you', label = 'asking you', fallback = 'waiting' },
  { number = 16, name = 'reporting', label = 'reporting', fallback = 'working' },
  { number = 17, name = 'committing', label = 'committing', fallback = 'running_a_command' },
  { number = 18, name = 'compacting', label = 'compacting', fallback = 'working' },
  { number = 19, name = 'error', label = 'hit an error', fallback = 'standing' },
  { number = 20, name = 'interrupted', label = 'interrupted', fallback = 'error' },
  { number = 21, name = 'done', label = 'done', fallback = 'resting' },
  { number = 22, name = 'idle', label = 'idle', fallback = 'resting' },
  { number = 23, name = 'asleep', label = 'asleep', fallback = 'idle' },
  { number = 24, name = 'leaving', label = 'leaving', fallback = 'standing' },
}

T['the vocabulary']['lists the four parents and the 24 states with their labels and fallbacks'] = function()
  eq(office_states.vocabulary(), VOCABULARY)
end

T['the vocabulary']['gives a copy that editing leaves the vocabulary alone'] = function()
  office_states.vocabulary()[1].name = 'dancing'

  eq(office_states.vocabulary()[1].name, 'standing')
end

T['the vocabulary']['gives the chain of states a state falls back through, the state first'] = function()
  eq(office_states.fallback_chain('asleep'), { 'asleep', 'idle', 'resting', 'standing' })
  eq(office_states.fallback_chain('interrupted'), { 'interrupted', 'error', 'standing' })
  eq(office_states.fallback_chain('standing'), { 'standing' })
end

T['the vocabulary']['ends the chain of every state at standing'] = MiniTest.new_set({
  parametrize = vim.tbl_map(function(state)
    return { state.name }
  end, VOCABULARY),
})

T['the vocabulary']['ends the chain of every state at standing'][''] = function(name)
  local chain = office_states.fallback_chain(name)

  eq(chain[#chain], 'standing')
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
