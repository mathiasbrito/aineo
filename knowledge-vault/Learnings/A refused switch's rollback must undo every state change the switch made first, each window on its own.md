# A refused switch's rollback must undo every state change the switch made first, each window on its own

**Tags:** #neovim #windows #state #trap
**Discovered:** [[Sessions/2026-10-05 — T24 Panes]] (the attack review of PR #105, its re-measure and the guarantee review of the second fix round)
**Applies to:** [[Projects/aineo]]

## The insight

A switch that writes its state first and then shows buffers in windows can be refused half-way. A window can refuse with `'winfixbuf'`, the command-line window can refuse with E11, and an autocommand can fail as a buffer enters. The rollback then has to undo **every** piece of state the switch wrote before the failure, not only the obvious one, and must undo each window on its own. Undoing the windows can fail too, so one `pcall` around the whole undo stops at the first window that raises and leaves the rest. Whatever the rollback leaves behind is later read by another path, a restore or a follow, as if the switch had happened.

## Example

T24's `switch_pane()` (`lua/aineo/layout/init.lua`, `local function switch_pane`) shows the agent pane or the changes pane in the right column's two windows. Each fix closed one leftover, and the next review found another:

1. **The first version** set the pane before the window loop. A refusing window left the column half switched while the state named a pane it did not show, so every later `\pc` did nothing and said nothing (the attack review, finding 2).
2. **The first fix round** (`dadbaed` on `dev`; `865ab63` on the PR's branch) restored the pane and showed the old pane again under one `pcall`. Two leftovers remained (the re-measure, findings 1 and 2):
   - It kept the Report's `b:changedtick`, taken before the switch to tell a report arriving while the Report is hidden. After a `\pc` refused in the command-line window, one report, and the user moving back to line 3, `\o` "followed" the arrival: the cursor went to 66 of 66, not 3.
   - When the undo itself raised at the Report's window, Input's window was never undone.
3. **The second fix round** (`1591bb1`; `5291f03` on the branch) undid each window in its own `pcall` (`show_buffers_of_each_window()`), kept raising the switch's own error and pinned it (the re-measure's RMk), and ran the follow inside the rollback so that nothing was left for a later restore.
4. **`f21cef0`** (`73760cf` on the branch) then removed the follow's pane check, reasoning that no case builds the corner it guards. The guarantee review built the corner. With the check gone, the follow ran under the changes pane and forgot the Report it had kept: PD3 (b) was lost after a refused switch (G1), and a `\pc` refused in the command-line window moved the cursor of a Report the user had shown by hand (G2) and lost the next arrival (G2b). The correction (`c9b78b1`; `8f08be9` on the branch) put the check back, red-first from those inputs.

## Why it matters

- **Each write is a separate obligation.** List every write the switch makes before its first call that can fail: the flag, any snapshot taken to compare against later (here a buffer and its tick), any "pending" marker. The rollback either restores each one or consumes it, as the follow does here.
- **Undo per window.** In Neovim, showing a buffer in a window runs `BufWinEnter` and other autocommands, so undoing a window can raise as easily as doing it. Undo each window separately, and raise the original error.

The same shape will meet T25's changes pane and any later code that moves buffers between fixed windows. Measured on Neovim 0.12.5.
