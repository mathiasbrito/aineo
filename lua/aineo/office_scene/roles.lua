--- The role of an agent in its pack's office: which kind of character it is,
--- and which activity it plays.

local M = {}

--- The id of the main agent; every other agent is a subagent.
local MAIN_AGENT = 'main'

--- The state of an agent that has nothing to do.
local IDLE_STATE = 'idle'

--- The states of an agent that is coming in or going out.
local ENTRANCE_STATES = { arriving = true, leaving = true }

--- Whether `agent` has nothing to do: it is in the state `idle`.
---
---@param agent { state: string }
---@return boolean
function M.is_idle(agent)
  return agent.state == IDLE_STATE
end

--- Whether `agent` is neither arriving nor leaving: it is in the office, and
--- may be sent to do something.
---
---@param agent { state: string }
---@return boolean
function M.is_settled_in(agent)
  return not ENTRANCE_STATES[agent.state]
end

--- The kind of character `agent` is drawn as: the agent for the main agent,
--- the subagent for the others.
---
---@param agent aineo.office_states.Agent
---@return string kind 'agent' or 'subagent'
function M.kind_of(agent)
  return agent.id == MAIN_AGENT and 'agent' or 'subagent'
end

--- The activity `agent` plays: the one a trigger chose when the pack has it;
--- otherwise, while it thinks right after a call (`after_call`), that call's
--- state's, so that it stays where the call took it; otherwise its state's,
--- otherwise standing's.
---
---@param pack aineo.office_pack.Pack
---@param agent aineo.office_states.Agent
---@return string|nil name
---@return table|nil activity
function M.activity_of(pack, agent)
  local name = agent.activity
  if not (name and pack.activities[name]) then
    name = pack.state_activity[agent.after_call]
      or pack.state_activity[agent.state]
      or pack.state_activity.standing
  end
  return name, pack.activities[name]
end

return M
