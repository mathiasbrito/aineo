# 2026-10-12 — T48 Resume elsewhere

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`, on Sonnet)
**Branch:** `bugfix/t48-background-resume` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C3, D23, D38, D54, T48
- [[Implementation/Waves/00012-background-resume/plan]] › *Round 4*, *Verification mutants — round 4*
- Brief: `Implementation/Waves/00012-background-resume/brief-t48-background-resume.md`, part 1
- Rests on: T46's reader (`claude agents --json`), [[Sessions/2026-10-11 — T46 Claude sessions key]]

The rulings this part is written for are the orchestrator's assumptions under the user's instruction of 2026-10-06, not the user's decisions: **A185** (two dispatches; this is part 1), **A187** (while the list runs, Claude's window is empty and the status line is as at any start, with no message) and **A190** (the warning's rule: the kept id, `kind` `interactive`, a `pid`). The user's request and answers are quoted in D54. Part 2, the question and the attach, waits for the user's check M16 and is not built here.

## What was done

A start that would resume now asks Claude Code where the session runs before it launches Claude Code, and warns when another interactive Claude Code has the session open.

- `lua/aineo/claude/init.lua`
  - `start_session()` on a kept id makes the terminal buffer at once, keeps it as the one session's, puts it in the last terminal's windows, and returns it. `launch_once_listed()` runs `agents.list_sessions()` and launches Claude Code **in that same buffer** from the callback that receives the answer, once `may_launch()` holds: the start is still the session, its buffer is not wiped, Neovim is not quitting. A start on a new id, and the new session in place of a resume with no conversation, list nothing and launch at once, as before.
  - While it waits: `session_status()` is `'starting'`, `session_id()` is the kept id, a second `start_session()` returns the same buffer, `write_to_session()` raises, and the quit presses nothing (`stop_on_quit()` needs a job).
  - The warning `aineo: this session is also open in another Claude Code` (55 characters, `WARN`) is told once, just before the launch. A list that cannot run, fails, times out, prints too much or is not JSON tells nothing and Claude Code resumes. A launch that fails after the list is told as an error starting `aineo:`, with the first line of what failed (`first_line_of()`). The `--settings` warning and `on_session_switched` are told when Claude Code launches, as the brief's item 4 words it.
  - `prepare_start()` makes the command and the buffer (before the list, so every error `start_session()` raised before it raises still); `launch()` takes the prepared start. The waiting buffer is named `aineo://claude/<start token>`.
