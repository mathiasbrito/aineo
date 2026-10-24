# 2026-10-23 — T125 office pack format

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t125-office-pack-format` · **Pull request:** into `feature/t123-office`

A regular packet of the office screensaver (T123; D26 applies). T124's skeleton read a pack with a reader that stopped at its first problem; this packet makes the pack format whole: every field of the plan's §3, read as data, checked line by line, laid over the pack it is `based_on`, chosen by `office.pack`, patched by `office.pieces` and checked by `:Aineo office check`.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T125's row in §6, §3 (the pack format), *Reading a pack*, *A complete small pack*, *Configuration*; D108, A561, A564, A572, A573 (OS5), A575, A576
- `lua/aineo/office_pack/`, `lua/aineo/office/colours.lua`, `lua/aineo/office/init.lua`, `lua/aineo/office_scene/floor_layout.lua`, `lua/aineo/office_scene/stretch.lua`, `lua/aineo/config/init.lua`, `lua/aineo/entry/office.lua`, `lua/aineo/entry/office_check.lua`, `plugin/aineo.lua`, `doc/aineo.txt`
- `tests/test_office_pack*.lua`, `tests/test_office_scene.lua`, `tests/test_office.lua`, `tests/test_entry_office*.lua`, `tests/test_config.lua`, `tests/fixtures/office_packs/`

## Task lines

- [X] T125 The pack format (C19, C1, D108, A564, A572): the literal reader completed (A576: block comments, long strings, `[1]=` mixed with items, numbers that are not finite); every field of §3 through one schema; art headers; floor plans with repeated columns and rows; decorations, `from_width`, stretched runs; `based_on`; `office.pack` (a name or a list picked at random) and `office.pieces`; the checks and the fallbacks; `:Aineo office check` into the quickfix list

## What was done

- **Literal reader** (`literal.lua`, `reader.lua`, `long_bracket.lua`): `--[[ ]]` and `--[==[ ]==]` comments, `[[ ]]` strings, a list item beating a `[n]=` key as in Lua, a number that is not finite refused, and `lines[table][key]`, the line each entry starts on, which every later problem is told at. Still nothing is run; the corpus of refused tokens (operators, keywords, calls, shapes of code) is a parametrised test and a seeded fuzz pins "a table or a problem, never an error".
- **Problems** (`problems.lua`): `{ pack, file, path, line, message }`, ordered by file then line, told as `pack/file:line: message`, as quickfix items, and as one warning naming the first problem of each file.
- **Art** (`art.lua`): `about`, `colours`, `anchor`, `faces`, `stretch`, `area <name>`, `seconds per frame`; rows of one width, letters the header names, colours the pack has, anchor/stretch/areas inside the art, 400×200 pixels and 64 frames.
- **Floor** (`floor.lua`): one block of columns and one block of rows that repeat, markers, letters in the legend, 400×200 cells; a row shorter than the widest reads as ending in spaces.
- **Schema** (`schema.lua`, `pack_format.lua`): the fields of §3 as data; defaults filled; paths in messages (`activities.stand.steps[2].pose names the pose “floating”, which the pack does not have`); unknown fields told.
- **Merging** (`loader.lua`, `entries.lua`, `characters.lua`, `poses.lua`, `states.lua`): an entry with a problem is left out so the pack's base shows through; `based_on` (default `default`, `false` for none, loops and 8 deep told once); subagent like agent, a cat only if drawn; `like` chains of poses up to 8; a pack that cannot be used gives the default pack.
- **Trigger patterns** (`lua_pattern.lua`, A580): a trigger's `lua_pattern` must be one Lua accepts and hold at most one repetition item (`*`, `+`, `-` outside a set and not escaped), so a match cannot freeze the editor; the glob matcher is `aineo.office_states`'s (T127). Mutants M26–M28 (two repetitions allowed; a set's or an escaped character counted) are killed by `test_office_pack_fields`.
- **Checks** (`checks.lua`): every spot reachable from the door; an activity whose steps go to a spot the floor lacks is told never to play.
- **Layout** (`office_scene/floor_layout.lua`, `stretch.lua`, painter): marked rows repeat to the height, `from_width`, `decorations` (as many as fit, in order, a spot of the piece's name on the first floor row below), a run of a stretchable piece stretched to the run. The only edit outside `aineo.office_pack`, `aineo.config` and the composition root.
- **Office and entry** (`office/init.lua`, `office/colours.lua`, `entry/office.lua`, `entry/office_check.lua`): settings and a random source handed in; one warning when the pack has problems; highlight-group text colours made into colours, again after a colorscheme; `:Aineo office check [name]` with completion.
- **Help**: the two settings, the command, and the pack format as far as built (packs, `pack.lua`, characters and poses, effects, art, floor, activities, triggers).

## Reported, not chosen (spec points the plan leaves open)

1. **`during` and `always`.** The plan's table says "`during` … `always` for the cat" without a shape. Built: a list of states, `always` among them.
2. **Counting.** `anchor` and `area` count pixels from 0, `stretch: columns a-b` from 1: the plan's own tiny pack writes them so (`area plan: 1, 1, 4 x 6` and `stretch: columns 2-5` on a 6-wide board).
3. **Rows of equal width.** The plan lists "rows of equal width" among the checks. Held for art; a floor row shorter than the widest is read as ending in spaces, since editors take trailing spaces off and the tiny pack's plan cannot be written without them.
4. **Leftover rows.** Rows a repeated block leaves over are floor, above the rows after the block; the plan says nothing.
5. **Decoration spot.** "Each with its spot on the first floor row below it": built as a spot named after the piece, at the piece's left column, on the first row below whose cell there is `.`.
6. **No door spot, no reachability check.** The default pack T124 shipped has no `door` spot; a plan with none is not told.
7. **The states of the vocabulary.** The check of `states` and `during` names reads `office_states.vocabulary()`, four states until T127; tests inject the names (`state_names`) so they do not wait for it.

## Tests

Counts as of the review round (cases per file): `test_office_pack_literal` 112, `_art` 38, `_floor` 20, `_fields` 84, `_based_on` 28, `_checks` 9, `test_office_pack` 37, `_bounds` 12, `_paths` 15, `_cache` 7, `test_office_scene` 49, `test_office` 48, `test_entry_office` 22, `test_entry_office_check` 8, `test_config` 180, `test_office_states_triggers` 20.

Reds seen, first round: art 30 of 31 before the reader; floor 11 of 16; fields 65 of 66 before the schema; checks 4 of 9; literal 8 of the new; scene 9 of 18; `test_office` 6 of 7; entry office 2; entry check 7; config 19; `find()` 3. `test_office_pack_based_on` was written after the loader code (stated in its commit); the later pins in the first round's last commits were written after their code.

Review round (A585): every item was test-first and seen failing: the `?` walker 5 + 2 cases; control characters 4 + 5 + 4 + 1; the bounded tests (NUL plan, every byte, 200 000-space headers, 100 000 rows, a seeded fuzz through `load`, `check`, `new_stage` and the quickfix items, a stretched picture) 5 + 1, two of them by the limit; paths 14 of 15; budget 2; cache 1; triggers 3. A bounded test runs the code in a Neovim killed past a limit (`tests/helpers/bounded.lua`, itself tested with an endless loop), so a hang fails by an assertion. The fuzz of the first round stopped at the reader; this one reaches `load` and `new_stage`.

## Mutants

Each run alone on the test files that exercise the code, from a pristine file, restored after (the source tree was clean of edits afterwards). The four the brief names are M1–M4; every mutant but one was killed by an assertion.

| # | Edit | Killed by |
|---|---|---|
| M1a | `literal.lua`: `refuse_value` skips the token instead of refusing (a call and an operator accepted) | `test_office_pack_literal`, 7 cases (the corpus) |
| M1b | `literal.lua`: the separator refusal removed | survived: the next entry's refusal names the same line (defence in depth, not a gap) |
| M1c | `literal.lua`: the text run with `loadstring` | `test_office_pack_literal`, 2 (never runs what it reads) |
| M2a–d | the schema's, the art's, the plan's and the reachability's `report(line, …)` → `report(nil, …)` | `test_office_pack_fields` 58, `_art` 2, `_floor` 2, `_checks` 2 |
| M3a | `art.lua`: a file with problems still gives a piece | `test_office_pack_based_on`, 2 |
| M3b | `poses.lua`: a pose with a problem kept as `{}` | `test_office_pack_based_on`, 1 (it survived until the test for a pose that is like itself was added) |
| M3c | `entries.lua`: an entry with a problem kept | `test_office_pack_based_on`, 4 |
| M4 | `floor_layout.lua`: the repeated rows laid out once (`copies = 1`) | `test_office_scene`, 3 |
| M5–M7 | `from_width` ignored; decorations placed whether or not they fit; stretched runs not stretched | `test_office_scene`, 1 each |
| M8 | reachability over one axis | `test_office_pack_checks`, 2 |
| M9 | a key beats a list item | `test_office_pack_literal`, 1 |
| M10–M12 | no implicit default base; pose chain limit 9; replaced pieces ignored | `test_office_pack_based_on` 1, `test_office_pack` 1, `_based_on` 3 |
| M13, M14, M16, M25 | the office never warns; ignores the random source; colours not made again on a colorscheme; text role without its fallback | `test_office`, 1, 2, 1, 1 |
| M15 | an empty list of packs accepted | `test_config`, 1 |
| M17–M24 | unreachable spot, never-playing activity, unknown field, art letters, art row width, `based_on` loop, plan letter, plan caps not told | `test_office_pack_checks` 2 and 2, `_fields` 7, `_art` 2 and 3, `_based_on` 1, `_floor` 2 and 1 |

## The review round (A585)

Findings of the review of #328 and what answered them: one NUL in a plan hung the editor (the layout counts a run by bytes now; control characters are refused in plans, art and every text a pack gives); an art header of spaces took minutes (split at the first colon, trimmed in one pass); `?` counts as a repetition item and the walker is `aineo.config`'s `lua_pattern_problem()`, one for the setting, the matching and the packs (`office_pack` now requires `aineo.config`, an edge the modularity table lacks: for an `ai/` change); a row of another width is told once per file; a load reads 2 MiB of files at most, a chain together, and is kept while no file changed; a pack and its bases hold 64 triggers at most and trying one call's triggers stops after 20 ms (the office hands the tracker the pack's triggers and a clock); stretched pieces are memoized; `~` is expanded in `office.pieces`; pack names are plain names and a pack's files must lie in its folder; links to regular files are followed, a FIFO is told and never opened, a linked pack folder is found. The placement budget of a piece in every cell belongs to T129 (OR3).

Mutants of the review round, all killed by an assertion: N1–N17 (budget not counted, kept load never stale or always stale, caller reaching the kept pack, triggers not capped, trigger time not limited, slow triggers told every time, pack names not plain, files not kept in the folder, FIFO opened, width told for every row, NUL kept in quickfix text, control characters accepted in a plan and in art, pieces over 500 not left out, `~` not expanded, linked folder not listed), and the reviewer's survivors: M1b (four refused inputs, 5 cases), MR4 (negative infinity, 1), MR1 (a class escape followed by a repetition, now the walker's, 3), `?` not counted (5 and 1), stretch not memoized (1), the layout counting by pattern again (2), control characters not refused (4 and 1).

## Open threads

- T129 draws what the layout now says: `in_use`, `shows`, `walk_over` and the repeated-row layout are read, not yet drawn.
- T127 grows the vocabulary; `:Aineo office check tiny` is clean once it has the tiny pack's seven states.
- T133 may add a `door` spot to the default pack so the reachability check has a door to walk from.

## Commits

Pull request #332 merged into `feature/t123-office`; that branch reached `dev` through pull request #343. Each commit below is as it stands on `dev` (a rebase merge replays under new hashes).
Released as v0.2.73 (pull request #345, `main` at `d3df7aff`).

- `dda94cc0` Read block comments, long strings and Lua's table semantics in packs
- `e0e922da` Tell every problem of a pack with its file and line, and read art headers
- `d27f32da` Read floor plans with repeated rows, and check them line by line
- `8c9722a8` Lay out repeated rows, hidden pieces, decorations and stretched runs
- `22071a4e` Read every field of the pack format through one schema, line by line
- `39346601` Pin the fallbacks of a pack based on another
- `dc893abf` Check that spots can be reached and that activities have their spots
- `8d5ee97e` Choose the office's pack, replace its pieces and check it
- `85bd06bb` Refuse a trigger's Lua pattern that is none, and pin the pack's size caps
- `7d9e6c18` Record T125 and pin a pose that is like itself falling back
- `1ceaa143` Describe :Aineo office check in the command's description test
- `623aef26` Refuse a trigger's Lua pattern with more than one repetition item
- `1675ffc8` Count ? as a repetition item, and read one walker for every Lua pattern
- `25262b53` Stop a pack's bytes from hanging, slowing or breaking the office
- `d806ceb0` Pin the reader's survivors, expand ~ in office.pieces, stretch once
- `1e27c09a` Keep a pack to plain names and to its own folder, and tell odd files
- `1973f7e7` Bound what loading a pack reads, and read it again only when it changed
- `8aac942c` Cap a pack's triggers at 64 and the time to try them at 20 ms
- `2ba1e14f` Record the review round of T125 in its session note
