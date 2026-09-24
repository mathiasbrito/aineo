#!/bin/sh
# A stand-in for a hung `claude`, which the suites run in its place through
# `claude.cmd` as `sh tests/helpers/fake_claude_deaf.sh [arguments]` in a
# terminal: it puts its terminal in raw mode, as tests/helpers/fake_claude.lua
# does, then ignores every key, the hangup and SIGTERM, as a process whose
# event loop is stuck would, so only a SIGKILL ends it — or itself, after
# LIFETIME seconds, so that none outlives a failed test for long. It is POSIX
# sh because a Neovim running a script (`nvim -l`) exits on a hangup whatever
# the script's own handler does.
#
# It appends to the record file AINEO_FAKE_CLAUDE_RECORD, one JSON object per
# line, less than tests/helpers/fake_claude.lua records: `{"argv":[],"pid":<pid>}`
# when it starts — an empty list, not its arguments — and
# `{"received":"\u0003"}` for each Ctrl-C it receives; the other bytes it
# reads and drops unrecorded.

record=${AINEO_FAKE_CLAUDE_RECORD:?AINEO_FAKE_CLAUDE_RECORD is unset}
LIFETIME=60

trap '' HUP TERM INT
stty raw -echo
printf '{"argv":[],"pid":%d}\n' "$$" >>"$record"
(sleep "$LIFETIME" && kill -KILL "$$") &

while byte=$(dd bs=1 count=1 2>/dev/null | od -An -tu1) && [ -n "$byte" ]; do
  if [ "$byte" -eq 3 ]; then
    printf '{"received":"\\u0003"}\n' >>"$record"
  fi
done

while :; do
  sleep 1
done
