# 2026-10-06 — T31 Selection old

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `bugfix/t31-selection-old` · **Pull request:** into `dev` (a small fix, orchestrate §3)

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D20 (with its 2026-10-05 and 2026-10-06 annotations: VS5 (b), the message is exactly the text `"_d` removes), T31; D26, D29
- Wave plan: `Implementation/Waves/00007-panes/plan.md` › *Packet T31 — 2026-10-06*; brief: `brief-t31-selection-old.md` (its F1–F5)
- Rests on: [[Sessions/2026-10-06 — T26 Visual Send]] (the fix round's `removed_region()`, its `gv` pin and its NUL pin), and the post-merge re-measure of PR #115 (the orchestrator's scratch, `remeasure115/remeasure-t26.md`, its cases and `remeasure-fix.diff`)

## Context

T31 corrects what the post-merge re-measure of T26's fix round found on `dev` `3b5f0f7` (v0.2.13): under `'selection'` old, `removed_region()` moved a selection's end where Vim's `"_d` does not, so a Visual Send wrote text that never left Input (F1); the empty-selection check joined the parts differently from the message (F2); two behaviours were unpinned (F3, F5); and an invalid byte at a block's edge is a limit to name, not fix (F4, the orchestrator's reading). Each fix was redone red-first from the re-measure's failing inputs, not copied from its diff.

## What was done

- **`removed_region()`** (`lua/aineo/send/init.lua`):
  - keeps the selection's end when Vim's operator is virtual (`operator_is_virtual`): when `'virtualedit'`'s flags, `none` and `NONE` dropped, are at least one and every one is `all`. Of the nine values the re-measure measured (`''`, `all`, `all,onemore`, `block,all`, `insert,all`, `block`, `onemore`, `insert`, `none`) only `all` keeps the end; the guarantee review found `all,all`, `all,`, `all,none` and `none,all` keep it too, and the *Correction* below reads the flags. A row pins `all,onemore` moving it, so a reading of "contains `all`" dies;
  - returns no region when the start lies past the end Vim moves the selection to (a start past its line's end on the line directly above the empty line: `"_d` removes nothing). `visual_selection()` reads that as no parts, and the Send is refused as empty.
  - Its docstring states the rule with both exceptions, and the optional returns.
- **The empty check** in `send_selection()` joins the parts with line feeds, as `removed_text()` joins them for the message. `send_selection()`'s docstring ("the text it would send holds nothing but white space") is now exact and was left as it is.
- **The help** (`doc/aineo.txt`): the *Visual Send* sentence on `'selection'` old now says that a selection starting past the end of the line above removes and sends nothing, and that `'virtualedit'` holding `all` and no other flag but `none` keeps the end (*Correction*). LIMITS gains *A block's edge on an invalid byte*: `"_d` removes the invalid byte and the combining mark or joiner after it as one character; the Visual Send sends the byte when the block ends on it, the mark when the block starts there.
- **The tests** (`tests/test_send_selection.lua`, 52 → 60 cases): three `SELECTIONS` rows (A2 under `all`, A2's lines under `all,onemore`, N1); a parametrized refusal set under `'selection'` old (A1 under `all`, B1 under `onemore`); F2's selection; F3's backwards selection after a failed write, `gv` and both ends; F4's limit pinned as aineo behaves. `tests/test_entry_send_selection.lua` was not changed: its cases are the doors, and the helper's own Visual mapping reaches `send_selection()` as `\s` does.

## Unit list (stated before the first test)

1. A2 — `{ '  abc', 'x', '' }`, `gg0lvjj`, old + all: Input `{ ' ' }`, writes ` abc\nx\n`.
2. A1 — `{ 'é', '' }`, `1G0llllvw`, old + all: refused as empty, Input kept.
3. B1 — `{ 'abc', '' }`, `gg$lvj`, old + onemore: refused as empty, Input kept.
4. F2 — `{ '\194', '\133' }`, `ggVj`: writes `\194\n\133`.
5. F3 — `{ 'abc def', 'ghi' }`, `jvgg0w`, the write fails, then `gv`: both ends and the text back.
6. F5 (N1) — `{ 'a👍🏽', '\0\204\129' }`, `1G0lllvjoo`: Input `{ 'a\204\129' }`, writes `👍🏽\n`.
7. F4 — `{ 'abcdef', 'a\255\204\129b', 'abcdef' }`, `gg0l<C-v>jj`: writes `b\n\255\nb`, Input `{ 'acdef', 'a   b', 'acdef' }`.

Added after unit 7, before the mutants: A2's lines under `all,onemore` (Input `{ '' }`, writes `  abc\nx\n`), so that the "exactly" is pinned.

## Seen red, arrived green

Every run on Neovim 0.12.5, `make test_file FILE=tests/test_send_selection.lua`.

| Case | Status | Evidence |
|---|---|---|
| A2 row (`virtualedit=all, which keep its end`) | **red** | `"writes"->1, left = "\27[200~  abc\nx\n\27[201~\r", right = "\27[200~ abc\nx\n\27[201~\r"` |
| B1 row (`virtualedit=onemore … which removes nothing`) | **red** | `"messages"->1, left = nil`; left's writes `{ "\27[200~c\27[201~\r" }` with Input `{ "abc", "" }` |
| F2 (`… a control character only across its line break`) | **red** | `"input"->1, left = "\194"`; refused with "the selection is empty" |
| A1 row (`virtualedit=all, from past a line's end …`) | green | spent by unit 1 and, as measured, by unit 3 too: its start lies past its line's end on the line above. Killed only by both edits at once, `M-drop-all-and-no-nil` |
| A2 under `all,onemore` | green | pins unit 1's "exactly"; killed by `M-find-all` |
| F3 (`puts back both ends of a selection made backwards …`) | green | the put-back held; the pin was missing. Killed by `R-gv-no-start` |
| N1 (`charwise through a NUL that a combining mark follows …`) | green | the NUL-as-line-feed choice held; the pin was missing. Killed by `R-nul-x` |
| F4 (`writes an invalid byte a block's edge ends on …, a named limit`) | green | pins the limit as it is. Killed by `M-in-block-end` |

## Mutants (on the final tree `efe9a31`, each from a copy of the file, on a narrowed copy of the test file, 0.12.5)

Narrowed copies: `.tests/t31-region.lua` (the `SELECTIONS` rows and the refusal rows under `'selection'` old, 30 cases), `.tests/t31-empty.lua` (control bytes, NUL, F2, F4 and the white-space refusals, 6 cases), `.tests/t31-gv.lua` (the failed-write group, 3 cases). Each green unmutated. Every restore printed an empty `git status` for the file.

| Mutant | Literal edit | Run on | Result |
|---|---|---|---|
| M-drop-all | `or not ends_on_empty_line or operator_is_virtual then` → `or not ends_on_empty_line then` | region | killed by assertion (A2: `"writes"->1`); A1 survives it alone |
| M-find-all | `vim.o.virtualedit == 'all'` → `vim.o.virtualedit:find('all') ~= nil` | region | killed by assertion (`all,onemore` row: `"writes"->1`) |
| M-no-nil | delete `if first[2] == above and first[3] > above_end then return nil end` | region | killed by assertion (B1: `"messages"->1`) |
| M-drop-all-and-no-nil | both edits above | region | killed by assertion, 3 cases (A2, A1: `"input"->2`, B1) |
| M-concat-nothing | `table.concat(selection.parts, '\n')` → `table.concat(selection.parts)` in the empty check | empty | killed by assertion (F2: `"input"->1`) |
| R-gv-no-start | delete `vim.fn.setpos("'<", from)` | gv | killed by assertion (F3: `"selected"->1, left = "d", right = "def"`) |
| R-nul-x | `line:gsub('%z', '\n')` → `line:gsub('%z', 'x')` in `character_end()` | region | killed by assertion (N1: `"writes"->1`) |
| M-in-block-end | the re-measure's in-block `character_end(line, byte, in_block)` and its call with `mode == '\22'` | empty | killed by assertion (F4: `"writes"->1`, the mark sent) |

## Suites (0.12.5)

- `tests/test_send_selection.lua`: 60 cases, Fails (0).
- `tests/test_doc.lua`: 44 cases, Fails (0) (the help changed).
- Whole suite on `efe9a31` (`make test`): 1800 cases (the baseline's 1792 and this packet's 8), Fails (0), exit 0. The runner printed no duration. The pushed tree differs from it by this note alone.
- `make lint`: StyLua clean; selene 0 errors, 0 warnings.

## Task lines

The wave holds its marks. For the knowledge pass:

- **T31** — done — PR into `dev`, wave 7 (F1: `removed_region()` keeps the end when `'virtualedit'`'s flags, `none` and `NONE` dropped, are at least one and all `all`, and gives no region when the start lies past the moved end; F2: the empty check joins with line feeds; F3 and F5 pinned; F4 named in LIMITS and pinned, not fixed; 52 → 60 cases in `tests/test_send_selection.lua`)

## Open threads

- ~~**The T26 session note's fix-round reading on `'selection'` old** is false under `'virtualedit'` all and onemore. This packet's boundary is its own note; the knowledge pass corrects that reading or points it here.~~ — closed by T31's knowledge pass: that reading carries a dated correction pointing here.
- **`character_end()`'s docstring** says it counts as one character what `"_d` removes whole; for an invalid byte that a combining mark follows, a block's `"_d` joins them and `character_end()` does not. LIMITS now names it; the docstring was outside the brief's boundary (it names `removed_region()` and the empty check) and is left for a follow-up.
- **F4's residue under `'virtualedit'` all** (the re-measure's 2 in 60,000). The first, a truncated sequence before a mark at a block's edge, falls under LIMITS' *A block's edge on an invalid byte*. The second, a charwise start with a coladd as wide as a 4-cell `<c3>`, has no block, mark or joiner and is not covered by that entry; the *Correction* names it in LIMITS of its own. Neither is pinned; both predate T31.

## Correction — 2026-10-06, after the guarantee review of PR #120

The guarantee review (the orchestrator's scratch, `guarantee120/guarantee-t31.md`, on `e3dd139`) confirmed four findings; this correction takes each as briefed, red-first from the review's failing inputs.

- **Finding 1 — Vim reads `'virtualedit'` as flags.** Vim's operator keeps the end when the effective flags, `none` and `NONE` dropped, are at least one and every one is `all`; aineo compared the string to `all`. `removed_region()` now splits the option on commas (empty entries trimmed), drops `none` and `NONE`, and asks that what remains is non-empty and all `all` — the review's measured fix. Five `SELECTIONS` rows, each expected value plain Neovim 0.12.5's own `"_d` on the same lines and keys (`t31cor-truth.lua`): `all,all`, `all,`, `all,none`, `none,all` built by `:set virtualedit=none | set virtualedit+=all`, and `all,NONE`. The last is beyond the review's four spellings: the rule drops `NONE`, so its branch needs a row. The rows gain a seventh field, Ex commands run in Input's window (`run_commands()`), for a value an option table cannot give. The docstring, the help's "`all` alone" and this note's "the only value" now state the rule as Vim reads it.
- **Finding 2 — K1:** a row under a global `''` and `setlocal virtualedit=all` in Input's window, which keeps the end.
- **Finding 3 — K2:** `{ 'abc', '' }`, `gg$vj`, old, `''`, which removes `c`.
- **Finding 4 — records only.** The charwise start whose coladd is as wide as a 4-cell `<c3>` (no block, mark or joiner) was not covered by LIMITS; reproduced on this branch with the review's `main-wide-12` input (`3G0lllllVipiwe$h`, old, `all`: `"_d` removes from `\195`, the Send writes from `x`). LIMITS now names it as *A characterwise start past an invalid byte*, beside F4's entry. Not fixed, not pinned; it predates T31.

### Seen red, arrived green

`make test_file FILE=tests/test_send_selection.lua`, Neovim 0.12.5. Every red failed by assertion with `"writes"->1, left = "\27[200~  abc\nx\n\27[201~\r", right = "\27[200~ abc\nx\n\27[201~\r"`.

| Row | Status | Evidence |
|---|---|---|
| `all,all` | **red** on the head's code | made green by splitting on commas, every flag `all` |
| `all,` | **red** on unit 1's code | made green by `trimempty` and `#flags > 0` |
| `all,none` | **red** on unit 2's code | made green by dropping `none` |
| `none,all` (`:set +=`) | green on arrival, spent by `all,none`'s filter | red on the head's code (below); killed by `M-keep-none` |
| `all,NONE` | **red** on unit 3's code | made green by dropping `NONE` |
| K1 (local `all`) | green, a pin | passes on the head; killed by `G-all-global` |
| K2 (`gg$vj`) | green, a pin | passes on the head; killed by `G-nil-at-end` |

**On the head's code:** the final test file run against `e3dd139`'s `lua/aineo/send/init.lua` (copied in and back) fails 5 — `all,all`, `all,`, `all,none`, `none,all`, `all,NONE` — each by the assertion above; K1 and K2 pass.

### Mutants (on the final file, each from a copy, one at a time, 0.12.5)

Narrowed copy: `.tests/t31cor-region.lua`, the `SELECTIONS` group alone, 35 cases, green unmutated.

| Mutant | Literal edit | Run on | Result |
|---|---|---|---|
| G-all-global | `vim.split(vim.o.virtualedit,` → `vim.split(vim.go.virtualedit,` | region | killed by assertion (K1: `"writes"->1`) |
| G-nil-at-end | `first[3] > above_end` → `first[3] >= above_end` | region | killed by assertion (K2: `"input"->1, left = "abc", right = "ab"`) |
| M-keep-none | `return flag ~= 'none' and flag ~= 'NONE'` → `return flag ~= 'NONE'` | region | killed by assertion (`all,none`, `none,all`) |
| M-keep-NONE | the same → `return flag ~= 'none'` | region | killed by assertion (`all,NONE`) |
| M-keep-empty | `{ trimempty = true }` → `{ trimempty = false }` | region | killed by assertion (`all,`) |
| M-no-count | delete `#flags > 0` and its `and` | region | killed by assertion, 7 cases (the `'selection'` old rows under `''`) |
| M-any-all | `vim.iter(flags):all(` → `vim.iter(flags):any(` | region | killed by assertion (`all,onemore`) |
| M-drop-all | `or not ends_on_empty_line or operator_is_virtual then` → `or not ends_on_empty_line then` | region | killed by assertion, 7 cases |
| M-no-nil | delete `if first[2] == above and first[3] > above_end then return nil end` | region; then the whole file | survives the region group (it holds no refusal); killed in the whole file by assertion (B1: `"messages"->1`) |
| T-no-commands (test side) | delete `run_commands(commands)` from the case | region | killed by assertion, 2 cases (`none,all`, K1: `"input"->1, left = "", right = " "`) |

T31's other mutants (`M-concat-nothing`, `R-gv-no-start`, `R-nul-x`, `M-in-block-end`) edit code this correction did not touch, and their test groups are unchanged; they were not re-run.

### Suites (0.12.5)

- `tests/test_send_selection.lua`: 67 cases (60 + 7), Fails (0).
- `tests/test_doc.lua`: 44 cases, Fails (0).
- `make lint`: StyLua clean; selene 0 errors, 0 warnings.
- Whole suite (`make test`) on the tree pushed: 1807 cases (T31's 1800 and these 7), 58 groups, Fails (0), exit 0, 232 s by the wall clock.

## Commits

Recorded after the merge, by T31's knowledge pass. PR #120 merged by rebase on 2026-10-06 (19:55 UTC; 21:55 CEST); `dev` `03a1345`, whose tree is the tree of the orchestrator's verified head `3fc1b11` (`git diff --stat 3fc1b11 03a1345` prints nothing). Released in `v0.2.14` (PR #121, squash-merged into `main` as `ebfe71c`, whose tree is `dev` `03a1345`'s).

The first two are the packet's; the last two are the bounded correction's, after the guarantee review.

| Branch | `dev` | Subject |
|---|---|---|
| `efe9a31` | `65679f4` | Send only what leaves Input under 'selection' old |
| `e3dd139` | `9bf8a36` | Record T31's session note: reds, mutants and suite |
| `acd3c8f` | `039602d` | Read 'virtualedit' as Vim's flag set in a Visual Send |
| `3fc1b11` | `03a1345` | Pin the window's 'virtualedit' and the no-region edge in Visual Send |
