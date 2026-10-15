# 2026-10-15 — T71 Changes flakes

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `bugfix/t71-changes-flakes` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D10, D26, D28, D29
- [[Sessions/2026-10-14 — T64 Report offers per tab]] › *Verification* (the whole-run failure of the keys case on a loaded host)

Test-only (D28): three cases of the changes suites that failed in whole-suite runs on a loaded host and passed alone. A295, the premise that they are load flakes, is the orchestrator's assumption, not the user's decision. No production code changed; each cause is in the test. Measured on Neovim 0.12.5.

## Task lines

- [X] T71 Harden three load flakes in the changes suites (test-only, D28) — done on `bugfix/t71-changes-flakes`: `a list of worktrees that fails` waits for the files window like the commits window; `of one copy selects the filter of its own files window alone` waits for both commits windows to list the commits before it presses a line number; `h on a file whose diff cannot be read` calls the mapping instead of typing the key; reviews and the pull request's merge are open.

## The cause of each case

1. `tests/test_changes_worktrees.lua` › *a list of worktrees that fails › leaves the editor's lines as ever…*. The case waited for the commits window (`expect_lines(COMMITS, …)`) and then read the files window once with `eq(lines_of(FILES), …)`. The files window is filled by a read of its own; when it ends after the commits window's, the single read finds `aineo is reading the repository`. Fix: `expect_lines(FILES, …)`, the wait the case already uses for the commits window. The assertion is the same.
2. `tests/test_changes_copies.lua` › *the commits window › of one copy selects the filter of its own files window alone*. The case waited for both files windows to list the two commits' files, not for the commits windows to list the commits, and then pressed `4G` and `3G` there. A commits window that still held fewer lines clamps the line number: the run's failures showed `Files in: Session work` for the first copy, and `Add b` where `Change a` was expected. Fix: wait for both commits windows to hold `Uncommitted`, `Session work` and the two commits before the first key.
3. `tests/test_changes_keys.lua` › *h › on a file whose diff cannot be read tells git's words once, naming the file*. `h` on a file under a commit reads `HEAD` with git (asynchronous) and only then reads the diff, which the case stubs to fail; the failure is told with `vim.notify(…, ERROR)`, which sets `v:errmsg`. `child.type_keys()` reads `v:errmsg` after each key it sends and raises what it finds, so when git answers between the key and that read, the press itself fails with the told message (`tests/test_changes_keys.lua:107`, `aineo: the diff of notes.txt could not be read: broken object`), before the case waits for it. Not a wait too short: a read of the child's state at a point git's answer may already have passed. Fix: a helper, `call_files_mapping_on_line()`, puts the cursor on the line and calls the files window's `h` mapping with `maparg(…).callback()`, as the neighbouring cases of the file do for a stubbed read that answers at once; the case keeps its wait for the told message and both assertions. The typed `h` is still pinned by the file's other `h` cases.

## What each case did before and after

Each run in a checkout of its own (the fixtures live beside the helpers, so same-file runs in one checkout delete one another's repositories), 8 runs of each of the three files at once, 16 busy loops beside them, host load about 18 beforehand.

| Case | Before (tree `ef2ebaf`) | After |
|---|---|---|
| `a list of worktrees that fails` | failed 3 of 8 (`aineo is reading the repository` for `  M notes.txt`) | 0 of 8, then 0 of 8 more with 32 busy loops |
| `of one copy selects the filter of its own files window alone` | failed 3 of 8 (first copy `Session work`, or `Add b` for `Change a`) | 0 of 8, then 0 of 8 more with 32 busy loops |
| `h on a file whose diff cannot be read` | 0 of 8 under load, 0 of 16 with 48 busy loops; alone, narrowed to the case: 1 of 10, then 0 of 30 | 0 of 8 under load; alone, narrowed: 0 of 30 |

The three files in full, run alone on the tree pushed: `Fails (0)` for each. Under the first load, all 24 runs of the three files ended with `Fails (0)`.

A forced timing reproduces each cause every time, in a copy of the file kept out of the repository:

- worktrees: the git stand-in sleeps 1 s on `diff` and `ls-files` — before: the case fails; after: it passes.
- copies: `commits_since` answers 1 s late — before: the case fails (the only failure of the file); after: passes.
- keys: `resolve_commit` answers from `vim.schedule` — before: 5 of 5 fail at the `type_keys` line with the told message; after: 5 of 5 pass.

## Open threads

- Other cases that stub a failing read and press the key with `press_on_files_line()` while the answer is asynchronous have the keys case's race (`tests/test_changes_keys.lua`: the cases around `h … HEAD names no commit` stub `resolve_commit` to answer at once, which is why they use `MiniTest.expect.error`). None failed in these runs; not changed here.

## Commits

- PR #212, `bugfix/t71-changes-flakes`, head `cd6cc71` (1 commit), merged by rebase into `dev` as `21451a3` (waits for what three changes cases read once). A test-only packet (D28, A297): it ships in v0.2.34 beside T66 and has no release of its own.
- Released in v0.2.34 (PR #214, `main` `8fe30d0`).
