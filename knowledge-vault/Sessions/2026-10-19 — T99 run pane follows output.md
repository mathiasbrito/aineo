# 2026-10-19 — T99 run pane follows output

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t99-run-follow` · **Pull request:** into `dev`, opened with this note

Every window in which the run pane shows a process's terminal now starts with its cursor on the last line of the terminal's buffer and that line in view, so the window follows the output. A D30 small fix of wave 21, from the user's report of 2026-10-19 and the orchestrator's ruling A507 (D89): “the \x pannels seems not to follow the output, at least after I open it they where in the first lines.”

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D89, T99 (A507, the orchestrator's ruling)
- `lua/aineo/layout/init.lua` — `follow_output_in()`, `show_in_place()`, `open_run_window_below()`
- `tests/test_entry_run_follow.lua`
- `doc/aineo.txt` — *aineo-run*

## Task lines

- [X] T99 The run pane follows its processes' output (C2, C12; D89, A507): the layout puts the cursor of every window it shows a run terminal in afresh on the buffer's last line (`follow_output_in()`, called by `show_in_place()` for a run terminal and by `open_run_window_below()`); a window that stays open keeps its cursor; the help's *aineo-run* says each window starts at the end of its output and follows it.

## What was found

A Neovim terminal window follows new output only while its cursor is on the buffer's last line. The layout opened the run pane's windows with the cursor at the top (a new window) or gave the Report's window the view the terminal had when it left (`restore_view()`), which is no longer the end once the process printed while hidden. Two places show a run terminal in a window it was not in: `show_in_place()` (the first window, in place of the Report; the pane switch) and `open_run_window_below()` (each later window, also a window closed with `:q` that comes back). `sync_run_windows()` keeps a window that already shows its terminal, so it is untouched.

## Decisions

- **The rule lives in the layout, in one helper**, `follow_output_in(window)`, called from the two places above. The entry's `run_pane.lua` only asks the layout to show the pane, so putting the rule there would have meant a second walk over the windows the layout owns.
- **`show_in_place()` still restores the saved view first** and moves the cursor to the end after it, for a buffer in `state.run.buffers`; the saved view of a run terminal is therefore overwritten, a view of any other buffer is not.
- Rejected: moving the cursor of every window of the stack on every `sync_run_windows()`; it would take a scrolled-up window back to the end whenever the stack is shown again.

## Red and green

Seen red (each by its message, `different values at key "follows", left = false, right = true`), before the change:

- follows the output of the first process, shown by `\x`
- follows the output of a process added below, by `\x`
- follows the output of the first process when `\x` shows the stack again
- follows the output of a process below when `\x` shows the stack again
- follows the output of a process whose window `:q` closed, when `\x` brings it back

Arrived green:

- *follows the output of a shell added below, by `\X`*: green by nature, the shell takes the cursor in Terminal mode, which follows whatever the window's cursor line; it pins the user-visible behaviour, and no mutant of the helper kills it.
- *keeps the cursor of a window that stays open where the user put it*: the code before the change never moved it; killed by mutant C.

## Mutants

Each applied to a copy of `lua/aineo/layout/init.lua`, run on `tests/test_entry_run_follow.lua`, restored.

| Edit | Result |
|---|---|
| A: in `show_in_place()`, `follow_output_in(window)` replaced by `local _ = window` | killed by assertion: the first process by `\x`; the first process when `\x` shows the stack again |
| B: in `open_run_window_below()`, `follow_output_in(result)` replaced by `local _ = result` | killed by assertion: the process added below; the process below shown again; the `:q`-closed window brought back |
| C: in `sync_run_windows()`, after `state.run_windows = stack`, a loop calling `follow_output_in()` on each of `run_stack_windows()` | killed by assertion: the window that stays open keeps its cursor |

## Verification

Test files run: `test_entry_run_follow`, `test_entry_run`, `test_entry_run_tabs`, `test_entry_run_calls`, `test_entry_zoom`, `test_layout_run`, `test_layout_panes`, `test_layout_zoom`, `test_doc`, each with `Fails (0)`. `make lint` clean. No whole suite (D30).

## Commits

The `dev` hash, recorded after the merge (PR #287, merged by rebase): `f89866f`. Released in v0.2.60 (PR #289, `main` `77a3860`).

## Open threads

- A window the user scrolled up in Normal mode, then hid and showed again, starts at the end again: the help says each window starts at the end of its output.
