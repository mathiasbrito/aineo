# 2026-11-17 — T186 a file opens on the Claude side of the panel it was picked from

**Author:** the user, with Claude — implementer agent (Sonnet 5.5)
**Branch:** `feature/t186-file-beside-picking-panel` (from `origin/dev` at 58eed31d)

## Links

[[Projects/aineo]] — A752 and D163 as the brief holds them; D30 (a regular layout packet: the test files it touches and every layout and entry file-column file; the orchestrator runs the whole suite).

## Why

The user, with the explorer column and the changes pane both in use: a file opened from the explorer appears beside it, but the same file opened from the changes pane appears between the explorer and the changes pane, on the other side of Claude Code's column from where the eye expects it; the file should open on the Claude side of the panel it was picked from, and the mirrored layout must behave the same.

## What changed

- `lua/aineo/layout/init.lua`: the layout keeps where the last pick put the file column (`state.file_beside_picker`) next to the option (`state.file_beside_explorer`). `remember_picking_panel(window, buffer)` runs before a file or a diff is shown (`show_in_file_column_keeping_cursor()` for `show_file` and `show_diff`, the window the cursor is in; `redirect()` for a file a layout window showed, the window that showed it): explorer column, beside it; a window of the panes column while the explorer column is open, between Claude's column and the panes column; anything else leaves the place alone, and with no file column open clears it, so the option says again. `wants_file_column_beside_explorer()` reads the place through `settings_put_file_column_beside_explorer()`; the existing move paths (`keep_file_column_in_place()`) carry an open file column to it. `take_file_beside_explorer()` ends the pick's place when `open()` or `set_explorer_column()` hands an option that differs from the one held, so a live `setup()` still wins and an `open()` with the same option leaves the column where the pick put it. New `M.pick_without_panel(buffer)`.
- `lua/aineo/entry/finding.lua`, `find_reveal.lua`: the finder names the file it opens to `pick_without_panel()` (the picker's own `BufWinEnter` in the watch, and the finder's own list), so `\f` leaves the file column where it is whichever window the cursor was in.
- `lua/aineo/entry/walkthrough.lua`: a step the agent shows names its buffer to `pick_without_panel()` before `show_file`.
- `README.md`, `doc/aineo.txt`: the layout prose, the file column section and the `layout.file_beside_explorer` entry.

## How the layout learns the panel

By the window, at the moment the file is shown: the cursor's window for `show_file` and `show_diff`, and the window that showed the file for `redirect()`, which is how `:edit` from the explorer, the changes pane and the run pane reach the file column. The layout classifies that window itself (`state.explorer_window`; the Report's, Input's and the run pane's windows). No caller passes a panel. Callers that open a file for the user without a panel of their own (the finder, the agent's walkthrough) say so with `pick_without_panel(buffer)`, which holds for one showing.

## Decided

- The pick's place is a layout state, not a setting: it ends when the file column closes and the next unplaced pick comes, and when a different option is handed.
- With the explorer column closed, a pick in the panes column records nothing, so the file column goes where it always went and returns beside the explorer when that opens again with the option on.
- Claude Code's own window counts as "anything else": a file opened there keeps the place.
- The finder and the walkthrough step are marked by an entry-side call, not by guessing from the window: the picker of a third-party finder opens the file in the window the search began in, which is often Input.

## Tests

- New `tests/test_layout_file_picking_panel.lua` (86 cases): the four mirrored layouts, a file and a diff, from the explorer column, the panes column and Claude's window, by `show_file`/`show_diff` and by `:edit`; an open file column moving each way keeping its window, buffer and cursor; the option when none is open and after the column closes; `open()` again with the same and with another option; `set_explorer_column()`; a swap of Claude's side; no explorer column; the explorer reopening.
- `tests/test_entry_file_beside_explorer.lua`: from Input, the explorer, Claude; `\f` from Input and from the explorer with the column on either side; `tests/test_entry_walkthrough.lua`: a step shown from Input.

## Existing tests changed

- `tests/test_layout_file_beside_explorer.lua`: four cases showed a file or a diff with the cursor where the layout opened it, in the panes column, and expected the option's place; they move the cursor to Claude's window first, a neutral opener.
- `tests/test_layout_explorer_column.lua`: `a file opened in the explorer column moves to the file column…` expected the centre; the file now lies beside the explorer column.
- `tests/test_entry_file_beside_explorer.lua`: the two `a file opened from Input … by default` cases expected beside the explorer; Input is a panes-column window, so they now expect the centre and are renamed; `restoring the layout` opens its file from Claude's window.

## Mutants

See the pull request.

## Commits

Recorded after the merge.
