# 2026-11-11 — T174 file beside explorer

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t174-file-beside-explorer` (from `dev` at 17ad67ee) · **Pull request:** into `dev` (number recorded after the merge)

T174 (D149, A730, A731; then D150, A732, D151, A733 and the review fixes): the file column opens beside the explorer column while that column is shown, by the new option `layout.file_beside_explorer`; and, folded in on the user's word during the packet, the explorer's windows show no line numbers unless `explorer.numbers` is on, and `layout.explorer_width` defaults to 40. Added after the first push, on the user's words and the review of PR #416: the default layout Claude | panes | files | explorer (`layout.explorer_column` defaults to `'right'`), the review's fixes, and `:Aineo layout mirror`. A regular packet of wave 21 (D26: the test files it touches while working, the whole suite once before the push).

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

## Added after the first push

- **A732, the default layout.** The whole suite run after the change failed 402 cases in 35 files, all of them entry-level cases counting windows or placing a file. The shared fake-claude helper (`entry.use_fake()`) now builds `vim.g.aineo` with `layout.explorer_column = false` under the settings a case hands, so those cases keep checking what they checked; `entry.use_fake_with_default_layout()` and `tests/test_entry_layout_default.lua` are for the default itself, and `test_entry_startup.lua`'s own base settings say `false` too. No test was loosened, `scripts/minimal_init.lua` is unchanged, and `make test_file` on each of the 35 files passed afterwards.
- **The review's fixes (PR #416's attack report).** (1) `size_columns()` set the explorer's, Claude's and the Report's widths and left the file column's to Neovim, which gave it 1-3 cells beside a left explorer; it sets the file column too, twice, unless the user split it into columns by hand (test_layout_side's hand-split case caught the first version). (2) `vim.wo[window].number = false` is `:set`, so the user's global numbers went off; `vim.wo[window][0]` is `:setlocal`. (3) and (4): the movers re-split the file column's windows one below another, so a vertical split became a stack; `place_columns()` now moves Claude's column, the panes column and the explorer column to the screen's edges around the file column, which stays put (a swap, the file column's moves, the move before the explorer goes and the mirror are the same pass), and `centre_file_column_windows()` is a plain if/else that leaves the explorer's window out. The reviewer's measured diffs were the leads for (1) to (3); (4) is the pass above.
- **The re-measure's fix, a split file column's widths.** A `:vsplit` in the file column lost its widths as the file column moved (40 | 39 became 67 | 1 or 1 | 67 after `\E` on, 1 | 78 or 64 | 4 after `\E` off or the option off; a mirror or swap alone kept them). The widths of the file column's parts are recorded before anything opens or moves (the first record counts, since a window opening at the screen's edge already changes them), given back in proportion by `size_file_column()` and forgotten after the sizing. 11 part-width cases were red first (turn on, turn off, option off, for four side combinations), the mirror cases arrived green; the mutants dropping each record, the proportion and the clearing are killed, and a survivor on the arrangement path has a case. A startup case now pins that the real default opens Claude | panes | explorer (`default_layout` in `test_entry_startup.lua`'s `editor_start`).
- **A733, the mirror.** `layout.set_column_sides(claude_side, explorer_side)` reaches `place_columns()` through `move_columns_to()`, so the mirror is one pass; the entry records the Claude side (`layout_side`) and the explorer side (`explorer_choice`) and hands every tab both. `explorer_choice.side_to_turn_on()` now prefers the side `\E` or a mirror last put over the setting (A733 (4)); a `setup()` that changes the setting to a side ends it, one that changes it to false keeps it (A729 (2)).

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
8. D150, A732: `layout.explorer_column` defaults to `'right'`; the suites that relied on the old default set `false` explicitly.
9. The review's fixes: the file column's width (the sizing sets it, twice); the numbers set with `vim.wo[window][0]`; one `place_columns()` pass instead of movers that re-split the file column, and the file column found with a window closed.
10. D151, A733: `:Aineo layout mirror`, `<Plug>(aineo-layout-mirror)`, the completion, the explorer side `\E` uses afterwards.

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

### After the first push

| Edit | Killed by |
|---|---|
| `set_column_widths`: drop the file column's width | 5 width cases (turn-on, with a window across the screen, after a shrink) |
| `size_columns`: one pass of `set_column_widths()` | 3 width cases (with a window across the screen, after a shrink, after a side change) |
| home: `vim.wo[window].number` / `relativenumber` instead of `[0]` | the file-from-the-column and file-from-the-pane entry cases (2) |
| `layout_column_window_nearest`: `return claude_window` (the reviewer's Mu2) | survived the first files; "does not take the Report's window ... Claude's closed" |
| centre lookup without the filter of the explorer's window | survived; "does not count the explorer column ... option off and Claude's window closed" |
| `place_columns`: drop the explorer's final move | survived; "keeps the explorer column outermost as a swap moves columns to its edge, the layout not complete" |
| `place_columns`: the inner edge not mirrored / the outer columns swapped | 11 / 11 cases |
| centre lookup without the Claude-on-the-right swap | 16 cases |
| `move_columns_to`: drop the explorer side / drop the `state.explorer_column` guard | 6 / 1 mirror cases |
| `set_column_sides`: drop `explorer_side ~= state.explorer_column` / drop `state.explorer_column ~= false` | 1 / 1 (the second survived the first file; "changes nothing for a layout with no explorer column ...") |
| actions: drop `record_side` / `layout_side.choose` / the explorer's opposite / use `set_claude_side` | 3 / 1 / 7 / 4 entry cases |
| `side_to_turn_on`: setting before the last side | the `\E` case (2) |
| `end_when_settings_changed`: keep the last side on a setting that names a side | the setup() case (2) |
| `layout.explorer_column` default `false` | the default-layout entry case |

## Open threads

- **A window across the top grows from 3 to 6 rows on `\E`** with the explorer on the right and the option on (the review's note 5): windows across the screen keep their place but not their height; the option off keeps 3, as v0.2.101. Not changed: the one-pass move of the columns did not cure it.
- The `centre_file_column_windows()` and/or pitfall the first report left open is fixed (the review measured the duplicate file column it caused).
- **The whole suite** (`AINEO_TEST_RUN_LIMIT_MS=2400000 make test`, on the tree before the records commit, host load average 10-36 from other sessions): `Fails (0)`, exit 0. The run after A732 alone had failed 402 cases in 35 files, the entry suites that relied on the old default; each passed alone once the helper set `false` explicitly.

## Commits

*Recorded after the merge.*
