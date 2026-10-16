#!/bin/sh
# Wave 18's planning probe: what listing the local branches and reading one
# branch's commits and files since its merge base with the working branch
# cost in a repository with many commits and many branches. Builds a
# synthetic repository in the directory given as $1 (emptied first) with
# git fast-import: COMMITS commits on main, and BRANCHES branches, each
# forked from a commit of main with BRANCH_COMMITS commits of its own.
# Usage: w18-branch-cost.sh <empty scratch directory>
set -eu
dir=$1
COMMITS=${COMMITS:-50000}
BRANCHES=${BRANCHES:-2000}
BRANCH_COMMITS=${BRANCH_COMMITS:-5}
rm -rf "$dir"
mkdir -p "$dir"
cd "$dir"
git init -q -b main .
awk -v commits="$COMMITS" -v branches="$BRANCHES" -v per="$BRANCH_COMMITS" 'BEGIN {
  mark = 0
  for (i = 1; i <= commits; i++) {
    mark++
    printf "commit refs/heads/main\nmark :%d\ncommitter p <p@x> %d +0000\ndata 3\nm%d\n", mark, 1700000000 + i, i % 10
    printf "M 644 inline f%d\ndata 2\n%d\n\n", i % 500, i % 10
  }
  for (b = 1; b <= branches; b++) {
    from = (b * 23) % commits + 1
    for (c = 1; c <= per; c++) {
      mark++
      printf "commit refs/heads/b%d\nmark :%d\ncommitter p <p@x> %d +0000\ndata 3\nb%d\n", b, mark, 1800000000 + b * 10 + c, c % 10
      if (c == 1) printf "from :%d\n", from
      printf "M 644 inline g%d\ndata 2\n%d\n\n", b, c % 10
    }
  }
}' | git fast-import --quiet
git gc -q
echo "git $(git --version | cut -d' ' -f3-); commits on main: $(git rev-list --count main); local branches: $(git for-each-ref refs/heads | wc -l | tr -d ' ')"
timed() {
  start=$(perl -MTime::HiRes=time -e 'printf "%.6f", time')
  "$@" >/dev/null
  end=$(perl -MTime::HiRes=time -e 'printf "%.6f", time')
  perl -e "printf \"%7.1f ms  %s\n\", ($end - $start) * 1000, '$*'"
}
for run in 1 2 3; do
  echo "run $run"
  timed git for-each-ref --sort=-committerdate '--format=%(refname:short)' refs/heads/
  timed git merge-base b1000 main
  timed git log -z --format=%H\ %s --no-show-signature main..b1000 --
  timed git diff --name-status -z -M main...b1000 --
  timed git log -z --format=%H\ %s --no-show-signature b1000 --
done
