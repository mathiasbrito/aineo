# A deleted scratch buffer written to again blocks quitting

**Tags:** #neovim #buffers #trap
**Discovered:** [[Sessions/2026-09-24 — T5 report channel]] (the fix round, attack A3)
**Applies to:** [[Projects/aineo]]

## The insight

In Neovim 0.11.6, a `nofile` scratch buffer that the user `:bdelete`s loses its `'buftype'`; a plugin that later writes into it — or the user showing it again with `:buffer #` — gets an ordinary buffer back, and once its text is changed it is modified, so `:qall` refuses to quit (E37). A plugin-owned buffer is therefore checked before every write — still `nofile`, and loaded — and recreated when it is not, never written to as it stands.

## Example

T5's Report (`aineo://report`) was written to by each delivered report. The attack review of PR #10 (A3) deleted it and showed it again: the next report went into an ordinary modifiable buffer, and `:qall` failed with E37. The fix round counts a Report as showing only while it is `nofile` (`65811ea`), and later dropped the packet's "and loaded" check as one no test could ask for (`33974fc`); the correction restored it (`10892e1`) after the re-measure found that `:bunload` keeps `'buftype'` while the buffer is unloaded — without the check, the next report showed twice (`lua/aineo/report/buffer.lua:66-78`).

## Why it matters

"The buffer still exists" and "the buffer is still mine" are different questions in Neovim: `:bdelete`, `:bunload` and `:bwipeout` each leave a different state behind, and only the last removes the buffer number. A plugin that keeps a buffer id across user commands re-asserts every property it relies on before it writes. Measured on Neovim 0.11.6.
