--- The tracker of `aineo.office_states`: the state of each agent, kept from the
--- signals the agent gave. Pure: it reads no clock and no editor state; the
--- caller says what time it is, on a clock of its own that only grows.

local details = require('aineo.office_states.details')
local display = require('aineo.office_states.display')
local record_module = require('aineo.office_states.record')
local timing = require('aineo.office_states.timing')

local M = {}

--- What the tracker is told about the office it keeps.
---@class aineo.office_states.TrackerOptions
---@field report_tool? string the name of aineo's report tool, as Claude Code calls it (`mcp__<server>__<tool>`); none when the office is told of none
---@field commands? aineo.office_states.CommandClasses the classes of shell commands (`office.commands`); none when the office is told of none, and every command is then a command run
---@field triggers? aineo.office_states.Trigger[] the pack's triggers, tried in order whenever a tool call starts; none when the pack has none
---@field clock? fun(): number the time in seconds, on a clock that only grows, which limits the triggers of one call to 20 ms; none, and they are not limited
---@field on_slow_triggers? fun() called, once, when the triggers of a call were given up for taking too long
---@field wall_clock? fun(): number the time in seconds since 1970, which tells how long ago a replayed subagent's transcript was written; none, and every replayed subagent counts as written now
---@field forgotten_before? number a time in seconds since 1970 before which what the transcripts' tails replay is left out: a line stamped before it, or not stamped, and the arrival of a subagent whose transcript was last written before it; the main agent hears none of it, and each subagent left out rests until a line of it is heard as it happens; none, and nothing is left out for its time

--- The kinds of signal beyond the transcript's (`aineo.transcript.SignalKind`)
--- that the office gives the tracker: a session that starts or ends, and an
--- agent that asks Claude Code for permission.
---@alias aineo.office_states.OfficeSignalKind 'session_started'|'session_ended'|'permission_asked'

---@class aineo.office_states.Agent
---@field id string 'main', or a subagent's id
---@field state string a state of the vocabulary
---@field activity? string the activity a trigger of the pack names for what the agent is doing, in place of its state's own; none when no trigger matches
---@field since? number when the agent came into its state, on the caller's clock; none for an agent that has been in it since the tracker was made
---@field details aineo.office_states.AgentDetails what the agent knows of the world it works in, which the pieces of the office show
---@field after_call? string while the agent thinks right after a call, the state of that call; none otherwise

--- What the tracker keeps of a subagent that walked out quiet, or that it
--- left out as quiet, until a line of it is heard.
---@class aineo.office_states.Rest
---@field started_by? string the id of the main agent's call that started it
---@field open_calls? table<string, aineo.office_states.OpenCall> the calls of its own that ran as it walked out; none for one left out
---@field started_calls? integer how many calls it had started as it walked out

---@class aineo.office_states.Tracker
---@field take fun(signal: aineo.transcript.Signal, now: number) takes in what an agent did, heard at `now`, in seconds on the caller's clock
---@field agents fun(now: number): aineo.office_states.Agent[] each agent and its state at `now`, the main agent first, the others in the order they were first heard of; a subagent that left is listed for a while, then not

--- The kinds of signal of the main agent that end its work.
local ENDS_THE_MAIN_AGENTS_WORK = { turn_ended = true, interrupted = true, session_ended = true }

--- The states of calls an agent does not go on with while it thinks after
--- them: asking the user and handing a task over are moments with someone,
--- over when the call is.
local NOT_GONE_ON_WITH = { asking_you = true, delegating = true }

--- The state of the call the agent of `record` finished, while what it shows,
--- `shown`, is the thinking that followed the call and has lasted less than
--- `timing.THINKS_AT_ITS_WORK_SECONDS` at `now`; none otherwise, and none for
--- a call it does not go on with (`NOT_GONE_ON_WITH`).
---
---@param record aineo.office_states.Record
---@param shown aineo.office_states.Appearance
---@param now number
---@return string|nil
local function after_call(record, shown, now)
  if shown.state ~= 'thinking' or now >= shown.since + timing.THINKS_AT_ITS_WORK_SECONDS then
    return nil
  end
  if NOT_GONE_ON_WITH[record.finished_call_state] then
    return nil
  end
  return record.finished_call_state
end

