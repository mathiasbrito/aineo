**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D63 as proposed and for the recommendations O4–O6 of `plan.md` in this folder. If the orchestrator ruled otherwise, a dated amendment at the end of this brief says so, and it wins over the body.

## Objective

The task, verbatim from the task list:

> | T62 | One Report and one Input draft per tab (C6, C11; D63, proposed): `aineo.report` and `aineo.draft` each gain `new()`, a home of its own whose Report or draft, followed session, claim and hand-overs are kept apart from every other copy's; a report the editor receives (`receive_session_report()`) reaches the copy a router the composition root gives chooses, the module's own copy when none is given; the module's own functions stay one such copy, so every caller and suite of today stands | T48 part 2 | planned — wave 15 |

It rests on:
- **D63**, the user's decision that each tab has its own Report and Input, and the proposed parts.
- **C6, C11 and C14**: the Report, the draft and the Report line.
- D39, D40, D42 and D45, which hold per copy.
- C8, D10, D26, D29.

### What a copy must do — one test each, seen failing first

**The report home**

1. `require('aineo.report').new()` returns a report home with the module's per-view functions, called as fields: `set_report_environment`, `report_buffer`, `receive_report`, `follow_report_session` and `hand_over_report_session`. Each call gives a copy of its own. The module stays one copy. The functions that keep no state stay on the module: `validate_report`, `report_schema`, `report_instructions` and `keep_session_report`.
2. Each copy's Report is a buffer of its own, under a name no other buffer holds. The module's keeps `aineo://report`. Making the second copy's Report neither raises (P1: E95) nor wipes the first's. Today `free_report_buffer_name()` frees the one name by wiping the buffer that holds it.
3. Two copies following two sessions each show only their own session's records, and each keeps a report it receives in its own session's records.
4. The module's `receive_session_report(arguments, session_id, options)` stays the entry point the report server calls (P2), with its arguments and answers.
   - With a router given (`set_report_router(router)`, new, on the module), it asks `router(session_id, options)` for the copy that takes the report. It hands the report to that copy, whose rules of today decide (`at_start`, `keep_with_directory`), and answers what that copy answers.
   - A router that gives no copy makes it answer `false`, so the report server goes on searching.
   - With no router, the module's copy takes it, as today.
   - `options.start_token`, a new optional key, reaches the router unchanged. The report home reads nothing else of it.
5. A router that raises: the report is not taken, `false` is answered, and the user is warned once, as a failing receive is told today (`warn_later()`).

**The draft home**

6. `require('aineo.draft').new()` returns a draft home with `set_draft_environment`, `keep_draft`, `follow_draft_session` and `hand_over_draft_session`, called as fields. Each call gives a copy of its own. The module stays one copy.
7. Two copies keeping two Inputs, following two sessions, each save to and restore from their own session's draft file. Following a session in one copy swaps that copy's Input only.
8. A draft change pending in one copy's Input is saved when that Input is wiped (`BufUnload`, as today), whatever the other copy does.
9. The handlers of one copy leave the other's alone, and no copy's group removes another's: the `SafeState` retries of a swap or a hand-over refused under textlock (`aineo.report`, `aineo.draft`), and the `BufUnload`, `BufWinEnter` and `QuitPre` saves.

### Facts, checked at `bugfix/t48-attach` `e0989f2` (both homes are the same on `dev` `1354cad`)

**`lua/aineo/report/init.lua`:**
- State: `environment` (21), `followed_session` (26), `followed_as_claim` (30), `directory_records_moved` (34), `report_view` (40), `hand_overs_waiting` (113), `followed_records_waiting` (375).
- Exports: `set_report_environment` (161), `report_buffer` (339), `receive_report` (443), `receive_session_report` (498), `keep_session_report` (536), `follow_report_session` (567), `hand_over_report_session` (616).
- `receive_session_report()` takes the report when `followed_session == session_id`, or while it follows none and `options.at_start`, and keeps it with the directory's records on `keep_with_directory` (498–525).
- The `SafeState` retry is in the group `aineo.report`, made with `clear = false` (397).

