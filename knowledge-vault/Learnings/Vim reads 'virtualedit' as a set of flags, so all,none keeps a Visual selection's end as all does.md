# Vim reads 'virtualedit' as a set of flags, so all,none keeps a Visual selection's end as all does

**Tags:** #neovim #options #visual-mode #trap
**Discovered:** [[Sessions/2026-10-06 — T31 Selection old]] (the guarantee review of PR #120, finding 1; the bounded correction)
**Applies to:** [[Projects/aineo]]

## The insight

Neovim stores `'virtualedit'` as the string it was given. It does not normalise it. `vim.o.virtualedit` reads back `all,none`, `none,all`, `all,all`, `all,` or `all,NONE` exactly as set. Vim's own behaviour follows the flags those words name, not the string. Under `'selection'` `old`, a charwise selection that ends on an empty line below its start keeps its end only when the operator is virtual. That holds when at least one flag remains once `none` and `NONE` are dropped, and every remaining flag is `all`. So every one of those spellings keeps the end exactly as `all` does. `all,onemore`, `block,all` and `insert,all` move it, as an empty value does. Code that compares the option with the string `all` gets the plain spelling right and every other one wrong.

Measured on Neovim 0.12.5, macOS (`Implementation/Waves/00007-panes/evidence/t31-close-probes.txt`):

| `'virtualedit'` | `{ '  abc', 'x', '' }`, `gg0lvjj"_d` leaves | Neovim reads back |
|---|---|---|
| `''`, `none`, `NONE`, `all,onemore`, `block,all`, `insert,all` | `` (the end moved) | the value as set |
| `all`, `all,all`, `all,`, `all,none`, `none,all`, `all,NONE`, `NONE,all` | ` ` (the end kept) | the value as set |
| global `all`, local `NONE` | `` (moved) | — |
| global `''` or `onemore`, local `all` | ` ` (kept) | — |

`:set virtualedit=none` followed by `:set virtualedit+=all` gives `none,all`. So does `vim.opt.virtualedit:append('all')` after `none`. A user's config can reach such a value without ever typing it.

## Why it is true

`:h 'virtualedit'` calls the option "a comma-separated list of these words" and says: "When combined with other words, "none" is ignored." `NONE` is its "alternative spelling". As a local value, `none` turns virtual editing off even when the global value is set. That Vim tests the flags the words name, not the string, is what the table shows; no Vim source was read for it.

The exact test, that the flags must be `all` alone, is not quoted from the source. The guarantee review inferred it, with `none` masked out, from the measurement, and every row above agrees with it. The table is what holds on 0.12.5.

## How it showed up here

T26's fix round taught `removed_region()` Vim's `'selection'` `old` rule. The post-merge re-measure found that the rule broke under `'virtualedit'` `all`, where Vim keeps the end. Its measured fix tested `vim.o.virtualedit == 'all'`, after measuring nine values. T31 took that fix. T31's guarantee review then tried 22 values Neovim accepts: the 16 subsets of `block`, `insert`, `all` and `onemore`, `none`, `NONE`, `all,all`, `all,`, `all,none` and `none,all`. With five global/local pairs, that is 27 setups by 5 rows. Under `all,all`, `all,`, `all,none` and `none,all`, aineo still moved the end, and a Visual Send wrote a leading space that never left Input. The bounded correction reads the flags: it splits on commas, drops empty entries, `none` and `NONE`, and asks that at least one flag remains and every one is `all`. The code is `lua/aineo/send/init.lua:218–224` on `dev` `03a1345`. Rows for six of the seven spellings above, all but `NONE,all`, pin it in `tests/test_send_selection.lua`, with a local `all` over a global `''`. `M-keep-none`, `M-keep-NONE`, `M-keep-empty`, `M-no-count`, `M-any-all` and `G-all-global` die on them.

## Where it applies again

The same trap applies to any comma-list option a plugin tests by string comparison, such as `'clipboard'`, `'completeopt'` or `'diffopt'`. Split the value, drop empty entries and the documented no-op words, and test the set. Read the value in force, `vim.o`, not the global one, `vim.go`: for a global-local option such as `'virtualedit'`, a local value overrides the global one, and `G-all-global`, which read `vim.go`, sent the wrong text under a local `all`. Only `'virtualedit'` was measured here. `:h` names no ignored word for those three; what each accepts was not measured.
