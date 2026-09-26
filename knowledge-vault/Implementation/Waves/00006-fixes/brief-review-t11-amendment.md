# Brief review: T11's amendment before dispatch (PR #41, `knowledge/w6-t11-amendment` at `2632818`)

*Verbatim. Findings 1–4 are answered in the amendment, rewritten on `dev` at `3c3a1c4`.*

**Reviewer:** `reviewer`, brief dimension, Opus 5.5. I worked detached at `2632818`, whose parent is `dev` `d86a0f9`. The pull request adds only two `knowledge-vault/` files, so every code fact below is `d86a0f9`'s unless another sha is named.

**Resources:** `review_brief_t11_amend`. `prepare-worktree.sh` printed `AGENT_RESOURCE=review_brief_t11_amend`, and `prepare_project` is empty. `make deps` ran in this worktree (mini.nvim `1345d19`).

**Instruments:** the host's `nvim` (0.12.5) and `<builds>/nvim-0.11.6/nvim-macos-arm64/bin/nvim` (0.11.6), in the literal `env PATH=…` form. Every output below is in this worktree's `.claude/local/orchestrator/`, prefixed `brief-`. I never ran the real `claude`.

**Labels** follow the `brief` block:
- **CONFIRMED:** the statement is false or misleading, shown by the check given.
- **REFUTED:** I tried to fault the statement and could not.
- **MISSING:** a slot, a boundary item or a rule is not met.
- **UNVERIFIABLE:** as the charter defines it.

**What moved during this review.** PR #40 (T16) merged while I worked. `origin/dev` is now `5a8a14a`, five commits past `d86a0f9`:
- `git diff --stat d86a0f9 origin/dev -- lua plugin tests doc scripts Makefile` names three files: `doc/aineo.txt` (+7), `lua/aineo/layout/init.lua` and `tests/test_layout_wrap.lua` (new).
- `git diff --stat eae53e3 origin/dev -- …` prints nothing. `eae53e3` is `git merge-tree --write-tree d86a0f9 be7af89`, the tree of the orchestrator's T16 verification.
- `origin/bugfix/t16-right-column-wrap` no longer exists (`git ls-remote`).

Findings 1 to 3 come from that merge. Everything the amendment says about `d86a0f9` holds.

---

## Findings, most severe first

### 1. CONFIRMED: the base and its baseline are overtaken; `origin/dev` now counts 808 cases, not 776

- **The amendment (l.181–182):** "Your base is `origin/dev` at `d86a0f9` or later. Its suite is green on both versions: 776 cases, `Fails (0)`."
- **On `d86a0f9` it holds.** See R1.
- **On the base an implementer now gets, it does not.** `feature/t11-report-icon` from `origin/dev` starts at `5a8a14a`, whose code is `7af0d47`'s and `eae53e3`'s. There, T16's cases take the count from 776 to 808, 32 more, `tests/test_layout_wrap.lua` being the one new file:
  - **measured on 0.12.5:** `Total number of cases: 808`, `Fails (0) and Notes (0)`, rc 0, 471 s (`brief-newdev-0125-second.txt`, on `git archive origin/dev` at `5a8a14a`);
  - **measured on 0.11.6:** 808, `Fails (0)`, rc 0, 461 s (`brief-newdev-0116.txt`);
  - the orchestrator's T16 verification (`verify40.txt`, also `evidence/baseline-7af0d47.txt` on the open `knowledge/w6-t14-amendment`) says 808, `Fails (0)`, on both.
- **The failure:** the implementer reports 808 against a brief that promises 776. Either they suspect their own base, or they believe a count that no evidence file in the brief supports.
- **Correction** (*Base and baseline*):
  - "Your base is `origin/dev` at `5a8a14a` or later. Its code is `7af0d47`'s: 808 cases, `Fails (0)`, on 0.12.5 and 0.11.6."
  - Cite an evidence file on `dev`. Either wait for T14's amendment to merge and cite its `evidence/baseline-7af0d47.txt`, or add `evidence/baseline-7af0d47.txt` to this pull request with the same content. Today the file exists only on an unmerged branch.
  - Keep the `d86a0f9` evidence as the history of this amendment.

### 2. CONFIRMED: the help's line numbers move by 7 on the base the implementer will have

