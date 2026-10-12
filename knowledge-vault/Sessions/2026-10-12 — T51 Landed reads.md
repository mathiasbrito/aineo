# 2026-10-12 — T51 Landed reads

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t51-landed-reads` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C13, D22, D35, D48, D56, D57, T51
- [[Implementation/Waves/00013-worktrees-landed/plan]] › O8, O10 · [[Implementation/Waves/00013-worktrees-landed/brief-t51-landed-reads]]
- Rests on: [[Sessions/2026-10-11 — T43 Changes filter]] (the commit reads this packet extends)
- [[Learnings/GIT_OPTIONAL_LOCKS=0 does not keep git diff from taking index.lock]]

The orchestrator's rulings this packet is written for are its assumptions under the user's instruction of 2026-10-06, not the user's decisions: A136 (O1), A137 (O2), A143 (O8, aineo never fetches), A145 (O10, `references_changed`); and, for the fix round, A158 (the `--` survivor is not equivalent), A159 (`FETCH_HEAD` counts as a reference) and A160 (the help is fixed in this packet).

## What was done

Reads and one watch field added to `aineo.git` (`lua/aineo/git/` only); nothing in `aineo.changes` or any other home. The fix round edits the help (`doc/aineo.txt`, A160).

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
| `RepositoryChange.references_changed` | true when a burst wrote a path under `refs/` or `reftable/`, `packed-refs` or `FETCH_HEAD` in the common git directory; the watch calls back for it alone | `watch.lua` |

`repository.merge_base_revisions()` and `repository.straight_revisions()` give the revision arguments the three diff reads and `files_between` share. `aineo.git.Failure.reason` gains `path_missing` (`process.lua`).

## Decisions

- **Two functions, not a flag** for the file diff from the merge base or straight (`clean-code` §2): `file_diff_between()` and `file_diff_straight()`.
- **`file_at_commit` lists the tree, then reads the blob by id** (`ls-tree -z --full-tree --end-of-options <commit> <path>`, then `cat-file blob <id>`; the listing's entry is matched by its exact name, never the first), where the brief names `<id>:<path>` given to `show`. One exit code then tells a path the commit lacks (an empty listing) from a commit the repository lacks (git's 128), whatever the locale; a directory or a submodule at the path is `failed` with its own words. The bytes are `cat-file`'s, unconverted. The brief's fifth mutant, a file read from the working tree instead, is run as such (below).
- **`commits_between` has no `--ignore-missing`**, unlike `commits_since`: a `to` the repository does not have is a failure, not an empty list.
- **`references_changed` is always present** on a call, false where no reference was written, so every existing expectation of a call gained the field (16 expectations in `tests/test_git_watch.lua`). `modules/*/refs/…` (a submodule's) is not a reference of this repository.
- **On Linux, where subdirectories are not watched**, the watch sees `packed-refs` and a fetch of this worktree (`FETCH_HEAD`, A159) and nothing else under `refs/`: not a commit's reference, not a tag, not another worktree's fetch. The docstrings and the help say so. Measured by making the watch non-recursive on macOS (`system_name = 'Linux'`); Linux itself was not run.

## Unit list

1. a name resolves to a full commit id; 2. an annotated tag gives its commit; 3. a name that names none is no commit; 4. an option-like name is a name; 5. the default branch of the remote, not the checked-out one; 6. none without `origin/HEAD`; 7. a file's text as the commit has it, not the working tree's; 8. exact bytes (CR, NUL, no last newline); 9. a path named like a pattern or an option; 10. a path the commit lacks (`path_missing`); 11. a directory, a missing commit (`failed`); 12. the commits between two commits; 13. no first commit; 14. a rebase merge under its new ids; 15. option-like refused; 16. files between two commits, kinds and renames; 17. from the merge base; 18. no first commit; 19. option-like refused; 20. the whole diff between, no header; 21. no first commit; 22. the whole file's context; 23. one file's diff from the merge base; 24. a rename with both paths; 25. straight where the merge base hides; 26. straight from no first commit; 27. option-like refused and a context git has no name for refused, for each of the three diffs; 28. the watch: a fetch, a fetch from another worktree, `packed-refs` alone, and the field on every existing call; 29. C13's promises for each new read: a fast event, once, later, on the main loop; no lock, no index touched.

## Red and green

Every case was seen red before its code, for the intended reason: the operation did not exist (`attempt to call a nil value`, or `calls = 0`), the field was absent (26 of the watch file's 36 cases failed: the 16 existing expectations of a call and the three new cases, in 26 test cases), or no call came within the patience (`1 calls from the watch`, the three new watch cases).

Arrived red for a reason of the test, corrected before the code: the shared parametrize of `a commit named` (every case ran three times); the nil `from` in `DIFF_BETWEEN` dropped by a Lua table (`{ found, nil, to }`); the first option-like name for `resolve_commit` (`--output=…`, then `--default=…`) cannot make `rev-parse` act differently with or without `--end-of-options`, so the case uses `--path-format=x`, which does (128 without, exit 1 with).

Arrived green, and why:

- *C13's promises for each new read* (8 cases, one body): green by nature — every read goes through `process.runner`, which gives them. Killed by mutant 14 below.
- *never holds the lock … nor touches the index* (7 cases): green by nature of a tree-only diff. Killed by mutants 15, 30 and 31 below.
- *the commits between a rebase merge's…*: green by nature of `from..to`; it pins the new ids the brief names (P1).
- *a directory there is a failure*: first asserted the reason only, which `cat-file blob <tree>` gives as well; it asserts the message now, killing mutant 16.

## Mutants

Each is the literal edit, applied to a copy of the file, run on the test file that covers the code it breaks, restored in the same call (`.tests/t51-batch.lua`, ids as below). An assertion is a failed expectation; none was a crash. Mutants 1–22 ran on the tree at the fix round's last commit with git 2.50.1; the host's git changed to 2.54.0 (Apple Git-157) mid-round, when the Xcode license lapsed and `/usr/bin/git` and `/usr/bin/make` stopped running, so 23–31 and the whole suite ran with the Command Line Tools' own git and make first on `PATH`.

| # | Literal edit (file: before → after) | File run | Killed by (assertion) |
|---|---|---|---|
| 1 (plan 1) | `repository.lua`: `{ from .. '...' .. to }` → `{ from .. '..' .. to }` | `test_git_changes`; `test_git_diffs` | 1: *count from the merge base … leaves out its own side*; 2: *is what the second gained …*, *straight is the change …* |
| 2 (plan 2) | `repository.lua`: `'--end-of-options', name .. '^{commit}'` → `name .. '^{commit}'` | `test_git_repository` | 1: *like an option is a name … that makes git fail* (`--path-format=x`) |
| 3 (plan 3) | `watch.lua`: `    or vim.startswith(name or '', 'refs/')` → `    or (vim.startswith(name or '', 'refs/') and not vim.startswith(name or '', 'refs/remotes/'))` | `test_git_watch` | 2: *a remote-tracking branch moves without a fetch*, *a fetch another worktree ran* (the fetch of this worktree is also seen through `FETCH_HEAD` since A159, so it is not the killer) |
| 4 (plan 4) | `repository.lua` `resolve_commit`: `answers = { 0, NONE_CODE },` → `answers = { 0 },` | `test_git_repository` | 5: *names none*, *like an option*, three ranges |
| 5 (plan 5) | `content.lua`: `done(nil, file.stdout)` → `done(nil, table.concat(vim.fn.readfile(found.top .. '/' .. path, 'b'), '\n') .. '\n')` | `test_git_repository` | 5; the one the edit is about: *is the text the commit has, not the working tree’s* |
| 6 | `content.lua`: `reason = 'path_missing',` → `reason = 'failed',` | `test_git_repository` | 3: *the commit does not have …*, the `--` and the normalised-path cases |
| 7 | `diffs.lua`: `  repository.straight_revisions(\n` → `  repository.merge_base_revisions(\n` | `test_git_diffs` | 1: *straight is the change …* |
| 8 | `diffs.lua` `diff_commits`: `{ unified },\n        { '--end-of-options' },` → `{ '--unified=3' },\n        { '--end-of-options' },` | `test_git_diffs` | 1: *has the whole file around a change* |
| 9 | `diffs.lua` `paths_of`: its `return change.kind == 'renamed' and { change.old_path, change.path } or { change.path }` → `return { change.path }` | `test_git_diffs` | 1: *of a renamed file is its rename* |
| 10 | `watch.lua`: `  return name == 'packed-refs'` → `  return false` | `test_git_watch` | 1: *packed-refs alone is rewritten* |
| 11 | `watch.lua`: `if moved or burst.files or burst.references then` → `if moved or burst.files then` | `test_git_watch` | 6: the fetch cases, the tag in reftable, the remote-tracking branch, *packed-refs alone* |
| 12 | `history.lua`: `from and from .. '..' .. to or to,` → `from and to .. '..' .. from or to,` | `test_git_commits` | 2 |
| 13 | `repository.lua`: `'refs/remotes/origin/HEAD'` → `'HEAD'` | `test_git_repository` | 2 |
| 14 | `history.lua`: `function M.commits_between(run, found, from, to, done)\n  run(` → the same with `done(nil, {})` before `run(` | `test_git_repository` | 1: *asked from a fast event … commits_between* |
| 15 | `changes.lua` `files_between`: `vim.list_extend(revisions, { '--' })` → `{ revisions[1]:match('^%x+'), '--' }` (the working tree is read) | `test_git_lock` | 1: *never holds the lock … files_between* |
| 16 | `content.lua`: `if not entry or entry.type ~= FILE_OBJECT_TYPE then` → `if not entry then` | `test_git_repository` | 2: the directory case (its message), the submodule case |
| 17 | `history.lua`: `'--encoding=UTF-8',\n        '--end-of-options',` → `'--encoding=UTF-8',` | `test_git_commits` | 1 |
| 18 | `changes.lua`: `'-O/dev/null',\n            '--end-of-options',` → `'-O/dev/null',` | `test_git_changes` | 1 |
| 19 | `diffs.lua`: `{ unified },\n        { '--end-of-options' },` → `{ unified },` | `test_git_diffs` | 3, one per operation |
| 20 | `content.lua`: `'--end-of-options', commit, path }` → `'--end-of-options', commit, '--', path }` | `test_git_repository` | **survives**: with the entry matched by its exact name the second pathspec `--` lists a second entry that is never read; the result does not change. It is the reintroduced `--` that was the defect (A158), together with taking the first entry (mutant 21); 20 and 21 together are killed by 2: *beside a top-level file named --*, *named by a path git would normalise*. The call has no `--` now. |
| 21 | `content.lua`: `    if name == path then` → `    if true then` | `test_git_repository` | 1: *named by a path git would normalise is not that path* |
| 22 | `repository.lua`: `done(nil, commit.stdout:match('^(%x+)\n$'))` → `done(nil, M.first_line(commit.stdout))` | `test_git_repository` | 4: `^main`, `old..main`, `main..old`, `old...main` |
| 23 | `watch.lua`: `    or vim.startswith(name or '', 'reftable/')\n` → `\n` | `test_git_watch` | 1: *a tag made in a repository that keeps its references in reftable* |
| 24 | `watch.lua`: `    or name == 'FETCH_HEAD'\n` → `\n` | `test_git_watch` | 1: *a watch that cannot see subdirectories … a fetch this worktree ran* |
| 25 | `changes.lua` `files_between`: delete `'-M',` | `test_git_configuration` | 1: *the files between two commits* |
| 26 | `changes.lua` `files_between`: delete `'-O/dev/null',` | `test_git_configuration` | 1 |
| 27 | `history.lua` `commits_between`: delete `'--no-show-signature',` | `test_git_configuration` | 1: *the commits between two commits* |
| 28 | `history.lua` `commits_between`: delete `'--encoding=UTF-8',` | `test_git_configuration` | 1 |
| 29 | `diffs.lua` `diff_commits`: delete the `UNIFIED_DIFF,` line | `test_git_configuration` | 1: *the diff between two commits* |
| 30 | `repository.lua`: `{ from .. '...' .. to }` → `{ from }` | `test_git_lock` | 3: `files_between`, `diff_between`, `file_diff_between` (with `touched-1.txt`) |
| 31 | `repository.lua`: `done(nil, { tree_ish, to })` → `done(nil, { tree_ish })` | `test_git_lock` | 1: `file_diff_straight` |

The plan's five mutants are 1–5. Mutants 6–31 are mine, 26 of them: 25 killed, 1 survivor (20) explained above, and the pair 20 + 21 killed together.

## Fix round — the two reviews of PR #175

| Finding | Done |
|---|---|
| Attack 1 + 2 (HIGH, A158) | Red first: *beside a top-level file named --* (every path answered with the `--` file) and *named by a path git would normalise* (`.` and `dir/` gave a neighbour's bytes). `content.lua` has no `--` and matches the entry by its exact name. The earlier "equivalent survivor" is withdrawn: its fixture had no file named `--`. |
| Attack 3 | Red first: `^main`, `old..main`, `main..old`, `old...main` gave an id or a negation. `resolve_commit` accepts one line of hex. Green by nature: `origin/main`, `refs/remotes/origin/main`, a full id. |
| Attack 4 | Red first: a tag in a repository cloned `--ref-format=reftable` called nothing back. `reftable/` counts as a reference. (A fetch there was also seen through `FETCH_HEAD` once A159 landed, so the case uses a tag.) |
| Attack 5 (A159) | Red first: a fetch with the watch made non-recursive called nothing back. `FETCH_HEAD` counts as a reference. |
| Tests 1 | Three cases in `test_git_configuration.lua` under `make_hostile()`: killing mutants 25–29. |
| Tests 2 | Covered by attack 2. |
| Tests 3 | The `references_changed` docstrings say what a non-recursive watch misses (a commit's and a tag's reference). |
| Tests 4 | The two lock rows use `touched-1.txt`: mutants 30 and 31. |
| Tests 5 | This table: literal edits, numbered 1–31 without a gap, the count counted. |
| Tests 6 (A160) | `doc/aineo.txt`: *aineo-changes*' list of what the watch sees, *aineo-limits*' Linux bullet, trigger list and cost line. |
| Tests 7 | "without a commit header". |
| Tests 8 | Cases: a link, a submodule (`failed`), `origin/<branch>` and a full-id name. |

New cases of the round: 17 (11 in `test_git_repository`, 3 in `test_git_watch`, 3 in `test_git_configuration`). Whole suite, once, on the tree pushed, Neovim 0.12.5, git 2.54.0 (Apple Git-157): exit 0, 2779 cases, 80 groups, `Fails (0)`.

## Open threads

- `files_between()` and the two diffs between, given two commits that share no history, fail with git's "no merge base" (`from...to`); T52 decides what the pane says.
- `follow_change()` ignores `references_changed`; T52 reads it for *Landed*.
- The host's `/usr/bin/git` and `/usr/bin/make` stopped running mid-round (the Xcode license); the suite must run with a git and a make that do, and is now measured on git 2.54.0 where the packet's first round ran on 2.50.1.

## Task lines

- T51 `[X]` (`feature/t51-landed-reads`, into `dev`) — the git home's reads for *Landed* and the files window's keys (C13; D56, D57): `resolve_commit`, `remote_default_branch`, `commits_between`, `files_between`, `diff_between`, `file_diff_between`, `file_diff_straight`, `file_at_commit`, and `references_changed` on the watch's call (O8 (a), O10 (a); A143, A145).

## Commits

Recorded after the merge.
