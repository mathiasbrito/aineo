# 2026-10-23 — T133 office default pack

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t133-default-pack-3` (continues `feature/t133-default-pack-2` and `feature/t133-default-pack`, built on `feature/t123-office` after T130 landed) · **Pull request:** into `feature/t123-office`, replacing the pull request of the second branch (number recorded after the merge)

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
8. **The four engine items of A594**, each test first and with a mutant killed by an assertion, and used by the default pack: a character with no place whose step names a spot the plan lacks is put on a floor cell where no character stands (`named_spots.choose_free_floor_cell`, `director` `route_to_spot`: at 60x24 and 100x40 every one of the 24 states draws its agent); a run of `decorations` hands its `shows` to each decoration (the window, first of the wall's decorations, shows the sky; a decoration that shows something still ranks as a decoration when a crowded plan drops pieces); the spot `next_to_the_cat` (a free cell beside a cat that stands still, facing it; the pack check knows it) with the activity `pet_the_cat` and the pose `petting`; `shows = 'name'` (a desk writes the name of the agent at the `desk` spot under it into its `name` area, cut to the area; the desks of the default pack have one under the desk top). The help (`doc/aineo.txt`) says each.
9. **Three mutants of the first round, killed** (F1, F2, F12): a lone idle agent never takes a table spot, the cat's nap is one unbroken minute on the sofa while it could walk off, the drumming agent goes no farther than beside its own desk.

10. **The fix round of the review of the second branch's pull request** (A595), each unit test first and seen failing (or, for a pin of behaviour already there, its mutant seen surviving first):
    1. *Name plates and monitors by the `desk` spot under them.* `floor_layout.assign_users` gives a plate the place of the `desk` spot in the columns its desk covers (a desk the width cut off from its seat names nobody) and a monitor that of the nearest `desk` spot, each spot to one monitor; a plan without `desk` spots counts as before. Pinned at 157x78 (plates, five agents) and 165x78 (clues of agents 4 and 5), by an engine case, and by a monitor case for the claim.
    2. *The rug stays in its lounge.* The low table's cell moves up one row in both lounges and its anchor becomes `0, 3` (the converter makes the same); the rug is one run. A plan case: no stretched piece is laid over a run narrower than its art, at five sizes.
    3. *The cat asleep on a seat shows whole.* Four empty rows at the foot of `cat_sleep_on_a_seat` and anchor `5, 9`; two life cases (all the art's pixels show; the lowest is above the cushion of the sofa front).
    4. *Petting holds the cat still.* A spot found beside a character carries its id (`beside`); the director holds a cat an agent has gone beside, or is walking to, until that agent's step is over (its step and waiting times do not run down meanwhile). The help says so. Pinned by an engine case, by the default life (in 900 s with the cat's whole life, the cat is within 16 pixels of the agent for the first 1.5 s of every petting) and by a pack case that the petting step takes the pose with the reaching arm.
    5. *An agent with no place stands on a free floor cell.* It replaces T124's "not drawn when there are more agents than spots": an agent with no place whose step names a spot the plan lacks, cannot reach, or the others have taken is put on the free floor cell nearest the door spot (the random source's cell when the plan has no door) and plays the step there; it is not drawn only when a character stands on every floor cell, and then draws no random number while it waits. An agent that has a place keeps it. Three arriving agents are all drawn at 60x24 and 100x40. T124's cases changed with it: "more agents than spots" (now drawn on a cell, and undrawn with no free cell), "appears once the agent that had its spot is gone" (a one-cell plan), "appears once a spot it had none for is let go" (now: stands on a floor cell and keeps it), "draws random times only once it has a place" (a one-cell plan), and "two players do not take along an agent that has no place" (now take along one that stands on a floor cell).
    6. *Anger at the mess.* A case sends the cat to the spot right of the first desk to leave a mess or a puddle, with an agent at the spot beside that desk, eight cells away: it must be upset. The pack's radius stays 16 (reported below).
    7. *The typing check reads the pose.* `office_cells.is_typing` also waits (250 ms at most) for the first monitor's screen to light, which only the typing screens do.
    8. *The pass through the states is named for what it reaches*: 22 of the 24 (idle and waiting_for_subagents go on with a random life, so they end nowhere fixed).
    9. *Test-only:* `test_entry_office`'s named-pipe helper opens the pipe read-write, which ends by itself, and the pipe case asserts the process exited 0.

## Reported, not chosen

- **60 columns by 24 rows holds no desk** (ruled, A594). The plan has 19 rows there (the status list takes 5): the wall's 13 rows and the aisle leave 5 rows of floor, and a seat is 7 rows under the aisle. An agent whose activity starts at a desk, the sofa or the printer is now put on a floor cell, so every state draws something; 15 of the 24 states start at a spot the plan lacks there, and a test names them. The mock's camera is not built; a window of 26 rows has a desk.
- **100 columns by 40 rows holds one desk.** The first desk row is a desk and the lounge (the mock's rule); the second row starts under row 35. A subagent has no desk there and is drawn on a floor cell (A594).
- **The window is one of the decorations** (ruled, A594): `shows` reaches decorations, and the window comes first in the run that starts at column 113, so it stands where it stood (columns 101-124) and appears from 125 columns; the cooler follows at 137, and the run shows what the width holds: window and cooler at 156, five pieces at 220, all six from 300. The window's spot is now its decoration's, on the aisle row below the baseboard, not on the baseboard.
- **A second lounge by height, not by width** (accepted, A594). The mock's rule is 180 columns or four desk rows; `from_width` gates a piece and not its spots, so a sofa hidden by width would leave its seats. The strip is the last 11 rows of the plan and shows when the room is tall enough (a plan of 53 rows); `from_width` is not used.
- **Pet the cat** (ruled, A594): the spot `next_to_the_cat` and the activity `pet_the_cat` (idle agents, a chance of 1); the cat standing still is what makes it possible.
- **The water cooler is a drink alone.** A decoration has one spot and `players = 2` needs two; the label is the mock's, "chats at the water cooler".
- **Name plates** (ruled, A594): `shows = 'name'` writes the agent's id into the desk's `name` area, left-aligned and cut to its 20 columns, in the pack's `name` text colour.
- **Where the mock drew with positions the engine does not have:** a paper thrown from the desk is thrown from the spot beside the bin; the cup is not carried while walking (the walking pose is the engine's); the box packed is not carried to the door; a task handed to a subagent that walks in is not shown arriving (no step waits for another agent); the clock is digital and the calendar's page dark, since the scene writes their text.
- **The mock has no mess** (A595 item 6 asked for the radius "as the mock measures it"): the approved mock draws no mess and no puddle, so there was nothing to measure. Ruled afterwards (A596): the anger must be visible, so the mess and the puddle upset every agent within 40 cells, in the pack and in the converter. Two cases pin it: an agent eight cells away, and an idle agent across the room (25 cells) at 157x78.
- **"Nearest the door"** (A595 item 5) is read as: the free floor cell nearest the `door` spot, counting cells across and down.
- **The scene's text colours serve the board and the status list both** (accepted, A594). `status` and `name` are the colours of the tasks on the white board and of the list on the dark floor, so they are mid greys (`#7c7f93`, `#6c7086`); each reads at about 3.6 to 4 on both.
- **A piece used from a spot is as wide as the way to the spot.** The scene shows a piece's `in_use` art while someone is at the spot nearest to it; the cabinet and the coffee machine are used from the left, and a bin and a printer have spots nearer to them, so their art carries seven empty columns on the left to bring their own spot within it.

