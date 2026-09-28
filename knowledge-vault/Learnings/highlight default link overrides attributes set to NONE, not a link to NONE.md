# highlight default link overrides attributes set to NONE, not a link to NONE

**Tags:** #neovim #highlight #colorscheme #measured
**Discovered:** [[Sessions/2026-09-26 — T18 Report line]] (PR #60: its guarantee and records reviews, the fix round) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

To Neovim, a highlight group whose attributes are all `NONE` has no settings, so a later `:highlight default link` links it. Each of these, given before a plugin's `:highlight default link G X`, is undone by it:
- `:highlight G gui=NONE cterm=NONE`;
- `nvim_set_hl(0, G, {})`;
- `nvim_set_hl(0, G, { bold = false })`.

`:highlight link G NONE`, or `nvim_set_hl(0, G, { link = 'NONE' })`, counts as a link, and a default link leaves a linked group alone. So to tell users how to turn off a group that a plugin defines lazily, give them the link form.

Either form lasts only until the next `:highlight clear`, which restores the recorded default link.

## Example

- **T18 (PR #60)** added `AineoReportStatusBold`, default-linked to `@markup.strong` once the Report shows its first report. The help first said: turn the bold off with `:highlight AineoReportStatusBold gui=NONE cterm=NONE`.
- **The guarantee review of PR #60** (at `467e192`, on 0.12.5 and 0.11.6) showed that this does nothing from a config.
  - Given before aineo's definition, the `[status]` still showed bold: `Cause: different values at key branch 1->"bold", left = true, right = false`.
  - So did `nvim_set_hl(0, g, {})` and `nvim_set_hl(0, g, { bold = false })`.
  - `:highlight link … NONE` and `nvim_set_hl(0, g, { link = 'NONE' })` turned the bold off both before the definition and after it.
- **The fix round** made the help's recipe `:highlight link AineoReportStatusBold NONE` and pinned it before the first report (`60714cf`, `eac342e` on `dev`).
- **The screen, measured by the orchestrator for T18** (`Implementation/Waves/00006-fixes/evidence/report-line-bold.txt`, the SGR the TUI writes, identical on both versions):
  - A6: `gui=NONE cterm=NONE` given after the first definition, then defined again: not bold;
  - A8b: `gui=NONE` given, then `:highlight clear`: bold again.
- **This pass, in bare Neovim** (2026-09-28, `probe-highlight.lua` in `Implementation/Waves/00006-fixes/evidence/learnings-probes.txt`). Each case ran in a fresh child. The first command reached it from Lua, over the API, or typed on its command line. The output is identical on 0.12.5 and 0.11.6:

  ```
  given first (lua) :highlight G gui=NONE cterm=NONE -> vim.empty_dict(); then default link G Title -> { link = "Title" }; then :highlight clear -> { link = "Title" }
  given first (api) :highlight G gui=NONE cterm=NONE -> vim.empty_dict(); then default link G Title -> { link = "Title" }; then :highlight clear -> { link = "Title" }
  given first (lua) :highlight link G NONE -> vim.empty_dict(); then default link G Title -> vim.empty_dict(); then :highlight clear -> { link = "Title" }
  given first (api) :highlight link G NONE -> vim.empty_dict(); then default link G Title -> vim.empty_dict(); then :highlight clear -> { link = "Title" }
  given first (typed) :highlight link G NONE -> vim.empty_dict(); then default link G Title -> vim.empty_dict(); then :highlight clear -> { link = "Title" }
  ```

**Why.** In `src/nvim/highlight_group.c`, `hl_has_settings()` (`v0.12.5` l.1547–1557, `v0.11.6` l.1553–1563) is true only for a group that is not cleared and has one of:
- a non-zero attribute word;
- a cterm or GUI colour;
- when a default link asks, the `SG_LINK` flag.

`gui=NONE` sets nothing non-zero. `:highlight link G NONE` marks the group linked (`sg_set |= SG_LINK`), with a link to nothing. `do_highlight()` skips a link while `hl_has_settings(from, dodefault)` holds (l.1145, l.1098). Read by this pass at both tags. The recorded default link is kept whatever happens ([[Learnings/highlight default link records only a group's first default link]]), which is why `:highlight clear` brings it back.

## Why it matters

- **Any plugin that defines its groups lazily** and tells users how to turn one off should give the link form. A user's `:highlight` lives in their config, which runs before the plugin defines anything.
- **The user's override does not survive a colour scheme change.** Either form lasts only until the next `:highlight clear`, that is, the next `:colorscheme`, as for any default-linked group. To survive it, the override belongs in a `ColorScheme` autocommand.
  - This reaches aineo's own recipe, which the help gives "in your config or at any time". A `:colorscheme` run after that line brings the bold back.
  - This was measured here in bare Neovim, not through aineo.
- **Limits:**
  - measured on 0.11.6 and 0.12.5;
  - `:highlight G NONE` given before the definition was not measured by this pass.
