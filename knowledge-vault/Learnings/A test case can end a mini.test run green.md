# A test case can end a mini.test run green

**Tags:** #testing #neovim #mini-test #trap
**Discovered:** [[Sessions/2026-09-23 — T1 tooling foundation]] · closed one level down by [[Sessions/2026-09-27 — T22 parallel runner]] (the attack review of PR #85, findings 1 and 4) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

When test cases run inside the runner's own Neovim, as they did from T1 until T22, a case can end the whole run — and the exit status is whatever that ending says, not what the suite found. `MiniTest.stop()`, `:quit`, `:qall!`, `:0cquit` and `os.exit(0)` inside a case each made the run exit 0 while the suite held a failing case — measured with `make test_file` for all five, and with `make test` for `quit` too. A green exit status is only a claim until the runner that produced it decides it from the cases it counted.

Since T22, the runner runs no test code: each test file runs in a Neovim of its own, so a case can end only its file's Neovim (`scripts/run_tests.lua`). One level down, the same trap held from T1 until T22: a test file's own `VimLeavePre` runs before the runner's guard, so one that raised, or that ran `0cquit`, still turned a failing run green. T22 closed those two shapes. A file now passes only when three things hold:
- its Neovim exited 0;
- it did not end on a signal;
- its records show at least one case, and every case run and passed.

The records are written in the file's own Neovim, where the test code runs, so they hold only against test code that does not mean to forge them. A file that writes a passing record for each of its cases, then ends its Neovim through a `VimLeavePre` of its own that raises, still passes (`scripts/run_tests.lua`, *Not guarded*).

## Example

The attack review of PR #4 (T1) measured five ways to end a run green with a failing case present (its guarantee 2, "defeated"); T1's fix round made each a test seen red first — `Left: 0` where 2 was expected — then had `scripts/run_tests.lua` replace `os.exit` for the runner's life, catch the rest on `VimLeavePre`, and exit non-zero unless every case ran and passed (T1's session note, *The runner owns the exit status*; the reds are listed in PR #4's body). A `MiniTest.finally` that raised stopped mini.test's queue and held the run for its 30-minute limit before it exited 1 — and ended it green under the attack reviewer's MU-limit mutant, which deleted the time-limit branch; a 10-second stall check replaced the limit. The re-measure of that fix round found the runner's own guard still defeatable: it read mini.test's `is_executing()`, which goes false before the runner decides, so a last case quitting three `vim.schedule` hops later exited 0 with `Fails (1)` printed, and a test that left a stub on `vim.cmd` made every failure exit 0. The correction (PR #4 head `5b323d8`) guards on a flag the runner sets itself and takes the Neovim functions it uses before any test file loads, and bounds the whole run with a timer (16 minutes by default).

**One level down, until T22.** T1's guard registers its `VimLeavePre` after the test file is sourced, so a `VimLeavePre` the file registers at its top level runs first. T22 (PR #85) kept that guard in each test file's own Neovim. Its attack review, at `5239471`, measured two shapes with `make test_file` (finding 4). Each exited 0 at that head and on the base before it, so the gap dates from T1.
- **A handler that raises.** Neovim then skips the guard's handler. A case that runs `qall!` next ends the file with exit 0, and the failing case after it never runs (`Fails (0)`).
- **A handler that runs `0cquit`.** It turns the guard's `cquit 1` into exit 0, with `Fails (1)` printed.

A second hole was new with T22's coordinator (finding 1). A file whose Neovim ended by a signal counted as passed, because `vim.system` reports such a process as `code = 0`, with the signal apart ([[Learnings/vim.system reports a process ended by a signal as code 0]]). A SIGKILL or SIGSEGV in a case gave `rc=0` with the whole case count.

T22's fix round adopted the review's rule, the three conditions above, red first (`8a6cb84`, `2f9af5d` on `dev`). The review had seen its own pins red at the head, and green under the rule, on 0.12.5 and 0.11.6.

## Why it matters

Anything that trusts a test run's exit code alone — an agent's report, a CI gate, a pre-merge verification — trusts every test file not to end the process. Make the runner, not the framework, own the status, from the cases it counted: in these cases `MiniTest.stop()` printed `Fails (0)` and the other four printed no summary at all, so neither the exit status nor the `Fails` line alone shows them — a run with no summary, or with fewer cases than the suite holds, is not green. Under T1's runner, a case that blocked Neovim synchronously was bounded only by an outside watchdog (T1's session note). T22's runner stops one with its time limit, since the case blocks only its file's Neovim. PR #89's records review measured it at `fb16544`, whose runner is `176fd21`'s, on 0.12.5: under `AINEO_TEST_RUN_LIMIT_MS=4000`, a case running `while true do end` ended `make test_file` with exit 2 in about 5 s, printing `the test run did not finish within 4 s`, and left no Neovim running.

Limits the fix does not remove: T22's session note, *Correction (2026-09-28)*, **Limits**, records what test code bent on the runner can still do. The re-measure measured the first two on both versions:
- through the runner's server (`$NVIM`) it can end the run with exit 0 and no summary: `os.exit(0)`, or the runner's `VimLeavePre` cleared, then `qall!`;
- through the same server it can print forged `Total` and `Fails` lines ahead of the real ones;
- a case can write a passing record for every case of its file, then end its Neovim through a raising `VimLeavePre`, and its file passes, because the records are written in that Neovim (`scripts/run_tests.lua`, *Not guarded*). PR #89's records review measured it at `fb16544` on 0.12.5: `rc=0`, `Fails (0)`, and the file's failing case never ran.

Each of these needs test code that means to do it.
