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
  - keeps the selection's end when `'virtualedit'` is exactly `all` (`operator_is_virtual`). That is the only value under which Vim's operator is virtual (the re-measure measured `''`, `all`, `all,onemore`, `block,all`, `insert,all`, `block`, `onemore`, `insert`, `none`; only exactly `all` keeps the end). A row pins `all,onemore` moving it, so a reading of "contains `all`" dies;
  - returns no region when the start lies past the end Vim moves the selection to (a start past its line's end on the line directly above the empty line: `"_d` removes nothing). `visual_selection()` reads that as no parts, and the Send is refused as empty.
  - Its docstring states the rule with both exceptions, and the optional returns.
- **The empty check** in `send_selection()` joins the parts with line feeds, as `removed_text()` joins them for the message. `send_selection()`'s docstring ("the text it would send holds nothing but white space") is now exact and was left as it is.
- **The help** (`doc/aineo.txt`): the *Visual Send* sentence on `'selection'` old now says that a selection starting past the end of the line above removes and sends nothing, and that `'virtualedit'` `all` alone keeps the end. LIMITS gains *A block's edge on an invalid byte*: `"_d` removes the invalid byte and the combining mark or joiner after it as one character; the Visual Send sends the byte when the block ends on it, the mark when the block starts there.
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

- **T31** — done — PR into `dev`, wave 7 (F1: `removed_region()` keeps the end under `'virtualedit'` exactly `all`, and gives no region when the start lies past the moved end; F2: the empty check joins with line feeds; F3 and F5 pinned; F4 named in LIMITS and pinned, not fixed; 52 → 60 cases in `tests/test_send_selection.lua`)

## Open threads

- **The T26 session note's fix-round reading on `'selection'` old** is false under `'virtualedit'` all and onemore. This packet's boundary is its own note; the knowledge pass corrects that reading or points it here.
- **`character_end()`'s docstring** says it counts as one character what `"_d` removes whole; for an invalid byte that a combining mark follows, a block's `"_d` joins them and `character_end()` does not. LIMITS now names it; the docstring was outside the brief's boundary (it names `removed_region()` and the empty check) and is left for a follow-up.
- **F4's residue under `'virtualedit'` all** (the re-measure's 2 in 60,000: a truncated sequence before a mark, a coladd inside a 4-cell `<c3>`) falls under the same LIMITS entry's invalid bytes; not pinned separately.

## Commits

Recorded after the merge.
