# 2026-10-14 — T61 Claude copies

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`, on Sonnet)
**Branch:** `feature/t61-claude-copies` · **Pull request:** recorded after it opens

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
- `aineo.claude.stop`: `stop_together(stops)` runs each stop's keys and waits side by side (a `way` of `keys` or `detach` per job); `stop_by_keys()` and `detach()` are its one-job cases, with the same keys, waits and promises.
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
| M7 | `stop_session` stops `started_homes` | killed by assertion: stop_session() › leaves the other copy running |
| M8 | Send: `local input = layout.input_buffer()` | killed: 3 Send cases |
| M9 | Send's `send()`: `claude.session_status()` for `session.session_status()` | killed: 2 Send cases (one by assertion, one by the write's error) |
| M10 | `start_token = function() return nil` | killed by assertion (types differ) |
| M13 | `table.insert(started_homes, home)` without the `tbl_contains` guard | killed by assertion: a copy that started twice |
| M11 | in `take_next_step()`: `progress.act_at = now` for `now + EXIT_AFTER_HANGUP_MS`; run on `tests/test_claude.lua` | killed by assertion: 4 *quitting Neovim* deaf-Claude cases |
| M12 | in `stop_together()`: `break` after the first job stepped in a tick | survived the copies file. Equivalent in effect: the other job due now is stepped in the next iteration, about 1 ms later (the wait is `max(next_act_at - now, 1)`), and the fakes' timings are of hundreds of ms. Measured on the committed tree, unloaded and loaded alike |

## The quit's time

Two fakes that each exit only on the stop's last key (the fake's `ready` mode, one stop about 4.4 s), `:qa` to the editor's exit: **4442 ms** with `stop_together`; **8901 ms** with the stops one after another (M2's edit), the "before" of O10 (b). The bound in the test is 7500 ms.

## Suites

- Whole suite, `AINEO_TEST_JOBS=4`, host load 20–150: 3214 cases in 88 files, `Fails (1)`: `tests/test_changes_worktrees.lua` › *a list of worktrees that fails* read `aineo is reading the repository` where `  M notes.txt` was expected — the changes home, which this packet does not touch, under load; the file alone passes (67 cases, `Fails (0)`). The first whole run, on the tree before the tail-call fix, failed the one case named above.
- `make lint`: stylua and selene, 0 errors.
- Files run while working, all `Fails (0)`: `test_claude_copies` (20), `test_claude` (117), `test_claude_attach` (18), `test_claude_switch` (100), `test_claude_resume` (54), `test_claude_resume_elsewhere` (34), `test_entry_sessions` (44), `test_send` (34), `test_send_selection` (67).
- The deep-require check prints no new line.

## Decisions and assumptions

- A234–A255 (O4, O5, O10 among them) as the orchestrator's assumptions.
- The registry `started_homes` keeps every home for good. A home a closed tab drops stays in it (small, and its token is dropped by `take_session_event()` once a later start replaces it). T67 may want a way to forget one; not done, not asked.
- The test copies start on new session ids: a start that resumes launches Claude Code only after the session list answers, by when the environment the test set may be another copy's.

## Open threads

- `can_join_session` and `prompt_shows_text` keep no state; they are fields of every copy as the brief lists, the same function.
- The hook relay's per-start routing for the *report server's* token (T64) is not touched.

## Task lines

- T61 — implemented on `feature/t61-claude-copies`; the line is marked by the knowledge pass after the merge (wave 15 holds its marks). Nothing left open on it.

## Commits

*Recorded after the merge.*
