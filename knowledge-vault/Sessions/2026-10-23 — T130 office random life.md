# 2026-10-23 — T130 office random life

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t130-random-life` · **Pull request:** into `feature/t123-office` (number recorded after the merge)

A regular packet of the office screensaver (T123; D26 applies). In `aineo.office_scene` (C20) an agent whose activity is over now picks the next at random, steps leave things on the floor that anger the agents near them and that an idle agent cleans up, a cat has a life of its own, and a step may take a spot another character is on.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T130's row in §6, §3 (*An activity*, *A step*, *A thing*, the spots without a legend), D109, A567, A575–A589
- `lua/aineo/office_scene/` (`director.lua`, `random_life.lua`, `next_activity.lua`, `parties.lua`, `named_spots.lua`, `things.lua`, `reactions.lua`, `lying_pieces.lua`, `performers.lua`, `following.lua`, `holding.lua`, `relocation.lua`, `durations.lua`, `status_list.lua`), `doc/aineo.txt`
- `tests/test_office_scene_{life,named_spots,things,cat}.lua`, `tests/helpers/office_scene.lua`

## Task lines

- [X] T130 Random life (C20; D109, A567, A587): `during`, `chance`, never twice in a row, random durations, `players`, the cat, things (`leave`, `remove`, upset agents, `cleaned_up_by`), `even_if_taken` and `the_one_moved_plays`, `follow`

## What was done

Units, in the order they were built:

1. **Random life** (`random_life.lua`, `next_activity.lua`, `director.lua`). When the last step of an activity has `for_seconds` and they are over while the state goes on, the performer picks an activity among those whose `during` names its state, by `chance`, never the one it has just played (the state's own included), and only one it can play: the plan has as many free spots as `players` for the first step with a spot and a spot for each step after, and, for a step that follows someone, someone is on the move. With nothing to pick it keeps its last pose and looks again every second. A change of state drops a random pick for what the new state asks for. The activities are listed by name, so a fixed random source picks the same one on every run.
2. **Players** (`parties.lua`). An activity with `players = N` takes along N-1 other agents drawn at random among those placed on the plan in a state its `during` names; all begin it together and each step lasts the time the first to begin it drew.
3. **The spots without a legend** (`named_spots.lua`). `anywhere` (a walkable cell the random source picks, cells listed in order), `an_empty_desk`, `an_idle_agents_desk` (the desk of another agent in the state `idle`, away from it), `next_to_an_agent` (the free cells beside another agent standing still, facing it), and a thing's name. `availability` answers whether a step can be played without drawing.
4. **Things** (`things.lua`, `lying_pieces.lua`, `reactions.lua`). A step's `leave` lays the thing at the character's feet as the step ends and `remove` takes the one of that name off the cell; a thing is drawn under what stands on its cell. The agents within `upsets_agents_within` cells play `upset_agents_play`; the idle agent nearest to it plays `cleaned_up_by`, first, so it is not also upset; a thing nobody can clean waits for an idle agent. Both are interludes: afterwards, or when the state changes, the agent goes back to what its state asks for.
5. **The cat** (`performers.lua`). `how_many` cats (at most four) with the activities that have `who = 'cat'` and `during = { 'always' }`; no place among the agents (no desk, no monitor, no row in the status list), its colour by its number.
6. **`even_if_taken` and `the_one_moved_plays`**; **`follow = 'someone_walking'`** (`following.lua`): the cat trails the nearest character on the move for the step's time, or until that one stops or leaves.
7. **The status list** says the label of the activity played, not of the one the state asks for.
8. **Help** (`doc/aineo.txt`, *Activities, things and states*) and the module header of `aineo.office_scene`.
9. **The director split.** It had grown to 896 lines; it is now 553 and the rest has a file each inside the home (`durations`, `holding`, `following`, `reactions`, `next_activity`, `relocation`, `performers`). No `require` leaves the home.

## Reported, not chosen

- **`follow` has one value.** The pack format accepts any name (`follow = schema.name`); the engine follows only `someone_walking` (a step naming another is a step with no spot) and the help says so. The pack check (T125's) does not refuse another name: a follow-up for `office_pack`.
- **An idle agent is one in the state `idle`.** The states that fall back to resting (`done`, `asleep`) do not clean, play or go to a desk.
- **`even_if_taken` takes the nearest spot of the name, taken or not** (the plan: "though another character is there"); a pack that wants a cat to nap on a free seat and another to jump on a taken one writes two activities.
- **A pick requires a free spot for the first step with one**, not only that the plan has one: an agent never picks a game it would only wait for.
- **Caps the plan does not state:** four cats, 64 things lying, four characters moved one by another in a row (two cats whose steps took each other's seat overflowed the stack before it), eight steps begun an update (T129's).
- **A step that never ends leaves and removes nothing**: `leave` and `remove` act as a step ends, and the last step without `for_seconds` does not.
- **A character that is moved or sent starts its new activity at the time of the update that moved it, so it begins to walk in the next frame.**
- **Found on the way and fixed:** a resize that took an agent's cell away left it in the list of placed characters, and the next picture failed on its position; an agent waiting for a spot waited for ever when every spot of the name was gone; a performer left by a new layout without a way to a thing's spot (not in the legend) stood still.
- **`mcp__aineo__announce_work`** answered "not taken" when called at the start of this packet; the worktree and branch are named here instead.
- **A bare `git stash`** was run once by mistake while measuring a red; it was the only entry on the shared stack, recovered with `git stash apply <sha>` and dropped by name, the tree unchanged.

## Tests

Test first; a case that arrived green says why.

| Test file | Cases | Red seen / why green |
|---|---|---|
| `test_office_scene_life` | 15 | plays an activity of its state (stayed put), goes back to its state's activity on a change of state, never picks an activity whose spot the plan lacks, a game for two starts together, a game for two with one agent, players stay for the same time, the status list's label of the pick (7 red); the chance, the never-twice cases (2), nothing in a state not named, a table with one end, partners in a state not named, partners not placed, looking again arrived green: `random_life` and `next_activity` were written with the first unit, pinned by the mutants R1–R3, R6–R10, D1, D2b |
| `test_office_scene_named_spots` | 8 | anywhere, an empty desk, an idle agent's desk, beside an agent (4 red); no idle agent, an agent on the move, a cell off the plan, facing arrived green with the code of the unit: mutants N4, N6, N8, N7 |
| `test_office_scene_things` | 15 | leave, remove, upset, cleaned by the nearest idle agent, waits while none is idle, a spot that is gone, cleaning after a resize, a resize that drops things (8 red); not upsetting the cleaner, the nearest only, the other idle agents left alone, the claim of a cleaner who stops being idle, the leaver cleaning its own mess, the cap of 64 arrived green: mutants T2, T5, T6, T4, T13 |
| `test_office_scene_cat` | 12 | the cat's own life, a seat an agent is on, following, following only `someone_walking`, two cats taking each other's seat (stack overflow) (5 red); no place among the agents, the split of `who`, the cat's mess chain, colours and four cats at most, stopping when the agent left, no desk of its own arrived green: mutants C10, C7, T8–T9, C3, C4, C6 |

## Mutants

Each applied to a pristine copy, run alone against the test files that target it, restored; the table is of the final tree.

The dispatch's five are D1 (the same behaviour twice in a row), D2a/D2b (`players = 2` started with one), D3 (the mess never cleaned with an idle agent present), D4 (the cat not taking an occupied seat) and D5 (a colour changing mid-stay). "assertion" is a failed expectation; "assertion/crash" means the mutant also raised an error in some cases and failed an expectation in at least one. Every mutant was killed by an assertion in a file that targets it, but T10r, which is equivalent.

| # | File and literal edit | Killed by |
|---|---|---|
| D1 | `random_life.lua`: `life.name ~= last_played ⏎       and vim.list_contains` → `vim.list_contains` — the same behaviour twice in a row | life: 2 assertion |
| D2a | `next_activity.lua`: `and #possible_partners(context, performer, activity) >= activity.players - 1` → `and true` — players = 2 started with one (partners not needed) | life: 4 assertion |
| D2b | `next_activity.lua`: `local needed = activity.players ⏎` → `local needed = 1 ⏎` — players = 2 started with one (one spot enough) | life: 1 assertion |
| D3 | `reactions.lua`: `roles.is_idle(agent) and agent.playing` → `false and agent.playing` — the mess never cleaned with an idle agent present | things: 7 assertion; cat: 1 assertion |
| D4 | `named_spots.lua`: `return even_if_taken or world.taken[spot] == nil or world.taken[spot] == character.id` → `return world.taken[spot] == nil or world.taken[spot] == character.id` — the cat not taking an occupied seat | cat: 2 assertion |
| D5 | `director.lua`: `table.insert(context.agents, performer) ⏎` → `table.insert(context.agents, performer) ⏎       performer.colour_index = #context.agents ⏎` — a colour changing mid-stay (colour by position among present agents) | places: 1 assertion; life: 0 -; cat: 0 - |
| R1 | `random_life.lua`: `remaining = remaining - life.activity.chance` → `remaining = remaining - 1` — chance ignored when drawing | life: 1 assertion |
| R2 | `random_life.lua`: `total = total + life.activity.chance` → `total = total + 1` — chance ignored in the total | life: 1 assertion |
| R3 | `random_life.lua`: `and can_play(life) ⏎` → `⏎` — can_play ignored when picking | life: 5 assertion |
| R4 | `director.lua`: `(performer.state_changed and performer.playing ~= WANTED)` → `(false and performer.playing ~= WANTED)` — state change does not drop a random pick | life: 1 assertion |
| R5 | `director.lua`: `performer.step_seconds = performer.party ⏎       and parties.seconds_of_step(performer.party, performer.step_index, draw) ⏎     or draw()` → `performer.step_seconds = draw()` — each player draws its own step time | life: 1 assertion |
| R6 | `next_activity.lua`: `and vim.list_contains(activity.during, other.state) ⏎` → `⏎` — partners of any state | life: 1 assertion |
| R7 | `next_activity.lua`: `and other.column ~= nil ⏎` → `⏎` — partners not placed | life: 2 assertion |
| R8 | `director.lua`: `performer.looks_for_life_at = time + SECONDS_BETWEEN_LOOKS ⏎     return false` → `performer.looks_for_life_at = math.huge ⏎     return false` — never looks for an activity again | life: 1 assertion |
| R10 | `random_life.lua`: `and vim.list_contains(life.activity.during, state) ⏎` → `⏎` — a pick in a state the activity does not name | life: 2 assertion |
| R9 | `next_activity.lua`: `if choice.free < needed or not choice.any then` → `if not choice.any then` — spots for the first step not counted per player | life: 1 assertion |
| N1 | `named_spots.lua`: `keys[math.floor(world.random() * #keys) + 1]` → `keys[1]` — anywhere always the first cell | named_spots: 1 assertion |
| N2 | `named_spots.lua`: `return not world.places_taken[desk.number]` → `return true` — an_empty_desk: every desk | named_spots: 1 assertion |
| N3 | `named_spots.lua`: `if agent.id ~= character.id and roles.is_idle(agent) and desks[agent.place] then` → `if roles.is_idle(agent) and desks[agent.place] then` — an_idle_agents_desk: including its own | named_spots: 2 assertion |
| N4 | `named_spots.lua`: `if agent.id ~= character.id and roles.is_idle(agent) and desks[agent.place] then` → `if agent.id ~= character.id and desks[agent.place] then` — an_idle_agents_desk: agents not idle | named_spots: 1 assertion |
| N5 | `named_spots.lua`: `ipairs({ -1, 1 })` → `ipairs({ 1 })` — next_to_an_agent: only the right side | named_spots: 1 assertion |
| N6 | `named_spots.lua`: `agent.column and #agent.path == 0 then` → `agent.column then` — next_to_an_agent: agents on the move too | named_spots: 1 assertion |
| N7 | `named_spots.lua`: `spot.facing = across < 0 and 'right' or 'left'` → `spot.facing = 'right'` — next_to_an_agent: always facing right | named_spots: 1 assertion |
| N8 | `named_spots.lua`: `if layout.is_walkable(column + across, row) then` → `if true then` — next_to_an_agent: cells off the plan | named_spots: 1 assertion |
| N9 | `named_spots.lua`: `if agent.id ~= character.id and agent.column` → `if agent.column` — next_to_an_agent: the agent itself | named_spots: 4 assertion |
| T1 | `reactions.lua`: `agent ~= leaver ⏎       and agent.column` → `agent.column` — the one who left a mess is upset by it | things: 9 assertion/crash |
| T2 | `reactions.lua`: `and agent.playing ~= INTERLUDE ⏎       and is_within` → `and is_within` — an agent in an interlude is upset again | things: 1 assertion |
| T3 | `reactions.lua`: `down * down <= cells * cells` → `down * down < cells * cells` — upset only strictly within the distance | things: 1 assertion |
| T4 | `reactions.lua`: `if agent ~= busy and agent.column` → `if agent.column` — the agent in the middle of its update is sent | things: 1 assertion |
| T5 | `reactions.lua`: `return thing.cleaner ~= nil and thing.cleaner.cleaning == thing` → `return false` — a second cleaner is sent | things: 1 assertion |
| T6 | `director.lua`: `performer.party = party ⏎   performer.cleaning = nil ⏎` → `performer.party = party ⏎` — a cleaner whose state changes keeps the claim | things: 1 assertion |
| T7 | `director.lua`: `context.things.keep_on(new_layout.is_walkable) ⏎` → `(removed)` — things kept on cells a new plan cannot walk on | things: 1 assertion |
| T8 | `director.lua`: `context.things.remove_at(step.remove, column, row) ⏎` → `(removed)` — remove does nothing | things: 6 assertion; cat: 1 assertion |
| T9 | `director.lua`: `local thing = context.things.leave(step.leave, column, row)` → `local thing = nil` — leave does nothing | things: 9 assertion; cat: 1 assertion |
| T10 | `lying_pieces.lua`: `depth = ON_THE_FLOOR,` → `depth = 1000,` — a thing painted over what stands on it | things: 3 assertion; cat: 1 assertion |
| T10r | `lying_pieces.lua`: `rank = items.RANK.on_the_floor,` → `rank = items.RANK.standing,` — a thing ranked as what stands (same depth only) | **equivalent**: the thing is at depth −1, below every cell; rank only orders items at one depth, and a rug at that depth is made before the thing, which comes later in the order whatever the rank |
| T11 | `director.lua`: `elseif why == spots.TAKEN then ⏎     wait_for_a_spot(performer, now) ⏎     return ⏎   end` → `else ⏎     wait_for_a_spot(performer, now) ⏎     return ⏎   end` — an agent waits for a spot that is gone | things: 1 assertion |
| T12 | `director.lua`: `and performer.looks_again_at == nil ⏎   if lost_its_way then` → `and false ⏎   if lost_its_way then` — a performer that lost its way is not resumed | things: 1 assertion |
| T13 | `things.lua`: `local MOST_LYING = 64` → `local MOST_LYING = math.huge` — no limit of 64 things | things: 1 assertion |
| C1 | `director.lua`: `else ⏎     begin_step(context, occupant, occupant.step_index, math.max(time, occupant.clock)) ⏎   end` → `end` — a displaced agent is not moved when the step says nothing | cat: 1 assertion |
| C2 | `director.lua`: `if activity_name and context.pack.activities[activity_name] then` → `if false then` — the_one_moved_plays ignored | cat: 1 assertion |
| C3 | `performers.lua`: `math.min(looks.how_many, MOST_CATS)` → `looks.how_many` — more than four cats | cat: 1 assertion |
| C10 | `performers.lua`: `colour_index = number,` → `colour_index = number, ⏎       place = number,` — the cat takes a place among the agents | cat: 1 assertion |
| C4 | `performers.lua`: `colour_index = number,` → `colour_index = 1,` — every cat in the first colour | cat: 1 assertion |
| C5 | `following.lua`: `if context.by_id[target.id] ~= target or #target.path == 0 then` → `if context.by_id[target.id] ~= target then` — a cat goes on after the one it follows stops | cat: 1 assertion |
| C6 | `following.lua`: `if context.by_id[target.id] ~= target or #target.path == 0 then` → `if #target.path == 0 then` — a cat goes on after the one it follows has left | cat: 1 assertion |
| C7 | `random_life.lua`: `local who = activity.who == 'cat' and lives.cat or lives.agents` → `local who = lives.agents` — cat activities picked by agents | cat: 10 assertion |
| C8 | `following.lua`: `return step.follow == M.SOMEONE_WALKING` → `return step.follow ~= nil` — any name follows | cat: 1 assertion |
| C9 | `following.lua`: `if other ~= performer and other.column and #other.path > 0 then` → `if other ~= performer and other.column then` — follows someone standing | cat: 2 assertion/crash |
| G1 | `director.lua`: `if context.moved_in_a_row >= MOST_MOVED_IN_A_ROW then` → `if false then` — no limit to characters moving one another | cat: 1 assertion |
| S1 | `status_list.lua`: `local activity = drawing.activities_played[agent.id] or asked_for` → `local activity = asked_for` — the status list says what the state asks for | life: 1 assertion; status_list: 0 - |

## Open threads

- `director.lua` is 553 lines, the largest file of the home; the performing of steps (`begin_step`, `start_step`, `settle_at_spot`, `play`) is one cycle that cannot be split without a module requiring itself back.
- The default pack's activities (`during`, `players`, the cat, the table-tennis table) are T133's; no pack in the repository exercises the random life yet beyond the tests' own.
- `follow`'s one value and `who`/`during` combinations are not checked by `:Aineo office check`.

## Commits

*Recorded after the merge.*
