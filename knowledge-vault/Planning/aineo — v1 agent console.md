# aineo — v1 agent console

## Context
**Project:** [[Projects/aineo]]
**Defined in session:** [[Sessions/2026-09-23 — Orchestration and knowledge vault scaffold]]
**Defined by:** Mathias Santos de Brito, with Claude — converged in two rounds, 2026-09-23
**Status:** in progress — wave 1 (T1) landed 2026-09-24; wave 2 (T3, T4, T5) landed 2026-09-24; wave 3 (T6) planned 2026-09-24

## Goal

The first and, for now, only spec: when Neovim starts, Claude Code runs in a terminal on the left half of the screen, and the right half is split into an **Agent Report** window (agent → user, top) and an **Input** window (user → agent, bottom). Every plugin command sits behind one prefix key. A command sends what the user typed in Input to the agent; the agent reports its work into Agent Report in a specified format. More features follow later, one spec at a time.

## ID legend
- `D#` — decision
- `C#` — component
- `A#` — alternative rejected
- `F#` — fact established before the design (read or measured, 2026-09-23)
- `R#` — risk · `Q#` — unknown
- `T#` — task

## Authority

Until the project has specs, this plan's **D# and C# rows are the spec for v1** (the root `CLAUDE.md` says so). They change only through a converge round with the user: a changed row is struck and superseded by a new ID, never edited in place, and the note says who agreed. The orchestrator records such an agreement; it never changes a row on its own.

## Facts the design rests on

