# A deletion run by normal! sets what . repeats, and a buffer API call does not

**Tags:** #neovim #mappings #redo #trap
**Discovered:** [[Sessions/2026-10-06 — T26 Visual Send]] (the attack review of PR #115, finding 2; the user's decision of 2026-10-06)
**Applies to:** [[Projects/aineo]]

## The insight

A mapping whose callback changes the buffer with `vim.cmd.normal({ args = { '"_d' }, bang = true })` leaves that deletion as what `.` repeats. The user's next `.` then deletes as much text again at the cursor, through whatever else the mapping did not repeat — a send, a log, a notification. A change made through `nvim_buf_set_lines()` or `nvim_buf_set_text()` leaves `.` repeating the user's own last change. Which one a mapping uses decides what `.` does after it.

Measured on Neovim 0.12.5, macOS (`Implementation/Waves/00007-panes/evidence/t26-close-probes.txt`, section 4): on `alpha beta gamma delta`, `:normal! 0wve"_d` then `.` leaves `alpha ma delta`, the `.` removing ` gam`, four characters at the cursor; after `0x` and an `nvim_buf_set_text()` that removes a word, `.` repeats the `x`.

## Why it is true

`:h :normal` (0.12.5): "{commands} are executed like they are typed", so a change it makes is recorded for `.` as a typed change is (`:h .`). The API functions change the text without going through the command that `.` records, so the last recorded change stays the user's.

## How it showed up here

T26's Visual Send removes the selection with Vim's own `"_d`, so that what leaves Input is by definition what Vim removes (VS-A), then sends that text. The attack review found that `.` after it removed text from Input and sent nothing, where `.` after a whole-Input Send, which clears Input through `nvim_buf_set_lines()`, repeats the user's own change. Removing through the API would have left `.` alone but given up `"_d` as the definition of the removal. The user chose, on 2026-10-06, "Name it in LIMITS (Recommended)": the help's *LIMITS* › *Repeating a Visual Send* says so, `u` brings the text back, and a case in `tests/test_send_selection.lua` pins it. `M-dot-api`, the removal by `nvim_buf_set_text()` over `'<`–`'>`, dies on that case.

## Where it applies again

Any mapping or command that edits with `:normal`, `feedkeys()` or an operator, and does something besides the edit: the edit alone is what `.` repeats. Options when that matters: make the edit through the API; or make the whole action repeatable with an `'operatorfunc'` and `g@`. Neither was measured here beyond the two calls above.
