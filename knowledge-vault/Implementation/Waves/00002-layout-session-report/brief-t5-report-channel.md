**Your role: implement.** A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` — you are dispatched as that specialist — and the *What bites here* and *Tests* sections of `.claude/agents/neovim-lua-developer.md`, which bind you too.

You are dispatched by the orchestrator to implement **one packet** of the aineo v1 plan: T5, the report channel. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*:

> T5 — MCP server and relay (C5), report rendering and persistence (C6)

It rests on: **C5** (a stdio MCP server run by Claude Code as `nvim --headless --clean -l …`, one tool `report`, each call relayed to the editor over its server socket), **C6** (the report format, its rendering, its persistence under `stdpath('state')`, and the appended prompt that tells Claude when to report), **D8** (the report is an MCP tool — its input schema *is* the format), **D11** (aineo pre-allows `mcp__aineo__report`), **F4** (`v:servername`), **A1**, **A3**, **A4**. Read those rows in the plan, not this summary of them.

### The contract with T4, fixed in both briefs

T4 (the Claude session, this wave) does not `require` your homes: the composition root (T7) hands it three values, and **you build them**:

| Value | Shape | Home |
|---|---|---|
| the MCP servers | `{ aineo = entry }`, `entry` in Claude Code's `--mcp-config` server format: `{ type = 'stdio', command = <string>, args = <list of strings>, env = <table of strings> }` — a function of the editor's address | `aineo.mcp` |
| the tools to pre-allow | `{ 'mcp__aineo__report' }` — derived from the server name and the tool name, one source for both | `aineo.mcp` |
| the instructions | one string, appended to Claude's system prompt (C6) | `aineo.report` |

The layout (T3, this wave) shows the Report buffer your `aineo.report` owns: the root (T7) asks your home for it and hands it to the layout. The layout never writes into it.

### The behaviours — the orchestrator's reading of T5, one test each; the seams are yours

**The report (C6), in `lua/aineo/report/`:**

- **R1 Validation.** A report is `{ task, status, summary, details? }`: `task` and `summary` non-empty strings, `status` one of `started`, `progress`, `blocked`, `done`, `failed`, `details` a string or absent — a JSON `null` counts as absent (`vim.NIL` is truthy). Anything else is refused with a message naming the field, and nothing is rendered or stored. One list of statuses feeds the validation, the tool's schema and the instructions.
- **R2 Rendering.** An accepted report renders as `HH:MM [status] task — summary` (an em dash, U+2014, as C6 writes it), the time taken from a clock your home receives (a test fixes it), with each line of `details` below it, indented. A newline inside `task` or `summary` never makes a second header line or an error — the orchestrator's reading: it becomes a space (`nvim_buf_set_lines` refuses strings holding a newline).
- **R3 The Report buffer.** Your home owns one Report buffer, created on first use: not a file (`'buftype'` `nofile`), no swap file, kept when hidden, and **read-only to the user** (C2 names this; the buffer is yours, so the property is too) — a user's edit fails, your own rendering still appends. Reports appear in arrival order; every window showing the buffer follows the newest report (the orchestrator's reading).
- **R4 Persistence.** Each accepted report, with its time, is appended as one record to a file under `stdpath('state')`, keyed by the editor's working directory (the orchestrator's reading: Claude's sessions are per folder, so the Report is too). When the Report buffer is created in a directory with records, they render first, with their original times; another directory's records never show. A record that fails to decode is skipped and counted, not fatal. The suite's `stdpath('state')` is inside `.tests/` (T1's isolation): no test touches the developer's.
- **R5 Instructions.** The text appended to Claude's system prompt says when to report — the orchestrator's reading: when a task starts, at meaningful progress on a long task, when it is blocked on the user, when it is done, when it failed — names the tool `mcp__aineo__report` and its fields, and lists every status from the one list (a pin: every status appears in it).

**The server and relay (C5), in `lua/aineo/mcp/`:**

- **M1 Protocol.** The relay speaks MCP over stdio: JSON-RPC 2.0, one message per line. *Recorded* from Claude Code 2.1.281 (`evidence/t2-handshake.txt`, 2026-09-24): `initialize` with `protocolVersion` `"2025-11-25"` and `id` 0, then `notifications/initialized`, then `tools/list` with `id` 1; a `tools/call` carries `name`, `arguments` and `_meta` (`claudecode/toolUseId`, `progressToken`) (`evidence/t2-summary.txt`). Build your client-side test messages from these recordings, and state their version in the fixture's header. The relay:
  - answers `initialize` with the client's `protocolVersion` when it is one the relay supports, else the newest it supports; `capabilities.tools` an **object** (`vim.empty_dict()`), and `serverInfo`;
  - answers no notification (a message without `id`);
  - answers `tools/list` with one tool, `report`, whose `inputSchema` is the report of R1 (`type` object, the four properties, `status` an `enum` from the one list, `required` `task`, `status`, `summary`, no other properties allowed);
  - answers `tools/call` for `report` with a result whose `content` is one text item — `isError` true, with R1's message, when the arguments are refused (a tool error is a result, not a JSON-RPC error); a call naming another tool gets JSON-RPC error `-32602`;
  - answers `ping` with an empty object; any other method with an `id` gets JSON-RPC error `-32601`;
  - answers a line that is not JSON with error `-32700` and `id` null, and keeps serving; buffers a partial line until its newline; echoes every `id` unchanged, `0` and strings included; refuses a line longer than a stated limit without buffering past it;
  - exits 0 when its input closes.
- **M2 Relay to the editor.** A valid `report` call reaches the editor whose address the relay was started with, and renders in that editor's Report buffer (R2); the tool result then says it was delivered. The relay passes the report to the editor **as data** — its fields never become Lua source, a command line or a shell string (pin: a report whose fields hold quotes, brackets and Lua code renders literally and runs nothing). When the editor cannot be reached — no address, or a socket that is gone — the call's result is `isError` true with a message saying so, and the relay keeps serving. The relay uses the address it was **given**; *measured* (`evidence/t2-handshake.txt`): the server also inherits `NVIM` and `AINEO_CHILD` through `claude`, but the given address is the one C5 names.
- **M3 The server entry.** A function of the editor's address returns the `--mcp-config` entry: `command` the running editor's own binary (`v:progpath`), `args` that run the relay with `--headless --clean -l` and the relay's absolute path, `env` carrying the address. Pin: the entry, started as Claude Code would start it (`vim.system` with its `command`, `args` and `env`), completes the recorded handshake and relays a call into a child Neovim. The relay runs under `--clean`, so it finds aineo's own Lua from its own path, not from `'runtimepath'`.

### Facts, checked against `origin/dev`

Paths under `evidence/` are in `knowledge-vault/Implementation/Waves/00002-layout-session-report/`.

- `origin/dev` is `798275d`: wave 1 landed — T1 (PR #4, rebased as `5edf69f` … `7284c00`) and the wave-1 `ai/` pass (PR #5: `12353b2`, `83c263e`, `798275d`). Its top level: `.claude`, `.githooks`, `.gitignore`, `.stylua.toml`, `.worktreeinclude`, `CLAUDE.md`, `Makefile`, `knowledge-vault`, `lua`, `neovim.yml`, `plugin`, `scripts`, `selene.toml`, `tests` (`git ls-tree --name-only origin/dev`). Under `lua/aineo/`: `init.lua` and `config/` only.
- **The suite** (root `CLAUDE.md` › *Read this first*): `make deps`, `make test`, `make test_file FILE=<path>`, `make lint`, `make format`. `make test` collects every `tests/**/test_*.lua` — a new test file needs no registration — and isolates every Neovim it starts, the runner included, under the checkout's `.tests/` (`XDG_*_HOME`, `CLAUDE_CONFIG_DIR`, `NVIM_LOG_FILE`; `stdpath('state')` is `.tests/state/nvim`). The runner ends a run at 16 minutes (`AINEO_TEST_RUN_LIMIT_MS`); the whole suite took about 87 s on the orchestrator's host.
- **Helpers** are loaded with `dofile('tests/helpers/<name>.lua')` (`tests/test_plugin.lua:2`). `child.lua`'s `restart(child, extra_args)` (re)starts a child from `MiniTest.new_child_neovim()` with mini.test's own start arguments (`--clean`, headless, listening) and the suites' minimal init, so the child sources `plugin/` as a user's editor would; `fixture.lua` makes files under `.tests/fixtures/` (`directory(name)`, `write(name, lines)`); `make.lua` runs a Makefile target; `git.lua` runs git hermetically. T1's helpers are not yours to edit; add your own beside them.
- **The configuration home** `aineo.config` (`lua/aineo/config/init.lua`): `resolve_config(global_settings, setup_options)` returns the resolved table — `config.prefix`, `config.autostart`, `config.claude.cmd`, `config.layout.report_height` — and the unknown keys; `record_setup_options()` / `recorded_setup_options()` keep what `setup()` was given. Nothing calls `resolve_config` at startup yet: the composition root does, in T7, and hands each home the values it needs.
- A child's server address — the editor a relay test dials — is `child.job.address`: mini.nvim v0.18.0's `new_child_neovim()` starts the child with `--listen` on `vim.fn.tempname()` and keeps it there (`lua/mini/test.lua` at the pin, the child's `start`).
- The `modularity` skill's interim deep-`require` check — `grep -rnE "require\(['\"]aineo\.[a-z_]+\." lua plugin tests scripts` — prints nothing on `origin/dev`; run it before you report.

- `lua/aineo/mcp/` and `lua/aineo/report/` do not exist on `origin/dev`; the `modularity` skill's §1 names them the homes of C5 and C6, and its direction table lets `aineo.mcp` require `aineo.config` and `aineo.report`, and `aineo.report` require `aineo.config`.
- T2 (`evidence/t2-summary.txt`): with `--allowedTools mcp__probe__ping`, an interactive Claude called a stdio MCP server's tool without a permission prompt; without it, the call asked (the control). The server's `env` from `--mcp-config` reached the server (the probe logged to the file its `env` named).
- The real `claude` never runs in your packet: not in a test, not in a measurement.

### Baseline

`make test`: **111 cases, `Fails (0)`, exit 0** — measured by the orchestrator on 2026-09-24 at `5b323d8`, PR #4's final head, which is code-identical to `798275d` (`git diff --stat 5b323d8 798275d -- lua plugin scripts tests Makefile neovim.yml selene.toml .stylua.toml` prints nothing). `.claude/hooks/test-hooks.sh`: **78 passed, exit 0**, at `798275d`, 2026-09-24 05:47 CEST. Both in `evidence/baseline.txt`.


Read first: the plan's *Authority*, *Decisions & reasoning* (D8, D11), *Architecture* (C2, C3, C5, C6), *Alternatives rejected* (A1, A3, A4); `knowledge-vault/Projects/aineo.md`; the `modularity` skill §1, §2 and §4; the MCP specification's *Lifecycle* and *Tools* pages at the protocol version the recording names — read raw — and the evidence files above.

## Boundary

- **Branch:** `feature/t5-report-channel` from `origin/dev`.
- **Model:** `opus` — every role in this project runs on Opus (D9).
- **Resources:** `impl_t5_report` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/mcp/`; `lua/aineo/report/`; `tests/test_mcp*.lua`, `tests/test_report*.lua`; new files under `tests/helpers/` whose names begin with `mcp` or `report`; new fixtures under `tests/fixtures/mcp/`; and the session note below. No existing document describes these homes.
- **You must not touch:** the other homes — `lua/aineo/layout/` (T3, this wave), `lua/aineo/claude/` (T4, this wave), `lua/aineo/send/`, `lua/aineo/init.lua`, `lua/aineo/config/`, `plugin/aineo.lua`; T1's existing files under `tests/helpers/`, `scripts/` and the `Makefile` (a need there is a spec conflict for your report); the plan note (**this wave holds its task marks** — write a `## Task lines` section in your session note instead); the project note; and never `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude` or `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/<YYYY-MM-DD> — T5 report channel.md`, the date read from `date` on the day you start.
- **Scratch prefix:** `t5-` on every file you write under the shared scratchpad.
- Anything the task needs that lies outside the boundary is a **spec conflict** for your report, not a reason to widen it.

## What was decided already

- **The report is an MCP tool**, not a file, a hook or the IDE protocol — D8, A1, A3, A4.
- **The format**: `{ task, status: started|progress|blocked|done|failed, summary, details? }`, rendered `HH:MM [status] task — summary` — C6.
- **The server runs as `nvim --headless --clean -l …`** and relays over the editor's server socket — C5.

## Verification mutants — the orchestrator runs these on your final head

Each is a literal edit, applied and shown with `git diff HEAD` before the run. Write the tests that kill them, and name in your report, for each, the test that fails:

- **M7** — build `initialize`'s `capabilities.tools` as `{}` (it then encodes as `[]`) → the M1 test fails.
- **M8** — remove `blocked` from the one list of statuses → the R1 test for a `blocked` report fails (and so does R5's pin).
- **M9** — persist every report to one file, whatever the working directory → the R4 other-directory test fails.

## Budget

Large: two homes — a protocol server with its relay, and the report's validation, rendering, buffer and persistence. If it is larger than that, stop at a green, reviewed, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t5-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure — including the line limit and how it is enforced, the protocol versions supported, and the M7–M9 killing tests.
