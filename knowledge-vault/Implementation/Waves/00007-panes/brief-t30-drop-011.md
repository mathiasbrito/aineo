**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`, since you are dispatched as the first and bound by both.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T30 | Drop Neovim 0.11 (D29): code, docstrings and test branches that exist only for Neovim 0.11 are removed, or restated for 0.12.5 where its behaviour is the same — the `vim.fn.has('nvim-0.12')` test branches keep their 0.12 side, the error framings `'^Error executing lua: '` go where 0.12.5 never produces them, the timing helper's LuaJIT check goes where 0.12.5 never needs it, and every docstring that gives a Neovim 0.11.6 behaviour as a reason says what 0.12.5 does; a removal that would change what the user sees is reported, not made | T24 | active |

It rests on **D29**: the suite runs on the newest Neovim release only, and Neovim 0.12 is the supported minimum. On 2026-10-05 the user confirmed the minimum, asked "Say if you meant to keep 0.11 working untested": "drop support for 0.11 and the dangling code and tests, since we are still in greenfield area, this is the right time for the clean up." Read D29 whole, with its *Reasoning*, and D10, whose minimum it supersedes.

**This packet removes; it adds no behaviour.** Every change is one of three kinds:
1. **a 0.11 branch removed**, its 0.12 side kept as it is;
2. **code whose only reason is a 0.11 behaviour removed**, once you have measured that 0.12.5 does not have that behaviour;
3. **a docstring restated** to give 0.12.5's behaviour as the reason, once you have measured it.

### What to clean, found with `grep -rn "0\.11\|has('nvim" lua plugin scripts tests doc Makefile` on `origin/dev` `5db771e`

Line numbers are `5db771e`'s. T24 lands first and moves some of them: find each again by its text.

**A. The eight test branches.** Each is `vim.fn.has('nvim-0.12') == 1 and <0.12 side> or <0.11 side>`, or an `if` on it. Keep the 0.12 side, drop the condition and the 0.11 side, and say in the docstring above it what Neovim 0.12 does, not what "each Neovim" does:
- `tests/test_entry.lua:196`, `:220`, `:264`, `:282`, `:311`;
- `tests/test_claude.lua:29` (`REQUEST_ERROR_FRAMING`) and `:55` (`wait_for_exit_line()`'s early return);
- `tests/test_mcp_delivery.lua:389` (`BUFFILEPRE_REASON`).

These are kind 1. They change no case's verdict on 0.12.5: the suite's case count and `Fails (0)` stay as the baseline's.

**B. The 0.11 error framing.** `'^Error executing lua: '` in two `ERROR_FRAMING` tables, with the docstrings' "`Error executing lua: ` before":
- `plugin/aineo.lua:259`: what Neovim puts before an error it passes on in this process;
- `lua/aineo/mcp/editor.lua:33`: what the editor puts before an error it answers the relay's request with. The editor is the Neovim that runs aineo, so 0.12 or later.

`tests/test_mcp_delivery.lua:332` parametrizes its framing case over `'Lua: '` and `'Error executing lua: '`. The project note's *Open threads* says it: "whether 0.12 ever produces it is unmeasured". Measure it on 0.12.5: an error raised in a Lua callback, a `:lua` command, `nvim_exec_lua()` over RPC and `nvim_exec2()` of Lua, and any other path the two tables' callers reach. Report each probe and its exact first line.
- If 0.12.5 never produces it: kind 2. Remove the pattern from both tables, the 0.11 row from the parametrized case, and the "before" from the docstrings.
- If some path still produces it: keep the pattern, and restate the docstring to name that path.

`'Error executing lua callback: '` in the 0.11 sides of A is a different string. It goes with them.

**C. The docstrings that give a Neovim 0.11.6 behaviour as a reason.** Each is Neovim's behaviour, which you can measure on 0.12.5 without Claude Code:
- `lua/aineo/claude/init.lua:105–107`: a `cwd` that cannot be entered is refused "because Neovim 0.11.6 does not refuse it: its terminal job then runs a copy of the editor in place of the command". Measure what 0.12.5's `jobstart(…, { term = true, cwd = <a directory that cannot be entered> })` does.
  - If 0.12.5 runs the command or raises, the check is kind 2 by its own reason. **But removing it changes what the user sees**: the error's words, and maybe a started session. Do not remove it. Restate the docstring with 0.12.5's behaviour, and report it as a finding for the orchestrator: the check, what 0.12.5 does without it, and what the user would see.
  - If 0.12.5 does as 0.11.6 did, it is kind 3: restate it with 0.12.5.
- `lua/aineo/claude/init.lua:392`: a hidden terminal has "5 [rows], at 80 columns, in Neovim 0.11.6". Measure it on 0.12.5; restate.
- `lua/aineo/claude/init.lua:407`: a command whose interpreter is missing exits "with 122, the code Neovim 0.11.6's terminal job exits with then". Measure on 0.12.5. If the code differs, it is a finding, not a fix: the session's `'exited'` with 122 is pinned by a test, and changing it is a behaviour change.
- `lua/aineo/claude/readiness.lua:60`: "as Neovim 0.11.6 sizes a terminal: the height of the tallest of them, in any tab page — among them the autocommand window `jobstart()` runs a hidden buffer's terminal in". Measure on 0.12.5; restate.
- `lua/aineo/claude/stop.lua:32`: "a process that ignores it gets a SIGTERM from Neovim 0.11.6 2 s after it, and one that ignores that too a SIGKILL 4 s after it". Measure with a plain process that ignores SIGHUP and SIGTERM (`sh -c 'trap "" HUP TERM; …'`), never Claude Code; restate. If 0.12.5's timings no longer fit inside `EXIT_AFTER_HANGUP_MS`, that is a finding.

**What stays as it is**, because it records where a measurement of Claude Code came from, and Claude Code never runs in a packet:
- `lua/aineo/claude/stop.lua:13`: "as Claude Code 2.1.281 answered them in a Neovim 0.11.6 terminal";
- `lua/aineo/claude/readiness.lua:4`: "The screens this reads are Claude Code's own, recorded in Neovim 0.11.6 terminals";
- `tests/fixtures/claude/startup-2.1.281.bytes:3`: the fixture's recording header.

These stay true as history. Do not restate them as 0.12.5's.

**D. The timing helper's LuaJIT check.** `tests/helpers/timed_attempts.lua:10–13` and its `STARTS_FOR_A_COMPILING_CHILD` loop restart a child whose LuaJIT compiles no code, "which happens to some processes of Neovim 0.11.6 that cannot allocate machine code for it". `tests/test_timed_attempts.lua:188` pins it. It was measured on 0.11.6 in about 1 child in 12.
- Measure on 0.12.5: at least 200 fresh children (`nvim --clean --headless`), each running the helper's own hot loop and its `traceinfo(1)` test. Report the count that compiled nothing.
- If none: kind 2. Remove the check, its loop, its case and its docstring lines, and leave the helper judging the second-fastest of three as T29 built it.
- If any: keep it, and restate the docstring with 0.12.5's count.

**What is not 0.11 debt, and stays:** the comments that say what Neovim 0.12 does (`lua/aineo/health.lua:12–14`, `scripts/run_tests.lua:231`, `Makefile:28` and `:65`, `tests/test_isolation.lua:125`, `tests/helpers/fake_claude.lua:121`), and `doc/aineo.txt:41–42`, which already reads "Neovim 0.12 or later". Neither is `tests/test_runner.lua:330`'s case name (T28's open thread).

If you find any other place that exists only for 0.11, clean it the same way and list it in your report. If you find one outside your boundary, it is a finding, not an edit.

### Baseline

`dev` `5db771e` has the code of `d1b9225`: `git diff --stat d1b9225 5db771e -- . ':!knowledge-vault'` prints nothing. Its tree `cd29244` was verified on 0.12.5 (`evidence/baseline-cd29244.txt`):
- `tests/test_entry_guard.lua`: 5 cases, `Fails (0)`;
- `make test`: 1455 cases, `Fails (0)`, in 197 s;
- `make lint`: clean.

T24 lands before you start, so your `origin/dev` is not `5db771e`. The dispatch message names the sha and pastes its counts from the orchestrator's verification of T24. **Your run of `make test` on that `origin/dev`, before your first edit, is your baseline.** After this packet the count changes only by the cases A, B and D remove, each named in your report.

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › D29, D10;
- `knowledge-vault/Projects/aineo.md` › *Open threads*;
- the four Learnings it links under "Neovim 0.12 differs from 0.11 where wave 6 met it". They hold what 0.12 does in the places A covers;
- `knowledge-vault/Sessions/2026-10-04 — T29 Timing cases.md`, for D.

## Boundary

- **Branch:** `refactor/t30-drop-nvim-011` from `origin/dev`, after T24's merge.
- **Class:** regular. Reviews: attack by `neovim-claude-code-reviewer`; test integrity and records together by `reviewer`.
- **Model:** `opus` — every role in this project runs on Opus.
- **Resources:** `impl_t30_drop_011`.
- **You may touch:**
  - `plugin/aineo.lua`: `ERROR_FRAMING` and its docstring, nothing else;
  - `lua/aineo/mcp/editor.lua`: `ERROR_FRAMING` and its docstring;
  - `lua/aineo/claude/init.lua`, `readiness.lua` and `stop.lua`: the docstrings under C. No code there, since C's code changes are findings;
  - `tests/test_entry.lua`, `tests/test_claude.lua` and `tests/test_mcp_delivery.lua`: the branches under A, the parametrized row under B, and their docstrings;
  - `tests/helpers/timed_attempts.lua` and `tests/test_timed_attempts.lua`, for D;
  - your session note.
- **You must not touch:**
  - every other file under `lua/` and `plugin/`;
  - `scripts/`, the `Makefile`, `doc/`;
  - `tests/fixtures/`;
  - every test file and helper not named above;
  - the task list: this rolling wave holds its marks. Write a `## Task lines` section in your session note;
  - the project note: its three *Open threads* lines on 0.11 are the knowledge pass's;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Never run the real `claude`.** The suites' fake and the `PATH` guard are the root `CLAUDE.md`'s.
