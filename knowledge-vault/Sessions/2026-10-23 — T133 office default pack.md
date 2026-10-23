# 2026-10-23 — T133 office default pack

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t133-default-pack` (built on `feature/t123-office` after T130 landed) · **Pull request:** into `feature/t123-office` (number recorded after the merge)

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
2. **The wall** (rows 0–12, a baseboard on row 13): door (open while someone is at it), whiteboard (tasks in its `plan` area), file cabinet (a drawer open while someone reads or searches), bin under a clock (`time`), coffee machine (brewing while someone gets a cup), printer under a calendar (`page`, `date`), the window (`sky`), and, as the wall allows, water cooler, snake plant, bookshelf, picture, fish tank and the corner plant; ceiling lamps over free wall.
3. **The floor**: rows of desks (a desk, a monitor with `screen` and `query` areas) filling the height, a lounge with a three-seat sofa (back and front pieces, so that agents sit between them), a rug, a low table and a lamp beside the first desk, and a strip of 11 rows under the desk rows with the second lounge and a table-tennis table.
4. **The agents**: a bean in about 45 poses made of layers (body, face with a blink, legs, hands, arms with what they hold) and of composites for what moves together (the paper that falls on the desk, the papers thrown up, a paper ball, spinning, tidying); the monitor's screens, sampled from the mock; about 27 effects.
5. **The 24 states**, each its own activity (states 10, 11, 15–18 too, A573: a spinner, the browser, a hand up with `?`, the printer, `git`, tidying), and what plays in the four parents.
6. **The random life**: fourteen things an idle agent does (`players = 2` for table tennis), five of a waiting one, three seated ones while an answer is awaited, and the cat's eleven (wander, wash, nap for a minute or three on the sofa seat, desk, keyboard, rubbing, following, the fish, a mess, a puddle, a taken seat) with the things it leaves and the agents' reactions.
7. **The older office tests** read the T124 pack's two activities and now read where the head is over for each spot (`office_cells.HEADS`).

## Reported, not chosen

- **60 columns by 24 rows holds no desk.** The plan has 19 rows there (the status list takes 5): the wall's 13 rows and the aisle leave 5 rows of floor, and a seat is 7 rows under the aisle (the mock's 14 pixels). So in a window of 24 rows an agent whose activity starts at a desk, the sofa or the printer has no place on the plan and, by T129's rule, is not drawn; 15 of the 24 states (a test names them). The mock solved it with a camera that follows the agent in focus, which the engine has not (T132 says so too); at 26 rows a desk is there. Choices for a ruling: the camera; a shorter wall; seats closer to the aisle (the look changes); a spot to fall back to when an activity's own is absent. Not chosen here.
- **100 columns by 40 rows holds one desk.** The first desk row is a desk and the lounge (the mock's rule); the second row starts under row 35. A subagent has no desk there and is not drawn while its activity starts at one.
- **The window is a fixed piece, not one of the decorations.** `shows` is read for the plan's own pieces only, not for the pieces a run of decorations places, so the window (and its sky) is at columns 101–124 and appears from 125 columns, ahead of the run of decorations (cooler, plant, bookshelf, picture, tank) that starts at column 140 and shows what the width holds: two at 156, four at 220, all five from 300.
- **A second lounge by height, not by width.** The mock's rule is 180 columns or four desk rows; `from_width` gates a piece and not its spots, so a sofa hidden by width would leave its seats. The strip is the last 11 rows of the plan and shows when the room is tall enough (a plan of 53 rows); `from_width` is not used.
- **Pet the cat is not in the random life.** No spot names the cat (the spots without a legend are `anywhere`, `an_empty_desk`, `an_idle_agents_desk` and `next_to_an_agent`), so an agent cannot walk to it. The cat rubs against legs and follows walkers; D109 and A567 list petting.
- **The water cooler is a drink alone.** A decoration has one spot and `players = 2` needs two; the label is the mock's, "chats at the water cooler".
- **Name plates.** The art format has an `area name` and no painter writes it (T129 did not), so the desks have none.
- **Where the mock drew with positions the engine does not have:** a paper thrown from the desk is thrown from the spot beside the bin; the cup is not carried while walking (the walking pose is the engine's); the box packed is not carried to the door; a task handed to a subagent that walks in is not shown arriving (no step waits for another agent); the clock is digital and the calendar's page dark, since the scene writes their text.
- **The scene's text colours serve the board and the status list both.** `status` and `name` are the colours of the tasks on the white board and of the list on the dark floor, so they are mid greys (`#7c7f93`, `#6c7086`); each reads at about 3.6 to 4 on both.
- **A piece used from a spot is as wide as the way to the spot.** The scene shows a piece's `in_use` art while someone is at the spot nearest to it; the cabinet and the coffee machine are used from the left, and a bin and a printer have spots nearer to them, so their art carries seven empty columns on the left to bring their own spot within it.

