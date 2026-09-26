**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T21 | Claude's exit keeps the layout (D25, C2, C3): when Claude Code exits while the user is in its prompt, Normal mode returns in its window and the exit stays on screen; a wiped Claude terminal leaves no error and no extra window, and `\c` then starts a new session — regular (the user, 2026-09-26) | T20 | active |

It rests on **D25** (read it whole, with the user's words), C2 (the layout), C3 (the Claude session) and T20's `\c` (C1).

### The behaviours — EX1 to EX3 tested, each test seen red first; EX4 is an invariant

- **EX1 — Normal mode when Claude Code exits under your typing.** When Claude Code's process ends while Claude's window is current in Terminal mode, the mode returns to Normal there (`nvim_get_mode().mode == 'nt'`). Its exit stays on screen, and the next key acts as a Normal-mode command: it closes nothing. It holds:
  - after `/exit` typed to Claude Code, or any exit while the user types;
  - when Claude Code exits right after `\c` entered Terminal mode, at its start too (T20's guarantee review, finding 4: today the next key erases the exit message);
  - when `\c` was handled before Neovim saw the exit (T20's CT2 bound, the brief review's F6): once the exit is seen, Normal mode returns.
  
  Measure the mode with keys that stay pending (`child.type_keys`), as T20's tests do: a feedkeys `'x'` itself ends Terminal mode.
- **EX2 — a wiped Claude terminal leaves the layout whole.** When Claude's terminal buffer is wiped while Claude's window shows it — a key after the exit in Terminal mode, `:bwipeout!`, `:bdelete!` — from the layout's own tab or from another:
  - no error is raised and no window is added;
  - the next `\c` starts a new session and enters Terminal mode in it (T20's CT1); `\r` and `\i` then work as before.
  
  Measured on `dev` before T20 (T20's guarantee review, finding 1, `guarantee-probe3.lua`): from the layout's tab, a key after the exit wipes the terminal, Claude's window stays open on an empty unnamed buffer, `redirect()` puts the wiped buffer back and raises `Invalid buffer id` (`lua/aineo/layout/init.lua:327`) after opening a file column for the empty buffer, and the next `\c` lands in that empty buffer in Normal mode and starts no session. From another tab the window closes and `\c` works.
- **EX3 — the exit is still yours to see.** EX1 does not close, restart or hide anything: the exited terminal stays in Claude's window until the user wipes it or restarts with `\o`, as today.
- **EX4 — nothing else changes (an invariant).** T20's CT1–CT4, the file column and its redirect for real files, `\o`'s restart, the draft's hand-off after a reopen, T16's wrapping, and every existing case of the suite stay green unchanged.

The seam is yours under `tdd`, **inside `lua/aineo/layout/`**: the layout knows Claude's window and its buffer (`state.windows.claude`, `state.buffers.claude`). Whether `:stopinsert`, or another way, leaves Terminal mode from where you act is not measured: measure it, on both versions, and say so in your note. If EX1 or EX2 cannot be met without a file outside *You may touch*, stop at a green, pushed state and report a spec conflict.

### The orchestrator's readings, for your note's *Readings for the MVP review*

- EX1 applies to Claude's window only: another terminal of the user's keeps Neovim's own behaviour;
- EX1 leaves the user in Normal mode even when they were typing when Claude Code exited: a key they type then is a Normal-mode command.

### Facts, checked against `origin/dev` (the code `origin/dev` holds once PR #58 (T20) merges: the tree `525b22b`)

- **`lua/aineo/layout/init.lua`:** `state.windows` and `state.buffers` by role (lines 20–27); `has_window(role)` (lines 50–53) reads only whether the window is valid; `redirect(window, file)` (lines 315–329) sets `state.buffers[role]` back in the window at line 327, and `redirect_when_file()` (lines 336–347) schedules it for any buffer `is_file()` counts a file (`buftype` empty), an unnamed empty buffer among them; `reopen_closed_windows()` (lines 510–528) and `show_buffers()` (lines 531–538); `watch_windows()` (lines 547–559) is where its autocommands are made; `M.focus(role, arrangement)` (lines 664–676) opens the layout only when the role's window is gone.
- **`plugin/aineo.lua`** (read only): `focus()` calls `layout.focus()` with an arrangement made around `current_claude_terminal()`, which starts a session only when there is no terminal to show; `focus_claude()` enters Terminal mode only in Claude's own terminal while its session has not exited (`can_type_to_claude()`, T20).
- **T20's tests:** `tests/test_entry_claude_mode.lua`, its fakes (`exit`, `trust`, `ready`) and its way of observing the mode.
- **The help:** `doc/aineo.txt` › `*:Aineo-claude*` (lines 158–164: "Once Claude Code has exited it stays in Normal mode, since a key typed in Terminal mode would close the terminal and its exit with it.") and the paragraph after it (lines 166–170: "…They start Claude Code only when there is no terminal to show: before the first start, or once the terminal was wiped. Only `open` restarts an exited Claude Code."). What EX1 and EX2 change there is yours to correct.

### Baseline

- `dev` once PR #58 (T20) merges: its code is the tree `525b22b`, which the orchestrator's verification of PR #58 measured: 985 cases, `Fails (0)`, on 0.12.5 and 0.11.6, and lint clean (`evidence/baseline-525b22b.txt`). The other packet of this plan may merge before you start or while you work: if it merges before you start, re-measure the baseline on your base.

- **Run the whole suite on both versions, one at a time.** Under load, `test_send.lua`, the `session_status()` cases of `test_claude.lua`, `tests/test_health.lua:336`, `test_entry*.lua` and `tests/test_mcp_blocked_editor.lua` fail spuriously; re-run a surprising failure alone before you believe it. A whole 0.12.5 run that stops at the 960 s limit is not a result: re-run it, and run the stalled file alone. Check `uptime` before a whole run, and head each log with `nvim --version | head -1`.
  - On the host's 0.12.5: `make test`.
  - On 0.11.6, in this literal form (the worktree guard refuses `PATH=…:$PATH make`):

    ```
    env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test
    ```

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › D25, C2, C3, C1;
- `knowledge-vault/Sessions/2026-09-26 — T20 Claude terminal mode.md` › *Limits* and *Readings*;
- `<builds>/guarantee58/guarantee58-report.md`, findings 1 and 4, with its probes in `<builds>/guarantee58/tests/`;
- `doc/aineo.txt` › `*aineo-layout*` and `*aineo-commands*`;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `bugfix/t21-claude-exit` from `origin/dev`.
- **Class:** regular (the user, 2026-09-26: "Both, regular (Recommended)").
- **Model:** `opus`.
- **Resources:** `impl_t21_claude_exit`.
- **You may touch:**
  - `lua/aineo/layout/`;
  - `tests/test_layout*.lua` and `tests/test_entry*.lua`, new cases, or new files of those names;
  - `doc/aineo.txt`, **only** from `*:Aineo-claude*` to `an exited Claude Code.` in `*aineo-commands*`;
  - your session note.
  - The documentation this change invalidates: those help lines and the layout home's docstrings. Correct them in the same change and say so in your report.
- **You must not touch:**
  - `plugin/aineo.lua` (T19 and T12 follow there), `lua/aineo/claude/` (T19 runs beside you there), `lua/aineo/report/` (T17), `lua/aineo/draft/`, `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/health.lua`;
  - `tests/test_plugin.lua`'s frozen pins, `tests/helpers/`, `scripts/`, the `Makefile`;
  - `doc/aineo.txt` outside your lines;
  - the task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note;
  - the project note, the MVP readings review;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Never run the real `claude`.**
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your lines** run from `*:Aineo-claude*` to `an exited Claude Code.`.
  - **The other packets:** T19 adds a subsection `Claude's session ~` in `*aineo-layout*`, directly above `Input's draft ~`; T17 edits `*aineo-report*`.
  - **Before you push**, for each of `origin/feature/t19-claude-resume` and `origin/bugfix/t17-report-paths` that exists and is unmerged:
    1. `git fetch origin && git merge-tree --write-tree <your head> <branch>`; report any conflict it prints, in any file;
    2. `git show <tree id>:doc/aineo.txt > doc/aineo.txt` and `git show <tree id>:tests/test_doc.lua > tests/test_doc.lua`;
    3. `make test_file FILE=tests/test_doc.lua`, on both versions;
    4. `git checkout HEAD -- doc/aineo.txt tests/test_doc.lua`.

    Report the results.
- **Session note:** `knowledge-vault/Sessions/<the day you are dispatched> — T21 Claude exit.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored); if the harness refuses to create it, use your worktree's `.tests/` and say so. Prefix every file with `t21-`. Keep all scratch inside your worktree, never in `/tmp`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. You read and run its Neovim builds and the review files named above there, and write nothing.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- **T20's guarantee review measured the fault** (findings 1 and 4), older than T20, which T20 makes more common: `\c` now leaves the user in Claude's prompt.
- **Asked how the follow-up should fix it**, as put to the user: "When Claude Code exits while you're typing in its window (after /exit, or when it fails right at startup), Neovim closes its terminal on your next key. The exit message goes with it. From the layout's tab this also breaks the layout: a Lua error, an extra window, and \c no longer starts a new Claude. The breakage already happens on dev; T20 makes it more common. How should the follow-up fix it?" The user chose "Both, regular (Recommended)", described as: "When Claude Code exits while you're in its prompt, aineo puts you back in Normal mode, so the exit message stays and no key closes it. A wiped Claude terminal no longer breaks the layout either: no error, no extra window, and \c starts a new session. The fix spans two parts of the code, so it runs as a regular packet with three reviews." — over "Layout fix only, small fix" and "Leave it for now". That is D25.
- **Where it lives:** the question's "two parts of the code" were the layout and the Claude session. This brief keeps both in the layout home, which knows Claude's window and buffer, so that T19 can change the Claude home beside it (rule 2).

## Budget

Medium: two behaviours in the layout home, their tests and the help lines. If it grows past that, stop at a green, pushed state and report a true partial.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t21-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
