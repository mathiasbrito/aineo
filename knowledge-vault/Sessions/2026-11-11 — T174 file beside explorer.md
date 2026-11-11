# 2026-11-11 — T174 file beside explorer

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t174-file-beside-explorer` (from `dev` at 17ad67ee) · **Pull request:** into `dev` (number recorded after the merge)

T174 (D149, A730, A731): the file column opens beside the explorer column while that column is shown, by the new option `layout.file_beside_explorer`; and, folded in on the user's word during the packet, the explorer's windows show no line numbers unless `explorer.numbers` is on, and `layout.explorer_width` defaults to 40. A regular packet of wave 21 (D26: the test files it touches while working, the whole suite once before the push).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D149 row (the user's words, A730 and A731 inside it) and the T174 row
- [[Sessions/2026-11-10 — T172 explorer column]] — the column this packet builds on
- [[Sessions/2026-11-10 — T171 swapped layout]] — the swap that keeps the file column beside the explorer

## What was done, and why

- **The file column's place is a fact the layout owns.** `aineo.layout` reads `file_beside_explorer` from the arrangement (validated; kept when an arrangement hands none; false before any, so callers that never hand it keep v0.2.101's places) and `set_explorer_column()` takes it as a third argument. `file_column_windows()` looks in the place the file column belongs, beside the explorer column or between Claude's column and the right one, and falls back to the other place while the column has not moved there, so no client ever opens a second file column. Every client (`show_file`, `show_diff`, the redirect, `\f`, Enter, `l`, a reopen, `\o`) reaches the file column through that one lookup; none computes the place.
- **Moving is the windows' move only.** `keep_file_column_in_place()` runs in the proportions pass, next to `keep_explorer_outermost()`: it moves the file column to the explorer's inner side (to the screen edge on the explorer's side, the explorer column moving to the edge again beyond it) or back between Claude's column and the right one, with `nvim_win_set_config` as a swap does, so buffers, splits, cursors and the current window stay. A swap needs no code of its own: it puts the file column between the moved columns and the pass puts it back beside the explorer.
- **Before the explorer goes.** The file column is found by its neighbour, the explorer column, so a change that removes or moves that neighbour (`\E` off, a side change, the option off, an `open()` that hands another column) first moves the file column to the centre (`leave_explorer_when_settings_change()`), after a zoom has ended.
- **A column closed by hand** sends the file column to the centre on the next pass; the explorer opening again brings it beside. The beside lookup works from the screen's edge when the explorer's window is gone.
- **Entry.** Every arrangement carries the setting, and the live `setup()` / `\E` path passes it to `set_explorer_column()`.
- **A731 (on the user's word, mid-packet).** `explorer.numbers` (default false) and the explorer home turning `number` and `relativenumber` off, window-locally, in each window the explorer's buffer enters (BufWinEnter), unless it is on; the sign and fold columns are untouched. `look.ALL_ON` became `look.DEFAULT`, since the numbers look is off. `layout.explorer_width` defaults to 40.

## Decisions

- **D149** (the user's, 2026-11-11), with **A730** and **A731** (the orchestrator's rulings): recorded in the plan with the user's words.
- **The layout's own default is false** (mine): the setting's default, true, lives in `aineo.config`; layouts built without it keep the centre, so the layout suites that predate it stay valid.
- **A closed Claude window** (mine): with Claude's window closed the centre and the beside places coincide at the edge, so the move back to the centre is skipped and the lookup finds the column in either place.

## Unit list (as sliced)

1. `layout.file_beside_explorer` validated, default true (config, help tag).
2. A file column built with the layout or shown later lands beside the explorer column, on both explorer sides and both Claude sides; with the option false, or no column, in the centre.
3. `\E` on/off, a live `setup()`, a side change and an arrangement move an existing file column, keeping its buffers, splits, cursors and the current window.
4. A swap keeps it beside; a window across the screen keeps its place.
5. Clients find it in its new place (`\f`, Enter, the redirect, `show_file`, `show_diff`, a reopen, `\o`).
6. Help, README picture and table.
7. A731: `explorer.numbers`, numbers off in the explorer's windows, width 40.

## Red, and green by design

Seen red: the two config tests and the two doc tags (units 1, 7); nine layout tests of unit 2 (the four built, four shown, one validation); nine of unit 3 (the four turn-off cases, the two option cases, the side case, the two-window case and the validation case; the two-window case was red for a harness error in the test, fixed in the same step as the implementation, so it was not seen red for its intended reason); the six entry tests of unit 5 (the Input, `\f`, `\E`, `setup()` and `\o` cases) and the explorer-column Enter test whose expectation changed; the explorer-home numbers tests; the three default-width tests. Arrived green, by the shared design: the option-off, no-option and no-column cases (current behaviour pinned), the turn-on, swap, closed-by-hand and the client cases at the layout level (the single lookup and the proportions pass do them), the entry `\E` current-window case, the numbers-kept and sign-column cases (current behaviour pinned). Their killers are in the mutant table.

## Mutants

Applied one at a time to a copy, each against the test file that exercises it (all exit 2, killed by assertions, no Lua error among them):

| Edit | Killed by |
|---|---|
| `wants_file_column_beside_explorer`: drop `state.file_beside_explorer and` | option-off layout cases (15) |
| open_file_column: `side.opposite(state.explorer_column)` → `state.explorer_column` | survived the first file; `with the layout not complete`, a file column opens beside the explorer all the same |
| drop `keep_file_column_in_place()` from `apply_proportions()` | 22 cases (built, turn-on, swap) |
| drop `leave_explorer_when_settings_change` from `set_explorer_column()` | five turn-off and side cases |
| `move_file_column_to_centre`: `right_column_edge()` → `claude_edge()` | eight cases |
| `file_column_windows()`: `return windows` for the fallback | survived the first file; `with the layout not complete`, a file column in the centre is reused |
| `file_column_leaves_explorer`: drop `explorer_column ~= state.explorer_column` | five cases |
| `take_arrangement`: set the option from `== true` when none is handed | the keeps-the-option case |
| `move_file_column_beside_explorer`: drop the second `move_column` (explorer to the edge again) | 27 cases |
| drop `leave_explorer_when_settings_change` from `M.open()` | survived the first file; the two arrangement cases |
| `changes_the_column`: drop the option clause | the two option cases |
| tab arrangement: drop `file_beside_explorer` | four entry cases |
| `explorer_column.apply_to`: pass `nil` for the option | the entry `setup()` case |
| home: drop the `numbers` guard / `relativenumber` / `number` / the BufWinEnter call / add `signcolumn` | home cases (1 / 2 / 2 / 2 / 1); the BufWinEnter call also by both entry cases |
| config: `explorer.numbers` default true; `layout.explorer_width` default 30; `layout.file_beside_explorer` default false; `look.DEFAULT.numbers` true | 13 / 6 / 6 / 2 cases |

## Open threads

- `centre_file_column_windows()` keeps `left = claude_is_left and claude_window or right_column_window()`, which with Claude's window closed and Claude on the left reads the right column twice; the packet did not touch it (the beside lookup and the lookup's fallback cover the case).
- **The whole suite** (`make test`, on the tree pushed, host load average 12–18 from other sessions): `Fails (0)` over every file that finished, and the run ended at its 960 s limit with `tests/test_send.lua` and `tests/test_send_selection.lua` (neither touched) still running. Rerun alone, each passed (`make test_file`, `Fails (0)`, exit 0). A run on a quieter host is the orchestrator's to make.

## Commits

*Recorded after the merge.*
