# A block edge on a character drawn from several codepoints needs charidx and byteidx to find its end

**Tags:** #neovim #unicode #visual-mode #trap
**Discovered:** [[Sessions/2026-10-06 — T26 Visual Send]] (the attack review of PR #115, finding 1; the fix round's unit 1)
**Applies to:** [[Projects/aineo]]

## The insight

When a blockwise selection's edge cuts a double-width character, `getregionpos()` gives that edge as the character's **first byte**, with a non-zero `off`: a right edge on its left half ends the line's region there, so a read through the region's end stops at the character's first byte. (A one-column block on the character, the probe's case, gives both ends there.) To read the whole character, as `"_d` removes it, the end must be extended to the end of the character Neovim draws. `vim.str_utf_end()` does not do that: it ends at the first **codepoint**. Where one drawn character is several codepoints — an emoji with a skin tone (`👍🏽`), a flag (`🇫🇷`), a ZWJ sequence (`👨‍👩`), a letter with a combining mark (`漢́`) — it stops short. `charidx()` and `byteidx()` count such a sequence as one character, so the end is:

```lua
vim.fn.byteidx(line, vim.fn.charidx(line, byte - 1) + 1) -- byte: 1-based; the result is the character's last byte, 1-based
```

Measured on Neovim 0.12.5, macOS (`Implementation/Waves/00007-panes/evidence/t26-close-probes.txt`, sections 1, 2 and 2b):

| line | `str_utf_end` ends at | `byteidx(charidx(…) + 1)` ends at |
|---|---|---|
| `a👨‍👩b` | 5 | 12 |
| `a👍🏽b` | 5 | 9 |
| `a🇫🇷b` | 5 | 9 |
| `a漢́b` | 4 | 6 |
| `a漢b` | 4 | 4 |

A block from column 2 over `a👍🏽b` gives `{ { 1, 2, 2, 0 }, { 1, 2, 2, 1 } }` for that line: both ends at byte 2. Other blocks over it (section 2b):

| keys | line 2's region |
|---|---|
| `gg0l<C-V>jj` | `{ { 1, 2, 2, 0 }, { 1, 2, 2, 1 } }` |
| `gg0<C-V>ljj` | `{ { 1, 2, 1, 0 }, { 1, 2, 2, 1 } }` |
| `gg0ll<C-V>ljj` | `{ { 1, 2, 2, 1 }, { 1, 2, 10, 0 } }` |
| `gg0ll<C-V>jj` | `{ { 1, 2, 2, 1 }, { 1, 2, 2, 2 } }` |

## Why it is true

`getregionpos()` returns byte positions, and for a double-width character half inside the block it can only point at the character's start. `vim.str_utf_end()` is a UTF-8 function: it knows codepoints, not what Neovim draws as one cell group. `charidx()` and `byteidx()` count characters as Vimscript does, with composing characters joined to their base — `:h charidx()` and `:h byteidx()` say so for composing characters; that a skin-tone modifier, a regional-indicator pair and a ZWJ sequence count as one on 0.12.5 is this note's measurement, not a documented promise.

## How it showed up here

T26's Visual Send sends exactly what `"_d` removes (VS5 (b), the user's). The attack review's fuzzer compared each message with what `nvim_buf_attach()`'s `on_bytes` showed leaving Input, and five of six rows failed on `08ea516`: Claude was sent `👍` where `👍🏽` was removed, a lone regional indicator `🇫` for `🇫🇷`. The fix round wrote `character_end()` (`lua/aineo/send/init.lua:159` on `dev` `3b5f0f7`) with the measured form, red-first from the review's rows.

## Where it applies again

Any code that turns `getregionpos()`, `getpos()` or a mouse column into text a block cuts: a selection sent elsewhere, a block yanked by hand, a highlight over a block. The limit: a line holding a NUL cannot go to `charidx()` as a Lua string ([[Learnings/A NUL in a buffer line is a line feed to Vimscript, and a Lua string holding one is a Blob]]). How newer Unicode sequences are counted depends on Neovim's own tables, so a new emoji form is worth re-measuring.
