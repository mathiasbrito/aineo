**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T20 | `\c` moves to Claude's window in Terminal mode, the cursor in Claude's prompt; when Claude's session has ended, it stays in Normal mode (C1) — a small fix (the user, 2026-09-26) | T14 | active |

It rests on C1, the entry point, and on the user's words of 2026-09-26 (*What was decided already*).

### The behaviours — CT1 and CT2 tested, each test seen red first; CT3 and CT4 are invariants

- **CT1 — `\c` leaves you typing to Claude.** After `\c`, the current window is Claude's and the mode is Terminal mode (`nvim_get_mode().mode == 't'`), so the next keys reach Claude Code's prompt. It holds:
  - with the layout open and the cursor in the Report, in Input, or in the file column;
  - with Claude's window closed, so that `\c` reopens it;
  - from another tab, where `\c` moves to the layout's tab;
  - while the session is starting (`'starting'`: Claude Code's startup or a dialog, such as the trust dialog): the keys then reach the dialog.
- **CT2 — not on an ended session.** When Claude's session has ended (`require('aineo.claude').session_status()` returns `'exited'`), `\c` moves to Claude's window and stays in Normal mode. In Terminal mode, a key on an ended terminal would close it.
- **CT3 — one action, three ways in (an invariant; a reading).** `\c`, `<Plug>(aineo-claude)` and `:Aineo claude` run one action today (`ACTIONS.claude`, `plugin/aineo.lua:204–206`), so all three enter Terminal mode. Name it in your note's *Readings for the MVP review*: the user asked for `\c`.
- **CT4 — nothing else changes (an invariant).** `\r` and `\i` leave the mode as today; the layout's windows, the draft's hand-off after a reopen (`focus()`, `plugin/aineo.lua:179–189`), and every existing case of `tests/test_entry*.lua`, `tests/test_plugin.lua` and `tests/test_health.lua` stay green unchanged.

The seam is yours under `tdd`. For example, the `claude` action could enter Terminal mode after `focus('claude')` when the session is not `'exited'`. Mind when a mode change takes effect: a mapping's callback and an Ex command end before Neovim acts on `:startinsert`; measure the mode after the key, in the child.

### Facts, checked against `origin/dev` (`2b75fc0`)

- **`focus(role)`** (`plugin/aineo.lua:179–189`) moves the cursor to the layout's window for `role`, reopening the layout when the window is gone, around `current_claude_terminal()` (`:135–140`); nothing enters Terminal mode.
- **`ACTIONS.claude`** (`:204–206`) calls `focus('claude')`; `PREFIX_KEYS` maps `c` to it.
- **The Claude home's status:** `session_status()` (`lua/aineo/claude/init.lua:224–236`) returns `'ready'`, `'starting'`, `'exited'` with the exit code, or nothing before a session has started. The composition root may call it inside a callback (the modularity skill's direction table).
- **The tests:** `tests/test_entry.lua:504–519` moves the cursor with each `<Plug>` from another tab; `tests/test_entry_prefix.lua` types the prefix keys; `tests/test_entry_draft.lua:293` runs the first `\i`, `\r` or `\c`. The fake `claude` (`tests/helpers/`) can be `'ready'`; read how its other states are made before you build an ended session.
- **The help:** `doc/aineo.txt:158`, in `*aineo-commands*` (`:Aineo claude` "Moves the cursor to Claude's terminal."); `:188–189`, in `*aineo-mappings*` (`<Plug>(aineo-claude)` "Does what |:Aineo-claude| does."); `:204–205`, in `*aineo-keys*` (`\c`); and line 28, in the introduction (`*aineo*`), which says `\r`, `\i` and `\c` "move to the Report, Input and Claude".

### Baseline

