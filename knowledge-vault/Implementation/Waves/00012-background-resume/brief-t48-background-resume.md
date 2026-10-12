**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> Written 2026-10-12 for wave 12's recommendations: U1 (a), U2 (a), O1–O5 (a) (`plan.md`). It is dispatched after the user answers U1. An answer that differs, and any fact below that moved on the `dev` you start from, is a dated amendment at the end of this brief, written before dispatch, and it wins over the body. **Never run the real `claude`**, and never touch Claude Code's background service: the suites run the fake.

## Objective

The task, verbatim from the task list:

> | T48 | A start of Claude Code does not resume a session that runs in Claude Code's background service (C3; D23, D38, proposed D54): when `claude agents --json` lists the session kept for the folder as a background session whose process runs, the start begins a new session and says so, leaving the background one untouched, as the user answers U1 | T46 | planned — wave 12, held for U1 |

It rests on: **proposed D54**, with the user's request quoted in it; D23 and D38 (the kept id, resumed at each start, and a switch followed and kept); D45 (the hand-over, which applies only to a dead session); D39–D41 (per-session Report, draft and changes base); D49's R3 ("Nothing is moved behind your back"); C3; D13 (`claude.cmd`); D26, D29. Design and evidence: `plan.md` in this folder (*What is established*, *What aineo should do*, *Decisions for the orchestrator*), and `evidence/w12-docs.txt` (D1–D8).

### The behaviour — one test each, seen failing first

