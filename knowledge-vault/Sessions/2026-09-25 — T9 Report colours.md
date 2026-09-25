# 2026-09-25 — T9 Report colours

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t9-report-colours` · **Pull request:** #30 into `dev` (a small fix, orchestrate §3)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C6; C10 as context; D10)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t9-report-colours.md`, its brief review `brief-review.md`, the evidence `baseline-0.11.6.txt` and `baseline-0.12.5.txt`
- The fix round's inputs: the guarantee review (findings G1–G4) and the records review (findings R1–R5) of pull request #30
- The correction's input: the re-measure of pull request #30 after the fix round (findings 1–3, probes Q3, Q3b, Q3e and Q8c, mutants MC3, MAB3 and MX)

## Context

**Goal:** T9. The user asked on 2026-09-25 for "Time as comment color, [<status/state>] some color", and called it a small fix. It rests on C6's rendered line, `HH:MM [status] task — summary`. C10's icon belongs to a later packet, and the line's text does not change.

## What was done

- **`lua/aineo/report/colours.lua`** (new, inside the report home) holds the group names: `AineoReportTime` and one group per status, each with its default link.
  - `define_report_colours()` defines each group with `:highlight default link`.
  - A group a user or a colour scheme has coloured keeps its colour.
  - `:highlight clear`, which a colour scheme runs first, restores each group's default link. That is aineo's link, unless a user or a colour scheme gave the group a default link of its own before aineo first defined it (see *Limits*). aineo defines no `ColorScheme` autocommand.
- **`render.lua`**: `render_records(records)` returns an `aineo.report.Rendering`, which holds `lines` and `colours`.
  - The colours are spans placed from the columns the render wrote the `HH:MM` and the `[status]` into, never found by matching text afterwards (RC3).
  - `render_report` is now private.
  - The header's text is unchanged (RC6).
- **`buffer.lua`**: `append_rendering(buffer, rendering)` adds the lines and places each colour as an extmark in the namespace `aineo_report_colours`.
  - When the buffer is empty, it first clears that namespace.
  - `append_lines` is now private; it has no other caller.
- **`init.lua`**: `show_rendering()` defines the groups only when a rendering has colours. Both `show_records()` (the Report opening, and `BufReadCmd` after `:edit`) and `show_and_keep()` (a live report) go through it.
- **`tests/test_report_colours.lua`**: new, 20 cases in 15 tests (17 in 12 until the correction).
- **`doc/aineo.txt`**: changed inside `*aineo-report*` only. This is the documentation the change invalidated; `CONTENTS` and every other section are untouched.
  - A *Colours* paragraph, which names `:colorscheme` and `:highlight clear`.
  - The six groups, each with its own tag (`*hl-AineoReportTime*` … `*hl-AineoReportFailed*`).

## Unit list and red/green

Every red was seen on the host's 0.12.5, through `make test_file`. In the packet, 7 tests (12 cases) were seen red and 2 arrived green. In the fix round, 3 more were seen red and 1 test was strengthened. In the correction, 3 tests were added: each arrived green, pinning the code as it stands, and each was seen red against its mutant on both 0.11.6 and 0.12.5.

