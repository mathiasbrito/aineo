# jobwait on a stopped job waits for it to die, whatever its timeout

**Tags:** #neovim #jobs #processes #timeouts #measured
**Discovered:** [[Sessions/2026-09-26 — T21 Claude exit]] (the attack review of PR #64, A5; T21's correction) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

`jobwait({id}, 0)` is not a poll for a job that `jobstop()` has already stopped but whose process still runs. Neovim waits, with no timeout, until the process has died. It then reports `-3` ("invalid job id"), not the exit status.

A process that ignores the signals therefore holds the editor until Neovim's kill timer sends SIGKILL:
- about 2 s for a pipe job;
- about 4 s for a terminal (pty) job.

`vim.uv.kill(pid, 0)` answers at once: `0` while the process exists, `nil, "ESRCH: no such process"` once it is gone.

## Example

- **T21's packet (PR #64)** told an ended Claude terminal by `jobwait({channel}, 0)`, on every `TermEnter`.
- **The attack review of PR #64** (at `70a43c7`, A5) stopped the deaf fake, which ignores the hangup, with `jobstop()`, then typed `i` in its terminal. The editor answered after 4001 ms on 0.12.5 and 4002 ms on 0.11.6, where `dev` answered in 0 ms.
- **The fix round** replaced the wait by a record kept at `TermClose` (`3371260` on `dev`).
- **The correction** added `vim.uv.kill(b:terminal_job_pid, 0)` for an exit that no `TermClose` handler saw (`9db0e4d` on `dev`). A stopped process still counts as running until its SIGKILL.
- **This pass, in bare Neovim** (2026-09-28, `probe-jobs.lua` in [[Attachments/learnings-probes-2026-09-28.txt]]). A job ran `sh -c 'trap "" HUP TERM; while :; do sleep 1; done'` and got `jobstop()` after 300 ms. The output on 0.12.5 was:

  ```
  pipe job: vim.uv.kill(pid, 0) right after jobstop() returned 0 in 0 ms
  pipe job: jobwait({id}, 0) returned -3 after 2002 ms
  pipe job: vim.uv.kill(pid, 0) afterwards returned nil ESRCH: no such process
  terminal job: vim.uv.kill(pid, 0) right after jobstop() returned 0 in 0 ms
  terminal job: jobwait({id}, 0) returned -3 after 4005 ms
  terminal job: vim.uv.kill(pid, 0) afterwards returned nil ESRCH: no such process
  ```

  0.11.6 gave the same lines, with 2002 ms and 4004 ms.

**Why.** From `src/nvim/eval/funcs.c` and `src/nvim/event/proc.c`, read by this pass at both tags, fetched with `gh api`.
- **The unbounded wait.** `f_jobwait()` (`v0.12.5` l.3770–3774, `v0.11.6` l.4206–4210) checks each job with `proc_is_stopped()`, which holds once the process has exited or `stopped_time` is set; `jobstop()` sets it (`event/proc.h`). For such a job it calls `proc_wait(&chan->stream.proc, -1, NULL)`, a wait with no timeout, next to the comment "Ensure all callbacks on its event queue are executed. #15402". Then it counts the job as invalid.
- **What `jobstop()` sends.** `proc_stop()` (`event/proc.c`, `v0.12.5` l.217, `v0.11.6` l.220) sends SIGTERM to a pipe job's process tree. For a pty job it closes the streams and the master instead, which sends SIGHUP.
- **The kill timer.** `children_kill_cb()` (l.254, l.256) fires `KILL_TIMEOUT_MS` (2000) later. It sends SIGKILL to a pipe job. A pty job first gets SIGTERM, then SIGKILL after another 2000 ms.

## Why it matters

Never use `jobwait(…, 0)` to ask "is it still running?" of a job that anything may have stopped: the user, another plugin, or the plugin's own quit path. Use `vim.uv.kill(pid, 0)`, which does not wait. A process id can be reused once the process is reaped, so pair the read with a record the exit handler keeps, as T21 does.

**Limits:**
- measured on 0.11.6 and 0.12.5, macOS;
- measured for processes that ignore SIGHUP and SIGTERM. For one that dies on the first signal the wait should be short, but that was not measured.
