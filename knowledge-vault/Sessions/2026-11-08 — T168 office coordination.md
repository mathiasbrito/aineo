# 2026-11-08 — T168 office coordination

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t168-office-coordination` (from `dev` at b90ebe8a) · **Pull request:** into `dev` (number recorded after the merge)

T168 (D143): the office keeps working subagents, the main agent coordinates while any is in the room, the coffee machine plays once from the agent's arrival, and the sofa mug is drawn in front of the sofa. A regular packet in wave 21 (D26 holds: the test files it touches while working, the whole suite once before the push).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — D143 in *Rulings recorded after the merge*, the T168 row in §6, states 13, 21 and 24 in §2, the default pack's activities in §3
- [[Planning/aineo — v1 agent console]] — the D143 row
- `knowledge-vault/Implementation/office-default-pack-converter/brew_art.lua` — writes the two new art files
- `doc/aineo.txt` — *aineo-office*, *aineo-office-states*, *aineo-office-poses*, *aineo-office-floor*, *aineo-office-spots*, *aineo-office-random-life*

## What was done, and why

- **Subagents stay.** `QUIET_SUBAGENT_SECONDS` is 3600 (the replay uses it too) and `WAITING_SUBAGENT_SECONDS` is 600: from ten silent minutes a subagent shows `waiting` and stays at its desk. A subagent whose starting call still runs, or that waits for permission, is exempt from both, as D119 had it for the one.
- **The main agent coordinates.** A subagent that waits counts as in the office, so the main's turn end shows `waiting_for_subagents`; its `done` event is not brought while one is in the room (the tracker hands each signal `subagents_in_room`). The default pack plays `go_through_papers`, `check_a_subagents_screen` and `write_the_plan_on_the_whiteboard` for it, in turn through the random life.
- **A break is not cut.** The director has an agent whose state changes between `done`, `idle` and `asleep` finish the steps of the activity the old state asked for, and then play what the new state asks for; a working state still cuts it.
- **The machine is used once.** Legend field `in_use_once`: the art plays from the moment a character comes to rest at the spot (`rests_at`, `rests_since`), holds its last frame, and a walker starts nothing.
- **The cup is carried and the mug is in front.** Pose fields `walks_as` and `in_front`.
- **Plan spots.** `a_subagents_screen` and `its_desks_end`, chosen by the desk they face on its row.

## Decisions

- **D143** (the user's, 2026-11-08): recorded in the office plan with the user's words.
- **`waiting` is the silent subagent's state** (mine): a 25th state would change every pack, test and help table that counts 24; the parent `waiting` is a name every pack already maps or falls back from. The five fillers that named it are dropped.
- **Spots by the desk they face, not by number** (mine, after the first build): a window that cuts a plan row short, and the stray cell at the end of a repeated block, broke "the n-th spot is the n-th desk's" (measured: 4 desks, 6 ends at 100×40).
- **`in_use_once` is opt-in** (mine): making every in_use piece wait for an arrival changes when the door opens for the agents that walk in.
- **The space-station pack, based on the default, got poses and plan cells of its own** (mine): it inherits the default's activities and poses, so it failed its own check and drew beans until it did.
- **Not deleted:** `arm_hold_cup_sofa`, which the space station draws with.

## Unit list (as sliced)

1. A subagent silent for 11 minutes stays, one silent past an hour leaves, a replay brings in one silent for 20 minutes.
2. A subagent silent for ten minutes shows `waiting`.
3. The main agent's turn end brings no `done` while a subagent is in the office; a subagent's does.
4. A change between resting states does not cut a break; a working state does.
5. A piece used once plays from the arrival, holds its last frame, and a walker starts nothing.
6. A pose that walks as another has its character walk so until it takes another pose.
7. A pose's `in_front` piece is drawn over what stands in front of the agent.
8. `a_subagents_screen` and `its_desks_end`.
9. The default pack, the space station, the art, the docs.

## Tests and evidence

Reds seen first, with the failure that proved each:

| Unit | Test | Red |
|---|---|---|
| 1 | seven of `test_office_states_quiet`, their hour constants (`written less than an hour before is brought in`, `twenty minutes before is brought in`, `goes quiet an hour after`, `eleven minutes is still in the office`, `walks out, then is gone`, `says something within an hour stays`, `waited for no more, with no other signal heard`) | the subagent left at 600 s |
| 2 | `that says nothing for ten minutes shows that it waits` | `{ thinking, thinking }` for `{ thinking, waiting }` |
| 3 | `does not cheer … a subagent runs`, `… a subagent waits silent` | `done` for `waiting_for_subagents` |
| 4 | `from done to idle goes on with its break, then rests` | cell `1,0` for `0,0`: the break was cut |
| 5 | four of `a piece used once` | the piece was left out (the field unknown), then walk-over and frames from the stage clock |
| 6 | `that walks as another has the agent walk in that pose …` | agent colour for the carrying art |
| 7 | `draws its in_front piece over a piece that stands in front …` | the piece's colour for the brown over red |
| 8 | three of `test_office_scene_named_spots` | the nearest plain spot, `3,0` for `5,0` |

Arrived green, and why: `from done to working leaves its break at once` (existing behaviour; killed by M6), `does not walk so after a pose that does not` (killed by M12), `without an in_front piece leaves the agent behind` (existing behaviour), `is done when its turn ends while another subagent is in the office` (pinned the `is_main` guard written with unit 3; first mutant M4 survived the suite until this test), `whose transcript was last written twenty minutes before waits at once` (by nature of the replayed `heard_at`; M2), the default-pack tests of `test_office_default_life` and `test_office_default_coffee` (the pack was written before them, a declarative file; D1, D2, D3 and M14b show they bite).

## Mutants (the literal edit; narrowed to the test files that target it)

| Mutant | Killed by |
|---|---|
| `timing.lua` `QUIET_SUBAGENT_SECONDS = 3600` → `600` | assertion, 8 |
| `tracker.lua` `record.heard_at = now - (…)` → `record.heard_at = now` | assertion, 2 |
| `display.lua` `if record.waits_at and now >= record.waits_at then` → `if false then` | assertion, 3 |
| `record.lua` `if not (is_main(record) and hearing.subagents_in_room > 0)` → `if not (hearing.subagents_in_room > 0)` | survived the first suite; assertion once `is done when its turn ends while another subagent is in the office` was added |
| `record.lua` `hearing.subagents_in_room > 0` → `> 1` | assertion, 2 |
| `director.lua` the two `roles.is_resting` conditions removed | assertion, 1 |
| `director.lua` `if performer.plays_wanted_after_steps and has_reached_last_step(performer) then` → `if false then` | assertion, 1 |
| `furniture.lua` `and (not placed.in_use_once or character.rests_at ~= nil)` removed | assertion, 1 |
| `furniture.lua` once frame → `math.min(#piece.frames, items.frame_after(piece, drawing.now))` | assertion, 2 |
| `items.lua` last frame held → `% #piece.frames + 1` | assertion, 1 |
| `poses.lua` `if walked_in then` → `if false then` | assertion, 1 |
| `walking.lua` `walker.walks_from` kept from the first walk | assertion, 1 |
| `figures.lua` `depth = feet_row + IN_FRONT_PIXELS` → `feet_row` | assertion, 1 |
| `named_spots.lua` the facing check removed | assertion, 1 |
| `named_spots.lua` the row check removed | survived the first suite; assertion once `does not go to a spot on another row, however near` was added |
| `walking.lua` `walker.rests_at = nil` removed | assertion, 1 |
| `roles.lua` `done` removed from the resting states | assertion, 1 |
| `director.lua` `rests_since` reset on every `arrive()` | survived the first suite; assertion once `goes on playing when the agent goes on to another step at the spot` was added |
| `pack.lua` `in_use_once = true` removed | assertion, 1 |
| `pack.lua` `in_front = 'mug_in_front'` removed | survived: the sofa test replaced the pose's field itself; assertion once it took the pack as it is |
| `pack.lua` `walks_as = 'walking_with_a_cup',` removed | assertion, 1 |

## Open threads

- The main agent's screen visits take the subagent whose spot is nearest by walking, so with several subagents the nearest is visited more than the others; "in turn" holds among the three activities, not among the subagents.
- The five waiting fillers' poses (`drumming`, `looking_at_the_watch`, `tapping_a_foot`, `glancing`) stay in the pack, now used by the permission waits only (`drumming`, `tapping_a_foot` by none): left, not removed.
- Whether a main agent that `done`-cheers nothing at all when its last turn ends with a subagent in the room is what the user wants once the last subagent finishes (it then idles): D143 says so; not measured with the real Claude Code.

## Task lines

- [X] T168 The office keeps working subagents, the main agent coordinates, the coffee and the sofa cup (D143): see the row in the office plan.

## Commits

Recorded after the merge.
