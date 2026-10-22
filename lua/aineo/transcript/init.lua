--- Claude Code's transcript of a session as a stream of signals, `require('aineo.transcript')`.
---
--- A signal is a record in plain words of what an agent did (`signals_of_line()`
--- lists their kinds). `follow()` reads them from a transcript file as Claude
--- Code writes it; `signals_of_line()` is the codec, public because the
--- recorded transcripts pin it.

local follower = require('aineo.transcript.follower')
local signals = require('aineo.transcript.signals')

local M = {}

M.follow = follower.follow
M.signals_of_line = signals.signals_of_line

return M
