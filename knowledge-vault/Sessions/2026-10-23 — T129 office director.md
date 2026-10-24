# 2026-10-23 — T129 office director

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t129-office-director` · **Pull request:** #334, into `feature/t123-office`

A regular packet of the office screensaver (T123; D26 applies). `aineo.office_scene` (C20) now has a director: agents walk the shortest way over the floor, take spots, and play the steps of their activity for their times; poses are drawn with mirrored layers, rises, props and screens; pieces show their `in_use` art and lie on the floor when `walk_over`; a status list takes the last rows; a plan can no longer make a frame costly.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T129's row in §6, §3 (spots, steps, poses, legend entries, art areas), §1 (the stage's interface, the status list); D107, D108, A562, A572, A582, A585.7, A586.2
- `lua/aineo/office_scene/`, `lua/aineo/office/init.lua`, `doc/aineo.txt`
- `tests/test_office_scene_{walking,steps,figures,pieces,screens,shows,budget,status_list,frame}.lua`, `tests/helpers/office_scene.lua`, `tests/test_office.lua`

## Task lines

- [X] T129 The director (C20; D107, A562, A572, A582, A585.7, A586.2): spots, paths over floor cells, steps, poses with layers, `like`, mirroring, `rises`, props, screens, `in_use` pieces, depth order, the status list, the placement budget

## What was done

Units, in the order they were built, each its own commit:

1. **Walking and steps.** The layout knows which cells characters walk on (floor, spots, `walk_over` pieces); `paths.lua` finds the shortest walk by breadth-first search; `spots.lua` gives an agent its own `desk` (by its place among the agents) or the nearest open spot of the name by walking; `walking.lua` moves along a path; the director plays an activity's steps in order, each lasting `for_seconds` from the agent's arrival (a random time between two numbers by the stage's `random`), the last until the activity changes; step `facing` and `effect` over the spot's and the pose's; a trigger's `activity` over the state's. A spot that cannot be walked to leaves the agent where it is; an agent with no open spot is not drawn until one is.
2. **Poses.** The painter is split into `items` (depth order), `furniture` (the plan's pieces), `figures` (the agents) and `painter`. A subagent is drawn from the pack's subagent poses; every layer is mirrored together when the agent faces the other way than the art's `faces`; `rises` lifts by the number for the frame counted from the moment the pose was taken (so do the art's and the effect's frames); `holding` draws a prop at the first layer's `hand` area, on the side the agent faces; a character at a `sitting` spot is ranked behind the pieces in front of it.
3. **`in_use` and `walk_over`.** A piece shows its `in_use` art while a character stands on, or walks over, the spot nearest to it (`use_spot.lua`); a `walk_over` piece is walkable and painted before everything else.
4. **Screens.** The n-th piece with a `screen` area is the n-th agent's monitor; the pose's `screen` piece is painted into that area only, through a `clip` on the canvas's `paint_art`, which now walks only the art pixels that lie on the canvas and in the clip.
5. **The placement budget** (A585.7). The layout places at most 2,000 pieces, the first the plan reads; a frame of the largest office (220×80) full of 24-pixel pieces took 9 ms with the cap and 112 ms without, against the 83 ms between frames.
6. **The status list.** From 24 rows, the last five rows of the picture: a rule and up to four agent lines (a dot in the agent's colour, the name cut to nine cells, the activity's `label` or the office's words for the state), the fourth line counting the rest as `+N more` when there are more than four agents. The plan takes the rows above. `aineo.office` hands the stage the vocabulary's labels. The picture carries `status_list_height` (A586.2, asked for by T132).
7. **Live text.** `shows = 'time'` and `'date'` write `07:05` and `Oct 03` from an injected wall clock into the area of that name (`aineo.office` gives the local time unless given a `wall_clock`).
8. **Help** states how an agent plays an activity, the status list and the cap.

## Reported, not chosen

- **`shows` is split between T129 and T131.** A582 adds `shows` drawing to T129; T131's row owns `time`, `date`, `sky`, `plan` and `printing`. T129 draws `time` and `date`, which need only a clock; `sky`, `plan` and `printing` (and the monitor's query) are left to T131, and the help says they are not drawn yet.
- **The status list's size and threshold.** §1 says "the window's last rows" without a number. Five rows (rule plus four lines), fixed so that the plan is not laid out again when a subagent comes or goes, and shown from 24 rows tall, the least the office is shown at (A560's too-small note is T132's). A stage shorter than that draws the plan alone.
- **`spot.sitting` ranks, it does not pose.** The loader gives every step the pose `standing` when it names none, so a spot's `sitting` cannot choose a default pose; it ranks the character behind the pieces in front of it.
- **Colours go by place.** An agent's colour is the one of its place among the agents (T124's rule); when an agent leaves, those after it change colour.
- **Stage options added:** `random`, `state_labels`, `clock`; the plan's interface listed `random` only.
- **Spots not built:** `anywhere`, `an_empty_desk`, `an_idle_agents_desk`, `next_to_an_agent` and a thing's name are T130's; `even_if_taken`, `the_one_moved_plays`, `leave`, `remove` and `follow` are read but not played.
- **An agent with no `at` on its first step** is put at the spot `door`, and is not drawn when the plan has none.
- **Text is above all pixels.** Effects, the clock's text and the status list are a text layer over the canvas, so an agent walking in front of the clock does not cover its text.
- A pack with one very large piece in every placement: the cap bounds the placements and `paint_art` bounds each to the canvas, so a frame costs at most the cap times the canvas; measured at 220×80 with 24-pixel art, not with 400×200 art.

## Tests

Test first; a case that arrived green says why.

| Test file | Cases | Red seen / why green |
|---|---|---|
| `test_office_scene_walking` | 2 | the wall detour (1 red: the path crossed the wall); the walled-in spot arrived green (the code was written with the first unit; mutants M01, M11) |
| `test_office_scene_steps` | 12 | for_seconds and its random range (2 red); the step effect, with and over the pose's (2 red); the rest arrived green (written with the director: facing ×2, trigger activity, same activity kept, nearest free spot, own desk, a spot let go, a departed agent) — M06, M29, M12, M13, M14, M30, M31, M39 |
| `test_office_scene_figures` | 10 | subagent poses, `faces` ×2, rises, prop, sitting spot (6 red); the effect rising with the agent, the effect restarting with the pose, the last column (red under their mutants M32, M36); mirrored layers arrived green (M03, M03b) |
| `test_office_scene_pieces` | 7 | `in_use` ×2 and the rug under an agent (3 red); the walk over a rug and round a piece that is not `walk_over`, and the visible-reads count arrived green (M24, M33b) |
| `test_office_scene_screens` | 3 | screen content and the second monitor (2 red); the monitor's own art arrived green |
| `test_office_scene_shows` | 4 | time, date, cut to the area (3 red); no clock arrived green |
| `test_office_scene_budget` | 2 | the cap (1 red: the last row was painted); the frame cost went from 112 ms to 9 ms with the cap and fails under 83 ms only without it (M05) |
| `test_office_scene_status_list` | 10 | the list's rows, rule, lines, labels, cut, overflow (7 red), `status_list_height` (1 red); the short stage arrived green |
| `test_office_scene_frame` | 3 | three frames derived by hand before the first run (door, a tenth of a second on the way, seated with dots); they arrived green, pinning the units above together |
| `test_office` | +2 | the vocabulary's labels and the wall clock reach the stage (2 red) |

## Mutants

Each applied to a pristine copy, run alone, restored (`git status` clean after) against the scene's test files and `test_office`; all 44 killed by assertion in at least one case, none survived on the final tree. M36 survived the first run and is why the last-column test exists; M33 is also killed by crashes in two files.

| # | Literal edit | Killed by |
|---|---|---|
| M01 | `floor_layout.lua`: `if letter == FLOOR or (entry and entry.walk_over) then` → `if true then` (dispatch: a path crosses a non-floor cell) | walking ×2, pieces ×1 |
| M02 | `director.lua`: `performer.step_seconds = seconds_of(...)` → `nil` (dispatch: a step field, `for_seconds`, ignored) | steps |
| M03 | `figures.lua`: `mirrored = facing_left ~= (layer.faces == 'left')` → `false` (dispatch: a mirrored layer drawn unmirrored) | scene, figures |
| M03b | the same → only the first layer mirrored | figures |
| M04 | `furniture.lua`: `is_in_use(...) and placed.in_use or placed.piece` → `not is_in_use(...) and ...` (dispatch: `in_use` art while the spot is free) | pieces |
| M04b | → `placed.in_use or placed.piece` (always in use) | pieces |
| M04c | `is_in_use` also requires `character.pose ~= 'walking'` | pieces (the walk-over case) |
| M05 | `floor_layout.lua`: `if #layout.pieces < MAX_PLACEMENTS then` → `if true then` (dispatch: the placement cap removed) | the timing case only on the first push (its cap case read rows that the status list had taken since, and was floor with or without the cap); since the review round, also the cap case on the plan's 2,000th and 2,001st cells |
| M06–M09 | `director.lua`: step `facing`, `effect`, `pose`, `at` each ignored | steps, figures, scene |
| M10 | `director.lua`: a random `for_seconds` always the shortest | steps |
| M11 | `spots.lua`: `if not character.column then` → `if true then` (every route is an empty walk, so an agent never walks) | walking (the wall detour; the walled-in case stays put with or without it) |
| M12 | `spots.lua`: the farthest spot instead of the nearest | steps |
| M13 | `spots.lua`: spots other agents have taken are open | steps |
| M14 | `spots.lua`: `if name == OWN_DESK then` → `if false then` | steps |
| M15 | `figures.lua`: rises counted from the stage clock | figures |
| M16 | `figures.lua`: the prop on the wrong side | figures |
| M17 | `furniture.lua`: every screen belongs to the first agent | screens |
| M18 | `furniture.lua`: the screen's clip removed | screens |
| M19–M21 | `status_list.lua`: no overflow line; names cut to ten cells; the state's words over the activity's label | status_list |
| M22 | `figures.lua`: a sitting spot does not seat its agent | figures |
| M23 | `furniture.lua`: a `walk_over` piece depth-sorted like the others | pieces |
| M24 | `floor_layout.lua`: `walk_over` pieces not walkable | pieces |
| M26 | `poses.lua`: a subagent drawn with the agent's poses | figures |
| M27 | `figures.lua`: the `faces` header ignored | figures |
| M28 | `figures.lua`: the step's effect ignored by the painter | steps |
| M29 | `roles.lua`: a trigger's activity ignored | steps |
| M30 | `director.lua`: an unplaced agent not tried again | steps |
| M31 | `director.lua`: a departed agent keeps its spot | steps |
| M32 | `figures.lua`: effect frames counted from the stage clock | figures |
| M33, M33b | `canvas.lua`: `paint_art` walks the whole art / every column of it | pieces (reads), screens ×2, budget (M33 by crash in pieces and budget) |
| M34 | `use_spot.lua`: a piece used from the first spot made | pieces |
| M35 | `furniture.lua`: live text not cut to the area | shows |
| M36 | `canvas.lua`: a mirrored art's columns counted as an unmirrored art's | figures (the last-column case; survived the first run) |
| M37 | `status_list.lua`: the list shown from any height | status_list |
| M38 | `office/init.lua`: no state words handed to the stage | test_office |
| M39 | `director.lua`: a step's end never reached | steps |
| M40 | `walking.lua`: 140 cells a second | scene, steps |
| M41 | `painter.lua`: `status_list_height` always 0 | status_list |

