--- What the tracker knows of one agent, and what each signal does to it.
--- Pure: the time of a signal is given with it.
---
--- A record keeps facts (the calls that run, whether the model is at work on a
--- result, whether the turn ended) and, apart from them, one event: a
--- short-lived state a signal brings (an error, the end of a turn), which
--- lasts a set time and gives way to what the facts say. `fact_state()` is the
--- state the facts give; `aineo.office_states.display` turns facts, event and
--- clock into what the agent shows.

local calls = require('aineo.office_states.calls')
local timing = require('aineo.office_states.timing')
local triggers = require('aineo.office_states.triggers')

local M = {}

--- The id the main agent goes by.
M.MAIN = 'main'

--- The id a tool call without one is kept under.
local UNNAMED_CALL = ''

--- A tool call that started and has not finished.
---@class aineo.office_states.OpenCall
---@field state string the state of an agent while the call runs
---@field activity? string the activity a trigger of the pack names for the call
---@field order integer how many calls the agent had started when this one did

--- A state that a signal brings and the clock ends.
---@class aineo.office_states.Event
---@field state string
---@field since number when the signal was heard
---@field lasts number seconds

--- A state of an agent from a time on.
---@class aineo.office_states.Appearance
---@field state string
---@field activity? string the activity a trigger names, in place of the state's own
---@field since number when the agent came into the state; `timing.BEFORE_THE_TRACKER` when it was always in it

---@class aineo.office_states.Record
---@field id string
---@field open_calls table<string, aineo.office_states.OpenCall> the tool calls that started and have not finished, by call id
---@field started_calls integer how many tool calls the agent has started
---@field background_jobs integer how many background jobs it started that have not reported back
---@field thinking boolean whether the model is at work on what it was given: a prompt, a thought or a result, since the last call started
---@field turn_ended boolean whether its last turn ended and nothing began since
---@field prompted boolean whether it was given a prompt
---@field finished boolean whether it finished: a subagent that is over
---@field session_ended boolean whether its session ended
---@field permission_asked_at? number when it asked for permission, until its next signal
---@field known boolean whether a line of its own, or word that it is a subagent, was heard: an agent known only by its permission request is not
---@field event? aineo.office_states.Event
---@field queued_event? aineo.office_states.Event the event that begins when an arrival ends
---@field fact aineo.office_states.Appearance the state its facts give, from when they give it
---@field shown aineo.office_states.Appearance the state it shows, held by the dwell
---@field listed_until? number a finished agent is listed until then

--- What the tracker is told about the office, which decides what a signal means.
---@class aineo.office_states.Settings: aineo.office_states.CallSettings
---@field triggers? aineo.office_states.Trigger[] the triggers of the pack, in order
---@field trigger_budget? aineo.office_states.TriggerBudget how long the triggers of one call may take

--- What a signal is heard with.
---@class aineo.office_states.Hearing
---@field now number when it was heard, in seconds on the caller's clock
---@field replayed boolean whether it was read from the transcript's tail, a thing of the past
---@field settings aineo.office_states.Settings

---@param id string
---@return aineo.office_states.Record
function M.new(id)
  return {
    id = id,
    open_calls = {},
    started_calls = 0,
    background_jobs = 0,
    thinking = false,
    turn_ended = false,
    prompted = false,
    known = false,
    finished = false,
    session_ended = false,
    fact = { state = 'standing', since = timing.BEFORE_THE_TRACKER },
    shown = { state = 'standing', since = timing.BEFORE_THE_TRACKER },
  }
end

--- Whether `record` is the main agent's.
---
---@param record aineo.office_states.Record
---@return boolean
local function is_main(record)
  return record.id == M.MAIN
end

--- The kind of agent `record` is, for a trigger's `agent` field.
---
---@param record aineo.office_states.Record
---@return aineo.office_states.AgentKind
local function kind_of_agent(record)
  return is_main(record) and 'main' or 'subagent'
end

--- Whether the arrival of `record` is still going on at `now`.
---
---@param record aineo.office_states.Record
---@param now number
---@return boolean
local function is_arriving(record, now)
  local event = record.event
  return event ~= nil and event.state == 'arriving' and now < event.since + event.lasts
end

--- Makes `state` the agent's event from now on, lasting `lasts` seconds; while
--- the agent is arriving, the event waits for the arrival to end, since the
--- walk in is not cut by what the agent does on its first lines. A signal read
--- from the past brings no event: it is not happening now.
---
---@param record aineo.office_states.Record
---@param hearing aineo.office_states.Hearing
---@param state string
---@param lasts number
local function bring_event(record, hearing, state, lasts)
  if hearing.replayed then
    return
  end
  if state ~= 'arriving' and is_arriving(record, hearing.now) then
    record.queued_event = {
      state = state,
      since = record.event.since + record.event.lasts,
      lasts = lasts,
    }
    return
  end
  record.event = { state = state, since = hearing.now, lasts = lasts }
end

---@param record aineo.office_states.Record
local function end_turn(record)
  record.open_calls = {}
  record.thinking = false
  record.turn_ended = true
end

