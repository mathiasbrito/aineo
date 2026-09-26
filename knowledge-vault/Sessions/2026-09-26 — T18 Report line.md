# 2026-09-26 — T18 Report line

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t18-report-line` · **Pull request:** into `dev`, a small fix (orchestrate §3)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (D24; C14, superseding C10; C6)
- [[Implementation/Waves/00006-fixes/plan]]; the brief `brief-t18-report-line.md`, its review `brief-review-t18-report-line.md`, the evidence `report-line-bold.txt` and `baseline-d30ff4d.txt`
- [[Sessions/2026-09-25 — T9 Report colours]] — how the groups are defined, and their limit
- [[Sessions/2026-09-26 — T11 Report icon]] — the icon this packet removes
- [[Sessions/2026-09-26 — T10 Report links]] — the links whose columns move
- [[Review/2026-09-24 — v1 MVP readings review]] — MR102, moot once this lands

## Context

**Goal:** T18. On seeing T11's icon the user said "the icon position is not as I imagined... it is not good", then "remove the Icon, just make the banned [<type>] bold then". D24 records it; C14, superseding C10, makes the line `HH:MM [status] task — summary`, `[status]` bold in its status's colour, the details under the `[status]`. Run as a small fix after T10, the user's choice over the orchestrator's stated concern that replacing C10 needs a new row.

## What was done

- **`lua/aineo/report/render.lua`:** `STATUS_ICONS` and `details_indent()` removed. The header is `HH:MM [status] task — summary`; `STATUS_COLUMN` (6) is where `[status]` starts, and `DETAILS_INDENT` six spaces: the prefix is ASCII, one cell a byte, so `'ambiwidth'` and `setcellwidths()` no longer change the indent and nothing measures it. `header_colours()` lays the time in `AineoReportTime`, then the `[status]` in `AineoReportStatusBold`, then over it in its status's group.
- **`lua/aineo/report/colours.lua`:** `STATUS_BOLD_GROUP = 'AineoReportStatusBold'`, default-linked to `@markup.strong` by `define_report_colours()` beside T9's groups (`:highlight default link`).
- **`lua/aineo/report/buffer.lua`:** code unchanged; `append_rendering()`'s docstring states the order it relies on: the colours are placed in their order at one priority, so where two cover the same text the later shows over the earlier. `aineo.report.Rendering`'s `colours` field says the same.
- **`lua/aineo/report/init.lua`:** unchanged; every drawing path goes through `render_records()` and `show_rendering()`, which defines the groups whenever a rendering has colours.
- **`doc/aineo.txt`, inside `*aineo-report*` only:** the example without `<icon>`, its details line indented 10 (under the `[status]`); the sentence naming the icons and the one on the indent following the icon's width removed ("The Report follows the newest report." kept); *Colours*: `[status]` bold, the bold's group beneath the status's, how to turn the bold off; the status groups' entries without their icons; a `*hl-AineoReportStatusBold*` entry.
- **Docstrings** of `render.lua` (module, `header_colours()`, `render_report()`, the new constants, `Rendering.colours`), `colours.lua` (module, `STATUS_GROUPS`, the new group) and `buffer.lua` (`append_rendering()`) corrected.
- **Tests:** the pins over the old line moved (RL4, RL5); new cases in `tests/test_report_colours.lua` for RL2, eight of them read on the screen.

### How the tests read the screen

`first_status_on_screen()` in `tests/test_report_colours.lua` shows the Report in the child's only window, calls `vim.api.nvim__inspect_cell(1, 0, 0)` once and drops its result, runs `:redraw` in its own request, then reads `nvim__inspect_cell(1, 0, 6)` (the `[`) and `nvim__inspect_cell(1, 0, end - 1)` (the `]`), each in its own request, keeping the RGB `foreground` and whether `bold` is set. The expected colour is read in the child with `nvim_get_hl(0, { name = <link target>, link = false }).fg`, or is the user's `#ff0000`. The child has no UI and needs none; the tests set no `'termguicolors'`, and the RGB foreground is reported all the same (measured: `0xB3F6C0` for `DiagnosticOk`).