--- Whether the agent of `record` has gone quiet by `now`: it was heard of
--- not at all for `timing.QUIET_SUBAGENT_SECONDS`.
---
---@param record aineo.office_states.Record
---@param now number
---@return boolean
local function is_quiet(record, now)
  return record.quiet_at ~= nil and now >= record.quiet_at
end

--- Whether the agent of `record` has walked out, quiet, by `now`: it went
--- quiet `timing.LEAVING_LISTED_SECONDS` ago or more.
---
---@param record aineo.office_states.Record
---@param now number
---@return boolean
local function has_walked_out_quiet(record, now)
  return record.quiet_at ~= nil and now >= record.quiet_at + timing.LEAVING_LISTED_SECONDS
end

--- How many of `records` are subagents that have neither finished nor gone
--- quiet by `now`.
---
---@param records aineo.office_states.Record[]
---@param now number
---@return integer
local function count_running_subagents(records, now)
  return #vim.tbl_filter(function(record)
    return record.id ~= record_module.MAIN and not record.finished and not is_quiet(record, now)
  end, records)
end

--- `action` as a function that runs it the first time and does nothing after.
---
---@param action? fun()
---@return fun()
local function once(action)
  local done = false
  return function()
    if not done and action then
      done = true
      action()
    end
  end
end