## Tests

Test first for each unit, each seen failing before it was made to pass (assertion failures, no crash). The first six files were written against the pre-conversion pack, so their red is of the T124 pack against the new contract; the engine items' red is of the engine without them.

| File | Cases | Red on the T124 pack |
|---|---|---|
| `test_office_default_pack` | 15 | 6: every state mapped in pack.lua itself, the loaded activities, a scene's own activity per state, the cat drawn, the pieces the scene looks for, the live areas; green on arrival (the old pack met them): states given an activity, `check` clean, spots in the plan, art for every piece, effects exist, 64 colours, one cell wide under both 'ambiwidth'. The window first among the decorations and the desks' `name` area are red on the pack of the first round |
| `test_office_default_plan` | 20 | 14 (green: no window in a narrow wall) |
| `test_office_default_states` | 155 | 64 (each state starts and ends at its spot at 100x40 and 220x80; the 60x24 list; the pass through the 24); the 48 cases of every state drawn at 60x24 and 100x40 are red on the engine before A594's first item (mutant A5) |
| `test_office_default_look` | 22 | 19; the names on the plates red on the pack of the first round |
| `test_office_default_life` | 42 | 33; the three cases of the first round's mutants and the petting are red on their mutant |
| `test_office_default_cost` | 6 | 0: green by nature; killed by mutant C1 |

