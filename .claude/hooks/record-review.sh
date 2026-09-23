#!/usr/bin/env bash
# Records that the currently staged changes have been reviewed.
#
#   .claude/hooks/record-review.sh '<one-line summary of the review>'
#
# The record is keyed to a hash of the staged diff, so it covers exactly the
# content that was read. Staging anything further invalidates it and the
# commit hook asks again.
#
# Records live under .git/, which is never committed: a review is a statement
# about one working tree at one moment, not a fact about the repository.
set -euo pipefail

summary=${1:-}
if [ -z "$summary" ]; then
  echo "usage: record-review.sh '<one-line summary of the review>'" >&2
  exit 2
fi

git_dir=$(git rev-parse --git-dir)
staged=$(git diff --cached)

if [ -z "$staged" ]; then
  echo "Nothing is staged. Stage what you reviewed, then record it." >&2
  exit 2
fi

fingerprint=$(printf '%s' "$staged" | shasum -a 256 | cut -d' ' -f1)
records="$git_dir/claude-review"
mkdir -p "$records"

# Records describe working trees that have moved on; keep the directory from
# growing without bound.
find "$records" -type f -mtime +7 -delete 2>/dev/null || true

{
  echo "reviewed_at: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  # symbolic-ref also names the unborn branch of a repository with no commit yet.
  echo "branch:      $(git symbolic-ref --short -q HEAD || echo detached)"
  echo "files:       $(git diff --cached --name-only | tr '\n' ' ')"
  echo "summary:     $summary"
} > "$records/$fingerprint"

echo "Review recorded for $(git diff --cached --name-only | wc -l | tr -d ' ') staged file(s)."
