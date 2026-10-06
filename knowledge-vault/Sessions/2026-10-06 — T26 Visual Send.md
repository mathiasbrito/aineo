# 2026-10-06 — T26 Visual Send

**Author:** Mathias Santos de Brito, with Claude — implementer agents (`neovim-claude-code-integrator`): a first agent, interrupted twice, a second that continued its work, and a third that made the fix round after the reviews of PR #115
**Branch:** `feature/t26-visual-send` · **Pull request:** into `dev` (a regular packet)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (D20 with its 2026-10-05 annotation; C4, D1, C1, C7, D17, D18; D26, D29)
- [[Implementation/Waves/00007-panes/plan]] › *Packet T26 — 2026-10-06* (its verification mutants S1–S20) and *Decisions for the user*; its brief `brief-t26-visual-send.md` with its *Amendment — 2026-10-05* (the user's answers to VS1–VS5 and to D20's undo gaps); the brief review `brief-review-t25-t26.md` › *T26*
- `Implementation/Waves/00007-panes/evidence/t26-probes.txt` (U, D, V, V2): the measurement the pins reproduce
- [[Sessions/2026-10-05 — T24 Panes]] — the last packet to add a `<Plug>` mapping, a prefix key, a health line and help entries

## Context

**Goal:** T26, under D20 and C4: `\s` in Visual mode in Input sends the selection alone, as one message, and removes it; a refused Send removes nothing; `u` in Input brings back what a Send removed. The user's answers of 2026-10-05: VS1 (a), VS2 (a), VS3 (a), VS4 (a), VS5 (b), and the undo gaps "as you propose" — named in the help, pinned, not worked around.

**The interruption, as a fact.** The packet's first agent was interrupted twice on 2026-10-06: the host slept, then the user restarted Neovim. It had committed three commits (`14800ee`, `f89f3d3`, `55e37d7`) and left undo cases uncommitted, saved by the orchestrator as a patch. The first agent did not push them: the orchestrator pushed them, on the user's "go, do it", at 10:39 CEST, and no whole-suite run was made on `55e37d7` before that push, as D26 asks. `08ea516`'s message, "after pushing VS-A to VS-C", is wrong on this; it is pushed history and stays, and this paragraph corrects it. A second agent was dispatched to continue from there. It found no red log among the first agent's scratch, so it rebuilt the first agent's reds commit by commit (*Red and green*). The patch held VS-D's undo cases, not the ragged-block unit the dispatch message named: that unit was already in `14800ee`.

**A push without the whole suite.** The second agent pushed `ed50a1a` at 10:55 CEST without a whole-suite run, under the orchestrator's instruction, against D26: the whole suite runs before each push of a code packet, and no rule allows a push at a green point. `ed50a1a`'s message says "D26 allows it at a green point"; that is wrong. The packet's last push (`08ea516`) followed the whole run on `eecc5cf`, whose tree differs from it by this note alone.

## What was done

