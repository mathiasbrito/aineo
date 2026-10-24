local MiniTest = require('mini.test')

local office_signals = dofile('tests/helpers/office_signals.lua')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

--- The time on the wall when the stories replay a transcript, in seconds
--- since 1970.
local WALL_NOW = 1700001000

--- Ten minutes, in seconds: how long a subagent may be silent.
local QUIET_SECONDS = 600

--- A story told to a tracker whose wall clock says `WALL_NOW`.
---
---@return aineo.tests.Story
local function told_at_wall_now()
  return office_signals.tell({
    wall_clock = function()
      return WALL_NOW
    end,
  })
end

--- The ids of the agents the tracker lists `seconds` after the story's last
--- signal.
---
---@param story aineo.tests.Story
---@param seconds number
---@return string[]
local function ids_after(story, seconds)
  return vim.tbl_map(function(agent)
    return agent.id
  end, story.agents_after(seconds))
end

--- The replay of the subagent `id`, whose transcript was last written
--- `seconds_ago` before `WALL_NOW`, started by the call `call`, and of a
--- prompt it was given.
---
---@param story aineo.tests.Story
---@param id string
---@param seconds_ago number
---@param call? string
local function replay_subagent(story, id, seconds_ago, call)
  story.hear_replayed(
    'subagent_started',
    { agent = id, written_at = WALL_NOW - seconds_ago, call = call }
  )
  story.hear_replayed('prompt', { agent = id })
end

T['a subagent replayed'] = MiniTest.new_set()

T['a subagent replayed']['whose transcript was last written ten minutes before is not brought in'] = function()
  local story = told_at_wall_now()

  replay_subagent(story, 'old', QUIET_SECONDS)

  eq(ids_after(story, office_signals.SETTLE), { 'main' })
end

T['a subagent replayed']['whose transcript was written less than ten minutes before is brought in'] = function()
  local story = told_at_wall_now()

  replay_subagent(story, 'recent', QUIET_SECONDS - 1)

  eq(ids_after(story, office_signals.SETTLE), { 'main', 'recent' })
end

T['a subagent replayed']['long quiet is brought in while the call that started it runs'] = function()
  local story = told_at_wall_now()
  story.hear_replayed('tool_started', { call = 'delegate', tool = 'Agent', input = {} })

  replay_subagent(story, 'working', 2 * QUIET_SECONDS, 'delegate')

  eq(ids_after(story, office_signals.SETTLE), { 'main', 'working' })
end

T['a subagent replayed']['long quiet walks in with its next line'] = function()
  local story = told_at_wall_now()
  replay_subagent(story, 'old', QUIET_SECONDS)

  story.hear('tool_started', { agent = 'old', call = 'read', tool = 'Read', input = {} })

  eq({ story.state('old'), story.state_after(5, 'old') }, { 'arriving', 'reading' })
end

T['a subagent replayed']['goes quiet ten minutes after its transcript was written, whatever its replayed lines'] = function()
  local story = told_at_wall_now()
  replay_subagent(story, 'sub', QUIET_SECONDS - 10)

  story.hear_replayed('tool_started', { agent = 'sub', call = 'read', tool = 'Read', input = {} })

  eq(
    { story.state_after(20, 'sub'), vim.tbl_contains(ids_after(story, 50), 'sub') },
    { 'leaving', false }
  )
end

T['a subagent followed'] = MiniTest.new_set()

--- A story in which the subagent `sub` arrives and is given a prompt, both
--- heard as they happen.
---
---@return aineo.tests.Story
local function with_a_subagent_followed()
  local story = told_at_wall_now()
  story.hear('subagent_started', { agent = 'sub' })
  story.hear('prompt', { agent = 'sub' })
  return story
end

T['a subagent followed']['that says nothing for ten minutes walks out, then is gone'] = function()
  local story = with_a_subagent_followed()

  eq(
    { story.state_after(QUIET_SECONDS - 1, 'sub'), story.state_after(QUIET_SECONDS + 1, 'sub') },
    { 'thinking', 'leaving' }
  )
  eq(ids_after(story, QUIET_SECONDS + 31), { 'main' })
end

T['a subagent followed']['that says something within ten minutes stays'] = function()
  local story = with_a_subagent_followed()

  story.hear_after(
    QUIET_SECONDS - 10,
    'tool_started',
    { agent = 'sub', call = 'read', tool = 'Read', input = {} }
  )

  eq(story.state_after(QUIET_SECONDS - 10, 'sub'), 'reading')
