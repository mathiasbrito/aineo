# 2026-10-25 — T149 office leaving and minors

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t149-office-leaving-and-minors` (from `dev` at 4474c671) · **Pull request:** into `dev` (number recorded after the merge)

T149 (D121, the user's of 2026-10-25: "go ahead with T49 and the minors, merge them in one PR"): the main agent leaves when its session ends (a), the `for_seconds` message (b), a stricter `:Aineo office check` (c), two agents never halting on one cell (d), a quiet subagent walking back in at its call (e), and two notes' commit hashes (f). A regular packet (D26).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — §2 (state 24, the switch), §6 row T149
- [[Sessions/2026-10-24 — T146 T147 office desk and old agents]] — the open threads (d) and (e) come from
- [[Sessions/2026-10-25 — T136 office authors guide]] — findings F1, F2 and A622's finding 5
- `doc/aineo.txt` — *aineo-office*, *aineo-office-states* (states 1 and 24), *aineo-office-steps*, *aineo-office-triggers*, *aineo-office-cat*, *aineo-office-check*, *aineo-office-session*, *aineo-office-hooks*

## What was done, and why

- **(a) The main agent leaves.** The tracker had known `session_ended` since T127; nothing sent it. The office home gets `session_ended()` (the main agent leaves, and leaves again after the replay each time the office follows that session again, so it is never seen back at work in a session that is over) and `session_started()` (after an end only, a running office's main agent walks in; told while the session runs, nothing). A switch to another session after an end (`session_changed()`) walks the new main agent in; a switch with no end before it stays as it was (a continuation, a newly named transcript). `:Aineo office reset` forgets the end. The Claude home gets `on_session_ended(id, reason)`: every `SessionEnd` hook of the start's token, unless a `SessionStart` of the same session whose hook ran after it was told already (an in-session `/resume` of the session, in whatever order the deliverers arrive), and the start's own process ending by itself (not stopped by the home's stop, as a replaced start is). The composition root tells the tab's office the end and the start of the session the tab shows (`panes_session()` or its own): `on_session_ended`; the panes leaving a session the tab claimed for its own (`set_panes_session()` while `holds_other_claim()`: `:Aineo claim` with no word, an attach that ended, a claim moved by a switch of the claimed session); `on_transcript` (each `SessionStart` hook) and the first readiness of each start as starts.
- **(b)** The `for_seconds` message now says "a number above 0, or two numbers from 0, the shortest first"; `{0, 0}` is pinned as accepted.
- **(c)** `when = {}` is told "needs at least one field" (a `fields` option of the schema, `at_least_one_field`); `follow` is `schema.choice({ 'someone_walking' })`. The help's "not checked" sentences now say the check tells them.
- **(d)** An agent that must wait for a taken spot first looks at its cell: when another character stands still on it or is on its way to it, it walks, standing, to the nearest floor cell that is no spot's and that no other character holds (`named_spots.choose_cell_out_of_the_way()`, `director.step_out_of_the_way()`), and waits there, looking again each second as before. One that only walks over its cell does not move it, and an agent waiting on its own spot keeps it.
- **(e)** A subagent that walks out quiet keeps, in its rest, its open calls and its call count; walking in again it gets them back, so the call's result ends the call and the subagent thinks at that call's spot (T146's after-call rule); a new call started instead is the one shown, its order counted on.
- **(f)** *T48 Resume elsewhere* already held its seven hashes; each was checked against PR #189's commits by subject and found on `dev`, and the note says so. *Wave 12 retrospective* lacked its own pass's hash: PR #204, `knowledge/w12-landed`, merged by rebase as `87e7bf5d`, matched by subject.

## Decisions

- **The main agent's leaving stays until a start** (the tracker's existing rule, pinned by T127's test: listed, `leaving`, for good). It is re-applied after each replay rather than kept in the transcript, which has no end line.
- **A start counts only after an end.** `session_started()` is told by two sources for one start (the hook and readiness); gating it on an end keeps a running session's agents from being forgotten.
- **A `/resume` switch now walks the main agent in**: its `SessionEnd` ends the session, its `SessionStart` of another id switches. `test_entry_office_life`'s switch case waits through the 4-second arrival (`SWITCH_PATIENCE_MS`) for that reason.
- **Spot cells are never stepped out to** (d): an owner or a user of that spot would stop there next. Rejected: letting a halted walker give up the spot it was heading to (it holds it while it waits, as on `dev`); that changes who holds what, beyond D121 (d).
- **`tell_exit()` has no "still the home's session" guard**: the home's stop marks a replaced start `stopped`, and the composition root keeps only ends of the session the tab shows.

## Unit list (as sliced)

1. (b) the `for_seconds` message; `{0, 0}` accepted.
2. (c) `follow` other than `someone_walking` told; `when` with no field told.
3. (e) a quiet subagent walks back in on its call's result at that call; with a new call, at the new call.
4. (d) two agents halted on one corridor cell end on two cells; one that only walks over a cell does not move the agent waiting there; the freed spot is taken in its pose; a new step begun while stepping out takes its pose; a spot freed while the agent still walks out of the way.
5. (a, office) `session_ended()` while shown; while hidden, then shown; `session_started()` after an end; a switch after an end; reset after an end; a start after an end not left again on reload; a switch while hidden after an end; a start while running; a switch with no end.
6. (a, Claude home) `on_session_ended` from a `SessionEnd` hook; an overtaken end not told (starts in any order); the process exiting; a replaced start not told.
7. (a, composition root) a `SessionEnd` hook of the shown session told, of another not; the Claude Code exiting told; the panes leaving a claim told, a claim made not; a `SessionStart` hook of the shown session told as a start, of another not; readiness told as a start.

## Tests and evidence

- **Whole suite**, Neovim 0.12.5 on the host, on the code pushed (`d6a9ea15`): two runs, 8202 cases in 248 groups each. Run 1: `Fails (1)` — `test_health` *leaves the editor free to wait when Ctrl-C ends a check …* (`vim.wait(100)` measured over 1000 ms under the run's load); run 2: `Fails (1)` — `test_entry_tab_reopen` *the first open … starts every tab's Claude Code at once* (a JSON record read at character 4099, mid-write). Each file passed alone afterwards (`test_health` twice, `test_entry_tab_reopen` once), and neither failed in the other run; neither touches what this packet changed but `tab.lua`'s office calls, which read no file.
- **Touched files**, each green alone on the final code: the pack files (`test_office_pack_fields`, `_checks`, `_based_on`, `test_office_pack`, `test_entry_office_check`, the two packs' tests, `test_office_scene_cat`), the tracker files (`test_office_states_quiet`, `_agents`, `test_office_states`, `_after_call`), all 37 scene, default-pack and space_station files, the office files (`test_office_session_end`, `test_office_session_switch`, `test_office`, `test_office_waits`, `test_office_cards`, `test_office_preview`, `test_entry_office`, `test_entry_office_reset`), the Claude and entry files (`test_claude_session_end`, `test_entry_office_hooks`, `test_entry_office_life`, `test_claude_switch`, `_transcript_path`, `_ready`, `_attach`, `_copies`, `_resume`, `test_entry_claim_input`, `_claim_attach`, `test_entry_tab_reopen`, `test_entry_session_handover`) and `test_doc`.
- `make lint`: clean (StyLua, selene 0 errors, 0 warnings). No `require` added reaches past a home's entry point.
- The office message *could not take in a 'prompt' signal* in the whole run's output comes from `test_transcript_subagents`, a case of which makes the consumer raise on purpose (the file run alone prints it too); the transcript home is not changed here.

### Seen red

- `test_office_pack_fields`: the two `for_seconds` cases (old message); `follow` and empty `when` (nothing told), each made green in turn.
- `test_office_states_quiet`: *walks in on its result at that call* — `standing` with no `after_call`.
- `test_office_scene_places`: *never wait for it on one cell* — the first agent `nowhere`, drawn under the second.
- `test_office_session_end`: five by a missing `session_ended`/`session_started`, then, function by function, *next leave* and *followed by another … walk in* (`idle`, not `arriving`) and *reset … walk in and stay* (never `standing`).
- `test_claude_session_end`: the hook end and the exit (nothing told), then the overtaken end (told).
- `test_entry_office_hooks`: the hook end, the exit, the claim left, the start hook and readiness (nothing told). The hook end's first red came from a helper that passed `...` mid-list (the token fell out); after fixing the helper it passed with the wiring, and mutant Mn1 (the wiring removed) fails it.

### Arrived green, with the mutant that kills each (all run, all killed by an assertion)

- *accepts … both 0* — Mb1 (`value[1] >= 0` → `> 0`).
- *walks in with a new call at the new call* — Me3 (call count not restored).
- *wait where they halt while another only walks over their cell* — Md2 (holders by position, not destination).
- *go to it once it is let go …*, *take the pose of a step they begin while stepping out*, *… while they step out of the way* — Md5/Md7/Md6.
- office: *told to start has nothing walk in* — Ma3; *followed in place of another has nothing walk in* — Ma5; *starts again … not left again* — Ma7; *followed by another while hidden* — Ma8.
- Claude home: *replaced start* — Mc5; *in any order* — Mc3.
- entry: the two "not told" cases and *a claim made* — Mn2, Mn4.

### Mutants

Each run alone, from a pristine copy put back after the run, against the test file named (the composition root's against `.tests/t149-hooks-end.lua`, `test_entry_office_hooks.lua` narrowed to its two new groups). Every one killed, by an assertion (`Failed expectation` in its log).

| ID | Literal edit | Killed by |
|---|---|---|
| Mb1 | `schema.lua`: `and value[1] >= 0` → `and value[1] > 0` | *accepts … both 0* |
| Me1 | `tracker.lua`: `walked_in.open_calls = rest.open_calls or {}` → `= {}` | *walks in on its result at that call* |
| Me2 | `tracker.lua`: `open_calls = record.open_calls,` → `open_calls = nil,` | same |
| Me3 | `tracker.lua`: `walked_in.started_calls = rest.started_calls or 0` → `= 0` | *walks in with a new call at the new call* |
| Md1 | `director.lua`: the `step_out_of_the_way(context, performer, time)` line removed | *never wait for it on one cell* |
| Md2 | `named_spots.lua`: `local last = other.path[#other.path]` → `local last = nil` | *never wait …*, *wait where they halt …* (3 cases) |
| Md3 | `named_spots.lua`: `if not held[key] and not spots[key] then` → `if not held[key] then` | *never wait …* (`2,0`, a shelf) |
| Md4 | `named_spots.lua`: the own-cell check → `if false then` | *keeps the spot it stands on*, *stays seated …* (3 cases) |
| Md5 | `director.lua`: `if #performer.path == 0 and performer.steps_out_of_the_way then` → `if false then` | *never wait …* (the agent in the board's pose) |
| Md6 | `director.lua`: `performer.steps_out_of_the_way = nil` in `look_again()` removed | *… while they step out of the way, in the spot's pose* |
| Md7 | `director.lua`: `performer.steps_out_of_the_way = nil` in `begin_step()` removed | *take the pose of a step they begin while stepping out* |
| Ma1 | `office/init.lua`: `session_ended()` no longer tells a running tracker | *has the main agent of the office that shows leave* |
| Ma2 | `leave_if_over()`: `if session_is_over then` → `if false then` | *… that shows next leave* |
| Ma3 | `session_started()`: the `if not session_is_over then return end` guard removed | *told to start has nothing walk in* |
| Ma4 | `session_changed()`: `arrives_next = was_over` → `= false` | *followed by another has the new main agent walk in* |
| Ma5 | `session_changed()`: `arrives_next = was_over` → `= true` | *followed in place of another has nothing walk in* |
| Ma6 | `follow_transcript()`: `if from_now then session_is_over = false end` removed | *reset … walk in and stay* |
| Ma7 | `session_started()`: `session_is_over = false` removed | *starts again … not left again* |
| Ma8 | `session_changed()`: `session_is_over = false` removed | *followed by another while the office is hidden* |
| Mc1 | `claude/init.lua`: `tell_session_ended(home.session, told)` removed | *told the end its SessionEnd hook tells* |
| Mc2 | `if told.event == 'SessionEnd' and not (latest_start and ran_before(told, latest_start)) then` → `if told.event == 'SessionEnd' then` | *not told an end … in any order* |
| Mc3 | `if not latest_start or ran_before(latest_start, told) then` → `if true then` | same |
| Mc4 | `tell_exit(ended)` removed | *told the end of its Claude Code … when the process exits* |
| Mc5 | `if vim.v.exiting == vim.NIL and not ended.stopped then` → `if vim.v.exiting == vim.NIL then` | *not told the exit of a Claude Code another start took the place of* |
| Mn1 | `tab.lua`: `offices.session_ended(tab, session_id)` in `on_session_ended` → `local _ = session_id` | the hook end, the exit (2 cases) |
| Mn2 | `entry/office.lua`: `is_shown_by` → `return session_id ~= nil` | the two "of a session the tab does not show" cases |
| Mn3 | `tab.lua`: `offices.session_ended(tab, panes_session)` → `local _ = panes_session` | *as the panes leave a session the tab claimed* |
| Mn4 | `tab.lua`: `if changed and panes_session and holds_other_claim() then` → `if changed and panes_session then` | *not told … as the panes claim another session* |
| Mn5 | `tab.lua`: `offices.session_started(tab, session_id)` in `on_transcript` → `local _ = session_id` | *its SessionStart hook … is told* |
| Mn6 | `tab.lua`: `offices.session_started(tab, id)` in `follow_confirmed_start()` → `local _ = id` | *as the tab's Claude Code is first ready* |

### (d) frames with two agents still on one cell

The reviewer's harness (`review363-harness.lua`, copied to `.tests/`), its 9- and 16-agent story, before (the call to `step_out_of_the_way()` removed) and after: default 100×40 0 → 0, 120×50 3 → 0, 157×78 302 → 0; space_station 100×40 0 → 0, 157×78 638 → 0. Its realistic-turn and background-subagent stories: 0 at every size it runs.

## Open threads

- A halted walker still holds the spot it was heading to while it waits elsewhere (as on `dev`); D121 (d) did not ask to change it.
- `test_office_scene_cat`'s *follows no one by a name other than someone_walking* now passes because the check refuses that activity before the scene sees it.
- The entry's attach-ended path is covered through the same `set_panes_session()` rule as the claim let go; no entry test drives a real attach's end.
- `test_entry_run_follow`'s *follows the output of a shell added below, by \\X* failed once in the fix round's whole run and once alone (then 4 of 4 green): a timing case outside this packet.

## Fix round (review370, ruling A624)

Each item red first, except where a pin is named with the mutant that kills it.

1. **aineo's own stop is never a session end.** `tell_session_ended()` now leaves out a `SessionEnd` of a start its home's stop stopped, as `tell_exit()` does: the Ctrl-C of the stop has Claude Code run that hook, and its deliverer can reach the editor while the stop still waits. Red: *is not told an end of the Claude Code its home stops, by its SessionEnd hook or its exit* (the reviewer's probe-stop, `{ { <id>, "prompt_input_exit" } }`). The `is_shown_by()` filter is pinned by *of the tab's own Claude Code is not told to the office while the tab claims another* (kills Mx3).
2. **Moving an attached claim tells the office the end.** `set_panes_session()` treats the panes leaving a session as an end when the tab claims it and it is not the tab's own session (`claimed_by_id == panes_session and panes_session ~= own_session_id()`, the reviewer's measured fix); `holds_other_claim()` was false while attached. Red: *the office is told the end of an attached claim the tab moves to another session it attaches to / to a session it cannot attach to* (`ended = 0`). *is told to the office once as the tab's own session switches to another* pins the claim condition (Mf4: 2 ends).
3. **The quit check of `tell_exit()`** is pinned by *is not told an end of the Claude Code that quitting Neovim stops* (the reviewer's probe-quit; kills Mx1).
4. **A reset after the session ended** keeps the main agent gone (`leaving`) until a session starts; the case that pinned the opposite became *and is reset keeps the main agent gone* (red: `arriving`), and *and is reset, then starts again, has the main agent walk in* was added. The help's state 24, state 1 and `:Aineo office reset` say so; state 24 also says aineo's own stop is no end.
5. **The unknown-`follow` cat case** moved from `test_office_scene_cat` to the pack-field cases, asserting the check's report (*a cat's step that follows someone the office does not know*; killed by `follow = schema.name`). Mx4 stays equivalent through `load()`: no loaded step carries another name.
6. **The fake's record is never read half-written.** Fakes that start at once (the first open of three tabs) append to one record; the C library wrote each line 4096 bytes at a time, and another fake's line fell between, which the helper then failed to decode (`Expected comma or array end … at character 4099`). The fake now writes each line with one `write` to the file opened `O_APPEND` (`vim.uv.fs_write`). Red: `test_fake_claude_record` — twelve fakes appending 20 KB lines at once — failed 6 of 10 runs before (the same decode error) and 0 of 10 after. Running `test_entry_tab_reopen` several times side by side does not measure this: the copies share their fixtures' record files by name.

| ID | Literal edit | Result |
|---|---|---|
| Mx1 | `claude/init.lua`: `  if vim.v.exiting == vim.NIL and not ended.stopped then` → `  if not ended.stopped then` | killed by assertion: *… that quitting Neovim stops* (`{ "<id> nil" }`) |
| Mx3 | `entry/office.lua`: `  return session_id == (tab.panes_session() or tab.session_id())` → `  return session_id == tab.panes_session() or session_id == tab.session_id()` | killed by assertion: *… while the tab claims another* (1 end) |
| Mx4 | `following.lua`: `  return step.follow == M.SOMEONE_WALKING` → `  return step.follow ~= nil` | survives `test_office_scene_cat`; equivalent through `load()`, which refuses any other name (pinned at the check instead) |
| Mf1 | `claude/init.lua`: the `and not running.stopped` line removed | killed by assertion: *… its home stops …* |
| Mf2 | `pack_format.lua`: `  follow = schema.choice(FOLLOWED),` → `  follow = schema.name,` | killed by assertion: both `follow` field cases |
| Mf3 | `tab.lua`: `      and panes_session ~= own_session_id()` → `      and holds_other_claim()` | killed by assertion: both attached-move cases |
| Mf4 | `tab.lua`: the `      and claimed_by_id == panes_session` line removed | killed by assertion: *once as the tab's own session switches* (2) |
| Mf5 | `office/init.lua`: `    if (from_now and not session_is_over) or arrives then` → `    if from_now or arrives then` | killed by assertion: *and is reset keeps the main agent gone* |

Ma6 of the first round named code this round removed (a reset no longer forgets the end); Mf5 takes its place.

Runs of the fix round, Neovim 0.12.5, host: every file the round touches green alone (`test_claude_session_end`, `test_entry_office_hooks`, `test_entry_claim_attach`, `test_office_session_end`, `test_office_pack_fields`, `test_office_scene_cat`, `test_fake_claude_record`, `test_doc`, `test_entry_office_life`, `test_claude_attach`, `test_entry_session_switch`, `test_entry_office_reset`, `test_office_session_switch`); `make lint` clean. Whole suite on `258183b6`: 8210 cases, 249 groups, `Fails (1)` — `test_entry_run_follow` *follows the output of a shell added below, by \X* (`follows = false`). That file is not touched by the packet; run alone it failed once and then passed 4 of 4, so it is a timing case of the run pane's shell, left as an open thread. `test_entry_tab_reopen` and `test_health` passed.

## Commits

*Recorded after the merge.*
