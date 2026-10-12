#!/bin/sh
# Wave 13's planning probes (git only). Run from the checkout's root:
#   sh knowledge-vault/Implementation/Waves/00013-worktrees-landed/evidence/w13-probes.sh
# Fixture repositories are written under .tests/w13-probe (gitignored); git
# runs there with no global or system configuration and a ceiling at the
# scratch directory. P8 alone reads the checkout's own repository, read-only.
# Every absolute path in the output is written as <scratch>.
set -u
ROOT=$(pwd)
S="$ROOT/.tests/w13-probe"
rm -rf "$S"; mkdir -p "$S/home"
export HOME="$S/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
  GIT_CEILING_DIRECTORIES="$S" TMPDIR="$S" GIT_OPTIONAL_LOCKS=0
G="git -c core.quotePath=false -c core.fsmonitor=false -c user.name=p -c user.email=p@p -c init.defaultBranch=main -c advice.detachedHead=false"
show() { "$@" > "$S/out" 2>&1; code=$?; sed "s#$S#<scratch>#g" "$S/out"; echo "(exit $code)"; }

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

# The remote: main (its default branch) and dev, the working branch.
$G init -q --bare "$S/remote.git"
$G clone -q "$S/remote.git" "$S/seed" 2>/dev/null
cd "$S/seed"
echo c0 > c0.txt; $G add .; $G commit -qm c0
$G push -q origin main
$G checkout -qb dev
echo c1 > c1.txt; $G add .; $G commit -qm c1
echo c2 > c2.txt; $G add .; $G commit -qm c2
$G push -q origin dev
C0=$($G rev-parse main)

# The editor's checkout, a clone, detached at dev's tip: its session's base.
$G clone -q "$S/remote.git" "$S/editor"
cd "$S/editor"
$G checkout -q --detach origin/dev
BASE=$($G rev-parse HEAD)
# The agent's worktree, branched from dev's tip, with two commits.
$G worktree add -q -b feature/a "$S/agent" origin/dev
cd "$S/agent"
echo a1 > a1.txt; $G add .; $G commit -qm a1
$G mv c1.txt c1-renamed.txt; $G commit -qm a2
$G push -q origin feature/a
A1=$($G rev-parse HEAD~1)

# A rebase merge, as GitHub makes one: the commits replayed on dev with a new
# committer date, so new ids, pushed by someone else.
$G clone -q "$S/remote.git" "$S/merger"
cd "$S/merger"
$G checkout -q dev
GIT_COMMITTER_DATE='2030-01-01T00:00:00Z' $G cherry-pick "origin/feature/a~1" "origin/feature/a" >/dev/null
$G push -q origin dev

echo "git: $(git --version)"
echo "== P1: a rebase merge, fetched by the agent's worktree, read from the editor's"
cd "$S/editor"
touch "$S/before-fetch"; sleep 1
cd "$S/agent"; $G fetch -q origin
cd "$S/editor"
echo "-- what the fetch wrote under the shared git directory (find -newer):"
(cd "$S/editor/.git" && find . -newer "$S/before-fetch" -type f | sort)
echo "-- the editor's HEAD before and after: $(echo "$BASE" | cut -c1-7) / $($G rev-parse --short HEAD)"
echo "-- git log --format='%h %s' BASE..origin/dev"
show $G log --format='%h %s' "$BASE..origin/dev" --
echo "-- the agent's own commits, by id (not the landed ones):"
show $G log --format='%h %s' "$BASE..feature/a" --
echo "-- git log --cherry-mark --format='%m %h %s' origin/dev...feature/a"
show $G log --cherry-mark --format='%m %h %s' 'origin/dev...feature/a' --
echo "-- git diff --name-status -M BASE...origin/dev (their combined change)"
show $G diff --name-status -M "$BASE...origin/dev" --
echo "-- the same, two dots"
show $G diff --name-status -M "$BASE..origin/dev" --
echo "-- git diff BASE...origin/dev -- c1.txt c1-renamed.txt (a rename asked with both paths)"
show $G diff --stat -M "$BASE...origin/dev" -- c1.txt c1-renamed.txt

echo "== P2: a working branch that does not exist"
show $G rev-parse --verify --quiet --end-of-options 'origin/nosuch^{commit}'
show $G log --format='%h %s' --end-of-options "$BASE..origin/nosuch" --

echo "== P3: a base that is not behind the working branch (a feature branch forked at c0)"
$G checkout -q -b old-feature "$C0"
echo f > f.txt; $G add .; $G commit -qm f
F=$($G rev-parse HEAD)
echo "-- git log F..origin/dev: everything dev gained since the fork, not since the session"
show $G log --format='%h %s' "$F..origin/dev" --
$G checkout -q --detach "$BASE"

echo "== P4: the remote's default branch, origin/HEAD"
echo "-- in a clone:"
show $G symbolic-ref --quiet refs/remotes/origin/HEAD
$G init -q "$S/added"
cd "$S/added"
$G remote add origin "$S/remote.git"; $G fetch -q origin
echo "-- in a repository whose remote was added and fetched, not cloned:"
show $G symbolic-ref --quiet refs/remotes/origin/HEAD
echo "-- after git remote set-head origin --auto:"
$G remote set-head origin --auto >/dev/null 2>&1
show $G symbolic-ref --quiet refs/remotes/origin/HEAD

echo "== P5: the checkout on the working branch itself"
cd "$S/editor"
$G checkout -q -b dev --track origin/dev~2 2>/dev/null || $G checkout -q -B dev "$BASE"
$G branch -q --set-upstream-to=origin/dev dev
echo "-- @{upstream}: $($G rev-parse --abbrev-ref '@{upstream}')"
echo "-- before a pull: BASE..HEAD"
show $G log --format='%h %s' "$BASE..HEAD" --
$G merge -q --ff-only origin/dev
echo "-- after git merge --ff-only origin/dev: BASE..HEAD, then BASE..origin/dev"
show $G log --format='%h %s' "$BASE..HEAD" --
show $G log --format='%h %s' "$BASE..origin/dev" --
$G checkout -q --detach "$BASE"

echo "== P6: a worktree's commit read from the editor's repository (one object store)"
show $G show --format='%h %s' --name-status "$A1"

echo "== P7: the local branch next to its remote-tracking one"
echo "-- the editor's clone made no local dev before P5; after P5, dev at $($G rev-parse --short dev), origin/dev at $($G rev-parse --short origin/dev)"

echo "== P8: this repository, read-only: the cost of the landed reads"
cd "$ROOT"
W=origin/dev
FROM=$(git rev-parse "$W~100")
echo "commits in FROM..$W: $(git rev-list --count "$FROM..$W")"
ms "log -z --format='%H %s' FROM..$W" git log -z --format='%H %s' "$FROM..$W" --
ms "diff --name-status -z -M FROM...$W" git diff --name-status -z -M "$FROM...$W" --
ms "rev-parse --verify $W" git rev-parse --verify --quiet "$W"
echo "-- the local dev and main against their remote-tracking branches, on this host:"
for b in dev main; do
  echo "$b: $(git rev-list --count "$b..origin/$b" 2>/dev/null) commits behind origin/$b"
done
echo "-- origin/HEAD: $(git symbolic-ref --quiet refs/remotes/origin/HEAD)"

rm -rf "$S"
