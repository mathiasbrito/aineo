#!/usr/bin/env bash
# Regression suite for the Claude Code hooks.
#
#   .claude/hooks/test-hooks.sh
#
# Every case states the command a hook sees and whether it must be denied.
# A hook that denies nothing is indistinguishable from a hook that is not
# installed, so refusals are asserted as carefully as permissions.
#
# Cases whose outcome depends on the current branch or the index run inside a
# throwaway repository, so the suite gives the same answer wherever it is run.
set -uo pipefail

HOOKS=$(cd "$(dirname "$0")" && pwd)
GUARD="$HOOKS/guard-protected-branch.sh"
REVIEW="$HOOKS/require-review-before-commit.sh"
CDGUARD="$HOOKS/guard-worktree-cd.sh"

passed=0
failed=0

# Reports "deny" or "allow" for a command, run from the current directory.
verdict() {
  local hook=$1 command=$2 output
  output=$(jq -cn --arg c "$command" '{tool_input:{command:$c}}' | "$hook")
  if printf '%s' "$output" | grep -q '"permissionDecision":"deny"'; then
    echo deny
  else
    echo allow
  fi
}

# The same, for a command a subagent issues: the hook input then carries the
# agent's identity, which is what tells the guard the caller is not the session.
verdict_as_agent() {
  local hook=$1 command=$2 output
  output=$(jq -cn --arg c "$command" '{tool_input:{command:$c},agent_id:"a1",agent_type:"implementer"}' | "$hook")
  if printf '%s' "$output" | grep -q '"permissionDecision":"deny"'; then
    echo deny
  else
    echo allow
  fi
}

