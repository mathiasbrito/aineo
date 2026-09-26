# Brief review — T14's dated amendment (PR #43, `knowledge/w6-t14-amendment` at `ddce2b6`)

*Verbatim. Findings 1–3 are answered in the amendment's corrected text; the wrong wording of `ddce2b6`'s message is named in the correcting commit.*

**Dimension:** brief. **Subject:** `## Amendment — 2026-09-26, before dispatch` of `knowledge-vault/Implementation/Waves/00006-fixes/brief-t14-input-draft.md`, its evidence `evidence/baseline-7af0d47.txt`, and every fact of the brief above it that T13 (PR #31), T15 (PR #39) or T16 (PR #40) could have moved.
**Checked at:** `ddce2b6`, detached. Its code is `7af0d47`'s: `git diff --stat 7af0d47 ddce2b6` lists only the two vault files. `origin/dev` moved during the review to `5a8a14a` (PR #44, vault only: `git diff --stat 7af0d47 origin/dev` lists no file under `lua plugin tests doc scripts Makefile`). The amendment says "`7af0d47` or later", so its facts hold there too, and `git merge-tree --write-tree origin/dev ddce2b6` merges clean (tree `991f808`).
**Resources:** `review_brief_t14_amend` (`prepare-worktree.sh` printed `AGENT_RESOURCE=review_brief_t14_amend`; `prepare_project` is empty and created nothing).

Labels follow the `brief` block of `reviewer-brief.md`. **CONFIRMED** means the statement is false or misleading, and the check that shows it is given. **REFUTED** means I tried to fault the statement and could not. **MISSING** means a slot, a boundary item or a rule is not met.

## Suite — the baseline re-measured at `ddce2b6` (code = `7af0d47`)

Runs were one at a time, colour off, with output to files in this scratch directory:

| run | Neovim | cases | Fails | rc | time | load (1/5/15) |
|---|---|---|---|---|---|---|
| 1 (`brief-suite-0.12.5.txt`) | 0.12.5 (Homebrew) | 808 | cut short: SIGTERM at the 16-min run limit | 2 | 961 s | 87–136 during the run |
| 2 (`brief-suite-0.12.5-run2.txt`), `AINEO_TEST_RUN_LIMIT_MS=1800000` | 0.12.5 | **808** | **`Fails (0) and Notes (0)`** | 0 | 466 s | 11.4 / 16.1 / 30.3 at the end |
| 3 (`brief-suite-0.11.6.txt`), literal `env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin` | 0.11.6 (`which nvim` under that PATH is the build) | **808** | **`Fails (0) and Notes (0)`** | 0 | 462 s | 17.6 / 21.1 / 26.8 at the end |

**Run 1 under load.** The host's load average was 87–136, and run 1 marked 13 cases failed before the run limit stopped it:
- 9 in `test_claude.lua`;
- 3 in `test_entry.lua`;
- 1 in `test_entry_prefix.lua`.

Run 2, on the same tree at load ~12–30, passed all 808. So they are the load failures the brief warns of, not baseline failures.

**The amendment's figure holds:** 808 cases, `Fails (0)`, on both versions. The duration matches the evidence's 468 s and 465 s. T16's `test_layout_wrap.lua` ran 32 cases with none failing in every run: run 1, run 2 (0.12.5) and run 3 (0.11.6).

## Findings, most severe first

### 1. MISSING (low; not introduced by the merges): the draft tests' state directory

**Why it matters.** Every child that `make test` starts shares one state directory: `XDG_STATE_HOME` is `.tests/state` (`Makefile:38`). No run cleans it: nothing in `Makefile`, `scripts/run_tests.lua` or `scripts/minimal_init.lua` deletes under `.tests/`. The children also share one working directory, the checkout's.

**Failure scenario.** A T14 case leaves a draft, for example ID2's quit save or ID7's unreadable draft. That draft is `.tests/state/nvim/aineo/drafts/<sha256 of the checkout>.txt`. It is then restored into the next empty Input that opens through `plugin/aineo.lua`, and that can be:
- a later case of the same file;
- a case of another `tests/test_entry*.lua` file;
- a case of the next run.

So T14's own "restores nothing" and "restored into a new Input" cases pass or fail by order and by history. The brief says nothing about this.

**How the suite already solves it.** The report tests give each child its own state directory before the first open:
- `child.lua('vim.env.XDG_STATE_HOME = ...', { fixture.directory('entry-report-state') })`, at `tests/test_entry_report.lua:41`, and again at `:52`, `:76` and `:96`;
- `fixture.directory()` deletes and remakes the directory (`tests/helpers/fixture.lua:16–23`).

**Scope of the risk today.** Only two existing plugin-level cases write into Input:
- `tests/test_entry.lua:551`;
- `tests/test_entry.lua:580`.

Both send, so they clear the draft again. No plugin-level case asserts Input's text (`grep get_lines tests/test_entry*.lua` finds only the Report's). The risk is to T14's own tests, not to the existing suite.

