# 2026-10-06 — T26 Visual Send

**Author:** Mathias Santos de Brito, with Claude — implementer agents (`neovim-claude-code-integrator`): a first agent, interrupted twice, and a second that continued its work
**Branch:** `feature/t26-visual-send` · **Pull request:** into `dev` (a regular packet)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (D20 with its 2026-10-05 annotation; C4, D1, C1, C7, D17, D18; D26, D29)
- [[Implementation/Waves/00007-panes/plan]] › *Packet T26 — 2026-10-06* (its verification mutants S1–S20) and *Decisions for the user*; its brief `brief-t26-visual-send.md` with its *Amendment — 2026-10-05* (the user's answers to VS1–VS5 and to D20's undo gaps); the brief review `brief-review-t25-t26.md` › *T26*
- `Implementation/Waves/00007-panes/evidence/t26-probes.txt` (U, D, V, V2): the measurement the pins reproduce
- [[Sessions/2026-10-05 — T24 Panes]] — the last packet to add a `<Plug>` mapping, a prefix key, a health line and help entries

## Context

**Goal:** T26, under D20 and C4: `\s` in Visual mode in Input sends the selection alone, as one message, and removes it; a refused Send removes nothing; `u` in Input brings back what a Send removed. The user's answers of 2026-10-05: VS1 (a), VS2 (a), VS3 (a), VS4 (a), VS5 (b), and the undo gaps "as you propose" — named in the help, pinned, not worked around.

**The interruption, as a fact.** The packet's first agent was interrupted twice on 2026-10-06: the host slept, then the user restarted Neovim. It had pushed three commits (`14800ee`, `f89f3d3`, `55e37d7` on the branch) and left undo cases uncommitted, saved by the orchestrator as a patch. A second agent was dispatched to continue from there. It found no red log among the first agent's scratch, so it rebuilt the first agent's reds commit by commit (*Red and green*). The patch held VS-D's undo cases, not the ragged-block unit the dispatch message named: that unit was already in `14800ee`.

## What was done

