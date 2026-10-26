# 2026-10-26 — T152 fix leaves only by a decision

**Author:** the repository's maintainer, with Claude — implementer agent
**Branch:** `feature/t152-fix-read-only` (from `dev` at 99c172c1) · **Pull request:** into `dev`

T152: a fix shown by `\Vf` leaves only by `\Va` or `\Vr`, the buffer read-only meanwhile, and the issue and the fix survive while the file is unchanged (D124, A632); folded in mid-packet, `\vc` cleans a buffer of everything the explain keys added (D125, A633).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D124 row (A632 inside it), the D125 row (A633 inside it) and the T152 row
- [[Sessions/2026-10-25 — T151 propose fix]] — the fix this packet changes; A632 supersedes its drop rules (A627, A630 (2), A631 (2))
- [[Sessions/2026-10-25 — T150 deep explain]] — the steering float `\vc` closes
- `lua/aineo/explain/{preview,fix,kept,steer,init}.lua`, `lua/aineo/entry/explaining.lua`, `plugin/aineo.lua`, `lua/aineo/health.lua`, `doc/aineo.txt`, `README.md`

## Task lines

- [X] T152 a fix leaves only by a decision, and `\vc` cleans a buffer (D124, A632; D125, A633): read-only buffer while a fix shows, `modifiable` given back exactly; no edit-watch drop, a stale mark instead; the issue stays after `\Vr`; fixes kept and shown again on `\Vf`, `\VVf` asking anew; `\vc`, `<Plug>(aineo-explain-clean)` and `:Aineo explain clear` one implementation, which also closes a steering float for the buffer and drops its kept answers and fixes; health, help, README.

## What was done, and why

The user lost fixes, and the issue explanations they were asked for, to mistyped keys: any edit of a fix's lines dropped it (D124). And the user asked for one key that returns a buffer to how it behaved when opened (D125).

1. **Read-only** (A632 (1), `aineo.explain.preview`): `show()` keeps the buffer's `modifiable` and turns it off; `clear()` gives it back on every way out (accept, reject, `\Vf` replacing, unload, `\vc`); `apply()` turns it on only to apply the edits, as one undo step. The head row reads `read-only until \Va accepts or \Vr rejects · \Vd shows the diff`.
2. **No drop, a stale mark** (A632 (2)): the edit watch (`touches()`, `drop_edited()`) is gone. Every change, after the event loop turns, redraws the fix; `render()` computes stale from A630 (1)'s checks (`stands()`), unchanged, at each drawing, so an undo back to the old lines lifts the mark. A stale fix is drawn as the diff view, its head row `the code under the fix changed · \Vr rejects · \Vf asks again`; with its extmarks gone, its head row alone, above the line the fix last started on, drawn after the next change (from the fix round on, also at the next redraw of a window showing it or when `\Va` refuses, A635 (1)). A reload detaches the buffer watch (`:edit!` fires `on_detach`, not `on_reload`, measured), so a detach while the buffer is loaded watches it again and redraws; while unloaded it clears quietly.
3. **The issue survives** (A632 (3)): `\Vr` never removed it; a case now pins that.
4. **Kept fixes** (A632 (4)): `aineo.explain.kept` holds any answer (`answer` in place of `explanations`) and gains `fix_key()` (issue line and text, model, effort, steer text); `aineo.explain.fix` keeps a fix once shown, and `\Vf` shows it again at once while the file reads as sent, saying `aineo: the fix kept from before, the code unchanged (\VVf asks anew)`; `\VVf` never recalls. After `u` undoes an accept, A552's kept issues come back with no request, confirmed by a case.
5. **What asks a fix** is told to the preview by the entry (`ask_keys`): the prefix keys, or the `<Plug>` mappings when the prefix is `false`.
6. **`\vc`** (A633): `<Plug>(aineo-explain-clean)` and `\vc` call the entry's `clear_explanations()`, as `:Aineo explain clear` does, which tells `aineo: explanations cleaned from this buffer`. `aineo.explain`'s `clear()` already stopped the requests, rejected the fix and cleared the marks (which takes back `]v`/`[v` and the badges through the marks listener); it now also closes a float steering a request for the buffer (`steer.close_for()`, each float told its buffer) and drops the buffer's kept answers and fixes.
7. Health, help (`aineo-explain-fix` rewritten, `aineo-explain-clean` new, the key, `<Plug>` and command entries), README (keys table, the fix paragraph).

