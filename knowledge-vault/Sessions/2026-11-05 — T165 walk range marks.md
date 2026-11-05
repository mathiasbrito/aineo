# 2026-11-05 — T165 walk range marks

**Author:** the repository's maintainer, with Claude — implementer agent
**Branch:** `bugfix/t165-walk-range-marks` (from `dev` at a2308216) · **Pull request:** into `dev`

T165: a walkthrough step marks the code it explains. The bands of a step stood above their lines but nothing marked the lines, so the context of a change was hard to read (the user, trying v0.2.93; A702 inside D140's row). A small fix in the user's prompt-driven waves (D30).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D140 row (A702 inside it) and the T165 row
- [[Sessions/2026-11-04 — T163 walkthrough]] — the walkthrough this builds on (A694–A701)
- `lua/aineo/explain/{ranges,walkthrough,look,kinds,init}.lua`, `lua/aineo/entry/walkthrough.lua`, `doc/aineo.txt`, `README.md`

## Task lines

- [X] T165 Mark the code a walkthrough step explains (D140, A702): `aineo.explain.ranges` marks every line from `start` to `end` of each range (the band's `▎` in the sign column, the line number in `AineoWalkNr`, a tint `AineoWalkRange`); cleared with the bands; `kinds.WALK.groups.range` and its definition in `look`; the composition root hands `end` on; help, README. Limits: the bar shows where 'signcolumn' is not `no`; no `ctermbg` tint; `\v` explanations unchanged (A702 (4)).

## Decisions (the implementer's, within A702)

1. **Where the tint is drawn.** A background set on a line wins over the one `'cursorline'` draws, measured with `nvim__inspect_cell` for both `line_hl_group` and `hl_group` + `hl_eol` on persistent extmarks (the combined attribute listed `CursorLine` then `AineoWalkRange`, the tint's colour). So the persistent extmarks carry the sign, the number group and the position, and a decoration provider (`keep_tinted()` in `ranges.lua`) adds an ephemeral `hl_group` + `hl_eol` mark to every marked row at each redraw, but the cursor row of a window that draws a cursor line (`'cursorline'` on and `'cursorlineopt'` holding `line`, `screenline` or `both`). An ephemeral `line_hl_group` draws nothing, measured.
2. **Visual and search need no care:** both are drawn over the tint (measured: the `Visual` and `Search`/`CurSearch` backgrounds show on a marked row). Diagnostics' sign (priority 10) and underline (150) win by priority.
3. **Priority 8** for the marks: above the sign a changed line shows by default in version-control plugins (6), so the bar runs unbroken over freshly changed code, and below a diagnostic's sign (10). 6 and 7 are not told apart from 8 by a case (see the mutant table).
4. **The bar needs a sign column.** With `'signcolumn'` `no` nothing shows; `auto` makes the column appear (the bands re-place themselves at the next redraw, as they do for any change of the gutter).
5. **`end` is required** in the explain home's step (`ranges[i]['end']`); the composition root passes the MCP call's `end` on, which A694 already required.
6. **The tint has no `ctermbg`:** `CursorLine`'s would equal the cursor line's on a terminal without true colour. The number group and the bar still mark the lines there.
7. **Blend 8%** (the band's is 12%): "lightly", A702 (1).

## Units, in order

1. every line from `start` to `end` is marked; 2. `AineoWalkRange` from the theme (and again on `ColorScheme`, the user's kept); 3. the number in `AineoWalkNr`; 4. the bar in the sign column; 5. next step, clear and `explain.clear` take the marks; 6. the priority below a diagnostic's marks; 7. the tint but on the cursor line (the red that moved the tint to the provider), the options that draw the cursor line, an empty line, the last line, edits above; 8. the composition root hands `end` on: marks per file, replaced by the next step, cleared by an end call, `\vq`, `\vc` and a session switch.

## Seen red

`tests/test_explain_walk.lua` (35 cases now, 26 added): marks every line of a range, from its start to its end (`Left: {}`, expected `{3,4,5,9}`); tints with the accent of DiagnosticInfo blended 8% into the background of Normal (`bg` absent); is computed again when the colour scheme changes (`bg` absent); shows the number of each marked line in the walkthrough number group; puts the gutter bar of the band in the sign column of each marked line; is marked again for the next step (`{3,4,5,9,10}` for `{9,10}`); is unmarked when the walkthrough is cleared and when the buffer is cleaned (`{3,4,5}` left); marks with a priority below the sign and the underline of a diagnostic (`false`, 4096 against 10); gives way to the cursor line where the window draws one (background `1056816`, the tint, for `16711680`). `tests/test_entry_walkthrough.lua`: marks every line of each range in the file, and takes the marks of the previous step with its bands (the step crashed in `ranges.lua:98: 'for' limit must be a number` before the composition root handed `end` on; every other case of the file failed the same way, 46 in all, until it did).

## Arrived green, and why

Look: keeps a group the user defined (nothing yet defined it; killer M20). Tint: fills the whole row of every line of a range and no other; reaches the last line; fills an empty line; follows the lines when others are inserted above them (written after the first persistent-extmark version, pinning code written ahead; killers M12, M13, M14, M19); the four options that draw the cursor line and the number-only option, and the window that draws none (pinning; M15, M16, M17, M28); gives way to a Visual selection and to a search match (green by nature: Neovim's own layering, no mutant of aineo's code changes it; the cases guard against a change of that layering or of the way the tint is drawn); the bar in the sign column on the screen (M4); the sign of priority 6 (M7c) and 10 (M7b); is gone with the walkthrough (M9). Entry: ending clears the marks, `\vq`, `\vc`, the session switch and the two refused steps keep or clear the marks as the bands (killers M9e and M25 through their assertions on the bands first).

## Mutants

Each applied to the committed file, run on the covering file, restored. All on `tests/test_explain_walk.lua` unless marked.

| # | Edit | Result |
|---|---|---|
| M1 | `ranges.lua` loop `range.start, range['end'] - 1` | killed, assertions (9 cases) |
| M2 | loop from `range.start + 1` | killed, assertions (9) |
| M3 | drop `number_hl_group` | killed, assertion (1) |
| M4 | drop `sign_text` | killed, assertions (2) and a crash in the priority case (`math.max` of nothing) |
| M5 | `sign_hl_group` the fill group | killed, assertion (1) |
| M6 | `PRIORITY = 4096` | killed, assertion (1) |
| M7 | `PRIORITY = 6` | survived, also with the other sign set first: the tie is decided for the bar |
| M7b | `PRIORITY = 10` | killed, assertions (2) |
| M7c | `PRIORITY = 5` | killed, assertion (1) |
| M7d | `PRIORITY = 7` | survived: above 6 as 8 is, equivalent for the claim made |
| M8 | `walkthrough.lua` `show()` without `ranges.clear` | killed, assertion (1) |
| M9 | `walkthrough.lua` `clear()` without `ranges.clear` | killed, assertions (3) |
| M9e | the same, on `tests/test_entry_walkthrough.lua` | killed, assertions (5) |
| M10 | cursor row test `false` | killed, assertions (5) |
| M11 | tint without `and not draws_cursor_line_at(...)` | killed, assertions (5) |
| M12 | `hl_eol = false` | killed, assertions (7) |
| M13 | `end_row = row` | killed, assertions (7) |
| M14 | `on_win` never true | killed, assertions (7) |
| M15 | `draws_cursor_line_at` without the `'cursorline'` check | killed, assertion (1) |
| M16 | drop `options == 'both'` | killed, assertions (2) |
| M17 | drop `options:find('line')` | killed, assertions (3) |
| M18 | `RANGE_BLEND = 0.12` | killed, assertions (2) |
| M19 | `is_marked` asks the next row | killed, assertions (4) |
| M20 | `look.lua` range group set with `nvim_set_hl` | killed, assertions (9) |
| M21 | `kinds.lua` group name `AineoWalkRangeX` | killed, assertions (9) |
| M22 | `doc/aineo.txt` tag `*hl-AineoWalkRangeX*`, on `tests/test_doc.lua` | killed, assertions (2) |
| M24 | `entry/walkthrough.lua` `['end'] = range.start`, on the entry file | killed, assertions (2) |
| M25 | `entry/walkthrough.lua` `clear_bands(tab)` before the checks, on the entry file | killed, assertions (10, through the bands) |
| M28 | `draws_the_line = true` | killed, assertion (1) |

## Open threads

- The marks assertions in the two refused-step cases of the entry file pin a state no marks-only mutant reaches; the bands assertions beside them kill M25.
- The 6/7 priority survivors: the tie rule of Neovim decides the equal-priority case; 8 is chosen with a margin and the cases fix 5 and 10.
- A user whose `'signcolumn'` is `no` sees the tint and the number but no bar.
- `\v` explanations unchanged (A702 (4)); the user is offered a change separately.

## Fix round (A703, A704; review of head 76fdb9b2)

Items, in the order of A704:

1. **Deleted lines took their marks onto the next line** (the reviewer's measured fix, adopted red-first): the marks carry `invalidate = true`, and the provider's `is_marked()` reads them with `details` and skips an invalid one. Seen red: "does not move onto the line after a range whose last line is deleted" (`:5delete` on range 3–5: `{tint, tint, tint}` for `{tint, tint, nil}`); "does not move onto the line after a range that is deleted whole" (`:3,5delete`: the old line 6 tinted); "leaves no bar on the line after a range that is deleted whole" (`▎` for ` ` in the sign column). "comes back with the lines when the deletion is undone" arrived green (the marks restore on undo by default); killer N3, `undo_restore = false`.
2. **Two windows, each its own cursor line** ("gives each window its own cursor line, whichever is current"): arrived green, pinning code written ahead; killer M1, `nvim_win_get_cursor(0)` (assertion). The rows are found by the line numbers each window draws and compared by mini.test's attribute letters, since the bands above lines shift the rows `screenpos()` gives.
3. **`cursorlineopt=screenline`** left as built; one sentence in the vimdoc.
4. **A line inserted inside a range stays unmarked** ("leaves a line inserted inside a range unmarked"): arrived green, a pin of what is built (the step's lines are a snapshot); no mutant of the code kills it.
6. **Records:** the `show()` helper's docstring names `end`; the vimdoc says what is built (moves with the lines, loses a deleted line's mark, none for an inserted one); the module's header says the same.

| # | Edit | Result |
|---|---|---|
| N1 | `ranges.lua` without `invalidate = true` | killed, assertions (3) |
| N2 | `is_marked()` returning true for an invalid mark (`return true`) | killed, assertions (2); the bar case survives it, since the sign is drawn by the extmark itself and only `invalidate` takes it away |
| N3 | `undo_restore = false` on the marks | killed, assertion (1) |
| M1 | `nvim_win_get_cursor(0)` in `draws_cursor_line_at()` | killed, assertion (1), the reviewer's mutant |

Final tree: `tests/test_explain_walk.lua` 41 cases, 0 fails; `tests/test_entry_walkthrough.lua` 72 cases, 0 fails (the marks code is exercised there too); `tests/test_doc.lua` 0 fails; `make lint` clean. No whole suite (D30).

## Commits

*recorded after the merge*
