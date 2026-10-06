# 2026-10-05 — T25 Changes pane

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t25-changes-pane` · **Pull request:** into `dev` (a regular packet)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (D19, D22, C15, C13, C12, C9, C2, C3, D18, D21; D26, D29)
- [[Implementation/Waves/00007-panes/plan]] › *Packet T25 — 2026-10-06*, its brief `brief-t25-changes-pane.md` with its *Amendment — 2026-10-05* (the user's answers to CP1–CP9), and the brief review `brief-review-t25-t26.md`
- `Implementation/Waves/00007-panes/evidence/t25-probes.txt` (L, F, S, N, CP8)
- [[Sessions/2026-09-27 — T23 git home]] (the git home this packet calls; *Minimum git*) · [[Sessions/2026-10-05 — T24 Panes]] (*The seam for T25*)

## What was done, and why

T25 fills the changes pane T24 built around placeholders: D19's lists and Enter, D22's refresh on every commit. The content lives in a new home, `lua/aineo/changes/` (C15, CP1 (a)), which requires `aineo.git` alone; the composition root wires it to the layout.

- **The home** (`lua/aineo/changes/`): `init.lua` (the session: its repository, base, save marks, the watch and the reads, Enter), `lines.lua` (pure: each window's page for what the session knows), `pages.lua` (writing a page into a buffer, the cursor kept on its entry), `scratch.lua` (named scratch buffers, the namesake and `:edit` traps), `diffs.lua` (the diff buffers and the 1 MiB cut), `serial.lua` (one read at a time). Its surface: `begin_session()`, `pane_buffers()`, `refresh_shown_pane()`.
- **The layout** (`lua/aineo/layout/init.lua`): one export, `show_diff()`, built on `place_in_file_column()`; `window_taking_files()` also takes a window showing a diff it showed (CP3 (a)); the `state` table keeps those diffs, which the predicate reads.
- **The composition root** (`plugin/aineo.lua`): the placeholder functions are gone; `changes_pane()` hands the home's buffers and refreshes a shown pane; `started_claude_terminal()` begins the session after `start_session()` returns.
- **The help**: requirements (git 2.36), the Panes bullet, a new *The changes pane* section (`*aineo-changes*`), the file column, and LIMITS.

## Decisions & reasoning

CP1–CP9 are the user's (2026-10-05), built as the amendment records them. The rest are the implementer's, for the review:

- **A commit that changes no file, in the D22 case, is made with `commit-tree` and `update-ref`.** Measured (`t25-probe-index.lua`, scratch): `git commit --allow-empty` rewrites the index, so the watch reports `files_changed` with it and K4 (commits read only on `files_changed`) survived that case. The case now moves the branch with no index write, which is what D22 asks the watch to see.
- **One read at a time is pinned by counts, not sleeps.** The serializer asks again inside the ended read's own callback, so the git home spy's count of calls, read the moment the third answer is counted, already holds any extra read (S4 killed).
- **The first repository found is the session's for the editor's life**, a look queued behind the one that finds it included (S10).
- **A watch failure is kept apart from the reads' failures** (`watch_failure`), so that a read meanwhile does not clear the line while no watch runs.
- **A diff of the same name is written again in the buffer already showing it**, rather than wiped and made anew: wiping it closed the middle column's window and opened another (the entry case `keeps the diff's window`).
- **Errors raised while a diff is shown are told once** (`could not be shown: …`), and an unreadable diff is told once in git's words, so no error of the home's reaches the user as a callback's. *Corrected by the fix round:* this was false until then — a pane buffer wiped, or unloaded by `:bdelete`, made the next read raise from its callback (attack F1, records 1). *Corrected again by the second fix round:* it was still false after the first — a list read or Enter's diff answering while textlock holds (an `<expr>` mapping waiting in `getcharstr()`, a `'completefunc'` waiting in `vim.wait()`) raised `E565` from a `vim.schedule` callback, a stack trace for the user, the pane left modifiable and stale (the re-measure's finding 1). It holds from the second fix round on, for every error Neovim raises for textlock; any other error a write raises is raised again on purpose, so that a programming error is told (*Fix round 2 — 2026-10-06*).
- **With none of the layout's windows open, a diff opens above the current window**; with no room anywhere (E36, from a split above or a new file column) nothing is shown and Enter warns in its own words.

## Readings for the MVP review

- The files window's line is `<mark> <letter> <path>`: `*` for a file saved, a blank otherwise; `A M D R T ?` as `git status --short` writes them; a rename `old → new`.
- A path holding a control character, a double quote or a backslash is quoted as git's `core.quotePath` quotes it, characters outside ASCII kept as they are.
- With nothing changed the files window says `No files changed on this session` (D19 names only the commits window's words).
- The words of the other states: `aineo is reading the repository`; `Not in a git repository: <directory>`; `git was not found: <git's start error>`; `The last refresh failed: <git's words>`; `The session's base, <id>, is no longer behind HEAD`; `Subdirectories are not watched: their changes show at the next showing of this pane, save or commit`; `aineo cut this diff at 1 MiB: <n> of its <m> bytes are shown`; `aineo: the middle column has no room for the diff of <path | commit id>, which is not shown`.
- Abbreviated ids are 7 characters; the commit diff buffer is named by the full id, `aineo://commit/<id>`.
- "Whenever it is shown" (CP6) is read as whenever a pane buffer enters a window, plus `\o` while the pane is shown, plus — from the fix round on — `\pc`, `<Plug>(aineo-pane-changes)` and `:Aineo pane changes` while the changes pane already shows (the user's CP6 answer names them). Both buffers entering their windows in one turn of the main loop are one showing: each list is read once (the fix round, attack N1).
- A save while there is no repository looks again but is not marked: saves count from the base (CP9). A save made while the first look for the repository runs is marked once it is found (the fix round, attack F7).
- Not in a repository, both windows say `Not in a git repository: <directory>` and then `git: <git's words>`, which tell a repository git refuses — of another owner, or a bare one — from none (the fix round, attack F3).
- Enter pressed again before a diff is read shows only the last Enter's diff (the fix round, attack F4).

**The orchestrator's readings, carried from the brief** (*What was decided already*; missing from this note until the fix round, records 4):

- The session's repository is Claude Code's working directory's at the first start, for the editor's life, whatever `:cd` does later and whatever directory a later restart of Claude Code runs in (CH1, CH10).
- A first start that fails takes no base (CH1). As built and measured (records 2): a start aineo cannot make — `claude.cmd` not executable — takes none; a Claude Code that starts and then exits takes one.
- The buffer names stay T24's (CH8); the diff buffers are named `aineo://diff/<path>` and `aineo://commit/<id>`, are wiped once hidden, and Enter ten times leaves one (CH9).
- The files window's line: a mark, the kind as git's status letter (`A`, `M`, `D`, `R`, `T`, and `?` for untracked), the path, and `old → new` for a rename; the commits window's: the abbreviated id and the subject.
- Files in git's order, commits newest first.
- The mark lasts the editor's life (CH3); a partial write (`FileWritePost`) and an append (`FileAppendPost`) count as saves, and are marked.
- A copy shows as `added`, as T23 left it: the git home has no `copied` kind. **This closes T23's open thread on the copied kind.**
- A diff already shown when its file or the branch changes stays as it was until Enter is pressed on its line again: the refresh reads the two lists, not the diffs shown.
- A refresh keeps the cursor on its entry (CH5).
- Both windows say so outside a repository and when `git` is not found (CH7).
- No health check line for `git`: C7's row does not list one, and the pane says so itself (CH7).

## Unit list (stated before the first test)

`.claude/local/orchestrator/t25-units.md` in the worktree: U1–U26 (the home), L1–L4 (the layout), E1–E9 (the entry), and the help. Units added on the way, each with a case: the guard keeping the first repository found, the watch that cannot start, the watch failure kept through a read, the diff written again in its window, an error raised while a diff is shown, the layout with no window and with no room for a file column.

## Red and green

**Seen red (45):** `tests/test_changes.lua` 36 — U1 (module not found), U2 (`  R there.txt`), U3 and U4 (`{ "" }`), U6, U10, U18, U5a and U5b, U12 (overlapping `start`s in the stand-in's log), U13 (cursor `{3,4}`), CP7 (`changed_files 1`), CH7 not a repository, CP9 shown again and saved, CP5 kept list and the commits', the failed watch, CP4, the four `:edit` cases (`buflisted true`), U8 `:write`, partial write and append, the symbolic link, the save where the watch misses it, Enter on a file (no diff shown) and on a commit (`attempt to index local 'change'`: the missing commit path), no room naming a file, an unreadable diff, a refused diff, the watch at quit (`{2, 2}`), the two cuts (`count 11000`, `count 1`). `tests/test_layout_diffs.lua` 4 — `show_diff` missing, a file opened later (5 windows), no room for a file column (E36 raised), the layout closed (`Invalid 'win'`). `tests/test_entry_changes.lua` 4 — the first start (the placeholder line), the restart (`No commits`), `\o` (after its rework), Enter again (window 1005 for 1004). `tests/test_doc.lua` 1 — `E149: No help for aineo-changes`. `tests/test_entry_panes.lua`: its eleven placeholder pins failed against the new code (`aineo does not list …` against the lists) before they were rewritten.

*Corrected by the fix round (records 5):* of the 29 below, **13 had their code written before their case**, against `tdd` §2 and under none of its sanctioned deviations: the nine marked "written ahead" — the first look's base kept (S10), a failed watch kept through a read (S8), a watch that cannot start (S11), `:bdelete` ×2 (S12), the namesakes ×4 (S13, S14) — and four marked "written with" another case: git not found (S9), the failure line alone (S7), no room naming a commit (S18), another error raised (S23). And `tests/test_entry_panes.lua`'s eleven rewritten pins were seen red only in their old form, against the new code; in their new form they were written after the code and never seen red. They count as arrived green: K10 killed the four `:edit` pins (above); the other seven are killed by MP1, and MP2 survives all seven (*Fix round — 2026-10-06*, *Mutants*; corrected by the second fix round, the re-measure's finding 5).

**Arrived green (29), each with its killer run:** in `tests/test_changes.lua` — shown first starts both reads (U1's code read at the find; S1); every file new before the first commit (the git home's nil base; S6); a subdirectory change once shown again (CP7's `pane_shown()`; S2); a commit that changes no file (U10's `follow_change()`; K4 after the case's rework); never on a timer (by nature; K21); git not found (written with the not-a-repository case, never run before the code; S9); the first look's base kept (the guard written ahead; S10, 3/3); the failure line alone (written with the kept-list case; S7); a failed watch kept through a read (written ahead; S8); a watch that cannot start (written ahead; S11); `:bdelete` (2) and the namesakes (4) (written ahead with the `:edit` refill; S12, S13, S14); `:write` to another file (U8's `match`; K3); a save before the session (by nature; S3); Enter on nothing (U22's guard; S15); the diff buffer's options (U22's `diff_buffer()`; K7); ten Enters (freeing the name; S16); no room naming a commit (written with the file's; S18). In `tests/test_layout_diffs.lua` — the file's window taken (`place_in_file_column()`; K17); above a file that cannot leave (T24's placement; S24); no room above it (`open_window_above()`'s nil; S25); another error raised (written with the E36 handling; S23). In `tests/test_entry_changes.lua` — a failed start (the call placed after `start_session()`; K2); ten showings (by design; S29, S31); Enter in the middle column (the pieces composed; K6, K16).

## Mutants

Every row's edit is literal; each was applied from a copy of the file, run on a copy of the test file narrowed to the named cases (`.tests/t25-<id>.lua`), and the file restored. All the plan's K1–K25 (with K13b and K20b) were run.

| id | file | literal edit (old → new) | run on | result |
|---|---|---|---|---|
| K4 | lua/aineo/changes/init.lua | `if change.branch_moved then read_commits()` → `if change.files_changed then read_commits()` | test_changes.lua › empty-commit case, with `git commit --allow-empty` | SURVIVED: measured, that commit rewrites the index (t25-probe-index.lua), so the watch says files_changed too; case reworked to commit-tree + update-ref |
| K4 | same | same | test_changes.lua › 'nor the index' | killed (assertion: commits window lacked `Nothing`) |
| K23 | init.lua | `follow_repository()` in the find's answer → `watch() read_files() read_commits()` | 'until it is first shown' | killed (assertion: changed_files 1, expected 0) |
| S1 | init.lua | BufWinEnter `callback = function() pane_shown() end` → `function() end` | 'the first time it is shown' | killed (assertion: files window still reading) |
| S2 | init.lua | `pane_shown()`: `session.shown = true` → `if session.shown then return end session.shown = true` | 'once shown again' | killed (assertion: files window kept `No files changed`) |
| K22 | lines.lua | `local text = view.unwatched_subdirectories and { M.NOT_WATCHED } or {}` → `local text = {}` | 'says once, above' | killed (assertion) |
| K3 | init.lua | `note_save(event.match)` → `note_save(vim.api.nvim_buf_get_name(event.buf))` | 'not the buffer' (3 params) | killed (assertion, 3 of 3) |
| K13 | init.lua | `{ 'BufWritePost', 'FileWritePost', 'FileAppendPost' }` → `{ 'BufWritePost' }` | 'not the buffer' | killed (assertion: part, log) |
| K13b | init.lua | `{ 'BufWritePost', 'FileWritePost', 'FileAppendPost' }` → `{ 'BufWritePost', 'FileWritePost' }` | 'not the buffer' | killed (assertion: log) |
| K14 | init.lua | `local top = resolved(session.repository.top) .. '/'` / `local file = resolved(written)` → `session.repository.top .. '/'` / `written` | 'symbolic link' | killed (assertion) |
| S3 | init.lua | a module-level `BufWritePost` recording resolved saves from `require` on, merged into `session.saved` as the base is taken (t25-m-S3.*) | 'before the session began' | killed (assertion: `* M notes.txt`) |
| K5 | serial.lua | the guard `if running then asked_again = true return end` removed | 'one at a time' | killed (assertion: overlapping `start`s in the log) |
| S4 | serial.lua | `asked_again` a count: each ask meanwhile runs once more (t25-m-S4.*) | 'one at a time' | killed (assertion: 4 calls at the third answer, expected 3) |
| K21 | init.lua | after `watch()` in `follow_repository()`, a `vim.uv` timer reading both lists every 2 s (t25-m-K21.new) | 'never on a timer' | killed (assertion: 2 calls at the first answer, expected 1) |
| S5 | pages.lua | the cursor put back (`if line then nvim_win_set_cursor(...) end`) → `_ = line` | 'keep the cursor' | killed (assertion: cursor {3,4}, expected {4,4}) |
| S6 | init.lua | `session.base = repository.head` → `session.base = repository.head or 'HEAD'` | 'before the first commit' | killed (assertion: window kept reading) |
| K20 | init.lua | `session.changes = changes or session.changes` → `session.changes = changes` | 'keeps the list shown' | killed (assertion: the list gone under the line) |
| K20c | init.lua | `session.commits = commits or session.commits` → `session.commits = commits` | 'of the commits keeps' | killed (assertion) |
| S7 | lines.lua | files window, no list: `return view.failure and page({}, {}, notes[1]) or page(notes, {}, M.READING)` → `return page(notes, {}, M.READING)` | 'line alone' (written with the kept-list case, never run before the code: no red seen) | killed (assertion) |
| S8 | init.lua | `watch_failed()`: `session.watch_failure = failure` → `session.files_failure = failure; session.commits_failure = failure` (the form before its test) | 'stays told' | killed (assertion: the line gone after a read) |
| K20b | init.lua | `watch_failed()`: `session.watch.stop(); session.watch = nil` → `session.watch.stop()` | 'started again the next' | killed (assertion: the line kept, no new watch) |
| K8 | init.lua | `commits_page()` under no repository → `lines.commits_window({ since = { commits = {}, base_is_ancestor = true } })` | 'both windows say so' | killed (assertion, 2 of 2: `No commits on this session`) |
| S9 | lines.lua | the `no_git` branch of `no_repository()` removed | 'both windows say so' (git-not-found case written with the first, not seen red) | killed (assertion) |
| K25 | init.lua | `look_again()`: `if session.absence then find()` → `if false then find()` | 'made since', 'a save looks again' | killed (assertion, 2 of 2) |
| S10 | init.lua | `find`'s answer: `if not session.repository then` → `if true then` | 'keeps the base the first look' (first form) | SURVIVED 3/3: the case asserted before the third look answered; reworked to wait for it and for every read after it |
| S10 | same | same | 'keeps the base the first look' (reworked) | killed 3/3 (assertion: `No commits on this session`); the kill rests on commit `Second` landing within the stand-in's 1 s sleep |
| S11 | init.lua | `watch()`: `if failure then watch_failed(failure)` → `if false then watch_failed(failure)` | 'cannot start is told' (code written ahead of its case) | killed (assertion) |
| K18 | lines.lua | `commits_window()`: after the no-list branch, `if not view.since.base_is_ancestor then return page(notes, {}, M.NO_COMMITS) end` | 'no longer behind' | killed (assertion: `No commits on this session` where git lists `Add other`) |
| K19 | init.lua | the commits read, when `base_is_ancestor` is false: `session.base = <HEAD by rev-parse>; read_files()` (t25-m-K19.new) | 'no longer behind' | killed (assertion on the commits window; the files window's expectation is met by the read before the mutant moves the base) |
| K10 | scratch.lua | the `BufReadCmd` refill removed | ':edit' cases, 4 params | killed (assertion, 4 of 4: buflisted true) |
| S12 | init.lua | `pane_buffers()`: `if not (buffers.X and vim.api.nvim_buf_is_loaded(buffers.X))` → `if not buffers.X`, for both | ':bdelete' cases (written after the code) | killed (assertion, 2 of 2: no new buffer) |
| S13 | scratch.lua | `free_name()`: `if vim.bo[buffer].modified then` → `if true then` (every namesake kept, unnamed) | 'gives the name up' (written after the code) | killed (assertion, 2 of 2) |
| S14 | scratch.lua | `free_name()`: `if vim.bo[buffer].modified then` → `if false then` (a typed namesake wiped) | 'keeps the text the user' (written after the code) | killed (assertion, 2 of 2: `'wiped'`) |
| S15 | init.lua | `open_entry()`: the entry of the line under the cursor, or else of the line below it | 'lists nothing does nothing' | killed (assertion: 2 diff reads, expected 1) |
| K7 | diffs.lua | `write_diff()`: `vim.bo[buffer].modifiable = false` removed | 'read-only scratch buffer' | killed (assertion: modifiable true) |
| S16 | diffs.lua | the diff buffer's name `name` → `name .. '#' .. vim.uv.hrtime()` | 'ten times on the same' | killed (assertion: names differ) |
| K24 | diffs.lua | `diff_lines()`: `local shown = shown_part(diff)` → `local shown = diff` | 'within 1 MiB', 'one long line' | killed (assertion, 2 of 2: count 11000 / 1) |
| S17 | diffs.lua | `shown_part()`: the cut on a character's edge → `diff:sub(1, SHOWN_BYTES)` | 'one long line' | killed (assertion: the first line ends in half an `é`) |
| S18 | init.lua | `told_name()`: the commit's branch removed, `lines.quoted_path(entry.key)` for both | 'naming the commit' (branch written with the file's, ahead of its case) | killed (assertion: the full id named) |
| K15 | init.lua | the warning → `('aineo: the file column has no room for %s, which stays where it was opened'):format(vim.fn.fnamemodify(diff_name(entry), ':t'))` | 'with no room' | first edit read the wiped buffer and raised (not counted); corrected edit killed (assertion, 2 of 2) |
| S19 | init.lua | `show_diff()`: the wipe of the unshown diff (`nvim_buf_delete(buffer, { force = true })`) → `_ = buffer` | 'keeps no diff' | killed (assertion: the buffer kept) |
| S20 | init.lua | the failed diff read: the `vim.notify(...)` call removed, `return` kept | 'cannot be read' | first edit did not parse (not counted); corrected edit killed (assertion: no message in time) |
| K17 | layout/init.lua | `show_diff()`: with a window that may take files, `open_window_above(diff, column_window)` instead of `place_in_file_column()` (t25-m-K17.new) | test_layout_diffs 'can leave it' | killed (assertion: another window) |
| K12 | layout/init.lua | `window_taking_files()`: `and (is_file(buffer) or state.diffs[buffer] == true)` → `and is_file(buffer)` | test_layout_diffs 'gives its window' | killed (assertion: 5 windows) |
| S23 | layout/init.lua | `show_diff()`: `if not tostring(window):find('E36:', 1, true) then` → `if false then` (every error swallowed) | 'raises the error a window' (written with the E36 handling) | killed (assertion) |
| S24 | layout/init.lua | `can_leave()` → `return true` | 'opens above a file that cannot' | first run failed by E37 raised (not counted); case reshaped to pcall; killed (assertion) |
| S25 | layout/init.lua | `show_diff()`: `return window` → `return window or current` | 'no room above' | killed (assertion: a window, expected nil) |
| S26 | layout/init.lua | `show_diff()`: `if has_any_window() then` → `if true then` | 'all closed' | killed (assertion: shown false) |
| K1 | changes/init.lua | `begin_session()`: the guard `if session then return end` removed (every start a new session) | test_entry_changes 'outlives a restart' | killed (assertion: `No commits on this session`) |
| K2 | plugin/aineo.lua | `begin_session({...})` moved from after `start_session()` to before it | 'start that fails' (first form: died at the find's wait, the spy installed late; case reshaped) | killed (assertion: the commit listed) — *corrected by the fix round:* this kill was a race, the child's git reading `HEAD` before the test's commit; the test review measured K2 surviving 12 of 12 runs with the child's git behind a shell script. K2FIX (the fix round) counts the looks the failed start asks for, and kills it without a race |
| K6 | plugin/aineo.lua | the `show_diff` handed to the home: `return require('aineo.layout').show_diff(diff)` → `vim.api.nvim_win_set_buf(0, diff); return vim.api.nvim_get_current_win()` | test_entry_changes 'in the middle column' | killed (assertion: the pane's window shows the diff) |
| K16 | plugin/aineo.lua | the same callback moves the cursor to the diff's window (`nvim_set_current_win(window)`) | 'in the middle column' | killed (assertion: current window the diff) |
| S27 | diffs.lua | `diff_buffer()`: the reuse `elseif vim.api.nvim_buf_get_name(existing) == name then` → `elseif false then` | 'keeps the diff' | killed (assertion: another window) |
| S28 | changes/init.lua | `refresh_shown_pane()`: `if is_shown(buffers.files) or is_shown(buffers.commits) then` → `if false then` | test_entry_changes 'restores the layout' (first form passed without the code: a queued read raced the exclude write; case reshaped to wait for every read) | the case's first form **survived** S28; killed (assertion) by the reshaped form |
| K11 | changes/init.lua | the `VimLeavePre` callback's `session.watch.stop()` removed | test_changes 'stops as the editor quits' | killed (assertion: 2 watches running, expected 0) |
| S29 | changes/init.lua | `follow_repository()`: `if not session.watch then watch() end` → `watch()` | test_entry_changes 'shown ten times' | killed (assertion: 40 watches, expected 4) |
| S31 | changes/init.lua | `pane_shown()`: an autocommand made at each showing | 'shown ten times' | killed (assertion: 327 autocommands, expected 309) |
| K10 | scratch.lua | the `BufReadCmd` refill removed | test_entry_panes :edit cases, 4 params | killed (assertion, 4 of 4) |
| S32 | changes/init.lua | `show_diff()`: `pcall(session.settings.show_diff, buffer)` → `true, session.settings.show_diff(buffer)` | 'error a window raised' | killed (assertion: nothing told) |
| K9 | lines.lua | `quoted_path()`: `if not path:find(NEEDS_QUOTING) then` → `if true then` (every path raw) | 'quotes a path holding' | killed (assertion: the list never written, Neovim refusing the line break) |

## Verification

On Neovim 0.12.5 and git 2.50.1 (macOS):

- `make test`: 1676 cases, `Fails (0)`, **216 s on `d9debd1`**, the head pushed; 217 s on `eefd0b0`, the same code (corrected by the fix round, records 10: this line gave 217 s for the pushed tree). Baseline `c599679`: 1602, 201 s. No case outside the boundary was made slow or flaky in that run.
- Each file's own run: `tests/test_changes.lua` 58 cases in 29 s; `tests/test_entry_changes.lua` 7 in 29 s; `tests/test_layout_diffs.lua` 8 in under 1 s; `tests/test_entry_panes.lua` 86 in 83 s — against **24 s on `origin/dev`** (the test review, finding 5; 23 s in the fix round's own run of `origin/dev`'s tree); the fix round brought it to 8 s; `tests/test_layout_file_column.lua` 57 and `tests/test_layout_panes.lua` 38 unchanged and green.
- `make lint`: StyLua and selene clean.
- `grep -rnE "require\(['\"]aineo\.[a-z_]+\." lua plugin tests scripts` prints only each home's requires of its own files; `aineo.changes` requires `aineo.git` and its own files alone, and `aineo.layout` requires no `aineo.git`.

## Fix round — 2026-10-06

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`), a fresh agent on the orchestrator's fix-round brief (resource `impl_t25_fix`). Its boundary was the brief's, widened to `plugin/aineo.lua`'s pane action (item 2) and to the whole of `tests/test_entry_panes.lua` (item 17).

The three reviews of PR #112 — attack, test integrity, records — each found defects or gaps; every fix below was redone red first in the project's own files, from the reviewers' failing inputs, not their patches.

### What changed, and why

- **A pane buffer gone** (attack F1, records 1): a buffer of the pane wiped, or unloaded by `:bdelete`, made the next read raise from its callback (`Invalid buffer id`, `Buffer is not 'modifiable'`) and, since the read ended only after writing, froze that list for the editor's life. The home writes a buffer only while it is loaded (`is_writable()`), and each of its three one-at-a-time reads — the files, the commits, the look for the repository — ends before it shows what it found. *Decisions & reasoning*' claim that no error of the home's reaches the user as a callback's was said here to be true from this round on; it was not, under textlock, until the second fix round (*Fix round 2 — 2026-10-06*).
- **`\pc`, `<Plug>(aineo-pane-changes)` and `:Aineo pane changes` with the pane shown** read it again (attack F6, records 3, the author's spec conflict 3; the user's CP6 answer): the composition root's `show_pane()` calls `refresh_shown_pane()` first.
- **A repository git refuses** — of another owner (`safe.directory`), or a bare one — adds git's own words under the not-a-repository line (attack F3). T23's mapping of exit 128 to `not_a_repository` stays (*Open threads*).
- **Enter pressed again before a diff is read** shows only the last Enter's diff (attack F4, CP2).
- **A diff that opens the file column** puts the layout's thirds back, as a file does (attack F5, CP3): `show_diff()` calls `keep_proportions()`.
- **No undo history** in the pane's buffers or the diffs (attack F2): `'undolevels'` `-1` in `make_scratch()`.
- **A save made while git first looks for the repository** is marked once it is found (attack F7, CP7); saves made while no repository is found still mark nothing (CP9).
- **One showing reads each list once** (attack N1): both buffers entering their windows in one turn of the main loop are one showing, followed at the next turn (`pane_shown()` schedules once). The case *a failed watch that cannot start* now waits for the watch to be asked for before it puts `.git` back, since the watch starts at that next turn.
- **`tests/test_entry_panes.lua` 83 s → 8 s** (item 17). The cause is not the working directory: a child that quits within some 50 ms of `:Aineo open` quits at once, because the fake Claude Code has not started yet, while one that lives longer meets aineo's quit-time stop by keys — 2.5 s + 0.3 s + the fake's emulated 1.6 s exit, measured 4.40–4.41 s from the checkout and from a fixture directory alike (`t25fix-quit-probe.lua`: 12 ms at 0 ms, 4 405–4 408 ms at 50, 200 and 1 500 ms). On `origin/dev` 4 of the file's 86 cases lived that long, on T25's head 14, since T25's cases wait for git to list the pane (per-case restart times on both trees). Each case's child now ends its terminals' processes by a hangup before it is stopped, and the file makes its fixture repository once, since no case changes it.
- **The test review's pins** (items 9–16): FIXB, FIXA, the CP4 case re-read, FIXD with K23d's timer count, FIXC, CP5c, CH8w, K2FIX and S10 gated by files — each green, each seen red against its mutant.
- **Records** (items 18–22): the help corrected (a start aineo cannot make takes no base, one that starts then fails does; the quoting; the save mark; Enter again; git's words; LIMITS' "rewritten with its own content"), `lines.files_window()`'s docstring, this note, the PR body. The fix commit's message names two claims of earlier messages as wrong: `eefd0b0` calls git 2.36 "measured", but T23 read it in git's source and only git 2.50.1 was ever run; `6cf587c` says `commit-tree` with `update-ref` is "the only way" to tell K4 apart, but `git reset --soft` does not write the index either.

### Unit list (stated before the first test)

U1 a pane buffer gone as its list is read; U2 a write that raises does not stop the reads after it; U3 no undo history; U4 git's words for a refused repository, and the four CH7 cases' wording; U5 Enter twice; U6 a save during the first look; U7 the test review's pins; U8 the thirds; U9 the user's window options in a diff's window; U10 `\pc` while shown; U11 one read per showing; U12 K2FIX; U13 `test_entry_panes.lua`'s time; then the records.

### Red and green

**Seen red (20)**, each for its intended reason before its code:
- `tests/test_changes.lua` — *gone as its list is read* ×4 (`every read answered` never in time: the read's callback raised on the gone buffer); *refuses its list once* (`No files changed on this session` for `* M notes.txt`: nothing read after the refused write); *keeps no undo history of the lists* (`{ 5, 1 }` for `{ 0, 0 }`); *keeps no undo history of the diff* (`1` for `0`); the six `outside a repository` cases with git's words (key 2 `nil`: the CH7 wording red first, then the owner and the bare repository); *twice in quick succession* (`{ b, a }` for `{ b }`); *while git first looks* (`  M notes.txt` for `* M notes.txt`).
- `tests/test_layout_diffs.lua` — *a third each* (`{ 40, 20, 18, 18 }` for `{ 26, 26, 26, 26 }`).
- `tests/test_entry_changes.lua` — *reads its lists again while it shows* ×3 (`  ? scratch.log` kept); *shown once reads its files once* (`4` for `3`).

**Arrived green (15)**, each with the reason and its killer, run:
- written with an earlier unit's code: *refuses its commits once* and *refuses what the first look found* (U2's reorder; RB2, RB3);
- the test review's pins, the behaviour already there: *on a file committed since the base* (CH6b), *made before the pane is first shown* (CH3b), *no longer behind HEAD* reworked (K19F, K19, K18), *leave no timer running* (K21, K21x, K21v), *starts no watch … nor a timer to* reworked (K23d), *shows the diff again once a command … emptied it* ×2 (CH8d), *of the commits shows the line alone* (CP5c), *keeps the base the first look found* gated (S10, 3/3), *keeps the user's window options* (CH8w), the failed start's `finds_asked` (K2);
- reworked for this round's own behaviour: *ten times on the same file, each once the last diff was read* (S16, ten buffers), *a failed watch that cannot start* (the author's S11, re-run below).

### Mutants

Each mutant is a literal edit (`.claude/local/orchestrator/t25fix-mutants.lua` in the round's worktree), applied from a copy of the file, run on a copy of the test file narrowed to the cases named, and the file copied back. The test review's mutants are run as its catalog wrote them where their text still occurs; where the round changed the code around one, it is re-anchored and the reviewer's text quoted in the catalog. Every kill is an assertion's (a `wait_until` that never held counts, its cause named).

| id | file | edit | run on | result |
|---|---|---|---|---|
| RA1 | init.lua | `show_files()`: `if session and is_writable(buffers.files) then` → `if session and buffers.files then` | 'gone as its list is read' ×4 | killed 2 of 4, the files cases (assertion: `every read answered` never held, the read's callback raising) |
| RA2 | init.lua | the same for `buffers.commits` in `show_commits()` | same | killed 2 of 4, the commits cases (same) |
| RB1 | init.lua | the files read: `ended()` / `show_files()` → `show_files()` / `ended()` | 'that refuses' ×3 | killed 1 (assertion: `No files changed on this session` kept) |
| RB2 | init.lua | the same in the commits read | same | killed 1 (assertion: `No commits on this session` kept) |
| RB3 | init.lua | the look: `ended()` moved after `follow_repository()`, `show_files()`, `show_commits()` | same | killed 1 (assertion: `Not in a git repository: …` kept) |
| RC | plugin/aineo.lua | `show_pane()`: the `if pane == 'changes' then … refresh_shown_pane() end` removed | test_entry_changes 'while it shows' ×3 | killed 3 of 3 (assertion: `  ? scratch.log` kept) |
| RD | lines.lua | `no_repository()`: the two-line page → `line = 'Not in a git repository: ' .. M.quoted_path(directory)` | 'outside a repository' | killed 6 (assertion: key 2 `nil`) |
| RE | init.lua | `open_entry()`: `if this_enter ~= enters then return end` removed | 'twice in quick succession' | killed (assertion: `{ b, a }`) |
| RF | layout/init.lua | `show_diff()`: `keep_proportions()` removed | test_layout_diffs 'a third each' | killed (assertion: `{ 40, 20, 18, 18 }`) |
| RG | scratch.lua | `vim.bo[buffer].undolevels = -1` removed | 'keeps no undo history' ×2 | killed 2 of 2 (assertion: `5`, `1`) |
| RH | init.lua | `note_save()`: `table.insert(session.early_saves, resolved(written))` → `local _ = written` | 'while git first looks' | killed (assertion: `  M notes.txt`) |
| RI1 | init.lua | `pane_shown()`: `if session.following_soon then return end` removed | test_entry_changes 'shown once reads its files once' | killed (assertion: `4` for `3`) |
| CH6b | init.lua | `git.file_diff(session.repository, session.base, entry.change,` → `… 'HEAD', …` (verbatim) | 'committed since the base' | killed (assertion: an empty diff) |
| CH3b | init.lua | `if not session.shown then return end` before `local top = resolved(session.repository.top) .. '/'` (verbatim; the line now lies in `mark_saved()`) | 'before the pane is first shown' | killed (assertion: `  M notes.txt`) |
| K19F | init.lua | the files read from the newest commit listed once the base is not behind (verbatim) | 'no longer behind HEAD' | killed (assertion: `No files changed on this session`) |
| K19 | init.lua | the base moved to the newest commit listed, the files read again (re-anchored before `ended()`) | same | killed (assertion: the commits window) |
| K18 | lines.lua | `end, view.since.commits),` → `end, view.since.base_is_ancestor and view.since.commits or {}),` (verbatim) | same | killed (assertion) |
| K21 | init.lua | a uv timer `start(2000, 2000, …)` reading both lists (verbatim) | 'leave no timer running' | killed (assertion: `uv` 1 for 0) |
| K21x | init.lua | the same at 4 000 ms (verbatim) | same | killed (assertion: `uv` 1 for 0) |
| K21v | init.lua | `vim.fn.timer_start(4000, …, { ['repeat'] = -1 })` (verbatim) | same | killed (assertion: `vim` 1 for 0) |
| K23d | init.lua | `vim.defer_fn(function() if not session.watch then watch() end end, 200)` once found (re-anchored after `session.base = repository.head`) | 'nor a timer to' | killed (assertion: `uv` 1 for 0) |
| CH8d | diffs.lua | `write_diff(made, shown_lines[made] or text)` → `… and {} or text` (verbatim) | 'emptied it' ×2 | killed 2 of 2 (assertion: `""`) |
| CP5c | lines.lua | the commits page before any list → `return page({}, {}, M.READING)` (verbatim) | 'of the commits shows the line alone' | killed (assertion: `aineo is reading the repository`) |
| CH8w | layout/init.lua | `vim.wo[window].wrap = false` once placed (re-anchored before `keep_proportions()`) | test_layout_diffs 'window options' | killed (assertion: `wrap` false) |
| S10 | init.lua | the look's guard `if session.repository then` → `if false then` (the author's `if not session.repository then` → `if true then`, on the reworked guard) | 'keeps the base the first look found', gated | killed 3 of 3 (assertion: `No commits on this session`) |
| K2 | plugin/aineo.lua | `begin_session({…})` moved above `start_session({…})` (verbatim) | test_entry_changes 'start that fails' | killed 3 of 3 (assertion: `finds_asked` 1 for 0, counted as the call is made) |
| S16 | diffs.lua | `named_scratch_buffer(name, …)` → `named_scratch_buffer(name .. '#' .. vim.uv.hrtime(), …)` | 'ten times on the same file, each once the last diff was read' | killed (assertion: ten buffers) |
| S11 | init.lua | `watch()`: `if failure then watch_failed(failure)` → `if false then …` | 'that cannot start is told' (adapted) | killed (assertion: the failure line missing) |
| MP1 | init.lua | `show_files()` and `show_commits()`: `if … then` → `if false then` | test_entry_panes' seven rewritten pins but the `:edit` ones | killed 7 of 7 (assertion: `aineo is reading the repository`) |
| MP2 | init.lua | a pane buffer's fill: `pages.write_page(made, page())` → nothing | same | survived 7 of 7: the reads write the lists after it; MP1 is their killer |

### Verification

On Neovim 0.12.5 and git 2.50.1 (macOS), on `aaa4b14`, the code tree pushed (the commits after it change only this note):

- `make test`: **1701 cases, `Fails (0)`, 212 s** (the first round: 1676 cases, 216 s on `d9debd1`).
- Each file's own run on that tree: `tests/test_changes.lua` 77 cases in 35–41 s; `tests/test_entry_changes.lua` 11 in 48–49 s; `tests/test_layout_diffs.lua` 10 in under 1 s; `tests/test_entry_panes.lua` 86 in **8 s** (twice; 83 s before, 24 s on `origin/dev`); `tests/test_layout_file_column.lua` 57, `tests/test_layout_panes.lua` 38, `tests/test_plugin.lua` and `tests/test_doc.lua` green.
- `make lint`: StyLua and selene clean.
- `aineo.changes` requires `aineo.git` and its own files alone; `aineo.layout` no `aineo.git`; `plugin/aineo.lua` requires `aineo.changes` only inside callbacks.

## Fix round 2 — 2026-10-06

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`), a fresh agent on the orchestrator's second fix-round brief (resource `impl_t25_fix2`), within the first round's boundary. Its input: the re-measure of PR #112 at `58d8610` (attack question, nine findings). Every fix was redone red first in the project's own test files, from the re-measure's failing inputs, not its patches.

### What changed, and why

- **Textlock** (finding 1, medium). A list read or Enter's diff answering while textlock holds — an `<expr>` mapping waiting in `getcharstr()`, a `'completefunc'` waiting in `vim.wait()` — made `nvim_buf_set_lines` raise `E565` from a `vim.schedule` callback: a stack trace for the user, the pane left modifiable and stale, the diff never shown and an orphan buffer left modifiable. `scratch.write_text()` now writes every pane and diff buffer: it catches `E565` alone, always puts `'modifiable'` back to false, and raises any other error again, so a programming error is told rather than retried silently (the re-measure's own limit of its FIXT). A refused list is written again at the next `SafeState`, once per buffer, with what the session knows then (`show_page()`); a refused diff is shown at the next `SafeState` while its Enter is the last still (`show_last_diff()`), and when another Enter came first, the empty buffer made for it is wiped (`diffs.wipe_unshown()`; measured before the fix on this round's tree: bufnr 4, lines `{ "" }`, no window). The help says a list or a diff read while Neovim allows no change of text is shown once it does.
- **`REFUSE_ONE_WRITE`'s three cases stay, re-aimed** (the decision the brief asked for). The textlock path is now pinned on the real triggers, with no stub. The stub's cases remain the only way to make a write fail for another reason — a page holding a line break would, and only a mutant makes one — so they now raise an error that is not textlock's (`FAIL_ONE_WRITE`) and assert what the user is told (the error, once), the buffer between (still the page before it, not modifiable) and the list the next read gives. They are the files and commits reads (parametrized) and the first look; RB1–RB3 kill them.
- **A showing and a quit in one turn** (finding 2): the follow does nothing once `v:exiting` is set (FIXQ), so no watch starts after `VimLeave` or during a later `VimLeavePre`; the help's LIMITS line is true again.
- **The save mark** (finding 3): the help now says a save made during the first look is marked when that look found the repository (CP9); P8 pins it.
- **`:set undolevels=…`** in the pane's window (finding 7): `write_text()` sets `'undolevels'` to -1 before every write, which covers the diffs too; `make_scratch()` no longer sets it.
- **`:Aineo-pane`** (finding 8) and the panes paragraph say a shown changes pane is read again.
- **Records** (findings 1, 4, 5): *Decisions & reasoning* and *Fix round › What changed* no longer say the callback-error claim held from the first round; the first round's mutant table has its five-column header; MP1 alone kills the seven `test_entry_panes.lua` pins, MP2 survives them. The PR body's "the only way found" is corrected: textlock is a real way, and the stub's own docstring named it.

### Unit list (stated before the first test)

U1 the lists under textlock (both holds); U2 Enter's diff under textlock (both holds); U3 a write failing for another reason told, read-only between, the next read listed; U4 a showing and a quit in one turn; U5 `:set undolevels` in the pane's window; then the pins that arrive green: P8 (NM3), P3e (NM6), the user's window options (CH8w, CH8n); then the help and the records. Added while working: the stale retry's empty buffer, and the pins of F1d, F1h and F1j.

### Red and green

**Seen red (11)**, each on this round's base `58d8610` or the round's tree before its code, for its intended reason:
- `tests/test_changes.lua` › *its lists read while textlock holds* ×2 — `modifiable = true` meanwhile and after, `E5108 … pages.lua:40: E565` told, the lists left `aineo is reading the repository`;
- *Enter › read while textlock holds* ×2 — no diff shown, `E5108 … diffs.lua:70: E565` told;
- *failing to take a list read* ×2 and *failing to take what the first look found* — `told = 0` on the round's catch-all tree (the error swallowed and retried at `SafeState`, the list shown meanwhile);
- *the watch › starts on no showing made in the turn the editor quits* ×2 — `{ VimLeavePre, VimLeave, watch started, changed_files asked, commits_since asked }` and `{ VimLeavePre, watch started, …, VimLeave }`;
- *keeps no undo history once :set undolevels runs in its window* — `2` for `0`;
- *Enter › read while textlock holds, then on another file before the editor allows it* — its `kept` assertion, `1` for `0` (the case first arrived green for F1h, below; its assertion of the kept buffer was added red).

**Arrived green (4 new cases, 1 strengthened)**, each with its killer run:
- *the user's saves › made while a first look finds no repository are not marked once one is made* — the code right since CP9; NM3 (`* ? notes.txt`);
- *Enter › twice in quick succession tells nothing of the first Enter's diff failing later* — NM6 (the failure told);
- *Enter › again on a shown diff while textlock holds, then on another file, keeps the diff shown* — written with the wipe's code; F1j (`a = 0` for 1);
- `tests/test_layout_diffs.lua` › *keeps the user's window options in its window*, now with `'list'` and `'number'` set by the user before the layout opens — CH8w and CH8n;
- the textlock lists case, strengthened while green: a second read during the hold, and one `SafeState` autocommand per buffer — F1d (`6` for `2`).

### Mutants

Each a literal edit (`.tests/t25fix2-catalog.lua` in the round's worktree, applied by `t25fix2-apply.lua`, every `old` occurring once), run one at a time from a pristine copy of `lua/` and `plugin/` on a copy of its test file narrowed to the cases named, re-run together on the final code tree (`5a81264`; F1j once more on `1350877` after its case was corrected). Every kill is by assertion.

| id | file | edit | run on | result |
|---|---|---|---|---|
| F1a | scratch.lua | `pcall(vim.api.nvim_buf_set_lines, …)` → the call itself, `written = true` | the textlock lists ×2, failing to take ×3 | killed 5 (`modifiable` true; lists `aineo is reading …`) |
| F1b | scratch.lua | `vim.bo[buffer].modifiable = false` → `= not written` | same | killed 5 (`modifiable` true meanwhile) |
| F1c | init.lua | `show_page()`: `… or refused[buffer] then` → `… or true then` | the textlock lists ×2 | killed 2 (lists not shown) |
| F1d | init.lua | `show_page()`: `or refused[buffer]` removed | same | killed 2 (`waiting` 6 for 2) |
| F1e | scratch.lua | `error(failure, 0)` → `return false` | failing to take ×3 | killed 3 (nothing told; the list shown meanwhile) |
| F1f | init.lua | `show_last_diff()`: `if show_diff(entry, diff) then` → `… or true then` | Enter under textlock ×2 | killed 2 (no diff shown) |
| F1g | diffs.lua | `return written and buffer or nil` → `return buffer` | same | killed 2 (an empty diff handed on) |
| F1h | init.lua | `show_last_diff()`: the stale check and its wipe removed | then on another file | killed (`a.txt` shown and kept) |
| F1i | init.lua | `diffs.wipe_unshown(diff_name(entry))` removed | same | killed (`kept` 1 for 0) |
| F1j | diffs.lua | `wipe_unshown()`: `and #vim.fn.win_findbuf(buffer) == 0` removed | again on a shown diff | killed (`a` 0 for 1); first run crashed the case's own read of a wiped buffer's name — not counted, the case corrected |
| RB1, RB2, RB3 | init.lua | the files read, the commits read, the look: `ended()` moved after the showing | failing to take ×3 | killed 1 each (the next read never listed) |
| F2 | init.lua | the `v:exiting` guard removed (FIXQ reverted) | the quit ×2 | killed 2 (`watch started` logged) |
| F7 | scratch.lua | `vim.bo[buffer].undolevels = -1` removed from `write_text()` | `undo history` ×3 | killed 3 (`{ 5, 1 }`, `5` and `1`, for 0) |
| NM3 | init.lua | `session.early_saves = {}` removed (verbatim) | P8 | killed (`* ? notes.txt`) |
| NM6 | init.lua | the Enter guard before the failure branch removed (the re-measure's first edit, verbatim; its second has no anchor, `show_last_diff()` holding that guard now) | P3e | killed (the failure told) |
| CH8w, CH8n | layout/init.lua | `wrap = false`; `number = false; list = false` once placed (verbatim) | window options | killed (`wrap`, `list` false) |

No survivor.

### Verification

On Neovim 0.12.5 and git 2.50.1 (macOS, load average about 10 from other agents), on the code tree `1350877` (the commit after it changes only this note):

- `make test`: **1712 cases, `Fails (0)`, 211 s.** A first run on the same tree, 215 s, failed one case outside the boundary, `tests/test_health.lua` › *leaves the editor free to wait when Ctrl-C ends a check of a command that writes without end* (`false` for `true`: its `vim.wait(100)` took 1 s or more); that file then passed alone three times out of three, and the second whole run passed. Recorded as a timing case under load, not touched.
- Own runs: `tests/test_changes.lua` 88 cases (77 before: 3 re-aimed, 11 added), `tests/test_layout_diffs.lua` 10, `tests/test_doc.lua` 43, each `Fails (0)`.
- `make lint`: StyLua and selene clean.
- `aineo.changes` requires `aineo.git` and its own files alone (`pages.lua` now requires `aineo.changes.scratch`, inside the home).

## Task lines

The wave holds its marks (rule 6). The line T25 would take:

- [X] T25 — the changes pane (D19, D22), in the new changes home `lua/aineo/changes/` (C15): the session's changed files with the user's saves marked, and its commits or "No commits on this session"; Enter shows a file's or a commit's diff, read-only, in the middle column, the cursor staying in the pane; read again on every showing, save, change and commit, one read at a time; it says so outside a repository and before git answers; CP1–CP9 as the user answered; the help's `*aineo-changes*` — regular.

## Limits

- A git the home is running when the editor quits runs to its end (CH9; the brief review's `b_quit`): the git home's reads give nothing to cancel with. The watch is stopped, and since the second fix round no showing in the quit's own turn starts one again (the re-measure's finding 2).
- `\pc` while the changes pane already shows read nothing until the fix round, whose widened boundary let `show_pane()` read it again.
- The lines a wiped diff showed are dropped the next time a diff is shown; that is not observable through the home's surface, and no case pins it.
- The pane is rendered and tested on macOS only; the Linux path (no subdirectory watched) is tested by handing the git home `system_name = 'Linux'`.

## Open threads

- **The boundary, widened and declared:** `tests/test_entry_panes.lua`'s `pre_case` now `:cd`s every case's child into a fixture repository and gives this file's Neovim T23's git isolation, which every child inherits, a restarted one included. The brief lists only that file's placeholder cases as T25's, while its CH1 (the orchestrator's reading of 2026-10-05) requires every case that shows the changes pane to run in a fixture repository; the second, the later and more specific, won.
- Neovim's framing of an autocommand's error (T24's open thread) stays open; T25's own callbacks catch their errors.
- **T23's mapping of git's exit 128 to `not_a_repository`** (`lua/aineo/git/repository.lua`) also takes a repository git refuses — of another owner (`safe.directory`), or a bare one — as no repository (attack F3). The fix round has the pane add git's words under the line; the mapping itself is T23's, outside T25's boundary, and stays as it is.
- `tests/test_entry_changes.lua` (49 s) meets the same quit-time stop by keys `tests/test_entry_panes.lua` did (*Fix round*); ending its children's terminals before they quit would shorten it too. Not done: outside the fix round's items.
- `tests/test_entry_changes.lua` and `tests/test_changes.lua` spy on the git home's public functions in the child to know when a find or a read has answered; a later reviewer may prefer an observable the user has.

## Commits

*Recorded after the merge.*
