**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md`, since you are dispatched as that specialist, and `neovim-lua-developer.md`, whose rules it also binds.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T13 | Neovim 0.12 compatibility (D10): the suite green on 0.12.5 and on 0.11.6 — Neovim's error framing stripped as 0.11's is, the `vim.system` error text, the terminal's exit line, the test editor that cannot load aineo | T8 | active |

It rests on:
- **D10** — Neovim ≥ 0.11 is the supported minimum;
- **C1** and **MR64** — every error an action raises reaches the user once as `aineo: <its first line>`, without Neovim's framing;
- **C3**, **C5** and **C7**.

The user runs Neovim 0.12.5 since 2026-09-25, so the host's `nvim` is 0.12.5.

### The failures — `evidence/baseline-0.12.5.txt`, measured on `9af91a6`

On 0.12.5, `make test` ran 727 cases, `Fails (8)`. Read each in the evidence file.

1. **`tests/test_claude.lua` › *names claude.cmd and the command that is not executable, and nothing else*.** The test expects the error to start with `Error executing lua: `. On 0.12.5 it starts with `Lua: `.
2. **`tests/test_claude.lua` › *session_status() › leaves the terminal showing Neovim's exit line*.** `[Process exited 3]` is not in the terminal's text on 0.12.5.
3. **`tests/test_entry.lua` › *when a TermOpen autocommand of the user fails tells the user the first line of its error*.** The user is told `aineo: Lua: nvim_exec2()[1]..TermOpen …`. `plugin/aineo.lua`'s `ERROR_FRAMING` (line 172) strips `^Error executing lua: `, a `.lua:<n>: ` position and `^Vim:`, but not 0.12's `Lua: `. **This one is a defect the user sees.**
4. **`tests/test_health.lua` › *warns when claude.cmd cannot be run, although it is executable*.** The warning reads `could not run: vim/_core/system:326: ENOENT: …`. 0.12 puts the position of its own Lua code inside the error.
5–7. **`tests/test_mcp_blocked_editor.lua`, three cases.** The test editor, started through `tests/helpers/report_tui.lua`, fails `require('aineo.report')`: `module 'aineo.report' not found`, where only the binary's built-in `package.path` was searched.
8. **`tests/test_mcp_delivery.lua` › *that the editor does not take is a tool error with the reason it gave*.** The tool error Claude receives reads `the editor did not take the report: Lua: aineo.report has no environment: …`. The test expects 0.11's `Error executing lua: …`.

### The behaviours — one test each, each seen red first on the version that shows it

- **NC1 — both versions green.** `make test` passes on 0.12.5 and on 0.11.6, the latter from `<scratchpad>/nvim-0.11.6/nvim-macos-arm64/bin/nvim` first on `PATH`. Report the counts of both runs.
- **NC2 — no framing reaches the user.** On both versions, an action's error reaches the user as `aineo: <its first line>` without Neovim's framing (MR64) — 0.12's `Lua: ` included.
- **NC3 — no framing reaches Claude.** On both versions, a report the editor does not take is a tool error whose text carries the editor's reason without Neovim's framing.
- **NC4 — health names the error, not Neovim's code.** On both versions, the health check's "could not run" warning names the error (`ENOENT: …`) without a position inside Neovim's own Lua.
- **NC5 — the exit line.** Measure what the terminal shows on 0.12.5 once Claude Code has exited — the fake's `exit 3` — and what `session_status()` reports.
  - If 0.12 shows its own line, the test states each version's line.
  - If 0.12 shows none, or the buffer is closed, that is a change the user sees in the left pane. Report it as a **spec conflict** with the measurement, rather than choose what aineo shows.
- **NC6 — the test editor loads aineo.** `tests/helpers/report_tui.lua`'s editor loads aineo on both versions. Find why 0.12 does not search the checkout's `lua/` in that editor, and fix the helper, not the test's claims.
- **A test whose expectation differs by version states both** — branch on `vim.fn.has('nvim-0.12')`. It never widens to a pattern that would accept wrong text.

### Facts, checked against `origin/dev` (`9af91a6`)

- `plugin/aineo.lua:172`: `local ERROR_FRAMING = { '^Error executing lua: ', '^.-%.lua:%d+: ', '^Vim:' }`, used by `error_line()`.
- Neovim 0.12.5's source is readable at the tag with `gh api 'repos/neovim/neovim/contents/<path>?ref=v0.12.5' --jq .content | base64 -d`.
- The two binaries in `<scratchpad>` are the official `nvim-macos-arm64.tar.gz` of each tag. Their sha256 matches each release's digest: 0.11.6 `d5ee93b6…c1dd`, 0.12.5 `65fb0000…1f9b`. The host's own `nvim`, Homebrew's, is 0.12.5.

### Baseline

- **0.12.5 at `9af91a6`:** 727 cases, `Fails (8)` — the eight above; `evidence/baseline-0.12.5.txt`.
- **0.11.6 at the same code** (`a9f8027`, Homebrew's build): 727 cases, `Fails (0)` (the wave-5 verification).

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › D10, C1, C3, C5, C7;
- `knowledge-vault/Review/2026-09-24 — v1 MVP readings review.md` › MR64;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `bugfix/t13-neovim-0-12` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t13_neovim_0_12`.
- **You may touch:**
  - `plugin/aineo.lua`, its error framing only;
  - `lua/aineo/mcp/`, where a tool error's text is built;
  - `lua/aineo/health.lua`, the "could not run" warning only;
  - `lua/aineo/claude/`, only if NC5 needs it;
  - `tests/helpers/report_tui.lua`, and another helper under `tests/helpers/` only if NC6 needs it (name it in your report);
  - the five test files above: `tests/test_claude.lua`, `tests/test_entry.lua`, `tests/test_health.lua`, `tests/test_mcp_blocked_editor.lua`, `tests/test_mcp_delivery.lua`;
  - `doc/aineo.txt`, **only inside** `*aineo-install*` — the Neovim versions aineo was measured on;
  - your session note.
  - The documentation this change invalidates, in the same change: that section, and any help line that quotes an error with Neovim's framing.
- **You must not touch:**
  - `lua/aineo/report/`, `tests/test_report_buffer.lua`, `tests/test_entry_report.lua`, `doc/aineo.txt` › `*aineo-report*` and a new `tests/test_report_colours.lua`. T9 owns them in this wave.
  - `plugin/aineo.lua`'s subcommand, action and key tables, `lua/aineo/layout/` and `health.lua`'s key table, which T12 changes after you.
  - `tests/test_plugin.lua`'s frozen pins.
  - `scripts/` and the `Makefile`.
  - The task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note.
  - The project note.
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **The help is shared under rule 2's section exception.** Before you push, re-run the merge check against T9's branch if it exists: `git fetch origin && git merge-tree --write-tree <your head> origin/bugfix/t9-report-colours` (exit 0 and no conflict listed means clean). Report the result.
- **Session note:** `knowledge-vault/Sessions/2026-09-25 — T13 Neovim 0.12.md`.
- **Scratch prefix:** `t13-`, under `<scratchpad>`, the orchestrator's scratch directory, which your dispatch message names.
- **Never run the real `claude`.** Confirm the guard holds on both versions before any autostart case runs.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

The user, 2026-09-25, chose this packet over deferring it: "Yes, first". D10's minimum stays 0.11, so both versions must pass.

## Budget

Medium: four small corrections, one of a test helper, and a measurement (NC5). If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t13-report-packet.md`, with the suite counts on both versions. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