- **The send home** (`lua/aineo/send/init.lua`, the first agent): `send_selection()` reads the selection's part of each line with `getregionpos()` from `getpos('v')` and `getpos('.')`, not from `'<` and `'>`, which still hold the previous selection inside an `x` mapping. A `$` block is read to each line's own end. A line the block lies past gives an empty part. A double-width character the block cuts is read whole. A charwise selection whose removal took its last line's break (`v$` on a line that has one; not on Input's last line, nor under `'virtualedit'`, where a selection past a line's end takes no line break) carries that line break, counted from the lines the removal joined. It removes the selection with Vim's own `"_d`, then writes exactly what was removed (VS5 (b)), without control bytes, as one bracketed paste and Enter in one write. It refuses, removing nothing and ending Visual mode with the selection kept for `gv` (VS4 (a)), when the current buffer is not Input (VS1 (a); with no Input at all too, the orchestrator's reading T26-9), when the selection holds only white space, and when Claude Code is not ready. When the write fails it puts Input back and raises, as `send()` does (`write_or_put_back()`, shared by both).
- **The entry point** (`plugin/aineo.lua`, the second agent): `VISUAL_ACTIONS` beside `ACTIONS`, and `<Plug>(aineo-send)` defined in Visual mode (`x`) too (VS2 (a)). `has_global_mapping(mode, keys)` reads the mode it maps, and `map_unless_mapped()` serves both loops. `map_prefix()` maps `\s` in Visual mode after the Normal keys, and nothing when `prefix` is `false`. `:Aineo` keeps taking no range (VS3 (a)).
- **The health check** (`lua/aineo/health.lua`): `PREFIX_KEYS` rows carry a mode, and the Visual `\s` row goes last. `global_mapping(mode, keys)` and `check_prefix_key()` read that mode, and the line says `in Visual mode` (`IN_MODE`).
- **The help** (`doc/aineo.txt`), corrected where T26 made it false or incomplete: section 1's keys paragraph; section 4's `:Aineo-send` (no range, E481); section 5's `<Plug>` paragraph and example (`{ 'n', 'x' }`), the `<Plug>(aineo-send)` entry, the *Prefix keys* list with the new `*aineo-v_\s*`, Select mode, and the paragraph on keys the user mapped (per mode); section 7, *Visual Send* and *Undo* (the old sentence "`u` in Input brings the text back" folded into it); section 10's *Prefix mappings*; section 11, *Undo after a Send*, naming the three gaps (VS-H).
- **The tests:**
  - `tests/test_send_selection.lua` (33 cases, 88 s on 0.12.5; 52 cases, 74 s after the fix round): every family of VS-A, pinned against Input's lines before and after; the registers, the cursor, and the last selection; the refusals (VS-B), with VS4's mode; the failed write (VS-C) and its undo block; `u` after a Visual Send of each kind; the `'undolevels'` gaps.
  - `tests/test_entry_send_selection.lua` (8 cases, 11 s), new, in a fixture repository of its own (`selection-entry`): the `\s` and `<Plug>` doors; `:'<,'>Aineo send` giving E481; `\s` outside Input, in another buffer and with no Input at all; and `u` after a Send typed from the Report's window (U2), under the changes pane (U3), and after the draft was restored (D2).
  - `tests/test_send.lua`: the whole-Input undo case (U1), pinned for the first time.
  - The pins that moved: `tests/test_plugin.lua` (`x <Plug>(aineo-send)`, `x \s`); `tests/test_entry_prefix.lua` (a mode column; the user's own mapping per mode); `tests/test_health.lua`, where four full lists and the not-mapped list gain the Visual line, two counts go 8 → 9, nine indexes go `[9]` → `[10]`, and one case is new; `tests/helpers/health.lua` (keys counted as `<mode> <keys>`, T26-4); `tests/test_doc.lua` (`aineo-v_\s` in `TAGS`; `TAGS_THE_PLUGIN_DEFINES` derives Visual-mode tags).

## Unit list (the second agent's, stated before its first test; the first agent's, reconstructed from its commits)

The first agent's units, as its commits and their tests show them (its scratch holds no unit list, so whether it stated one is not known):
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
- **The count.** 26 reds drove code: the first agent's 17, rebuilt, and the second agent's 9 above (1 + 4 + 1 + 1 + 2). Apart from them, 16 cases of `tests/test_health.lua`'s *Prefix mappings* went red when the Visual row was added — the four full lists, the not-mapped list, the two counts and the nine `[9]` indexes — pins that moved, not reds that drove code (the records review re-ran `ed50a1a`'s `tests/test_health.lua` over the final health check: Fails (16)). An earlier count of "30 reds" counted those 16 as 4 and mixed them in; it is wrong.
- **Arrived green, each with its reason and the mutant that kills it (run, below):**
  - The undo cases (U1, each kind, the `'undolevels'` 0 and -1 gaps, U2, U3, D2): green by nature, since they pin Neovim's undo as the orchestrator measured it. Killed by S7, `M-visual-undo` and `M-undolevels-worked-around`.
  - `the prefix` `x` row with `prefix = false`, and the user's own Visual `\s` stays: green before any code, since nothing mapped the Visual key. The first is killed by `M-visual-prefix-before-false`; the second by `M-visual-unconditional`, run in the fix round (*Fix round*). S8-mirror, which this line named before, does not kill it (the records review, finding 1). The own-Visual-mapping row is a weak pin under S8 (see *Mutants*).
  - The user's own `\s` in one mode, aineo's in the other: spent by unit 6's mode-aware check. Killed by S8 and S8-mirror.
  - The `\s` door, `:'<,'>Aineo send`, outside Input, with no Input: spent by unit 6 and by the send home's refusals (Neovim's own E481). Killed by S2, S13–S17, `M-no-input-own-reason` and `M-no-visual-plug`.
  - The health check's warning for a user's Visual `\s`: spent by unit 10's mode-aware read. Killed by S9.
  - `tests/test_plugin.lua`'s `x <Plug>(aineo-send)` line was added after its code. Killed by `M-no-visual-plug`.