- **Session note:** `knowledge-vault/Sessions/<the date you start> — T30 Drop Neovim 0.11.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). Prefix every file with `t30-`. Keep all scratch and every probe inside your worktree, never in `/tmp`. Commit the probes' record as `knowledge-vault/Implementation/Waves/00007-panes/evidence/t30-probes.txt`: each probe's code, its Neovim version and its output.
- **How you run the suite** (the root `CLAUDE.md`):
  - **D29:** on the newest Neovim release only, the host's 0.12.5. **Never 0.11.**
  - **D26:** run the test files your change touches while you work. Run the whole suite (`make test`) **once before each push**, on the tree you push.
  - **D28 does not apply:** `plugin/` and `lua/` change.
  - **TDD** binds as the `tdd` skill says. A removal of a dead branch has no red step of its own; say so for each. A removal under B or D is preceded by its measurement, recorded in `t30-probes.txt`.
- **Stop every process you start, by pid.**
- Anything the task needs outside this boundary is a **spec conflict** for your report, not a reason to widen it.

## What was decided already

- **D29's minimum is the user's**, 2026-10-05, quoted under *Objective*.
- **The orchestrator's readings**, for your note's *Readings for the MVP review*:
  - a recorded provenance (C's *What stays*) is history, not 0.11 debt;
  - a check that 0.12.5 no longer needs, but whose removal the user would see, stays until the user decides;
  - the comments that already speak of 0.12 are not 0.11 debt.

## Verification mutants

The orchestrator applies each literally against the test files that exercise the code it breaks:
- **V1 — the 0.12 framing dropped where an error is passed on.** Remove `'^Lua: '` from `plugin/aineo.lua`'s `ERROR_FRAMING`. A case in `tests/test_entry.lua` or `tests/test_claude.lua` must kill it.
- **V2 — the 0.12 framing dropped in the relay.** Remove `'^Lua: '` from `lua/aineo/mcp/editor.lua`'s `ERROR_FRAMING`. `tests/test_mcp_delivery.lua`'s framing case must kill it.
- **V3 — the exit line read as text.** In `tests/test_claude.lua`, `wait_for_exit_line()` returns `claude.wait_for_screen(child, buffer, part)` at once, as its 0.11 side did. A case that waits on the exit line must fail: on 0.12.5 the exit line is an extmark, not text.
- **V4** — only if D's check stays: `STARTS_FOR_A_COMPILING_CHILD` set to 1. `tests/test_timed_attempts.lua:188` must kill it.

## Budget

Small: about twenty places in ten files, and the probes under B, C and D. If it grows past that, stop at a green, pushed state and report a true partial.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t30-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every probe's result and every verification claim a reviewer can re-measure. The findings under C come first, each with its probe.
