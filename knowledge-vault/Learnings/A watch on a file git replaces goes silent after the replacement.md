# A watch on a file git replaces goes silent after the replacement

**Tags:** #git #libuv #fs-event #watch #measured
**Discovered:** [[Sessions/2026-09-27 — T23 git home]] (the brief review of PR #76, finding 2; PR #79's integrity review) · [[Sessions/2026-09-27 — Wave 7 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

A `vim.uv` `fs_event` watch on a regular file follows the file it was started on. Git replaces some files instead of writing into them: it writes a new file and renames it over the old. `git gc` and `git reflog expire` do this to `.git/logs/HEAD`. After that, the watch reports one `rename` event and then nothing, for good, with no error.

A watch on `logs/HEAD` has more gaps:
- it cannot start before the first commit (`ENOENT`);
- it cannot start under `core.logAllRefUpdates=false`;
- it has nothing to watch in a reftable repository;
- it misses a branch moved from another worktree with `git update-ref`.

Watch the directory instead, and decide "HEAD moved" by reading `HEAD` again after the events, not from the event itself.

## Example

- **The planning probe** (`Implementation/Waves/00007-panes/evidence/git-probe.txt`, the orchestrator, on 0.12.5 and 0.11.6, git 2.50.1) measured only that a watch on `logs/HEAD` fired on an empty commit.
- **The brief review of PR #76** (at `09c0f56`, the same results on both versions, git 2.50.1) tried every branch move.
  - The `logs/HEAD` watch fired once for each of: a commit, an empty commit, `--amend`, `reset --hard`, `reset --soft`, `checkout -b`, `checkout`, `merge --no-ff`, `switch --detach`, `switch`, and `update-ref` of the current branch. A `rebase` fired it 3 or 4 times.
  - **Defeated:**
    - after `git reflog expire --expire=now --all`, one `rename` event came, and two later commits gave 0 events;
    - after `git gc -q`, when nothing expires, one `rename` event came, then 0 events for the next commit.
  - **Auto-gc can reach any session.** `git commit` runs `maintenance run --auto` (the planning probe saw `.git/objects/maintenance.lock`). So once auto-gc's thresholds are passed, a long session can lose such a watch.
- **T23** (PR #79; `watch.lua`, `6bd652e` on `dev`) watches the common git directory, and compares `HEAD`'s commit and branch after each burst of events. Its `gc` case was rewritten by PR #79's integrity review. It then fails under a `logs/HEAD` watch: mutant W8 killed it by assertion on both versions.

**Why.** The brief review gave the reason: "Git replaces the file, and libuv watches a regular file through kqueue on its inode". That is macOS. This pass did not read libuv's source for it.

## Why it matters

Any watcher of git state loses events after the first replacement: a status line, a file tree, a branch indicator. The same holds for any file its writer replaces by rename instead of rewriting in place, as many editors and configuration writers do.

- **Limits:**
  - measured on macOS, where libuv uses kqueue, with git 2.50.1;
  - Linux and Windows were not run;
  - a directory watch on Linux has a gap of its own ([[Learnings/libuv ignores fs_event's recursive flag on Linux]]).