## Unit list and red/green

The slicing, before the first test:

1. **RL1** — a report's header starts with its time, no icon, for every status; its details start six cells in, under the `[`, whatever `'ambiwidth'` or `setcellwidths()` say; the pins over the old line (RL3, RL4, RL5) moved with it.
2. **RL2a** — on Neovim's default colours, `[status]`, brackets included, shows bold in its status's colour; the bold is `AineoReportStatusBold`, linked to `@markup.strong`.
3. **RL2b** — with `@markup.strong` given a foreground, `[status]` keeps its status's colour, bold.
4. **RL2c** — a user's colour for a status shows on `[status]`, bold, made before the first report or after one.
5. **RL2d** — `:highlight clear` brings back the default link, bold.
6. **RL2e** — the user turns the bold off, the colour kept, through aineo's next definition.
7. **RL2f** — the bold on every drawing path: the records when the Report opens, `:edit`/`:edit!`, the Report made anew after `:bdelete`, `:bwipeout`, `:bunload`.
8. **RL2g** — the bold's group is not defined until the Report shows a report.

### Seen red

- **RL1 (unit 1),** every moved pin run against the icon code, one file at a time, 0.12.5:
  - `tests/test_report_buffer.lua`: 41 of 67, e.g. "renders as its time, status, task and summary": `left = "✓ 09:05 [done] Refactor the parser — All tests pass", right = "09:05 [done] …"`; "indents its details six cells under 'ambiwidth' double": `Left: { "◐ 09:05 [progress] Task — Summary", "         Detail" }`; "of every status the report tool accepts shows with no icon, its details under its status": every header with its icon and every details line indented 8 listed as faults.
  - `tests/test_report_colours.lua`: 17 of 26 (every time and status span 4 bytes earlier; the icon's mark present).
  - `tests/test_report_links.lua`: 66 of 83 (every row with a link; the two header cases; three `gx` rows).
  - `tests/test_entry_report.lua` 2 of 4, `tests/test_mcp_blocked_editor.lua` 2 of 5, `tests/test_mcp_delivery.lua` 5 of 26: the icon in each expected line.
- **RL2a (unit 2):** "the status › shows, brackets included, in AineoReportStatusBold as well, linked to @markup.strong" ×5: `Left: { {}, vim.NIL } Right: { { { 0, 6, 12 } }, "@markup.strong" }`; "the status › shows bold on the screen, brackets included, in the colour of its status" ×5: `key branch 1->"bold", left = false, right = true` (foreground `11794112`, `0xB3F6C0`, right). With them, the exact lists gaining the bold's row after the status's: "the header" ×5, "the colours" ×3 and the links file's "in the header leaves the time and the status their colours" (the bold's mark missing).
- **RL2b (unit 3):** "the status › keeps the colour of its status, bold, when a colour scheme colours @markup.strong" ×5: `key branch 1->"foreground", left = 16711935, right = 11794112` — `0xFF00FF`, the scheme's colour, over the status's, with the bold's mark placed after the status's (the natural edit, A2s). With them, the eight exact lists and the links case expecting the bold's row before the status's.

### Arrived green

Every one killed by the mutant named, run on the final tree (§ Mutants):

