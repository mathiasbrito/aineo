# 2026-10-20 — T109 follow only an open diff

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `bugfix/t109-follow-only-open` · **Pull request:** into `dev`

In the changes pane's files window, the diff follows the cursor only while a diff is already open in the file column; with none open, moving the cursor opens nothing. A small fix of wave 21 (D30).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D98 (the user's decision, amends D95), A529 (the orchestrator's ruling, superseding A523's clause on `\d`), T109; C15
- [[Sessions/2026-10-20 — T106 diff follows the cursor]] — the following this narrows
- `lua/aineo/changes/copy.lua` — `is_a_diff_open()`, `show_diff_following_the_cursor()`, `windows_showing_a_diff()`
- `doc/aineo.txt` — the files window's section; `README.md` — the changes pane's key table and its tour

## Task lines

- [X] T109 The diff follows the cursor only while a diff is open (C15; D98, A529, D95, D30): `show_diff_following_the_cursor()` returns unless a window of the tab page shows a diff the home showed; help and README say so — done, PR to follow

## What was done

- **The check.** `is_a_diff_open()` asks `windows_showing_a_diff()`, the function `\d` closes by, so what `\d` closes is what counts as open. `show_diff_following_the_cursor()` returns when it is false, before it reads the line under the cursor.
- **Read from the windows, not remembered.** A diff buffer stays in `shown_diffs` after `\d` or after a file replaced it in the file column; counting `shown_diffs` would keep following on (mutant 2 below).
- **The tests.** `tests/test_changes_follow.lua` pins the five behaviours; the cases that followed with no diff open now open one with `l` first. `tests/test_entry_changes.lua` pins the real `\<CR>` path in the whole layout.

## Decisions

- D98 and A529, from the user's words and the orchestrator's ruling.
- A529 is recorded inside the D98 row, as A523 is inside D95's; the plan has no separate row table for rulings.

## What arrived green, and why

- `follows once l opened a diff`: green before the change, as following was unconditional; killed by the mutant that makes the check always false.
- The entry case `leaves the file in the file column when the cursor then moves in the files window` was written after the check, to pin the real `\<CR>` path; killed by mutant 1.

## Mutants

See the pull request.

## Tests changed

Added in `tests/test_changes_follow.lua`: `draws nothing while no diff is open`, `follows once l opened a diff`, `draws nothing while the file column holds a file opened for edition`, `draws nothing when l in the commits window moved the cursor to the files window`; replaced `shows a diff again after the diff was closed` with `draws nothing after the diff was closed`. In `tests/test_entry_changes.lua`: `leaves the file in the file column when the cursor then moves in the files window`. Changed to open a diff with `l` first: `shows the diff of the file it reaches`, `leaves the cursor in the files window, on its line`, `draws only the last file of the moves within the pause`, `keeps the diff against the previous version until h chooses HEAD`, `shows nothing new on the header`, `leaves the commits window’s choice and cursor as they were`, `draws the diff once while it is shown already`, `closes its timer once the files buffer is wiped`, `shown by following the cursor moves the cursor to the files window, on the line of its file`, `stays Vim’s own in a file opened for editing`; `is told nothing while the diffs against HEAD follow the cursor` now follows from an open diff against `HEAD` to a file that is as `HEAD` has it.

## Open threads

- A diff is open when any window of the tab page shows one, not only the file column's window; with the layout the two are the same window.

## Commits

Recorded after the merge.
