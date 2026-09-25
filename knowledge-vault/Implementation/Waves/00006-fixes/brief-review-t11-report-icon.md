# Brief review: T11, Report icon (PR #34, `knowledge/w6-t11-report-icon` at `3012cc7`)

*Verbatim. The files named `brief-t11-*` were the reviewer's scratch, not committed; its width probe and its output are in `evidence/icon-widths.txt`. Every finding is answered in the corrected brief and the plan's T11 section. Finding 11: the user's words are quoted from the conversation of 2026-09-25 and enter the vault with this pull request.*

**Reviewer:** `reviewer`, brief dimension, Opus 5.5. Detached at `3012cc7`, whose parent is `dev` `dbc96c9`. The PR adds only `knowledge-vault/` files, so every code fact below is `dbc96c9`'s.
**Resources:** `review_brief_t11`. `prepare-worktree.sh` printed `AGENT_RESOURCE=review_brief_t11`; `prepare_project` is empty. `make deps` ran in this worktree (mini.nvim `1345d19`).
**Instruments:** the host's `nvim` (0.12.5) and `<builds>/nvim-0.11.6/nvim-macos-arm64/bin/nvim` (0.11.6), each named below. All probes and outputs are in this worktree's `.claude/local/orchestrator/`, prefixed `brief-t11-`. I never ran the real `claude`.

**Labels** (the `brief` block): **CONFIRMED** means a statement is false or misleading, shown by the check given. **REFUTED** means I tried to fault the statement and could not. **MISSING** means a slot, a boundary item or a rule is not met. **UNVERIFIABLE** as the charter defines it.

**The instrument that decides most findings.** I wrote a reference implementation of T11 (`brief-t11-render-reference.lua`: the icon table, `strdisplaywidth()` of `<icon> HH:MM ` for the indent, three colour spans) and put it in `lua/aineo/report/render.lua`, nothing else changed. The whole suite on 0.11.6 then gives **747 cases, `Fails (41)`**, every one by assertion, every one in the five test files the brief names (`brief-t11-suite-reference-0.11.6.txt`). That list is the full set of pins the packet must move. Render restored with `git checkout HEAD -- lua/aineo/report/render.lua`; `git status` clean.

---

## Findings, most severe first

### 1. CONFIRMED: the colour pins in `tests/test_report_colours.lua` are listed as three lines; seven statements move, and each gains a span

- **The brief (l.72):** "`tests/test_report_colours.lua`: the column pins at lines 78, 83–87 and 101."
- **Measured.** Under the reference render, `tests/test_report_colours.lua` fails 11 cases, at the `eq` of lines **78, 101 (×5), 116, 128, 160, 199 (×2)**. Lines 116, 128–133, 160–163 and 199–202 are not in the brief:
  - `:116` `eq(all_colours(), { { 0, 0, 5, 'AineoReportTime' }, { 0, 6, 12, 'AineoReportDone' } })`;
  - `:128–133`, the same over two reports;
  - `:160–163` and `:199–202`, `spans_of()` over the records and `:edit` paths.
- **They change in a way the brief does not name.** Every column moves by `#icon + 1` = 4 bytes (time `{0,4,9}`, status from 10: ends 19, 20, 19, 16, 18). And each gains the icon's span, `{ 0, 0, 3, <status group> }`. `spans_of(<status group>)` then returns two spans, so `:101`, `:162` and `:201` get a new first entry. IC3 says "moved to the new columns"; IC6's "exactly two ways" covers text pins only. A records reviewer holding IC6 would flag the added spans.
- **Correction** (Facts, the pins bullet):
  - "`tests/test_report_colours.lua`: every colour pin — `:78`, the parametrize at `:83–87` with `:101`, `:116`, `:128–133`, `:160–163`, `:199–202`."
  - Add under IC3: "Each colour pin moves by 4 bytes, one icon's 3 and its space, and gains the icon's span in its status's group. No span is deleted."

### 2. CONFIRMED: a header filter by pattern, and two details pins, are missing from the list

