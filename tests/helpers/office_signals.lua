--- A story told to an office tracker: signals heard one after another on a
--- clock the story keeps, and the states the tracker shows afterwards.
---
--- Each signal is heard `PAUSE` seconds after the one before, so the state a
--- signal gave has been held long enough to show by the time the next one
--- comes; `state()` asks `SETTLE` seconds after the last signal, when the
--- state it gave shows and no timed state has run out. A test that is about
--- time moves the clock itself with `wait()` and asks with `state_after()`.

local office_states = require('aineo.office_states')

local M = {}

--- Seconds between one signal and the next.
M.PAUSE = 2

--- Seconds after the last signal at which `state()` asks: past the tracker's
--- dwell of 1.2 seconds, within the shortest timed state.
M.SETTLE = 1.3

---@class aineo.tests.Story
---@field hear fun(kind: string, fields?: table) the main agent, or the agent `fields.agent`, gives a signal of `kind` after the pause
---@field hear_replayed fun(kind: string, fields?: table) the same, marked as read from the transcript's tail
---@field wait fun(seconds: number) moves the clock on
---@field state fun(id?: string): string|nil the state of the agent `id` (the main agent by default) just after the last signal
---@field state_after fun(seconds: number, id?: string): string|nil the state of the agent `id` that many seconds after the last signal
---@field activity fun(id?: string): string|nil the activity a trigger chose for the agent `id` just after the last signal
---@field agents_after fun(seconds: number): aineo.office_states.Agent[] every agent that many seconds after the last signal
---@field started fun(call: string, tool: string, input?: table) the main agent starts the tool call `call`
---@field finished fun(call: string, failed?: boolean) the main agent's tool call `call` finishes

--- A story told to a new tracker made with `options`.
---
---@param options? table the options of `office_states.new_tracker()`
---@return aineo.tests.Story story
function M.tell(options)
  local tracker = office_states.new_tracker(options or {})
  local clock = 0
  local story = {}

  --- The agent `id` as the tracker lists it `seconds` after the clock.
  ---
  ---@param seconds number
  ---@param id string|nil
  ---@return aineo.office_states.Agent|nil
  local function agent_after(seconds, id)
    return vim.iter(tracker.agents(clock + seconds)):find(function(agent)
      return agent.id == (id or 'main')
    end)
  end

  ---@param kind string
  ---@param fields table|nil
  ---@param replayed boolean
  local function give(kind, fields, replayed)
    clock = clock + M.PAUSE
    local signal = vim.tbl_extend('force', { agent = 'main', kind = kind }, fields or {})
    signal.replayed = replayed or nil
    tracker.take(signal, clock)
  end

  function story.hear(kind, fields)
    give(kind, fields, false)
  end

  function story.hear_replayed(kind, fields)
    give(kind, fields, true)
  end

  function story.wait(seconds)
    clock = clock + seconds
  end

  function story.state_after(seconds, id)
    local agent = agent_after(seconds, id)
    return agent and agent.state
  end

  function story.state(id)
    return story.state_after(M.SETTLE, id)
  end

  function story.activity(id)
    local agent = agent_after(M.SETTLE, id)
    return agent and agent.activity
  end

  function story.agents_after(seconds)
    return tracker.agents(clock + seconds)
  end

  function story.started(call, tool, input)
    story.hear('tool_started', { call = call, tool = tool, input = input or {} })
  end

  function story.finished(call, failed)
    story.hear('tool_finished', { call = call, failed = failed or false })
  end

  return story
end

return M
