# 2026-10-12 — T51 Landed reads

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t51-landed-reads` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C13, D22, D35, D48, D56, D57, T51
- [[Implementation/Waves/00013-worktrees-landed/plan]] › O8, O10 · [[Implementation/Waves/00013-worktrees-landed/brief-t51-landed-reads]]
- Rests on: [[Sessions/2026-10-11 — T43 Changes filter]] (the commit reads this packet extends)
- [[Learnings/GIT_OPTIONAL_LOCKS=0 does not keep git diff from taking index.lock]]

The orchestrator's rulings this packet is written for are its assumptions under the user's instruction of 2026-10-06, not the user's decisions: A136 (O1), A137 (O2), A143 (O8, aineo never fetches), A145 (O10, `references_changed`).

## What was done

Reads and one watch field added to `aineo.git` (`lua/aineo/git/` only); nothing in `aineo.changes`, the help or any other home.

| Export | Does | File |
|---|---|---|
| `resolve_commit(found, name, done)` | full id of the commit a name gives (`<name>^{commit}`, `--end-of-options`); nil when it names none (exit 1 is an answer) | `repository.lua` |
| `remote_default_branch(found, done)` | short name `refs/remotes/origin/HEAD` points at, nil when none | `repository.lua` |
| `commits_between(found, from, to, done)` | `Commit[]` reachable from `to` and not `from`, newest first; `from` nil gives all of `to` | `history.lua` |
| `files_between(found, from, to, done)` | `Change[]` of `from...to`; `from` nil from the empty tree | `changes.lua` |
| `diff_between(found, from, to, done, options)` | the whole diff of `from...to`, no header, `UNIFIED_DIFF`, the options' context | `diffs.lua` |
| `file_diff_between(found, from, to, change, done, options)` | one file's diff from the merge base (a rename asked with both paths) | `diffs.lua` |
| `file_diff_straight(found, from, to, change, done, options)` | the same, straight from the first commit to the second | `diffs.lua` |
| `file_at_commit(found, commit, path, done)` | the bytes of a path as the commit has it; `path_missing` when it has none | `content.lua` (new) |
| `RepositoryChange.references_changed` | true when a burst wrote a path under `refs/` or `packed-refs` in the common git directory; the watch calls back for it alone | `watch.lua` |

`repository.merge_base_revisions()` and `repository.straight_revisions()` give the revision arguments the three diff reads and `files_between` share. `aineo.git.Failure.reason` gains `path_missing` (`process.lua`).

## Decisions

- **Two functions, not a flag** for the file diff from the merge base or straight (`clean-code` §2): `file_diff_between()` and `file_diff_straight()`.
- **`file_at_commit` lists the tree, then reads the blob by id** (`ls-tree -z --full-tree --end-of-options <commit> -- <path>`, then `cat-file blob <id>`), where the brief names `<id>:<path>` given to `show`. One exit code then tells a path the commit lacks (an empty listing) from a commit the repository lacks (git's 128), whatever the locale; a directory or a submodule at the path is `failed` with its own words. The bytes are `cat-file`'s, unconverted. The brief's fifth mutant, a file read from the working tree instead, is run as such (below).
- **`commits_between` has no `--ignore-missing`**, unlike `commits_since`: a `to` the repository does not have is a failure, not an empty list.
- **`references_changed` is always present** on a call, false where no reference was written, so every existing expectation of a call gained the field (16 expectations in `tests/test_git_watch.lua`). `modules/*/refs/…` (a submodule's) is not a reference of this repository.
- **A fetch on Linux is missed**, as `git update-ref` from another worktree already is: the watch there sees only the common directory's own entries (`watches_subdirectories`). The docstrings say so.

## Unit list

1. a name resolves to a full commit id; 2. an annotated tag gives its commit; 3. a name that names none is no commit; 4. an option-like name is a name; 5. the default branch of the remote, not the checked-out one; 6. none without `origin/HEAD`; 7. a file's text as the commit has it, not the working tree's; 8. exact bytes (CR, NUL, no last newline); 9. a path named like a pattern or an option; 10. a path the commit lacks (`path_missing`); 11. a directory, a missing commit (`failed`); 12. the commits between two commits; 13. no first commit; 14. a rebase merge under its new ids; 15. option-like refused; 16. files between two commits, kinds and renames; 17. from the merge base; 18. no first commit; 19. option-like refused; 20. the whole diff between, no header; 21. no first commit; 22. the whole file's context; 23. one file's diff from the merge base; 24. a rename with both paths; 25. straight where the merge base hides; 26. straight from no first commit; 27. option-like refused and a context git has no name for refused, for each of the three diffs; 28. the watch: a fetch, a fetch from another worktree, `packed-refs` alone, and the field on every existing call; 29. C13's promises for each new read: a fast event, once, later, on the main loop; no lock, no index touched.

## Red and green

Every case was seen red before its code, for the intended reason: the operation did not exist (`attempt to call a nil value`, or `calls = 0`), the field was absent (26 of the watch file's 36 cases failed: the 16 existing expectations of a call and the three new cases, in 26 test cases), or no call came within the patience (`1 calls from the watch`, the three new watch cases).

Arrived red for a reason of the test, corrected before the code: the shared parametrize of `a commit named` (every case ran three times); the nil `from` in `DIFF_BETWEEN` dropped by a Lua table (`{ found, nil, to }`); the first option-like name for `resolve_commit` (`--output=…`, then `--default=…`) cannot make `rev-parse` act differently with or without `--end-of-options`, so the case uses `--path-format=x`, which does (128 without, exit 1 with).

Arrived green, and why:

- *C13's promises for each new read* (8 cases, one body): green by nature — every read goes through `process.runner`, which gives them. Killed by mutant 14 below.
- *never holds the lock … nor touches the index* (7 cases): green by nature of a tree-only diff. Killed by mutant 16 below.
- *the commits between a rebase merge's…*: green by nature of `from..to`; it pins the new ids the brief names (P1).
- *a directory there is a failure*: first asserted the reason only, which `cat-file blob <tree>` gives as well; it asserts the message now, killing mutant 18.

## Mutants

Each is the literal edit, applied to a copy, run on the test file that covers the code it breaks, restored in the same call. "Assertion" is a failed expectation; none was a crash.

| # | Literal edit | File run | Result |
|---|---|---|---|
| 1 (plan 1) | `repository.lua`: `from .. '...' .. to` → `from .. '..' .. to` | `test_git_changes` | killed by assertion, 1 — *count from the merge base: … leaves out its own side*; `test_git_diffs` 2 more |
| 2 (plan 2) | `repository.lua` `resolve_commit`: `'--end-of-options', name .. '^{commit}'` → `name .. '^{commit}'` | `test_git_repository` | killed, 1 — *like an option is a name* (`--path-format=x`) |
| 3 (plan 3) | `watch.lua` `is_reference`: `refs/` that is not `refs/remotes/` | `test_git_watch` | killed, 2 — both fetch cases |
| 4 (plan 4) | `resolve_commit`: `answers = { 0, NONE_CODE }` → `{ 0 }` | `test_git_repository` | killed, 2 — *names none*, *like an option* |
| 5 (plan 5) | `content.lua`: `done(nil, file.stdout)` → the working-tree file read with `vim.fn.readfile` | `test_git_repository` | killed, 3 — *is the text the commit has, not the working tree’s* is the one the edit is about |
| 6 | `content.lua`: `reason = 'path_missing'` → `'failed'` | `test_git_repository` | killed, 1 |
| 7 | `diffs.lua` `file_diff_straight`: `straight_revisions` → `merge_base_revisions` | `test_git_diffs` | killed, 1 — *straight …* |
| 8 | `diffs.lua` `diff_commits`: `{ unified }` → `{ '--unified=3' }` | `test_git_diffs` | killed, 1 — *has the whole file around a change* |
| 9 | `diffs.lua` `paths_of`: renamed asked with `{ change.path }` only | `test_git_diffs` | killed, 1 — *of a renamed file is its rename* |
| 10 | `watch.lua` `is_reference`: `packed-refs` removed | `test_git_watch` | killed, 1 — *packed-refs alone* |
| 11 | `watch.lua` `read_branch`: `or burst.references` removed | `test_git_watch` | killed, 3 — both fetch cases, *packed-refs alone* |
| 12 | `history.lua`: `from .. '..' .. to` → `to .. '..' .. from` | `test_git_commits` | killed, 2 |
| 13 | `repository.lua`: `refs/remotes/origin/HEAD` → `HEAD` | `test_git_repository` | killed, 2 |
| 14 | `history.lua` `commits_between`: `done(nil, {})` before the `run` | `test_git_repository` | killed, 1 — *asked from a fast event … commits_between* |
| 16 | `changes.lua` `files_between`: the revisions replaced by `from` alone, so the working tree is read | `test_git_lock` | killed, 1 — the lock case for `files_between` |
| 18 | `content.lua`: `entry.type ~= FILE_OBJECT_TYPE` dropped | `test_git_repository` | killed, 1 — the directory case (message) |
| 19 | `history.lua`: `--end-of-options` dropped from `commits_between` | `test_git_commits` | killed, 1 |
| 20 | `changes.lua`: `--end-of-options` dropped from `files_between` | `test_git_changes` | killed, 1 |
| 21 | `diffs.lua`: `--end-of-options` dropped from `diff_commits` | `test_git_diffs` | killed, 3 — the three operations |
| 17 | `content.lua`: `'--', path` → `path` after the commit | `test_git_repository` | **survives, equivalent**: once `ls-tree` has read the commit, every later argument is a path, `-a.txt` and `-r` included (measured: `ls-tree -z --full-tree --end-of-options HEAD -r` exits 0 and lists nothing). The `--` stays as a guard against a git that stops parsing options later. |

## Open threads

- **The help is incomplete in two places** (`doc/aineo.txt`, T52's to write): the sentence on *aineo-changes* that the other worktrees are read again when the watch sees "in another worktree, its `git add` or commit, a worktree added or removed, or a file written in one inside your top level", and the *aineo-limits* line on what the watch sees in the repository — both lack a fetch and any other write of a reference (a tag, a branch made or deleted), which now call the watch back and read the other worktrees again (`follow_change()` reads them at every call, D35). A fetch is also missed on Linux.
- `files_between()` and the two diffs between, given two commits that share no history, fail with git's "no merge base" (`from...to`); T52 decides what the pane says.

## Task lines

- T51 `[X]` (`feature/t51-landed-reads`, into `dev`) — the git home's reads for *Landed* and the files window's keys (C13; D56, D57): `resolve_commit`, `remote_default_branch`, `commits_between`, `files_between`, `diff_between`, `file_diff_between`, `file_diff_straight`, `file_at_commit`, and `references_changed` on the watch's call (O8 (a), O10 (a); A143, A145).

## Commits

Recorded after the merge.
