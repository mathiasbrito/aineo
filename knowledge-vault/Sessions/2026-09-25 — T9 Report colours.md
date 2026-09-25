# 2026-09-25 — T9 Report colours

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t9-report-colours` · **Pull request:** into `dev` (a small fix, orchestrate §3)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C6; C10 as context; D10)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t9-report-colours.md`, its brief review `brief-review.md`, the evidence `baseline-0.11.6.txt` and `baseline-0.12.5.txt`

## Context

**Goal:** T9. The user asked on 2026-09-25 for "Time as comment color, [<status/state>] some color", and called it a small fix. It rests on C6's rendered line, `HH:MM [status] task — summary`. C10's icon belongs to a later packet, and the line's text does not change.

## What was done

- **`lua/aineo/report/colours.lua`** (new, inside the report home): the group names, meaning `AineoReportTime` and one group per status, and their default links. `define_report_colours()` links each group with `default = true`. It also creates a `ColorScheme` autocommand in the augroup `aineo_report_colours`, which it creates anew on every call so the autocommand is never defined twice. That autocommand links the groups again after every `:colorscheme`.
- **`render.lua`**: `render_records(records)` returns an `aineo.report.Rendering`, which holds `lines` and `colours`. The colours are spans placed from the columns the render wrote the `HH:MM` and the `[status]` into, never found by matching text afterwards (RC3). `render_report` is now private. The header's text is unchanged (RC6).
- **`buffer.lua`**: `append_rendering(buffer, rendering)` adds the lines and places each colour as an extmark in the namespace `aineo_report_colours`. When the buffer is empty, it first clears that namespace. `append_lines` is now private; it has no other caller.
- **`init.lua`**: `show_rendering()` defines the groups only when a rendering has colours. Both `show_records()` (the Report opening, and `BufReadCmd` after `:edit`) and `show_and_keep()` (a live report) go through it.
- **`tests/test_report_colours.lua`**: new, 14 cases.
- **`doc/aineo.txt`**: changed inside `*aineo-report*` only. A *Colours* paragraph, and the six groups, each with its own tag (`*hl-AineoReportTime*` … `*hl-AineoReportFailed*`). This is the documentation the change invalidated. `CONTENTS` and every other section are untouched.

## Unit list and red/green

| # | Behaviour | Test | Status |
|---|---|---|---|
| 1 | RC1 | *the time › shows in AineoReportTime, which links to Comment* | red: `Left: { {}, vim.NIL }` |
| 2 | RC2 | *the status › shows, brackets included, in the group of its status, linked to its default* (5 statuses) | red, all 5: `Left: { {}, vim.NIL }` |
| 3 | RC4 | *the groups › keep a user's colour made before the first report* | red: `left = "DiagnosticOk"` at key `link` (aineo's link replaced the user's colour) |
| 4 | RC5 | *the records › show their time and status coloured when the Report opens* | red: `Left: { {}, {}, {} }` |
| 5 | RC5 | *the records › show their colours once again when the user edits the Report again* (`edit`, `edit!`) | red, both: stale marks `{ 2, 0, 0 }` in every group |
| 6 | RC4 | *the groups › link to their defaults again when a colour scheme that colours none of them follows one that did* | red: `Left: vim.empty_dict()` |
| 7 | RC3 | *the colours › cover only the time and the status the render placed, not their like in the text* | arrived green: unit 1–2's seam places colours from render columns; killed by M6 |
| 8 | RC7 | *the groups › are not defined, nor their autocommand, until the Report shows a report* | red: `Left: { { 1, 1, 1, 1, 1, 1 }, 1 }` (an empty Report defined them) |
| 9 | RC5 | *the colours › of a report that follows another are on its own header* | arrived green: pins code written with unit 1 (the non-empty offset in `append_rendering`), added after M10 was killed only by a crash; killed by M10b |

## Mutants

Final table, run on the committed tree `de2ce3d` with the host's Neovim 0.12.5 (`make test_file` on the default `PATH`, as were the red runs above), one at a time, from a pristine copy, each against a copy of its test file narrowed to the targeted group (`.tests/t9-<group>.lua`). M9, M14p and M15p were run again on 0.11.6, with the same results.

