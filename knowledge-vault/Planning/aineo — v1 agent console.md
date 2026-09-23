# aineo — v1 agent console

## Context
**Project:** [[Projects/aineo]]
**Defined in session:** [[Sessions/2026-09-23 — Orchestration and knowledge vault scaffold]]
**Defined by:** Mathias Santos de Brito, with Claude — converged in two rounds, 2026-09-23
**Status:** in progress — wave 1 (T1) being planned, 2026-09-23

## Goal

The first and, for now, only spec: when Neovim starts, Claude Code runs in a terminal on the left half of the screen, and the right half is split into an **Agent Report** window (agent → user, top) and an **Input** window (user → agent, bottom). Every plugin command sits behind one prefix key. A command sends what the user typed in Input to the agent; the agent reports its work into Agent Report in a specified format. More features follow later, one spec at a time.

## ID legend
- `D#` — decision
- `C#` — component
- `A#` — alternative rejected
- `F#` — fact established before the design (read or measured, 2026-09-23)
- `R#` — risk · `Q#` — unknown
- `T#` — task

## Facts the design rests on

- **F1** — `:h index` lists `\` as *not used* in Normal mode; it is also the default `mapleader`. `:h map-which-keys` suggests `_` or `,` plus a key; `<Space>` is a synonym for `l`.
- **F2** — `termopen()` is deprecated in Nvim 0.11; a terminal is `jobstart(cmd, { term = true })`.
- **F3** — `'winfixbuf'` pairs a window with its buffer; `:edit` there fails (E1513) rather than redirecting.
- **F4** — `v:servername` is set at startup, so a child process can call back into the editor.
- **F5** — `claude --help` (2.1.280) lists `--append-system-prompt`, `--mcp-config` and `--allowedTools` without a print-only restriction.
- **F6** — *measured*: the first `claude` launch in this folder shows the workspace-trust dialog, defaulting to "No, exit".

## Decisions & reasoning

| ID | Decision | Reasoning |
|----|----------|-----------|
| D1 | "Command mode" is Normal mode; the prefix is `\` | F1: the one Normal-mode key Vim's index lists as unused. The user's choice over `,` and `<Space>` |
| D2 | "The agent" is the interactive Claude Code in the left terminal | The spec asks for Claude Code in a terminal; headless (A2) was rejected |
| D3 | Autostart only on a bare interactive `nvim` | `nvim file`, `git commit`, `--headless` and stdin must not be taken over |
| D4 | Layout A: Claude terminal 50% left; Report ~2/3 over Input ~1/3 on the right | The user's choice; the startup empty buffer becomes Input |
| D5 | Files open in a middle column between the terminal and the Report/Input column, created on first use and reused (C9) — superseding "files in a new tab" | The user's note on layout A, confirmed in round 2 |
| D6 | With a file column open, the three columns take equal thirds | The user's choice over "Claude stays at 50%" and "files get the most" |
| D7 | A file opened from an aineo window is redirected to the file column, the aineo window keeps its buffer | The user's choice over refusing with `winfixbuf` (F3) |
| D8 | The agent writes reports through an MCP tool, not a file | The tool's input schema *is* the report format; no file permissions, no re-reading a growing file. The user's choice over A1 |
| D9 | Model policy: Opus for the orchestrator and every agent | The user, 2026-09-23 (see [[Skills/Orchestrate]]) |
| D10 | Nvim ≥ 0.11; tests on mini.test with a fake `claude`; the real Claude never runs in the suite | 0.11 carries `jobstart` terminals and `vim.validate`'s current form; mini.test runs a child Neovim per test and needs no luarocks |
| D11 | Claude's permission prompts are answered by the user in the terminal | The interactive TUI is its own permission host; aineo pre-allows only its own report tool (C3) |

## Architecture

| ID | Component | Where | Specialist |
|----|-----------|-------|------------|
| C1 | Entry point: `:Aineo …`, `<Plug>(aineo-…)` mappings, the `\` prefix mapped only where the user has not mapped it (configurable or off through `vim.g.aineo`), and the `VimEnter` autostart under D3 — never inside aineo's own Claude terminal (`$AINEO_CHILD`) | `plugin/aineo.lua`, `lua/aineo/config/` | `neovim-lua-developer` |
| C2 | Layout: the three windows, widths per D4/D6, Report read-only to the user, all three pinned against resizing; `\o` restores it | `lua/aineo/layout/` | `neovim-lua-developer` |
| C3 | Claude session: `claude` in the left terminal with the report instructions appended to its system prompt, the aineo MCP server through `--mcp-config`, `--allowedTools mcp__aineo__report`, `AINEO_CHILD=1` and the editor's `v:servername` in its environment; readiness tracking; restart; a clean stop on quit | `lua/aineo/claude/` | `neovim-claude-code-integrator` |
| C4 | Send (`\s`): the Input buffer as one bracketed paste plus Enter into the terminal, then Input cleared; refused while Claude is not ready (trust dialog, startup) or Input is empty | `lua/aineo/send/` | `neovim-claude-code-integrator` |
| C5 | Report channel: a stdio MCP server run by Claude Code as `nvim --headless --clean -l …`, one tool `report`, each call relayed to the editor over its server socket | `lua/aineo/mcp/` | `neovim-claude-code-integrator` |
| C6 | Report format and rendering: tool input `{ task, status: started\|progress\|blocked\|done\|failed, summary, details? }`, rendered `HH:MM [status] task — summary` with details indented; persisted under `stdpath('state')`; the appended prompt tells Claude when to report | `lua/aineo/report/` | `neovim-lua-developer` |
| C7 | Health: `claude` and its version, the server socket, prefix-mapping conflicts, why autostart did or did not run | `lua/aineo/health.lua` | `neovim-lua-developer` |
| C8 | Tooling: the mini.test harness, the fake `claude`, `prepare_project`, vimdoc | `tests/`, `scripts/`, `doc/aineo.txt`, `.claude/scripts/prepare-worktree.sh` | `neovim-lua-developer` |
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

- **Q1** — Whether a bracketed paste plus Enter lands in Claude's prompt is unmeasured: the trust dialog (F6) stopped the spike. Measured in a folder the user trusts once, **before C4 lands**.
- **Q2** — Whether `--mcp-config` and `--allowedTools mcp__…` take effect in interactive mode — measured in the same step.
- ~~**Q3** — The formatter and linter~~ — **resolved 2026-09-23 by the user: StyLua + selene**; installed on this Mac as StyLua 2.5.2 and selene 0.31.0. lua-language-server type-checking is not in v1.
- **R1** — Claude exits (Ctrl-C, `/exit`): the terminal shows the exit; `\o` restarts the session.
- **R2** — Quitting Neovim with Claude running: aineo stops it on quit, interrupting first (SIGINT) so the turn ends rather than being cut (see `neovim-claude-code-integrator`).

## Implementation plan

| ID | Task | Depends on | Status |
|----|------|------------|--------|
| T1 | Tooling foundation (C8), as a packet: the mini.test harness and its make targets (deps, test, lint, format), the suites' isolation from the developer's editor and Claude state, the fake `claude`, the `plugin/aineo.lua` and `lua/aineo/init.lua` skeletons, and `lua/aineo/config/` with `vim.g.aineo` validation. The agent-configuration part — `.gitignore`, the `modularity` table, the Nvim minimum in the root `CLAUDE.md` (before the packet), and the commands in `CLAUDE.md` and any `prepare_project` step (after it) — is the orchestrator's `ai/` pass, because no implementer edits those files | — | active |
| T2 | Measure Q1 and Q2 against the real CLI in a folder the user trusts; record the transcripts as fixtures and the result as a Learning | — (needs the user for the trust dialog) | active |
| T3 | Layout (C2) and the file column with its redirect (C9) | T1 | active |
| T4 | Claude session (C3): start, flags, environment, readiness, restart, stop on quit | T1 | active |
| T5 | MCP server and relay (C5), report rendering and persistence (C6) | T1 | active |
| T6 | Send (C4) | T2, T3, T4 | active |
| T7 | Entry point (C1): prefix mapping, `<Plug>` mappings, `:Aineo`, autostart | T3, T4, T5, T6 | active |
| T8 | Health (C7) and `doc/aineo.txt` | T7 | active |

## Done
<!-- ~~**T1 — <title>**~~ — **Done YYYY-MM-DD** (commit in session note) -->

**Done means:** a bare `nvim` in a trusted folder shows the layout; `\s` delivers Input to Claude and clears it; Claude's `report` calls render in Agent Report in the C6 format; opening a file from any window lands in the middle column at equal thirds; `:checkhealth aineo` passes; the suite is green under mini.test with the fake `claude`; vimdoc documents every command.

## Out of scope (v1)

Chat history, several sessions, diffs and selection sharing, headless mode, a user-defined report language beyond C6, Windows.

## Related
- [[Skills/Orchestrate]] · [[Projects/aineo]]
