# 2026-10-23 — T133 office default pack

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t133-default-pack-2` (continues `feature/t133-default-pack`, built on `feature/t123-office` after T130 landed) · **Pull request:** into `feature/t123-office` (number recorded after the merge)

A regular packet of the office screensaver (T123; D26 applies). The default pack is complete: the approved mock's art converted by a converter that ran once, a floor plan of a wall, desk rows with monitors, a lounge and a strip with a second lounge and a table-tennis table, an activity for each of the 24 states, the random life of idle and waiting agents, and the cat with what it leaves.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T133's row in §6, §3 (the pack format), §5 (*`default`*), *Converting the approved mock*, D109, A562, A567, A573, A587, A590
- `aineo-office/default/` (`pack.lua`, `floor.txt`, `art/*.txt`: 95 pieces), the converter in `knowledge-vault/Implementation/office-default-pack-converter/` (its `README.md` says how to run it)
- `tests/test_office_default_{pack,plan,states,look,life,cost}.lua`, `tests/helpers/office_default.lua`, `tests/helpers/office_cells.lua`

## Task lines

- [X] T133 The default pack, complete (C20; D109, A562, A567, A573, A587, A590): the converter run once, every piece, the floor plan, all activities, the cat, D109's adjustments

## What was done

1. **The converter** (`knowledge-vault/Implementation/office-default-pack-converter/`, never shipped, nothing requires it). It reads the mock's `sprites.lua` and `behaviours.lua` and writes the pack: art files from the sprite tables (a function of the width is the art at its narrowest with `stretch:`; a function of time is sampled into frames or becomes an `area`), the colours merged from 81 hexes into 58 names, the floor plan, `pack.lua`. `compare.lua` checks the pack's random-life activities against the mock's `behaviours.lua`: 28 activities, no difference but the lazier nap (D109).
2. **The wall** (rows 0–12, a baseboard on row 13): door (open while someone is at it), whiteboard (tasks in its `plan` area), file cabinet (a drawer open while someone reads or searches), bin under a clock (`time`), coffee machine (brewing while someone gets a cup), printer under a calendar (`page`, `date`), and, as the wall allows, the window (`sky`, the first of the decorations, A594), water cooler, snake plant, bookshelf, picture, fish tank and the corner plant; ceiling lamps over free wall.
3. **The floor**: rows of desks (a desk, a monitor with `screen` and `query` areas) filling the height, a lounge with a three-seat sofa (back and front pieces, so that agents sit between them), a rug, a low table and a lamp beside the first desk, and a strip of 11 rows under the desk rows with the second lounge and a table-tennis table.
4. **The agents**: a bean in about 45 poses made of layers (body, face with a blink, legs, hands, arms with what they hold) and of composites for what moves together (the paper that falls on the desk, the papers thrown up, a paper ball, spinning, tidying); the monitor's screens, sampled from the mock; about 27 effects.
5. **The 24 states**, each its own activity (states 10, 11, 15–18 too, A573: a spinner, the browser, a hand up with `?`, the printer, `git`, tidying), and what plays in the four parents.
6. **The random life**: fourteen things an idle agent does (`players = 2` for table tennis), five of a waiting one, three seated ones while an answer is awaited, and the cat's eleven (wander, wash, nap for a minute or three on the sofa seat, desk, keyboard, rubbing, following, the fish, a mess, a puddle, a taken seat) with the things it leaves and the agents' reactions.
7. **The older office tests** read the T124 pack's two activities and now read where the head is over for each spot (`office_cells.HEADS`).
8. **The four engine items of A594**, each test first and with a mutant killed by an assertion, and used by the default pack: a character with no place whose step names a spot the plan lacks is put on a floor cell where no character stands (`named_spots.choose_free_floor_cell`, `director` `route_to_spot`: at 60x24 and 100x40 every one of the 24 states draws its agent); a run of `decorations` hands its `shows` to each decoration (the window, first of the wall's decorations, shows the sky; a decoration that shows something still ranks as a decoration when a crowded plan drops pieces); the spot `next_to_the_cat` (a free cell beside a cat that stands still, facing it; the pack check knows it) with the activity `pet_the_cat` and the pose `petting`; `shows = 'name'` (a desk writes the name of the agent whose desk it is, counted by the desk's place in the plan, into its `name` area, cut to the area; the desks of the default pack have one under the desk top). The help (`doc/aineo.txt`) says each.
9. **Three mutants of the first round, killed** (F1, F2, F12): a lone idle agent never takes a table spot, the cat's nap is one unbroken minute on the sofa while it could walk off, the drumming agent goes no farther than beside its own desk.

## Reported, not chosen

- **60 columns by 24 rows holds no desk** (ruled, A594). The plan has 19 rows there (the status list takes 5): the wall's 13 rows and the aisle leave 5 rows of floor, and a seat is 7 rows under the aisle. An agent whose activity starts at a desk, the sofa or the printer is now put on a floor cell, so every state draws something; 15 of the 24 states start at a spot the plan lacks there, and a test names them. The mock's camera is not built; a window of 26 rows has a desk.
- **100 columns by 40 rows holds one desk.** The first desk row is a desk and the lounge (the mock's rule); the second row starts under row 35. A subagent has no desk there and is drawn on a floor cell (A594).
- **The window is one of the decorations** (ruled, A594): `shows` reaches decorations, and the window comes first in the run that starts at column 113, so it stands where it stood (columns 101-124) and appears from 125 columns; the cooler follows at 137, and the run shows what the width holds: window and cooler at 156, five pieces at 220, all six from 300. The window's spot is now its decoration's, on the aisle row below the baseboard, not on the baseboard.
- **A second lounge by height, not by width** (accepted, A594). The mock's rule is 180 columns or four desk rows; `from_width` gates a piece and not its spots, so a sofa hidden by width would leave its seats. The strip is the last 11 rows of the plan and shows when the room is tall enough (a plan of 53 rows); `from_width` is not used.
- **Pet the cat** (ruled, A594): the spot `next_to_the_cat` and the activity `pet_the_cat` (idle agents, a chance of 1); the cat standing still is what makes it possible.
- **The water cooler is a drink alone.** A decoration has one spot and `players = 2` needs two; the label is the mock's, "chats at the water cooler".
- **Name plates** (ruled, A594): `shows = 'name'` writes the agent's id into the desk's `name` area, left-aligned and cut to its 20 columns, in the pack's `name` text colour.
- **Where the mock drew with positions the engine does not have:** a paper thrown from the desk is thrown from the spot beside the bin; the cup is not carried while walking (the walking pose is the engine's); the box packed is not carried to the door; a task handed to a subagent that walks in is not shown arriving (no step waits for another agent); the clock is digital and the calendar's page dark, since the scene writes their text.
- **The scene's text colours serve the board and the status list both** (accepted, A594). `status` and `name` are the colours of the tasks on the white board and of the list on the dark floor, so they are mid greys (`#7c7f93`, `#6c7086`); each reads at about 3.6 to 4 on both.
- **A piece used from a spot is as wide as the way to the spot.** The scene shows a piece's `in_use` art while someone is at the spot nearest to it; the cabinet and the coffee machine are used from the left, and a bin and a printer have spots nearer to them, so their art carries seven empty columns on the left to bring their own spot within it.

## Tests

Test first for each unit, each seen failing before it was made to pass (assertion failures, no crash). The first six files were written against the pre-conversion pack, so their red is of the T124 pack against the new contract; the engine items' red is of the engine without them.

| File | Cases | Red on the T124 pack |
|---|---|---|
| `test_office_default_pack` | 14 | 6: every state mapped in pack.lua itself, the loaded activities, a scene's own activity per state, the cat drawn, the pieces the scene looks for, the live areas; green on arrival (the old pack met them): states given an activity, `check` clean, spots in the plan, art for every piece, effects exist, 64 colours, one cell wide under both 'ambiwidth'. The window first among the decorations and the desks' `name` area are red on the pack of the first round |
| `test_office_default_plan` | 15 | 14 (green: no window in a narrow wall) |
| `test_office_default_states` | 153 | 64 (each state starts and ends at its spot at 100x40 and 220x80; the 60x24 list; the pass through the 24); the 48 cases of every state drawn at 60x24 and 100x40 are red on the engine before A594's first item (mutant A5) |
| `test_office_default_look` | 20 | 19; the names on the plates red on the pack of the first round |
| `test_office_default_life` | 37 | 33; the three cases of the first round's mutants and the petting are red on their mutant |
| `test_office_default_cost` | 6 | 0: green by nature; killed by mutant C1 |

The engine items' own cases: `test_office_scene_named_spots` (a step whose spot the plan lacks), `test_office_scene` (the agent drawn on a floor cell), `test_office_scene_sky` and `test_office_scene_budget` (decorations that show), `test_office_scene_cat` and `test_office_pack_checks` (`next_to_the_cat`), `test_office_scene_shows` (names on plates), `test_office_pack_fields` (the message that lists what `shows` may be).

Corrections after the first green run, all of the tests' arithmetic, none of the pack: `beside_desk` is 4 at 100x40 (the next row's aisle is in view); the decorations at 156, 220 and 300 columns after the padding became 4; the desk's hands, not its body, are at the desk's top; the second `screen_code` pixel (green) so that a cursor screen cannot pass for code.

The older tests that read the T124 pack changed: `test_office` (rest on the sofa after a turn; a still pack for the no-rewrite case), `test_entry_office` (sofa; the cabinet for the recorded grep; the baseboard for `office.pieces`), `test_entry_office_hooks`, `test_entry_office_life`, `test_office_life`; `office_cells` has `HEADS` and `is_at`.

## Mutants

Each a literal edit on the file the test file targets, run against the test files that exercise the code it breaks, restored after. Killed by an assertion, no crash: D1 (a state left without an activity), D2 (the door spot), D3 (a piece's rows of unequal width), D4 (the second lounge in a small room: the strip moved before the first desk row), P1-P4, L1, L3-L6, L2b (the window, by the look file), S1-S5, K1-K12, F3-F11, C1; the three survivors of the first round, now killed: F1 (`players = 2` made `1`: a lone idle agent takes the table), F2 (the cat's nap `{ 60, 180 }` made `{ 6, 18 }`: no unbroken minute on the sofa), F12 (a waiting agent that drums at the sofa).

A594's items: A1 (the fallback also for an agent that has a place), A2 (also when the spots are only taken), A3 (a taken cell not skipped over), A5 (no fallback: the states at 60x24 and 100x40); B1 (`shows` not handed to decorations), B2 (a decoration that shows something ranked above furniture); the spot `next_to_the_cat`: its C1 (the cells beside the cat taken from the agents), C2 (a cat on the move counted), C3 (the name left out of the known spots), C4 (the name left out of the pack check); the plates: N1 (every plate the first agent's), N2 (the name not cut), N3 (the status colour), N4 (no painter), N5 (`name` not a `shows`), N6 (any agent for any plate); the pack's W1 (no window among the decorations), W2 (no name on the desks), W3 (petting at the sofa).

## Open threads

- T134's help should list the piece names the engine looks for (`aineo-office-live`) and each activity's `about`, which the pack already carries; T136's guide documents the default pack as the worked example.
- The camera for windows below 26 rows is not built; an agent is drawn on a floor cell there (A594).
- The plate is left-aligned; a centred name is for a later pass.

## Commits

*Recorded after the merge.*