- **`tests/test_report_buffer.lua:394–398`, `REPORT_HEADERS`**, keeps the lines that match `^%d` ("the header line of each report"). Once the icon leads the line, no header matches.
  - **Measured:** under the reference render, *show the newest 2 MiB of them* fails with `Left: { 3145728, 0 }` against `Right: { 3145728, 2048, "09:05 [done] Task 1025 — Summary", … }`. Zero headers, not a text difference.
  - Moving the pins at `:414`, `:415` and `:434`, as the brief lists them, cannot turn these two cases green. The filter must change too, for example to a line that does not start with a space.
  - The brief names the same trap in `tests/test_entry_report.lua`'s `REPORT_LINES` (l.68–69), but not this one.
- **`tests/test_mcp_delivery.lua:249–250`** are details pins indented six spaces: `"      ') os.exit(3) --"` and `'      ' .. shell_line`. The brief names only `tests/test_report_buffer.lua:60–61` as details pins (l.66). They fail under the reference render, inside the `eq` at `:247`.
- **Correction** (Facts):
  - add "`tests/test_report_buffer.lua:394–398`, `REPORT_HEADERS`, finds a header by its leading digit (`^%d`). It must change with the pins at 414, 415 and 434, or those cases count 0 headers";
  - add "`tests/test_mcp_delivery.lua:249–250`: two details lines, indented six spaces".
  - Name both patterns, `REPORT_LINES` and `REPORT_HEADERS`, under IC6 as the lines outside the "two ways" rule (finding 8).

### 3. MISSING: `setcellwidths()` changes the width IC4 measures, and nothing in the brief tests it

- **Measured on both versions** (`brief-t11-widths.lua`, `nvim --clean -u NONE -i NONE --headless -l`, 0.12.5 then 0.11.6, identical):
  - `ambiwidth=single` plus `setcellwidths({{0x2713,0x2713,2}})`: `✓` is 2 cells, and `✓ 09:05 ` is 9.
  - `ambiwidth=double` plus `setcellwidths({{0x25D0,0x25D0,1}})`: `◐` is 1 cell, and `◐ 09:05 ` is 8.
  - `strdisplaywidth()`, `strwidth()` and `nvim_strwidth()` agree in all three settings (`brief-t11-width-functions.lua`).
- **So IC4's principle holds; its bullets do not.** "Indented by the display width of what comes before `[status]`" is right whatever sets the width. But l.36, "every icon is one cell, so that width is 8", is false under a `setcellwidths()` entry. l.145, "each one column wide … holds only under the default `'ambiwidth'`", misses the second cause.
- **An implementation keyed on `'ambiwidth'` passes every test the brief asks for.** Mutant M8: `(' '):rep((vim.o.ambiwidth == 'double' and report.status == 'progress') and 9 or 8)` survives all 14 of my brief-derived tests, on both versions. It is killed only by the added case: a `done` report after `setcellwidths({{0x2713,0x2713,2}})`, details at 9 (`Left: "        One"`, `Right: "         One"`).
- **Correction:**
  - IC4: "the width is measured, with `strdisplaywidth()` or `nvim_strwidth()`, never derived from `'ambiwidth'`: both `'ambiwidth'` and `setcellwidths()` change it";
  - add the `setcellwidths()` case to IC4's test;
  - add M8 to the verification mutants;
  - amend l.36 and l.145, and add the two `setcellwidths()` rows to `evidence/icon-widths.txt`.

### 4. MISSING: "the width is taken when the report is rendered" has no test, and its wording over-promises

- **No test is asked for l.38.** Mutant M9 keeps each status's width from its first rendering: `INDENTS[report.status] = INDENTS[report.status] or (' '):rep(vim.fn.strdisplaywidth(before_status))`. It survives every brief-derived test on both versions, the `'ambiwidth'` `double` case included, since that case renders its first `progress` report under `double`.
- **Killed only by** a sequence: a `progress` report with details under `single`, then `'ambiwidth'` `double`, a second `progress` report, then `:edit`.
  - Expected: 8 then 9, then 9 and 9 after `:edit`.
  - M9 gives 8 and 8 (`Left`/`Right` in `brief-t11-mutant-M9.txt`).
