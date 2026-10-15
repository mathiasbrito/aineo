# 2026-10-14 — T62 Report and draft copies

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t62-report-draft-copies` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C6, C11, C14, D39, D40, D42, D45, D63, T62
- [[Implementation/Waves/00015-tabs/plan]] › *The model*, O4, O6, *Verification mutants* › T62
- [[Implementation/Waves/00015-tabs/brief-t62-report-draft-copies]]
- `Implementation/Waves/00015-tabs/evidence/w15-probes.txt` › P1, P2, P4, P5
- The head of `dev` this branch starts from: `5942eba`

Stage 1 of wave 15 changes nothing the user sees: with one tab aineo acts as before. O4 and O6 (A234–A255) are the orchestrator's assumptions under the user's instruction of 2026-10-06, not the user's decisions; the user decided the per-tab Report and Input (D63).

## What was done

`aineo.report` and `aineo.draft` each gained `new()`. The body of each home's state became a factory, in a file of the home: `lua/aineo/report/home.lua` (`new(identity)`) and `lua/aineo/draft/home.lua` (`new(group_name)`). The module's `init.lua` of each makes its own copy at load, `home.new(...)` with today's names, and its per-view functions are that copy's fields, so every caller and suite of today stands. The form is O4 (a)'s cheapest, the module body wrapped in a function, which is why `git diff -w` is the readable diff. The functions that keep no state stay on the module (`validate_report`, `report_schema`, `report_instructions`, `keep_session_report`); `keep_session_report` is defined in `report/home.lua` beside the `keep_unshown` it shares with the copy.

Per-editor resources, each made unique per copy; the module's copy keeps today's names:

| Resource | The module's copy | A copy `new()` makes |
|---|---|---|
| Report buffer's name (P1: a second buffer cannot take a name, E95; `free_report_buffer_name()` wiped the holder) | `aineo://report` | `aineo://report-<n>` |
| Group of the Report buffer's handlers (`BufReadCmd`, `BufWinEnter`; P4: `nvim_create_augroup(…, {})` clears a group made again) | `aineo_report` | `aineo_report_<n>` |
| Group of the Report's `SafeState` retries (`clear = false`) | `aineo.report` | `aineo.report.<n>` |
| Group of the draft's handlers and `SafeState` retries (`BufUnload`, `BufWinEnter`, `QuitPre`; `QuitPre` was made once per group) | `aineo.draft` | `aineo.draft.<n>` |
| Environment, followed session, claim, directory move, hand-overs waiting, Report view, retries waiting; the draft's kept buffers, `warned` kinds, replacements waiting | file-level locals | locals of the factory, one set per copy |

`<n>` is the next number after those the copies made since the module loaded took, and one whose group exists, as `aineo.layout.new()` does (T60). `aineo.report.buffer.create_report_buffer()` takes the identity (`name`, `group`) as a third argument in place of the two constants it held.

The router: `aineo.report.set_report_router(router)` (nil takes it away). `receive_session_report(arguments, session_id, options)` with no router is the module's copy's, as today. With one it calls `router(session_id, options)` (`options` the table given, `{}` when none, `start_token` unchanged), and hands the report to the copy returned: that copy's `receive_session_report`, whose rules (`at_start`, `keep_with_directory`) decide, its answer and its errors the module's. A router returning nothing makes the answer `false` with no warning; one that raises, or returns what is no home, makes it `false` and warns once (`warn_later()`), as a failing receive warns today.

Decisions made inside the packet, none of them spec:

