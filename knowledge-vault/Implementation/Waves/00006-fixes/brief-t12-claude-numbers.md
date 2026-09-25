**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T12 | `\tcn` toggles the line numbers of Claude's window (D16), with its `:Aineo` subcommand, `<Plug>` mapping, health check and help | T8 | active |

It rests on:
- **D16** — "`\tcn` toggles the line numbers of Claude's window, with `:Aineo claude-numbers` and `<Plug>(aineo-claude-numbers)` beside it, as for every command (C1)";
- **C1** — the entry point: the prefix is mapped only where the user has not mapped it, configurable or off;
- **C2** — the layout;
- **C7** — the health check;
- **D13** — `prefix`.

### The behaviours — one test each, each seen red first

- **CN1 — hide.** With the layout open and line numbers shown in Claude's window (`'number'` or `'relativenumber'` on), `\tcn` in Normal mode turns both off in that window.
- **CN2 — show again.** Pressed again, `\tcn` restores the values that window had when they were hidden. A Claude window that never had line numbers gets `'number'`.
- **CN3 — only Claude's window.** No other window's options change. The current window, the cursor and the mode stay where they were.
- **CN4 — no Claude window.** When Claude's window is not shown — the layout is closed, or its Claude window was closed — the command changes nothing. It gives one warning through the same path every action's failure takes (`run()`), naming why.
- **CN5 — the three doors.**
  - `:Aineo claude-numbers` and `<Plug>(aineo-claude-numbers)` do what `\tcn` does.
  - `:Aineo` completion offers `claude-numbers`.
  - `:Aineo` without a known subcommand lists six.
- **CN6 — the prefix rule.**
  - `<prefix>tcn` is mapped under the same rule as the other five keys: never over the user's own global mapping of that sequence.
  - It follows a changed `prefix`.
  - `prefix = false` maps nothing.
- **CN7 — health.** `:checkhealth aineo` checks `<prefix>tcn` as it checks the other keys. `lua/aineo/health.lua`'s key table gains the key, and the test that compares it with `plugin/aineo.lua`'s mappings stays green.
- **CN8 — help.**
  - `doc/aineo.txt` documents the command, the `<Plug>` mapping and the key, with the tags the derived-tag test in `tests/test_doc.lua` requires: `:Aineo-claude-numbers`, `<Plug>(aineo-claude-numbers)` and `aineo-\tcn`.
  - These edits go **only inside** `*aineo-commands*`, `*aineo-mappings*` and `*aineo-keys*`.

**Where the window logic lives.** Finding Claude's window and changing its options belongs to the layout (C2). The layout exposes only `open`, `focus` and `input_buffer` today, so add a public function there. Do not reach into its tables from `plugin/aineo.lua` (`modularity`). The function's shape is yours under `tdd`.

### Facts, checked against `origin/dev` (`9af91a6`)

- **`plugin/aineo.lua`:**
  - `SUBCOMMANDS = { 'send', 'open', 'report', 'input', 'claude' }` (line 27);
  - `ACTIONS` (line 152) and `run(action)` (line 195);
  - `PREFIX_KEYS = { send = 's', open = 'o', report = 'r', input = 'i', claude = 'c' }` (line 220);
  - the prefix mapping builds `prefix .. PREFIX_KEYS[subcommand]` (line 247). Every key today is one character; `tcn` is the first of three.
- **`lua/aineo/health.lua`:** its own `PREFIX_KEYS` at line 241.
- **`tests/test_health.lua`:** lists the five per-key lines in several cases, lines 499–503 and 615 among them. Each such list gains a sixth line.
- **`tests/test_plugin.lua` › *defines :Aineo, its <Plug> mappings, the prefix mappings and, once started, the StdinReadPost autocommand alone*** (line 62) counts every keymap `plugin/aineo.lua` defines. It gains `n <Plug>(aineo-claude-numbers)` and `n \tcn`. **That list is the only change to that file.** The pin *loads the configuration alone in a headless start* stays as it is.
- **`lua/aineo/layout/init.lua`:**
  - `---@alias aineo.layout.Role 'claude'|'report'|'input'` (line 16);
  - public `M.open`, `M.focus`, `M.input_buffer`; `role_of(window)` is internal (line 34).
- **Your Neovim config** (the user's, read-only on 2026-09-25) maps nothing under `\t`. Its `maplocalleader` is `\` (R3), which the health check already warns about.

### Baseline

**You are dispatched after T13 merges**, since T13 also changes `plugin/aineo.lua`, `lua/aineo/health.lua` and `tests/test_health.lua`. T13 makes the suite green on 0.12.5 and 0.11.6; its merge's counts are this packet's baseline. Before dispatch, the orchestrator re-checks every fact above against that `dev` and records any change as a dated amendment of this brief. Run the whole suite on both versions:
- the host's 0.12.5;
- `<scratchpad>/nvim-0.11.6/nvim-macos-arm64/bin/nvim` first on `PATH`.

Report both counts.

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › D16, C1, C2, C7, D13;
- `doc/aineo.txt` › `*aineo-commands*`, `*aineo-mappings*`, `*aineo-keys*`;
- `knowledge-vault/Sessions/2026-09-25 — T7 entry point.md` for how the prefix is mapped;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t12-claude-numbers` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t12_claude_numbers`.
- **You may touch:**
  - `plugin/aineo.lua`, its subcommand, action and key tables — not `start_up` or what it reaches;
  - `lua/aineo/layout/` and `tests/test_layout*.lua`, new cases only; every layout case that exists stays as it is and green;
  - `lua/aineo/health.lua`, its key table only, and `tests/test_health.lua`;
  - `tests/test_plugin.lua`, the one list named above;
  - `tests/test_entry_*.lua`, new cases;
  - `doc/aineo.txt`, **only inside** `*aineo-commands*`, `*aineo-mappings*` and `*aineo-keys*`;
  - your session note.
  - The documentation this change invalidates: those three help sections. Correct them in the same change and say so in your report.
- **You must not touch:**
  - `lua/aineo/report/`, the Report's tests, and `doc/aineo.txt` outside the three sections. T9 owns `*aineo-report*` in this wave.
  - `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/send/`.
  - `scripts/`, `tests/helpers/`, the `Makefile`.
  - The task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note instead.
  - The project note.
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **The help is shared under rule 2's section exception.** Before you push, re-run the merge check against T9's branch if it exists: `git fetch origin && git merge-tree --write-tree <your head> origin/bugfix/t9-report-colours` (exit 0 and no conflict listed means clean). Report the result.
- **Session note:** `knowledge-vault/Sessions/2026-09-25 — T12 Claude line numbers.md`.
- **Scratch prefix:** `t12-`, under `<scratchpad>`, the orchestrator's scratch directory, which your dispatch message names.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- **The user's request** (2026-09-25): "A toogle for line number for the claude buffer "\tcn" as the command". It is D16.
- **The orchestrator's readings, for the user to confirm.** Name each in your session note's *Readings for the MVP review*:
  - the subcommand and `<Plug>` names;
  - CN1's clearing of `'relativenumber'` together with `'number'`;
  - CN2's restoring of the earlier values;
  - CN4's warning;
  - what `\o` does to a toggled window it rebuilds. The rebuilt window takes the user's defaults, unless you find a reason otherwise and report it.
- **Not in scope.** A Terminal-mode key to leave Claude's terminal was asked for and dropped by the user (2026-09-25: "No new key").

## Budget

Medium: one command through its three doors, a layout function, the health key and the help. If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t12-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