## Tests

**Work in progress: handed over at the coordinator's request; the whole suite has not run on the final tree.** Test first for the four files below, each seen failing against the pre-conversion pack (assertion failures, no crash); the pack was generated before the tests were run, so the red is of the old pack against the new contract.

| File | Cases | Red on the T124 pack |
|---|---|---|
| `test_office_default_pack` | 13 | 6: every state mapped in pack.lua itself, the loaded activities, a scene's own activity per state, the cat drawn, the pieces the scene looks for, the live areas; green on arrival (the old pack met them): states given an activity, `check` clean, spots in the plan, art for every piece, effects exist, 64 colours, one cell wide under both 'ambiwidth' |
| `test_office_default_plan` | 15 | 14 (green: no window in a narrow wall) |
| `test_office_default_states` | 105 | 64 (each state starts and ends at its spot at 100x40 and 220x80; the 60x24 list; the pass through the 24) |
| `test_office_default_look` | 19 | 19 |
| `test_office_default_life` | 33 | 33 |
| `test_office_default_cost` | 6 | 0: green by nature; killed by mutant C1 |

Corrections after the first green run, all of the tests' arithmetic, none of the pack: `beside_desk` is 4 at 100x40 (the next row's aisle is in view); the decorations at 156, 220 and 300 columns after the padding became 4; the desk's hands, not its body, are at the desk's top; the second `screen_code` pixel (green) so that a cursor screen cannot pass for code.

The older tests that read the T124 pack changed: `test_office` (rest on the sofa after a turn; a still pack for the no-rewrite case), `test_entry_office` (sofa; the cabinet for the recorded grep; the baseboard for `office.pieces`), `test_entry_office_hooks`, `test_entry_office_life`, `test_office_life`; `office_cells` has `HEADS` and `is_at`.

## Mutants

Each a literal edit on a pristine copy, run against the file that targets it (`.tests/` scratch, not kept; the edits are in the handover report). Killed by an assertion, no crash: D1 (a state left without an activity), D2 (the door spot), D3 (a piece's rows of unequal width), D4 (the second lounge in a small room: the strip moved before the first desk row), P1–P4, L1, L3–L6, L2b (the window, by the look file), S1–S5, K1–K12, F3–F11, C1. **Survivors, not yet killed:** F1 (`players = 2` made `1`: the two idle agents need not play together; the test asks for one moment with both at the table), F2 (the cat's nap `{ 60, 180 }` made `{ 6, 18 }`: the test sums the time asleep over 300 s, and a short nap repeated sums the same; it must ask for one unbroken stay), F12 (a waiting agent that drums at the sofa: the label is all the test reads; it must ask for the desk). A successor strengthens those three tests red first.

## Open threads

- T134's help should list the piece names the engine looks for (`aineo-office-live`) and each activity's `about`, which the pack already carries; T136's guide documents the default pack as the worked example.
- The camera, or whichever the ruling is, for windows below 26 rows.

## Commits

*Recorded after the merge.*
