# A NUL in a buffer line is a line feed to Vimscript, and a Lua string holding one is a Blob

**Tags:** #neovim #lua #vimscript #binary #trap
**Discovered:** [[Sessions/2026-10-06 — T26 Visual Send]] (the attack review of PR #115, finding 4; the fix round's unit 2)
**Applies to:** [[Projects/aineo]]

## The insight

A NUL byte in a buffer line crosses the Lua–Vimscript boundary differently each way:

- **Read through Vimscript**, `vim.fn.getline()` gives it as `"\n"`; `vim.api.nvim_buf_get_lines()` gives it as `"\0"`. A Lua string from `getline()` therefore cannot tell a NUL from a line break.
- **Handed to Vimscript**, a Lua string holding a `"\0"` becomes a Blob, and a function that wants a String refuses it: `charidx()` with `E1174: String required for argument 1`, `byteidx()` and `strchars()` with `E976: Using a Blob as a String`.

So read lines with `nvim_buf_get_lines()`, and before passing one to a Vimscript string function, replace each NUL with `"\n"` — one byte for one byte, so byte positions still match.

Measured on Neovim 0.12.5, macOS (`Implementation/Waves/00007-panes/evidence/t26-close-probes.txt`, section 5): `getline` `"a\nb"`, `nvim_buf_get_lines` `"a\0b"`; `type('a\0b')` is 10, `v:t_blob`.

## Why it is true

Vim stores a NUL in a line as a NL in memory (`:h NL-used-for-Nul`), and `getline()` returns the line as stored. The API returns the bytes as the buffer holds them. In the other direction, `:h lua-eval` (0.12.5) says: "If a Lua string contains a NUL byte, it will be converted to a |Blob|", and Blobs are not converted to Strings automatically (`:h E976`).

## How it showed up here

T26's Visual Send read each selected line with `vim.fn.getline()`, so `a<NUL>b` reached `without_control_bytes()` as `a\nb` — a line break, which it keeps — and Claude was sent two lines where Input held one. The whole-Input Send reads with `nvim_buf_get_lines()` and drops the NUL. The fix round read the line through `buffer_line()` (`nvim_buf_get_lines()`), and then found that `charidx()` refuses that line; `character_end()` (`lua/aineo/send/init.lua:159` on `dev` `3b5f0f7`) hands it `line:gsub('%z', '\n')`. `M-nul-blob`, which passes the raw line, dies on the NUL case.

## Where it applies again

Any Lua code that mixes `vim.fn` string functions with buffer text a user can fill with arbitrary bytes: positions from `charidx()`, `byteidx()`, `strchars()`, `strdisplaywidth()`, `matchstr()`, and lines from `getline()`, `getregion()` or registers (`:h getreg()` gives NULs as NLs unless asked for a list). The same family of trap on a channel: [[Learnings/sockconnect's on_data hands a zero byte over as a newline]]. Only the functions named above were measured.