- **The wording.** "A later change … shows in the next rendering, which is the next report, or `:edit`" reads as if the Report realigns at the next report. It does not. A new report renders only itself (`init.lua:179`). Reports already shown keep their indent until `:edit`, which re-renders every record (`:117` through `BufReadCmd`). Measured by the sequence above on the reference render.
- **Correction:**
  - IC4, l.38: "Each report's details keep the width of the rendering that drew them: a report that arrives after a change is drawn with the new width; `:edit` in the Report redraws every report with it";
  - add that sequence as IC4's test, and M9 as a verification mutant.
- M10 is a load-time table: `INDENTS` computed from `ICONS` when `render.lua` loads. The brief's own `double` case kills it, because `report_editor.start()` loads the report home before the test sets `'ambiwidth'`. That holds only while the test sets the option after `start()`. Say so in IC4's test.

### 5. CONFIRMED: "IC1 to IC5 one test each, each seen red first" — IC5 can be red only before IC1's code exists

- **One render serves all three paths** (finding 13 REFUTED below). Once the render prepends the icon, a test of the records path or of `:edit` passes with no further code.
- **Measured:** my IC5 test (saved records shown when the Report opens) fails on `dev`'s render by assertion (`brief-t11-probe-on-dev.txt`, 16/16 red). It passes on the reference render.
- This is the lesson of the first brief review's finding 13, and of T14's finding 6.
- **Correction:** "IC5's test is written and seen red before the render changes, beside IC1's. Written after IC1, it is green at once." Or name the moved pins on the other paths as IC5's red:
  - `tests/test_report_buffer.lua:164` (`:edit`), `:236` (re-created after a delete), `:587`, `:772` and `:800` (records shown when the Report opens). Names read from the reference render's failures;
  - `tests/test_report_colours.lua:160–163`, `:199–202`.

  Their old text is red once IC1 lands, but the new expectation must be seen failing first.

### 6. CONFIRMED: the post-T13 baseline goes into "the dispatch message", which rule 1 of the rolling wave does not allow; and it moves line numbers the brief states as fixed

- **The brief (l.84):** "gives the counts measured on that sha in the dispatch message."
- **SKILL §3, *A rolling wave*:** "before it is dispatched, every fact in its brief is re-checked against the new `origin/dev`, and a changed fact is a dated amendment (§4)". §4: an amendment is "a `knowledge/` pull request adding a dated section, reviewed by the brief dimension". T14's brief (l.98) and T12's (l.68) both say "records any change as a dated amendment". T14's review, finding 10, asked for exactly this.
- **What T13 moves.** Measured on `git merge-tree --write-tree origin/dev 050bd97`, T13's current head, which gives tree `25ab9b8`:
  - the help: every line from 39 on moves by +1. `*aineo-report*` is at **254–306**, the line at **270–271**, the colours at **276–286** and the groups at **288–299**. The brief's 253–305, 269–270, 275–285 and 287–298 are marked only as `dbc96c9`'s;
  - `tests/test_mcp_blocked_editor.lua`: 49, 94, 95 → **75, 120, 121**;
  - `tests/test_mcp_delivery.lua`: unchanged at 142, 181, 229, 248–250, 268.
- **Correction:**
  - replace l.84's last sentence with "Before dispatch the orchestrator re-checks every fact above against that `dev` and records any change as a dated amendment of this brief: the counts, with their evidence file, and the line numbers";
  - mark the help's line numbers "at `dbc96c9`; T13 moves them by one".

### 7. MISSING: the other briefs still name T9 as the owner of `*aineo-report*`; and T12's fence is not quoted

- **T14's brief** says "T9 owns `*aineo-report*`" (l.132) and "**T9** (PR #30), if still open, edits from `8. THE AGENT REPORT …`" (l.138).
  - T9 is merged. T11 now owns that section and is planned to run **beside** T14.
  - T14's merge-check step is generic ("for each open branch that edits the help"), so it would still find `feature/t11-report-icon`. But the named owner is wrong.
