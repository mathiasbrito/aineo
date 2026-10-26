# A check against extmark spans runs once a buffer-wide change is whole

**Tags:** #neovim #extmarks #on_lines #scheduling
**Discovered:** [[Sessions/2026-10-25 — T151 propose fix]] (D123, A630 and A631)
**Applies to:** [[Projects/aineo]]

## The insight

A command that changes the whole buffer (a move, a join, a global command) may reach an `nvim_buf_attach` `on_lines` callback in parts, and extmarks have already moved for the whole command by the first part. A check of text against extmark spans made inside the callback can therefore read spans that no longer match a part's lines; the check belongs in a scheduled function that runs after the change is whole.

## Example

The fix preview's edit watch drops a fix when an edit touches its old lines. It runs its re-check of every edit's text and order in a scheduled redraw (T151, A630 (2)), and the drop itself is scheduled, so accept's own re-check guards an edit made in the same tick. Even so, a command Neovim reports in parts (`:5m1`, `:2m3`, `:g/return/m$`, `4J` above an old range) may drop a fix whose lines still stand: a later part seems to touch spans already moved. That residue is recorded as a limit of the watch (A631 (3)): it is never unsafe, and the user asks again.

## Where it applies again

Any watch that compares extmark positions with buffer text from `on_lines`. Scheduling narrows the window but, as the example shows, does not remove every false positive; decide which way a false positive fails and make it the harmless one.
