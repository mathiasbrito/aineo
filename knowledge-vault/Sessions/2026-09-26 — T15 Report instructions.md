# 2026-09-26 — T15 Report instructions

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t15-report-instructions` · **Pull request:** #39 into `dev` (a small fix, orchestrate §3)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C6; D10)
- [[Implementation/Waves/00006-fixes/plan]] § *Packet T15 — 2026-09-26*, its brief `brief-t15-report-instructions.md`, its brief review `brief-review-t15-t16.md`, the baseline `evidence/baseline-dbc96c9.txt`
- The fix round's inputs, both reviews of pull request #39:
  - the guarantee review: findings G1–G5, its mutants G1–G11, and its tighter pins;
  - the records review: findings R1–R7.

## Context

**Goal:** T15. On 2026-09-26 the user asked that Claude write the Agent Report for a person:
- in plain language;
- the whats and hows, never the whys;
- a plan's features, or what was done, listed;
- references to documents at the end, in parentheses, "only citing numbers".

The user called it a small fix. It rests on C6: "the appended prompt tells Claude when to report". T15 adds *how to write* a report to that prompt.

## What was done

- **`lua/aineo/report/instructions.lua`:** a private `writing_lines()`. It holds eight rules under the heading `Write a report for the user to read:`, and `report_instructions()` joins them last.
  - **RI1:**
    - for a person, in plain language, with `summary` and `details` describing what is being reported;
    - what was done or planned, and how;
    - never the reasons for Claude's decisions: no whys;
    - a `blocked` or `failed` report states, as a fact, what blocks the task or what stopped it.
  - **RI2:** a `started` report of a plan lists the features planned in `details`, one per line.
  - **RI3:** a `done` report lists what was done, the features, in `details`, one per line.
  - **RI4:**
    - references to decisions, components, tasks, issues, pull requests and docs go at the very end, in parentheses, by number or ID only, with no explanation, such as `(D18, C12, #31)`;
    - they go only there, nowhere else in the report (added in the fix round, G5);
    - the very end is a line of its own, the last line of `details`, or the end of `summary` when a report has no `details`.
  - **Scope:** every line names a report or one of its fields. The text joins Claude's whole system prompt, and its rules are for reports, not for Claude's replies in the terminal.
- **The `details` description** changed from "such as the files you changed or the question the user must answer" to "such as the features planned or done, or the question the user must answer". The old text contradicted RI3 (RI5's allowance).
- **Unchanged (RI5, RI6):**
  - the first line naming the tool;
  - the four field names;
  - each status's moment (`format.STATUSES`);
  - the report format and its validation;
  - the MCP tool's schema and description;
  - the Report's rendering.

  The pins of `report_instructions()` from before T15 stayed green unchanged.
- **Docstrings:**
  - `writing_lines()` is new, and since the fix round it lists all eight rules (R1).
  - `report_instructions()`'s docstring now names the writing block.
- **`doc/aineo.txt`**, inside `*aineo-report*` only:
  - The list item on the appended instructions says they also tell Claude how to write a report.
  - A new paragraph says what they ask. Since the fix round (R1) it covers all eight rules: it has "never the reasons for its decisions" in place of "never why", the `blocked`/`failed` rule, and "only at the very end".
  - It also says the rules are for reports only, and that a running Claude Code keeps the instructions it started with.
- **`tests/test_report.lua`:** thirteen new cases under `report_instructions()`, ten in the packet and three in the fix round.
  - The four helpers are documented: `line_with`, `block_under`, `writing_block` and `lines_naming_no_report`.
  - No case from before T15 changed.

## Decisions & reasoning

- **The writing rules are a block of their own,** under their own heading, joined after the status lines. The pins of the first line, the fields and the statuses stayed as they were (RI5).
- **Every rule names a report or one of its fields.** The text is appended to Claude's whole system prompt through `--append-system-prompt`, so an unscoped rule such as "never explain why" would govern Claude's terminal replies as well.
- **MR109's reading has its own line.** The orchestrator reads RI1 for every status: what blocks a task, or stopped it, is a fact among the whats. The wording of that line is mine: "state as a fact what blocks the task or what stopped it". That way "no whys" cannot suppress it.
- **The `details` description offers the features** (RI5's allowance). "The files you changed" contradicted RI3.
- **The instructions are pinned word for word, in three tests** (the fix round, the orchestrator's decision on G1–G4):
  - the writing block;
  - the field block;
  - the first line.

  Phrase pins on one line had passed texts that said the opposite of a rule. The instructions are text given to Claude, so any change to them should be deliberate. The phrase cases stay, so that each rule is named by a test.
- **"Only there, nowhere else in the report"** (the fix round, G5, the orchestrator's decision). Before, the rule said where references go, but it did not keep them out of `summary` or `task`.
  - The clause is added after the example. That leaves the guarantee reviewer's G1 edit site, `docs at the very end, in parentheses`, intact, so G1 could be re-run as its literal edit.
  - It does not say "never in `summary`": a report without `details` ends its `summary` with the references.
- **Commit `6ac74cf`'s message is wrong about the user's words (R2).** It says the user asked for references "by number or ID only". The user said "only citing numbers". "Or ID" is the brief's reading, which counts an ID such as `D18` as a number. The pushed history is not rewritten; the fix round's commit message says so.

## Unit list and red/green

Every red was seen on the host's 0.12.5 through `make test_file FILE=tests/test_report.lua`.

| # | Behaviour | Test (under `report_instructions()`) | Status |
|---|---|---|---|
| 1 | RI1 | *asks for each report to be written for a person, in plain language, saying what is reported* | red: `Left: false, Right: true` |
| 2 | RI1 | *asks each report to say what was done or planned, and how* | red: `Left: false, Right: true` |
| 3 | RI1 | *asks each report never to explain the reasons for decisions* | red: `Left: false, Right: true` |
| 4 | RI1, every status | *asks a blocked or failed report to state what blocks or stopped the task as a fact* | red: `Left: false, Right: true` |
| 5 | RI2 | *asks a started report of a plan to list the features planned in its details, one per line* | red: `Left: false, Right: true` |
| 6 | RI3 | *asks a done report to list what was done, the features, in its details, one per line* | red: `Left: false, Right: true` |
| 7 | RI4 | *asks a report to cite documents at its very end, in parentheses, by number or ID only, with an example* | red: `Left: false, Right: true` |
| 8 | RI4, "very end" | *places the very end of a report on a last line of details, or at the end of a summary without details* | red: `Left: false, Right: true` |
| 9 | RI5's allowance | *offers the features planned or done as the details of a report* | red: `Left: false, Right: true` (the description offered files changed) |
| 10 | RI1's scope | *states every rule on writing for a report or one of its fields* | arrived green: it pins the lines units 1–8 wrote, each naming a report or a field; killed by M6 |
| 11 | G5 (fix round) | *states the rules on writing a report word for word* | red on `44f2c06`'s code: `different values at key 8` (the references line, without "only there, nowhere else in the report"); green once the clause was added |
| 12 | G4 (fix round) | *asks for reports in addition to the usual replies, word for word, in its first line* | arrived green: it pins a line from before T15; killed by G10 |
| 13 | G3, G5 (fix round) | *describes the fields of a report word for word* | arrived green: it pins the field lines as T15 left them; killed by G5 (a line added after the `details` field) |

**Units 1, 2, 5 and 7 were tightened in the fix round** (guarantee G1, G2). Their phrase sets now keep the verb or subject next to the rule. The phrases are the guarantee reviewer's measured `guarantee-tight.lua`, adopted with credit:
- unit 1: `'each report for a person'`;
- unit 2: `'In a report, say what was done or planned, and how'`;
- unit 5: ``'`started` report of a plan'`` and `'features planned, one per line'`;
- unit 7: `'docs at the very end'`.

They are green on the code. They are red against G8 (unit 1), G2 (unit 2), G6 and G7 (unit 5) and G1 (unit 7), as the mutant table shows.

**How the packet's units went red and then green** (the records review asked):
- **One at a time, in two tool calls each.** The first call wrote one test and ran `make test_file`, saving `t15-red<n>.txt`. The second added one line of production code and ran the file again, saving `t15-green<n>.txt`.
- **In order.** The next unit started only after that green. The 5–6 s between files is how long one `make test_file` of `tests/test_report.lua` takes.
- **No replay.** No script replayed prepared edits.
- **Wording chosen in advance.** I had drafted the rules' wording in my reasoning before the first test, so each call wrote text already chosen.
- **Every red read first.** Each red was seen and read before its line was written.

## Mutants

**How they ran:**
- one at a time, from a pristine copy (`t15-mutants.py` in the scratchpad);
- on the fix round's code (`7dfdec6`), which is the code this pull request ships;
- against `.tests/t15-instructions.lua`, `tests/test_report.lua` narrowed to its `report_instructions()` group (24 cases).

**Results:**
- All 27 were killed by assertion failures (`Failed expectation`). Each row names every case that failed.
- No mutant survived, so none went back to the whole file.

**Where the rows come from:**
- **M1–M14:** the packet's mutants. The packet's run, on `6ac74cf` against 21 cases, killed each with the first unit its row names. The M rows before M15 held at that head too.
- **M4:** now edits `docs at the very end`, not `at the very end`. The fix round's docstring put "at the very end, in parentheses" in the file a second time; the substance is the same.
- **M15:** the fix round's "only there".
- **G1–G11:** the guarantee reviewer's literal edits. Each had survived the whole file at `44f2c06`.

**The test names the table uses:**
- *block* is *states the rules on writing a report word for word*;
- *fields* is *describes the fields of a report word for word*;
- *first line* is *asks for reports in addition to the usual replies, word for word, in its first line*.

| # | Literal edit in `instructions.lua` | Failing cases |
|---|---|---|
| M1 | the `started` line deleted | unit 5, block |
| M2 | the `done` line deleted | unit 6, block |
| M3 | the references line deleted | unit 7, block |
| M3b | `by number or ID only, with` → `by number or ID, with` | unit 7, block |
| M4 | `docs at the very end, in parentheses` → `docs at the very start, in parentheses` | unit 7, block |
| M4b | `The very end of a report is` → `The very start of a report is` | unit 8, block |
| M5 | the no-whys line deleted | unit 3, block |
| M6 | `'- Never explain the reasons for your decisions.',` added after the last rule | unit 10, block |
| M7 | `tool_name` → `'mcp__aineo__report'` in the first line's `:format()` | *names the tool it is given* (`mcp__renamed__report`) |
| M8 | the plain-language line deleted | unit 1, block |
| M9 | the "and how" line deleted | unit 2, block |
| M10 | the `blocked`/`failed` line deleted | unit 4, block |
| M11 | `such as the features planned or done, or the question` → `such as the files you changed or the question` | unit 9, fields |
| M12 | `` , such as `(D18, C12, #31)` `` deleted | unit 7, block |
| M13 | `` a line of its own, the last line of `details` `` → `` the last line of `details` `` | unit 8, block |
| M14 | `in parentheses, by number or ID only, with` → `by number or ID only, with` | unit 7, block |
| M15 | `: only there, nowhere else in the report.` → `.` | block |
| G1 | `docs at the very end, in parentheses` → ``docs at the very start of `summary`, never at the very end, in parentheses`` | unit 7, block |
| G2 | `'- In a report, say what was done or planned, and how.'` → `'- In a report, never say what was done or planned, and how.'` | unit 2, block |
| G3 | `never explain the reasons for your decisions: no whys.` → `never explain the reasons for your decisions briefly: give every why in full.` | block |
| G4 | `'- In every reply in the terminal, as in a report, never explain why.',` added after the last rule | block |
| G5 | `'- Reply to the user in plain language and never explain why.',` added after the `details` field line | fields |
| G6 | `the features planned, one per line.` → `the features planned, all on one line, not one per line.` | unit 5, block |
| G7 | ``In a `started` report of a plan to implement, `details` `` → ``In a `started` report, `details` `` | unit 5, block |
| G8 | `Write each report for a person` → `Write each reply in the terminal for a person` | unit 1, block |
| G10 | `in addition to your usual replies` → `instead of your usual replies` | first line |
| G11 | `what blocks the task or what stopped it.` → `what blocks the task or what stopped it, and why you chose to stop.` | block |

The guarantee reviewer's G9 (the heading deleted) was killed at `44f2c06` by the helper's `assert`, and it is not re-run. `block_under` keeps that precondition.

## Suites

**Packet**, on code commit `6ac74cf`:
- 0.12.5: 757 cases, `Fails (8)`, the baseline's eight T13 failures by name.
- 0.11.6: 757 cases, `Fails (0)`.

**Fix round**, on code commit `7dfdec6`, one run after the other, with load averages 140 to 170:
- **0.11.6** (`env PATH=<builds>/nvim-0.11.6/… make test`): 760 cases, `Fails (0)`, rc 0.
- **0.12.5** (`make test`): 760 cases, `Fails (8)`, rc 2. These are the eight of `evidence/baseline-dbc96c9.txt`, by name, and no others.
- The count is 747 at baseline plus the 13 new cases.
- `make lint`: 0 errors, 0 warnings. `make format` changed nothing after the last edit.

**Merge checks of the shared help** (`git merge-tree --write-tree`; each exited 0 and listed no conflict). For each, `tests/test_doc.lua` ran on the merged tree's `doc/aineo.txt`, then the help was restored from `HEAD`:

| Merge | Tree | `test_doc.lua`, 0.12.5 | `test_doc.lua`, 0.11.6 |
|---|---|---|---|
| `6ac74cf` (the packet's code commit) with `origin/bugfix/t13-neovim-0-12` at `079d632` | `9bf69a0` | 36 cases, `Fails (0)` | 36 cases, `Fails (0)` |
| `7dfdec6` (the fix round's code commit) with `origin/dev` at `2502334`, T13 merged | `87023fd` | 36 cases, `Fails (0)` | 36 cases, `Fails (0)` |
| `7dfdec6` with `origin/bugfix/t16-right-column-wrap` at `f03b826` | `600d4c1` | 36 cases, `Fails (0)` | 36 cases, `Fails (0)` |

## Readings for the MVP review

- **RI1 for every status** (the orchestrator's reading, MR109):
  - What blocks a task (`blocked`) and what stopped it (`failed`) are facts, among the whats. What is left out is the reasoning behind Claude's choices.
  - The instructions say so in their own line, so "no whys" does not keep Claude from saying what blocks it.
- **"A plan to be implemented" is a `started` report** (the orchestrator's restatement, which the user accepted). The instructions say "a `started` report of a plan to implement". A `started` report that is not a plan has no features to list.
- **"Only citing numbers" includes IDs** such as `D18` (the brief's *What was decided already*).

## Limits

- **The phrase cases pin phrases, not wording.** Their phrases sit on one line. The word-for-word pins are what hold the wording.
- **A change to the rules' text means a change to the tests.** The block pin makes that deliberate.
- **The scope test covers only the writing block.** It checks from the heading to the end of the text. A line added to the field lines is held by the field-block pin. The status lines come from `format.STATUSES` and are held by the pins of each status's moment.
- **Whether Claude follows the instructions is not testable in the suite,** because the real `claude` never runs there.
- **New instructions reach Claude only through a Neovim that loaded them** (R7). The text is built from `require('aineo.report')`, and `require` caches the module. So after the files change on disk, `:Lazy update` say, an editor that was already running keeps the text it loaded. The next Claude Code it starts gets that old text. A restarted Neovim gives the new text to the Claude Code it starts.

## Open threads

- **The wording of the eight rules** is for the user to read as Claude will. `require('aineo.report').report_instructions('mcp__aineo__report')` prints it.
- **The `blocked`/`failed` wording is mine,** my phrasing of MR109's reading. MR109 is open with the user.
- **Whether Claude follows the rules** is seen only in use (D10: the suite never runs the real `claude`).
- **T11 re-checks its `*aineo-report*` line numbers after this merge.** Against `4dd5cf4`, this change alters one line at `:257` and inserts eleven after `:274`, at new `:275–285`.
- **R7's module cache:** an editor running across an update keeps the instructions it loaded, as *Limits* says. Nothing in aineo reloads `aineo.report.instructions`.
- **`lua/aineo/report/init.lua`'s docstring was left unchanged,** because that file is outside this packet's boundary. It still says "telling it when and how to call the report tool", which is accurate.

## Task lines

The wave holds its marks (rule 6), so the task list is untouched. T15's line, for the knowledge pass:

`| T15 | … | T8 | done — PR #39, wave 6 |`

Its open threads are above.

## Commits

*Recorded after the merge.*