The engine items' own cases: `test_office_scene_named_spots` (a step whose spot the plan lacks), `test_office_scene` (the agent drawn on a floor cell), `test_office_scene_sky` and `test_office_scene_budget` (decorations that show), `test_office_scene_cat` and `test_office_pack_checks` (`next_to_the_cat`), `test_office_scene_shows` (names on plates), `test_office_pack_fields` (the message that lists what `shows` may be).

Corrections after the first green run, all of the tests' arithmetic, none of the pack: `beside_desk` is 4 at 100x40 (the next row's aisle is in view); the decorations at 156, 220 and 300 columns after the padding became 4; the desk's hands, not its body, are at the desk's top; the second `screen_code` pixel (green) so that a cursor screen cannot pass for code.

The older tests that read the T124 pack changed: `test_office` (rest on the sofa after a turn; a still pack for the no-rewrite case), `test_entry_office` (sofa; the cabinet for the recorded grep; the baseboard for `office.pieces`), `test_entry_office_hooks`, `test_entry_office_life`, `test_office_life`; `office_cells` has `HEADS` and `is_at`.

## Mutants

Each a literal edit on a pristine copy of the file named, run on the test files that exercise the code it breaks, restored after; each killed by an assertion, none by a crash. `FLOOR` is `aineo-office/default/floor.txt`, `PACK` is `aineo-office/default/pack.lua`.

**This round (A595)**

| ID | File: edit | Killed by |
|---|---|---|
| MQ1 | `floor_layout.lua`: `if seat and seat.column >= left and seat.column < left + (placed.columns or piece.width) then` made `if seat then` | `test_office_scene_shows` (the blank plate of a desk cut off from its seat) |
| MQ2 | `floor_layout.lua`: `if seat and not seats_with_a_monitor[seat] then` made `if seat then` | `test_office_scene_monitor` (two monitors over one desk spot) |
| MQ3 | `floor_layout.lua`: `new_owner_finders(layout.spots.desk)` made `new_owner_finders(nil)` (counting again) | `test_office_scene_shows`; `test_office_default_look` (plates at 157x78, clues at 165x78) |
| MR1 | `FLOOR`: the `t` of both lounges put back in the rug's row | `test_office_default_plan` (4 sizes) |
| MP6a | `art/cat_sleep_on_a_seat.txt`: `anchor: 5, 9` made `anchor: 5, 6` | `test_office_default_life` (the cat shows whole) |
| MP6 | `art/cat_sleep_on_a_seat.txt`: `anchor: 5, 9` made `anchor: 5, 1` (the cat on the rug in front of the sofa) | `test_office_default_life` (above the cushion) |
| MH1 | `director.lua`: `if is_visited(context, cat, now) then` made `if false then` | `test_office_scene_cat`; `test_office_default_life` (the cat beside the agent) |
| MH2 | `director.lua`: `agent.spot.beside == cat.id and step_end_before(agent, now) == nil` made `agent.spot.beside == cat.id` | `test_office_scene_cat` (the cat strolls off once the agent leaves) |
| MH3 | `named_spots.lua`: the line `spot.beside = other.id` deleted | `test_office_scene_cat` |
| MP3 | `PACK`: `pose = 'petting'` made `pose = 'standing'` in `pet_the_cat` | `test_office_default_pack` (the petting step has the reaching arm) |
| MF1 | `director.lua`: `if route or performer.column then` made `if route or why ~= spots.UNREACHABLE or performer.column then` (the old rule) | `test_office_scene` (a floor cell for the agent without a spot); `test_office_default_states` (three arriving agents, 2 sizes) |
| MF2 | `named_spots.lua`: `free_floor_cell_nearest(world, cells_characters_stand_on(world), M.ENTRANCE)` made `floor_cell_choice(world, cells_characters_stand_on(world))` | `test_office_scene_named_spots` (nearest the door) |
| MF3 | `named_spots.lua`: `if not first_free_key_from(keys, 1, avoided) then` made `if world.random() < 0 or not first_free_key_from(keys, 1, avoided) then` (a number drawn though no cell is free) | `test_office_scene_places` (2 cases) |
| MF4 | `director.lua`: `if route or performer.column then` made `if route then` (placed agents fall back too) | `test_office_scene_named_spots`; `test_office_scene_cat` |
| MP5b | `PACK`: the mess's `upsets_agents_within = 40` made `1` | `test_office_default_life` (an agent eight cells away is upset) |
| MP5c | `PACK`: the puddle's `upsets_agents_within = 40` made `1` | `test_office_default_life` |
| MP5d | `PACK`: the mess's, and the puddle's, `upsets_agents_within = 40` made `16` (the value of the first rounds; seen failing before the pack took 40) | `test_office_default_life` (an idle agent across the room at 157x78) |
| MT1 | `PACK`: `run_a_command`'s step `pose = 'typing_command'` made `pose = 'sitting'` (`write_code`'s `pose = 'typing_code'` made `pose = 'sitting'` is not reached by `test_office`'s recorded turn, which runs a command, and is killed by `test_office_default_look`) | `test_office` (3 cases) |

