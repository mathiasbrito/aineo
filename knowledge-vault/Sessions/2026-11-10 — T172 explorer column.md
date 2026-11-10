# 2026-11-10 — T172 explorer column

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t172-explorer-column` (from `dev` at 0023f8ef) · **Pull request:** into `dev` (number recorded after the merge)

T172 (D148, A726, A727): the explorer as a fourth, full-height column at the far left or far right of the screen, set by `layout.explorer_column` and sized by `layout.explorer_width`, independent of the side Claude Code is on (D147); and a file opened with `\f` revealed in the explorer that shows. A regular packet of wave 21 (D26: the test files it touches while working, the whole suite once before the push).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D148 row (the user's words, A726 and A727 inside it) and the T172 row
- [[Sessions/2026-11-10 — T171 swapped layout]] — the layout this column is independent of

## What was done, and why

- **The column is a fact the layout owns.** An arrangement carries `explorer_column` (a side or `false`), `explorer_width` and the explorer's buffer, validated before anything changes. `open()` builds the column with `nvim_open_win({ split = side, win = -1 })` after the other three columns, fixes its width, and `size_columns()` takes the width and a separator out of the screen before Claude's column and the panes column share the rest by halves or thirds. The width is required whenever the column is a side, so the one default (30) lives in `aineo.config`.
- **Outermost, through a swap and any other opening.** A swap moves Claude's and the panes column to the screen's edges, which put them beyond the explorer, so it moves the explorer column last, to its own edge. Any other window that opens at an edge (Claude's, reopened) is corrected by the proportions pass, `keep_explorer_outermost()`, which reads the window tree (`columns.is_outermost()`), so it also moves the column to a side a later `setup()` names. Closing a column, moving it to the other side and resizing it are all one `open()` handing a new value.
- **`\e` never toggles.** `focus_explorer_column()` moves the cursor into the column, opening the layout (and the column, in place) only when it must, and does nothing from inside it. In the tab, `\e` with the option set focuses the column; if the layout still holds a column the setting no longer names (or none and the setting names one) it opens the layout again first so the two agree, and with the option off it is today's pane. While the column is a side the explorer pane gives way to the agent pane.
- **A file shown in the column's window goes to the file column.** The explorer opens a file with `:edit` in its own window, and the layout's redirect knew only the three roles' windows; `own_buffer_in()` now answers for the explorer column's window too.
- **A727: `\f` reveals.** `home.reveal(file)` is `follow()` plus the cursor of every window showing the explorer and a centring scroll when the line is off-screen; `follow()` now says whether it followed. The finder hands the search to third-party pickers that open the file where they like and tell no one, so `aineo.entry.find_reveal` watches the search: the next file a non-floating window of the tab page enters (other than the buffer the search began in) is revealed, two ticks later so the layout's redirect has moved it; the watch ends when the cursor is back in the window the search began in with nothing opened.

## Decisions

- **D148** (the user's, 2026-11-10), with **A726** and **A727** (the orchestrator's rulings): recorded in the plan with the user's words. The brief asked for "a D147 row"; D147 and A725 were recorded by T171 already, so the row added is D148 (the user's words quoted there are those of the explorer column).
- **The width has no default in the layout** (mine): a side without a width is an error naming `arrangement.explorer_width`.
- **Reveal by watching the search, not by asking the picker** (mine): none of the four pickers offers a uniform confirm callback.
- **`\e` reconciles the layout with the setting** (mine): the layout reads the option when it opens, so a `\e` after a `setup()` that changed it opens the layout again first, as `\o` would.

## Unit list (as sliced)

1. The arrangement's `explorer_column` and `explorer_width` validated; the column built on either side, full height, width fixed.
2. A swap and a reopened Claude column leave it outermost; a window across the screen does not span it.
3. `layout.explorer_column` and `layout.explorer_width` in the configuration.
4. Later opens close, move and resize it; `focus_explorer_column()`; the explorer pane gives way.
5. `\e` (and its twins) focuses the column; files open in the file column; new tabs, restores and a full zoom.
6. A727: `home.reveal()` and the watch of `\f`.
7. Help, README, cheatsheet.

## Evidence

Each unit was seen failing before its code. Reds: `tests/test_layout_explorer_column.lua` (16 of 18 for the build and its validation, 8 for the swap and the reopened Claude column, 6 for `focus_explorer_column()` and the closing of a column, 1 for the explorer pane giving way, 1 for building around the column), `tests/test_config.lua` (19), `tests/test_entry_explorer_column.lua` (16, among them the file replacing the explorer's window, which led to the redirect), `tests/test_explorer_home_reveal.lua` (6, the missing `reveal()`) and `tests/test_entry_find_reveal.lua` (2, no cursor moved).

Arrived green, and why: in `tests/test_layout_explorer_column.lua` the cases for a column opened, moved to the other side, resized or reopened by a later `open()` and the thirds after a swap (the proportions pass of unit 2 already did them; killed by L5, L16), the pinned `false`/not-handed cases (green by nature; killed by L17), the redirect of a file shown in the column (pinned the code of the entry unit; killed by L10); in `tests/test_entry_explorer_column.lua` the setting turned off (today's pane); in `tests/test_entry_find_reveal.lua` the unfold-for-next-time and the other-way cases (today's `follow()`, killed by H5); `follow()` leaves cursors in `tests/test_explorer_home_reveal.lua` (H5); `tests/test_layout_swap_terminal_size.lua` (6, A728, below).

Mutants, each the literal edit run on the test file that exercises the code, one at a time from a copy: layout (`tests/test_layout_explorer_column.lua`) L1 `size_columns` without the explorer's width, L3 no `winfixwidth`, L4 column never closed, L5 no `keep_explorer_outermost()` in the proportions pass, L6 swap not moving the column, L7 width not required, L8 explorer pane kept, L9 `focus_explorer_column()` never opening, L10 redirect ignoring the column's window, L11/L12 `is_outermost()` always true or on the wrong edge, L13/L14 column and width validators too loose, L15 thirds ignoring the column, L16 column never opened, L17 a `false` column not taken, L18 `explorer_column()` constant, L19 focus not moving the cursor: all killed by assertions (after L7, L9 and L10, first killed by a raised error, were given assertion-based cases). L2 (the column always created on the left) survives and is equivalent: `open()` always runs the proportions pass afterwards, which moves the column to its side. Configuration (`tests/test_config.lua`) C1-C4, entry (`tests/test_entry_explorer_column.lua`) E1-E5 (setting ignored, no reconciling, no buffer, width or column not handed): killed. Reveal (`tests/test_entry_find_reveal.lua`, `tests/test_explorer_home_reveal.lua`) R1-R9 and H1-H7: R1 no `WinEnter` stop, R2 no check of the buffer the search began in, R3 floats counting, R4 a single schedule, R5 a stop that ignores its token, R8 another tab page counting, R9 unnamed buffers counting, R6 no stop after a search that left the cursor where it began and R7 an error swallowed, H3 no cursor moved, H4 only the first window, H5 `follow()` moving the cursor, H6 the current window moved, H7 `follow()` of a file elsewhere returning true: killed, R6-R9 and H7 after a case each was added for them. H1 and H2, the explorer's own scroll block, survived: `nvim_win_set_cursor` already scrolls, so the block was removed.

A728 (a bug found in v0.2.100): measured, not reproduced. A terminal job recording `stty size` at its start and at each SIGWINCH ended at the size of its window in every run: in a headless child, in a child with a UI attached, and in a real Neovim TUI in a pty driven through `:Aineo layout swap` (a swap, a swap and back, four swaps, with a file column, the explorer column, a window across the screen, from Claude's Terminal mode). The job saw no size from the middle of a move: Neovim sizes a terminal when its window is redrawn, after the command, and a swap that ends at the size it began with sends no SIGWINCH. No code changed; `tests/test_layout_swap_terminal_size.lua` pins the contract and arrived green. What stays unmeasured: Claude Code's own drawing after the window's cells move without a size change, which only the real Claude Code shows.

Whole run on Neovim 0.12.5, on the host, on the tree pushed with `AINEO_TEST_RUN_LIMIT_MS=2400000`: 10267 cases in 320 groups, `Fails (0)`, exit 0. A first run of the same tree under a host load of 55 ended on the default 960 s limit with one failure in `tests/test_entry_sessions.lua` ("is refused while the panes follow a claimed session", a file this packet does not touch) and `tests/test_send.lua` unfinished; the rerun alone was cut short by the host, and the second whole run passed both. The touched files alone: `test_layout_explorer_column`, `test_layout_swap_terminal_size`, `test_explorer_home_reveal`, `test_config`, `test_doc`, `test_layout_side`, `test_layout_file_column`, `test_entry_explorer_column`, `test_entry_find_reveal`, `test_entry_find`, `test_entry_explorer`: all `Fails (0)`; `make lint` clean.


## Open threads

- A window across the whole width opened before a swap is absorbed by the swap (T171's `win = -1`), so the explorer column, like the others, then spans its cells; the new tests pin the order only.
- A reveal asked before the explorer's first tree read moves no cursor; the file is highlighted once it is read.
- A picker that confirms its file more than two ticks after its window closed is not revealed.
