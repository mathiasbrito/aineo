# 2026-10-23 — T135 office space station pack

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t135-space-station-pack` (from `feature/t123-office-authors`) · **Pull request:** into `feature/t123-office-authors` (number recorded after the merge)

A regular packet of the office screensaver (T123; D26 applies). The second pack: an original space-station theme, written as an outside author would write it, in the pack format alone (`pack.lua`, `floor.txt`, `art/*.txt`). `office.pack = 'space_station'` draws it, and a list of both picks one each time the office shows. Nothing of the engine changed.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T135's row in §6, §3 (the pack format), §5 (*`space_station`*), D110, A571
- `aineo-office/space_station/` (`pack.lua`, `floor.txt`, `art/*.txt`: 85 pieces)
- `tests/test_office_space_station_{pack,states,switch,life}.lua`, `tests/helpers/office_default.lua` (its `load_pack` takes a pack's name)

## Task lines

- [X] T135 The space-station pack (A571, D110): original art, a plan of its own, crew, service bots and a starhare, a trigger of its own; `check` clean; it switches with `office.pack`; a list picks among both

## What was done

1. **The pack is based on `default`** and keeps its spot names, so the default's 24 states and its random life play here as they are. Its own: the colours (50 names), the floor plan, 85 pieces of art, the three characters' poses, an effect, an activity for the trigger, the activities whose spot or words named an object the station has under another name, the things the starhare leaves.
2. **The plan** is a compact bridge: a wall 11 rows tall (airlock door, message terminal, holo-table, cargo crates, recycler chute under a chronometer, food dispenser, then a run of decorations: viewport, coolant tap, hydroponics rack, data archive, star chart, specimen tank, a hydroponics pod at the end, light bars over bare wall), a first band with a crew bench of two seats beside the first console desks, a band of console desks that repeats down the height, and a strip with a second bench and a holo-game table for two. Because the wall is short, **a desk, a bench seat and the message terminal exist at 60×24**: all 24 states start at a spot the plan has at 60×24, 100×40 and 220×80 (the default's plan lacks 15 of the 24 at 60×24, accepted there by A594).
3. **Art** (original; nothing named, shaped or coloured after a film's or a game's characters, ships or logos): the wall pieces above with `in_use` art (the airlock's leaves slide apart, the holo-table's grid is scanned, the crates' lid lifts, the dispenser forms a ration, the terminal's lines run, the game table's orb crosses); the four skies are 20 frames of drifting stars with a planet's limb at dawn, a bright star by day, a nebula at dusk and a small planet at night; crew in flight suits (a helmet, a visor with eyes that blink and change); service bots (a box on two legs, one round lens, one antenna); the starhare (long ears, two glowing eyes, a violet tail tip). The limbs, hands, legs and screens are the default pack's; a test names exactly which. Seven props (data slates, a supply case, chips thrown up…) are the default's art recoloured, with their own names.
4. **The word *droid* is not used**: it is a franchise's mark (A571's "no trademarked names"). The plan and the brief say droids; the pack says service bots (`bot`, `bot_lens_*`). The pet is a starhare, the bench a crew bench.
5. **The trigger**: `{ when = { tool = 'Bash', command = 'git push' }, play = 'send_a_transmission' }`. The activity stands at the `comms_console` spot (the left half of the message terminal's spots), reaches towards the terminal with signal arcs `)` `))` `)))` over its head, and is labelled "sends a transmission". The terminal shows its active art there.
6. **Reworded activities** (37, same names and steps as the default's, the station's words in `about`, `label`, and for five the spot: `look_out_of_the_window` at `viewport`, `water_the_snake_plant` at `hydroponics_rack`, `water_the_corner_plant` at `hydroponics_pod`, `get_a_drink_at_the_water_cooler` at `coolant_tap`, `stare_at_the_fish` at `specimen_tank`), copied from the default's text by a one-off script that was not kept; the pose tables of the crew and the bots likewise.
7. **One help sentence** (`doc/aineo.txt`, *aineo-office*) said aineo's own pack is the default; it now names both. Declared as a widening of the packet's files: a sentence the second pack made untrue. The chapters of T136 are untouched.

## What the format could not express (reported, not worked around in the engine)

- **A character's poses cannot be "the agent's, with these pieces swapped".** `like` takes a kind's poses whole, so the crew's and the bots' 46 poses each are written out (generated once from the default's table).
- **An activity cannot be reworded alone.** An own activity replaces the one of its name, steps and all, so changing a label or an `about` means copying the steps; 37 activities are copies.
- **A decoration's spot is its piece's name**, so renaming a decoration (`window` to `viewport`) orphans the inherited activities that go to it; five are restated.
- **A piece's `in_use` art follows one spot, the nearest to the cells the piece covers** (the first when tied). A piece with two spots shows it for one (the terminal: the comms console is the first), and a piece used from a distance needs empty columns in its art to bring its spot inside (the crates and the dispenser carry three, as the default's cabinet carries seven).
- **Art cannot be derived from another piece's**: the recoloured props are copies.
- **At 60 columns** the food dispenser is cut by the window's edge (its spot is in the plan; the first seven of its ten columns show).

## Spec conflicts

- The plan's §5 and the brief say droids; A571 says no trademarked names. A571 won (point 4); the plan's text stays (rows change only by a converge round).
- The brief's "every state reachable at 60×24" is stronger than the default's accepted state at that size; it is met here by the shorter wall, not by the engine's fallback.

## Tests

232 new cases in four files, every one of the files run in a Neovim of its own (the suite's way). Test first for the plan's contract: the first run of the three files written before the pack existed:

| File | Cases | Red | Arrived green, and why |
|---|---|---|---|
| `test_office_space_station_pack.lua` | 22 | 22: "there is no pack “space_station”", the loader gave the default pack | none |
| `test_office_space_station_switch.lua` | 6 | 4 (`office.pack` naming it, a list picking the last, no problem told, `Aineo office check`) | 2 by nature: the default is drawn when `office.pack` names it or a list picks it first; killed by M3c |
| `test_office_space_station_states.lua` | 160 | 42: every state that starts at a desk, the bench or the printer at 60×24 (the default's plan lacks them), the comms console at three sizes, the trigger and its walk at three sizes | 118: the default's own behaviour at 100×40 and 220×80, which the pack inherits; killed by M2, M2b–M2d |

Added afterwards, each pinning data written ahead of its test and so arriving green; the mutant that kills each is in the table: the stars of the four hours and their drift (M6, M7, M15), the transmission's arcs and label (M8, M9), nothing left out at four sizes (M10), the stretched runs (M21), a push from the tracker to the stage (M1), the starhare's fur (M17), and `test_office_space_station_life.lua` (20 cases: the reworded labels, the spots of the five restated activities, two idle crew playing the holo game, the starhare at the specimen tank, petting: M12–M14, M18, M19). Three cases of the first life file asked for the starhare's labels in the status list; the list names agents only, so they were red for a reason that is not the pack's and were dropped.

Totals after the last edit: see the pull request.

## Mutants

Each is the literal edit, run on the files that exercise it from a pristine copy of the file, restored after; every kill is an assertion failure (no Lua error in any run).

| Mutant | Literal edit | Killed by |
|---|---|---|
| M1 | `pack.lua`: `command = 'git push'` → `command = 'git pushed'` (the trigger never matches) | assertion: states 4, pack 1 |
| M2 | `floor.txt`, baseboard row, column 32: `b` → `z` (the holo-table spot; thinking and planning have nowhere) | assertion: states 18 |
| M2b | `floor.txt`, baseboard row: `p` at column 17 → `z`, `z` at column 62 → `p` (reporting unreachable at 60 columns) | assertion: states 4 |
| M2c | `floor.txt`, row 17, column 41: `s` → space (no desk seat at 60×24) | assertion: states 27 |
| M2d | `floor.txt`: every `Q` and `q` → space (no bench seat) | assertion: states 19 |
| M2e | `floor.txt`, baseboard row, column 12: `k` → `z` (no comms console) | assertion: states 7 |
| M3 | `pack.lua`: `floor_colour = 'deck'` → `'floor'` | assertion: switch 2 |
| M3b | `pack.lua`: `based_on = 'default'` → `false` | assertion: pack 21, switch 4 |
| M3c | `default/pack.lua`: `floor = '#303446'` → `'#242e3c'` (the default draws the station's deck; kills the two cases that arrived green) | assertion: switch 2 |
| M4 | `pack.lua`: the `cat` table removed (the default's cat shows through) | assertion: pack 2; survives the states file |
| M5 | `pack.lua`: the `subagent` table removed | assertion: pack 2 |
| M6 | `art/sky_day.txt` replaced by the default's `sky_day.txt` | assertion: pack 1, states 2 |
| M7 | `art/sky_day.txt` cut to its first frame | assertion: pack 1, states 1 |
| M8 | `pack.lua`: `, effect = 'transmitting'` removed from the step | assertion: states 1 |
| M9 | `pack.lua`: the line `label = 'sends a transmission',` removed | assertion: states 1 |
| M10 | `floor.txt`: every `#` of rows 0–8 → `l` (a light bar in every wall cell; more than 2,000 pieces at 300 columns) | assertion: states 1 (300×120 only) |
| M11 | `pack.lua`: `decorations = { 'viewport', 'coolant_tap'` → `{ 'coolant_tap', 'viewport'` | assertion: pack 1; survives the states file |
| M12 | `pack.lua`: `at = 'viewport'` → `at = 'window'` | assertion: life 2, pack 1 |
| M13 | `pack.lua`: `label = 'plays a holo game'` → `'plays table tennis'` | assertion: life 1 |
| M14 | `floor.txt`: every `j` → space (no right end of the game table) | assertion: life 2 |
| M15 | `art/sky_night.txt`: `A = space_black` → `A = day_top` | assertion: states 1, pack 1 |
| M16 | `pack.lua`: the crew's standing pose drawn with `'bean', 'bean_face_front'` | assertion: pack 2 |
| M17 | `art/starhare_sit.txt`: `B = agent,` → `B = agent_light,` | assertion: pack 2 |
| M18 | `pack.lua`: `label = 'pets the starhare'` → `'pets the cat'` | assertion: life 1 |
| M19 | `pack.lua`: `at = 'specimen_tank'` → `at = 'fish_tank'` | assertion: life 1, pack 1 |
| M20 | `pack.lua`: `u = { piece = 'crew_bench_back' }` → `'sofa_back'` | assertion: pack 1 |
| M21 | `floor.txt`, row 9, columns 34–37: `B` → `#` (the holo-table's run four cells short) | assertion: states 3 |

Survivors, and where they are killed: M4 and M11 survive the states file and die in the pack file (the default's cat shows through a removed pet; the viewport is a decoration in either order). M17 survived the states file in the first round and was killed only after the pack case on the starhare's fur was added.

## Open threads

- The pack's look is to be seen by the user: the crew's helmet and the bots' single lens are the first things to change if they do not read.
- T136's chapters should list `space_station` among the packs and use it as the worked example of `based_on` and a trigger.

## Commits

*Recorded after the merge.*
