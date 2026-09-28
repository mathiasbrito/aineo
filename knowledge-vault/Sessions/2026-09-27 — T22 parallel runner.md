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
- **`Makefile`**: `TEST_LOG_DIRECTORY` (`.tests/state/nvim`), made by both recipes before the runner starts; `TEST_HOMES` (`.tests/homes`), passed to the runner; the drafts' and kept session ids' clean-up removed (each file's home is new); `__NVIM_LOG_FILE_WANT` added to the global `unexport` line, which every target reads — a widening of the brief's boundary (the `test` and `test_file` targets only) that this note and the PR body did not declare, and that the fix round undid (see *Fix round*); the comments rewritten.
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

**Seen red** (each on 0.12.5 unless said). Only two of these eleven reds were saved (`t22-red-p4.out`, `t22-red-p5.out`); the other nine were read at the time and not kept, so they rest on this table alone:

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
| make test › prints one summary over all its files — its failing case's `FAIL in` line naming the case with its arguments (`+ args { 1 }`), given an argument in `413c827` ("Let each test file's Neovim decide its file, and pin case names") after the worker's naming was written in `43f6660` | pinning code written ahead: the worker named cases with their arguments before any test asked for it; it was in no unit of the list above | W1, run: killed, assertion (`FAIL in tests/test_b.lua \| fails \| with` without `+ args { 1 }`), in the fix round's re-run at `1083de2` |

## Mutants

Each ran alone, from a pristine copy of its file, against a copy of its test file narrowed to the group that exercises it, with the outer run on a pristine copy of the tree (so only the runs the tests start met the mutant); a mutant that leaves processes behind had them stopped by pid after its row. Final rows, on `c86db4c`'s tree — except S1, W1 and R1, whose messages below are the fix round's re-run of the same literal edits at `1083de2` (0.12.5, load 140–145, `t22f-mutants.txt`): the messages first written here were run 1's (`t22-mutants-run1.txt`), while the final table (`t22-mutants-final.txt`) had `Left: {}` for S1 and W1 — `make.run`'s 10 s bound stopping the nested run at load 800–920, not the mutant — and `{ 7, 7, 7, 7, 7, 7, 7, 7 }` for R1:

| id | edit | result |
|---|---|---|
| R1 | `local DEFAULT_JOBS = 8` → `local DEFAULT_JOBS = 7` | killed, assertion: `{ 4, 7, 7, 7, 7, 7, 7, 7 }` ≠ eight 8s (re-run at `1083de2`) |
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
| S1 | `vim.list_extend(all_cases, recorded_cases(…))` → `all_cases = recorded_cases(…)` (at `1083de2`: `vim.list_extend(all_cases, cases)` → `all_cases = cases`) | killed, assertion: `Total number of cases: 1` ≠ `3` (re-run at `1083de2`) |
| S2 | the file's reporter → `MiniTest.gen_reporter.stdout({ quit_on_finish = false })` | killed, assertion: two per-file summaries before the run's |
| W1 | `if #case.args > 0 then` → `if false then` | killed, assertion: `FAIL in tests/test_b.lua \| fails \| with` without `+ args { 1 }` (re-run at `1083de2`) |
| W2 | `os.exit = function()` → `local _ = function()` | killed, assertion: the `os.exit(0)` ending |
| F1 | `local written = ('%s.%d.writing'):format(…)` → `local written = path` | killed, assertion: `"new\n"` |
| M1 | `{ AINEO_TEST_JOBS = '' }` → `{}` | killed, assertion: `{ 1, 1 }` |
| M2 | `run.makefile or MAKEFILE` → `MAKEFILE` | killed, assertion: the fresh-checkout case's probe fails its `home` pin |

The first table (before the rewrite of "leaves the outer file's home as it was") had H1 and H6 surviving; under the mutated runner itself they ended the file's run rc 2 with its records removed along with its home — a crash, not a kill. The rewrite gave them an assertion.

Measured on the way: the E2 and E3 mutants leave busy Neovims behind by construction. Two table runs left 12 of them running for 20–32 min before they were found and stopped by pid (21:02); the host's load stood at 800–920 then, and E2, E3, E5, E6 and E7 were re-run after (`t22-mutants-final-e.txt`), with leftovers stopped by the mutant runner after each row; the E2 and E3 rows above quote that re-run. No process listing of the twelve leftovers was kept.

## Verification

Every run below is a whole `make test` from this worktree, logged with `nvim --version | head -1`, `uptime` at its start and end, and the sha (`.claude/local/orchestrator/t22-times.txt`, gitignored). Loads are the 1-minute average. The three runs on the working tree before the first commit are logged there as `sha=384c084`: the commit `rev-parse HEAD` named while the tree held uncommitted changes, not the code they ran. Whether 0.12.5's run 1 at `c86db4c` overlapped the E-mutant re-run in the same worktree cannot be told from the logs, which keep no process listing; the streak counted is runs 3–10.

**PR6 — wall clock.**

| tree | Neovim | jobs | wall clock | load, start → end | cases, Fails |
|---|---|---|---|---|---|
| base `384c084` (the old runner) | 0.12.5 | one runner | 856 s | 88 → 125 | 1227, 0 |
| base `384c084` | 0.11.6 | one runner | 875 s | 125 → 195 | 1227, 0 |
| working tree before the first commit | 0.12.5 | 4 | 287 s | 153 → 128 | 1248, 0 |
| working tree before the first commit | 0.12.5 | 8 | 178 s | 126 → 185 | 1248, 0 |
| working tree before the first commit | 0.12.5 | 12 | 172 s | 181 → 139 | 1248, 0 |
| `c86db4c` | 0.12.5 | 8 (default), 10 runs | 169–172 s | 54–316 at the starts | 1249 each |
| `c86db4c` | 0.11.6 | 8 (default), 10 runs | 167–175 s | 27–224 at the starts | 1249 each |
| `c86db4c` | 0.12.5 | 1 | 887 s | 34 → 42 | 1249, 0 |
| `c86db4c` | 0.11.6 | 1 | 896 s | 42 → 139 | 1249, 0 |

**The file that bounds the run** (sampled every second with `ps`, `t22-files-*.txt`): at the default, `tests/test_send.lua` ends every one of the 20 runs, at 167–174 s — it starts at 64–71 s, when a slot frees, and runs 98–104 s. `tests/test_claude.lua` starts at 1 s and runs 154–156 s; `tests/test_claude_resume.lua` (T19) 103–113 s. At 12 jobs `tests/test_claude.lua` ended the run (170 s).

**PR7 — green runs at the default (8), sha `c86db4c`.** A run counts as green when it exits 0 with 1249 cases (the base's 1227 and this packet's 22).

- 0.12.5: runs 1–10 → green, **red** (run 2), then 8 green in a row (runs 3–10).
- 0.11.6: runs 1–10 → green, **red** (run 2), then 8 green in a row (runs 3–10).

PR7 is met: five in a row on 0.12.5 and three on 0.11.6, each past a failing run that restarted its count.

**Cases that failed under side-by-side load, not alone** — each rate k/10 over the ten whole runs at the default on that version, and ten runs of the file alone (`make test_file`). `tests/test_runner.lua`'s alone runs followed its series (22:36–22:48, loads 32–192); `tests/test_health.lua`'s and `tests/test_report_links.lua`'s did not: they ran at 22:48–22:53, over an hour after the 0.11.6 run they failed in (load 202 → 175), at loads 22–92, so they do not rule out the host's load. The fix round ran each ten times more, alone on 0.11.6 at `1083de2`: 10/10 and 10/10 green, but at loads 14–30 (`t22f-alone-*-0116.txt`), not the whole runs' 100–200, which the host did not reach again that night:

| case | version | whole suite | alone | cause |
|---|---|---|---|---|
| `tests/test_runner.lua` › the run time limit › ends a run, saying so, while a case waits › on `vim.wait(1e9, …)` | 0.12.5 | 1/10 (run 2, load ~190) | 0/10 | `make.run`'s own 10 s bound (`DEFAULT_TIME_LIMIT_MS`) stopped a nested run whose limit is 3 s: `Left: 124`. The same run by itself took 3.16–3.20 s in 10 of 10 (`t22-limit-probe.sh`, load ~230). What took the other 7 s was not found |
| `tests/test_runner_parallel.lua` › the run time limit › ends a run, saying so, while a case keeps its Neovim busy | 0.12.5 | 0/10 here; 1 of 3 in the records review's whole runs at `5239471` (load ~200) | 0/5 (records review, loads 127–161) | the same `make.run` 10 s bound on a nested run whose limit is 3 s: `Left: 124`. Missed by this table at first |
| `tests/test_health.lua` › Claude Code › leaves the editor free to wait when Ctrl-C ends a check of a command that writes without end | 0.11.6 | 1/10 (run 2) | 0/10; the re-measure: 7/7 at loads 32–67 and **10/10 at loads 80–193**, beside five or six suites | its own timing: `vim.wait(100)` in the child must return in under 1000 ms (`test_health.lua:336`) |
| `tests/test_report_links.lua` › a long line › shows in the Report, and again on :edit, within the time limit (`https://a`, `)`, 1000000) | 0.11.6 | 1/10 (run 2) | 0/10; the re-measure: 10/10 at loads 80–124, then **2 of 10 red at loads 128–253** (red at 138 and 192, `arrival = "5.2 s"`) | its own timing: a limit of 2 s, measured 5.1 s: the host's load, since it fails alone at the load its whole-run failure had |
| `tests/test_report_paths.lua` › the file checks › of a line of distinct paths take at most the time limit, on arrival and on :edit (T17's) | 0.11.6 | 0/10 | 0/10 | — *The re-measure: failed in every one of its 10 runs made with five or six whole suites side by side (`edit = "2.4 s"`, its own limit), against 0/3 in its single whole runs — five suites together are not one suite at a high load.* |

The two outside the boundary are timing cases whose own limits the host's load exceeded; they are reported, not changed. The first is inside it; it is reported rather than changed, because its cause is not established (see Open threads).

**Mutants and the touched files** on 0.12.5 as above. **Lint:** `make lint` clean (StyLua, selene) on every commit.

## Decisions & reasoning

- **The records feed the summary; each file's Neovim decides its file.** The worker keeps every guard T1 built, so its exit status is the file's verdict; a second verdict from the records could not be told apart from the first by any test. *Wrong, as the attack review measured (A1, A4): a signal, or a test file's own `VimLeavePre`, tells the two apart. The fix round decides a file from both.*
- **The summary is printed once, at the end,** through mini.test's own reporter, so its lines are mini.test's exactly: one `Total number of cases`, one progress line per file in collection order, one `Fails (`. Rejected: relaying each file's own summary with an aggregate after (F4). The cost: no live progress while the run goes.
- **Homes are made new for each run and removed at its end; nothing is cleared at a start.** The suite's own tests run the recipes while other files run (F2); `fs_mkdtemp` gives every run, beside or inside another, a directory of its own.
- **`__NVIM_LOG_FILE_WANT` is unexported by the Makefile, and the runner's log directory made by the recipes** (F1). The runner itself strips nothing: the two measures leave it no way to have the variable — through `make`; a runner whose own log file cannot be opened in an existing directory would still export it (not measured). The fix round moved the variable from the global `unexport` line to a `test test_file: override` that empties it. *That override held the environment route only: GNU Make 3.81 gives a recipe the command line's or `MAKEFLAGS`' value of a variable it does not export. The correction adds `export __NVIM_LOG_FILE_WANT` beside it (see Correction).*
- **The default is 8.** Measured on this host (10 cores), on the working tree before the first commit: 4 jobs 287 s, 8 jobs 178 s, 12 jobs 172 s, at loads 126–185 (see Verification). At 8, `tests/test_send.lua` ends every run (167–174 s): it starts late, when a slot frees at 64–71 s, and runs about 100 s; `tests/test_claude.lua`, the slowest file alone, ends at 154–156 s.
- **No list of files by name** to start the slowest first (the brief review's guard: T12 adds a file concurrently). What it would save: `tests/test_send.lua` starts at 64–71 s and ends the run at 167–174 s; started first it would end near 105 s, and the run near 157 s, when `tests/test_claude.lua` ends.

## Task lines

This wave holds its marks (rule 6). For the orchestrator: T22 — the runner runs each file in a Neovim of its own, 8 at once by default (`AINEO_TEST_JOBS`), each in a home of its own under `.tests/homes/`, with one summary and one exit status; PR7 as measured in Verification.

## Limits

- **A process a test starts with `vim.system` and never stops** outlives its file's Neovim when that Neovim ends by itself (measured: `sleep 41` re-parented to pid 1); at the limit it is stopped with the tree.
- **SIGKILL of the runner from outside** skips its `VimLeavePre`, leaving every file's Neovim running; `make.lua` stops a nested run's whole tree, listed first, so the suite's own tests are not affected.
- **A home that cannot be removed** stays in `.tests/homes/`; so does a run's directory whose runner was killed. Until the fix round, that included one per whole run at least: `make.run` SIGKILLed the nested run of `tests/test_runner.lua` › a run stopped at its time limit, so its `run-*` stayed (and one more for each nested run stopped at `make.run`'s bound). The fix round's `make.run` sends SIGTERM first, which the runner answers by removing its homes.
- **No live progress:** the summary prints at the end; a file's own output is relayed as it ends.

## Open threads

- **`make.run`'s 10 s default under side-by-side load** (1/10 whole runs on 0.12.5, 0/10 alone), met by two cases, `tests/test_runner.lua`'s and `tests/test_runner_parallel.lua`'s, not one. Raising `DEFAULT_TIME_LIMIT_MS` would cost only a failing nested run's wait; left for the orchestrator, since the 7 s it missed were not explained. *The fix round raised it to a minute (see Fix round).*
- **Start the longest files first** without a list by name — for instance, by the times of the last run — would end the run near 157 s instead of 170 s.
- **Sentences this change makes false, outside the boundary** (for the orchestrator's `ai/` pass, and two spec conflicts):
  - root `CLAUDE.md`: the make table ("a case that keeps Neovim itself busy is not bounded"; the isolation paragraph's "under the checkout's `.tests/`", which now means a home per file under `.tests/homes/`; `AINEO_TEST_JOBS` unnamed), and the D26 bullet's "a whole run takes 10–12 minutes" (now about 3);
  - `.claude/agents/neovim-lua-developer.md:35` and `.claude/agents/neovim-claude-code-integrator.md:61` (the `Makefile` sets the variables under `.tests/`: now the runner sets each file's);
  - `.claude/agents/implementer.md`'s "10–12 minutes";
  - `scripts/minimal_init.lua:1–2` and `:10–11` (the init of "the test runner … and each child Neovim"; `CLAUDE_CONFIG_DIR` "which the Makefile points into `.tests/`") and `tests/helpers/child.lua:4–6` ("the isolation `make test` sets up" — a child now inherits its file's home): outside the boundary, not edited.
  - Missed by this list, found by the records review (R3): `.claude/agents/reviewer.md:47` and `.claude/skills/orchestrate/SKILL.md:27` ("a whole run takes 10–12 minutes", the sentence of `implementer.md:56`); `tests/helpers/entry_editor.lua:9–10` ("the isolation `make test` sets up", as `child.lua:4–6`); `knowledge-vault/Projects/aineo.md:79` ("the `Makefile` never creates the log's directory": both recipes now make it, and the runner makes each home's); the root `CLAUDE.md:42`'s init clause ("the runner, and each child a test starts" leaves out every test file's Neovim) and its list of variables kept from the runner. Outside the boundary; not edited.

## Fix round (2026-09-28)

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`), a fresh agent taking over the round from the packet's author. **Branch:** `feature/t22-parallel-runner`, from `5239471`. It works the three reviews of PR #85 — attack A1–A8, test-integrity I1–I11, records R1–R14 — and the orchestrator's decisions on them, as one round.

**What changed.**

- **A file's verdict** (A1, A4): a file passes only when its Neovim exited 0, not on a signal, and its records show at least one case and every case run and passed. The records check refutes the reason `413c827`'s message (and the *Decisions* above) gave for leaving the records out: a signal, or a test file's own `VimLeavePre` that raises or runs `0cquit`, tells the two verdicts apart. The attack review's form, adopted.
- **Every failing ending names its file** (A3): after the summary, on stdout, a line `FAIL in <file>: the test file did not pass: <why>` for each file that failed with no failing case of its own — the attack review's reasons, on a line the verification scripts read. A file with a failing case is already named by that case's line, so the summary test's lines are unchanged.
- **A file's output cannot forge the summary** (A8): each file's stdout and stderr go to a file in its home and are relayed on **stderr** as it ends, so nothing a test prints comes before the summary on stdout. The attack review's form (relay the files' stdout to stderr).
- **A file ends when its Neovim exits** (A6): the file's Neovim is started with `vim.uv.spawn`, its output to that file, not with `vim.system`, which reports an exit only once the output pipes close (`runtime/lua/vim/_core/system.lua`, `_on_exit`). The attack review's own suggestion — skip closing processes and bound the wait for their output — would have left the verdict without its exit code. The ending is recorded in libuv's exit callback, so the runner never signals a reaped pid.
- **The runner's own guard** (A5): its `VimLeavePre` runs `cquit 1` until the verdict is reached. The attack review's form, with the flag set just before the final decision rather than right after the files end.
- **Refused limits** (A2): `nan` and `inf` are refused with every limit that is not a finite number above zero. `1e18` stays accepted: a finite limit is honoured as given (a limit, below).
- **Homes** (A7, R12, decision 8): `make.run` stops a run at its limit with SIGTERM first — the runner, which runs no test code, answers by stopping its files and removing their homes — and SIGKILLs what is left after 5 s. The runner makes `.tests/homes` as the report records and the draft home do, retrying a `mkdir()` that lost a race.
- **`make.run`'s default bound** (decision 16, R1): 10 s → 60 s. Measured first: two whole runs with `make.run` instrumented (0.12.5, load 34 → 56; 0.11.6, 64 → 56) timed all 88 nested runs on the default bound; the longest took 3.1 s. *The 88 rows and the 3.1 s are the 0.11.6 run's (`t22f-make-times-instrumented-2-0116.txt`, longest 3146 ms): the 0.12.5 run's log has no limit column, and matched to the 0.11.6 run's rows 54 of its rows are default-bound only (longest 3158 ms) and 36 cannot be told apart (the re-measure).* A minute is six times the 10 s a nested run exceeded at load ~200. Cost: a nested run that truly hangs is stopped after 60 s instead of 10 s.
- **The widening undone** (R4, decision 17): `__NVIM_LOG_FILE_WANT` left the global `unexport` line for `test test_file: override __NVIM_LOG_FILE_WANT :=`. *Wrong on two routes of three, as the re-measure measured: the command line and `MAKEFLAGS` reached every Neovim of the run, where `5239471`'s `unexport` had held; the records review had measured the environment route only, so `5ec1d7d`'s "as the records review measured" was wrong too. Fixed in the correction.*
- **Records**: R2, R5, R6, R7, R8, R10, R12, R13, R14 corrected above, in place; R9 in the `Makefile`; R3's five places added to *Open threads*.

**Fixture names** (R13): the names the touched test files pass to `fixture.write`, `fixture.directory`, `suite()` and `suite_counting_files_at_once()` — the packet's 22, as the records review checked, and the round's new ones — are each used by one test file only (grep).

**Seen red on `5239471`, by assertion, on 0.12.5 and on 0.11.6** (`t22f-red-*.log`):

| test | red |
|---|---|
| `test_runner_verdict.lua` › a test file whose Neovim ends by a signal › fails the run (`sigkill`, `sigsegv`) | `Left: 0` |
| › … › once every case passed fails the run (`sigkill`, `sigsegv`) — the round's own pin: the signal alone tells | `Left: 0` |
| › a test file whose own VimLeavePre defeats its runner › fails the run (two shapes) | `Left: 0` |
| › a test file that ends the runner over its server › fails the run | `Left: 0` |
| › a test file that did not pass › is named on a line that begins FAIL in (nine endings: no load, no case, `qall!`, `0cquit`, `os.exit`, `MiniTest.stop()`, a stall, the limit, a signal) | no such line: `Fails (0) and Notes (0)` only |
| › a test file's output › cannot take the place of the summary | `Left: { "Total number of cases: 1227", "Fails (0) and Notes (0)" }` |
| › a test file's output › held open by a process it started does not keep the run going | `Left: 2` (the limit, 10 s) |
| `test_runner.lua` › the run time limit › is refused … (`nan`, `inf`) | `Left: 0` |
| `test_runner_homes.lua` › a run › whose homes directory another run makes at the same moment runs its files | `Left: 2` (E739 at `run_tests.lua:330`) |
| › a run › stopped by a test at its time limit leaves no home behind | `Left: { … }` (the run directory still there) |

**Pins of correct code, each red under its literal mutant** (the reviewers' cases, adopted and credited; rows in `t22f-mutants.txt`, 0.12.5 and 0.11.6, loads 21–145):

| test | mutant | 0.12.5 | 0.11.6 |
|---|---|---|---|
| make test › fails when a case of its last file fails while every other passes (I1) | V1 | `Left: 0` | `Left: 0` |
| make test › exits zero when every case of several files passes (I5) | V11 | `Left: 2` | `Left: 2` |
| the run time limit › bounds the whole run, not each file (I2) | V2, adapted to the `uv.spawn` start | `Left: 0` | `Left: 0` |
| AINEO_TEST_JOBS › of 2 runs two test files at once, and no more (I4; replaces "bounds how many") | V6 | `Left: { 3, { 1, 1 } }` | the same |
| a run › of make test in a checkout with no .tests/ yet tells no Neovim of a missing log (I3) | V3 | `Left: 2` | survives: 0.11.6 makes the directory itself, cannot be red |
| a run started inside another › gives its file a home apart from the outer file (I6, rewritten as a run inside a run whose inner file shares the outer's name) | H1, outer runner pristine | *no* equality on `…/homes/run/1-test_outer/state/nvim` | the same |
| a test file's output › is relayed (I9) | V8, adapted: the relay removed | `Fragment: printed by a case` | the same |

*I9 was not fixed by this pin, as the re-measure measured: I9 named the relay of a file's **stdout**, and the pin prints with `print()`, which a headless `nvim -l` writes to stderr, so dropping a file's stdout (Ma2) survived the whole suite. The correction renames it "printed is relayed" and adds "written to stdout is relayed".*

Under H1 with the mutated runner as the outer runner too, the whole narrowed run ended rc 2 with `Total number of cases: 0` — the nested run truncating the outer file's records, a crash, not a kill; the pristine-outer run is the kill.

**Mutants of the round's own code** (0.12.5):

| id | literal edit | result |
|---|---|---|
| N1 | `ending.code == 0 and ending.signal == 0` → `ending.code == 0` | killed, assertion: the two "once every case passed" cases, `Left: 0` |
| N2 | `return #cases > 0 and vim.iter(cases):all(case_passed)` → `return true` | killed, assertion: both VimLeavePre shapes, `Left: 0` |
| N3 | the runner's `if not verdict_reached then vim.cmd('cquit 1') end` removed | killed, assertion: the server case, `Left: 0` |
| N4 | `relay(io.stdout, table.concat(unnamed_failures, '\n'))` removed | killed, assertion: all nine endings |
| N11 | `if not (file_passed(file_run) or vim.iter(cases):any(case_failed)) then` → `if not file_passed(file_run) then` | survived the endings group; killed, assertion, by make test › prints one summary (a fourth line `FAIL in tests/test_b.lua`) |
| N5 | the file output relayed on stdout instead of stderr | killed, assertion: `{ "Total number of cases: 1227", … }` |
| N6 | `not (limit_ms > 0 and limit_ms < math.huge)` → `not (limit_ms > 0)` | killed, assertion: `inf`, `Left: 0` |
| N7 | the same → `limit_ms <= 0 or limit_ms == math.huge` | killed, assertion: `nan`, `Left: 0` |
| N8 | `make_directory(homes)` → `vim.fn.mkdir(homes, 'p')` | killed, assertion: the race case, `Left: 2` |
| N9 | `make.lua`: `signal_process_tree(process.pid, 'sigterm')` → `'sigkill'` | killed, assertion: `Left: { … }` (it left one `run-*`, removed by hand) |
| N10 | the `test test_file: override __NVIM_LOG_FILE_WANT :=` line removed | killed, assertion, on both versions: `test_isolation.lua` › keeps a parent Neovim's log fallback out, `Left: 2` |

**Whole suite at `1083de2`** (the code pushed; the pushed head adds this note), default 8 jobs, `t22f-whole-final.txt`: 0.12.5, 10 runs, all rc 0, 1276 cases, `Fails (0)`, 171–174 s, loads 67–182 at the starts, no `run-*` left by any; *not so: run 1's listing, which names every `run-*` present after the run and not only those it made, shows `run-ZkRSjA`. The only run recorded to leave one before it is the N9 mutant, at 0:58, in the same `.tests/homes` (the fix round's report: "N9's mutant left one run-* (1-waiting)"); the six runs between (the 0.11.6 instrumented whole run, two `green60` files, S1, W1, R1) are not recorded to leave any, and run 2's listing shows none, so it was removed by hand during run 2. Most probably N9's; the logs cannot name it. Runs 2–13 left none;* 0.11.6, 3 runs, the same, 172–174 s, loads 66–132. 1276 = 1249 + the round's 27 new cases. The two cases that met `make.run`'s 10 s bound — `test_runner.lua`'s `vim.wait(1e9, …)` case and `test_runner_parallel.lua`'s busy case — failed in 0 of these 10 0.12.5 runs each (and 0 of 3 on 0.11.6); so did `test_health.lua`'s Ctrl-C case and `test_report_links.lua`'s long line.

**With `origin/dev` merged** (`d7714d6`, in a scratch worktree, never into the branch): one whole run on 0.12.5, rc 0, 1377 cases, `Fails (0)`, 187 s, load 22 at the start; T23's eight `tests/test_git_*.lua` files all passed under this runner. `git merge-tree --write-tree origin/dev HEAD` reports no conflict.

**Limits recorded.** A file's Neovim SIGKILLed from outside leaves its child Neovims and `vim.system` processes running: by the time its exit is seen they are no longer its descendants. `AINEO_TEST_RUN_LIMIT_MS=1e18` (or any finite number) is honoured as given. A runner SIGKILLed from outside, or a nested run `make.run` has to SIGKILL after its 5 s, leaves its `run-*` home. A test file that has the runner run `os.exit()` over its server would end it without its `VimLeavePre` (not measured; nothing in the suite but the isolation probe connects to the runner). *Measured by the re-measure, with two more routes: `os.exit(0)` over the server, or its `VimLeavePre` cleared then `qall!`, ends the run with exit 0 and no summary, leaving that file's Neovim and the run's `run-*`; `io.stdout:write` over the server puts forged `Total`/`Fails` lines ahead of the real ones. And SIGSEGV or SIGABRT of a file's Neovim from outside leave its children as SIGKILL does. The correction records these as limits (see Correction).*

## Correction (2026-09-28)

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`), a fresh agent taking over PR #85 for one bounded correction. **Branch:** `feature/t22-parallel-runner`, from `3eac789`. It works the re-measure's findings 1–9 (`remeasure85-report.md`) under the orchestrator's decisions, and reopens none of the fix round's.

**What changed.**

- **The log fallback on every route** (finding 1): `export __NVIM_LOG_FILE_WANT` beside the `test test_file: override`, the re-measure's fix. The `Makefile`'s "whatever its origin" was false and now names the three routes; `5ec1d7d`'s "as the records review measured" was wrong, and `17bf19b`'s message says so.
- **A file that cannot be started** (finding 2): a failed `fs_open` of its output or a failed `uv.spawn` is recorded and handed to `on_exit` from the event loop, so the run goes on; its line says `it could not be started: <error>`. The re-measure's fix.
- **Four checks pinned** (findings 4 and 6): the re-measure's pins, adopted. I9's case is renamed "printed is relayed"; "written to stdout is relayed" is I9's stdout pin.
- **Limits recorded in the runner's docstring** (findings 3, 5, 8): its two over-claiming sentences narrowed, and a *Not guarded* paragraph. The orchestrator's decision: a limit, not a fix — unsetting `NVIM` for each file closes the channel, but turns 8 of `test_isolation.lua`'s cases red.

**Seen red on `3eac789`'s code, by assertion, on 0.12.5 and 0.11.6** (`t22c-red-*.log`):

| test | red |
|---|---|
| `test_isolation.lua` › make test_file › keeps a parent Neovim's log fallback out of its runner and children › handed (on the command line; in MAKEFLAGS) | `Left: 2` each; the environment row green, as at `3eac789` |
| `test_runner_verdict.lua` › a test file whose output cannot be opened › does not keep the run going | `Left: { 2, { "Total number of cases: 1", …, "FAIL in tests/test_c.lua", "…in main chunkthe test run did not finish within 20 s" } }` |
| › a test file whose output cannot be opened › is named, saying why | no line beginning `…: it could not be started: ` (the head said `it never started`) |
| › a test file whose Neovim cannot be started › does not keep the run going (built here: the first case replaces `vim.uv.spawn` in the runner over `$NVIM`) | the same stall, `…did not finish within 20 s` |

**Pins of correct code, arrived green, each red under its literal mutant on both versions** (narrowed copies under `.tests/`, `t22c-mutants.txt`):

| test | mutant (literal edit) | kill, 0.12.5 and 0.11.6 |
|---|---|---|
| `test_runner.lua` › a run stopped at its time limit › ends soon after it, even when its recipe ignores SIGTERM | Mf: `make.lua`'s `  if not ended then\n    signal_process_tree(process.pid, 'sigkill')\n  end\n` removed | `Left: { 124, false }` |
| `test_runner_verdict.lua` › a test file whose records are gone › fails the run | Mi: `return #cases > 0 and vim.iter(cases):all(case_passed)` → `return vim.iter(cases):all(case_passed)` | `Left: 0` |
| › a test file whose own VimLeavePre defeats its runner in its last case › fails the run | Mj: `    and vim.startswith(case.exec.state or '', 'Pass')\n` removed | `Left: 0` |
| › a test file's output › written to stdout is relayed | Ma2: `    stdio = { nil, output, output },` → `    stdio = { nil, nil, output },` | `Fragment: written to stdout by a case` |

**Mutants of the correction's own code**, both versions, each killed by an assertion:

| id | literal edit | killed by |
|---|---|---|
| EXP | `export __NVIM_LOG_FILE_WANT\n` removed | the command-line and `MAKEFLAGS` rows, `Left: 2` |
| AS1 | the `fs_open` failure branch → `  local output = assert(vim.uv.fs_open(file_run.output_path, 'w', OUTPUT_FILE_MODE))` | both output cases (`Start: …it could not be started: `; `Left: { 2, { "Total number of cases: 1", … } }`) |
| AS2 | the spawn failure branch → `  file_run.pid = assert(process and pid_or_failure, pid_or_failure)` | the Neovim case, the stall |
| AS3 | `why_not_passed`'s `start_failure` branch removed | is named, saying why |
| AS4 | `vim.schedule(on_exit)` removed from `record_start_failure` | both "does not keep the run going" cases (`…did not finish within 20 s`) |

**Mc, reasoned rather than pinned.** `if file_run.pid and not file_run.ending then` → `if file_run.pid then` signals the pid of a file whose Neovim was reaped; the input that separates the two is that pid reused by another process inside one run, which neither the re-measure nor this correction could build. Mk (the ending recorded in the scheduled callback) rests on the same property.

**Records corrected** (finding 7), in place above: the `__NVIM_LOG_FILE_WANT` decision and fix-round bullets; the 88 nested runs and their 3.1 s, which are the 0.11.6 run's; I9, which the fix round's pin did not fix; `run-ZkRSjA` in run 1's listing, most probably the N9 mutant's; the limits the re-measure measured. The fix round's report (`t22f-report-fix-round.md`) counted "30 reds, `test_runner_verdict.lua` (19)": measured by the re-measure, it is **22 reds** on `5239471`, 18 of them in `test_runner_verdict.lua` (its "is relayed" case, I9's pin, was green there), plus **8 pins of correct code that arrived green** (I1, I5, I2, I4, I3, I6, I9 and W1's naming case). This note and the pull request listed the 22 and stated no total.

**Limits** (findings 3, 5, 8, 9 — the docstring's *Not guarded* and *What it prints* for the first three):
- Through the runner's server (`$NVIM`), a test can end the run with exit 0 and no summary — `os.exit(0)`, or its `VimLeavePre` cleared then `qall!` — leaving that file's Neovim running and the run's `run-*`; it can write forged `Total`/`Fails` lines to the runner's stdout ahead of the real ones. Measured by the re-measure on both versions; each needs test code that means to.
- A case that writes a passing record for every case of its file to `arg[2]` and ends its Neovim through a raising `VimLeavePre` of its own passes its file, at `5239471` as at the head.
- A file named by a failing case gets no `FAIL in <file>:` line, so a signal that ended it, or its still running at the limit, is not said; the output of a file still running at the limit is never relayed.
- `make.run`'s 60 s bound: a mutant that hangs every nested run takes `test_runner.lua` (38 nested runs on the default bound, the 0.11.6 instrumented run) past the outer run's 16-minute limit, where 10 s cost 380 s; `test_deps` has 13 such runs, `test_runner_parallel` 12, `test_isolation` 9, `test_runner_verdict` 9, `test_runner_homes` 7.

**Whole suite at `b935a99`** (the code pushed; the pushed head adds this note), default 8 jobs, one run per version, one after the other (`t22c-whole.txt`): 0.12.5 rc 0, **1285** cases, `Fails (0)`, 173 s, load 23.6 → 29.7; 0.11.6 rc 0, 1285, `Fails (0)`, 171 s, load 29.7 → 33.1; no `run-*` in `.tests/homes` before or after either. 1285 = 1276 + 9: `test_isolation.lua` 23 (+2), `test_runner_verdict.lua` 25 (+6), `test_runner.lua` 44 (+1). `git merge-tree --write-tree origin/dev HEAD` (`d7714d6`) printed a tree id only: no conflict.

## Commits

*Recorded after the merge.*
