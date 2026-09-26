# 2026-09-26 — T15 Report instructions

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t15-report-instructions` · **Pull request:** into `dev` (a small fix, orchestrate §3)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C6; D10)
- [[Implementation/Waves/00006-fixes/plan]] § *Packet T15 — 2026-09-26*, its brief `brief-t15-report-instructions.md`, its brief review `brief-review-t15-t16.md`, the baseline `evidence/baseline-dbc96c9.txt`

## Context

**Goal:** T15. The user asked on 2026-09-26 that Claude write the Agent Report for a person: plain language, the whats and hows and never the whys, a plan's features or what was done listed, and references to documents at the end, in parentheses, by number only. The user called it a small fix. It rests on C6: "the appended prompt tells Claude when to report". T15 adds *how to write* a report to that prompt.

## What was done

- **`lua/aineo/report/instructions.lua`**: a private `writing_lines()`, eight rules under the heading `Write a report for the user to read:`, joined last by `report_instructions()`.
  - RI1: for a person, in plain language, `summary` and `details` describing what is being reported; what was done or planned, and how; never the reasons for decisions, no whys; a `blocked` or `failed` report states as a fact what blocks the task or what stopped it.
  - RI2: a `started` report of a plan lists the features planned in `details`, one per line.
  - RI3: a `done` report lists what was done, the features, in `details`, one per line.
  - RI4: references to decisions, components, tasks, issues, pull requests and docs at the very end, in parentheses, by number or ID only, with no explanation, such as `(D18, C12, #31)`; the very end is a line of its own, the last line of `details`, or the end of `summary` when a report has no `details`.
  - Every line names a report or one of its fields: the text joins Claude's whole system prompt, and its rules are for reports, not for Claude's replies in the terminal.
- **The `details` description** changed from "such as the files you changed or the question the user must answer" to "such as the features planned or done, or the question the user must answer". The old text contradicted RI3 (RI5's allowance).
- **Unchanged (RI5, RI6):** the first line naming the tool, the four field names, each status's moment (`format.STATUSES`), the report format and its validation, the MCP tool's schema and description, and the Report's rendering. The existing pins of `report_instructions()` stayed green unchanged.
- **Docstrings:** `writing_lines()` is new and documented; `report_instructions()`'s docstring now names the writing block.
- **`doc/aineo.txt`**, inside `*aineo-report*` only: the list item on the appended instructions now says they also tell Claude how to write a report, and a new paragraph says what they ask, that they apply to reports only, and that a running Claude Code keeps the instructions it started with.
- **`tests/test_report.lua`**: ten new cases under `report_instructions()`, with three documented helpers (`line_with`, `writing_block`, `lines_naming_no_report`). No existing case changed.

## Unit list and red/green

Every red was seen on the host's 0.12.5 through `make test_file FILE=tests/test_report.lua`, each a `Left: false, Right: true` assertion failure.

| # | Behaviour | Test (under `report_instructions()`) | Status |
|---|---|---|---|
| 1 | RI1 | *asks for each report to be written for a person, in plain language, saying what is reported* | red |
| 2 | RI1 | *asks each report to say what was done or planned, and how* | red |
| 3 | RI1 | *asks each report never to explain the reasons for decisions* | red |
| 4 | RI1, every status | *asks a blocked or failed report to state what blocks or stopped the task as a fact* | red |
| 5 | RI2 | *asks a started report of a plan to list the features planned in its details, one per line* | red |
| 6 | RI3 | *asks a done report to list what was done, the features, in its details, one per line* | red |
| 7 | RI4 | *asks a report to cite documents at its very end, in parentheses, by number or ID only, with an example* | red |
| 8 | RI4, "very end" | *places the very end of a report on a last line of details, or at the end of a summary without details* | red |
| 9 | RI5's allowance | *offers the features planned or done as the details of a report* | red (the description offered files changed) |
| 10 | RI1's scope | *states every rule on writing for a report or one of its fields* | arrived green: it pins the lines units 1–8 wrote, each naming a report or a field; killed by M6 |

## Mutants

Run one at a time from a pristine copy (`t15-mutants.py` in the scratchpad), on the final code, against `.tests/t15-instructions.lua` — `tests/test_report.lua` narrowed to its `report_instructions()` group (21 cases). Every kill is an assertion failure (`Failed expectation`), one failing case each. No mutant survived, so none went back to the whole file.

| # | Literal edit in `instructions.lua` | Killed by |
|---|---|---|
| M1 | the `started` line deleted | unit 5 |
| M2 | the `done` line deleted | unit 6 |
| M3 | the references line deleted | unit 7 |
| M3b | `by number or ID only, with` → `by number or ID, with` | unit 7 |
| M4 | `at the very end, in parentheses` → `at the very start, in parentheses` | unit 7 |
| M4b | `The very end of a report is` → `The very start of a report is` | unit 8 |
| M5 | the no-whys line deleted | unit 3 |
| M6 | `'- Never explain the reasons for your decisions.',` added after the last rule | unit 10 |
| M7 | `tool_name` → `'mcp__aineo__report'` in the first line's `:format()` | *names the tool it is given* (`mcp__renamed__report`) |
| M8 | the plain-language line deleted | unit 1 |
| M9 | the "and how" line deleted | unit 2 |
| M10 | the `blocked`/`failed` line deleted | unit 4 |
| M11 | `such as the features planned or done, or the question` → `such as the files you changed or the question` | unit 9 |
| M12 | `, such as \`(D18, C12, #31)\`` deleted | unit 7 |
| M13 | `a line of its own, the last line of \`details\`` → `the last line of \`details\`` | unit 8 |
| M14 | `in parentheses, by number or ID only, with` → `by number or ID only, with` | unit 7 |

## Suites

Both runs were on the code commit, one after the other, with the host loaded (load averages 106 to 160):
- **0.12.5** (`make test`): 757 cases, `Fails (8)`. These are the baseline's eight T13 failures, by name, and there are no others.
- **0.11.6** (`env PATH=<builds>/nvim-0.11.6/… make test`): 757 cases, `Fails (0)`, rc 0.
- The count is 747 at baseline plus the 10 new cases.
- `make lint` found 0 errors and 0 warnings. `make format` changed nothing after the last edit.

**Merge check before the push:**
- T16's branch did not exist on `origin`.
- With `origin/bugfix/t13-neovim-0-12` (`079d632`), `git merge-tree --write-tree` exited 0 and listed no conflict; it printed the tree `9bf69a0`.
- `tests/test_doc.lua`, run on that tree's `doc/aineo.txt`, passed 36 cases with `Fails (0)` on both 0.12.5 and 0.11.6.
- The help was then restored from `HEAD`.

## Readings for the MVP review

- **RI1 for every status** (the orchestrator's reading, in the brief): what blocks a task (`blocked`) and what stopped it (`failed`) are facts, among the whats; what is left out is the reasoning behind Claude's choices. The instructions say so in their own line, so "no whys" does not keep Claude from saying what blocks it.
- **"A plan to be implemented" is a `started` report** (the orchestrator's restatement, which the user accepted). The instructions say "a `started` report of a plan to implement": a `started` report that is not a plan has no features to list.
- **"Only citing numbers" includes IDs** such as `D18` (the brief's *What was decided already*).

## Limits

- The tests pin the rules' content by phrases on one line, not their exact wording; a rule reworded without its key phrases fails its test.
- RI1's scope test covers the writing block only, from its heading to the end of the text. A line added to the field or status lines is outside it; those lines each name a field or a status today.
- Whether Claude follows the instructions is not testable in the suite (the real `claude` never runs there). New instructions reach Claude when aineo next starts it.

## Task lines

The wave holds its marks (rule 6), so the task list is untouched. T15's line, for the knowledge pass: `| T15 | … | T8 | done — PR #<n>, wave 6 |`, with nothing left open in the packet.

## Commits

*Recorded after the merge.*
