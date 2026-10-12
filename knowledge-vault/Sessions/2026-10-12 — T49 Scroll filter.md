# 2026-10-12 — T49 Scroll filter

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `bugfix/t49-scroll-filter` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D47, C15, T43, T49
- Rests on: [[Sessions/2026-10-11 — T43 Changes filter]] (the commits window as a filter)

## What was done

The orchestrator's diagnosis on v0.2.23: with the cursor in another window, the mouse wheel over the changes pane's commits window scrolls it and moves its cursor, and the files window did not follow. `select_filters_from()` (`lua/aineo/changes/init.lua`) listened to `CursorMoved` on the commits buffer, which fires for the current window only; the wheel fires `WinScrolled`, with the scrolled window's id in `<amatch>`.

- `select_filters_from(buffer)` gains a `WinScrolled` autocmd: when the window that scrolled shows the commits buffer, it sets `window_moved` to that window and restarts the pause, so `select_filter_at_cursor()` reads that window's cursor. The autocmd is global (the event is not buffer-local), so it lives in its own augroup, `aineo_changes_commits_scroll`, which a commits buffer made anew replaces rather than adds to.
- `doc/aineo.txt` › *aineo-changes*: the filter follows the cursor however it moves, the wheel over the window included.
- A scroll that leaves the cursor on the same line reads nothing already: `select_filter_at_cursor()` returns when the line lists the selected filter (T43), so no second case.

## Unit list

1. With the cursor in the files window, the wheel over the commits window until its cursor is on the first commit: the files window names that commit.

## Red and green

**Seen red:** *the filter follows a scroll of the commits window made while the cursor is in the files window* — `left = "Files in: Session work"`, `right = "Files in: 316d7b7 Change a"` (the commits cursor reached line 4, the files window stayed). Green after the autocmd.

## Mutants

Run on `tests/test_changes_filter.lua` (the file the pull request modifies), each restored in the same call.

| # | Literal edit (`changes/init.lua`) | Result |
|---|---|---|
| 1 | the whole `WinScrolled` `nvim_create_autocmd` call removed | killed by assertion, 1 — the new case (`Files in: Session work` against the commit) |
| 2 | `window_moved = window` removed from its callback | killed by assertion, 1 — the new case |
| 3 | `selection_pause.restart()` removed from its callback | killed by assertion, 1 — the new case |

## Task lines

- T49 `[X]` (`bugfix/t49-scroll-filter`, into `dev`) — the commits window's filter follows a scroll made from another window: a `WinScrolled` autocmd for a window showing the commits buffer sets `window_moved` and restarts the pause (D47). The user's words: “while I scroll through the commits, the file list window do not change at all”. Small fix of the user's prompt-driven waves (D30).

## Commits

Recorded after the merge.
