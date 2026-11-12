# 2026-11-12 — T178 the explorer and `\f` follow the file across the focused work

**Author:** the user, with Claude — implementer agent (Sonnet 5.5)
**Branch:** `feature/t178-explorer-follows-file` (from `origin/dev` at 089bf49b)

## Links

[[Projects/aineo]] — D154, A742 and A744 as the brief holds them; D30 (small fix: the test files touched, no whole suite).

## Cause (A742, A744)

The explorer follows the changes pane's focused work (`lua/aineo/entry/explorer.lua`, `lua/aineo/explorer/home.lua`'s `resolve_place()`). When an agent reports a worktree, the focused view becomes that worktree and the explorer shows it. Files of Claude's folder, opened with `:e` or `\f`, were then "elsewhere" for `take_followed()`, and nothing unfolded or moved; `\f` searched Claude's folder's repository, not the folder the explorer shows.

## The user's ruling, "go with your recommendation, both parts"

1. `\f` searches the folder the explorer shows.
2. Opening a file outside the folder the explorer shows, under Claude's folder, switches the explorer back to Claude's folder and reveals the file; the changes pane keeps its view.

## What changed

- `aineo.explorer` home: `shown_folder(done)` gives the folder the explorer shows; `follow()` / `reveal()` take a file under Claude's folder, while another folder is shown, by holding the default view (`state.default_held`, part of `place_key()`, honoured by `resolve_place()`), reading the tree again and following the file there; a reveal puts the cursors of the explorer's windows on the file's line once that tree is read (`reveal_pending`, settled after the read). `follow_focused_work()` ends the hold and reads again.
- `lua/aineo/entry/explorer.lua` hands `follow_focused_work` to `watch_focused_work`, so the next change of the focused work ends the hold; `lua/aineo/entry/finding.lua` searches under `shown_folder()`.
- `doc/aineo.txt` (the explorer's current-file paragraph, the `\f` reveal sentence, the `aineo-find` entry) and `README.md` (the reveal sentence, the `\f` row).

## Decided

- The tree and the place shown stay as they were until the read ends (state.place is not switched early), since the explorer drew Claude's header over the worktree's tree for a moment otherwise; a hidden explorer switches its place at once and reads when it next shows.
- A reveal before the tree is first read still moves no cursor (as before); only a go-back with the explorer showing places the cursors.
- A gone worktree or a branch without a folder resolve as before; the hold only matters while a worktree is focused.

## Tests

`tests/test_explorer_home_back.lua` (home, fake git: 10 cases), `tests/test_entry_explorer_back.lua` (real git worktree, child Neovim: `\f` searches the worktree, the default view still searches Claude's folder, `:e` goes back with the changes pane keeping its view, `\f` reveal places the cursor, a pick ends the hold, a file outside both folders changes nothing); `tests/helpers/fake_explorer.lua` takes `focused_work`. Whole suite not run (D30).

## Commits

Recorded after the merge.
