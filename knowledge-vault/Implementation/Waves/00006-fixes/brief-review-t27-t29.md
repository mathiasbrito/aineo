# Brief review — T27, T28, T29 (wave 6's last packets)

**Dimension:** brief. **Subject:** PR #92, `knowledge/w6-t27-t29` at `4aca93e`, on `origin/dev` `40324f7` (`git merge-base --is-ancestor origin/dev HEAD` true; one commit on top). **Reviewer:** `reviewer`, Opus, worktree `agent-a3c0b2b647b4c5a5a`, resource `review_brief_t27_t29`.

**Method.** Every task id, path, symbol, line range, count and attribution in the three briefs and the plan's new sections was read at `40324f7` (the code roots are identical at `4aca93e`: `git diff --stat 40324f7 HEAD -- lua plugin tests scripts doc Makefile` prints nothing). Probes ran on 0.12.5 (host `nvim`, LuaJIT 2.1.1788856981) and 0.11.6 (`env -u VIMRUNTIME PATH=<orchestrator's 0.11.6 bin>:…`, LuaJIT 2.1.1741730670), headless, through `make test_file` where they started Neovims with a home, or `nvim --clean --headless -l` for the bytecode script exactly as the evidence runs it. No whole suite ran. The real `claude` never ran. Every scratch file is under this worktree's `.tests/` (prefix `brief-`).

The question: **would an implementer acting on these briefs be misled?** Yes, on one point shared by all three (finding 1), which an implementer bound by its charter cannot follow, and in T29 on the measurement plan itself (T29-1 to T29-4).

---

## Findings across the three briefs

### 1. CONFIRMED (high) — the testing strategy contradicts D26 and the binding documents; an implementer must either ignore the brief or break its charter

The briefs say:

- T27 (`brief-t27-bold-recipe.md:75`): "**Before you push: those two files again, on both versions. Not the whole suite.**"; `:76` "Mutants: run each on `tests/test_report_colours.lua` alone, never on the whole suite."
- T29 (`brief-t29-timing-cases.md:77`): "Before you push: those two files, on both versions, idle and under your load. Not the whole suite."; `:78` "Mutants: on these two files only, never on the whole suite."
- T28 (`brief-t28-harness-docstrings.md:54`): "**Run no test file and no suite.**"

What binds the implementer:

- D26 (`Planning/aineo — v1 agent console.md:63`): "the whole suite at the end of each step that pushes code and in the orchestrator's verification; a mutant on the test files that exercise the code it breaks, and on the whole suite only when it survives there".
- Root `CLAUDE.md:43`: "Run the whole suite (`make test`) once before each push, on the tree you push, on every Neovim version the task names".
- `.claude/agents/implementer.md:56`: "Before each push, run the whole suite on every Neovim version your brief names"; `:55`: a mutant that survives its group and its files is re-run "on the whole suite, before it is recorded as surviving" (the small-fix exception does not apply: all three are *regular*).
- `.claude/agents/implementer.md:18`: "The project's binding documents — the root `CLAUDE.md` … rank above everything else: if a task, a brief or a convenience conflicts with one, the binding document wins and you say so in your report."
- Root `CLAUDE.md` (*Read this first*): D# rows "change only through a converge round with the user, superseded by a new ID".

So the implementer either runs the whole suite anyway (the brief's optimisation does nothing, and it reports a spec conflict) or follows the brief against D26 and its charter. The commit message's "D26 itself stands" is false as written: the push clause and the mutant clause of D26 are exactly what the briefs remove.

It also reaches the orchestrator's own step: `orchestrate/SKILL.md:150` verifies the laid-over tree because "the head alone was run by the step that pushed it" — the premise this plan removes — and its "compare every number with the report" would have no whole-suite counts in any pull request to compare with. The reviewer charter's rule ("whole-suite counts, which the orchestrator's verification checks … and compares its counts with the pull request's") has no subject either.

The user's 2026-10-04 words ("Please be carefull with the testing strategy, since each run is taking too long, try to optimize") ask for an optimisation; they do not say which part of D26 to drop.

**Correction, before any dispatch, one of:**
- (a) put it to the user as a decision — "for packets confined to test files and the help, skip the per-packet whole suite before push and run it once on the merged tree" — closed with `AskUserQuestion`, recorded as a new D# row superseding D26's push and mutant clauses for that class, and landed with an `ai/` change to `CLAUDE.md:43` and `implementer.md:55–56` (and SKILL §6's premise); or
- (b) keep D26 as it stands: each packet runs the whole suite once per version before its push (197 s per version on this host, `verify85.txt:8–13`), and the briefs drop "Not the whole suite", "never on the whole suite" and T28's "no suite".

As the implementer, I would refuse those three instructions, run the whole suite before pushing, and report the conflict.

### 2. CONFIRMED (medium) — "a change confined to a test file, or to the help, cannot change another file's outcome" is false as a general claim

The plan (*Packet T27*, the testing strategy) and the T27/T29 briefs give it as the reason to skip the whole suite. Since T22 each file has its own Neovim and home, but these channels still cross files:

- **One fixture namespace for the whole run.** `tests/helpers/fixture.lua:9` puts fixtures in the checkout's `.tests/fixtures/`, not the file's home; `M.directory(name)` (`:16–23`) deletes and recreates `.tests/fixtures/<name>`. A case that calls it with a name another file uses deletes that file's fixtures while it runs. The docstring of `M.write` (`:26–30`) says "test files run side by side, and some write the same fixture". No literal name collides today: I listed every `fixture.directory`/`fixture.write` literal across `tests/`.
- **The runner's collection.** `scripts/run_tests.lua:149` collects `tests/**/test_*.lua`, which includes `tests/helpers/`. A new helper named `test_*.lua` becomes a test file, and the run fails because it contributes no case.
- **The host.** Files run side by side on one host. A test file made heavier changes the load that other files' timing-sensitive cases see. T22's flakes table (`Sessions/2026-09-27 — T22 parallel runner.md:153`) shows `tests/test_health.lua:336` (`vim.wait(100)` under 1000 ms) failing beside five or six suites.
- **The help.** `tests/test_doc.lua:8` reads `doc/aineo.txt` (a copy under fixtures, `:helptags`, 78 columns, the tags). After T27, `tests/test_report_colours.lua` will read it too. Nothing else does: `test_layout*.lua` run `:help`, which opens Neovim's own `help.txt`, and `test_health.lua` only prints `:help |…|` strings.
- **Nested runs: REFUTED as a channel for T27 and T29.** `test_runner*.lua` and `test_deps.lua` run fixture suites only: `make.lua:1–7,15` starts from `.tests/empty`, and `suite()` writes into `.tests/fixtures/<name>/tests/`. They never run the real `tests/`. They do copy the real `scripts/` (`test_runner_homes.lua:97`), and their probe files `dofile` the real `tests/helpers/child.lua` (`test_runner_homes.lua:54`, `test_isolation.lua:40`).

**The test files each packet's change can reach:**

| packet | its change can reach |
|---|---|
| T27 | `tests/test_doc.lua`, `tests/test_report_colours.lua`. No other file reads the help. |
| T28 | **every test file**: `scripts/minimal_init.lua` is the init of the runner, of each file's Neovim and of each child; `child.lua` is loaded by most files and by `test_runner_homes`'s and `test_isolation`'s probe files; `claude_session.lua` and `entry_editor.lua` by several. That is why its proof must be the bytecode check, and it holds (T28-1 to T28-3). |
| T29 | `tests/test_report_paths.lua`, `tests/test_report_links.lua`, its new helper; any file sharing a fixture name with it; timing-sensitive files under side-by-side load if the new form adds work. |

**Correction:** qualify the sentence in the plan and in both briefs. Tell T29 to use fixture names of its own, not to name the helper `test_*.lua`, and not to add work to the timed cases.

### 3. CONFIRMED (medium) — T29's load phases share the host with T27, T28 and their reviewers

T29 is told to load every core and to measure "idle", with all three packets dispatched at once. Its "idle" baseline is not idle while T27 runs its files, and the load that actually produced the reds (five or six whole suites side by side, T29-3) would disturb T27's runs and the reviews. The six rules do not cover CPU, but the plan dispatches the packets together.

**Correction:** run T29's load phases when no other agent runs (dispatch T29 after T27 and T28 land, or tell it to wait for a quiet host), and tell T27 that a failure seen while T29 loads the host is re-run alone (its brief already says to re-run once).

---

## T27 — the help's bold recipe

- **T27-1 REFUTED (the facts hold).**
  - The recipe: `doc/aineo.txt:493–496` (see T27-6).
  - `define_report_colours()` (`lua/aineo/report/colours.lua:50–54`) runs `:highlight default link` for each group. It is called from `show_rendering()` (`lua/aineo/report/init.lua:196–199`) whenever a rendering has colours: each report, and each time the Report is shown again.
  - The two pins exist under those names, `tests/test_report_colours.lua:500` and `:518`; so does the recipe case, `:466`.
  - Code identity holds: `git diff --stat 176fd21 40324f7 -- lua plugin tests scripts doc Makefile` printed nothing.
  - `habamax` runs `:highlight clear` on both versions: it sources `$VIMRUNTIME/colors/vim.lua`, whose line 12 is `vim.cmd.highlight('clear')`. Its own `hi clear` line is commented out.
  - The aineo probe reproduced on both versions through the harness, and its output matches the attachment's (`learnings-probes-2026-09-28.txt:798–811`): link NONE → empty → `@markup.strong` after `habamax` → `@markup.strong` after a definition → empty → `@markup.strong` after `default`.
  - The task line is quoted verbatim apart from a final full stop the plan row does not have; the same holds for T28 and T29.
- **T27-2 REFUTED (the boundary can hold).** `autocmd ColorScheme * highlight link AineoReportStatusBold NONE`, plus the link itself, keeps the group empty through `:colorscheme habamax`, the first report, a next report, `:colorscheme default` and a report after it, on 0.12.5 and 0.11.6 (`.tests/brief-hlprobe-0{12,11}.txt`). No `lua/` change is needed. The ColorScheme pins count in a child that `report_editor.start()` restarts for each case (`tests/helpers/report_editor.lua:16`), so a recipe case cannot leak into them.
- **T27-3 MISSING (low) — the recipe does not survive a bare `:highlight clear`.** Measured on both versions: no `ColorScheme` event fires, the link to `@markup.strong` returns, and the next report keeps it. The task asks only about `:colorscheme`, but the paragraph after the recipe (`doc/aineo.txt:499–504`) speaks of "`:colorscheme` or `:highlight clear`". The brief should tell the implementer that the help must not suggest the recipe survives a bare `:highlight clear`.
- **T27-4 MISSING (low).** "What the recipe must do" lists "after `:edit` in the Report", but *The test* never asks for `:edit`. The parametrized case *let the user turn a [status]'s bold off, its colour kept, through the next report* (`:443–464`) also runs `highlight link AineoReportStatusBold NONE`, and the brief does not name it.
- **T27-5 MISSING (low) — records the change makes false are not named, nor who corrects them.**
  - `Learnings/highlight default link overrides attributes set to NONE, not a link to NONE.md` › *Why it matters* (the bullet "This reaches aineo's own recipe …").
  - `Projects/aineo.md:96`.
  - The retrospective's open thread (`Sessions/2026-09-26 — Wave 6 retrospective.md:586`).

  Say that the knowledge pass corrects them, so the implementer neither edits them nor reports them missing.
- **T27-6 CONFIRMED (low).** "`doc/aineo.txt:492–496`": line 492 belongs to the sentence before. The recipe is lines 493–496.
- **T27-7 CONFIRMED (low, plan).** The plan says the measurement was "reproduced by the records reviews of PRs #90 and #91". The records (`Projects/aineo.md:96`, retrospective `:586`) say PR #90's review reproduced it, and PR #91's measured a scheme that does not clear. The brief attributes this correctly.
- **Instructions I would refuse:** "Not the whole suite" (`:75`) and "never on the whole suite" (`:76`), per finding 1.

**Verdict T27: dispatch after these corrections.** Finding 1 must be settled. T27-3 to T27-7 are wording.

## T28 — the harness docstrings

- **T28-1 REFUTED (the evidence holds, and every attack on "ignores comments" failed).** The evidence's `cmp.lua`, byte for byte, on `tests/helpers/child.lua` and its variants (`.tests/brief-bc/`, built by `make-variants.lua`), on both versions:

  | variant of `a.lua` | edit | 0.12.5 | 0.11.6 |
  |---|---|---|---|
  | b | two docstring lines added, one reworded (the evidence's b) | identical=true | identical=true |
  | d | `'scripts'` → `'script'` (the evidence's d) | false | false |
  | e | `local unused = 1` added (the evidence's e) | false | false |
  | f | `--- a comment holding ]] and [[ and ]=] and --[[` added | true | true |
  | g | `--[=[ a long comment ]] that holds a ]] ]=]` added | true | true |
  | k | `---@param child table` → `---@param child nonsense_type<<` | true | true |
  | l1→l2 | `if false then _G.x = 1 end` → `… = 2 end` (dead branch) | false | false |
  | cs_n | `-- a comment-looking line` added inside a `[[ … ]]` string of `claude_session.lua` | false | false |
  | cs_o | a trailing space added inside that string | false | false |

- **T28-2 CONFIRMED (medium) — the bytecode check does not catch every code edit; the brief's step 3 does, but the brief does not give its command.**

  | variant | code edit | 0.12.5 | 0.11.6 |
  |---|---|---|---|
  | h | local `MINIMAL_INIT` → `THE_MINIMAL_INIT` (both uses) | identical=true | identical=true |
  | j | parameter `extra_args` → `more_args` | true | true |
  | i | `child.restart(vim.list_extend(…))` broken over three lines | true | true |
  | m1→m2 | `_G.y = 1 + 1` → `_G.y = 2` | true | true |

  All four keep behaviour, so "no executable change" still holds. But:
  - the plan's T28 verification mutant, "one code line changed in each of the five files, which the bytecode check must catch", fails for a rename or a reflow;
  - step 3 says "Paste the command and its empty result" without giving the command.

  Measured on these variants, this filter prints nothing for b, prints the changed lines for h and i, and prints nothing for cs_n, which the bytecode check catches. The two checks are complementary:

  ```
  git diff -U0 origin/dev -- scripts tests | grep -E '^[-+]' | grep -Ev '^(\+\+\+|---) (a/|b/|/dev/null)' | grep -Ev '^[-+][[:space:]]*--'
  ```

  **Correction:** give this command in the brief, and name the plan's T28 mutants literally as a constant or statement change (the evidence's d and e), with a rename checked against step 3.
- **T28-3 REFUTED (nothing reads what a comment edit changes and the bytecode cannot see).**
  - `---@` annotations: selene 0.31 with the project's `selene.toml` and StyLua 2.5.2 `--check` give the same result on k as on a (0 errors, 0 warnings, no diff). Neither reads them, and nothing else in the tooling does.
  - The five files hold no `selene:` or `stylua:` directive for an edit to remove, and `make lint` (step 2) covers any added one. `make lint` is green on `40324f7`.
  - No test asserts a line number of these files or reads their text: I grepped for `<file>.lua:`, `currentline` and the `readfile`/`io.open` users. `test_runner_homes.lua:97` copies `scripts/` and runs it, which comments cannot affect.
  - The only `error()` in the five files (`entry_editor.lua:78`) is matched by no test, so a shifted line number changes no outcome.
- **T28-4 REFUTED (the facts and the six places hold).**
  - `run_tests.lua:41` "runs no test code".
  - `start_file()` (`:291–303`) spawns `-u minimal_init.lua -l run_test_file.lua` with `file_environment(home)` (`:247–262`): the `XDG_*` variables, `CLAUDE_CONFIG_DIR`, `NVIM_LOG_FILE` and `NVIM = vim.v.servername`. Each home is under `.tests/homes/run-XXXXXX/<n>-<name>` (`:505–517`).
  - A child inherits its file's home: `.tests/brief-child-env.lua` asserted the child's six variables equal its file's, under `.tests/homes/run-`, green on 0.12.5 and 0.11.6.
  - All six places read as the table says at those lines: `minimal_init.lua:1–2` and `:10–12`, `child.lua:4–6`, `entry_editor.lua:9–10`, `claude_session.lua:6`, `test_entry_guard.lua:14`.
  - No seventh place: `test_isolation.lua:24` ("run in the test runner") is true, since that chunk runs over RPC in the runner. `Makefile:27` is true too.
  - Wording nuance for the table's `:10–12` row: the runner still gets `CLAUDE_CONFIG_DIR` from the Makefile, so the new docstring keeps the Makefile for the runner and the runner for the files.
- **T28-5 MISSING (low) — slots.**
  - There is no *What was decided already*: the user's "check 1 to 3 and close 6", and item 2 as it was put on 2026-10-01, are quoted nowhere in PR #92.
  - *Read first* omits `knowledge-vault/Projects/aineo.md`.
  - There is no generic spec-conflict line. The charter carries it, so this misleads no one.
- **T28-6 MISSING (low).** The brief does not say how to compare against `origin/dev`. The script compares every argument with its first, so one call over the five heads prints `false`. Give it, for example, as `git show origin/dev:<path> > .tests/t28-base-<name>.lua`, then one call per file, the base first.
- **Instruction I would refuse:** "Run no test file and no suite" (`:54`), the suite half, per finding 1.

**Verdict T28: dispatch after these corrections.** Finding 1 must be settled. T28-2 and T28-6 are small, and T28-5 is slots.

## T29 — the timing cases

- **T29-1 CONFIRMED (high) — the first "slowing mutant", and the plan's first T29 verification mutant, cannot slow the timed case.** The case's input is 209 674 *distinct* paths, so one file-system check per occurrence equals one per distinct path. Measured with the literal edit `    if answers[path] == nil then` → `    if true then` (`lua/aineo/report/init.lua:131`), on a narrowed probe of the timed step (`.tests/brief-paths-probe.lua`, 0.12.5):
  - checks: 209 674 on arrival and 209 674 on `:edit`, with the mutant and without;
  - wall time: arrival 0.94 → 0.94 s, `:edit` 1.03 → 1.02 s.

  It is equivalent on this input under any measure, wall or CPU. Only the counting cases kill it (`test_report_paths.lua:355`, `:369`), never a timing case. **Correction:** replace it with the mutants these two cases exist to kill, both recorded literally:
  - **T17's M10** (`Sessions/2026-09-26 — T17 Report paths.md:183`): `paths.lua:85` `local first, run_last = text:find(RUN, position)` → `local rest = text:sub(position)` / `local first, run_last = rest:find(RUN)` / `if first then` / `first, run_last = first + position - 1, run_last + position - 1` / `end`. It killed the case at arrival 22.4 s.
  - **T10's X11** (`Sessions/2026-09-26 — T10 Report links.md:267`): after the bracket branch's `last = last - 1` (`links.lua:71`), add `candidate = candidate:sub(1, last)`. It killed the 1 000 000 `)` row at arrival 72.4 s.

  Both anchors still exist on `40324f7`, and both mutants are CPU-bound. Add T10's session note to *Read first*.
- **T29-2 CONFIRMED (high) — the candidate's premise, that CPU time is about the same idle and under load, fails on this host when the child runs on an efficiency core.** The host is an Apple M1 Max, 8 performance and 2 efficiency cores (`sysctl hw.perflevel0/1.logicalcpu`). The paths step, measured with `vim.uv.getrusage()` (user plus system) beside `hrtime`:

  | condition | version | arrival cpu / wall | `:edit` cpu / wall |
  |---|---|---|---|
  | quiet host (load ~8–11) | 0.12.5 | 0.94 / 0.94 s | 1.03 / 1.03 s |
  | quiet host | 0.11.6 | 0.95 / 0.96 s | 0.94 / 0.94 s |
  | `taskpolicy -b make test_file …` (background QoS, which macOS runs on the efficiency cores) | 0.12.5 | **2.49** / 11.21 s | **2.52** / 6.38 s |
  | the same | 0.11.6 | **2.40** / 5.58 s | **2.30** / 6.60 s |

  The same work costs 2.3–2.5 s of CPU on the slower cores, above the 2 s bound. Whether a heavily loaded host moves the child there is for the packet to measure. The brief should state the fact, and `taskpolicy -b` as a way to probe it, because of T29-3.
- **T29-3 CONFIRMED (high) — the brief's load does not produce the red.** "Load all cores with busy processes", with 12 and then 40 `sh -c 'while :; do :; done'` processes started by `.tests/brief-load.lua` and stopped by their handles (load 22–40 by `uptime`), left the step at arrival 0.90 s and `:edit` 1.00 s, CPU equal to wall, under 2 s, on 0.12.5. The scheduler kept the child on a fast core. An implementer following the brief can therefore measure "CPU time about the same idle and under heavy load" (true under busy loops) without ever reproducing the condition that fails the case. The record of that condition: five or six whole suites side by side, loads 128–253 (`T22 parallel runner.md:154–155`).

  **Correction:** require the red first, under a load that fails today's case, then the CPU time in that same condition. Say that busy loops did not reproduce it here (this review). Name the efficiency-core case (T29-2) as a condition CPU time must survive, or report that it does not.
- **T29-4 MISSING (medium) — CPU time cannot see a drawing that waits.** A drawing that blocks — a sleep, a wait on I/O, `fs_stat` on a slow or network file system — "really exceeds the bound" in wall time and passes a CPU-time bound. The brief's *Nothing hidden* covers work handed to another process or thread, not waiting. That is a narrowing of the guarantee. Name it, ask for a waiting mutant (for example `vim.uv.sleep(3000)` inside the step) with its result, and have the packet report whether that loss is acceptable.
- **T29-5 REFUTED (the facts hold).**
  - The test file: `TIMED_DISTINCT_PATHS`, `DISTINCT_PATHS_IN_A_LINE = 209674` (distinct, since 209 674 < 62³), `TIME_LIMIT_SECONDS = 2` in both files, and `hrtime` around arrival and `:edit`.
  - The records: MR159 "about 1–1.2 s" and MR133 (`Review/2026-09-24 — v1 MVP readings review.md:305`, `:235`); RP4 "within 2 s on this host, on both versions" (`brief-t17-report-paths.md:29`); loads 131, 115 and 29 failing, 95 and 38–48 passing (retrospective `:588`).
  - The runs: 1 of 1434 failing on 0.11.6 (`verify85.txt:11–14`); every run beside five or six whole suites failing (`T22 note:155`); the links case 2 of 10 at loads 128–253, `arrival = "5.2 s"` (`T22 note:154`, on the `('https://a', ')', 1000000)` row).
  - "Only these two cases bound aineo's drawing" holds. The `hrtime` users also include `tests/helpers/health.lua` and `tests/helpers/fake_claude.lua`, which bound the health check's and the fake's waits, not drawing.
- **T29-6 CONFIRMED (low).** The line ranges are off: the paths case is 384–431, not 385–429; the links case is 339–387, not 338–380, and 338–380 cuts the case in two. The links "case" is four parametrized rows (`:368–375`), and only the 1 000 000 `)` row is on record as flaking.
- **T29-7 MISSING (low).** *Read first* omits `knowledge-vault/Projects/aineo.md` and T10's session note (see T29-1).
- **Instructions I would refuse:** "Not the whole suite" (`:77`) and "never on the whole suite" (`:78`), per finding 1. I would follow "Load all cores with busy processes", but not trust it as the red (T29-3).

**Verdict T29: dispatch after these corrections, and not in parallel with T27's runs** (finding 3). The corrections are substantive: finding 1, T29-1 (new mutants), and T29-2 to T29-4 (the measured facts the packet needs so it does not prove load-independence under a load that never reproduces the flake).

---

## Baseline — CONFIRMED, its evidence MISSING (low)

- **Code identity.** `git diff --stat 176fd21 40324f7 -- lua plugin tests scripts doc Makefile` prints nothing. `verify85.txt:1` names tree `57edc9b19021…`, which is `176fd21^{tree}` (measured).
- **The counts.** 1434 cases in 197 s on each version: `Fails (0)` on 0.12.5 and `Fails (1)` on 0.11.6, *the file checks › of a line of distinct paths …* (`verify85.txt:8–14`). They match `plan.md` › *Landed*, T22 (`:1022–1035`).
- **MISSING:** that output exists only in `.claude/local/orchestrator/verify85.txt`, which is untracked. `Implementation/Waves/CLAUDE.md:16` says `evidence/` holds "the baseline's measurement output", and the template's Baseline slot asks for the output pasted. Commit `verify85.txt:1–14` as `evidence/baseline-176fd21.txt` and cite it.

## The six rules, recomputed from the briefs

Against every open packet and every claimed wave:
- Wave 6 is `claimed`, `rolling: true`, `claimed_by` session `938616f1…`, this session.
- Wave 7 is `claimed`, `rolling: true`, and paused (`00007-panes/plan.md:124`): T23 done (PR #79), T24–T26 not dispatched.
- `gh pr list --state open` shows only PR #92.

| rule | T27 | T28 | T29 |
|---|---|---|---|
| 1 dependencies | T18 `done — PR #60` ✓ | T22 `done — PR #85` ✓ | T10 `done — PR #52`, T17 `done — PR #68` ✓ |
| 2 files | `doc/aineo.txt` › *Colours*; `tests/test_report_colours.lua`; `tests/test_doc.lua` only if a pin counts the change | comment lines of `scripts/minimal_init.lua`, `tests/helpers/child.lua`, `tests/helpers/entry_editor.lua`, `tests/helpers/claude_session.lua`, `tests/test_entry_guard.lua` | `tests/test_report_paths.lua`, `tests/test_report_links.lua`, one new `tests/helpers/` file |
| 2, recomputed | disjoint ✓. The only pin over the whole help, `tests/test_doc.lua`, is T27's alone. | disjoint ✓ | disjoint ✓. No registration list: the runner globs `tests/**/test_*.lua` and the lint takes `LUA_SOURCES := lua plugin scripts tests`; a helper named `test_*.lua` would be collected (finding 2). |
| 3 schema or shared state | none ✓ | none ✓ | none ✓. Host CPU during its load phases is shared, outside rule 3 (finding 3). |
| 4 dependencies | none ✓ | none ✓ | none ✓ |
| 5 decisions | the user's item 1; the recipe's form is code shape, its behaviours fixed ✓ | the user's item 2 ✓ (not quoted in the brief, T28-5) | the user's item 3; "what to measure" is code shape, the behaviour fixed by the task line ✓. If CPU time fails (T29-2), the brief returns it as a report, not a choice ✓ |
| 6 task lines | rows 148–150 are adjacent to each other and to T26 (row 147, wave 7, paused). Each brief holds its mark with a `## Task lines` section ✓ | ✓ | ✓ |

