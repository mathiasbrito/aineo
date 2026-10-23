# 2026-10-23 — T131 office live pieces

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t131-office-live-pieces` · **Pull request:** into `feature/t123-office`

A regular packet of the office screensaver (T123; D26 applies). The pieces a plan marks `shows` now follow the world outside the office: the window's sky follows the hour, the whiteboard lists the session's real tasks and ticks them, the printer prints a page when an agent reports, and a monitor shows the clue of a web search and the verdict of a test run.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T131's row in §6, §3 (the `shows` field and the art `area` names), §2 (OF13, states 4, 9, 11, 16), D109, A567, A570, A573, A587
- `lua/aineo/office_states/` (`tasks.lua`, `clues.lua`, `details.lua`, `record.lua`, `tracker.lua`), `lua/aineo/office_scene/` (`areas.lua`, `sky.lua`, `whiteboard.lua`, `printing.lua`, `monitor_notes.lua`, `live_pieces.lua`, `cell_text.lua`, `furniture.lua`, `status_list.lua`), `doc/aineo.txt`
- `tests/test_office_states_details.lua`, `tests/test_office_scene_{sky,plan,printing,monitor}.lua`, `tests/helpers/office_signals.lua`

## Task lines

- [X] T131 Live pieces (C18, C20; D109, A567, A570, A573, A587): `shows = 'sky'`, `'plan'`, `'printing'`; the monitor's web clue; ✓ / ✗ for a test run

## What was done

Units, each its own commit or part of one:

1. **Details of an agent** (`aineo.office_states`). Each agent the tracker lists carries `details`: `tasks` (a `TodoWrite` is the whole list; `TaskCreate` adds one; `TaskUpdate` finishes the one its number names, numbered by creation order), `web_clue` (a search's query, a fetch's host only — never the path, query string or credentials), `test_verdict` (`passed` and when, from the result of a test run's call; cleared when a new run starts) and `reported_at` (when the agent called the report tool). Signals read from the transcript's tail set no verdict and no report: they are not happening now.
2. **The sky.** A piece with `shows = 'sky'` paints the pack's piece `sky_night`, `sky_dawn`, `sky_day` or `sky_dusk` for the hour of the stage's wall clock into its `sky` area (night 21–5, dawn to 8, day to 17, dusk to 21), clipped to the area; none without a clock or without the piece.
3. **The whiteboard.** `shows = 'plan'` writes the main agent's tasks a row each into the `plan` area, `✓ ` before the done (in the `name` text colour) and `○ ` before the others (`status`), cut to the area by display width; when the tasks outgrow the rows it starts at the first not done, or ends with the last.
4. **The printer.** `shows = 'printing'` lets the pack's piece `printed_page` come out of the top of the `page` area a pixel row at a time for four seconds after the latest `reported_at` of any agent.
5. **The monitor.** The clue is written into the monitor's `query` area while its owner is on the web; the verdict is `✓` (green) or `✗` (red) at the top left of its `screen` area for three seconds from the result.
6. **Structure.** The dispatch on `shows` moved from `furniture.lua` to `live_pieces.lua` (time and date unchanged); `areas.lua` gives the canvas pixels of a placed piece's area; `cell_text.lua` is the status list's cut, now shared.
7. **Help.** `aineo-office-live` in `doc/aineo.txt` replaces "not drawn yet".

## Reported, not chosen

- **The names of the four skies and the page.** §3 says the sky is "four art files: night, dawn, day, dusk" without naming them, and the `page` area without naming its art. The engine looks for the pack pieces `sky_night`, `sky_dawn`, `sky_day`, `sky_dusk` and `printed_page`. T133 draws them; T134's help (`aineo-office-live` is the start of it) carries the names.
- **The globe is the pack's.** The monitor's globe is the `screen` piece of the pose of the on-the-web activity (the existing `screen` machinery); the engine writes the clue text only. If the globe should come from the engine, say so.
- **The verdict is not a state.** A failed test run is no error (the lifecycle case stands) and the result moves the agent to thinking at once, so the ✓ / ✗ cannot ride on the state `running_tests`. It is a detail with its time, shown for three seconds, and so shows over the next state's screen.
- **Task numbers.** A `TaskUpdate` names its task by the number Claude Code gave it, which the transcript's call does not carry; the tracker counts the `TaskCreate` calls it heard. When the 256 KiB tail starts after some creations, the numbers are off and an update ticks the wrong row or none. A tier-2 limit of the same kind as OF1–OF15; the recordings of T128 do not cover it.
- **The main agent's tasks only.** Subagents keep tasks of their own (the tracker lists them) but the board shows the main agent's.
- **`tests/test_office_states.lua`'s whole-table expectation** for a fresh agent now lists `details = { tasks = {} }`.

## Tests

71 cases in five files, all green on the final tree. Test first; red seen by name, green-on-arrival said with the mutant that kills it.

| File | Cases | Red seen / why green |
|---|---|---|
| `test_office_states_details` | 22 | red (`details.tasks` nil, or a field missing): TodoWrite list; TaskCreate; TaskUpdate to completed; web clue of a search; host of a fetch and of a scheme-less address; verdict passed and failed; verdict gone on a new run; report told and told still after the result. Green on arrival: TaskUpdate to another status, of a task nobody made, and naming no task (pins of code written with the unit; D3, D4); tasks per agent (written with the record; the tracker mutant dropping `details` fails it); web clue gone after the result (nil by nature; D14); clue none for a call that looks nothing up (nil by nature; a mutant returning `input.file_path` kills it); IPv6 host (a pin after the bracket branch was found redundant); verdict none for a non-test command, for a replayed result (D11, D10); report none for another tool, for a replayed call (D13, D12) |
| `test_office_scene_sky` | 15 | red: the ten hours (a fixture where the glass shows the frame's brown); green on arrival: the three negatives (no clock, no piece, and the frame left as it is — K7, K1, K8), and the cases added after K8, K9 and K10 survived (clip, anchor, frames) |
| `test_office_scene_plan` | 11 | red: the list with ticks, the colours, the cut, the `?` for control and wide characters, no more rows than the area, the scroll cases ×3 (the first four on a fixture whose board stood a row too high, so their red was the missing painter, shown again by mutant P1); green on arrival: no tasks (a mutant inventing a task), no details (the same), the main agent's only (P8) |
| `test_office_scene_printing` | 10 | red: the first page; green on arrival: no page before a report (R10), further, whole pixel rows (R4), a report yet to come (a mutant taking `abs`), the frames (R8), the page away (R2, R9), a subagent's report, the latest report (R5), no page in the pack (a mutant falling back to the printer's art) |
| `test_office_scene_monitor` | 13 | red: the clue, its cut, its `?`, its colour, the owner's own; the tick, the cross, just-before-three-seconds, own agent only; green on arrival: no clue off the web (M1), none when nothing is looked up (a mutant writing `web`), gone after three seconds (M7, M8, M9), an absent agent (M10) |

`tests/helpers/office_signals.lua` gains `details()` and `details_after()`.

## Mutants

Each applied to a pristine copy, run alone on the test file of its unit, restored; 54 run on the final tree, all killed by an assertion (M10 also by crashes in ten other cases). Two more are equivalent: the removed bracket branch of the host (a port after `]` is stripped by the same cut) and the removed negative guard of the printer (a negative height clips to nothing); both were deleted from the code.

| # | Literal edit | Killed by |
|---|---|---|
| D1 | `tasks.lua`: `done = todo.status == COMPLETED` → `done = false` (a finished task not ticked) | TodoWrite list |
| D2 | `tasks.lua`: the update's `done = input.status == COMPLETED` → `done = false` (a finished task not ticked) | TaskUpdate to completed |
| D3 | same → `done = true` | TaskUpdate to another status |
| D4 | `tonumber(input.taskId)` → `… or 1` | TaskUpdate naming no task |
| D5 | `clues.lua`: `host_of(input.url) or nil` → `input.url or nil` (the full URL instead of the host) | host cases ×3 |
| D6 | `:gsub(':%d*$', '')` → `` (the port kept) | host cases ×2 |
| D7 | `:gsub('^.*@', '')` → `` (credentials kept) | host case |
| D8 | `record.lua`: `passed = not signal.failed` → `signal.failed == true` (✓ for a failed run) | verdict ×2 |
| D9 | the clear of the verdict at a new test call removed | verdict gone on a new run |
| D10 | the replay guard of the verdict removed | verdict from the past |
| D11 | `if call.state == 'running_tests'` → `if true` | verdict of a non-test |
| D12 | `and not hearing.replayed` removed from the report | report from the past |
| D13 | the report condition → `if not hearing.replayed` | report of another tool |
| D14 | `record.open_calls[id] = nil` removed | web clue gone after the result |
| K1 | `sky.lua`: `return 'sky_' .. phase_at(hour)` → `'sky_night'` (the sky not following the hour) | ten hours, no-sky case |
| K2–K5 | `from = 5/8/17/21` → `6/9/18/22` | one hour each |
| K6 | `hour >= candidate.from` → `>` | four hours |
| K7 | no wall clock → noon | no clock |
| K8 | clip to the glass → clip to the plan | wider sky over the frame |
| K9 | `column = glass.column + view.anchor.column` → `glass.column` | anchor |
| K10 | `frame_after(view, …)` → `1` | frames |
| P1 | `plan = whiteboard.paint` removed | nine cases |
| P2 | the tick always `BULLET` | ticks |
| P3 | tick and bullet swapped (a finished task not ticked) | eight |
| P4 | one colour for all rows | colours |
| P5 | no cut to the area | cut, `?` |
| P6 | the list always from the first task | scroll ×3 |
| P7 | `math.min(first_not_done, #tasks - rows + 1)` → `first_not_done` | three |
| P8 | any agent's tasks | main only |
| P9 | `rows = 99` | four |
| P10 | row off by one | nine |
| R1 | `printing = printing.paint` removed (the printer not printing on a report) | six |
| R2 | `>=` → `>` | page away |
| R3 | all rows at once | seven |
| R4 | `floor` → `ceil` | whole pixel row |
| R5 | latest report → earliest | latest of several |
| R6 | no clip to the printed rows | eight |
| R7 | anchor row ignored | six |
| R8 | frame 1 | frames |
| R9 | the print never over | page away |
| R10 | the `seconds` guard removed | no page before a report |
| M1 | the web state check removed | off the web |
| M2 | clue not cut | `?` |
| M3 | any agent's monitor | own agent ×2 |
| M4 | other colour | colour |
| M5 | ✓ for every verdict (✓ shown for a failed test) | cross |
| M6 | ✗ for every verdict | tick ×3 |
| M7–M9 | `<` → `<=`; no time limit; four seconds | three-second cases |
| M10 | the owner guard removed | absent agent (and ten crashes) |

Also killed: the tracker not listing `details` (fifteen cases), `clues.of_call` returning `input.file_path` (five), a board that invents a task (the no-details case), a printer that falls back to its own art (the no-page case), `abs` of the printed height (a report yet to come), a monitor writing `web` for no clue (the nothing-looked-up case).

## Open threads

- T133 draws `sky_night`, `sky_dawn`, `sky_day`, `sky_dusk`, `printed_page` and the globe screen piece; T134's help should keep the names of `aineo-office-live`.
- The task numbers of `TaskUpdate` rest on the tracker hearing every `TaskCreate` (above).
- Frame cost of the new painters was not measured at 220×80 with a pack that uses all of them; each paints a clipped area or a few cells.

## Commits

*Recorded after the merge.*
