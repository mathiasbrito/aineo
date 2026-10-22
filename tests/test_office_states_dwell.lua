local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local office_signals = dofile('tests/helpers/office_signals.lua')

local T = MiniTest.new_set()

--- A story whose main agent started reading 2 seconds in.
---
---@return aineo.tests.Story
local function story_reading()
  local story = office_signals.tell()
  story.started('a', 'Read')
  return story
end

T['a state'] = MiniTest.new_set()

T['a state']['is held 1.2 seconds before the next one shows'] = function()
  local story = story_reading()

  story.hear_after(0.3, 'tool_finished', { call = 'a' })

  eq(story.state_after(0.5), 'reading')
  eq(story.state_after(0.8), 'reading')
  eq(story.state_after(1.0), 'thinking')
end

T['a state']['gives way at once when it has been held 1.2 seconds'] = function()
  local story = story_reading()

  story.hear_after(1.3, 'tool_finished', { call = 'a' })

  eq(story.state_after(0), 'thinking')
end

T['a state']['is followed by the latest state that came while it was held'] = function()
  local story = story_reading()

  story.hear_after(0.3, 'tool_started', { call = 'b', tool = 'Grep', input = {} })
  story.hear_after(0.3, 'tool_started', { call = 'c', tool = 'Edit', input = {} })

  eq(story.state_after(0), 'reading')
  eq(story.state_after(1), 'writing_code')
end

T['a state']['is kept when the state that came while it was held went back to it'] = function()
  local story = story_reading()

  story.hear_after(0.3, 'tool_started', { call = 'b', tool = 'Edit', input = {} })
  story.hear_after(0.3, 'tool_finished', { call = 'b' })

  eq(story.state_after(2), 'reading')
end

T['a state']['is held for each agent on its own'] = function()
  local story = story_reading()

  story.hear_after(0.3, 'tool_started', { agent = 'a1', call = 'x', tool = 'Edit', input = {} })

  eq(story.state_after(0.1, 'main'), 'reading')
  eq(story.state_after(0.1, 'a1'), 'writing_code')
end

return T
