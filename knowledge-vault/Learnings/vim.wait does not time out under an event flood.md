# vim.wait does not time out under an event flood

**Tags:** #neovim #event-loop #processes #timeouts
**Discovered:** [[Sessions/2026-09-25 — T8 health and help]] (the attack review of PR #21) · [[Sessions/2026-09-25 — Wave 5 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

In Neovim 0.11.6, `vim.wait(ms, …)` does not return at `ms` while a child process keeps writing to its output: the timeout runs out only once the stream stops. `SystemObj:wait(ms)` is built on `vim.wait()`, so it is no bound either for a command that writes without end. A bound that must hold is a `vim.uv` timer of your own that kills the process, and output that must stay small is capped in the `stdout`/`stderr` handlers.

## Example

The attack review of PR #21 measured this at `6cf76b4`, on Neovim 0.11.6 under macOS:

- **`vim.wait()` on its own.** `vim.wait(1000, function() return false end, nil, true)`, with a child writing stdout continuously to a no-op handler, returned after **24 009 ms**. It returned only once the reviewer killed the writer.
- **Inside the health check.** `:checkhealth aineo` with `claude.cmd = { '/usr/bin/yes' }` (macOS `yes --version` prints `--version` forever) had not returned after 171 s. Its maximum resident size was 2 158 690 304 bytes. Sampled, the editor was spinning in `ex_checkhealth → nlua_wait → loop_poll_events → uv_run`.
- **`vim.system`'s `timeout` option** is a libuv timer, and it did fire under the same flood, at 1 166 ms. By then it had collected 137 510 100 bytes of stdout.
- **The fix,** in `lua/aineo/health.lua` › `run_within_bound()`, was measured on the same input at 3 008 ms and 14.6 MB:
  - a `vim.uv` timer of the check's own sends SIGKILL to the process group, since the child is started with `detach = true`;
  - `vim.wait()`'s predicate reads the timer's flag;
  - the group is killed again whenever the wait returns before the command completed, which also covers Ctrl-C;
  - each output keeps its first 1024 bytes.

Which step inside `vim.wait()` fails to see the time pass was not traced in Neovim's source. The claim rests on the measurements above.

## Why it matters

Any Neovim code that waits on a child it does not control must not bound the wait with `vim.wait()` or `SystemObj:wait()` alone. That includes a health check, a version probe, and a formatter or linter run synchronously. A misbehaving child (a flood, a wrapper whose grandchild holds the pipes, a `yes`) otherwise freezes the editor and grows its memory without limit. The limits of this finding:
- it was measured on 0.11.6 only;
- the flood was stdout at full speed; a slow trickle was not measured;
- a timer's kill reaches the process group, not a descendant that starts a session of its own (MR93 of [[Review/2026-09-24 — v1 MVP readings review]]).