- **T12's brief** says the same at l.98 and at l.106, with "(lines 253–280)", which are 9af91a6's numbers.
- **T11's section and brief** say nothing about these amendments. The folder rule forbids editing those briefs in this PR. Their pre-dispatch amendments must carry the change.
- **T11's own brief, l.126**, gives T12's section by tags alone: "`*aineo-commands*`, `*aineo-mappings*` and `*aineo-keys*`". Rule 2's vimdoc exception says "by each section's first and last line, quoted, since a tag on its own line marks no end". T12's brief quotes its own fence (l.105).
- **Correction:**
  - in the T11 plan section: "T14's and T12's dated amendments name T11, not T9, as the packet that edits `*aineo-report*`, with T11's quoted fence";
  - in T11's brief, l.126: "T12, after T14, edits from `4. COMMANDS                                                   *aineo-commands*` to `of both (|aineo-health|).`". Both are verbatim at `dbc96c9`: `doc/aineo.txt:89` and `:177`.

### 8. CONFIRMED (low): IC6's "each changed pin changes in exactly two ways" is checkable and true for every text pin, but not the whole rule

- **Checkable, and true for the text pins.** The reference render's diffs show only:
  - `<icon> ` before a header;
  - a details indent of 6 → 8.

  Read on every text failure's `Left`/`Right` in `brief-t11-suite-reference-0.11.6.txt`: `test_report_buffer` ×20, `test_entry_report` ×2, `test_mcp_delivery` ×5 (one with its two details lines at 8), `test_mcp_blocked_editor` ×1. The `test_report_buffer` count leaves out its 2 `REPORT_HEADERS` cases.
- The colour failures show the other change, as finding 1 says. `:78` gives `{0,4,9}` for `{0,0,5}`. `:101` gives `{ {0,0,3}, {0,10,19} }` for `{ {0,6,15} }` (started), and so on.
- **What falls outside the rule:**
  - the two patterns (finding 2), `REPORT_LINES` (`test_entry_report.lua:14–16`) and `REPORT_HEADERS` (`test_report_buffer.lua:396–398`). They are changed code, not pins;
  - the colour pins (finding 1): columns +4 and one added span;
  - **`tests/test_mcp_blocked_editor.lua:49`** (T13: 75), `first:report_lines({...})`, is a wait's target, not an assertion. `report_lines()` waits up to `WAIT_MS` = 5000 and returns without failing. Under the reference render, `:49` is **not** among the failures; only the `eq` at `:93` fails. An unmoved `:49` stays green and costs 5 s. The suite cannot see it; only the records review can.
- **Correction** (IC6):
  - "Every text pin changes in exactly two ways …; every colour pin moves by 4 bytes and gains the icon's span; `REPORT_LINES` and `REPORT_HEADERS` change their pattern";
  - "`tests/test_mcp_blocked_editor.lua:49` (75 after T13) is a wait's target: move it with the others, since no test fails when it is left".

### 9. CONFIRMED (low): verification mutant 7's "killed only by a `progress` report under `'ambiwidth'` `double`"

- **Measured:** M7, `(' '):rep(1 + vim.fn.strdisplaywidth(' ' .. clock_time .. ' '))`, is also killed by the `setcellwidths()` case (finding 3) and by the later-change sequence (finding 4).
- **IC1's test must cover all five statuses.** M1, `done` and `failed` swapped, is killed by IC1 only if `done` or `failed` is tested. A swap of `started` and `blocked` would pass a test of `done` alone. This is reasoned, not run.
- **Correction:**
  - "killed by a report whose icon is two cells: `progress` under `'ambiwidth'` `double`, or any icon under `setcellwidths()`";
  - IC1: "parametrized over the five statuses".

### 10. MISSING (low): the evidence file does not hold its probe

- `evidence/icon-widths.txt` describes its probe ("the probe setting `vim.o.ambiwidth` and printing `#icon` and `vim.fn.strdisplaywidth(icon)`") but does not contain it. `Waves/CLAUDE.md`: `evidence/` holds "the planning probe and its output".
- My probe reproduces every figure (finding 12). But a reader cannot re-run the orchestrator's own.
- **Correction:** paste the probe into the file, and add the `setcellwidths()` rows (finding 3).

### 11. UNVERIFIABLE: the user's words