All six rules hold. The one rule the briefs break is not among the six (finding 1).

**Session notes:** `2026-10-04 — T27 Report bold recipe.md`, `2026-10-04 — T28 Harness docstrings.md` and `2026-10-04 — T29 Timing cases.md` are distinct, and no `Sessions/2026-10-*` note exists ✓. **Scratch prefixes** `t27-`, `t28-`, `t29-` are distinct ✓. **Resources** `impl_t27_bold_recipe`, `impl_t28_harness_docstrings` and `impl_t29_timing_cases` match `prepare-worktree.sh`'s `^(impl|review)(_[a-z0-9]+)+$` ✓.

## Slots — `.claude/skills/orchestrate/prompts/packet-brief.md`

| slot | T27 | T28 | T29 |
|---|---|---|---|
| role line, dispatch line | ✓ | ✓ | ✓ |
| task lines verbatim | ✓ (a final full stop added) | ✓ (same) | ✓ (same) |
| rests on | ✓ | ✓ | ✓ |
| facts checked against `origin/dev` | ✓ (two line ranges off, T27-6) | ✓ | ✓ (ranges off, T29-6) |
| baseline pasted, with its evidence file | numbers only, no file | numbers only, no file | numbers only, no file |
| read first, with the project note | ✓ | no project note | no project note, no T10 note |
| branch, class, model, resources | ✓ | ✓ (`refactor/` for a docs-only change; the template names `feature/` or `bugfix/`, and CLAUDE.md's `refactor/` is "structural change". Defensible, not misleading.) | ✓ |
| may touch, with the documentation invalidated | ✓, but invalidated records not named (T27-5) | ✓ | ✓ |
| must not touch | ✓ | ✓ | ✓ |
| session note, scratch prefix | ✓ | ✓ | ✓ |
| spec-conflict line | ✓ (specific) | absent (low) | partial (low) |
| what was decided already | ✓ | **absent** (T28-5) | ✓ |
| budget, report | ✓ | ✓ | ✓ |

The report path `.claude/local/orchestrator/<slug>-report-packet.md` sits under `.claude/`, which each brief's *must not touch* forbids. It is gitignored (`.gitignore:39`), so no commit is at stake, but one clause ("not committed") would remove the doubt.

## The plan's verification mutants

| packet | plan's mutant | the test that must fail it | status |
|---|---|---|---|
| T27 | the help's recipe restored to `:highlight link … NONE` alone | the new case that runs the help's text then `:colorscheme habamax`; the brief tells the packet to write it, and red on dev's recipe is attainable (T27-1) | sound |
| T27 | the test's `:colorscheme` step removed | none named: with the new recipe the case stays green | name the expected result. It means something only together with the first mutant (dev's recipe plus no `:colorscheme` step → green, which proves the step is what turns it red). |
| T28 | one code line changed in each of the five files, caught by the bytecode check | the bytecode check | fails for a rename or a reflow (T28-2); name constant or statement edits |
| T29 | one file-system check per occurrence | the timing cases | **equivalent on their input** (T29-1); replace with M10 and X11 |
| T29 | a busy-wait in the drawing step | the new form | sound for CPU time; add a sleeping mutant (T29-4) |