end

T['a subagent followed']['quiet for ten minutes stays while the call that started it runs'] = function()
  local story = told_at_wall_now()
  story.started('delegate', 'Agent')
  story.hear('subagent_started', { agent = 'sub', call = 'delegate' })
  story.hear('prompt', { agent = 'sub' })

  eq(story.state_after(QUIET_SECONDS + 1, 'sub'), 'thinking')
end

T['a subagent followed']['quiet for ten minutes stays while it waits for permission'] = function()
  local story = with_a_subagent_followed()

  story.hear('permission_asked', { agent = 'sub' })

  eq(
    { story.state_after(QUIET_SECONDS + 31, 'sub'), ids_after(story, QUIET_SECONDS + 31) },
    { 'needs_permission', { 'main', 'sub' } }
  )
end

T['a subagent followed']['that walked out quiet walks in again with its next line'] = function()
  local story = with_a_subagent_followed()

  story.hear_after(
    QUIET_SECONDS + 60,
    'tool_started',
    { agent = 'sub', call = 'read', tool = 'Read', input = {} }
  )

  eq({ story.state('sub'), story.state_after(5, 'sub') }, { 'arriving', 'reading' })
end

T['a subagent followed']['that walked out quiet and then finishes does not come back'] = function()
  local story = with_a_subagent_followed()

  story.hear_after(QUIET_SECONDS + 60, 'subagent_finished', { agent = 'sub' })

  eq(ids_after(story, 0.1), { 'main' })
end

T['a subagent followed']['that went quiet is waited for no more'] = function()
  local story = with_a_subagent_followed()
  story.hear('turn_ended')

  story.hear_after(QUIET_SECONDS + 10, 'compacted')

  eq(story.state_after(6), 'idle')
end

T['a subagent followed']['that went quiet is waited for no more, with no other signal heard'] = function()
  local story = with_a_subagent_followed()

  story.hear('turn_ended')

  eq({ story.state_after(QUIET_SECONDS + 40), story.state_after(1300) }, { 'idle', 'asleep' })
end

T['a subagent replayed']['long quiet walks in with the call that started it, which keeps it while it runs'] = function()
  local story = told_at_wall_now()
  replay_subagent(story, 'old', QUIET_SECONDS, 'delegate')
  story.started('delegate', 'Agent')

  story.hear('tool_started', { agent = 'old', call = 'read', tool = 'Read', input = {} })

  eq(story.state_after(QUIET_SECONDS + 1, 'old'), 'reading')
end

T['a tracker that forgets what came before a time'] = MiniTest.new_set()

--- A story told to a tracker whose wall clock says `WALL_NOW` and that
--- forgets what the transcripts replay of before `seconds_ago` before it.
---
---@param seconds_ago number
---@return aineo.tests.Story
local function told_forgetting_before(seconds_ago)
  return office_signals.tell({
    wall_clock = function()
      return WALL_NOW
    end,
    forgotten_before = WALL_NOW - seconds_ago,
  })
end

T['a tracker that forgets what came before a time']['lists neither a replayed subagent nor what the main agent did before it'] = function()
  local story = told_forgetting_before(0)
  story.hear_replayed('tool_started', { call = 'read', tool = 'Read', input = {} })

  replay_subagent(story, 'recent', 1)

  eq({ ids_after(story, office_signals.SETTLE), story.state() }, { { 'main' }, 'standing' })
end

T['a tracker that forgets what came before a time']['has a replayed subagent it forgot walk in with its next line'] = function()
  local story = told_forgetting_before(0)
  replay_subagent(story, 'recent', 1)

  story.hear('tool_started', { agent = 'recent', call = 'read', tool = 'Read', input = {} })

  eq({ story.state('recent'), story.state_after(5, 'recent') }, { 'arriving', 'reading' })
end

T['a tracker that forgets what came before a time']['hears what the replay says came after it'] = function()
  local story = told_forgetting_before(100)
  story.hear_replayed(
    'tool_started',
    { call = 'read', tool = 'Read', input = {}, at = WALL_NOW - 50 }
  )

  replay_subagent(story, 'before', 200)
  replay_subagent(story, 'after', 20)

  eq({ ids_after(story, office_signals.SETTLE), story.state() }, { { 'main', 'after' }, 'reading' })
end

return T
