**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> Written 2026-10-12 for wave 12's round 3 (`plan.md` › *Round 3*): the user's M11, the orchestrator's re-scope A164, and its rulings A165 and A166.
>
> Any fact below that moved on the `dev` you start from is a dated amendment at the end, and it wins over the body.
>
> **Never run the real `claude`**, and never touch Claude Code's background service: the suites run the fake.

## Objective

The task, verbatim from the task list:

> | T48 | When the session kept for the folder is open in another interactive Claude Code, the start tells the user and resumes it all the same (C3; D23, D38, D54): `claude agents --json`, run beside a start that resumes and never before it, lists the kept id as `interactive` with a `pid` that is not aineo's own Claude Code (A165); one warning of at most 60 characters (A166). A session running in the background service is resumed as today (A164) | T46 | planned — wave 12 |

It rests on:
- **D54**, with the user's answers quoted in it, verbatim. aineo always resumes the kept session; it warns when that session is open in another interactive Claude Code; it resumes a background one; the quit is not changed.
- D23 and D38 (the kept id, resumed at each start).
- D49 and T46's reader (`claude agents --json`).
- C3, D13 (`claude.cmd`), D26, D29.
- A164–A166, the orchestrator's (below).

Design and evidence: `plan.md` in this folder (*The user's answers — round 1*, *Round 3*), and `evidence/w12-docs.txt` D5.

### The behaviour — one test each, seen failing first

1. **The start resumes as today.** It passes `--resume <kept id>` when an id is kept, `--session-id` otherwise. Nothing in this packet replaces, forks, stops, delays or redraws it, whether the kept session runs in another terminal or in the background service (A164).
2. **The list runs beside the start.**
   - After a start that resumed has launched Claude Code — never before — aineo lists the folder's sessions through T46's reader: `list_sessions()`, which runs `claude.cmd` followed by `agents --json --cwd <folder> --all`, `<folder>` being the start's `settings.cwd`.
   - A start that did not resume runs no list. Neither does the new session that takes the place of a resume with no conversation (`start_new_session_in_place()`).
3. **What warns** (A165). The list warns when it holds an entry that has all of these:
   - its session id is the kept id;
   - its `kind` is `interactive`;
   - it has a `pid`;
   - it is not aineo's own Claude Code. aineo's own is the entry whose `pid` is the terminal job's (`jobpid()`), or whose `startedAt` is at or after this start's launch, in milliseconds since the epoch, since a `claude.cmd` that wraps `claude` gives another pid.

   A `background` entry never warns.
4. **The warning** (A166). One warning of at most 60 characters, for example `aineo: this session is also open in another Claude Code` (55). It is told once per start, and not at all once the start's session has exited, another start has taken its place, or Neovim is quitting.
5. **Nothing else changes.**
   - A list that cannot run, fails, times out, prints too much or is not JSON tells nothing.
   - D38's kept id, the hooks, the panes and the quit (U2) are as they were.
6. **The help** says:
   - that a start resuming a session open in another interactive Claude Code warns and resumes it all the same;
   - that `claude agents --json` now also runs beside each start that resumes (*The session list*);
   - in *Stopping Claude Code on quit*, two facts. When the session in aineo's window is one attached from Claude Code's background service, the quit's Ctrl-C interrupts a turn in progress there (`evidence/w12-docs.txt` D2). And Claude Code shows its own `Background work is running` dialog on exit while background work runs (D3), and what aineo's stop does then is not measured.

### Facts, checked against `origin/dev` `1dc3186`

- `lua/aineo/claude/init.lua`:
  - `start_session()` 560 starts on `kept_or_new_session()` 196, through `start_in_place` (assigned at 467) and `launch()` 293, which runs `jobstart(…, { term = true })` and keeps the job in `launched.job`.
  - `start_new_session_in_place()` 427 is T19's replacement.
  - `SETTINGS_UNREAD_WARNING` 254 is the 60-character rule.
  - `session_id()` 780, `list_sessions()` 806.
- `lua/aineo/claude/agents.lua`:
  - `LIST_BOUND_MS` 16 (5 s).
  - `list_sessions(command, folder, on_done)` 277 calls `on_done(sessions)` or `on_done(nil, problem)`, scheduled, and kills its run when Neovim quits.
  - `ListedSession` 12 carries `session_id`, `name`, `kind`, `status`, `running` and `cwd`, but not `pid` or `startedAt`. Add those two, typed as the reader types fields (`typed_field()` 35): `pid` and `startedAt` are numbers in Claude Code's JSON (`evidence/w12-docs.txt` D5).
  - `standing()` 89 is `\S`'s pick rule, not this packet's.
- **The fake.** `tests/helpers/fake_claude.lua` `answer_agents()` 274 records the `agents` run's argv in **the same record file** as Claude Code's run (`AINEO_FAKE_CLAUDE_RECORD`), and prints the array in the file `AINEO_FAKE_CLAUDE_AGENTS` names (`[]` when unset). Its record gives Claude Code's own `pid` (first line). That is the `pid` a test writes into the listing to stand for aineo's own entry, when `claude.cmd` is the fake itself.
- **The harness consequence.** `tests/helpers/claude_session.lua` `wait_for_starts()` 811 counts every record entry with an `argv` as a start, and `wait_for_start()` 840 returns the first.
  - With behaviour 2, the list's run writes such an entry beside every resume, before or after Claude Code's.
  - Make a start an entry whose `argv` does not begin with `agents`. Give `tests/test_entry_sessions.lua` and `tests/test_claude_agents.lua`, which read the list's own argv, whatever accessor they need.
  - Measure the change on the suites that resume (`git grep -ln 'wait_for_start' tests`) before you rely on it.
- **Two interactive processes on one session.** The real shape is not measured: it is the user's M14, which does not hold this packet. A165 is written for both shapes the fake can give: another `pid`, or aineo's own.

### Baseline

The suite's counts on the `dev` you start from are pasted by the dispatch message.

Read first:
- the v1 plan note's D23, D38, D49, D54 and C3;
- `plan.md` in this folder;
- `knowledge-vault/Projects/aineo.md`;
- the session note of T46 in `knowledge-vault/Sessions/`.

## Boundary

- **Branch:** `bugfix/t48-background-resume` from `origin/dev`.
- **Class:** regular. It adds a process run to the start in `lua/aineo/claude/`, which §3 of the orchestrate skill keeps from a small fix.
- **Model:** `sonnet` — the orchestrator's instruction for this wave.
- **Resources:** `impl_t48_background_resume` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/claude/init.lua`: the start path, the list beside it, the warning, and their docstrings. A new file in `lua/aineo/claude/` for the rule, exported through `init.lua`, if it keeps `init.lua` thinner.
  - `lua/aineo/claude/agents.lua`: `pid`, `startedAt` and A165's predicate.
  - `tests/helpers/claude_session.lua`: what counts as a start.
  - A new `tests/test_claude_resume_elsewhere.lua`. `tests/test_entry_sessions.lua` and `tests/test_claude_agents.lua`, where the helper's change moves them.
  - `doc/aineo.txt`, three places: the section from `*aineo-claude-session*` to the line before `*aineo-draft*`; and, in section 11, the subsections *Stopping Claude Code on quit* and *The session list*.
  - Your session note.
  - Correct in the same commit what the change makes false there, and say in your report what you corrected.
- **You must not touch:**
  - The rest of `lua/aineo/claude/`: `stop.lua` (U2), `hook_relay.lua`, `readiness.lua`, `prompt.lua` and `session_ids.lua` are used as they are.
  - `plugin/aineo.lua`, `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/changes/`, `lua/aineo/report/`, `lua/aineo/draft/`.
  - `tests/helpers/fake_claude.lua`, which already gives what the tests need, and the rest of `tests/helpers/`.
  - Every other section of `doc/aineo.txt`, and `tests/test_doc.lua` (run it).
  - The plan notes, the project note and the task list: write a `## Task lines` section in your session note.
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/<date> — T48 Resume elsewhere.md`, `<date>` the dispatch message's.
- **Scratch prefix:** `t48-`.
- **How the suite runs (D26, D29):** on Neovim 0.12.5.
  - While you work: the test files you touch, every test file that requires a helper you change, and `tests/test_doc.lua`.
  - Before each push: the whole suite (`make test`), once.
  - Mutants run on their covering files. The fake `claude` only.

## What was decided already

- **D54**, the user's, verbatim there: "it must resume the session, if it is running in another claude-code session warn, if it is running in the background, resume". And on the quit: "Not yet; you check first". No new session, no fork, no stop.
- **M11**, the user's: "I hit <- did qa!, reopened nvim and it resumed the session". A background session is resumed as today, with nothing added.
- **A164–A166**, the orchestrator's assumptions (`plan.md` › *Round 3*). Record them in the session note and the PR body as such, never as the user's decisions.
- The display fault of the request is an open thread with the check M15. It is not this packet's.

## Budget

Small: one list beside the start, one predicate with two new fields, one warning, one helper's rule for what a start is, and the help — about six cases. If it reaches further than `lua/aineo/claude/`, stop at a green, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t48-report-packet.md`. Open the pull request into `dev` before you report. Put in it:
- every verification claim a reviewer can re-measure;
- each test file whose pins moved, and why;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s five round-3 mutants: name the test that kills each.
