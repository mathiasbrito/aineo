#!/bin/sh
# Wave 10's planning probes (git only). Run from the checkout's root:
#   sh knowledge-vault/Implementation/Waves/00010-changes-filter/evidence/w10-probes.sh
# Everything it writes is under .tests/w10-probe (gitignored). git runs with no
# global or system configuration and a ceiling at the scratch directory.
set -u
ROOT=$(pwd)
S="$ROOT/.tests/w10-probe"
rm -rf "$S"; mkdir -p "$S/home"
export HOME="$S/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
  GIT_CEILING_DIRECTORIES="$S" TMPDIR="$S" GIT_OPTIONAL_LOCKS=0
G="git -c core.quotePath=false -c core.fsmonitor=false -c user.name=p -c user.email=p@p"

ms() { # ms <label> <command...>: median of 5 wall times, in ms
  label=$1; shift
  t=""
  for i in 1 2 3 4 5; do
    a=$(perl -MTime::HiRes=time -e 'printf "%d", time*1000')
    "$@" >/dev/null 2>&1
    b=$(perl -MTime::HiRes=time -e 'printf "%d", time*1000')
    t="$t $((b - a))"
  done
  echo "$label: $(echo $t | tr ' ' '\n' | sort -n | sed -n 3p) ms (runs:$t)"
}

echo "== P1: the cost of one files read, on a clone of this repository"
$G clone -q --no-local "$ROOT" "$S/repo"
cd "$S/repo"
echo "commits: $($G rev-list --count HEAD); files: $($G ls-files | wc -l | tr -d ' ')"
C1=$($G rev-parse HEAD); C2=$($G rev-parse HEAD~5); BASE=$($G rev-parse HEAD~60)
printf 'x\n' >> doc/aineo.txt; printf 'y\n' > untracked.txt
ms "diff-tree, one commit (HEAD)" $G diff-tree -r --no-commit-id --name-status -z -M --root "$C1"
ms "diff-tree, one commit (HEAD~5)" $G diff-tree -r --no-commit-id --name-status -z -M --root "$C2"
ms "show --name-status, one commit" $G show --format= --name-status -z -M "$C1"
ms "uncommitted: diff --name-status HEAD" $G diff --name-status -z -M HEAD --
ms "uncommitted: ls-files --others" $G ls-files --others --exclude-standard -z
ms "session work: diff --name-status HEAD~60" $G diff --name-status -z -M "$BASE" --
ms "log HEAD~60..HEAD" $G log -z --format='%H %s' "$BASE..HEAD" --
$G checkout -q -- doc/aineo.txt; rm untracked.txt

echo; echo "== P2: a merge commit's and a root commit's files"
mkdir "$S/m"; cd "$S/m"; $G init -q -b main .
printf 'a\n' > a; $G add a; $G commit -qm root
$G checkout -qb side; printf 'b\n' > b; $G add b; $G commit -qm side
$G checkout -q main; printf 'c\n' > c; $G add c; $G commit -qm main
$G merge -q --no-edit side
echo "-- diff-tree -r --name-status <merge> (default):"; $G diff-tree -r --no-commit-id --name-status HEAD; echo "exit $?"
echo "-- diff-tree --first-parent? (diff-tree -r <merge>^1 <merge>):"; $G diff-tree -r --name-status HEAD^1 HEAD
echo "-- show --format= --name-status <merge> (default, combined):"; $G show --format= --name-status HEAD; echo "exit $?"
echo "-- show --format= --name-status --diff-merges=first-parent <merge>:"; $G show --format= --name-status --diff-merges=first-parent HEAD
echo "-- log --format=%h:%s main~1..main (the merge is listed):"; $G log --format='%h:%s' HEAD~1..HEAD
echo "-- root commit, diff-tree without --root:"; $G diff-tree -r --no-commit-id --name-status "$($G rev-list --max-parents=0 HEAD)"; echo "(printed nothing above means nothing)"
echo "-- root commit, diff-tree --root:"; $G diff-tree -r --no-commit-id --name-status --root "$($G rev-list --max-parents=0 HEAD)"
echo "-- an empty commit:"; $G commit -q --allow-empty -m empty; $G diff-tree -r --no-commit-id --name-status --root HEAD; echo "exit $? (nothing listed)"

echo; echo "== P3: full context"
mkdir "$S/u"; cd "$S/u"; $G init -q -b main .
seq 1 40 > f; seq 1 10 > gone; seq 1 30 > old; $G add .; $G commit -qm one
sed -i '' 's/^5$/five/; s/^35$/thirty-five/' f; rm gone; $G mv old new; sed -i '' 's/^2$/two/' new
for n in 3 1000000 2147483647 2147483648 99999999999 -1; do
  out=$($G diff --no-color -U$n -- f 2>&1); echo "-U$n: exit $? lines $(printf '%s\n' "$out" | wc -l | tr -d ' ') hunks $(printf '%s\n' "$out" | grep -c '^@@') first-hunk: $(printf '%s\n' "$out" | grep -m1 '^@@')$(printf '%s\n' "$out" | grep -m1 -i 'error\|fatal')"
done
echo "-- --function-context on a plain text file:"; $G diff --no-color -W -- f | grep '^@@'
echo "-- -U2147483647, deleted file:"; $G diff --no-color -U2147483647 -- gone | grep '^@@\|^deleted'
echo "-- -U2147483647, renamed and modified (staged rename), both paths:"; $G diff --no-color -M -U2147483647 HEAD -- old new | grep '^@@\|^rename\|^similarity'
echo "-- -U2147483647, untracked via --no-index:"; seq 1 5 > fresh; $G diff --no-color --no-index -U2147483647 -- /dev/null fresh | grep '^@@\|^new'
echo "-- show -U2147483647 of a commit (every file whole):"; $G add -A; $G commit -qm two; $G show --no-color --format= -U2147483647 HEAD | grep '^@@\|^diff'

echo; echo "== P3b: size of full-context diffs on this repository"
cd "$S/repo"
for c in HEAD HEAD~1 HEAD~2 HEAD~3; do
  a=$($G show --no-color --format= -U3 "$c" | wc -c | tr -d ' ')
  b=$($G show --no-color --format= -U2147483647 "$c" | wc -c | tr -d ' ')
  echo "$($G log -1 --format=%h "$c"): -U3 $a bytes, full $b bytes"
done
a=$($G diff --no-color -U3 "$BASE" | wc -c | tr -d ' '); b=$($G diff --no-color -U2147483647 "$BASE" | wc -c | tr -d ' ')
echo "HEAD~60..working tree: -U3 $a bytes, full $b bytes"
ms "show -U3 HEAD" $G show --no-color -U3 HEAD
ms "show full HEAD" $G show --no-color -U2147483647 HEAD
ms "diff full HEAD~60" $G diff --no-color -U2147483647 "$BASE"

echo; echo "== P4: untracked files in a whole diff, through intent-to-add on a private index"
cd "$S/u"; printf 'new\n' > brand-new; printf 'edit\n' >> f
cp .git/index "$S/private-index"
GIT_INDEX_FILE="$S/private-index" $G add --intent-to-add -- brand-new
echo "-- git diff HEAD on the private index:"; GIT_INDEX_FILE="$S/private-index" $G diff --no-color --stat HEAD
echo "-- the real index is untouched (status --short):"; $G status --short
echo "-- git diff HEAD on the real index (untracked absent):"; $G diff --no-color --stat HEAD
