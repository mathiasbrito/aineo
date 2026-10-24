local MiniTest = require('mini.test')

local office_signals = dofile('tests/helpers/office_signals.lua')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

--- The classes of commands the stories run: `make test` runs tests.
local COMMANDS = { tests = { 'make test' } }

--- A story whose agent ran its tests in the call `a`, which finished.
---
---@return aineo.tests.Story
local function after_a_test_run()
  local story = office_signals.tell({ commands = COMMANDS })
  story.started('a', 'Bash', { command = 'make test' })
  story.finished('a')
  return story
end

--- The `after_call` of the main agent `seconds` after the story's last signal.
---
---@param story aineo.tests.Story
---@param seconds number
---@return string|nil
local function after_call_after(story, seconds)
  return story.agents_after(seconds)[1].after_call
end

T['an agent thinking'] = MiniTest.new_set()

T['an agent thinking']['right after a call tells the state of the call it finished'] = function()
  local story = after_a_test_run()

  eq(
    { story.state(), after_call_after(story, office_signals.SETTLE) },
    { 'thinking', 'running_tests' }
  )
end

T['an agent thinking']['after a call tells it until ten seconds into the thinking'] = function()
  local story = after_a_test_run()

  eq(after_call_after(story, 9.9), 'running_tests')
  eq({ story.state_after(10), after_call_after(story, 10) }, { 'thinking' })
end

T['an agent thinking']['after a prompt that followed a call tells no call'] = function()
  local story = after_a_test_run()

  story.hear('prompt')

  eq({ story.state_after(3.5), after_call_after(story, 3.5) }, { 'thinking' })
end

T['an agent thinking']['after a call and a thought of its own still tells the call'] = function()
  local story = after_a_test_run()

  story.hear_after(1, 'thinking')

  eq(after_call_after(story, office_signals.SETTLE), 'running_tests')
end

T['an agent thinking']['after a call tells nothing once its next call runs'] = function()
  local story = after_a_test_run()

  story.started('b', 'Read')

  eq({ story.state(), after_call_after(story, office_signals.SETTLE) }, { 'reading' })
end

return T
