# GIT_OPTIONAL_LOCKS=0 does not keep git diff from taking index.lock

**Tags:** #git #locks #concurrency #measured
**Discovered:** [[Sessions/2026-09-27 — T23 git home]] (the brief review of PR #76, finding 1; PR #79's attack review) · [[Sessions/2026-09-27 — Wave 7 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

`GIT_OPTIONAL_LOCKS=0` stops `git status` from refreshing the index. It does not stop `git diff`.

Suppose a tracked file's stat has changed but its content has not. Then `git diff <base>`, or `git diff <base> -- <file>`, rewrites `.git/index` under `index.lock`. A `git commit` started meanwhile fails with `Unable to create '…/index.lock': File exists`.

There are two ways around it:
- `-c diff.autoRefreshIndex=false` avoids the lock, but then the diff lists every such file as modified;
- a private copy of the index, named in `GIT_INDEX_FILE`, gives the right list and leaves `.git/index` alone.

## Example

The brief review of PR #76 measured this for wave 7's plan and T23's brief, at `09c0f56` (its code is `dev` `aaa326a`). It used git 2.50.1 (Apple Git-155) on macOS.
- **Which reads rewrite the index.** It made 3000 tracked files stat-dirty but unchanged. "Rewritten" means that `.git/index`'s inode or modification time changed.

  | read | plain | `GIT_OPTIONAL_LOCKS=0` | `-c diff.autoRefreshIndex=false` |
  |---|---|---|---|
  | `diff --name-status -z -M <base>` | rewritten | **rewritten** | untouched |
  | `diff <base> -- <file>` | rewritten | **rewritten** | untouched |
  | `rev-parse`, `ls-files --others`, `log`, `show`, `merge-base --is-ancestor`, `diff --no-index` | untouched | untouched | untouched |
  | `status --porcelain` (the control) | rewritten | untouched | rewritten |

- **A commit started while the lock is held.** A probe polled for `.git/index.lock` while a read ran, and started `git commit --allow-empty --no-verify` the moment the lock appeared.
  - With `GIT_OPTIONAL_LOCKS=0`, the lock was seen in 96 polls of 419, then 107 of 474, and the commit exited 128 both times.
  - With `-c diff.autoRefreshIndex=false`, the lock was seen in no poll.
  - Reader and committer loops racing for 6 s produced no `index.lock` failure in any mode, the `status` control included. Only the deterministic trigger shows the failure.
- **T23's fix** (PR #79; `2f44c73` … `6661d4c` on `dev`). The git home reads through a private copy of the index. A case starts `git commit` the moment `index.lock` appears, and must never see the lock.
  - PR #79's attack review found a trap in the copy. A copy stamped with the time it was made defeats git's racy-clean check: a file rewritten at the same size, within the second its index was written, went missing from the list. The copy now takes the real index's modification time.
  - T23 also keeps `GIT_OPTIONAL_LOCKS=0`. Without it, a read rewrote a submodule's index (the attack review's mutant M1, pinned).

**Why.** The brief review read git v2.50.1's source and documentation.
- In `builtin/diff.c`, `refresh_index_quietly()` takes the index lock and never calls `use_optional_locks()`.
- It runs when `1 < rev.diffopt.skip_stat_unmatch` (line 680), which `diff.autoRefreshIndex` enables (line 545). One stat-dirty file is enough.
- `Documentation/git.adoc` gives `git status` as its only example of what `GIT_OPTIONAL_LOCKS=0` prevents.

## Why it matters

A tool that reads a repository in the background can break the user's commits: an editor plugin, a status line, a watcher, or an agent's side process. Setting `GIT_OPTIONAL_LOCKS=0` is not enough if it runs `git diff`.

- **Limits:**
  - measured with git 2.50.1 on macOS only;
  - other git versions were not measured; the source lines are 2.50.1's.
