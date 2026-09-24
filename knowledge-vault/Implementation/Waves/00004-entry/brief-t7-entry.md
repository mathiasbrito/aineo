**Your role: implement.** Your worktree starts from `main`, whose `.claude/` is stale: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md` — you are dispatched as that specialist — and `.claude/agents/neovim-claude-code-integrator.md` › *Tests* and the sections on the fake, which bind the fake you extend.

You are dispatched by the orchestrator to implement **one packet** of the aineo v1 plan: T7, the entry point — the composition root that wires the homes into the console the user sees. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*:

> T7 — Entry point (C1): prefix mapping, `<Plug>` mappings, `:Aineo`, autostart

It rests on: **C1** (the entry point), **D1** (the prefix `\`), **D3** (autostart only on a bare interactive `nvim`), **D13** (the settings `prefix`, `autostart`, `claude.cmd`, `layout.report_height`), **D15** (the user, 2026-09-24: aineo takes the screen from a startup dashboard), **R1** (`\o` restarts an exited session), **R3** (the user's `maplocalleader` is `\`), and the plan's line **v1 commands:** "`\s` send · `\o` open/restore · `\r` Report · `\i` Input · `\c` Claude · and `:Aineo send|open|report|input|claude`". It wires C2 (`aineo.layout`), C3 (`aineo.claude`), C4 (`aineo.send`), C5 (`aineo.mcp`) and C6 (`aineo.report`) through their entry points. Read those rows in the plan, not this summary of them.

### The behaviours — the orchestrator's reading of C1, one test each; the seams are yours

- **EP1 `:Aineo {send|open|report|input|claude}`.** One user command whose argument completes to the five; without one, or with another, it tells the user the five in one message and does nothing else.
- **EP2 `<Plug>(aineo-send)`, `<Plug>(aineo-open)`, `<Plug>(aineo-report)`, `<Plug>(aineo-input)`, `<Plug>(aineo-claude)`** — Normal mode, each doing what the matching subcommand does.
- **EP3 The prefix.** Normal-mode `<prefix>s`, `o`, `r`, `i`, `c` go to the matching `<Plug>` mapping, with `prefix` from the configuration (D13, default `\`). Each is made **only where the user has not mapped that key sequence** — the user's mapping stays and aineo's is not made (C7, T8, reports it); `prefix = false` maps nothing. The configuration must be complete when the mappings are made: a plugin manager may source `plugin/aineo.lua` before it runs the user's `setup()` — measure what lazy.nvim's `lazy = false` does, or read its source at a cited version, and say when yours are made.
- **EP4 Open (`\o`)** — the composition:
  - the configuration resolved (`require('aineo.config').resolve_config(vim.g.aineo, recorded_setup_options())`): a wrong value is one error message naming the setting, and nothing opens; unknown keys are one warning naming them;
  - the report home given its environment once (`set_report_environment`: the clock, a state directory under `stdpath('state')`, `getcwd()`), and its Report buffer taken (`report_buffer()`);
  - the session started — `require('aineo.claude').start_session({ cmd = config.claude.cmd, cwd = getcwd(), mcp_servers = require('aineo.mcp').mcp_servers(v:servername, v:progpath), allowed_tools = require('aineo.mcp').allowed_mcp_tools(), instructions = require('aineo.report').report_instructions(require('aineo.mcp').report_tool_name()) })` — and **shown in the same tick** with `require('aineo.layout').open({ claude = <its buffer>, report = <the Report>, report_height = config.layout.report_height })`. `start_session()`'s docstring states why: a terminal not yet shown gets the rows of a hidden window, 5 at 80 columns, where Claude Code's prompt does not fit;
  - again while the session runs: the layout restored, nothing started (the homes do both);
  - **after Claude has exited (R1): a new session started and shown** — `start_session()` puts the new terminal in every window that showed the old.
- **EP5 Focus (`\r`, `\i`, `\c`)** — `require('aineo.layout').focus(role, arrangement)`, with the arrangement EP4 builds, so a focus with the layout closed opens it (and starts the session if none runs).
- **EP6 Send (`\s`)** — `require('aineo.send').send()` (T6: no argument; it refuses with its own message). **Not an `<expr>` mapping:** Send clears Input before it writes, and under textlock — an `<expr>` mapping's evaluation — the clear fails and Send refuses (T6's fix round, the attack review of PR #15, finding 2).
- **EP7 Autostart (D3, D13, C1).** Once per editor, at startup, when `autostart` is true **and** the start is bare and interactive, the editor does what `\o` does. *Measured* (`evidence/t7-startup-summary.txt`, Neovim 0.11.6): at `VimEnter` an interactive start already has a UI attached (`#nvim_list_uis() == 1`) and `--headless` has none; a file argument makes `argc()` 1; piped stdin fires `StdinReadPost` before `VimEnter` with `argc()` 0. Never when `$AINEO_CHILD` is set (C1: aineo's own Claude terminal). Nothing starts for `nvim file`, `git commit`, `--headless`, piped stdin. A start D3 does not name — a session restored with `-S`, commands given with `-c` or `+` — is your reading, stated, pinned and routed to *Readings for the MVP review*.
- **EP8 A startup dashboard (D15).** When a dashboard shows at a bare start — snacks.nvim's, alpha, dashboard-nvim, mini.starter — aineo's layout still opens, and the dashboard is not left on screen; with `autostart = false` the dashboard is left alone. The orchestrator measured no dashboard: read when each opens from its source at a version you cite (raw source, never a summary), or build stand-ins that open a buffer of each one's filetype at `VimEnter`, at `UIEnter` and from `vim.schedule()` after `VimEnter`; the property holds for every moment you pin, and the note says which moments you did not.
- **EP9 End to end through the fake.** A new mode of the fake `claude` acts as the MCP client Claude Code is: it reads its `--mcp-config` argument, starts the server entry it names (command, arguments, environment), speaks `initialize`, `notifications/initialized`, `tools/list` and `tools/call` of the report tool, and exits. `\o` with that fake shows the report in the Report, rendered in C6's format. This proves the wiring the homes' own suites inject: `v:servername`, `v:progpath`, the entry's environment. *Measured by the orchestrator on the real CLI* (`evidence/t7-summary.txt`): wired by hand exactly as EP4 says, Claude Code 2.1.281 accepted the report tool — its schema's `"details": {"type": ["string", "null"]}` included — and its call rendered in the Report.
- **EP10 The plugin file stays cheap.** Sourcing `plugin/aineo.lua` requires no aineo module (T1's pin stands); a headless start loads none.
- **EP11 `setup()` with a table that contains itself** gives one error naming `opts` — T1's session note records that it raises a stack overflow today.

### How tests reach a UI-attached start

*Measured* (`evidence/t7-startup-summary.txt`): mini.test's child always starts with `--headless`, so its `VimEnter` sees no UI. An `nvim --embed` started as an RPC job (`jobstart(…, { rpc = true })`) runs no autocommand until the test calls `nvim_ui_attach(80, 24, { ext_linegrid = true })`; then `VimEnter` sees one UI and `UIEnter` follows — a UI-attached start without a terminal. Isolate such a child as the suite isolates its own (the root `CLAUDE.md`, the `Makefile`'s variables), and stop it by its channel.

