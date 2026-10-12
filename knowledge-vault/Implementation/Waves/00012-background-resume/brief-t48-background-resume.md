**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> Written 2026-10-12 for wave 12's round 2 (`plan.md` › *The user's answers — round 1*, *Round 2*). It covers the user's U1 and U2 answers, the redraw (ii) under O6 (a), and O7–O10 (a). It is dispatched after the user's check M11.
>
> If M11 shows that `Ctrl+L` does not bring the content and the window held a fresh session, this brief is amended for the typed `/resume` (i) before dispatch, and M12 must be in too. Any fact below that moved on the `dev` you start from is also a dated amendment at the end. An amendment wins over the body.
>
> **Never run the real `claude`**, and never touch Claude Code's background service: the suites run the fake.

## Objective

The task, verbatim from the task list:

> | T48 | A start whose kept session runs elsewhere resumes it and shows it (C3; D23, D38, D54): when Claude Code's screen shows that the start attached to a session running in its background service, aineo makes the session's content show (wave 12's O6, after the user's check M11); when `claude agents --json` lists the kept session open in another interactive Claude Code, aineo tells the user and resumes it all the same | T46 | planned — wave 12, held for M11 |

It rests on these:
- **D54**, with the user's answers quoted in it, verbatim. aineo always resumes the kept session. It warns when that session runs in another interactive Claude Code. It resumes a background one so that its content shows. The quit is not changed.
- D23 and D38: the kept id, resumed at each start; a switch is followed and kept.
- D37's note (A1): a `SessionStart` with no `SessionEnd` of the followed id before it is no switch.
- D49's reader (`claude agents --json`, T46). A133: how a write is made to Claude's terminal.
- C3, D13 (`claude.cmd`), D26, D29.

Design and evidence: `plan.md` in this folder (*What is established* E2–E3, *Round 2*, *Decisions for the orchestrator — round 2*), and `evidence/w12-docs.txt` D1, D2, D4, D9, D10.

### The behaviour — one test each, seen failing first

1. **The start resumes as today.** It passes `--resume <kept id>` when an id is kept. Nothing in this packet replaces, forks, stops or delays it.
2. **The attach is read off the screen** (O7 (a)).
   - After a start that resumed, aineo watches the new terminal's lines for Claude Code's `running in the background (` line, read with every white space removed, as `found_no_conversation()` reads its line.
   - A start that did not resume watches for nothing. So does the new session that takes the place of a resume with no conversation.
3. **The redraw** (O6 (a), (ii); O8 (a)).
   - Once that line has shown, and once a window has shown the terminal at its size (`start_session()`'s docstring: before that the terminal has a hidden window's 5 rows), aineo writes one `Ctrl+L` (`\x0c`) to Claude Code's terminal.
   - It does this once per start, however often the line is redrawn.
   - It writes nothing once the session has exited, once Neovim is quitting (`v:exiting`), or more than 10 s after the start.
   - `Ctrl+L` is Claude Code's documented recovery for a partially blank fullscreen display, and attached sessions render fullscreen (D2, D9, D10).
4. **The warning** (O9 (a), O10 (a)).
   - Beside the start — after Claude Code is launched, never before — aineo lists the folder's sessions through T46's reader: `list_sessions()`, which runs `claude.cmd` followed by `agents --json --cwd <folder> --all`, `<folder>` being the start's `settings.cwd`.
   - A list that comes back with an entry of the kept id that is `interactive`, has a `pid`, and is not aineo's own Claude Code gives one warning of at most 60 characters. For example `aineo: this session is also open in another Claude Code`. aineo's own is the entry whose `pid` is the terminal job's (`jobpid()`), or whose `startedAt` is at or after this start's launch, since a `claude.cmd` that wraps `claude` gives another pid.
   - A start that did not resume runs no list.
   - A list that fails, times out, prints too much or is not JSON tells nothing.
5. **Nothing else changes.**
   - D38: the kept id stays as it was. No hook is told, nothing is switched, and the panes follow the session once it is ready, as at any start.
   - The quit stays as it is (U2), and so does the session hook relay.
6. **The help** says:
   - what a start does when the kept session runs in Claude Code's background service: it attaches, and aineo redraws once;
   - that an attached session keeps its own flags, so aineo's Report may get nothing from it and Claude may ask before using the report tool (D4);
   - that aineo's quit presses Ctrl-C into it, which interrupts a turn in progress (D2; U3);
   - and the warning.

### Facts, checked against `origin/dev` `1dc3186`

- `lua/aineo/claude/init.lua`:
  - `start_session()` 560 starts on `kept_or_new_session()` 196, through `start_in_place` (assigned at 467) and `launch()` 293, which makes the buffer, watches it (`readiness.watch()`), and runs `jobstart(…, { term = true })` in it.
  - `found_no_conversation()` 236 reads the screen at exit, with the white space removed.
  - `start_new_session_in_place()` 427 is T19's replacement. No list runs for it, and it watches for no line.
  - `SETTINGS_UNREAD_WARNING` 254 is the 60-character rule.
  - `session_status()` 584, `session_id()` 780, `list_sessions()` 806, `write_to_session()` 896.
- `lua/aineo/claude/agents.lua`:
  - `LIST_BOUND_MS` 16 (5 s).
  - `list_sessions(command, folder, on_done)` 277 calls `on_done(sessions)` or `on_done(nil, problem)`, scheduled, and kills its run when Neovim quits.
  - `ListedSession` 12 carries `session_id`, `kind`, `status`, `running` and `cwd`. It does not keep `pid` or `startedAt`: add what O9 (a) needs, typed as the reader types fields (`typed_field()`).
