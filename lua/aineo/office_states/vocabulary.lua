--- The office's vocabulary of states: the names a pack can draw, and the state
--- each falls back to when a pack draws nothing for it. Pure data and its
--- reading.

local M = {}

---@class aineo.office_states.State
---@field name string the state's name
---@field fallback? string the state whose drawing a pack that draws nothing for this one uses; none for the root

--- The states, parents before the states that fall back to them.
---@type aineo.office_states.State[]
local STATES = {
  { name = 'standing' },
  { name = 'working', fallback = 'standing' },
  { name = 'resting', fallback = 'standing' },
  { name = 'idle', fallback = 'resting' },
}

--- The states of the vocabulary, each with the state it falls back to.
---
---@return aineo.office_states.State[] states
function M.vocabulary()
  return vim.deepcopy(STATES)
end

--- The state `name` followed by the states it falls back to, in turn, down to
--- the root; none when `name` is no state of the vocabulary.
---
---@param name string
---@return string[] chain
function M.fallback_chain(name)
  local by_name = {}
  for _, state in ipairs(STATES) do
    by_name[state.name] = state
  end
  local chain = {}
  local state = by_name[name]
  while state do
    table.insert(chain, state.name)
    state = state.fallback and by_name[state.fallback]
  end
  return chain
end

return M
