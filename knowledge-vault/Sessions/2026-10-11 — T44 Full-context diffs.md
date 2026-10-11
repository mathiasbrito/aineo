# 2026-10-11 — T44 Full-context diffs

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet, A104)
**Branch:** `feature/t44-full-context` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D48, D19, D46, D47, C13, C15, T44
- [[Implementation/Waves/00010-changes-filter/plan]] and [[Implementation/Waves/00010-changes-filter/brief-t44-full-context]] (its *Amendment — 2026-10-11, at dispatch*). The orchestrator's rulings A101–A103, A105–A107, A111 and A124, and the fix round's A125, are the orchestrator's assumptions under the user's instruction of 2026-10-06, never the user's decisions. **A124** is the orchestrator's dispatch instruction that the implementer write T44's dispatch amendment into the brief, as its first commit, in place of A93's separate amendment, for cost; the knowledge pass records it in `plan.md`.
- Rests on: [[Sessions/2026-10-11 — T43 Changes filter]] (the four diffs `F` re-reads), [[Sessions/2026-10-09 — T42 Focus diff]] (Enter's move to the diff, unchanged)

## What was done

**The git home (C13), `lua/aineo/git/`** — keeps no state; each of its six diffs takes the context from `options.context` (`aineo.git.DiffOptions`, a new class extending `aineo.git.Options`): `'three_lines'` (`--unified=3`, the default) or `'whole_file'` (`--unified=2147483647`, a table entry named `CONTEXT_OPTIONS`; `2147483648` wraps and `--function-context` follows function lines, `evidence/w10-probes.txt` P3). A context it has no name for raises an error naming the two, at the call, not inside a callback. The four private readers (`untracked_diff`, `tracked_diff`, `show_commit`, `whole_diff`) take the option as an argument; `file_diff`, `commit_diff`, `commit_file_diff`, `uncommitted_file_diff`, `diff_since` and `uncommitted_diff` take it as a trailing `context`.

**The changes home (C15), `lua/aineo/changes/`** — still requiring only `aineo.git`:
- `full_context.lua` (new): the context the diffs are read in, for the editor's life — `current()`, `use(context)`, `other(context)`; in memory, starting at three lines, never on disk.
- `diff_position.lua` (new): where a row of a unified diff stands in its file — the section (named by its `diff --git` line, `''` before the first), then either the row's distance from the section's first row (header rows) or the line's number in the new file, or the old for a `-` line, read from the hunk headers — and the row that stands there in another read. A hunk's header takes the first row under it, a "no newline" note the row above.
- `entry_diff.lua`: `DiffSource` gains `context`, handed to the git home for every read (own worktree's entries and other worktrees' alike).
- `init.lua`: `diff_source()` (the context Enter and `F` read in), `shown_diffs` (for each diff buffer the entry it shows, the context its text is in and the context `F` last asked of it, recorded by `show_diff()`), `F` set buffer-local in Normal mode on every buffer `show_diff()` shows (`remember_diff()`), `reread_diff()` (asks for the context other than the one the buffer was last asked in, makes it the editor's, only the last `F`'s read counts) and `write_reread()` (writes into the same buffer through `diffs.diff_buffer()` under the same name; puts the cursor of every window that shows the buffer on the same line of the file, or on the first line; column kept where the line has it; a refusal by textlock is retried at the next `SafeState`). `open_entry()` reads the diff again when `F` changed the context while it was being read. `tell_diff_unreadable()` serves Enter and `F`.

**`doc/aineo.txt`** — *aineo-changes*: a paragraph after the one on Enter (what `F` does, its scope, that it shadows `F{char}`, that a diff in another window keeps its text, the failure and the last-`F` rule); LIMITS › *The changes pane*: the large-diff item says a full-context diff reaches the 1 MiB cut sooner. `tests/test_doc.lua` stays green.

**The brief** — its *Amendment — 2026-10-11, at dispatch: T43 merged* (A124): the lines T43 moved; no spec conflict.

## Decisions and departures from the brief

- **The context travels as `options.context`**, not as a new positional argument: the git home's six functions already end in `done, options`, and a position before `done` would change every caller and test. Rejected: a count of lines as the argument (a named pair of contexts keeps the wrapping count private to the git home).
- **One re-read counter for every `F`**, not one per buffer: `F` in one diff and then in another before either read arrives leaves the first buffer as it was, which is the context the second `F` left the editor in.
- **A125 (the fix round; the orchestrator's assumption, not the user's decision):** `F` sets the context to the opposite of what the buffer it is pressed in shows (or was last asked to show), and that becomes the remembered context. D48 says `F` "re-reads the same diff with the whole file"; brief item 3 says "`F` flips the mode"; the two differ in a buffer shown before an `F` elsewhere (A111), where flipping the mode would have re-read the same three lines. Brief item 3 is read this way, and the help says so.
- **The cursor is read when the re-read arrives**, not when `F` was pressed: a key the user pressed meanwhile is kept.
- **The mapping is set when the home shows the buffer** (`show_diff()`), which every diff the home shows passes through, a retried one included; a buffer Neovim refused its text and the home never showed has none.
- **Untracked-file diffs take the context argument too** though a wholly added file has no context to widen (P3); one signature for the four readers.

## Unit list (stated before the first test)

1. The git home: a file's diff as one hunk in `'whole_file'`; three lines when asked for `'three_lines'` and when asked for none; a context it has no name for refused; a deleted, an untracked and a renamed file in `'whole_file'`.
2. The git home: `uncommitted_file_diff`, `commit_diff`, `commit_file_diff`, `diff_since`, `uncommitted_diff` in `'whole_file'`.
3. `F` re-reads the diff into the same buffer under the same name; pressed again it goes back; the next diff opens in the context; it is a Normal-mode map of diff buffers alone.
4. The cursor at a flip: a context line, an added line, a removed line, a line three lines no longer show, a hunk's header, a "no newline" note, the section of a diff of several files; the column kept.
5. Only the last `F`'s read; a failed re-read told once, the buffer kept, the context flipped all the same; no message; a textlock hold; a diff in another window kept.
6. Each kind of diff: a file in a commit, a commit (the header kept), *Uncommitted* (from `HEAD`), *Session work* (every file), another worktree's file; a diff larger than 1 MiB cut as before.

The fix round added: a file new between the two reads; an Enter in flight when `F` is pressed (another file, the same file); `F` in a diff shown before another diff's `F`; the cursor in a second window; a stale read's failure; a file's header row; a failed read asked again.

## Red and green

**Seen red (before the code):** `tests/test_git_diffs.lua` 8 of 12 new cases — a file's diff, a context git has no name for, a renamed file, a file from `HEAD`, a commit, a file in a commit, since a base, from `HEAD` (each by the hunk header: `@@ -7,7 +7,7 @@` against `@@ -1,20 +1,20 @@`; the refusal case: the call did not raise). `tests/test_changes_full_context.lua`: *is a Normal-mode map of the diff buffers alone* (`F` not mapped: `normal = false`), and *pressed again…*, *makes the next file’s diff open…* (the child blocked, `F` waiting for a character, with no mapping), *in a file’s diff shows the whole file…* (hunk `@@ -7,7 +7,7 @@`). **Fix round, red before the code (5):** *makes an Enter already reading when it is pressed read again in the new context*, *is not undone by an Enter on the same file…*, *in a diff shown before another diff’s F reads it with the whole file too*, *puts the cursor of every window that shows the diff on the same line of the file*, and the cursor case *stays in its own file when a file new to the diff came between the two reads* (each by assertion or by a bounded wait that expired).

**Arrived green:** `test_git_diffs.lua` › *of a file is three lines of context when asked for three* and *…when not asked for any* — existing behaviour, spent by the default; killed by mutant 19. › *of a deleted file…* and *of an untracked file…* — green by nature (git gives a deleted or untracked file whole at any context); killed by mutant 2 (the wrapped count). `test_changes_full_context.lua`, 19 of the first 23 cases, whose production code was written ahead of them — *pinning code written ahead of its test* — all killed by assertion by the mutants below (each mutant is the red): the cursor cases (mutants 5, 8, 9, 14, 17, 18), *pressed again before the diff arrives* (6, 12), *tells once…* (7), *flips the context all the same…* (1, 7), *writes the diff it read while textlock held…* (16), the kinds (4, 15, 3), the 1 MiB case (11), *says nothing when it flips* (21), *leaves a diff shown in another window as it was* (20). The four cursor cases first failed for a fault of the test, which waited on the line under the cursor before the re-read had arrived; the wait is on the hunk headers now. Fix round, arrived green: *leaves a failure of a read it no longer waits for untold* (the tests review's mutant 28 survived without it) and *on a file’s header row stays on that row of the same file* (mutant 29), *asks for the whole file again after a read of it failed* (mutants 32, 33).

## Mutants

Each applied to the file named, run on the covering test file, restored in the same call (the edit is the text before → after). A kill is an equality assertion, read from the output: every failure of every run below is a `Failed expectation for equality`. Rows 1–27 were measured on `6e7b0cb` (the fix round then rewrote `write_reread()`, `reread_diff()` and `open_entry()`); the plan's five are measured again on the final tree, in the second table, whose edits follow the code as it is now.

| # | File | Literal edit | Result |
|---|---|---|---|
| 1 | `changes/init.lua` | `open_entry()`: `entry_diff.read(entry, diff_source(), …)` → `entry_diff.read(entry, vim.tbl_extend('force', diff_source(), { context = 'three_lines' }), …)` (the choice not remembered) | killed, 2 — *makes the next file’s diff open…*; *flips the context all the same…* |
| 2 | `git/diffs.lua` | `whole_file = '--unified=2147483647'` → `'--unified=2147483648'` | killed — `test_git_diffs` 9 (every whole-file case), `test_changes_full_context` 16 |
| 3 | `changes/init.lua` | `write_reread()`: `diffs.diff_buffer(entry_diff.name(entry), diff)` → `diffs.diff_buffer(entry_diff.name(entry) .. 'x', diff)` (a new buffer) | killed, 16 |
| 4 | `changes/init.lua` | `reread_diff()`: `entry_diff.read(entry, …)` → `entry_diff.read(vim.tbl_extend('force', entry, { filter = { kind = 'session_work' } }), …)` | killed, 3 — the Uncommitted case among them (`+changed 10` shown as added) |
| 5 | `changes/init.lua` | `local row = position and diff_position.row_of(shown, position) or 1` → `local row = 1` | killed, 4 — the context, added, removed and several-files cursor cases |
| 6 | `changes/init.lua` | `rereads = rereads + 1` → `rereads = 0` | killed, 1 — *pressed again before the diff arrives shows only the last read* |
| 7 | `changes/init.lua` | `reread_diff()`: `tell_diff_unreadable(entry, failure)` line removed | killed, 2 |
| 8 | `changes/diff_position.lua` | `if candidate.section ~= position.section then` → `if false then` | killed, 1 — the several-files case |
| 9 | `changes/init.lua` | `math.min(cursor[2], math.max(#shown[row] - 1, 0))` → `0` | killed, 1 — the context case's column |
| 10 | `git/diffs.lua` | `if not option then` → `if false then` | killed, 1 — the refused context |
| 11 | `changes/diffs.lua` | `if #diff <= SHOWN_BYTES then` → `if true then` | killed, 1 — the 1 MiB case |
| 12 | `changes/full_context.lua` | `shows_whole_file = not shows_whole_file` → `shows_whole_file = true` | killed, 3 |
| 13 | `git/init.lua` | `context_of()`: `return options and options.context` → `return nil` | killed — `test_git_diffs` 8 |
| 14 | `changes/init.lua` | `… or 1` → `… or math.min(cursor[1], #shown)` (the row kept when the line is gone) | killed, 1 — *goes to the first line when three lines of context no longer show its line* |
| 15 | `changes/entry_diff.lua` | another worktree's file read: `source.options` → `nil` | killed, 1 — the worktree case |
| 16 | `changes/init.lua` | `write_reread()`: the `vim.api.nvim_create_autocmd('SafeState', { … })` retry replaced by `return` | killed, 1 — *writes the diff it read while textlock held…* |
| 17 | `changes/diff_position.lua` | `at()`: the branch `elseif vim.startswith(lines[row] or '', '\\') then return positions[row - 1]` removed | killed, 1 |
| 18 | `changes/diff_position.lua` | `at()`: `if vim.startswith(lines[row] or '', '@@') then` → `if false then` | killed, 1 |
| 19 | `git/diffs.lua` | `three_lines = '--unified=3'` → `'--unified=4'` | killed, 2 — the two three-line cases of `test_git_diffs.lua` |
| 20 | `changes/init.lua` | `reread_diff()` after `full_context.flip()`: every other remembered diff buffer rewritten (`diffs.diff_buffer(entry_diff.name(diff_entries[other]), vim.api.nvim_buf_get_lines(other, 0, 1, true)[1] .. '\n')`) | killed, 1 — *leaves a diff shown in another window as it was*; the first version of that case compared one line and was killed by a Lua error (index out of bounds), not by an assertion, so it now compares the whole buffer |
| 21 | `changes/init.lua` | `reread_diff()`: `full_context.flip()` → `vim.notify('aineo: ' .. full_context.flip(), vim.log.levels.INFO)` | killed, 2 — *says nothing when it flips*; *tells once…* |
| 22 | `git/diffs.lua` | `commit_diff()`: `show_commit(run, found, commit, {}, context_option(context), done)` → `… context_option(nil) …` | killed, 1 |
| 23 | `git/diffs.lua` | `commit_file_diff()`: `show_commit(run, found, commit, paths, context_option(context), done)` → `… context_option(nil) …` | killed, 1 |
| 24 | `git/diffs.lua` | `uncommitted_file_diff()`: `M.file_diff(run, found, head, change, done, context)` → `M.file_diff(run, found, head, change, done)` | killed, 1 |
| 25 | `git/diffs.lua` | `diff_since()`: `whole_diff(run, found, tree_ish, unified, give_diff)` → `whole_diff(run, found, tree_ish, context_option(nil), give_diff)` | killed, 2 |
| 26 | `git/diffs.lua` | `uncommitted_diff()`: `M.diff_since(run, found, head, done, context)` → `M.diff_since(run, found, head, done)` | killed, 1 |
| 27 | `git/diffs.lua` | `file_diff()`: `tracked_diff(run, found, tree_ish, change, unified, give_diff)` → `tracked_diff(run, found, tree_ish, change, context_option(nil), give_diff)` | killed, 3 |

**The plan's five (`plan.md` › *Verification mutants* › T44), on the final tree** (head of the fix round):

| # | File | Literal edit | Result |
|---|---|---|---|
| P1 | `changes/full_context.lua` | `use()`: `current = context` → `current = 'three_lines'` (the choice not remembered) | killed, 26 (every case that reads in the whole file, `test_changes_full_context.lua`) |
| P2 | `git/diffs.lua` | `whole_file = '--unified=2147483647',` → `'--unified=2147483648',` | killed, 9 (`test_git_diffs.lua`, the whole-file cases) |
| P3 | `changes/init.lua` | `write_reread()`: `diffs.diff_buffer(entry_diff.name(entry), diff)` → `diffs.diff_buffer(entry_diff.name(entry) .. 'x', diff)` | killed, 23 (`test_changes_full_context.lua`) |
| P4 | `changes/init.lua` | `reread_diff()`: `entry_diff.read(shown.entry, diff_source(), …)` → `entry_diff.read(vim.tbl_extend('force', shown.entry, { filter = { kind = 'session_work' } }), diff_source(), …)` | killed, 3 (the commit-file, commit and Uncommitted cases) |
| P5 | `changes/init.lua` | `write_reread()`: `local row = before_write.position and diff_position.row_of(shown, before_write.position) or 1` → `local row = 1` | killed, 9 (the cursor cases, the header-row case among them) |

**The fix round's mutants** (final tree, each killed by assertion):

| # | File | Literal edit | Result |
|---|---|---|---|
| 28 | `changes/init.lua` | `reread_diff()`'s callback: the guard `if this_reread ~= rereads then return end` removed (the tests review's M-A) | killed, 1 — *leaves a failure of a read it no longer waits for untold* |
| 29 | `changes/diff_position.lua` | `head = row - section_start` → `head = 0` (the tests review's M-B) | killed, 1 — *on a file’s header row stays on that row of the same file* |
| 30 | `changes/diff_position.lua` | `section, section_start, in_hunk = line, row, false` → `section .. '.', row, false` (a section named by its position) | killed, 1 — *stays in its own file when a file new to the diff came between the two reads* |
| 31 | `changes/init.lua` | `open_entry()`: `if source.context ~= full_context.current() then` → `if false then` | killed, 2 — the two Enter-in-flight cases |
| 32 | `changes/init.lua` | `reread_diff()`: `full_context.other(shown.asked)` → `full_context.other(full_context.current())` (the global flip) | killed, 2 — *in a diff shown before another diff’s F…*; *asks for the whole file again after a read of it failed* |
| 33 | `changes/init.lua` | `reread_diff()`: `shown.asked = shown.context` → `shown.asked = shown.asked` | killed, 1 — *asks for the whole file again after a read of it failed* |
| 34 | `changes/init.lua` | `write_reread()`: `ipairs(vim.fn.win_findbuf(buffer))` → `ipairs({ vim.api.nvim_get_current_win() })` | killed, 1 — *puts the cursor of every window that shows the diff…* |

Not mutated: the context argument of `untracked_diff()` — a wholly added file has no context to widen (P3), so removing it changes nothing git prints; the tests review measured it (`Fails (0)`) and called it equivalent.

## Fix round — the two reviews of PR #161

| Finding | What was done | Case (red first) |
|---|---|---|
| Attack 1 (cursor into another file) | A file's section is named by its `diff --git` line, `''` before the first | *stays in its own file when a file new to the diff came between the two reads* |
| Attack 2 (an Enter in flight) | A read that arrives in a context `F` has since changed is read again in the current one | *makes an Enter already reading… read again in the new context*; *is not undone by an Enter on the same file…* |
| Attack 3 (`F` in a stale-context buffer) | A125 above | *in a diff shown before another diff’s F reads it with the whole file too* |
| Attack 4 (a second window) | The cursor is restored in every window that shows the buffer | *puts the cursor of every window that shows the diff…* |
| Tests 1, 2 | The stale-read and header-row cases | arrived green; mutants 28, 29 |
| Tests 3 | This table: rows numbered 1–34 with no gap, literal edits for the git readers, the plan's five measured on the final tree with the killing tests named | — |
| Tests 4 | `show_diff()`'s docstring says it records the entry and the context and maps `F` | — |
| Tests 5 | Not required; the gap stays: nothing pins that the context is never kept on disk | — |

The plan's five and the tests that kill them: P1 — *makes the next file’s diff open with the whole file as its context* and *flips the context all the same…*; P2 — the nine whole-file cases of `test_git_diffs.lua` (`a diff in the whole file’s context`) and, in the first round, 16 of `test_changes_full_context.lua`; P3 — *in a file’s diff shows the whole file as its context, in the same buffer under the same name* and the cases that read the same buffer afterwards; P4 — *in the diff of Uncommitted shows the whole file from HEAD, not from the base* (with the two commit cases); P5 — the cursor cases (*stays on the same context line…*, *…added line*, *…removed line*, *…in a diff of several files*).

## Suites

On Neovim 0.12.5 (git 2.50.1), on the tree pushed: `make test` — 2594 cases in 76 groups, `Fails (0)`, exit 0 (2586 at the first push plus 8 of the fix round: `test_changes_full_context` 23 → 31). Files run alone while working: `test_git_diffs` 44, `test_changes_full_context` 31, `test_doc` 44, each `Fails (0)`. `make lint`: StyLua clean, selene 0 errors, 0 warnings.

## Open threads

- An Enter's read that arrives after `F` changed the context is read again (a second git read of the same diff); the user sees the diff in the new context.
- `F` twice before a read arrives ends where it began: the second `F` asks for the context other than the one the first asked.
- A diff buffer wiped between `F` and its read's arrival is skipped silently, the context having changed; the help does not say so.
- `F` shadows Vim's `F{char}` in a diff buffer (A105); no `<Plug>` mapping stands for it.

## Task lines

Marked done in the v1 plan note by wave 10's closing knowledge pass (PR #161, wave 10; released in v0.2.21). The line as the wave holds it:

- [X] T44 — a full-context diff toggle (C15, C13; D48): `F` in a diff the changes pane showed re-reads it with the whole file as context, in the same buffer, and every diff shown after opens the same way until `F` flips it back, for the editor's life; for a file, a commit, *Uncommitted* and *Session work*, another worktree's too (PR #161, into `dev`, wave 10) — regular. The five mutants of `plan.md` › *Verification mutants* › T44 map to this note's P1–P5.

## Commits

Recorded after the merge, by wave 10's closing knowledge pass. PR #161 merged by rebase as `0b09db7` … `32283d1` (5 commits); the orchestrator verified the pull request's head `221531c`, rebased on `dev` `c3d4d30`: the whole suite 2594 cases, `Fails (0)`, lint clean, and the mutant naming a file's section by position instead of its `diff --git` line killed by assertion. Released in v0.2.21 (PR #162, `main` `50a28da`).

| Branch | `dev` | Subject |
|---|---|---|
| `5066bc8` | `0b09db7` | Add F, a full-context toggle for the diffs the changes pane shows |
| `6e7b0cb` | `a3c2408` | Pin T44's cursor, textlock and failure cases and record the session |
| `48afb1d` | `ca8919c` | Name pull request #161 on T44's task line |
| `9aa8819` | `fa96f80` | Fix T44's review findings: sections, stale Enters, F's target, windows |
| `221531c` | `32283d1` | Record T44's fix round in the session note |

The `Branch` column is the pull request's own commits (`refs/pull/161/head`); the verified head `221531c` is the last of them. The first commit carries the brief's dispatch amendment (A124).