1. **The check.** A start that would resume — the folder has a kept id (`kept_or_new_session()`) — first lists the folder's sessions through T46's reader (`list_sessions()`): `claude.cmd` followed by `agents --json --cwd <folder> --all`, `<folder>` being the start's `settings.cwd`. A start with no kept id runs no list. The new session that `found_no_conversation()` puts in place runs no list either.
2. **Running in the background** (O1 (a)). A listed entry whose session id is the kept id, whose `kind` is `background`, and whose process runs (the reader's `running`: a `pid` or a `status`) makes the start begin a **new** session (`--session-id <new id>`). That new id is kept for the folder, as D23 keeps a new one. The background session is not resumed, attached, forked or stopped, and nothing is written to it.
3. **Anything else resumes as today** (`--resume <kept id>`): the kept id not listed; listed as background without `pid` or `status`; listed as `interactive`, running or not (O1 (a)); and a list that could not be run, failed, timed out, printed too much, or printed what is not a JSON array (O3 (a)). None of these tells the user anything new.
4. **The user is told** (O5 (a)). A start that begins a new session for behaviour 2 gives one warning, at most 60 characters, for example `aineo: kept session runs in background; started a new one`. Nothing else is told.
5. **The editor never waits** (O2 (a)). `start_session()` returns the terminal buffer at once, as today. Claude Code is launched in that same buffer once the list has answered — or failed, or reached its 5 s bound — so no window changes its buffer and `on_terminal_replaced` is not called. While the list runs, `session_status()` is `'starting'`. What raises today still raises synchronously: a malformed setting, a first word that is not executable, a command that cannot be built. A `jobstart()` that fails after the list is told the user once, as an error starting with `aineo:`, as `start_new_session_in_place()` tells it, and leaves the session exited.
6. **Quitting or restarting while the list runs.** If Neovim quits before the list answers, no Claude Code is started (the reader already kills its run on `VimLeavePre`), and the quit waits on nothing. A second `start_session()` while the list runs starts nothing and returns the same buffer: one Claude Code at a time.
7. **The new session takes nothing from the background one** (O4 (a)). Its Report, Input draft and changes base are its own (D39–D41); D45's hand-over is not called. The panes follow it once it is ready, as at any start (`on_session_ready`).
8. **The help** says what a start does when the kept session runs in the background service, and how to reach that session: `claude attach <id>` in a shell, or agent view.

### Facts, checked against `origin/dev` `1dc3186`

- `lua/aineo/claude/init.lua`:
  - `start_session()` 560 starts on `kept_or_new_session()` 196, through `start_in_place()` (assigned at 467) and `launch()` 293, which makes the buffer and runs `jobstart(…, { term = true })` in it (`run_in_terminal()`).
  - `session_arguments()` 209.
  - `found_no_conversation()` 236 and `start_new_session_in_place()` 427 are the T19 path, which `on_terminal_replaced` and the D45 hand-over hang on (`plugin/aineo.lua` `replacement_callbacks()` 563, `hand_over_dead_session()` 512).
  - `SETTINGS_UNREAD_WARNING` 254 is the 60-character rule.
  - `session_status()` 584, `session_id()` 780, `list_sessions()` 806.
  - `stop_on_quit()` 73.
- `lua/aineo/claude/agents.lua`: `LIST_BOUND_MS` 16 (5 s); `list_sessions(command, folder, on_done)` 277, which calls `on_done(sessions)` or `on_done(nil, problem)`, scheduled; `ListedSession` 12, whose `running` is set by `pid` or `status`; `standing()` 89 is the pick's rule and is not this packet's.
- `lua/aineo/claude/session_ids.lua`: `kept_session_id()` 90, `keep_session_id()` 178.
- **The fake.** `tests/helpers/fake_claude.lua` `answer_agents()` 274 records the `agents` run's argv in **the same record file** as Claude Code's run (`AINEO_FAKE_CLAUDE_RECORD`), and prints the array in the file `AINEO_FAKE_CLAUDE_AGENTS` names (`[]` when unset). Its modes `--resume` and `--session-id` record the session they started on.
- **The harness consequence.** `tests/helpers/claude_session.lua` `wait_for_starts()` 811 counts every record entry with an `argv` as a start, and `wait_for_start()` 840 returns the first. With behaviour 1, every suite that resumes would see the list's run as its first start. Make a start an entry whose `argv` does not begin with `agents`. Give `tests/test_entry_sessions.lua` and `tests/test_claude_agents.lua`, which read the list's own argv, whatever accessor they need. Measure the change on the suites that resume (`git grep -ln 'wait_for_start' tests`) before you rely on it.
- **What a resume of a running background session does** (`evidence/w12-docs.txt` D1, D2, D4; `plan.md` E2, E3): Claude Code 2.1.296 attaches the terminal to it. The attached terminal is not aineo's session, and aineo's quit then presses Ctrl-C into it. That is why the start must not resume it. None of this is reproduced: the fake has no background service, and the test of behaviour 2 is the argv the fake records.

### Baseline

The suite's counts on the `dev` you start from are pasted by the dispatch message.

Read first: the v1 plan note's D23, D38, D45, D49 (its note of 2026-10-11 on R3), proposed D54, C3; `plan.md` in this folder; `evidence/w12-docs.txt`; `knowledge-vault/Projects/aineo.md`; the session notes of T19, T41 and T46 in `knowledge-vault/Sessions/`.

## Boundary

- **Branch:** `bugfix/t48-background-resume` from `origin/dev`.
- **Class:** regular. It changes what a start does, in `lua/aineo/claude/`, and runs a process; §3 of the orchestrate skill keeps both from a small fix.
- **Model:** `sonnet` — the orchestrator's instruction for this wave.
- **Resources:** `impl_t48_background_resume` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/claude/init.lua`: the start path (`start_session()`, `start_in_place()`, `launch()`, `kept_or_new_session()`) and its docstrings.
  - `lua/aineo/claude/agents.lua`: one predicate on a listed session, if the start needs one beyond `running` and `kind`.
  - `tests/helpers/claude_session.lua`: what counts as a start.
  - `tests/helpers/fake_claude.lua`: a delay before its `agents --json` answer, if behaviour 5 or 6 needs one to be seen; its docstring updated.
  - A new `tests/test_claude_background_resume.lua`. `tests/test_entry_sessions.lua` and `tests/test_claude_agents.lua`, where the helper's change moves them.
  - `doc/aineo.txt`, three places: the section from `*aineo-claude-session*` to the line before `*aineo-draft*`; in section 11, the subsection *Stopping Claude Code on quit* (add that Claude Code shows its own `Background work is running` dialog on exit while background work runs, and that what aineo's stop does then is not measured); and the subsection *The session list* (`claude agents --json` now also runs at each start that resumes).
  - Your session note.
  - Correct in the same commit what the change makes false there, and say in your report what you corrected.
- **You must not touch:**
  - The rest of `lua/aineo/claude/`: `stop.lua`, `hook_relay.lua`, `readiness.lua` and `session_ids.lua` are used as they are.
  - `plugin/aineo.lua` — O4 (a) needs no change there; if it does, that is a spec conflict for your report.
  - `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/changes/`, `lua/aineo/report/`, `lua/aineo/draft/`, and the rest of `tests/helpers/`.
  - Every other section of `doc/aineo.txt`, and `tests/test_doc.lua` (run it).
  - The plan notes, the project note and the task list: write a `## Task lines` section in your session note instead.
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/<date> — T48 Background resume.md`, `<date>` the dispatch message's.
- **Scratch prefix:** `t48-`.
- **How the suite runs (D26, D29):** on Neovim 0.12.5. While you work, run the test files you touch, every test file that requires a helper you change, and `tests/test_doc.lua`. Run the whole suite (`make test`) once before each push. Mutants run on their covering files. The fake `claude` only.

## What was decided already

- Proposed D54's decided part: a start does not open the kept session in aineo's terminal while that session runs in Claude Code's background service.
- U1 (a) and U2 (a) as the user answers them, which the amendment quotes. The quit is not changed in this packet.
- D49's R3, the user's: a session running elsewhere is never moved behind the user's back.
- O1–O5 (a), the orchestrator's, recorded in the session note and the PR body as the orchestrator's assumptions, never as the user's decisions.

## Budget

Small to medium: one check before the start, a launch deferred into the same buffer, one helper's rule for what a start is, and the help — about eight cases. If the deferred launch reaches further than `lua/aineo/claude/init.lua` — for example a caller that reads `session_id()` before Claude Code runs and breaks — stop at a green, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t48-report-packet.md`. Open the pull request into `dev` before you report. Put in it every verification claim a reviewer can re-measure, each test file whose pins moved and why, and the whole suite's counts. The orchestrator's verification runs `plan.md`'s five mutants: name the test that kills each.
