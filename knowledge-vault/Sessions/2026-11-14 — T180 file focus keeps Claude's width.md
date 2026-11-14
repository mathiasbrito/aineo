# 2026-11-14 — T180 `<C-l>` keeps Claude's width when no file column is open

**Author:** the user, with Claude — implementer agent (Sonnet 5.5)
**Branch:** `bugfix/t180-file-focus-width` (from `origin/dev` at e49d2403)

## Links

[[Projects/aineo]] — A746 and D156 as the brief holds them; D30 (small fix: the test files touched, no whole suite before a push; the orchestrator runs it).

## Why

The user, of `<C-l>` on a file in the explorer: the file takes more room than the Report and Input panel it replaces, and the Claude panel changes size; the column should keep the size of what it replaces. With the explorer in the panes column, the file should open as it does with `l`.

## Cause

`on_file_focus` (`lua/aineo/explorer/home.lua`) opened the file first, which opened the first file column and gave Claude a third of the screen, then scheduled the focus on; the focus recorded the already-shrunk Claude width. Measured at 240 wide: Claude 99 to 65, the file column 133 against the panes column's 99.

## What changed

- `home.lua`: with the focus off, `<C-l>` turns the focus on first, then opens the file; turning it off keeps its scheduled call. With the explorer handed `is_in_explorer_column` and not in the column, `<C-l>` with the focus off is `l`.
- `layout/init.lua`: `is_explorer_column_window(window)`.
- `entry/explorer.lua`: hands the explorer `is_in_explorer_column`, built from the layout; the explorer home requires no other home.
- `doc/aineo.txt` (the explorer keys, the file-focus section, the explorer pane's `<C-l>`), `README.md` (the `<C-l>` row).

## Decided

- The pane guard lives in the explorer home, fed through a setting the entry builds, not in the entry's toggle: the home already decides what `<C-l>` does per line, and `l` is its own function. A home given no such setting takes its window to be the column's, so existing callers are unchanged.
- `<C-l>` on a folder in the pane is `l` on a folder (it unfolds); the brief left it to the existing behaviour, `l` being the consistent one.
- The keys table's phrase for `<C-l>` in the explorer is not changed; the pane row shares it.

## Tests

- Red first: `tests/test_entry_file_focus.lua` `<C-l> on the first file` at 240x42 and 160x45, Claude left/explorer right and mirrored (4 cases: Claude 65 against 99, file 133 against 99 at 240x42); the two `<C-l> in the explorer pane` cases (file: the focus was on and the panes column closed; folder: not unfolded); `tests/test_layout_explorer_column.lua` two cases for `is_explorer_column_window` (the function was missing). All seen red for those reasons, green after.
- Two cases of `the explorer pane under the file focus` started the focus with `<C-l>` in the pane; they now use `:Aineo focus` and `l`.
- Files run green: `test_entry_file_focus` (46 cases), `test_layout_file_focus`, `test_entry_explorer`, `_back`, `_column`, `_look`, `_pick`, `test_doc`, `test_entry_file_beside_explorer`, `test_layout_explorer_column`, `test_keys`; `make lint` clean. The whole suite was not run (D30).

## Mutants

Each run alone from a pristine copy, on the narrowed groups of `test_entry_file_focus.lua` (14 cases), the layout one on its file.

| Mutant (literal edit) | Result |
|---|---|
| the starting branch ends with `vim.schedule(settings.toggle_file_focus)` after the open, as before the fix | killed: the 4 width cases (assertion) |
| the starting branch ends with `settings.toggle_file_focus()` after the open (not scheduled) | survived: the four width cases pass with it, so the focus still records Claude's width when called after the open in the same tick; not explained further, measured at 240x42 and 160x45, both sides |
| `if false and settings.is_in_explorer_column …` | killed: both pane cases |
| entry's `is_in_explorer_column` returns `true` | killed: both pane cases |
| layout's `is_explorer_column_window` drops `window == state.explorer_window` | killed: the layout case |
| the ending branch's `vim.schedule(settings.toggle_file_focus)` becomes `settings.toggle_file_focus()` | survived: a line this change did not write, and the ending is observed the same either way |
| a folder returns before the focus is turned on | killed: the folder case and the armed-widths case |

## Open threads

- The keys table phrase for the explorer's `<C-l>` still describes the column's behaviour.
- In the pane the focus is only turned on by `:Aineo focus`; the user may want a key.

## Commits

Recorded after the merge. At writing the branch held 5a6e49f8 (the fix, tests and docs), which is replayed under a new hash at the merge.