- **The fake.**
  - `tests/helpers/fake_claude.lua` `answer_agents()` 274 records the `agents` run's argv in **the same record file** as Claude Code's run (`AINEO_FAKE_CLAUDE_RECORD`), and prints the array in the file `AINEO_FAKE_CLAUDE_AGENTS` names.
  - A mode prints `printed_lines` before its screens (841). Every chunk of input is recorded as `{ received }`, so a `\x0c` shows as `{"received":"\f"}` or `"\u000c"`.
  - Teach it an `Opening "<name>", running in the background (<8 hex>)` line, printed before the ready screen on a `--resume` of an id it is told runs in the background (an environment variable of your naming).
- **The harness consequence.** `tests/helpers/claude_session.lua` `wait_for_starts()` 811 counts every record entry with an `argv` as a start, and `wait_for_start()` 840 returns the first.
  - With behaviour 4, the list's run writes such an entry beside every resume, before or after Claude Code's.
  - Make a start an entry whose `argv` does not begin with `agents`. Give `tests/test_entry_sessions.lua` and `tests/test_claude_agents.lua`, which read the list's own argv, whatever accessor they need.
  - Measure the change on the suites that resume (`git grep -ln 'wait_for_start' tests`) before you rely on it.
- **What is not reproduced.** The fake has no background service and draws no fullscreen view. The test of behaviour 3 is the bytes the fake receives, and whether `Ctrl+L` brings the content on the real Claude Code is M11's. Quote M11's result, from the dispatch message, in your session note.

### Baseline

The suite's counts on the `dev` you start from are pasted by the dispatch message.

Read first:
- the v1 plan note's D23, D37, D38, D49, D54 and C3;
- `plan.md` in this folder;
- `evidence/w12-docs.txt`;
- `knowledge-vault/Projects/aineo.md`;
- the session notes of T19 and T46 in `knowledge-vault/Sessions/`.

## Boundary

- **Branch:** `bugfix/t48-background-resume` from `origin/dev`.
- **Class:** regular. It changes what a start does in `lua/aineo/claude/`, and runs a process; §3 of the orchestrate skill keeps both from a small fix.
- **Model:** `sonnet` — the orchestrator's instruction for this wave.
- **Resources:** `impl_t48_background_resume` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/claude/init.lua`: the start path and its docstrings — reading the line, the one redraw, and the list beside the start. A new file in `lua/aineo/claude/` for either, exported through `init.lua`, if it keeps `init.lua` thinner.
  - `lua/aineo/claude/agents.lua`: the fields and the predicate the warning needs.
  - `tests/helpers/fake_claude.lua`: the `Opening …` line and its docstring.
  - `tests/helpers/claude_session.lua`: what counts as a start.
  - A new `tests/test_claude_background_resume.lua`. `tests/test_entry_sessions.lua` and `tests/test_claude_agents.lua`, where a helper's change moves them.
  - `doc/aineo.txt`, three places:
    - the section from `*aineo-claude-session*` to the line before `*aineo-draft*`;
    - in section 11, the subsection *Stopping Claude Code on quit*. Add that it presses Ctrl-C into an attached background session. Add also that Claude Code shows its own `Background work is running` dialog on exit while background work runs, and that what aineo's stop does then is not measured.
    - the subsection *The session list*: `claude agents --json` now also runs beside each start that resumes.
  - Your session note.
  - Correct in the same commit what the change makes false there, and say in your report what you corrected.
- **You must not touch:**
  - The rest of `lua/aineo/claude/`: `stop.lua` (U2), `hook_relay.lua`, `readiness.lua`, `prompt.lua` and `session_ids.lua` are used as they are.
  - `plugin/aineo.lua`, `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/changes/`, `lua/aineo/report/`, `lua/aineo/draft/`, and the rest of `tests/helpers/`.
  - Every other section of `doc/aineo.txt`, and `tests/test_doc.lua` (run it).
  - The plan notes, the project note and the task list: write a `## Task lines` section in your session note.
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/<date> — T48 Background resume.md`, `<date>` the dispatch message's.
- **Scratch prefix:** `t48-`.
- **How the suite runs (D26, D29):** on Neovim 0.12.5.
  - While you work: the test files you touch, every test file that requires a helper you change, and `tests/test_doc.lua`.
  - Before each push: the whole suite (`make test`), once.
  - Mutants run on their covering files. The fake `claude` only.

## What was decided already

- **D54**, the user's, verbatim there:
  - "it must resume the session, if it is running in another claude-code session warn, if it is running in the background, resume";
  - and, on the quit, "Not yet; you check first".
  - No new session, no fork, no stop: the user rejected all three.
- The user's observation in the request: a `/resume` typed into Claude Code shows the background session's content. It is the fallback (i), by amendment, if M11 rules (ii) out.
- O6–O10 (a), the orchestrator's, recorded in the session note and the PR body as the orchestrator's assumptions, never as the user's decisions.
- U3 does not hold this packet: the quit is not touched whatever the answer, until a later wave.

## Budget

Small to medium:
- one line read off the new terminal;
- one byte written, once;
- one list beside the start, with its warning;
- the fake's line, and one helper's rule for what a start is;
- the help.

About eight cases. If it reaches further than `lua/aineo/claude/`, stop at a green, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t48-report-packet.md`. Open the pull request into `dev` before you report. Put in it:
- every verification claim a reviewer can re-measure;
- each test file whose pins moved, and why;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s five round-2 mutants: name the test that kills each.