| # | Behaviour | Test | Status |
|---|---|---|---|
| 1 | RC1 | *the time › shows in AineoReportTime, which links to Comment* | red: `Left: { {}, vim.NIL }` |
| 2 | RC2 | *the status › shows, brackets included, in the group of its status, linked to its default* (5 statuses) | red, all 5: `Left: { {}, vim.NIL }` |
| 3 | RC4 | *the groups › keep a user's colour made before the first report* | red: `left = "DiagnosticOk"` at key `link` (aineo's link replaced the user's colour) |
| 4 | RC5 | *the records › show their time and status coloured when the Report opens* | red: `Left: { {}, {}, {} }` |
| 5 | RC5 | *the records › show their colours once again when the user edits the Report again* (`edit`, `edit!`) | red, both: stale marks `{ 2, 0, 0 }` in every group |
| 6 | RC4 | *the groups › link to their defaults again when a colour scheme that colours none of them follows one that did* | red: `Left: vim.empty_dict()` |
| 7 | RC3 | *the colours › cover only the time and the status the render placed, not their like in the text* | arrived green: units 1–2's seam places colours from the render's columns; killed by M6 |
| 8 | RC7 | *the groups › are not defined, nor any ColorScheme autocommand, until the Report shows a report* | red: `Left: { { 1, 1, 1, 1, 1, 1 }, 1 }` (an empty Report defined them). Renamed in the fix round: it counts `ColorScheme` autocommands in place of the augroup (G2) |
| 9 | RC5 | *the colours › of a report that follows another are on its own header* | arrived green: pins code written with unit 1 (the non-empty offset in `append_rendering`), added after M10 was killed only by a crash; killed by M10b |
| 10 | RC5 (fix round, G1) | *the records › show in groups linked to their defaults when the Report opens* | the guarantee reviewer's pin, adopted. Green on the code; red against the reviewer's MP: `left = vim.NIL, right = "Comment"` |
| 11 | RC4 (fix round, G4) | *the groups › link to their defaults again when :highlight clear drops a user's colour made before the first report* | red on the packet's code: `Left: vim.empty_dict()` |
| 12 | RC4 (fix round) | *the groups › need no ColorScheme autocommand, however many reports came* | red while the autocommand existed: `Left: 1, Right: 0` |
| 13 | RC7 (correction, re-measure finding 3) | *the groups › add no autocommand of any event until the Report shows a report* | the re-measure's pin, adopted. Arrived green (pins code without autocommands); red against the re-measure's MC3: `Left: 285, Right: 284` (0.12.5), `Left: 281, Right: 280` (0.11.6) |
| 14 | RC7 (correction, re-measure finding 3) | *the groups › add no autocommand of any event as more reports come* | the re-measure's pin, adopted. Arrived green, as unit 13; red against MAB3: `Left: 287, Right: 286` (0.12.5), `Left: 283, Right: 282` (0.11.6) |
| 15 | RC4's limit (correction, re-measure finding 1) | *the groups › go back to a colour scheme's default link made before the first report whenever :highlight clear runs* | arrived green: it pins the limit as it behaves (the re-measure's Q3 values `Title`, `DiagnosticOk`, `Title`); red against MX: `Left: { "Title", "DiagnosticOk", "DiagnosticOk" }` on both versions |

**One assertion changed in the fix round.** Unit 6 now expects `{ link = 'DiagnosticOk' }` in place of `{ link = 'DiagnosticOk', default = true }`.
- The `default` key was a detail of the removed `nvim_set_hl` mechanism. RC4's behaviour is "linked to its default again".
- It is still an exact whole-table assertion.

## Mutants

The final table was run on the pull request's final code (the fix round's code commit), one mutant at a time, from a pristine copy. The correction's rows, MC3, MAB3 and MX, were run on the pull request's final tree, after the correction's last edit; its Lua differs from the fix round's only in the `define_report_colours` docstring.
- **Where it ran:** on the host's 0.12.5, each mutant against a copy of its test file narrowed to the targeted group (`.tests/t9-<group>.lua`).
- **M11 and M12 are retired:** they edited the `nvim_set_hl` call and the autocommand's callback, which the fix round removed.
- **The packet's table:** measured on the packet's code, it had the same results for every row still present, with two exceptions: M8b killed 3 of 3 there, and M16p killed 3 of 4 (the third through the autocommand it added).

