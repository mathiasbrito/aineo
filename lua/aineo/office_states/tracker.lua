--- The tracker of `aineo.office_states`: the state of each agent, kept from the
--- signals the agent gave. Pure: it reads no clock and no editor state; the
--- caller says what time it is.

local calls = require('aineo.office_states.calls')

local M = {}

--- The id a tool call without one is kept under.
local UNNAMED_CALL = ''

--- What the tracker is told about the office it keeps.
---@class aineo.office_states.TrackerOptions
---@field report_tool? string the name of aineo's report tool, as Claude Code calls it (`mcp__<server>__<tool>`); none when the office is told of none
---@field commands? aineo.office_states.CommandClasses the classes of shell commands (`office.commands`); none when the office is told of none, and every command is then a command run

---@class aineo.office_states.Agent
---@field id string 'main', or a subagent's id
---@field state string a state of the vocabulary
---@field since? number when the agent came into its state, on the caller's clock; none for an agent that has been in it since the tracker was made

---@class aineo.office_states.Tracker
---@field take fun(signal: aineo.transcript.Signal, now: number) takes in what an agent did, heard at `now`, in seconds on the caller's clock
---@field agents fun(now: number): aineo.office_states.Agent[] each agent and its state at `now`, the main agent first, the others in the order they were first heard of

--- A tool call that started and has not finished.
---@class aineo.office_states.OpenCall
---@field state string the state of an agent while the call runs
---@field order integer how many calls the agent had started when this one did

--- What the tracker knows of one agent.
---@class aineo.office_states.Record
---@field id string
---@field open_calls table<string, aineo.office_states.OpenCall> the tool calls that started and have not finished, by call id
---@field started_calls integer how many tool calls the agent has started
---@field thinking boolean whether the model is at work on what it was given: a result, since the last call started
---@field turn_ended boolean whether its last turn ended and nothing began since
---@field state string
---@field since? number

---@param id string
---@return aineo.office_states.Record
local function new_record(id)
  return {
    id = id,
    open_calls = {},
    started_calls = 0,
    thinking = false,
    turn_ended = false,
    state = 'standing',
  }
end

--- The call `record` started last of those still running; none when none runs.
---
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

--- The state the facts of `record` give: the state of the call started last
--- while a tool call runs, thinking while the model works on a result, idle
--- once its turn ended, standing otherwise.
---
---@param record aineo.office_states.Record
---@return string state
local function state_from_facts(record)
  local call = latest_open_call(record)
  if call then
    return call.state
  end
  if record.thinking then
    return 'thinking'
  end
  if record.turn_ended then
    return 'idle'
  end
  return 'standing'
end

---@param settings aineo.office_states.CallSettings
---@return fun(record: aineo.office_states.Record, signal: aineo.transcript.Signal)
local function opening_call(settings)
  return function(record, signal)
    local id = signal.call or UNNAMED_CALL
    record.turn_ended = false
    record.thinking = false
    if not record.open_calls[id] then
      record.started_calls = record.started_calls + 1
      record.open_calls[id] = {
        state = calls.state_of_call(signal, settings),
        order = record.started_calls,
      }
    end
  end
end

--- Closes the call `signal` names; a call that was not open changes nothing.
---
---@param record aineo.office_states.Record
---@param signal aineo.transcript.Signal
local function close_call(record, signal)
  local id = signal.call or UNNAMED_CALL
  if record.open_calls[id] then
    record.open_calls[id] = nil
    record.thinking = true
  end
end

--- Ends the agent's turn: no call is running any more, whatever was started.
---
---@param record aineo.office_states.Record
local function end_turn(record)
  record.open_calls = {}
  record.thinking = false
  record.turn_ended = true
end

--- What a signal does to the record of the agent that gave it, by the signal's kind.
---
---@param settings aineo.office_states.CallSettings
---@return table<aineo.transcript.SignalKind, fun(record: aineo.office_states.Record, signal: aineo.transcript.Signal)>
local function takes_for(settings)
  return {
    tool_started = opening_call(settings),
    tool_finished = close_call,
    turn_ended = end_turn,
  }
end

--- A tracker that knows the main agent, standing, and every other agent once a
--- signal names it.
---
---@param options? aineo.office_states.TrackerOptions
---@return aineo.office_states.Tracker tracker
function M.new_tracker(options)
  options = options or {}
  local takes = takes_for({ report_tool = options.report_tool, commands = options.commands })
  local records = {}
  local by_id = {}

  ---@param id string
  ---@return aineo.office_states.Record
  local function record_of(id)
    if not by_id[id] then
      by_id[id] = new_record(id)
      table.insert(records, by_id[id])
    end
    return by_id[id]
  end

  record_of('main')

  return {
    take = function(signal, now)
      local take = takes[signal.kind]
      if not take then
        return
      end
      local record = record_of(signal.agent)
      take(record, signal)
      local state = state_from_facts(record)
      if state ~= record.state then
        record.state = state
        record.since = now
      end
    end,
    agents = function()
      return vim.tbl_map(function(record)
        return { id = record.id, state = record.state, since = record.since }
      end, records)
    end,
  }
end

return M
