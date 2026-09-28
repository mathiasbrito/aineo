# Among extmarks of equal priority the one placed later wins the foreground

**Tags:** #neovim #extmarks #highlight #measured
**Discovered:** [[Sessions/2026-09-26 — T18 Report line]] (the brief review of PR #57, the guarantee review of PR #60) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

Two highlight extmarks can cover the same text at the same priority. Their groups combine there:
- an attribute only one of the groups sets, such as bold, shows either way;
- where both set the same attribute, such as a foreground, the mark placed later wins.

A higher priority beats the order: that mark wins wherever it was placed. The order rule is not written in `:help nvim_buf_set_extmark()`.

## Example

The orchestrator measured the screen for T18 with the brief review's probe (`Implementation/Waves/00006-fixes/evidence/report-line-bold.txt`, 2026-09-26). An editor's own TUI ran in a pseudo-terminal in truecolor. The probe decoded the SGR written before `[done]`, and the results were identical on 0.11.6 and 0.12.5.

The setup:
- the status mark is in `AineoReportDone`, which links to `DiagnosticOk`, `#b3f6c0`;
- a bold mark over the same text is in `AineoReportStatusBold`, which links to `@markup.strong`;
- a colour scheme gives `@markup.strong` `guifg=#ff00ff gui=bold`.

| case | bold mark | `[done]` drawn |
|---|---|---|
| A2s | same priority, placed after the status mark | `#ff00ff`, bold |
| A2t | same priority, placed before it | `#b3f6c0`, bold |
| A2 | priority 4097 | `#ff00ff`, bold |
| A3 | priority 4095 | `#b3f6c0`, bold |

In A2 and A3 the status mark keeps the default priority.

- **T18 lays the bold by order**, the status's group last, so the status's colour wins (`370bdaa` on `dev`). The pieces are `header_colours()` in `lua/aineo/report/render.lua`, and `append_rendering()` in `buffer.lua`, whose docstring states the order it relies on.
- **The case that reads it on the screen** is *keeps the colour of its status, bold, when a colour scheme colours @markup.strong*. A Neovim that changed the rule would fail it. Mutant M3, the bold mark placed after the status's, killed it 5 of 5 times.
- **The records path.** The guarantee review of PR #60 (at `467e192`, G7) found that the path which shows the records again could reverse the order with every test green. The fix round pinned it (`60714cf`).

**Why.** This pass did not read the rule in Neovim's source. It rests on the measurements above, on both versions. `:help nvim_buf_set_extmark()`'s `priority` item says only that for virtual text the highest priority is drawn last, and that treesitter uses 100. It says nothing about ties (read in both versions' `api.txt`).

## Why it matters

A plugin that layers highlights at one priority depends on the order it places them in, and nothing documents that order. Give each layer its own `priority` when the winner matters, or pin the result on the screen as T18 did.
- `hl_mode = 'replace'` or `'combine'` on the bold mark changed nothing (A10, A10b).
- **Limits:**
  - measured on 0.11.6 and 0.12.5, with two marks and one contested attribute, the foreground;
  - undocumented, so it may change.
