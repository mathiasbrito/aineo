# 2026-11-12 — T177 find reveal and thin explorer

**Author:** the user, with Claude — implementer agent (Sonnet 5.5)
**Branch:** `bugfix/t177-find-reveal` (from `origin/dev` at 933c267d)

## Links

[[Projects/aineo]] — the brief holds the user's words (A740 for `\f`, A741 for the thin explorer) as the orchestrator gave them. Earlier work on the reveal: `47719d75`, `0fa67fd8`, `148fe965` (pre-rebase hashes on `dev`).

## A740 — `\f` does not reveal the file in the explorer

**Measured with the real snacks.nvim** (checkout at 882c996, `picker = { enabled = true }`, run in a child Neovim with the suite's isolation): from the file column, from Claude's window, and with no file column yet (snacks picks the explorer window as its main window and the layout's redirect moves the file), the file opened, the folders above unfolded, the explorer window's cursor sat on the file's line and the current window was the file's. snacks' confirm closes the picker (`WinEnter` on its main window), then `:buffer N` (`BufWinEnter`), all in one tick, so the watch ending "before snacks' BufWinEnter", a skipped window and the layout's redirect swallowing the event were each ruled out.

**The hole found:** a file already shown in a window of the tab page. snacks' confirm (`jump.reuse_win`) only enters that window; no `BufWinEnter` fires, the watch stopped without a reveal, and the explorer's cursor was never placed (the folders still unfolded through the explorer's own `BufEnter` follow). The user's exact case (nothing unfolded) was not reproduced beyond this; the candidates left are a file outside the folder the explorer shows (`follow()` returns false for a file elsewhere: Claude started below the repository's top, or the explorer showing another work) and a file git does not list.

**Fix:** `lua/aineo/entry/find_reveal.lua` — once the picker is gone (the cursor re-entered a window that existed when the search began), and two ticks later the watch is still alive (no file opened meanwhile), the file the current window shows is revealed when that window is not the one the search began in. A cancel returns to that window, so it reveals nothing.

**Decided, flagged:** the cancel case of the asynchronous picker (`reveals nothing when cancelled, though the cursor returns to a file`) modelled a cancel landing in a file window other than the origin; by events it is indistinguishable from a confirm of a shown file, and snacks never does it (its cancel sets `picker.main` to the window the picker started in). The case now returns to the origin window. The cases "cancelled from a file window" and "cancelled, whatever file is entered next" stand and kill the removal of the origin check.

## A741 — the explorer column becomes thin when the file window closes

Layout Claude | terminal pane (`\pt`) | file | explorer. Closing the file window gave Claude's column half of the width left after the explorer, but without a file column `set_column_widths()` sized no window but Claude's: with one fixed window per column Neovim took the cells Claude's column grew by from the explorer column (30 to 21), and the second pass ping-ponged the same cells. With the agent pane the right column is a stack and the cells came out of it. `set_column_widths()` now sets the right column's width too, as it does for the file column's three windows.

## Tests

`tests/test_entry_find_reveal.lua` (new case red first: the explorer's cursor stayed on the first line), `tests/test_layout_explorer_column.lua` (new case red first: the explorer was 21 cells, not 30). Whole suite not run (D30).

## Commits

Recorded after the merge.

## Open threads

- The user's own `\f` case was not reproduced: the orchestrator may ask the user for the Claude folder against the repository's top and whether the file picked was already open.