**`lua/aineo/report/buffer.lua`:**
- `REPORT_BUFFER_NAME = 'aineo://report'` (14).
- `create_report_buffer(fill, open_path)` (136) first calls `free_report_buffer_name()`, which wipes the buffer holding the name. It then makes its handlers in the group `aineo_report`, cleared when made again (142).

**`lua/aineo/draft/init.lua`:**
- State: `environment` (64), `kept` (76, already per buffer), `followed_session` (111), `followed_as_claim` (115), `warned` (184), `directory_draft_moved` (281), `replacements_waiting` (638), `hand_overs_waiting` (718).
- Exports: `set_draft_environment` (767), `keep_draft` (814), `follow_draft_session` (905), `hand_over_draft_session` (965).
- Its groups are `aineo.draft`, made with `clear = false` (705, 831). `BufUnload` saves a pending change (833).

**The report server's call** (`lua/aineo/mcp/delivery.lua`, `RECEIVE_SESSION_REPORT`, `RECEIVE_AT_START`) is `require('aineo.report').receive_session_report(report, session, options)`. T64 adds `start_token` to `options` in the same stage. Neither packet waits for the other: the key is optional on both sides.

Evidence: `evidence/w15-probes.txt` › P1, P2, P4, P5.

### Baseline

This plan ran no suite. The dispatch message pastes the counts of the test files you run, measured on the `dev` you start from.

Read first:
- `plan.md` in this folder (*The model*, O4–O6);
- the v1 plan note's C6, C11, D39, D40, D42, D45 and **D63**;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t62-report-draft-copies` from `origin/dev`.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t62_report_draft_copies`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/report/` and `lua/aineo/draft/`;
  - new `tests/test_report_copies.lua` and `tests/test_draft_copies.lua`, and the `tests/test_report*.lua` and `tests/test_draft*.lua` files where a pin moves (none should);
  - your session note.
- **You must not touch:**
  - `plugin/aineo.lua`, which T66 changes;
  - `lua/aineo/mcp/`, which T64 changes in the same stage;
  - every other home under `lua/`;
  - `tests/helpers/`;
  - `doc/aineo.txt`;
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Keep the interfaces.** Every export of both homes keeps its name, its arguments and its promises, and the modules act as today. Add `new()` to each and `set_report_router()` to the report home, each with its docstring.
- **Session note:** `knowledge-vault/Sessions/<date> — T62 Report and draft copies.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t62-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run the test files you touch, plus `tests/test_report_sessions.lua`, `tests/test_draft_sessions.lua`, `tests/test_mcp_delivery.lua` and `tests/test_entry_session_handover.lua`.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on their covering files.
  - Never run the real `claude`.

## What was decided already

- **The user's decision, 2026-10-14:** "report and input is per tab" (D63, `plan.md` › *The user's words*).
- **The orchestrator's assumptions** (O4–O6): one copy per tab behind the same functions, the module as the first; a router given by the composition root; the start token in the options. Record them in the session note and the pull request as such, never as the user's.
- **Rejected:** routing by session alone (O6 (b)), which would show one tab's reports in another when two tabs follow one session.
- **Not yours:** which copy the router chooses. T66 writes it, from the tabs' Claude Codes and panes.

## Budget

Medium: two homes given copies and one router, with about twelve new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

Write it in your definition's shape, to `<scratchpad>/t62-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- each per-editor resource you made unique per copy, and how;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s T62 mutants. Name the test that kills each.

## The orchestrator's rulings — 2026-10-14, before dispatch

`plan.md` › *The user's answers* (U1–U3, the user's decisions) and *The orchestrator's rulings* (O1–O22 → A234–A255, each its (a)) bind this brief, which is written for them. Record A234–A255 as the orchestrator's assumptions, never as the user's decisions.