### Facts, checked against `origin/dev`

Paths under `evidence/` are in `knowledge-vault/Implementation/Waves/00004-entry/`. `<scratchpad>` is the orchestrating session's scratch directory, which the dispatch message names.

- `origin/dev` is `bb0e185`: waves 1–3 landed.
- **Where the wiring lives** (`.claude/skills/modularity/SKILL.md` §1 and its direction table): `plugin/aineo.lua` is the composition root — commands, `<Plug>` mappings, autocommands — and `require()`s a home only inside a callback, so sourcing it stays cheap; it may require any home's entry point. `lua/aineo/init.lua` (`require('aineo')`) may require only `aineo.config`. A need for another edge is a spec conflict for your report.
- **The homes' entry points** — read each docstring on `bb0e185`: `aineo.config` (`resolve_config`, `recorded_setup_options`), `aineo.layout` (`open`, `focus`, `input_buffer`; `aineo.layout.Arrangement`), `aineo.claude` (`start_session`, `session_status`, and T6's `write_to_session(bytes)`), `aineo.mcp` (`mcp_servers`, `report_tool_name`, `allowed_mcp_tools`), `aineo.report` (`set_report_environment`, `report_buffer`, `report_instructions`), `aineo.send` (`send`).
- **T1's pins your change moves:** `tests/test_plugin.lua` › *defines no autocommand, command or mapping* stops being true by design — replace it with what the file now defines; *is sourced at startup and loads no aineo module* stays. `tests/test_aineo.lua` › *exposes setup() alone* stays unless you add to the public API, which the direction table does not allow.
- **The fake** (`tests/helpers/fake_claude.lua`, T4, with T6's modes) and the session helper `tests/helpers/claude_session.lua`: add modes and helpers beside the others, leaving the existing ones unchanged. *Measured by the brief review of wave 3:* the fake echoes what it receives where the cursor is, and a second send's echo overwrites the input box's lower rule, so the session reads `'starting'` from then on — an effect of the fake, never Claude Code's behaviour; T4's `busy` mode draws the startup screen, not a turn.
- **The user's own editor** loads aineo from a clone of `dev` through lazy.nvim with `lazy = false` and calls no `setup()`; its `maplocalleader` is `\` (R3). Never start, read or write it: measure plugin managers in isolated editors only.
- **The fake's screens are 80 columns wide** (recorded from Claude Code at 120x40, which drew 80): a Claude window narrower than that never reads `ready`. The layout gives Claude half the columns, a third with the file column open — so a child showing the layout needs at least 160 columns, 240 with a file column (T6's suites run a 240x42 child; the test-integrity review of PR #15, finding 10).
- The real `claude` never runs in your packet; the measurements above are the orchestrator's.

### Baseline

**491 cases, `Fails (0)`, exit 0**, 365 s — measured by the orchestrator on 2026-09-25 (01:13–01:20 CEST) at PR #15's final head `9706947` and on T6's files laid over `dev` `0b52d7f`; the merge, `bb0e185`, is per-file identical to `9706947` on T6's files. `.claude/hooks/test-hooks.sh`: **78 passed**, exit 0, at `bb0e185`, 01:51 CEST — `evidence/baseline.txt`.

Read first: the plan's *Decisions & reasoning* (D1, D3, D13, D15), *Architecture* (C1–C6, the v1 commands line), *Risks and unknowns* (R1, R3); `knowledge-vault/Projects/aineo.md`; the `modularity` skill §1, §2 and §4; the *Readings for the MVP review* of the T3, T4, T5 and T6 session notes; the evidence named above.

## Boundary

- **Branch:** `feature/t7-entry` from `origin/dev`.
- **Model:** `opus` (D9).
- **Resources:** `impl_t7_entry`.
- **You may touch:** `plugin/aineo.lua`; `lua/aineo/init.lua`; `lua/aineo/config/` for EP11 only; `tests/test_plugin.lua` and `tests/test_aineo.lua` for the pins above; `tests/test_config.lua` for EP11; `tests/test_entry*.lua` (new); `tests/helpers/fake_claude.lua` and `tests/helpers/claude_session.lua` — new modes and helpers only; new files under `tests/helpers/` whose names begin with `entry`; new fixtures under `tests/fixtures/claude/` (where the fake reads its screens — new files only, each with a header naming its source) and `tests/fixtures/entry/`; and the session note below.
- **You must not touch:** the homes `lua/aineo/layout/`, `lua/aineo/claude/`, `lua/aineo/send/`, `lua/aineo/mcp/`, `lua/aineo/report/` — a change one needs is a spec conflict for your report; `lua/aineo/health.lua` and `doc/` (T8); T1's `scripts/`, `Makefile` and helpers; the plan note (marks held: a `## Task lines` section in your note); the project note; and never `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude` or `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/<YYYY-MM-DD> — T7 entry point.md`, the date read from `date` on the day you start.
- **Scratch prefix:** `t7-`.

## What was decided already

- **D15** — the user, 2026-09-24, over yielding to a dashboard: aineo takes the screen at a bare start; `autostart = false` leaves the dashboard alone.
- **D14** — Send works while Claude is in a turn (T6 built it; EP6 only calls it).
- **The composition root is `plugin/aineo.lua`** — the modularity table, agreed with the plan.

## Verification mutants — the orchestrator runs these on your final head

- **M19** — autostart without the UI check → the `--headless` test fails: a session started.
- **M20** — the prefix mapping made over a user's mapping → the test that keeps the user's mapping fails.
- **M21** — `mcp_servers('', v:progpath)` in place of `v:servername` → the EP9 test fails: no report in the Report.
- **M22** — autostart without the `$AINEO_CHILD` check → that test fails.
- **M23** — autostart skipped while a dashboard's filetype shows → the D15 test fails.

## Readings

Every choice where the rows and this brief are silent goes to a *Readings for the MVP review* section of your session note, each named once, with the same list in the pull request body and your report.

## Budget

Medium to large: the command, five `<Plug>` mappings and the prefix, the composition, the autostart with D3 and D15, and the fake's MCP-client mode. If it is larger than that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t7-report-packet.md`. Open the pull request into `dev` before you report, with every verification claim a reviewer can re-measure. **Keep your context small:** test and mutant output go to files, and you read back the summary line and failing names; run each mutant against a copy of its test file narrowed to the group it targets, under `.tests/`.