- **The amendment (l.187–190):**
  - `*aineo-report*` at 254–317;
  - the line and its details at 270–271;
  - *Colours* at 287–297;
  - the groups at 299–310.
- **At `5a8a14a`, measured with `grep -nF` on `git archive origin/dev`:** T16 added seven lines at line 69, inside `*aineo-layout*`. So:
  - `8. THE AGENT REPORT … *aineo-report*` is at **261**, and `the working directory of its own moment.` at **324**;
  - `HH:MM [status] task — summary` and its details line are at **277–278**;
  - `Colours ~` to `when the Report first shows a report.` is at **294–304**;
  - `*hl-AineoReportTime*` to the `AineoReportFailed` row is at **306–317**.
- **The failure:** an implementer who edits by line number lands seven lines early, in T15's paragraph, which the amendment says to leave as it is. The quoted fence lines still find the section. So this misleads, but it cannot break the boundary.
- **Correction:** give the numbers at `5a8a14a` as above, or state them at `d86a0f9` with "T16's merge moved every line of the section down by 7".

### 3. CONFIRMED: *The other packets now* is out of date, and its merge-check list drops T12

- **The amendment (l.206–209):** "**T16** (PR #40, open)…". Then: "run the merge check of *Boundary* against each of `origin/bugfix/t16-right-column-wrap` and `origin/feature/t14-input-draft` that exists and is unmerged."
- **Measured:**
  - PR #40 is `MERGED`, and its branch is deleted.
  - T14 can now be dispatched: its dated amendment is open as `knowledge/w6-t14-amendment` (`ddce2b6`). It names T11 as the packet beside it, with T11's fence, and lists `origin/feature/t11-report-icon` and `origin/feature/t12-claude-numbers` for its own merge check.
- **The drop.** *Boundary* (l.146) listed `origin/feature/t12-claude-numbers`. The amendment, which "holds where it differs", replaces that list with T16's and T14's. T12 follows T14's merge (plan l.350), and T14 runs beside T11. If T14 lands during T11's review, T12 can be dispatched while T11 is still open. A fix-round push by T11 would then skip the check against T12's branch.
  - The check is cheap and guarded by "that exists and is unmerged".
  - T14's amendment keeps T12 in its own list, so the two amendments disagree.
- **Correction:**
  - "T16 (PR #40) has merged; its paragraph in `*aineo-layout*` is on your base."
  - "Before you push, run the merge check of *Boundary* against each of `origin/feature/t14-input-draft` and `origin/feature/t12-claude-numbers` that exists and is unmerged."

### 4. MISSING: a whole-suite run can stop at the runner's 960 s limit, not only fail

- **The brief (l.103):** "Under load, `test_send.lua`, `session_status()` and `tests/test_health.lua:336` fail spuriously; re-run a surprising failure alone before you believe it."
- **Measured in this review:** three of five whole-suite runs on 0.12.5 did not finish. Two stopped with `the test run did not finish within 960 s`, and one was held until I stopped it. The two whole runs on 0.11.6 and the other two on 0.12.5 finished green:
  - `d86a0f9`, under a load of about 150 while the orchestrator's T16 verification ran, stopped in `tests/test_mcp_blocked_editor.lua` after its third case (`brief-base-0125.txt`). The run had also failed 14 cases in `test_claude`, `test_entry`, `test_entry_prefix` and `test_health`, all green on the next run.
  - The copy of `5a8a14a` stopped in `tests/test_health.lua` after 74 of 78 cases, at a one-minute load of 19 at the start and 11 at the stop (`brief-newdev-0125.txt`). The file alone passed 78/0 right after, and the next whole run passed 808/0.
  - A reference-render run given a 60-minute limit was held in `test_mcp_blocked_editor.lua`'s third case for more than 25 minutes, until I stopped it by pid (`brief-ref-0125.txt`, `rc=143`). The TUI editor's processes were alive and idle.
  - No per-file run hung: three runs of all 27 files one at a time, and the blocked-editor file alone twice more.
- **Why it matters to T11:** T11 moves the pins of `tests/test_mcp_blocked_editor.lua`, the file that hung. An implementer who reads a stopped run as a red caused by their change will chase it.
- **Correction** (Baseline): add "A whole run that stops at `the test run did not finish within 960 s` is not a result. Re-run it. Run `tests/test_mcp_blocked_editor.lua` alone after moving its pins."
- **For the orchestrator, outside this brief:** an unbounded wait somewhere in the TUI cases, where the helper's startup wait is bounded, is a harness defect worth a task. I did not isolate the request that blocks.

