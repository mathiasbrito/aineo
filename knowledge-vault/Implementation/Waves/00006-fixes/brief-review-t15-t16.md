# Brief review: T15, Report instructions, and T16, right-column wrap (PR #36, `knowledge/w6-t15-t16` at `8db9732`)

*Verbatim. The files named `brief-t15-*` and `brief-t16-*` were the reviewer's scratch, not committed; its reopen probe and output are `evidence/window-option-scope.txt`'s probe 3. Every finding is answered in the corrected briefs and the plan's T15 and T16 sections; finding 13 by quoting the restatements put to the user.*

**Reviewer:** `reviewer`, brief dimension, Opus 5.5. Detached at `8db9732`, whose parent is `dev` `2596241`. The PR adds only `knowledge-vault/` files (5 files, +417), so every code fact below is `2596241`'s.
**Resources:** `review_brief_t15_t16`. `prepare-worktree.sh` printed `AGENT_RESOURCE=review_brief_t15_t16`; `prepare_project` is empty and created nothing. `make deps` ran in this worktree (mini.nvim `1345d19`).
**Instruments:** the host's `nvim` 0.12.5 and `<builds>/nvim-0.11.6/nvim-macos-arm64/bin/nvim` 0.11.6 (`nvim --version` checked through the brief's literal `env PATH=… make` form). All probes, mutants and outputs are in this worktree's `.claude/local/orchestrator/`, prefixed `brief-t15-`, `brief-t16-`, `brief-t13-` or under `brief-doc/`. I never ran the real `claude`, and wrote nothing outside this worktree.

**Labels** (the `brief` block): **CONFIRMED** means a statement is false or misleading, shown by the check given. **REFUTED** means I tried to fault the statement and could not. **MISSING** means something the packet, a rule or a slot needs is absent. **UNVERIFIABLE** as the charter defines it.

**The instruments that decide most findings.**
- **Reference implementations.** T16: `wrap_right_column()` in `lua/aineo/layout/init.lua`, setting the three options with `vim.wo[state.windows[role]][0][option] = true` for `report` and `input`, called in `open()` after `pin_windows()` (14 lines; `brief-t16-layout-reference.lua`). T15: `writing_lines()` in `lua/aineo/report/instructions.lua`, five lines under a `Write a report:` heading (15 lines; `brief-t15-instructions-reference.lua`).
- **The tests an implementer would write from the briefs.** `tests/test_layout_wrap.lua` (29 cases: RW1's four paths, RW2, RW3's scope cases, RW4) and `tests/test_report_writing.lua` (8 property cases for RI1–RI4). Uncommitted probes, not proposals.
- **Whole suites with both references:**
  - dev code, 0.11.6: **784 cases, `Fails (0)`**, rc 0 (747 existing + 37 probe cases; `brief-t15-t16-suite-ref-0116.txt`);
  - dev merged with T13's head `050bd97` (`git merge-tree --write-tree 2596241 050bd97` → `8eaf702`, its nine code, test and help files laid over the worktree), plus both references, plus the three-way-merged help (below), 0.12.5: **797 cases, `Fails (0)`**, rc 0 (`brief-t15-t16-suite-t13merge-0125.txt`);
  - the same on 0.11.6: **797 cases, `Fails (0)`**, rc 0 (`brief-t15-t16-suite-t13merge-0116.txt`).

  **No existing case pins anything either packet changes.** Neither packet has a pin to move, and T16 changes no screen any test reads.

---

## Findings, most severe first

### 1. CONFIRMED (T16): verification mutant 4 survives the test the plan names; RW1's "`\o` after the user closed the Report, Input or both" pins nothing about `\o`