- **A deviation, said:** in unit 6 the second agent first wrote the Visual key's check as Normal mode alone (the minimum), saw it fail (aineo's own Normal `\s`, mapped a moment before, kept the Visual key from being mapped), and then made the check read its mode in the same unit, before the per-mode case existed.

## Mutants

Each is a literal edit in `.claude/local/orchestrator/t26-mutants.py` (the second agent's scratch). Each was applied alone to a pristine copy of its file, run with `make test_file` on the files named, then the file was restored. All ran on Neovim 0.12.5 against `eecc5cf`'s code, the packet's code before the fix round; the fix round's own mutants are in *Fix round*. The outputs are in `t26-mutants.txt`. **Every mutant was killed by assertion; none crashed, none survived.**

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
| `M-visual-unconditional` (the fix round) | `  if not has_global_mapping(mode, keys) then` → `  if mode == 'x' or not has_global_mapping(mode, keys) then` | *the user's own mapping › of a whole key sequence stays*, row `x` |

**33 mutants, 33 killed by assertion** — the second agent's 32, and `M-visual-unconditional`, which the records review measured and the fix round ran as the own-Visual-mapping row's killer. Of the first agent's ten arrived-green cases, the tab and both `virtualedit` cases are killed by S11 and S19, the ragged one-column case by `M-short-line-not-empty`, the exclusive case by `M-exclusive-ignored`, the cursor case by `M-cursor-moved`, the registers case by S10, the last-selection case by S4, and all of Input by S1, S4, S6 and S19. The multibyte charwise case (`wörl`, ending on an ASCII letter) is killed only by mutants that break every case (S1, S4, S6). `M-whole-double-width` leaves it green, and it would leave green a selection ending on `ö` too. The second agent tried that case (`gg0fwvl`, sending `wö`): it passed, and `M-whole-double-width` survived it. A probe then showed why (`t26-spike-regionpos.lua`, `nvim --clean`, 0.12.5): `getregionpos()` ends a selection on its last character's last byte, charwise and blockwise alike (`ö` at byte 10, `漢` at byte 4). The mutant is therefore equivalent wherever the selection holds its last character whole. `vim.str_utf_end()` matters only where a block's edge cuts a double-width character, which the double-width case pins. The extra case was not kept, so that the counts above stay measured on the tree shipped.

**S8, against the brief's wording.** The plan says VS-E's own-mapping case must kill S8. It does not: under S8 the Visual key reads Normal mode, finds aineo's own Normal `\s`, and is never mapped, so a user's own Visual `\s` stays either way. S8 is killed instead by the four `x` rows of `the prefix` and by *own `\s` in Normal mode, aineo's in Visual*. A user's own Visual `\s` overwritten is `M-visual-unconditional`'s failure — the Visual key mapped without asking `has_global_mapping()` — and that case kills it. S8-mirror does not: under it the Visual key still reads its own mode and keeps the user's mapping; what it breaks is the eight Normal keys.

## Verification (before the fix round)

On the packet's final code (`eecc5cf`, the session note then uncommitted), Neovim 0.12.5:
- `make test`: **1770 cases, `Fails (0)`**, 220 s, exit 0. The baseline at `origin/dev` `893a427` was 1718. The 52 new cases are 33 in `tests/test_send_selection.lua`, 8 in `tests/test_entry_send_selection.lua`, 1 in `tests/test_send.lua`, 8 in `tests/test_entry_prefix.lua`, 1 in `tests/test_health.lua` and 1 in `tests/test_doc.lua`. `tests/test_entry_guard.lua` runs inside it.
- `make lint`: StyLua clean; selene 0 errors, 0 warnings.
- The deep-require check (modularity §1) prints only lines inside their own homes; T26 adds none.
- Run times of the new files: `tests/test_send_selection.lua` 88 s, `tests/test_entry_send_selection.lua` 11 s. No case waits a fixed delay.

## Fix round — 2026-10-06

The third agent's round, after PR #115's attack, test-integrity and records reviews, from the orchestrator's fix-round brief, on `08ea516`. Every case below ran on Neovim 0.12.5 with `make test_file`, narrowed to its group where a run says so.

**Unit list, stated before the first test:**
1. A block edge on a multi-codepoint double-width character sends the whole character (attack 1).
2. A NUL in a selected line is sent as the whole-Input Send sends it (attack 4).
3. `'selection'` old: a charwise selection ending on an empty line sends exactly what it removes (attack 3).
4. After a Visual Send whose write fails, `gv` selects what was selected (attack 5).
5. `line_part()` without its boolean flag (records 11), while green.
6. `tests/test_send_selection.lua` ends its fake by a hangup (tests 6).
7. The whole-Input failed-write undo block, pinned (records 2, tests 1).
8. The `'undolevels'` 0 and -1 gaps for a Visual Send (tests 2).
9. A selection of control bytes alone refused (tests 3); the register case asserts the Send (tests 4); the VS-A rows read `messages` (tests 5).
10. The attack review's K1–K4; `.` after a Visual Send (the user's decision); the own-Visual-mapping row's killer (records 1).
11. The help, the docstrings, this note and the PR body (records 5, 6, 8, 9, 12, 13; items 13–17 of the brief).

