#!/usr/bin/env bash
# Per-clone setup. Run once after cloning; safe to re-run.
#
# Everything here is *local git configuration*, which cannot be committed and
# therefore cannot arrive with the clone. Each setting is one a contributor
# would otherwise have to know about and remember.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# The shared hooks refuse commits and pushes that would land on main or dev.
# .git/hooks is not versioned, so core.hooksPath is what makes .githooks/ real.
git config core.hooksPath .githooks
printf '✓ core.hooksPath = .githooks\n    main and dev are now write-protected locally.\n'

# GitHub deletes merged head branches, but each clone keeps its own stale
# remote-tracking refs until told otherwise — branches that look alive in
# `git branch -r` long after they were merged and deleted.
git config remote.origin.prune true
printf '✓ remote.origin.prune = true\n    fetch now clears refs for branches deleted upstream.\n'

# Clear anything already stale from before this ran.
if git remote get-url origin >/dev/null 2>&1; then
  pruned=$(git fetch --prune 2>&1 | grep -c '\[deleted\]' || true)
  [ "$pruned" -gt 0 ] && printf '✓ pruned %s stale remote-tracking ref(s).\n' "$pruned"
fi

printf '\nSetup complete. Reminder: main and dev are never written to directly —\nwork on release/ bugfix/ hotfix/ feature/ refactor/ knowledge/ ai/ and open a PR.\n'