## Decisions (the implementer's, within A632 and A633)

- **A stale fix shows as the diff view**, whatever `\Vd` chose: the overlay would hide lines that are no longer the old lines under new lines that no longer replace them. `\Vd`'s choice comes back once the mark goes.
- **Extmarks gone: the head row alone**, above the line the first edit last started on (clamped to the buffer), since nothing tells where the edits are.
- **A collapsed span** (every old line deleted) draws its new lines after its explanation, above the line where it stood, so no row is set at line −1.
- **`\VVf`'s answers are kept too**, under their steer text, as A632 (4) says; see the open threads.
- **The old "asking again while a fix is shown replaces it" case asks with another model**: on unchanged code `\Vf` now shows the kept fix, so a second answer needs another kept key.
- **Cases that used `clear()` to hide an answer before recalling the kept one now use `\v`/`\V`'s own toggle** (A552's path), since a clean drops kept answers (test_explain, test_explain_deep, test_entry_explain); the steered-fix case that removed its issue by `clear()` now clears the issues namespace as another plugin would, since a clean closes the float.

## Spec points for the orchestrator

1. **Steered fixes are kept but never recalled.** A632 (4) keys a fix by its steer text, `\VVf` always asks fresh and `\Vf` asks with the default text, so a fix asked by `\VVf` and then rejected is not shown again by `\Vf`. Built as written; if `\Vf` should show the last fix of the issue whatever its steer, that is a new ruling.
2. **`\vc` never meets an open steering float.** The float closes itself when its window is left (A626 (3)), so pressing `\vc` in the code's window finds none; only a command run for the buffer while the float keeps the focus (`nvim_buf_call`, a timer, a script) does. A633's float rule is built and tested on that path.
3. **The issue stays, but its band is hidden while the fix shows**: the issue sits above an old line, which the overlay conceals (T151's design). It shows again with `\Vr`, and in the diff view.

## Tests and mutants

Every file run with `make test_file` on Neovim 0.12.5 on the host (D29); no whole suite before the push (D30, a small fix of wave 21). Final counts, on the tree pushed: test_explain_fix 76 cases, test_entry_explain_fix 10, test_entry_explain_clean 6 (new), test_entry_explain 46, test_explain 110, test_explain_deep 38, test_entry_explain_deep 8, test_explain_issue_marks 28, test_explain_fix_request 13, test_explain_jump 31, test_entry_explain_send 18, test_health 160, test_plugin 5, test_doc 158: Fails (0) in each. `make lint`: 0 errors, 0 warnings.

**Seen red** (each before its code):
- accepting · in a buffer that was not modifiable applies the fix and leaves it not modifiable — error `Buffer is not 'modifiable'` from `apply()`.
- while shown · a mistyped edit changes nothing, and the fix and its issue stay (`\Vs`, `dd`, `x`, `yyp`, `:s`) — the buffer's line 2 changed in each.
- the preview · shows the keys…, shows edits that touch…, the diff view · shows the old lines struck… — the head row had the old text.
- while shown · a forced edit of its old lines keeps it, marked stale, and accepting changes nothing — no stale head (the fix was dropped).
- while shown · reloading the file keeps it, read-only, without a word — the fix was cleared by the detach.
- entry · the preview keys · of a fix whose code changed name `\Vf`…, and with no prefix… the `<Plug>` mapping… — no such row (the entry gave no `ask_keys`).
- asking again · after a rejection, the code unchanged, shows the kept fix at once, with a word — a request started.
- `:Aineo explain` · clear removes every explanation…, and says so once — no message.
- `:Aineo explain` · clear drops the kept answer, so asking again asks anew — one request, not two.
- `\vc` · on a buffer with nothing to clean says so once, and changes nothing — no message (`\vc` unmapped).
- `:Aineo explain clear` · closes the float steering a request for the buffer — the float stayed.
- test_health: seven cases (the prefix-key lists, the explain section) — no `\vc` row, the old fix text.

**Updated to the new wording after the code** (their killer: the head-row and health mutants of T151 and this packet): the keys · leave a global key of the user's alone… (core), the preview keys · with no prefix… (entry), and the leader cases of test_health reading row 49 and 48 rows instead of 48 and 47.

**Arrived green**, with the mutant that kills each (run, all by assertion):
- rejecting · gives the buffer the modifiable it had before the fix (true, false) — spent by the restore in `clear()`; M1 (true), M1b (false).
- while shown · a forced edit undone marks it stale no more… — spent by stale computed at each drawing; M11.
- while shown · its marks cleared by another plugin, an edit marks it stale… — pins the head-alone branch written with the forced-edit unit; M13.
- while shown · a command that changes its old lines keeps it… (`5normal! J`, `2normal! J`, `6m0`), moving an old line above… with `:m .-2` keys — converted from the drop rule, spent by its removal; M2.
- rejecting · keeps the issue the fix was asked for — green by nature; M3.
- asking again · with the prompt edited first asks anew, a fix being kept — green by nature; M14.
- asking again · after the code changed asks anew, the kept fix not shown — green by nature (`recall()` compares the text); M4.
- accepting · undone, lets the issues asked for come back from the kept answer, asking nothing — green by nature (A552); M21.
- accepting · through its `<Plug>` mapping applies the fix in the read-only buffer — written because M10 died only by errors elsewhere; M10.
- test_plugin's mapping list — pins the mapping written with the `\vc` unit; M19.
- `\vc` · leaves no virtual line, key or badge…; gives back the window its options and the buffer its modifiable; shows no answer of the request that ran, later; leaves the text and its undo history… — spent by `clear()`; M26 and M7, M1c, M7, M25.

| Mutant | Literal edit | Killed by (assertion) |
|---|---|---|
| M1 | `preview.lua` `clear()`: delete `vim.bo[buffer].modifiable = preview.modifiable` | accepting · not modifiable…; rejecting · … (true) |
| M1b | same line → `vim.bo[buffer].modifiable = true` | rejecting · … (false) |
| M1c | M1, on test_entry_explain_clean | `\vc` · gives back … modifiable |
| M2 | `watch_edits()` `on_lines`: `render(preview)` → `M.clear(preview.buffer)` | 13 cases of while shown |
| M3 | `fix.reject()`: add `marks.remove_issue(buffer, fixed_issues[buffer])` first | rejecting · keeps the issue |
| M4 | `kept.recall()`: `if found and vim.deep_equal(found.lines, lines) then` → `if found then` | asking again · after the code changed… |
| M5 | `apply()`: `standing_spans(preview)` → `spans_of(preview)` | 4 accepting cases (one by error, three by assertion), while shown · a forced edit… |
| M6 | `explain.clear()`: delete `kept.forget(buffer)` | `:Aineo explain` · clear drops the kept answer… |
| M7 | `explain.clear()`: delete `runs.stop_all_of(buffer)` | `\vc` · leaves no virtual line…; shows no answer… later |
| M9 | `show()`: delete `vim.bo[buffer].modifiable = false` | the five mistyped edits; reloading… read-only |
| M10 | `apply()`: delete `vim.bo[buffer].modifiable = true` | accepting · through its `<Plug>` mapping… (the other four by error) |
| M11 | `render()`: `preview.stale = not (…)` → `preview.stale = preview.stale or not (…)` | while shown · a forced edit undone… |
| M12 | `on_detach`: `watch_edits(preview)` + `render(preview)` → `M.clear(preview.buffer)` | while shown · reloading the file keeps it… |
| M13 | `render()`: `add_rows(places, row, true, head_rows(…))` → `local _ = row` | while shown · its marks cleared… |
| M14 | `ask_steered()`: recall the kept fix first (`if not show_kept(at_send, issue) then … end`) | asking again · with the prompt edited first… |
| M15 | `head_text()` stale: `preview.ask_key` → `'<Plug>(aineo-explain-fix)'` | entry · of a fix whose code changed name `\Vf` |
| M16 | entry: `ask_keys = prefix and {…}` → `ask_keys = false and {…}` | entry · of a fix whose code changed name `\Vf` |
| M16b | entry: `plain = '<Plug>(aineo-explain-fix)'` → `plain = 'Vf'` | entry · with no prefix, … the `<Plug>` mapping |
| M17 | `steer.close_for()`: `if open_window and open_for == buffer then` → `if false then` | `:Aineo explain clear` · closes the float… |
| M18 | entry: delete the `explanations cleaned` notify | `\vc` · on a buffer with nothing to clean… |
| M19 | plugin: delete `map_unless_mapped('n', prefix .. CLEAN_KEYS, 'explain-clean', '')` | test_plugin · defines :Aineo, … |
| M20 | `show_answer()`: delete `kept.keep(…)` | asking again · after a rejection… kept fix |
| M21 | `kept.recall()`: `return found.answer` → `return nil` | accepting · undone, lets the issues… |
| M23 | health: delete the `vc` row of `PREFIX_KEYS` | 17 cases of the prefix mappings |
| M25 | `explain.clear()`: `fix.reject(buffer)` → `fix.accept(buffer)` | `\vc` · nothing to clean…; leaves the text and its undo history… |
| M26 | `explain.clear()`: delete the `marks.clear` loop | `\vc` · leaves no virtual line…; shows no answer… later |

Each mutant ran from a pristine copy, alone, on the group of its test file that exercises it (a wrapper keeping the named top-level sets), or the whole file for test_plugin and test_health; A632's five (M1, M2, M3, M4, M5) and A633's three (M6, M7, M1c) are among them.

## Fix round of PR #377 (A634, A635)

A634 answered the spec points: (1) and (3) changed the code, and (2) accepted the float rule as built. A635 adopted review377's findings.

1. **The latest kept fix** (A634 (1)): `kept.fix_key()` drops the steer text; the key is the issue on its line, the model and the effort, so the fix asked last for an issue, with `\Vf` or `\VVf`, is the one kept, and `\Vf` on unchanged code shows it. A kept fix records whether it was steered, and the message says `asked with the default prompt` or `asked with your edited prompt`. `\VVf` still asks fresh.
2. **The issue at the top of the overlay** (A634 (3)): the overlay's rows for the first edit start with the issue's text in the issue look (`kinds.ISSUES`' groups, label `issue`, shown as `issu` in a six-column gutter, as issue bands are). Only the overlay draws it. The diff view and a stale fix leave the issue's line visible, and with it the issue's own band, so drawing it there would repeat it on the next row.
3. **Lost drawings redrawn** (A635 (1), review377's measured FIX1 and FIX2): a decoration provider `on_win` (`redraw_lost()`), set while any fix shows and removed with the last. When the drawing is gone, or the fix is drawn as standing while its edit marks are gone, it redraws the fix, stale, once the event loop turns. `apply()`'s refusal draws it too. Clearing only the edit marks changes no decoration, so the redraw comes with the next full redraw of a window showing the buffer; the case forces it with `redraw!`.
4. **`BufDelete` ends the fix** (A635 (2), FIX3): `:%bd|e#` no longer brings a fix back into a stripped buffer.
5. **Reload cases** (A635 (3)): a file changed on disk then `:e!` shows stale (kills ME), and `:e!` then a forced edit shows stale (kills MD).
6. **`fill_buffer()`** (A635 (4)) waits on `is_shown()` of the current buffer.
7. **Head row and `\Vd`** (A635 (5)): the head row says read-only only while `modifiable` is off; an `OptionSet` autocommand on `modifiable` redraws it. `\Vd` on a stale fix leaves the diff view and says `aineo: the fix is stale: \Vr rejects, \Vf asks again`. `named_key()` and `is_stale()` were extracted so the head row and `toggle_diff()` share them.
8. **Records** (A635 (6)): the help now says a fix whose marks were cleared is drawn stale at the next redraw of a window showing it, or when `\Va` refuses, which is what the code does. Item 2 of *What was done* above held only after an edit until this round.

**Seen red:**
- asking again · after a steered fix was rejected… shows that fix…: a request started (Left 1, Right 0).
- asking again · after a rejection… shows the kept fix…: the message lacked the prompt.
- the preview · starts with the issue it fixes…: no issue row (nil).
- while shown · its marks cleared by another plugin, it shows marked stale at once… (all namespaces; the edit marks only): no stale head (0).
- while shown · with modifiable set back on…: still read-only (0).
- while shown · marked stale, its diff view toggled says once…: no message.
- while shown · deleting the buffer, then editing it again…: the fix was still shown (true).

**Updated after the code:** the exact rows of the preview · shows the keys…, and shows edits that touch…, which now hold the issue row.

**Arrived green, each killed by a mutant that was run:**
- while shown · reloading the file changed on disk marks it stale: ME.
- while shown · after a reload, a forced edit…: MD.
- accepting · refused for its marks cleared, draws it marked stale before the screen is redrawn: MR. It was written because MR survived: the provider draws the same thing at the next redraw, so only the drawing's extmarks before that redraw tell the two apart.

| Mutant | Literal edit | Killed by (assertion) |
|---|---|---|
| MD | `on_detach`: drop `watch_edits(preview)` before `render(preview)` | after a reload, a forced edit… |
| ME | `on_detach`: drop `render(preview)` after `watch_edits(preview)` | reloading the file changed on disk… |
| MA1 | `start()`: `key = kept_key(fixing, issue),` → `key = steered_text and kept_key(fixing, issue) .. ' steered' or kept_key(fixing, issue),` | after a steered fix was rejected… |
| MA3 | `add_overlay()`: `band_rows({ preview.issue },` → `band_rows({},` | the three preview cases with the issue row |
| MP | `show()`: `watch_drawings(true)` → `watch_drawings(false)` | marks cleared… at once (both) |
| MB | `BufDelete` callback: delete `M.clear(event.buf)` | deleting the buffer, then editing it again… |
| MO | `head_text()`: `vim.bo[preview.buffer].modifiable and` → `false and` | with modifiable set back on… |
| MV | `toggle_diff()`: `if is_stale(preview, spans_of(preview)) then` → `if false then` | marked stale, its diff view toggled… |
| MR | `apply()`: delete the `render(preview)` before the refusal's notify | refused for its marks cleared, draws it… |

All 35 mutants were re-run on the round's final tree, one at a time from a pristine copy: the nine above, and the packet's 26. Every one was killed by an assertion. M5 and M10 also crash some cases, as before.

The round's refactor moved two anchors, so M11 and M15 were re-run as literal edits on the current text:
- M11: `preview.stale = is_stale(preview, spans)` → `preview.stale = preview.stale or is_stale(preview, spans)`. Killed by: a forced edit undone…
- M15: the stale head's `preview.ask_key` → `'<Plug>(aineo-explain-fix)'`. Killed by: entry · of a fix whose code changed name `\Vf`…

Counts on the round's final tree, Neovim 0.12.5, host:
- test_explain_fix: 86 cases.
- test_entry_explain_fix: 10.
- test_entry_explain_clean: 6.
- test_explain: 110.
- test_entry_explain: 46.
- test_doc: 158.

Every file shows Fails (0). `make lint` is clean. The whole suite was not run (D30).

## Open threads

- Spec points 1 and 3 above were ruled by A634 and built in the fix round; point 2 was accepted as built.
- The `announce_work` call was refused twice with "not taken" and no correction; the work went on.
- A632 (2)'s "an external reload" is measured with `:edit!`; a `:checktime` reload of a file changed on disk goes the same way (`on_detach` without `on_reload`) but has no case of its own.

## Commits

*Recorded after the merge.*