## Mutant and probe table (this review's runs)

| literal edit or probe | where | result |
|---|---|---|
| `lua/aineo/report/init.lua:131` `    if answers[path] == nil then` → `    if true then` | `.tests/brief-paths-probe.lua` (narrowed timed step, 0.12.5) | equivalent: 209 674 checks both ways; 0.94 → 0.94 s, 1.03 → 1.02 s. Restored (`cmp` with the saved copy). |
| bytecode variants b, d, e, f, g, h, i, j, k, l1/l2, m1/m2, cs_n, cs_o | `nvim --clean --headless -l cmp.lua`, both versions | as in T28-1 and T28-2; the same on both versions |
| comment-only filter on b, h, i, cs_n | the command in T28-2 | b empty, h and i printed, cs_n empty |
| CPU-time probe, quiet / 12 loops / 40 loops / `taskpolicy -b` | `.tests/brief-paths-probe.lua` | as in T29-2 and T29-3 |
| `hlprobe` plus the ColorScheme recipe | `.tests/brief-hlprobe-run.lua`, both versions | as in T27-1 to T27-3 |
| child environment | `.tests/brief-child-env.lua`, both versions | green: the child's six variables equal its file's |

**Summary:** 1 production mutant run, equivalent on the timed input. 15 bytecode variants on 2 versions: every comment-only edit ignored, every constant or statement edit caught, 4 behaviour-preserving code edits missed (caught by the diff filter).

