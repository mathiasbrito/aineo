# 2026-09-23 — T1 tooling foundation

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t1-tooling` · **Pull request:** #4 (one packet round, one fix round, one correction)

## Links

- **Project:** [[Projects/aineo]]
- **Plan:** [[Planning/aineo — v1 agent console]] — T1, C1, C8, D10, D12, D13
- **Wave:** [[Implementation/Waves/00001-tooling/plan]] · the brief `Implementation/Waves/00001-tooling/brief-t1-tooling.md` · its review `brief-review.md`
- **The fix round's findings:** the attack, test-integrity and records reviews of PR #4, cited here by their IDs (attack A#, test-integrity I#, records R#, cross-dimension X#). The orchestrator's fix-round decisions are cited as FR-D1 to FR-D10.
- **The correction's findings:** the re-measure of PR #4 at the fix round's head, cited as RM1–RM12 in its own numbering, and the orchestrator's correction brief, whose items carry the same numbers.

## Context

**Goal:** T1 lays the tooling every later packet stands on: the mini.test harness and its make targets, the suites' isolation from the developer's editor and Claude state, the `plugin/aineo.lua` and `lua/aineo/init.lua` skeletons, and `lua/aineo/config/` with `vim.g.aineo` validation.

## What was done

**Make targets.**

- `deps` (B1): mini.nvim pinned by commit `1345d19`, which is tag v0.18.0.
- `test` (B2): every `tests/**/test_*.lua` under the working directory.
- `test_file FILE=<path>` (B3): one file.
- `lint` (B5): `stylua --check`, then `selene`.
- `format` (B6): StyLua in place.

**Files.**

- `scripts/minimal_init.lua`: the init for the runner and for every child Neovim.
- `scripts/run_tests.lua`: the runner, under `nvim -l`. It decides the exit status itself.
- `plugin/aineo.lua`: a guard and nothing else (B7).
- `lua/aineo/init.lua`: `setup()` alone (B8).
- `lua/aineo/config/init.lua`: `resolve_config()`, plus the options `setup()` records (B9).
- `.stylua.toml`, `selene.toml`, `neovim.yml`.
- Six test files and four helpers.

**Result.**

- **After the packet round:** 59 cases.
- **After the fix round:** 81 cases, all passing. `make lint` is clean, and the hooks suite reports 78 passed.
- **After the correction:** 111 cases, all passing, in 87, 88 and 87 s. `make lint` is clean, and the hooks suite reports 78 passed.

## Why it is shaped this way

**The runner exits instead of hanging (B2, B3).** With mini.nvim v0.18.0, the invocation TESTING.md proposes never exits in four cases:

- a test file that fails to parse;
- a top-level `require` of a missing module;
- zero cases;
- `run_file` on a missing path.

Each was reproduced under a 10 s watchdog: exit status 142, killed by the watchdog. Under `nvim -l`, any Lua error ends Neovim with exit 1, and shada is off.

**The runner owns the exit status (fix round: A1, A2, A6; FR-D1).** A run exits 0 only when every case ran and passed. mini.test's reporter no longer quits. The reviews found five ways a run ended green while a case failed:

- a case that runs `quit`, `qall!` or `0cquit`;
- a case that calls `MiniTest.stop()` or `os.exit(0)`;
- a file that contributes no case;
- an edited `deps/`;
- a mini.test in a system site directory.

Each is now a test seen red first. `os.exit` is replaced for the runner's life, and `VimLeavePre` catches the rest.

**A stall check replaces the time limit.** A `MiniTest.finally` that raises stops mini.test's queue. The run then held for 30 minutes before it exited 1. Under the attack reviewer's MU-limit mutant, which deleted the time-limit branch and set the limit to 2 s, it ended green. Now it fails after 10 s idle, saying so. The design is the attack reviewer's measured runner, adopted red-first.

- **Why the wait still matters.** `nvim -l` runs callbacks scheduled before the script returns (the test-integrity reviewer's measurement, I2). What makes the wait load-bearing now is that the runner checks every case after it.
- **What the stall check cannot see.** Neither a case that blocks Neovim itself nor a slow case in its own `vim.wait` is observable to it. mini.test's steps run back to back within one pass of Neovim's event processing (measured, below). The correction bounds the waiting kind with a run time limit (RM2, below).

**Every exit path inside the runner stops its child Neovims (FR-D1).**

- A stalled runner ends through `cquit`, and Neovim stops its jobs on the way out. So does every other ending the runner decides, the correction's time limit included.
- The suite's `make` helper stops the whole process tree at its own time limit. Each child Neovim leads a process group of its own, so stopping `make`'s group left one orphan at 100 % CPU. The attack reviewer measured it, and this round's red reproduced it.
- **This is not true of every way a run can be stopped.** A SIGKILL from outside skips Neovim's exit, and its child Neovims outlive it: the re-measure found two alive after a SIGKILL of make's process group (RM2). A process a test starts with `vim.system` is not a job, and outlives any run.

**Isolation (B4; fix round: A3, A4, X3, X4; FR-D2).** The Makefile sets `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`, `CLAUDE_CONFIG_DIR` and `NVIM_LOG_FILE` into `.tests/`. It does so as target-specific overrides on `test test_file`, with a global `export`. So even `make test XDG_STATE_HOME=…` on the command line cannot move the suite.

- **Make 3.81 cannot put `override` and `export` on one target-specific line** (measured).
- **Why the Makefile, and not the minimal init:** `'runtimepath'` and Neovim's log location are fixed before an init runs.
- **The minimal init removes every `CLAUDE*` variable except `CLAUDE_CONFIG_DIR`.** make cannot unset by pattern. This session's own Claude Code variables (`CLAUDE_CODE_CHILD_SESSION` and more) reached the runner and a child before the fix.
- **The pinned mini.nvim is prepended** to `'runtimepath'`, ahead of every system site directory.

Measured first, with `-i NONE`: the plain TESTING.md invocation resolves every stdpath under the developer's home, and puts `~/.config/nvim` and its `after/` on `'runtimepath'`. The developer's shada and log kept the same mtime and size through every run of this session, both rounds.

**The harness tests run make from an empty directory under `.tests/`.**

- A runner that ignored `FILE` would collect nothing there, rather than start the suite inside itself.
- A run past the helper's limit is stopped with its whole process tree. `vim.system():wait(timeout)` kills only `make`, and an orphan keeps the pipes open, so `wait` returns `nil`.
- Every git the suites start runs without the developer's git configuration.
- Every `make` a test starts has the outer make's `MAKEFLAGS`, `MFLAGS`, `MAKELEVEL` and `FILE` emptied. Otherwise `make test_file FILE=…` leaks its `FILE` into the nested runs (X1).
- `FILE` reaches the runner through the environment, never pasted into shell text (A9).

**`aineo.config` (B9).**

- **It reads no editor state.** It is handed `vim.g.aineo` and the `setup()` options (`modularity` §4).
- **Resolution is per setting:** setup first, then `vim.g.aineo`, then the default, with `false` counting as given.
- **Rejected: `vim.tbl_deep_extend`.** An empty list overrides the default.
- **Every value either source gives is checked,** with an error naming its full path. A wrong `vim.g.aineo` value is refused even when `setup()` masks it (FR-D7).
- **Unknown keys are returned, sorted, each once,** a flattened `['layout.report_height']` included (A7).
- **It keeps what `setup()` records,** and hands out copies only (FR-D5).

## Decisions & reasoning

- **B1, C8 — the pin is a commit, not a tag,** so the tag cannot move under the suite. `make deps` checks the commit checked out, asking only that directory's own `.git`. A match reaches no remote, and a changed pin fetches it. A checkout whose files differ from the commit is refused (A5).
- **D12 — StyLua `syntax = "Lua51"`,** so `goto` and other 5.2+ syntax fail `make lint`. Measured: `LuaJIT` syntax accepts `goto`. selene's standard is `lua51` plus:
  - `vim`;
  - the read-only `jit` global with `jit.os`, `jit.arch`, `jit.version` and `jit.version_num`, for `neovim-lua-developer.md`'s `if jit then` guard;
  - `vim.loop` marked deprecated.

  Measured on planted lines (X2, FR-D8): `if jit then … jit.os` admitted, `jit = nil` refused, `vim.loop.now()` refused.
- **B9, FR-D7 — "checks every value" is decided.** Every value either source gives is validated, so a wrong `vim.g.aineo` value is refused even when `setup()` masks it. The brief left it open, and `neovim-lua-developer.md` asks only that the merged configuration be validated. The orchestrator decided in the fix round (R6) to keep this stricter reading, which also satisfies the specialist's line.
- **C1, B8, FR-D5 — `require('aineo')` exposes `setup()` alone.** The packet round had added `require('aineo').setup_options()` so a composition root could read what `setup()` recorded. Its only client was the test suite (R1, A8; `modularity` §2 and §7), and C1 names no second export. The record now lives in the configuration home:
  - `aineo.setup()` calls `require('aineo.config').record_setup_options()`;
  - `recorded_setup_options()` hands out a copy.

  Its production reader is T7's composition root. Today only tests read it.
- **B4, FR-D4 — the Makefile header no longer claims `make -f <checkout>/Makefile` works from anywhere** (R3, A10). It says `deps`, `lint` and `format` take their paths from the checkout, and `test` and `test_file` from the working directory. A checkout path with a space is not supported.
- **Dropped unit, "a list replaces whole".** Nothing realistic fails it: per-setting resolution replaces a list whole, and so does `vim.tbl_deep_extend` for a non-empty list (measured).

## Red, green and mutants

**Packet round.**

- **Seen red:** 25 tests, 44 cases.
- **Arrived green:** 12 tests, 15 cases.
- **Account:** in the packet report, `t1-report-packet.md`.

**Fix round.**

- **Seen red:** 19 test functions, 23 cases, after three invalid reds, each a harness defect fixed first. The pull request's Pin column lists 15 rows: rows 1–3 are one parametrized test of 5 cases, and its API row holds 7 tests.
  - `vim.system():wait()` returning `nil`;
  - a multi-line probe written with a NUL byte;
  - a `nil` hole in a parametrize list, in the packet round.
- **Arrived green:** 7 test functions, 7 cases, each with a named killer:
  - a stalled run leaves no child Neovim: spent by the stall check and Neovim's job teardown;
  - a slow case is not a stall: green by nature, see below;
  - I1, I3, I4, I5 and I6, adopted from the test-integrity reviewer.

**Mutant table.** Literal edits, one at a time, each file restored byte for byte, all on the fix round's code commit. The correction changed the runner, the Makefile and the configuration home after it; its own table, measured on its final head, is in *Correction*. The packet round's table was measured on its configuration commit, and this table replaces it wherever the code changed.

| Mutant | Literal edit | Killed by (kind) |
|---|---|---|
| **M1** | Makefile: delete `test test_file: override XDG_STATE_HOME := $(TEST_HOME)/state` | runner and child `stdpath { "state" }`; the four `make test_file` isolation probes (assertion) |
| MU6/MU7/MU8/MU9 | delete the `XDG_CONFIG_HOME` / `XDG_DATA_HOME` / `XDG_CACHE_HOME` / `CLAUDE_CONFIG_DIR` override line | their runner and child tests; the four probes (assertion) |
| log line | delete the `NVIM_LOG_FILE` override line | the log probe; the command-line probe (assertion) |
| no override | `test test_file: override XDG_STATE_HOME :=` → `test test_file: XDG_STATE_HOME :=` | the command-line probe (assertion) |
| R11 (equivalent) | the six `test test_file: override` lines → `test: override` | three `make test_file` probes (assertion) |
| deps status | delete the `git … status --porcelain` block | refuses a checkout whose files differ (assertion) |
| MU17 | deps condition → `@if true; then` | reaches for no remote (assertion) |
| MU18 | deps condition → `@if [ ! -d '$(MINI_NVIM_DIR)/.git' ]; then` | moves to a changed pin (assertion) |
| FILE in shell | `"$$AINEO_TEST_FILE"` → `'$(FILE)'` | takes FILE as a path (assertion) |
| MU1 | recipe drops `"$$AINEO_TEST_FILE"` | 11 fails, 9 of them assertions (exits zero on a passing file; no file named; the probes). The two child-pid tests crash on an empty pid file. |
| MU3 | `test_file` recipe → stock `-c "lua require('mini.test').run_file('$(FILE)')"` | the 5 hang tests (`Left: 124`), the 5 early-ending cases, the stall test (assertion) |
| MU5 | `test` recipe → stock `-c "lua require('mini.test').run()"` | collects no test file; a caseless file (assertion) |
| Claude kept | delete the `CLAUDE*` removal loop in the minimal init | the four probes (assertion) |
| pin appended | minimal init back to `prepend(checkout)` then `append(mini)` | runs the pinned mini.test over a system copy (assertion) |
| reporter quits | `MiniTest.execute(cases, { reporter = … quit_on_finish = false … })` → `MiniTest.execute(cases)` | 7 tests (assertion) |
| no every-case check | delete `if not every_case_passed(cases) then vim.cmd('cquit 1') end` | fails when a case fails; `stop()` (assertion). The outer `make test` also exits 0 under this mutant: read the `Fails (n)` line, not the status (I7). |
| no leave guard | delete the `VimLeavePre` autocommand | `quit`, `qall!`, `0cquit` (assertion) |
| os.exit kept | delete the `os.exit` replacement | `os.exit(0)` (assertion) |
| no stall branch (R16's equivalent: the edit deletes the wait with its branch) | delete `if not wait_for_execution() then fail_run(…) end` | 11 tests (assertion) |
| MUlimit's equivalent (the re-measure's edit: the wait stays, its verdict goes) | `if not wait_for_execution() then fail_run(…) end` → `wait_for_execution()` | the stall test's message (assertion), measured by the re-measure on the fix round's head; re-run in *Correction* |
| stall exit bypasses teardown | stall `fail_run(…)` → `vim.uv.kill(vim.uv.os_getpid(), 'sigkill')` | the stall test; leaves no child Neovim when the run stalls (assertion) |
| no caseless check | delete the `caseless_files` refusal | fails when one test file contributes no case (assertion) |
| MU4 | delete `if #cases == 0 then … end` | collects no test file (assertion) |
| empty FILE accepted | delete the `named_file == ''` refusal | no file is named (assertion) |
| helper, direct children only | `vim.list_extend(tree, process_tree(child))` → `table.insert(tree, child)` | a run stopped at its time limit leaves no child Neovim (assertion) |
| helper, outer make kept | delete `OUTER_MAKE_CLEARED,` from the helper's environment, run as `make test_file FILE=tests/test_runner.lua` | no file is named (assertion) |
| **M2** (appended, and before the guard) | add `require('aineo')` | loads no aineo module (assertion); before the guard, also the disabled test |
| MU11 | delete the guard | does nothing when already set (assertion) |
| MU10 | child helper adds `--cmd 'set runtimepath^=<home>/.config/nvim/aineo-mutant-probe'` | a child has no developer config on 'runtimepath' (assertion) |
| setup accumulates | `recorded_setup_options = vim.deepcopy(setup_options)` → `vim.tbl_deep_extend('force', recorded_setup_options, vim.deepcopy(setup_options))` | replaces without merging; records empty options (assertion) |
| snapshot dropped | `… = vim.deepcopy(setup_options)` → `… = setup_options` | records the options as they were (assertion) |
| record handed out live | `return vim.deepcopy(recorded_setup_options)` → `return recorded_setup_options` | keeps its record when a caller edits the copy (assertion) |
| setup_options export | add `M.setup_options = config.recorded_setup_options` to `lua/aineo/init.lua` | exposes setup() alone (assertion) |
| **M3** | `return type(value) == 'number' and value > 0 and value < 1` → `return type(value) == 'number'` | report height 0, 1, 1.5, −0.25 (assertion) |
| M3 zero / M3 one | `value > 0` → `value >= 0` / `value < 1` → `value <= 1` | height 0 / height 1 (assertion) |
| MU14 | `{ setup_options or {}, global_settings or {} }` → `{ setup_options or global_settings or {} }` | merges setting by setting; unknown keys once (assertion) |
| dotted key known | `elseif not IS_TOP_LEVEL_SETTING[key] then` → `elseif not IS_SETTING[key] then` | returns a dotted top-level key as unknown (assertion) |
| R10 (reviewer's literal) | `return not MiniTest.is_executing()` → `return true` | the stall test's message (assertion) |
| R2 (reviewer's literal) | copy the resolved value only when it is the default | shares no table with the sources (assertion) |
| R7 (reviewer's literal) | add a `UIEnter` autocommand requiring `aineo` | defines no autocommand, command or mapping (assertion) |
| R18 (reviewer's literal) | require `aineo` inside the guard's early return | does nothing when already set (assertion) |
| R1 (reviewer's literal) | delete `table.sort(unknown)` | lists each unknown key once, in sorted order: 6 of 6 runs (assertion) |
| R15 (reviewer's literal) | `test: deps` → `test:` | **survived** — a fresh checkout fails loudly without mini.nvim; not pinned, as the reviewer also judged. The re-measure refuted this as a limit (RM4): R15 also skips A5's refusal of an edited `deps/`. The correction adopted its pin, which kills R15 (see *Correction*). |
| R20 (reviewer's literal) | add `vim.defer_fn(function() require('aineo') end, 200)` to the plugin file | **survived** — a timing bound no startup snapshot closes; recorded, as the reviewer did |
| MUlimit, R16, R11 (reviewers' literals) | the old time-limit branch, the old wait block, the old `export` lines | **not applied**: their text is gone. Their equivalents are the rows above. |
| helper, group kill (mine, malformed) | stop only `make`'s process group, without the `detach` that made `make` a group leader | **hung** the suite until the mutant script's 600 s watchdog. Replaced by "direct children only". |
| stall clock never resets | delete the `watched_case` reset in `wait_for_execution` | **survived** on the slow fixture (exit 0): the stall check never runs while mini.test's steps run back to back, so this edit is equivalent on that input |
| stall timer watchdog | the stall check driven by a libuv timer instead of the wait's check | measured on the slow-case pin's input run directly: exit 2 ("stalled") where the pristine runner exits 0. The pin asserts 0. |

**Tally.**

- **The round's own mutants:** 44 run. 41 killed by a suite test by assertion. The timer watchdog was killed on the pin's input. One is equivalent on its input, and one malformed edit hung.
- **The reviewers' surviving edits:** 10 re-run. 5 killed by assertion, R1 in 6 of 6 runs. 2 survived, as limits. 3 were not applied.

## Correction, after the re-measure

**Why.** The re-measure of PR #4 at the fix round's head found that the runner could still end a failing run with exit 0. It also found that nothing bounded a run whose case waits in a nested loop, and five smaller holes; it held its other three findings. The orchestrator dispatched one bounded correction (orchestrate §6), with a decision on each finding. A fresh implementer agent (`neovim-lua-developer`) did the work, because the fix round's agent had stopped.

**Commits.** Three commits of code and tests, then this note's records commit, all on top of the fix round's head; pushed history was not rewritten. Their hashes are recorded after the merge.

1. The correction itself.
2. A pin that a stalled or timed-out run blames no test case.
3. One plain copy in `aineo.config` instead of two.

**What changed, by finding.**

- **RM1: the runner's verdict.**
  - The `VimLeavePre` guard reads the runner's own `verdict_reached` flag, never mini.test's `is_executing()`. That flag goes false in mini.test's last queue step, before the runner decides. A last case that quit three or four `vim.schedule` hops later ended a failing run with 0.
  - The flag is set when `fail_run` runs, when the time limit fires, and just before the final check.
  - Every Neovim function the runner calls once a test file is sourced is taken before the first one is. They are `nvim_command`, `nvim_echo`, `nvim_create_autocmd`, `vim.wait`, `vim.uv.now`, `vim.uv.kill` and `vim.uv.fs_write`.
  - `every_case_passed` and `files_without_cases` use plain loops, so the rule holds without `vim.iter` or `vim.tbl_filter`.
  - The mechanism is the re-measure's measured `run_tests.fixed.lua`. It is extended to the guard's own `nvim_create_autocmd` and `vim.wait`, each with a pin, and to the two helpers.
- **RM2: a bound on the whole run.**
  - A libuv timer starts before the first test file is sourced. It fires inside a nested `vim.wait`, a `vim.system():wait()`, a request to a child Neovim, and a test file's top level.
  - When it fires, it writes "the test run did not finish within N s", marks the verdict reached, and sends the runner SIGTERM. Neovim's own exit then stops the child Neovims.
  - **Default: 16 minutes.** The full suite took 87, 88 and 87 s on the final head. Ten times the slowest is 880 s, and rounded up to whole minutes that is 15. The extra minute covers a 90 s run seen mid-correction.
  - `AINEO_TEST_RUN_LIMIT_MS` replaces the default. It is refused unless it names a number of milliseconds above zero.
  - Adopted from the re-measure's `run_tests.fixed_clock.lua`.
- **RM3.** `make deps` checks git's exit status as well as its output, so a checkout git cannot read is refused. The re-measure's `Makefile.depsfix`, adopted.
- **RM4.** The re-measure's R15 pin, adopted: `make test` refuses an edited dependency checkout, so R15 is no longer a recorded limit.
- **RM6.** `override TEST_HOME := $(ROOT)/.tests`, the re-measure's measured fix.
- **RM7.** `setup()` records a plain copy: keys and values at every depth, no metatable. `recorded_setup_options()` hands out a copy of that plain record.
- **RM8.** `unexport NVIM NVIM_APPNAME MYVIMRC VIMINIT AI_AGENT` in the Makefile.
- **RM9.** The records above, corrected:
  - the fix round's reds are counted by test function and by case (19 functions, 23 cases);
  - the 30-minute stall names the mutant under which it ended green;
  - the "no stall branch" row names R16 as its equivalent, beside a row for MUlimit's own.

**Decisions.**

- **The orchestrator's, from the correction brief:**
  - items 1–4 and 6–8 as above;
  - RM2's three holes and RM5 are recorded as limits, not fixed (see *Open threads*);
  - `VIMRUNTIME` stays.
- **Mine:**
  - **A plain copy, over refusing a table with a metatable in `setup()`.** A refusal would also refuse `vim.empty_dict()`, and what `vim.json.decode()` returns. A plain copy records what `vim.g.aineo` could hold; `vim.empty_dict()` is recorded as `{}` (measured).
  - **Cost of the plain copy:** a table that contains itself now raises a stack overflow, where `vim.deepcopy` accepted it (measured). The docstrings say so.
  - **A global `unexport`.** Make 3.81 refuses a target-specific one (measured: "No rule to make target `unexport'"). No other target reads the five names. `unexport` held against the environment, the command line, `MAKEFLAGS` and `make -e` (measured on a probe Makefile).
  - **The variable replaces the default; it does not only lower it.** No test can tell `math.min` from a replacement without outlasting the default.
  - **The timer sends SIGTERM from its own callback.** A kill scheduled with `vim.schedule` never runs while a case waits on a child Neovim or on `vim.system():wait()`; the "scheduled kill" mutant measures it.
  - **The timer marks the verdict reached, and so does `fail_run`.** Without the flag, the guard fires during the timer's exit and adds a false reason: "a test case ended Neovim before the run finished". Commit 2 pins this: the stall test and the run-limit test expect no such line.
  - **`fail_run`'s flag is equivalent on the stall and `os.exit` paths.** Without it, both paths still print one reason and exit 1; the only difference is a trailing newline (measured). The line stays, so `fail_run` never runs again inside its own `cquit`.
  - **One plain copy, not two** (commit 3). With a plain copy on both sides, reverting either one survived.

**Units, in the order they were written.** 16 test functions, 30 cases: 11 functions (23 cases) seen red, 5 functions (7 cases) arrived green. The suite went from 81 cases to 111.

| # | Test (file) | Cases | Red, or why it arrived green | Killer, run on the final head |
|---|---|---|---|---|
| 1 | fails when the last case ends Neovim from a callback it scheduled (runner) | 6 | red: 6 × `Left: 0 Right: 2` | guard back to `MiniTest.is_executing()` |
| 2 | fails when a case leaves a stub on a function the runner ends it with (runner) | 2 | red: 2 × `Left: 0 Right: 2` | final `vim.cmd`; `fail_run`'s `vim.api.nvim_echo` |
| 3 | fails, saying so, when mini.test stops after a case froze vim.uv.now (runner) | 1 | red: `Left: 124 Right: 2` | stall clock on `vim.uv.now` |
| 4 | fails when a file stubs nvim_create_autocmd and a case ends Neovim (runner) | 1 | red: `Left: 0 Right: 2` | guard created with `vim.api.nvim_create_autocmd` |
| 5 | exits zero when a passing file stubs vim.wait (runner) | 1 | red: `Left: 2 Right: 0` | wait on `vim.wait` |
| 6 | the run time limit ends a run, saying so, while a case waits (runner) | 4 | red: 4 × `Left: 124 Right: 2` | no run limit; `vim.uv.kill`; `vim.uv.fs_write`; timer without the flag |
| 7 | … ends a run, saying so, while a case waits on a child (runner) | 2 | green: spent by unit 6's timer | no run limit; scheduled kill (busy child) |
| 8 | … leaves no child Neovim running when it ends a run (runner) | 2 | green: spent by unit 6's SIGTERM | `'sigterm'` → `'sigkill'` |
| 9 | … ends a run, saying so, while a test file is sourced (runner) | 1 | green: spent by unit 6, which starts the timer before collection | the timer started after collection |
| 10 | … is refused unless it is a number of milliseconds above zero (runner) | 2 | red: 2 × `Left: 0 Right: 2` | zero accepted; no check |
| 11 | make deps refuses a checkout its git cannot read (deps) | 2 | red: 2 × `Left: 0 Right: 2` | the check on output only |
| 12 | make test refuses a dependency checkout whose files differ from the pin (deps) | 1 | green: the behaviour exists (RM4) | R15 |
| 13 | keeps its isolation when TEST_HOME is named outside the Makefile (isolation) | 2 | red: 2 × `Left: 2 Right: 0` | no `override` |
| 14 | records the options' own keys, never what their metatable reaches (aineo) | 1 | red: `Left: "changed after setup()" Right: vim.NIL` | record by `vim.deepcopy` |
| 15 | hands out its record without a metatable (aineo) | 1 | green: spent by unit 14's plain record | record by `vim.deepcopy` |
| 16 | keeps a parent editor's variables out of its runner and children (isolation) | 1 | red: `Left: 2 Right: 0`; run directly, the probe listed all five planted values in the runner | no `unexport`; each name kept |

**Seen red on the fix round's head.** The final tests were run against the fix round's head's four production files (Makefile, runner, configuration home, API): 111 cases, 27 fails, every one a new case. The 23 seen red failed there, and so did units 7 (2), 9 and 15. The other three new cases pass there. Unit 8 passes because the helper stops the whole tree at its own limit; unit 12 because the deps check already existed.

**The stall and run-limit tests were tightened (commit 2).** Each now also expects no "a test case ended Neovim" line. On the fix round's head the stall test still passes, because the head's second reason never reaches stderr on the stall path (measured above). The run-limit test fails there anyway, since that head has no limit.

**Mutant table.** Literal edits, one at a time, each file restored byte for byte, run by `make test_file` on the test file named, or by `make test` for M1. Kinds are read from mini.test's output.

- **Where each was measured:** M1, M2, M3 and the four configuration rows on the final head, commit 3. The rest on commit 2, whose files differ from commit 3 only in the configuration home, which none of them edits or runs.
- **The full literal edits** are in the correction report (`t1c_mut.py` in the scratchpad).

| Mutant | Literal edit | Result (kind) |
|---|---|---|
| guard asks mini.test | `if not verdict_reached then` → `if MiniTest.is_executing() then` | killed, 10: the 6 scheduled quits, and the 4 run-limit waits by "a test case ended Neovim" (assertion) |
| final check on `vim.cmd` | final `neovim.command('cquit 1')` → `vim.cmd('cquit 1')` | killed, 1: the `vim.cmd` stub (assertion) |
| `fail_run` on `vim.api.nvim_echo` | `neovim.echo(` → `vim.api.nvim_echo(` | killed, 1: the `nvim_echo` stub (assertion) |
| stall clock on `vim.uv.now` | the three `neovim.now()` → `vim.uv.now()` | killed, 1: the frozen clock, `Left: 124` (assertion) |
| guard on `vim.api.nvim_create_autocmd` | `neovim.create_autocmd('VimLeavePre'` → `vim.api.nvim_create_autocmd('VimLeavePre'` | killed, 1 (assertion) |
| wait on `vim.wait` | `neovim.wait(NO_TIME_LIMIT_MS` → `vim.wait(NO_TIME_LIMIT_MS` | killed, 1: the `vim.wait` stub, `Left: 2` (assertion) |
| no final flag | delete `verdict_reached = true` before the final check | killed, 3: every passing run exits 1 (assertion) |
| `fail_run` without the flag | delete `verdict_reached = true` in `fail_run` | **survived**: equivalent on the stall and `os.exit` paths (measured above) |
| no run limit | delete `limit_run_time(run_time_limit_ms(…))` | killed, 9: units 6, 7, 9, 10 (assertion) |
| SIGKILL | `'sigterm'` → `'sigkill'` in the timer | killed, 2: unit 8, `Left: false`; four orphaned Neovims stopped by pid (assertion) |
| scheduled kill | `neovim.kill(…)` → `vim.schedule(function() neovim.kill(…) end)` | killed, 2: the `vim.system` wait and the busy child, `Left: 124` (assertion) |
| kill on `vim.uv.kill` | `neovim.kill(` → `vim.uv.kill(` | killed, 1: the `vim.uv.kill` stub (assertion) |
| write on `vim.uv.fs_write` | `neovim.write(STDERR,` → `vim.uv.fs_write(STDERR,` | killed, 1: the `fs_write` stub, `Fragment: did not finish within 3 s` (assertion) |
| limit after collection | move `limit_run_time(…)` after collection | killed, 1: unit 9 (assertion) |
| zero accepted | `if limit_ms == nil or limit_ms <= 0 then` → `if limit_ms == nil then` | killed, 1 (assertion) |
| no limit check | the same line → `if false then` | killed, 2 (assertion) |
| timer without the flag | delete `verdict_reached = true` in the timer | killed, 4: "a test case ended Neovim" (assertion) |
| default below the slow pin | `16 * 60 * 1000` → `11 * 1000` | killed on the slow pin's input, run directly: exit 2, "did not finish within 11 s", against the pristine 0 in 12 s |
| deps on output only | the new status block → the fix round's `@if [ -n "$$(git … status --porcelain)" ]; then … fi` | killed, 2 (assertion) |
| R15 | `test: deps` → `test:` | killed, 1: unit 12 (assertion) |
| no `override` | `override TEST_HOME :=` → `TEST_HOME :=` | killed, 2 (assertion) |
| record by `vim.deepcopy` | `plain_copy(setup_options)` → `vim.deepcopy(setup_options)` | killed, 2: units 14 and 15 (assertion) |
| record handed out live | `return vim.deepcopy(recorded_setup_options)` → `return recorded_setup_options` | killed, 1 (assertion) |
| snapshot dropped | `plain_copy(setup_options)` → `setup_options` | killed, 3 (assertion) |
| setup accumulates | `plain_copy(setup_options)` → `vim.tbl_deep_extend('force', recorded_setup_options, plain_copy(setup_options))` | killed, 2 (assertion) |
| no `unexport` | delete the `unexport` line | killed, 1: unit 16 (assertion) |
| each name kept | drop `NVIM`, `NVIM_APPNAME`, `MYVIMRC`, `VIMINIT` or `AI_AGENT` from the line, one at a time | 5 mutants, each killed, 1: unit 16 (assertion) |
| **M1** | delete `test test_file: override XDG_STATE_HOME := $(TEST_HOME)/state` | killed, 9: the runner and child `stdpath { "state" }` and 7 `make test_file` probes (assertion) |
| **M2** | `require('aineo')` after `vim.g.loaded_aineo = true` | killed, 1: `Left: { "aineo.config", "aineo" }` (assertion) |
| **M3** | `return type(value) == 'number' and value > 0 and value < 1` → `return type(value) == 'number'` | killed, 4: heights 0, 1, 1.5, −0.25 (assertion) |
| MUlimit's equivalent | `if not wait_for_execution() then fail_run(…) end` → `wait_for_execution()` | killed, 2: both stall tests, `Fragment: made no progress` (assertion) |
| R16's equivalent | delete that `if` block | killed, 16 (assertion) |

**Tally: 36 mutants.**

- **34** killed by a suite test, by assertion.
- **1** killed on the slow pin's input, run directly.
- **1** equivalent: `fail_run` without the flag, measured on the stall and `os.exit` paths.
- **Superseded:** commit 2's table held two survivors. One is the equivalent above. The other, the record reverted to `vim.deepcopy`, survived because `recorded_setup_options()` also took a plain copy. Commit 3 removed that second copy, and the row above now kills.

**The re-measure's fixtures, against the final head.** Each ran as `make test_file`, with the fixtures pointed at this worktree.

- **The 12 race fixtures** (`qall!`, `quit`, `0cquit` at depths 1–4): exit 2 each.
- **The stubs.**
  - `stub_cmd`: exit 2.
  - `stub_cmd_stall` and `stub_now_stall`: exit 2 in 10.2 s, "made no progress".
- **Under an 8 s limit.**
  - `endless_wait`: exit 2 in 8.1 s.
  - `system_wait`: exit 2 in 8.1 s; its `sleep` outlived the run with ppid 1, and was stopped by pid (limit).
  - `child_busy`: exit 2 in 10.1 s, child gone.
  - `child_idle_wait`: exit 2 in 8.1 s, child gone.
- **Left running.**
  - `system_left`: exit 2; its `sleep` outlived the run (limit).
  - `job_left`: exit 2, the job gone.
  - The five child exit paths: 2, 0, 2, 2, and 2 in 10.2 s; each child gone.
- **Exit 0, as before:** `-leading.lua`, `with space/passing.lua`, `i2_fixture` and `i2_reporter_only`.
- `getchar`: exit 2.
- **RM5's two fixtures:** exit 0 with 1 case each (limit).
- **The two pins:** `pin_deps_unreadable` and `pin_r15`, exit 0.
- **`busy_runner`, under a 5 s limit:** still running at 20 s. It ignored SIGTERM and was stopped by SIGKILL (limit).
- **`seam_probe`:** it now fails at its line 22, because the handed-out copy has no metatable to index. A variant that reports that step shows:
  - the proxy's later edit is not recorded (`nil`);
  - the handed-out copy has no metatable;
  - `require('aineo')` exposes `setup` alone.
- **`env_probe`, with the five variables planted:**
  - none reaches the runner or the child;
  - stdpaths are under `.tests/.../nvim`;
  - `VIMINIT` did not run.
- **`nested.lua`** (make through `jobstart` in a Neovim isolated under the scratchpad): the runner has no `NVIM`, and its child's `NVIM` is the runner's own servername.

## Commits

Merged by rebase into `dev` on 2026-09-24 (PR #4, final head `5b323d8`; per-file identity 21 of 21), recorded by the orchestrator's knowledge pass:

| `dev` | was | round |
|---|---|---|
| `5edf69f` | `711fcc5` | packet — Add the mini.test harness and the entry-point skeleton |
| `35a5fab` | `f4a6e8b` | packet — Resolve aineo's configuration from vim.g.aineo and setup() |
| `09684d5` | `c199936` | packet — Record the T1 packet's session and put T1 in review |
| `d10b6a5` | `2a9be2e` | fix round — Let the test runner own its exit status and close the review's gaps |
| `c63fecb` | `f36a06f` | fix round — Correct the T1 records after the review of PR #4 |
| `1b0a578` | `c961ac4` | correction — Close the gaps the re-measure of PR #4 found in T1 |
| `a8e901d` | `ae0c84e` | correction — Pin that a stalled or timed-out run blames no test case |
| `4eaf389` | `8bebc90` | correction — Copy setup()'s options plainly once, when they are recorded |
| `7284c00` | `5b323d8` | correction — Record the T1 correction and correct the fix round's records |

The *For the `ai/` pass* items below landed with PR #5 (`12353b2`, `83c263e`, `798275d`).

## Open threads

- **For the `ai/` pass.**
  - The root `CLAUDE.md` gets the commands: `make deps`, `make test`, `make test_file FILE=<path>`, `make lint`, `make format`. `AINEO_TEST_RUN_LIMIT_MS=<milliseconds>` replaces the run's 16-minute limit.
  - `prepare_project` needs no step: `make test` isolates itself and fetches the pin on first use.
  - `neovim-lua-developer.md` › *Tests* should say the isolation lives in the Makefile, with the `CLAUDE*` removal in the minimal init, not in `prepare_project`.
  - `VIMRUNTIME` still reaches the suite from a parent Neovim (attack review, under A3; RM8). Unsetting it would break a developer who runs a development build of Neovim through it. The orchestrator decided it stays; recorded as a limit.
- **For T7.**
  - The composition root calls `require('aineo.config').resolve_config(vim.g.aineo, require('aineo.config').recorded_setup_options())`. Nothing reads `vim.g.aineo` yet.
  - Whether an empty-string `prefix` is refused. D13 allows any string, and `''` would map the bare keys.
  - How a `vim.validate` error reaches the user.
- **For T8.** The unknown keys `resolve_config()` returns are for the health check to report.
- **Limits.**
  - The run time limit bounds a case that waits: in its own `vim.wait`, on a process, on a request to a child Neovim, or at a test file's top level. It cannot bound a case that keeps Neovim itself busy, such as `while true do end`. That case ignores the limit and SIGTERM alike, and only a SIGKILL from outside ends it (RM2, re-measured on the correction's head).
  - A SIGKILL from outside skips Neovim's exit, so child Neovims outlive it. The re-measure found two alive after a SIGKILL of make's process group. The suite's own helper stops a run's whole process tree.
  - A process a test starts with `vim.system` and never stops is not a job, and outlives the run (re-measured: a `sleep` left with ppid 1).
  - A test group written as a plain table, or a set with `parametrize = {}`, is never collected. Such a file still contributes its other cases, so it passes the per-file check (RM5; the orchestrator's decision: recorded, not fixed; new suites build their groups with `MiniTest.new_set`).
  - `VIMRUNTIME` from a parent Neovim reaches the suite (RM8).
  - Every gate that reads only `make test`'s exit status is blind to a runner edited to stop propagating failures (I7). Read the `Fails (n)` line.
  - A plugin file that requires `aineo` after a delay (R20) is not caught by a startup snapshot.
  - `setup()` with a table that contains itself raises a stack overflow; `vim.deepcopy` accepted it.
  - `require('aineo.config').record_setup_options()` accepts a non-table; `setup()` refuses one first. This is internal API, unchanged.
