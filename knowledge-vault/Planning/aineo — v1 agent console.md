# aineo — v1 agent console

## Context
**Project:** [[Projects/aineo]]
**Defined in session:** [[Sessions/2026-09-23 — Orchestration and knowledge vault scaffold]]; the rows added in wave 6 (D16–D20, C10–C13, 2026-09-25) in [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Defined by:** Mathias Santos de Brito, with Claude — converged in two rounds, 2026-09-23
**Status:** in progress — wave 1 (T1) landed 2026-09-24; wave 2 (T3, T4, T5) landed 2026-09-24; wave 3 (T6) landed 2026-09-25; wave 4 (T7) landed 2026-09-25; wave 5 (T8) planned 2026-09-25

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
| D1 | "Command mode" is Normal mode; the prefix is `\` | F1: the only printable Normal-mode key Vim's index lists as unused. The user's choice over `,` and `<Space>` *(a Visual-mode `\s` in Input added by D20, 2026-09-25)* |
| D2 | "The agent" is the interactive Claude Code in the left terminal | The spec asks for Claude Code in a terminal; headless (A2) was rejected — the orchestrator's inference i2, agreed by the user in round 1 (\"Agree as written\") |
| D3 | Autostart only on a bare interactive `nvim` | `nvim file`, `git commit`, `--headless` and stdin must not be taken over — inference i3, agreed by the user in round 1 |
| D4 | Layout A: Claude terminal 50% left; Report ~2/3 over Input ~1/3 on the right | The user's choice; the startup empty buffer becomes Input *(the right column may show the changes pane instead, D18, 2026-09-25)* |
| D5 | Files open in a middle column between the terminal and the Report/Input column, created on first use and reused (C9) — superseding "files in a new tab" | The user's note on layout A, confirmed in round 2 |
| D6 | With a file column open, the three columns take equal thirds | The user's choice over "Claude stays at 50%" and "files get the most" |
| D7 | A file opened from an aineo window is redirected to the file column, the aineo window keeps its buffer | The user's choice over refusing with `winfixbuf` (F3) |
| D8 | The agent writes reports through an MCP tool, not a file | The tool's input schema *is* the report format; no file permissions, no re-reading a growing file. The user's choice over A1 |
| D9 | Model policy: Opus for the orchestrator and every agent | The user, 2026-09-23 (see [[Skills/Orchestrate]]) |
| D10 | Nvim ≥ 0.11; tests on mini.test with a fake `claude`; the real Claude never runs in the suite | 0.11 carries `jobstart` terminals and `vim.validate`'s current form; mini.test's `MiniTest.new_child_neovim()` gives each test a child Neovim it starts or restarts itself, and needs no luarocks — proposed as C8 and agreed by the user in round 1 |
| D11 | Claude's permission prompts are answered by the user in the terminal | The interactive TUI is its own permission host. aineo pre-allows its own report tool (`--allowedTools mcp__aineo__report`, C3) and nothing else — proposed in round 1 with that reason (\"so reporting never prompts\") and agreed by the user with C1–C8. It raises no permission mode and answers no prompt |
| D12 | StyLua formats and selene lints; lua-language-server type-checking is not in v1 | The user's choice (Q3), over StyLua alone and over deferring both; installed as StyLua 2.5.2 and selene 0.31.0 |
| D13 | The v1 settings, read from `vim.g.aineo` and `require('aineo').setup()`: `prefix` — a string, or `false` to map nothing (default `\`); `autostart` — a boolean (default `true`); `claude.cmd` — the command run in the left terminal, a list of strings (default `{ "claude" }`); `layout.report_height` — the Report's share of the right column, strictly between 0 and 1 (default 2/3, D4) | Added by the user on 2026-09-23, after the brief review of wave 1 found three of these keys backed by no row; `prefix` comes from C1 ("configurable or off") |
| D14 | Send works while Claude is in a turn: the paste and the Enter go to the terminal, and Claude Code queues the message and runs it after the turn | Measured 2026-09-24 on 2.1.281: during a turn the input box stays on screen, so the session reads ready, and a message submitted then is queued (`Implementation/Waves/00003-send/evidence/t6-summary.txt`). The user's choice, 2026-09-24, over refusing Send while a turn runs — with the risk stated in the option and accepted: a permission dialog drawn in the ~11–30 ms before the session notices it receives Send's paste and Enter, which by the dialog's footer ("Enter to confirm") would pick its highlighted choice — inferred, not measured — against D11; recorded as a limit (R4). C4 is otherwise unchanged *[Correction appended 2026-09-25, the text before it unchanged: the footer quoted, "Enter to confirm", is the trust and MCP-server dialogs'; the recorded permission dialog's reads "Esc to cancel · Tab to amend", so that the Enter would pick `❯ 1. Yes` is inferred, not read from the footer (the attack review of PR #15, finding 6; R4).]* |
| D15 | On a bare start (D3), aineo takes the screen from a startup dashboard: it opens its layout even when a dashboard (snacks.nvim's, alpha, dashboard-nvim, mini.starter) drew first, replacing the dashboard's window; with `autostart = false` the dashboard shows as before | Resolves Q5. The user's choice, 2026-09-24, over yielding to the dashboard (aineo then never opening by itself while one is enabled); the cost stated with it: T7 handles the startup order against dashboards that open on `VimEnter` or later, tested for the known ones, and an unknown one may show first |
| D16 | `\tcn` toggles the line numbers of Claude's window, with `:Aineo claude-numbers` and `<Plug>(aineo-claude-numbers)` beside it, as for every command (C1) | The user's request, 2026-09-25 (“A toogle for line number for the claude buffer "\tcn" as the command”), the first packet of wave 6. The subcommand and `<Plug>` names are the orchestrator's, after C1's pattern |
| D17 | Input keeps unsent text as a draft: saved per working directory beside the Reports shortly after each change and at quit, restored into an empty Input when aineo opens there, cleared with Input when Send clears it; two editors in one folder share one draft, the last change winning | The user's decision, 2026-09-25, after the orchestrator measured that a `nofile` Input is dropped at quit without a word: “Keep it as a draft” over refusing to quit and over both — the user having called the loss “completly undesired behavior” |
| D18 | The right column shows one of two panes: the agent pane — the Report over Input — and the changes pane (D19). `\pa` and `\pc` switch between them, with `:Aineo pane agent\|changes` and `<Plug>` mappings beside them, as for every command (C1). The right column's windows and their sizes stay put | The user's request, 2026-09-25: “the user could switch panes with \pa \pc agent pane, and changes pane, p for pane and a and c for the type of pane”. The orchestrator's proposal, D18 as written, agreed by the user for wave 7 (“Agree (Recommended)”, the orchestrator's recommended option) |
| D19 | The changes pane. Its top window lists every file that differs from the session's base commit, committed or not, and every new file, marking the files the user saved from this editor in that time, since aineo sees those saves. Its bottom window lists the session's commits, or “No commits on this session”. Enter on a file shows its unified diff in the middle column, read-only; Enter on a commit shows that commit's diff there. The middle column is read-only only for a diff, and read/write for everything else. The pane refreshes when a file is saved or changed; outside a git repository it says so. The session starts when aineo first starts Claude Code in this editor and lasts the editor's life: a restart of Claude keeps the same list and commits | The user's answers, 2026-09-25: “middle column read-only state is just applied on the diffs, otherwise it is read/write. 1. Only what Claude changed or commited on the session, so we need to keep track of the commits. Diff style unifeid one since it is just for review purposes. 3. when a file is save/changed by claude. 4 commits on the session, if no commits, just display "No commits on this session". 5. yes.” Then “Session diff, yours marked (Recommended)”, over listing only Claude's own edits through a Claude Code hook, which would change C3 and depend on the hook's format; the cost stated with it: a file both edited is not told apart. And “First Claude start (Recommended)”, over a fresh list at each Claude start. Each was the orchestrator's recommended option. Agreed with D18 (“Agree (Recommended)”), wave 7 |
| D20 | In Input, `\s` in Visual mode sends only the selection, charwise, linewise or blockwise, as one message, and removes it from Input; the rest of Input stays, not cleared. A refused Send (Claude not ready) removes nothing. `u` in Input brings back what a Send removed — a Visual Send's selection, and a whole-Input Send's text too — if it can be done, which the packet measures first; it restores only Input, the message having reached Claude. `\s` in Normal mode sends the whole Input and clears it, as C4 says | The user's request, 2026-09-25: “if the user has selected text in the input window, only the selected text is send to the prompt, and is removed from the input pane”. Their answers: “\s will work on visual mode, in this case \s will not clear but send only the selection. Yes, claude refuses do not remove, ideally only line in my mind, but we should not restrict that. If possible undo would bring back what was sent, to allow the user to quickly recover from a mistake (if posible).” The user was answering the orchestrator's two questions: “Should it cover character, line and block selections alike?” and “A refused Send (Claude not ready) should remove nothing, as today. Correct?”. The orchestrator's own clauses — “as one message”, `u` as the key, undo for whole-Input Sends too, and the measurement first — come from its settlement, told to the user the same day, to which the user did not reply. It adds a Visual-mode command beside D1's Normal mode; for a selection it supersedes C4's “the Input buffer” and “then Input cleared”, and it adds undo to every Send. Wave 7 |

## Architecture

| ID | Component | Where | Specialist |
|----|-----------|-------|------------|
| C1 | Entry point: `:Aineo …`, `<Plug>(aineo-…)` mappings, the `\` prefix mapped only where the user has not mapped it (configurable or off through `vim.g.aineo`), and the `VimEnter` autostart under D3 — never inside aineo's own Claude terminal (`$AINEO_CHILD`) | `plugin/aineo.lua`, `lua/aineo/init.lua` (the public API, `setup()`), `lua/aineo/config/` | `neovim-lua-developer` |
| C2 | Layout: the three windows, widths per D4/D6, Report read-only to the user, all three pinned against resizing; `\o` restores it | `lua/aineo/layout/` | `neovim-lua-developer` *(its right column's windows show one pane at a time, C12, 2026-09-25)* |
| C3 | Claude session: `claude` in the left terminal with the report instructions appended to its system prompt, the aineo MCP server through `--mcp-config`, `--allowedTools mcp__aineo__report`, `AINEO_CHILD=1` and the editor's `v:servername` in its environment; readiness tracking; restart; a clean stop on quit; the fake `claude` the suites run in the CLI's place | `lua/aineo/claude/`, the fake under `tests/helpers/` | `neovim-claude-code-integrator` |
| C4 | Send (`\s`): the Input buffer as one bracketed paste plus Enter into the terminal, then Input cleared; refused while Claude is not ready (trust dialog, startup) or Input is empty | `lua/aineo/send/` | `neovim-claude-code-integrator` *(for a Visual selection, “the Input buffer” and “then Input cleared” superseded by D20; undo after every Send added by D20, 2026-09-25)* |
| C5 | Report channel: a stdio MCP server run by Claude Code as `nvim --headless --clean -l …`, one tool `report`, each call relayed to the editor over its server socket | `lua/aineo/mcp/` | `neovim-claude-code-integrator` |
| C6 | Report format and rendering: tool input `{ task, status: started\|progress\|blocked\|done\|failed, summary, details? }`, rendered `HH:MM [status] task — summary` with details indented; persisted under `stdpath('state')`; the appended prompt tells Claude when to report | `lua/aineo/report/` | `neovim-lua-developer` *(rendered line superseded by C10, 2026-09-25)* |
| C7 | Health: `claude` and its version, the server socket, prefix-mapping conflicts, why autostart did or did not run | `lua/aineo/health.lua` | `neovim-lua-developer` |
| C8 | Tooling: the mini.test harness and its make targets, the suites' isolation from the developer's editor and Claude state, formatting and linting (D12) | `Makefile`, `scripts/`, `tests/`, `.stylua.toml`, the selene configuration — `prepare_project` in `.claude/scripts/prepare-worktree.sh` is the orchestrator's `ai/` pass | `neovim-lua-developer` |
| C9 | File column: a normal file buffer shown in any aineo window is moved to a middle column (created between the terminal and the right column on first use, reused after) and the aineo window gets its buffer back — a `BufWinEnter` redirect, not `'winfixbuf'`; `:q` in it returns to three windows | `lua/aineo/layout/` | `neovim-lua-developer` |
| C10 | Report line, superseding C6's rendered line (the rest of C6 stands): `<icon> HH:MM [status] task — summary`, the icon by status — `▸` started, `◐` progress, `⊘` blocked, `✓` done, `✗` failed — coloured like the status; details indented under the status | `lua/aineo/report/` | `neovim-lua-developer` |
| C11 | Input draft (D17): keeps Input's unsent text in one file per working directory beside the Reports — written shortly after each change and at once when Input empties, a pending change saved at quit, restored only into a new or emptied Input; never raises | `lua/aineo/draft/` | `neovim-lua-developer` |
| C12 | Panes (D18): the right column's two windows show one pane at a time, the agent pane or the changes pane, switched in place; v1's right column is the agent pane | `lua/aineo/layout/` | `neovim-lua-developer` |
| C13 | Git home (D19): the session's base commit, the files changed since it and the session's commits; every git call asynchronous and time-bounded | `lua/aineo/git/` — the orchestrator's name for the proposal's “a git home” | `neovim-lua-developer` |

**v1 commands:** `\s` send · `\o` open/restore · `\r` Report · `\i` Input · `\c` Claude · and `:Aineo send|open|report|input|claude`. Added in wave 6: `\tcn` toggles the line numbers of Claude's window (D16).

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
- Send may answer a permission dialog that appears in the ~11–30 ms before the session notices it (D14, R4) — accepted by the user on 2026-09-24 so that Send works while Claude is in a turn.

## Risks and unknowns

- ~~**Q1**~~ — **resolved 2026-09-23 by the orchestrator's T2 measurement** on Claude Code 2.1.281: a bracketed paste lands in the input box unsubmitted, and Enter submits it as one message (`Implementation/Waves/00002-layout-session-report/evidence/t2-summary.txt`). Was: Whether a bracketed paste plus Enter lands in Claude's prompt is unmeasured: the trust dialog (F6) stopped the spike. Measured in a folder the user trusts once, **before C4 lands**.
- ~~**Q2**~~ — **resolved 2026-09-23 by the same measurement**, with a control run: `--mcp-config`, `--allowedTools` and `--append-system-prompt` take effect interactively; the unlisted tool asked for permission, the allowed one did not (measured under `--permission-mode manual`). Was: Whether `--mcp-config` and `--allowedTools mcp__…` take effect in interactive mode — measured in the same step.
- ~~**Q3** — The formatter and linter~~ — **resolved 2026-09-23 by the user: StyLua + selene**; installed on this Mac as StyLua 2.5.2 and selene 0.31.0. lua-language-server type-checking is not in v1.
- **R1** — Claude exits (Ctrl-C, `/exit`): the terminal shows the exit; `\o` restarts the session.
- **R2** — Quitting Neovim with Claude running: aineo stops it on quit, interrupting first (SIGINT) so the turn ends rather than being cut (the integrator's rule was measured for headless `-p`; the interactive behaviour is Q4). *Carried out, since Q4's resolution of 2026-09-24, as the Ctrl-C key written to the terminal — one press, then a double press — with `jobstop` as the fallback (T4's brief).*
- **R3** — The user's own Neovim config sets `maplocalleader` to `\` (read 2026-09-23): a filetype plugin's `<LocalLeader>` mapping would shadow aineo's `\` commands in that buffer. Nothing in the config or its installed plugins uses `<LocalLeader>` today; C7 reports conflicts.
- **R4** — Send's paste and Enter can reach a permission dialog drawn in the 11–30 ms before the session's readiness notices it (the re-measure of PR #11, finding 8: 10.8–29.5 ms over ten cycles). What the dialog does with the pasted bytes, and whether the Enter then answers it with its highlighted `❯ 1. Yes`, is inferred, not measured — its footer reads "Esc to cancel · Tab to amend" (corrected 2026-09-25: this row first said it inferred from a footer "Enter to confirm", which is the trust and MCP-server dialogs'). The 11–30 ms is a lower bound: Claude Code's own input and render latency are not in it, nor are dialogs drawn in several writes (the attack review of PR #15, finding 6). Accepted with D14 (the user, 2026-09-24); MR49 of [[Review/2026-09-24 — v1 MVP readings review]].
- ~~**Q5**~~ — **resolved 2026-09-24 by the user: D15** (aineo takes the screen from a startup dashboard). Was: A startup dashboard (snacks.nvim's, alpha, dashboard-nvim, mini.starter) claims the same bare-`nvim` start as the autostart (D3). The user, 2026-09-23: "I have a plugin that starts a screen in full screen, it should not, the aineo should open" — after which the orchestrator turned off snacks.nvim's dashboard in the user's config at their request. *[Corrected 2026-09-24: this row first said the user had turned it off.]* Whether aineo takes the screen from a dashboard or documents that it must be off changes C1 — converged with the user before T7 is dispatched.
- ~~**Q4**~~ — **resolved 2026-09-24 by the orchestrator's measurement** on 2.1.281: one Ctrl-C during a turn ends the turn and keeps the process; a double Ctrl-C 0.3 s apart exits 0 at idle but not during a turn; `/exit` exits 0; `jobstop` exits 129 (`…/evidence/t4-summary.txt`). Measured for Ctrl-C typed into the terminal — the byte `\3` written to its pty; whether the TUI reads it as a byte (raw mode) or the pty turns it into SIGINT was not measured, nor a SIGINT signal sent to the process; T4 stops Claude by keys. Was: How the interactive TUI answers SIGINT and the end of its input — whether a turn ends or is cut. Measured with Q1 and Q2 in T2.
- **Q6** — What `\o` does while the changes pane is shown (D18): restore the layout keeping that pane, or go back to the agent pane. No row decides it; for the user before wave 7's plan.
- **Q7** — Whether the changes pane's commits window refreshes when Claude commits without changing a file in the working tree: D19 refreshes when a file is saved or changed. For the user, or a reading in wave 7's plan.

## Implementation plan

| ID | Task | Depends on | Status |
|----|------|------------|--------|
| T1 | Tooling foundation (C8) and the entry-point skeleton (C1), as a packet: the mini.test harness and its make targets (deps, test, lint, format), the suites' isolation from the developer's editor and Claude state, the `plugin/aineo.lua` and `lua/aineo/init.lua` skeletons, and `lua/aineo/config/` with `vim.g.aineo` validation. The agent-configuration part — `.gitignore`, the `modularity` table, the Nvim minimum in the root `CLAUDE.md` (before the packet), and the commands in `CLAUDE.md` and any `prepare_project` step (after it) — is the orchestrator's `ai/` pass, because no implementer edits those files | — | done — PR #4, wave 1 |
| T2 | Measure Q1, Q2 and Q4 against the real CLI in a folder the user trusts; record the transcripts as fixtures and the result as a Learning | — (needs the user for the trust dialog) | done — measured by the orchestrator; evidence and fixtures in `Implementation/Waves/00002-layout-session-report/evidence/`, the Learning [[Learnings/Claude Code's interactive CLI in a Neovim terminal]] |
| T3 | Layout (C2) and the file column with its redirect (C9) | T1 | done — PR #9, wave 2 |
| T4 | Claude session (C3): start, flags, environment, readiness, restart, stop on quit, and the fake `claude` its suites run | T1, T2 — T5 only through T7's wiring, by injection (wave 2 plan, *Why T4 runs beside T5*) | done — PR #11, wave 2 |
| T5 | MCP server and relay (C5), report rendering and persistence (C6) | T1, T2 | done — PR #10, wave 2 |
| T6 | Send (C4) | T2, T3, T4 | done — PR #15, wave 3 |
| T7 | Entry point (C1): prefix mapping, `<Plug>` mappings, `:Aineo`, autostart | T3, T4, T5, T6 | done — PR #17, wave 4 |
| T8 | Health (C7) and `doc/aineo.txt` | T7 | done — PR #21 (and #22), wave 5 |
| T9 | Report colours (C6): the time in `Comment`'s colour and `[status]` in a colour of its status, as highlight groups a user can override — a small fix (the user, 2026-09-25) | T8 | done — PR #30, wave 6 |
| T12 | `\tcn` toggles the line numbers of Claude's window (D16), with its `:Aineo` subcommand, `<Plug>` mapping, health check and help | T8 | active |
| T13 | Neovim 0.12 compatibility (D10): the suite green on 0.12.5 and on 0.11.6 — Neovim's error framing stripped as 0.11's is, the `vim.system` error text, the terminal's exit line, the test editor that cannot load aineo | T8 | active |
| T14 | Input keeps unsent text as a draft (D17): saved per working directory beside the Reports shortly after each change and at quit, restored into an empty Input when aineo opens there, cleared with Input when Send clears it | T8 | active |

## Done
<!-- ~~**T1 — <title>**~~ — **Done YYYY-MM-DD** (commit in session note) -->
~~**T1 — Tooling foundation and the entry-point skeleton**~~ — **Done 2026-09-24** (commits in [[Sessions/2026-09-23 — T1 tooling foundation]])
~~**T2 — Measure Q1, Q2 and Q4**~~ — **Done 2026-09-24** (wave 2 plan, *Measured before planning*)
~~**T3 — Layout and the file column**~~ — **Done 2026-09-24** (commits in [[Sessions/2026-09-24 — T3 layout]])
~~**T4 — Claude session**~~ — **Done 2026-09-24** (commits in [[Sessions/2026-09-24 — T4 Claude session]])
~~**T5 — MCP server and relay, report rendering and persistence**~~ — **Done 2026-09-24** (commits in [[Sessions/2026-09-24 — T5 report channel]])
~~**T6 — Send**~~ — **Done 2026-09-25** (commits in [[Sessions/2026-09-24 — T6 Send]])
~~**T7 — Entry point**~~ — **Done 2026-09-25** (commits in [[Sessions/2026-09-25 — T7 entry point]])

**Done means:** a bare `nvim` in a trusted folder shows the layout; `\s` delivers Input to Claude and clears it; Claude's `report` calls render in Agent Report in the C6 format; opening a file from any window lands in the middle column at equal thirds; `:checkhealth aineo` passes; the suite is green under mini.test with the fake `claude`; vimdoc documents every command.

## Out of scope (v1)

Chat history, several sessions, diffs and selection sharing, headless mode, a user-defined report language beyond C6, Windows.

## Related
- [[Skills/Orchestrate]] · [[Projects/aineo]]
