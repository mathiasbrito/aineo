# 2026-10-29 — T159 write whole file

**Author:** the repository's maintainer, with Claude — implementer agent
**Branch:** `feature/t159-write-whole-file` (from `dev` at 4f4dd8ef) · **Pull request:** into `dev`

T159: `\WW` writes code as `\W` does, but the code may also change other places of the file — an import at the top, a variable outside the function — and each change shows as a proposal of its own, moved through with `]w`/`[w` and decided one by one (`\Wa`/`\Wr`/`\Wd`) or all at once (`\WA`/`\WR`) (D136, A662). An addition: `\W`, `\w` and the fix keep every behaviour and test they had.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D136 row (A662 inside it) and the T159 row
- [[Sessions/2026-10-27 — T154 write code]] — `\w`/`\W`, the shared preview and placement this builds on (D127, D128, A640–A643)
- [[Sessions/2026-10-28 — T156 write keys]] — the keys of written code, the blank anchor line, the preview in view (D130–D132, A645–A652)
- [[Sessions/2026-10-26 — T153 cheatsheet]] — the keys table the new rows join
- `lua/aineo/explain/{preview,write,request,fix,kept,kinds,init}.lua`, `lua/aineo/entry/{explaining,init}.lua`, `lua/aineo/keys/init.lua`, `plugin/aineo.lua`, `lua/aineo/health.lua`, `doc/aineo.txt`, `README.md`

## Task lines

