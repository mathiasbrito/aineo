# A test child that quits with aineo's Claude Code running waits 4.4 s for the stop by keys

**Tags:** #testing #mini-test #quit #performance
**Discovered:** [[Sessions/2026-10-05 — T25 Changes pane]] (the test review of PR #112, finding 5; its fix round, item 17)
**Applies to:** [[Projects/aineo]]

## The insight

A child Neovim that started aineo's Claude Code — the fake one in the suites — and then quits spends about 4.4 s quitting. aineo's `VimLeavePre` handler stops a running Claude Code by its keys: one Ctrl-C and a 2.5 s wait, a second Ctrl-C and a 0.3 s wait, a third, then as long as the fake takes to exit, which emulates Claude Code's 1.6 s (`KEY_PRESSES` in `lua/aineo/claude/stop.lua`). A child that quits in the same turn as `:Aineo open` quits at once (12 ms in the fix round's probe), because the fake has not started yet. One that quits 50 ms or more after it waits the 4.4 s (4 405–4 408 ms at 50, 200 and 1 500 ms). So a test file pays the 4.4 s once per case whose child lived long enough. Ending the child's terminals by a hangup before stopping it — `jobstop()` then `jobwait()` on each terminal job — leaves aineo nothing to stop, and the quit is immediate.

## Why it is true

The stop exists so that quitting never leaves Claude Code running (R2, Q4's measurement). It presses the keys a user would and waits, because Claude Code 2.1.281 needed those gaps. The fake reproduces the exit it emulates. Neither knows it is in a test. A hangup ends the fake's process first, so the handler finds no process alive and returns.

## How it showed up here

- **The cost.** T25 made `tests/test_entry_panes.lua` run every case in a fixture repository, and its cases now wait for git to list the changes pane. The file went from 24 s on `origin/dev` to 83–84 s (the test review: six runs). A timed copy put 77.3 s in `entry.restart()`: 17 restarts took 4.43 s each, and the child's `0cquit` alone blocked 4.41 s after those 17 cases and 1–12 ms after the others.
- **The cause.** The test review found the same 4.41 s with the child's working directory moved to a fixture directory that is no repository, and could not say why the checkout differed. The fix round measured that the working directory does not matter. A child quitting 0 ms after `:Aineo open` took 12 ms; at 50, 200 and 1 500 ms it took 4 405–4 408 ms, from the checkout and from a fixture directory alike. Counting per case, 4 cases lived that long on `origin/dev` and 14 on T25's head (the test review's timed copy counted 17 at the same head, `d9debd1`; neither source says why the two counts differ).
- **The fix** (`9220c19` on `dev`). `stop_the_child()` runs `END_TERMINALS` in the child before `child.stop()`: each terminal job is stopped and waited for (`tests/test_entry_panes.lua:35–54`). The file then ran its 86 cases in 8 s. No assertion changed. The quit-time stop the file no longer meets stays pinned by `tests/test_claude.lua` › *quitting Neovim* (the re-measure).
- **Not yet applied:** `tests/test_entry_changes.lua`, 48–49 s for its 11 cases after the fix round, meets the same stop (the project note's open threads).

## Where it applies again

Any test file whose child starts Claude Code through aineo and is restarted or stopped per case. Before blaming a fixture, a working directory or git for a slow file, time the child's quit on its own. A case that tests the quit-time stop itself must keep it; every other case can hang its terminals up first.
