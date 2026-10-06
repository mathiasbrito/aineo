# A removal and its put-back made in one typed command are one undo step, so the first u shows nothing

**Tags:** #neovim #undo #mappings
**Discovered:** [[Sessions/2026-10-06 — T26 Visual Send]] (D20's measurement before T26, `U4` and `V2b`; the records review of PR #115, finding 2)
**Applies to:** [[Projects/aineo]]

## The insight

When one typed command — a key and the mapping it runs — removes text and then puts it back, both changes join one undo block. The buffer ends as it was, and the first `u` after it undoes that block: nothing visible changes. The second `u` undoes the user's own change before it. An undo break between the removal and the put-back (`let &g:undolevels = &g:undolevels`) would split them, and the first `u` would then empty the text again.

## Why it is true

`:h undo-blocks` (0.12.5): "One undo command normally undoes a typed command, no matter how many changes that command makes. … if the typed key(s) call a function, all the commands in the function are undone together." `:h undo-break`: "Setting the value of 'undolevels' also closes the undo block. Even when the new value is equal to the old value."

Measured on Neovim 0.12.5, macOS (`Implementation/Waves/00007-panes/evidence/t26-close-probes.txt`, section 6): after `itext<Esc>` and a typed `<F2>` whose mapping empties the buffer and puts its line back, `u` leaves `{ 'text' }` and `u u` gives `{ '' }`; with `let &g:undolevels = &g:undolevels` between the removal and the put-back, `u` gives `{ '' }` and `u u` `{ 'text' }`.

## How it showed up here

aineo's Send clears Input, then writes to Claude Code's terminal; when the write fails, it puts Input back and raises (`write_or_put_back()`, `lua/aineo/send/init.lua:92` on `dev` `3b5f0f7`). The orchestrator measured this before T26's dispatch (`Implementation/Waves/00007-panes/evidence/t26-probes.txt`, `U4`): after a failed `\s`, Input held `First line`, `second line`; after `u`, the same; after `u u`, an empty Input. A removal and its put-back made in one callback moved `undotree()`'s `seq_cur` by one step (`V2b`). D20 says a gap goes to the user, not around it, and the user chose on 2026-10-05 that the help's *LIMITS* name it and a test pin it. The records review of PR #115 found that only the Visual Send's case was pinned; its mutant `W1`, the undo break above added to the whole-Input Send, survived `tests/test_send.lua` until the fix round's case killed it.

## Where it applies again

Any undo-sensitive action that changes a buffer and may roll the change back in the same command: a formatter that restores on error, a refactoring that reverts a failed step. The first `u` looks broken to the user. Measuring it needs typed keys, since the block is the typed command's: the probes above type with `nvim_feedkeys(…, 'mtx')`, which makes each key sequence its own command and its own undo block (`t26-probes.txt`, its header).