- **The plan (l.322):** "the options set only on the first open — killed by `\o` after closing the Report".
- **Measured.** M4 = the reference with `wrap_right_column()` moved from after `pin_windows()` into `open()`'s `build()` branch (literal edit: delete `  wrap_right_column()` after `  pin_windows()`; add `    wrap_right_column()` after `    build(arrangement)`). Against the 29 probe cases, on both versions: **`Fails (2)`**, *reopen › after Input was wiped* and *reopen › after a user nowrap in the Report (RW2)*. **It survives** *after the Report closed*, *after Input closed* and *after both closed* (`brief-t16-wrap0125-M4.txt`, `brief-t16-wrap0116-*`).
- **Why.** A window closing saves its options in its buffer's window list. A window made again for that buffer takes them back. Measured on both versions without aineo (`brief-t16-reopen-probe.lua`, `brief-t16-reopen-out.txt`):

  ```
  first window, set: wrap=true lbr=true bri=true
  made again after the close, nothing set: wrap=true lbr=true bri=true
  a buffer never shown before, in a new window: wrap=false lbr=false bri=false
  ```

  So RW1's three close-and-reopen paths are red on `dev` (measured) but stay green whether or not `open()` sets the options again. The only tests that pin RW2's "`open()` sets them again" are RW2's own (`:setlocal nowrap`, then `\o`) and the wiped-Input path (a new buffer has no saved options).
- **Correction:**
  - plan l.322: "the options set only on the first open — killed by RW2's `:setlocal nowrap` then `\o`, and by `\o` after Input's buffer was wiped; **not** by `\o` after closing a window, which gets the closed window's options back from Neovim";
  - brief RW1, after the path list: "Closing a window and `\o` reopening it keeps the buffer's own options: Neovim gives the reopened window the options the closed one had. Those paths are red first but do not show that `open()` sets the options again; RW2's test does";
  - add the reopen probe and its output to `evidence/window-option-scope.txt` as probe 3.

### 2. CONFIRMED (T16): RW3 and RW4 cannot be seen red first