**Seen red, 11 cases, each by assertion on its write or its selection:**
- Unit 1, five rows of VS-A (an emoji with a skin tone, a flag, a ZWJ sequence's left half and right half, a CJK character with a combining mark), e.g. `"writes"->1, left = "\27[200~b\n👍\nb…", right = "\27[200~b\n👍🏽\nb…"`. The `漢` row, already there, stayed green. Fixed by `character_end()`: `charidx()` and `byteidx()` count a character with its composing ones, or an emoji sequence, as one character on 0.12.5, where `vim.str_utf_end()` ended at the first codepoint.
- Unit 2, *writes a NUL byte in the selection as Send writes it*: `left = "\27[200~a\nb…", right = "\27[200~ab…"`. Fixed by reading the line with `nvim_buf_get_lines()`; a Lua string with a NUL handed to `charidx()` raises `E976: Using a Blob as a String` (measured), so `character_end()` hands it the line as Vimscript holds it, NUL as a line feed.
- Unit 3, four rows: to an empty line (`bc\n` for `bc`), two lines down (`bc\nde\n` for `bc\nde`), below an empty line (`bc\n\n` for `bc\n`), from the indent (` abc\nx\n` for `  abc\nx\n`). Fixed by `removed_region()`. A fifth row of the attack review's, from a line's start (`gg0vj` on `{ 'abc', '', 'def' }`), was green on the old code and stays green under every mutant of the new branch — its linewise and charwise readings send the same `abc\n` — so it was not kept.
- Unit 4, *a Visual Send whose write fails › ends Visual mode, gv selecting again what was selected*: `"selected"->2, left = nil, right = "ghi"` (`gv` selected `def` alone). Fixed by setting `'<` and `'>` again in the put-back; `write_or_put_back()` now takes the put-back as a function, so the whole-Input Send and the Visual Send each put back their own.

**Arrived green, each with its reason and its killer, run (table below):**
- Two `'selection'` old rows written after their code: *made backwards* (`jvk0l`), pinning `in_buffer_order()`, killed by `M-unordered`; *from a line's first non-blank* (`gg0llvjj` on `{ '  abc', 'x', '' }`), added when `M-old-indent-strict` survived the other rows, killed by it.
- The pins of units 7–10 pin behaviour the code had: each is green by nature, and each is killed by the mutant its review named — the whole-Input failed-write undo block (W1); the Visual `'undolevels'` 0 and -1 cases (O-GAP2v, O-GAP3v); control bytes alone (O-BLANKCTRL); the register case (O-NOOP, S10); the VS-A rows' `messages` (O-RAISE-AFTER, all 25 rows); K1 *says the selection is empty before saying Claude has not started* (A1-order); K2 *removes the selection as Vim's own "_d does, whatever d is mapped to in Visual mode* (A2); K3 *is told once, as aineo tells an error, by pressing \s* (A3); K4 *of \s in Select mode alone stays, and aineo maps \s in Visual mode* (A4); *leaves . to repeat its removal, which sends nothing, and u to bring it back* (`M-dot-api`).
- The linewise row (the user's decision on the final line feed) was already there; O-F2 kills it.

**Mutants of the fix round, 20, each its literal edit, applied to a copy of its file, run alone on the group named, then restored; all 20 killed by assertion, run again on the committed code (`77181e3`'s tree):**

| Mutant | Literal edit | Killed by |
|---|---|---|
| W1 (= O-GAP1n) | after `vim.api.nvim_buf_set_lines(input, 0, -1, false, {})` in `send()`: `vim.cmd('let &g:undolevels = &g:undolevels')` | `tests/test_send.lua` *leaves one undo block when the write fails…*: `"after_u"->1, left = ""` |
| O-GAP3v | before the `"_d`: `if vim.go.undolevels < 0 then vim.bo[input].undolevels = 1000 end` | *brings no Visual Send's selection back with undolevels -1* |
| O-GAP2v | before the `"_d`: `if vim.go.undolevels == 0 then vim.bo[input].undolevels = 1 end` | *… toggles it, with undolevels 0*: `"after_u_u"->1, left = "a1"` |
| O-BLANKCTRL | the empty check without `without_control_bytes()` | *… a selection of control bytes alone …*: `"input"->1, left = "kept"` |
| O-NOOP | `do return end` first in `send_selection()` | the register case: `"input"->1, left = "some text to send"` |
| S10 | `normal! ygv` before the `"_d` | the register case: `"registers"->"unnamed", left = "text"` |
| O-RAISE-AFTER | `error('after the write')` after the write | all 25 VS-A rows: `"messages"->1, left = { error = "…: after the write" }` |
| A1-order | the status check above the empty check | K1: `left = "aineo: nothing sent — Claude has not started"` |
| A2-normal-without-bang | `bang = false` on the `"_d` | K2: `"a", left = "beta"` |
| A3-plug-unwrapped | the Visual `<Plug>` runs `action()`, not `run(action)` | K3: `"messages"->1, left = nil` |
| A4-keymap-v-for-x | `nvim_get_keymap(mode == 'x' and 'v' or mode)` | K4: `"visual", left = ""` |
| M-visual-unconditional | `if mode == 'x' or not has_global_mapping(mode, keys) then` | *of a whole key sequence stays*, row `x`: `different string length` |
| M-dot-api | the `"_d` replaced by `<Esc>` and `nvim_buf_set_text()` over `'<`–`'>` | the `.` case: `"after_dot"->1, left = "alpha  gamma delta"` |
| O-F2 | the final line feed rule without `selection.charwise` | the `linewise` row: `left = "\27[200~a2\na3\n…"` |
| M-nul-blob | `local as_vimscript = line` | the NUL case: `"input"->1, left = "a\0b"` |
| M-old-no-linewise | the indent test → `if false then` | both indent rows |
| M-old-indent-strict | `>=` → `>` in the indent test | *from a line's first non-blank*: `left = "\27[200~abc\nx\n…"` |
| M-old-above-col0 | `math.max(#buffer_line(above), 1)` → `#buffer_line(above)` | *below an empty line*: `"input"->1, left = "abc"` — the Send raised `E964: Invalid column number: 0` before removing, which the row reads |
| M-old-end-kept | `return first, last, mode` in place of the moved end | 4 of the 6 `'selection'` old rows |
| M-unordered | `in_buffer_order()` returns `a, b` | *made backwards*: `left = "\27[200~bc\n…"` |

**Records corrected:** the help's *Visual Send* ("a selection past the end of a line takes its line break" was false under `'virtualedit'` and on Input's last line), its *LIMITS* (`gv` after a failed write; the `'undolevels'` gaps for a Visual Send; `.`); `send_selection()`'s, `removed_text()`'s and `visual_selection()`'s docstrings; `tests/helpers/send.lua`'s module, `messages()`, `raised()`, `send()`, `send_selection()` and `start_with_layout()` docstrings, which the brief's boundary had kept from the second agent (a spec conflict its report did not name); this note's interruption record, red count, unit-list heading, killer attribution and readings.

**Run times on 0.12.5:** `tests/test_send_selection.lua` 89 s for 33 cases on `08ea516`; 122 s for 44 cases with the fix round's rows and the end by keys; 63 s for the same 44 with the hangup; 74 s for the final 52. `tests/test_entry_send_selection.lua` 14 s for 9.

**Verification of the fix round** (0.12.5): `make test` on the pushed tree but for this paragraph (the code of `77181e3`): **1792 cases in 58 files, `Fails (0)`**, 220 s, exit 0 — the 1770 before it and 22 new (19 in `tests/test_send_selection.lua`, 1 each in `tests/test_send.lua`, `tests/test_entry_send_selection.lua` and `tests/test_entry_prefix.lua`); `tests/test_entry_guard.lua` runs inside it. `make lint`: StyLua clean, selene 0 errors, 0 warnings (StyLua took two passes of `make format` to settle the reformatted `eq()` calls). The deep-require check prints only lines inside their own homes; the send home and the plugin add none.

## Decisions & reasoning

- **VS1–VS5, the user's**, each built as the amendment records it: VS1 (a), VS2 (a), VS3 (a), VS4 (a), VS5 (b). The undo gaps are named in the help, pinned, and not worked around.
- **Visual mode is `x`.** Select mode, where typed characters replace the selection, keeps `\s` as text. The help says so.
- **One table for Visual actions** (`VISUAL_ACTIONS`) beside `ACTIONS`, read by both the `<Plug>` loop and `map_prefix()`, rather than a second `PREFIX_KEYS`: the Visual key reuses its action's keys.
- **The health line's wording**, the second agent's: `\s in Visual mode runs <Plug>(aineo-send)`, and `\s in Visual mode is not mapped`. The helpers count a line that says Visual mode as `x`, and any other as `n`.

## Readings for the MVP review

**The brief's readings (the orchestrator's):**
- "In Input" is Input as the current buffer, in whichever window.
- Ragged lines: what is removed is what Vim's `"_d` removes, and what is sent is exactly that text (VS5 (b)); a ragged block's short lines are empty lines of the message, and no padding is sent.
- A tab a block cuts: `"_d` removes it and puts spaces for its part outside the block; the message holds the tab, without those spaces. The packet applies the same reading to a double-width character, and the fix round to any character Neovim draws as one (an emoji with its modifiers, a flag, a ZWJ sequence, a character with a combining mark).
- Outside Input, with or without an Input, the message is VS1 (a)'s: `aineo: nothing sent — Visual Send works in Input only` (T26-9).
- The white-space refusal: a selection holding only white space is refused as an empty Input is, saying `aineo: nothing sent — the selection is empty`.
- Registers: no register is written, the unnamed one included.
- The tag and the health row: the Visual key's tag is `*aineo-v_\s*`, and its health row goes last.
- A failed write's single undo block is reported, and stays (VS-C, VS-H).

**The author's own readings (the first and second agents'):**
- Select mode: Visual mode is `x`. In Select mode a typed `\s` is text, which replaces the selection; `<C-o>\s` sends. The help says so.
- The health wording: `\s in Visual mode runs <Plug>(aineo-send)`, and `\s in Visual mode is not mapped`.
- E21: a Visual Send in an Input that cannot be changed is not a refusal: Neovim's `E21: Cannot make changes, 'modifiable' is off` is shown as an error, `aineo: E21: …`, Visual mode ending and nothing written.
- Control bytes: a selection of control bytes alone is refused as empty, since the check reads the text it would send (control bytes removed), as Send's does.
- `'virtualedit'`: a selection past the end of a line takes no line break and sends no spaces; only `"_d`'s removal counts.