**The review of the second branch's pull request (the edits it ran)**

| ID | File: edit | Result then |
|---|---|---|
| MA3 | `named_spots.lua`: `if not occupied[key] then` made `if true then` | killed |
| MB1 | `floor_layout.lua` `decorate`: the line `shows = entry.shows,` deleted | killed |
| MB2 | `placements.lua` `kind_of`: the early `if placed.decoration then return DECORATION end` deleted | killed |
| MC1 | `named_spots.lua` `cells_beside_cats`: `world.cats or {}` made `world.agents` | killed |
| MC2 | `named_spots.lua` `cells_beside`: `and #other.path == 0` deleted | killed |
| MN1 | `name_plate.lua` `owner_of`: `== placed.owner_place` made `return true` | killed |
| MN2 | `name_plate.lua`: `cell_text.cut_to(owner.id, plate.width)` made `owner.id` | killed |
| MN3 | `name_plate.lua`: `text_colours.name` made `text_colours.status` | killed |
| MN7 | `floor_layout.lua` `assign_users`: plates counted on the monitors' counter | killed by the look file |
| MN8 | `name_plate.lua`: the plate row `+ 1` | killed |
| MA-b | `director.lua`: `why ~= spots.UNREACHABLE or` deleted | killed by T124's case, now replaced |
| MA-c | `director.lua`: `or performer.column` deleted | killed by 3 engine cases |
| MP1 | `PACK` `sleep_on_a_seat`: `for_seconds = { 60, 180 }` made `{ 6, 18 }` | killed |

**The first rounds' pack mutants** (the edits as run)

