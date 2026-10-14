# 2026-10-14 — T61 Claude copies

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`, on Sonnet)
**Branch:** `feature/t61-claude-copies` · **Pull request:** #207 into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C3, C4, D23, D25, D36–D38, D54, D61–D63, D10, D26, D29, T48, T61
- [[Implementation/Waves/00015-tabs/plan]] and its `brief-t61-claude-copies` (with the dated amendment at dispatch)
- [[Sessions/2026-10-14 — T48 Attach]] (the code this starts from: `dev` `9ca0abc`)

Wave 15, stage 1: the Claude session home and Send hold one copy per tab. Nothing the user sees changes. O4, O5 and O10 (A234–A255) are the orchestrator's assumptions, not the user's decisions. Everything was measured on Neovim 0.12.5 against the fake `claude`, on a host whose load average was 20 to 150 from other work.

## What was done

- `aineo.claude`: the file-level `session` becomes a *home* (`aineo.claude.Home`) that every internal function takes first. `new()` returns the per-session functions as fields over a home of its own (`aineo.claude.Session`); the module is one more copy, made at load, so every caller and suite stands. `stop_session()` and `start_token()` are new fields.
- Hooks: `receive_session_event()` stays on the module; `take_session_event()` finds, among the homes that have started (`started_homes`, which keeps a home for good), the one whose last start has the hook's token. The arrival counter stays per editor.
- Quit: one `VimLeavePre` handler, made once per module load, stops every started home's running Claude Code together.
- `aineo.claude.stop`: `stop_together(stops)` runs each stop's keys and waits side by side (a `way` of `keys` or `detach` per job); `stop_by_keys()` and `detach()` are its one-job cases, with the same keys and waits. One departure (A266): a stop of a Claude Code that has exited already presses no key; before, it pressed one. Callers guard with `is_process_alive()`, so nothing the user sees moves.
- `aineo.send`: `send(target)` and `send_selection(target)` take an optional `{ session, input }`.

The brief's facts moved (T48 part 2's A233 withdrew `self_attach.lua`); the dated amendment is its first commit (A256).

## Unit list

1. `new()` gives the per-session functions as fields; the stateless ones stay on the module; each call is a copy of its own.
2. Two copies each start a Claude Code of their own.
3. One copy's Claude Code exits; the other runs on; the first starts anew.
4. A hook reaches the copy whose start has its token, and no other.
5. The quit stops every copy by its keys, together (time of one stop); an attached copy gets Ctrl+Z alone; one handler no start replaces; a copy that started twice is pressed each key once.
6. `stop_session()` stops its own copy alone, by Ctrl+Z when attached, and does nothing for a copy that is not running.
7. `start_token()`.
8. Send to a given copy and Input: text, selection, refusal.

## Red and green

| Unit | Test (in `tests/test_claude_copies.lua`) | Red message, or why green |
|---|---|---|
| 1 | `new()` › returns a session home with each per-session function as a field; leaves the functions that keep no state on the module; gives each call a copy of its own | red: `attempt to call field 'new' (a nil value)` (3 cases) |
| 2 | two copies › each start a Claude Code of their own… | red: terminals of both copies equal (`Left: false, Right: true`) with a `new()` that delegated to the module's one session |
| 3 | two copies › leave the other running when one's Claude Code exits… | green: spent by unit 2's implementation; killer M5, run |
| 4 | session hooks › reach the copy whose start has the hook's token | red: copy 2's switches `{}` where one `/clear` switch was expected (module routing only) |
| 5 | quitting › stops each copy's Claude Code by its keys | red: `code = 129` (hangup) for the first copy, `0` expected: its handler was replaced by the second copy's start |
| 5 | quitting › takes about the time of one stop, not of two | red after a handler stopped the copies one after another: bound exceeded; green with `stop_together` |
| 5 | quitting › presses Ctrl+Z… to an attached copy | green: spent by `stop_together` and the one handler; killer M6, run |
| 5 | quitting › presses each key of the stop once to a copy that started twice | green: written for the registry's once-only guard; killer M13, run |
| 5 | quitting › keeps the one handler… | green: by nature of the single handler; killers M3, M3b, run |
| 6 | stop_session() › four cases | red: `attempt to call field 'stop_session' (a nil value)` (4 cases) |
| 7 | start_token() › two cases | red: `attempt to call a nil value` (2 cases) |
| 8 | Send › text, refusal, selection | red: text and selection never reached the second fake (`Left: false, Right: true`); refusal said `there is no Input` where `Claude has not started` was expected |

`tests/test_claude_resume_elsewhere.lua` › *raises on a write, as when no session runs* was red in the first whole run: the export wrapper was not a tail call, so `error(…, 2)` named the wrapper's line. `return write_to_session(home, bytes)` restored the message; no new test, that case is the pin.

## Mutants

Each is the literal edit, applied to the committed files and run on `tests/test_claude_copies.lua` unless said.

| # | Edit | Result |
|---|---|---|
| M1 (plan T61-1) | in `take_session_event()`: `local home = started_homes[1]` for the `find` by token | killed by assertion: hooks › reach the copy… (copy 2's switches `{}`) |
| M2 (plan T61-2) | in `stop_running_sessions()`: `for _, home in ipairs(homes) do stop.stop_together(vim.iter({ home }):map(stop_of):totable()) end` | killed by assertion: quitting › takes about the time of one stop |
| M3 | delete the `if is_quit_handler_made then return end … = true` guard in `stop_on_quit()` | killed by assertion: quitting › keeps the one handler |
| M3b (plan T61-3) | `stop_on_quit(home)`, no guard, callback `stop_running_session(home)`, called as `stop_on_quit(home)` | killed by assertion: 3 cases (first copy hung up, `129`) |
| M4 (plan T61-4) | in Send: `pcall(claude.write_to_session, …)` for `pcall(session.write_to_session, …)` | killed by assertion: Send › text, selection |
| M5 | `M.new()` returns `session_functions_of(module_home)` | killed: 9 cases |
| M6 | `way = 'keys'` always in `stop_of()` | killed by assertion: both attached-copy cases (`ended` hangup/keys, Ctrl-C counted) |
| M7 | in the Session table: `stop_session = function() stop_running_sessions(started_homes) end` for `stop_running_session(home)` | killed by assertion: stop_session() › leaves the other copy running |
| M8 | in `existing_input()`: `local input = layout.input_buffer()` for `target.input or layout.input_buffer()` | killed: 3 Send cases |
| M9 | Send's `send()`: `claude.session_status()` for `session.session_status()` | killed: 2 Send cases (one by assertion, one by the write's error) |
| M10 | `start_token = function() return nil` | killed by assertion (types differ) |
| M11 | in `take_next_step()`: `progress.act_at = now` for `now + EXIT_AFTER_HANGUP_MS`; run on `tests/test_claude.lua` | killed by assertion: 4 *quitting Neovim* deaf-Claude cases |
| M12 | in `stop_together()`: `break` after the first job stepped in a tick | survived the copies file as first written, and was called equivalent: wrong. The separating input is a `has_exited` that turns true once the first job is pressed: the committed code presses `{1, 2}`, the mutant `{1}`. Killed by assertion by `stop_together()` › presses the first key to every stop before it looks at an exit (fix round) |
| M13 | `table.insert(started_homes, home)` without the `tbl_contains` guard | killed by assertion: a copy that started twice |

## The quit's time

Two fakes that each exit only on the stop's last key (the fake's `ready` mode, one stop about 4.4 s), `:qa` to the editor's exit: **4442 ms** with `stop_together`; **8901 ms** with the stops one after another (M2's edit), the "before" of O10 (b). The bound in the test is 7500 ms.

## Suites

- Whole suite, `AINEO_TEST_JOBS=4`, host load 20–150: 3214 cases in 88 files, `Fails (1)`: `tests/test_changes_worktrees.lua` › *a list of worktrees that fails* read `aineo is reading the repository` where `  M notes.txt` was expected — the changes home, which this packet does not touch, under load; the file alone passes (67 cases, `Fails (0)`). The first whole run, on the tree before the tail-call fix, failed the one case named above.
- Whole suite after the fix round, `AINEO_TEST_JOBS=4`, Neovim 0.12.5: 3225 cases in 88 files, `Fails (0)`. `tests/test_claude_copies.lua` has 31 cases. `make lint`: stylua and selene, 0 errors.
- Files run while working, all `Fails (0)`: `test_claude_copies` (20), `test_claude` (117), `test_claude_attach` (18), `test_claude_switch` (100), `test_claude_resume` (54), `test_claude_resume_elsewhere` (34), `test_entry_sessions` (44), `test_send` (34), `test_send_selection` (67).
- The deep-require check prints no new line.

## Fix round (PR #207)

The attack and the tests-and-records reviews of `ac06f5e`; the rulings A265 and A266 are the orchestrator's assumptions, not the user's decisions.

| Finding | What was done | Case (red first unless marked) |
|---|---|---|
| Attack 1: `stop_session()` left a start that waits for its list to launch afterwards | A265: `stop_running_session()` marks the home's start `stopped`; `may_launch()` refuses a stopped start; a stopped start with no job is not alive (status `'exited'`, no code); the docstring says so | stop_session() › keeps a start that waits for the list of sessions from launching — red: the fake started |
| Attack 2: a stop racing an automatic restart | the two restart callbacks (no conversation, failed attach) refuse a stopped start; `stop_of()` captures the start it stops | stop_session() › starts nothing in place of a Claude Code that found no conversation — red: two starts, status `ready` |
| Attack 3: Send's `target` not validated | `validated()` runs `vim.validate` on `target`, `target.input`, `target.session` in `send()` and `send_selection()` | Send › refuses a target of the wrong kind, 6 parameters — 6 red. Asked for the field's name alone, the two `target = 5` cases passed on Lua's own `attempt to index local 'target'`, so the cases ask for `vim.validate`'s phrase (`target: expected table`) |
| Attack 4: no pin where token and session routing differ | two copies on one session (`replace_session` onto copy 1's session), hooks naming copy 2's token | session hooks › follow the start's token and not the session… — green; mutant TS kills it |
| Tests 1: no hook to the first-started copy | `/clear` in copy 1 | session hooks › reach the copy that started first as well — green; mutant B3 kills it |
| Tests 2: M12 not equivalent | `stop_together` called directly with `nvim_chan_send` stubbed and `has_exited` true once job 1 is pressed: `{1, 2}` | stop_together() › presses the first key to every stop before it looks at an exit — green; M12 kills it. The M12 row above is corrected; this case reaches `aineo.claude.stop` by a deep `require` in a child, as the orchestrator asked, the one line the deep-require check prints for the tests |
| Tests 3: M9 killed by an error | the refusal case calls `send` under `pcall` and asserts `{ true }` | Send › refuses a copy that is not ready… — M9b kills it by assertion |
| Tests 4 (A266) | recorded as a departure in *What was done*; `stop_by_keys()` and `detach()` docstrings say no key is pressed when `has_exited()` is true | none, nothing the user sees moves |
| Tests 5 | the PR field, the task line's open items, M7 and M8 as literal edits, M12's row, the order of M11–M13 | none |

Mutants of the fix round, run on `tests/test_claude_copies.lua`, all on the committed tree:

| # | Literal edit | Result |
|---|---|---|
| FA1 | delete `and not waiting.stopped` in `may_launch()` | killed by assertion (stop while the list waits) |
| FA2 | delete `or ended.stopped` in the no-conversation callback of `start_in_place_of_no_conversation()` | killed by assertion (two starts) |
| FA3 | delete `if home.session then home.session.stopped = true end` in `stop_running_session()` | killed by assertion: both stop cases |
| FA4 | delete `vim.validate('target.session', …)` in `validated()` | killed by assertion: the two `target.session` parameters |
| FA5 | `has_exited = function() return not is_process_alive(home) end` in `stop_of()` for `running.exit_code ~= nil` | **survives**: with the callbacks refusing a stopped start no restart takes the home during a stop, so reading the home live and reading the stopped start differ only in a race `replace_running_session()` has (a restart run inside its stop's wait); no case builds that race. The capture stays as the reviewer measured it (A117) |
| B3 | `take_session_event()`: `local home = started_homes[#started_homes]; if home and home.session.start_token ~= told.start_token then home = nil end` | killed by assertion: the first copy's hook case |
| TS | `take_session_event()`: `return started.session.start_token == told.start_token or started.session.followed == told.id` | killed by assertion: two copies on one session |
| M12 | `break` after `take_next_step(progress, now)` in `stop_together()` | killed by assertion: `stop_together()` direct case (`{1}` for `{1, 2}`) |
| M9b | `send()`: `claude.session_status()` for `session.session_status()` | killed by assertion: the text case and the refusal case |

## Decisions and assumptions

- A234–A255 (O4, O5, O10 among them) as the orchestrator's assumptions.
- The registry `started_homes` keeps every home for good. A home a closed tab drops stays in it (small, and its token is dropped by `take_session_event()` once a later start replaces it). T67 may want a way to forget one; not done, not asked.
- The test copies start on new session ids: a start that resumes launches Claude Code only after the session list answers, by when the environment the test set may be another copy's.

## Open threads

- `can_join_session` and `prompt_shows_text` keep no state; they are fields of every copy as the brief lists, the same function.
- The hook relay's per-start routing for the *report server's* token (T64) is not touched.

## Task lines

- T61 — implemented on `feature/t61-claude-copies` (PR #207); the line is marked by the knowledge pass after the merge (wave 15 holds its marks). Open on it: `started_homes` never forgets a home, which T67 will need when a tab closes (T67's); the start token's report-server side (the offer carrying it) is untouched (T64's).

## Commits

*Recorded after the merge.*