--- A tracker that knows the main agent, standing, and every other agent once a
--- signal names it.
---
--- Signals of the transcript's kinds are those of `aineo.transcript`; the
--- office adds `session_started` and `session_ended` for the main agent's
--- session, and `permission_asked` for the agent that asked.
---
--- A subagent goes quiet when it is heard of not at all for
--- `timing.QUIET_SUBAGENT_SECONDS`, unless the main agent's call that started
--- it still runs or it waits for permission: it then leaves, and is listed no
--- more once it has walked out. A replayed subagent whose transcript was last
--- written that long ago (`options.wall_clock`) is not listed at all. Either
--- walks in again with the next signal heard of it as it happens.
---
---@param options? aineo.office_states.TrackerOptions
---@return aineo.office_states.Tracker tracker
function M.new_tracker(options)
  options = options or {}
  ---@type aineo.office_states.Settings
  local settings = {
    report_tool = options.report_tool,
    commands = options.commands,
    triggers = options.triggers,
    trigger_budget = options.clock and {
      clock = options.clock,
      seconds = timing.TRIGGER_SECONDS,
      on_late = once(options.on_slow_triggers),
    } or nil,
  }

  ---@type aineo.office_states.Record[]
  local records
  ---@type table<string, aineo.office_states.Record>
  local by_id
  ---@type table<string, true>
  local gone
  ---@type table<string, aineo.office_states.Rest> the subagents left out for being quiet, until a line of theirs is heard
  local resting

  local function start_over()
    records, by_id, gone, resting = {}, {}, {}, {}
  end

  --- How many seconds before now, on the wall, the replayed `signal` says its
  --- subagent's transcript was last written; 0 when the tracker has no wall
  --- clock or the signal does not say.
  ---
  ---@param signal aineo.transcript.Signal a `subagent_started` signal
  ---@return number
  local function seconds_since_written(signal)
    if not (options.wall_clock and signal.written_at) then
      return 0
    end
    return math.max(0, options.wall_clock() - signal.written_at)
  end

  --- Whether the main agent's call `call` has started and not finished: the
  --- session's agent still waits on the subagent that call started.
  ---
  ---@param call string|nil
  ---@return boolean
  local function main_agent_runs(call)
    local main = by_id[record_module.MAIN]
    return call ~= nil and main ~= nil and main.open_calls[call] ~= nil
  end

  --- Whether `signal` is replayed and tells of before `options.forgotten_before`:
  --- the arrival of a subagent whose transcript was last written before it,
  --- or a line stamped before it, or not stamped.
  ---
  ---@param signal aineo.transcript.Signal
  ---@return boolean
  local function replays_what_was_forgotten(signal)
    if not (signal.replayed and options.forgotten_before) then
      return false
    end
    local when = signal.kind == 'subagent_started' and signal.written_at or signal.at
    return when == nil or when < options.forgotten_before
  end

  --- Whether `signal` replays the arrival of a subagent that has been quiet
  --- for `timing.QUIET_SUBAGENT_SECONDS` and that no call of the main agent
  --- still runs, which the office leaves out.
  ---
  ---@param signal aineo.transcript.Signal
  ---@return boolean
  local function replays_a_quiet_arrival(signal)
    return signal.kind == 'subagent_started'
      and signal.replayed == true
      and seconds_since_written(signal) >= timing.QUIET_SUBAGENT_SECONDS
      and not main_agent_runs(signal.call)
  end

  ---@param id string
  ---@return aineo.office_states.Record
  local function record_of(id)
    if not by_id[id] then
      by_id[id] = record_module.new(id)
      table.insert(records, by_id[id])
    end
    return by_id[id]
  end

  --- Forgets the agents that left long enough ago: those that finished, which
  --- are gone for good, and those that went quiet, which rest until a line of
  --- theirs is heard.
  ---
  ---@param now number
  local function forget_agents_that_left(now)
    records = vim.tbl_filter(function(record)
      local finished = record.listed_until and now >= record.listed_until
      local walked_out = has_walked_out_quiet(record, now)
      if finished or walked_out then
        by_id[record.id] = nil
        gone[record.id] = finished or nil
        resting[record.id] = walked_out
            and {
              started_by = record.started_by,
              open_calls = record.open_calls,
              started_calls = record.started_calls,
            }
          or nil
      end
      return not (finished or walked_out)
    end, records)
  end

  --- When the agent of `record` goes quiet: `timing.QUIET_SUBAGENT_SECONDS`
  --- after it was last heard of; never for the main agent, an agent that
  --- finished or waits for permission, or a subagent whose starting call the
  --- main agent still runs.
  ---
  ---@param record aineo.office_states.Record
  ---@return number|nil
  local function quiet_at(record)
    if
      record.id == record_module.MAIN
      or record.finished
      or record.permission_asked_at
      or main_agent_runs(record.started_by)
    then
      return nil
    end
    return record.heard_at + timing.QUIET_SUBAGENT_SECONDS
  end

  --- When the last subagent that has gone quiet by `now` went quiet; nil when
  --- none has.
  ---
  ---@param now number
  ---@return number|nil
  local function last_gone_quiet(now)
    local last = nil
    for _, record in ipairs(records) do
      if is_quiet(record, now) then
        last = math.max(last or record.quiet_at, record.quiet_at)
      end
    end
    return last
  end

  --- `record` as it stands at `now`: itself, or, when subagents that went
  --- quiet since its facts were last given change what they give, a view of
  --- it whose facts are those of `now`, from when the last of them went quiet.
  --- Asked at any time, in any order: it changes nothing.
  ---
  ---@param record aineo.office_states.Record
  ---@param now number
  ---@param running_subagents integer how many subagents run at `now` (`count_running_subagents()`)
  ---@return aineo.office_states.Record
  local function as_of(record, now, running_subagents)
    local state, activity = record_module.fact_state(record, running_subagents)
    if state == record.fact.state and activity == record.fact.activity then
      return record
    end
    local since = math.max(record.fact.since, last_gone_quiet(now) or record.fact.since)
    return setmetatable(
      { fact = { state = state, activity = activity, since = since } },
      { __index = record }
    )
  end

  --- Gives every record the state its facts give now, remembering since when,
  --- and when it goes quiet.
  ---
  ---@param now number
  local function refresh_facts(now)
    local running_subagents = count_running_subagents(records, now)
    for _, record in ipairs(records) do
      record.quiet_at = quiet_at(record)
      local state, activity = record_module.fact_state(record, running_subagents)
      if state ~= record.fact.state or activity ~= record.fact.activity then
        record.fact = { state = state, activity = activity, since = now }
      end
    end
  end

  --- Brings every agent to the state it wants to show, with no dwell.
  ---
  ---@param now number
  local function show_at_once(now)
    for _, record in ipairs(records) do
      record.shown = display.shown_at_once(record, now)
    end
  end

  --- Notes, on the record of the agent that gave `signal`, when it was last
  --- heard of on the tracker's clock: at `now` for a signal heard as it
  --- happens; for the replayed arrival of a subagent, when its transcript was
  --- last written; a replayed line of an agent already heard of changes
  --- nothing. A subagent's arrival also tells which call started it.
  ---
  ---@param record aineo.office_states.Record
  ---@param signal aineo.transcript.Signal
  ---@param now number
  local function note_when_heard(record, signal, now)
    if signal.kind == 'subagent_started' then
      record.started_by = signal.call
      record.heard_at = now - (signal.replayed and seconds_since_written(signal) or 0)
    elseif not signal.replayed or not record.heard_at then
      record.heard_at = now
    end
  end

  --- Lets the agent that gave `signal` hear it, at `now`; when it ends the
  --- main agent's work, the agents heard of only by their permission requests
  --- leave: nothing else will ever tell they are over.
  ---
  ---@param signal aineo.transcript.Signal
  ---@param now number
  local function let_hear(signal, now)
    local hearing = { now = now, replayed = signal.replayed == true, settings = settings }
    local hearer = record_of(signal.agent)
    note_when_heard(hearer, signal, now)
    record_module.hear(hearer, signal, hearing)
    if signal.agent == record_module.MAIN and ENDS_THE_MAIN_AGENTS_WORK[signal.kind] then
      for _, record in ipairs(records) do
        if record_module.is_known_only_by_permission(record) then
          record_module.hear(record, { agent = record.id, kind = 'subagent_finished' }, hearing)
        end
      end
    end
    refresh_facts(now)
    if signal.replayed then
      show_at_once(now)
    end
  end

  --- Whether `signal` is of a subagent the office leaves out: one that rests,
  --- having gone quiet, as the replayed arrival of a quiet subagent makes it,
  --- or as a replayed signal of what came before `options.forgotten_before`
  --- does (`replays_what_was_forgotten()`), which is left out for the main
  --- agent too.
  --- A signal heard as it happens ends the rest: the subagent walks in again,
  --- as if it arrived, with the main agent's call that started it and the
  --- calls of its own that ran as it walked out, before it hears the signal;
  --- the end of the subagent has it gone for good instead.
  ---
  ---@param signal aineo.transcript.Signal
  ---@param now number
  ---@return boolean
  local function stays_out(signal, now)
    local rest = resting[signal.agent]
    if replays_what_was_forgotten(signal) then
      if signal.agent ~= record_module.MAIN then
        resting[signal.agent] = { started_by = signal.call or (rest and rest.started_by) }
      end
      return true
    end
    if replays_a_quiet_arrival(signal) then
      rest = { started_by = signal.call }
      resting[signal.agent] = rest
    end
    if not rest then
      return false
    end
    if signal.replayed then
      return true
    end
    resting[signal.agent] = nil
    if signal.kind == 'subagent_finished' then
      gone[signal.agent] = true
      return true
    end
    if signal.kind ~= 'subagent_started' then
      let_hear({ agent = signal.agent, kind = 'subagent_started', call = rest.started_by }, now)
      local walked_in = by_id[signal.agent]
      walked_in.open_calls = rest.open_calls or {}
      walked_in.started_calls = rest.started_calls or 0
    end
    return false
  end

  start_over()
  record_of(record_module.MAIN)

  return {
    take = function(signal, now)
      vim.validate('now', now, 'number')
      vim.validate('signal.agent', signal.agent, 'string')
      if signal.kind == 'session_started' then
        start_over()
        let_hear(signal, now)
        return
      end
      forget_agents_that_left(now)
      if gone[signal.agent] or not record_module.hears(signal.kind) then
        return
      end
      if stays_out(signal, now) then
        return
      end
      local running_subagents = count_running_subagents(records, now)
      for _, record in ipairs(records) do
        record.shown = display.shown_at(as_of(record, now, running_subagents), now)
      end
      let_hear(signal, now)
    end,

    agents = function(now)
      local agents = {}
      local running_subagents = count_running_subagents(records, now)
      for _, record in ipairs(records) do
        local listed = (not record.listed_until or now < record.listed_until)
          and not has_walked_out_quiet(record, now)
        if listed then
          local shown = display.shown_at(as_of(record, now, running_subagents), now)
          local since = shown.since ~= timing.BEFORE_THE_TRACKER and shown.since or nil
          table.insert(agents, {
            id = record.id,
            state = shown.state,
            activity = shown.activity,
            since = since,
            details = details.of(record),
            after_call = after_call(record, shown, now),
          })
        end
      end
      return agents
    end,
  }
end

return M
