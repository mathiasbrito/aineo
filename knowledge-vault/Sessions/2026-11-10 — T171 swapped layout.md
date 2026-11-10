# 2026-11-10 — T171 swapped layout

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t171-swapped-layout` (from `dev` at 33cb1e0c) · **Pull request:** into `dev` (number recorded after the merge)

T171 (D147, A725): a second layout that mirrors today's, Claude Code's terminal on the right, the panes column on the left and the file column between, set by `layout.claude_side` and swapped live by `:Aineo layout swap|left|right`. A regular packet of wave 21 (D26: the test files it touches while working, the whole suite once before the push).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D147 row (the user's words, A725 inside it) and the T171 row

## What was done, and why

- **The side is one fact the layout owns.** `aineo.layout` keeps `claude_side` in each layout's state (`claude_side()`, `set_claude_side()`, the arrangement's `claude_side`); every split that put a window at the left or right edge now asks for Claude's edge or the panes column's edge, and the file column is found between the two whichever way they lie (`file_column_windows()`). `aineo.layout.side` names the two sides and their opposite.
- **A swap moves windows with `nvim_win_set_config`.** Claude's column goes to its edge, the panes column to the opposite one, window by window, each below the one before it. The windows keep their IDs, so the terminal job, Input's draft, every buffer, the cursors and the current window stay. The move runs inside `nvim_win_call`, which makes a tab page that is not shown move too without a `TabEnter` (measured on Neovim 0.12.5: `win = -1` otherwise resolves against the current tab page and moves the window into it). A zoom ends first and is not restored; the layout's proportions are put back after the move, which mirrors the widths (a third each with a file column, otherwise Claude half).
- **The session's choice is the composition root's.** `aineo.entry.layout_side` holds the side the user chose (nil until then, else `layout.claude_side`) and every tab's arrangement carries it, so a tab opened later, a restore (`\o`, `\r`, `\i`, `\c`) and a reopened window land on it; an `open()` that names the other side moves a layout that is open. `:Aineo layout swap|left|right` choose it and call `set_claude_side()` on every bound tab's layout.
- **The clients of the panes column follow by construction.** The office and the cheatsheet cover `right_column_area()`, a rectangle read from the windows' positions, so they were side-neutral already; their user-visible words, the help and the README now say "panes column". Files and diffs go to the file column through `show_file()`/`show_diff()`/the redirect, found between the columns.

## Decisions

- **D147** (the user's, 2026-11-10), with **A725** (the orchestrator's rulings): recorded in the plan with the user's words.
- **The session's side lives in `aineo.entry`, not in a layout module-level variable** (mine): a module-level override inside `aineo.layout` would leak between the layouts a test makes; the composition root already owns session state and hands the layout what it needs, as it does `report_height`.
- **`aineo.layout` exposes `opposite_side()`** (mine), so the entry layer does not import `aineo.layout.side` (a deep import).
- **The identifiers `right_side`, `right_column_area` and `NO_RIGHT_SIDE` keep their names** (mine): they are the panes column's area in every case; renaming them touches the office and cheatsheet options and their tests. Reported as a follow-up.

## Unit list (as sliced)

1. `layout.claude_side` validated; the layout built on either side, widths mirrored.
2. `set_claude_side()` and the arrangement's side move a built layout; `:Aineo layout swap|left|right` and the `<Plug>` mappings through the entry.
3. The clients of the panes column on the swapped side (file column, area, panes, zoom, office, cheatsheet).
4. Restore and new tabs on the current side.
5. Help, README, the plan's rows.

## Evidence

Each unit was seen failing before its code: `tests/test_config.lua` (12 cases red, then green), `tests/test_layout_side.lua` (3 red for the build, 16 for the move) and `tests/test_entry_layout_side.lua` (17 red for the commands). The cases for the clients of the panes column (unit 3) pass on the code of units 1 and 2, whose consequence they pin (the area, the redirect and the reopened windows ask the side already); each was seen failing only under the mutants below.

Mutants (23), each run on the test file that exercises the code it breaks (`tests/test_layout_side.lua`, `tests/test_entry_layout_side.lua`, `tests/test_config.lua`), and all killed: the file column ignoring the side; Input's, Claude's, the Report's and Input's reopened window always on the default edge; the file column opened on the wrong side of Claude's window, or at the wrong edge with Claude's window closed; a zoom not ended by a move; the move without `nvim_win_call`; `open()` not moving an open layout; the arrangement's side not validated; the panes column, or Claude's, not moved; the proportions not put back; the windows below the first not stacked; `set_claude_side()` going to the wrong side; the arrangement carrying no side; the swap going nowhere; the choice not recorded; only the first tab moving; the setting's default flipped; the setting's validator accepting anything. One survived at first, Input reopened at the edge when the Report's window is closed under a terminal pane that gives way; a case was added and killed it.

The whole run on Neovim 0.12.5, on the host, under a load of 10 to 24 from other work: the first, with the default 960 s limit, ended on the limit with four failures: two of `tests/test_entry_panes.lua` (the completion list lacked `layout`: fixed), `tests/test_entry_explorer_pick.lua` and `tests/test_entry_run_follow.lua`, which passed alone, and `tests/test_send.lua`, which had not finished and passed alone. The second, on the tree pushed with `AINEO_TEST_RUN_LIMIT_MS=2400000`, ran 10152 cases in 315 groups and failed one, `tests/test_office_scene_live_cost.lua` ("of the largest office ... is cheap", a cost bound on the scene's picture, a file this packet does not touch), which passed alone.

## Open threads

- Rename `right_side` (the office's and the cheatsheet's option), `NO_RIGHT_SIDE` and `right_column_area()` to the panes column's names; they are side-neutral in behaviour and still say "right" in name.
- A window across the whole width (`:botright split`) lies below the columns: a swap puts the columns on the screen's edges (`win = -1`), as a restore already does, so such a window no longer spans the moved column's cells.
- T172 (the always-visible explorer column) is independent of this side and not started.
