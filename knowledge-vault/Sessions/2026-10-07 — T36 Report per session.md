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

- **`lua/aineo/report/records.lua`.** `session_records_file(state, id)`: `<state>/aineo/reports/session-<sha256(id)>.jsonl` — the prefix keeps every session's name off the directories' 64-hex names. `move_records(from, to)`: renames `from` to `to` when `to` is absent and `from` exists; returns nil when it does not try, and a reason only when the rename fails. *(Corrected in the fix round, records finding 9; the move is now a link and an unlink — see* Fix round *below.)*
- **`lua/aineo/report/init.lua`.** `follow_report_session(id)`: the same id changes nothing; otherwise the records file reports are kept in swaps at once (`report_view.records_file`), the first follow in the editor moves the directory's file (`move_directory_records_once()`, a failure warned through `warn_later()`), and `show_followed_records()` empties the Report and shows the session's records. An `E565` refusal alone is retried at the next `SafeState`, registering again while refused; any other error is raised again. `set_report_environment()` now runs the move for a session told before it (T36-1), so it moved below the helpers it calls. `:edit`'s refill reads `report_view.records_file` when it runs, not the file the Report was made with — without that, `:edit` after a follow showed the old session (seen red).
- **`lua/aineo/draft/init.lua`.** `session_draft_file()` (`session-<sha256(id)>.txt`) and `kept_draft_file()`, which every read and write now goes through. `follow_draft_session(id)`, in D40's order: a pending change saved at once to the old file; the session switched; the directory's draft moved once (`move_directory_draft_once()`, warned with a new `warn_once` kind, `move`); every kept buffer given the session's draft in place of its text, or emptied (`replace_with_kept_draft()`), with `'undolevels'` at -1 as D17's restore does (`put_draft()`, now shared by both). An `E565` refusal is retried at `SafeState` while the buffer is still kept; another refusal (not `'modifiable'`) is warned as the restore warns. Without an environment the follow is held; `set_draft_environment()` runs the move, and `keep_draft()` then restores the session's draft.
- **`doc/aineo.txt`**, inside the brief's two fences only: *aineo-draft*'s body (per session, the file's name, what a follow does to Input, the move and its cost, two Neovims on one session, per directory until a session is followed) and *aineo-report*'s last paragraph (the same for the records). No tag changed.
- **Tests.** `tests/test_report_sessions.lua` (14 cases) and `tests/test_draft_sessions.lua` (13 cases), a child Neovim per case. No existing test changed: `tests/test_report.lua`, `tests/test_report_buffer.lua`, `tests/test_entry_report.lua`, `tests/test_draft.lua` and `tests/test_entry_draft.lua` pin the behaviour before any follow and stay green unchanged.

### Decisions inside the brief's room

- The entry points are `follow_report_session()` and `follow_draft_session()`, one shape in both homes.
- After a follow the Report's cursor is where emptying the buffer leaves it, as when the Report is first made; the Report does not jump to its last line.
- The replacement at a follow is saved as the new session's own draft by the buffer's change watch (D40: "not saved as either session's draft but the new one's own"): an Input emptied for a session with no draft writes an empty draft file for it at once. An empty draft restores nothing, so this is invisible. *(False, and reversed in the fix round: the write-back overwrote another editor's newer draft and an unreadable one — attack findings 3–4, records finding 2. The swap is now never saved.)*
- A draft that cannot be read at a follow is warned once and Input is emptied, as for a session with no draft. *(Since the fix round the unreadable file is left as it is.)*

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

The runner is `.tests/t36-mutate.py` in the worktree (gitignored); every row's literal edit is there. There are **28** mutants — the plan's eleven and 17 more; the PR body and the report first said 29 (records finding 4, corrected). A control of each narrowed copy, unmutated, passed first (6, 4, 1, 3 report cases; 6, 4, 1, 2 draft cases). Every mutant was killed in its group by an assertion; none needed a wider run.

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

- **T36** — done — PR into `dev`, wave 9 (the Report's records and Input's draft per Claude session, D39, D40: `follow_report_session()` and `follow_draft_session()`, `session-<sha256(id)>` files beside the directories', the directory's file moved to the first session followed (history (i), A6), a session told before the environment held (the ruling on T36-1), a swap refused under textlock retried at `SafeState`; nothing calls them until T39; 27 new cases in `tests/test_report_sessions.lua` and `tests/test_draft_sessions.lua`; fix round of PR #135: a kept buffer's saves stay with its old session until its swap lands, the swap never saved, no swap while the old text cannot be saved, the moves by link then unlink, the ids checked; 52 cases in the two files; fix round 2 after the re-measure: a failed save stays pending, two interleaved first follows keep one file each, an edit in the first follow's window lands with the moved draft, both retries in aineo's augroups, a rename fallback where hard links are refused, an unreadable session draft never replaced (the orchestrator's ruling), LIMITS names the two races left; 117 cases in the two files)

## Open threads

- **For T39:** call `follow_report_session()` and `follow_draft_session()` from the composition root at the first start and at every switch; either may be called before `set_report_environment()` / `set_draft_environment()` / `keep_draft()`.
- ~~**A7 is not pinned by a case of its own**~~ — pinned in the fix round (test-integrity finding 2).
- **Not built, by the brief's silence:** a report arriving while textlock holds still fails to render and is warned (behaviour from before T36); only the follow's swap is retried.
- **To report to the user** (the orchestrator's, built as written): A4, A6 with its cost, A7, and the ruling on T36-1.
- **Boundary note:** early in the session, run logs were written to `/tmp/t36-*.log`, outside the worktree; they were removed, and every later file went under the worktree's `.tests/`.

## Fix round — 2026-10-07, after the reviews of PR #135

Three reviews on `fe112c4`: attack, test integrity, records (`.claude/local/orchestrator/review135/` in the main checkout). The orchestrator's brief for the round is `orch-fixround-135.md` there.

### The orchestrator's rulings — its assumptions under the user's instruction of 2026-10-06, to report to the user

- **The attack's draft fix is adopted** (attack findings 1–4, records findings 2–3), over the brief's step 2 ("the home keeps for the new session from then on") and over this packet's empty-file decision:
  - a kept buffer's saves stay on the file its text came from until its swap lands;
  - the swap is kept out of the change watch, and is never saved;
  - no swap while the old session's text could not be saved: Input keeps it, with a warning each time;
  - an unreadable draft is never replaced by an empty file.
- **The move links, then unlinks**, in both homes (attack finding 5).
- **A6's cost is corrected** in the help, the PR and this note (records finding 1). A working directory's file written after the first move is not "never shown again". It is taken by the next editor that first follows a session with no file of its own; the once-flag is per editor.
- **Both entry points check their id** with `vim.validate` (attack finding 6, records finding 7). For the draft, this overrules C11's "never raises" for a caller's wrong argument.
- **The help may describe behaviour T39 wires**: no wave-9 release is cut before T39 merges.

### What changed

- **`lua/aineo/report/records.lua`.** `move_records()` links `to` to `from`, then unlinks `from`.
  - `EEXIST` (another editor made the session's file) and `ENOENT` (another editor took the directory's) are no failure.
  - An unlink that fails after the link is a failure, since the records are then in both files. It is a fix beyond the reviews: `clean-code` allows no ignored error.
- **`lua/aineo/report/init.lua`.** `follow_report_session()` validates its id. `report_view`'s docstring now names the file reports are kept in (records finding 9).
- **`lua/aineo/draft/init.lua`.**
  - Each `aineo.draft.Watch` has a `file`, pinned at a follow, which every save of that buffer writes until `replace_with_kept_draft()` lands the swap (`file_of()`).
  - A follow saves each buffer's pending change before the directory's draft moves, so the change moves with it. The retry saves again first, at once, and does not swap when that fails.
  - `warn()` was split out of `warn_once()`, so the kept-text warning is given each time.
  - The `replacing` flag keeps the swap out of `take_in_change()`.
  - The move links, then unlinks, as in the records.
  - `write_draft()` and `save()` take the file.
- **`doc/aineo.txt`** (both fences):
  - A6's cost;
  - the undo sentence: no `u` reaches a change or a Send made before the swap (records finding 5);
  - "the new session's draft", and "of a session's reports" (records finding 8);
  - the text kept when it cannot be saved, the window before the swap lands, and the swap never saved.
- **This note.** The untrue statements above are marked in place (records findings 4 and 9). The records finding about the commit `c821a74`'s "but aineo.config's edge" stays as history: `aineo.report` requires no aineo home.

### Tests — seen red, arrived green

**Report:** `tests/test_report_sessions.lua`, 14 → 22 cases.
- **Seen red** (each on the code before its fix):
  - "taken by another editor first are told as no failure": a warning naming `ENOENT`.
  - "never replace a session's file another editor made meanwhile": `session->1, left = "Written by an older aineo"`.
  - "refuses an id that is not a string…" × 3: `refusal->followed, left = true, right = false`. On its first version two of these crashed; I rewrote the case so all three fail by assertion.
  - "whose file cannot be removed once linked are told once": `moves, left = 0, right = 1`.
- **Arrived green**, each with the mutant that kills it (sweep below):
  - "back shows the reports another editor kept…" (A7, test finding 2) — X-R7 (= the reviewer's R9);
  - "followed twice…" (finding 5) — X-R6 (= R7);
  - "with no records…" strengthened (finding 4) — M5;
  - "keeps a report arriving meanwhile", now asserting `waiting = 1` (finding 3) — M1;
  - "are left as they are…", now asserting no warning — X-R1.
- The read-only fixture is restored by `MiniTest.finally` (finding 1).

**Draft:** `tests/test_draft_sessions.lua`, 13 → 30 cases.
- **Seen red, against the committed draft home** (`HEAD`, copied back and forth from `.tests/`): 8 cases, `Fails (8)`, each by assertion:
  - "saves a change not saved yet…": `second, left = "", right = nil` — the case changed under the ruling;
  - the two window cases: `first, left = "Typed for the first session\n"`;
  - the completion case: `second, left = "Typed for the first session alphabet\n"`;
  - "a follow writes nothing back…": `different string length`;
  - "a draft that cannot be read…": `second, left = ""`;
  - the two unsaved-switch cases: `kept, left = 0`.
- **Seen red, before their fix:**
  - the two race cases: a warning, and `session, left = "Written by an older aineo\n"`;
  - "refuses an id…" × 3: two by assertion (`first, left = "Notes…\n", right = ""`), and the `{}` case by a crash with the same cause (the table became the followed session, and `sha256({})` raised in the change watch).
- **Arrived green**, each killed in the sweep:
  - the A7 case — X-D14 (= D9);
  - "followed twice" — X-D13 (= D10);
  - "a follow refused for another reason" — X-D12 (= D11);
  - "back brings back…" strengthened — M6, X-D3;
  - "planted again…" strengthened, and "becomes…", "moves … with a change not saved yet" — M9, X-D6;
  - the move-failure case, now asserting `writes = 1` (finding 7) — X-D11 (= D8);
  - "whose file cannot be removed once linked" — X-D9;
  - "is left as it is…", asserting no warning — X-D7.
- `MiniTest.finally` restores the read-only fixture (finding 1).

The reviewer's R5 (`empty_report()` swallowing every error) and D6 (the retry ignoring `kept`) still have no separating input. Neither was run.

### Mutants (on `12a0a40`, each its literal edit from a pristine copy, one at a time, against the whole new test file of its home, Neovim 0.12.5)

The runner is `.tests/t36-mutate-fix.py` in the worktree. It holds every literal edit, and the reviewers' edits where named (`=ti-…`), adapted where the fix renamed what they matched.

All **32** were killed with at least one assertion failure. M6 and X-D10 also crash in some cases. The 32 are:
- the plan's eleven (M1–M11);
- seven for the Report: X-R1 `EEXIST` a failure, X-R2 `ENOENT` a failure, X-R3 back to check-then-rename, X-R4 the unlink failure untold, X-R5 no validation, X-R6 = R7, X-R7 = R9;
- fourteen for the draft:
  - X-D1 no pin, X-D2 the pin never released, X-D3 no `replacing` guard;
  - X-D4 the swap made when the save failed, X-D5 that warning given once, X-D6 no save before the move;
  - X-D7 and X-D8 as X-R1 and X-R2, X-D9 the unlink failure untold, X-D10 no validation;
  - X-D11 = D8, X-D12 = D11, X-D13 = D10, X-D14 = D9.

Each row's failing cases are in `.tests/t36-mutants-fix.out`.

### Suites, lint, merges

- **Whole suite** (`make test`, once, on `12a0a40`, `NVIM v0.12.5`): 1981 cases in 62 groups, `Fails (0) and Notes (0)`, exit 0 — `dev`'s 1929 and the two new files' 22 + 30. In that run: `tests/test_report.lua` 55, `tests/test_report_buffer.lua` 101, `tests/test_entry_report.lua` 4, `tests/test_draft.lua` 41, `tests/test_entry_draft.lua` 17, `tests/test_doc.lua` 44, `tests/test_report_sessions.lua` 22, `tests/test_draft_sessions.lua` 30. The push adds only this note to that tree.

- `make lint`: clean.
- The merge checks the brief asks for now run:
  - `git merge-tree --write-tree 12a0a40 origin/feature/t35-session-switch` (`c2a6cee`) gives `223c4b2`;
  - with `origin/feature/t37-changes-sessions` (`0442ade`) it gives `6e8ce89`.
  - Both are clean. Each tree, extracted under `.tests/` with `deps/` copied, passes `make test_file FILE=tests/test_doc.lua`: 44 cases, `Fails (0) and Notes (0)`.

### Not done, and why

- **The attack's caveat**, a file system without hard links, would now warn where `rename` worked. No fallback was built: the ruling names link-then-unlink only.
- **The two new `SafeState` autocommands have no augroup** (attack › *Other dimensions*). The changes home sets the same precedent, and the orchestrator's list does not include it.
- **For T39 or the knowledge pass:**
  - the help's *Undo* section and LIMITS *Undo after a Send*, outside T36's fences (records finding 5);
  - `plugin/aineo.lua`'s docstrings, the plan's A6 and A7, and D39's "once" (records › *What T36 makes false elsewhere*).

## Fix round 2 — 2026-10-07, after the re-measure of PR #135

A fresh implementer (`neovim-lua-developer`, Opus) took the re-measure of `199910a` (`remeasure135/remeasure-t36.md` in the main checkout's orchestrator folder) and the orchestrator's instructions for the round (`orch-fixround2-135.md` there). Every red below was seen on Neovim 0.12.5, each case run alone, before its code.

### The orchestrator's rulings — its assumptions under the user's instruction of 2026-10-06, to report to the user

- **Finding 8: a session whose draft cannot be read keeps its file.** While Input shows such a session, typing is not saved to that file. The user is warned at the follow and again at the first edit, each time. No write ever replaces an unreadable draft.
  - Read here as: the session's draft, at a follow or at `keep_draft()`'s restore of a held session. The working directory's draft before any follow keeps D17's rule (replaced by the first change after one warning), so `dev` behaves as before; a case pins it.
  - Text typed while Input shows such a session is a text that cannot be saved, so the first round's ruling applies: the next follow keeps it in Input, with a warning each time. An empty Input has nothing to keep, and the follow goes on.
- **Finding 7: the older-aineo race is named in LIMITS, not fixed.**
- **Findings 1–6** were to be fixed as the re-measure built them (F1–F5), and **finding 9** corrected in the PR body.

### What changed

- **F1 (finding 1).** Every save goes through `save_pending_change_now()`, which clears `pending` only once the write succeeded: the delayed save, the save at once when Input empties, and the quit save. `save()` had no caller left and went.
- **F3 (finding 2), both homes.** When the unlink after a successful link finds `ENOENT`, another editor took the file between the two calls. `give_up_link_taken_meanwhile()` then removes this editor's name when the file has another one, and keeps it when it is the only one. A removal that fails is told, naming that another editor moved the file at the same moment and that both sessions keep it: that is the round's "the warning names what happened". Before, the warning blamed the directory's file with `ENOENT`.
- **F5 (finding 3).** `pin_moved_text()` re-pins every buffer pinned to the directory's file to the session's, once the session's file holds the text: after the link, also when the directory's name cannot be removed, and after the fallback's rename.
- **F2 (finding 4).** The draft's retry is in `aineo.draft` and the Report's in a new `aineo.report`. Each docstring says what clearing aineo's own group while a retry waits does, measured with `:autocmd! aineo.draft` and `:autocmd! aineo.report`: the buffer stays on its old file, or the Report on its old records, for the editor's life.
- **F4 (finding 5), both homes.** A link refused with `ENOTSUP`, `EPERM`, `EXDEV`, `EMLINK` or `ENOSYS` falls back to looking for the session's file, then renaming. A rename that finds the directory's file gone is no failure, and any other failure is told. LIMITS names the race the fallback keeps.
- **Finding 8.** `watch.unreadable` holds the session file that could not be read. `write_kept_text()`, used by every save, never writes it. The follow's read warning is given each time (it was `warn_once`), and `tell_text_not_saved()` warns at the first change after each such follow.
- **Help.** The draft fence says the unreadable-session rule. A new LIMITS subsection, *The first follow's move*, names the fallback's check-then-rename race and the older-aineo save removed between the link and the unlink (finding 7). That subsection is outside the brief's fences, as the round's instructions asked.

### Tests — seen red, arrived green

`tests/test_draft_sessions.lua`: 30 → 71 cases. `tests/test_report_sessions.lua`: 22 → 46. The F4 cases are a set parametrized over the five codes.

**Seen red:**

| Item | Case | Red |
|---|---|---|
| F1 | keeps Input's text whose delayed save failed before the switch (RM-1) | `kept` 0 vs 1, Input showing B's draft |
| F1 | saves the text whose delayed save failed once the disk is freed (RM-2) | on `199910a`'s home: `first` nil vs the text |
| F1 | keeps the text when its delayed save fails between two switches (RM-3) | on `199910a`'s home: `kept` 1 vs 2 |
| F3 | records moved by another editor at the same moment stay that session's file alone (RR-1) | `other` held "Kept for session a only", `same_file` true |
| F3 | records … told so when the link cannot be removed | no warning |
| F3 | draft moved by another editor at the same moment stays that session's alone (RM-9) | Input showed the directory's draft |
| F3 | draft … told so when the link cannot be removed | no warning |
| F5 | keeps an edit made while the first follow waits with the draft it moved (RM-11) | the edit in a new directory file |
| F2 | draft: made still when every `SafeState` autocommand in no group is cleared (RM-4) | A's file took the third session's typing |
| F2 | Report: the same (RR-2) | Report stayed on Alpha |
| F4 | records become the first session followed by a rename, ×5 | Report empty |
| F4 | records left as they are when the session has records, ×5 | session's file replaced |
| F4 | records that cannot be renamed are told once, ×5 | `moves` 0 vs 1 |
| F4 | draft becomes the first session followed by a rename, ×5 | directory's file left |
| F4 | draft left as it is when the session has a draft, ×5 | a move warning |
| F4 | draft taken by another editor first is told as no failure, ×5 | a move warning |
| 8 | is told at each follow to its session | 1 vs 2 |
| 8 | is not replaced by what is typed while Input follows its session | typed text in the file |
| 8 | tells at the first change after the follow, once, that Input's text is not saved | `unsaved` 0 vs 1 |
| 8 | lets an emptied Input take the next session draft, writing nothing | `kept` 1 vs 0 |
| 8 | a held session whose draft cannot be read keeps it from what is typed | typed text in the file |

The three F1 cases: RM-1 was seen red alone, before the fix. RM-2 and RM-3 were written after it, arrived green, and were then run against `199910a`'s draft home, where all three fail (shown above).

The records' two "cannot be renamed" rows above went red before their code. The draft's "cannot be renamed" case arrived green, as described below.

**Arrived green**, each with the mutant that kills it, run on the final tree:
- "removed between the link and its removal", both homes: written ahead in the same unit. Killed by F3-*-nlink.
- Records "taken by another editor first", where links are refused: killed by F4-report-enoent-fails.
- Draft "that cannot be renamed is told once", ×5: green on the old code too, because the refused link was itself told. Killed by F4-draft-rename-untold.
- "keeps an edit … with the draft it renamed where links are refused": killed by F5-no-pin-rename.
- Finding 6's three cases (twice in one hold with an edit; a quit in the window; an unreadable draft empties Input): killed by MX3, MX16a and MX5a.
- "keeps what was typed for its session in Input at the next follow": spent by "is not replaced…". Killed by F8-write-unguarded.
- "tells again, at the first change after each follow": killed by F8-told-never-reset.
- "saves an emptying of Input whose save failed once the disk is freed": built for the survivor F1-empty-clears, which it kills.
- "of the working directory, before any follow, is replaced by the first change": built for the survivor F8-restore-marks-directory, which it kills.

**Not adopted literally:**
- RM-5: under the ruling, its second follow keeps the typed text in Input and reads nothing, so its `reads = 2` no longer holds. Its two claims are the first two finding-8 cases.
- RM-13 (finding 7): ruled a LIMITS entry.

### Mutants (each its literal edit from a pristine copy, one at a time, against its home's session test file and, while it survives, the covering files; Neovim 0.12.5)

The runner is `.tests/t36f2/mutate.py` in the worktree, with every literal edit; its rows are in `.tests/t36f2/mutants.txt`. 61 mutants:
- **The re-measure's 19**: ti-R5, ti-R7, ti-R9, ti-D6a, ti-D8a, ti-D10, ti-D11a; MX3, MX5a, MX6, MX9, MX10, MX15, MX16a, MX17; POISON-D, POISON-R, NOOP-D, NOOP-R. They are literal where the edit still applies.
  - MX5 is adapted: the follow's read warning is `warn()` now.
  - MX16 is adapted: the quit save shares `save_pending_change_now()`, so its edit is `watch.file = nil` before that call.
  - 17 were killed by assertion. POISON-D and POISON-R crash, as meant. NOOP-R has 39 assertions and 2 crashes.
  - **ti-R5 and ti-D6a survive** the session file and every covering file. They have had no separating input since the first round, as disclosed then.
- **This round's 42:**
  - F1 ×2;
  - F3 ×8: `ENOENT` ignored, the link always given up, the link never given up, the give-up's failure untold, each in both homes;
  - F5 ×3;
  - F2 ×2;
  - F4 ×18: each of the five codes dropped, no fallback, no look, `ENOENT` a failure, and the rename failure untold, each in both homes;
  - finding 8 ×9: F8-read-told-once, F8-swap-unmarked, F8-restore-unmarked, F8-restore-marks-directory, F8-told-never-reset, F8-told-every-change, F8-write-unguarded, F8-empty-refused, F8-change-unguarded.
- On the first run, 40 of the 42 were killed by assertion.
  - F1-empty-clears and F8-restore-marks-directory survived all three draft files.
  - The two cases above were built for them, and each is now killed by assertion.

**Totals on the final tree:** 59 of 61 killed. The 2 survivors are ti-R5 and ti-D6a.

The source files are the same at `8b97d8a`, where the full run was made, and at the head. Only `7becb7d` adds the two draft cases, and every killing case is still in the file. ti-D6a was re-run on the final draft file and still survives; the report files did not change.

### Suites, lint, merges

- Touched files, final tree: `test_draft_sessions` 71, `test_report_sessions` 46, `test_draft` 41, `test_entry_draft` 17, `test_doc` 44. Each has `Fails (0)`.
- `make lint`: clean.
- Merge checks, on `8b97d8a`. The code and help are final there; the later commits add test cases and this note.
  - `git merge-tree --write-tree` with `origin/feature/t35-session-switch` (`83a5029`) gives `d11da13`, clean.
  - With `origin/feature/t37-changes-sessions` (`0442ade`) it gives `0c5031f`, clean.
  - `tests/test_doc.lua` on each merged tree: 44 cases, `Fails (0) and Notes (0)`.
- **Whole suite** (`make test`, once, on `7becb7d`, `NVIM v0.12.5`): 2046 cases in 62 groups, `Fails (0) and Notes (0)`, exit 0. That is the first round's 1981 plus this round's 41 draft and 24 report cases. The push adds only this note to that tree.

### Not done

- ti-R5 and ti-D6a: still no separating input.
- `give_up_link_taken_meanwhile()` keeps a link that is the file's only name without re-pinning a waiting buffer to it. That needs the directory's file deleted by hand, between two syscalls, during a textlock window.

## Commits

*Recorded after the merge.*