| # | Literal edit | Test | Result |
|---|---|---|---|
| M1 | colours: `[M.TIME_GROUP] = 'Comment'` → `'Normal'` | time | killed, assertion |
| M2 | render: `end_column = #clock_time, group` → `#clock_time + 1` | time | killed, assertion |
| M3 | render: `first_column = status_column,` → `status_column + 1,` | status | killed, assertion (5/5) |
| M4 | colours: blocked `'DiagnosticWarn'` → `'DiagnosticError'` | status | killed, assertion |
| M5 | render: `group = colours.STATUS_GROUPS[report.status]` → `colours.STATUS_GROUPS.done` | status | killed, assertion (4/5) |
| M6 | render: status columns from the last text match, `header:match('.*()' .. vim.pesc(bracketed_status)) - 1` and `header:match('.*' .. vim.pesc(bracketed_status) .. '()') - 1` | colours | killed, assertion |
| M6s | the same edit | status | survived (RC2 has one match); rerun on `tests/test_report_colours.lua`: killed, assertion (RC3) |
| M7 | render: `local line = #rendering.lines + colour.line` → `colour.line` | records | killed, assertion (3/3) |
| M8b | init: `show_rendering(report_buffer, render.render_records(kept))` → `buffer.append_rendering(report_buffer, { lines = render.render_records(kept).lines, colours = {} })` | records | killed, assertion (3/3) |
| M9 | buffer: delete `vim.api.nvim_buf_clear_namespace(buffer, REPORT_COLOURS, 0, -1)` | records | killed, assertion (2/3, the `:edit` cases) |
| M10 | buffer: delete `first_line = 0` | time | **crash** (`Invalid 'end_col': out of range`), not counted |
| M10b | buffer: `local first_line = vim.api.nvim_buf_line_count(buffer)` → `… - 1` | colours | killed, assertion |
| M11 | colours: `{ link = link, default = true }` → `{ link = link }` | groups | killed, assertion (2/3) |
| M12 | colours: `callback = link_groups_to_defaults,` → `callback = function() end,` | groups | killed, assertion |
| M13 | init: `if #rendering.colours > 0 then` → `if true then` | groups | killed, assertion |
| M14 | init: `colours.define_report_colours()` before `return M` (at `require('aineo.report')`) | groups | killed, assertion |
| M14p | the same edit | `tests/test_plugin.lua` (frozen) | **survived**; killed by the file this PR adds, assertion (M14) |
| M15 | `plugin/aineo.lua`: `vim.api.nvim_set_hl(0, 'AineoReportTime', { link = 'Comment', default = true })` before `vim.g.loaded_aineo = true` | groups | killed, assertion |
| M15p | the same edit | `tests/test_plugin.lua` (frozen) | **survived**; killed by the file this PR adds, assertion |
| M16p | `plugin/aineo.lua`: `require('aineo.report.colours').define_report_colours()` before `vim.g.loaded_aineo = true` | `tests/test_plugin.lua` (frozen) | killed, assertion (3/4) |
| M17 | render: `'%s %s %s — %s'` → `'%s %s %s - %s'` (RC6) | `test_report_buffer.lua` › *a report* | killed, assertion (4/6) |

An earlier M8, which called the now-private `buffer.append_lines`, crashed and was replaced by M8b.

## Decisions & reasoning

- **The render returns its colours beside its lines.** This was the brief's suggested seam (RC3). Matching the text afterwards was rejected: it colours `[done]` inside a task, which M6 shows.
- **Groups are defined only when a rendering has colours.** RC7 says "when the Report first shows a report, or later". An empty Report opening, for example the layout opening with no records, is earlier, so it defines nothing (unit 8's red).
- **Groups are defined again on every coloured rendering, and the augroup is re-created each time.** This avoids a module-level "defined" flag. The cost is six `nvim_set_hl` calls and one autocommand per report.
- **Clearing colours in an empty buffer.** `:edit` on the Report (`BufReadCmd`) empties its text but keeps its extmarks, collapsed at the buffer's end (unit 5's red: `{ 2, 0, 0 }`). `append_rendering` treats an empty buffer as a fresh start.

## Verification

- 0.11.6 (`<builds>/nvim-0.11.6`, first on `PATH`), final tree: 741 cases, `Fails (0)`, exit 0.
- Host 0.12.5, final tree: 741 cases, `Fails (8)`. These are the same eight, by name, as `evidence/baseline-0.12.5.txt`. None is T9's.
- `make lint`: StyLua check and selene, 0 errors, 0 warnings.
- The deep-require check prints only requires inside a home. T9 adds two, `lua/aineo/report/init.lua` and `lua/aineo/report/render.lua` requiring `aineo.report.colours`, both inside `aineo.report`.

## Readings for the MVP review

- **The colour of each status** (RC2) is the orchestrator's reading, for the user to confirm: started → `DiagnosticInfo`, progress → `DiagnosticHint`, blocked → `DiagnosticWarn`, done → `DiagnosticOk`, failed → `DiagnosticError`. The time → `Comment` is the user's own.
- The groups are defined when a report is first shown, and not when an empty Report opens.

## Task lines

The wave holds its marks (rule 6). The line T9 would take:

> T9 — [X] Report colours: `AineoReportTime` (→ `Comment`) and one group per status (→ `Diagnostic*`), `default = true`, re-linked on `ColorScheme`, placed from the render's columns; defined only once a report is shown.

## Open threads

- **The frozen RC7 pins do not catch every mutant the brief said they would.** `tests/test_plugin.lua` passes when the groups are defined at `require('aineo.report')` (M14p) or by a plain `nvim_set_hl` in `plugin/aineo.lua` (M15p). Only a `require` of a report file from `plugin/aineo.lua` turns them red (M16p). T9's own pin in `tests/test_report_colours.lua` catches M14 and M15.
- **A candidate Learning for the adjustment pass:** `:edit` on a `nofile` buffer with a `BufReadCmd` empties its text but not its extmarks, which collapse to the end of the refilled buffer. Measured by unit 5's red on 0.12.5 and by mutant M9 on both 0.11.6 and 0.12.5.
- The merge checks with T13's and T12's branches found neither branch on the remote at the time of the push; see the pull request.

## Commits

*Recorded after the merge.*
