# 2026-11-17 — T187 `q` in the changes pane closes the file column, and `\d` is unbound

**Author:** the user, with Claude — implementer agent (Sonnet 5.5)
**Branch:** `bugfix/t187-q-closes-file-column-in-changes` (from `origin/dev` at 839ae28b)

## Links

[[Projects/aineo]] — T182 (`q` in the explorer), D80 (`\d` closes the pane's diff), D30 (a small fix: the test files it touches).

## Why

The user, after `\E`'s `q` closed the file column: a file opened with `<S-CR>` from the `\g` pane stays open, and `q` does nothing there, so one tries to close source windows with `q`. The brief changed twice during the packet: first `q` as an alias of `\d`; then the final rule, `q` closes the whole file column (diffs and files) and the default `\d` is freed.

## What changed

- `lua/aineo/entry/file_column.lua` (new): `close(homes)` is the explorer's close path lifted out of `entry/explorer.lua` (`layout.close_file_column()`, then the file focus ended when on), and `toggle_file_focus(homes)`, which `explorer.lua` now takes from it. `explorer.lua` calls both; nothing is copied.
- `lua/aineo/entry/projects.lua`: `map_close_file_column()` maps `q`, Normal mode, `nowait`, in both buffers of the pane the tab shows (`pane_of()`) and of every project's home (`prepare_pane()`); it calls `file_column.close(tab.homes)`. With nothing open `layout.close_file_column()` does nothing and says nothing, and `q` mapped means no recording starts.
- `lua/aineo/keys/init.lua`: the `\d` / `<C-\>d` row (`diff-close`) is gone; a `changes_pane` row lists `q`. `:Aineo diff close` and `<Plug>(aineo-diff-close)` stay (they come from `ACTION_ARGUMENTS`, not from the key rows) and the action is unchanged.
- `README.md`, `doc/aineo.txt` (new tag `aineo-changes-q`): `q` listed for the pane; `\d` and `<C-\>d` removed from the key lists and prose, which now name `:Aineo diff close`.

## Tests

- `tests/test_entry_changes.lua`: new `q` group (8 cases): after `<S-CR>`, after `gf`, from the commits window, a diff shown, a diff and a file side by side, nothing open (no change, no recording, no error), a modified file kept with the warning, the mapping's buffer and description; `Diff close`: the key is unbound and the `<Plug>` stays; the former `\d` doors run `<Plug>(aineo-diff-close)` and `:Aineo diff close`.
- Key tables updated for the freed key: `test_entry_prefix`, `test_entry_terminal_keys`, `test_plugin`, `test_health`.

## Open

- `q` with nothing open does nothing. `\d`'s old notice `aineo: no diff to close` stays with `:Aineo diff close` only.
- `q` is not mapped in a diff buffer or a file buffer of the file column itself, only in the pane's two buffers.
