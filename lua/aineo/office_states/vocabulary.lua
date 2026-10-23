--- The office's vocabulary of states: the names a pack can draw, and the state
--- each falls back to when a pack draws nothing for it. Pure data and its
--- reading.
---
--- Four parents, `standing`, `working`, `waiting` and `resting`, are no state
--- of an agent's life: a pack that draws five poses covers every state
--- through them. The 24 states are numbered; every chain of fallbacks ends at
--- `standing`.

local M = {}

---@class aineo.office_states.State
---@field number? integer the state's number among the 24; none for a parent
---@field name string the state's name, as a pack names it
---@field label string what the status list says while an agent is in the state
---@field fallback? string the state whose drawing a pack that draws nothing for this one uses; none for the root

---@type aineo.office_states.State[]
local STATES = {
  { name = 'standing', label = 'standing' },
  { name = 'working', label = 'working', fallback = 'standing' },
  { name = 'waiting', label = 'waiting', fallback = 'standing' },
  { name = 'resting', label = 'resting', fallback = 'standing' },
  { number = 1, name = 'arriving', label = 'arriving', fallback = 'standing' },
  { number = 2, name = 'getting_a_task', label = 'getting a task', fallback = 'thinking' },
  { number = 3, name = 'thinking', label = 'thinking', fallback = 'working' },
  { number = 4, name = 'planning', label = 'planning', fallback = 'thinking' },
  { number = 5, name = 'reading', label = 'reading', fallback = 'working' },
  { number = 6, name = 'searching', label = 'searching', fallback = 'reading' },
  { number = 7, name = 'writing_code', label = 'writing code', fallback = 'working' },
  {
    number = 8,
    name = 'running_a_command',
    label = 'running a command',
    fallback = 'writing_code',
  },
  { number = 9, name = 'running_tests', label = 'running tests', fallback = 'running_a_command' },
  {
    number = 10,
    name = 'background_job',
    label = 'running a background job',
    fallback = 'running_a_command',
  },
  { number = 11, name = 'on_the_web', label = 'on the web', fallback = 'reading' },
  { number = 12, name = 'delegating', label = 'delegating', fallback = 'working' },
  {
    number = 13,
    name = 'waiting_for_subagents',
    label = 'waiting for subagents',
    fallback = 'waiting',
  },
  { number = 14, name = 'needs_permission', label = 'needs permission', fallback = 'waiting' },
  { number = 15, name = 'asking_you', label = 'asking you', fallback = 'waiting' },
  { number = 16, name = 'reporting', label = 'reporting', fallback = 'working' },
  { number = 17, name = 'committing', label = 'committing', fallback = 'running_a_command' },
  { number = 18, name = 'compacting', label = 'compacting', fallback = 'working' },
  { number = 19, name = 'error', label = 'hit an error', fallback = 'standing' },
  { number = 20, name = 'interrupted', label = 'interrupted', fallback = 'error' },
  { number = 21, name = 'done', label = 'done', fallback = 'resting' },
  { number = 22, name = 'idle', label = 'idle', fallback = 'resting' },
  { number = 23, name = 'asleep', label = 'asleep', fallback = 'idle' },
  { number = 24, name = 'leaving', label = 'leaving', fallback = 'standing' },
}

--- The four parents and the 24 states, each with its label and the state it
--- falls back to.
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
