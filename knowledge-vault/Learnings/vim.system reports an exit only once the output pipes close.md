# vim.system reports an exit only once the output pipes close

**Tags:** #neovim #processes #timeouts #testing #measured
**Discovered:** [[Sessions/2026-09-27 — T22 parallel runner]] (the attack review of PR #85, finding 6) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

`vim.system()` calls `on_exit`, and `SystemObj:wait()` returns, only when two things have happened:
- the process has exited;
- its captured stdout and stderr have both reached end of file.

A descendant that inherits those pipes and outlives the process holds the result back until it closes them, however long that is. Examples are a daemon, a `cmd &`, or a wrapper's grandchild. `:wait(ms)` then returns `nil`, after twice `ms`.

Two ways around it:
- with `stdout = false, stderr = false`, no pipe is made, and the exit is reported at once;
- `vim.uv.spawn()` with the output sent to a file reports the exit from libuv's exit callback.

## Example

- **A process holding the pipes.** The attack review of PR #85 (T22, at `5239471`, 0.12.5, finding 6) ran a passing test file that started `vim.uv.spawn('sleep', { args = { '40' }, stdio = { nil, 1, 2 } })`.
  - The file counted as "running" after its Neovim had exited, and the runner stalled to its 15 s limit (`rc=2`). The base runner finished in 0.2 s.
  - T22's fix round starts each file's Neovim with `vim.uv.spawn`, its output to a file, and records the ending in libuv's exit callback (`scripts/run_tests.lua`, `8a6cb84` on `dev`).
- **This pass, in bare Neovim** (2026-09-28, `probe-system-exit.lua` in [[Attachments/learnings-probes-2026-09-28.txt]]). The command was `sh -c 'sleep 3 & exit 3'`: `sh` exits at once with 3, and its `sleep 3` keeps sh's stdout and stderr.

  ```
  0.12.5
  vim.system, output captured: on_exit after 3016 ms, code=3
  vim.system, stdout = false, stderr = false: on_exit after 8 ms, code=3
  vim.system(...):wait(500): returned after 1006 ms, result=nil
  vim.uv.spawn, output to a file: exit callback after 9 ms, code=3
  0.11.6+ge8b87a554f
  vim.system, output captured: on_exit after 3009 ms, code=3
  vim.system, stdout = false, stderr = false: on_exit after 7 ms, code=3
  vim.system(...):wait(500): returned after 1006 ms, result=nil
  vim.uv.spawn, output to a file: exit callback after 7 ms, code=3
  ```

**Why.** The code is `_on_exit()` in `runtime/lua/vim/_core/system.lua` at `v0.12.5` (l.349–391), and in `runtime/lua/vim/_system.lua` at `v0.11.6` (l.279–321).
- On exit it closes the process handle, stdin and the timer. It leaves stdout and stderr open ("#30846: Do not close stdout/stderr here, as they may still have data to read. They will be closed in uv.read_start on EOF.").
- It then starts a libuv check handle. The handle builds the result and calls `on_exit` only once every pipe `is_closing()`.
- A pipe that was never made, as with `stdout = false`, is `nil`, and the loop skips it.
- `SystemObj:wait()` (`v0.12.5` l.135–151, `v0.11.6` l.87–103) waits for its timeout, then kills through the process handle with SIGKILL, then waits the same timeout again. The process has already exited by then; the descendant is never signalled.

This pass read both releases' own runtimes.

## Why it matters

- **An exit code that must come in time**, when the process may leave descendants, cannot come from `vim.system`'s `on_exit`. That covers a test runner, a formatter run on save, and a health check.
- **`:wait(ms)` does not bound the time spent**: it waits up to twice `ms` and returns no result.
- See also [[Learnings/vim.wait does not time out under an event flood]], another way such a wait is not bounded, and [[Learnings/vim.system reports a process ended by a signal as code 0]], another way `vim.system`'s exit report misleads.
- **Limits:**
  - measured on 0.11.6 and 0.12.5, macOS.