- **The send home** (`lua/aineo/send/init.lua`, the first agent): `send_selection()` reads the selection's part of each line with `getregionpos()` from `getpos('v')` and `getpos('.')`, not from `'<` and `'>`, which still hold the previous selection inside an `x` mapping. A `$` block is read to each line's own end. A line the block lies past gives an empty part. A double-width character the block cuts is read whole. A charwise selection past its last line's end carries that line break, counted from the lines the removal joined. It removes the selection with Vim's own `"_d`, then writes exactly what was removed (VS5 (b)), without control bytes, as one bracketed paste and Enter in one write. It refuses, removing nothing and ending Visual mode with the selection kept for `gv` (VS4 (a)), when the current buffer is not Input (VS1 (a); with no Input at all too, the orchestrator's reading T26-9), when the selection holds only white space, and when Claude Code is not ready. When the write fails it puts Input back and raises, as `send()` does (`write_or_put_back()`, shared by both).
- **The entry point** (`plugin/aineo.lua`, the second agent): `VISUAL_ACTIONS` beside `ACTIONS`, and `<Plug>(aineo-send)` defined in Visual mode (`x`) too (VS2 (a)). `has_global_mapping(mode, keys)` reads the mode it maps, and `map_unless_mapped()` serves both loops. `map_prefix()` maps `\s` in Visual mode after the Normal keys, and nothing when `prefix` is `false`. `:Aineo` keeps taking no range (VS3 (a)).
- **The health check** (`lua/aineo/health.lua`): `PREFIX_KEYS` rows carry a mode, and the Visual `\s` row goes last. `global_mapping(mode, keys)` and `check_prefix_key()` read that mode, and the line says `in Visual mode` (`IN_MODE`).
- **The help** (`doc/aineo.txt`), corrected where T26 made it false or incomplete: section 1's keys paragraph; section 4's `:Aineo-send` (no range, E481); section 5's `<Plug>` paragraph and example (`{ 'n', 'x' }`), the `<Plug>(aineo-send)` entry, the *Prefix keys* list with the new `*aineo-v_\s*`, Select mode, and the paragraph on keys the user mapped (per mode); section 7, *Visual Send* and *Undo* (the old sentence "`u` in Input brings the text back" folded into it); section 10's *Prefix mappings*; section 11, *Undo after a Send*, naming the three gaps (VS-H).
- **The tests:**
  - `tests/test_send_selection.lua` (33 cases, 88 s on 0.12.5): every family of VS-A, pinned against Input's lines before and after; the registers, the cursor, and the last selection; the refusals (VS-B), with VS4's mode; the failed write (VS-C) and its undo block; `u` after a Visual Send of each kind; the `'undolevels'` gaps.
  - `tests/test_entry_send_selection.lua` (8 cases, 11 s), new, in a fixture repository of its own (`selection-entry`): the `\s` and `<Plug>` doors; `:'<,'>Aineo send` giving E481; `\s` outside Input, in another buffer and with no Input at all; and `u` after a Send typed from the Report's window (U2), under the changes pane (U3), and after the draft was restored (D2).
  - `tests/test_send.lua`: the whole-Input undo case (U1), pinned for the first time.
  - The pins that moved: `tests/test_plugin.lua` (`x <Plug>(aineo-send)`, `x \s`); `tests/test_entry_prefix.lua` (a mode column; the user's own mapping per mode); `tests/test_health.lua`, where four full lists and the not-mapped list gain the Visual line, two counts go 8 → 9, nine indexes go `[9]` → `[10]`, and one case is new; `tests/helpers/health.lua` (keys counted as `<mode> <keys>`, T26-4); `tests/test_doc.lua` (`aineo-v_\s` in `TAGS`; `TAGS_THE_PLUGIN_DEFINES` derives Visual-mode tags).

## Unit list (stated before the first test)

The first agent's units, as its commits and their tests show them:
1. VS-A, each kind against what `"_d` removes: charwise, linewise, blockwise; a `$` block on a shorter line; a ragged block two columns past; a line break past a line's end (`14800ee`).
2. VS-B, each refusal, removing nothing, VS4's mode; VS-A's remaining families, the registers, the cursor, and the last selection; control bytes; the double-width cut (`f89f3d3`).
3. VS-C, the failed write: put back, raise, the one undo block; an Input that cannot be changed (`55e37d7`).

The second agent's, stated before its first test:
4. VS-D: the whole-Input Send undone (U1); each kind of Visual Send undone; the `'undolevels'` 0 and -1 gaps (the first agent's uncommitted cases).
5. VS-E, `<Plug>(aineo-send)` in Visual mode sends the selection (VS2 (a)), with `tests/test_plugin.lua`'s list.
6. VS-E, `\s` mapped in Visual mode once the editor has started: by default, from `vim.g.aineo`, from `setup()`, late, and not when `prefix` is `false`.
7. VS-E, a user's own Visual `\s` stays; a user's own `\s` in one mode does not keep aineo from mapping the other.
8. VS-E, `\s` typed in Visual mode in Input; `:'<,'>Aineo send` stays E481; outside Input; with no Input at all.
9. VS-D at the entry point: U2, U3 and D2.
10. VS-F: the Visual row, counted as a key of its own by the helpers, last in the section.
11. VS-F: a user's own Visual `\s` warned of, saying Visual mode.
12. VS-G: the `aineo-v_\s` tag, and tags derived from Visual-mode mappings.
13. VS-G, VS-H: the help's prose.

## Red and green

**The first agent's reds, rebuilt by the second agent** (each commit's test file and helper over its parent's send home, on 0.12.5; `t26-red-*.txt` in the second agent's scratch):
- `14800ee`'s 6 cases over `origin/dev`'s send home: **6 red**, each an assertion on Input's lines (`send_selection` missing; the mapping's `pcall` keeps the error).
- `f89f3d3`'s 25 cases over `14800ee`'s: **9 red** by assertion: the double-width cut, control bytes, the white-space refusal, the three not-ready refusals, both outside-Input refusals, and VS4's mode. **10 arrived green**, already given by `14800ee`'s read: a ragged block one column past, a tab cut by a block, `virtualedit` `all` and `block`, a multibyte charwise cut, `selection=exclusive`, all of Input, the registers, the cursor, and the last selection. Each is killed below.
- `55e37d7`'s 28 cases over `f89f3d3`'s: **2 red** by assertion (put back and raise; the undo block, `after_failure` `abc ` against `abc def`); **1 arrived green**: an Input that cannot be changed raises E21 (`:normal! "_d` already raised it). Killed below by `M-e21-swallowed`.

**The second agent's:**
- **Seen red, each with its message:**
  - `<Plug>(aineo-send)` door: `input->1, left = "end)"`. The unmapped `<Plug>` let the rest of the keys run as Visual commands.
  - The four `x` rows of `the prefix` (default, `vim.g.aineo`, `setup()`, late): `different string length` / `different values`.
  - `tests/test_plugin.lua`'s list: `keymaps->18, left = "x \\s", right = nil`.
  - The health check's *… no more and no fewer*: `key 9, left = nil, right = "x \\s"`, on the helper change before the row existed.
  - `tests/test_doc.lua`'s tag pair: `aineo-v_\s` missing from the help.
- **Arrived green, each with its reason and the mutant that kills it (run, below):**
  - The undo cases (U1, each kind, the `'undolevels'` 0 and -1 gaps, U2, U3, D2): green by nature, since they pin Neovim's undo as the orchestrator measured it. Killed by S7, `M-visual-undo` and `M-undolevels-worked-around`.
  - `the prefix` `x` row with `prefix = false`, and the user's own Visual `\s` stays: green before any code, since nothing mapped the Visual key. Killed by `M-visual-prefix-before-false` and S8-mirror. The own-Visual-mapping row is a weak pin under S8 (see *Mutants*).
  - The user's own `\s` in one mode, aineo's in the other: spent by unit 6's mode-aware check. Killed by S8 and S8-mirror.
  - The `\s` door, `:'<,'>Aineo send`, outside Input, with no Input: spent by unit 6 and by the send home's refusals (Neovim's own E481). Killed by S2, S13–S17, `M-no-input-own-reason` and `M-no-visual-plug`.
  - The health check's warning for a user's Visual `\s`: spent by unit 10's mode-aware read. Killed by S9.
  - `tests/test_plugin.lua`'s `x <Plug>(aineo-send)` line was added after its code. Killed by `M-no-visual-plug`.
