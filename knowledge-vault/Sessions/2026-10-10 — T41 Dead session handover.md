# 2026-10-10 — T41 Dead session handover

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t41-dead-session-handover` · **Pull request:** into `dev` (a regular packet)

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D38, D39, D40, D41, D45; C1, C6, C11, C15
- Wave plan: `Implementation/Waves/00009-worktrees-sessions/plan.md` › *Packet T41 — 2026-10-08* (A57–A64, *Verification mutants — T41* 1–12); brief: `brief-t41-dead-session-handover.md` with its correction from the brief review (T41-1 to T41-15), its dispatch amendment of 2026-10-10 (mutants 13 and 14) and the orchestrator's rulings A86–A89
- Evidence: `evidence/w9-t41-probes.txt` (P1–P3)
- Rests on: [[Sessions/2026-10-08 — T39 Panes follow switch]], [[Sessions/2026-10-10 — T40 Lost editor]]

## Context

D45 (the user, 2026-10-08): when a resume finds no conversation and Claude Code starts a fresh session in its place (T19's fallback), the fresh session takes over the dead one's Input draft, Report records and changes-pane base with its saves. "Wait for the resume" (T39) kept the folder's files out of a dead session but left behind what a session kept while alive — the notes typed after a `/clear` in which nothing was sent.

## What was done

- **`lua/aineo/report/init.lua`** — `hand_over_report_session(from, to)`: the records file moves whole and unread, by one rename since the fix round (`records.rename_records()`, A91), only when `to` has none (an `lstat` first, T41-8); a home following `from` follows `to` as its own, with no swap (lines, cursor, a waiting `SafeState` showing); held before the environment; a failed move told once.
- **`lua/aineo/draft/init.lua`** — `hand_over_draft_session(from, to)`; the directory's move made general as `move_draft(from, to)` (and `move_draft_by_rename()`), inside the home; since the fix round the hand-over moves by `move_draft_by_rename()` (A91). A pending change is saved to `from`'s file first; watches pinned to `from`'s file, or naming it unreadable, now name `to`'s; Input keeps text, cursor and undo.
- **`lua/aineo/changes/`** — `kept.move_kept_base()` (first link then unlink, with a rename where links are refused or the file is a symbolic link, a race given up and both failures returned; since the fix round one rename after a look for `to`, A91) and `hand_over_changes_session({ from, to, state_directory })`: keeps for `from` first (`keep()`), moves the file and `held_bases`, renames the id on the home's own copy of the followed session so a look for `HEAD` under way completes for `to`; a session told before `begin_session()` is renamed too. `follow_changes_session()` now keeps a copy of its argument. The told-once flag of a failed keep moved from the session to the home, so a hand-over before the session begins can tell its failure.
- **`plugin/aineo.lua`** — `replacement_callbacks(working_directory)`: `on_terminal_replaced` notes the fresh id; the switch with that id and source `startup` is the fallback's, handed over at once (`hand_over_dead_session()`) before T39's drop and T40's hold, neither changed. Skipped while T40's `running_sessions()`, asked with the dead start's own directory, lists the dead id (A63, T41-1). This Neovim's claim of the dead id let go by `release_claim()`; a claim made with the id ends the hold; `panes_session` moved and the entry written when the panes followed the dead id.
- **`doc/aineo.txt`** — the seven places (below).
- **Tests** — at the first push: 15 cases in `tests/test_report_sessions.lua`, 18 in `tests/test_draft_sessions.lua`, 31 in `tests/test_changes_sessions.lua` (that file then counted 92), 11 in the new `tests/test_entry_session_handover.lua`. After the fix round: 17, 19, 19 and 12 (files of 68, 106, 80 and 12 cases). `tests/test_entry_session_switch.lua` unchanged: its two dead-resume cases leave no file under the dead id and stay green.

## Decisions and readings

- **Whose each is.** D45 is the user's decision. A57–A64 are the planning's readings; A86–A91 are the orchestrator's assumptions under the user's instruction of 2026-10-06, to report to the user. None is the user's decision.
- A57–A64 built as written; A86 (help place 7 and LIMITS), A87 (a claim's follow of the dead id becomes the editor's own in the report and draft homes), A88 (mutants 13 and 14 kept); in the fix round A90 and A91 (below).
- **Beyond the brief.** `kept.lua` first carried the full move with every branch, nine more changes cases than the brief counted (links refused ×5 moving by a rename, a symbolic link, the race, an unremovable dead file, the race with an unremovable new name); A91 replaced that move with one rename, and the fix round deleted seven of them (the five links-refused moves and both unremovable cases), with the five rename-failure cases of the same group; the race case now stages the APFS double removal, and the symbolic link's stays. `follow_changes_session()` keeps a copy of its argument (written ahead of its own case, pinned in `2581b66`). The changes home's told-once flag moved from the session to the home. A90 widened the boundary by one condition in T40's `receive_session_report()`.
- **A home follows `to` exactly when `to` had no file of its own**, whether `from` had one, and whether the move then failed (a failure is told). The brief's contract says what happens when `to` has its own and when the move fails, not which session the home follows after a failed move; following `to` keeps Input's next change and the next report and mark with the session that runs.
- **The composition root moves `panes_session` and the entry whenever the panes followed the dead id**, also in the case (not expected: the id is minutes old) where a home kept following the dead id because `to` had a file of its own; T39's confirmation then follows `to` in every home.
- The A57 note's error path (a handler raising after the note) has no case of its own, as the brief says (T39-12's precedent).

## Red and green

Each red was read and was for the missing behaviour. Arrived green, with the killer run: report R3, R4, R5, R7, R8, R9 (spent by R1/R6's move and re-point); draft D3, D4, D5, D8, D9, D12, D13, D14 (spent by D1's `move_draft()`, which pins and warns, and D7's re-point); changes rename-failure, neither, unreadable, no re-read, later follow, not followed, and the argument copy (written in C8's unit); entry E2–E6 (spent by E1's wiring) and the A87 undo case (meaningful once E9's hold ends). The entry case of a restart with a conversation has no killer inside this packet: neither callback fires there (P1b). E9's two forms were seen red together, written in one edit.

## Mutants (each its literal edit, quoted in the pull request's body)

| plan # | edit | killed by (all by assertion) |
|---|---|---|
| 1 | `if id == replacing_session and source == 'startup'` → `if source == 'startup'` | entry: start in another directory |
| 2 | hand-over held in a pending table and made in `on_session_ready` | entry: chain; entry before ready; no-word claim |
| 3 | the move → a copy (`mkdir`, `writefile(readfile(from) or {})`) in each home | R1 R3 R4 R6 R10 R12; D1 D3 D4 D6 D7 D10 D12 D14 D15; C1 C3 C4 C6 + branches |
| 4 | the re-point to `to` removed, in each home | R6 R7 R9 R10 R13; D7 D8 D10 D13 D15 D16; C6 C8 C10 C13 |
| 5 | the re-point → `follow_*_session(to)` | R5 R13; D5 D16; C5 C13 (reads asked) |
| 6 | the save of a pending change removed | D6 |
| 7 | the `lstat` of `to` removed | R2; D2; C2 |
| 8 | `held_bases` move removed | C7 |
| 9 | `if holds_other_claim() then return end` first in the switch handler | entry: A64 |
| 10 | the `running_sessions()` check removed; and the query on `kept_places().working_directory` | entry: A63 with `:cd` (both) |
| 11 | `session.followed` replaced by a new table instead of renamed | C8 |
| 12 | `report_view.records_file` left the dead's | R6, R9 |
| 13 | the `panes_session`/`write_entry()` block removed | entry: entry before ready |
| 14 | the claim release and hold end removed (and each alone) | entry: no-word claim; id claim |
| — | the not-followed guard made true (each home); `if true then` on `panes_session == dead` | R8; D9 D3 D14; C9 C3 C7; entry: A64 (after the A64 case gained its entry assertion) |
| — | held hand-overs dropped; warnings dropped; kept.lua branches (links refused, symbolic link, race, unremovable, race-unremovable, rename failure) | R10; D10; R12, C12 + branch cases |
| — | the claim flag kept, report / draft | R13 and the entry A87 case / D16 (survives the entry suite: the confirmation keeps an Input whose text is already the draft) |

## Suites

The whole suite on the pushed tree, Neovim 0.12.5, macOS: 2502 cases in 74 groups, `Fails (0) and Notes (0)`, exit 0, 303 s (2422 at `0ed6681`, + 5 of PR #152, + 75 of this packet). `make lint` clean.

## The help

1. *aineo-claude-session*'s fallback paragraph: the new session takes over records, draft, base and saves; panes that showed the dead session show the same at once; nothing handed over while a known Claude Code runs on it.
2. T39's paragraph on when the panes follow: the strand sentences replaced; first start takes the directory's only when the dead one kept none.
3. *aineo-changes*: the exception for a session taking a dead one's place; the "unless a resume … finds no conversation" clause rewritten.
4. A new LIMITS subsection, *A session in place of one with no conversation ~* (A61 with A86, A62, A63 with T41-14, a session with a file of its own).
5. *aineo-draft*'s swap paragraph and 6. *aineo-send* › `Undo ~`: no switch, Input keeps text and undo.
7. *aineo-report-claims* item 4, qualified (A86).
T38's sentence on a save before the first follow re-read: still true.

## Task lines

- T41 — built on `feature/t41-dead-session-handover` (this note); the row still lacks T40 among its dependencies (T41-12), for the `knowledge/` change that marks it done.

## Open threads

- The readings above (a failed move, `panes_session` when `to` had its own) for the reviewers.
- A58 and A60 depart from the wording of "Wait for the resume": to report to the user together (*For the orchestrator*, 4).

## Fix round — 2026-10-11

The three reviews of PR #154 (attack, test integrity, records) and the orchestrator's rulings A90 and A91. Each fix was driven by a case seen red first, or, for a test-only fix, shown failing by assertion against the mutant it guards.

- **Attack 1, A90.** `receive_session_report()` refuses to keep a report with the directory's records when the report's session has a records file of its own; the report server then keeps it with that session. The review's probe P3 is an entry case (red: the fresh session's Report lacked the report). The help's *aineo-report-claims* item 4 and the LIMITS bullet on A86 say what holds now.
- **Attack 2 and 3, A91.** The hand-over moves by one rename after the look for `to`, in each home. One case per home stages another editor handing the same id over at the same moment, both removals succeeding as APFS let them; each was red against the link (two names on one file). T36's directory moves keep link then unlink; their docstrings now say the APFS double removal shares one file, and LIMITS names that window as an open limit.
- **Tests 1–5.** The A64 case asserts this Neovim still claims the claimed session; both textlock cases assert the file moved; the report analogue of D16 (the directory's records wait for the next follow told without a claim); each home's not-a-string rows match `<name>: expected string`; the A63 case changes directory while the resume runs.
- **Tests 6, records 1 and 3.** `replacement_callbacks()` gives the operative reason for a per-start id note; `start_confirmed` names the hand-over exception; `started_claude_terminal()` rewrapped; item 4 says "when it kept any".
- **Records 2, 4 and 5.** The first push's `test_changes_sessions` count was 92, not 91; whose each A is, and the departures, are under *Decisions and readings*.

**Mutants of the fix round, each its literal edit, all killed by assertion:**

| edit | killed by |
|---|---|
| the A90 condition removed (seen as the red) | entry: report kept with its session |
| report hand-over `records.rename_records(…)` → `records.move_records(…)` | report: same moment |
| draft hand-over `move_draft_by_rename(from_file, to_file)` → `move_draft(from_file, to_file)` | draft: same moment |
| `kept.move_kept_base` `vim.uv.fs_rename(from_file, to_file)` → `fs_link` then `fs_unlink(from_file)` | changes: same moment; symbolic link |
| `if claimed == dead then release_claim() end` → `release_claim()` | entry: A64 (claimant) |
| `if followed_records_waiting then return end` before the report hand-over | report: textlock |
| `if next(replacements_waiting) then return end` before the draft hand-over | draft: textlock |
| `directory_records_moved = true` after `followed_as_claim = false` (report) | report: A87 directory |
| each home's entry point renamed away | each home: the `to` row (and `from` rows) |
| `hand_over_dead_session(left, id, working_directory)` → `…(left, id, vim.fn.getcwd())` | entry: A63 with a `:cd` while it resumes |

**The whole suite** after the fix round, on `a3943f9` (code identical to the pushed head), Neovim 0.12.5, macOS: 2494 cases in 74 groups, `Fails (0) and Notes (0)`, exit 0, 324 s (2502, plus 4 new cases, less the 12 link cases). `make lint` clean.

## Commits

*Recorded after the merge.*