**Correction.** Add one bullet under *The behaviours* (or *Boundary*):

> Every child that opens the layout through `plugin/aineo.lua` in a draft test gets its own state directory before its first open, as `tests/test_entry_report.lua:41` does with `fixture.directory()`. `.tests/state` is shared by every child of a run, in one working directory, and survives the run.

### 2. CONFIRMED (low, records): the commit message says three functions moved that did not

**The statement.** The message of `ddce2b6` says:

> T13 grew plugin/aineo.lua's error framing, which moves give_report_environment(), open(), focus(), run() and the autostart's open-failed record

The amendment lists the first three under *Facts that moved*.

**The check.** `git diff d35dc4f 7af0d47 -- plugin/aineo.lua` is one hunk, `@@ -166,22 +166,39 @@`. Nothing above line 166 moved:

| function | at `d35dc4f` | at `7af0d47` |
|---|---|---|
| `give_report_environment()` | 58–70 | 58–70 |
| `open()` | 131–134 | 131–134 |
| `focus()` | 143–148 | 143–148 |

Only these moved, each by 17 lines:
- `run()`: 195–203 → 212–220;
- the autostart's record: 348–359 → 365–376, with `open-failed` at 357 → 374.

The brief's "56–70" for `give_report_environment()` counts its two docstring lines, so it was not a line number that moved either.

**Effect on an implementer.** None on the lines themselves, which are right. The damage is a false record in history: PRs land by rebase, so the message is kept as written. A reader may also look for a change to those three that is not there.

**Correction.**
- *In the amendment:* move the `give_report_environment()` / `open()` / `focus()` bullet to *Facts that held*, written as "unchanged: T13's only hunk in `plugin/aineo.lua` starts at line 166".
- *In the commit message:* replace the quoted clause with:

  > which moves run() (195–203 → 212–220) and the autostart's open-failed record (357 → 374); give_report_environment(), open() and focus() sit above T13's hunk and keep their lines

### 3. CONFIRMED (cosmetic): `open_unless_session_restored()` is lines 365–376, not 365–377

**The check.** `sed -n 365,377p plugin/aineo.lua` at `7af0d47`: its `end` is line 376, and line 377 is blank. The `open-failed` record at line 374 is right.

**Correction.** Change "(lines 365–377)" to "(lines 365–376)".

## REFUTED — statements I tried to fault and could not

Each statement is checked against `7af0d47`, which is code-identical to `ddce2b6` and to `origin/dev` at `5a8a14a`.

### The merges and the base

**R1. "T13 (PR #31), T15 (PR #39) and T16 (PR #40) have merged."**
`gh pr list --state all` shows all three as MERGED:
- #31 at 00:53Z;
- #39 at 02:59Z;
- #40 at 04:02Z.

#40's head is `be7af89`.