- **A deviation, said:** in unit 6 the second agent first wrote the Visual key's check as Normal mode alone (the minimum), saw it fail (aineo's own Normal `\s`, mapped a moment before, kept the Visual key from being mapped), and then made the check read its mode in the same unit, before the per-mode case existed.

## Mutants

Each is a literal edit in `.claude/local/orchestrator/t26-mutants.py` (the second agent's scratch). Each was applied alone to a pristine copy of its file, run with `make test_file` on the files named, then the file was restored. All ran on Neovim 0.12.5 against the packet's final code. The outputs are in `t26-mutants.txt`. **Every mutant was killed by assertion; none crashed, none survived.**

| Mutant | Literal edit (abridged; the file holds it whole) | Killed by |
|---|---|---|
| S1 sent, not removed | `"_d` line removed from `send_selection()` | 18 cases, `tests/test_send_selection.lua` |
| S2 whole Input from Visual | `VISUAL_ACTIONS.send` runs `send()` | 4, `tests/test_entry_send_selection.lua` |
| S3 removed before refusing | the `"_d` moved above the status check | 4: the three not-ready refusals, VS4's mode |
| S4 previous selection | `getpos("'<")`, `getpos("'>")` | 28, among them *the selection made last* |
| S5 block as characters | `{ type = 'v' }` | 11, among them every blockwise case |
| S6 one write per line | the write split on line feeds | 13, among them every multi-line case |
| S7 Send undo cannot reach | `send()` clears under `undolevels = -1` | `tests/test_send.lua`'s U1; U2, U3, D2 |
| S8 Normal for the Visual key | `has_global_mapping('n', keys)` | 5: the four `x` rows; *own `\s` in Normal, aineo's in Visual* |
| S9 health reads Normal | `global_mapping('n', …)` | 2: *warn of a key the user mapped*; *… a Visual-mode key …* |
| S10 a register written | `ygv` before the removal | *leaves every register as it was* |
| S11 `$` block read short | `parts = getregion(getpos('v'), getpos('.'), …)` | 7, among them the `$` block on a shorter line |
| S12 the gap worked around | `let &g:undolevels = &g:undolevels` before the put-back | *leaves one undo block …* |
| S13 VS1 (b) | Visual `\s` mapped buffer-locally in Input from a `BufEnter` | 3: the `\s` door; both outside-Input cases |
| S14 VS1 (c) | outside Input, the selection written, nothing removed | 2: both outside-Input cases |
| S15 VS2 (b) | `<Plug>(aineo-send-selection)` in Visual mode | 4: both doors; both outside-Input cases |
| S16 VS3 (b) | `range = true`; a range sends those lines linewise | *takes no range …* (E481) |
| S17 VS3 (c) | `range = true`; a range refused by aineo's own error | *takes no range …* (E481) |
| S18 VS4 (b) | no `<Esc>` in `refuse_selection()` | *ends Visual mode, gv …*; both outside-Input cases |
| S19 VS5 (a) | the message is the `"z` yank | 11, among them the ragged, tab and `virtualedit` cases |
| S20 VS5 (c) | `h` before `"_d` past a line's end; no line break appended | *charwise past a line's end …* |
| `M-visual-undo` | the `"_d` run under `undolevels = -1` | 4: each kind's `u`; the undo block |
| `M-undolevels-worked-around` | `send()` sets `undolevels = 1000` before clearing | 2: the `'undolevels'` 0 and -1 gaps |
| S8-mirror | `has_global_mapping('x', keys)` | 12, among them the eight Normal own-mapping rows and both per-mode rows |
| `M-visual-prefix-before-false` | the Visual loop above the `false` guard | *maps nothing … when it is false* (`x` row) |
| `M-no-visual-plug` | the Visual `<Plug>` named `<Plug>(aineo-unused)` | `tests/test_plugin.lua`'s list; 4 entry cases |
| `M-no-input-own-reason` | no Input refused as `no_input` | *removes nothing with no Input at all …* |
| `M-whole-double-width` | `last[3]` without `vim.str_utf_end()` | the double-width block case |
| `M-short-line-not-empty` | no empty part for a line the block lies past | both ragged cases; the blockwise `u` |
| `M-exclusive-ignored` | `getregionpos(…, { type = mode, exclusive = false })` | the `selection=exclusive` case |
| `M-cursor-moved` | the cursor set to `{ 1, 0 }` after the removal | *leaves the cursor where Vim's own "_d leaves it* |
| `M-e21-swallowed` | the `"_d` run under `pcall` | *… cannot be changed: writes nothing and raises* |
| `M-health-visual-row-missing` | the Visual row removed from health's `PREFIX_KEYS` | 18, among them *… no more and no fewer* |

**32 mutants, 32 killed by assertion.** Of the first agent's ten arrived-green cases, the tab and both `virtualedit` cases are killed by S11 and S19, the ragged one-column case by `M-short-line-not-empty`, the exclusive case by `M-exclusive-ignored`, the cursor case by `M-cursor-moved`, the registers case by S10, the last-selection case by S4, and all of Input by S1, S4, S6 and S19. The multibyte charwise case (`wörl`, ending on an ASCII letter) is killed only by mutants that break every case (S1, S4, S6). `M-whole-double-width` leaves it green, and it would leave green a selection ending on `ö` too. The second agent tried that case (`gg0fwvl`, sending `wö`): it passed, and `M-whole-double-width` survived it. A probe then showed why (`t26-spike-regionpos.lua`, `nvim --clean`, 0.12.5): `getregionpos()` ends a selection on its last character's last byte, charwise and blockwise alike (`ö` at byte 10, `漢` at byte 4). The mutant is therefore equivalent wherever the selection holds its last character whole. `vim.str_utf_end()` matters only where a block's edge cuts a double-width character, which the double-width case pins. The extra case was not kept, so that the counts above stay measured on the tree shipped.

**S8, against the brief's wording.** The plan says VS-E's own-mapping case must kill S8. It does not: under S8 the Visual key reads Normal mode, finds aineo's own Normal `\s`, and is never mapped, so a user's own Visual `\s` stays either way. S8 is killed instead by the four `x` rows of `the prefix` and by *own `\s` in Normal mode, aineo's in Visual*. A user's own Visual `\s` overwritten is S8-mirror's failure, and that case kills it.

## Verification

On the packet's final code (`eecc5cf`, the session note then uncommitted), Neovim 0.12.5:
- `make test`: **1770 cases, `Fails (0)`**, 220 s, exit 0. The baseline at `origin/dev` `893a427` was 1718. The 52 new cases are 33 in `tests/test_send_selection.lua`, 8 in `tests/test_entry_send_selection.lua`, 1 in `tests/test_send.lua`, 8 in `tests/test_entry_prefix.lua`, 1 in `tests/test_health.lua` and 1 in `tests/test_doc.lua`. `tests/test_entry_guard.lua` runs inside it.
- `make lint`: StyLua clean; selene 0 errors, 0 warnings.
- The deep-require check (modularity §1) prints only lines inside their own homes; T26 adds none.
- Run times of the new files: `tests/test_send_selection.lua` 88 s, `tests/test_entry_send_selection.lua` 11 s. No case waits a fixed delay.

## Decisions & reasoning

- **VS1–VS5, the user's**, each built as the amendment records it: VS1 (a), VS2 (a), VS3 (a), VS4 (a), VS5 (b). The undo gaps are named in the help, pinned, and not worked around.
- **Visual mode is `x`.** Select mode, where typed characters replace the selection, keeps `\s` as text. The help says so.
- **One table for Visual actions** (`VISUAL_ACTIONS`) beside `ACTIONS`, read by both the `<Plug>` loop and `map_prefix()`, rather than a second `PREFIX_KEYS`: the Visual key reuses its action's keys.
- **The health line's wording**, the second agent's: `\s in Visual mode runs <Plug>(aineo-send)`, and `\s in Visual mode is not mapped`. The helpers count a line that says Visual mode as `x`, and any other as `n`.

## Readings for the MVP review

- "In Input" is Input as the current buffer, in whichever window (the orchestrator's reading).
- Outside Input, with or without an Input, the message is VS1 (a)'s: `aineo: nothing sent — Visual Send works in Input only`. The selection holding only white space says `aineo: nothing sent — the selection is empty`.
- A tab or a double-width character a block cuts: `"_d` removes it and puts spaces for its part outside the block, and the message holds it whole, without those spaces (the orchestrator's reading of "exactly the text removed").
- The help's *Visual Send* and *Undo* paragraphs are the second agent's words. *LIMITS* › *Undo after a Send* names the three gaps in the user's terms.

## Task lines

The wave holds its marks (rule 6). The line T26 would take:

- [X] T26 — Visual Send (D20, C4): `\s` and `<Plug>(aineo-send)` in Visual mode in Input send the selection alone, exactly the text `"_d` removes, as one paste and Enter, and remove it; a refused Send removes nothing and ends Visual mode; `u` brings back what every Send removed, pinned, with the failed-write and `'undolevels'` gaps named in the help; VS1–VS5 as the user answered — regular.

## Limits

- What Claude Code makes of a message ending in a line feed (a charwise selection past its last line's end) was not measured; no other Send ends in one.
- `tests/test_send_selection.lua` takes 88 s on 0.12.5, since each case starts the fake Claude Code. It is among the suite's longer files.

## Open threads

- None from the gaps: each is the user's, as answered on 2026-10-05.
- S8 is not killed by the case the plan names (see *Mutants*). It is killed by others, and the plan's wording is the orchestrator's to correct.

## Commits

Recorded after the merge.
