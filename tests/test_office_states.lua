local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local office_states = require('aineo.office_states')
local office_signals = dofile('tests/helpers/office_signals.lua')
local transcript = require('aineo.transcript')

local T = MiniTest.new_set()

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

  eq(tracker.agents(0), { { id = 'main', state = 'standing' } })
end

T['a tracker']['has an agent working while a call of a tool it does not class runs'] = function()
  local story = office_signals.tell()

  story.started('a', 'SendMessage')

  eq(story.state(), 'working')
end

T['a tracker']['has an agent working while a call without a tool name runs'] = function()
  local story = office_signals.tell()

  story.hear('tool_started', { call = 'a' })

  eq(story.state(), 'working')
end

T['a tracker']['has an agent thinking once its tool call finished, until the next call'] = function()
  local story = office_signals.tell()

  story.started('a', 'SendMessage')
  story.finished('a')

  eq(story.state(), 'thinking')
end

T['a tracker']['keeps an agent working while any of its calls runs'] = function()
  local story = office_signals.tell()

  story.started('a', 'SendMessage')
  story.started('b', 'SendMessage')
  story.finished('a')

  eq(story.state(), 'working')
end

T['a tracker']['ignores the result of a call it never saw start'] = function()
  local story = office_signals.tell()

  story.started('a', 'SendMessage')
  story.finished('never_started')

  eq(story.state(), 'working')
end

T['a tracker']['counts a call without an id as a call'] = function()
  local story = office_signals.tell()

  story.hear('tool_started', { tool = 'SendMessage' })

  eq(story.state(), 'working')
end

T['a tracker']['gives each agent a state of its own, the main agent first'] = function()
  local story = office_signals.tell()

  story.hear('tool_started', { agent = 'a0001', call = 'x', tool = 'SendMessage' })

  eq(story.state('main'), 'standing')
  eq(story.state('a0001'), 'working')
  eq(
    vim.tbl_map(function(agent)
      return agent.id
    end, story.agents_after(1.3)),
    { 'main', 'a0001' }
  )
end

T['a tracker']['says since when an agent has been in its state'] = function()
  local story = office_signals.tell()

  story.started('a', 'SendMessage')

  eq(story.agents_after(1.3)[1].since, office_signals.PAUSE)
end

T['a tracker']['refuses a signal heard at a time that is no number'] = function()
  local tracker = office_states.new_tracker()

  MiniTest.expect.error(function()
    tracker.take({ agent = 'main', kind = 'thinking' }, '12')
  end, 'now: expected number')
end

T['a tracker']['refuses a signal that names no agent'] = function()
  local tracker = office_states.new_tracker()

  MiniTest.expect.error(function()
    tracker.take({ kind = 'thinking' }, 1)
  end, 'signal.agent: expected string')
end

T['a tracker']['reads a recorded turn as a turn that ended, and left alone, as idle'] = function()
  local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
  local tracker = office_states.new_tracker()
  local second = 0
  for _, line in ipairs(fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl')) do
    for _, taken in ipairs(transcript.signals_of_line(line, 'main')) do
      second = second + 2
      tracker.take(taken, second)
    end
  end

  eq(tracker.agents(second + 60)[1].state, 'idle')
end

return T
