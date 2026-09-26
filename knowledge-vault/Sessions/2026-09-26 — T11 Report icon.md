# 2026-09-26 — T11 Report icon

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t11-report-icon` · **Pull request:** #45 into `dev` (a regular packet)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C10, which supersedes C6's rendered line; C6; D10)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t11-report-icon.md` with its amendment of 2026-09-26, the brief reviews `brief-review-t11-report-icon.md` and `brief-review-t11-amendment.md`, the evidence `icon-widths.txt` and `baseline-7af0d47.txt`
- [[Sessions/2026-09-25 — T9 Report colours]] — the groups this packet colours the icon with, and its *Limits*

## Context

**Goal:** T11. The user asked on 2026-09-25 for "an icon in the beginning (icons from unicode, but only the ones terminal styled)" and chose the "Unicode set": `▸` started, `◐` progress, `⊘` blocked, `✓` done, `✗` failed. That is C10: `<icon> HH:MM [status] task — summary`, the icon coloured like the status, the details indented under the status.

## What was done

- **`lua/aineo/report/render.lua`**
  - `STATUS_ICONS`, private to the render, maps each status to its icon.
  - The header is `<icon> HH:MM [status] task — summary`. The one render, `render_records()`, serves every path that shows a report: a new report, the saved records when the Report opens, and the refill after `:edit` (IC5).
  - `header_colours(status)` places three spans: the icon's 3 bytes and the `[status]` in the status's group, the `HH:MM` in `AineoReportTime`. The space after the icon shows in no group (IC2, IC3).
  - `details_indent(status_prefix)` indents each details line by the display width of `<icon> HH:MM `, measured with `strdisplaywidth()` at each rendering (IC4). Under Neovim's defaults the indent is 8.
- **`lua/aineo/report/colours.lua`**: only its docstrings, which now name the icon beside the `[status]`.
- **`doc/aineo.txt`**, inside `*aineo-report*` only: the line with `<icon>`, the icons by status, the measured indent and when it is redrawn, the icon in the *Colours* paragraph (reflowed to 78 columns), and each group's row naming its icon.
- **Pins moved (IC6).**
  - 31 header pins gain the icon and its space: 21 in `test_report_buffer.lua`, 2 in `test_entry_report.lua` (one of them through `REPORT_LINES`), 5 in `test_mcp_delivery.lua`, 3 in `test_mcp_blocked_editor.lua`, including the wait target at line 75.
  - 4 details pins go from 6 to 8 spaces: `test_report_buffer.lua`'s two and `test_mcp_delivery.lua`'s two.
  - Every colour pin in `test_report_colours.lua` moves by 4 bytes and gains the icon's span; none is deleted.
  - Two patterns change: `REPORT_HEADERS` keeps lines starting with a non-space (`^%S`) in place of a digit, and `REPORT_LINES` keeps the icon and rewrites the time after it.
- **Unchanged:** `records.lua` and the records' format, so reports saved before this change show with the icon; `init.lua`; the groups and their links; `plugin/aineo.lua`.

## Unit list and red/green

The slicing, stated before the first test:

1. IC1 — the header starts with the icon of its status, parametrized over the five statuses.
2. IC5 — the icon shows on the records shown when the Report opens, and after `:edit`. Written and seen red beside IC1, before the render changed, as the brief asks.
3. IC6 — the text pins follow the new header (a consequence of 1, done in the same unit so the suite ends green).
4. IC3 — the time and the status keep their colours at columns moved by 4 bytes.
5. IC2 — the icon shows in its status's group, and the space after it in none.
6. IC4 — the details' indent is the display width of `<icon> HH:MM `: 8 under the defaults, 9 for `◐` under `'ambiwidth'` `double`, 9 for `✓` under `setcellwidths()`, and each report keeps the width it was drawn with until `:edit`.

**Seen red (26 cases):**

| Test | Red |
|---|---|
| `a report › renders the icon of its status first › for the status` × 5 | `left = "09:05 [started] Task — Summary", right = "▸ 09:05 [started] Task — Summary"`, and the like for each status |
| `a report › shows its icon among the records when the Report opens in a new editor` | `left = "09:05 [failed] Task — Summary", right = "✗ 09:05 [failed] Task — Summary"` |
| `a report › shows its icon again when the user edits the Report again` | `left = "09:05 [progress] Task — Summary", right = "◐ 09:05 [progress] Task — Summary"` |
| `test_report_colours.lua`: `the time`, `the status` × 5, both `the colours` cases, `the records › show their time and status coloured…`, `…once again when the user edits…` × 2 — the 11 colour pins moved by 4 bytes (IC3) | `left = 0, right = 4` (the time) and `left = 6, right = 10` (the status) |
| `the icon › shows in the group of its status, and the space after it in none` × 5 | `different values at key branch 1->2, left = 4, right = 0` — no span at byte 0 |
| `a report › renders each line of its details below it, indented`, and `test_mcp_delivery.lua`'s `…fields holding code render literally…` — the details pins moved to 8 (IC4, defaults) | `left = "      Changed three files", right = "        Changed three files"` |
| `a report › indents its details by its icon's width under 'ambiwidth' double` | `left = "        Detail", right = "         Detail"` — against the indent measured once when `render.lua` loaded |

The 31 header pins and the two patterns were moved after IC1's code turned them red (22 failing cases in `test_report_buffer.lua` alone); they are pins of existing behaviour following a changed line, not new units.

**Arrived green (2):**

