# 2026-11-14 — T182 `q` in the explorer closes the file column

**Author:** the user, with Claude — implementer agent (Sonnet 5.5)
**Branch:** `feature/t182-explorer-q-closes-file` (from `origin/dev` at 792b3a12)

## Links

[[Projects/aineo]] — A748 and D158 as the brief holds them; D30 (small fix: the test files touched, no whole suite before a push; the orchestrator runs it).

## Why

The user: a file shown with `l` leaves the cursor in the tree, which is as expected, but the only way to close it was to move to the file column and type `:q`, which slows a quick walk through files for a look. The proposal, accepted: `q` in the explorer closes the file column.

## What changed

- `layout/init.lua`: `close_file_column()` hides the file column's windows that take files (`windows_taking_files()`, which `window_taking_files()` now takes its first from) and returns whether it did. `nvim_win_hide()` keeps the buffers loaded, and the `WinClosed` handler already puts the proportions back and, under an applied file focus, gives the panes column back, exactly as `:q` does. A file with unsaved changes in the column closes nothing and warns once at WARN level; with no file column it does nothing and says nothing.
- `explorer/home.lua`: `q` in the explorer's buffer calls `settings.close_file_column` and puts the cursor back on its window and line once the commands in flight are done, as `l` does. With no such setting `q` does nothing.
- `entry/explorer.lua`: hands the explorer a `close_file_column` that calls the layout's and, when it closed the column while the file focus is on, ends the focus through the same path `<C-l>` takes (`toggle_file_focus_of()`).
- `keys/init.lua`, `README.md`, `doc/aineo.txt`: the key in the cheatsheet and the explorer's key tables.

## Decided

- The sizing is not a new rule: closing the window is what `:q` does, and the layout's own close handler sizes the columns. Ending the focus is the focus's own end (`end_file_focus()` through `<C-l>`'s action).
- `q` is mapped in the explorer buffer whether or not a file column is open, so it never starts a macro recording there.

## Tests

- Red first: `tests/test_layout_close_file_column.lua`, `tests/test_explorer_home_close_file.lua`, and the group `q in the explorer` of `tests/test_entry_file_focus.lua`.

## Open threads

None.
