# strdisplaywidth follows the current window, nvim_strwidth does not

**Tags:** #neovim #layout #unicode #measured
**Discovered:** [[Sessions/2026-09-26 — T11 Report icon]] (the attack review of PR #45, finding 1) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

`vim.fn.strdisplaywidth()` measures a string the way the current window would lay it out. When that window is narrower than the string and has `'linebreak'` or `'showbreak'`, the padding a line break would add is counted too. The result is then larger than the string's cells, and it changes with the window, not with the string.

`vim.api.nvim_strwidth()` counts cells only. It follows `'ambiwidth'` and `setcellwidths()` exactly as `strdisplaywidth()` does. To size text for a buffer that will show in some other window, or in several, use `nvim_strwidth()`.

## Example

The attack review of PR #45 (T11, at `e1a5bea`) measured the prefix `✓ 09:05 `, whose width is 8 cells. The results were identical on 0.11.6 and 0.12.5.

| current window | `strdisplaywidth` | `nvim_strwidth` |
|---|---|---|
| 80 wide | 8 | 8 |
| 6 wide, `'nolinebreak'` | 8 | 8 |
| 6 wide, `'linebreak'` | **9** | 8 |
| 6 wide, `'breakindent'` | 8 | 8 |
| 6 wide, `'showbreak'` `>>` | **10** | 8 |
| 12 wide, `'linebreak'` | 8 | 8 |
| 3 wide, `'linebreak'` | **9** | 8 |
| 3 wide, `'linebreak'`, `'showbreak'` `+++` | **37** | 8 |

- **The error does not grow steadily with narrowness.** With a global `'number'` and `'signcolumn=yes'` (a text offset of 6) and `'linebreak'`, `strdisplaywidth` gave 8, 8, 10, 9, 8 and 11 at window widths 16, 14, 13, 12, 11 and 10.
- **In aineo's real layout**, a 26-column editor with the cursor in the Input (12 wide), a report's details were indented 9 cells under a `[` at column 8.
- **Elsewhere the two agreed.** In every `'ambiwidth'` and `setcellwidths()` row the review tried, the two functions gave the same width.
- **The fix.** T11's fix round measured the indent with `nvim_strwidth()` (`7b4e428` on `dev`). T18 later removed the icon, and the indent became a constant.

**Why.** `:help strdisplaywidth()`, identical in substance in both versions, says: "The option settings of the current window are used. This matters for anything that's displayed differently, such as 'tabstop' and 'display'." `:help nvim_strwidth()` says: "Calculates the number of display cells occupied by `text`. Control characters including <Tab> count as one cell." That the break padding is counted was measured; this pass did not read it in the C source.

## Why it matters

Plugin code often measures text from a callback: a timer, an RPC request, an autocommand. The current window at that moment is whatever the user left current, and often a narrow split. `strdisplaywidth()`'s answer then depends on the user's layout, so the resulting misalignment shows only in some layouts.
- **Limits:**
  - measured on 0.11.6 and 0.12.5;
  - measured with `'linebreak'` and `'showbreak'`; `'breakindent'` alone changed nothing;
  - Tab characters, which `strdisplaywidth()` expands from its `{col}` and `nvim_strwidth()` counts as one cell, were not measured.
