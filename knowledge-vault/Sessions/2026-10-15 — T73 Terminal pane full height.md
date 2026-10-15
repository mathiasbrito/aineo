# 2026-10-15 — T73 Terminal pane full height

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t73-terminal-full-height` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D18, D30, **D68**, C2, C12
- [[Sessions/2026-10-15 — T69 Terminal pane]] (the layout's third pane, the shell's end and wipe), [[Sessions/2026-10-15 — T70 Terminal pane key]] (the key and the help)

A small fix in the user's prompt-driven waves (D30), after wave 16: the terminal pane shows the shell alone over the whole right column. Measured on Neovim 0.12.5.

## The user's words (2026-10-15, verbatim)

"I opened the terminal and it occupied the space of the report window, the input window was kept below it, ideally it should take the whole vertical space, as we do with the git panels, the two replaces the two from the agent view (report, insert), the terminal has to take the whole space, every \p* command must occupy the entire vertical space of the right side."

The user's decision, for the knowledge pass to number: every pane takes the whole height of the right column; the terminal pane shows the shell alone, with no Input below it. It supersedes the wave 16 plan's item 1, "in the Report's window, over Input, which stays", which was the orchestrator's ruling, never the user's (D68 itself said "in place of the agent pane").

## Task lines

- [X] T73 The terminal pane takes the whole right column (D68; the user's words above) — done on `feature/t73-terminal-full-height`: under the terminal pane the layout closes Input's window and the Report's window, showing the shell, takes the column's whole height; the agent pane and the changes pane open Input's window again below the Report's, at `layout.report_height`, with Input's cursor and top line as they were; `\i` shows the agent pane first, as `\r` does.

## What was built

**The shape chosen**: one window, the Report's, takes the column; Input's window is closed while the pane shows and opened again below the Report's when the agent or the changes pane shows. Measured against the alternative of keeping three windows and giving Input none of the rows: a window cannot be given zero rows (`'winminheight'` is global), and a window that stays open and shows nothing is what the user's "the terminal has to take the whole space" rules out. The windows the changes pane replaces are two for two; the terminal pane replaces two with one, so a window has to go.

`lua/aineo/layout/init.lua`:

- `PANE_BUFFERS.terminal` has the Report's role only; `pane_roles(pane)` lists the roles a pane shows, and every loop over the right column's windows (`show_buffers_of()`, `shows_a_buffer_of_another_pane()`, `can_show_in_place()`, …) walks those of the pane.
- `switch_input_window(from, to)`, called by `switch_pane()` before the buffers are shown, so that each window is at its final size when its buffer comes back with its saved view: `close_input_window()` keeps the view of the buffer Input's window shows (`state.views`) and closes it; `open_input_window()` splits below the Report's window (or opens the rightmost column when the Report's is closed), pins it, puts the proportions back, then restores the view. A switch that fails undoes the window change (`pcall(switch_input_window, pane, shown)`) before the buffers are given back.
- `is_open()` asks for Claude's window and the windows of the pane shown; `apply_proportions()` sizes the Report's share only when Input's window exists; `pin_windows()` and `show_buffers()` walk the windows that exist; `reopen_closed_windows()` and `build()` leave Input's window closed under the terminal pane.
- `reopen_agent_pane()` (the shell's wipe) and the `TermClose` path (`switch_pane('agent')`) open Input's window again.
- `must_open_to_focus()` treats Input's window closed by the pane as there; `focus_shows_agent_pane()` is true for the Report and Input, so `\i` shows the agent pane, then moves the cursor to Input — `\r` and `\i` now act alike (A347).

`doc/aineo.txt`: the layout section, *Panes* (the terminal pane's paragraph, `\r` and `\i`, the shell's end, Send), and a limit line. `plugin/aineo.lua` is untouched: `\i` is `focus('input')`, which the layout routes.

## Rulings made in the packet (the orchestrator's assumptions A345–A348, applied)

- **A345** back to the agent pane (`\pa`, `\g`, `\r`, `\i`, the shell's end, a tab close): Input's window comes back below the Report's at `layout.report_height`, showing its own buffer with its draft and its cursor line and top line. The window is a new one (a new window ID); Claude's and the Report's windows keep theirs.
- **A346** the shell's end reopens Input's window — the terminal pane hid it, the user did not close it. An Input window the user had closed *before* the terminal pane showed stays closed as the shell ends (`state.input_closed_by_user`, noted as the pane takes the column and consumed as it gives way); asking for the agent pane (`\pa`, `\g`, `\i`) opens it, as every pane switch opened a closed window before. A Report window the user closed stays closed, as in T69 (A312).
- **A347** `\i` / `<C-\>i` under the terminal pane: the agent pane shows, the cursor is in Input. If Input's buffer or the Report is gone, the layout opens first, as under the changes pane.
- **A348** every pane fills the column: the entry suite pins it for `\g`, `\pa` and `\pt` (the column's windows end where Claude's does).

## Spec conflicts

None.

## Cases (red first)

`tests/test_layout_terminal_pane.lua` (70 cases at the end; the file had 61) and `tests/test_entry_terminal_pane.lua` (+4 cases).

**Seen red** (the window count was 3, not 2): `shows the shell alone in the right column, as tall as Claude's window, and Input in no window`; `leaving the terminal pane` × 3 — the agent pane again at its proportion with the draft and cursor kept, the changes pane in two windows that fill the column, the shell's end with both windows back — each after `eq(layout.window_count(child), 2)` under the terminal pane.

