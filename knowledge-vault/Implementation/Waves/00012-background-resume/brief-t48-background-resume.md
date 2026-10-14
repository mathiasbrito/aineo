**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one part** of one packet of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what. **The dispatch message names the part, 1 or 2.** Do that part only.

> Written 2026-10-12 for wave 12's round 4 (`plan.md` › *Round 4*): the user's reproduction, and the user's answer "Ask at start". Rounds 1–3 of this brief were never dispatched.
>
> The orchestrator's rulings of O11–O17 are pasted by the dispatch message. A ruling other than (a) is a dated amendment at the end, and it wins over the body. So does any fact below that moved on the `dev` you start from.
>
> **Never run the real `claude`**, and never touch Claude Code's background service: the suites run the fake.

## Objective

The task, verbatim from the task list:

> | T48 | When the session kept for the folder runs elsewhere, the start knows it before Claude Code launches (C3; D23, D38, D54): `claude agents --json` (T46's reader) runs before a start that would resume, bounded at 5 s, and a failed or slow list resumes as today. A session open in another interactive Claude Code is warned of and resumed (A166). A session running in the background service is asked about at start: attach to it (`claude attach`, its quit detaching with Ctrl+Z), or start a new session. The attach half waits for the user's check M16 | T46 | planned — wave 12 |

It rests on:
- **D54**, with the user's answers quoted in it, verbatim. aineo resumes the kept session. It warns when that session is open in another interactive Claude Code. When the session runs in the background service, it asks: "A one-line choice at start: attach to the running session, or start a new one." The quit of aineo's own session is not changed (U2). The quit of an attached terminal changes only after the user's check of `Ctrl+Z` (U3), which is M16.
- D23 and D38 (the kept id, resumed at each start), D51, D49's R3.
- T46's reader (`claude agents --json`).
- C3, D13 (`claude.cmd`), D26, D29.
- O11–O17, the orchestrator's rulings, pasted by the dispatch message.

Design and evidence: `plan.md` in this folder (*Round 4* › *The design*), and `evidence/w12-docs.txt` D1, D2, D4, D5.

## Part 1 — the list before the start, and the warning

One test each, seen failing first.

1. **A start that would resume lists first.**
   - When an id is kept for `settings.cwd`, `start_session()` lists the folder's sessions with `agents.list_sessions(settings.cmd, settings.cwd, on_done)`. Claude Code launches only from `on_done`.
   - A start on a new id lists nothing and launches at once, as today. So does the new session that takes the place of a resume with no conversation (`start_new_session_in_place()`).
2. **`start_session()` still returns at once.**
   - It makes the terminal buffer, keeps it as the one session's, replaces the last terminal in its windows (`replace_terminal()`), and returns it, before the list answers.
   - Claude Code is later launched **in that same buffer**: `launch()` takes the buffer it is given.
   - Every error `start_session()` raises today it still raises before the list runs, leaving the session as it was. That covers the settings, `claude.cmd`'s executable, and the command built for the resume.
3. **While the start waits for the list:**
   - `session_status()` is `'starting'`;
   - a second `start_session()` returns the same buffer and starts nothing;
   - `write_to_session()` raises, as when no session runs;
   - the quit presses nothing, since there is no job (the reader kills its own run when Neovim quits);
   - `session_id()` is the kept id.
4. **When the list answers,** nothing is launched if any of these holds:
   - the buffer was wiped;
   - another start has taken this one's place;
   - Neovim is quitting (`v:exiting`).

   Otherwise Claude Code launches with `--resume <kept id>`, exactly as today: the same arguments, hooks, start token and warnings (`SETTINGS_UNREAD_WARNING`). `on_session_ready`, `on_session_switched` and the panes behave as for today's start, as seen from the moment of the launch.
5. **The warning** (O16, A166). An entry is another interactive Claude Code on the session when:
   - its session id is the kept id;
   - its `kind` is `interactive`;
   - it has a `pid`.

   Such an entry is told as one warning of at most 60 characters, for example `aineo: this session is also open in another Claude Code` (55), and the start resumes. It is told once per start. A `background` entry never warns.
6. **A list that cannot run, fails, times out, prints too much or is not JSON** resumes as today, and tells nothing.
7. **In part 1, a running background entry of the kept id resumes as today.** Part 2 changes that.
8. **The reader keeps two more fields** on `ListedSession`, typed as `typed_field()` types the others:
   - `pid`, a number;
   - `id`, Claude Code's short id, a string (`evidence/w12-docs.txt` D5).

   Name the short id's field so that it cannot be confused with `session_id`.
9. **The help** (`doc/aineo.txt`):
   - In *aineo-claude-session*: a start that would resume first asks Claude Code where the session runs, and Claude's window stays empty until it answers, for up to 5 s. A session open in another interactive Claude Code is warned of, then resumed.
   - In section 11, *The session list*: `claude agents --json` now also runs before each start that resumes, and what a failed list does then.

## Part 2 — the question, attach and new *(held for M16)*

Dispatched only once the user's M16 is in. The dispatch message pastes its answers. Start from `origin/dev` with part 1 merged. One test each, seen failing first.

1. **The question** (O12). It is asked when the list holds an entry of the kept id whose `kind` is `background`, which has a `pid` or a `status`, and which has a short `id`. aineo asks with `vim.ui.select`:
   - prompt `This folder's session runs in the background`;
   - the items `Attach to it` and `Start a new session`, in that order.

   A `nil` answer (Esc, an empty answer) starts a new session. A running background entry without a short `id` is not asked about and resumes as today. When both kinds are listed, the background entry is asked about and no warning is told. Nothing is launched from an answer given once the buffer was wiped, another start has taken its place, or Neovim is quitting.
2. **Attach** (O17).
   - The command is `claude.cmd` followed by `attach <short id>`: no `--settings`, no `--mcp-config`, no `--append-system-prompt`, no `--allowedTools`, no `--resume`, no start token.
   - The start's choice records that it attached. `session_id()` stays the kept id, and **the kept file is not written** (D23, D38, D51).
   - `found_no_conversation()` does not apply to an attached start.
   - aineo tells one line of at most 60 characters at the attach, for example `aineo: attached to a background session (no Report)` (51). Claude's status line reads `<name> (attached) — <folder>` while it runs (O14).
3. **The stop of an attached terminal** (O15). aineo's quit presses `Ctrl+Z` (`\26`) and **never Ctrl-C**. It waits the time the dispatch message gives from M16 step 4, and only then hangs up and waits, as `stop_by_keys()` does after its keys. The stop of aineo's own session is unchanged (U2).
4. **New.**
   - A new session on a new id (`--session-id`), launched in the same buffer, and kept for the folder (D23).
   - One line of at most 60 characters, for example `aineo: started a new session; the background one runs on` (56).
   - The background session is not touched, attached, stopped or forked.
   - This start counts as a new session, as a start with no kept id does. It is not `on_session_switched`'s `startup` replacement: `on_terminal_replaced` is not called.
5. **The help:**
   - *aineo-claude-session*: the question, what each answer does, and what an attached terminal lacks (session hooks, the Report, aineo's allowed tools).
   - *Stopping Claude Code on quit*: an attached terminal is detached with `Ctrl+Z`, which leaves the background session running.
   - Part 1's sentence "a running background session resumes as today" is replaced.

## Facts, checked against `origin/dev` `0fa0116`

- `lua/aineo/claude/init.lua`:
  - `is_process_alive()` 56 and `is_running()` 64; `stop_on_quit()` 73 calls `stop.stop_by_keys(session.job, …)`.
  - `kept_or_new_session()` 196, `session_arguments()` 209, `keep_session_id()` 218, `found_no_conversation()` 236, `SETTINGS_UNREAD_WARNING` 254 (the 60-character rule).
  - `launch()` 293 makes the buffer itself (`nvim_create_buf(false, true)`). It starts `readiness.watch()` and runs `jobstart(…, { term = true })` through `run_in_terminal()` 161 under `nvim_buf_call()`, keeping the job in `launched.job`.
  - `start_new_session_in_place()` 427, `start_in_place` 467, `start_session()` 560, `session_status()` 584, `write_to_session()` 896 (the only other user of `session.job`).
- **Neovim 0.12's `jobstart(…, { term = true })` needs an unmodified current buffer.** Leave the waiting buffer empty, and run the job under `nvim_buf_call()` as today.
- `lua/aineo/claude/agents.lua`: `ListedSession` 12, `LIST_BOUND_MS` 16, `typed_field()` 35, `listed_session()` 48 (`running` is a `pid` or a `status`), `list_sessions()` 277. `list_sessions()` calls `on_done` scheduled, and kills its run when Neovim quits.
- `lua/aineo/claude/stop.lua`: `CTRL_C` 9, `KEY_PRESSES` 24, `stop_by_keys()` 71, the hang-up and `EXIT_AFTER_HANGUP_MS` after it.
- **Session hooks:** `take_session_event()` (init.lua, about 692) drops a hook whose start token is not the running start's. A background session started by an earlier aineo start carries that start's hooks (D4), and its hooks are dropped.
- **The fake** (`tests/helpers/fake_claude.lua`):
  - `answer_agents()` 274 records the `agents` run's argv in the same record file as Claude Code's run, and prints the array `AINEO_FAKE_CLAUDE_AGENTS` names (`[]` when unset). It exits with `AINEO_FAKE_CLAUDE_AGENTS_EXIT`, printing nothing, when that is set.
  - Its record gives Claude Code's own `pid` (first line).
  - Given `attach`, it does not know the word. Part 2 may teach it: record the argv, draw the ready screen, and exit 0 on `\26`.
- **The harness** (`tests/helpers/claude_session.lua`): `wait_for_starts()` 811 counts every record entry with an `argv` as a start, and `wait_for_start()` 840 returns the first. With part 1, the list's run writes such an entry **before** every resume.
  - Make a start an entry whose `argv` does not begin with `agents`.
  - Give `tests/test_entry_sessions.lua` and `tests/test_claude_agents.lua`, which read the list's own argv, the accessor they need.
  - Measure the change on the suites that resume (`git grep -ln 'wait_for_start' tests`, 17 files) before you rely on it.
  - A suite that reads the terminal job or writes to it straight after `start_session()` on a kept id now meets a waiting start. Find these suites by measuring, and wait for `'starting'` to become a launch rather than changing what they assert.

### Baseline

The suite's counts on the `dev` you start from are pasted by the dispatch message.

Read first:
- the v1 plan note's D23, D38, D49, D51, D54 and C3;
- `plan.md` in this folder, *Round 4*;
- `knowledge-vault/Projects/aineo.md`;
- the session note of T46 in `knowledge-vault/Sessions/`.

## Boundary

- **Branch:** part 1 `bugfix/t48-background-resume`, part 2 `bugfix/t48-attach`, each from `origin/dev`.
- **Class:** regular. It changes when a start launches Claude Code, in `lua/aineo/claude/`, which §3 of the orchestrate skill keeps from a small fix.
- **Model:** `sonnet` — the orchestrator's instruction for this wave.
- **Resources:** part 1 `impl_t48_background_resume`, part 2 `impl_t48_attach` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch, in part 1:**
  - `lua/aineo/claude/init.lua`: the start path, the list before it, the warning, and their docstrings. A new file in `lua/aineo/claude/` for the rule over the listed entries, required by `init.lua`, if that keeps `init.lua` thinner.
  - `lua/aineo/claude/agents.lua`: `pid` and the short id.
  - `tests/helpers/claude_session.lua`: what counts as a start, and a wait for a waiting start's launch.
  - A new `tests/test_claude_resume_elsewhere.lua`, and the suites the waiting start or the helper's change moves. Name each in your report, with why.
  - `doc/aineo.txt`, two places: the section from `*aineo-claude-session*` to the line before `*aineo-draft*`, and *The session list* in section 11.
- **In part 2, also:**
  - `lua/aineo/claude/stop.lua`: the detach beside `stop_by_keys()`, which stays as it is.
  - `lua/aineo/claude/session_name.lua`: the `(attached)` mark.
  - `lua/aineo/claude/arguments.lua`, only if the attach command is built there.
  - `tests/helpers/fake_claude.lua`: `attach`.
  - `doc/aineo.txt`: *Stopping Claude Code on quit* in section 11.
- **Both parts:**
  - Your session note.
  - Correct in the same commit what the change makes false in the places you may touch, and say in your report what you corrected.
- **You must not touch:**
  - The rest of `lua/aineo/claude/`: `hook_relay.lua`, `readiness.lua`, `prompt.lua` and `session_ids.lua` are used as they are. `stop.lua` is also used as it is in part 1.
  - `plugin/aineo.lua`, `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/changes/`, `lua/aineo/report/`, `lua/aineo/draft/`, `lua/aineo/layout/`.
  - The rest of `tests/helpers/`.
  - Every other section of `doc/aineo.txt`, and `tests/test_doc.lua` (run it).
  - The plan notes, the project note and the task list: write a `## Task lines` section in your session note.
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Session note:**
  - part 1: `knowledge-vault/Sessions/<date> — T48 Resume elsewhere.md`;
  - part 2: `knowledge-vault/Sessions/<date> — T48 Attach.md`;
  - `<date>` is the dispatch message's.
- **Scratch prefix:** `t48-`.
- **How the suite runs (D26, D29):** on Neovim 0.12.5.
  - While you work: the test files you touch, every test file that requires a helper you change, and `tests/test_doc.lua`.
  - Before each push: the whole suite (`make test`), once. The start path runs in most entry suites.
  - Mutants run on their covering files. The fake `claude` only.

## What was decided already

- **D54**, the user's, verbatim there.
  - U1: "it must resume the session, if it is running in another claude-code session warn". Its background half is replaced by the user's later answer, "Ask at start" ("A one-line choice at start: attach to the running session, or start a new one.").
  - U2 on the quit: "Not yet; you check first".
  - U3 on an attached terminal's quit: "Leave it; you check Ctrl+Z" — M16 is that check.
- A164–A166 were the orchestrator's assumptions of round 3. A166's warning stands. The round-4 answer replaces A164's "a background session is resumed as today". O16 replaces A165.
- **O11–O17** are the orchestrator's rulings, never the user's decisions. Record them as such in the session note and the PR body.
- The rename the user asked about is not the cause (`plan.md` › *Did the rename cause it?*): aineo resumes by id.

## Budget

- **Part 1:** one waiting start, one list before it, one rule, one warning, two reader fields, one helper rule, and the help — about eight cases.
- **Part 2:** the question, two commands, one detach, one mark, the help — about six cases.

If either part reaches outside the files it may touch, stop at a green, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t48-report-part<N>.md`. Open the pull request into `dev` before you report. Put in it:
- every verification claim a reviewer can re-measure;
- each test file whose pins moved, and why;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s round-4 mutants for your part: 1–3 for part 1, 4–5 for part 2. Name the test that kills each.

## The orchestrator's rulings — 2026-10-12, before dispatch (round 4)

`plan.md` › *The orchestrator's rulings — round 4* rules O11–O17 as their (a), which this brief is written for: A185–A191. They are the orchestrator's assumptions, to record in the session note and the PR body as such, never as the user's decisions. Part 1 is dispatched now; part 2 waits for the user's M16.

## Amendment — 2026-10-14, at dispatch: M16 measured, the user's decisions

Part 2 is dispatched on `dev` `1354cad`, with part 1 merged (PR #189) and T55–T58 on `dev`. This amendment wins over the body above, and **A223** (the orchestrator's assumption) is that it is a faithful reading of what follows. Part 2's branch is `bugfix/t48-attach`.

**M16, the user's check, as reported** (names and ids left out; step 2's time was not reported, so the 5 s bound stays):
- Step 3: `claude attach <id>` in a Neovim 0.12.5 terminal shows the conversation.
- Step 4: after `Ctrl+Z` the terminal ends with `[Process exited 0]`.
- Step 5: the session is still running, with the same `pid`.
- Step 6: a `:bwipe!` of the attached terminal also leaves it running, and a new attach brings it back.
- Step 7: `claude agents --json` prints its output and exits.

**The user's decision (2026-10-14):** "when reopening I must land in the session to open on the window." The next start lands in the session that was on Claude's window when Neovim quit, an attached background session included. So after an attach **the kept id for the folder becomes the attached session's**. This replaces item 2's "the kept file is not written", and round 4's "the kept id stays the background session's" (A189's part): the kept id follows the window.

**The user's decision (2026-10-14):** "Attach straight away", when the session runs in the background. `\N` gives a new session. So there is **no question at start**: item 1 (the `vim.ui.select` question, A186) and item 4 (the answer *Start a new session*) fall, as do their cases. This supersedes "Ask at start".

**Part 2, as dispatched:**
- At a start that would resume, when the list holds an entry of the kept id with `kind` `background`, a `pid` or a `status`, and a short `id` (A191), the terminal's command is `claude.cmd` followed by `attach <short id>`, with none of aineo's flags. A background entry without a short `id` resumes as today.
- When both kinds are listed, the background entry attaches and no warning is told.
- aineo tells one note of at most 60 characters at the attach, and says what the attached terminal lacks (session hooks, the Report server, aineo's instructions and allowed tools). Claude's status line reads `<name> (attached) — <folder>` while it runs (A188).
- The stop and the quit of an attached terminal press `Ctrl+Z` and never Ctrl-C, then hang up as today (A189). M16 shows both leave the session running.
- When the kept session is no longer running, the start resumes as today.
- The "Start a new session" of the body is `\N`'s existing new session (T58, `new_session()`), unchanged.

**Facts that moved on `dev` `1354cad`** (the body's *Facts* were written against `0fa0116`):
- `launch()` no longer makes the buffer: `prepare_start()` makes it, named `aineo://claude/<start token>`, and `launch(prepared, on_exit)` runs the job in it. The list's answer is handled in `launch_once_listed()`, where the attach is decided. `start_session()` is at line 766 of `lua/aineo/claude/init.lua`, `stop_on_quit()` at 78, `found_no_conversation()` at 242.
- The reader's field for Claude Code's short id is `short_id` (not `id`); `agents.is_open_in_another_claude_code()` is the warning's rule. `lua/aineo/claude/window_options.lua` exists (part 1).
- `tests/helpers/claude_session.lua`: `wait_for_starts()` counts the fake's runs that are not `agents` runs; `wait_for_launch()` and `list_gate()` exist. A fake started as `attach <id>` is a start of the fake, and counts.
- T58's `\N` (`new_session()` in `plugin/aineo.lua`) starts a new session on a new id where Claude Code runs no session, and writes `/clear` at the empty prompt where it runs and is ready. It is the user's way to a new session; part 2 does not touch it (see the report for what it does in an attached terminal).

## Amendment — 2026-10-14, after dispatch: `\S` attaches to running sessions too

The user's decision, verbatim, after the orchestrator offered it (R3 of 2026-10-11 refused a pick of a session running elsewhere): "yes, make \S attach to running sessions too". It is D62 in the plan note, and it adds to part 2, in the same pull request and after part 2's own units. **A224** (the orchestrator's assumption) is that the details below are the orchestrator's, not the user's.
- A pick of a row marked `[running elsewhere]` replaces Claude's window's Claude Code with one on that session, through part 2's attach launch. The prompt check of D49 runs first and refuses with the same words; the Claude Code that ran is stopped as quitting Neovim stops it, by `Ctrl+Z` when it is attached itself; the kept id follows the window; a pick of this terminal's row still does nothing.
- Widened boundary: `plugin/aineo.lua` (the pick path of `\S`), `tests/test_entry_sessions.lua`, `doc/aineo.txt` (`:Aineo-sessions`, the new-session limit) and the plan note (dated notes on D49 and D51, and D62).
- **Spec conflict, reported and not chosen by the brief:** a session open in another interactive Claude Code has no short id (`claude agents --json` gives `id` to background sessions only), so `claude attach` cannot take it. The pick resumes it (`--resume`) in the window and warns (A166) instead; a background session without a short id stays refused.
