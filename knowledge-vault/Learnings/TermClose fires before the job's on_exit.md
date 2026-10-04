# TermClose fires before the job's on_exit

**Tags:** #neovim #terminal #jobs #autocommands #measured
**Discovered:** [[Sessions/2026-09-26 — T21 Claude exit]] · [[Sessions/2026-09-27 — T19 Claude resume]] (both from the brief review of PR #62) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

When the job of a terminal buffer ends by itself, Neovim runs `TermClose` for the buffer before it calls the job's `on_exit`. By `TermClose`:
- the process's last output is already in the buffer;
- a user who was typing to it is still in Terminal mode.

`:stopinsert` in a `TermClose` handler leaves Terminal mode, to `nt`, whether it is called directly or through `vim.schedule()`. So `TermClose` is where a plugin reacts to an exit that should change the mode. `on_exit` comes after it, and there the buffer still holds the process's output to read. The exception is a terminal that a `TermClose` handler has wiped: then there is nothing left to read (T19's session note).

## Example

- **The brief review of PR #62** (T19 and T21, at `15c7e20`; its code is `617e4a5`), on 0.12.5 and 0.11.6:
  - `TermClose` came before `on_exit` in 5 runs of 5 on each version (`brief-order.lua`);
  - a message the process printed before it exited was in the buffer at `TermClose` and at `on_exit` in 8 runs of 8, for an `sh` writer and for an `nvim -l` writer;
  - a `TermClose` handler saw mode `t` with the terminal current. After its `:stopinsert` the mode was `nt`, and the next `x` gave only `E21`, the terminal kept.
- **T21** leaves Terminal mode as Claude Code exits, from a `TermClose` handler (`leave_terminal_mode_as_claude_exits()`; `3371260`, `9db0e4d` on `dev`).
- **T19** reads Claude Code's failed resume from the terminal's lines at `on_exit` (`found_no_conversation()`).
- **This pass, in bare Neovim** (2026-09-28, `probe-jobs.lua` in [[Attachments/learnings-probes-2026-09-28.txt]]): a terminal job `sh -c 'exit 3'`, with a buffer-local `TermClose` autocommand and an `on_exit`. It gave `TermClose then on_exit` in 5 runs of 5, on 0.12.5 and on 0.11.6.

**Why.** Not read in Neovim's source; the order was measured.

## Why it matters

- **Changing the mode on an exit** belongs in `TermClose`, before anything the job's own callback does.
- **Reading the process's last words** works at either event.
- **A handler that must never miss an exit needs a second check.** An exit can pass without any `TermClose` handler running:
  - `TermClose` is in `'eventignore'`;
  - the exit is processed inside `:noautocmd`;
  - a user's `TermClose` autocommand re-creates the handler's group before the handler runs.

  T21's re-measure measured all three. T21's correction added a read of the process ([[Learnings/jobwait on a stopped job waits for it to die, whatever its timeout]]).
- **Limits:**
  - measured on 0.11.6 and 0.12.5, for jobs that end by themselves;
  - for a terminal wiped while its job runs, `TermClose` comes inside the wipe ([[Learnings/bwipeout of a running terminal shows the next buffer before BufWipeout]]); its order against `on_exit` there was not measured.
