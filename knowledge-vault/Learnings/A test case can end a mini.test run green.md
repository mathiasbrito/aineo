# A test case can end a mini.test run green

**Tags:** #testing #neovim #mini-test #trap
**Discovered:** [[Sessions/2026-09-23 — T1 tooling foundation]]
**Applies to:** [[Projects/aineo]]

## The insight

When test cases run inside the runner's own Neovim, a case can end the whole run — and the exit status is whatever that ending says, not what the suite found. `MiniTest.stop()`, `:quit`, `:qall!`, `:0cquit` and `os.exit(0)` inside a case each made `make test` exit 0 while the suite held a failing case. A green exit status is only a claim until the runner that produced it decides it from the cases it counted.

## Example

The attack review of PR #4 (T1) measured five ways to end a run green with a failing case present (its guarantee 2, "defeated"); T1's fix round made each a test seen red first — `Left: 0` where 2 was expected — then had `scripts/run_tests.lua` replace `os.exit` for the runner's life, catch the rest on `VimLeavePre`, and exit non-zero unless every case ran and passed (T1's session note, *The runner exits instead of hanging*). A `MiniTest.finally` that raised stopped mini.test's queue and held the run for its 30-minute limit, ending green; a 10-second stall check replaced the limit. The re-measure of that fix round found the runner's own guard still defeatable: it read mini.test's `is_executing()`, which goes false before the runner decides, so a last case quitting three `vim.schedule` hops later exited 0 with `Fails (1)` printed, and a test that left a stub on `vim.cmd` made every failure exit 0. The correction (PR #4 head `5b323d8`) guards on a flag the runner sets itself and takes the Neovim functions it uses before any test file loads, and bounds the whole run with a timer (16 minutes by default).

## Why it matters

Anything that trusts a test run's exit code alone — an agent's report, a CI gate, a pre-merge verification — trusts every test file not to end the process. Make the runner, not the framework, own the status, from the cases it counted: in these cases `MiniTest.stop()` printed `Fails (0)` and the other four printed no summary at all, so neither the exit status nor the `Fails` line alone shows them — a run with no summary, or with fewer cases than the suite holds, is not green. Limits the fix does not remove: a case that blocks Neovim synchronously is bounded only by an outside watchdog (T1's session note).
