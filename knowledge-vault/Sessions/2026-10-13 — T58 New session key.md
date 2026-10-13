# 2026-10-13 — T58 New session key

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`, on Sonnet)
**Branch:** `feature/t58-new-session` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C1, C3, D23, D37, D38, D49, D53, D58, D61, T58
- [[Implementation/Waves/00014-cut-bases-new-session/plan]] › O12–O17, A207–A212, *Verification mutants* › T58
- [[Implementation/Waves/00014-cut-bases-new-session/brief-t58-new-session]]
- Rests on: [[Sessions/2026-10-12 — T54 Terminal keys]] (the twin), and the `\S` packet T46 (the pasted write and its refusals), at the head of `dev` this branch starts from (`20def68`)

The user's part is the key itself: "go ahead implement them", 2026-10-13, answering a list that named "the offered single key for a new session after `/exit`". **Everything else is the orchestrator's assumption under that answer, not the user's decision:** the letters (`\N`, `<C-\>N`), the command (`:Aineo new`), what the key does in each state, its four refusals, and what it does while a turn runs — O12–O17, ruled as A207–A212 before dispatch.

## What was done

`:Aineo new`, `<Plug>(aineo-new)`, `\N` and the twin `<C-\>N` (Terminal and Insert mode).

- **No Claude Code running in this editor** (never started, exited, or its terminal wiped): `start_new_session()` starts it on a new `--session-id` — no list of sessions, no resume — keeps the new id for the folder (so the next `\o` after an `/exit` resumes it), opens or restores the layout around the new terminal as `\o` does, and moves to Claude's window in Terminal mode (`focus_claude()`). The start is told to `on_session_switched` as any start on another session is, so the Report, Input's draft and the changes pane follow it.
- **Running, ready, prompt empty:** `write_command_at_empty_prompt()` moves to Claude's window in Terminal mode, reads the prompt, and writes a bracketed paste of `/clear` and Enter in one write. The fake's hooks then move it to a new session and aineo follows as it follows any `/clear`.
- **Refusals**, each one warning beginning `aineo: no new session — ` with nothing written or started: a claim of another session (checked first, in any state), Claude Code starting or behind a dialog or in a start that waits for the session list (`NOT_READY`'s words), text in the prompt (cursor back through `return_to()`), and Claude's window not entering Terminal mode in a second.

Files:

- `lua/aineo/claude/init.lua`: one optional validated setting, `new_session`; `kept_or_new_session()` ignores the kept id under it; `start_session()`'s docstring says what it changes. A start on a new id already lists nothing, keeps its id (`start_in_place()`) and is told as a switch (`announce_launch()`), so nothing else changed there.
- `plugin/aineo.lua`: `new` after `sessions` in `SUBCOMMANDS`; `new = 'N'` in `PREFIX_KEYS` (the twin and the `<Plug>` mapping follow from the lists); `open_layout_around()` split out of `open()`; `started_claude_terminal(config, new_session)`; `write_command_at_empty_prompt()` extracted from `switch_to_session()` and shared with `new_session()`; `after_entering_terminal_mode()` takes the words its caller's warning begins with.
- `lua/aineo/health.lua`: `N` in its `PREFIX_KEYS`; the twins' lines come from it.
- `doc/aineo.txt`: the introduction, *aineo-claude-session*, `*:Aineo-new*`, `*<Plug>(aineo-new)*`, `*aineo-\N*`, `*aineo-<C-\>N*`, a LIMITS entry *The new session key*; and two sentences the change made false (*Of the actions, only `open` restarts an exited Claude Code*; the line-number note naming `open` as the only restart).

## Decisions

- **The claim is checked before the state** (A211: "a claim holds, in any state of Claude Code"). A claim in the exited state would otherwise start a session behind the claimed panes.
- **The setting is `new_session`, a boolean, on `aineo.claude.Settings`**, as the brief's boundary asks, not a second function: `start_session()` stays the one entry point and `kept_or_new_session()` the one place that chooses.
- **`write_command_at_empty_prompt()` is extracted, not copied**: `\S` and `\N` share the move to Claude's window, the prompt read, the write, `return_to()` and the timeout. The timeout's message begins with the caller's `outcome`, so `\S` keeps `aineo: not switched — ` and `\N` says `aineo: no new session — ` (the `\S` test of that message passes unchanged).
- **A turn is not detected** (A212): the input box shows during a turn, so the session reads as ready and `/clear` is written as Send writes during a turn (D14). The user's check M2 measures what Claude Code does; it is in LIMITS.

## Unit list

1. `start_session()` with `new_session` starts on a new id, not the kept one; 2. keeps it for the folder; 3. starts nothing while a session runs; 4. tells `on_session_switched`; 5. refuses a `new_session` that is not a boolean; 6. the subcommand, the `<Plug>` mapping and `\N` (completion, description, usage, the key pins); 7. the twin; 8. the health lines; 9. after an exit: a new id, no list, kept, layout and cursor, never started, wiped terminal, panes follow; 10. running and ready: the paste and Enter, the cursor; 11. the four refusals, with the claim in the exited state too; 12. the twin from Terminal mode and from Insert mode for each of 9–11; 13. the help.

## Red and green

`make test_file` on Neovim 0.12.5.

Seen red for the intended reason, before the code:

- `tests/test_claude_resume.lua` (5 cases added): 4 red — `starts Claude Code on a new session id, not the kept one…` (`--session-id` words `{}`: the kept id was resumed), `keeps the new session id it was asked for…`, `tells on_session_switched of the new session…` (0 switches, expected 1), `raises an error naming new_session when it is not a boolean` (nothing raised). `starts nothing when asked for a new session while Claude Code runs` arrived green by nature (the running guard exists); its first form counted all the record's lines (5) and was corrected to count starts. Killer: the edit `if is_running() then` → `if false then` in `start_session()` (M13 below).
- `tests/test_entry_new_session.lua` (new, 26 cases), first run before any plugin code: 23 of 25 red (the file had 25 cases then); the two that passed, `lists no session and resumes nothing` and `keeps the new id for the folder…`, passed because they asserted on a second start that never came; both were corrected to assert that the start exists (`eq(#wait_for_starts(fake, 2), 2)`, `eq(#new_id_of_start(fake, 2), 1)`) and are killed by M1. The case `opens the layout around a new session when Claude’s terminal was wiped` was added after the code and arrived green; killed by M6 (and M1, M9).
- `tests/test_health.lua`: 6 red with `N` missing from `health.lua` (the *Prefix mappings* and *Terminal prefix mappings* lines); after the production change 17 more pins moved by position (the leader warnings at line 12, the Visual line at 11, the twins' warning at 19, the not-mapped list) and were corrected.
- The pins that list the subcommands, the keys and the mappings, run against the parent commit's `plugin/aineo.lua`, `lua/aineo/health.lua` and `lua/aineo/claude/init.lua` with the final tests (see *Pins run against the parent*, below).

Arrived green, and why:

- `starts nothing when asked for a new session while Claude Code runs`: green by nature, as above; killer M13.
- The twin cases of `tests/test_entry_new_session.lua` and the `<C-\>N` cases of `tests/test_entry_terminal_keys.lua`, which are parametrized over `TWIN_KEYS` and `PREFIX_KEYS`: red before the code by the missing mapping; none arrived green.

## Mutants

Literal edits, one at a time, restored from a copy after each, on the final tree. The claude-home mutants ran on a copy of `tests/test_claude_resume.lua` narrowed to its `start_session()` group (27 cases) and on `tests/test_entry_new_session.lua`; the plugin mutants on `tests/test_entry_new_session.lua`, M10 on `tests/test_entry_prefix.lua`, M11 also on `tests/test_entry_terminal_keys.lua`. A kill counts when the failures are expectations (`Failed expectation` as many as `Fails`); every kill below is.

| # | Edit | Killed by |
|---|---|---|
| M1 | `lua/aineo/claude/init.lua`: `if kept and not settings.new_session then` → `if kept then` | resume file 3 (`…new session id, not the kept one…`, `keeps the new session id…`, `tells on_session_switched…`); entry file 10 (the three entry points, `lists no session…`, `keeps the new id…`, the layout case, the wiped case, the panes case, the twin's start in `t` and `i`) |
| M2 | same file: `if not choice.resumed then` → `if not choice.resumed and not settings.new_session then` (before `keep_session_id`) | resume file 1 (`keeps the new session id it was asked for…`); entry file 1 (`keeps the new id for the folder, so that \o resumes it after /exit`) |
| M3 | `plugin/aineo.lua`: `if claude.prompt_shows_text(vim.api.nvim_get_current_win()) then` → `if false then` | 3: `while the prompt holds text…` and the twin's, `t` and `i` |
| M4 | `claude.write_to_session(PASTE_START .. command .. PASTE_END .. '\r')` → `… PASTE_END)` | 3: `writes /clear and Enter as one paste…` and the twin's, `t` and `i` |
| M5 | `if refuses_while_claimed(NO_NEW_SESSION) then` → `if false then` | 2: the claim in the ready state and in the exited state |
| M6 | `if status == nil or status == 'exited' then` + `start_new_session()` → `if status == nil then` + `start_new_session()` | 10 (every case that starts after an exit; the exited session is refused as not ready) |
| M7 | `if refuses_while_not_ready(NO_NEW_SESSION) then` → `if false then` | 2: `while Claude Code is starting or a dialog…` and `while a start waits for the session list…` |
| M8 | `start_new_session()`: `focus_claude()` removed | 1: the cursor in Claude's window in Terminal mode after the start |
| M9 | `started_claude_terminal(config, true)` → `started_claude_terminal(config)` | 10 (the start resumes the kept id) |
| M10 | `PREFIX_KEYS`: `new = 'N',` → `new = 'M',` | `tests/test_entry_prefix.lua` 4 |
| M11 | `HAS_NO_TWIN = { send = true }` → `{ send = true, new = true }` | entry file 6 (the twin cases); `tests/test_entry_terminal_keys.lua` 4 (`is <C-\> by default…`, `is the one vim.g.aineo names`, `N` in `t` and `i`) |
| M12 | `vim.notify(outcome .. 'Claude’s window did not enter Terminal mode'` → `vim.notify(NOT_SWITCHED .. …` | 1: `when Claude’s window does not enter Terminal mode…` |
| M13 | `start_session()`: `if is_running() then` → `if false then` | resume file 1 (`starts nothing when asked for a new session while Claude Code runs`) |
| M14 | `vim.validate('settings.new_session', settings.new_session, 'boolean', true)` removed | resume file 1 (`raises an error naming new_session…`) |

The five mutants of `plan.md` › *Verification mutants* › T58 are M1 (its 1), M2 (its 2), M3 (its 3), M4 (its 4) and M5 (its 5).

## Pins run against the parent

The tests of this branch against the parent commit's `plugin/aineo.lua`, `lua/aineo/health.lua` and `lua/aineo/claude/init.lua` (the three files copied from `HEAD~1`, restored after): `tests/test_entry.lua` 5 of 50 red, `tests/test_entry_prefix.lua` 4 of 78, `tests/test_entry_terminal_keys.lua` 4 of 108, `tests/test_plugin.lua` 1 of 5, `tests/test_entry_panes.lua` 2 of 98, `tests/test_health.lua` 22 of 106, `tests/test_claude_resume.lua` 4 of 54. The pins were changed first and seen failing in the health file; the others were moved together with the code and are shown red here against the code they pin.

## Whole suite

`AINEO_TEST_JOBS=4 AINEO_TEST_RUN_LIMIT_MS=2700000 make test` on Neovim 0.12.5 (the host, loaded: other agents' suites ran beside it), on the tree pushed, code and tests unchanged since the mutants: **3117 cases in 85 groups, `Fails (0) and Notes (0)`, exit 0**; `make lint`: 0 errors, 0 warnings. A first whole run at a load average of 70 failed one case, `tests/test_claude.lua | quitting Neovim | ends a turn by keys though Ctrl-C is pressed in the editor meanwhile` (the stop's keys, which this branch does not touch: the session ended on the hangup, 129, before the keys); the file alone passed (117 cases, `Fails (0)`) and so did the second whole run. The note was completed after the run; no other file changed.

## Open threads

- That Claude Code takes a pasted `/clear` as a command (check M1) and what it does with `/clear` written during a turn (check M2) are unmeasured; both are in LIMITS, *The new session key*.
- After `\N` on a session in which nothing was sent, the session left holds no conversation and `/resume` of it finds none: that is Claude Code's, as for any `/clear` before a first message.
- The brief's boundary did not list `tests/test_plugin.lua` and `tests/helpers/entry.lua`; the first pins the whole list of the plugin's mappings and the second holds `:Aineo`'s usage string, and both had to name `new`. Both changes are one added word or list entry.

## Task lines

- T58 `[X]` (`feature/t58-new-session`, into `dev`) — `:Aineo new`, `<Plug>(aineo-new)`, `\N` and `<C-\>N` (C1, C3; D61): a new session on a new id after the exit, `/clear` at an empty prompt while Claude Code runs, four refusals; the health lines and the help. D61's letters and states are the orchestrator's assumptions (A207–A212), not the user's decisions.

## Commits

Recorded after the merge.