| # | Literal edit | Test | Result |
|---|---|---|---|
| M1 | colours: `[M.TIME_GROUP] = 'Comment'` → `'Normal'` | time | killed, assertion |
| M2 | render: `end_column = #clock_time, group` → `#clock_time + 1` | time | killed, assertion |
| M3 | render: `first_column = status_column,` → `status_column + 1,` | status | killed, assertion (5/5) |
| M4 | colours: blocked `'DiagnosticWarn'` → `'DiagnosticError'` | status | killed, assertion |
| M5 | render: `group = colours.STATUS_GROUPS[report.status]` → `colours.STATUS_GROUPS.done` | status | killed, assertion (4/5) |
| M6 | render: status columns from the last text match, `header:match('.*()' .. vim.pesc(bracketed_status)) - 1` and `header:match('.*' .. vim.pesc(bracketed_status) .. '()') - 1` | colours | killed, assertion |
| M6s | the same edit | status | survived (RC2 has one match); rerun on `tests/test_report_colours.lua`: killed, assertion (RC3) |
| M7 | render: `local line = #rendering.lines + colour.line` → `colour.line` | records | killed, assertion (3 of the group's 4; the G1 pin asserts links, not places) |
| M8b | init: `show_rendering(report_buffer, render.render_records(kept))` → `buffer.append_rendering(report_buffer, { lines = render.render_records(kept).lines, colours = {} })` | records | killed, assertion (4/4) |
| M9 | buffer: delete `vim.api.nvim_buf_clear_namespace(buffer, REPORT_COLOURS, 0, -1)` | records | killed, assertion (2, the `:edit` cases) |
| M10 | buffer: delete `first_line = 0` | time | **crash** (`Invalid 'end_col': out of range`), not counted |
| M10b | buffer: `local first_line = vim.api.nvim_buf_line_count(buffer)` → `… - 1` | colours | killed, assertion |
| MH | colours: `vim.cmd.highlight({ 'default', 'link', group, link })` → `vim.cmd.highlight({ 'link', group, link, bang = true })` | groups | killed, assertion (3) |
| MI | colours: the same line → `vim.api.nvim_set_hl(0, group, { link = link, default = true })` (the packet's mechanism, without its autocommand) | groups | killed, assertion (2: the `:highlight clear` case and the colour-scheme case) |
| MC2 | colours: `vim.api.nvim_create_autocmd('ColorScheme', { callback = M.define_report_colours })` before `return M` | groups | killed, assertion (2) |
| MAB2 | colours: `vim.api.nvim_create_autocmd('ColorScheme', { callback = function() end })` as the first line of `define_report_colours()` | groups | killed, assertion (1: *need no ColorScheme autocommand*) |
| M13 | init: `if #rendering.colours > 0 then` → `if true then` | groups | killed, assertion |
| M14 | init: `colours.define_report_colours()` before `return M` (at `require('aineo.report')`) | groups | killed, assertion |
| M14p | the same edit | `tests/test_plugin.lua` (frozen) | **survived**; killed by the file this PR adds, assertion |
| M15 | `plugin/aineo.lua`: `vim.api.nvim_set_hl(0, 'AineoReportTime', { link = 'Comment', default = true })` before `vim.g.loaded_aineo = true` | groups | killed, assertion |
| M15p | the same edit | `tests/test_plugin.lua` (frozen) | **survived**; killed by the file this PR adds, assertion |
| M16p | `plugin/aineo.lua`: `require('aineo.report.colours').define_report_colours()` before `vim.g.loaded_aineo = true` | `tests/test_plugin.lua` (frozen) | killed, assertion (2/4) |
| M17 | render: `'%s %s %s — %s'` → `'%s %s %s - %s'` (RC6) | `test_report_buffer.lua` › *a report* | killed, assertion (4/6) |
| MC3 | colours: `vim.api.nvim_create_autocmd('ColorSchemePre', { callback = function() end })` before `return M` (the re-measure's edit) | groups, both versions | killed, assertion (1: unit 13) |
| MAB3 | colours: `  vim.api.nvim_create_autocmd('ColorSchemePre', { callback = function() end })` as the first line of `define_report_colours()` (the re-measure's edit) | groups, both versions | killed, assertion (1: unit 14) |
| MX | colours: `    vim.api.nvim_set_hl(0, group, { link = link, default = true })` inserted before the `vim.cmd.highlight` line (the re-measure's edit) | groups, both versions | killed, assertion (1: unit 15); it survived the whole file before the correction |

An earlier M8, which called the now-private `buffer.append_lines`, crashed and was replaced by M8b.

**The guarantee reviewer's four survivors**, re-run as its literal edits against `tests/test_report_colours.lua`:

| # | Literal edit | On the packet's code | On the final code |
|---|---|---|---|
| MP | init: `  show_rendering(report_buffer, render.render_records(kept))` → `  buffer.append_rendering(report_buffer, render.render_records(kept))` | survived | killed, assertion (the G1 pin) |
| MC | colours: `vim.api.nvim_create_autocmd('ColorScheme', { callback = link_groups_to_defaults })` before `return M` | survived | crash (`Required: 'command' or 'callback'`: the function no longer exists); MC2 is its form on the final code |
| MA | colours: `nvim_create_augroup('aineo_report_colours', {})` → `…, { clear = false })` | survived | not applicable: the augroup is gone; MAB2 is its form on the final code |
| MB | colours: delete `group = vim.api.nvim_create_augroup('aineo_report_colours', {}),` | survived | not applicable, as MA |

## Decisions & reasoning

- **The render returns its colours beside its lines.** This was the brief's suggested seam (RC3). Matching the text afterwards was rejected: it colours `[done]` inside a task, which M6 shows.
- **Groups are defined only when a rendering has colours.** RC7 says "when the Report first shows a report, or later". An empty Report opening, for example the layout opening with no records, is earlier, so it defines nothing (unit 8's red).
- **`:highlight default link`, not `nvim_set_hl(…, { default = true })`** (the fix round; the orchestrator's decision 2, on the guarantee reviewer's G4).
  - **What `nvim_set_hl` missed:** it records no default link over a group that already has settings. So a user's colour made before the first report, then `:highlight clear`, left the group empty.
  - **What the Ex form does:** it records the default link anyway, when the group has none yet, and `:highlight clear` restores it. When a user or a colour scheme gave the group a default link first, that one stays (*Limits*).
  - **Measured by a probe on 0.11.6 and 0.12.5, identical on both:**
    - a user's colour, or a user's `:highlight! link`, is kept;
    - a scheme's colour made before aineo's definition is kept;
    - `:highlight clear` then links the group to its default again;
    - a second definition changes nothing in those cases.
  - **The `ColorScheme` autocommand was dropped.** Every RC4 case the suite pins passes without it on both versions, and MI shows the old mechanism needed it. One case does not, which the re-measure found and the orchestrator accepted as a limit: a colour scheme's own default link for a group, made before aineo first defined it (*Limits*). The old autocommand covered that case; the fix round's sentence "every RC4 case passes without it" claimed more than was measured.
- **Groups are defined again on every coloured rendering.** Six idempotent `:highlight default link` commands per report. This avoids a module-level "defined" flag.
- **Clearing colours in an empty buffer.** `:edit` on the Report (`BufReadCmd`) empties its text but keeps its extmarks, collapsed at the buffer's end (unit 5's red: `{ 2, 0, 0 }`). `append_rendering` treats an empty buffer as a fresh start.

## Verification

Measured on the pull request's final tree, after the correction's last edit.

- 0.11.6 (`<builds>/nvim-0.11.6`, first on `PATH`): 747 cases, `Fails (0)`, exit 0.
- Host 0.12.5: 747 cases, `Fails (8)`, exit 2. These are the same eight, by name, as `evidence/baseline-0.12.5.txt`. None is T9's.
- `tests/test_report_colours.lua` alone: 20 cases, `Fails (0)` on both versions. Of its 15 tests (20 cases): 7 tests (12 cases) seen red in the packet, 3 in the fix round, 2 arrived green in the packet and 3 in the correction; 12 + 3 + 2 + 3 = 20, and 727 + 20 = 747.
- `make lint`: StyLua check and selene, 0 errors, 0 warnings.
- The deep-require check prints only requires inside a home. T9 adds two, `lua/aineo/report/init.lua` and `lua/aineo/report/render.lua` requiring `aineo.report.colours`, both inside `aineo.report`.

## Readings for the MVP review

- **The colour of each status** (RC2) is the orchestrator's reading, for the user to confirm: started → `DiagnosticInfo`, progress → `DiagnosticHint`, blocked → `DiagnosticWarn`, done → `DiagnosticOk`, failed → `DiagnosticError`. The time → `Comment` is the user's own.

## Task lines

The wave holds its marks (rule 6). The line T9 would take:

- [X] T9 — Report colours (C6): `AineoReportTime` (→ `Comment`) and one group per status (→ `Diagnostic*`), defined with `:highlight default link` so a user's or a colour scheme's colour wins and `:highlight clear` restores their default links, with no autocommand (a default link given before aineo's is the one restored: a recorded limit); placed from the render's columns; defined only once a report is shown. A small fix.

## Limits

- **A default link given before aineo's is the one `:highlight clear` restores.** Re-measure finding 1, accepted by the orchestrator as a limit of RC4.
  - **The case.** A colour scheme runs `highlight clear`, then `highlight default link AineoReportDone Title` (or, in Lua, `nvim_set_hl(0, 'AineoReportDone', { link = 'Title', default = true })`), before the Report first shows a report. After a report, `:colorscheme` to a scheme that does not name the group leaves it linked to `Title`, not `DiagnosticOk`. The next report, or `:edit` in the Report, links it to `DiagnosticOk`; the next `:colorscheme` or `:highlight clear` brings `Title` back.
  - **The cause.** Neovim keeps one default link per group and records only the first (`do_highlight()` sets `sg_deflink` only while it is 0); `highlight_clear()` restores `sg_link = sg_deflink`. aineo's `:highlight default link` never replaces the scheme's.
  - **Measured by the re-measure, identical on 0.11.6 and 0.12.5:**
    - Q3: the scheme, a report, `colorscheme` without the group, a report, `:highlight clear` → `Title`, `Title`, `DiagnosticOk`, `Title`;
    - Q3b: the Lua scheme with `default = true`, a report, `colorscheme` without the group → `Title`;
    - Q3e: Q3's scheme, a report, `colorscheme` without the group, `:highlight clear` → `Title`;
    - Q8c: Q3's scheme, a report, `colorscheme` without the group, `:edit` in the Report → `Title`, then `DiagnosticOk`.
  - **Why it stays.** A scheme that names aineo's groups chose that colour on purpose. The re-measure measured the fixes it could build: restoring the `ColorScheme` autocommand cures the scheme's case but loses a user's own default link (its Q3c) and does not cure a standalone `:highlight clear` (Q3d). Neovim cannot tell a scheme's first default link from a user's.
  - **Pinned** by unit 15, so a later change to it is seen; MX, which cures only Q3's last step, turns it red.

## Open threads

- **The frozen RC7 pins do not catch every mutant the brief said they would.** `tests/test_plugin.lua` passes when the groups are defined at `require('aineo.report')` (M14p) or by a plain `nvim_set_hl` in `plugin/aineo.lua` (M15p). Only a `require` of a report file from `plugin/aineo.lua` turns them red (M16p). T9's own pin in `tests/test_report_colours.lua` catches M14 and M15. The records review traced the claim to the brief review's finding 13, which was written unmeasured.
- **Candidate Learnings for the adjustment pass:**
  - `:edit` on a `nofile` buffer with a `BufReadCmd` empties its text but not its extmarks, which collapse to the end of the refilled buffer. Measured by unit 5's red on 0.12.5 and by mutant M9 on both 0.11.6 and 0.12.5.
  - `nvim_set_hl(…, { default = true })` records no default link over a group that already has settings, and `:highlight default link` does. Measured by the guarantee review and the fix round's probe, on both versions.
    - But `:highlight default link` records a default link only when the group has none yet (`sg_deflink == 0` in `highlight_group.c`): the first default link wins. `nvim_set_hl(…, { default = true })`, when it applies, replaces the one there. Measured by the re-measure's Q3 and Q3b on both versions, and read in `highlight_group.c` at `v0.11.6` and `v0.12.5`.
- **The shared help's merge check with T13:** `origin/bugfix/t13-neovim-0-12` appeared during the fix round, at `84fb0e1`.
  - Merging it with this branch's fix-round head gives one tree and no conflict. T13's only help change is at `*aineo-install*`.
  - `tests/test_doc.lua` on the merged `doc/aineo.txt`: 36 cases, `Fails (0)`.
  - Whichever of T9 and T13 lands second re-runs the check against the other's head. `origin/feature/t12-claude-numbers` did not exist yet.

## Commits

*Recorded after the merge.*
