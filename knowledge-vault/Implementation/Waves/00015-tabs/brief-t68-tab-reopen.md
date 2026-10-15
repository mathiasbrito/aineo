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

## Amendment — 2026-10-15, at dispatch

The facts above, re-read on `origin/dev` `5b99ffc` (T65, T66, T67 and T69 merged). The amendment wins over the body. Nothing below is a spec conflict; each item says what moved or what the implementer reads differently, for the reviewers.

**What moved**

- `kept_or_new_session(settings)` is at `lua/aineo/claude/init.lua` 281, unchanged in behaviour. `aineo.claude.Settings` has no field that names a session to resume, and `new()` (T61) offers none.
- `open_unless_session_restored()` is at `plugin/aineo.lua` 2690 and `start_up()` at 2721. The first open runs `ACTIONS.open`, which is `acting_tab().actions.open()`; `acting_tab()` makes the first tab (`new_tab()`) when none exists. The autostart and `\o` and `:Aineo open` share that path.
- `keep_tabs()` and `kept_tabs()` are in `lua/aineo/tabs/init.lua` and nothing in `lua/` or `plugin/` outside `lua/aineo/tabs/` calls either: this packet is their first caller.
- `plugin/aineo.lua` is 2792 lines. A tab opens through `open_new_tab(start)` (T67), which makes a tab (`new_tab()`, whose first line is `finish_closing()`, A318) and a tab page, then calls `start(tab)`; a tab closed leaves `tab_list` in `release_tab()`, called from the `TabClosed` handler.
- `stopping` and `closing` (A319) hold the tabs whose Claude Code a closed tab still stops. At the editor's first open there are none, since no tab has closed yet; the reopening goes through `open_new_tab()` all the same.
- The quit: `aineo.claude` makes its `VimLeavePre` handler, the one that stops every Claude Code, at the first start, and `make_editor_handlers()` makes the editor's at the first entry write. Handlers run in the order they were made, so a handler that keeps the list before the stops is made when the first tab is made (`new_tab()`), before its start.

**Readings of the brief**

1. **The kept id is read through `aineo.claude`.** The decision whether a list "holds the kept id" needs the kept id, and the composition root may not reach `aineo.claude.session_ids` (a deep require). `lua/aineo/claude/init.lua` gets a read of it beside the one optional setting the brief allows; the boundary is widened by that one forward, declared in the pull request.
2. **The setting is `resume_session`**, a session id, validated for its form (it becomes an argument to `--resume`). It is the choice of `kept_or_new_session()` when set; `start_session()`'s docstring says so. A start on it keeps nothing for the folder: the kept id is the session the next start lands in, and stays what the last switch or new session made it (D23, D38).
3. **What the list holds** (item 1): the tabs of `tab_list` whose layout is in a tab page, in the order of their tab pages' places, each with the session its Claude Code follows (`aineo.entry.Tab`'s `session_id()`); a tab that has no session yet is left out, and a session two tabs show is listed once, at the lower place, since `kept_tabs()` refuses a repeated id. The place is that of the current aineo tab, or, when the current tab page is not aineo's, of the aineo tab used last (`last_used_tab`), else the first.
4. **When it is written.** A tab opens (`hold_tab()`), a tab closes (`release_tab()`), a tab's session changes (`follow_own_session()`, the hand-over of a dead session) and at `VimLeavePre`, from a handler made when the first tab is made so that it runs before the stops. Not at `TabEnter`: the place of the current tab is written with the next change and at the quit. While tabs reopen, nothing is written until the last has opened, so that a half-reopened list never replaces the one being restored.
5. **When it reopens (O20).** The first run of `ACTIONS.open` in an editor, whatever started it, uses the list; every later run reopens nothing. A session restored by a session plugin (`v:this_session`) consumes it too. It reopens only when no aineo tab exists yet, so a `\T` or `\S` before the first `\o` leaves that `\o` as it is today. The tabs reopen from `open_new_tab()`: the first in the current tab page, each next after the one before it; the current tab is the one at the list's place among the tabs reopened, not among the editor's tab pages.
6. **A failure** to start one tab raises the error of that start and leaves the tabs opened so far; the rest are not tried.
7. **The user's decision of 2026-10-15, taken in this packet: a tab's title is `<number>: <session name>`**, a colon after the number, in aineo's tab line and in `tab_title()`. Asked "What should change?" about today's `<n> <name>`, the user answered, verbatim: "<number>: <session name>". The orchestrator's assumptions (A321): the name stays the one aineo keeps (`b:aineo_session_name`, `Claude Code` until Claude Code names the session); the 24-cell cut applies to the name alone; a tab page that is not aineo's shows `<number>: <buffer tail>`. The plan's knowledge pass gives the decision its D-number. The boundary is widened (A322) to `lua/aineo/tabs/init.lua`'s `title()`, to `lua/aineo/init.lua`'s docstring of `tab_title()`, to the pins that read a title (`tests/test_entry_tabs.lua`, `tests/test_tabs.lua`) and to the help's *aineo-tabs* paragraph. The tab line's width math counts the title as a string, so it counts the colon with no change.