**R2. "Your base is `origin/dev` at `7af0d47` or later."**
`origin/dev` was `7af0d47` at dispatch, and is `5a8a14a` now. The two differ only in the vault. T14's task row in the planning note is byte-identical to the brief's verbatim quote (`cmp` exit 0 on `origin/dev`).

### The baseline

**R3. "808 cases, `Fails (0)`, on 0.12.5 and on 0.11.6", and the evidence's identity.**
- *Identity.* `git merge-tree --write-tree d86a0f9 be7af89` prints `eae53e32…`, the tree the evidence names. `git diff --stat eae53e3 7af0d47 -- lua plugin tests doc scripts Makefile` prints nothing. That meets the orchestrate skill's rule (SKILL line 104): a tree proven code-identical to the base, by exactly that command.
- *Counts.* Re-measured; see *Suite* above.

### `plugin/aineo.lua` at `7af0d47`

**R4. `give_report_environment()`, lines 58–70.**
It takes `vim.fn.getcwd()` at line 67, once, behind `report_environment_given`.

**R5. `open()`, lines 131–134, and `focus()`, lines 143–148.**
These are the only two production callers of the layout: `git grep` finds `require('aineo.layout').open` at `plugin/aineo.lua:133` and `.focus` at `:145`, and nothing else under `lua/` or `plugin/`.

**R6. `run()`, lines 212–220, reporting at `ERROR` through `error_line()` (line 194).**
- `error_line` is defined at 194;
- `vim.notify(..., ERROR)` is at 218;
- `run()` returns `false, line` at 219.

