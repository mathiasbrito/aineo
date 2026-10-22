local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local office_signals = dofile('tests/helpers/office_signals.lua')

local T = MiniTest.new_set()

--- The ids of the agents `story` lists `seconds` after its last signal.
---
---@param story aineo.tests.Story
---@param seconds number
---@return string[] ids
local function ids_after(story, seconds)
  return vim.tbl_map(function(agent)
    return agent.id
  end, story.agents_after(seconds))
end

T['a session'] = MiniTest.new_set()

T['a session']['that starts has the main agent arrive, then stand'] = function()
  local story = office_signals.tell()

  story.hear('session_started')

  eq(story.state_after(1.3), 'arriving')
  eq(story.state_after(30), 'standing')
end

T['a session']['that ends has the main agent leave'] = function()
  local story = office_signals.tell()
  story.hear('thinking')

  story.hear('session_ended')

  eq(story.state_after(1.3), 'leaving')
  eq(story.state_after(1000), 'leaving')
  eq(ids_after(story, 1000), { 'main' })
end

T['a session']['that starts after another has the main agent arrive and the subagents of the first gone'] = function()
  local story = office_signals.tell()
  story.hear('subagent_started', { agent = 'a1' })
  story.hear('session_ended')

  story.hear('session_started')

  eq(story.state(), 'arriving')
  eq(ids_after(story, 1.3), { 'main' })
end

T['a subagent'] = MiniTest.new_set()

T['a subagent']['arrives when it is heard of, then stands'] = function()
  local story = office_signals.tell()

  story.hear('subagent_started', { agent = 'a1' })

  eq(story.state_after(1.3, 'a1'), 'arriving')
  eq(story.state_after(30, 'a1'), 'standing')
  eq(ids_after(story, 1.3), { 'main', 'a1' })
end

T['a subagent']['is done when it finishes, then leaves, then is gone'] = function()
  local story = office_signals.tell()
  story.hear('subagent_started', { agent = 'a1' })

  story.hear('subagent_finished', { agent = 'a1' })

  eq(story.state_after(1.3, 'a1'), 'done')
  eq(story.state_after(10, 'a1'), 'leaving')
  eq(ids_after(story, 20), { 'main', 'a1' })
  eq(ids_after(story, 100), { 'main' })
end

T['a subagent']["that finished in the past, as the transcript's tail tells, is not listed"] = function()
  local story = office_signals.tell()
  story.hear_replayed('subagent_started', { agent = 'a1' })

  story.hear_replayed('subagent_finished', { agent = 'a1' })

  eq(ids_after(story, 0), { 'main' })
end

T['a subagent']['that is heard of again after it left is not drawn again'] = function()
  local story = office_signals.tell()
  story.hear('subagent_started', { agent = 'a1' })
  story.hear('subagent_finished', { agent = 'a1' })

  story.hear_after(100, 'subagent_started', { agent = 'a1' })

  eq(ids_after(story, 1.3), { 'main' })
end

T['a subagent']['that finished shows leaving even when its turn ended too'] = function()
  local story = office_signals.tell()
  story.hear('subagent_started', { agent = 'a1' })
  story.hear('turn_ended', { agent = 'a1' })

  story.hear_after(10, 'subagent_finished', { agent = 'a1' })

  eq(story.state_after(10, 'a1'), 'leaving')
end

T['a subagent']['whose turn ended is idle, not waiting for subagents'] = function()
  local story = office_signals.tell()
  story.hear('subagent_started', { agent = 'a1' })

  story.hear('turn_ended', { agent = 'a1' })

  eq(story.state_after(30, 'a1'), 'idle')
end

T['the main agent'] = MiniTest.new_set()

T['the main agent']['delegates while it calls an agent that has not arrived'] = function()
  local story = office_signals.tell()

  story.started('a', 'Agent')

  eq(story.state(), 'delegating')
end

T['the main agent']['waits for subagents while it calls an agent that has arrived'] = function()
  local story = office_signals.tell()
  story.started('a', 'Agent')

  story.hear('subagent_started', { agent = 'a1' })

  eq(story.state(), 'waiting_for_subagents')
end

T['the main agent']['waits for subagents when its turn ended while one runs'] = function()
  local story = office_signals.tell()
  story.hear('subagent_started', { agent = 'a1' })

  story.hear('turn_ended')

  eq(story.state_after(30), 'waiting_for_subagents')
end

T['the main agent']['is idle once the subagent it waited for finished'] = function()
  local story = office_signals.tell()
  story.hear('subagent_started', { agent = 'a1' })
  story.hear('turn_ended')

  story.hear_after(20, 'subagent_finished', { agent = 'a1' })

  eq(story.state_after(30), 'idle')
end

T['the main agent']['does not wait for a subagent that finished'] = function()
  local story = office_signals.tell()
  story.hear('subagent_started', { agent = 'a1' })
  story.hear('subagent_finished', { agent = 'a1' })

  story.started('a', 'Agent')

  eq(story.state(), 'delegating')
end

T['a permission wait'] = MiniTest.new_set()

T['a permission wait']['has the agent need permission'] = function()
  local story = office_signals.tell()
  story.started('a', 'Edit')

  story.hear('permission_asked')

  eq(story.state(), 'needs_permission')
end

T['a permission wait']["ends with the agent's next signal, the result of the call among them"] = function()
  local story = office_signals.tell()
  story.started('a', 'Edit')
  story.hear('permission_asked')

  story.finished('a')

  eq(story.state(), 'thinking')
end

T['a permission wait']['is the wait of the agent it names alone'] = function()
  local story = office_signals.tell()
  story.hear('subagent_started', { agent = 'a1' })

  story.hear('permission_asked', { agent = 'a1' })
  story.hear('thinking')

  eq(story.state('a1'), 'needs_permission')
  eq(story.state('main'), 'thinking')
end

T['a permission wait']['shows over the state of a call that runs'] = function()
  local story = office_signals.tell()
  story.started('a', 'Edit')
  story.hear('thinking')
  story.hear('permission_asked')

  eq(story.state(), 'needs_permission')
end

return T
