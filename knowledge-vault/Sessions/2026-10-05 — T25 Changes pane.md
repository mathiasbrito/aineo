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
- **Errors raised while a diff is shown are told once** (`could not be shown: …`), and an unreadable diff is told once in git's words, so no error of the home's reaches the user as a callback's.
- **With none of the layout's windows open, a diff opens above the current window**; with no room anywhere (E36, from a split above or a new file column) nothing is shown and Enter warns in its own words.

## Readings for the MVP review

- The files window's line is `<mark> <letter> <path>`: `*` for a file saved, a blank otherwise; `A M D R T ?` as `git status --short` writes them; a rename `old → new`.
- A path holding a control character, a double quote or a backslash is quoted as git's `core.quotePath` quotes it, characters outside ASCII kept as they are.
- With nothing changed the files window says `No files changed on this session` (D19 names only the commits window's words).
- The words of the other states: `aineo is reading the repository`; `Not in a git repository: <directory>`; `git was not found: <git's start error>`; `The last refresh failed: <git's words>`; `The session's base, <id>, is no longer behind HEAD`; `Subdirectories are not watched: their changes show at the next showing of this pane, save or commit`; `aineo cut this diff at 1 MiB: <n> of its <m> bytes are shown`; `aineo: the middle column has no room for the diff of <path | commit id>, which is not shown`.
- Abbreviated ids are 7 characters; the commit diff buffer is named by the full id, `aineo://commit/<id>`.
- "Whenever it is shown" (CP6) is read as whenever a pane buffer enters a window, plus `\o` while the pane is shown; `\pc` while the changes pane already shows changes nothing and reads nothing, since `show_pane()` (outside the boundary) calls nothing then.
- A save while there is no repository looks again but is not marked: saves count from the base (CP9).

## Unit list (stated before the first test)

`.claude/local/orchestrator/t25-units.md` in the worktree: U1–U26 (the home), L1–L4 (the layout), E1–E9 (the entry), and the help. Units added on the way, each with a case: the guard keeping the first repository found, the watch that cannot start, the watch failure kept through a read, the diff written again in its window, an error raised while a diff is shown, the layout with no window and with no room for a file column.

## Red and green

**Seen red (45):** `tests/test_changes.lua` 36 — U1 (module not found), U2 (`  R there.txt`), U3 and U4 (`{ "" }`), U6, U10, U18, U5a and U5b, U12 (overlapping `start`s in the stand-in's log), U13 (cursor `{3,4}`), CP7 (`changed_files 1`), CH7 not a repository, CP9 shown again and saved, CP5 kept list and the commits', the failed watch, CP4, the four `:edit` cases (`buflisted true`), U8 `:write`, partial write and append, the symbolic link, the save where the watch misses it, Enter on a file (no diff shown) and on a commit (`attempt to index local 'change'`: the missing commit path), no room naming a file, an unreadable diff, a refused diff, the watch at quit (`{2, 2}`), the two cuts (`count 11000`, `count 1`). `tests/test_layout_diffs.lua` 4 — `show_diff` missing, a file opened later (5 windows), no room for a file column (E36 raised), the layout closed (`Invalid 'win'`). `tests/test_entry_changes.lua` 4 — the first start (the placeholder line), the restart (`No commits`), `\o` (after its rework), Enter again (window 1005 for 1004). `tests/test_doc.lua` 1 — `E149: No help for aineo-changes`. `tests/test_entry_panes.lua`: its eleven placeholder pins failed against the new code (`aineo does not list …` against the lists) before they were rewritten.

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
| K2 | plugin/aineo.lua | `begin_session({...})` moved from after `start_session()` to before it | 'start that fails' (first form: died at the find's wait, the spy installed late; case reshaped) | killed (assertion: the commit listed) |
| K6 | plugin/aineo.lua | the `show_diff` handed to the home: `return require('aineo.layout').show_diff(diff)` → `vim.api.nvim_win_set_buf(0, diff); return vim.api.nvim_get_current_win()` | test_entry_changes 'in the middle column' | killed (assertion: the pane's window shows the diff) |
| K16 | plugin/aineo.lua | the same callback moves the cursor to the diff's window (`nvim_set_current_win(window)`) | 'in the middle column' | killed (assertion: current window the diff) |
| S27 | diffs.lua | `diff_buffer()`: the reuse `elseif vim.api.nvim_buf_get_name(existing) == name then` → `elseif false then` | 'keeps the diff' | killed (assertion: another window) |
| S28 | changes/init.lua | `refresh_shown_pane()`: `if is_shown(buffers.files) or is_shown(buffers.commits) then` → `if false then` | test_entry_changes 'restores the layout' (first form passed without the code: a queued read raced the exclude write; case reshaped to wait for every read) | killed (assertion) |
| K11 | changes/init.lua | the `VimLeavePre` callback's `session.watch.stop()` removed | test_changes 'stops as the editor quits' | killed (assertion: 2 watches running, expected 0) |
| S29 | changes/init.lua | `follow_repository()`: `if not session.watch then watch() end` → `watch()` | test_entry_changes 'shown ten times' | killed (assertion: 40 watches, expected 4) |
| S31 | changes/init.lua | `pane_shown()`: an autocommand made at each showing | 'shown ten times' | killed (assertion: 327 autocommands, expected 309) |
| K10 | scratch.lua | the `BufReadCmd` refill removed | test_entry_panes :edit cases, 4 params | killed (assertion, 4 of 4) |
| S32 | changes/init.lua | `show_diff()`: `pcall(session.settings.show_diff, buffer)` → `true, session.settings.show_diff(buffer)` | 'error a window raised' | killed (assertion: nothing told) |
| K9 | lines.lua | `quoted_path()`: `if not path:find(NEEDS_QUOTING) then` → `if true then` (every path raw) | 'quotes a path holding' | killed (assertion: the list never written, Neovim refusing the line break) |

## Verification

On Neovim 0.12.5 and git 2.50.1 (macOS), on the tree pushed:

- `make test`: 1676 cases, `Fails (0)`, 217 s (baseline `c599679`: 1602, 201 s). No case outside the boundary was made slow or flaky in that run.
- Each file's own run: `tests/test_changes.lua` 58 cases in 29 s; `tests/test_entry_changes.lua` 7 in 29 s; `tests/test_layout_diffs.lua` 8 in under 1 s; `tests/test_entry_panes.lua` 86 in 83 s; `tests/test_layout_file_column.lua` 57 and `tests/test_layout_panes.lua` 38 unchanged and green.
- `make lint`: StyLua and selene clean.
- `grep -rnE "require\(['\"]aineo\.[a-z_]+\." lua plugin tests scripts` prints only each home's requires of its own files; `aineo.changes` requires `aineo.git` and its own files alone, and `aineo.layout` requires no `aineo.git`.

## Task lines

The wave holds its marks (rule 6). The line T25 would take:

- [X] T25 — the changes pane (D19, D22), in the new changes home `lua/aineo/changes/` (C15): the session's changed files with the user's saves marked, and its commits or "No commits on this session"; Enter shows a file's or a commit's diff, read-only, in the middle column, the cursor staying in the pane; read again on every showing, save, change and commit, one read at a time; it says so outside a repository and before git answers; CP1–CP9 as the user answered; the help's `*aineo-changes*` — regular.

## Limits

- A git the home is running when the editor quits runs to its end (CH9; the brief review's `b_quit`): the git home's reads give nothing to cancel with. The watch is stopped.
- `\pc` while the changes pane already shows reads nothing; reading again then would need `show_pane()`, outside the boundary.
- The lines a wiped diff showed are dropped the next time a diff is shown; that is not observable through the home's surface, and no case pins it.
- The pane is rendered and tested on macOS only; the Linux path (no subdirectory watched) is tested by handing the git home `system_name = 'Linux'`.

## Open threads

- **The boundary, widened and declared:** `tests/test_entry_panes.lua`'s `pre_case` now `:cd`s every case's child into a fixture repository and gives this file's Neovim T23's git isolation, which every child inherits, a restarted one included. The brief lists only that file's placeholder cases as T25's, while its CH1 (the orchestrator's reading of 2026-10-05) requires every case that shows the changes pane to run in a fixture repository; the second, the later and more specific, won.
- Neovim's framing of an autocommand's error (T24's open thread) stays open; T25's own callbacks catch their errors.
- `tests/test_entry_changes.lua` and `tests/test_changes.lua` spy on the git home's public functions in the child to know when a find or a read has answered; a later reviewer may prefer an observable the user has.

## Commits

*Recorded after the merge.*
