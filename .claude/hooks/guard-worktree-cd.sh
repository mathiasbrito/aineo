#!/usr/bin/env bash
# Refuses a bare `cd` or `pushd` into an agent worktree from the session.
#
# The Bash tool keeps the session's working directory from one call to the
# next, so `cd .claude/worktrees/<name> && …` at the top of a command moves the
# session into that worktree for every later call — and an agent dispatched
# from there gets its worktree created inside the wrong checkout. A subshell,
# `(cd <path> && …)`, or `git -C <path>` / `make -C <path>` does the same work
# and leaves the session where it was.
#
# Subagents are not refused: each runs in its own worktree, and moving within
# it is its own affair. The hook input names a subagent caller.
#
# Runs as a Claude Code PreToolUse hook on Bash. Reads the tool call as JSON
# on stdin and emits a permission decision as JSON on stdout.
set -uo pipefail

payload=$(cat)
command=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -z "$command" ] && exit 0

agent=$(printf '%s' "$payload" | jq -r '.agent_type // .agent_id // empty' 2>/dev/null)
[ -n "$agent" ] && exit 0

deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# The directory a cd names may be quoted; every other quoted string is prose
# and is blanked, so a cd written inside a message is never read as one.
shape=$(printf '%s' "$command" \
  | sed -E "s/(cd|pushd)([[:space:]]+)\"([^\"]*)\"/\1\2\3/g; s/(cd|pushd)([[:space:]]+)'([^']*)'/\1\2\3/g" \
  | sed "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g")

# A cd inside a subshell moves only the subshell: drop every parenthesised
# group, innermost first, until none is left.
previous=''
while [ "$shape" != "$previous" ]; do
  previous=$shape
  shape=$(printf '%s' "$shape" | sed -E 's/\([^()]*\)//g')
done

if printf '%s' "$shape" | grep -Eq '(^|[;&|]|&&|\|\|)[[:space:]]*(cd|pushd)[[:space:]]+[^;&|]*\.claude/worktrees(/|[[:space:];&|]|$)'; then
  deny "Blocked: a bare cd into .claude/worktrees/ moves this session's working directory into that worktree for every later command. Run it in a subshell — (cd <path> && …) — or use git -C <path> / make -C <path>."
fi
exit 0
