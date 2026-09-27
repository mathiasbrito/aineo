# 2026-09-27 — T22 parallel runner

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t22-parallel-runner` · **Pull request:** into `dev` (a regular packet)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (D26, D10, C8; T22, T1, T19)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t22-parallel-runner.md` and the brief review `brief-review-t22-parallel-runner.md` (F1 to F11)
- `Implementation/Waves/00006-fixes/evidence/suite-times-aaa326a.txt` — the times D26 rests on
- [[Sessions/2026-09-23 — T1 tooling foundation]] — how the runner came to decide the exit status itself (T1, PR #4)
- [[Learnings/mini.test v0.18.0 hangs instead of failing]] · [[Learnings/A test case can end a mini.test run green]] · [[Learnings/NVIM_LOG_FILE leaks past XDG isolation]]

## Context

**Goal:** T22, under D26: `make test` runs each test file in a Neovim of its own, several at once, each with a test home of its own, and gives one summary and one exit status as it did.

The user's decision, 2026-09-27, as D26 records it: asked "How should I cut the time the tests cost?", the user chose "Run less + parallel runner (Recommended)". This packet is its second half; PR #74 was the first.

## What was done

- **`scripts/run_tests.lua`** is now a coordinator. It refuses a bad `AINEO_TEST_JOBS` or `AINEO_TEST_RUN_LIMIT_MS` before it starts anything; collects the files as before (the named one, or mini.test's default glob, erroring when none matches); makes a directory for the run's homes with `vim.uv.fs_mkdtemp(<.tests/homes>/run-XXXXXX)` and, inside it, a home per file (`<n>-<file stem>`) with its log directory; runs each file in `nvim --headless --noplugin -u scripts/minimal_init.lua -l scripts/run_test_file.lua <file> <records>` through `vim.system`, with `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`, `CLAUDE_CONFIG_DIR` and `NVIM_LOG_FILE` in that home and everything else inherited; at most `AINEO_TEST_JOBS` at once (8 by default); relays each file's stdout and stderr as it ends; then prints one summary by driving mini.test's own `gen_reporter.stdout` over the cases every file recorded; and exits 1 unless every file's Neovim exited 0 and the run finished within its limit. Its `VimLeavePre` stops every running file's Neovim with SIGKILL of its whole process tree, listed first, and removes the run's homes — on every ending: normal, at the limit, on its own error, on SIGTERM.
- **`scripts/run_test_file.lua`** (new) is T1's runner for one file: the Neovim functions taken before the file is sourced, the `os.exit` and `VimLeavePre` guards, the stall wait; its reporter shows nothing and writes JSON records (the cases' names, with arguments folded in as mini.test names them, then each state change of a case) to the record file.
- **`Makefile`**: `TEST_LOG_DIRECTORY` (`.tests/state/nvim`), made by both recipes before the runner starts; `TEST_HOMES` (`.tests/homes`), passed to the runner; the drafts' and kept session ids' clean-up removed (each file's home is new); `__NVIM_LOG_FILE_WANT` added to the `unexport` line; the comments rewritten.
- **`tests/helpers/fixture.lua`**: `write()` writes `<path>.<pid>.writing` and renames it over the target.
- **`tests/helpers/make.lua`**: `AINEO_TEST_JOBS` emptied for every target a test runs (an empty variable reads as absent in Neovim); a `makefile` option.
- **Tests:** `tests/test_runner_parallel.lua` (14 cases), `tests/test_runner_homes.lua` (6), `tests/test_runner_fixtures.lua` (1), and in `tests/test_isolation.lua` one new case and a probe that pins a home of its own, the runner's own user state (asked over RPC through the `NVIM` address every file's Neovim inherits), and no log fallback in the file's Neovim or its child. The group `the runner` there is renamed `a test file's Neovim`, which is what it now tests.

## Unit list (stated before the first test)

1. `AINEO_TEST_JOBS` that names no whole number above zero is refused.
2. Characterization, before the rewrite: one summary over a suite of two files; a failing file fails the run while another passes.
3. `make test` runs its files side by side (no option: the default).
4. `AINEO_TEST_JOBS=2` bounds the files at once; `AINEO_TEST_JOBS=1` runs one at a time.
5. Each file has a home apart from every other file of its run.
6. A file's home starts empty of what an earlier run left there.
7. A run started inside a file gives its file a home apart from the outer file's, and leaves the outer file's home as it was.
8. A run removes its homes when it ends.
9. The isolation probe: a home of its own inside `.tests/homes/`, its log in that home, no `__NVIM_LOG_FILE_WANT` in the file's Neovim or its child.
10. A parent's `__NVIM_LOG_FILE_WANT` reaches no Neovim of the run.
11. A run in a checkout with no `.tests/` yet tells no Neovim of a missing log.
12. The time limit ends a run whose case keeps its Neovim busy, and leaves that Neovim stopped.
13. A runner ended from outside leaves no file's Neovim running.
14. `fixture.write` replaces a file whole.
15. A run a case starts runs side by side whatever `AINEO_TEST_JOBS` the outer run had.
16. The default is eight files at once.

## Red and green

**Seen red** (each on 0.12.5 unless said):

| test | red |
|---|---|
| `AINEO_TEST_JOBS` › is refused unless it is a whole number above zero (`many`, `0`, `-2`, `1.5`) | `Left: 0` (the setting was ignored). An empty value was dropped from the table: Neovim reads an empty variable as absent, and `make.lua` empties variables that way |
| make test › runs its test files side by side | `Left: { 1 }` — both files ran in one Neovim |
| a test file › has a home apart from every other file of its run | `Failed expectation for *no* equality`, both `.tests/state/nvim` |
| a test file › starts in a home empty of what an earlier run left there | the file's run ended rc 2 with `Fails (0)`: the homes were then named by index under `.tests/homes/`, so the runs the case started wrote their records over the outer file's. The missing behaviour itself; the assertion's own message was not readable |
| a run › removes the homes of its files once it ends | `Left: { atime = … }` (the home still there) |
| the isolation probe's `log`, `no log fallback`, `no log fallback in a child` | 7 `make test_file` cases of `test_isolation.lua` at `Left: 2`; the probe alone: those three failed on 0.12.5, all 13 passed on 0.11.6 (0.11.6 makes the directory itself — behaviour that cannot be red there) |
| make test_file › keeps a parent Neovim's log fallback out of its runner and children | `Left: 2` |
| a run › in a checkout with no .tests/ yet tells no Neovim of a missing log | `Left: 2`; run by hand, the probe's `no log fallback` and `no log fallback in a child` failed: the runner fell back and every file's Neovim inherited `__NVIM_LOG_FILE_WANT` |
| a run ended from outside › leaves no test file's Neovim running | `Left: false` |
| fixture.write › replaces a file whole, leaving a reader of the old one its content | `Left: "new\n"`, `Right: "old\n"` |
| make test › started by a case runs its files side by side, whatever the outer run allows | `Left: { 1, 1 }` |

**Arrived green:**

| test | why | killer, run |
|---|---|---|
| make test › prints one summary over all its files | green by nature: the old runner was one mini.test run | S1, S2 (below) |
| make test › fails when a case of one file fails while every other passes | green by nature | E5 |
| AINEO_TEST_JOBS › bounds how many test files run at once; › of 1 runs one test file at a time | pinning code written ahead: the pool took `jobs` in unit 3 | R3 |
| a run started inside another › gives its file a home apart from the outer file | spent by unit 6's `fs_mkdtemp` | H2 in its file; H1 does not reach it (below) |
| a run started inside another › leaves the outer file's home as it was | spent by unit 6. Its first form survived H1 and H6 under a pristine outer runner, so it was rewritten as a run inside a run (commit "Test that a run inside a file keeps that file's home, one level down") | H1, H6 |
| the run time limit › ends a run, saying so, while a case keeps its Neovim busy; › leaves no test file's Neovim running when it ends a run | pinning code written ahead: the coordinator's bounded wait and its stop, from unit 3 | E4; E1, E3 |
| make test › runs eight test files at once unless told otherwise | pinning code written ahead: `DEFAULT_JOBS = 8` was set before the test | R1 |
| the isolation probe's `home` and `the runner` | `home`: spent by unit 5; `the runner`: the Makefile already isolated the runner | H3; H9 |

## Mutants

Each ran alone, from a pristine copy of its file, against a copy of its test file narrowed to the group that exercises it, with the outer run on a pristine copy of the tree (so only the runs the tests start met the mutant); a mutant that leaves processes behind had them stopped by pid after its row. Final rows, on `c86db4c`'s tree:

| id | edit | result |
|---|---|---|
| R1 | `local DEFAULT_JOBS = 8` → `local DEFAULT_JOBS = 7` | killed, assertion: `{ 5, 7, 7, 7, 7, 7, 7, 7 }` ≠ eight 8s |
| R2 | `local DEFAULT_JOBS = 8` → `local DEFAULT_JOBS = 1` | killed, assertion: side by side `{ 1, 1 }` |
| R3 | `local jobs = jobs_at_once(vim.env.AINEO_TEST_JOBS)` → `… and DEFAULT_JOBS` | killed, assertion: `{ 3, 3, 3 }` above 2; `{ 2, 2 }` ≠ `{ 1, 1 }` |
| R4 | `jobs_setting:match('^%d+$') and tonumber(jobs_setting)` → `tonumber(jobs_setting)` | killed, assertion: `1.5` exits 0; `-2` exits 124 |
| R5 | `if not jobs or jobs == 0 then` → `if not jobs then` | killed, assertion: `0` exits 124 |
| R6 | `if not jobs or jobs == 0 then` → `if false then` | killed, assertion: 4 cases (message missing, or 124) |
| H1 | `return assert(vim.uv.fs_mkdtemp(…'run-XXXXXX'))` → `vim.fn.mkdir(<homes>/run, 'p') return <homes>/run` | killed, assertion: leaves the outer file's home as it was (`Left: 2`) |
| H2 | `('%d-%s'):format(index, …)` → `'home'` | killed, assertion: a home apart from every other file |
| H3 | `{ env = home_environment(file_run.home), text = true }` → `{ text = true }` | killed, assertion: 2 cases |
| H4 | `vim.fn.mkdir(vim.fs.dirname(log_file(home)), 'p')` → `vim.fn.mkdir(home, 'p')` | killed, assertion: 8 `make test_file` isolation cases (0.12.5) |
| H5 | `vim.fn.delete(run_homes, 'rf')` removed | killed, assertion |
| H6 | `vim.fn.mkdir(homes, 'p')` → `vim.fn.delete(homes, 'rf') vim.fn.mkdir(homes, 'p')` | killed, assertion: leaves the outer file's home as it was |
| H7 | the `test_file` recipe's `mkdir -p '$(TEST_LOG_DIRECTORY)'` removed | killed, assertion: the fresh-checkout case (0.12.5) |
| H8 | `__NVIM_LOG_FILE_WANT` removed from `unexport` | killed, assertion: the planted-fallback case |
| H9 | `test test_file: override XDG_CONFIG_HOME := $(TEST_HOME)/config` removed | killed, assertion: 8 isolation cases (the probe's `the runner`) |
| E1 | `stop_running_files(file_runs)` removed from `VimLeavePre` | killed, assertion: 2 cases |
| E2 | `ipairs(process_tree(root_pid))` → `ipairs({ root_pid })` | killed, assertion: test_runner's "leaves no child Neovim running when it ends a run" ×2 |
| E3 | `vim.uv.kill(pid, 'sigkill')` → `'sigterm'` | killed, assertion: "leaves no test file's Neovim running when it ends a run" |
| E4 | `return vim.wait(limit_ms, …` → `return vim.wait(2 ^ 31 - 1, …` | killed, assertion: `Left: 124` |
| E5 | `return file_run.completed ~= nil and file_run.completed.code == 0` → `return file_run.completed ~= nil` | killed, assertion: 21 of test_runner's `make test_file` cases |
| E6 | the relay of a file's stderr removed | killed, assertion: the two stall cases lose "made no progress" |
| E7 | `if #files == 0 then` → `if false then` | killed, assertion: `Left: 0` |
| S1 | `vim.list_extend(all_cases, recorded_cases(…))` → `all_cases = recorded_cases(…)` | killed, assertion: `Total number of cases: 1` |
| S2 | the file's reporter → `MiniTest.gen_reporter.stdout({ quit_on_finish = false })` | killed, assertion: two per-file summaries before the run's |
| W1 | `if #case.args > 0 then` → `if false then` | killed, assertion: `FAIL in … | with` without `+ args { 1 }` |
| W2 | `os.exit = function()` → `local _ = function()` | killed, assertion: the `os.exit(0)` ending |
| F1 | `local written = ('%s.%d.writing'):format(…)` → `local written = path` | killed, assertion: `"new\n"` |
| M1 | `{ AINEO_TEST_JOBS = '' }` → `{}` | killed, assertion: `{ 1, 1 }` |
| M2 | `run.makefile or MAKEFILE` → `MAKEFILE` | killed, assertion: the fresh-checkout case's probe fails its `home` pin |

The first table (before the rewrite of "leaves the outer file's home as it was") had H1 and H6 surviving; under the mutated runner itself they ended the file's run rc 2 with its records removed along with its home — a crash, not a kill. The rewrite gave them an assertion.

Measured on the way: the E2 and E3 mutants leave busy Neovims behind by construction. Two table runs left 12 of them running for 20–32 min before they were found and stopped by pid (21:02); the host's load stood at 800–920 then, and E5, E6, E7 were re-run after, with leftovers stopped by the mutant runner after each row.

## Verification

Every run below is a whole `make test` from this worktree, logged with `nvim --version | head -1`, `uptime` at its start and end, and the sha (`.claude/local/orchestrator/t22-times.txt`, gitignored). Loads are the 1-minute average.

**PR6 — wall clock.**

| tree | Neovim | jobs | wall clock | load, start → end | cases, Fails |
|---|---|---|---|---|---|
| base `384c084` (the old runner) | 0.12.5 | one runner | 856 s | 88 → 125 | 1227, 0 |
| base `384c084` | 0.11.6 | one runner | 875 s | 125 → 195 | 1227, 0 |
| working tree before the first commit | 0.12.5 | 4 | 287 s | 153 → 128 | 1248, 0 |
| working tree before the first commit | 0.12.5 | 8 | 178 s | 126 → 185 | 1248, 0 |
| working tree before the first commit | 0.12.5 | 12 | 172 s | 181 → 139 | 1248, 0 |
| `c86db4c` | 0.12.5 | 8 (default), 10 runs | 169–172 s | 33–316 at the starts | 1249 each |
| `c86db4c` | 0.11.6 | 8 (default), 10 runs | 167–175 s | 27–224 at the starts | 1249 each |
| `c86db4c` | 0.12.5 | 1 | 887 s | 34 → 42 | 1249, 0 |
| `c86db4c` | 0.11.6 | 1 | 896 s | 42 → 139 | 1249, 0 |

**The file that bounds the run** (sampled every second with `ps`, `t22-files-*.txt`): at the default, `tests/test_send.lua` ends every one of the 20 runs, at 167–174 s — it starts at 64–71 s, when a slot frees, and runs 98–104 s. `tests/test_claude.lua` starts at 1 s and runs 154–156 s; `tests/test_claude_resume.lua` (T19) 103–113 s. At 12 jobs `tests/test_claude.lua` ended the run (170 s).

**PR7 — green runs at the default (8), sha `c86db4c`.** A run counts as green when it exits 0 with 1249 cases (the base's 1227 and this packet's 22).

- 0.12.5: runs 1–10 → green, **red** (run 2), then 8 green in a row (runs 3–10).
- 0.11.6: runs 1–10 → green, **red** (run 2), then 8 green in a row (runs 3–10).

PR7 is met: five in a row on 0.12.5 and three on 0.11.6, each past a failing run that restarted its count.

**Cases that failed under side-by-side load, not alone** — each rate k/10 over the ten whole runs at the default on that version, and ten runs of the file alone (`make test_file`) right after at loads 22–192:

| case | version | whole suite | alone | cause |
|---|---|---|---|---|
| `tests/test_runner.lua` › the run time limit › ends a run, saying so, while a case waits › on `vim.wait(1e9, …)` | 0.12.5 | 1/10 (run 2, load ~190) | 0/10 | `make.run`'s own 10 s bound (`DEFAULT_TIME_LIMIT_MS`) stopped a nested run whose limit is 3 s: `Left: 124`. The same run by itself took 3.16–3.20 s in 10 of 10 (`t22-limit-probe.sh`, load ~230). What took the other 7 s was not found |
| `tests/test_health.lua` › Claude Code › leaves the editor free to wait when Ctrl-C ends a check of a command that writes without end | 0.11.6 | 1/10 (run 2) | 0/10 | its own timing: `vim.wait(100)` in the child must return in under 1000 ms (`test_health.lua:336`) |
| `tests/test_report_links.lua` › a long line › shows in the Report, and again on :edit, within the time limit (`https://a`, `)`, 1000000) | 0.11.6 | 1/10 (run 2) | 0/10 | its own timing: a limit of 2 s, measured 5.1 s |
| `tests/test_report_paths.lua` › the file checks › of a line of distinct paths take at most the time limit, on arrival and on :edit (T17's) | 0.11.6 | 0/10 | 0/10 | — |

The two outside the boundary are timing cases whose own limits the host's load exceeded; they are reported, not changed. The first is inside it; it is reported rather than changed, because its cause is not established (see Open threads).

**Mutants and the touched files** on 0.12.5 as above. **Lint:** `make lint` clean (StyLua, selene) on every commit.

## Decisions & reasoning

- **The records feed the summary; each file's Neovim decides its file.** The worker keeps every guard T1 built, so its exit status is the file's verdict; a second verdict from the records could not be told apart from the first by any test.
- **The summary is printed once, at the end,** through mini.test's own reporter, so its lines are mini.test's exactly: one `Total number of cases`, one progress line per file in collection order, one `Fails (`. Rejected: relaying each file's own summary with an aggregate after (F4). The cost: no live progress while the run goes.
- **Homes are made new for each run and removed at its end; nothing is cleared at a start.** The suite's own tests run the recipes while other files run (F2); `fs_mkdtemp` gives every run, beside or inside another, a directory of its own.
- **`__NVIM_LOG_FILE_WANT` is unexported by the Makefile, and the runner's log directory made by the recipes** (F1). The runner itself strips nothing: the two measures leave it no way to have the variable.
- **The default is 8.** Measured on this host (10 cores), on the working tree before the first commit: 4 jobs 287 s, 8 jobs 178 s, 12 jobs 172 s, at loads 125–185 (see Verification). From 8 on, the run is bounded by `tests/test_claude.lua` alone (about 156 s) and `tests/test_send.lua`, which starts late in collection order.
- **No list of files by name** to start the slowest first (the brief review's guard: T12 adds a file concurrently). What it would save: `tests/test_send.lua` starts at 64–71 s and ends the run at 167–174 s; started first it would end near 105 s, and the run near 157 s, when `tests/test_claude.lua` ends.

## Task lines

This wave holds its marks (rule 6). For the orchestrator: T22 — the runner runs each file in a Neovim of its own, 8 at once by default (`AINEO_TEST_JOBS`), each in a home of its own under `.tests/homes/`, with one summary and one exit status; PR7 as measured in Verification.

## Limits

- **A process a test starts with `vim.system` and never stops** outlives its file's Neovim when that Neovim ends by itself (measured: `sleep 41` re-parented to pid 1); at the limit it is stopped with the tree.
- **SIGKILL of the runner from outside** skips its `VimLeavePre`, leaving every file's Neovim running; `make.lua` stops a nested run's whole tree, listed first, so the suite's own tests are not affected.
- **A home that cannot be removed** stays in `.tests/homes/`; so does a run's directory whose runner was killed.
- **No live progress:** the summary prints at the end; a file's own output is relayed as it ends.

## Open threads

- **`make.run`'s 10 s default under side-by-side load** (1/10 whole runs on 0.12.5, 0/10 alone). Raising `DEFAULT_TIME_LIMIT_MS` would cost only a failing nested run's wait; left for the orchestrator, since the 7 s it missed were not explained.
- **Start the longest files first** without a list by name — for instance, by the times of the last run — would end the run near 157 s instead of 170 s.
- **Sentences this change makes false, outside the boundary** (for the orchestrator's `ai/` pass, and two spec conflicts):
  - root `CLAUDE.md`: the make table ("a case that keeps Neovim itself busy is not bounded"; the isolation paragraph's "under the checkout's `.tests/`", which now means a home per file under `.tests/homes/`; `AINEO_TEST_JOBS` unnamed), and the D26 bullet's "a whole run takes 10–12 minutes" (now about 3);
  - `.claude/agents/neovim-lua-developer.md:35` and `.claude/agents/neovim-claude-code-integrator.md:61` (the `Makefile` sets the variables under `.tests/`: now the runner sets each file's);
  - `.claude/agents/implementer.md`'s "10–12 minutes";
  - `scripts/minimal_init.lua:1–2` and `:10–11` (the init of "the test runner … and each child Neovim"; `CLAUDE_CONFIG_DIR` "which the Makefile points into `.tests/`") and `tests/helpers/child.lua:4–6` ("the isolation `make test` sets up" — a child now inherits its file's home): outside the boundary, not edited.

## Commits

*Recorded after the merge.*
