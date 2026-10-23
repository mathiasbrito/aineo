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
| M05 | `floor_layout.lua`: `if #layout.pieces < MAX_PLACEMENTS then` → `if true then` (dispatch: the placement cap removed) | budget ×2 |
| M06–M09 | `director.lua`: step `facing`, `effect`, `pose`, `at` each ignored | steps, figures, scene |
| M10 | `director.lua`: a random `for_seconds` always the shortest | steps |
| M11 | `spots.lua`: `if not character.column then` → `if true then` (an unreachable spot is jumped to) | walking |
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

The whole suite (`make test`) on the code's final tree, on Neovim 0.12.5, on the host: 7000 cases in 200 groups, `Fails (0) and Notes (0)`, exit 0.

## Open threads

- T130 takes the spots the format lists without a legend and the steps' interactions; T131 the contents of `shows` beyond `time` and `date`, and the monitor's `query`.
- T132 puts the report cards above `status_list_height` rows and decides what a stage under 24 rows shows.
- The colour of an agent follows its place; a pack author who wants a colour to stay with an agent needs the tracker to give a stable index.

## Commits

*Recorded after the merge.*