- `lua/aineo/claude/window_options.lua` (new, thin, private to the home): `keep_while()` sets the window-local options of the windows that show a buffer back to the values they had before an action. `launch()` runs `jobstart()` through it.
- `lua/aineo/claude/agents.lua`: `ListedSession` keeps `pid` (a number) and `short_id` (Claude Code's short id, a string; not the `session_id`); `is_open_in_another_claude_code()` is the warning's rule.
- `tests/helpers/claude_session.lua`: `wait_for_starts()` counts Claude Code's runs, not the list's; `wait_for_listings()`, `wait_for_launch()` (a waiting start's buffer is an empty scratch buffer until it launches) and `list_gate()` (a `claude.cmd` that holds the list back until the test opens the gate, for 30 s at most) are new; `end_by_keys()` and `press_keys()` wait for the launch.
- `doc/aineo.txt`: *aineo-claude-session* (a paragraph) and *The session list* in section 11.

## Decisions

- **The waiting buffer is named.** Layout's `close_claude_window_when_wiped()` and `take_input_buffer()` take an unnamed, empty buffer in Claude's window for the one Neovim leaves in place of a wiped terminal. `\o` after an exit swaps the empty waiting buffer in for the ended terminal while layout still holds the ended one as Claude's, and layout closed Claude's window (the test `keeps Claude's window in the layout while a restart waits for the list…` was red with 2 windows of 3). A name keeps it out of that rule, and `jobstart()` replaces it with `term://…` (measured on 0.12.5). The brief's "leave the waiting buffer empty" holds: the buffer is empty and unmodified.
- **`jobstart()` runs through `window_options.keep_while()`.** Neovim's default `TermOpen` autocommand sets `number`, `relativenumber`, `wrap`, `list`, `signcolumn`, `foldcolumn` and `winhighlight` of the window the terminal opens in. A terminal started in a hidden buffer opened in a window that is nobody's, and the layout's window kept the user's own; a terminal opened in the window that already shows the buffer lost them (the user's line numbers in Claude's window, and the numbers `\tcn` showed; `test_entry_claude_numbers` and `test_entry_terminal_keys` were red). Putting every window-local option back is the baseline behaviour. Rejected: a `TermOpen` hook in the layout home (outside the boundary; it covered the toggled numbers only, not the user's own, and a test showed that); launching in a new buffer and calling `on_terminal_replaced` (the brief and part 2 say the buffer is the same one and `on_terminal_replaced` is not called).
- **Keeping the options is best effort and never loses the job.** The first form assigned `prepared.job = keep_while(…)`. When putting the options back raised, the job was running but never recorded, the quit found no job to stop, and the fake got a hangup instead of keys. The case `keeps the job it launched when the options of its window cannot be put back` reproduces that. It is the likely cause of a flake seen while the first form stood: `test_claude.lua`'s `ends a turn by keys though Ctrl-C is pressed in the editor meanwhile`, which types Ctrl-C into the editor as it quits, failed in every whole-file run on a loaded host and passed on a quiet one (the baseline passed it on both); after the change it passed in two whole-suite runs, which is evidence and not proof. `keep_while()` now swallows a failure to read or put back (documented), and the job is assigned inside the action.
- **The warning and the `on_session_switched` call come at the launch**, as the brief's item 4 words them ("as seen from the moment of the launch"). Told at `start_session()`, they would name a launch that may never come (a wiped buffer, a quit). The composition root's `start_confirmed` is false until the start is ready, so a switch told later is still not followed (`plugin/aineo.lua`, `forget_confirmation_unless_running()`).
- **The list goes through `schedule_outside_command_line_window()`.** A terminal is refused while the command-line window is open (E11), and a user can open it during the wait.
- **`may_launch()`'s "another start has taken this one's place" check cannot be reached on its own.** A start replaces a waiting one only when `is_running()` is false, which needs the buffer wiped, so the wiped-buffer check always answers first. It stays, as the brief's item 4 asks, and its mutant (m4b) is recorded as equivalent.
- **A launch error is told as its first line.** The command that caused a launch has returned by then, so the composition root's `error_line()` does not see the error. The TermOpen-failure cases of `test_entry.lua` now expect the message without Neovim's `nvim_exec2()[1]..` call-chain prefix, which belongs to the command's context.

## Suites the change moved

Each waits for the launch of a start that resumes (or, where noted, types a key) and asserts what it asserted. Found by running them; the kept id one case leaves makes every later start in the file's home a resume.

| File | Why |
|---|---|
| `tests/test_claude_resume.lua` | `resume_with_no_conversation()` waits for the resume's launch before it returns the terminal |
| `tests/test_claude_switch.lua` | the switch of a resume in another directory is told at the launch (`wait_for_session_switches()`) |
| `tests/test_claude.lua` | `start_again()` cases wait for the launch; the cases that run a script or the deaf fake as `claude.cmd` start in a state directory of their own (`on_a_new_session()`), since a script that ignores its arguments does not answer `agents --json` |
| `tests/test_entry.lua` | wait for the fake's start before they read the windows; the four TermOpen-failure cases wait for the message |
| `tests/test_entry_claude_exit.lua`, `tests/test_entry_claude_mode.lua` | wait for the launch before they look (the "no error" checks after it, since a launch error comes later); the cases that assert Terminal mode press `\c` again once launched (A192) |
| `tests/test_entry_panes.lua` | `open_layout()` and five cases that open the layout themselves wait for the fake's start, and the two command-line-window cases wait for that window to close before they list the windows (T55 works beside this file) |
| `tests/test_entry_sessions.lua` | the refusal cases compare the `agents --json` runs with those a start that resumed made before |
| `tests/test_entry_startup.lua` | two cases wait for the whole layout |
| `tests/test_entry_claude_resume.lua` | a new case, the layout around a waiting start |

`tests/test_claude_agents.lua` changed for the reader's fields. The harness accessor the brief names for `test_entry_sessions.lua` and `test_claude_agents.lua` was not needed: neither counts starts.

## Unit list

1. the reader keeps `pid` and `short_id`; 2. a start on a kept id lists first, then resumes; 3. a start on a new id lists nothing; 4. the buffer comes back at once and the session is `'starting'` on the kept id; 5. a second start returns it and starts nothing, a write raises, the quit presses nothing; 6. the launch is in that buffer with today's arguments; 7. no launch for a wiped buffer, a replaced start, a quit; 8. a list that fails, prints no JSON or times out resumes and tells nothing; 9. the warning, and no warning for a background entry, another id, an entry with no pid; 10. the new session in place of a resume with no conversation lists nothing; 11. the command-line window, a launch that fails, the window's options; 12. the suites the change moved, the layout around a waiting start, the help.

## Red and green

The suite is `tests/test_claude_resume_elsewhere.lua` (24 cases, 8 of them red first), `tests/test_claude_agents.lua` (1 changed case) and `tests/test_entry_claude_resume.lua` (1 new case). Every red was read.

Seen red (10):

- `tests/test_claude_agents.lua`, *delivers each session that carries an id…*: the listed sessions held no `pid` and no `short_id`.
- *lists the folder’s sessions before it launches Claude Code on the kept session*: the record's first run was `--resume`, not `agents`.
- *lists nothing for the new session that takes the place of a resume with no conversation*: no list ran for the resume (0 of 1).
- *returns its buffer at once, empty, starting on the kept session*: the buffer was already a terminal.
- *starts nothing for a second start, which returns the same buffer*: no list reached the gate (0 of 1), the start having launched at once.
- *raises on a write, as when no session runs*: the write succeeded.
- *is warned of once, in one short line, and resumed*: nothing was told.
- *leaves the options of the window that shows it as they were when Claude Code launches in it*: `number`, `relativenumber`, `wrap`, `list` were false, `signcolumn` `no`, `foldcolumn` `0`, `winhighlight` held `StatusLineTerm`.
- *keeps the job it launched when the options of its window cannot be put back*: the write raised, the job lost.
- `tests/test_entry_claude_resume.lua`, *keeps Claude's window in the layout while a restart waits for the list…*: two windows of three.

Arrived green, and the mutant that kills each:

- *lists nothing and launches at once where no session is kept* — green by nature (today's behaviour); m7.
- *presses nothing when Neovim quits* — green before there was a waiting start; m5.
- *launches in that same buffer once the list answers, resuming the kept session as a start does* — green by nature (pinning the arguments, which the launch keeps); m1 (and m12).
- *launches nothing, and tells nothing, when its buffer was wiped…* — green on a start that launched at once; m4a (the first form, without the told-nothing check, let m4a survive).
- *launches nothing for a start that another has taken the place of, and the other launches* — green; m4b is equivalent (see Decisions).
- *launches once the command-line window has closed…* — green by nature of the `schedule_outside_command_line_window()` written with the launch; m10.
- *launches nothing once Neovim is quitting* — green; m4c.
- *tells the user once, as an error, when Claude Code cannot launch…* — green by nature of the `pcall` written with the launch; m15.
- *launches Claude Code all the same when the options of its window cannot be read* — green by nature of the `pcall` written with the module; m18.
- *a list that does not answer* (3 cases: exit 3, not JSON, 5 s timeout) — green by nature (resume as today); m2.
- *is told nothing of when what the list holds is no such session* (4 cases) — green by nature; m8a, m8b, m8c.

## Mutants

Each is its literal edit (`before` → `after`, in the function named), applied from a copy, run on the test file that covers the code, restored after. Round 1 ran on the code of commit `83f5c65`; the fix round's table follows it. `tests/test_claude_resume_elsewhere.lua` unless noted.

| # | Edit | Result |
|---|---|---|
| m1 (round 4's 1) | `start_after_list()`: `become_the_session(waiting, previous)` then `launch_once_listed(waiting, left)` → the same with `launch_start(waiting)` between them | killed, 5 assertions (*returns its buffer at once…*, *raises on a write…*, *tells the user once, as an error…*, *launches once the command-line window has closed…*, *is warned of once…*) |
| m2 (round 4's 2) | `launch_once_listed()`: `function(sessions)` → `function(sessions, problem)` and `if not may_launch(waiting) then` → `if problem or not may_launch(waiting) then` | killed, 3 assertions on the three cases of *a list that does not answer* (their group alone: with the nested `vim.wait()` the 5 s case first had, the run never returned) |
| m3 (round 4's 3) | `launch_once_listed()`: `if agents.is_open_in_another_claude_code(…) then` → `if false and agents.is_open_in_another_claude_code(…) then` | killed, 1 (*is warned of once…*) |
| m4a | `may_launch()`: `and vim.api.nvim_buf_is_valid(waiting.buffer)` → `and true` | killed, 1 (*launches nothing, and tells nothing, when its buffer was wiped…*) |
| m4b | `may_launch()`: `return session == waiting` → `return true` | survived, equivalent: a waiting start is replaced only after its buffer is wiped, which m4a's check answers first |
| m4c | `may_launch()`: `and vim.v.exiting == vim.NIL` → `and true` | killed, 1 (*launches nothing once Neovim is quitting*) |
| m5 | `stop_on_quit()`: `if is_process_alive() and session.job then` → `if is_process_alive() then` | killed, 1 (*presses nothing when Neovim quits*) |
| m6 | `write_to_session()`: `if not is_running() or not session.job then` → `if not is_running() then` | killed, 1 (*raises on a write…*) |
| m7 | `start_session()`: `if choice.resumed then` → `if true then` | killed, 2 (*lists nothing and launches at once…*, *lists nothing for the new session…*) |
| m8a | `agents.lua`, `is_open_in_another_claude_code()`: `… and listed.kind == 'interactive' and listed.pid ~= nil` → `… and listed.pid ~= nil` | killed, 1 (the background-entry case) |
| m8b | the same: → `… and listed.kind == 'interactive'` | killed, 1 (the case with no pid) |
| m8c | the same: `listed.session_id == session_id and …` → `…` without that term | killed, 1 (the case of another id) |
| m9 | `prepare_start()`: delete `vim.api.nvim_buf_set_name(buffer, WAITING_BUFFER_NAME .. start_token)`; `tests/test_entry_claude_resume.lua` | killed, 9 (the layout case among them) |
| m10 | `launch_once_listed()`: `schedule_outside_command_line_window(function()` → `vim.schedule(function()` | killed, 1 (*launches once the command-line window has closed…*) |
| m11a | `agents.lua`: `short_id = typed_field(entry, 'id', 'string'),` → `short_id = entry.id,`; `tests/test_claude_agents.lua` | killed, 1 |
| m11b | `agents.lua`: `pid = typed_field(entry, 'pid', 'number'),` → `pid = entry.pid,`; `tests/test_claude_agents.lua` | killed, 2 |
| m12 | `claude_session.lua`, `wait_for_starts()`: `entry.argv ~= nil and not is_listing(entry)` → `entry.argv ~= nil` | killed, 13 (12 assertions, 1 crash in *lists the folder’s sessions before…*) |
| m13 | not used: drafted for a hook in the layout home that was dropped (see Decisions) | — |
| m14 | `launch_once_listed()`: delete `announce_launch(left)`; `tests/test_claude_switch.lua` | killed, 2 |
| m15 | `launch_once_listed()`: `local launched, failure = pcall(launch_start, waiting)` and the `if not launched then … return end` below it → `launch_start(waiting)` | killed, 1 (*tells the user once, as an error…*) |
| m16 | `window_options.keep_while()`: `pcall(restore, before)` → `local _ = before` | killed, 1 (*leaves the options of the window…*) |
| m17 | the same line → `restore(before)` | killed, 1 (*keeps the job it launched…*) |
| m18 | `keep_while()`: `local read, before = pcall(values_of_windows_showing, buffer)` → `local read, before = true, values_of_windows_showing(buffer)` | killed, 1 (*launches Claude Code all the same when the options… cannot be read*) |
| m19 | `start_session()`: `if is_running() then return session.buffer` → `if is_running() and session.job then …` | killed, 1 (*starts nothing for a second start…*) |

The first round ran against an earlier form of two cases: m4a survived (the launch on an invalid buffer failed quietly) and m2 never returned; both were fixed red-first. The brief's list of failing lists names five (cannot run, fails, times out, prints too much, not JSON); the suite has three cases (exit 3, not JSON, the 5 s timeout). "Cannot run" and "prints more than 1 MiB" take the same `problem` branch of the reader (T46's), which those three cases and m2 pin, so the start's behaviour is covered; the reader's own cases are T46's.

## Fix round

The attack and test-integrity reviews of PR #189 found ordinary paths that left a start stuck or typed into the user's file. The orchestrator ruled **A192** (the waiting buffer is not modifiable, and `\c` enters Terminal or Insert mode only in a terminal buffer, which widens the boundary to `plugin/aineo.lua`'s Claude focus), **A193** (`pcall` around the reader's `nvim_del_autocmd`, which widens part 1's `agents.lua` allowance), **A194** (the two stale comments corrected) and **A195** (the two points that need the real CLI become checks for the user). They are the orchestrator's assumptions under the user's instruction of 2026-10-06, not the user's decisions. Each fix was driven by a case seen failing first.

| Finding | What was done | Case, red first |
|---|---|---|
| Attack 1, typing after `\c` while the start waits | A192: `modifiable = false` in `prepare_start()`; `can_type_to_claude()` requires a terminal buffer | *launches although the user typed into its empty window* (the buffer was wiped, Claude Code never launched); `test_entry_claude_resume`'s *leaves the user in Normal mode, typing nothing into Claude’s empty window…* (mode `i`, `hh` in the buffer) |
| Attack 2, no D45 guard | `was_typing`/`stopinsert` around the waiting launch; four cases ported from the no-conversation start | *leaves a user in Normal mode…* (`dd` typed into the file), *…leaves Visual mode…* (red); *lets a user typing in Insert mode…* and *…Replace mode…* (green by nature, killed by g3b) |
| Attack 3, `:bdelete` of the waiting buffer | `may_launch()` requires the buffer loaded; a `BufUnload` autocommand wipes a waiting buffer that was unloaded | *launches nothing, and tells nothing, when the user deletes its buffer…* (Claude Code launched hidden) |
| Attack 4, a raise in the swap | the list is asked for before the terminals are swapped | *still lists, and launches, when a raise ends the swap…* (1 of 2 starts) |
| Attack 5, `:autocmd! VimLeavePre` | A193: `pcall(vim.api.nvim_del_autocmd, quit_hook)` | *launches although the user removed the list’s own quit hook* |
| Attack 6, a notifier that raises | the warning is told after the launch and `announce_launch()` | *is resumed all the same when the user’s notifier raises on the warning* |
| Attack 7, stale comments | A194: `readiness.lua` (`shown_rows()`) and `plugin/aineo.lua` (`forget_confirmation_unless_running()`) | — |
| Attack 8, the real CLI | A195: steps 9 and 10 of the plan's M16 (a start right after a wipe; whether the list starts or stops the background service) | — |
| Tests 1 | the four TermOpen-failure cases of `tests/test_entry.lua` start from an explicit kept id (`use_state_directory(name, true)`); a new case on a new id pins the prefixed message | the five run alone (a copy keeping them): 5 of 5 pass |
| Tests 2 | `tests/test_entry_claude_exit.lua`: the waits come before the `entry.messages()` and `v:errmsg` checks | X1 (below) killed by assertion |
| Tests 3 | *raises at once, starting nothing, when claude.cmd is not executable* (kept id) | X2 (below) killed run alone |
| Tests 7 | `sleep 100m` in the layout case → a scheduled-callback fence (`wait_for_scheduled_callbacks()`), a condition wait | — |

Two consequences of A192, in the suites: the cases that asserted Terminal mode after the `\c` that *starts* Claude Code now press `\c` again once it has launched (`wait_for_claude_code_in_terminal_mode()`), since the first one stays in Normal mode while the start waits; and the deaf-fake case in `test_entry_claude_exit.lua` starts in a state directory of its own, since typing `i` into a waiting buffer is E21.

Mutants of the fix round (literal edits, from a copy, restored after, on the final code):

| # | Edit | Result |
|---|---|---|
| g1 | `prepare_start()`: delete `vim.bo[buffer].modifiable = false` | killed, 1 (*launches although the user typed…*); the entry case passes without it (g2 guards that path) |
| g2 | `plugin/aineo.lua`, `can_type_to_claude()`: delete `and vim.bo.buftype == 'terminal'` | killed, 1 (`test_entry_claude_resume`'s typed case) |
| g3 | `launch_once_listed()`: delete `if not was_typing then vim.cmd.stopinsert() end` | killed, 2 |
| g3b | the same: `if not was_typing then` → `if was_typing then` | killed, 4 (the two Normal-mode cases and the Insert and Replace cases) |
| g4 | `may_launch()`: `nvim_buf_is_loaded(waiting.buffer)` → `nvim_buf_is_valid(waiting.buffer)` | survived: the `BufUnload` wipe (g5) runs on the next tick, before a list can answer, so the loaded check is defence in depth that no input separates |
| g5 | `prepare_start()`: `and not vim.api.nvim_buf_is_loaded(buffer)` → `and false` in the `BufUnload` callback | killed, 1 (*launches nothing, and tells nothing, when the user deletes its buffer…*) |
| g6 | `start_after_list()`: `launch_once_listed(…)` then `become_the_session(…)` → the two swapped | killed, 1 (*still lists, and launches, when a raise ends the swap…*) |
| g7 | `agents.lua`: `pcall(vim.api.nvim_del_autocmd, quit_hook)` → `vim.api.nvim_del_autocmd(quit_hook)` | killed, 1 |
| g8 | `launch_once_listed()`: the warning's `if agents.is_open_in_another_claude_code(…)` block also before `local was_typing = …` | killed, 2 (*is warned of once…* — told twice —, *is resumed all the same when the user’s notifier raises…*) |
| f1 | round 4's mutant 1 on the reordered code: `launch_start(waiting)` before `launch_once_listed(waiting, left)` in `start_after_list()` | killed, 8 |
| X1 (the reviewer's) | `launch_once_listed()`: `error('rev mutant: boom')` after `announce_launch(left)`; `tests/test_entry_claude_exit.lua` | killed, 2 by assertion (*raising no error, when wiped from another tab by*, both parametrisations) |
| X2 (the reviewer's) | `prepare_start()`: `ensure_executable(settings.cmd[1])` → `if not choice.resumed then ensure_executable(settings.cmd[1]) end`; the new case alone | killed, 1 |

## Whole suite

`AINEO_TEST_JOBS=4 AINEO_TEST_RUN_LIMIT_MS=2700000 make test` on Neovim 0.12.5 (the host, loaded by other agents' suites throughout), on the tree whose code is the fix round's last code commit: 3052 cases in 84 groups, `Fails (0) and Notes (0)`, exit 0. `make lint`: 0 errors, 0 warnings. The first round's run, on commit `83f5c65`, was 3040 cases in 84 groups. `tests/test_doc.lua` passes.

## Open threads

- **User-visible, by design (A187):** Claude's window is empty from `\o`/`\c`/autostart until the list answers, usually well under a second, at most 5 s. `\c` pressed in that time asks for Insert mode in the empty buffer, and Neovim enters Terminal mode when the terminal exists. Part 2's M16 step 2 times the list.
- **Stale comments outside the boundary:** `lua/aineo/claude/readiness.lua` says the session starts Claude Code's terminal in a buffer no window shows (`shown_rows()`'s docstring), and `plugin/aineo.lua`'s `forget_confirmation_unless_running()` says `start_session()` tells the switch before it returns; for a start that resumes, both now start later. The behaviour is unchanged (checked above).
- **`test_entry_panes.lua`'s command-line-window case failed once on a loaded host and passed on re-run** (`a switch refused in the command-line window`); it types `<C-c><Esc>` against Neovim's timing. Not touched.
- **A nested `vim.wait()` inside a `vim.wait()` condition never returned** when the outer condition never held (the 5 s timeout case before it was rewritten): worth a line in the test conventions.
- **For the user, with the real CLI (A195; steps 9 and 10 of the plan's M16):** a hung-up Claude Code may still be listed right after a wipe, which would make the warning false for an immediate `\o`; and whether `claude agents --json`, which every start that resumes now runs, starts or stops Claude Code's background service.
- **`\c` while the start waits** (A192) moves to Claude's window and stays in Normal mode; a second `\c` after the launch enters Terminal mode.
- `dev` has moved on (T55 changes the pane actions in `plugin/aineo.lua` and the layout); this branch was not merged with it. The `plugin/aineo.lua` edits here are `can_type_to_claude()` and one comment.
- Hashes are recorded after the merge.

## Task lines

- T48 part 1 done (`bugfix/t48-background-resume`, into `dev`): the list before a start that resumes, the waiting start, the warning for a session open in another interactive Claude Code, the reader's `pid` and `short_id`, the help (C3; D23, D38, D54). The task line stays open for part 2, the question and the attach, which waits for the user's check M16.

## Commits

Recorded after the merge.