## Verdict

The briefs are accurate in almost every checkable fact: ids, rows, paths, test names, counts, attributions, and the aineo probe, re-measured on both versions. The six rules hold.

They would still mislead the implementers in two places. First, all three tell an implementer bound by D26, the root `CLAUDE.md` and its own charter not to run the whole suite before pushing, and never to run a surviving mutant on it: an instruction the charter says it must override. Second, T29's measurement plan rests on a mutant that cannot slow its input and on a load that, on this host, never fails the case, while the candidate measure itself fails on the efficiency cores.

**The single most important change before dispatch:** settle finding 1. Either take the push-time suite skip to the user as a decision recorded as a new D# row and an `ai/` change, or restore D26's whole suite before push in all three briefs. Then correct T29's mutants and add its measured host facts.

| brief | verdict |
|---|---|
| T27 | dispatch after these corrections (finding 1; T27-3 to T27-7 are low) |
| T28 | dispatch after these corrections (finding 1; T28-2, T28-5, T28-6) |
| T29 | dispatch after these corrections (findings 1 and 3; T29-1 to T29-4 substantive; T29-6 and T29-7 low), not in parallel with T27's runs |

**For the other dimensions:** reviewer allocation (`orchestrate/SKILL.md:141`): T27's deliverable is user-facing help text, and "a documentation packet takes records and reader". Consider a `reader` pass on its help paragraph alongside `guarantee`.

## Cleanup

- `git status --short`: empty. `lua/aineo/report/init.lua` byte-identical to its saved copy (`cmp` printed "init.lua restored"). `git diff --stat`: empty.
- Load processes: both runs ended by their own handles ("load stopped"). `ps -p <all 52 pids>` lists 0. `pgrep -f brief-load.lua`: none.
- `.tests/homes/`: empty after the runs.
- `prepare-worktree.sh review_brief_t27_t29` printed `AGENT_RESOURCE=review_brief_t27_t29` and created nothing (`prepare_project` is empty). `make deps` fetched mini.nvim at the pin (`1345d19…`) into this worktree's `deps/`.
- Scratch is under this worktree's `.tests/brief-*`, left for the worktree's discard. Nothing was written outside the worktree except this session's own background-task output files.