| ID | File: edit |
|---|---|
| D1 | `PACK`: the line `thinking = 'think_at_the_whiteboard',` of `states` deleted |
| D2 | `FLOOR`: the door's `d` on the baseboard row made `z` |
| D3 | `art/desk.txt`: the first row one `W` longer than the others |
| D4 | `FLOOR`: the strip's 11 rows moved before the first desk row |
| P1 | `PACK`: the effect text `{ '.', '. ∘', '. ∘ o' }` made `{ '·', '· ∘', '· ∘ o' }` (ambiguous width) |
| P2 | `art/printer.txt`: the `area page:` line deleted |
| P3 | `PACK`: `P = { piece = 'printer', ...}` made `piece = 'printr'` |
| P4 | `PACK`: the `cat` key of `characters` renamed `crab` |
| L1 | `FLOOR`: the first desk's seat `s` made a space |
| L2, L2b | `FLOOR`: the window's `W` in the wall made `#` (the look file sees it by the sky) |
| L3, L4 | `FLOOR`: the coffee machine's, and the printer's, baseboard spot made `z` |
| L5 | `FLOOR`: one seat `q` of the first sofa made a space |
| L6 | `FLOOR`: the table-tennis table's right end `j` made `.` |
| S1 | `PACK`: `thinking`'s `at = 'whiteboard'` made `at = 'file_cabinet'` |
| S2 | `PACK`: `done`'s last step `at = 'sofa'` made `at = 'beside_desk'` |
| S3 | `PACK`: `at = 'door', pose = 'waving'` made `at = 'beside_desk', pose = 'waving'` |
| S4 | `PACK`: the printer step of `reporting` made `at = 'door'` |
| S5 | `PACK`: `asleep`'s `at = 'sofa'` made `at = 'anywhere'` |
| K1 | `art/desk.txt`: `W = wood` made `W = white` |
| K2 | `art/sky_day.txt`: `day_top` made `night_top` |
| K3–K5 | `PACK`: `in_use = 'coffee_machine_brewing'`, `'door_open'`, `'file_cabinet_open'` deleted |
| K6–K10 | `PACK`: `shows = 'plan'`, `'time'`, `'date'`, `'sky'`, `'printing'` deleted from the whiteboard, clock, calendar, window and printer |
| K11 | `PACK`: `sitting = true` added to `typing_code` |
| K12 | `PACK`: `typing_code`'s `screen = 'screen_code'` made `screen_cursor` |
| F1 | `PACK`: `players = 2,` made `players = 1,` |
| F2 | `PACK`: `sleep_on_a_seat`'s `for_seconds = { 60, 180 }` made `{ 6, 18 }` |
| F3, F8 | `PACK`: `cleaned_up_by = 'clean_up_the_mess',` and `'mop_up_the_puddle'` deleted |
| F4, F5 | `PACK`: `even_if_taken = true,` and `the_one_moved_plays = 'leave_in_a_huff',` deleted |
| F6 | `PACK`: the corner plant's watering `at = 'corner_plant'` made `at = 'snake_plant'` |
| F7 | `PACK`: `stretches`' `during = { 'idle' }` made `{ 'asleep' }` |
| F9, F10 | `PACK`: `leave = 'mess'` and `leave = 'puddle'` deleted from their steps |
| F11 | `PACK`: the fish stare's `at = 'fish_tank'` made `at = 'door'` |
| F12 | `PACK`: the drumming step's `at = 'desk'` made `at = 'sofa'` |
| C1 | `FLOOR`: every floor cell of 26 desk rows made a sofa back `u` |

The edits of the first round's engine mutants (A1–A5, B1, B2, C1–C4, N1–N6, W1–W3, killed then) were not kept; the review re-ran twelve of them as MA3 to MN8 above, with the edits listed.

## Open threads

- T134's help should list the piece names the engine looks for (`aineo-office-live`) and each activity's `about`, which the pack already carries; T136's guide documents the default pack as the worked example.
- The camera for windows below 26 rows is not built; an agent is drawn on a floor cell there (A594).
- The plate is left-aligned; a centred name is for a later pass.

## Commits

Pull request #340 merged into `feature/t123-office`; that branch reached `dev` through pull request #344. Each commit below is as it stands on `dev` (a rebase merge replays under new hashes).
Released as v0.2.73 (pull request #345, `main` at `d3df7aff`).

- `71850d85` Convert the approved mock into the complete default office pack
- `5a155293` Pin the default pack: its plan, its states, its look and its life
- `44a69f58` Write a step's fields in the order the pack format lists them
- `4ad0d882` WIP: record T133 in a session note and make the code screen test stricter
- `b8530b57` Kill the three surviving mutants of the default pack's random life
- `2c6154a4` Draw an agent on a floor cell when the plan lacks its spot
- `7b0c87b6` Let a run of decorations show live content
- `b75f509a` Add the spot next_to_the_cat
- `b3e034c8` Write an agent's name on its desk's name plate
- `be38a3c7` Use the new engine items in the default pack
- `392a306e` Record T133 as done: the session note and the plan row
- `d0ae54c8` Read the status list's cases by where the agent is drawn
- `c02816c7` Match name plates and monitors to the desk spot under them
- `1890b3e1` Keep the rug inside its lounge
- `92ef3905` Show the cat asleep on a sofa seat whole
- `0c8e0f1a` Hold the cat still while an agent pets it
- `75b72dce` Put an agent with no place on a free floor cell near the door
- `e40d967d` Read the rug case from the plan text, not the engine's layout
- `d8ccb3e0` Pin the anger a mess or a puddle causes
- `8f15692c` Have the typing check read the pose, not only the desk
- `eb2994d5` Stop test_entry_office leaving shells blocked on a named pipe
- `a41180c3` Pin that a desk spot gives its place to one monitor
- `5a9d76ba` Record the fix round of T133 and every mutant's literal edit
- `35aeaa2e` Make the anger at a mess or a puddle reach across the room