- "the groups › show a user's colour for a status made before the first report on its [status], bold" and "… made after a report …": spent by units 2–3, which keep the status group on top; killed by M9.
- "the groups › show a [status] bold, in its status's default colour, once :highlight clear drops a user's colour": spent by unit 2's definition (`:highlight default link`); killed by M7b.
- "the groups › let the user turn a [status]'s bold off, its colour kept, through the next report" ×2 (`gui=NONE cterm=NONE`, `link … NONE`): spent by unit 2's definition, which a defined group ignores; killed by M8.
- "the records › show their colours once again when the Report is made anew after the user deletes it" ×3, and the bold's spans added to "show their time and status coloured when the Report opens" and "show their colours once again when the user edits the Report again" ×2: every path renders through `render_records()`; killed by M4 (6 of 7 in "the records").
- The bold's link added to "the records › show in groups linked to their defaults when the Report opens": killed by M12.
- `AineoReportStatusBold` added to "the groups › are not defined, nor any ColorScheme autocommand, until the Report shows a report": green by nature (the group was not defined on the icon code either); killed by M10.
- In `tests/test_report_links.lua`, the `gx` rows `See **https://x.y/docs** now` (12) and `See *https://x.y/docs* now` (11) passed on the icon code as well: there the cursor sits on the `**`/`*` before the link, and `gx` opened the link from it. The brief review measured the same with the icon removed and the columns unmoved. Their columns move so the cursor is on each link's first byte, as T10's rows mean; nothing in T18 can turn them red.

## Mutants

Each is the literal edit in the implementing worktree's `.claude/local/orchestrator/t18-mutant.py` (gitignored scratch), applied and restored in one run, against a copy of the test file narrowed to the set or case named, 0.12.5, on the final tree.

| # | Literal edit | Run against | Result |
|---|---|---|---|
| M1 | `DETAILS_INDENT = (' '):rep(STATUS_COLUMN)` → `(' '):rep(STATUS_COLUMN + 2)` | buffer › "a report" (24) | killed, assertion, 12/24 |
| M2 | `STATUS_COLUMN = CLOCK_TIME_LENGTH + 1` → `+ 2` | colours › "the header" (5) | killed, assertion, 5/5 |
| M3 | the bold's mark placed after the status's (A2s) | colours › "the status › keeps the colour … @markup.strong" (5) | killed, assertion, 5/5 |
| M4 | the bold's mark deleted | colours › "the status › shows bold on the screen …" (5); "the records" (7) | killed, assertion, 5/5; 6/7 |
| M5 | the bold's `end_column = status_end_column - 1` | colours › "the status › shows bold on the screen …" (5) | killed, assertion, 5/5 |
| M6 | `[M.STATUS_BOLD_GROUP] = '@markup.strong'` → `'Normal'` | same (5) | killed, assertion, 5/5 |
| M7 | after the definitions' loop, `vim.api.nvim_set_hl(0, M.STATUS_BOLD_GROUP, { bold = true, default = true })` | "the groups › show a [status] bold … :highlight clear …" (1); then the six test files the PR modifies, whole (49, 83, 67, 4, 5, 26) | **survived; equivalent** — see below |
| M7b | A9c literally: `[M.STATUS_BOLD_GROUP] = '@markup.strong',` deleted, and after the loop `vim.api.nvim_set_hl(0, M.STATUS_BOLD_GROUP, { bold = true, default = true })` | "the groups › show a [status] bold … :highlight clear …" (1) | killed, assertion, 1/1 |
| M8 | after the loop, `vim.api.nvim_set_hl(0, M.STATUS_BOLD_GROUP, { link = '@markup.strong' })` | "the groups › let the user turn a [status]'s bold off …" (2) | killed, assertion, 2/2 |
| M9 | the status's mark `group = colours.STATUS_GROUPS[status]` → `'DiagnosticOk'` | "the groups › show a user's colour … before …", "… after …" (2) | killed, assertion, 2/2 |
| M10 | `M.define_report_colours()` called as `colours.lua` loads | "the groups › are not defined … until the Report shows a report" (1) | killed, assertion, 1/1 |
| M11 | the time's `end_column = CLOCK_TIME_LENGTH + 1` | colours › "the time" (1) | killed, assertion, 1/1 |
| M12 | `[M.STATUS_BOLD_GROUP] = '@markup.strong',` deleted | "the status › shows bold on the screen …" (5); "the records › show in groups linked to their defaults …" (1) | killed, assertion, 5/5; 1/1 |

