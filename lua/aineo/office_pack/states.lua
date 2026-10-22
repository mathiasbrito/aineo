--- What a pack plays in each state of the office's vocabulary: the activity a
--- pack maps to a state, or the one of the first state it falls back to that
--- the pack maps.

local office_states = require('aineo.office_states')

local M = {}

--- The names of the states of the vocabulary.
---
---@return string[]
function M.names()
  return vim.tbl_map(function(state)
    return state.name
  end, office_states.vocabulary())
end

--- The activity each state of the vocabulary plays, from `states`, the
--- activities the pack maps to states.
---
--- `nil` when `states` map nothing to `standing`, which every state falls
--- back to in the end.
---
---@param states table<string, string>
---@return table<string, string>|nil state_activity
function M.activities(states)
  local state_activity = {}
  for _, state in ipairs(office_states.vocabulary()) do
    for _, name in ipairs(office_states.fallback_chain(state.name)) do
      if states[name] then
        state_activity[state.name] = states[name]
        break
      end
    end
  end
  return state_activity.standing and state_activity or nil
end

return M