expect() {
  local hook=$1 want=$2 command=$3 got
  got=$(verdict "$hook" "$command")
  if [ "$got" = "$want" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    printf 'FAIL  expected %-5s got %-5s  %s\n' "$want" "$got" "$command"
  fi
}

# A repository the cases may commit to and stage into freely.
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
git -C "$sandbox" init -q -b dev
git -C "$sandbox" config user.email hooks@test
git -C "$sandbox" config user.name Hooks
echo one > "$sandbox/file.txt"
git -C "$sandbox" add file.txt
git -C "$sandbox" commit -q -m 'initial'

cd "$sandbox" || exit 1

echo "── branch guard: command names a protected branch ──"

expect "$GUARD" deny  "git push origin dev"
expect "$GUARD" deny  "git checkout dev && git commit -m 'x'"
expect "$GUARD" deny  "git switch main && git commit -m 'x'"
expect "$GUARD" deny  "git checkout -b dev && git commit -m 'x'"
expect "$GUARD" deny  "git checkout -b feature/x dev && git push origin main"

echo "── branch guard: standing on a protected branch ──"

expect "$GUARD" deny  "git commit -m 'x'"
expect "$GUARD" deny  "git push"

# A separator, rather than whitespace, follows the verb.
expect "$GUARD" deny  "git commit; echo done"
expect "$GUARD" deny  "git push; echo done"
expect "$GUARD" deny  "git commit && echo done"

# Creating a branch moves the work off the protected one before anything is
# written, so where HEAD is right now does not matter.
expect "$GUARD" allow "git checkout -b feature/x dev && git commit -m 'x'"
expect "$GUARD" allow "git switch -c bugfix/y dev && git commit -m 'x'"

# A branch or path whose name merely contains a subcommand is not that
# subcommand.
expect "$GUARD" allow "git checkout -b ai/require-review-before-commit dev"
expect "$GUARD" allow "git checkout -b feature/push-notifications dev"

# Reads are never anyone's business, and a subcommand quoted inside a message
# is not a command.
expect "$GUARD" allow "git status"
expect "$GUARD" allow "git diff --cached"
expect "$GUARD" allow "echo 'run git commit later'"

echo "── branch guard: on an unprotected branch ──"

git checkout -q -b feature/sandbox
expect "$GUARD" allow "git commit -m 'x'"
expect "$GUARD" allow "git push"
expect "$GUARD" allow "git push origin feature/sandbox"

# A branch whose name merely *contains* a protected branch's name is not that
# branch. `/` and `-` are word boundaries, so a word-boundary match read
# `knowledge/dev-blogs-plan` as `dev`. A ref is matched whole, never as a
# word.
expect "$GUARD" allow "git push -u origin knowledge/dev-blogs-plan"
expect "$GUARD" allow "git push -u origin feature/docs-dev-blog-audit-trail"
expect "$GUARD" allow "git push origin ai/dev-guard"
expect "$GUARD" allow "git checkout knowledge/dev-blogs-plan"
expect "$GUARD" allow "git checkout -b knowledge/dev-blogs-plan dev && git push -u origin knowledge/dev-blogs-plan"
expect "$GUARD" allow "git push origin developer-notes"
expect "$GUARD" allow "git push origin feature/maindeck"

# The refusals the whole-ref match must keep, including the refspec forms a
# word match never had to think about.
expect "$GUARD" deny  "git push -u origin dev"
expect "$GUARD" deny  "git push origin HEAD:dev"
expect "$GUARD" deny  "git push origin feature/x:dev"
expect "$GUARD" deny  "git push origin +dev"
expect "$GUARD" deny  "git push origin refs/heads/dev"
expect "$GUARD" deny  "git push --force origin main"

# A commit message is prose, not a command. Rich messages are written through
# a heredoc, which the scrubber cannot blank the way it blanks a quoted
# string, so a line that merely says `push` and names a branch must not be
# read as a push to it.
push_prose='git commit -F - <<EOF
refused to push it three times, while the dev blog was landing
EOF
git push -u origin ai/branch-guard-ref-match'
expect "$GUARD" allow "$push_prose"

# Every push in a compound command is judged, not only the first.
expect "$GUARD" deny  "git push origin feature/x && git push origin dev"
expect "$GUARD" deny  "git push origin feature/x; git push origin main"
# Switching to a branch that is not protected and writing there is the
# sanctioned workflow, and the checkout rule must judge the ref it names.
expect "$GUARD" allow "git checkout knowledge/x && git commit -m 'x'"
expect "$GUARD" deny  "git checkout dev && git commit -m 'x'"
expect "$GUARD" deny  "git switch main && git push"
expect "$GUARD" deny  "git checkout -q dev && git commit -m 'x'"

echo "── both hooks: a git write hidden behind a shell wrapper cannot be judged ──"

# The scrubber blanks quoted strings so a subcommand named inside a message is
# not a command — which also blanks the whole payload of `bash -c '…'`. A write
# the hook cannot see is refused rather than allowed.
git checkout -q dev
expect "$GUARD" deny  "bash -c 'git commit -m x'"
expect "$GUARD" deny  "sh -c \"git push origin HEAD:dev\""
expect "$GUARD" deny  "eval 'git push'"
expect "$GUARD" deny  "zsh -c 'cd sub && git commit -m x'"
git checkout -q feature/sandbox
expect "$REVIEW" deny "bash -c 'git commit -m x'"
expect "$REVIEW" deny "sh -c 'git commit --amend --no-edit'"

# A script file that commits is a wrapper too, when the hook can read it.
printf '#!/bin/sh\ngit commit -m landed\n' > land.sh
expect "$GUARD" deny  "bash land.sh"
expect "$REVIEW" deny "sh ./land.sh"
printf '#!/bin/sh\necho nothing to do\n' > harmless.sh
expect "$GUARD" allow "bash harmless.sh"
expect "$REVIEW" allow "bash harmless.sh"

# Wrappers that run no git write stay allowed.
expect "$GUARD" allow "bash -c 'npm test'"
expect "$REVIEW" allow "bash -c 'git status && git diff --cached'"
expect "$GUARD" allow "bash -n .claude/scripts/prepare-worktree.sh"

# Prose inside a heredoc is not a wrapper: a period followed by a space is
# not the `.` builtin, and a quoted sentence naming git commit is not a
# payload, unless a wrapper at command position runs it.
prose=$'python3 - <<\'PY\'\nold="layer 2. Using it is fine."\nnew="the hooks refuse a git commit hidden behind bash -c"\nPY\ngit add -A && bash -n check.sh'
expect "$REVIEW" allow "$prose"
expect "$GUARD" allow "$prose"

# A pattern the command merely names is not expanded by the hook; one a
# wrapper would execute is, because `bash hooks/*.sh` runs whatever matches.
mkdir -p hooks && printf '#!/bin/sh\ngit commit -m via-glob\n' > hooks/commit.sh
expect "$REVIEW" allow "bash -n hooks/*.sh"
expect "$GUARD" allow "shellcheck hooks/*.sh && bash -n hooks/*.sh"
expect "$REVIEW" deny  "bash hooks/*.sh"
expect "$GUARD" deny  "sh hooks/*.sh"

# The tail of `*.sh` is not the `sh` wrapper.
mkdir -p scripts && printf '#!/bin/sh\necho harmless\n' > scripts/ok.sh
expect "$REVIEW" allow "bash -n scripts/*.sh hooks/*.sh"
expect "$GUARD" allow "bash -n scripts/*.sh hooks/*.sh && echo SYNTAX-OK"

echo "── branch guard: a subagent never merges ──"

# Merging is the one action the orchestration design leaves with the user;
# the session may do it when delegated, an agent never.
expect "$GUARD" allow "gh pr merge 36 --rebase --delete-branch"
[ "$(verdict_as_agent "$GUARD" "gh pr merge 36 --rebase --delete-branch")" = deny ] && passed=$((passed + 1)) || { failed=$((failed + 1)); echo "FAIL  expected deny  got allow  (agent) gh pr merge 36 --rebase --delete-branch"; }
[ "$(verdict_as_agent "$GUARD" "gh pr merge --squash 36")" = deny ] && passed=$((passed + 1)) || { failed=$((failed + 1)); echo "FAIL  expected deny  got allow  (agent) gh pr merge --squash 36"; }
[ "$(verdict_as_agent "$GUARD" "gh pr view 36 --json files")" = allow ] && passed=$((passed + 1)) || { failed=$((failed + 1)); echo "FAIL  expected allow got deny   (agent) gh pr view 36 --json files"; }
[ "$(verdict_as_agent "$GUARD" "git commit -m 'x'")" = allow ] && passed=$((passed + 1)) || { failed=$((failed + 1)); echo "FAIL  expected allow got deny   (agent) git commit on a feature branch"; }

echo "── worktree cd guard: the session never moves into an agent worktree ──"
expect "$CDGUARD" deny  "cd .claude/worktrees/orch-verify-t6 && git status"
expect "$CDGUARD" deny  "cd /Users/x/aineo/.claude/worktrees/orch-verify-t4 && ls deps"
expect "$CDGUARD" deny  "cd \"/Users/x/my repo/.claude/worktrees/a\" && make test"
expect "$CDGUARD" deny  "ls; cd .claude/worktrees/a"
expect "$CDGUARD" deny  "true && pushd .claude/worktrees/a"
expect "$CDGUARD" deny  "cd .claude/worktrees"
expect "$CDGUARD" allow "(cd .claude/worktrees/a && make test)"
expect "$CDGUARD" allow "(cd /Users/x/aineo/.claude/worktrees/a && make deps >/dev/null; echo rc=\$?)"
expect "$CDGUARD" allow "ls && (cd .claude/worktrees/a && (make test))"
expect "$CDGUARD" allow "git -C .claude/worktrees/a status"
expect "$CDGUARD" allow "make -C .claude/worktrees/a test"
expect "$CDGUARD" allow "cd /Users/x/aineo && git status"
expect "$CDGUARD" allow "cd .claude && ls"
expect "$CDGUARD" allow "echo 'then cd .claude/worktrees/a'"
expect "$CDGUARD" allow "git worktree add --detach .claude/worktrees/a origin/dev"
[ "$(verdict_as_agent "$CDGUARD" "cd .claude/worktrees/agent-x && make test")" = allow ] && passed=$((passed + 1)) || { failed=$((failed + 1)); echo "FAIL  expected allow got deny   (agent) cd into its own worktree"; }

echo "── review hook ──"

# Not a commit, so not this hook's concern.
expect "$REVIEW" allow "git status"
expect "$REVIEW" allow "git add -A"
expect "$REVIEW" allow "git push origin feature/sandbox"

# Nothing staged: git refuses on its own, and an --amend here only edits a
# message. A long option beginning with -a is not -a: --allow-empty must not
# be refused as `git commit -a` because `--all` matches it as a prefix.
expect "$REVIEW" allow "git commit -m 'x'"
expect "$REVIEW" allow "git commit --allow-empty -m 'x'"

# Staged and unreviewed.
echo two >> file.txt
git add file.txt
expect "$REVIEW" deny  "git commit -m 'x'"

# -a stages as it commits, so the reviewed index is not what would land.
expect "$REVIEW" deny  "git commit -am 'x'"
expect "$REVIEW" deny  "git commit --all -m 'x'"

# Recorded, so the same staged content may now be committed.
"$HOOKS/record-review.sh" 'suite: reviewed the sandbox change' > /dev/null
expect "$REVIEW" allow "git commit -m 'x'"
expect "$REVIEW" allow "git commit --allow-empty -m 'x'"

# Staging more invalidates the record, because it was never reviewed.
echo three >> file.txt
git add file.txt
expect "$REVIEW" deny  "git commit -m 'x'"

# A commit concluding a merge lands already-reviewed content.
touch .git/MERGE_HEAD
expect "$REVIEW" allow "git commit -m 'x'"
rm -f .git/MERGE_HEAD

echo
if [ "$failed" -eq 0 ]; then
  echo "$passed passed"
else
  echo "$passed passed, $failed FAILED"
  exit 1
fi