**M7 is equivalent, measured on the states it meets** (`t18-m7-state.lua`, `nvim --clean --headless -l`, 0.12.5 and 0.11.6): M7's call always follows the loop's `:highlight default link`, which has defined the group by then, and a `default` definition leaves a defined group as it is — linked to `@markup.strong` at the first definition; empty (the user's `gui=NONE`) when defined again after the user turned the bold off; linked again after `:highlight clear` and after the next definition. It is not A9c, which defines the bold as attributes *instead of* the link; M7b is, and it is killed.

## Decisions & reasoning

- **The bold is laid by order, not by priority.** Both were measured to work (A2t, A3); order needs no new field in `aineo.report.Colour` and no change to `append_rendering()`. The same-priority rule (the later mark shows over the earlier) is not written in `:h nvim_buf_set_extmark()` (0.11.6's `priority` item says only that treesitter uses 100); it was measured on both versions, and "keeps the colour of its status, bold, when a colour scheme colours @markup.strong" reads it on the screen, so a Neovim that changed it would fail that case.
- **The indent is a constant.** `nvim_strwidth()` of an ASCII prefix is its byte count on every setting; a constant says so, and T11's width cases now pin that `'ambiwidth'` `double`, `setcellwidths()` and a wrapping window leave it at six.
- **`setcellwidths()`' case** gives `—` (U+2014), a character of the header after `[status]`, a width of 2, since the prefix has no character `setcellwidths()` accepts (it refuses anything below U+0100).

## Verification

- **Baseline:** `dev` at `d30ff4d`, 973 cases, `Fails (0)` on both versions (the brief's `baseline-d30ff4d.txt`); T20 had not merged, and `dev`'s later commits (`7154039`, `6e5e6ce`) touch only the vault, so it was not re-measured.
- **Whole suite, one version at a time, on the code pushed:** 0.12.5 (`make test`) 996 cases, `Fails (0)`, exit 0; 0.11.6 (`env PATH=<builds>/nvim-0.11.6/… make test`) 996 cases, `Fails (0)`, exit 0. 996 = 973 + 23 new cases, all in `tests/test_report_colours.lua` (26 → 49).
- **Per file after the change (0.12.5):** buffer 67, colours 49, links 83, entry_report 4, mcp_blocked_editor 5, mcp_delivery 26, doc 36 — each `Fails (0)`.
- `make lint`: StyLua clean, selene `0 errors, 0 warnings, 0 parse errors`.
- **Modularity:** no `require` added; `render.lua` already required `aineo.report.colours` inside its own home.
- **T20 (PR #58, unmerged):** `git merge-tree --write-tree HEAD origin/bugfix/t20-claude-terminal-mode` printed tree `d6dbbe4`, no conflict in any file; its `doc/aineo.txt` and `tests/test_doc.lua` checked out, `make test_file FILE=tests/test_doc.lua` 36 cases, `Fails (0)` on 0.12.5 and on 0.11.6; both files restored from `HEAD`.

## Readings for the MVP review

The orchestrator's readings, from the brief:

- the brackets are bold with the word, as C6 and T9 colour them with it;
- the bold can be turned off apart from the colour (RL2): `:highlight AineoReportStatusBold gui=NONE cterm=NONE`, or `:highlight link AineoReportStatusBold NONE`, pinned on the screen through the next report;
- the bold is a group of its own, `AineoReportStatusBold`, linked by default to `@markup.strong`, the only built-in group that is bold and nothing else and means strong text. So a colour scheme's style for Markdown bold — its background, italic, underline, or bold turned off — also styles `[status]`'s bold; its colour does not, since the status's colour wins (RL2). Only the colour and the bold were measured on the screen here; the other attributes follow from how Neovim combines marks, not from a test.

## Task lines

The wave holds its marks (rule 6). The line T18 would take:

- [X] T18 — the Report line is `HH:MM [status] task — summary`, no icon; `[status]`, brackets included, shows bold (`AineoReportStatusBold`, linked to `@markup.strong`, beneath the status's group) in its status's colour on every drawing path; the details start six cells in, under the `[`. A small fix.

## Open threads

- MR102 (the indent by the icon's width) is moot once this merges; the MVP readings review is the orchestrator's to mark.

## Commits

*Recorded after the merge* — hashes change on rebase.
