# 2026-10-16 — T83 Tab names whole

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t83-tab-names-whole` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D69, D71, D73, D78, D26, D29
- [[Implementation/Waves/00018-scope-filter/plan]] › *The name cut* (O20–O23, A412–A415)
- [[Implementation/Waves/00018-scope-filter/brief-t83-tab-names-whole]]

A regular packet (O23 (a)), measured on Neovim 0.12.5.

## The user's words (2026-10-16)

D78: "aineo should do that only if there is no horizontal space enough" — a tab's name is cut only when the line has no room for the names whole. The cap, the floor and what `tab_title()` gives are the orchestrator's assumptions (O20–O23, A412–A415; and, in the fix round, A420–A421), not the user's decisions.

## Task lines

- [X] T83 A tab's name whole while the tab line has room (C1; D78) — done on `feature/t83-tab-names-whole`: `tabs/tabline.lua` draws every title whole while all fit `'columns'`, else cuts every name wider than one shared cap to it (the widest cap at which the line fits, found by bisection), never below `titles.SHORTEST_CUT_CELLS` (8), and below the floor draws the run around the current tab; a line entry carries `number`, `name`, `indicator` and `current`; `titles.cut(name, cap)`, `titles.title_of()`; `tabs.title()` and `require('aineo').tab_title()` give the name whole; help `*aineo-tabs*`, `*aineo-tab_title*` and `*aineo-config-tabs.padding*`; reviews and the pull request's merge are open.

## What changed

- `lua/aineo/tabs/titles.lua`: `MAX_NAME_CELLS` gone; `SHORTEST_CUT_CELLS = 8`; `cut(name, cap)`; `title_of(number, name, indicator)`, the one place that knows the shape `<number>: <name>[ <indicator>]`.
- `lua/aineo/tabs/tabline.lua`: `TabLineEntry` holds the parts of a title; `cap_that_fits()` returns `math.huge` when the whole titles fit, else the widest cap in [8, widest name] at which they fit, else 8; `format()` cuts to that cap and draws the run around the current tab as before.
- `lua/aineo/tabs/init.lua`: `title()` gives the name whole; `tabline()` hands the format the parts of each title.
- `lua/aineo/init.lua`: `tab_title()`'s docstring only.
- `doc/aineo.txt`: `*aineo-tabs*` (the cut replaced by the fit), `*aineo-tab_title*` (the name whole), and `*aineo-config-tabs.padding*` — outside the brief's list, declared: its sentence that overflowing titles are drawn as a run of whole titles was no longer the first resort.
- `README.md`: checked, says no cut; unchanged.

## Cases (red first)

Measured red against `dev`'s `lua/` (`55fd4f7`) with the new tests: 25 of 126 cases of `tests/test_tabs.lua` and 2 of 43 of `tests/test_tabs_activity.lua` failed with the message of the old cut (a name cut to 23 cells and `…` where the name or a wider cut was expected).

- `test_tabs.lua`, red: `title()` gives a name whole (6 of 7 parameters; the 24-cell name arrived green, spent by the old rule); gives the tail of a buffer name whole; `tabline()` draws every name whole while all fit, per current tab (3); whole when the titles fill the line exactly (111); cuts the names to one cap, per current tab (3); cuts when the titles overflow by one cell (110); gives the room a short name leaves to the long one; counts the padding (3); counts the indicator; counts the ellipsis as `'ambiwidth'` gives it; cuts no name below 8 cells and draws the run (3); cuts to 8 cells when that lets all fit (45).
- `test_tabs_activity.lua`, red: the indicator after the whole name of a long name; `tab_title()` says what `title()` says for a long name, whole.
- Arrived green: the character cuts on the line (multibyte, wide on a character's edge, decomposed accent, family emoji, the buffer name's tail) and a name shorter than 8 cells never padded or cut (3 widths) — pre-existing behaviour moved to the line, spent by `cut()`'s old body; killers: the mutants `cap_that_fits` returning 0 and the `<`-for-`<=` fit, both below.
- Pins moved: the 24-cell `title()` cases (215–245) and the three character cases (807–816) of `test_tabs.lua` went to the line at 31 columns, where the cap is 24; the 80-column cases over three long names (720–800) went to the new rule, and *counts the padding in the width of the titles it fits* keeps its name with its parameters now the padding and the line drawn; the activity case at 223 became a whole name.

## Mutants (literal edits; each killed by an assertion)

Run on the final tree (after the fix round), `tests/test_tabs.lua` of 131 cases and `tests/test_tabs_activity.lua` of 43.

| Edit | Killed by |
|---|---|
| `tabline.lua`: `titles_cut_to(entries, cap_that_fits(entries, columns, padding))` → `titles_cut_to(entries, 24)` (mutant 1) | `test_tabs.lua` (22), among them *draws every name whole while all the titles fit* |
| `tabline.lua`: `width_of_all(titles_cut_to(entries, cap), padding) <= columns` → `width_of_all(titles_cut_to(entries, cap), 0) <= columns` (mutant 2) | `test_tabs.lua` (16), among them *counts the padding in the width of the titles it fits* |
| `tabline.lua`: `local drawn = titles_cut_to(entries, cap_that_fits(entries, columns, padding))` → `local without_indicator = vim.tbl_map(function(e) return vim.tbl_extend('force', e, { indicator = false }) end, entries)` then `local drawn = titles_cut_to(entries, cap_that_fits(without_indicator, columns, padding))` (mutant 3) | `test_tabs.lua` (1) *counts the indicator in the width of the titles and never cuts it* |
| `tabline.lua`: `cap_that_fits` first statement `do return math.floor(columns / #entries) - 2 * padding - 3 end` (mutant 4) | `test_tabs.lua` (5): *gives the room a short name leaves to the long one*, *counts the indicator*, and the three floor-run cases |
| `tabs/init.lua`: `return titles.title_of(number, name_of_tab(tab), activities.indicator(tab, animation.glyph()))` → `return titles.title_of(number, titles.cut(name_of_tab(tab), 24), activities.indicator(tab, animation.glyph()))` (mutant 5) | `test_tabs_activity.lua` (2) |
| `titles.lua`: `SHORTEST_CUT_CELLS = 8` → `7` | `test_tabs.lua` (3) the floor-run cases (first commit's tree) |
| `titles.lua`: `SHORTEST_CUT_CELLS = 8` → `9` | `test_tabs.lua` (4) the floor-run cases and *cuts the names to 8 cells* (first commit's tree) |
| `tabline.lua`: `<= columns` → `< columns` | `test_tabs.lua` (6), among them *fill the line exactly* (first commit's tree) |
| `tabline.lua`: `if not fits(fitting) then return fitting` → `return math.huge` | `test_tabs.lua` (3) the floor-run cases (first commit's tree) |
| `tabline.lua`: `if fits(math.huge) then return math.huge` → `return 0` | `test_tabs.lua` (17), among them *never pads or cuts a name shorter than 8 cells* (first commit's tree) |
| `titles.lua`, in `cut()`: `if vim.api.nvim_strwidth(name) <= cap then` → `if vim.fn.strdisplaywidth(name) <= cap then` | `test_tabs.lua` (2) the wide-character and `'linebreak'` narrow-window cases |
| `titles.lua`, in `cut()`: `<= cap` → `< cap` | `test_tabs.lua` (3), among them *draws a name as wide as the cap whole* |
| `titles.lua`, in `longest_prefix_within()`: `vim.api.nvim_strwidth(vim.fn.strcharpart(text, 0, middle, 1)) <= room` → `vim.fn.strdisplaywidth(…) <= room` | `test_tabs.lua` (1) *cuts wide characters on the same edge in a narrow current window* |
| `tabs/init.lua`, in `tabline()`: `name = vim.fn.strtrans(name_of_tab(tab)),` → `name = name_of_tab(tab),` | `test_tabs.lua` (1) *keeps the line within the screen for names with a control character* |
| `tabline.lua`, in `cap_that_fits()`: `math.max(overflowing, vim.api.nvim_strwidth(entry.name))` → `math.max(overflowing, vim.fn.strdisplaywidth(entry.name))` | survived, equivalent: a bound above the widest name changes nothing, since no cap above it fits when the whole titles do not, and no window makes `strdisplaywidth()` smaller than `nvim_strwidth()` of a `strtrans()`ed name |

## Fix round (the reviews of PR #248)

Rulings are the orchestrator's assumptions, not the user's decisions.

- **A420 (attack 1).** Names are measured with `vim.api.nvim_strwidth()` in `titles.cut()`, `longest_prefix_within()` and the fit's search bound, never `vim.fn.strdisplaywidth()`, which follows the current window (its width, `'linebreak'`, `'showbreak'`). Red first: *cuts the same in a narrow current window with wide characters* and *… with 'linebreak' set* (the attack's probes), with the cursor in a 30-cell window; and *cuts wide characters on the same edge in a narrow current window*, which pins the prefix measure.
- **A421 (attack 2).** `tabline()` passes each name through `vim.fn.strtrans()`, so a control character is counted as the `^X` it is drawn as. Red first: *keeps the line within the screen for names with a control character*, which drew a leading `<`. `title()` and `tab_title()` stay whole and untouched.
- **Attack 3.** *aineo-tabs* says a wide character that would cross the edge is left out, so a cut name may take a cell less than the width, the floor included.
- **Tests review 1.** *draws a name as wide as the cap whole* (20, 40 and 40 cells at 81 columns, padding 2); it arrived green and kills `<= cap` → `< cap` in `cut()`.
- **Tests review 2.** The subject of the pushed commit `edc237c` is 73 characters, over the 72 the root `CLAUDE.md` asks for. It is not reworded, because pushed history is not rewritten; the other subjects are under 72.
- **Tests review 3, 4, 6.** The mutant table above is re-run on the final tree, mutants 3 and 5 are written as literal edits, and the cell that is not from the final tree says so. A415 is the orchestrator's assumption too.
- Attack 5 (cost): no change.

## Suites

- After the fix round: `tests/test_tabs.lua` 131 cases (107 on `dev`; 126 in the first round), `tests/test_tabs_activity.lua` 43 (42 on `dev`); `make lint` 0 errors, 0 warnings.
- The whole suite once, on the tree pushed, Neovim 0.12.5, with `AINEO_TEST_JOBS=4 AINEO_TEST_RUN_LIMIT_MS=2700000` because the host's load average was about 18: 4162 cases in 106 files, `Fails (0) and Notes (0)` on the first round's tree; 4167 cases in 106 files, `Fails (0) and Notes (0)`, on the tree after the fix round, under the same settings.

## Decisions

- The fit's one floor lives in `titles.lua` as `SHORTEST_CUT_CELLS`; `cut()` first clamped a smaller cap to it, and the clamp was removed because the fit never passes one and no test could reach it.
- `tabline.lua` requires `aineo.tabs.titles`: an edge inside the `tabs` home, not between homes. §1's deep-require check prints no line from outside a home for the files this change touches.

## Open threads

- The fit calls `titles.cut()` for every name that is wider than the cap, about log2(widest name) + 2 times per redraw; it runs at every redraw, the animation's twice a second included. Not measured on a long tab list.

## Commits

*Recorded after the merge.*
