# With 'selection' old, a Visual selection ending on an empty line ends on the line above, or turns linewise from the indent

**Tags:** #neovim #visual-mode #options #trap
**Discovered:** [[Sessions/2026-10-06 — T26 Visual Send]] (the attack review of PR #115, finding 3; the fix round's unit 3)
**Applies to:** [[Projects/aineo]]

## The insight

With `'selection'` set to `old`, an operator on a charwise Visual selection whose end lies on an empty line below its start does not act on the selection as drawn. The end moves to the end of the line above, so the line break between them is not taken. When the start is at or before its line's first non-blank, the operation becomes linewise and takes whole lines, from the start's line through the line above the end. Under `'selection'` `inclusive` the same keys take the line break and join the lines. Code that computes "what `d` removes" from the selection's two ends, through `getregionpos()` or by hand, is wrong for both cases.

Measured on Neovim 0.12.5, macOS (`Implementation/Waves/00007-panes/evidence/t26-close-probes.txt`, section 3):

| Input | keys | `inclusive` leaves | `old` leaves |
|---|---|---|---|
| `abc`, ``, `def` | `gg0lvj"_d` | `adef` | `a`, ``, `def` |
| `  abc`, `x`, `` | `gg0lvjj"_d` | ` ` | `` |

*(corrected 2026-10-06, after T31: two exceptions, both measured on 0.12.5.*
- *When `'virtualedit'` holds `all` and no other flag but `none`, Vim keeps the selection's end. The second row then leaves ` ` under `old` too; see [[Learnings/Vim reads 'virtualedit' as a set of flags, so all,none keeps a Visual selection's end as all does]].*
- *When the start lies past the end of the line above, which a `'virtualedit'` such as `onemore` allows, the moved end lies before the start, and `d` removes nothing: `{ 'abc', '' }` with `gg$lvj"_d` under `onemore` leaves both lines.*

*The table above holds for `'virtualedit'` empty. `Implementation/Waves/00007-panes/evidence/t31-close-probes.txt`)*

## Why it is true

These are the two exceptions `:h exclusive` lists for an exclusive motion: one that ends in column 1 has its end moved to the end of the previous line and becomes inclusive, and, when its start was at or before the first non-blank, it becomes linewise (`:h exclusive-linewise`). `:h 'selection'` gives `old` as the value that does not let the cursor past the end of a line. That Vim applies the exclusive-motion rules to a Visual selection only under `old` is the attack review's reading of Vim's condition `(!is_VIsual || *p_sel == 'o')`; the table above is the measurement that the behaviour holds on 0.12.5.

## How it showed up here

T26's Visual Send reads the selection's parts and sends exactly what `"_d` removed (VS5 (b), the user's). The attack review's fuzzer, which ran `'selection'` `old` among its options, found both cases on `08ea516`: `{ 'abc', '', 'def' }` with `gg0lvj` removed `bc` and sent `bc\n`; `{ '  abc', 'x', '' }` with `gg0lvjj` removed `  abc\nx\n` linewise and sent ` abc\nx\n`. The fix round's `removed_region()` (`lua/aineo/send/init.lua:211` on `dev` `3b5f0f7`) applies both rules before `getregionpos()` reads the region; six rows of `tests/test_send_selection.lua` pin it, and `M-old-no-linewise`, `M-old-indent-strict`, `M-old-above-col0` and `M-old-end-kept` die on them.

## Where it applies again

Any plugin that predicts an operator's effect from a Visual selection — sending, yanking or highlighting it — rather than letting the operator act. Only the charwise case was measured; whether a `'selection'` `old` block or a selection ending on an empty line's start under `'virtualedit'` adds more cases was not. *(2026-10-06: under `'virtualedit'` it does, for a charwise selection — the two exceptions above, which the post-merge re-measure of PR #115 found and T31 fixed in PR #120)* The simplest way out is to let the operator remove the text and compare the buffer before and after, as the review's fuzzer did with `nvim_buf_attach()`'s `on_bytes`.