1. A copy has a sixth field, `receive_session_report`, beside the brief's five: the router's copy must be handed the report, and "the copy's rules of today decide" needs that function on the copy.
2. A router may return `require('aineo.report')` for the first tab's copy. The module's copy is not reachable otherwise, and handing the report to the module would call the router again, in a tail-call loop without end (mutant m6). The module stands for its copy. A registry of the copies `new()` made (A275, fix round) decides what else a router may return: nothing but a copy or the module.
3. `warned` (the draft's once-per-kind warnings) is per copy: its docstrings said "once per editor" and now say "once per home". The brief did not name it.
4. No teardown: the groups and the Report of a copy whose tab closed stay. T66 and T67 decide when a copy goes, and may add a `let_go()` as the layout's.

The brief's facts were checked against `dev` `5942eba` and had not moved (the report home's state at lines 21–40, 113, 375, the draft home's at 64–281, 638, 718; `lua/aineo/report`, `lua/aineo/draft` and `lua/aineo/mcp/delivery.lua` have no commit between `1354cad` and `dev`): no amendment (A256).

## Unit list

1. `new()` of each home gives the module's per-view functions as fields, a different copy each call.
2. A copy's Report has a name no other buffer holds; making it leaves the module's Report alone.
3. Two copies following two sessions show only their own session's records and keep their reports there.
4. The handlers of a copy leave the module's alone (the Report's `:edit`, the draft's `BufUnload`, `QuitPre`, `SafeState` retries).
5. The router: the chosen copy takes the report and shows it; none chosen answers `false`; none given leaves the module; a cleared router leaves the module; `start_token` and the options reach the router; the module may be chosen; a raising or non-copy router answers `false` and warns once; a non-function is refused.
6. The draft copies: own session files, own swaps, a pending change saved at the wipe and at `QuitPre`.
7. State apart: the claim, the directory move, the hand-overs told before the environment, the environment itself, the warnings, an Input shown again.

## Red and green

The first runs of two cases were red for a fault in the test and not for the missing behaviour, and were corrected before the factory or the names: the five rows of unit 1 (a `local` inside `lua_get`) and the Report-name case (the second home had no environment, so it raised at its own `report_buffer()`). Their reds below are from the corrected cases. The factory was first written with every copy under today's names, so the name and group cases were red against that.

`tests/test_report_copies.lua`, 23 cases (rows counted):

| Case | At its first run | Killed, after, by |
|---|---|---|
| `offers the per-view functions as fields` (5 rows) | red, `attempt to call field 'new' (a nil value)` | m22, assertion: 5 of 5 rows |
| `has a Report under a name no other buffer holds…` | red, assertion: the module's Report was wiped (`first_valid = false`) against copies sharing `aineo://report` | m2, assertion |
| `makes the handlers of its Report apart…` (`:edit` refills) | arrived green: written after the unique group existed | m3, assertion |
| `each show the records of the session they follow…` | arrived green: the closure makes the state one per copy | m5, m13, m17 |
| `keep the retries of their swaps apart…` | arrived green: written after the retry group was a parameter | m4, m5, m17, m18 |
| `hold a claim apart…` | arrived green by the closure | m14 |
| `each move the directory's records…` | arrived green by the closure | m15 |
| `hold the hand-overs told before their environment apart` | arrived green by the closure | m16 |
| router: `hands the report to the home it chooses…` | red, `attempt to call field 'set_report_router' (a nil value)` | m1, m5, m11 |
| router: `leaves the rules of the home it chooses to decide…` | red, same | m20 |
| router: `answers false, taking nothing, when it chooses no home` (and no warning) | red, same | m8, m11 |
| router: `leaves the module taking the report when no router is given` | arrived green: today's behaviour | m19 |
| router: `goes back to the module… when it is cleared` | red, same | m19, m21 |
| router: `is asked the report's session and the offer's options, the start token unchanged` | red, same | m11 |
| router: `is asked with an empty table when the offer gave no options` | arrived green: pins `options or {}`, written ahead of the case | m10 |
| router: `gives a home taking the module` | red, same | m6 (a hang, see below) |
| router: `that raises takes nothing, answers false and warns the user once` | red, same | m7, assertion |
| router: `that chooses what is no home…` | red, same | m9 |
| router: `is refused when it is not a function` | red (failed; message not read) | m12 |

`tests/test_draft_copies.lua`, 15 cases:

| Case | At its first run | Killed, after, by |
|---|---|---|
| `offers the per-view functions as fields` (4 rows) | red, `attempt to call field 'new' (a nil value)` | d13, assertion: 4 of 4 rows |
| `each restore from and save to the draft file of the session they follow` | arrived green by the closure | d2 |
| `swap only the Input of the home that follows another session` | arrived green by the closure | d2, d3 |
| `save a change pending in one Input when it is wiped…` | arrived green by the closure | d2, d3, d11 |
| `save the change pending in each Input as Neovim starts to quit` | red, assertion: the second Input's file was missing (the shared group made `QuitPre` once) | d1, d11 |
| `keep the retries of their swaps apart…` | arrived green: written after the group was a parameter | d1, d2, d3 |
| `keep the draft under the state directory each was given` | arrived green by the closure | d4 |
| `hold a claim apart…` | arrived green by the closure | d5 |
| `each move the directory's draft…` | arrived green by the closure | d6 |
| `hold the hand-overs told before their environment apart` | arrived green by the closure | d7 |
| `keep again, each in its own home, an Input shown again after it was dropped` | arrived green by the closure | d12 |
| `each tell the user once of a draft they cannot read` | arrived green by the closure; first measured as a survivor of d9 | d9 |

## Mutants

Each mutant is its literal edit, applied to a copy and restored, run on the one new test file of its home (`tests/test_report_copies.lua` for `m`, `tests/test_draft_copies.lua` for `d`). "Hoisted" is: the line `  local <name>` inside `new()` deleted and the same `local <name>` put on the line before `function M.new(`. m1, m2 and d2 are the plan's three mutants of T62. Each ran alone, one after another, from the tree as it is pushed; one pair run side by side by mistake was discarded, the file restored by hand from the diff and re-run.

| Mutant (the literal edit) | Result |
|---|---|
| m1. `report/init.lua`: `if not router then` → `if true then` | killed by assertion: 6 |
| m2. `report/init.lua`: `buffer_name = ('aineo://report-%d'):format(copies_made)` → `buffer_name = 'aineo://report'` | killed: 3, 1 by assertion (the name case), 2 by crash (`E86`, `E216`) |
| m3. `buffer_group = ('aineo_report_%d'):format(copies_made)` → `buffer_group = 'aineo_report'` | killed by assertion: 1 |
| m4. `retry_group = ('aineo.report.%d'):format(copies_made)` → `retry_group = 'aineo.report'` | killed by assertion: 1 |
| m5. `report/home.lua`: `followed_session` hoisted | killed by assertion: 3 |
| m6. `report/init.lua`: `if chosen == M then chosen = module_copy end` deleted | killed by a hang in the first round (the router returning the module loops in tail calls; the run was bounded with `AINEO_TEST_RUN_LIMIT_MS=100000`); killed by assertion since the fix round (f5) |
| m7. `local asked, chosen = pcall(router, session_id, options)` → `local asked, chosen = true, router(session_id, options)` | killed by assertion: 1 (the first form of the case killed it by crash; the case now calls through `pcall`) |
| m8. the `if chosen == nil then return false end` guard deleted | killed by assertion: 1 |
| m9. `if not is_report_home(chosen) then` → `if false then` | killed by assertion: 1 |
| m10. `receive_through_router(arguments, session_id, options or {})` → `…, options)` | killed by assertion: 1 |
| m11. `router = chosen_router` → `router = nil` | killed by assertion: 6 |
| m12. `vim.validate('router', chosen_router, 'function', true)` deleted | killed by assertion: 1 (by crash in the first form of the case) |
| m13. `report/home.lua`: `environment` hoisted | killed by assertion: 1 |
| m14. `followed_as_claim` hoisted | killed by assertion: 1 |
| m15. `directory_records_moved` hoisted | killed by assertion: 1 |
| m16. `hand_overs_waiting` hoisted | killed by assertion: 1 |
| m17. `report_view` hoisted | killed by assertion: 4 |
| m18. `followed_records_waiting` hoisted | killed by assertion: 1 |
| m19. `if not router then` → `if false then` | killed by assertion: 2 |
| m20. `return chosen.receive_session_report(arguments, session_id, options)` → the call without `return`, then `return true` | killed by assertion: 1 |
| m21. `router = chosen_router` → `router = router or chosen_router` | killed by assertion: 1 |
| m22. `report/init.lua`, in `M.new()` after the `until` line: `if true then return module_copy end` (a copy that is the module's) | killed by assertion: 12 of 12 |
| d1. `draft/init.lua`: `return home.new(('aineo.draft.%d'):format(copies_made))` → `return home.new('aineo.draft')` | killed by assertion: 2 |
| d2. `draft/home.lua`: `followed_session` hoisted | killed by assertion: 5 |
| d3. `kept` hoisted | killed by assertion: 4 |
| d4. `environment` hoisted | killed by assertion: 1 |
| d5. `followed_as_claim` hoisted | killed by assertion: 1 |
| d6. `directory_draft_moved` hoisted | killed by assertion: 1 |
| d7. `hand_overs_waiting` hoisted | killed by assertion: 1 |
| d8. `replacements_waiting` hoisted | survived the first 15 cases, called equivalent on the state of two copies with a buffer each; the review built the input that separates it (one buffer kept by both copies, a swap held under textlock) and the fix round pins it: killed by assertion, see the fix round |
| d9. `warned` hoisted | survived the first 14 cases; killed by assertion: 1 once `each tell the user once of a draft they cannot read` existed |
| d11. `vim.api.nvim_clear_autocmds({ group = group, buffer = buffer })` → `vim.api.nvim_clear_autocmds({ group = 'aineo.draft' })` | killed by assertion: 2. A first form, `{ event = 'BufUnload' }`, changed nothing observable and was dropped: Neovim's clear with an event alone leaves buffer-local autocommands |
| d12. the `BufWinEnter` callback's `copy.keep_draft(buffer)` → `require('aineo.draft').keep_draft(buffer)` | killed by assertion: 1 |
| d13. `draft/init.lua`, in `M.new()` after the `until` line: `if true then return module_copy end` | killed by assertion: 14 of 14 |

## Suites

All on Neovim 0.12.5, on the host, from the tree pushed. The host's load average was 66 to 100 during the run, so the whole suite ran as `AINEO_TEST_JOBS=4 AINEO_TEST_RUN_LIMIT_MS=2700000 make test`.

- `make test`: 3279 cases in 90 files, `Fails (0) and Notes (0)`, make exit status 0.
- The branch was then rebased onto `dev` `3f18402` (T63's merge, which touches `lua/aineo/changes/` and its tests only); the two new test files, `tests/test_entry_session_handover.lua` and `make lint` were run again on the rebased tree, 0 fails and clean. The whole suite was not run again after the rebase.
- While working, each with 0 fails: `tests/test_report_copies.lua` (23 cases), `tests/test_draft_copies.lua` (15), and the files that exercise the code the change touches, none edited: `tests/test_report.lua`, `tests/test_report_buffer.lua`, `tests/test_report_sessions.lua`, `tests/test_draft.lua`, `tests/test_draft_sessions.lua`, `tests/test_mcp_delivery.lua`, `tests/test_entry_session_handover.lua`.
- `make lint`: StyLua check clean, selene 0 errors, 0 warnings, 0 parse errors.
- After the fix round, on the pushed tree, `AINEO_TEST_JOBS=4 AINEO_TEST_RUN_LIMIT_MS=2700000 make test` on Neovim 0.12.5: 3304 cases in 91 files, `Fails (0) and Notes (0)`, exit 0. A first run of that tree failed one case of `tests/test_health.lua` (the Ctrl-C of a check, timing on a host at a load average above 60); the file alone passed, and a second whole run passed. `tests/test_report_copies.lua` has 29 cases and `tests/test_draft_copies.lua` 17.
- The deep-`require` check prints no line outside a home; `aineo.report.init` requires `aineo.report.home`, `.warning`, `.format` and `.instructions`, and `aineo.draft.init` requires `aineo.draft.home`, inside their own homes.

## Open threads

- The cases are 46 after the fix round (23 + 15 before it), not the brief's twelve: the extra are pins of state kept apart (claim, directory move, hand-overs, environment, warnings, an Input shown again), each from a hoisting mutant that survived without it.
- `aineo.mcp.editor` still calls `require('aineo.report').receive_report(...)` for the path it names; it reaches the module's copy. Which copy it should reach is T64's and T66's.
- The names `new` of `aineo.report` and `aineo.draft` repeat the one of `aineo.layout` (the brief names it so).
- A copy's Report, groups and handlers stay when its tab closes (decision 4).

## Fix round (review of PR #209)

The orchestrator's rulings, assumptions under the user's instruction of 2026-10-06 and never the user's decisions: A274 (attack 1), A275 (attack 2), A276 (attack 3), A277 (attack 8, T64's, no change here). Each case below was run against the head the review read (`fef102f`) before the code that answers it was put back: the reds are from that run.

**Attack 1, A274.** Only the module's copy uses the editor's directory records file and directory draft file. `aineo.report.Identity` and `aineo.draft.Identity` gained `label` (nil for the module's copy; the copy's number for a `new()` copy). A copy with a label:

- keeps a report it takes before its first follow (`at_start`) in the records of the report's own session (`unfollowed_destination()`), which the offer names, and answers false to `keep_with_directory`;
- keeps a report received otherwise before its first follow in `<sha256(wd)>-<label>.jsonl`, and the text of its Input before its first follow in `<sha256(wd)>-<label>.txt` (`records.records_file()` and `draft_file()` take the label); its first non-claim follow moves that file into the followed session as the module's copy does with the directory's.

Two copies before their first follow never share a file. New or changed cases: report `hands an offer at the start to the home it chooses before it follows…` (red: the module's Report showed `B at start`), `leaves the working directory's records to the module…` (red: the report was kept in the directory's records), `each move what they kept before their first follow…` (replaces the directory-move case; red: the second copy took the directory's records); draft `keep the text typed before the first follow out of the module's draft…` (replaces the directory-move case; red: the module's Input showed `tab 2 notes`).

**Attack 2, A275.** `report/home.lua` keeps a weak-keyed registry of the copies `new()` made (`is_copy()`), and `receive_through_router()` checks it after mapping the module to its copy, so a proxy, an object that delegates to a copy or the module, or a shallow copy is refused with one warning and answers false. Cases: `that chooses what only looks like a home…` (3 rows: a proxy of the module, a delegating object, a shallow copy; red against `fef102f` by a hang, the run did not finish within its 150 s bound, as the review measured) and `gives a home taking the module, which is asked once` (the counting router of the tests review, arrived green; its mutant f5 is the case's kill).

**Attack 3, A276.** `new()` of each home creates its group itself (`nvim_create_augroup(…, { clear = false })`) after choosing the number, so a reloaded module skips a live copy's number whether or not its Report or Input exists. The two docstrings say "does not exist yet". Cases: report `keeps its names when the module is loaded again before its Report exists` (red: the new copy was `aineo://report-2` and wiped the old one's Report) and draft `keeps its group when the module is loaded again before it keeps an Input` (red: the newer copy's text was not saved at `QuitPre`).

**Tests 1.** The `at_start` offer through the router reaching a chosen copy that follows nothing is the A274 case above; it kills the mutant that drops `options` (f8) by assertion.

**Tests 2 / attack 4.** `leave a swap held under textlock to the home that asked for it, though one buffer is kept by both` pins d8 (two retries, the Input ends as `Delta`; arrived green on `fef102f`, killed d8 by assertion). d8 is no longer called equivalent: it is separated only by a buffer that two homes keep, which no composition does.

**Tests 4, 5, 6.** The mutant count is 34 for the first round (22 `m`, 12 `d`), 44 with this round's ten. The draft docstring of the `SafeState` retry names the copy's group (`identity.group_name`; `aineo.draft` for the module's). `that raises takes nothing…` offers twice and expects two warnings, one for each failing offer.

Fix-round mutants (literal edits, run on the home's copies file):

| Mutant | Result |
|---|---|
| f1. `report/home.lua`: `, identity.label)` → `)` (both calls of `records.records_file()`) | killed by assertion: 1 |
| f2. `report/home.lua`, `unfollowed_destination()`: `if not identity.label then` → `if true then` | killed by assertion: 1 (the first form of the case survived it, the label file carrying the report to the same place; the case now reads the session's records before the follow) |
| f3. `report/home.lua`: `if identity.label then return false end` deleted | killed by assertion: 1 |
| f4. `report/init.lua`: `if not home.is_copy(chosen) then` → `if false then` | killed by a hang (the three look-alike routers loop), run bounded |
| f5. `report/init.lua`: `if chosen == M then chosen = module_copy end` deleted (m6 again) | killed by assertion: 1 |
| f6. `report/home.lua`: `copies[copy] = true` deleted | killed by assertion: 3 |
| f7. `report/init.lua`: the `nvim_create_augroup(('aineo_report_%d'):format(copies_made), { clear = false })` line deleted | killed by assertion: 1 |
| f8. `report/init.lua`: `chosen.receive_session_report(arguments, session_id, options)` → `…(arguments, session_id)` | killed by assertion: 1 |
| f9. `draft/home.lua`: `, identity.label)` → `)` | killed by assertion: 1 |
| f10. `draft/init.lua`: the `nvim_create_augroup(group_name, { clear = false })` line deleted | killed by assertion: 1 |
| d8 again | killed by assertion: 1 |
| m1, m2, m15 (report), d2, d6 (draft) again on the changed code | killed by assertion: 12, 2 of 4 (the others by `E86`/`E216`), 1, 6, 1 |

## Task lines

- T62 `[X]` (`feature/t62-report-draft-copies`, into `dev`) — one Report and one Input draft per tab (C6, C11; D63): `aineo.report.new()` and `aineo.draft.new()` make a copy of the home of their own — the Report buffer (`aineo://report-<n>`), the followed session, the claim, the directory move, the hand-overs and the retries, and the draft's kept Inputs and handlers, each under a name of its own (groups `aineo_report_<n>`, `aineo.report.<n>`, `aineo.draft.<n>`) — the module serving as the first copy, so no caller and no suite moved; `aineo.report.set_report_router(router)` makes `receive_session_report()` ask the router for the copy that takes a report, the module's own when none is given (O4 and O6 are the orchestrator's assumptions). Kept apart in the copy beyond the brief's five functions: `receive_session_report` as a sixth field, and the module standing for its copy when a router returns it.

## Commits

- PR #209, `feature/t62-report-draft-copies`, head `1a1fb92` (3 commits), merged by rebase into `dev` as `a1b29fb` (the Report and Input's draft, one copy per tab), `c84c241` (the rebase onto `dev` and the runs after it, in this note), `e05a1e3` (the fix round: a copy's pre-follow files, router targets and names kept apart).
- Released in v0.2.34 (PR #214, `main` `8fe30d0`).