The whole suite (`make test`) on the first push's tree, on Neovim 0.12.5, on the host: 7000 cases in 200 groups, `Fails (0) and Notes (0)`, exit 0. The review round ran the scene's files, `test_office`, `test_office_default_pack` and `test_doc`; the whole suite on its head is the orchestrator's.

## The review round (A589)

The review of the first push (attack and test integrity) measured what the first round had not, and its findings were fixed in this order, each test first and seen red:

1. **Pinned what was unpinned (A589.12, 13).** The cap case read cells that the status list had taken; it reads the plan's 2,000th and 2,001st now. The reviewer's killing cases for seven surviving mutants (the spot's facing, a rise counted by the first layer's frames, a screen's first frame, a step's time counted from the arrival, the door for a first step with no `at`, the row of a spot in use, a subagent's dot) are in the steps, figures, screens, pieces and status files.
2. **Search only as far as the nearest spot (A589.1).** `paths.nearest` goes a step at a time over flat cell keys and stops at the end of the step in which the first spot is reached: 400 steps of no length took 1.9 s, now 0.1 ms; 65 agents changing activity took 540 ms, now 29 ms; an agent begins at most eight steps in one update.
3. **What a frame can afford (A589.2, 7, 8).** `placements.lua`: at most 2,000 pieces that paint at most sixteen times the plan's pixels, decorations first, then furniture, last pieces that stand on a spot, show something or have a screen or `in_use` art; the scene reports how many were left out and `aineo.office` tells it once each time it shows. 2,000 pieces of 400x200 art hung from their tops: 292 ms, now 7 ms. Lay-out found each `in_use` spot through an index by row and the walls of a row in two passes: 449 ms, now 14 ms for a spot and a piece in use in every cell.
4. **The plan above the list (A589.5, 6, 11).** The plan is cut to its rows; pieces, layers, props, screens and effects are clipped to them; a prop mirrors with its layer and by its own `faces`; a status line counts cells.
5. **Places (A589.3, 4, 9, 10).** An agent has a place from arrival to leaving and its desk, monitor and colour go by it; an agent whose spots are taken keeps its own and looks again every second; a spot that cannot be walked to lets the activity go on; a resize keeps each agent's activity and step; a step's random time is drawn once the agent has a place.

Tests of the round, each seen red before the code (the cases adopted from the review arrived green and were seen red under their mutants):

| Test file | Cases now | Red seen |
|---|---|---|
| `test_office_scene_cost` (new) | 6 | 400 steps of no length (1.9 s), 65 agents changing activity (540 ms), the eight steps an update (20 against 8), 2,000 huge pieces (292 ms), a stage made and resized with a spot and a piece in use in every cell (449 ms) |
| `test_office_scene_budget` | 7 (+4 parametrized) | what is told when pieces are left out (nothing was told), decorations before furniture, the pieces that matter kept (spot, in use, time, screen), the pixel budget (18 pieces left out of an 8x10 stage of slabs; derived by hand) |
| `test_office_scene_places` (new) | 7 | the spot kept while taken (and found by no one else), looking again, the seat kept behind the desk, a place kept across departures, the random draws (26 against 1), a resize mid-walk, a seated agent resized |
| `test_office_scene_status_list` | 18 | the plan cut to its rows (2), a piece hanging over the list, an effect sunk onto it, a wide label (59 cells against 40), the way round below the plan, the dot by place |
| `test_office_scene_figures` | 13 | a prop on the same side whichever way the body faces; a prop that faces left |
| `test_office_scene_steps`, `_screens`, `_pieces`, `_walking` | 16, 5, 9, 3 | the reviewer's cases (green on the head), the tie between spots as near, a screen kept by its agent across a departure (red), the next step after a spot that cannot be walked to (red under its mutant), two spots in use as near (red under its mutant) |

The reviewer's mutants, as the review gave them (all killed by an assertion now):

| # | Literal edit | Killed by |
|---|---|---|
| MDa | `director.lua` `arrive`: `performer.facing = step.facing or (performer.spot and performer.spot.facing) or performer.facing` → `performer.facing = step.facing or performer.facing` | steps: "faces the way the spot it walked to says, when that is left" |
| MH | `figures.lua` `rise_of`: `/ layers[1].seconds_per_frame)` → `/ 0.25)` | figures: "rises by the frames of its first layer" |
| MI | `furniture.lua` `paint_screen`: `items.frame_after(content, math.max(0, drawing.now - owner.pose_since))` → `items.frame_after(content, drawing.now)` | screens: "begins at its first frame when its agent takes the pose" |
| MS | `director.lua`: `performer.arrived_at = time` (in `arrive`) → `performer.arrived_at = performer.arrived_at or time`, with `performer.arrived_at = nil` (in `begin_step`) → `performer.arrived_at = time` | steps: "counts its time from the agent's arrival, not from when its walk began" |
| MK | `director.lua`: `local ENTRANCE = 'door'` → `local ENTRANCE = 'no_such_spot'` | steps: "puts an agent whose first step names no spot at the spot called door" |
| ME | `furniture.lua` `is_in_use`: the row comparison dropped | pieces: "keeps its own art for an agent in its spot's column on another row" |
| MG | `status_list.lua`: `pack[roles.kind_of(agent)].colours` → `pack.agent.colours` | status_list: "dots a subagent in the colours subagents take" |
| M05 | `floor_layout.lua`: `if #layout.pieces < MAX_PLACEMENTS then` → `if true then` | budget: the cap case on the plan's 2,000th and 2,001st cells, and the timing case |

The round's own mutants, killed by an assertion each: B1–B6 (`director.lua`: the cap on steps begun an update removed; `paths.lua`: the last of spots as near taken, the search never stopping early, stopping at the first spot found and not at the end of its step, a walk wrapping from the last or the first column); C1–C18 (`placements.lua`: decorations dropped like furniture, a spot, `in_use`, `shows` or a screen not essential, the first read dropped first, the pixel budget or the cap raised; `floor_layout.lua`: the plan not cut; `furniture.lua`: pieces not clipped; `figures.lua`: the prop mirrored or placed by the facing alone, an effect written onto the list; `status_list.lua`: wide characters kept; `use_spot.lua`: no tie by order; `office/init.lua` and `stage.lua`: what is left out told every time or never); D1–D13 (`director.lua`: no waiting, no looking again, looking every three seconds, a place not freed, a resize that starts the agents again or puts a walker at its spot, the random time drawn before a place, the seat flag lost; `spots.lua`: every desk the first, a spot that cannot be walked to treated as taken; `furniture.lua`, `figures.lua`, `status_list.lua`: the monitor, the colour and the dot by the first place or by position). C8 (a spot below the plan kept) survived as equivalent, since that spot is outside the clip and unreachable, and its guard was removed. D3 and D13 survived until a test was sharpened (half a second after the board was let go; an agent standing at a seat behind its desk while it waits).

## Open threads

- T130 takes the spots the format lists without a legend and the steps' interactions; T131 the contents of `shows` beyond `time` and `date`, and the monitor's `query`.
- T132 puts the report cards above `status_list_height` rows and decides what a stage under 24 rows shows.
- The place an agent has (its colour, desk and monitor) is the director's own, assigned on arrival; a pack author cannot choose it.

## Commits

Pull request #335 merged into `feature/t123-office`; that branch reached `dev` through pull request #344. Each commit below is as it stands on `dev` (a rebase merge replays under new hashes).
Released as v0.2.73 (pull request #345, `main` at `d3df7aff`).

- `573bb541` Walk agents over floor cells and play activities step by step
- `edfac013` Draw poses with mirrored layers, rises, props and seats
- `d2140758` Show in_use art and lay walk_over pieces on the floor
- `57276c7a` Show a pose's screen on its agent's own monitor
- `a4c20a60` Cap the pieces a plan places so a pack cannot make a frame costly
- `ac29dcff` Draw the status list on the last rows below the plan
- `cca71dcf` Write the time and the date into the pieces that show them
- `d45fb34a` Document how agents play activities and the status list
- `2c928b00` Pin a frame's rows, a departing agent's spot and a pose's restart
- `bca3adf8` Pin the columns a mirrored figure shows at the stage's edge
- `f821d78f` Give the picture the rows its status list takes
- `5a12ee40` Record T129, the office director, in the plan and a session note
- `367d5196` Name the pull request in the T129 session note
- `d9795f9c` Pin what the review of the director found unpinned
- `f2c90168` Search only as far as the nearest spot, and begin few steps an update
- `bb8a13ac` Leave out what a frame cannot afford, and lay out in linear time
- `863f0fb8` Keep the plan above the status list, and a prop with its art
- `b0efc5f8` Keep an agent's place, its spot and its walk across arrivals and resizes
- `ec3cb212` Document what a pack can ask of a frame, and the review round
- `72271336` Pin that a report card stands above the status list the scene draws
