#!/usr/bin/env bash
# Refuses `git commit` until the staged changes have been reviewed.
#
# The review is recorded against a hash of the staged diff, so one review
# covers exactly one staged state: stage anything further and the review no
# longer applies. Record one with:
#
#   .claude/hooks/record-review.sh '<one-line summary of the review>'
#
# This enforces that the step happens. It cannot enforce that it was done
# well — recording a review without performing one defeats it, the same way
# `--no-verify` defeats a git hook. It exists so that skipping review is a
# deliberate act rather than an oversight.
#
# A commit hidden behind a shell wrapper or a script file is refused outright,
# because the hook cannot see whether it commits — see command-shape.sh.
#
# Runs as a Claude Code PreToolUse hook on Bash. Reads the tool call as JSON
# on stdin and emits a permission decision as JSON on stdout.
set -uo pipefail

payload=$(cat)
command=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -z "$command" ] && exit 0

# shellcheck source=command-shape.sh
. "$(dirname "$0")/command-shape.sh"

deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# A commit the scrubbing below would hide is refused before it is scrubbed.
if hidden_git_write "$command"; then
  deny "Blocked: this runs git through a shell wrapper or a script, where the review gate cannot see whether it commits. Run git commit directly, after recording the review."
fi

# Strip quoted strings so the subcommand named inside a message never matches.
scrubbed=$(printf '%s' "$command" | sed "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g")

# The subcommand must be a standalone word, or a branch or path merely
# containing it would read as a commit.
printf '%s' "$scrubbed" \
  | grep -Eq '(^|[;&|(]|&&|\|\|)[[:space:]]*git\b[^;&|]*[[:space:]]commit([^[:alnum:]_/-]|$)' || exit 0

git_dir=$(git rev-parse --git-dir 2>/dev/null) || exit 0

# A commit concluding a merge, rebase, cherry-pick or revert lands content
# that was reviewed when it was written. Refusing here would strand the
# working tree mid-operation with no way forward.
for state in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
  [ -e "$git_dir/$state" ] && exit 0
done

# `git commit -a` stages tracked changes as it commits, so what is staged now
# is not what would land, and a review of it would describe the wrong thing.
if printf '%s' "$scrubbed" | grep -Eq '[[:space:]]commit[^;&|]*([[:space:]]-[a-zA-Z]*a|[[:space:]]--all([[:space:]]|$))'; then
  deny "Stage the changes explicitly before committing.

\`git commit -a\` stages tracked files as it commits, so a review of the
current index would not describe what actually lands. Run \`git add\` for what
you intend to commit, review that, then commit without -a."
fi

staged=$(git diff --cached 2>/dev/null)

# Nothing staged: git will refuse this itself, or it is an --amend that edits
# only a message and changes no content.
[ -z "$staged" ] && exit 0

fingerprint=$(printf '%s' "$staged" | shasum -a 256 | cut -d' ' -f1)
[ -f "$git_dir/claude-review/$fingerprint" ] && exit 0

deny "The staged changes have not been reviewed.

Review them, then record it:

  1. Read the staged diff: git diff --cached
  2. Check it against the project's binding rules: the root CLAUDE.md and,
     once the project has one, the constitution
     (.specify/memory/constitution.md). A principle violation is never a
     style question.
  3. Check it against the four mandatory skills: tdd — was every unit driven
     by a test seen failing? clean-code. documentation-discipline — do the
     docstrings describe what the code does now, not what it will do?
     modularity — does anything reach past a module's index?
  4. Record it:
       .claude/hooks/record-review.sh 'what you checked and what you found'

The record is keyed to the staged diff, so staging anything further requires
reviewing again. Nothing here stops you reporting problems instead of
recording a clean review — that is the point of doing it."