- **The brief (l.13):** "RW1 to RW4 tested, each test seen red first".
- **Measured on `dev`**, the 29 probe cases without the reference: `Fails (10)`, exactly RW1's and RW2's (`brief-t16-wrap-dev-0125.txt`). All 19 RW3 and RW4 cases pass. Nothing sets the options on `dev`, so a file split from the Report, the global values and Claude's window already hold the user's values.
- **They can fail, against a mutant.** M1 (window scope, `vim.wo[state.windows[role]][option] = true`) fails 18 of them. M7 (Claude's window too, `ipairs({ 'claude', 'report', 'input' })`) fails RW4's. Both by assertion, both versions.
- This is the lesson of T9's RC6/RC7 and T14's ID8 (`brief-review.md` #13, `brief-review-t14-input-draft.md` #6).
- **Correction:** l.13 "RW1 and RW2 tested, each test seen red first; RW3 and RW4 are invariants whose tests pass before the change — show each can fail by running it against a named mutant: the options set for the window (`vim.wo[win]`) for RW3, and Claude's window wrapped too for RW4; RW5 is an invariant".

### 3. CONFIRMED (T16): `vim.o.wrap` is not the global value

- **The brief (RW3, l.25):** "the user's global values (`vim.o.wrap` and the others) are unchanged".
- **Measured** (`brief-t16-vimo-probe.lua`, both versions): with `vim.o.wrap = false` and `vim.wo[win][0].wrap = true`, **in that window `vim.o.wrap` is `true` and `vim.go.wrap` is `false`**. `vim.o` reads the current window's value.
- **Failure scenario.** `open()` leaves the cursor in Input. A test written as the brief says, `eq(child.lua_get('vim.o.wrap'), false)`, fails against a correct implementation.
- **Correction:** "the global values are unchanged: `vim.go.wrap`, `vim.go.linebreak` and `vim.go.breakindent` (read with `vim.go`; `vim.o` reads the current window's value)".

### 4. MISSING (T15): the instructions go into Claude's whole system prompt, and nothing asks the new rules to be scoped to reports

- The text is `--append-system-prompt` (`lua/aineo/claude/arguments.lua:37–38`). It shapes Claude's replies in the terminal too, not only the tool call.
- RI1's third bullet, "never to explain the reasons for decisions — no whys", written as a bare line, tells Claude not to explain its reasoning in the conversation. The user scoped it: "the report window are the whats and how" … "an adjustment to what should be asked to the agent in the session" about the report window. My own reference's line `- Never explain the reasons for your decisions: no whys.` sits under a heading and still reads as general.
- The existing first line already draws this line ("in addition to your usual replies").
- **Correction:** add to RI1: "Every rule of RI1–RI4 is stated for a report — its `summary` and `details` — and says so in its own line, since the instructions are part of Claude's whole system prompt. Claude's replies in the terminal are unchanged." It is testable as a property: every line of the new block names a report or one of its fields.

### 5. CONFIRMED (T15): RI5 freezes "the four fields", but `details`' description then contradicts RI3

- **`field_lines()`** tells Claude that `details` is "optional further lines, such as the files you changed or the question the user must answer" (brief l.44).
- **RI3:** a `done` lists "what was done — the features".
- **RI5 (l.28–30):** "These stay as they are … the four fields". It does not say whether a field's description may change. The pins check only `` `details`: `` (`tests/test_report.lua:167`).
- **Failure scenario.** The implementer keeps the field text, as RI5 reads. A `done` report then has two instructions for `details`: files changed, or features. Claude follows the first, and lists paths. Every test is green, and the user's "if it is a done, to list what was done, which features" is not met.
- **Correction:** RI5: "the tool's name, the four field names, and the statuses with their moments stay as they are, as the existing pins check. The `details` description may change to agree with RI2–RI4; say so in the report."

### 6. MISSING (T15): the other statuses

- RI1 applies to every report. RI2 and RI3 name `started` and `done`. The brief says nothing of `progress`, `blocked` and `failed`, beyond their moments (l.120–121).
- "No whys" meets `blocked` (the question the user must answer, which the `details` description asks for) and `failed` ("when the task cannot be completed"). An implementer who writes "Never explain why" makes Claude's `failed` reports leave out what stopped the task.
- **Correction** (a reading, for the MVP review): "RI1 holds for every status. What blocks a task and what made it fail are stated as facts, in the whats; what is left out is the reasoning behind Claude's choices."

### 7. CONFIRMED (low, T15): RI4's placement and form are read two ways

- **"The very end is the last line of `details`"** (l.26). It can mean a line of its own or the end of the last line. With RI2/RI3's "one feature per line", the second attaches the references to the last feature. **Correction:** "on a line of its own, the last line of `details`; or, when a report has no details, at the end of `summary`".
- **The task row says "by number only"; RI4 says "by number or ID only"**, and its example is IDs (`D18`, `C12`). An implementer copying the row writes "number only", which the example contradicts. **Correction:** the row, "by number or ID only" (the plan note's row, in this PR).

### 8. CONFIRMED (low, T15): two of the plan's mutants

- **"The instructions' first line changed" (plan l.289)** is not a literal edit. It is killed only when the tool name goes:
  - `:format(tool_name)` → `:format('mcp__aineo__report')`: killed by *names the tool it is given* (renamed);
  - `Keep it current by calling the \`%s\` tool, in addition` → `Keep it current, in addition`: killed by both cases of it.
  - Any change keeping `` `%s` `` survives, since nothing pins the rest of that line.
  - **Correction:** name the first form above.
- **Placement is not among the mutants.** TM7, `at the very end of the report` → `at the very start of the report`, **survived** my RI4 test, which looked for "end": "the end of `summary`" also holds it (`brief-t15-writing-TM7.txt`). **Correction:** add "references placed at the start rather than the end", killed by a test that pins "very end".

### 9. MISSING (low, both): the facts T15's and T16's merges move in the briefs that wait for them

The T11 section (plan l.257) named the amendments that T11 made necessary. These sections name the waits, not the facts.
- **T11's brief l.92** gives `*aineo-report*` as "lines 253–305 at `dbc96c9`; T13 moves every line from 39 on down by one". T15 adds lines at 256–257, above every line T11 cites in that section.
- **T14's brief l.88** says "When T13 (PR #31) merges, only the help's line numbers move". After T16 that is false: T16 changes `lua/aineo/layout/init.lua` and T14's own section, `*aineo-layout*`.
- **T12's brief** cites `lua/aineo/layout/init.lua` lines (l.61–63) that T16 may move.
- **Correction**, in both sections: "T11's dated amendment re-checks its help line numbers after T15's merge. T14's and T12's re-check `lua/aineo/layout/init.lua` and `*aineo-layout*` after T16's merge. T14's line 88 names T16."

### 10. CONFIRMED (low, T16): three wordings an implementer could test literally

- **RW1 (l.15)**, "Whenever the layout is open, the Report's window and Input's window … have 'wrap', 'linebreak' and 'breakindent' on", is broken by RW2's own "A user's `:setlocal nowrap` in the Report lasts until the next `\o`". **Correction:** "Whenever the layout opens or is restored, … have … on".
- **RW1's path list (l.17–21)** leaves out `show_buffers()`, which the seam note names (l.36): `\o` after a help, terminal or scratch buffer, or a file the file column had no room for, took the Report's or Input's window. My case for it passes with the reference and fails on `dev`. No mutant is killed by it alone: M6, `open()` setting the options only when a window was missing, is killed by RW2's test. **Correction:** add the path.
- **Facts l.45**, "`open()` … runs one of the first two, then `pin_windows()`". In the restore branch it runs `reopen_closed_windows()` then `show_buffers()` (`lua/aineo/layout/init.lua:616–617`). **Correction:** "runs `build()`, or `reopen_closed_windows()` then `show_buffers()`, then `pin_windows()` and the proportions".

### 11. MISSING (low, both): the help check's Neovim version

- Step 3 of the pre-push check (T15 l.106, T16 l.107) says `make test_file FILE=tests/test_doc.lua` with no version. T13's correction runs it on both.
- `test_doc.lua` passed 36/0 on both versions on every merged file I built (finding 16).
- **Correction:** "on both versions".

### 12. CONFIRMED (cosmetic, T15): `tests/test_report.lua` lines 134–170

The `report_instructions()` group runs from `:134` to `:168`. `:170` is `T['set_report_environment()']`. **Correction:** 134–168.

### 13. UNVERIFIABLE: the orchestrator's restatement

- The user's words for both packets match the ledger verbatim, for T15 from "for the agent it must be clear" on (the ledger's quote opens on another subject).
- The text of the restatement the user answered — plan `started`, features one per line, the example `(D18, C12, #31)`, the list of document kinds — is not recorded. The ledger holds only the answers: "Right, as a small fix (Recommended)" and "Word wrap, small fix (Recommended)".
- The briefs quote both answers without "(Recommended)". Wave 7's rows record that label ("Agree (Recommended)", the orchestrator's recommended option). **Correction:** record the restatement as put to the user, and that each answer was the recommended option.

### 14. MISSING (low, plan): the host's three slots

- The plan (l.91) says the host takes three agents at once. T13's correction, T15 and T16 fill them.
- A small fix's two reviews go "in one message" (SKILL §3). When T15's pull request arrives, one slot frees and two are needed.
- **Correction:** the sections say the reviews wait for a second free slot. Or the order: T15 and T16 reviewed one after the other.

---

## REFUTED: what I checked that held

15. **The class.**
  - **T15** changes one behaviour in `lua/aineo/report/`, with its tests and the help. **T16** changes one behaviour in `lua/aineo/layout/`, with its tests and the help.
  - Neither reaches a §3 exclusion. Both briefs list them and add `plugin/aineo.lua` whole, which is stricter than §3 and costs neither.
  - Both references needed only their one file.
  - **"No row" for T15 is sound:**
    - C6 says "the appended prompt tells Claude when to report". The module has said "when to report, and how" since T8 (`instructions.lua:1`), and `field_lines()` already says how to fill each field.
    - T9's row is the precedent: "Report colours (C6) … a small fix", no C row.
    - The user's words: "just an adjustment to what should be asked to the agent in the session".
16. **The help fences and merges.**
  - All six quoted fence lines are byte-exact in both briefs (`brief-t15-t16-fences.lua`: `doc/aineo.txt:36`, `:48`, `:51`, `:86`, `:253`, `:305`). The same six lines, text unchanged, are at `:36`, `:49`, `:52`, `:87`, `:254` and `:281` in T13's head `050bd97`.
  - I made test edits at both edges of each section. T15: `:256–257` rewritten to 3 lines, and its last line `:305`. T16: its first body line `:53` and its last line `:86`.
  - `git merge-file` merged clean, rc 0, in every case: T15 × T16 on `dev`; T15 × T13 and T16 × T13 on the merge base `d35dc4f`; and all three (`brief-doc/m_*.txt`). The three-way file has 423 lines = 419 + 1 + 2 + 1.
  - `tests/test_doc.lua` passed 36/0 on the three-way file inside both whole-suite runs, and on each pairwise file on both versions (see *Suites*).
  - Neither packet adds a tag, so E154 cannot arise.
17. **Would T15, T16 and T13's correction collide?** No.
  - T13's correction touches only `plugin/aineo.lua`, `lua/aineo/mcp/editor.lua`, `tests/helpers/report_tui.lua`, new cases in `tests/test_entry.lua` and `tests/test_mcp_delivery.lua`, and its session note (`orch-correction-t13.md` › *Boundary*).
  - PR #31's files meet T15's and T16's only in `doc/aineo.txt`, in other sections.
  - The whole suite over dev + T13's head + both references + the merged help is 797/0 on 0.12.5.
18. **The user's words** in both briefs and both sections match the ledger verbatim (finding 13 for the restatement).
19. **RI1–RI4 can each be tested red first as a property of the text**, not by a golden copy.
  - Eight property cases each find one line holding the clause's words, such as `` `started` ``, "features planned" and "one per line" together. All eight are red on `dev` (`Fails (8)`) and green on the reference.
  - The plan's mutants TM1–TM4 each die by assertion against them. TM3b is the "by number only" removal.
20. **Nothing else carries the instructions' text.**
  - `git grep` for each of its phrases in the repository outside the vault finds only `instructions.lua`.
  - The fake `claude` records `argv` through `vim.json.encode` (`tests/helpers/fake_claude.lua:144`, `:376`).
  - `tests/test_entry.lua:124–134` compares the argument after `--append-system-prompt` with the live `report_instructions()`. `tests/test_claude.lua:124–132` uses the stand-in `claude_session.stand_in_settings().instructions`. `lua/aineo/health.lua` never reads them, and no recorded transcript under `tests/fixtures/` holds them.
  - With the reference, `test_entry` and `test_claude` pass: on 0.11.6 over `dev`, and on both versions over T13's head.
  - `lua/aineo/report/init.lua:34–36`, "telling it when and how to call the report tool", stays true, so T15's boundary, which excludes that file, costs nothing.
21. **Every T15 fact at `2596241`:**
  - the task row, byte-exact at plan note l.126;
  - C6's words (plan note l.68);
  - `field_lines()` 20–30, `status_lines()` 32–39, `report_instructions()` 41–58, with both quoted field texts;
  - `format.STATUSES` 9–13;
  - `protocol.lua:32`, `plugin/aineo.lua:92` (also `:92` in T13's head);
  - `tests/test_entry.lua:18`;
  - the help, `:255–257`.
22. **Every T16 fact at `2596241`:**
  - the task row, byte-exact at l.127;
  - `pin_windows()` 170–175, called at `:622`;
  - `build()` 459–483, `reopen_closed_windows()` 485–506 and `show_buffers()` 508–517, each with its docstring, and `open()` 607–625;
  - the git grep, which prints nothing, exit 1, and whose bare `wrap` matches only `health.lua:113` and `plugin/aineo.lua:169`;
  - the five `tests/test_layout*.lua` files;
  - `T['focus()']['reopens the closed window of']` at `tests/test_layout.lua:396`;
  - `*aineo-layout*` 51–86, which says nothing of wrapping (the help's only "wrap" words are `:218` and `:349`, "wrapper").
23. **The evidence re-measured.** Both probes of `evidence/window-option-scope.txt`, extracted verbatim from its comments (`brief-t16-probe1.lua`, `brief-t16-probe2.lua`), print exactly the file's output on 0.12.5 and 0.11.6+ge8b87a554f, rc 0 (`brief-t16-probes-out.txt`).
24. **`'breakindent'` does what the brief says** (`brief-t16-breakindent-probe.lua`, both versions, a window 30 columns wide).
  - A details line, indented 6 as `render.lua:20` does, continues at window column 6.
  - A header line continues at column 0.
  - `'linebreak'` breaks both between words: at byte 27, "summary", rather than 33, mid-word.
25. **RW3's `:setlocal` scope survives every path I could build.** Each passes with the reference on both versions.
  - **Nothing leaks.** Each of these keeps the user's values, and M1 (window scope) fails each:
    - the file column a file is redirected to, from the Report or from Input;
    - the file column opened from the Report with Claude's window closed (`open_file_column()`'s `split = 'left', win = -1` path);
    - `:vsplit <file>`, `:new`, `:tabnew`, `:tabedit <file>` and `:help` from either window;
    - a scratch buffer shown in either window;
    - the current window's global values (`vim.go`).
  - **Aineo's buffers keep theirs:**
    - the window's own buffer given back after a redirect;
    - `show_buffers()` putting the Report back;
    - `\o` after closing either window or both;
    - `:edit` and `:edit!` in a `BufReadCmd`-refilled scratch buffer, as the Report is (`brief-t16-edit-probe.lua`).

  `\o` from another tab sets the options in the layout's tab only, since `open()` enters that tab first. The probe test files are kept as `brief-t16-test_layout_wrap.lua` and `brief-t15-test_report_writing.lua`.
26. **No pin moves** (the whole suites above). RW5 holds: every case of the five `tests/test_layout*.lua` files is green with the reference, and so is every other suite. T13's TUI cases in `tests/test_mcp_blocked_editor.lua` (80×24) are green over T13's head.
27. **The plan's other mutants compile and die by assertion** against tests the briefs ask for (table below): T16's M1, M2, M3 and M5, and T15's five.
28. **The baseline.**
  - `git diff --stat dbc96c9 2596241 -- lua plugin tests doc scripts Makefile` prints nothing.
  - `evidence/baseline-dbc96c9.txt` holds 747 cases on both versions, `Fails (8)` on 0.12.5 and `Fails (0)` on 0.11.6, the eight named.
  - My 0.11.6 run of the dev code with the references is 747 + 37 cases, `Fails (0)`.
29. **The six rules' waits.** "T11 waits for T15, T14 for T16" is right and sufficient; see the table.
30. **The slots.**
  - Every field of `prompts/packet-brief.md` is present and non-empty in both briefs.
  - Branches: `bugfix/`, as the template gives a small fix.
  - Resources: `impl_t15_report_instructions` and `impl_t16_right_column_wrap`, both valid for `prepare-worktree.sh`.
  - Model `opus`, and the §3 class paragraph with the pull-request titles.
  - Session notes `… — T15 Report instructions.md` and `… — T16 Right column wrap.md`, distinct from each other and from every name under `Sessions/`.
  - Scratch prefixes `t15-` and `t16-`, distinct.
  - Budget and report shape named.
  - The literal 0.11.6 form works as written.

---

## Mutants

Each mutant is the reference with one literal edit, applied from a generated file (`brief-t16-make-mutants.lua`, `brief-t15-make-mutants.lua`, each asserting that its edit matched exactly once) and restored after its run (`cmp` confirmed). Every kill is an assertion failure (`Failed expectation for equality`), read in the output.

| # | literal edit | tests | 0.12.5 | 0.11.6 |
|---|---|---|---|---|
| **T16 M1** (plan 1) | `vim.wo[state.windows[role]][0][option] = true` → `vim.wo[state.windows[role]][option] = true` | probe file (29) | killed, 18 fails, all RW3 | killed, 18 |
| **T16 M2** (plan 2) | `{ 'wrap', 'linebreak', 'breakindent' }` → `{ 'wrap', 'breakindent' }` | probe file | killed, 10 (RW1, RW2) | — |
| **T16 M3** (plan 3) | → `{ 'wrap', 'linebreak' }` | probe file | killed, 10 | — |
| **T16 M4** (plan 4) | the call moved from after `pin_windows()` into the `build()` branch | probe file | **killed only by** *after Input was wiped* and *RW2*; **survives** *after the Report / Input / both closed* | same |
| **T16 M5** (plan 5) | `ipairs({ 'report', 'input' })` → `ipairs({ 'report' })` | probe file | killed, 5 | — |
| T16 M6 (mine) | `open()` sets the options only when a window was missing (`local reopened = not is_open()`, `if reopened then … end`) | probe file | killed by RW2 alone | same |
| T16 M7 (mine) | `ipairs({ 'report', 'input' })` → `ipairs({ 'claude', 'report', 'input' })` | probe file | killed by RW4 alone | same |
| **T15 TM1** (plan 1) | the `` `started` `` line deleted | property file (8) | killed, RI2 | — |
| **T15 TM2** (plan 2) | the `` `done` `` line deleted | property file | killed, RI3 | — |
| **T15 TM3a** (plan 3) | the references line deleted | property file | killed, 3 RI4 | — |
| **T15 TM3b** (plan 3) | `, by number or ID only, with no explanation` → `` | property file | killed, RI4 | — |
| **T15 TM4** (plan 4) | the no-whys line deleted | property file | killed, RI1 | — |
| **T15 TM5a** (plan 5) | `:format(tool_name)` → `:format('mcp__aineo__report')` | `tests/test_report.lua` (42) | killed, renamed-tool case | — |
| **T15 TM5b** (plan 5) | `` Keep it current by calling the `%s` tool, in addition `` → `Keep it current, in addition` | `tests/test_report.lua` | killed, 2 | — |
| T15 TM6 (mine) | `` When you report `started` for a plan `` → `When you report a plan` | property file | killed, RI2 | — |
| T15 TM7 (mine) | `at the very end of the report` → `at the very start of the report` | property file | **survived** (finding 8) | — |

**Summary:** 16 mutants; 14 killed by assertion, M4 killed only by tests other than the one the plan names, TM7 survived. Those two are findings 1 and 8. "—" means not run there: M1, M4, M6 and M7 were run on 0.11.6 as the scope-sensitive ones and matched 0.12.5.

---

## The six rules, recomputed from the briefs

Open packets: T13 (PR #31, bounded correction). Planned: T11, T14, T12, and T10 after T11. Claimed waves: this one only. Open pull requests: #31 and #36 only (`gh pr list`).

| rule | T15 | T16 | T13's correction beside them |
|---|---|---|---|
| 1 dependencies | T8, done ✓ | T8, done ✓ | — |
| 2 files | `lua/aineo/report/instructions.lua`, `tests/test_report.lua` (new cases), `doc/aineo.txt` › `*aineo-report*`. ∩ T13: the help only, another section. ∩ T16: the help only. ∩ T11: the same section → **T11 after T15** ✓. ∩ T14, T12: other help sections ✓ | `lua/aineo/layout/`, `tests/test_layout*.lua` (new cases or a new file), `doc/aineo.txt` › `*aineo-layout*`. ∩ T13: the help only. ∩ T14: the same section → **T14 after T16** ✓. ∩ T12: `layout/`, `test_layout*.lua` → T12 after T14, after T16 ✓. ∩ T11: other help sections ✓ | its five code/test files meet neither; the help merges clean three-way, `test_doc` 36/0 |
| registration files and pins | none: tests are collected by glob; `test_doc.lua` derives its tags; neither adds a tag; the reference suites show no pin moves | same | — |
| 3 schema | none ✓ | none ✓ | — |
| 4 dependencies | none ✓ | none ✓ | — |
| 5 decisions | decided ("Right, as a small fix (Recommended)"); findings 5–7 are readings to record | decided ("Word wrap, small fix (Recommended)"); RW2 a recorded reading ✓ | — |
| 6 task lines | rows T14 (l.125), T15 (l.126), T16 (l.127) adjacent, gap 0: every mark held ✓ | same ✓ | T13's l.124 held ✓ |

**Sufficient.**
- T10 follows T11, which follows T15. T12 follows T14, which follows T16.
- T11 and T14 still run side by side after these merges, since T11 is in `*aineo-report*` and the report home while T14 is in `*aineo-layout*` and must not touch `lua/aineo/layout/`.
- What is not yet said is which of their facts move (finding 9).

---

## Verdict

- **T15 — dispatch after corrections: findings 4, 5, 6, 7, 8 and 12.**
  - Finding 4 matters most: the new rules must say they are about reports, or "no whys" reaches Claude's whole conversation.
  - Finding 5: RI5 must say whether `details`' description may change.
- **T16 — dispatch after corrections: findings 1, 2, 3 and 10.**
  - The plan's mutant 4 must name the tests that kill it (RW2's and the wiped Input), and RW1 must say that close-and-reopen keeps the options by itself.
  - RW3 and RW4 must be invariants with named mutants.
  - `vim.o` must become `vim.go`.
- **The wave:** findings 9, 11, 13 and 14 go into the two plan sections.

The references confirm the rest. No pin in any suite moves, both evidence probes reproduce, and the help merges clean with T13's head on both versions. The single most important change is finding 1, with finding 2: without them, an implementer can pass every test the brief asks for with `\o` never setting the options again, and the plan's verification would record the survivor as killed.

## Other dimensions

- **Records:** the plan's T15 section says "No row … as T9 added colours to C6's Report". True, and the row, C6 and the help sentence should all move together at the knowledge pass. C6 still says only "when to report".
- **Attack (T16):** a user's `BufWinEnter` or `FileType` autocommand that sets `nowrap` wins after a redirect. The row's "whatever the user's own setting" promises more than `vim.o.wrap = false` tests.

## Suites

Each ran one at a time, with its output in a file. `uptime` showed a load of 24–64 during the runs, and no run failed a case.

| run | code | cases | result |
|---|---|---|---|
| 0.11.6 | `dev` + both references + 37 probe cases | 784 | `Fails (0)`, rc 0 |
| 0.12.5 | `dev` ⊕ T13 `050bd97` (tree `8eaf702`) + both references + three-way help + probes | 797 | `Fails (0)`, rc 0 |
| 0.11.6 | the same | 797 | `Fails (0)`, rc 0 |
| probe file `test_layout_wrap` | `dev`, 0.12.5 | 29 | `Fails (10)`: RW1 and RW2, red first |
| probe file `test_layout_wrap` | reference, both versions | 29 | `Fails (0)` |
| probe file `test_report_writing` | `dev` / reference, 0.12.5 | 8 | `Fails (8)` / `Fails (0)` |
| `tests/test_report.lua` | reference, 0.12.5 | 42 | `Fails (0)` (RI5) |
| `tests/test_doc.lua` on `m_15_16`, `m_15_13`, `m_16_13`, `m_all` | T13 overlay, both versions | 36 each | `Fails (0)` ×8 |

## Cleanup

- The worktree is back at `8db9732`. Everything I changed was restored:
  - the nine T13 files, put back with `brief-t13-overlay.sh restore`;
  - `lua/aineo/layout/init.lua` and `lua/aineo/report/instructions.lua`, with `git checkout HEAD -- …`;
  - the two probe test files, removed after copies were kept in the scratch.

  `git status --short` then printed nothing, and `git log -1 --oneline` printed `8db9732 Add T15 and T16 to wave 6: report instructions, right-column wrap`.
- Every file I wrote is in this worktree's `.claude/local/orchestrator/`, which is gitignored (`.gitignore:39:.claude/local/`). The one exception: the `make deps` log first went to `/tmp`, and I moved it into the scratch at once.
- `review_brief_t15_t16` created nothing: `prepare_project` is empty. Nothing to release.
- No background process of mine is running: all three suite runs exited, rc 0.
- I committed nothing, pushed nothing, and wrote nothing in `<builds>`.
