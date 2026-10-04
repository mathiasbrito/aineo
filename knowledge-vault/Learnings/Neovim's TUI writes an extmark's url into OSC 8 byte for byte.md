# Neovim's TUI writes an extmark's url into OSC 8 byte for byte

**Tags:** #neovim #tui #extmarks #security #terminal #measured
**Discovered:** [[Sessions/2026-09-26 — T10 Report links]] (the brief review of PR #49, the guarantee review of PR #52) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

Neovim's TUI draws an extmark's `url` as an OSC 8 hyperlink, `ESC ] 8 ; id=<n> ; <url> ESC \`, and copies the url into it unchanged. Any of these in the url reaches the outer terminal's escape parser:
- ESC;
- BEL;
- a C1 control;
- bytes that are not well-formed UTF-8.

An `ESC \` inside the url ends the hyperlink early, and whatever follows is read as a sequence of its own, such as setting the window title or writing the clipboard. Text a plugin did not write itself must be cut before it becomes a url.

## Example

- **The brief review of PR #49** (T10's brief, at `987cf3e`; its code is `dev` `2cb3cbb`). It ran a Neovim TUI in a pseudo-terminal with `TERM=xterm-256color`, and the two versions wrote the same bytes.
  - With the url `https://x.y/<ESC>\<ESC>]0;title<BEL>z`, the TUI wrote `\x1b]8;id=3790209024;https://x.y/\x1b\\\x1b]0;title\x07z\x1b\\…`. The planted `ESC \` ends the OSC 8, and a complete OSC 0 (set the title) follows.
  - With `https://x.y/<ESC>]52;c;cHduZWQ=<BEL>`, it wrote a complete OSC 52, a clipboard write, inside the link.
  - Without the url extmark, which is `dev`'s code, the same text showed as `^[` and never reached the terminal.
- **The guarantee review of PR #52** (T10, at `ff58448`, both versions) did the same with raw bytes of 0x80 and above.
  - `https://x.y/a\x9c\x9d0;pwned\x9cz` was written as it is: an 8-bit ST, then an 8-bit OSC 0.
  - `https://x.y/a` followed by a lone `\xC2` was written as `…;https://x.y/a\xc2\x1b\\`: an incomplete lead byte right before the ST's ESC, which a lenient UTF-8 decoder may swallow.
  - Its effect on a real terminal was not driven, since no terminal emulator may be run here.
- **T10's fix** (`lua/aineo/report/links.lua`, `12a37fe` … `d30ff4d` on `dev`) ends a link at any of:
  - a C0 control or DEL;
  - a C1 control;
  - the first byte that does not begin a well-formed UTF-8 character. Overlong forms and surrogates count as ill-formed, since a lenient decoder can read `\xE0\x80\x9B` as ESC.

**Why.** `src/nvim/tui/tui.c` formats the url with `%s` and escapes nothing: `kv_printf(tui->urlbuf, "\x1b]8;id=%" PRIu64 ";%s\x1b\\", id, url);` (`v0.12.5` l.919, `v0.11.6` l.904). The id is `0xE1EA0000` plus the url's index, which is the 3790209024 above. `nvim_buf_set_extmark()` takes the url and returns it unchanged (`Implementation/Waves/00006-fixes/evidence/report-links.txt` §1). This pass read the TUI at both tags, fetched with `gh api`.

## Why it matters

A plugin may set `url` from text it did not write: an LSP message, a log line, a model's output, a file's contents. It must cut the url at controls and ill-formed bytes, or refuse it, before setting it.
- The hyperlink exists only when a TUI draws to a terminal. A headless test sees the extmark alone, so pin the url that is set; the bytes on the terminal are not visible there.
- **Limits:**
  - measured through Neovim's own TUI with `TERM=xterm-256color`; the plain url also with and without `TERM_PROGRAM=iTerm.app` (`report-links.txt` §2), on 0.11.6 and 0.12.5;
  - what a given terminal does with the planted sequences was not measured;
  - a NUL byte, which would end `%s`, was not tried.
