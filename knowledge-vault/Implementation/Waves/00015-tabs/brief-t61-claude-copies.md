**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md`, and `.claude/agents/neovim-lua-developer.md`, whose Neovim rules bind you too.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D63 as proposed and for the recommendations O4, O5 and O10 of `plan.md` in this folder. If the orchestrator ruled otherwise, a dated amendment at the end of this brief says so, and it wins over the body.

## Objective

The task, verbatim from the task list:

> | T61 | One Claude Code per tab (C3, C4; D63, proposed): `aineo.claude` gains `new()`, a session home of its own whose start, join, status, prompt, writes and session hooks are kept apart from every other copy's; a session hook reaches the copy whose start its token names; quitting stops every copy's Claude Code at once; a copy can be stopped alone, as quitting stops it, and tells its start's token; Send writes from a given Input to a given copy; the module's own functions stay one such copy, so every caller and suite of today stands | T48 part 2 | planned — wave 15 |

It rests on:
- **D63**, the user's decision of tabs, and the proposed parts.
- **C3 and C4**: the Claude session and Send.
- D23, D25, D36–D38, D45, D54, D61 and D62, as T48 part 2 leaves them.
- C8, D10, D26, D29.

### What a copy must do — one test each, seen failing first

**Copies**

1. `require('aineo.claude').new()` returns a session home with the module's per-session functions, called as fields: `start_session`, `join_session`, `can_join_session`, `replace_session`, `is_attached`, `session_status`, `session_id`, `session_directory`, `prompt_shows_text` and `write_to_session`. Each call gives a copy of its own. The module stays one copy, so its callers and suites keep working. The functions that keep no state stay on the module: `is_session_id`, `list_sessions`, `session_standing`, `listed_session_name`, `session_row`, `session_statusline`, `session_statusline_format` and `given_settings_verdict`.
2. Two copies each start a fake Claude Code at once. Each has its own terminal, its own `session_status()` and its own `session_id()`, and a start of one never returns or replaces the other's terminal.
3. The exit of one copy's Claude Code leaves the other's running. The first copy then starts anew, as a session that has exited does today.

**Session hooks**

4. A hook told through the module's `receive_session_event()` reaches the copy whose start has the hook's token, and no other copy. A `/clear` in the second copy's fake switches the second copy's session, keeps that id for the folder (D38), and calls the second copy's `on_session_switched`. The first copy follows nothing.

**The stop**

5. Quitting Neovim stops every copy's running Claude Code at once.
   - Each key of the stop is pressed to every running terminal before the wait that follows it, and the waits are shared.
   - An attached copy gets Ctrl+Z alone, never Ctrl-C (T48 part 2's `stop.detach()`).
   - With two fakes that each exit only on the stop's last key, the quit takes about one stop's time, not two (P3).
   - There is one `VimLeavePre` handler for the editor, which no copy's start replaces.
6. A copy's `stop_session()` stops its own running Claude Code as quitting stops it, by keys or by Ctrl+Z for an attached one, and blocks no longer than one stop. It leaves the other copies running. It does nothing when the copy's Claude Code is not running.
7. A copy's `start_token()` gives the token of its last start, which its session hooks and its report server name. It gives nil before any start.

**Send (C4)**

8. `require('aineo.send').send()` and `send_selection()` take an optional `{ session = <claude copy>, input = <buffer> }`. They send that Input's text, or its selection, to that copy's Claude Code, with every refusal and undo of today. Without it they act as today, on the module's Claude Code and the layout's Input.
   - A Send from the second Input reaches the second copy's fake only.
   - A Send to a copy that is not ready is refused as today, whatever the other copy's state.

### Facts, checked at `bugfix/t48-attach` `e0989f2` (T48 part 2, PR #200, open)

Re-check them on the `dev` you are dispatched on. T48 part 2 must have merged first.

**`lua/aineo/claude/init.lua`** (1352 lines):
- The home's state is the file-level `session` (51), the one start, and `hooks_received` (55).
- `stop_running_session()` (79) stops it by `stop.stop_by_keys()`, or by `stop.detach()` when attached.
- `stop_on_quit()` (92) makes its handler in the group `aineo.claude`, cleared when made again. A second copy would remove the first's (P3).
- `prepare_start()` (339) makes each start's token (`session_ids.new_session_id()`) and its buffer `aineo://claude/<token>`, already unique per start. `launch_start()` (617), `become_the_session()` (632), `announce_launch()` (672) and `attach_to()` (689) follow.
- The exports: `can_join_session` (776), `is_attached` (785), `replace_session` (828), `join_session` (859), `start_session` (988), `session_status` (1014), `receive_session_event` (1189), `session_id` (1226), `session_directory` (1234), `prompt_shows_text` (1292) and `write_to_session` (1345).
- `take_session_event()` (1138) drops a hook whose token is not the one start's (1142). The hook relay calls `require('aineo.claude').receive_session_event(...)` (`hook_relay.lua:62`). The module-level function stays the entry point and must route.
- `lua/aineo/claude/self_attach.lua` (T48 part 2) reads a terminal's screen and keeps no file-level state.

