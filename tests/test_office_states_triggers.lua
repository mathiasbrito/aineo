local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local office_signals = dofile('tests/helpers/office_signals.lua')

local T = MiniTest.new_set()

--- The activity the agent plays while it runs the Bash command `command`, in
--- an office told of `triggers`.
---
---@param triggers table[]
---@param command string
---@return string|nil activity
local function activity_while_running(triggers, command)
  local story = office_signals.tell({ triggers = triggers })
  story.started('a', 'Bash', { command = command })
  return story.activity()
end

T['a trigger'] = MiniTest.new_set()

T['a trigger']['names the activity the agent plays while a call it matches runs'] = function()
  local triggers = { { when = { tool = 'Bash', command = 'docker' }, play = 'tend_the_rack' } }

  eq(activity_while_running(triggers, 'sudo docker compose up'), 'tend_the_rack')
end

T['a trigger']['leaves the state the call gives as it is'] = function()
  local story = office_signals.tell({
    triggers = { { when = { tool = 'Bash', command = 'docker' }, play = 'tend_the_rack' } },
  })

  story.started('a', 'Bash', { command = 'docker ps' })

  eq(story.state(), 'running_a_command')
end

T['a trigger']['names no activity once the call finished'] = function()
  local story = office_signals.tell({
    triggers = { { when = { tool = 'Read' }, play = 'look_closely' } },
  })
  story.started('a', 'Read')
  story.finished('a')

  eq(story.activity(), nil)
end

T['a trigger']['names no activity for a call it does not match'] = function()
  local triggers = { { when = { tool = 'Bash', command = 'docker' }, play = 'tend_the_rack' } }

  eq(activity_while_running(triggers, 'dockerfile lint'), nil)
end

T['a trigger']['needs every field of its when to match'] = function()
  local triggers = { { when = { tool = 'Edit', command = 'docker' }, play = 'tend_the_rack' } }

  eq(activity_while_running(triggers, 'docker ps'), nil)
end

T['a trigger']['does not match a call that has no such field'] = function()
  local triggers = { { when = { tool = 'Bash', file_path = '*.md' }, play = 'write_notes' } }

  eq(activity_while_running(triggers, 'docker ps'), nil)
end

T['a trigger']['names the activity of the first trigger that matches, in order'] = function()
  local triggers = {
    { when = { tool = 'Bash', command = 'make' }, play = 'first' },
    { when = { tool = 'Bash', command = 'make test' }, play = 'second' },
  }

  eq(activity_while_running(triggers, 'make test'), 'first')
end

T['a trigger']['is tried for a call whose state the office classes too'] = function()
  local story = office_signals.tell({
    commands = { tests = { 'make test' } },
    triggers = { { when = { tool = 'Bash', command = 'make test' }, play = 'sweat' } },
  })

  story.started('a', 'Bash', { command = 'make test' })

  eq(story.state(), 'running_tests')
  eq(story.activity(), 'sweat')
end

T['a trigger']["matches a glob and a Lua pattern on the call's fields"] = function()
  local story = office_signals.tell({
    triggers = {
      { when = { tool = 'Edit', file_path = '*.md' }, play = 'write_notes' },
      { when = { tool = 'Write', file_path = { lua_pattern = '%.lua$' } }, play = 'write_lua' },
    },
  })

  story.started('a', 'Edit', { file_path = 'docs/guide.md' })
  eq(story.activity(), 'write_notes')

  story.started('b', 'Write', { file_path = 'init.lua' })
  eq(story.activity(), 'write_lua')
end

T['a trigger']['matches a field that is true or a number as that value'] = function()
  local story = office_signals.tell({
    triggers = { { when = { tool = 'Bash', run_in_background = true }, play = 'send_it_off' } },
  })

  story.started('a', 'Bash', { command = 'sleep 5', run_in_background = true })

  eq(story.activity(), 'send_it_off')
end

T['a trigger']['with an agent of main matches the main agent alone'] = function()
  local story = office_signals.tell({
    triggers = { { when = { tool = 'Read', agent = 'main' }, play = 'look_closely' } },
  })

  story.hear('tool_started', { agent = 'a1', call = 'x', tool = 'Read', input = {} })
  story.started('a', 'Read')

  eq(story.activity('a1'), nil)
  eq(story.activity('main'), 'look_closely')
end

T['a trigger']['with an agent of subagent matches a subagent alone'] = function()
  local story = office_signals.tell({
    triggers = { { when = { tool = 'Read', agent = 'subagent' }, play = 'look_closely' } },
  })

  story.hear('tool_started', { agent = 'a1', call = 'x', tool = 'Read', input = {} })
  story.started('a', 'Read')

  eq(story.activity('a1'), 'look_closely')
  eq(story.activity('main'), nil)
end

T['a trigger']['with an empty when matches no call'] = function()
  local triggers = { { when = {}, play = 'always' } }

  eq(activity_while_running(triggers, 'ls'), nil)
end

T['a trigger']['without a when or without a play matches no call'] = function()
  local triggers = { { play = 'always' }, { when = { tool = 'Bash' } }, 'docker' }

  eq(activity_while_running(triggers, 'ls'), nil)
end

T['a trigger']['names the activity of the call started last while several run'] = function()
  local story = office_signals.tell({
    triggers = { { when = { tool = 'Read' }, play = 'look_closely' } },
  })
  story.started('a', 'Read')
  story.started('b', 'Edit')

  eq(story.activity(), nil)
end

T['a trigger']['is shown for the dwell like a state: a new activity holds the one before'] = function()
  local story = office_signals.tell({
    triggers = {
      { when = { tool = 'Read', file_path = 'a' }, play = 'first' },
      { when = { tool = 'Read', file_path = 'b' }, play = 'second' },
    },
  })
  story.started('a', 'Read', { file_path = 'a' })

  story.hear_after(0.3, 'tool_started', { call = 'b', tool = 'Read', input = { file_path = 'b' } })

  eq(story.agents_after(0.3)[1].activity, 'first')
  eq(story.agents_after(1.5)[1].activity, 'second')
end

T['an office with no triggers'] = MiniTest.new_set()

T['an office with no triggers']['names no activity'] = function()
  local story = office_signals.tell()

  story.started('a', 'Read')

  eq(story.activity(), nil)
end

return T