- [X] T159 `\WW`, written code that may edit the whole file (D136, A662): the prompt's file-wide paragraph after the anchor's rules; the answer placed with the fix's placement, the anchor's edit first, at most 20, overlaps refused; each edit a proposal of its own (own keys row `write i/n`, stale and diffed on its own, chosen by the cursor's line else the last `]w`/`[w` move); accept one, accept-all as one undo step leaving the stale, reject one, reject-all, `\vc`; the proposal at the cursor brought into view; kept answers apart from `\W`'s; `<Plug>(aineo-write-file|accept-all|reject-all|next|previous)`; the keys table, health, help (*aineo-write-file*), README. Left open: see *Open threads*.

## What was done, and why

1. **The prompt** (`request.lua`): a request that may edit the whole file adds `WHOLE_FILE_RULES` after the rules of the anchor's edit — for a typed request below a line, on a blank line, and for the request's lines alike. `\W`'s prompt is byte for byte as before.
2. **The answer** (`write.lua`, `placed_in_the_whole_file()`): more than 20 edits are refused first; the first edit alone must pass `\W`'s own checks (one edit of exactly the anchor's lines, the cursor's line kept, the blank-line rule) with its own words (`its first edit must …`); then every edit goes through the fix's `placement.place()`, which already refuses overlaps, lines the file lacks and old lines that stand nowhere or in several places. The anchor's edit keeps the blank-line rule's dropped leading copy (`in_its_place()`). `\W`'s path is `placed_at_the_line_asked()`, the old checks in one function.
3. **Separate proposals** (`preview.lua`): a preview shown with `separate` draws a head row for each edit — `write 2/3 · read-only until \Wa accepts or \Wr rejects · \Wd shows the diff · ]w [w move · \WA accepts all · \WR rejects all` — marks each edit stale on its own (`add_proposals()`), shows a stale or diffed edit as a diff and the others as the overlay, in blocks of those that touch. `choose()` takes the edit whose lines hold the cursor's line, else the one `jump()` moved to last, else tells the user how to choose. `apply_chosen()`, `drop()`, `apply_all()` (every standing edit, lowest first, as one undo step) and `remove_edits()` (the last decided clears the preview, giving the buffer its 'modifiable' back). The request is named above the anchor's proposal (`subject_edit`), and that proposal is the one brought into view (`places.lead`), so D132 holds for `\WW` with the import far above. Every non-separate path is as it was.
4. **The keys**: `\WW` in the keys table's Write section; `\WA`, `\WR`, `]w`, `[w` in "While a proposal shows"; `<Plug>(aineo-write-file)` in Normal and Visual mode with `\W`'s settings; `<Plug>(aineo-write-accept-all|reject-all|next|previous)`; the accept, reject and diff `<Plug>`s hand the cursor's line to the explain home. The buffer maps the four new keys only for separate proposals, never over a user's own.
5. **Kept answers**: the kept key holds the scope, so `\W` and `\WW` never show each other's (A662 (4)).

## Decisions (the implementer's, within A662)

- **`<Plug>(aineo-write-next)` and `<Plug>(aineo-write-previous)`** are added, though A662 names only the accept-all and reject-all mappings: the preview maps every key of a proposal to a `<Plug>` of its kind, and `]w`/`[w` follow that.
- **Accept-all with a stale proposal** applies the standing ones as one undo step and leaves the stale one shown, to be rejected (A662 (4): a stale proposal only rejects). With none standing it tells the stale message.
- **Accepting one while others are left** tells `aineo: code written (u undoes it once the rest is decided)`: `u` fails while the buffer is read-only.
- **`\Wd`** toggles the chosen proposal's diff alone (A662 (3) has it act on the chosen one).
- **With `prefix = false`** none of the keys is mapped, `]w`/`[w` included, as for `\Wa`/`\Wr`/`\Wd`; the `<Plug>`s are there.
- **`:Aineo write`** gets no word for `\WW`: A662 names none.
- **The float** is titled `Write code that may change the whole file`.

## Seen red

Each red was read before the code that turns it green was written. `tests/test_explain_write_file.lua`:

1. *the prompt / allows edits elsewhere in the file* — the line after the rules was the first numbered line, not `WHOLE_FILE_RULES`.
2. *the proposals / are each edit, with a keys row of its own* — no keys row: the two-edit answer was refused.
3. *accepting one / applies the proposal on the cursor's line alone* — both edits were applied (the import on line 1).
4. *rejecting one / leaves the buffer as it is and the other proposal shown* — no keys row left: everything was rejected.
5–7. *moving* (three cases) — first a missing `jump_to_proposal()`; then, against an empty stub, the assertion: `{ 3, 3 }` for `{ 1, 3 }`, `2` for `3`.
8–10. *deciding all* (three cases), against empty stubs — nothing accepted (the `undo` hit the still read-only buffer, E21), the sorting line missing, 4 drawn marks for 0.
11–13. *a stale proposal / is the one whose text changed …*, *is never accepted*, *stays shown when all are accepted* — the head row did not say stale: the whole preview went to the diff view instead.
14. *the diff / shows the proposal on the cursor's line alone* — both proposals were shown as a diff.
15. *the code kept / is never reused for code written at the cursor alone* — 2 records for 4: `\W` reused `\WW`'s answer.
16. *the preview in view / is the proposal at the cursor's line* — `topfill` 0: the topmost proposal, not the anchor's, was the lead.

`tests/test_entry_write_file.lua`:

17–19. *`\WW` asks as `\W` does …*, *opens a float that says what it does*, *in Visual mode …* — `\WW` was `\W` with a `W` typed into its float: no file-wide paragraph, `\W`'s title.
20–25. *the keys / are mapped while the proposals show …* (`\WA` … `[w` unmapped), *move between the proposals* (`{ 3, 3, 3 }`), *accept each proposal as one undo step* (E21 on `u`: `\Wa` chose nothing), *accept every proposal left …* and *reject the proposal under the cursor alone* (no import).

`tests/test_health.lua`: *writing code / says what Claude Code writes with …* — no `\WW` line (run on a copy narrowed to that group).

## Arrived green, and why

- *the prompt / of code written at the cursor alone allows no edit elsewhere*, *`\W` / asks for code that does not allow edits elsewhere* — green by nature (`\W` unchanged); M7, M7e.
- *the answer refused* (five inputs), *the answer / of more than 20 edits …*, *of 20 edits is shown* — code written ahead: `placed_in_the_whole_file()` was written whole in unit 2; the overlap, out-of-file and nowhere refusals are the fix's placement. M1, M2, M28, M29, M6, M5.
- *accepting one / then the other applies it too* — green before unit 4 by accident (both applied at once); M13.
- *rejecting one / that is the last ends the preview* — green before unit 5 by nature (reject removed all); M11.
- *choosing* (three cases) — code written ahead in unit 4's `choose()`; M9, M10, M30.
- *a stale proposal / is rejected, ending the preview* — spent by unit 5; M11s.
- *touching proposals* (two orders) — green by nature: the extmarks already follow their text; M12 (`{3, 5}`), M32 (`{4, 3}`).
- *the selected lines* (two), *the code kept / is shown again*, *cleaning the buffer* — spent by the units before them; M8, M33, M34, M35.
- *`\W` / alone still asks … once the time for a second `W` is over* — green by nature: Neovim waits 'timeoutlen' on the ambiguity and then runs `\W`; M21b.
- *the keys / of code written by `\W` are its three alone* — first red for a wrong test (`\W` refuses a two-edit answer, so nothing showed); corrected together with the code it pins, so it was not seen red; M26.
- *the keys / leave a `]w` of the user's*, *name `\WW` as what asks again*, *accept the proposal on the cursor's line alone* — written after the code, to pin what the first mutant run showed loose; M36, M24, M23.
- The lists of keys, `<Plug>` mappings and health rows in `test_keys`, `test_plugin`, `test_health`, and `test_doc`'s tag list, were updated for the added keys; each was red first with the new key or the shifted row.

## Mutants

Each row is the literal edit, run against a copy of its test file narrowed to the cases named, on the final tree (the rows whose cases changed after the first final run, M11, M21, M21b, M25, were run again after the change). Killed means an assertion failed.

| | Edit | Cases | Result |
|---|---|---|---|
| M1 | `write.lua`: `or fault_of(first_placed, asked.ask, FIRST_OUT_OF_PLACE)` → `or nil` (the anchor edit not required) | the answer refused | killed, 2 |
| M2 | `placement.lua`: `if overlap(placed) then` → `if false then` (overlap allowed) | the answer refused | killed |
| M3 | `preview.lua` `apply_edits()`: `vim.o.undolevels = vim.o.undolevels` after each `apply_edit()` (accept-all as several undo steps) | deciding all | killed |
| M3e | the same | the keys / accept every proposal left | killed |
| M4a | `index_toward()`: `return 1` → `return #spans` (`]w` not wrapping) | moving | killed |
| M4b | `index_toward()`: the last `return #spans` → `return 1` (`[w` not wrapping) | moving | killed |
| M4e | as M4a | the keys / move between the proposals | killed |
| M5 | `> MOST_EDITS` → `>= MOST_EDITS` | the answer / of 20 edits is shown | killed |
| M6 | `> MOST_EDITS` → `> MOST_EDITS + 1` | the answer / of more than 20 edits | killed |
| M7 | `request.lua`: `if code.whole_file then` → `if true then` | the prompt | killed |
| M7e | the same | `\W` / asks for code that does not allow … | killed |
| M8 | `write.lua` `start()`: `whole_file = writing.whole_file and ask.place ~= 'in_request_lines'` | the selected lines | killed |
| M9 | `chosen_index()`: `if edit == preview.chosen then` → `if false then` | choosing | killed |
| M10 | `chosen_index()`: `if line and not preview.chosen and …` | choosing | killed |
| M11 | `remove_edits()`: `M.clear(preview.buffer)` → `vim.bo[preview.buffer].modifiable = preview.modifiable` | rejecting one | survived the first final run (the redraw that the option change starts cleared the drawing); killed once the case asserts the keys gone |
| M11s | the same | a stale proposal / is rejected | killed |
| M12 | the proposals' extmarks given `right_gravity = false` | touching proposals | killed (`{3, 5}`) |
| M13 | `remove_edits()`: `decided[preview.edits[index]]` → `decided[preview.edits[1]]` | accepting one | killed |
| M14 | `lead_rows()`: `if index == 1 or preview.separate then` → `if index == 1 then` | the proposals | killed |
| M15 | `add_proposals()`: `edit.stale = false` | a stale proposal / is the one … | killed |
| M16 | `apply_chosen()`: the stale check → `if false then` | a stale proposal / is never accepted | killed |
| M17 | `apply_all()`: the standing check → `if true then` | a stale proposal / stays shown … | killed |
| M18 | `toggle_diff()`: `toggled = preview.edits[index]` → `preview.edits[1]` | the diff | survived the first run (the case toggled the first proposal); killed once it toggles the second |
| M19 | `kept.lua`: `asking.whole_file,` removed from the key | the code kept | killed |
| M20 | `add_proposals()`: `places.lead = places.lead` | the preview in view | killed |
| M21 | keys table: `\WW`'s suffix `'WW'` → `'W'` | `\W` / alone … | survived: `\W` still opens `\W`'s float, the case's subject; M21b is its killer |
| M21b | keys table: `\W`'s suffix `'W'` → `'Wx'` | `\W` / alone … | crashed first (a missing title indexed); killed once the case reads the title through a helper |
| M22 | entry: `next = ']w',` removed | the keys / are mapped … | killed |
| M23 | entry: `accept_fix()` without `vim.fn.line('.')` | the keys / accept the proposal on the cursor's line alone | crashed first (E21 on `u` in the undo case); killed by the case added |
| M24 | entry: `ask_key_of()`'s `'WW'` → `'W'` | the keys / name `\WW` … | killed |
| M25 | `write.lua`: `title = title_of(writing)` → `\W`'s title | `\WW` / opens a float … | killed |
| M26 | `key_mappings()`: always `SEPARATE_ACTIONS` | the keys / of code written by `\W` … | killed |
| M27 | `index_toward()`: `span.first > line` → `>=` | moving | killed |
| M28 | `placement.lua`: the line-number checks → `false or false` | the answer refused | killed |
| M29 | `placement.lua`: `return nil, 'the old lines … stand nowhere …'` → `return 1` | the answer refused | killed |
| M30 | `choose()`: `chosen_index(…) or 1` | choosing / tells how to choose | killed |
| M32 | the proposals' extmarks given `end_right_gravity = true` | touching proposals | killed (`{4, 3}`) |
| M33 | `write.lua`: the whole-file placement skipped for the request's lines | the selected lines / are replaced … | killed |
| M34 | `write.lua`: `kept.keep(…, kept_key(…) .. 'x', …)` | the code kept / is shown again | killed |
| M35 | `fix.lua` `reject()`: `preview.clear(buffer)` → `preview.drop(buffer)` | cleaning the buffer | killed |
| M36 | `map_keys()`: `if not taken then` → `if true then` | the keys / leave a `]w` of the user's | killed |

## Suites

`make test` on the tree pushed (head `106d0938` plus these records), Neovim 0.12.5 on the host: 268 files, 8830 cases, `Fails (0) and Notes (0)`, exit 0. `make lint`: StyLua and selene clean (0 errors, 0 warnings). `test_doc` green.

## Open threads

- The first edit must be the anchor's as Claude Code answers it: an answer that puts the import first is refused whole (A662 (2)), though its edits would place. The refusal says so; the prompt says "after that first one".
- With proposals far apart, the window is brought to the anchor's proposal only; `]w`/`[w` reach the others.
- An undo of an earlier accept is not possible until the last proposal is decided (the buffer is read-only, A632).

## Commits

*recorded after the merge*