- "an icon in the beginning (icons from unicode, but only the ones terminal styled)" (brief l.143, plan l.204) is recorded nowhere on `dev` before this PR (`git grep -F "terminal styled" origin/dev` is empty).
- Neither is the option's "each one column wide".
- "Unicode set" and the five icons are on `dev`, in `plan.md:111`, consistent with C10.

---

## REFUTED: what I checked that held

12. **The widths, both versions.**
    - Every icon is 3 bytes.
    - Under `single`, each is 1 cell and `<icon> 09:05 ` is 8.
    - Under `double`, `◐` (U+25D0) is 2 cells and `◐ 09:05 ` is 9; the others stay 1.
    - Same on 0.12.5 and 0.11.6 (`brief-t11-widths.lua`). `'ambiwidth'` `double` is accepted without error by `--clean` (`fillchars` empty, `listchars` ASCII).
    - The brief's "a column counted in bytes and an indent counted in cells therefore differ" holds.
13. **IC5, one render.** `render.render_records()` is called at `lua/aineo/report/init.lua:117` (`show_records()`, which serves the Report's opening, its re-creation after a delete, and `:edit`, through the refill callback at `:131–133` that `buffer.create_report_buffer()` runs from its `BufReadCmd`, `buffer.lua:59`) and at `:179` (a new report). No other path renders a report line:
    - `instructions.lua` lists the fields and statuses only;
    - the MCP relay replies `Delivered to the Agent Report.` or an error (`mcp/editor.lua:148`, `:156–158`);
    - `health.lua` renders nothing of a report;
    - each notification (`warn_later`) carries a count or a failure;
    - the helpers `report_editor.lines()` and `report_tui:report_lines()` read the buffer;
    - the fake `claude` and `tests/fixtures/mcp/claude-code-2.1.281.jsonl` hold the report's *input* only (`git grep "Refactor the parser"` in `tests/helpers` and `tests/fixtures`);
    - no test pins the screen (`git grep screenshot|screenstring` is empty).
14. **IC2 and IC3: nothing else in the Report is coloured by column or by pattern.**
    - The only colours are the render's extmarks, set in `buffer.lua:131–141` in the namespace `aineo_report_colours`, and cleared on an empty buffer (`:126–129`).
    - There is no `syntax/`, `ftplugin/` or `after/` directory, no `matchadd`, and no filetype on the Report.
    - Measured: the reference render passes my IC3 test over `task = '✓ 12:34 [done]'`, `summary = '[failed] at 10:00'`, `details = '09:05 [done]'`, colours exactly `{0,0,3,Done}`, `{0,4,9,Time}`, `{0,10,16,Done}`.
15. **Every render fact.** `render_report()` at `render.lua:50–74`; the header built by `('%s %s %s — %s'):format(clock_time, bracketed_status, …)`; the time span `0`..`#clock_time`; the status from `#clock_time + 1`; `DETAILS_INDENT` at `:20`, `(' '):rep(#'HH:MM ')`.
16. **Every pin the brief lists is where it says, at `dbc96c9`.** `git grep -n -E "\[(started|progress|blocked|done|failed)\] " origin/dev -- tests` gives exactly:
    - `test_report_buffer` 45, 59, 75, 87, 164, 176, 191, 236, 414, 415, 434, 587, 711, 772, 800;
    - `test_entry_report` 48, 70;
    - `test_mcp_delivery` 142, 181, 229, 248, 268;
    - `test_mcp_blocked_editor` 49, 94, 95;
    - `test_report_colours` 112, a task string, not a pin.

    The `REPORT_LINES` claim (l.68–69) holds: under the reference render `:48` fails with `Left: "✓ 00:55 [done] …"` against `Right: "HH:MM [done] …"`.
17. **No pin outside the five files.**
    - The reference render's 41 failures are all in `test_report_buffer` (22: 20 text pins and the 2 `REPORT_HEADERS` counts), `test_report_colours` (11), `test_mcp_delivery` (5), `test_entry_report` (2) and `test_mcp_blocked_editor` (1). The mapping from each to its `eq` line is in the suite output.
    - Nothing under `tests/helpers/` builds a header with `HH:MM` or the em dash. `git grep "—"` in `tests/helpers` and `tests/fixtures` finds only docstrings and Claude Code screens.
    - Nothing in `records.lua`, `format.lua`, `buffer.lua`, `init.lua`, `instructions.lua`, `plugin/` or `health.lua` describes the line.
18. **The boundary suffices.** The reference changes `render.lua` alone. Every test it breaks is in *may touch*. `records.lua` and `init.lua` need no change: the records hold `{ time, report }`, so saved reports show with the icon (IC6's last sentence). `test_mcp_*` need only their rendered-line pins.
19. **C10 against IC1–IC7.**
    - Every clause of C10 is covered: the line (IC1), the five icons (IC1), "coloured like the status" (IC2), "details indented under the status" (IC4).
    - The rest carries standing rows: C6 and T9's RC1–RC3 (IC3, read at T9's brief l.15–26), RC7 (IC7).
    - IC2's "the space has no colour" and IC4's measured width are readings of C10, named as such. Nothing C10 asks is left out.
20. **IC4 as the reading of "indented under the status."**
    - It is right: `render.lua:18–19` already defines the indent as "as wide as the `HH:MM ` that starts its header, so the details line up under the status". Alignment in Neovim's grid is in cells.
    - It is testable red first: 16/16 of my tests fail on `dev`'s render, the IC4 cases by indent.
    - An indent fixed at 8 misaligns every `progress` report under `double`, and is not "under the status".
21. **The help fence.** Both quoted lines match `doc/aineo.txt:253` and `:305` byte for byte (`cat -e`). T14's quoted fence matches `:51` and `:86`.
    - **Merge measured.** I built three edits of `dev`'s help, each at both edges of one section: T11's (inserted after `:253`, appended to `:305`), T14's (`:51`, `:86`) and T12's (`:89`, `:177`). `git merge-file` merged T11 with T14 with exit 0, then that result with T12 with exit 0: no conflict marker, all six edits present.
    - `make test_file FILE=tests/test_doc.lua` on the three-way merge: 36 cases, `Fails (0)` (0.12.5). The file was restored with `git checkout HEAD -- doc/aineo.txt`.
    - The sections are 167 lines apart (`*aineo-layout*` ends at `:86`, `*aineo-report*` starts at `:253`).
22. **The plan's verification mutants each compile and die.** Each was applied as a literal edit to the reference (`brief-t11-mutants.lua`) and run against the 14 tests the brief asks for, plus my 2 added ones, on both versions. See the table. All seven of the plan's die by assertion, each to a test the brief asks for.
23. **The baseline.**
    - `git diff --stat 40bc378 dbc96c9 -- lua plugin tests doc scripts Makefile` prints nothing.
    - **My re-measure at `3012cc7`**, whose code is `dbc96c9`'s:
      - 0.11.6: 747 cases, `Fails (0)`, rc 0;
      - host 0.12.5: 747 cases, `Fails (8)`, rc 2, the same eight tests as `evidence/baseline-dbc96c9.txt`.

      Run one at a time (`brief-t11-suite-0.11.6.txt`, `brief-t11-suite-0.12.5.txt`).
24. **The task ID.** T10 and T11 were both named on `dev` before this PR:
    - `Projects/aineo.md:57`: "T10 (Report links, a small fix) and T11 (the report icon, C10)";
    - the retrospective, `:20–21` and `:104`.

    T11 takes the ID already given to this packet. T10 stays held for the links, which still await a behaviour. The row sits in numeric order between T9 and T12, and cites T9 and C10 as C10 reads.
25. **Rule 6 and the plan section's form.**
    - The task lines are T9 `:114`, T11 `:115`, T12 `:116`, T13 `:117`, T14 `:118`: adjacent, and every packet holds its mark.
    - The section sits directly above `## Landed`. The diff touches nothing else in the folder.
    - The frontmatter stays `claimed`, `rolling: true`.
26. **The slots.** Every field of `prompts/packet-brief.md` is present and non-empty:
    - the objective verbatim from the row, and what it rests on;
    - facts and baseline;
    - read-first, whose headings exist: T9's note has `## Limits`;
    - the boundary: branch `feature/t11-report-icon`, free on the remote; class; model; resource `impl_t11_report_icon`, valid for `prepare-worktree.sh`; may and must not touch; the invalidated documents; the shared document with a merge check;
    - the session note: `<dispatch day> — T11 Report icon.md`, distinct from every other packet's;
    - scratch prefix `t11-`, distinct;
    - decisions, budget and report shape.

    The 0.11.6 command is in its literal form.
27. **The other open PR.** PR #35, `knowledge/w7-decisions` at `4c33f10`, edits the same Planning note, in its D and C rows, not the task list. `git merge-tree --write-tree 3012cc7 4c33f10` gives one tree, `70ed323`, and no conflict. Wave 7 is not planned and not claimed, so it is outside the six rules.

---

## Mutants

Reference: `brief-t11-render-reference.lua` in place of `lua/aineo/report/render.lua`. The tests are `brief-t11-probe-test.lua`, copied to `tests/test_brief_t11_probe.lua` and removed afterwards:
- **14 derived from the brief:** IC1 ×5, IC2 ×5, IC3, IC4 `single`, IC4 `double`, IC5 records;
- **2 proposed:** P1, a `done` report under `setcellwidths(✓=2)`; P2, the later-`'ambiwidth'` sequence.

Each mutant is one literal edit of the reference. Each run was `make test_file FILE=tests/test_brief_t11_probe.lua`, on host 0.12.5 and on 0.11.6. In every run, each failure has a `Left:` line: assertion failures only. Identical on both versions (`brief-t11-mutants-0.12.5.txt`, `brief-t11-mutants-0.11.6.txt`).

| Mutant (literal edit of the reference) | In the plan? | Killed by the brief's tests | Killed by P1 / P2 | Result |
|---|---|---|---|---|
| none: the reference | — | 0/14 fail | 0/2 fail | green |
| M1 `done = '✗', failed = '✓'` | yes (1) | IC1 done, IC1 failed, IC4 `single` | P1 | killed |
| M2 the icon span `{0, 0, #icon, status_group}` removed | yes (2) | IC2 ×5, IC3 | — | killed |
| M3 the icon span's group `colours.TIME_GROUP` | yes (3) | IC2 ×5, IC3 | — | killed |
| M4 the time span `first_column = 0, end_column = #clock_time` | yes (4) | IC3 | — | killed |
| M5 the indent `(' '):rep(#'HH:MM ')` | yes (5) | IC4 `single`, IC4 `double`, IC5 | P1, P2 | killed |
| M6 the indent `(' '):rep(#before_status)` (bytes: 10) | yes (6) | IC4 `single`, IC4 `double`, IC5 | P1, P2 | killed |
| M7 the indent `(' '):rep(1 + strdisplaywidth(' ' .. clock_time .. ' '))` | yes (7) | IC4 `double` | P1, P2 | killed |
| M8 the indent `(vim.o.ambiwidth == 'double' and status == 'progress') and 9 or 8` | **no** | **none** | P1 | **survives the brief** (finding 3) |
| M9 the indent memoized per status at its first rendering | **no** | **none** | P2 | **survives the brief** (finding 4) |
| M10 the indents computed from `ICONS` when `render.lua` loads | no | IC4 `double` | P1, P2 | killed |
| M11 the icon span `end_column = #icon + 1` (the space coloured) | no | IC2 ×5, IC3 | — | killed |

**Summary:** 11 mutants. The plan's 7 are all killed by tests the brief asks for. Of the 4 I added, 2 survive every test the brief asks for, and each dies to one added test.

---

## The six rules, recomputed from the briefs for T11

Open packets: T13, PR #31 at `050bd97`, in its re-measure. Planned: T14, then T12. Claimed waves: only wave 6.

| rule | T11 against T13 | T11 against T14 | T11 against T12 |
|---|---|---|---|
| 1 dependencies | T11 needs T9, done (PR #30) ✓. It needs no open packet's code. But the brief asks both versions green, and 0.12.5 is green only with T13 | none ✓ | none ✓ |
| 2 files | **shared**: `tests/test_mcp_delivery.lua`, `tests/test_mcp_blocked_editor.lua`, `doc/aineo.txt` (`comm -12` of T11's list with `gh pr view 31`'s 10 files). **Wait for T13's merge** ✓. That is sufficient once the amendment re-reads the moved lines (finding 6). T13 also changes `tests/helpers/report_tui.lua`, which T11 does not need | `doc/aineo.txt` only. `*aineo-layout*` (`:51–86`) against `*aineo-report*` (`:253–305`), 167 lines apart. Merge-checked, with `test_doc` 36/0 on the merge ✓. T14 must not touch `lua/aineo/report/`, and adds only new `tests/test_entry_*.lua` files: disjoint from `tests/test_entry_report.lua` ✓. **Its brief still names T9 as the section's owner (finding 7)** | `doc/aineo.txt` only, `:89–177` against `:253–305` ✓, merge-checked with the other two. T12's brief forbids `lua/aineo/report/` and the three report test files ✓ |
| 3 schema | none ✓ | none ✓ | none ✓ |
| 4 dependencies | none ✓ | none ✓ | none ✓ |
| 5 decisions | C10 decided by the user ("Unicode set", `plan.md:111`). IC4 is a reading of "under the status", named for the MVP review. With finding 3 it covers `setcellwidths()` too. The behaviour is fixed; only the code shape is open ✓ | ✓ | ✓ |
| 6 task lines | T11 `:115` is adjacent to T9 `:114` and T12 `:116`; T13 is `:117`, T14 `:118`. All hold their marks ✓ | ✓ | ✓ |

**Is waiting for T13's merge right and sufficient?** Right: rule 2, three shared files, and the 0.12.5 baseline. Sufficient, once the dated amendment re-reads the baseline and the moved lines (finding 6).

**Can T11 run beside T14?** Yes, by all six rules. Two conditions:
- T14's pre-dispatch amendment names T11 as the owner of `*aineo-report*` (finding 7);
- whichever of the two lands second has its suite run over the first. This is §6's verification on the head laid over `dev`. A new T14 test that pinned a rendered Report line would otherwise meet T11's icon only there. Nothing in T14's brief asks for such a pin.

## Verdict

**Brief T11: dispatch after corrections.** No finding stops the packet:
- the boundary holds;
- the facts it states are true at `dbc96c9`;
- one render serves every path;
- the plan's seven mutants die to tests the brief asks for.

But an implementer following it as written would be misled in two places:
- **the pin inventory** (findings 1 and 2): 4 colour-pin statements, a header filter and 2 details pins are unlisted. The colour pins change in a way IC3 and IC6 do not describe, and moving the listed header pins cannot turn 2 cases green;
- **IC4's contract** (findings 3 and 4): it can be met by an `'ambiwidth'`-keyed or memoizing implementation that no requested test catches.

**The single most important change:** state IC4 as "measured with `strdisplaywidth()` at each rendering", and add its two cases — `setcellwidths()`, and a later `'ambiwidth'` change followed by `:edit` — with M8 and M9 as verification mutants.

Then:
- complete the pin list (findings 1 and 2);
- move the post-T13 facts into a dated amendment (finding 6);
- have the T14 and T12 amendments name T11, and quote T12's fence (finding 7).

## Other dimensions

- **records** (for the packet's review): the records review must check `tests/test_mcp_blocked_editor.lua:49` (75 after T13) by eye. A missed move there is invisible to the suite (finding 8).
- **attack:** try `setcellwidths()` on each icon, and an `'ambiwidth'` change between reports then `:edit`. Those are the two surfaces the brief's tests do not reach.

## Cleanup

- `lua/aineo/report/render.lua` and `doc/aineo.txt` were restored with `git checkout HEAD -- …`. `tests/test_brief_t11_probe.lua` was removed.
- `git status --short` prints nothing. Ignored: `.claude/local/`, `.tests/`, `deps/`, all inside this worktree.
- No process of mine is running: the three background suites exited, rc 0, 2 and 2 as recorded.
- `review_brief_t11` created nothing to release (`prepare_project` is empty).
- The worktree is left in place, detached at `3012cc7`.