- `a report › indents its details by its icon's width under setcellwidths()` — spent by IC4's per-rendering measurement. Killer: M10, an indent derived from `'ambiwidth'` instead of measured; run, killed by assertion.
- `a report › keeps the indent it was drawn with until the user edits the Report again` — spent the same way. Killer: M11, the indent measured once per icon and kept; run, killed by assertion.

## Mutants

Each mutant is its literal edit to `lua/aineo/report/render.lua` at the committed head, applied to a pristine copy, run against a narrowed copy of the test file that targets it, then restored: `.tests/t11-a-report.lua` (the header and the `a report` group of `test_report_buffer.lua`, 15 cases) and `.tests/t11-colours.lua` (every group of `test_report_colours.lua` before `the groups`, 17 cases). All on 0.12.5. Every kill is an assertion (`Failed expectation for equality`); none crashed, none survived.

| Id | Literal edit | Result |
|---|---|---|
| M1 | `progress = '◐',` / `blocked = '⊘',` → `progress = '⊘',` / `blocked = '◐',` | killed, 5 cases, among them IC1's `progress` and `blocked` |
| M2 | `('%s %s '):format(STATUS_ICONS[report.status], time:sub(12, 16))` → `('%s %s '):format('▸', time:sub(12, 16))` | killed, 13 cases, among them both IC5 cases |
| M3 | icon span `end_column = #icon` → `end_column = #icon + 1` | killed, 15 cases, among them IC2 × 5 |
| M4 | the icon span's line deleted | killed, 15 cases |
| M5 | icon span `group = status_group` → `group = colours.TIME_GROUP` | killed, 16 cases |
| M6 | `local time_column = #icon + 1` → `local time_column = #icon` | killed, 16 cases |
| M7 | `local status_column = time_column + CLOCK_TIME_LENGTH + 1` → `… + CLOCK_TIME_LENGTH` | killed, 15 cases |
| M8 | `return (' '):rep(vim.fn.strdisplaywidth(status_prefix))` → `return (' '):rep(#status_prefix)` | killed, 4 cases (bytes, not cells) |
| M9 | the same line → `return (' '):rep(8)` | killed, 3 cases: `ambiwidth`, `setcellwidths()`, the sequence |
| M10 | the same line → `return (' '):rep(8 + ((vim.o.ambiwidth == 'double' and status_prefix:find('◐', 1, true)) and 1 or 0))` | killed, 1 case: `setcellwidths()` |
| M11 | `details_indent` keeps the first width measured per icon (`measured_indents[icon] = measured_indents[icon] or …`) | killed, 1 case: the sequence |
| M12 | `details_indent` returns a width per icon computed when `render.lua` loads (`LOADED_INDENTS[icon] = (' '):rep(vim.fn.strdisplaywidth(icon .. ' HH:MM '))`) | killed, 3 cases: `ambiwidth`, `setcellwidths()`, the sequence |
| M13 | `('%s %s '):format(STATUS_ICONS[report.status], time:sub(12, 16))` → `('%s '):format(time:sub(12, 16))` | killed, 14 cases |

## Decisions & reasoning

- **The icons stay private to `render.lua`,** not beside `colours.STATUS_GROUPS`. Nothing outside the render reads them, and an icon is not a colour; `colours.lua` keeps one concern.
- **The header's colours depend on the status alone.** The time is always 5 bytes, since a record's time is validated as `YYYY-MM-DDTHH:MM:SS` before it is rendered; `CLOCK_TIME_LENGTH` names that.
- **The indent is measured with `vim.fn.strdisplaywidth()` at each rendering,** never derived from `'ambiwidth'` and never kept (IC4). M10, M11 and M12 are the three shortcuts, each killed.
- **IC5's tests were seen red beside IC1's,** two tests failing with IC1's at once, because the brief asks for their red before the render changes; one render serves all three paths, so they turn green with IC1's code.

## Verification

- `make test`, 0.12.5 (the host's): 823 cases, `Fails (0)`, exit 0 — 808 on the base plus the 15 cases this packet adds.
- `env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:… make test`, 0.11.6: 823 cases, `Fails (0)`, exit 0.
- `make lint`: StyLua clean; selene 0 errors, 0 warnings.
- The deep-require check prints only lines inside their own home.
- `tests/test_doc.lua` green: the help fits in 78 columns.

## Readings for the MVP review

- **"Details indented under the status"** is read as: each details line is indented by the display width of what comes before `[status]` in its header, `<icon> HH:MM `, measured at the moment the report is drawn. Under Neovim's defaults that is 8 cells. A report keeps the width it was drawn with; `:edit` in the Report redraws every report with the width of that moment. The orchestrator's reading, in the brief.
- **The icon's colour** is its status's group, the same as the `[status]`'s (T9's reading of the status colours, awaiting the same review).

## Task lines

This wave holds its marks. The line for the orchestrator to mark:

`| T11 | Report icon (C10): … | T9 | done — the icon by status, coloured like the status; details indented by the display width of "<icon> HH:MM ", measured per rendering |`

## Limits

- **Reports already shown keep their indent** after `'ambiwidth'` or `setcellwidths()` changes, until `:edit` in the Report; a new report renders only itself. Named in the help.
- **The width is Neovim's.** A terminal whose font draws an icon wider than Neovim counts it misaligns the details however they are measured; `setcellwidths()` is the user's way to tell Neovim.

## Open threads

- **The merge check against T14 and T12** (`git merge-tree` of this head with `origin/feature/t14-input-draft` and `origin/feature/t12-claude-numbers`, then `test_doc.lua` on the merged help) could not run: neither branch existed on `origin` when this packet pushed. Every hunk of `doc/aineo.txt` is inside `*aineo-report*`.

## Commits

*Recorded after the merge* — hashes change on rebase.
