#!/usr/bin/env bash
# Refuses `git commit` and `git push` that would land on a protected branch.
#
# The repository's rule: agents and people commit on release/, bugfix/,
# hotfix/, feature/, refactor/, knowledge/ or ai/ branches and open a pull
# request. `main` and `dev` are integration branches and are never written to
# directly.
#
# Two refusals besides the branch rule. A commit or push hidden behind a shell
# wrapper or a script file is refused because it cannot be judged — see
# command-shape.sh. And `gh pr merge` is refused when the tool call comes from
# a subagent, because merging is a decision left with the user.
#
# Runs as a Claude Code PreToolUse hook on Bash. Reads the tool call as JSON
# on stdin and emits a permission decision as JSON on stdout.
set -uo pipefail

PROTECTED='main|master|dev'
ALLOWED_PREFIXES='release/, bugfix/, hotfix/, feature/, refactor/, knowledge/, ai/'

payload=$(cat)
command=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -z "$command" ] && exit 0

# shellcheck source=command-shape.sh
. "$(dirname "$0")/command-shape.sh"

# Strip quoted strings so a branch name inside a commit message never matches.
deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# A write the scrubbing below would hide is refused before it is scrubbed.
if hidden_git_write "$command"; then
  deny "Blocked: this runs git commit or git push through a shell wrapper or a script, where the branch guard cannot see it. Run the git command directly."
fi

# Merging is the one action the orchestration design leaves with the user.
# The session may do it when the user delegates it; a subagent never does,
# and the hook input names the caller.
agent=$(printf '%s' "$payload" | jq -r '.agent_type // .agent_id // empty' 2>/dev/null)
if [ -n "$agent" ] && printf '%s' "$command" | grep -Eq '(^|[;&|(]|&&|\|\|)[[:space:]]*gh[[:space:]]+pr[[:space:]]+merge\b'; then
  deny "Blocked: a subagent does not merge pull requests. Report the pull request to the orchestrator; merging is the user's decision."
fi

scrubbed=$(printf '%s' "$command" | sed "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g")

# The subcommand must be a standalone word. \b is not enough: it treats the
# hyphen in `…-before-commit` as a boundary, so a branch name carrying the
# verb reads as the verb. The terminator admits a separator as well as
# whitespace, because `git commit; echo x` is still a commit.
is_commit=false; is_push=false
printf '%s' "$scrubbed" | grep -Eq '(^|[;&|(]|&&|\|\|)[[:space:]]*git\b[^;&|]*[[:space:]]commit([^[:alnum:]_/-]|$)' && is_commit=true
printf '%s' "$scrubbed" | grep -Eq '(^|[;&|(]|&&|\|\|)[[:space:]]*git\b[^;&|]*[[:space:]]push([^[:alnum:]_/-]|$)'   && is_push=true
$is_commit || $is_push || exit 0

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# A ref is matched whole, never as a word. `\b` treats `/` and `-` as
# boundaries, so `\bdev\b` finds `dev` inside `knowledge/dev-blogs-plan` and
# `main` inside `feature/maindeck`, and would refuse every push of a branch
# whose name merely contains a protected one. It is the same lesson the subcommand detection above already records, applied
# to the names instead of the verbs.
#
# A push target is a whole refspec argument, and what it writes is the half
# after the last colon: `dev`, `+dev`, `HEAD:dev`, `feature/x:dev`,
# `refs/heads/dev`, and `:dev`, which deletes it.
protected_ref() {
  printf '%s' "${1##*:}" \
    | sed 's/^[+^]*//; s#^refs/heads/##' \
    | grep -Eq "^($PROTECTED)$"
}

# The arguments every `git <verb>` in the command is given, one per line.
# Options are dropped, so `git push -u origin dev` yields `origin` and `dev`.
#
# The verb is anchored to a real git invocation at a command boundary, for the
# same reason the scrubber blanks quoted strings: a commit message is prose,
# not a command. Rich commit messages are written through a heredoc, which the
# scrubber cannot blank the way it blanks a quoted string, and an unanchored
# search reads a message line such as "refused to push it three times, while
# the dev blog was landing" as a push to `dev`.
#
# Every occurrence is judged, not the first: `git push origin feature/x && git
# push origin dev` pushes both, and reading only the first would wave the
# second through.
args_after() {
  printf '%s' "$scrubbed" \
    | grep -oE "(^|[;&|(]|&&|\|\|)[[:space:]]*git\b[^;&|]*[[:space:]]($1)([^[:alnum:]_/-][^;&|]*|$)" \
    | sed -E "s/.*[[:space:]]($1)//" \
    | tr ' \t' '\n\n' \
    | grep -vE '^-|^$'
}

# True when any argument the verb was given names a protected branch.
verb_names_protected() {
  local arg
  while IFS= read -r arg; do
    [ -n "$arg" ] && protected_ref "$arg" && return 0
  done <<EOF
$(args_after "$1")
EOF
  return 1
}

# A compound command that switches to a protected branch and then writes to it.
#
# `git checkout -b <new> dev` creates a branch FROM dev and is the sanctioned
# workflow — the branch you end up on is <new>, and the start point is
# irrelevant. So when the command creates a branch, judge the created name;
# only otherwise judge the checkout target. Without this the guard refuses its
# own recommended first step.
#
# Extraction uses grep, not sed: BSD sed on macOS has no \\b word boundary, and
# a pattern relying on it silently matches nothing rather than erroring.
created=$(printf '%s' "$scrubbed" \
  | grep -oE '(checkout|switch)[^;&|]*[[:space:]]-[bBcC][[:space:]]+[^[:space:]]+' \
  | awk '{print $NF}' | head -1)

if [ -n "$created" ]; then
  if printf '%s' "$created" | grep -Eq "^($PROTECTED)$"; then
    deny "Blocked: this command creates or resets '$created', a protected branch, and then commits or pushes. Work on a $ALLOWED_PREFIXES branch and open a pull request."
  fi
elif printf '%s' "$scrubbed" | grep -Eq "\bgit\b[^;&|]*\b(checkout|switch)\b" \
  && verb_names_protected 'checkout|switch'; then
  deny "Blocked: this command switches to a protected branch and then commits or pushes. This repository never writes directly to main or dev. Work on a $ALLOWED_PREFIXES branch and open a pull request."
fi

# Explicitly pushing a protected branch, from wherever you are.
if $is_push && verb_names_protected 'push'; then
  deny "Blocked: pushing directly to a protected branch (main/dev). Push a $ALLOWED_PREFIXES branch instead and open a pull request."
fi

# Creating a non-protected branch moves the work off the protected one before
# anything is written, so where HEAD happens to be right now is irrelevant.
# The explicit-push check above still applies, so a command that creates a
# branch and then pushes a protected one is caught.
if [ -n "$created" ] && ! printf '%s' "$created" | grep -Eq "^($PROTECTED)$"; then
  exit 0
fi

if printf '%s' "$branch" | grep -Eq "^($PROTECTED)$"; then
  if $is_commit; then
    deny "Blocked: you are on '$branch', which is protected. This repository never commits directly to main or dev. Create a branch first — e.g. 'git checkout -b feature/<slug>' — then commit and open a pull request."
  fi
  deny "Blocked: you are on '$branch', which is protected, so this push would update it. Move the work to a $ALLOWED_PREFIXES branch and open a pull request."
fi

exit 0
