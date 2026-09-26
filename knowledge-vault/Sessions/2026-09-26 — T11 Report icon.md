# 2026-09-26 — T11 Report icon

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t11-report-icon` · **Pull request:** #45 into `dev` (a regular packet), with one fix round and one correction

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C10, which supersedes C6's rendered line; C6; D10)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t11-report-icon.md` with its amendment of 2026-09-26, the brief reviews `brief-review-t11-report-icon.md` and `brief-review-t11-amendment.md`, the evidence `icon-widths.txt` and `baseline-7af0d47.txt`
- [[Review/2026-09-24 — v1 MVP readings review]] — MR96 (the status colours) and MR102 (IC4's indent), both kept by the user on 2026-09-26
- [[Sessions/2026-09-25 — T9 Report colours]] — the groups this packet colours the icon with, and its *Limits*
- The fix round's input: the attack (A1–A4), test-integrity (I1–I4) and records (R1–R7) reviews of pull request #45 at `e1a5bea`
- The correction's input: findings 1–3 of the re-measure of pull request #45 at `4fd7987`, after the fix round

## Context

**Goal:** T11. On 2026-09-25 the user asked for "an icon in the beginning (icons from unicode, but only the ones terminal styled)". They chose the "Unicode set": `▸` started, `◐` progress, `⊘` blocked, `✓` done, `✗` failed. That is C10:
- the line is `<icon> HH:MM [status] task — summary`;
- the icon is coloured like the status;
- the details are indented under the status.

## What was done

- **`lua/aineo/report/render.lua`**
  - `STATUS_ICONS`, private to the render, maps each status to its icon.
  - The header is `<icon> HH:MM [status] task — summary`.
  - One render, `render_records()`, serves every path that shows a report (IC5):
    - a new report;
    - the saved records when the Report opens;
    - the refill after `:edit`;
    - the Report made anew after the user deletes it.
  - `header_colours(status)` places three spans (IC2, IC3):
    - the icon's 3 bytes, in the status's group;
    - the `HH:MM`, in `AineoReportTime`;
    - the `[status]`, in the status's group.

    The space after the icon shows in no group.
  - `details_indent(status_prefix)` indents each details line by the width in cells of `<icon> HH:MM ` (IC4).
    - It measures with `vim.api.nvim_strwidth()` at each rendering. That width follows `'ambiwidth'` and `setcellwidths()`, and it does not depend on the window that is current.
    - Under Neovim's defaults the indent is 8.
    - The first round used `vim.fn.strdisplaywidth()`, which measures as the current window would lay the string out. The fix round replaced it (attack A1).
- **`lua/aineo/report/colours.lua`**: only its docstrings, which now name the icon beside the `[status]`.
- **`doc/aineo.txt`**, inside `*aineo-report*` only:
  - the line with `<icon>`;
  - the icons by status;
  - the measured indent;
  - what redraws the reports already shown: `:edit` in the Report, or the Report made anew after the user deletes it;
  - the icon in the *Colours* paragraph, reflowed to 78 columns;
  - each group's row naming its icon.
- **Pins moved (IC6).**
  - 31 header pins gain the icon and its space:
    - 21 in `test_report_buffer.lua`;
    - 2 in `test_entry_report.lua`, one of them through `REPORT_LINES`;
    - 5 in `test_mcp_delivery.lua`;
    - 3 in `test_mcp_blocked_editor.lua`, including the wait target at line 75.
  - 4 details pins go from 6 to 8 spaces: two in `test_report_buffer.lua` and two in `test_mcp_delivery.lua`.
  - Every colour pin in `test_report_colours.lua` moves by 4 bytes and gains the icon's span. None is deleted.
  - Two patterns change:
    - `REPORT_HEADERS` keeps lines that start with a non-space (`^%S`), where it kept lines that start with a digit;
    - `REPORT_LINES` keeps the icon and rewrites the time after it.
- **Fix round.**
  - The wait at `test_mcp_blocked_editor.lua:75` is now an `eq()`.
  - Four tests, six cases, pin what the reviews found unpinned.
  - Three cases are renamed so that their names name the icon:
    - `a report › renders as its icon, time, status, task and summary`;
    - `the colours › cover only the icon, the time and the status the render placed, not their like in the text`;
    - `the records › show their icon, time and status coloured when the Report opens`.
- **Correction.**
  - The test-integrity review's reversed-order case is adopted: a `done` report shown before a `progress` report, under `'ambiwidth'` `double`, after `:edit`.
  - Five tests, seven cases, now pin what the reviews found unpinned: the fix round's four tests and six cases, and this one. Counted by collecting the cases of the three test files the rounds changed, at `e1a5bea` and at the correction's head, and setting aside the three renamed cases and the narrow-window case × 2, which are A1's reds.
- **Unchanged:**
  - `records.lua` and the records' format, so reports saved before this change show with the icon;
  - `init.lua`;
  - the groups and their links;
  - `plugin/aineo.lua`.

## Unit list and red/green

The slicing, stated before the first test:

1. IC1: the header starts with the icon of its status, parametrized over the five statuses.
2. IC5: the icon shows on the records shown when the Report opens, and after `:edit`. As the brief asks, these were written and seen red beside IC1, before the render changed.
3. IC6: the text pins follow the new header. This is a consequence of unit 1, done in the same unit so that the suite ends green.
4. IC3: the time and the status keep their colours, at columns moved by 4 bytes.
5. IC2: the icon shows in its status's group, and the space after it in none.
6. IC4: the details' indent is the width in cells of `<icon> HH:MM `:
   - 8 under the defaults;
   - 9 for `◐` under `'ambiwidth'` `double`;
   - 9 for `✓` under `setcellwidths()`;
   - each report keeps the width it was drawn with until the Report shows every report again.

The fix round added:

7. A1: the indent does not depend on the current window: a narrow window with `'linebreak'`, or with `'showbreak'`.
8. The pins listed under *Arrived green*.

The correction added:

9. The mixed widths in the other order: a `done` report before a `progress` report.

**Seen red (28 cases).** 15 of them are new cases: IC1 × 5, IC5 × 2, IC2 × 5, the `'ambiwidth'` case and the narrow-window case × 2. The other 13 are existing cases whose pins were moved before the code: IC3's 11 and IC4's 2 details pins.

| Test | Red |
|---|---|
| `a report › renders the icon of its status first › for the status` × 5 | `left = "09:05 [started] Task — Summary", right = "▸ 09:05 [started] Task — Summary"`, and the same for each status |
| `a report › shows its icon among the records when the Report opens in a new editor` | `left = "09:05 [failed] Task — Summary", right = "✗ 09:05 [failed] Task — Summary"` |
| `a report › shows its icon again when the user edits the Report again` | `left = "09:05 [progress] Task — Summary", right = "◐ 09:05 [progress] Task — Summary"` |
| `test_report_colours.lua`, the 11 colour pins moved by 4 bytes (IC3): `the time`, `the status` × 5, both `the colours` cases, `the records › show their … coloured…`, `…once again when the user edits…` × 2 | `left = 0, right = 4` for the time, `left = 6, right = 10` for the status |
| `the icon › shows in the group of its status, and the space after it in none` × 5 | `different values at key branch 1->2, left = 4, right = 0`: there is no span at byte 0 |
| The details pins moved to 8 (IC4, defaults): `a report › renders each line of its details below it, indented`, and `test_mcp_delivery.lua`'s `…fields holding code render literally…` | `left = "      Changed three files", right = "        Changed three files"` |
| `a report › indents its details by its icon's width under 'ambiwidth' double` | `left = "        Detail", right = "         Detail"`, against the indent measured once when `render.lua` loaded |
| `a report › indents its details by their width alone, however the current window wraps › with` × 2 (fix round, A1): `setlocal linebreak` and `set showbreak=↪\ ` in a window 6 columns wide | at `e1a5bea`, on both 0.12.5 and 0.11.6: `left = "         Detail"` (9) and `left = "          Detail"` (10), each `right = "        Detail"` |

The 31 header pins and the two patterns were moved after IC1's code turned them red. That was 22 failing cases in `test_report_buffer.lua` alone. They are pins of existing behaviour following a changed line, not new units.

**Arrived green (9).** Each killer below was run, and each killed by assertion. The mutants are in the table under *Mutants*.

- `a report › indents its details by its icon's width under setcellwidths()`: spent by IC4's per-rendering measurement. Killer: M10.
- `a report › keeps the indent it was drawn with until the user edits the Report again`: spent the same way. Killer: M11.
- `a report › indents each report's details by its own icon when reports of different widths show together` (fix round, A2 and I1; the attack's A7). Killers: MA1, MA2 and X1; and XW (correction), which, of A′'s cases, only this one kills. XN survives it: the first report it renders is the wider one.
- `a report › indents each report's details by its own icon when a done report shows before a progress report` (correction, the re-measure's finding 1; the test-integrity review's case, as it measured it). Killers: XN, which, of `test_report_buffer.lua`'s cases, only this one kills; and X1, which kills it beside the case above. Each order pins what the other cannot.
- `a report › of every status the report tool accepts shows with an icon` (fix round, A4). Killers: MD, an icon dropped; and MF, a status added to `format.STATUSES` with no icon, which, of the cases that render a report, no other sees. The pins over the status list fail too, for the list: six cases, each by assertion —
  - `tests/test_mcp_relay.lua`: `tools/list › lists one tool, report, whose input schema is the report format` and `tools/call › of a refused report is a tool error naming the field`;
  - `tests/test_report.lua`: `validate_report() › refuses anything else, naming the field` × 3 and `report_instructions() › describes the fields of a report word for word`.
- `a report › keeps the indent it was drawn with until the Report is made anew after the user deletes it › with the command` × 3, for `bdelete`, `bwipeout` and `bunload` (fix round, R2; the records review's probe). Killers: M11 and M9, among others.
- `the colours › cover no icon in the text` (fix round, I2; the test-integrity review's case). Killer: X2.

The wait at `test_mcp_blocked_editor.lua:75` became an assertion (A3, I4), so it is an existing case made to prove its line. Killer: MW.

## Mutants

**How they were run.**
- Measured on the shipped tree, commit `2e84083`.
- Each mutant is a literal edit of the file it names, applied to a pristine copy, run, then restored. They ran one at a time, with `t11-mutants-fix.py`.
- Each ran against a narrowed copy of its test file, built by `t11-narrow.sh`:
  - **A** = `.tests/t11-a-report.lua`: the `a report` cases of `test_report_buffer.lua` before `the Report buffer`. That is 22 of the group's 23; it leaves out `is refused until the report home has its environment`, at the file's end.
  - **C** = `.tests/t11-colours.lua`: every group of `test_report_colours.lua` before `the groups`, 18 cases.
  - **B** = `.tests/t11-blocked.lua`: `test_mcp_blocked_editor.lua` before `a report for an editor at a hit-enter prompt`, 3 cases.
- All ran on 0.12.5. The survivors the reviews named, and MS, MD, MF, MW and MWR, also ran on 0.11.6, with identical results.
- Every kill is an assertion. In every row but MD, the count of `Failed expectation` equals the count of failing cases. None survived.
- **The correction's three rows**, XN, XW and X1 again, were measured on its own commit, `db623b4`, whose `lua/` is `2e84083`'s. They ran with `t11c-mutants.py`, one at a time, from the committed file, and the file was compared with its pristine text after each run. They ran on 0.12.5 and on 0.11.6, with identical results, against:
  - **A′** = `.tests/t11c-a-report.lua`, built by `t11c-narrow.sh`: A with the done-before-progress case, 23 cases;
  - `tests/test_report_buffer.lua` whole, 67 cases (XN and X1).

  XW's whole-file run was not needed: it was killed against A′. The rows above them were measured against the fix round's A, which holds 22 cases, not the correction's. MF was run again with the same tool against `tests/test_mcp_relay.lua` (2 of 30 cases) and `tests/test_report.lua` (4 of 55), on 0.12.5: the six cases under *Arrived green*, each by assertion.

| Id | File | Literal edit | Against | Result |
|---|---|---|---|---|
| M1 | render | `  progress = '◐',` / `  blocked = '⊘',` → `  progress = '⊘',` / `  blocked = '◐',` | A | killed, 9 cases |
| M2 | render | `('%s %s '):format(STATUS_ICONS[report.status], time:sub(12, 16))` → `('%s %s '):format('▸', time:sub(12, 16))` | A | killed, 19 cases, among them both IC5 cases |
| M3 | render | `end_column = #icon, group = status_group },` → `end_column = #icon + 1, group = status_group },` | C | killed, 16 cases |
| M4 | render | the line `    { line = 0, first_column = 0, end_column = #icon, group = status_group },` deleted | C | killed, 16 cases |
| M5 | render | `end_column = #icon, group = status_group },` → `end_column = #icon, group = colours.TIME_GROUP },` | C | killed, 17 cases |
| M6 | render | `local time_column = #icon + 1` → `local time_column = #icon` | C | killed, 17 cases |
| M7 | render | `local status_column = time_column + CLOCK_TIME_LENGTH + 1` → `local status_column = time_column + CLOCK_TIME_LENGTH` | C | killed, 16 cases |
| M8 | render | `  return (' '):rep(vim.api.nvim_strwidth(status_prefix))` → `  return (' '):rep(#status_prefix)` | A | killed, 10 cases |
| M9 | render | the same line → `  return (' '):rep(8)` | A | killed, 7 cases |
| M10 | render | the same line → `  return (' '):rep(8 + ((vim.o.ambiwidth == 'double' and status_prefix:find('◐', 1, true)) and 1 or 0))` | A | killed, 1 case: `setcellwidths()` |
| M11 | render | `details_indent` replaced, below | A | killed, 6 cases: the sequence, the re-creation × 3 and the narrow window × 2 |
| M12 | render | `details_indent` replaced, below | A | killed, 7 cases |
| M13 | render | `('%s %s '):format(STATUS_ICONS[report.status], time:sub(12, 16))` → `('%s '):format(time:sub(12, 16))` | A | killed, 21 cases |
| MA1 (attack) | render | the indent line → `  local widest = 0` / `  for _, icon in pairs(STATUS_ICONS) do` / `    widest = math.max(widest, vim.fn.strdisplaywidth(icon .. status_prefix:sub(4)))` / `  end` / `  return (' '):rep(widest)` | A | killed, 3 cases: mixed widths, and the narrow window × 2, since the edit brings `strdisplaywidth` back |
| MA2 (attack) | render | `details_indent` → `local batch_indent` / `local function details_indent(status_prefix)` / `  batch_indent = batch_indent or (' '):rep(vim.fn.strdisplaywidth(status_prefix))` / `  return batch_indent` / `end`; and `  batch_indent = nil` as `render_records()`'s first line | A | killed, 3 cases: mixed widths and the narrow window × 2 |
| X1 (integrity) | render | `  M.batch_indent = nil` after `  local rendering = { lines = {}, colours = {} }`; `  local indent = details_indent(status_prefix)` → `  M.batch_indent = M.batch_indent or details_indent(status_prefix)` / `  local indent = M.batch_indent` | A | killed, 1 case: mixed widths |
| X2 (integrity) | render | `render_report`'s `return` → a span in the status's group at every later occurrence of its icon in the header (the integrity report's finding 2, verbatim) | C | killed, 1 case: `cover no icon in the text` |
| MS | render | `vim.api.nvim_strwidth(status_prefix)` → `vim.fn.strdisplaywidth(status_prefix)` (the first round's code) | A | killed, 2 cases: the narrow window × 2 |
| MD (attack) | render | `  done = '✓',` deleted | A | killed, 10 failing cases. 2 are assertions: `of every status the report tool accepts shows with an icon`, and `renders a newline…`, whose pcall returns the error. The other 8 raise when a `done` report is received |
| MF | `format.lua` (a temporary edit, outside the boundary, restored) | after `  { name = 'failed', … },` add `  { name = 'cancelled', moment = 'when the user cancels the task' },` | A | killed, 1 case: `of every status the report tool accepts shows with an icon` |
| MW (attack) | narrowed B | in the `eq()` at `:75`, both `'✓ 09:05 [done] Refactor the parser — All tests pass'` → `'09:05 [done] Refactor the parser — All tests pass'`, the target left unmoved | B | killed, 1 case. At `e1a5bea`, without the `eq()`, the attack measured it surviving |
| MWR | render | M13's edit, against the blocked-editor path | B | killed, 1 case: `is confirmed before the warning can hold the editor` |
| XN (re-measure) | render | `  local rendering = { lines = {}, colours = {} }` → the same line, then `  M.batch_indent = nil`; `  local indent = details_indent(status_prefix)` → `  local own = details_indent(status_prefix)` / `  M.batch_indent = M.batch_indent or own` / `  local indent = #M.batch_indent < #own and M.batch_indent or own` | A′, and `test_report_buffer.lua` whole | killed, 1 case in each: the done-before-progress case, `left = "        Two", right = "         Two"`. Without that case it survived A, `test_report_buffer.lua` and `test_report_colours.lua`, as the re-measure measured it |
| XW | render | XN's edit with `#M.batch_indent > #own` for `#M.batch_indent < #own` | A′ | killed, 1 case: the mixed-widths case, `key branch 2->4, left = "         Two", right = "        Two"` |
| X1 (integrity), again | render | X1's edit, as above | A′, and `test_report_buffer.lua` whole | killed, 2 cases in each: the mixed-widths case and the done-before-progress case |

M11 replaces the three-line `details_indent` with:

```lua
local measured_indents = {}
local function details_indent(status_prefix)
  local icon = status_prefix:sub(1, 3)
  measured_indents[icon] = measured_indents[icon] or (' '):rep(vim.fn.strdisplaywidth(status_prefix))
  return measured_indents[icon]
end
```

M12 replaces it with:

```lua
local LOADED_INDENTS = {}
for _, icon in pairs(STATUS_ICONS) do
  LOADED_INDENTS[icon] = (' '):rep(vim.fn.strdisplaywidth(icon .. ' HH:MM '))
end
local function details_indent(status_prefix)
  return LOADED_INDENTS[status_prefix:sub(1, 3)]
end
```

**The first round.** It measured M1–M13 at `1b34f07`, against narrowed copies of 15 and 17 cases, on the first round's `strdisplaywidth()` line. It found the same kills at smaller counts, all by assertion. The integrity review re-ran them and reproduced every count.

## Decisions & reasoning

- **The icons stay private to `render.lua`,** not beside `colours.STATUS_GROUPS`. Nothing outside the render reads them, and an icon is not a colour, so `colours.lua` keeps one concern. A test now ties them to the status list (A4).
- **The header's colours depend on the status alone.** The time is always 5 bytes:
  - a saved record's time is validated as `YYYY-MM-DDTHH:MM:SS` when it is read back (`records.lua`);
  - a new report's time comes from the plugin's clock, `os.date('%Y-%m-%dT%H:%M:%S')` (`plugin/aineo.lua`), and is not validated.

  `CLOCK_TIME_LENGTH` names that length.
- **The indent is measured with `vim.api.nvim_strwidth()` at each rendering,** never derived from `'ambiwidth'` and never kept (IC4).
  - `vim.fn.strdisplaywidth()`, which the brief allowed too, counts the current window's break padding when that window is narrow and wraps. The attack measured 9 to 37 cells in place of 8 (A1, A10).
  - M10, M11 and M12 are the shortcuts, and each is killed.
- **Reports of different widths are pinned in both orders.** Each order pins what the other cannot:
  - an indent kept from a rendering's first report only while it is narrower than a report's own (XN) is killed by the `done`-first case alone;
  - one kept only while it is wider (XW) is killed by the `progress`-first case alone;
  - one kept whatever its width (X1) is killed by both.
- **IC5's tests were seen red beside IC1's,** two tests failing with IC1's at once, because the brief asks for their red before the render changes. One render serves all three paths, so they turn green with IC1's code.

## Verification

- `make test` on 0.12.5, the host's, at the correction's `db623b4`: 832 cases, `Fails (0)`, exit 0. That is 808 on the base plus the 24 cases this packet adds: 15 in the first round, 8 in the fix round, 1 in the correction.
- `env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:… make test` on 0.11.6, at the same commit: 832 cases, `Fails (0)`, exit 0.
- `make lint`: StyLua clean; selene 0 errors, 0 warnings.
- The deep-require check prints only lines inside their own home.
- `tests/test_doc.lua` is green: the help fits in 78 columns.
- **The merge check with T14.**
  - `git merge-tree --write-tree 2e84083 origin/feature/t14-input-draft`, with T14 at `e0929f0`, is clean and gives tree `e588881`.
  - `test_doc.lua` on the merged help: 36 cases, `Fails (0)`, on 0.12.5 and on 0.11.6.
  - T12's branch does not exist yet.

## Readings, kept

- **"Details indented under the status"** is MR102 of [[Review/2026-09-24 — v1 MVP readings review]], which the user kept on 2026-09-26.
  - Each details line is indented by the width in cells of `<icon> HH:MM `, measured when the report is drawn. That is 8 cells under Neovim's defaults.
  - A report keeps the width it was drawn with until the Report shows every report again: `:edit` in the Report, or the Report made anew after the user deletes it.
- **The icon's colour** is C10's "coloured like the status": the status's group, whose links are MR96, kept on 2026-09-26.

## Task lines

This wave holds its marks. The line for the orchestrator to mark:

`| T11 | Report icon (C10): … | T9 | done — PR #45, wave 6 |` — the status cell only changes; the description stays as the plan has it.

## Limits

- **Reports already shown keep their indent** after `'ambiwidth'` or `setcellwidths()` changes, until the Report shows every report again: `:edit` in the Report, or the Report made anew after the user deletes it. A new report renders only itself. The help names both paths.
- **The width is Neovim's.** A terminal whose font draws an icon wider than Neovim counts it misaligns the details however they are measured. `setcellwidths()` is how the user tells Neovim the width.

## Open threads

- **The merge check against T12** (`origin/feature/t12-claude-numbers`) is still to run once that branch exists.

## Commits

*Recorded after the merge*: hashes change on rebase.
