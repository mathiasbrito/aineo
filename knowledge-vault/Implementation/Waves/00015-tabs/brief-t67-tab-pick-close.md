**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md`, and `.claude/agents/neovim-lua-developer.md`, whose Neovim rules bind you too.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D65 and D66 as proposed, for the user's answer U1 (a), and for the recommendations O17–O19 of `plan.md` in this folder. **It is dispatched in stage 3, once T66 has merged and the user has answered U1.** Before dispatch the orchestrator re-checks every fact below on the `dev` it dispatches on, and writes a dated amendment at the end of this brief for each fact that moved and for an answer other than U1 (a) (A163). The amendment wins over the body.

## Objective

The task, verbatim from the task list:

> | T67 | `\S` in a new tab, and closing a tab (C1, C3; D65, D66, proposed; U1): a pick of a session a tab shows moves to that tab, any other pick opens a new tab on it — resumed, attached, or resumed with the warning — and the list marks the sessions this editor's tabs show; `:Aineo tab close`, `\Q` and `<C-\>Q` close the current tab as the user answers U1; with the health check and the help | T66 | planned — wave 15 |

It rests on:
- **D65**: the user's decision "\S loads in a new tab", and the proposed parts.
- **D66**: the user's decision of a way to close a tab, "the effect would be the same of a qa! we have now, but feel free to propose a different behavior", with U1 and the proposed parts.
- D49, D51, D53, D54, D62 (T48 part 2's join), D63.
- C1, C3, C7.
- C8, D10, D26, D29.

### The behaviour — one test each, seen failing first

**`\S` (D65)**

1. The list's rows mark each session a tab of this editor shows `[tab <n>]`, in place of `[this terminal]` and `[running elsewhere]`. A session another process runs keeps `[running elsewhere]`. Make the mark in `aineo.claude`'s rows (`agents.lua`).
2. A pick of a session a tab of this editor shows moves to that tab, the current tab's own included, and starts nothing.
3. A pick of a session no tab shows, of the folder, opens a new tab after the current one (T66's new tab), whose Claude Code:
   - resumes it (`--resume`) when no process runs it;
   - attaches to it (`claude.cmd attach <short id>`) when it runs in Claude Code's background service with a short id, as T48 part 2 attaches;
   - resumes it with the warning when it is open in another interactive Claude Code (D62's ways).

   The cursor ends in the new tab's Claude window in Terminal mode.
4. Nothing is written into the current tab's prompt, and the current tab's Claude Code goes on as it was. A pick made while the current tab's prompt holds text opens the tab all the same (D49's prompt check no longer applies to a pick).
5. These are refused as today, with today's words, and open no tab:
   - a session of another folder (`[another folder]`);
   - a background session without a short id;
   - a list that fails or is still being read.
6. The new tab's session is the one its tab follows and keeps for the folder (D51, D38), as every start keeps its id.

**Closing a tab (D66, U1 (a))**

7. `:Aineo tab close`, `<Plug>(aineo-tab-close)`, `\Q`, and `<C-\>Q` in Terminal and Insert mode close the current aineo tab, while another aineo tab remains:
   - its Claude Code is stopped as `:qa!` stops it today: by keys, or by Ctrl+Z alone for an attached one, so a background session runs on (T61's `stop_session()`);
   - its Input's draft is saved;
   - its copies are let go;
   - its entry is removed;
   - the tab page closes.

   Its records, draft and changes base stay on disk, and `\S` brings the session back in a new tab. The cursor lands in the tab Neovim makes current.
8. On the last aineo tab, the key quits Neovim as `:qa` does. Neovim refuses that while a buffer has unsaved changes, and nothing is stopped then. Otherwise every Claude Code is stopped as quitting stops it, and the session is the one the next start lands in (D23, D38), as today's `:qa!` leaves it.
9. From a tab that is not aineo's, the key closes nothing and says `aineo: this tab holds no Claude Code session`.
10. A tab closed by Neovim's own commands keeps T66's behaviour, and is the same close as the key's, but for 8: Neovim never closes its last tab page (P1: E784).

**Keys, health and help**

11. No existing key changes. No aineo key starts with `Q`, and `Q` begins none (O16). `:checkhealth aineo` lists `\Q` and `<C-\>Q`.
12. The help.
    - *aineo-tabs* gains the close.
    - `:Aineo-sessions` says a pick opens in a new tab or moves to the tab that has it.
    - COMMANDS, MAPPINGS, *aineo-terminal-keys* and HEALTH CHECK gain the close.
    - *aineo-claude-session* and LIMITS › `The session list ~` drop the `/resume` written in Claude's window and the replacement of its Claude Code.

    Run `tests/test_doc.lua`.

### Facts to re-check at dispatch

Read at `bugfix/t48-attach` `e0989f2`, before stages 1 and 2.
- `plugin/aineo.lua`:
  - `\S` runs `list_sessions()` (1389), `offer_sessions()` (1359), `pick_listed_session()` (1323) and `take_listed_session()` (1293). These lead to `switch_to_session()` (1172, the pasted `/resume`), `join_running_session()` (1226) and `replace_attached_session()` (1246).
  - The refusals are `NO_LIST`, `NOT_SWITCHED` and `refuses_by_standing()` (1263).
  - T66 makes these per tab.
- `lua/aineo/claude/agents.lua`:
  - `standing()` (94) gives `own`, `elsewhere`, `another_folder` or `switchable`;
  - `STANDING_MARKS` (168) gives the row's mark, and `row()` (193) writes it;
  - `way_to_join()` (144) gives `attach` or `resume`.
- `lua/aineo/claude/init.lua`: `join_session(settings, listed, sessions)` (859) replaces the running Claude Code. A new tab's copy has none running, so a join there is a start on that session.
- T61's `stop_session()` stops one copy's Claude Code. T66's close by Neovim's commands lets a tab's copies go.

Evidence: `evidence/w15-probes.txt` › P1, P7.

### Baseline

The dispatch message pastes the whole suite's counts on the `dev` you start from.

Read first:
- `plan.md` in this folder (U1, O17–O19);
- T66's session note;
- the session notes of T46 and T48 part 2;
- the v1 plan note's D49, D51, D62, **D65** and **D66**;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t67-tab-pick-close` from `origin/dev`.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t67_tab_pick_close`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `plugin/aineo.lua`, `lua/aineo/claude/agents.lua` and `lua/aineo/health.lua`;
  - `tests/test_entry_sessions.lua`, `tests/test_claude_agents.lua`, a new `tests/test_entry_tab_close.lua`, and the entry and health suites where a pin moves;
  - `tests/helpers/`, **additions only**;
  - `doc/aineo.txt`: *aineo-tabs*, *aineo-claude-session*, COMMANDS, MAPPINGS, *aineo-terminal-keys*, HEALTH CHECK, LIMITS › `The session list ~` and `Several tabs ~`;
  - your session note.
- **You must not touch:**
  - every other file under `lua/aineo/claude/`;
  - every other home;
  - the folder's list of tabs, which T68 writes;
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/<date> — T67 Tab pick and close.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t67-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run the test files you touch, plus `tests/test_entry_tabs*.lua`, `tests/test_claude_attach.lua` and `tests/test_doc.lua`.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on their covering files.
  - Never run the real `claude`.

## What was decided already

- **The user's decisions, 2026-10-14**, verbatim in `plan.md` › *The user's words*: "\S loads in a new tab", and a way to close a tab, "the effect would be the same of a qa! we have now, but feel free to propose a different behavior".
- **The user's answer U1**, pasted by the dispatch message. This brief is written for (a).
- **The rest is the orchestrator's** (O17–O19): the key `\Q`, a tab closed by any means closed alike, a pick of a shown session moving to its tab, and the `[tab <n>]` mark. Record them in the session note and the pull request as such.
- **Rejected:** `\q` (O17 (c)), one released Shift from stopping a session; leaving a closed tab's Claude Code running hidden (O18 (b)).

## Budget

Medium to large: `\S`'s pick reworked onto a new tab, a close with three cases, with about twenty new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial: `\S` first, then the close.

## Report

Write it in your definition's shape, to `<scratchpad>/t67-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- each pin of T46 and T48 part 2 that moved, and why;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s T67 mutants. Name the test that kills each.
