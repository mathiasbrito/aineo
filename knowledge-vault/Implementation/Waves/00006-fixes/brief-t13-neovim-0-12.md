**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md`, since you are dispatched as that specialist, and `neovim-lua-developer.md`, whose rules it also binds.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T13 | Neovim 0.12 compatibility (D10): the suite green on 0.12.5 and on 0.11.6 — Neovim's error framing stripped as 0.11's is, the `vim.system` error text, the terminal's exit line, the test editor that cannot load aineo | T8 | active |

It rests on:
- **D10** — Neovim ≥ 0.11 is the supported minimum;
- **C1**, the entry point, and **MR64**, an open reading of the MVP review: every error an action raises reaches the user once as `aineo: <its first line>`, without Neovim's framing;
- **C3**, **C5** and **C7**.

The user runs Neovim 0.12.5 since 2026-09-25, so the host's `nvim` is 0.12.5.

### The failures — `evidence/baseline-0.12.5.txt`, measured on `9af91a6`

On 0.12.5, `make test` ran 727 cases, `Fails (8)`. Read each in the evidence file.

1. **`tests/test_claude.lua` › *names claude.cmd and the command that is not executable, and nothing else*.** The test expects the error to start with `Error executing lua: `. On 0.12.5 it starts with `Lua: `.
2. **`tests/test_claude.lua` › *session_status() › leaves the terminal showing Neovim's exit line*.** `[Process exited 3]` is not in the terminal's text on 0.12.5.
   - The brief review measured why: 0.12.5 still shows it, but as an overlay virtual-text extmark. That extmark comes from the default `TermClose` autocommand of group `nvim.terminal`; on 0.11.6 it is buffer text.
   - The user sees the same line, so this is a test that reads the wrong place on 0.12.
3. **`tests/test_entry.lua` › *when a TermOpen autocommand of the user fails tells the user the first line of its error*.** Two differences, measured by the brief review:
   - on 0.11.6 the user is told `aineo: nvim_exec2()[1]..TermOpen Autocommands for "*": Vim(append):Error executing lua callback: [string "<nvim>"]:3: the user autocommand fails`;
   - on 0.12.5 the user is told `aineo: Lua: nvim_exec2()[1]..TermOpen Autocommands for "*": Vim(append):Lua callback: [string "<nvim>"]:3: the user autocommand fails`.

   `plugin/aineo.lua`'s `ERROR_FRAMING` (line 172) strips `^Error executing lua: `, a `.lua:<n>: ` position and `^Vim:`, but not 0.12's leading `Lua: `. **That prefix is a defect the user sees.** The inner `Error executing lua callback:` / `Lua callback:` differs by version too. Framing is stripped only at the line's start, so the test states each version's full message.
4. **`tests/test_health.lua` › *warns when claude.cmd cannot be run, although it is executable*.** The warning reads `could not run: vim/_core/system:326: ENOENT: …`. Both versions prefix the position of Neovim's own Lua (measured by the brief review with `pcall(vim.system, {'/nonexistent/aineo-probe'})`). 0.11's ends in `.lua:<n>: ` (`…/lua/vim/_system.lua:254: ENOENT: …`), which `health.lua`'s `error_line()` strips. 0.12's is a chunk name without `.lua` (`vim/_core/system:324: `), which it does not. Say in your report whether `plugin/aineo.lua`'s `'^.-%.lua:%d+: '` meets the same shape; the brief review knows of no action that raises from 0.12's runtime Lua.
5–7. **`tests/test_mcp_blocked_editor.lua`, three cases.** The test editor, started through `tests/helpers/report_tui.lua`, fails `require('aineo.report')`: `module 'aineo.report' not found`. The brief review measured why:
   - on 0.12.5 the first RPC request is answered **during startup**, with `vim_did_enter = 0` and the checkout not yet on `'runtimepath'`;
   - it is served inside 0.12's startup wait for the terminal's answer to the background-colour query, `vim.wait(100, … did_dsr_response …)` in `vim/_core/defaults.lua:977`, which the helper's pty never answers. That wait comes before `-u scripts/minimal_init.lua` runs;
   - 1.5 s later the same editor loads `aineo.report`, and its `:messages` hold `E1568: Terminal did not respond to DSR request for 'background' color. Startup may be slower. :help 'ttyfast'`. `defaults.lua` suppresses E1568 only when `NVIM_TEST` is set;
   - on 0.11.6 the first request is answered after `VimEnter`, and `:messages` is empty.

   E1568 is a second 0.12 effect in that editor, and this test file is about messages and hit-enter prompts.
8. **`tests/test_mcp_delivery.lua` › *that the editor does not take is a tool error with the reason it gave*.** The tool error Claude receives reads `the editor did not take the report: Lua: aineo.report has no environment: …`. The test expects 0.11's `Error executing lua: …`.

### The behaviours — one test each, each seen red first on the version that shows it

- **NC1 — both versions green.** `make test` passes on the host's 0.12.5 and on 0.11.6. For 0.11.6, put the downloaded build first on `PATH` in this literal form; the worktree guard refuses `PATH=…:$PATH make`:

  ```
  env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test
  ```

  Report the counts of both runs.
- **NC2 — no framing reaches the user.** On both versions, an action's error reaches the user as `aineo: <its first line>` without Neovim's framing (MR64) — 0.12's `Lua: ` included.
- **NC3 — no framing reaches Claude.** On both versions, a report the editor does not take is a tool error whose text carries the editor's reason without Neovim's framing.
  - This changes v0.1.0's text on 0.11 too. Today `tests/test_mcp_delivery.lua:322` pins `the editor did not take the report: Error executing lua: …`, built by `lua/aineo/mcp/editor.lua:148` (`first_line(tostring(failure[2]))`).
  - It is the orchestrator's reading, for the user to confirm. Name it in your session note's *Readings for the MVP review*.
- **NC4 — health names the error, not Neovim's code.** On both versions, the health check's "could not run" warning names the error (`ENOENT: …`) without a position inside Neovim's own Lua.
- **NC5 — the exit line.** On both versions the user sees `[Process exited 3]` once Claude Code has exited (the fake's `exit 3`). The test reads it where each version puts it: buffer text on 0.11, the `nvim.terminal` group's virtual-text extmark on 0.12 (failure 2).
  - `lua/aineo/claude/` needs no change.
  - If the test reads the screen through `tests/helpers/claude_session.lua`, write the 0.12 check inline in `tests/test_claude.lua`, or change that helper, which is inside your boundary for this.
  - Confirm the measurement before you rely on it.
- **NC6 — the test editor loads aineo.** `tests/helpers/report_tui.lua`'s editor serves its first request only after startup on both versions, and so loads aineo. Its `:messages` hold no E1568, or the test states why they may. Fix the helper, not the test's claims (failures 5–7).
- **A test whose expectation differs by version states both** — branch on `vim.fn.has('nvim-0.12')`. It never widens to a pattern that would accept wrong text.

### Facts, checked against `origin/dev` (`9af91a6`)

- `plugin/aineo.lua:172`: `local ERROR_FRAMING = { '^Error executing lua: ', '^.-%.lua:%d+: ', '^Vim:' }`, used by `error_line()`.
- Neovim 0.12.5's source is readable at the tag with `gh api 'repos/neovim/neovim/contents/<path>?ref=v0.12.5' --jq .content | base64 -d`.
- The two binaries in `<builds>` are the official `nvim-macos-arm64.tar.gz` of each tag. Their sha256 matches each release's digest: 0.11.6 `d5ee93b6…c1dd`, 0.12.5 `65fb0000…1f9b`. The host's own `nvim`, Homebrew's, is 0.12.5.
- `lua/aineo/health.lua`'s `error_line()` (line 15) builds the "could not run" text. The configuration error uses it too (line 30).
- No help line quotes Neovim's framing today: `grep -n -E 'Error executing|Lua: |Vim:|Vim\(' doc/aineo.txt` prints nothing.

### Baseline

- **0.12.5 at `9af91a6`,** the downloaded build: 727 cases, `Fails (8)`, the eight above (`evidence/baseline-0.12.5.txt`). The brief review reproduced them on the host's Homebrew 0.12.5.
- **0.11.6 at `9af91a6`,** the downloaded build: 727 cases, `Fails (0)` (`evidence/baseline-0.11.6.txt`).

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
  - `lua/aineo/health.lua`, the "could not run" warning and `error_line()` — which the configuration error shares, so it keeps its pins green;
  - `lua/aineo/claude/`, only if NC5 needs it;
  - `tests/helpers/report_tui.lua`, and `tests/helpers/claude_session.lua` only if NC5 needs it, and another helper under `tests/helpers/` only if NC6 needs it (name each in your report);
  - the five test files above: `tests/test_claude.lua`, `tests/test_entry.lua`, `tests/test_health.lua`, `tests/test_mcp_blocked_editor.lua`, `tests/test_mcp_delivery.lua`;
  - `doc/aineo.txt`, **only inside** `*aineo-install*` — the Neovim versions aineo was measured on;
  - your session note.
  - The documentation this change invalidates, in the same change: that section. No help line quotes Neovim's framing today (see *Facts*).
- **You must not touch:**
  - `lua/aineo/report/`, `tests/test_report_buffer.lua`, `tests/test_entry_report.lua`, `doc/aineo.txt` › `*aineo-report*` and a new `tests/test_report_colours.lua`. T9 owns them in this wave.
  - `plugin/aineo.lua`'s subcommand, action and key tables, `lua/aineo/layout/` and `health.lua`'s key table, which T12 changes after you.
  - `tests/test_plugin.lua`'s frozen pins.
  - `scripts/` and the `Makefile`.
  - The task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note.
  - The project note.
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your section** runs from its first line, `2. REQUIREMENTS AND INSTALLATION                               *aineo-install*` (line 36 at `9af91a6`), to its last, ``|aineo-configuration|; then run `:checkhealth aineo` (|aineo-health|).`` (line 48).
  - **The other packet:** T9 edits from `8. THE AGENT REPORT                                             *aineo-report*` to `the working directory of its own moment.` (lines 253–280).
  - Every hunk stays inside your section.
  - **Before you push:** merge with T9's branch if it exists — `git fetch origin && git merge-tree --write-tree <your head> origin/bugfix/t9-report-colours` (exit 0 and no conflict listed means clean). Then run `make test_file FILE=tests/test_doc.lua` on the merged `doc/aineo.txt`. Report both results.
- **Session note:** `knowledge-vault/Sessions/2026-09-25 — T13 Neovim 0.12.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). The harness refuses writes outside your worktree. Prefix every file there with `t13-`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. You read and run its Neovim builds there, and write nothing.
- **Never run the real `claude`.** Confirm the guard holds on both versions before any autostart case runs.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

The user, 2026-09-25, chose this packet over deferring it: "Yes, first". D10's minimum stays 0.11, so both versions must pass.

## Budget

Medium: four small corrections, one of a test helper, and a measurement (NC5). If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t13-report-packet.md`, with the suite counts on both versions. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
