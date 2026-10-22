--- A pack's custom triggers: a match on a tool call that names the activity an
--- agent plays while the call runs, in place of the activity its state gives.
--- Pure; a trigger costs a string match on a signal already read.

local matching = require('aineo.office_states.matching')

local M = {}

--- The kind of agent that makes a call, for a trigger's `agent` field.
---@alias aineo.office_states.AgentKind 'main'|'subagent'

--- One trigger of a pack.
---@class aineo.office_states.Trigger
---@field when table<string, aineo.office_states.Rule> the call it matches: `tool`, `agent`, and any field of the tool's input by its own name; every field must match
---@field play string the activity played while the call runs

--- The value of the field `name` of the call `signal` carries: its tool, the
--- kind of agent that makes it, or a field of the tool's input.
---
---@param signal aineo.transcript.Signal a `tool_started` signal
---@param agent_kind aineo.office_states.AgentKind
---@param name string
---@return any
local function field_of_call(signal, agent_kind, name)
  if name == 'tool' then
    return signal.tool
  elseif name == 'agent' then
    return agent_kind
  end
  return (signal.input or {})[name]
end

--- Whether the call matches `trigger`: it has a `when` with at least one field
--- and a `play`, and every field of the `when` matches.
---
---@param trigger any
---@param signal aineo.transcript.Signal
---@param agent_kind aineo.office_states.AgentKind
---@return boolean
local function matches_call(trigger, signal, agent_kind)
  if
    type(trigger) ~= 'table'
    or type(trigger.when) ~= 'table'
    or type(trigger.play) ~= 'string'
  then
    return false
  end
  if next(trigger.when) == nil then
    return false
  end
  for name, rule in pairs(trigger.when) do
    if not matching.matches(rule, field_of_call(signal, agent_kind, name)) then
      return false
    end
  end
  return true
end

--- The activity the first of `triggers`, in order, that matches the call
--- `signal` starts names; none when none matches.
---
---@param signal aineo.transcript.Signal a `tool_started` signal
---@param agent_kind aineo.office_states.AgentKind
---@param triggers aineo.office_states.Trigger[]
---@return string|nil activity
function M.activity_of_call(signal, agent_kind, triggers)
  for _, trigger in ipairs(triggers) do
    if matches_call(trigger, signal, agent_kind) then
      return trigger.play
    end
  end
  return nil
end

return M
