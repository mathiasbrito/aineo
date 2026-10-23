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

| Test file | Cases | Reds seen |
|---|---|---|
| `test_office_pack_literal` | 106 | 8 of the new (block comments, long strings, positional wins, finite numbers, lines); the corpus and the fuzz were green at once (pinned by mutants M1a–c) |
| `test_office_pack_art` | 33 | 30 of 31 against the tree before the art reader (the rest written after) |
| `test_office_pack_floor` | 16 | 11 of 16 before the floor reader |
| `test_office_pack_fields` | 67 | 65 of 66 before the schema |
| `test_office_pack_based_on` | 25 | none: written after the loader's code (stated in its commit) |
| `test_office_pack_checks` | 9 | 4 of 9 before the checks (the tiny pack's tests passed) |
| `test_office_pack` | 35 | moved to the new shape; `find()`: 3 red |
| `test_office_scene` | 49 | 9 of 18 new before the layout |
| `test_office` | 47 | 6 of 7 new before the wiring |
| `test_entry_office`, `test_entry_office_check`, `test_config` | 18, 7, 105 | 2, 7 and 19 before the wiring |

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

## Open threads

- T129 draws what the layout now says: `in_use`, `shows`, `walk_over` and the repeated-row layout are read, not yet drawn.
- T127 grows the vocabulary; `:Aineo office check tiny` is clean once it has the tiny pack's seven states.
- T133 may add a `door` spot to the default pack so the reachability check has a door to walk from.

## Commits

*Recorded after the merge.*