---

## Statements tried and not faulted (REFUTED)

**R1. The baseline at `d86a0f9`: 776 cases, `Fails (0)`, on both versions.** Measured in this worktree, detached at `2632818`, which is code-identical to `d86a0f9`:
- 0.11.6: `Total number of cases: 776`, `Fails (0) and Notes (0)`, rc 0, 460 s (`brief-base-0116.txt`);
- 0.12.5: `Total number of cases: 776`, `Fails (0) and Notes (0)`, rc 0, 463 s (`brief-base-0125-second.txt`). The first 0.12.5 run is finding 4's.

**R2. The evidence's identity.**
- `git merge-tree --write-tree 2502334 20a8fae` prints `b496f5c…`.
- `git diff --stat b496f5c d86a0f9` prints nothing, over the whole tree and not only the source roots.
- `gh pr view 39` gives head `20a8fae`, `MERGED`.
- Lines 4–15 of `evidence/baseline-d86a0f9.txt` equal lines 1–12 of the orchestrator's `verify39.txt` byte for byte (`diff` empty).
- The ledger (l.321, 323) names that verification's tree as "20a8fae + dev overlay b496f5c".
- So the numbers come from a tree proven code-identical to the base, as SKILL l.104 requires.

**R3. `tests/test_mcp_blocked_editor.lua`: pins at 75, 120 and 121; 75 is a wait's target.**
- `git grep` at `d86a0f9` finds the three `'09:05 [done] …'` lines there. T13 inserted 26 lines at line 38, the *a user's editor* set, so 49 → 75 and 94/95 → 120/121.
- `report_lines()` (`tests/helpers/report_tui.lua:56–68`) waits `WAIT_MS` and returns without asserting.
- Under the reference render the file fails one case, at the `eq` of `:119`, whose `Left`/`Right` are `:120`/`:121`. `:75` is not a failure, as IC6 says.

**R4. The help at `d86a0f9`.**
- `*aineo-report*` is at 254–317.
- The line and its details are at 270–271.
- `Colours ~` … `when the Report first shows a report.` is at 287–297.
- The groups are at 299–310.
- Each quoted fence line is found once by `grep -nF`, with its exact spacing. The fences: `*aineo-report*` 254/317, `*aineo-layout*` 52/87, `*aineo-commands*` 90 and `of both (|aineo-health|).` 178.
- T15's additions inside the section are l.258 and the paragraph at 276–285 (`git diff dbc96c9 d86a0f9 -- doc/aineo.txt`). Neither describes the rendered line.

**R5. "Facts that held."**
- `git diff --stat dbc96c9 d86a0f9 -- lua plugin tests doc scripts Makefile` names 11 files. None of them is `render.lua`, `colours.lua`, `test_report_buffer.lua`, `test_entry_report.lua` or `test_report_colours.lua`, nor `report/init.lua`, `records.lua`, `buffer.lua`, `format.lua` or `tests/helpers/report_editor.lua`.
- Read at `d86a0f9`:
  - `render_report()` is at 50–74, with the header `('%s %s %s — %s')` and the time at `0..#clock_time`;
  - the status starts at `#clock_time + 1`;
  - `DETAILS_INDENT` is at l.20;
  - `render.render_records()` is called at `init.lua:117` (`show_records`, reached from `BufReadCmd`) and at `:179`.
- `REPORT_HEADERS` is at 394–398 (`^%d`) and `REPORT_LINES` at 12–16 (`^%d%d:%d%d `). The details pins are at 60–61.
- The colour pins are at 78, 83–87 with 101, 116, 128–133, 160–163 and 199–202.

**R6. `tests/test_mcp_delivery.lua` keeps 142, 181, 229, 248, 268 and 249–250.** T13's changes to it begin at line 319, and every line it adds is a refusal case with no rendered line. The reference render fails exactly the `eq`s at `:142`, `:181`, `:229`, `:247` (lines 248–250) and `:268`.

