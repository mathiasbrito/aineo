#!/usr/bin/env bash
# Recognises a git write the hooks cannot see through.
#
# Both hooks blank quoted strings before matching, so that a subcommand named
# inside a commit message is not read as a command. The same blanking hides
# the entire payload of `bash -c '…'`, `eval '…'` and friends — a commit or
# push inside one is invisible to the regexes and would be allowed by
# default. A script file run through a shell hides it the same way.
#
# Sourced by guard-protected-branch.sh and require-review-before-commit.sh.
# `hidden_git_write <raw command>` succeeds when the command runs a shell
# wrapper whose quoted payload, or whose script file, contains a git commit or
# push. The hooks refuse such a command outright: a write that cannot be
# judged is not allowed on the strength of not having been seen.

WRAPPERS='bash|sh|zsh|dash|ksh|eval|exec|source|\.'
GIT_WRITE='\bgit\b[^;&|]*\b(commit|push)\b'

hidden_git_write() {
  local command=$1 wrapper_call script

  # A wrapper at command position: start of line, or after a separator.
  printf '%s' "$command" \
    | grep -Eq "(^|[;&|(]|&&|\|\|)[[:space:]]*($WRAPPERS)([[:space:]]|$)" || return 1

  # The payload is quoted inline. The wrapper must stand at command position:
  # the `sh` at the end of `*.sh`, or a period closing a sentence in a
  # heredoc, is not one.
  if printf '%s' "$command" | grep -Eq "(^|[;&|(]|&&|\|\|)[[:space:]]*($WRAPPERS)[[:space:]][^;&|]*(-c[[:space:]]|eval[[:space:]])?['\"][^'\"]*$GIT_WRITE"; then
    return 0
  fi
  if printf '%s' "$command" | grep -Eq "(^|[;&|(]|&&|\|\|)[[:space:]]*eval[[:space:]]+['\"]?[^'\"]*$GIT_WRITE"; then
    return 0
  fi

  # The payload is a script file the hook can read from where it runs. Tokens
  # are read one per line, never word-split, so a pattern in the command is
  # not expanded by this loop; one a wrapper would execute is expanded on
  # purpose, since `bash scripts/*.sh` runs whatever matches.
  while IFS= read -r wrapper_call; do
    script=${wrapper_call#* }
    case "$script" in
      ''|-*) continue ;;
    esac
    for candidate in $(compgen -G "$script" 2>/dev/null || printf '%s\n' "$script"); do
      if [ -f "$candidate" ] && grep -Eq "$GIT_WRITE" "$candidate"; then
        return 0
      fi
    done
  done < <(printf '%s' "$command" | grep -oE "(^|[[:space:];&|(])($WRAPPERS)[[:space:]]+[^[:space:];&|'\"]+" | sed -E 's/^[[:space:];&|(]+//')

  return 1
}
