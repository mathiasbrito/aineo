# After the first nvim__inspect_cell, cells read before a redraw decode wrongly

**Tags:** #neovim #testing #screen #highlight #measured
**Discovered:** [[Sessions/2026-09-26 — T18 Report line]] (the brief review of PR #57; the guarantee review of PR #60, G8) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

Take a Neovim whose UIs do not use hlstate; a headless test child has no UI at all. The first call of the internal `nvim__inspect_cell()` in it reads its own cell correctly, then rebuilds the highlight attribute tables. Every later read of a highlighted cell before the next redraw decodes the cell's old attribute id against the new tables, and returns a wrong foreground, or loses bold. A cell drawn with no highlight, attribute 0, reads right.

Reads made after a redraw are right. A new RPC request is enough, since the child redraws between requests.

## Example

- **The brief review of PR #57** (T18's brief, at `73bbce3`; its code is `dev` `d30ff4d`), on 0.12.5 and 0.11.6:
  - reads made in the request that made the first call came back without bold (`[:#b3f6c0 ]:#b3f6c0`);
  - the next request, and reads after `:redraw`, came back with it (`[:#b3f6c0+B`);
  - on 0.11.6 a cell drawn in `DiagnosticOk`'s `#b3f6c0` read as `Title`'s bold `#e0e2ea`.

  It gave the likely cause as "not verified in Neovim's source (none was at hand)".
- **T18's helper** (`370bdaa` on `dev`). `first_status_on_screen()` in `tests/test_report_colours.lua` makes one call and drops its result, runs `:redraw`, then reads each cell in a request of its own.
- **The guarantee review of PR #60** (at `467e192`, G8) removed the dropped call and the redraw: 0 of 49 cases failed. Each read already had its own request.
- **This pass, in bare Neovim** (2026-09-28, `probe-inspect-cell.lua` in [[Attachments/learnings-probes-2026-09-28.txt]]).
  - The setup: a fresh child, `nvim --clean --headless --embed`, with the line `09:05 [done] Task`. Extmarks colour `09:05` `#9b9ea4` and `[done]` `#b3f6c0` bold.
  - Each numbered block below is a new child. Each line is one request.
  - The output is identical on 0.12.5 and 0.11.6:

  ```
  1 first call ever, one request reading cols 6, 6, 7, 0, 5: [:#b3f6c0+B [:#b3f6c0 d:#b3f6c0 0:#e0e2ea  :-
  1 next request, cols 6, 7, 0:                            [:#b3f6c0+B d:#b3f6c0+B 0:#9b9ea4
  1 after a :redraw request, cols 6, 7, 0:                 [:#b3f6c0+B d:#b3f6c0+B 0:#9b9ea4
  2 first call ever reads col 0 alone:                     0:#9b9ea4
  2 next request, cols 6, 7, 0:                            [:#b3f6c0+B d:#b3f6c0+B 0:#9b9ea4
  3 first call ever reads col 6 alone:                     [:#b3f6c0+B
  3 next request, col 6 alone:                             [:#b3f6c0+B
  ```

  The first call's own cell is right. The same cell, read again in that request, has lost its bold. `0` shows `Normal`'s colour.

**Why.** `src/nvim/api/vim.c`, `nvim__inspect_cell()` (`v0.12.5` l.2007–2041, `v0.11.6` l.1820–1855).
- Its doc comment says: "NB: if your UI doesn't use hlstate, this will not return hlstate first time."
- It decodes the cell with `hl_get_attr_by_id(attr, …)`, then calls `highlight_use_hlstate()`, next to the comment "will not work first time".
- In `src/nvim/highlight.c` (`v0.12.5` l.60–69, `v0.11.6` l.62–71), `highlight_use_hlstate()` sets `hlstate_active` the first time and runs `clear_hl_tables(true)`, under "hl tables must now be rebuilt".
- The grid keeps the attribute ids it was drawn with until the next redraw.

This pass read both at the two tags, fetched with `gh api`.

## Why it matters

A test that reads the screen through `nvim__inspect_cell()` must read each cell in a request of its own, or redraw after the first call before it reads. Otherwise a bold assertion can pass with no bold drawn, or fail with bold drawn, and a red step lies.
- It is an internal API (`nvim__`), so none of this is a contract.
- **Limits:**
  - measured on 0.11.6 and 0.12.5;
  - a Neovim with a UI that uses `ext_hlstate` was not measured. With the plain TUI attached, the brief review's reads agreed with the SGR the TUI wrote in 28 cases of 28, on both versions.