**R7. No pin over a rendered line was added by T13 or T15.** The reference render is the earlier review's `brief-t11-render-reference.lua`: the icon, `strdisplaywidth()` of `<icon> HH:MM ` for the indent, and three colour spans. I put it in a scratch copy of the tree, `brief-refrender/`, and ran every test file on its own:
- **0.12.5:** 776 cases, 41 failing (`brief-ref-perfile-0125.txt`);
- **0.11.6:** 776 cases, 41 failing (`brief-ref-perfile-0116.txt`).
- **The failing cases' names equal the 41 that the earlier review measured at `dbc96c9`** (`brief-t11-suite-reference-0.11.6.txt`), on both versions. `diff` of the sorted names, cut at 110 characters because the two runners' paths differ in length, is empty.
- **Per file:** `test_report_buffer` 22, `test_report_colours` 11, `test_mcp_delivery` 5, `test_entry_report` 2, `test_mcp_blocked_editor` 1. Every other file is 0.
- The 29 cases T13 and T15 added, in `test_report.lua`, `test_entry.lua`, `test_claude.lua`, `test_mcp_delivery.lua` and `test_mcp_blocked_editor.lua`, are all green under it.
- `git grep` finds no rendered-line description in `lua/`, `plugin/` or the help outside `*aineo-report*`: `instructions.lua` describes the fields, not the line.
- **At `5a8a14a`** as well, the per-file reference run on 0.12.5 gives 808 cases and 41 failing. The names are the same 41, and `tests/test_layout_wrap.lua` has 0 failing (`brief-newdev-ref-perfile-0125.txt`). T16 added no pin over a rendered line.

**R8. The other packets' fences, quoted.**
- **T16:** `brief-t16-right-column-wrap.md:101` has the same `*aineo-layout*` fence, and its merged diff, `bb46c2e`, sits at l.69–75, inside it.
- **T14:** `brief-t14-input-draft.md:121` has the same fence. Its amendment gives 52–94 at `7af0d47`, which my `grep` at `5a8a14a` confirms: 52 and 94.
- **T12:** `brief-t12-claude-numbers.md:105` has `4. COMMANDS … *aineo-commands*` to `of both (|aineo-health|).`, at 90 and 178 on `d86a0f9` and at 97 and 185 on `5a8a14a`. T12's own brief still says 89/177 and "T9 owns `*aineo-report*`". That is for T12's amendment, which plan l.256 already schedules.

**R9. The merges, measured.**
- **T11 against T16:** a simulated T11 edit touches `*aineo-report*` at its first content line, at the rendered line and one line above its last line. Merged by `git merge-file` over T16's merge base `f8317d8` with `be7af89`'s help: 0 conflicts. `make test_file FILE=tests/test_doc.lua` on the merged help gives 36/0 on 0.12.5 and on 0.11.6.
- **T11 against T14:** the same T11 edit, and a simulated T14 edit on the first and last lines inside `*aineo-layout*` after T16, merged: 0 conflicts. `test_doc` gives 36/0 on both versions.
- **PR #41 against the new `dev`:** `git merge-tree --write-tree origin/dev 2632818` is clean (`44f1135`).

**R10. Slots and names.**
- The task row T11 is quoted verbatim from `Planning/… .md:124`.
- C10 is at `:74`.
- The session note `<day> — T11 Report icon.md` is free and distinct from T14's, T12's and T16's.
- The resources `impl_t11_report_icon` pass `prepare-worktree.sh`'s pattern.
- The scratch prefixes `t11-`, `t14-`, `t12-` and `t16-` are distinct.
- No branch `feature/t11-report-icon` exists, locally or on `origin`.
- The budget, class, model and report shape are stated.
- `Sessions/2026-09-25 — T9 Report colours.md` has its *Limits* section (l.145).

**R11. IC7's pins.** `tests/test_plugin.lua` is unchanged since `dbc96c9`. T13's `plugin/aineo.lua` change adds nothing at startup: the frozen pin, `autocmds = { 'aineo StdinReadPost' }`, is green on both versions. The wording "adds no autocommand" comes from T9's RC7, which names that pin. The merges did not move it.

---

## The six rules, recomputed from the briefs

Files are from each brief's *may touch* list and, for T16, from `gh pr view 40 --json files`.

