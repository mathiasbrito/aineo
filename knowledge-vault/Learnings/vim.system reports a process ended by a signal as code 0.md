# vim.system reports a process ended by a signal as code 0

**Tags:** #neovim #processes #testing #trap #measured
**Discovered:** [[Sessions/2026-09-27 — T22 parallel runner]] (the attack review of PR #85, finding 1) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

`vim.system()` reports a process that a signal ended with `code = 0`, and the signal's number in `signal`. So `code == 0` alone reads a killed or crashed process as a success. A process succeeded only when `code == 0` **and** `signal == 0`.

There is one exception. When `vim.system`'s own timeout ended the process, a `code` of 0 is turned into 124, with the signal it sent still in `signal`. That covers the timeout of `SystemObj:wait()`, which sends SIGKILL, and the `timeout` option, which sends SIGTERM.

## Example

- **A crashed test file read as passed.** T22's first coordinator (PR #85) decided a test file's run by `code == 0` alone. Its attack review (at `5239471`, 0.12.5, finding 1) measured `code=0` for processes ended by KILL, TERM, SEGV, ABRT, HUP and INT, and for a Neovim that SIGKILLs itself (`code=0 signal=9`). A file whose Neovim was SIGKILLed or crashed in a case gave `rc=0` with the whole case count.
- **The fix.** T22's fix round starts each file's Neovim with `vim.uv.spawn` and passes a file only when its Neovim exited 0, **not on a signal**, and its records show every case passed (`file_passed()` in `scripts/run_tests.lua`, `8a6cb84` on `dev`). See [[Learnings/A test case can end a mini.test run green]].
- **Both versions, in bare Neovim.** PR #90's records review (at `c25bb30`, its finding 7) measured `code=0` with `signal` 9, 15 and 11 for a shell that killed itself with KILL, TERM and SEGV, on 0.12.5 and 0.11.6. Its correction re-ran that probe with two timeout cases added (2026-09-28, at the same head, `probe-system-signal.lua` in [[Attachments/learnings-probes-2026-09-28.txt]]). The output is identical on both versions:

  ```
  sh kills itself with KILL: code=0 signal=9
  sh kills itself with TERM: code=0 signal=15
  sh kills itself with SEGV: code=0 signal=11
  sleep 5, ended by :wait(200): code=124 signal=9
  sleep 5, ended by { timeout = 200 }: code=124 signal=15
  ```

**Why.** `_on_exit()` in `runtime/lua/vim/_core/system.lua` at `v0.12.5` (l.349–391), and in `runtime/lua/vim/_system.lua` at `v0.11.6` (l.279–321), builds the result from the `code` and `signal` that libuv's exit callback passed it. It changes `code` in one place only (`v0.12.5` l.371–375, `v0.11.6` l.301–305): when `code` is 0 or 1 and the process was ended by the timeout, `code` becomes 124. The comments there say 0 is what Unix reports and 1 what Windows reports. The correction read both releases' own runtimes. It did not read libuv's source; that a signalled process arrives with `code` 0 rests on the measurements above.

## Why it matters

- **`code == 0` does not mean success** unless `signal == 0` too. That covers a test runner, a build step and a health check that runs a tool.
- **124 is not the process's own exit code.** It means `vim.system` gave up on the process; `signal` says how it ended it.
- See also [[Learnings/vim.system reports an exit only once the output pipes close]], the other way `vim.system`'s exit report misleads.
- **Limits:**
  - KILL, TERM and SEGV measured on 0.11.6 and 0.12.5; ABRT, HUP and INT on 0.12.5 only (the attack review of PR #85);
  - macOS only; the Windows `code` of 1 is from the source's comment, not measured.
