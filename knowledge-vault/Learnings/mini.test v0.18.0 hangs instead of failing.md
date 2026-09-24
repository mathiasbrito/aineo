# mini.test v0.18.0 hangs instead of failing

**Tags:** #testing #neovim #mini-test #trap
**Discovered:** [[Sessions/2026-09-23 — T1 tooling foundation]]
**Applies to:** [[Projects/aineo]]

## The insight

Run the way mini.nvim's `TESTING.md` proposes (`nvim --headless --noplugin -u scripts/minimal_init.lua -c "lua MiniTest.run()"`), mini.test at tag `v0.18.0` (commit `1345d19`) **does not exit** when the suite is broken: a test file that fails to parse, a test file that `require`s a missing module at its top level, a run that collects no case, and `MiniTest.run_file()` on a path that does not exist each print an error (or "No cases to execute.") and then keep Neovim running. A broken suite reads as a hang, not a failure — and a `require` of a module not yet written is the usual first red under `tdd`.

## Example

Measured by the brief review of wave 1, 2026-09-23, with a 5-second watchdog inside Neovim (`knowledge-vault/Implementation/Waves/00001-tooling/brief-review.md`, finding 6 and its table): `local T = MiniTest.new_set(` as a test file gave E5108 and no exit; an empty `tests/` gave "No cases to execute." and no exit; `MiniTest.run_file('tests/test_typo.lua')` gave "cannot open" and no exit. On `main` (`561751e`) zero cases pass through the reporter and exit **0** instead — a green run that tested nothing. T1's session note lists the four cases and `scripts/run_tests.lua`, which exits non-zero on each (*The runner exits instead of hanging*).

## Why it matters

An agent that runs such a suite in the foreground stalls until its tool timeout and reports nothing useful; a CI job waits for its own limit. Wherever mini.test is driven directly, the runner around it — not mini.test — decides the exit status, and every way a suite can be broken is a test of that runner. The behaviour is the tag's: re-measure after moving the pin.
