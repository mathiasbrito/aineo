# libuv ignores fs_event's recursive flag on Linux

**Tags:** #libuv #fs-event #watch #linux #source-read
**Discovered:** [[Sessions/2026-09-27 — T23 git home]] (the brief review of PR #76, finding 3; PR #79's attack review 10 and records review 6) · [[Sessions/2026-09-27 — Wave 7 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

`vim.uv.new_fs_event():start(path, { recursive = true }, callback)` watches subdirectories only on macOS and Windows. On Linux, libuv accepts the flag, never reads it, returns success, and watches the top directory alone. Changes in subdirectories are then missed, and nothing says so. A caller must decide from the platform (`vim.uv.os_uname().sysname`), not from `start()`'s result, whether its watch sees subdirectories.

**No one in this project has run this on Linux.** The claim rests on libuv's source, read by the brief review of PR #76, and on a measurement made on macOS through libuv's non-recursive path.

## Example

- **The source.** The brief review of PR #76 (at `09c0f56`) read libuv's `v1.x` branch:
  - in `src/unix/linux.c`, `uv_fs_event_start` takes `flags` and never reads it;
  - `docs/src/fs_event.rst` gives the recursive flag "only on OSX and Windows".
- **On macOS.** The planning probe (`Implementation/Waves/00007-panes/evidence/git-probe.txt`, the orchestrator, on 0.12.5 and 0.11.6) started a recursive watch on a repository's tree.
  - Writing `sub/b.txt` gave the event `sub/b.txt`.
  - An empty commit gave 18 events under `.git/` on 0.12.5, and 16 on 0.11.6, among them `.git/logs/HEAD` and `.git/refs/heads/main`.
- **T23** (PR #79; `lua/aineo/git/watch.lua`, `6bd652e` on `dev`) watches recursively only where libuv does: `RECURSIVE_PLATFORMS = { Darwin = true, Windows_NT = true }`. Elsewhere it reports `watches_subdirectories = false`.
- **What the non-recursive watch misses.** T23's note, *Limits*, measured it on macOS through libuv's non-recursive path:
  - **missed:** a file changed in a subdirectory, and a branch moved by `git update-ref` from another worktree;
  - **seen:** a commit, since the index and `COMMIT_EDITMSG` sit in the common directory; a `reset --soft`, through `ORIG_HEAD`; and a linked worktree's commit, through `packed-refs.lock`.

  The packet had first read that a `reset --soft` is missed; records review 6 corrected it.

**Why.** libuv's Linux backend does not implement the flag. The source says so, as read above.

## Why it matters

A Neovim plugin that watches a project tree with `fs_event` and asks for `recursive` sees subdirectories on macOS and Windows only. On Linux it needs another way:
- a watch per directory;
- polling;
- re-reading on a timer.

It must also say that it cannot see subdirectories, because libuv will not.

**Limits:**
- Linux and Windows were not run;
- the libuv read was its `v1.x` branch at the time of the review, not the exact libuv bundled with Neovim 0.11.6 or 0.12.5.
