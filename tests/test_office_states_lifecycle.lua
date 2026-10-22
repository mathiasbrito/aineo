local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local office_signals = dofile('tests/helpers/office_signals.lua')

local T = MiniTest.new_set()

T['a prompt'] = MiniTest.new_set()

T['a prompt']['sends the main agent to get its task, then to think'] = function()
  local story = office_signals.tell()

  story.hear('prompt')

  eq(story.state_after(1.3), 'getting_a_task')
  eq(story.state_after(5), 'thinking')
end

T['a prompt']['sends the main agent to get a task each time the user gives one'] = function()
  local story = office_signals.tell()

  story.hear('prompt')
  story.hear_after(20, 'prompt')

  eq(story.state(), 'getting_a_task')
end

T['a prompt']['sends a subagent to get its task once, with its first prompt'] = function()
  local story = office_signals.tell()

  story.hear('prompt', { agent = 'a1' })
  eq(story.state('a1'), 'getting_a_task')

  story.hear_after(20, 'prompt', { agent = 'a1' })
  eq(story.state('a1'), 'thinking')
end

T['a prompt']['is taken by the agent that gave it alone'] = function()
  local story = office_signals.tell()

  story.hear('prompt', { agent = 'a1' })

  eq(story.state('main'), 'standing')
end

T['a thought'] = MiniTest.new_set()

T['a thought']['has the agent thinking'] = function()
  local story = office_signals.tell()

  story.hear('thinking')

  eq(story.state(), 'thinking')
end

T['a thought']['gives way to the next tool call'] = function()
  local story = office_signals.tell()

  story.hear('thinking')
  story.started('a', 'Read')

  eq(story.state(), 'reading')
end

T['the end of a turn'] = MiniTest.new_set()

T['the end of a turn']['has the agent done, then idle, then asleep after ten quiet minutes'] = function()
  local story = office_signals.tell()
  story.started('a', 'Read')
  story.finished('a')

  story.hear('turn_ended')

  eq(story.state_after(1.3), 'done')
  eq(story.state_after(30), 'idle')
  eq(story.state_after(4 + 599), 'idle')
  eq(story.state_after(4 + 601), 'asleep')
end

T['the end of a turn']['says since when the agent has been idle and asleep'] = function()
  local story = office_signals.tell()

  story.hear('turn_ended')

  eq(story.agents_after(30)[1].since, 2 + 4)
  eq(story.agents_after(4 + 601)[1].since, 2 + 4 + 600)
end

T['the end of a turn']['is over when a tool call starts'] = function()
  local story = office_signals.tell()
  story.hear('turn_ended')

  story.hear_after(2, 'tool_started', { call = 'b', tool = 'Read', input = {} })

  eq(story.state(), 'reading')
end

T['the end of a turn']['leaves no call running, however many were started'] = function()
  local story = office_signals.tell()
  story.started('a', 'Read')

  story.hear('turn_ended')

  eq(story.state_after(30), 'idle')
end

T['an interruption'] = MiniTest.new_set()

T['an interruption']['has the agent interrupted, then idle'] = function()
  local story = office_signals.tell()
  story.started('a', 'Read')

  story.hear('interrupted')

  eq(story.state_after(1.3), 'interrupted')
  eq(story.state_after(30), 'idle')
end

T['a failed result'] = MiniTest.new_set()

T['a failed result']['has the agent hit an error, then thinking'] = function()
  local story = office_signals.tell()
  story.started('a', 'Edit')

  story.finished('a', true)

  eq(story.state_after(1.3), 'error')
  eq(story.state_after(30), 'thinking')
end

T['a failed result']['is no error when a test run failed'] = function()
  local story = office_signals.tell({ commands = { tests = { 'make test' } } })
  story.started('a', 'Bash', { command = 'make test' })

  story.finished('a', true)

  eq(story.state(), 'thinking')
end

T['a failed result']['is no error when its call was never seen start'] = function()
  local story = office_signals.tell()

  story.finished('never_started', true)

  eq(story.state(), 'standing')
end

T['a result that succeeded'] = MiniTest.new_set()

T['a result that succeeded']['is no error'] = function()
  local story = office_signals.tell()
  story.started('a', 'Edit')

  story.finished('a', false)

  eq(story.state(), 'thinking')
end

T['compaction'] = MiniTest.new_set()

T['compaction']['has the agent compacting for a while, then back to what it was doing'] = function()
  local story = office_signals.tell()
  story.hear('thinking')

  story.hear('compacted')

  eq(story.state_after(1.3), 'compacting')
  eq(story.state_after(30), 'thinking')
end

T['a background job'] = MiniTest.new_set()

T['a background job']['keeps the agent on it after its call finished, until it is done'] = function()
  local story = office_signals.tell()
  story.started('a', 'Bash', { command = 'sleep 100', run_in_background = true })
  story.finished('a')

  eq(story.state(), 'background_job')

  story.hear('background_done')

  eq(story.state(), 'thinking')
end

T['a background job']['ends with the turn'] = function()
  local story = office_signals.tell()
  story.started('a', 'Bash', { command = 'sleep 100', run_in_background = true })
  story.finished('a')

  story.hear('turn_ended')

  eq(story.state_after(30), 'idle')
end

T['a background job']['is one of several when several run'] = function()
  local story = office_signals.tell()
  story.started('a', 'Bash', { command = 'sleep 1', run_in_background = true })
  story.finished('a')
  story.started('b', 'Bash', { command = 'sleep 2', run_in_background = true })
  story.finished('b')

  story.hear('background_done')

  eq(story.state(), 'background_job')
end

T['a background job']['that was never started changes nothing'] = function()
  local story = office_signals.tell()
  story.started('a', 'Read')
  story.finished('a')

  story.hear('background_done')

  eq(story.state(), 'thinking')
end

T['a replayed signal'] = MiniTest.new_set()

T['a replayed signal']['rebuilds a prompt as thinking, without the walk to get a task'] = function()
  local story = office_signals.tell()

  story.hear_replayed('prompt')

  eq(story.state(), 'thinking')
end

T['a replayed signal']['rebuilds a turn that ended as idle, without done'] = function()
  local story = office_signals.tell()

  story.hear_replayed('turn_ended')

  eq(story.state(), 'idle')
end

T['a replayed signal']['rebuilds a failed result as thinking, without the error'] = function()
  local story = office_signals.tell()
  story.hear_replayed('tool_started', { call = 'a', tool = 'Edit', input = {} })

  story.hear_replayed('tool_finished', { call = 'a', failed = true })

  eq(story.state(), 'thinking')
end

T['a replayed signal']['rebuilds an interruption as idle, without the jump'] = function()
  local story = office_signals.tell()

  story.hear_replayed('interrupted')

  eq(story.state(), 'idle')
end

T['a replayed signal']['rebuilds a compaction as nothing'] = function()
  local story = office_signals.tell()

  story.hear_replayed('compacted')

  eq(story.state(), 'standing')
end

T['a replayed signal']['shows at once, without the hold a live one has'] = function()
  local story = office_signals.tell()

  story.hear_replayed('tool_started', { call = 'a', tool = 'Read', input = {} })
  story.hear_replayed_after(0.1, 'tool_finished', { call = 'a' })

  eq(story.state_after(0), 'thinking')
end

return T