- `dev` at `2b75fc0`, T14 merged: 890 cases, `Fails (0)`, on 0.12.5 and 0.11.6 (`evidence/baseline-2b75fc0.txt`, the orchestrator's verification of PR #46, whose tree has the same code).
- If T10 (PR #52) has merged when you start, its cases add to the count; re-measure the baseline on your base first.

- **Run the whole suite on both versions, one at a time.** Under load, `test_send.lua`, `session_status()`, `tests/test_health.lua:336`, `test_claude.lua`, `test_entry*.lua` and `tests/test_mcp_blocked_editor.lua` fail spuriously; re-run a surprising failure alone before you believe it. A whole 0.12.5 run that stops at the 960 s limit is not a result: re-run it, and run the stalled file alone. Check `uptime` before a whole run.
  - On the host's 0.12.5: `make test`.
  - On 0.11.6, in this literal form (the worktree guard refuses `PATH=…:$PATH make`):

    ```
    env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test
    ```

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › C1, C3 and the *Architecture* line of v1's commands;
- `doc/aineo.txt` › `*aineo-commands*`, `*aineo-mappings*` and `*aineo-keys*`;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `bugfix/t20-claude-terminal-mode` from `origin/dev`.
- **Class:** **small fix** (the orchestrate skill, §3), called by the user on 2026-09-26 ("Small fix, right after T14 (Recommended)"). It changes one behaviour, the mode `\c` leaves you in, in `plugin/aineo.lua` outside the autostart, with its tests.
  - If it needs a file outside *You may touch*, or reaches any of these, stop at a green, pushed state and report a true partial: `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/health.lua`, `lua/aineo/init.lua`, the autostart in `plugin/aineo.lua` (`start_up` and what it reaches), `scripts/`, `tests/helpers/`, the `Makefile`.
  - Title the pull request `Small fix: \c leaves you typing to Claude`. No commit subject says "small" (root `CLAUDE.md`).
  - Re-run every mutant survivor on the test files the pull request adds or modifies.
- **Model:** `opus`.
- **Resources:** `impl_t20_claude_terminal_mode`.
- **You may touch:**
  - `plugin/aineo.lua`, the `claude` action and `focus()`'s docstring, outside the autostart;
  - `tests/test_entry*.lua`, new cases only, or a new `tests/test_entry_claude_mode.lua`;
  - `doc/aineo.txt`, only the lines that say what `:Aineo claude`, `<Plug>(aineo-claude)` and `\c` do, inside `*aineo-commands*`, `*aineo-mappings*` and `*aineo-keys*`, and line 28's summary in the introduction;
  - your session note.
  - The documentation this change invalidates is those help lines and the docstrings of `focus()` and the `claude` action. Correct them in the same change and say so in your report.
- **You must not touch:**
  - `lua/aineo/`, every home;
  - `tests/test_plugin.lua`'s frozen pins, `tests/helpers/`;
  - `doc/aineo.txt` elsewhere. T10 (PR #52) edits `*aineo-report*`;
  - the task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note;
  - the project note;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your lines** are the three entries named above and line 28.
  - **The other packet:** T10 (PR #52) edits `*aineo-report*`, from `8. THE AGENT REPORT` to `the working directory of its own moment.`.
  - **Before you push**, for `origin/bugfix/t10-report-links` if it exists and is unmerged:
    1. `git fetch origin && git merge-tree --write-tree <your head> origin/bugfix/t10-report-links`;
    2. `git show <tree id>:doc/aineo.txt > doc/aineo.txt` and `git show <tree id>:tests/test_doc.lua > tests/test_doc.lua`;
    3. `make test_file FILE=tests/test_doc.lua`, on both versions;
    4. `git checkout HEAD -- doc/aineo.txt tests/test_doc.lua`.

    Report the results.
- **Session note:** `knowledge-vault/Sessions/<the day you are dispatched> — T20 Claude terminal mode.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). Prefix every file there with `t20-`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. You read and run its Neovim builds there, and write nothing.
- **Never run the real `claude`.**
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- **The user asked, on 2026-09-26:** "also one more feature '\c' must move to the claude window in insert mode, cursor on the prompt."
- **Asked how it should run**, as put to the user: "T20: `\c` moves to Claude's window and enters Terminal mode, so the cursor sits in Claude's prompt ready to type. If Claude's session has ended, `\c` stays in Normal mode, so a keypress can't close the ended terminal." The user chose "Small fix, right after T14 (Recommended)", described as: "One behaviour in one file, no new spec row: two reviews. It starts as soon as T14 merges, before T12 (\tcn), which touches the same file."
- **No new row:** `\c` still moves to Claude (C1); T16 changed the right column's wrapping the same way.

## Budget

One behaviour with its tests: a small packet. If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t20-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