**R7. The autostart records `open-failed` at line 374.**
The line is `record_startup('open-failed', failure)` (see finding 3 for the function's range).

**R8. Nothing else of the brief's `plugin/aineo.lua` facts moved.**
The boundary names three regions T14 must not touch:
- `start_up`'s refusal checks;
- the key tables;
- the error framing.

All three still exist. The framing is T13's hunk at 166–203.

### `lua/aineo/layout/init.lua` (T16)

**R9. `open()` makes the Report's and Input's windows wrap, for their own buffers: `wrap_right_column()`, called after `pin_windows()`.**
- `wrap_right_column()` is defined at line 190;
- `M.open` calls `pin_windows()` at 648 and `wrap_right_column()` at 649, for both the build and the restore branch;
- it sets `vim.wo[window][0]` (`:setlocal`) for `'wrap'`, `'linebreak'` and `'breakindent'`.

**R10. "Input is still made as before; the draft reaches it through `M.input_buffer()` (line 680)."**
T16's diff to the file, `git diff d35dc4f 7af0d47`, is only:
- the `WORD_WRAP` and `WORD_WRAPPED_ROLES` tables;
- `wrap_right_column()`;
- the `M.open` docstring;
- the call at 649.

All of these are unchanged:
- `make_scratch()` at 378–383 (`nofile`, `hide`, unlisted, no swap);
- `keep_input_scratch`, `make_input` and `take_input_buffer` (420);
- `M.focus` (664);
- `M.input_buffer` (680).

**R11. "T16's `tests/test_layout_wrap.lua` stays green unchanged."**
- The file drives `require('aineo.layout')` directly (`tests/helpers/layout.lua:106–124`), never `plugin/aineo.lua`. The draft is wired only in `plugin/aineo.lua`, and ID8 keeps it off startup, so no draft code runs in these cases.
- T14 may not touch `lua/aineo/layout/` or existing test files.
- In the re-measured run, the file's 32 cases pass on both versions.

### T16's wrap against ID3 and the hand-off (the brief's question)

**R12. A draft restored into Input does not interact with `wrap_right_column()`, and neither `open()` nor `focus()` changes Input's text.**

*Measured with a probe* (`brief-probe-onlines.lua` in this scratch directory, `nvim --clean --headless -l`). It attaches `on_lines`/`on_detach` to Input after the first `layout.open()`. The results were identical on 0.12.5 and 0.11.6:

| step | `on_lines` | Input's window wrap/linebreak/breakindent |
|---|---|---|
| first open | — | true/true/true |
| open again while open | 0 | true/true/true |
| Input's window closed, `open()` | 0 | true/true/true |
| Input's window closed, `focus('input')` | 0 | true/true/true |
| a restore-like `nvim_buf_set_lines` of a 300-column line | 1 | true/true/true |
| the user's `:setlocal nowrap`, then `open()` | +0 | true/true/true; text kept |
| `:bdelete!` Input | `on_detach` fired once; buffer valid, unloaded | — |
| `open()` after `:bdelete` | +0; **the same buffer number**; lines `{ "" }` | true/true/true |
| `open()` after `:bwipeout` | a new buffer; lines `{ "" }` | true/true/true |

What this shows:
- **The layout never makes a change the draft would count.** A restore through `open()` or `focus()`, the wrap included, fires no `on_lines`. The layout has no text autocommand either: its only ones are `BufWinEnter` ×2, `WinClosed`, `VimResized` and `TabEnter`, at lines 549–558. So ID2's "a restore is not a change" holds with T16's code.
- **A restore does not disturb the wrap.** It is a text change, and it leaves the window options alone.
- **The hand-off order is safe.** The hand-off comes after `open()` returns, so after `wrap_right_column()`.

*One detail the implementer should know (not a defect).* After `:bdelete`, `M.input_buffer()` hands back the **same buffer number**, emptied and detached. So "an Input it has not been handed before" cannot be told by the number alone. The signal is the `on_detach`, which ID3's "one whose text was dropped without a change" already covers. An optional sentence under ID3 would say so.

### The help

**R13. `*aineo-layout*` is lines 52–94, and its first and last lines are unchanged.**
- Line 52 is `3. THE LAYOUT … *aineo-layout*`.
- Line 94 is ``lives in one tab; from another tab, `\o` moves you to it.``
- `grep -c -F` of the Boundary's first-line quote finds 1 in `doc/aineo.txt` and 1 in the brief.
- At `d35dc4f` the same two lines were 51 and 86. The +1 is T13's `*aineo-install*` line; the +7 is T16's paragraph and its blank line.

**R14. "T16 added a paragraph on wrapping inside it … keep your hunks apart from it by at least one unchanged line."**
- The paragraph is lines 70–75, with 69 and 76 blank.
- The instruction is defensible, and it costs T14 nothing: the natural places for the draft text are the Input bullet (67–68, with blank 69 between) or a new paragraph or `~` subsection lower down.
- Strictly, rule 2's one-line separation is owed only to a packet still open, and T16 is on `dev`. The instruction protects T16's text, not a merge.

**R15. The Report's section is now T11's, with the fence quoted.**
- T11's fence at `7af0d47` is lines 261–324: `8. THE AGENT REPORT … *aineo-report*` to `the working directory of its own moment.`
- T11's boundary, on PR #41's branch, matches the amendment's description: `render.lua` (and `colours.lua` if needed), five existing test files, and `*aineo-report*`.
- T11 forbids itself `plugin/aineo.lua`, `lua/aineo/layout/` and `doc/aineo.txt` outside its section.

**R16. The merge check between T14's and T11's sections holds.**
- *Synthetic test.* Two synthetic hunks at each edge of each fence:
  - T14 after lines 52 and 92;
  - T11 after lines 261 and 323.
- *Result.* `git merge-file -p t14 base t11` exits 0 and keeps all four hunks. The nearest hunks are 168 unchanged lines apart.
- `test_doc.lua` holds no pin that counts across sections. Its pins are:
  - helptags;
  - the landing;
  - tags for commands, mappings, keys and settings;
  - 78 columns;
  - the header and the modeline.
- The one cross-section hazard left is both packets adding the same `*tag*` (E154). The Boundary's step 3 (`test_doc.lua` on the merged file) catches it.
- `origin/feature/t11-report-icon` does not exist yet. "That exists and is unmerged" handles that, and handles `origin/feature/t12-claude-numbers`, which cannot exist before T14 merges.

### Facts that held

**R17. `claude/init.lua`, `send/init.lua`, `records.lua` and `tests/helpers/send.lua` are unchanged since `d35dc4f`.**
`git diff --stat d35dc4f 7af0d47 --` over the four files prints nothing. Re-read at `7af0d47`:
- **`claude/init.lua`:** `stop_on_quit()` at 51–63, its `VimLeavePre` at 52.
- **`send/init.lua`:** `nvim_buf_set_lines(input, 0, -1, false, {})` at 118, and the restore at 121.
- **`records.lua`:**
  - `records_file()` at 30 → `<state>/aineo/reports/<sha256>.jsonl`;
  - `OWNER_ONLY` at 13–15, used at 79;
  - `keep_newest_records()` at 99–116, with `fs_realpath` at 100 and `%s.%d.cut` with `os_getpid()` at 101;
  - `make_directory()` at 133–154.
- **`tests/helpers/send.lua`:** unchanged, so it still opens the layout directly.

**R18. The quit path.**
No quit-time handler was added by T13, T15 or T16. `git grep -E 'VimLeave|BufUnload|QuitPre|ExitPre|UILeave|BufDelete|BufWipeout' -- lua plugin` finds, at both `d35dc4f` and `7af0d47`, only:
- `claude/init.lua:52`;
- a health message, moved from `health.lua:496` to `health.lua:508`.

**R19. The other files the brief leans on did not move.**
`tests/test_plugin.lua` (ID8's frozen pins), `tests/test_health.lua` (`:336`, the timing case the brief names as spurious under load) and `tests/test_send.lua` are unchanged (`git diff --stat` prints nothing).

### Records and slots

**R20. The rows and names the brief rests on exist and are free.**
- C11 and D17 exist in the planning note (lines 75 and 54).
- No session note for T11 or T14 exists yet, so both names are free and distinct: `… — T14 Input draft.md` and `… — T11 Report icon.md`.
- Scratch prefixes (`t14-`, `t11-`) and resources (`impl_t14_input_draft`, `impl_t11_report_icon`) are distinct.

**R21. The amendment keeps the brief's slots intact.**
- It adds `### Before you push` with both branches, and `test_doc.lua` on both versions.
- Every template slot of the brief above is still present:
  - Objective;
  - behaviours;
  - facts;
  - baseline;
  - Boundary (branch, class, model, resources, touch and must-not, the shared document, session note, scratch, builds);
  - decisions;
  - Budget;
  - Report.

## The six rules, recomputed from the briefs

### T14 beside T11

| rule | T14 | T11 (brief + PR #41's amendment) | verdict |
|---|---|---|---|
| 1 dependencies | T8 (done) | T9 (task row 124: `T9`; T9 is `done — PR #30`). It waited on T13 and T15 under rule 2, and both have merged | ✓ |
| 2 files | `lua/aineo/draft/` (new) and its new tests; new `tests/test_entry_*.lua` only; `plugin/aineo.lua` (open, focus, report environment); `doc/aineo.txt` 52–94; T14 session note | `lua/aineo/report/render.lua` (+`colours.lua`); `tests/test_report_buffer.lua`, `test_report_colours.lua`, `test_entry_report.lua`; pins in `test_mcp_delivery.lua`, `test_mcp_blocked_editor.lua`; `doc/aineo.txt` 261–324; T11 session note | ✓ disjoint (see below) |
| 3 schema/shared state | `<state>/aineo/drafts/`, new, T14's alone | none (records' format unchanged, `records.lua` forbidden) | ✓ |
| 4 dependencies (manifest) | none | none | ✓ |
| 5 decision | D17 decided by the user; the readings are named for the MVP review | C10 decided | ✓ |
| 6 task lines | holds its mark; row at line 127 | holds its mark; row at line 124 | ✓ (gap: lines 125–126) |

Rule 2 in detail:
- **`plugin/aineo.lua`:** T14 only; T11 forbids it (T11 brief line 134).
- **Help sections:** T14's 52–94 and T11's 261–324, with 166 unchanged lines between them.
- **Test files:** T14 may create files only. T11 edits five existing ones, and its boundary allows it no new file, so no name can collide.
- **Registration lists:** none shared. No file lists aineo's module homes: `lua/aineo/init.lua` requires only `aineo.config`, and no test globs `lua/aineo/`.

### T14 before T12

T12's boundary shares files with T14, so rule 2 puts T12 after T14's merge:
- `plugin/aineo.lua` (its tables and `:Aineo`'s description) — T14's file;
- `lua/aineo/layout/` and `tests/test_layout*.lua` (new cases) — forbidden to T14.

That order is what `plan.md` records (lines 185, 237, 350: "T12 after T14"). T12's brief will need its own dated amendment after T14 merges; the brief's facts about T12 are correct as far as they go.

## Mutant table

None. This is a brief review: no packet code exists to mutate. The probe (R12) and the synthetic merge (R16) are its measurements.

## Verdict

**Dispatch after corrections.**

**Would an implementer be misled? Not in any way that sends them wrong.** Every fact of the brief that T13, T15 or T16 could have moved was checked on `7af0d47`, and each holds as the amendment states it:
- every line it names in `plugin/aineo.lua`, the layout, `claude`, `send` and `records`;
- the quit path;
- the help's fences;
- T16's wrap against ID3 and the hand-off, measured on both versions;
- the baseline, 808 cases with `Fails (0)` on both versions, re-measured;
- the evidence's identity.

**The six rules hold** for T14 beside T11 and for T14 before T12.

**The two CONFIRMED items are editorial:**
- the commit message and *Facts that moved* claim that `give_report_environment()`, `open()` and `focus()` moved, when T13's hunk starts below them (finding 2);
- the range "365–377" should be 365–376 (finding 3).

**The single most important change before dispatch is finding 1.** Add one sentence telling the packet to give every plugin-level draft test its own `XDG_STATE_HOME`, as `tests/test_entry_report.lua` does. The shared `.tests/state` survives runs, so without it T14's restore tests depend on order and on history. Finding 2's commit-message wording should be corrected before PR #43 merges, since a rebase keeps it.

## For the other dimensions and briefs (one line each)

- **T11 (PR #41):** its amendment is dated to `d86a0f9`. At `7af0d47`:
  - T16's +7 lines move `*aineo-report*` from 254–317 to **261–324**, and its sub-ranges (270–271, 287–297, 299–310) by 7 likewise;
  - the baseline is **808**, not 776.

  If T11 is dispatched from today's `dev`, its amendment's help lines and count are stale.
- **The help's and health's quit wording (pre-existing, outside T14's fence):** `doc/aineo.txt:422–425` (*aineo-limits*) and `lua/aineo/health.lua:508` say an earlier `VimLeavePre` handler "that raises an error" skips aineo's. The brief's measured fact is narrower: a Lua error does not skip later handlers; an uncaught Vimscript `throw` does. T14's own limit text, in `*aineo-layout*`, will be the precise one, and the two will then read differently.

## Cleanup

- **Worktree:** detached at `ddce2b6`. `git status --short` prints nothing: `deps/` and `.tests/` are ignored, and the scratch files are under the ignored `.claude/local/orchestrator/`. Nothing was committed or pushed.
- **Resources:** `prepare-worktree.sh review_brief_t14_amend` printed `AGENT_RESOURCE=review_brief_t14_amend`. Its `prepare_project` is empty, so it created nothing to release.
- **Processes:** `pgrep -fl agent-aa137aa6a2cdba89e` prints nothing after the runs.
- **Probe:** ran under `nvim --clean`, with `XDG_STATE_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME` and `NVIM_LOG_FILE` pointing into `brief-probe-home/` in this scratch directory. Its log is empty.
- **Nothing written outside this worktree.** The orchestrator's builds were only read and run.
