**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md`, and `.claude/agents/neovim-lua-developer.md`, whose Neovim rules bind you too.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D67 as proposed, for the user's answers U1 (a) and U2 (a), and for the recommendations O19–O22 of `plan.md` in this folder. **It is dispatched in stage 4, once T67 has merged and the user has answered U2.** Before dispatch the orchestrator re-checks every fact below on the `dev` it dispatches on, and writes a dated amendment at the end of this brief for each fact that moved and for an answer other than (a) (A163). The amendment wins over the body.

## Objective

The task, verbatim from the task list:

> | T68 | The folder reopens its tabs (C3; D67, proposed; U2): the folder's ordered list of its tabs' sessions and the tab current at quit, kept as tabs open, close and switch and at quit (T65's file); the editor's first open restores the list as the user answers U2, each tab landing in its session, attached where it runs in the background; a list that is missing, unreadable or does not hold the kept id opens one tab on the kept id, as today; with the help | T67 | planned — wave 15 |

It rests on:
- **D67**, proposed.
- U1 and U2.
- The user's decision of 2026-10-14, made for one window, "when reopening I must land in the session to open on the window" (T48 part 2).
- D3, D23, D38, D45, D54, D62, D63.
- C3.
- C8, D10, D26, D29.

### The behaviour — one test each, seen failing first

**The list (O21)**

1. The folder's list (T65's `keep_tabs()`) is written:
   - whenever an aineo tab opens or closes;
   - whenever a tab's session changes: a switch, a hand-over (D45), a new session (D61);
   - at quit (`VimLeavePre`), before the stops.

   It holds the aineo tabs' sessions in the order of their places, and the place of the current one, or of the aineo tab used last when the current tab is not aineo's.
2. Under U1 (a), a tab closed with `\Q` or by Neovim's commands is no longer in the list, while `:qa` keeps every tab. The kept id's file is written as today (D23, D38).

**Reopening (U2 (a), O20)**

3. At the editor's first open (the autostart or the first `\o`), a list read back (`kept_tabs()`) that holds the kept id reopens every tab in its order:
   - the first in the current tab page, the others in new tab pages after it;
   - each tab's Claude Code on its own session, landing in it, as a start lands in the kept id today: resumed; attached where it runs in Claude Code's background service with a short id (T48 part 2); resumed with the warning where another interactive Claude Code has it open;
   - every tab's Claude Code starts at once.

   The tab at the list's current place is current at the end.
4. A list that is missing, unreadable, or does not hold the kept id opens one tab on the kept id, as today, and every entry suite of today passes unchanged.
5. A session of the list that Claude Code finds no conversation for is replaced in its tab by a new session on a new id, and the dead one's draft, Report and changes base are handed over, as T19 and D45 do today for the one tab.
6. A Neovim started on a session restored by a session plugin (`v:this_session`) reopens no tab, as D3 opens nothing then. A later `\o` reopens nothing either: the reopening is the editor's first open's alone.
7. Each tab's start lists the folder's sessions as a resuming start does today (O22 (a)). A list that fails resumes as today.

**The help**

8. *aineo-tabs* says what the folder keeps and what reopening does, and that a closed tab does not reopen. *aineo-claude-session*'s paragraph on the kept session says how the list and the kept id relate. LIMITS › `Several tabs ~` says that two Neovims in one folder write one list and the last to write wins, and that N tabs run N lists at a reopening. Run `tests/test_doc.lua`.

### Facts to re-check at dispatch

Read at `bugfix/t48-attach` `e0989f2`, before stages 1–3.
- `lua/aineo/claude/init.lua`'s `kept_or_new_session(settings)` (210) gives the kept id, resumed, or a new id with `settings.new_session`. A start of a tab on a given session needs that session's id as its choice. Add one optional setting to `aineo.claude.Settings`, validated as the others are, if T61's copy offers none, and say in `start_session()`'s docstring what it changes.
- `plugin/aineo.lua`'s `start_up()` (1822) and `open_unless_session_restored()` (1791) make the first open. T66 makes the first tab there.
- T65's `keep_tabs()` and `kept_tabs()` write and read the list under `<state>/aineo/claude-tabs/`, and check every id's form.
- P6: each resuming start runs `claude agents --json`, bounded at 5 s.

Evidence: `evidence/w15-probes.txt` › P6.

**Unmeasured.** No suite runs the real Claude Code (D10). A reopening with a session attached in the background is the user's check M3 (`plan.md` › *Checks for the user*).

### Baseline

The dispatch message pastes the whole suite's counts on the `dev` you start from.

Read first:
- `plan.md` in this folder (U1, U2, O19–O22);
- the session notes of T65, T66 and T67, and of T48 parts 1 and 2;
- the v1 plan note's D23, D38, D45, D54, D62 and **D67**;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t68-tab-reopen` from `origin/dev`.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t68_tab_reopen`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `plugin/aineo.lua`;
  - `lua/aineo/claude/init.lua`, for the start on a given session alone;
  - `lua/aineo/tabs/`, where its list needs a fix;
  - a new `tests/test_entry_tab_reopen.lua`, `tests/test_claude_resume.lua` for the start on a given session, `tests/test_tabs.lua`, and the entry suites where a pin moves;
  - `tests/helpers/`, **additions only**;
  - `doc/aineo.txt`: *aineo-tabs*, *aineo-claude-session*, LIMITS › `Several tabs ~`;
  - your session note.
- **You must not touch:**
  - every other home;
  - the kept id's file and its form (`lua/aineo/claude/session_ids.lua`);
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/<date> — T68 Tab reopen.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t68-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run the test files you touch, plus `tests/test_entry_startup.lua`, `tests/test_entry_claude_resume.lua`, `tests/test_claude_attach.lua`, `tests/test_entry_tabs*.lua` and `tests/test_doc.lua`.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on their covering files.
  - Never run the real `claude`.

## What was decided already

- **The user's decision of 2026-10-14**, for one window: "when reopening I must land in the session to open on the window".
- **The user's answers U1 and U2**, pasted by the dispatch message. This brief is written for (a) and (a).
- **The rest is the orchestrator's** (O19–O22): when the reopening runs, where the list lives, the fallback to the kept id, and one list run per tab. Record them in the session note and the pull request as such.
- **Rejected:** the list inside the kept id's file (O21 (b)); one shared list run (O22 (b)).

## Budget

Medium: the list kept at each change and the first open restoring it, with about twelve new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

Write it in your definition's shape, to `<scratchpad>/t68-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s T68 mutants. Name the test that kills each.

## The orchestrator's rulings — 2026-10-14, before dispatch

`plan.md` › *The user's answers* (U1–U3, the user's decisions) and *The orchestrator's rulings* (O1–O22 → A234–A255, each its (a)) bind this brief, which is written for them. Record A234–A255 as the orchestrator's assumptions, never as the user's decisions.
