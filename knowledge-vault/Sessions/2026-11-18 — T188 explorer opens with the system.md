# 2026-11-18 — T188 `<M-l>` in the explorer opens the entry with the operating system

**Author:** the user, with Claude — implementer agent (Sonnet 5.5)
**Branch:** `feature/t188-explorer-open-with-system` (from `origin/dev` at 1423dbbb)

## Links

[[Projects/aineo]] — D92 (the explorer), D30 (a small fix: the test files it touches).

## Why

The user asked for a key in the explorer that opens the entry under the cursor with the operating system's default application, instead of in Neovim.

## What changed

- `lua/aineo/explorer/home.lua`: a new setting `open_with_system(path)` and a Normal-mode key `<M-l>` in the tree's buffer. It hands the absolute path of the entry under the cursor (a file or a folder) to the setting; nothing happens on a line with no entry or when no handler was given. The file column, the layout and the cursor are untouched.
- `lua/aineo/entry/links.lua`: `open_with_system()` (which tells the user, once, when `vim.ui.open()` fails) is now exported as `M.open_with_system()`, and its other callers use it.
- `lua/aineo/entry/explorer.lua`: hands `links.open_with_system` to the explorer, as `open_file` is handed.
- `lua/aineo/keys/init.lua`, `README.md`, `doc/aineo.txt`: the key is listed (an `explorer_pane` row, which feeds the cheatsheet).

`<M-l>` was not mapped anywhere in the plugin before: no conflict.

## Tests

- `tests/test_explorer_home_open_with_system.lua` (6 cases): a file's absolute path, no file opened and the cursor kept, a folder's path, a non-entry line, no handler, the mapping's description.
- `tests/test_entry_explorer_open_with_system.lua` (3 cases, a real layout, `vim.ui.open` stubbed): file (no file column, the cursor in the tree), folder, and the one-time notice when `vim.ui.open` fails.
- `tests/helpers/fake_explorer.lua`: passes `open_file` and `open_with_system` from the world.
- Mutants, both killed: the key's lhs changed (3 of 6 fail in the home file); the hand-over in `entry/explorer.lua` removed (3 of 3 fail in the entry file).

## Open

- `<M-l>` is mapped in the explorer's buffer only, so it works in both the column and the pane. A terminal that sends Alt as an escape prefix may need Neovim's usual `<M-…>` handling; nothing was changed for it.
