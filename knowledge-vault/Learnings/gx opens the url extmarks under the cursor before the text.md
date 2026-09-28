# gx opens the url extmarks under the cursor before the text

**Tags:** #neovim #extmarks #gx #measured
**Discovered:** [[Sessions/2026-09-26 — T10 Report links]] (PR #52; the brief review of PR #49, finding 2) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

Neovim's default Normal-mode `gx` gathers the urls under the cursor and opens every one of them. It gathers, in order:
- on 0.12.5 only, the LSP document links;
- the `url` of every highlight extmark over the cursor, from any namespace;
- the treesitter `@url` captures.

It falls back to the text under the cursor (`<cfile>`, with `@` added to `'isfname'`) only when it found none. So a url extmark decides what `gx` opens, and the text's own trimming no longer applies. An extmark that holds a worse url than the text makes `gx` worse.

## Example

- **The orchestrator's measurements for T10**, identical on 0.11.6 and 0.12.5 (`Implementation/Waves/00006-fixes/evidence/report-links.txt`, at `dev` `2cb3cbb`).
  - §3: the line `See https://example.com/docs. then (https://x.y/a) end` had an extmark with a url over [4, 28). `gx` at column 10 opened `https://example.com/docs`, the extmark's url. At column 40, with no extmark, it opened `https://x.y/a` from the text.
  - §6: with no extmark, `gx` trims trailing punctuation and brackets by itself. It cut `https://en.wikipedia.org/wiki/Lua_(programming_language)` to `…/Lua_`.
- **The brief review of PR #49** (finding 2) warned of the consequence: the extmark's url wins over the text, so a link finder worse than `gx`'s own trimming is a regression of `gx`.
- **T10 (PR #52) met it.** Its first finder ran a link to white space, and `gx` then opened `https://x.y/docs**`, `https://x.y/docs*`, `https://x.y/a~~` and `https://x.y/a).`. `dev`'s own `gx`, reading the text, got the first two and the last right. T10's finder now leaves trailing punctuation, emphasis and unpaired closing brackets out (`12a37fe` … `d30ff4d` on `dev`).

**Why.** `runtime/lua/vim/ui.lua`, `M._get_urls()`:
- `v0.12.5` l.268–330 and `v0.11.6` l.174–232 read `nvim_buf_get_extmarks(bufnr, -1, { row, col }, { row, col }, { details = true, type = 'highlight', overlap = true })` and keep each `details.url`.
- Then they read treesitter's captures.
- Then `<cfile>`, only `if #urls == 0`.
- 0.12.5 first adds `get_lsp_urls(bufnr)` (l.276).

The default `gx` mapping calls `do_open()` on every url returned (`_core/defaults.lua` `v0.12.5` l.157–164, `_defaults.lua` `v0.11.6` l.148–155). This pass read both releases' own runtimes.

## Why it matters

A plugin that marks urls with extmarks takes `gx` over on them.
- Every url extmark over the cursor is opened, in any namespace, so two overlapping ones open two pages.
- The url must be exactly the link: `gx` will not trim it.
- **Limits:**
  - measured on 0.11.6 and 0.12.5;
  - the LSP document links of 0.12 were not measured;
  - Visual-mode `gx` opens the selection's text and reads no extmark (the same files).
