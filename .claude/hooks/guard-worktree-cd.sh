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
# What it reads: a `cd` or `pushd` written with `.claude/worktrees` in its
# argument, at command position — after a separator, or after the shell's own
# prefix words (`{`, `!`, `if`, `then`, `do`, `builtin`, `command`, `time` …).
# Heredoc bodies and quoted strings are prose and are dropped first, across
# lines; a `cd`'s own quoted argument is kept; parenthesised groups, which run
# in a subshell, are dropped. What it cannot see: a directory reached through
# a variable, a symlink, `CDPATH`, `..`, or two `cd`s in turn.
#
# Subagents are not refused: each runs in its own worktree. The hook input
# names a subagent by `agent_id`.
#
# Runs as a Claude Code PreToolUse hook on Bash. Reads the tool call as JSON
# on stdin and emits a permission decision as JSON on stdout.
set -uo pipefail

payload=$(cat)
command=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -z "$command" ] && exit 0

agent=$(printf '%s' "$payload" | jq -r '.agent_id // empty' 2>/dev/null)
[ -n "$agent" ] && exit 0

deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# Prints stdin without the bodies of its heredocs (`<<EOF`, `<<-EOF`, `<<'EOF'`),
# keeping each line that opens one.
without_heredoc_bodies() {
  awk '
    delim != "" { line = $0; if (tabs) sub(/^\t+/, "", line); if (line == delim) delim = ""; next }
    { print
      if (match($0, /(^|[^<])<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*["\047]?/)) {
        head = substr($0, RSTART, RLENGTH); sub(/^[^<]?<</, "", head)
        tabs = (head ~ /^-/); sub(/^-?[ \t]*/, "", head); gsub(/["\047]/, "", head); delim = head
      } }'
}

# Prints stdin with the contents of every quoted string removed, reading
# single and double quotes left to right across lines and a backslash as an
# escape, so an apostrophe inside double quotes opens nothing.
blank_quoted_strings() {
  awk '
    { text = text (NR > 1 ? "\n" : "") $0 }
    END {
      n = length(text); quote = ""; out = ""
      for (i = 1; i <= n; i++) {
        c = substr(text, i, 1)
        if (quote == "") {
          if (c == "\\") { out = out substr(text, i, 2); i++; continue }
          if (c == "\047" || c == "\"") quote = c
          out = out c
        } else if (c == "\\" && quote == "\"") {
          i++
        } else if (c == quote) {
          quote = ""; out = out c
        }
      }
      printf "%s", out
    }'
}

# A cd's own quoted argument is kept; every other quoted string is blanked.
shape=$(printf '%s\n' "$command" \
  | without_heredoc_bodies \
  | sed -E "s/(cd|pushd)([[:space:]]+)\"([^\"]*)\"/\1\2\3/g; s/(cd|pushd)([[:space:]]+)'([^']*)'/\1\2\3/g" \
  | blank_quoted_strings)

# A cd inside a subshell moves only the subshell: drop every parenthesised
# group, innermost first and across lines, until none is left.
previous=''
while [ "$shape" != "$previous" ]; do
  previous=$shape
  shape=$(printf '%s' "$shape" | tr '\n' '\036' | sed -E 's/\([^()]*\)//g' | tr '\036' '\n')
done

if printf '%s' "$shape" | grep -Eq '(^|[;&|]|&&|\|\|)[[:space:]]*(([{!]|if|then|else|elif|do|while|until|time|builtin|command)[[:space:]]+)*(cd|pushd)[[:space:]]+[^;&|]*\.claude/worktrees(/|[[:space:];&|]|$)'; then
  deny "Blocked: a bare cd into .claude/worktrees/ moves this session's working directory into that worktree for every later command. Run it in a subshell — (cd <path> && …) — or use git -C <path> / make -C <path>."
fi
exit 0
