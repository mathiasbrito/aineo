# 2026-10-07 — T36 Report per session

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t36-report-sessions` · **Pull request:** into `dev` (a regular packet, D26)

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C6, C11, C14, D8, D17, D39, D40; D26, D29
- [[Planning/aineo — worktrees and session switches]] › P9, P10 and the outcome of the converge round
- Wave plan: `Implementation/Waves/00009-worktrees-sessions/plan.md` › T36, *Assumptions to report to the user* (A4, A6, A7), *Verification mutants* (T36 1–11); brief: `brief-t36-report-sessions.md` with its *Amendment* and *Correction — 2026-10-07*; `brief-review.md` (T36-1 to T36-6)
- Evidence it rests on: `evidence/w9-probes.txt` (B2), `evidence/w9-real-claude-sessions.txt` (M5)
- [[Learnings/A scheduled callback can run under textlock, where Neovim refuses a buffer change with E565]]
- [[Sessions/2026-09-24 — T5 report channel]], [[Sessions/2026-09-26 — T14 Input draft]], [[Sessions/2026-10-07 — T34 Report layout]]

## Context

D39 (the user, 2026-10-07: "all your recommendations are fine") keeps the Report per Claude session, with the directory's records moved to the kept session once (history (i)). D40 (the user, the same day, over the orchestrator's recommendation: "p10 must be one per session, why, because it is used to catalog changes and notes that goes to the prompt with \s") keeps Input's draft per Claude session and swaps it at a switch. T36 builds both homes' halves; T39 wires them to T35's switch. Nothing on `dev` calls the two new entry points after this packet, so `dev` behaves as before.

## What was done

- **`lua/aineo/report/records.lua`.** `session_records_file(state, id)`: `<state>/aineo/reports/session-<sha256(id)>.jsonl` — the prefix keeps every session's name off the directories' 64-hex names. `move_records(from, to)`: renames `from` to `to` when `to` is absent and `from` exists, returns why not otherwise.
- **`lua/aineo/report/init.lua`.** `follow_report_session(id)`: the same id changes nothing; otherwise the records file reports are kept in swaps at once (`report_view.records_file`), the first follow in the editor moves the directory's file (`move_directory_records_once()`, a failure warned through `warn_later()`), and `show_followed_records()` empties the Report and shows the session's records. An `E565` refusal alone is retried at the next `SafeState`, registering again while refused; any other error is raised again. `set_report_environment()` now runs the move for a session told before it (T36-1), so it moved below the helpers it calls. `:edit`'s refill reads `report_view.records_file` when it runs, not the file the Report was made with — without that, `:edit` after a follow showed the old session (seen red).
- **`lua/aineo/draft/init.lua`.** `session_draft_file()` (`session-<sha256(id)>.txt`) and `kept_draft_file()`, which every read and write now goes through. `follow_draft_session(id)`, in D40's order: a pending change saved at once to the old file; the session switched; the directory's draft moved once (`move_directory_draft_once()`, warned with a new `warn_once` kind, `move`); every kept buffer given the session's draft in place of its text, or emptied (`replace_with_kept_draft()`), with `'undolevels'` at -1 as D17's restore does (`put_draft()`, now shared by both). An `E565` refusal is retried at `SafeState` while the buffer is still kept; another refusal (not `'modifiable'`) is warned as the restore warns. Without an environment the follow is held; `set_draft_environment()` runs the move, and `keep_draft()` then restores the session's draft.
- **`doc/aineo.txt`**, inside the brief's two fences only: *aineo-draft*'s body (per session, the file's name, what a follow does to Input, the move and its cost, two Neovims on one session, per directory until a session is followed) and *aineo-report*'s last paragraph (the same for the records). No tag changed.
- **Tests.** `tests/test_report_sessions.lua` (14 cases) and `tests/test_draft_sessions.lua` (13 cases), a child Neovim per case. No existing test changed: `tests/test_report.lua`, `tests/test_report_buffer.lua`, `tests/test_entry_report.lua`, `tests/test_draft.lua` and `tests/test_entry_draft.lua` pin the behaviour before any follow and stay green unchanged.

### Decisions inside the brief's room

- The entry points are `follow_report_session()` and `follow_draft_session()`, one shape in both homes.
- After a follow the Report's cursor is where emptying the buffer leaves it, as when the Report is first made; the Report does not jump to its last line.
- The replacement at a follow is saved as the new session's own draft by the buffer's change watch (D40: "not saved as either session's draft but the new one's own"): an Input emptied for a session with no draft writes an empty draft file for it at once. An empty draft restores nothing, so this is invisible.
- A draft that cannot be read at a follow is warned once and Input is emptied, as for a session with no draft.

## Unit list (stated before the first test)

Report: 1 a follow shows the session's records and keeps the next report there; 2 another session replaces the lines, a report then lands in the new file only; 3 the same session leaves lines and cursor; 4 a session with no records shows an empty Report; 5 the first follow moves the directory's records; 6 both exist, neither touched; 7 a later follow moves nothing, a directory file planted again; 8 a failed move warns once, the session's file used; 9 a session told before the environment is held; 10 a follow refused under textlock lands at a later `SafeState`, no retry left; 11 a report arriving meanwhile lands in the new session; 12 a wiped Report made again, and 13 `:edit`, show the followed session.

Draft: 1 a follow puts the session's draft into Input in place of its text, the next change kept for it; 2 following back brings the text back; 3 a pending change is saved as the old session's draft; 4 the replacement is no change of the user's; 5 the same session leaves text, cursor and undo; 6 no draft empties Input; 7 the first follow moves the directory's draft; 8 both exist; 9 a later follow moves nothing, planted again; 10 a failed move warns once; 11 held before the environment and `keep_draft()`; 12 textlock.

Before any follow, the records and the draft are the directory's: pinned by the existing `tests/test_entry_report.lua` (line 109), `tests/test_report_buffer.lua` › *the records*, `tests/test_draft.lua` and `tests/test_entry_draft.lua`, all green unchanged, so no new case was added for it.

## Seen red, arrived green

**Seen red — 14** (each run alone before its code, on Neovim 0.12.5):

| Case | The failure that proved it |
|---|---|
| report › following a session › shows that session's records and keeps the next report there | `attempt to call field 'follow_report_session' (a nil value)` |
| report › … replaces the Report's lines with another session's, keeping the next report there only | `first->2, left = "Received now", right = nil` (the report kept in the old session's file, the Report still showing it) |
| report › … already followed leaves the Report's lines and cursor as they were | `cursor->1, left = 1, right = 3` |
| report › the working directory's records › become the first session followed | `lines->1, left = "", right = "10:00 [done] Task — Before any session"` |
| report › a session told before the environment › is held … | `lines->1, left = "10:00 … After the environment", right = "09:00 [done] Task — Directory"` |
| report › a follow refused while textlock holds › … [waiting for a key] | `lua/aineo/report/init.lua:306: E565: Not allowed to change text or change window` raised out of the follow — the refusal unhandled (written unparametrized; the `input()` hold was added once it was green) |
| report › following a session › shows that session's records when the user edits the Report again | `left = "09:00 [done] Task — Alpha", right = "09:00 [done] Task — Beta"` |
| draft › following a session › puts its draft into Input in place of Input's text, … | `attempt to call field 'follow_draft_session' (a nil value)` |
| draft › … saves a change not saved yet as the draft of the session followed until then | `first, left = "", right = "Typed a moment ago\n"` |
| draft › … already followed leaves Input's text, cursor and undo as they were | `undone->1, left = "Typed for the session", right = ""` |
| draft › the working directory's draft › becomes the first session followed | `directory, left = "From the directory\n", right = nil` |
| draft › a session told before the environment › is held … | `lua/aineo/draft/init.lua:270: attempt to index upvalue 'environment' (a nil value)` — the follow fails without an environment |
| draft › a follow refused while textlock holds › … [waiting for a key] | `meanwhile->retries, left = 0, right = 1` |
| draft › a follow refused while textlock holds › … [waiting in input()] | `meanwhile->retries, left = 0, right = 1` |

**Arrived green — 13**, each with the mutant that kills it, run on the final tree (below):

| Case | Why green | Killed by |
|---|---|---|
| report › with no records shows an empty Report | spent by unit 2's swap | M5 |
| report › … are left as they are when the session has records | spent by unit 5's `fs_stat(to)` guard | R-a |
| report › … planted again are not moved at a later follow | spent by unit 5's once flag | M2 |
| report › … that cannot be moved are told once, and the session keeps its own | the warning was written ahead of its test, in unit 5 | R-b |
| report › textlock › … [waiting in input()] | spent by the retry's recursion | R-c |
| report › keeps a report arriving meanwhile in the new session | spent by unit 2 (the file swaps at the follow, not when shown) | M1 |
| report › shows that session's records in a Report wiped out and made again | spent by unit 2's `report_view.records_file` swap (added with the `:edit` case, which was red) | M3, R-g |
| draft › back brings back the text Input held for it | spent by unit 1's order (switch, then replace) | M6 |
| draft › puts its draft in as no change of the user … | spent by `put_draft()`'s `'undolevels'` and unit 1's order | D-c, M6 |
| draft › with no draft empties Input | spent by unit 1's replacement | D-e, M8 |
| draft › … is left as it is when the session has a draft | spent by unit 7's `fs_stat(to)` guard | D-a |
| draft › … planted again is not moved at a later follow | spent by unit 7's once flag | M9 |
| draft › … that cannot be moved is told once, and the session keeps its own | the warning was written ahead of its test, in unit 7 | D-b |

## Mutants (on the final tree `2195138`, each its literal edit from a pristine copy, one at a time, against a copy of its test file narrowed to one group, Neovim 0.12.5)

The runner is `.tests/t36-mutate.py` in the worktree (gitignored); every row's literal edit is there. A control of each narrowed copy, unmutated, passed first (6, 4, 1, 3 report cases; 6, 4, 1, 2 draft cases). Every mutant was killed in its group by an assertion; none needed a wider run.

| # | Literal edit | Killed by |
|---|---|---|
| M1 (plan 1) | the records file swapped in `show_followed_records()` when the display lands, not in `follow_report_session()` | report › textlock › keeps a report arriving meanwhile |
| M2 (plan 2) | `directory_records_moved = true` deleted | report › … planted again are not moved at a later follow |
| M3 (plan 3) | `report_view.records_file` left as it was; the shown lines from the new file | report › replaces the Report's lines …; … Report wiped out and made again; … edits the Report again |
| M4 (plan 4) | `vim.uv.fs_rename(from, to)` → `vim.uv.fs_copyfile(from, to)` | report › become the first session followed |
| M5 (plan 5) | `… or not vim.uv.fs_stat(report_view.records_file)` added to `show_followed_records()`'s guard | report › with no records shows an empty Report |
| M6 (plan 6) | the new session's draft read, then put into Input with the old session still followed, then switched | draft › back brings back …; saves a change not saved yet …; puts its draft in as no change … |
| M7 (plan 7) | the loop saving pending changes deleted | draft › saves a change not saved yet … |
| M8 (plan 8) | `replace_with_kept_draft(buffer)` only `if is_empty(buffer)` | draft › puts its draft into Input …; with no draft empties Input; saves a change …; puts its draft in as no change … |
| M9 (plan 9) | `directory_draft_moved = true` deleted | draft › … planted again is not moved at a later follow |
| M10 (plan 10) | the `session_id == followed_session` guard deleted (report) | report › already followed leaves the Report's lines and cursor |
| M11 (plan 11) | `followed_session = session_id` moved after the `if not environment then return end` (report) | report › a session told before the environment › is held … |
| R-a | `if vim.uv.fs_stat(to) or not vim.uv.fs_stat(from)` → `if not vim.uv.fs_stat(from)` (records) | report › … left as they are when the session has records |
| R-b | `if failure then warn_later(failure) end` deleted from `move_directory_records_once()` | report › … cannot be moved are told once |
| R-c | the `SafeState` callback empties and shows once, without registering again | report › textlock › … [waiting in input()] |
| R-d | `:edit`'s refill shows `records_file`, the file the Report was made with | report › … edits the Report again |
| R-e | `empty_report()` raises every error, E565 included | report › textlock, both holds (assertion: `raised_nothing`); the meanwhile case crashes as well |
| R-f | `do return end` before `followed_records_waiting = true` (a refused swap dropped) | report › textlock, both holds and meanwhile |
| R-g | a Report made again opens the directory's file | report › … Report wiped out and made again |
| R-h | `set_report_environment()` no longer moves for a held session | report › … is held … |
| D-a | the draft move's `fs_stat(to)` guard deleted | draft › … left as it is when the session has a draft |
| D-b | `if not moved` → `if false` before the move warning | draft › … cannot be moved is told once |
| D-c | `vim.bo[buffer].undolevels = -1` deleted from `put_draft()` | draft › puts its draft in as no change of the user … |
| D-d | the draft's `session_id == followed_session` guard deleted | draft › already followed leaves Input's text, cursor and undo |
| D-e | Input left alone when the session has no draft | draft › with no draft empties Input; saves a change …; puts its draft in as no change … |
| D-f | `followed_session = session_id` moved after the environment guard (draft) | draft › … is held … |
| D-g | `set_draft_environment()` no longer moves for a held session | draft › … is held … |
| D-h | the `SafeState` callback puts the draft once, without registering again | draft › textlock › … [waiting in input()] |
| D-i | `do return end` before `replacements_waiting[buffer] = true` (a refused replacement dropped) | draft › textlock, both holds |

Two kills of the first sweep (on `34a58e5`) were crashes of the test, not assertions: R-b (the case indexed the first warning, `vim.NIL` under the mutant) and R-e (the E565 raised out of the follow's RPC call). Commit `2195138` made both cases assert, and moved the textlock group's `parametrize` onto the one case that uses it (the meanwhile case had run once per hold); the table above is the second sweep, on that tree.

## Suites (Neovim 0.12.5)

- **Whole suite** (`make test`, once, on `2195138`, `NVIM v0.12.5`): 1956 cases in 62 groups, `Fails (0) and Notes (0)`, exit 0 — `dev`'s 1929 cases in 60 groups and the two new files' 27 cases in 2. The branch adds only this note after that tree; the suite reads no vault file.
- In that run: `tests/test_report.lua` 55, `tests/test_report_buffer.lua` 101, `tests/test_draft.lua` 41 (each as on `dev`), `tests/test_entry_report.lua` 4, `tests/test_entry_draft.lua` 17, `tests/test_doc.lua` 44, `tests/test_report_sessions.lua` 14, `tests/test_draft_sessions.lua` 13.
- `make lint`: StyLua `--check` and selene clean (0 errors, 0 warnings).

## Merge with T35 and T37

The brief asks for `git merge-tree --write-tree` with `origin/feature/t35-session-switch` and `origin/feature/t37-changes-sessions`, and `tests/test_doc.lua` on each merged tree, for each branch that exists. After `git fetch origin` just before the push, neither branch existed on the remote (`git branch -r --list 'origin/feature/t3*'` printed nothing; `origin/dev` at `85a57f9`), so neither check could run. They are for whichever packet pushes second, or the orchestrator's verification.

## Task lines

The wave holds its marks. For the knowledge pass:

- **T36** — done — PR into `dev`, wave 9 (the Report's records and Input's draft per Claude session, D39, D40: `follow_report_session()` and `follow_draft_session()`, `session-<sha256(id)>` files beside the directories', the directory's file moved to the first session followed (history (i), A6), a session told before the environment held (the ruling on T36-1), a swap refused under textlock retried at `SafeState`; nothing calls them until T39; 27 new cases in `tests/test_report_sessions.lua` and `tests/test_draft_sessions.lua`)

## Open threads

- **For T39:** call `follow_report_session()` and `follow_draft_session()` from the composition root at the first start and at every switch; either may be called before `set_report_environment()` / `set_draft_environment()` / `keep_draft()`.
- **A7 is not pinned by a case of its own:** two Neovims on one session share its file because the file is named by the id alone; the existing two-editor cases (`tests/test_draft.lua` › *two editors in one working directory*, `tests/test_report_buffer.lua` › *the records*) cover the sharing of one file.
- **Not built, by the brief's silence:** a report arriving while textlock holds still fails to render and is warned (behaviour from before T36); only the follow's swap is retried.
- **To report to the user** (the orchestrator's, built as written): A4, A6 with its cost, A7, and the ruling on T36-1.
- **Boundary note:** early in the session, run logs were written to `/tmp/t36-*.log`, outside the worktree; they were removed, and every later file went under the worktree's `.tests/`.

## Commits

*Recorded after the merge.*