| rule | T11 × T16 (PR #40, merged as `bb46c2e`…`7af0d47`) | T11 × T14 (beside T11) | T11 × T12 (after T14) |
|---|---|---|---|
| 1 dependencies | T11 needs T9 (done, PR #30) and T16 needs T8 ✓ | T14 needs T8 ✓ | T12 needs T8 ✓ |
| 2 files | T16: `lua/aineo/layout/init.lua`, `tests/test_layout_wrap.lua` (new), its note, and `doc/aineo.txt` in `*aineo-layout*`. Only the help is shared, in another section; merge clean and `test_doc` 36/0 on both versions ✓ | T14: `lua/aineo/draft/` (new), `plugin/aineo.lua`, **new** `tests/test_entry_*.lua` (not `test_entry_report.lua`, which exists), and the help in `*aineo-layout*`. Only the help is shared, in another section; the three-way merge is clean and `test_doc` 36/0 on both versions ✓ | T12: `plugin/aineo.lua`, `lua/aineo/layout/`, `tests/test_layout*.lua`, `health.lua`, `test_health.lua`, `test_plugin.lua`, `test_entry_prefix.lua` or a new file, `test_entry.lua`, `helpers/entry.lua` (`M.USAGE`), and the help from `*aineo-commands*` to `of both`. Only the help is shared, in other sections. T12 must not touch the report home or its three test files ✓ |
| 3 schema | none ✓ | none ✓ | none ✓ |
| 4 dependency change | none; `Makefile` and `deps/` are outside T11 ✓ | none ✓ | none ✓ |
| 5 undecided decision | C10 is decided; IC4 is the orchestrator's reading, named for the MVP review ✓ | D17 is decided ✓ | D16 is decided ✓ |
| 6 task lines | T11 at l.124, T16 at l.129: 4 rows between ✓ | T14 at l.127: 2 rows between (125, 126) ✓ | T12 at l.125 is adjacent, so both hold their marks. Both briefs say so ✓ |

Registration files: none in any pair. T11 adds no file, and T16's and T14's test files are new files of their own. No counting pin in T11's boundary is moved by another packet.

---

## Verdict

**Dispatch after corrections.** Every fact the amendment states about `d86a0f9` holds:
- the baseline, 776/0 on both versions, reproduced here, with an evidence file whose identity I recomputed;
- the moved pins and help lines;
- the unchanged files;
- the fences.

The reference render over the whole suite gives the brief's own 41 failing cases, and no new pin from T13 or T15.

But `dev` moved under the amendment when T16 merged. An implementer branched now starts from `5a8a14a`, with 808 cases and every help line of `*aineo-report*` seven lower. The single most important correction is findings 1 and 2 together: re-state the base as `5a8a14a` (code `7af0d47`), its 808/0 baseline with an evidence file on `dev`, and the help at 261–324, 277–278, 294–304 and 306–317. Then do finding 3's merge-check list, T14 and T12, and finding 4's line about a stopped run.

## For the other dimensions

- **attack / test-integrity (a later task):** in this environment the TUI cases of `tests/test_mcp_blocked_editor.lua`, and once `tests/test_health.lua`, held a whole run past its limit. A request to an editor held at a prompt is unbounded (`report_tui.lua:56–68` asks without a bound per request). The evidence is in finding 4.
- **records:** `plan.md` l.353 onward (`## Landed`) now records T16. The T11 section's "T11 and T14 may run together once T13 has merged" (l.220) and the amendment's order agree.

## Cleanup

- `prepare-worktree.sh review_brief_t11_amend` printed `AGENT_RESOURCE=review_brief_t11_amend`. Its `prepare_project` is empty, so it created nothing, and there is nothing to release.
- Every run I started has ended. I stopped the one held run by its own pids: 26701, 26702 and 26703 (its editors and relay), 22973 (the runner) and 22961 (`make`). `ps -Ao command | grep -F agent-a33bbffe2c3fceab9 | grep -vc grep` prints `0`.
- `git status --short` in the worktree prints nothing, and `git log -1 --oneline` is `2632818 Amend T11's brief before dispatch: facts after T13 and T15`. `render.lua` was never edited in the worktree: the reference render ran only in scratch copies (`brief-refrender/`, `brief-newdev-ref/`), and the merged help only in `brief-mergecheck/`.
- The scratch copies, `deps/` and `.tests/` are gitignored, inside this worktree, and go with it.