- **F1** — `:h index` lists `\` as *not used* in Normal mode — the only printable key it lists so; the others are control keys (CTRL-@, CTRL-K, CTRL-_ and more); it is also the default `mapleader`. `:h map-which-keys` suggests `_` or `,` plus a key; `<Space>` is a synonym for `l`.
- **F2** — `termopen()` is deprecated in Nvim 0.11; a terminal is `jobstart(cmd, { term = true })`.
- **F3** — `'winfixbuf'` pairs a window with its buffer; `:edit` there fails (E1513) rather than redirecting.
- **F4** — `v:servername` is set at startup, so a child process can call back into the editor.
- **F5** — `claude --help` (2.1.280) lists `--append-system-prompt`, `--mcp-config` and `--allowedTools` without a print-only restriction.
- **F6** — *measured by the orchestrator*, 2026-09-23: `claude` started in a headless Nvim terminal in this folder showed the workspace-trust dialog with "❯ No, exit" selected; `~/.claude.json` holds `hasTrustDialogAccepted = false` for this folder (read by the orchestrator, and again by the records review of #2).

## Decisions & reasoning

| ID | Decision | Reasoning |
|----|----------|-----------|
| D1 | "Command mode" is Normal mode; the prefix is `\` | F1: the only printable Normal-mode key Vim's index lists as unused. The user's choice over `,` and `<Space>` |
| D2 | "The agent" is the interactive Claude Code in the left terminal | The spec asks for Claude Code in a terminal; headless (A2) was rejected — the orchestrator's inference i2, agreed by the user in round 1 (\"Agree as written\") |
| D3 | Autostart only on a bare interactive `nvim` | `nvim file`, `git commit`, `--headless` and stdin must not be taken over — inference i3, agreed by the user in round 1 |
| D4 | Layout A: Claude terminal 50% left; Report ~2/3 over Input ~1/3 on the right | The user's choice; the startup empty buffer becomes Input |
| D5 | Files open in a middle column between the terminal and the Report/Input column, created on first use and reused (C9) — superseding "files in a new tab" | The user's note on layout A, confirmed in round 2 |
| D6 | With a file column open, the three columns take equal thirds | The user's choice over "Claude stays at 50%" and "files get the most" |
| D7 | A file opened from an aineo window is redirected to the file column, the aineo window keeps its buffer | The user's choice over refusing with `winfixbuf` (F3) |
| D8 | The agent writes reports through an MCP tool, not a file | The tool's input schema *is* the report format; no file permissions, no re-reading a growing file. The user's choice over A1 |
| D9 | Model policy: Opus for the orchestrator and every agent | The user, 2026-09-23 (see [[Skills/Orchestrate]]) |
| D10 | Nvim ≥ 0.11; tests on mini.test with a fake `claude`; the real Claude never runs in the suite | 0.11 carries `jobstart` terminals and `vim.validate`'s current form; mini.test's `MiniTest.new_child_neovim()` gives each test a child Neovim it starts or restarts itself, and needs no luarocks — proposed as C8 and agreed by the user in round 1 |
| D11 | Claude's permission prompts are answered by the user in the terminal | The interactive TUI is its own permission host. aineo pre-allows its own report tool (`--allowedTools mcp__aineo__report`, C3) and nothing else — proposed in round 1 with that reason (\"so reporting never prompts\") and agreed by the user with C1–C8. It raises no permission mode and answers no prompt |
| D12 | StyLua formats and selene lints; lua-language-server type-checking is not in v1 | The user's choice (Q3), over StyLua alone and over deferring both; installed as StyLua 2.5.2 and selene 0.31.0 |
| D13 | The v1 settings, read from `vim.g.aineo` and `require('aineo').setup()`: `prefix` — a string, or `false` to map nothing (default `\`); `autostart` — a boolean (default `true`); `claude.cmd` — the command run in the left terminal, a list of strings (default `{ "claude" }`); `layout.report_height` — the Report's share of the right column, strictly between 0 and 1 (default 2/3, D4) | Added by the user on 2026-09-23, after the brief review of wave 1 found three of these keys backed by no row; `prefix` comes from C1 ("configurable or off") |
| D14 | Send works while Claude is in a turn: the paste and the Enter go to the terminal, and Claude Code queues the message and runs it after the turn | Measured 2026-09-24 on 2.1.281: during a turn the input box stays on screen, so the session reads ready, and a message submitted then is queued (`Implementation/Waves/00003-send/evidence/t6-summary.txt`). The user's choice, 2026-09-24, over refusing Send while a turn runs — with the risk stated in the option and accepted: a permission dialog drawn in the ~11–30 ms before the session notices it takes Send's Enter, which picks its highlighted choice, against D11; recorded as a limit. C4 is otherwise unchanged |
| D15 | On a bare start (D3), aineo takes the screen from a startup dashboard: it opens its layout even when a dashboard (snacks.nvim's, alpha, dashboard-nvim, mini.starter) drew first, replacing the dashboard's window; with `autostart = false` the dashboard shows as before | Resolves Q5. The user's choice, 2026-09-24, over yielding to the dashboard (aineo then never opening by itself while one is enabled); the cost stated with it: T7 handles the startup order against dashboards that open on `VimEnter` or later, tested for the known ones, and an unknown one may show first |

## Architecture

| ID | Component | Where | Specialist |
|----|-----------|-------|------------|
| C1 | Entry point: `:Aineo …`, `<Plug>(aineo-…)` mappings, the `\` prefix mapped only where the user has not mapped it (configurable or off through `vim.g.aineo`), and the `VimEnter` autostart under D3 — never inside aineo's own Claude terminal (`$AINEO_CHILD`) | `plugin/aineo.lua`, `lua/aineo/init.lua` (the public API, `setup()`), `lua/aineo/config/` | `neovim-lua-developer` |
| C2 | Layout: the three windows, widths per D4/D6, Report read-only to the user, all three pinned against resizing; `\o` restores it | `lua/aineo/layout/` | `neovim-lua-developer` |
| C3 | Claude session: `claude` in the left terminal with the report instructions appended to its system prompt, the aineo MCP server through `--mcp-config`, `--allowedTools mcp__aineo__report`, `AINEO_CHILD=1` and the editor's `v:servername` in its environment; readiness tracking; restart; a clean stop on quit; the fake `claude` the suites run in the CLI's place | `lua/aineo/claude/`, the fake under `tests/helpers/` | `neovim-claude-code-integrator` |
| C4 | Send (`\s`): the Input buffer as one bracketed paste plus Enter into the terminal, then Input cleared; refused while Claude is not ready (trust dialog, startup) or Input is empty | `lua/aineo/send/` | `neovim-claude-code-integrator` |
| C5 | Report channel: a stdio MCP server run by Claude Code as `nvim --headless --clean -l …`, one tool `report`, each call relayed to the editor over its server socket | `lua/aineo/mcp/` | `neovim-claude-code-integrator` |
| C6 | Report format and rendering: tool input `{ task, status: started\|progress\|blocked\|done\|failed, summary, details? }`, rendered `HH:MM [status] task — summary` with details indented; persisted under `stdpath('state')`; the appended prompt tells Claude when to report | `lua/aineo/report/` | `neovim-lua-developer` |
| C7 | Health: `claude` and its version, the server socket, prefix-mapping conflicts, why autostart did or did not run | `lua/aineo/health.lua` | `neovim-lua-developer` |
| C8 | Tooling: the mini.test harness and its make targets, the suites' isolation from the developer's editor and Claude state, formatting and linting (D12) | `Makefile`, `scripts/`, `tests/`, `.stylua.toml`, the selene configuration — `prepare_project` in `.claude/scripts/prepare-worktree.sh` is the orchestrator's `ai/` pass | `neovim-lua-developer` |
| C9 | File column: a normal file buffer shown in any aineo window is moved to a middle column (created between the terminal and the right column on first use, reused after) and the aineo window gets its buffer back — a `BufWinEnter` redirect, not `'winfixbuf'`; `:q` in it returns to three windows | `lua/aineo/layout/` | `neovim-lua-developer` |

**v1 commands:** `\s` send · `\o` open/restore · `\r` Report · `\i` Input · `\c` Claude · and `:Aineo send|open|report|input|claude`.

## Alternatives rejected

- **A1** — The report as a file the agent edits and aineo watches: the format would only be a request, each report re-reads a growing file, and the path needs a permission rule.
- **A2** — Headless `claude -p` over stream-json with aineo's own chat UI: the spec asks for Claude Code in a terminal.
- **A3** — The IDE WebSocket protocol for the report: undocumented and heavy for one tool.
- **A4** — A `Stop` hook posting Claude's last message: no control of the format.
- **A5** — `'winfixbuf'` on the aineo windows: it refuses a file (E1513) where D7 redirects it.

## Accepted trade-offs

- A bare `nvim` always starts a Claude process (and, in a new folder, its trust dialog).
- `\` collides with the `<Leader>` mappings of users who keep the default leader; aineo never overwrites a mapping and lists conflicts in `:checkhealth aineo`.
- One small relay process runs per Claude session for the report tool.
- With the file column open, Claude's terminal is a third of the screen and wraps its output to that width.

## Risks and unknowns

- ~~**Q1**~~ — **resolved 2026-09-23 by the orchestrator's T2 measurement** on Claude Code 2.1.281: a bracketed paste lands in the input box unsubmitted, and Enter submits it as one message (`Implementation/Waves/00002-layout-session-report/evidence/t2-summary.txt`). Was: Whether a bracketed paste plus Enter lands in Claude's prompt is unmeasured: the trust dialog (F6) stopped the spike. Measured in a folder the user trusts once, **before C4 lands**.
- ~~**Q2**~~ — **resolved 2026-09-23 by the same measurement**, with a control run: `--mcp-config`, `--allowedTools` and `--append-system-prompt` take effect interactively; the unlisted tool asked for permission, the allowed one did not (measured under `--permission-mode manual`). Was: Whether `--mcp-config` and `--allowedTools mcp__…` take effect in interactive mode — measured in the same step.
- ~~**Q3** — The formatter and linter~~ — **resolved 2026-09-23 by the user: StyLua + selene**; installed on this Mac as StyLua 2.5.2 and selene 0.31.0. lua-language-server type-checking is not in v1.
- **R1** — Claude exits (Ctrl-C, `/exit`): the terminal shows the exit; `\o` restarts the session.
- **R2** — Quitting Neovim with Claude running: aineo stops it on quit, interrupting first (SIGINT) so the turn ends rather than being cut (the integrator's rule was measured for headless `-p`; the interactive behaviour is Q4). *Carried out, since Q4's resolution of 2026-09-24, as the Ctrl-C key written to the terminal — one press, then a double press — with `jobstop` as the fallback (T4's brief).*
- **R3** — The user's own Neovim config sets `maplocalleader` to `\` (read 2026-09-23): a filetype plugin's `<LocalLeader>` mapping would shadow aineo's `\` commands in that buffer. Nothing in the config or its installed plugins uses `<LocalLeader>` today; C7 reports conflicts.
- ~~**Q5**~~ — **resolved 2026-09-24 by the user: D15** (aineo takes the screen from a startup dashboard). Was: A startup dashboard (snacks.nvim's, alpha, dashboard-nvim, mini.starter) claims the same bare-`nvim` start as the autostart (D3). The user, 2026-09-23: "I have a plugin that starts a screen in full screen, it should not, the aineo should open" — after which the orchestrator turned off snacks.nvim's dashboard in the user's config at their request. *[Corrected 2026-09-24: this row first said the user had turned it off.]* Whether aineo takes the screen from a dashboard or documents that it must be off changes C1 — converged with the user before T7 is dispatched.
- ~~**Q4**~~ — **resolved 2026-09-24 by the orchestrator's measurement** on 2.1.281: one Ctrl-C during a turn ends the turn and keeps the process; a double Ctrl-C 0.3 s apart exits 0 at idle but not during a turn; `/exit` exits 0; `jobstop` exits 129 (`…/evidence/t4-summary.txt`). Measured for Ctrl-C typed into the terminal — the byte `\3` written to its pty; whether the TUI reads it as a byte (raw mode) or the pty turns it into SIGINT was not measured, nor a SIGINT signal sent to the process; T4 stops Claude by keys. Was: How the interactive TUI answers SIGINT and the end of its input — whether a turn ends or is cut. Measured with Q1 and Q2 in T2.

## Implementation plan

| ID | Task | Depends on | Status |
|----|------|------------|--------|
| T1 | Tooling foundation (C8) and the entry-point skeleton (C1), as a packet: the mini.test harness and its make targets (deps, test, lint, format), the suites' isolation from the developer's editor and Claude state, the `plugin/aineo.lua` and `lua/aineo/init.lua` skeletons, and `lua/aineo/config/` with `vim.g.aineo` validation. The agent-configuration part — `.gitignore`, the `modularity` table, the Nvim minimum in the root `CLAUDE.md` (before the packet), and the commands in `CLAUDE.md` and any `prepare_project` step (after it) — is the orchestrator's `ai/` pass, because no implementer edits those files | — | done — PR #4, wave 1 |
| T2 | Measure Q1, Q2 and Q4 against the real CLI in a folder the user trusts; record the transcripts as fixtures and the result as a Learning | — (needs the user for the trust dialog) | done — measured by the orchestrator; evidence and fixtures in `Implementation/Waves/00002-layout-session-report/evidence/`, the Learning [[Learnings/Claude Code's interactive CLI in a Neovim terminal]] |
| T3 | Layout (C2) and the file column with its redirect (C9) | T1 | done — PR #9, wave 2 |
| T4 | Claude session (C3): start, flags, environment, readiness, restart, stop on quit, and the fake `claude` its suites run | T1, T2 — T5 only through T7's wiring, by injection (wave 2 plan, *Why T4 runs beside T5*) | done — PR #11, wave 2 |
| T5 | MCP server and relay (C5), report rendering and persistence (C6) | T1, T2 | done — PR #10, wave 2 |
| T6 | Send (C4) | T2, T3, T4 | active |
| T7 | Entry point (C1): prefix mapping, `<Plug>` mappings, `:Aineo`, autostart | T3, T4, T5, T6 | active |
| T8 | Health (C7) and `doc/aineo.txt` | T7 | active |

## Done
<!-- ~~**T1 — <title>**~~ — **Done YYYY-MM-DD** (commit in session note) -->
~~**T1 — Tooling foundation and the entry-point skeleton**~~ — **Done 2026-09-24** (commits in [[Sessions/2026-09-23 — T1 tooling foundation]])
~~**T2 — Measure Q1, Q2 and Q4**~~ — **Done 2026-09-24** (wave 2 plan, *Measured before planning*)
~~**T3 — Layout and the file column**~~ — **Done 2026-09-24** (commits in [[Sessions/2026-09-24 — T3 layout]])
~~**T4 — Claude session**~~ — **Done 2026-09-24** (commits in [[Sessions/2026-09-24 — T4 Claude session]])
~~**T5 — MCP server and relay, report rendering and persistence**~~ — **Done 2026-09-24** (commits in [[Sessions/2026-09-24 — T5 report channel]])

**Done means:** a bare `nvim` in a trusted folder shows the layout; `\s` delivers Input to Claude and clears it; Claude's `report` calls render in Agent Report in the C6 format; opening a file from any window lands in the middle column at equal thirds; `:checkhealth aineo` passes; the suite is green under mini.test with the fake `claude`; vimdoc documents every command.

## Out of scope (v1)

Chat history, several sessions, diffs and selection sharing, headless mode, a user-defined report language beyond C6, Windows.

## Related
- [[Skills/Orchestrate]] · [[Projects/aineo]]