**The user's two decisions of 2026-10-06** (asked by the orchestrator, each with options; the user chose the recommended one):
- `.` after a Visual Send — "Name it in LIMITS (Recommended)": the removal stays Vim's `"_d`, so `.` repeats it, removing without sending, and `u` brings it back. The help's *LIMITS* › *Repeating a Visual Send* says so, and a case pins it.
- A linewise selection — "No final line feed (Recommended)": a `V` selection is sent as its lines joined by line feeds, with none after the last, like a whole-Input Send. This is the reading of VS5's "exactly the text removed" for a linewise removal, whose last line break `"_d` takes too; the `linewise` row pins it (O-F2 kills it).

**The orchestrator's reading for the fix round:** VS4 (a) applied to a failed write. After a Visual Send whose write fails, Input is put back and `gv` selects what was selected: the put-back sets `'<` and `'>` again, which `"_d` had moved.

**The fix round's readings:**
- `'selection'` old: a charwise selection ending on an empty line below its start is removed by Vim as an exclusive motion ending in column 1, on the line above, or linewise when the start lies in the indent. When it is linewise, the message holds every line break removed, the last one included (`  abc\nx\n`): that removal is a charwise selection's, and VS5 (b)'s "exactly the text removed" is read literally there, unlike the user's decision for a `V` selection.
- A NUL byte in a selected line is sent as the whole-Input Send sends it: not at all.

