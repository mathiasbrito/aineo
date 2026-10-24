# 2026-10-23 — T140 office tab switch

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t140-office-tab-switch` (from `feature/t123-office-authors`) · **Pull request:** into `feature/t123-office-authors` (#354)

A small fix (D30) of the office screensaver (T123): an office that shows was gone after the user went to another tab page and came back (D115).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T140's row in §6, D115
- `lua/aineo/office/init.lua`, `doc/aineo.txt`, `tests/test_office_life.lua`, `tests/test_entry_office_tabs.lua`

## Task lines

- [X] T140 the office survives a tab-page switch (D115): it stays shown through a leave and a return; the cursor entering the right side afterwards still closes it

## What was done

1. **Cause, measured.** Returning to a tab page fires `WinLeave`, `TabLeave` on the way out and, on the way back, `WinEnter` for the window the cursor was in, and only then `TabEnter`. The office's `WinEnter` handler closes the office when the window entered lies in the cells it covers; the office is paused between `TabLeave` and `TabEnter`, but the handler did not look. With the cursor in the right column when the tab page was left (the office shown with `\O` or `:Aineo office` from Input or the Report; the idle countdown never shows it there), the return closed the office. With the cursor in the left column nothing closed it (measured on the layout stand-ins and on the entry with the fake `claude`, `tabnew`/`tabprevious`, `gt`/`gT`, `:tabnext`, a second aineo tab with its own office, the office shown by the idle countdown, the cursor in Claude's terminal in Terminal mode): the cases for it are kept as pins, and the cause named in the brief's candidates (`follow_right_side`, `WinClosed`, the layout's `TabEnter`) did not close it in any of them.
2. **Fix** (`aineo.office`): `is_paused(open)` (the frame timer is stopped) is checked by the `WinEnter` handler, so the window entered as the tab page is re-entered is not the cursor entering the office's cells; `TabEnter` resumes the office and later `WinEnter`s close it as before.
3. **Documented**: the paragraph on tab pages in `doc/aineo.txt`.

## Tests and mutants

`tests/test_office_life.lua` (3 cases added) and `tests/test_entry_office_tabs.lua` (4 cases).

Red before the fix: office-life "keeps the office on screen when the cursor was in the right side it covers" (`false` expected `true`); office-life "has the office run again, with its agent where it was, ..." (`timers = 0`, expected 2); entry "stays when the user goes to a tab page of no layout with gt and comes back with gT", cursor in the right column (0 floats, expected 1); entry "... another aineo tab, whose office shows too ...", cursor in the right column (1 float, expected 2).

Green on arrival: the two left-column entry cases (they pin the behaviour that already held; no mutant of this fix kills them, M1 leaves them green by nature, and they are kept so that the left-column path stays pinned through a real `gt`/`gT`); office-life "still closes the office when the cursor enters the right side after the tab page was entered again" (killed by M2).

Mutants, re-run on the tree that ships, on the base b376eb5a (literal edits to `lua/aineo/office/init.lua`):

- M1, delete the line `and not is_paused(open)` from the `WinEnter` handler: killed by assertion, the four reds above.
- M2, `return true` in place of `return open.timer == nil` in `is_paused`: killed by assertion by the still-closes case and by five cases of `tests/test_office.lua` (waking, wipes the buffer, the timer and watch stop).
- M3, `and false` appended to the condition of the `TabEnter` handler that resumes the office: killed by assertion, five cases of `tests/test_office_life.lua` (including the still-closes case).

## Open threads

- The brief's left-column report was not reproduced; if the user sees it with the cursor in the left column, a trace of `WinEnter`, `WinClosed`, `TabEnter` and `WinResized` at the moment it closes is the next step.
- An office shown with the cursor in the right column stays shown over it through a tab-page switch, as it does until the cursor next enters a window.

## Commits

Pull request #354 merged into `feature/t123-office-authors`; that branch reached `dev` through pull request #355. Each commit below is as it stands on `dev` (a rebase merge replays under new hashes).
Released as v0.2.74 (pull request #356, `main` at `2874493e`).

- `5a2009d4` Keep the office shown through a tab-page switch
