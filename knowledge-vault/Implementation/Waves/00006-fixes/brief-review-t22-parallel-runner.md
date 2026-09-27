# Brief review — T22, the parallel runner (PR #75, head `d1b2331`)

**Dimension:** brief. **Subject:** `brief-t22-parallel-runner.md`, `## Packet T22 — 2026-09-27` in `plan.md`, the D26 and T22 rows, `evidence/suite-times-aaa326a.txt`. **Base:** `origin/dev` = `aaa326a`; the worktree sat detached at `d1b2331` (dev plus the four knowledge files; `git diff --stat 8386aed aaa326a -- lua plugin tests scripts Makefile doc` is empty, so the code is the evidence's). **Resources:** `review_brief_t22` (`prepare-worktree.sh` created nothing: `prepare_project` is empty).

**Labels.** As the `brief` block of `reviewer-brief.md` defines them: **CONFIRMED** — a statement that is false or misleading, with the check that shows it; **REFUTED** — a statement I tried to fault and could not; **MISSING** — a slot, boundary item or rule not met; **UNVERIFIABLE** — cannot be checked from what I can read.

**What ran** (everything inside this worktree; scratch in `.claude/local/orchestrator/`, prefix `brief-`, plus `race/` and `logprobe/`):
- `make deps` into this worktree's `deps/` (mini.nvim at the pin).
- Fresh-home runs: each of the 34 files by `make test_file` with `.tests/` removed first (`brief-fresh-loop.sh`; `brief-fresh-0125-summary.txt`, `brief-fresh-0125-slow-summary.txt`, `brief-fresh-0116-summary.txt`); control runs with `.tests/state/nvim/` present (`brief-warm-0125-summary.txt`).
- Probes under `--clean` with every `XDG_*` and `NVIM_LOG_FILE` in `logprobe/` (`probe.sh`, `probe2.sh`, `nvimenv.lua`); a write/read race in `race/`.
- No whole suite; no real `claude`; nothing written outside this worktree.

---

## Findings, most severe first

### F1. CONFIRMED — PR2's log-directory bullet is true on 0.12.5 only, names the wrong mechanism, and its remedy is not sufficient (brief:26)

The brief: "The harness never creates it today, and a first run in a fresh `.tests/` fails the exact-message cases … With a fresh home per file, that would fail every run."

**Measured.**
1. `logprobe/probe.sh`: a Neovim whose `NVIM_LOG_FILE` sits in a missing `state/nvim/`:
   - 0.12.5 tells `log: "<home>/state/nvim/log" not accessible, logging to: "<home>/state/nvim/nvim.log"`; the next Neovim, with the directory now there, tells nothing.
   - 0.11.6 creates the directory and its `log`, and tells nothing.
2. `logprobe/probe2.sh`, 0.12.5: that first Neovim rewrites its own `NVIM_LOG_FILE` to `…/nvim.log` and exports `__NVIM_LOG_FILE_WANT=<the wanted path>`. A Neovim it starts with `NVIM_LOG_FILE` in a directory that **exists** still tells `log: "<parent's wanted>" not accessible, logging to: "<its own>"`; the same child with `__NVIM_LOG_FILE_WANT` cleared tells nothing. The check is `runtime/lua/vim/_core/log.lua` (`check_log_file`): it compares the inherited `__NVIM_LOG_FILE_WANT` with the Neovim's own `NVIM_LOG_FILE`. On 0.11.6 the variable is never set.
   So it is not "the first child that logs" (the T17 session note's reading): in a fresh `.tests/`, the runner itself falls back, and **every** Neovim it starts for the rest of that run tells the notice.
3. Each file alone in a fresh `.tests/`, 0.12.5 (`brief-fresh-0125-summary.txt`, `brief-fresh-0125-slow-summary.txt`) — the red cases a home-per-file runner without the fix would hit on every run:
   - `tests/test_draft.lua`, 5 — *a change › whose write is cut short leaves the previous draft and warns how much was written*; *a draft that cannot be written ›* *is told once Insert mode is left, not while typing*, *is told once Insert mode is left with <C-c>, before a quit*, *is told once Terminal mode is left, not while typing in a terminal*, *is told once as a warning and raises nothing into the typing*. Each cause is the `log: … not accessible` line, read where aineo's message was expected.
   - `tests/test_entry_prefix.lua`, 1 — *a wrong setting at startup › is told to the user, naming it, and nothing is mapped*.
   - `tests/test_report_buffer.lua`, 2 — *the records › show whole records only, when the newest 2 MiB begin inside one*; *the records › cut by another editor while this one cuts them are still cut, without a warning*.
   - `tests/test_mcp_blocked_editor.lua` — **hangs** on its fourth case (*a report for an editor at a hit-enter prompt › is answered in time, the relay keeps serving, and the report shows once the user is done*) until the run limit: rc 2 after 960 s, `the test run did not finish within 960 s`. A reading, not measured: the notice adds a message to the TUI editor, the `\r` the case types then leaves it at a prompt, and `TuiEditor:report_lines()` waits in an `rpcrequest` that has no timeout (`tests/helpers/report_tui.lua:59`).
   - `tests/test_entry_claude_exit.lua`, 19 — every case of *a wiped Claude terminal* (16: 8 cases × `bwipeout!`/`bdelete!`), *a wiped running Claude terminal › closes Claude's window, raising no error* (2), and *a Claude terminal wiped while Claude's window shows another buffer › keeps the empty buffer the same command line opens there*. Each cause is the notice in `messages`.
   - `tests/test_entry_draft.lua`, 7 — *:Aineo send › from another window empties the draft with Input, at once*; *:bdelete of Input while its window is closed › then \r or \c, then \i, …* (`r`, `c`); *after a Send › \o, \i, \r or \c restores nothing, …* (`o`, `i`, `r`, `c`).
   - `tests/test_entry.lua`, 3 — *<Plug>(aineo-send) › sends Input's text to Claude*; *:Aineo send › sends Input's text to Claude*; *a prefix too long for a mapping, at startup › is told to the user without the position of Neovim's own Lua*.
   - `tests/test_send.lua`, 27 of its 32 — every one in *send()*.
   - `tests/test_claude.lua`, 9 — *session_status() ›* the readiness cases (*is ready once its input box shows*, *… when the folder's name holds the word trust*, *… with a draft of several lines in the prompt*, *is not ready while a permission dialog asks …* (2), *is ready again once the prompt returns …* (2), *is ready when its input box fits a terminal no window has shown*, *is exited as soon as its running terminal is wiped*): `left = "starting", right = "ready"`. The fake `claude` is itself a Neovim (`nvim --clean -l tests/helpers/fake_claude.lua`, `claude_session.lua:33`). It inherits `__NVIM_LOG_FILE_WANT` and writes the notice into Claude's terminal, which is where readiness and Send read and write. That is why the damage reaches well past exact-message cases.
   - Green in a fresh `.tests/`: the other 25 files, `test_entry_claude_mode.lua` and `test_runner.lua` among them.
   - **In all: 73 cases in 8 files fail, and 1 file hangs to the limit.**
4. Controls.
   - The same files with `.tests/state/nvim/` present, 0.12.5 (`brief-warm-0125-summary.txt`, `brief-warm-0125-slow-summary.txt`, loads 25–65): all green, with no notice — `test_mcp_blocked_editor.lua` 8 s, `test_draft.lua` 26 s, `test_entry_prefix.lua` 2 s, `test_claude.lua` 165 s, `test_send.lua` 105 s, `test_entry.lua` 71 s, `test_entry_draft.lua` 65 s. `test_report_buffer.lua`'s second run was green too.
   - In a fresh `.tests/` on 0.11.6 (`brief-fresh-0116-summary.txt`, `brief-fresh-0116-slow-summary.txt`): `test_mcp_blocked_editor`, `test_draft`, `test_entry_prefix`, `test_report_buffer`, `test_send` and `test_entry_claude_exit` are all green, with no notice.
   - Not run: a whole `make test` in a fresh `.tests/`. By the mechanism in F1.2 it takes every one of these failures in one run and ends at the 16-minute limit on `test_mcp_blocked_editor.lua`.

**Why it misleads.** The brief understates the damage. It is not only the exact-message cases: readiness and Send fail too, because the fake `claude` is a Neovim. And an implementer who makes "each home's log directory exist before its Neovim starts" and nothing else still ships the failure: `make` starts the runner with `NVIM_LOG_FILE=$(TEST_HOME)/state/nvim/log`, and in a fresh `.tests/` that directory does not exist. On 0.12.5 the runner then exports `__NVIM_LOG_FILE_WANT`, and every file's Neovim inherits it and tells the notice, whatever its own home holds. Such a first run fails the cases above and waits 16 minutes on `test_mcp_blocked_editor.lua`. It shows on the first run after `.tests/` is removed, which is how every new worktree starts.

**Correction** (replace brief:26):
> **Each home's log directory exists before its Neovim starts, and so does the runner's own** (`$(TEST_HOME)/state/nvim`, before `make` starts the runner). On 0.12.5, though not on 0.11.6, a Neovim that cannot open its `NVIM_LOG_FILE` logs to `nvim.log` beside it and exports `__NVIM_LOG_FILE_WANT`. Every Neovim it starts inherits that variable and tells `log: "…" not accessible` through `vim.notify()`, whatever its own log file (`runtime/lua/vim/_core/log.lua`). So `__NVIM_LOG_FILE_WANT` never reaches a file's Neovim. The fake `claude` is a Neovim too, so the notice also lands in Claude's terminal. Measured at `aaa326a`, each file alone in a fresh `.tests/` on 0.12.5: 73 cases in 8 files fail, among them readiness in `test_claude.lua` and 27 of `test_send.lua`'s 32, and `tests/test_mcp_blocked_editor.lua` hangs to the run limit. They are this behaviour's red cases.

Add a verification mutant to `plan.md`: *the runner's log directory not created* (or *`__NVIM_LOG_FILE_WANT` passed on*).

### F2. MISSING — the brief never says that the suite runs the Makefile's own test recipes inside itself, beside the other files (PR2, brief:25)

`git grep` at `aaa326a`:
- `tests/test_runner.lua` has 23 `make.run('test_file', …)` sites, some parametrised, and 2 `make.run('test', …)` (`:521`, `:531`);
- `tests/test_isolation.lua` has 7 nested `make test_file` runs, 8 with the parametrised route;
- `tests/test_deps.lua:123` has 1 nested `make test`, which stops at `deps`.

All of them run the `Makefile`'s recipe under the same `$(ROOT)/.tests`: `override TEST_HOME := $(ROOT)/.tests`, whatever the caller's environment holds.

**Failure scenario.** Brief:25 asks the implementer to "say what your homes need instead" of today's clean-up. The obvious answer is a recipe line that empties every home at the start of a run, for example `rm -rf $(TEST_HOME)/homes`. Under PR1, `test_runner.lua` runs beside the other 33 files. Each of its nested runs (25 call sites, more runs because some cases are parametrised) executes that line and deletes the homes those files are using: drafts, kept session ids, Reports, `CLAUDE_CONFIG_DIR`, and F1's log directory. Today's `rm -rf '$(TEST_DRAFTS)'` has the same reach. It is harmless now only because files run one at a time.

A second, smaller point. Nested runs inherit `AINEO_TEST_JOBS` and start pools of their own. Each is bounded by `make.lua`'s 10 s default (`DEFAULT_TIME_LIMIT_MS`), which side-by-side load makes tighter. Both are inside the boundary.

**Correction** (add to PR2):
> `tests/test_runner.lua` (25 call sites), `tests/test_isolation.lua` (8 runs) and `tests/test_deps.lua` (1) run the `Makefile`'s `test` and `test_file` recipes from inside the suite, while other files run. Whatever a run clears at its start reaches only its own homes, never a directory another run's files use. A nested run's file never gets a suite file's home.

Add a mutant: *the run clears every home at its start*.

### F3. CONFIRMED — three fixture files are shared between files, by a route the brief does not name (brief:27)

The brief's own claim holds, and I tried to fault it (REFUTED): no literal passed to `fixture.directory('…')` or `claude_session.fake('…')` is used by two files. The five in-file repeats are exactly `decoy` (3 uses), `report-colours-state` (3), `report-links-state` (2), `report-paths-elsewhere` (2) and `report-state` (22) (`brief-fixtures.py`).

Every route checked:
- the literal calls of `fixture.directory`, `fixture.write`, `claude_session.fake` / `claude.fake` and `layout.file`;
- each computed name, resolved from its callers (`brief-fixtures2.py` over-approximates by pairing each computed route with every string literal of its file; every shared candidate it printed was read and dismissed, except the three below);
- the four hand-built paths the brief names;
- `make.lua`'s `.tests/empty`, which three files use as a working directory and none writes into;
- `vim.fn.tempname()`, which is per process.

The shared names:
- **`tests/helpers/layout.lua:235`**: `layout.file(name)` is `fixture.write('layout/' .. name, …)`.
  - `layout/first.txt` is written by 6 files: `test_layout`, `test_layout_file_column`, `test_layout_input`, `test_layout_proportions`, `test_layout_tabs`, `test_layout_wrap`.
  - `layout/second.txt` is written by 3: `test_layout`, `test_layout_file_column`, `test_layout_tabs`.
  - `layout/third.txt` is written by 3: `test_layout_file_column`, `test_layout_tabs`, `test_layout_wrap`.
  - 79 call sites in all.
- `fixture.write` rewrites a file in place (`vim.fn.writefile`, which truncates first).
- **Measured** (`race/run.sh`, 0.12.5): a reader in another process, reading the file while a writer rewrote it as `fixture.write` does, got a short or empty file on 205 of 182,816 reads. With the writer writing a file of its own and renaming it over the target (`race/writer_atomic.lua`), it got 0 short reads of 191,613 (`race/atomic.txt`).
- **Failure scenario:** `test_layout_file_column.lua` › *a file opened on line 3 in Input › shows line 3 under the cursor in the file column* runs `:edit +3 <layout/first.txt>`. If `test_layout.lua` rewrites that file at the same moment, the child can read it empty and the cursor lands on `{ 1, 0 }`.
- The callers are outside the boundary. The remedy is inside it: `tests/helpers/fixture.lua`.
- T19's head (`57a740e`) adds no cross-file name: its new files use `resume-…` and `entry-resume-…`.
- One more in-file repeat, through a computed name: `mcp-tui-state` (`test_mcp_blocked_editor.lua:98` and `:129`, via `start_editor`). It is harmless.

**Correction** (append to brief:27):
> One route the grep above misses: `layout.file()` (`tests/helpers/layout.lua:235`) writes `layout/first.txt` from six files and `layout/second.txt` and `layout/third.txt` from three each. `fixture.write()` rewrites in place, so a reader in another file can see the file empty: measured, 205 of 182,816 concurrent reads. `fixture.write()` is yours. Writing a file of the writer's own and renaming it over the target measured 0 of 191,613.

### F4. CONFIRMED — PR3 names the strings the verification reads, but not how it reads them (brief:28–33)

`verify58.py`–`verify68.py`, `summary()`:
- it removes only SGR escapes (`\x1b\[[0-9;]*m`);
- it reads `stdout + stderr`, in that order;
- it keeps a line that **contains** `Total number of cases`, `Fails (` or `did not finish within`, or that **begins with** `FAIL in`;
- it keeps **only the first 14** such lines.

(The runs set `NO_COLOR=1 FORCE_COLOR=0`, which mini.test ignores: the logs carry colour codes.)

**Failure scenario.** The simplest runner starts today's `run_tests.lua` once per file and relays each file's output, then prints an aggregate. That output holds 34 `Total number of cases` lines and 34 `Fails (` lines before any aggregate. The orchestrator's record of the run is then 14 per-file totals, with no `FAIL in` line and no aggregate. "Prints what `make test` prints today, in the same lines" does not rule that out.

**Correction** (PR3):
> Exactly one `Total number of cases: <n>` line and one `Fails (<n>) and Notes (<m>)` line in the whole output, and no file's own summary passed through. Each failing case on a line that begins `FAIL in ` once colour codes (`ESC[…m`) are removed, with no other escape sequence or carriage return before it. The verification scripts keep only the first 14 lines that match.

### F5. CONFIRMED — PR4's list of endings is not the runner's, and two of its instructions presume the answer (brief:34–42)

- **(a) Endings missing from the list.** Brief:67 makes the docstring binding ("every ending it names"), but PR4's own list, the one an implementer will test against, lacks:
  - test code that calls `os.exit` (docstring l.5; `test_runner.lua` › *…ends the run before a failing one* › `os.exit(0)`);
  - no file named where one was expected (l.4–5; `test_runner.lua:274`);
  - a run that collects no test file at all (`run_tests.lua:202`; `test_runner.lua:520`);
  - an `AINEO_TEST_RUN_LIMIT_MS` that names no number above zero, which is refused (`run_tests.lua:80–94`; `test_runner.lua:501`). The docstring does not name this one at all.
- **(b) "stopped by its pid".** SIGTERM does not stop a Neovim that is kept busy (docstring l.13–16), and the brief does not say what then stops a file's Neovim. A Neovim stopped by SIGKILL leaves its child Neovims running: each leads a process group of its own (`tests/helpers/make.lua:44–47`).
- **(c) "The runner's docstring states … what it does not bound (a case that keeps Neovim itself busy)".** This presumes the old limit. In a design where the runner runs no case itself, its timer fires even while one file's Neovim is busy, so the new runner *can* bound that file, by SIGKILL of the file's process tree listed first, as `make.lua` does. The instruction also drops the docstring's second unbounded case: a process a test starts with `vim.system` and never stops (l.16–17).
- **(d) Validation of `AINEO_TEST_JOBS`.** None is asked for. `AINEO_TEST_JOBS=0` either starts no file and waits for the 16-minute limit, or reads as green on zero files, whichever the pool does with it.

**Correction:**
- List all eight endings in PR4: the four above plus the brief's four, and add the refusal of a bad limit to the docstring.
- Replace brief:41–42:
  > When the run ends early, whether at the limit or on the runner's own error, every file's Neovim still running is stopped by its pid, with every process it started, never by a process-wide kill. A stopped file's cases count as not run. Say how a file's Neovim that ignores SIGTERM is stopped. The docstring states what the runner bounds and what it does not, as measured, including a `vim.system` process a test never stops.
- Add to PR1:
  > `AINEO_TEST_JOBS` that names no whole number above zero is refused, as `AINEO_TEST_RUN_LIMIT_MS` is.

### F6. CONFIRMED — the evidence leaves out one of the verification runs, so "35 runs" and "loads 15 to 165" are wrong (evidence §1, D26, plan.md, brief:14)

Evidence §1 claims "the suite run and every mutant run" of the verifications of #58, #60, #64 and #68.

- The 35 lines it lists match `verify58.txt`, `verify60.txt`, `verify64.txt` and `verify68.txt` exactly: every label, rc, second count and load triple (REFUTED as a fault).
- It leaves out `verify60g7.txt`: *Y7 G7 the records' colours reversed*, a whole-suite run in PR #60's verification (`make test` on 0.11.6, 1013 cases, rc 2, **618 s**, load **209.40** 194.36 152.35).
- So there are 36 runs, at 1-minute loads from 15.80 to 209.40. The 600–739 s range still holds, and so does the conclusion.
- The same "35 … from 15 to 165" appears in D26, in plan.md's *The request, and the answer*, in brief:14, in the commit message and in the PR body.

**Correction:**
- In all five places, read "36 whole runs … 600–739 s … at host loads from 16 to 209".
- Add to evidence §1 the line `verify60g7  Y7 G7 the records' colours reversed  rc=2  618 s  load 209.40 194.36 152.35`.
- Or keep 35 and name the four files instead of "every mutant run".

D26 is a spec row. Correct it before #75 merges, while it is still new.

### F7. MISSING — PR7 does not say when a run counts as green, what "in a row" means, or when to stop (brief:47–50)

- **Green on too little.** A run is judged by its exit status alone. A pool that drops a file while exiting 0 passes PR7. Require each green run's `Total number of cases` to equal the base's count on that Neovim version.
- **"In a row".** Say: consecutive runs of one sha on one version, and one failing run restarts that version's count.
- **"Its measured failure rate".** No number of runs is given. Say, for example, 10 runs of the whole suite at the default and 10 of the file alone under the same load, reported as k/10 each.
- **No stop rule.** Suppose a case outside the boundary fails at every job count above 1. PR7 then cannot be met, and brief:49 forbids touching the case. Say: stop at a green, pushed state at the highest job count that met PR7, or report PR7 unmet with each case's rate, and the orchestrator decides.
- **Affordability.**
  - A sequential run is 600–739 s (36 runs).
  - PR6 needs the base, sequential, measured before the first edit (brief:77, version not named) and `AINEO_TEST_JOBS=1`, each on both versions: about 4 × 11–12 min = 45 min.
  - PR7 needs at least 8 runs. At the orchestrator's estimate of about 3 min, and the slowest file alone was 157 s at a load of about 150, that is 25–40 min.
  - PR #74 adds a whole run on both versions before each push.
  - About 70–90 min of runs before any flake: affordable for a medium packet. T19 ran the sequential suite 11 times.
  - "Five in a row" at a per-run flake rate r needs on average (1−q⁵)/((1−q)·q⁵) runs, with q = 1 − r: 6.9 runs at r = 0.1, 10.3 at r = 0.2, 16.5 at r = 0.3. Beyond about 0.2 it is not affordable, which is why the stop rule matters.
- PR6 is measurable as written: wall clock and `uptime` per run, and the bounding file from per-file times. State which versions the base measurement at brief:77 covers.

### F8. CONFIRMED — the packet's dependency on PR #74 is recorded nowhere (brief:109; plan.md rule 1)

Brief:109 cites `implementer.md` for "run the test files your change touches while you work. The whole suite runs before each push".

- `origin/dev`'s `.claude/agents/implementer.md:39` says the opposite: "minimum code, **whole suite green**" at every unit.
- Only PR #74 (`ai/run-less-tests`, head `6d713c1`) changes it (its `implementer.md:39`, `:56`).
- #74's `CLAUDE.md` cites D26, which only #75 adds. The records review of #74 (ledger, 12:44, finding 7) orders them: #75 first.
- Rule 1 in plan.md lists only T1 and T19.

If T22 is dispatched before #74 merges, the brief and the charter contradict each other.

**Correction:**
- Rule 1 reads: "T1 ✓; T19 (PR #73) merged ✓; PR #74 merged after this PR ✓".
- Brief:109 reads "(D26; `implementer.md` after PR #74)".
- The dispatch waits for #73 and #74.

### F9. MISSING — the brief names only the root `CLAUDE.md` among the documents this change makes false (brief:73, :97)

A home per file and a runner that sets it also make these sentences false:
- `.claude/agents/neovim-lua-developer.md:35`: "the `Makefile`'s `test` and `test_file` targets set the four `XDG_*` variables, `CLAUDE_CONFIG_DIR` and `NVIM_LOG_FILE` under the checkout's `.tests/`";
- `.claude/agents/neovim-claude-code-integrator.md:61`: "`make test` sets `CLAUDE_CONFIG_DIR` under the checkout's `.tests/`";
- `scripts/minimal_init.lua:10–11`, outside the boundary: "`CLAUDE_CONFIG_DIR`, which the Makefile points into `.tests/`";
- `tests/helpers/child.lua:4–6`, outside the boundary: "A child inherits the runner's environment, and with it the isolation `make test` sets up";
- after #74, the root `CLAUDE.md`'s D26 bullet and `implementer.md:56`: "a whole run takes 10–12 minutes".

**Correction** (brief:73):
> Your report names each sentence your change makes false in the root `CLAUDE.md`, `.claude/agents/*.md`, `scripts/minimal_init.lua` and `tests/helpers/child.lua` — known today: [the list above]. The orchestrator corrects the `ai/` ones after the merge. The two outside your boundary are spec conflicts for your report.

### F10. CONFIRMED — "NVIM … not passed on" cannot be true of a file's Neovim (brief:24)

**Measured** (`logprobe/nvimenv.lua`, both versions): Neovim hands its own server address to every process it starts, as `NVIM`, whether through `vim.system` or `jobstart`. A file's Neovim started by the runner therefore sees the runner's `NVIM`. The root `CLAUDE.md:42` says so: "a child then sees the runner's own `NVIM`, which Neovim gives every job". The isolation concerns the caller's values (`test_isolation.lua:227`, the planted ones). An implementer who pins "a file's Neovim sees no `NVIM`" writes a test against Neovim itself.

**Correction:**
> the values of `NVIM`, `NVIM_APPNAME`, `MYVIMRC`, `VIMINIT` and `AI_AGENT` in the caller's environment never reach a file's Neovim (the runner's own `NVIM`, which Neovim gives every process it starts, may).

### F11. CONFIRMED — minor facts and records

- **Brief:68**, "36 top-level cases (`^T\[`)". These are 36 `T[…]` lines: 4 groups, 7 parametrised sets and 25 case functions. The run has 41 cases, which is correct. Read: "36 `T[…]` lines (4 groups, 7 parametrised sets, 25 case functions); 41 cases in its run".
- **Brief:71**, decoys "lines 86–91 and 208–214". `DECOY_TEST_HOME` is at `:86`, the routes table at `:88–92`, and the parametrised case at `:208–217`.
- **Brief:58**, "`test: deps` removes `$(TEST_DRAFTS)`". `test_file` removes it too (`Makefile:86`). After T19 both also remove `$(TEST_CLAUDE_SESSIONS)` (`…/aineo/claude-sessions`, T19's diff).
- **plan.md:627** names `brief-review-t22-parallel-runner.md`, which is not in the tree at `d1b2331`. It is true only once the orchestrator writes that file before #75 merges.
- **plan.md:593–594**: no blank line before `## Packet T22`. It still renders, but every other packet section has one.
- **Rule 2's T12 list** omits T12's optional new `tests/test_entry_claude_numbers.lua` (T12 brief:91). The sets stay disjoint.
- **The Baseline slot** is deferred to the dispatch message (brief:77), and the session note is given as a pattern (brief:106). Both are defensible while the base does not exist. The template wants the counts in the brief itself, so record them in plan.md's T22 section, or in a dated amendment, when dispatching.

### UNVERIFIABLE

- Evidence §2's "0.12.5". Neither `file-times-aaa326a.tsv` nor the ledger's 12:21 entry records the version.
- D26's first quote. The ledger holds it only elided ("…too slow ... simple features take half to one day to land."), so its middle, "this is slowing down the whole proccess", cannot be checked there. The rest of D26's quotes — the question, the option, its description and the two options rejected — match the ledger's `USER DECISION (AskUserQuestion "How should I cut` entry character for character (checked in Python). No personal data in the four files.

---

## REFUTED — statements I tried to fault and could not

- **The `Makefile` facts** (brief:55–59): `override TEST_HOME := $(ROOT)/.tests` (:25); the six overrides (:36–41); `unexport NVIM NVIM_APPNAME MYVIMRC VIMINIT AI_AGENT` (:49); `test:` removes `$(TEST_DRAFTS)` and runs `$(NVIM_TEST) -l …/run_tests.lua` (:78–80); `test_file` passes `FILE` as `AINEO_TEST_FILE` (:84–87). T19 adds the session ids' folder to both clean-ups.
- **`scripts/run_tests.lua`**: 225 lines; `neovim = { … }` at :29–37; `STALL_LIMIT_MS` 10 s at :48; `RUN_TIME_LIMIT_MS` 16 min at :59 with the override; `test_files()` at :121; `MiniTest.collect` at :193; `MiniTest.execute(…, stdout({ quit_on_finish = false }))` at :215; docstring at :1–21; the runner decides the exit status itself.
- **The fixture and helper paths**: `test_isolation.lua:8` (`TEST_HOME`) and `:49` (the `stdpath('state')` pin); `fixture.lua:9`; `make.lua:14`. The four hand-built fixture paths, `test_entry_startup.lua:128`, `test_health.lua:1070`, `:1103` and `test_report_paths.lua:23`, are also the only ones.
- **The per-file times**: evidence §2 equals `file-times-aaa326a.tsv` row for row. The totals are 681 s, 1164 cases and 34 files. The seven slow files sum to 579 s, and the next is 27 s (`test_draft`). The wall clock 12:09:57–12:21:18 is 681 s. Both load triples match.
- **Evidence §1**: every one of its 35 lines against the four `verify*.txt` files. The gap is F6.
- **The T22 row** is quoted verbatim in brief:9. **D26** carries the ledger's option description exactly.
- **The host**: `hw.ncpu` = 10 (8 performance + 2 efficiency cores).
- **The log readers**: the verification scripts read exactly `Total number of cases`, `Fails (`, `FAIL in` and `did not finish within`. How they read them is F4.
- **PR2 can be met inside the boundary**, given F1–F3:
  - Nothing outside the boundary reads the shared home except through fixtures. `git grep` for `stdpath`, `XDG_*`, `CLAUDE_CONFIG_DIR`, `NVIM_LOG_FILE` and `.tests` finds only child-to-child comparisons (`test_claude.lua:214`), per-test state directories under fixtures, and the four fixture paths.
  - `scripts/minimal_init.lua` needs no change. A file's Neovim needs `-u minimal_init.lua` for its `'runtimepath'` anyway, which gives it the `PATH` guard, the `CLAUDE*` and `AINEO_CHILD` removal and the `vim.g.aineo` preset. The runner already removed those variables from what it hands on, and `test_entry_guard.lua:27`'s `exepath('claude')` holds either way.
  - `test_isolation.lua`'s pins are in the boundary.
  - F1's log directory belongs to the `Makefile`'s `test` recipe and the runner. F3's remedy is `fixture.lua`. F2's clean-up is the recipe's.
  - What remains outside is the docstrings of F9.
- **Rule 2 against T12 and T19**: disjoint (table below). No registration list or counting pin is shared: the runner globs, and no test pins the number of test files or the `Makefile`'s text.
  - One guard is worth adding to the brief, because T12 adds a test file concurrently: *no list of test files by name*, such as an order of the slowest files first. With such a list, T12's `tests/test_entry_claude_numbers.lua` would be missing from it.

---

## The six rules, recomputed from the briefs

| rule | T22 | T12 (stale brief, 2026-09-25) | result |
|---|---|---|---|
| 1 dependencies | T1 ✓; T19 (PR #73) must merge: its `Makefile` lines ✓; **PR #74 must merge** (F8) | T13 ✓; follows T19 on `plugin/aineo.lua` and the layout | holds once #73, #75 and #74 merge, in that order |
| 2 files | `scripts/run_tests.lua` and new `scripts/`; `Makefile` `test`/`test_file`; `tests/test_runner.lua`, `tests/test_isolation.lua`, new `tests/test_runner_*.lua`; `tests/helpers/make.lua`, `tests/helpers/fixture.lua`; its session note | `plugin/aineo.lua`; `lua/aineo/layout/`; `lua/aineo/health.lua`; `tests/test_health.lua`, `test_plugin.lua`, `test_entry.lua`, `test_entry_prefix.lua` or a new `test_entry_claude_numbers.lua`, `test_layout*.lua`; `tests/helpers/entry.lua`; `doc/aineo.txt`; must not touch `scripts/`, the `Makefile`, other helpers | disjoint ✓. T19's diff (`Makefile`, `claude_session.lua`, `fake_claude.lua`, `test_claude.lua`, `test_layout.lua`, 2 new test files) lands before T22 starts |
| 3 schema | none | none | ✓ |
| 4 dependency change | none (`deps` untouched, pin kept) | none | ✓ |
| 5 undecided decision | the job count is the packet's, by measurement; a flaky case outside the boundary is the orchestrator's to decide, with no stop rule (F7) | none | ✓, once F7's stop rule is written |
| 6 task lines | T22 at line 142 of the plan note; T19 at 139 (gap 3), T12 at 132 (gap 10); no marks (brief:102) | holds its marks | ✓ |

Slots: every template field is present. The Baseline and the session note's exact name are deferred (F11). The budget is stated (medium) and so is the report shape (`t22-report-packet.md`). Scratch prefixes (`t22-`, `t12-`) and resources (`impl_t22_parallel_runner`, `impl_t12_claude_numbers`) are distinct. The session-note name `… — T22 parallel runner.md` is free on `origin/dev`.

---

## Verdict

**Dispatch after corrections.** Would an implementer acting on this brief be misled? Yes, in four places that cost real time.

- **F1:** creating each home's log directory, as the brief instructs, still fails the exact-message cases on 0.12.5, and hangs `test_mcp_blocked_editor.lua` for 16 minutes, whenever the runner itself starts in a fresh `.tests/`.
- **F2:** the brief invites a start-of-run clean-up that the suite's own nested `make` runs would turn against every sibling home.
- **F3:** it declares the fixtures unshared while three `layout/` files are rewritten concurrently by six files.
- **F4:** it names the strings the verification reads but not the 14-line window and line-start rule that a relaying runner breaks.

Also needed before dispatch:
- F5's full list of endings;
- F6's corrected run count in D26, the plan, the brief and the evidence;
- F7's definition of green and stop rule;
- F8's dependency on #74.

**The single most important change** is F1's corrected bullet. The remedy the brief prescribes is not enough to prevent the failure it describes.

**Other dimensions:**
- **records:** `Sessions/2026-09-26 — T17 Report paths.md:336` says the notice comes from "the first child that logs" and "never in a whole-file … run". Measured here: every Neovim of a fresh run, and whole-file runs fail (F1.2, F1.3).

## Cleanup

- `prepare-worktree.sh review_brief_t22` printed `AGENT_RESOURCE=review_brief_t22` and created nothing (`prepare_project` is empty), so there is nothing to release.
- Every probe and run was mine, started from this worktree, and waited on or finished.
  - `pgrep -f agent-a877e4b66dd6de8a3 | wc -l` → `0`.
  - The one run that hung (`test_mcp_blocked_editor.lua`) was ended by the runner's own 960 s limit, not by me.
- `git status --short --ignored` → only `!! .claude/local/`, `!! .tests/`, `!! deps/`: all gitignored and inside this worktree. The tree is at `d1b2331` and unmodified.
- Nothing was written in the orchestrator's scratch directory, the main checkout, `~/.claude/` or the developer's Neovim directories. The worktree is left in place.