**Arrived green, each with its mutant**: the two Input-window cases for a window the user closed (`\pa`, `\i`), the cursor case, `opens nothing for Input`, the `build()` case, the third-columns case, the refused-switch case, the Send case (code written ahead of them; mutants L5–L7, L10, L11, L17, L20). The pinned old shape in 14 existing cases moved: the switches among the panes (windows counted, buffers listed per pane), the terminal pane asked for again, `focus()` (`\i` shows the agent pane; Input needs the Report), the shell's end, `open()`, two layouts (+ heights), and the entry suite's `TERMINAL_PANE` (two windows) with `\i` landing on the agent pane.

**Moved because Neovim resizes**: the scrolled-view cases set `'scrolloff'` to 0 and the shell's case asserts the cursor line only — a window that changes height lets Neovim move the top line of what it shows to keep the cursor (measured: `topline` 100 became 94 and 97 when the view was restored before the window had its final size; with the window sized first, the Report and Input keep both). A terminal resizes with its window, so its top line follows; recorded in the limits.

## Mutants — literal edits on `lua/aineo/layout/init.lua`, run on `tests/test_layout_terminal_pane.lua` (L11, L20 also on the entry file)

| # | Edit | Killed by |
|---|---|---|
| L1 | `close_input_window_for_terminal_pane()` in `switch_input_window()` → `nothing = 1` | assertion ×7 |
| L2 | `show_input_window_after_terminal_pane(to)` → `nothing = 1` | assertion ×9 |
| L3 | `restore_view(state.windows.input, buffer)` removed from `open_input_window()` | assertion: `shows the Report and Input as they were scrolled` (input) |
| L4 | the `state.views[…] = winsaveview` of `close_input_window()` removed | same case |
| L5 | `state.input_closed_by_user = was_closed` → `= false` | `reopens the Report's window when its wipe closed it, and leaves Input's closed` |
| L6 | `if pane ~= 'terminal' then state.input_closed_by_user = nil end` removed from `M.show_pane()` | `…when the agent pane is asked for` |
| L7 | the `if role == 'input'` clear removed from `M.focus()` | `…when Input is asked for` |
| L8 | `show_input_window_after_terminal_pane('agent')` removed from `reopen_agent_pane()` | assertion ×6 (the wipes) |
| L9 | `closed_on_purpose = false` in `can_show_in_place()` | assertion and crash ×11 |
| L10 | `must_open_to_focus()` without `is_closed_by_pane(role) and has_input()` | `opens nothing for Input…` (survived the first run) |
| L11 | the `close_input_window()` of `build()` removed | `builds the layout anew…` (survived the first run) |
| L12 | `and PANE_BUFFERS[state.pane].input` removed from `reopen_closed_windows()` | `shows the shell again in a Report's window reopened` |
| L13 | `focus_shows_agent_pane()` → `role == 'report'` | assertion ×4 |
| L14 | `keep_proportions()` removed from `open_input_window()` | `shows the Report and Input as they were scrolled` (input) |
| L15 | `pin_windows()` over `pairs(state.windows)` | crash ×9 |
| L16 | the cursor move to the Report after `close_input_window()` | survived: Neovim sends the cursor to the window above, the Report's; the move and its docstring line are gone, the case stays as a pin |
| L17 | `pcall(switch_input_window, pane, shown)` removed from `switch_pane()` | `leaves the terminal pane shown, Input's window closed, when the shell's window refuses…` (survived the first run) |
| L18 | `show_buffers_of(pane)` before `switch_input_window(shown, pane)` | `shows the Report and Input as they were scrolled` (report) |
| L19 | `apply_proportions()`: `if has_window('input')` → `if true` | crash ×13 |
| L20 | `is_open()` → `vim.iter(ROLES):all(has_window)` | `makes three columns of a third each when a file opens beside it` (survived the first run) |
| L21 | `PANE_BUFFERS.terminal` with `input = 'input'` back | assertion and crash ×19 |

## Limits recorded

- The shell's window is as tall as the column and the terminal resizes with it; the top line of its window can differ on return, the cursor line stays (`doc/aineo.txt`, *The terminal pane*).
- `tests/test_entry_panes.lua` failed once in four runs on `a switch to the changes pane, refused … in the command-line window`, while five other test files ran beside it; it passed on three re-runs. The case does not touch the terminal pane.

## Open threads

- The Input window's ID changes on every round trip; nothing in the repository reads it.
- Left to the orchestrator's check: the whole suite (D30).

## Fix round (the review of the pull request; the orchestrator's assumptions)

- **Finding 1, the Report's top line drifted** on every round trip (50 became 39 after four `\pt` and `\pa`): closing Input's window grows the Report's window and Neovim moves its top line to keep the cursor at the same fraction of the height, and the moved view was saved. `close_input_window()` now saves the Report window's view before the close and restores it after. Cases: top line 50, cursor 52, `'scrolloff'` 0, four round trips, the cursor in the Report's window and in Claude's. Red first: 39 and 42 against 50.
- **Finding 2, the share**: `open_input_window()` sized the column through `keep_proportions()`, which needs Claude's window; with it closed Input came back at 11 of 21 rows. It now calls `size_right_column()` when the Report's window exists. Case, for `\pa`, `\g` and the shell's `exit`, Claude's window closed first. Red first: 10 rows against 14.
- **Finding 3**: the help says `\r` leaves Input closed when it was closed before `\pt`, and `\pa`, `\g` and `\i` open it.
- **Finding 4**: the first round-trip case asserts the reopened Input's `winfixheight` and `winfixwidth`.

Mutants, killed by assertion: the Report view's save removed (2 cases), `size_right_column()` removed (3), `pin_windows()` removed from `open_input_window()` (1).
