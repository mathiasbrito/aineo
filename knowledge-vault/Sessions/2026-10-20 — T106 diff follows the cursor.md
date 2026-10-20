# 2026-10-20 — T106 diff follows the cursor

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t106-follow-diff` · **Pull request:** into `dev`

In the changes pane's files window, the middle column shows the diff of the file under the cursor as the cursor moves, with no key, and the cursor stays in the list; `<BS>` in a diff the pane shows moves back to the files window, onto that file's line. A small fix of wave 21 (D30).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D95 (the user's decision), A523 and A525 (the orchestrator's rulings, the second added to T106 mid-packet), T106; C15
- `lua/aineo/changes/copy.lua` — `follow_cursor_of()`, `show_diff_following_the_cursor()`, `is_diff_shown()`, `move_back_to_files_window()`; `lua/aineo/changes/pause.lua` (reused); `lua/aineo/entry/tab.lua` — the `show_changes_pane` setting
- `doc/aineo.txt` — the files window's section and `:Aineo diff close`; `README.md` — the changes pane's key table and its tour

## Task lines

- [X] T106 The diff follows the cursor in the changes pane's files window (C15; D95, A523, A525, A526, D30): a pause restarted by `CursorMoved` in the files buffer shows the diff of the file under the cursor through the read `l` and `h` use, in the kind `l` or `h` chose last (`l` by default), the cursor staying in the list; the pause is closed when the files buffer is wiped; `<BS>` in the pane's diff buffers moves back to the files window, onto the file's line; help and README — done, PR to follow

## What was done

- **The pause.** `follow_cursor_of(buffer)` makes one `pause.restartable()` of 120 ms for each files buffer, restarted by `CursorMoved` there and closed by `BufWipeout`. A files buffer made anew gets its own pause; the one of the wiped buffer cannot close the new one.
- **The show.** When the pause ends, `show_diff_following_the_cursor()` returns when the cursor left the files window, when the line lists no file (`pages.entry_at()`), and when a window of the tab page shows the buffer the diff would be named for (`is_diff_shown()`); otherwise it calls `show_diff_at_cursor()`, the function `l` and `h` call, with `cursor_stays`. There is no second diff path.
- **The kind.** `followed_diffed` holds the entry mapping of the kind chosen last: `l` sets `as_listed`, `h` sets `head_diff.of`, before they show. Enter does not change it.
- **`<BS>` (A525).** `remember_diff()` maps `<BS>` in each diff buffer the home shows, and only there. `move_back_to_files_window()` enters the files window and puts its cursor on the line `pages.line_of()` finds for the diff's entry key. When the tab page shows no files window it calls the session's new `show_changes_pane` setting first; the tab gives it `show_pane('changes')`, which leaves the cursor where it is, so the home does the move.

## Decisions

- D95, A523, A525, A526 (read from the user's words and the orchestrator's rulings; rows appended to the plan note).
- A526: `show_diff_at_cursor()` takes what to do with an empty diff against `HEAD` (`tell_file_is_as_head_has_it()` for Enter, `l` and `h`; `tell_nothing()` for following), not a flag.
- "Differs from the one shown" is read from the windows of the tab page, not remembered: a remembered name would stay "shown" after `\d` closed the diff, and A523 says moving shows a diff again then.
- The pause is built per files buffer, not per home: `pause.close()` is final, and the files buffer can be made anew.
- `<BS>` brings the pane back through a setting the composition root gives, not through the layout: the home has no layout (`modularity`: no edge from `aineo.changes` to `aineo.layout`).

## What arrived green, and why

- `shows nothing when the cursor left the window within the pause`, `shows nothing new on a line that lists no file` and `leaves no handler of its own once the files buffer is wiped` were green before the code: they assert an absence, which the missing feature also satisfies.
- `stays Vim's own in a file opened for editing` was green before the code for the same reason; its killer is the global `<BS>` mutant.
- `then <BS> in the diff, with the agent pane on screen, ...` (`test_entry_changes.lua`) was written after the code, to pin the wiring in `tab.lua`; its killer is the removal of `show_changes_pane = show_changes_pane`.

## Mutants

See the pull request.

## Tests changed

Added: `tests/test_changes_follow.lua` (the following and `<BS>`), one case in `tests/test_entry_changes.lua`. Changed: `tests/test_changes.lua`, `the reads leave no timer running once they have answered, while the pane shows`, which read the running timers at once and now waits for them to settle, as the 120 ms pause that a list written under the cursor starts is running then. The other files-window test files ran green unchanged.

## Open threads

- A list written under the cursor, or `l` in the commits window, moves the cursor in the files window and so shows a diff after the pause.

## Commits

Recorded after the merge.
