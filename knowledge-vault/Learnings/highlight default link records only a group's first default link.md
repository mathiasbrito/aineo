# highlight default link records only a group's first default link

**Tags:** #neovim #highlight #colorscheme #measured
**Discovered:** [[Sessions/2026-09-25 — T9 Report colours]] (PR #30: the guarantee review's G4, the re-measure) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

`:highlight default link G X` does two separate things.
1. **It records X as G's default link**, the link `:highlight clear` restores. Every `:colorscheme` starts with `:highlight clear`. The link is recorded only while G has no default link yet.
2. **It links G to X now**, unless G already has settings: a colour, an attribute, or a link.

So the first default link wins for good. Suppose a colour scheme or a config gives G a default link before a plugin defines G. Then that link is kept, and every `:highlight clear` restores it, not the plugin's.

`nvim_set_hl(0, G, { link = X, default = true })` differs on both counts. It does nothing at all to a group that has settings, so it records nothing there. When it does apply, it replaces the recorded default link.

## Example

- **T9 (PR #30) first used `nvim_set_hl(…, { default = true })`.** The guarantee review found (G4) that this lost a group. A user's colour given before the first report, then `:highlight clear`, left the group empty, because `nvim_set_hl` had recorded no default link. The fix round moved to `:highlight default link` (`27b327d` on `dev`). The Ex form records the default link even over a group that has a colour.
- **The re-measure of PR #30** (at `e5d0a76`, code `72827be`, identical on 0.11.6 and 0.12.5) then found the limit. A colour scheme ran `highlight clear`, then `highlight default link AineoReportDone Title`, before the Report's first report. After a report, a `:colorscheme` that does not name the group left it linked to `Title`, not `DiagnosticOk`. Its Q3 read `Title`, `Title`, `DiagnosticOk`, `Title` across the steps. T9 recorded this as a limit and pinned it (T9's session note, *Limits*).
- **This pass, in bare Neovim** (2026-09-28): `probe-highlight.lua` in [[Attachments/learnings-probes-2026-09-28.txt]]. Each case ran in a fresh child, `nvim --clean --headless --embed`. The output is identical on 0.12.5 and 0.11.6:

  ```
  given first (lua) :highlight default link G DiagnosticOk -> { link = "DiagnosticOk" }; then default link G Title -> { link = "DiagnosticOk" }; then :highlight clear -> { link = "DiagnosticOk" }
  given first (lua) :highlight G guifg=#ff0000 -> { fg = 16711680 }; then default link G Title -> { fg = 16711680 }; then :highlight clear -> { link = "Title" }
  ```

**Why.** `src/nvim/highlight_group.c`:
- In `do_highlight()`'s `link` branch (`v0.12.5` l.1133–1134, `v0.11.6` l.1086–1087), `if (dodefault && (forceit || hlgroup->sg_deflink == 0)) { hlgroup->sg_deflink = to_id; … }` records the default link only when none is there.
- The link itself is set only when `hl_has_settings()` is false (l.1145, l.1098).
- `highlight_clear()` ends with `sg_link = sg_deflink` (l.1578, l.1584).
- `set_hl_group()`, behind `nvim_set_hl()`, returns at once when `is_default && hl_has_settings(idx, true)` (l.916, l.906). When it goes on with `default`, it sets `g->sg_deflink = link_id` whatever was there (l.931, l.920).

The re-measure of PR #30 read the `link` branch and `highlight_clear()` at both tags, and found them byte-identical. This pass read all four again, fetched with `gh api` at `v0.11.6` and `v0.12.5`.

## Why it matters

A plugin that defines its groups with `:highlight default link` gets what it wants in most cases: the user's and the colour scheme's colours are respected, and `:highlight clear` restores the plugin's link. What it cannot do is take back a default link that someone gave first. Neovim cannot tell a scheme's first default link from a user's.
- A plugin that defines its groups when it loads, before any colour scheme, makes its own default link the first.
- A plugin that defines them lazily leaves them to whoever came first. aineo defines them at the Report's first report.
- **Limits:**
  - measured on 0.11.6 and 0.12.5;
  - `:highlight! default link`, which by the source (`forceit`) replaces the recorded default link, was not measured.

See also [[Learnings/highlight default link overrides attributes set to NONE, not a link to NONE]].
