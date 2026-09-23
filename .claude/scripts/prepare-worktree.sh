#!/usr/bin/env bash
# Makes an agent's worktree able to run the suites.
#
# Usage, from inside the worktree:
#   .claude/scripts/prepare-worktree.sh <impl_slug|review_dimension_slug>
#
# The name is validated before it reaches anything that could act on shared
# state: an agent kind (`impl_` or `review_`), then slug segments of lower-case
# letters and digits. A name the developer's own resources could carry is
# refused by construction, not by care.
#
# Generic steps run always: the name check, the refusal to run in the main
# checkout, and the check that every file `.worktreeinclude` lists was copied
# in. The project's own steps — linking or installing dependencies, creating
# the agent's isolated test database, anything else a suite needs — belong in
# prepare_project below. Run the script again after editing anything that is
# applied once (a migration, generated code): prepare_project should recreate
# it, because an applied change never re-runs on state that already holds it.
set -euo pipefail

name=${1:?usage: prepare-worktree.sh <impl_slug|review_dimension_slug>}

if ! printf '%s' "$name" | grep -Eq '^(impl|review)(_[a-z0-9]+)+$'; then
  echo "refusing: '$name' is not an agent resource name (impl_<slug> or review_<dimension>_<slug>)" >&2
  exit 1
fi

worktree=$(git rev-parse --show-toplevel)
# The first entry of the porcelain listing is the main checkout; the path may
# contain spaces, so everything after the field name is taken.
main=$(git worktree list --porcelain | awk 'NR==1 && $1=="worktree" {sub(/^worktree /, ""); print}')

if [ "$worktree" = "$main" ]; then
  echo "refusing: run this inside an agent worktree, not the main checkout" >&2
  exit 1
fi

# Every gitignored file the project declared in .worktreeinclude must have
# arrived; a missing one is a configuration error to report, not to recreate.
if [ -f "$worktree/.worktreeinclude" ]; then
  missing=0
  while IFS= read -r entry; do
    entry=${entry%%#*}
    entry=$(printf '%s' "$entry" | awk '{$1=$1; print}')
    [ -z "$entry" ] && continue
    if ! compgen -G "$worktree/$entry" > /dev/null; then
      echo "missing $entry in the worktree; .worktreeinclude should have copied it" >&2
      missing=1
    fi
  done < "$worktree/.worktreeinclude"
  [ "$missing" -eq 0 ] || exit 1
fi

# The project's per-worktree setup. Empty until the project has a stack; fill
# it in on an `ai/` branch, and keep every step idempotent and scoped to
# "$name" so a second run recreates rather than accumulates. Examples of what
# belongs here:
#   - dependencies: link each entry of "$main/node_modules" into the worktree
#     (never install inside a worktree whose tree other agents share), or
#     create an isolated virtualenv;
#   - an isolated test database named "${name}_test", dropped and recreated
#     from a template, never the developer's own;
#   - exporting what the suites read to find those resources.
prepare_project() {
  :
}

prepare_project

echo "AGENT_RESOURCE=$name"
