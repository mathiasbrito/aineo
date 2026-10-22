--- The tracker of `aineo.office_states`: the state of each agent, kept from the
--- signals the agent gave. Pure: it reads no clock and no editor state.

local M = {}

--- The id a tool call without one is kept under.
local UNNAMED_CALL = ''

---@class aineo.office_states.Agent
---@field id string 'main', or a subagent's id
---@field state string a state of the vocabulary

---@class aineo.office_states.Tracker
---@field take fun(signal: aineo.transcript.Signal) takes in what an agent did
---@field agents fun(): aineo.office_states.Agent[] each agent and its state now, the main agent first, the others in the order they were first heard of

--- What the tracker knows of one agent.
---@class aineo.office_states.Record
---@field id string
---@field open_calls table<string, true> the tool calls that started and have not finished
---@field open_call_count integer
---@field turn_ended boolean whether its last turn ended and nothing began since

---@param id string
---@return aineo.office_states.Record
local function new_record(id)
  return { id = id, open_calls = {}, open_call_count = 0, turn_ended = false }
end

--- The state of the agent `record` describes: working while a tool call runs,
--- idle once its turn ended, standing otherwise.
---
---@param record aineo.office_states.Record
---@return string state
local function state_of(record)
  if record.open_call_count > 0 then
    return 'working'
  end
  if record.turn_ended then
    return 'idle'
  end
  return 'standing'
end

---@param record aineo.office_states.Record
---@param signal aineo.transcript.Signal
local function open_call(record, signal)
  local call = signal.call or UNNAMED_CALL
  record.turn_ended = false
  if not record.open_calls[call] then
    record.open_calls[call] = true
    record.open_call_count = record.open_call_count + 1
  end
end

--- Closes the call `signal` names; a call that was not open changes nothing.
---
---@param record aineo.office_states.Record
---@param signal aineo.transcript.Signal
local function close_call(record, signal)
  local call = signal.call or UNNAMED_CALL
  if record.open_calls[call] then
    record.open_calls[call] = nil
    record.open_call_count = record.open_call_count - 1
  end
end

--- Ends the agent's turn: no call is running any more, whatever was started.
---
---@param record aineo.office_states.Record
local function end_turn(record)
  record.open_calls = {}
  record.open_call_count = 0
  record.turn_ended = true
end

--- What a signal does to the record of the agent that gave it, by the signal's kind.
---@type table<aineo.transcript.SignalKind, fun(record: aineo.office_states.Record, signal: aineo.transcript.Signal)>
local TAKES = {
  tool_started = open_call,
  tool_finished = close_call,
  turn_ended = end_turn,
}

--- A tracker that knows the main agent, standing, and every other agent once a
--- signal names it.
---
---@return aineo.office_states.Tracker tracker
function M.new_tracker()
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
    take = function(signal)
      local take = TAKES[signal.kind]
      if take then
        take(record_of(signal.agent), signal)
      end
    end,
    agents = function()
      return vim.tbl_map(function(record)
        return { id = record.id, state = state_of(record) }
      end, records)
    end,
  }
end

return M