The help's *Visual Send* and *Undo* paragraphs are the second agent's words, corrected by the fix round; *LIMITS* › *Undo after a Send* names the three gaps in the user's terms.

## Task lines

The wave holds its marks (rule 6). The line T26 would take:

- [X] T26 — Visual Send (D20, C4): `\s` and `<Plug>(aineo-send)` in Visual mode in Input send the selection alone, exactly the text `"_d` removes, as one paste and Enter, and remove it; a refused Send removes nothing and ends Visual mode; `u` brings back what every Send removed, pinned, with the failed-write and `'undolevels'` gaps named in the help; VS1–VS5 as the user answered — regular.

## Limits

- What Claude Code makes of a message ending in a line feed (a charwise selection past its last line's end) was not measured; no other Send ends in one.
- `tests/test_send_selection.lua` takes 74 s on 0.12.5 for 52 cases (it took 88 s for 33 before the fix round ended its fake by a hangup), since each case starts the fake Claude Code and waits 1.5 s for it to be ready.

## Open threads

- None from the gaps: each is the user's, as answered on 2026-10-05.
- S8 is not killed by the case the plan names (see *Mutants*). It is killed by others, and the plan's wording is the orchestrator's to correct.

## Commits

Recorded after the merge, by T26's knowledge pass. PR #115 merged by rebase on 2026-10-06 (13:41 UTC; 15:41 CEST); `dev` `3b5f0f7`, whose code is the code of the orchestrator's verified head `66eb1b7` (`git diff --stat 66eb1b7 3b5f0f7 -- . ':!knowledge-vault'` prints nothing; the vault differs only by T25's knowledge pass, `4f80458` and `28189e3`, and the idea note `f1eca74`, which `dev` held before the rebase). Released in `v0.2.13` (PR #117, squash-merged into `main` as `1cb649d`, whose tree is `dev` `3b5f0f7`'s).

The first three were committed by the first agent and pushed by the orchestrator (*Context*). The next five are the second agent's: `70b0ed0` commits the first agent's uncommitted undo cases, unchanged. The last two are the fix round's.

| Branch | `dev` | Subject |
|---|---|---|
| `14800ee` | `51da4bb` | Send a Visual selection as exactly the text it removes |
| `f89f3d3` | `09e8920` | Refuse a Visual Send that cannot reach Claude, removing nothing |
| `55e37d7` | `23d5599` | Put Input back when a Visual Send's write fails |
| `70b0ed0` | `6cddec3` | Pin that u brings back what every Send removed |
| `ed50a1a` | `1624920` | Map Visual Send to `\s` and `<Plug>(aineo-send)` in Visual mode |
| `583ffe1` | `1db3ba3` | Report the Visual-mode `\s` in `:checkhealth aineo` |
| `eecc5cf` | `181890f` | Document Visual Send, undo after every Send, and its gaps |
| `08ea516` | `8af6dc7` | Record T26's session: Visual Send, its pins and mutants |
| `77181e3` | `c6c1654` | Send what a Visual Send removes in every case the reviews found |
| `66eb1b7` | `3b5f0f7` | Record T26's fix round and correct its session note |
