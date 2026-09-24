**Your role: implement.** A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` — you are dispatched as that specialist — and the *What bites here* and *Tests* sections of `.claude/agents/neovim-lua-developer.md`, which bind you too.

You are dispatched by the orchestrator to implement **one packet** of the aineo v1 plan: T4, the Claude session. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*:

> T4 — Claude session (C3): start, flags, environment, readiness, restart, stop on quit, and the fake `claude` its suites run

It rests on: **C3** (the Claude session), **D2** (the agent is the interactive Claude Code in the left terminal), **D8** and **D11** (the report is an MCP tool; aineo pre-allows its own report tool and nothing else, raises no permission mode and answers no prompt), **D10** (the real Claude never runs in the suite), **D13** (`claude.cmd`), **R1** (Claude exits: the terminal shows the exit; `\o` restarts the session), **R2** (quitting Neovim stops Claude, interrupting first), **Q4** and **F6**. Read those rows in the plan, not this summary of them.

**The user asked for this packet by name on 2026-09-24:** "Plan also the implementation of the plumbing of the claude agent with his window on the left, given that he received the instruction to report on it. after planning implement it."

### How T4 runs beside T5 — the contract, fixed in both briefs

The plan lists T4 as depending on T5, because the session registers the report server (C3, C5). This wave removes that dependency **by injection**, and the wave plan records why: `aineo.claude` does not `require` `aineo.mcp` or `aineo.report`. Its caller — the composition root, wired in T7 — hands it three values, and T5's brief builds exactly these:

| Value | Shape | T5 builds it in |
|---|---|---|
| the MCP servers | a Lua table `{ [name] = entry }`, each `entry` in Claude Code's `--mcp-config` server format: `{ type = 'stdio', command = <string>, args = <list of strings>, env = <table of strings> }` | `aineo.mcp` (server name `aineo`) |
| the tools to pre-allow | a list of strings — in v1 `{ 'mcp__aineo__report' }` | `aineo.mcp` |
| the instructions | one string, appended to Claude's system prompt | `aineo.report` (C6: "the appended prompt tells Claude when to report") |

Your tests supply stand-in values of these shapes. The end-to-end path (a Claude that calls the real `report` tool) is T7's, once both homes exist.

### The behaviours — the orchestrator's reading of T4, one test each; the seams are yours

- **S1 Start.** The session runs `claude.cmd` (D13: a list of strings, default `{ "claude" }`) with the arguments below, in a new terminal buffer — `jobstart(cmd, { term = true })`, a list, never a shell string — with the editor's current directory as its `cwd`, and gives its caller that buffer so the layout (T3, through T7) can show it on the left. Starting while a session is running starts nothing and returns the running session: one `claude` at a time.
- **S2 Arguments (C3, D11).** After the configured command come, in any order the fake can read: `--mcp-config` with one JSON string whose decoded value is `{ "mcpServers": <the servers given> }` — each entry's `env` an **object** even when empty (`vim.empty_dict()`; `vim.json.encode({})` is `"[]"`); `--allowedTools` with each tool given; `--append-system-prompt` with the instructions given, byte for byte. Nothing else: no `--permission-mode`, no `--dangerously-skip-permissions`, no other flag of aineo's own (D11). An element of `claude.cmd` holding spaces and quotes reaches the process unchanged.
- **S3 Environment (C3).** The process sees `AINEO_CHILD=1` and the editor's `v:servername`. *Measured* (`evidence/t2-handshake.txt`): Neovim already gives a `jobstart` terminal the variable `NVIM` set to `v:servername`, and it reached an MCP server that `claude` started; pin it in your test anyway, since C3 names it. Every other variable passes through unchanged — the orchestrator's reading: the user's `CLAUDE_CONFIG_DIR` and the like are theirs. (The **suite** removes the orchestrating session's `CLAUDE*` variables — T1's isolation; that is not the session's behaviour.)
- **S4 Readiness.** The session reports *starting*, *ready* or *exited* (with the exit code). It becomes ready when the terminal's screen shows the prompt glyph `❯` **and no trust-dialog text** — *measured* in T2 (`evidence/t2-summary.txt`): the glyph with no trust text, then a settle of 1.5 s before any input, worked in every run; a wait keyed on the footer text `? for shortcuts` timed out with the prompt ready in the run where a warning took the footer line (in the clean runs the footer did show after start), so the footer is not the signal; and the trust dialog's selected line carries the same `❯` (`evidence/t4-trust-dialog-screen.txt`). Whether the settle is needed is unmeasured: derive whether readiness waits after the glyph from what the fake and the recorded bytes show, and say what you chose. A session behind the trust dialog never becomes ready; after the process exits it is not ready. How you watch the screen (buffer events, a timer) is yours — mind that terminal-buffer callbacks run under textlock and fast-event rules (`neovim-lua-developer.md`).
- **S5 The exit shows (R1).** When `claude` exits (Ctrl-C twice, `/exit`), its terminal buffer stays valid and shows Neovim's own `[Process exited N]` line; the session reports *exited* with N.
- **S6 Restart (R1).** Restarting an exited session starts a new process in a new terminal buffer, which the caller receives to show in the left window; the old terminal buffer is wiped (the orchestrator's reading: one Claude buffer at a time, so the buffer list does not fill with dead terminals). Restarting a running session starts nothing.
- **S7 Stop on quit (R2, Q4).** When Neovim quits with a session running, the session stops `claude` **by the keys a user would press, before any signal** — and none outlives Neovim. *Measured* on 2.1.281 (`evidence/t4-summary.txt`, `evidence/t2-summary.txt`):
  - one Ctrl-C (`\3`) **during a turn** ends the turn and keeps the process; the message's text is put back into the input box;
  - a double Ctrl-C (two `\3`, 0.3 s apart) **at idle** exits 0 — with or without text in the input box — within about 1.6–2.9 s of the second press; a gap of 1.2 s does not exit (the window is shorter);
  - a double Ctrl-C **during a turn** does **not** exit (no exit within 10 s);
  - `jobstop` (SIGHUP to a terminal job) exits 129.

  So the sequence is: one `\3`; then a double `\3`; then a bounded wait for the exit; then `jobstop` as the fallback. The waits are **timings on the orchestrator's host**; derive yours from the phases (the turn ending after the first press, the double-press window, the exit after the second), state them in the report, and keep the whole stop bounded — a quit that hangs is a defect. Register the stop yourself when a process starts (the orchestrator's reading: the child's lifetime is the session's concern, so no caller can forget it). **Measure first** what Neovim 0.11.6 does on `:qa` — without `!` — while a terminal job runs (E948, E37 or nothing); the behaviour required is that `:qa` quits the editor and stops Claude by the sequence above.
- **S8 The fake `claude` (C3, D10).** An executable under `tests/helpers/` that the suites run in the CLI's place — through `claude.cmd`, so no test depends on `PATH` order. It records, to a file the test names through its environment, its argv, the environment variables a test asks about, and every byte it receives, and it plays the behaviours of S4 and S7 **as measured**, not as documented:
  - *ready*: replays the recorded startup bytes (`evidence/t4-claude-2.1.281-startup-paste-exit.bytes.txt` — copy what you use into your fixtures with the version and date in a header); then echoes what it receives;
  - *trust*: shows the trust dialog's text (`evidence/t4-trust-dialog-screen.txt`) and never becomes ready;
  - *busy*: behaves as in a turn — the first `\3` ends the turn, a double `\3` then exits 0; a double `\3` during the turn does not;
  - *deaf*: ignores every key, so only the fallback stops it.

  **A pty delivers Ctrl-C as SIGINT unless the program puts its terminal in raw mode** — the real `claude` does (its bytes enable bracketed paste, `ESC[?2004h`). A fake that stays in cooked mode receives a signal, not the byte `\3`; measure what yours receives. The recorded bytes also carry terminal queries (DA, `ESC[16t`, a kitty graphics query) whose answers Neovim's terminal writes back to the fake's input: tests that assert on received bytes account for them. Write the fake in Lua run by Neovim (`nvim -l`) or in POSIX `sh` — the suite needs no other interpreter.

### Facts, checked against `origin/dev`

Paths under `evidence/` are in `knowledge-vault/Implementation/Waves/00002-layout-session-report/`.

- `origin/dev` is `798275d`: wave 1 landed — T1 (PR #4, rebased as `5edf69f` … `7284c00`) and the wave-1 `ai/` pass (PR #5: `12353b2`, `83c263e`, `798275d`). Its top level: `.claude`, `.githooks`, `.gitignore`, `.stylua.toml`, `.worktreeinclude`, `CLAUDE.md`, `Makefile`, `knowledge-vault`, `lua`, `neovim.yml`, `plugin`, `scripts`, `selene.toml`, `tests` (`git ls-tree --name-only origin/dev`). Under `lua/aineo/`: `init.lua` and `config/` only.
- **The suite** (root `CLAUDE.md` › *Read this first*): `make deps`, `make test`, `make test_file FILE=<path>`, `make lint`, `make format`. `make test` collects every `tests/**/test_*.lua` — a new test file needs no registration — and isolates every Neovim it starts, the runner included, under the checkout's `.tests/` (`XDG_*_HOME`, `CLAUDE_CONFIG_DIR`, `NVIM_LOG_FILE`; `stdpath('state')` is `.tests/state/nvim`). The runner ends a run at 16 minutes (`AINEO_TEST_RUN_LIMIT_MS`); the whole suite took about 87 s on the orchestrator's host.
- **Helpers** are loaded with `dofile('tests/helpers/<name>.lua')` (`tests/test_plugin.lua:2`). `child.lua`'s `restart(child, extra_args)` (re)starts a child from `MiniTest.new_child_neovim()` with mini.test's own start arguments (`--clean`, headless, listening) and the suites' minimal init, so the child sources `plugin/` as a user's editor would; `fixture.lua` makes files under `.tests/fixtures/` (`directory(name)`, `write(name, lines)`); `make.lua` runs a Makefile target; `git.lua` runs git hermetically. T1's helpers are not yours to edit; add your own beside them.
- **The configuration home** `aineo.config` (`lua/aineo/config/init.lua`): `resolve_config(global_settings, setup_options)` returns the resolved table — `config.prefix`, `config.autostart`, `config.claude.cmd`, `config.layout.report_height` — and the unknown keys; `record_setup_options()` / `recorded_setup_options()` keep what `setup()` was given. Nothing calls `resolve_config` at startup yet: the composition root does, in T7, and hands each home the values it needs.
- The `modularity` skill's interim deep-`require` check — `grep -rnE "require\(['\"]aineo\.[a-z_]+\." lua plugin tests scripts` — prints nothing on `origin/dev`; run it before you report.

- `lua/aineo/claude/` does not exist on `origin/dev`; the `modularity` skill's §1 names it the home of C3, and its direction table lets `aineo.claude` require `aineo.config` and `aineo.mcp` — this packet uses neither `aineo.mcp` nor `aineo.report` (the contract above); `aineo.config` only if you read `claude.cmd` from it rather than receiving it.
- T2's measurements (`evidence/t2-summary.txt`, 2026-09-23): a bracketed paste lands in the input box unsubmitted and Enter submits it as one message (Q1 — C4's, T6); `--mcp-config` as a JSON string, `--allowedTools` and `--append-system-prompt` take effect in interactive mode, with a control run (Q2); an inherited `CLAUDE_CODE_CHILD_SESSION` marker turned transcript saving off (why the suite removes `CLAUDE*`).
- The real `claude` never runs in your packet: not in a test, not in a measurement. The recorded bytes and screens are the orchestrator's (T2), made in a folder the user trusted.

### Baseline

`make test`: **111 cases, `Fails (0)`, exit 0** — measured by the orchestrator on 2026-09-24 at `5b323d8`, PR #4's final head, which is code-identical to `798275d` (`git diff --stat 5b323d8 798275d -- lua plugin scripts tests Makefile neovim.yml selene.toml .stylua.toml` prints nothing). `.claude/hooks/test-hooks.sh`: **78 passed, exit 0**, at `798275d`, 2026-09-24 05:47 CEST. Both in `evidence/baseline.txt`.


Read first: the plan's *Authority*, *Decisions & reasoning* (D2, D8, D10, D11, D13), *Architecture* (C3, and C4–C6 for what consumes the session), *Risks and unknowns* (R1, R2, Q4, F6 in *Facts*); `knowledge-vault/Projects/aineo.md`; the `modularity` skill §1, §2 and §4; the evidence files named above.

## Boundary

- **Branch:** `feature/t4-claude-session` from `origin/dev`.
- **Model:** `opus` — every role in this project runs on Opus (D9).
- **Resources:** `impl_t4_claude` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/claude/`; `tests/test_claude*.lua`; new files under `tests/helpers/` whose names begin with `claude` or `fake_claude`; new fixtures under `tests/fixtures/claude/`; and the session note below. No existing document describes the session.
- **You must not touch:** the other homes — `lua/aineo/layout/` (T3, this wave), `lua/aineo/mcp/` and `lua/aineo/report/` (T5, this wave), `lua/aineo/send/`, `lua/aineo/init.lua`, `lua/aineo/config/`, `plugin/aineo.lua`; T1's existing files under `tests/helpers/`, `scripts/` and the `Makefile` (a need there is a spec conflict for your report); the plan note (**this wave holds its task marks** — write a `## Task lines` section in your session note instead); the project note; and never `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude` or `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/<YYYY-MM-DD> — T4 Claude session.md`, the date read from `date` on the day you start.
- **Scratch prefix:** `t4-` on every file you write under the shared scratchpad.
- Anything the task needs that lies outside the boundary is a **spec conflict** for your report, not a reason to widen it.

## What was decided already

- **The interactive TUI in a terminal**, not headless stream-json — D2, A2.
- **Permissions are the user's** — D11: aineo pre-allows its report tool and nothing else.
- **Claude's report instructions travel by `--append-system-prompt`** — C3.
- **T4 does not wait for T5** — the orchestrator's wave plan, by the injection above, on the user's request of 2026-09-24 to plan and implement the session now.

## Verification mutants — the orchestrator runs these on your final head

Each is a literal edit, applied and shown with `git diff HEAD` before the run. Write the tests that kill them, and name in your report, for each, the test that fails:

- **M4** — build the `--mcp-config` entry's `env` with `{}` where it is empty (it then encodes as `[]`) → the S2 test fails.
- **M5** — drop the trust-dialog condition from readiness (the glyph alone) → the S4 *trust* test fails.
- **M6** — remove the first, single `\3` from the stop sequence → the S7 *busy* test fails (a double press during a turn does not exit).

## Budget

Medium to large: one home (start, arguments, environment, readiness, restart, stop) and the fake with four modes. If it is larger than that, stop at a green, reviewed, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t4-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure — including what `:qa` did before your change, the stop sequence's bounds and how you derived them, what the fake receives for Ctrl-C, and the M4–M6 killing tests.