**Elsewhere:**
- `lua/aineo/claude/stop.lua`: `stop_by_keys(job, has_exited)` (92) and `detach(job, has_exited)` (115) block the editor for one job.
  - `KEY_PRESSES` waits 2500, 300 and 4000 ms, then a hangup waits up to 5000 ms: 11.8 s at worst per Claude Code (P3).
  - A stop of several jobs at once belongs here, beside them.
- `lua/aineo/send/init.lua`: `send()` (122) and `send_selection()` (319) read `layout.input_buffer()` (50) and write with `claude.write_to_session()` (93), both module-level. `session_status()` is read at 131 and 329.
- The fake: `tests/helpers/fake_claude.lua` answers the stop's keys, `/clear` and the hooks. `tests/helpers/claude_session.lua` waits for starts and launches. Two fakes in one editor are two terminals of the same program, each with its own environment.

Evidence: `evidence/w15-probes.txt` › P2, P3, P4, P5.

### Baseline

This plan ran no suite. The last whole run on record is T48 part 2's fix round: 3199 cases, `Fails (0)`. The dispatch message pastes the counts of the files you run, measured on the `dev` you start from.

Read first:
- `plan.md` in this folder (*The model*, O4, O5, O10);
- the v1 plan note's C3, C4, D23, D36–D38, D54, D61, D62 and **D63**;
- the session notes of T48 part 1 and part 2;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t61-claude-copies` from `origin/dev`, once T48 part 2 has merged.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t61_claude_copies`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/claude/init.lua`, `lua/aineo/claude/stop.lua` and `lua/aineo/send/init.lua`;
  - a new `tests/test_claude_copies.lua`, and `tests/test_claude.lua`, `tests/test_claude_quit_helper.lua`, `tests/test_send.lua` and `tests/test_send_selection.lua` where a pin moves;
  - `tests/helpers/`, **additions only**. If you add to a helper, run every test file that requires it;
  - your session note.
- **You must not touch:**
  - `plugin/aineo.lua`, which T66 changes in stage 2;
  - every other file under `lua/aineo/claude/`, among them `agents.lua`, which T67 changes;
  - every other home under `lua/`;
  - `doc/aineo.txt`. Nothing the user sees changes. The quit of several Claude Codes is told by T66.
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Keep the interfaces.** Every export of `aineo.claude`, `aineo.claude.stop` and `aineo.send` keeps its name, its arguments and its promises, and the modules act as today. Add `new()`, `stop_session()`, `start_token()`, the stop of several jobs, and Send's optional argument, each with its docstring.
- **Session note:** `knowledge-vault/Sessions/<date> — T61 Claude copies.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t61-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run the test files you touch, plus `tests/test_claude_attach.lua`, `tests/test_claude_switch.lua`, `tests/test_claude_resume.lua` and `tests/test_entry_sessions.lua`.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on their covering files.
  - Never run the real `claude`.

## What was decided already

- **The user's decision, 2026-10-14:** tabs, each with its own Claude terminal, Report and Input, only sessions of one folder (D63, `plan.md` › *The user's words*).
- **The orchestrator's assumptions** (O4, O5, O10): one copy per tab behind the same functions, the module as the first; the hook routed by its token; the stop of every copy at once. Record them in the session note and the pull request as such, never as the user's.
- **Rejected:** one Claude Code stopped after another at quit (O10 (b), up to 11.8 s each); a tab key on every function (O4 (b)).
- **What stays as it is:** the stop's keys and waits for one Claude Code (D25, the T59 fix), the attach and its Ctrl+Z (T48 part 2), and `\N`'s new session (D61).

## Budget

Medium to large: one home given copies, the shared stop, Send's argument, with about twelve new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

Write it in your definition's shape, to `<scratchpad>/t61-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- the quit's time with two fakes, before and after;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s T61 mutants. Name the test that kills each.

## The orchestrator's rulings — 2026-10-14, before dispatch

`plan.md` › *The user's answers* (U1–U3, the user's decisions) and *The orchestrator's rulings* (O1–O22 → A234–A255, each its (a)) bind this brief, which is written for them. Record A234–A255 as the orchestrator's assumptions, never as the user's decisions.
