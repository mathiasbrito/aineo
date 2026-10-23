--- What each agent of the office is doing, as a state of a published
--- vocabulary, `require('aineo.office_states')`. Pure: it is given signals, the
--- time, the classes of commands and the pack's triggers, and reads nothing
--- else.
---
--- `vocabulary()` lists the four parents and the 24 states with what each
--- falls back to, and `fallback_chain()` follows those fallbacks;
--- `new_tracker()` keeps every agent's state, and the activity a trigger names
--- for it, from the signals `aineo.transcript` gives and the few the office
--- adds (`aineo.office_states.OfficeSignalKind`). Each agent it lists carries
--- details of what it works on (`aineo.office_states.AgentDetails`): its
--- tasks, what it looks up on the web, how its last test run ended and when it
--- last reported.

local tracker = require('aineo.office_states.tracker')
local vocabulary = require('aineo.office_states.vocabulary')

local M = {}

M.vocabulary = vocabulary.vocabulary
M.fallback_chain = vocabulary.fallback_chain
M.new_tracker = tracker.new_tracker

return M
