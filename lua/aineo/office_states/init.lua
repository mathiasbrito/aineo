--- What each agent of the office is doing, as a state of a published
--- vocabulary, `require('aineo.office_states')`. Pure: it is given signals and
--- reads nothing else.
---
--- `vocabulary()` lists the states and what each falls back to;
--- `new_tracker()` keeps every agent's state from the signals
--- `aineo.transcript` gives.

local tracker = require('aineo.office_states.tracker')
local vocabulary = require('aineo.office_states.vocabulary')

local M = {}

M.vocabulary = vocabulary.vocabulary
M.fallback_chain = vocabulary.fallback_chain
M.new_tracker = tracker.new_tracker

return M
