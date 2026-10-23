--- What an agent's record knows about the world it works in, beyond its
--- state: the details the office draws into the pieces that show them. Pure.

local record_module = require('aineo.office_states.record')

local M = {}

---@class aineo.office_states.AgentDetails
---@field tasks aineo.office_states.Task[] the agent's tasks, in order; none when it keeps none. Not to be changed by the caller
---@field web_clue? string what the call the agent started last, still running, looks for on the web
---@field test_verdict? aineo.office_states.TestVerdict how the agent's last test run ended, until it starts another
---@field reported_at? number when the agent last called aineo's report tool, on the caller's clock; none for a report read from the past

--- The details `record` gives of its agent.
---
---@param record aineo.office_states.Record
---@return aineo.office_states.AgentDetails
function M.of(record)
  local call = record_module.latest_open_call(record)
  return {
    tasks = record.tasks,
    web_clue = call and call.clue,
    test_verdict = record.test_verdict,
    reported_at = record.reported_at,
  }
end

return M