--- What each kind of signal does to the record of the agent that gave it.
---@type table<string, fun(record: aineo.office_states.Record, signal: aineo.transcript.Signal, hearing: aineo.office_states.Hearing)>
local HEARS = {
  tool_started = function(record, signal, hearing)
    record.turn_ended = false
    record.thinking = false
    local id = signal.call or UNNAMED_CALL
    if record.open_calls[id] then
      return
    end
    local state = calls.state_of_call(signal, hearing.settings)
    record.started_calls = record.started_calls + 1
    record.open_calls[id] = {
      state = state,
      activity = triggers.activity_of_call(
        signal,
        kind_of_agent(record),
        hearing.settings.triggers or {},
        hearing.settings.trigger_budget
      ),
      order = record.started_calls,
    }
    if state == 'background_job' then
      record.background_jobs = record.background_jobs + 1
    end
  end,

  tool_finished = function(record, signal, hearing)
    local id = signal.call or UNNAMED_CALL
    local call = record.open_calls[id]
    if not call then
      return
    end
    record.open_calls[id] = nil
    record.thinking = true
    if signal.failed and call.state ~= 'running_tests' then
      bring_event(record, hearing, 'error', timing.ERROR_SECONDS)
    end
  end,

  prompt = function(record, _, hearing)
    record.thinking = true
    record.turn_ended = false
    if is_main(record) or not record.prompted then
      bring_event(record, hearing, 'getting_a_task', timing.GETTING_A_TASK_SECONDS)
    end
    record.prompted = true
  end,

  thinking = function(record)
    record.thinking = true
    record.turn_ended = false
  end,

  turn_ended = function(record, _, hearing)
    end_turn(record)
    bring_event(record, hearing, 'done', timing.DONE_SECONDS)
  end,

  interrupted = function(record, _, hearing)
    end_turn(record)
    bring_event(record, hearing, 'interrupted', timing.INTERRUPTED_SECONDS)
  end,

  compacted = function(record, _, hearing)
    bring_event(record, hearing, 'compacting', timing.COMPACTING_SECONDS)
  end,

  background_done = function(record)
    record.background_jobs = math.max(0, record.background_jobs - 1)
  end,

  subagent_started = function(record, _, hearing)
    bring_event(record, hearing, 'arriving', timing.ARRIVING_SECONDS)
  end,

  subagent_finished = function(record, _, hearing)
    record.finished = true
    record.event = nil
    if hearing.replayed then
      record.listed_until = hearing.now
    else
      record.listed_until = hearing.now + timing.DONE_SECONDS + timing.LEAVING_LISTED_SECONDS
    end
    bring_event(record, hearing, 'done', timing.DONE_SECONDS)
  end,

  session_started = function(record, _, hearing)
    bring_event(record, hearing, 'arriving', timing.ARRIVING_SECONDS)
  end,

  session_ended = function(record)
    record.session_ended = true
  end,

  permission_asked = function(record, _, hearing)
    record.permission_asked_at = hearing.now
  end,
}

--- Whether a signal of `kind` changes a record.
---
---@param kind string
---@return boolean
function M.hears(kind)
  return HEARS[kind] ~= nil
end

--- Takes in `signal`, which the agent of `record` gave. Any signal but a
--- permission request ends the agent's event, unless it is arriving, and
--- any but a permission request or the start of a tool call (which can be
--- read after the hook that asked about that very call) ends the agent's
--- wait for permission; a finished agent hears nothing more.
---
---@param record aineo.office_states.Record
---@param signal aineo.transcript.Signal
---@param hearing aineo.office_states.Hearing
function M.hear(record, signal, hearing)
  if record.finished then
    return
  end
  if signal.kind ~= 'permission_asked' then
    record.known = true
    if signal.kind ~= 'tool_started' then
      record.permission_asked_at = nil
    end
    if not is_arriving(record, hearing.now) then
      record.event = nil
    end
    record.queued_event = nil
  end
  HEARS[signal.kind](record, signal, hearing)
end

--- Whether `record` is an agent heard of only by its permission request: not
--- the main agent, and not yet heard from or announced.
---
---@param record aineo.office_states.Record
---@return boolean
function M.is_known_only_by_permission(record)
  return not record.known and record.id ~= M.MAIN and not record.finished
end

---@param record aineo.office_states.Record
---@return aineo.office_states.OpenCall|nil
local function latest_open_call(record)
  local latest = nil
  for _, call in pairs(record.open_calls) do
    if not latest or call.order > latest.order then
      latest = call
    end
  end
  return latest
end

--- Whether the main agent waits for its subagents: some are running and
--- either an `Agent` call is the call it started last or its turn ended. No
--- other agent waits so.
---
---@param record aineo.office_states.Record
---@param latest_call aineo.office_states.OpenCall|nil the call it started last of those still running
---@param running_subagents integer how many subagents have not finished
---@return boolean
local function waits_for_subagents(record, latest_call, running_subagents)
  if not is_main(record) or running_subagents == 0 then
    return false
  end
  if latest_call then
    return latest_call.state == 'delegating'
  end
  return record.turn_ended
end

--- The state the facts of `record` give, and the activity a trigger names for
--- the call it started last, if the state is that call's: leaving when its
--- work is over; else waiting for subagents, when the main agent has some
--- running; else the state of the call started last while a tool call runs; a
--- background job still running; thinking while the model works on what it
--- was given; idle once its turn ended; standing otherwise.
---
---@param record aineo.office_states.Record
---@param running_subagents integer how many subagents have not finished
---@return string state
---@return string|nil activity
function M.fact_state(record, running_subagents)
  if record.finished or record.session_ended then
    return 'leaving'
  end
  local call = latest_open_call(record)
  local activity = call and call.activity
  if waits_for_subagents(record, call, running_subagents) then
    return 'waiting_for_subagents', activity
  end
  if call then
    return call.state, activity
  end
  if record.background_jobs > 0 then
    return 'background_job'
  end
  if record.thinking then
    return 'thinking'
  end
  if record.turn_ended then
    return 'idle'
  end
  return 'standing'
end

return M
