--- Claude Code's transcript of a session as a stream of signals, `require('aineo.transcript')`.
---
--- A signal is a record in plain words of what an agent did (`signals_of_line()`
--- lists their kinds). `follow()` reads them from a session's transcript, and
--- from those of its subagents, as Claude Code writes them, and goes on in the
--- transcript of the session a session's transcript says it was continued in;
--- `signals_of_line()` is the codec, public because the recorded transcripts
--- pin it.

local follower = require('aineo.transcript.follower')
local signals = require('aineo.transcript.signals')

local M = {}

M.follow = follower.follow
M.signals_of_line = signals.signals_of_line

return M
