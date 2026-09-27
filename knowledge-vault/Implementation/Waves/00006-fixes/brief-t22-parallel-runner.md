**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T22 | The suite runs its test files side by side (D26, C8): `make test` runs each test file in a Neovim of its own, several at once, each with a test home of its own, and gives one summary and one exit status as it does today | T1, T19 | active |

It rests on **D26** (read it whole, with the user's words), **C8** (the tooling), **D10** (mini.test, the fake `claude`) and T1's runner (`scripts/run_tests.lua`, its docstring).

**Why.** The orchestrator measured the suite (`knowledge-vault/Implementation/Waves/00006-fixes/evidence/suite-times-aaa326a.txt`):
- 36 whole-suite runs took 600–739 s each, at host loads from 16 to 209: a run waits on real processes (child Neovims, the fake `claude`'s timings); it does not compute.
- Run file by file at `aaa326a`, the 34 files took 681 s together. Seven files hold 579 s of it: `test_claude.lua` 157 s, `test_send.lua` 105 s, `test_runner.lua` 80 s, `test_entry.lua` 66 s, `test_entry_draft.lua` 66 s, `test_entry_claude_exit.lua` 58 s, `test_entry_claude_mode.lua` 47 s. No other file took more than 27 s.

Run side by side, the whole suite should take about as long as its slowest file. That is the orchestrator's estimate, not a figure you must reach: you measure and report what it is.

### The behaviours — one test each, each seen red first

- **PR1 — side by side.** `make test` runs each collected test file in a Neovim of its own, at most `AINEO_TEST_JOBS` at once. The default is yours to choose and to justify by measurement on this host (10 cores, where two or three other suites often run at once). `AINEO_TEST_JOBS=1` runs one file at a time. An `AINEO_TEST_JOBS` that names no whole number above zero is refused, as `AINEO_TEST_RUN_LIMIT_MS` is.
- **PR2 — a home of its own.** Each file's Neovim, and every process it starts, sees a test home of its own under the checkout's `.tests/`: its own `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`, `CLAUDE_CONFIG_DIR` and `NVIM_LOG_FILE`.
  - No file sees another file's state: drafts, kept Claude session ids, Reports, logs.
  - No file sees the developer's: every isolation the root `CLAUDE.md` describes for `make test` holds for each file. That covers the variables above set inside `.tests/`, every other `CLAUDE*` variable and `AINEO_CHILD` removed, `tests/helpers/entry_guard/` first on `PATH`, the values of `NVIM`, `NVIM_APPNAME`, `MYVIMRC`, `VIMINIT` and `AI_AGENT` in the caller's environment never reaching a file's Neovim (the runner's own `NVIM`, which Neovim gives every process it starts, may: the brief review measured it), and the `vim.g.aineo` preset of `scripts/minimal_init.lua`. `tests/test_isolation.lua` pins them. Make its pins true of a file's own home, and keep every refusal it asserts.
  - **Each home starts empty of earlier state.** Today the `Makefile` removes the drafts and, after T19, the kept session ids at the start of a run, because every child in the checkout's directory shares them. Say what your homes need instead.
  - **The suite runs the `Makefile`'s own recipes inside itself**, while other files run: `tests/test_runner.lua` (25 call sites), `tests/test_isolation.lua` (8 runs) and `tests/test_deps.lua` (1), all under the same `$(ROOT)/.tests` (`override TEST_HOME`). Whatever a run clears at its start reaches only its own homes, never a directory another run's files use, and a nested run's file never gets a suite file's home. A nested run inherits `AINEO_TEST_JOBS` and is bounded by `tests/helpers/make.lua`'s 10 s default (`DEFAULT_TIME_LIMIT_MS`), both yours.
  - **Each home's log directory exists before its Neovim starts, and so does the runner's own** (`$(TEST_HOME)/state/nvim`, before `make` starts the runner). On 0.12.5, though not on 0.11.6, a Neovim that cannot open its `NVIM_LOG_FILE` logs to `nvim.log` beside it and exports `__NVIM_LOG_FILE_WANT`. Every Neovim it starts inherits that variable and tells `log: "…" not accessible` through `vim.notify()`, whatever its own log file (`runtime/lua/vim/_core/log.lua`). So `__NVIM_LOG_FILE_WANT` never reaches a file's Neovim. The fake `claude` is a Neovim too, so the notice also lands in Claude's terminal. The brief review measured it at `aaa326a`, each file alone in a fresh `.tests/` on 0.12.5:
    - 73 cases in 8 files fail, among them readiness in `test_claude.lua` and 27 of `test_send.lua`'s 32;
    - `tests/test_mcp_blocked_editor.lua` hangs to the run limit.

    They are this behaviour's red cases. The same files pass with `.tests/state/nvim/` present, and on 0.11.6.
  - **Fixtures stay where they are**, in the checkout's `.tests/fixtures/`. Tests outside your boundary build those paths themselves (`tests/test_entry_startup.lua:128`, `tests/test_health.lua:1070` and `:1103`, `tests/test_report_paths.lua:23`). At `aaa326a` no fixture name passed to `fixture.directory('…')` or `claude_session.fake('…')` is used by two files. Five names repeat, each inside one file: `decoy`, `report-colours-state`, `report-links-state`, `report-paths-elsewhere` and `report-state`. Check every other way a test names a fixture, and report any name two files share, with what you did about it.
    - One route that grep misses, found by the brief review: `layout.file()` (`tests/helpers/layout.lua:235`). It writes `layout/first.txt` from six files, and `layout/second.txt` and `layout/third.txt` from three each.
    - `fixture.write()` rewrites a file in place, so a reader in another file can see it empty: measured, 205 of 182,816 concurrent reads.
    - `fixture.write()` is yours. Writing a file of the writer's own and renaming it over the target measured 0 short reads of 191,613.
- **PR3 — one summary.** The run prints what `make test` prints today, in the same lines, so every reader of a log keeps working:
  - exactly one `Total number of cases: <n>` line in the whole output, over all files;
  - one progress line per file, `tests/<file>: ooo…`;
  - each failing case on a line that begins `FAIL in ` once colour codes (`ESC[…m`) are removed, with no other escape sequence or carriage return before it;
  - exactly one `Fails (<n>) and Notes (<m>)` line, over all files.
  - No file's own summary is passed through.
  - The orchestrator's verification scripts remove only colour codes, read stdout then stderr, and keep only the first 14 lines that contain `Total number of cases`, `Fails (` or `did not finish within`, or begin with `FAIL in`.
- **PR4 — one exit status, for every reason it has today.** The run exits non-zero when any file:
  - has a case that fails or never ran;
  - does not load, or adds no case;
  - runs test code that ends Neovim, or calls `os.exit`;
  - stalls in mini.test.

  It also exits non-zero:
  - when no file was named where one was expected;
  - when the run collects no test file at all;
  - when the run outlasts its time limit;
  - when `AINEO_TEST_RUN_LIMIT_MS` names no number above zero, which is refused (`run_tests.lua:80–94`). The docstring names that one too.
  - `AINEO_TEST_RUN_LIMIT_MS` bounds the whole run, not each file. The default stays 16 minutes unless you measure a reason to change it.
  - When the run ends early, whether at the limit or on the runner's own error, every file's Neovim still running is stopped by its pid, with every process it started, never by a process-wide kill. A stopped file's cases count as not run.
  - Say how a file's Neovim that ignores SIGTERM is stopped. A Neovim stopped by SIGKILL leaves its child Neovims running: each leads a process group of its own (`tests/helpers/make.lua:44–47`).
  - The docstring states what the runner bounds and what it does not, as measured. That includes a `vim.system` process a test never stops. A runner that runs no case itself may now be able to bound a busy file.
- **PR5 — one file.** `make test_file FILE=<path>` behaves as today: one file, in one home, with the same summary and exit status.
- **PR6 — measured.** Report, on both versions, with the load (`uptime`) beside each figure:
  - the whole suite's wall clock at your default `AINEO_TEST_JOBS`, and at `AINEO_TEST_JOBS=1`;
  - the file that bounds the run.
- **PR7 — green, repeatedly.** The whole suite at your default, green **five times in a row on 0.12.5 and three on 0.11.6**. Record every run in a log headed with `nvim --version | head -1`, `uptime` and the sha.
  - A run counts as green only when its exit status is 0 **and** its `Total number of cases` equals your base's count on that version.
  - "In a row" means consecutive runs of one sha on one version. One failing run restarts that version's count.
  - A failure rate is measured over 10 runs of the whole suite at your default, and 10 of the file alone under the same load, each reported as k/10.
  - **Stop rule:** a case outside your boundary may fail at every job count above 1. Then stop at a green, pushed state at the highest job count that met PR7, or report PR7 unmet with each case's rate. The orchestrator decides.
  - A case that fails under side-by-side load but not alone is a finding. Report it with its file, its measured failure rate and its cause.
  - You change it only when the cause is the harness's shared state, which is yours. A case's own timing is not: a flaky case outside your boundary is reported, and the orchestrator decides.
  - Lowering the default job count is a legitimate answer. Say what it costs.

### Facts, checked against `origin/dev` (`aaa326a`)

- **`Makefile`:**
  - `override TEST_HOME := $(ROOT)/.tests`;
  - `test test_file:` override `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`, `CLAUDE_CONFIG_DIR` and `NVIM_LOG_FILE` under it;
  - `unexport NVIM NVIM_APPNAME MYVIMRC VIMINIT AI_AGENT`;
  - `test: deps` and `test_file: deps` both remove `$(TEST_DRAFTS)`; `test` runs `$(NVIM_TEST) -l '$(ROOT)/scripts/run_tests.lua'`;
  - `test_file` passes `FILE` through the environment (`AINEO_TEST_FILE`).
  - T19 (PR #73) adds the kept session ids' folder to that clean-up. You start from `dev` after T19 merges.
- **`scripts/run_tests.lua`** (225 lines):
  - it decides the exit status itself;
  - it takes Neovim's functions it ends and times the run with before any test file is sourced (`neovim = { … }`, lines 29–37);
  - `STALL_LIMIT_MS` is 10 s (line 48), and `RUN_TIME_LIMIT_MS` is 16 min (line 59), with `AINEO_TEST_RUN_LIMIT_MS` replacing it;
  - `test_files()` is at line 121, and `MiniTest.collect` at line 193;
  - it runs `MiniTest.execute(cases, { reporter = MiniTest.gen_reporter.stdout({ quit_on_finish = false }) })` at line 215.
  - Read its docstring (lines 1–21) whole: every ending it names is a behaviour PR4 keeps.
- **`tests/test_runner.lua`:** 36 `T[…]` lines (4 groups, 7 parametrised sets, 25 case functions), 41 cases in its run, 80 s. **`tests/test_isolation.lua`:**
  - `TEST_HOME` is `<cwd>/.tests` (line 8);
  - line 49 pins `stdpath('state')` to `HOME .. '/state/nvim'`;
  - `DECOY_TEST_HOME` is at line 86, the routes table at lines 88–92, and the parametrised case at lines 208–217.
- **`tests/helpers/fixture.lua:9`:** `FIXTURES = <checkout>/.tests/fixtures`. **`tests/helpers/make.lua:14`:** `EMPTY_DIRECTORY = <checkout>/.tests/empty`.
- **Sentences your change makes false,** known today; your report names each, and any more you find:
  - the root `CLAUDE.md`'s make table (the isolation, the run limit) and, after PR #74, its D26 bullet ("a whole run takes 10–12 minutes");
  - `.claude/agents/neovim-lua-developer.md:35` and `.claude/agents/neovim-claude-code-integrator.md:61`, which say the `Makefile` sets the variables under the checkout's `.tests/`;
  - after PR #74, `.claude/agents/implementer.md`'s "10–12 minutes";
  - `scripts/minimal_init.lua:10–11` and `tests/helpers/child.lua:4–6`.

  The orchestrator corrects the `ai/` ones after the merge. The two outside your boundary are spec conflicts for your report.

### Baseline

You start from `dev` once T19 (PR #73) merges. The orchestrator's verification of PR #73 measures that tree's cases on both versions. The dispatch message names the tree and pastes its counts. Measure the sequential wall clock yourself, at your base, before your first edit, on both versions (PR6).

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › D26, D10, C8;
- `knowledge-vault/Sessions/` › the T1 session note, for how the runner came to decide the exit status;
- the evidence file above;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t22-parallel-runner` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t22_parallel_runner`.
- **You may touch:**
  - `scripts/run_tests.lua`, and new files under `scripts/` for the runner;
  - the `Makefile`'s `test` and `test_file` targets, the variables they read, and their comments — not `deps`, `lint` or `format`;
  - `tests/test_runner.lua`, `tests/test_isolation.lua`, and new `tests/test_runner_*.lua` files;
  - `tests/helpers/make.lua` and `tests/helpers/fixture.lua`;
  - your session note.
  - The documentation this change invalidates: the runner's docstring, and the `Makefile`'s comments. Everything else is reported, not edited (above).
- **You must not touch:**
  - `lua/`, `plugin/`, `doc/`;
  - every test file and helper not named above. T12 runs beside you on `plugin/aineo.lua`, the layout, `lua/aineo/health.lua`, `tests/test_health.lua`, `tests/test_plugin.lua`, `tests/test_entry.lua`, `tests/test_entry_prefix.lua`, `tests/helpers/entry.lua`, `tests/test_layout*.lua` and the help;
  - `scripts/minimal_init.lua`, unless PR2 cannot hold without it. Then it is a spec conflict for your report, not an edit;
  - the task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note;
  - the project note;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Never run the real `claude`,** and never read or write `~/.claude/` or the developer's Neovim directories.
- **Session note:** `knowledge-vault/Sessions/<the day you are dispatched> — T22 parallel runner.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). If the harness refuses to create it, use your worktree's `.tests/` and say so. Prefix every file with `t22-`. Keep all scratch inside your worktree, never in `/tmp`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. Read and run its Neovim builds; write nothing there. For 0.11.6: `env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test`.
- **How you run the suite** (D26; the root `CLAUDE.md` and `implementer.md` once PR #74 merges, which it does before you are dispatched): run the test files your change touches while you work. The whole suite runs before each push, and PR6 and PR7 are measurements of it.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- **The user's decision, 2026-09-27, as D26 records it.** Asked "How should I cut the time the tests cost?", the user chose "Run less + parallel runner (Recommended)". This packet is its second half. Its first half is the agents' rule change: PR #74, `ai/run-less-tests`.
- **Not in scope.** The option not chosen, "All, plus faster fake Claude":
  - shortening the fake `claude`'s real-time delays;
  - rewriting the tests that wait out a full patience to prove that nothing happened.
  Splitting a slow test file is out too: every test file outside your boundary stays as it is.

## Budget

Medium: a runner that runs files side by side, a home per file, one summary and one exit status, and the measurements. If it grows past that, stop at a green, pushed state and report a true partial.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t22-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
