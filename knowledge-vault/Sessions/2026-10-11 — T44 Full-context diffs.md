# 2026-10-11 — T44 Full-context diffs

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet, A104)
**Branch:** `feature/t44-full-context` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D48, D19, D46, D47, C13, C15, T44
- [[Implementation/Waves/00010-changes-filter/plan]] and [[Implementation/Waves/00010-changes-filter/brief-t44-full-context]] (its *Amendment — 2026-10-11, at dispatch*; the orchestrator's rulings A101–A103, A105–A107, A111, A124, to be read as the orchestrator's assumptions, never the user's decisions)
- Rests on: [[Sessions/2026-10-11 — T43 Changes filter]] (the four diffs `F` re-reads), [[Sessions/2026-10-09 — T42 Focus diff]] (Enter's move to the diff, unchanged)

## What was done

**The git home (C13), `lua/aineo/git/`** — keeps no state; each of its six diffs takes the context from `options.context` (`aineo.git.DiffOptions`, a new class extending `aineo.git.Options`): `'three_lines'` (`--unified=3`, the default) or `'whole_file'` (`--unified=2147483647`, a table entry named `CONTEXT_OPTIONS`; `2147483648` wraps and `--function-context` follows function lines, `evidence/w10-probes.txt` P3). A context it has no name for raises an error naming the two, at the call, not inside a callback. The four private readers (`untracked_diff`, `tracked_diff`, `show_commit`, `whole_diff`) take the option as an argument; `file_diff`, `commit_diff`, `commit_file_diff`, `uncommitted_file_diff`, `diff_since` and `uncommitted_diff` take it as a trailing `context`.

**The changes home (C15), `lua/aineo/changes/`** — still requiring only `aineo.git`:
- `full_context.lua` (new): the editor's context for its life, `current()` and `flip()`; in memory, starting at three lines, never on disk.
- `diff_position.lua` (new): where a row of a unified diff stands in its file — the section (the nth `diff --git` block), then either the row's distance from the section's first row (header rows) or the line's number in the new file, or the old for a `-` line, read from the hunk headers — and the row that stands there in another read. A hunk's header takes the first row under it, a "no newline" note the row above.
- `entry_diff.lua`: `DiffSource` gains `context`, handed to the git home for every read (own worktree's entries and other worktrees' alike).
- `init.lua`: `diff_source()` (the context Enter and `F` read in), `diff_entries` (the entry each diff buffer shows, remembered in `show_diff()`), `F` set buffer-local in Normal mode on every buffer `show_diff()` shows (`remember_diff()`), `reread_diff()` (flips the mode, reads the entry again in it, only the last `F`'s read counts) and `write_reread()` (writes into the same buffer through `diffs.diff_buffer()` under the same name; puts the cursor of the window `F` was pressed in on the same line of the file, or on the first line; column kept where the line has it; a refusal by textlock is retried at the next `SafeState`). `tell_diff_unreadable()` now serves Enter and `F`.

**`doc/aineo.txt`** — *aineo-changes*: a paragraph after the one on Enter (what `F` does, its scope, that it shadows `F{char}`, that a diff in another window keeps its text, the failure and the last-`F` rule); LIMITS › *The changes pane*: the large-diff item says a full-context diff reaches the 1 MiB cut sooner. `tests/test_doc.lua` stays green.

**The brief** — its *Amendment — 2026-10-11, at dispatch: T43 merged* (A124): the lines T43 moved; no spec conflict.

## Decisions and departures from the brief

- **The context travels as `options.context`**, not as a new positional argument: the git home's six functions already end in `done, options`, and a position before `done` would change every caller and test. Rejected: a count of lines as the argument (a named pair of contexts keeps the wrapping count private to the git home).
- **One re-read counter for every `F`**, not one per buffer: `F` in one diff and then in another before either read arrives leaves the first buffer as it was, which is the context the second `F` left the mode in. Enter's own counter (`enters`) is not shared: an Enter in flight when `F` is pressed arrives in the context it was asked in (the mode flipped after it was asked).
- **The cursor is read when the re-read arrives**, not when `F` was pressed: a key the user pressed meanwhile is kept.
- **The mapping is set when the home shows the buffer** (`show_diff()`), which every diff the home shows passes through, a retried one included; a buffer Neovim refused its text and the home never showed has none.
- **Untracked-file diffs take the context argument too** though a wholly added file has no context to widen (P3); one signature for the four readers.

## Unit list (stated before the first test)

1. The git home: a file's diff as one hunk in `'whole_file'`; three lines when asked for `'three_lines'` and when asked for none; a context it has no name for refused; a deleted, an untracked and a renamed file in `'whole_file'`.
2. The git home: `uncommitted_file_diff`, `commit_diff`, `commit_file_diff`, `diff_since`, `uncommitted_diff` in `'whole_file'`.
3. `F` re-reads the diff into the same buffer under the same name; pressed again it goes back; the next diff opens in the mode; it is a Normal-mode map of diff buffers alone.
4. The cursor at a flip: a context line, an added line, a removed line, a line three lines no longer show, a hunk's header, a "no newline" note, the section of a diff of several files; the column kept.
5. Only the last `F`'s read; a failed re-read told once, the buffer kept, the mode flipped all the same; no message; a textlock hold; a diff in another window kept.
6. Each kind of diff: a file in a commit, a commit (the header kept), *Uncommitted* (from `HEAD`), *Session work* (every file), another worktree's file; a diff larger than 1 MiB cut as before.

## Red and green

**Seen red (before the code):** `tests/test_git_diffs.lua` 8 of 12 new cases — a file's diff, a context git has no name for, a renamed file, a file from `HEAD`, a commit, a file in a commit, since a base, from `HEAD` (each by the hunk header: `@@ -7,7 +7,7 @@` against `@@ -1,20 +1,20 @@`; the refusal case: the call did not raise). `tests/test_changes_full_context.lua`: *is a Normal-mode map of the diff buffers alone* (`F` not mapped: `normal = false`), and *pressed again…*, *makes the next file’s diff open…* (the child blocked, `F` waiting for a character, with no mapping), *in a file’s diff shows the whole file…* (hunk `@@ -7,7 +7,7 @@`).

**Arrived green:** `test_git_diffs.lua` › *of a file is three lines of context when asked for three* and *…when not asked for any* — existing behaviour, spent by the default; killed by mutant 21. › *of a deleted file…* and *of an untracked file…* — green by nature (git gives a deleted or untracked file whole at any context); killed by mutant 2 (the wrapped count). `test_changes_full_context.lua`, 19 of its 23 cases, whose production code was written ahead of them — *pinning code written ahead of its test* — all killed by assertion by the mutants below (each mutant is the red): the cursor cases (mutants 5, 9, 10, 16, 19, 20), *pressed again before the diff arrives* (6, 14), *tells once…* (7), *flips the context all the same…* (1, 7), *writes the diff it read while textlock held…* (18), the kinds (4, 17, 3), the 1 MiB case (13), *says nothing when it flips* (23), *leaves a diff shown in another window as it was* (22). The four cursor cases first failed for a fault of the test, which waited on the line under the cursor before the re-read had arrived; the wait is on the hunk headers now.

## Mutants

Each applied to the file named, run on the covering test file, restored in the same call (the edit is the literal text in the `.old`/`.new` pair of the run; production code identical to the pushed tree). A kill is an equality assertion, read from the output: every failure of every run below is a `Failed expectation for equality`.

| # | File | Literal edit | Result |
|---|---|---|---|
| 1 | `changes/init.lua` | `open_entry()`: `entry_diff.read(entry, diff_source(), …)` → `entry_diff.read(entry, vim.tbl_extend('force', diff_source(), { context = 'three_lines' }), …)` (the choice not remembered) | killed, 2 — *makes the next file’s diff open…*; *flips the context all the same…* |
| 2 | `git/diffs.lua` | `whole_file = '--unified=2147483647'` → `'--unified=2147483648'` | killed — `test_git_diffs` 9 (every whole-file case), `test_changes_full_context` 16 |
| 3 | `changes/init.lua` | `write_reread()`: `diffs.diff_buffer(entry_diff.name(entry), diff)` → `diffs.diff_buffer(entry_diff.name(entry) .. 'x', diff)` (a new buffer) | killed, 16 |
| 4 | `changes/init.lua` | `reread_diff()`: `entry_diff.read(entry, …)` → `entry_diff.read(vim.tbl_extend('force', entry, { filter = { kind = 'session_work' } }), …)` | killed, 3 — the Uncommitted case among them (`+changed 10` shown as added) |
| 5 | `changes/init.lua` | `local row = position and diff_position.row_of(shown, position) or 1` → `local row = 1` | killed, 4 — the context, added, removed and several-files cursor cases |
| 6 | `changes/init.lua` | `rereads = rereads + 1` → `rereads = 0` | killed, 1 — *pressed again before the diff arrives shows only the last read* |
| 7 | `changes/init.lua` | `reread_diff()`: `tell_diff_unreadable(entry, failure)` removed | killed, 2 |
| 9 | `changes/diff_position.lua` | `candidate.section ~= position.section` → `false` | killed, 1 — the several-files case |
| 10 | `changes/init.lua` | `math.min(cursor[2], math.max(#shown[row] - 1, 0))` → `0` | killed, 1 — the context case's column |
| 11 | `git/diffs.lua` | `if not option then` → `if false then` | killed, 1 — the refused context |
| 13 | `changes/diffs.lua` | `if #diff <= SHOWN_BYTES then` → `if true then` | killed, 1 — the 1 MiB case |
| 14 | `changes/full_context.lua` | `shows_whole_file = not shows_whole_file` → `shows_whole_file = true` | killed, 3 |
| 15 | `git/init.lua` | `context_of()`: `return options and options.context` → `return nil` | killed — `test_git_diffs` 8 |
| 16 | `changes/init.lua` | `… or 1` → `… or math.min(cursor[1], #shown)` (the row kept when the line is gone) | killed, 1 — *goes to the first line when three lines of context no longer show its line* |
| 17 | `changes/entry_diff.lua` | another worktree's file read: `source.options` → `nil` | killed, 1 — the worktree case |
| 18 | `changes/init.lua` | the `SafeState` retry in `write_reread()` removed (`return` alone) | killed, 1 — *writes the diff it read while textlock held…* |
| 19 | `changes/diff_position.lua` | the "no newline" branch of `at()` removed | killed, 1 |
| 20 | `changes/diff_position.lua` | the hunk-header branch of `at()` `if … '@@' then` → `if false then` | killed, 1 |
| g1–g6 | `git/diffs.lua` | `commit_diff`, `commit_file_diff`, `uncommitted_file_diff`, `diff_since`, `tracked_diff` (g6) and `uncommitted_diff` (g5) each reading with `context_option(nil)` or no context | killed, 1, 1, 1, 2 (g4), 1 (g5), 3 (g6) |
| 21 | `git/diffs.lua` | `three_lines = '--unified=3'` → `'--unified=4'` | killed, 2 — the two three-line cases of `test_git_diffs.lua` |
| 22 | `changes/init.lua` | `reread_diff()` after `full_context.flip()`: every other remembered diff buffer rewritten (`diffs.diff_buffer(entry_diff.name(diff_entries[other]), vim.api.nvim_buf_get_lines(other, 0, 1, true)[1] .. '\n')`) | killed, 1 — *leaves a diff shown in another window as it was*; the first version of that case compared one line and was killed by a Lua error (index out of bounds), not by an assertion, so it now compares the whole buffer |
| 23 | `changes/init.lua` | `reread_diff()`: `full_context.flip()` → `vim.notify('aineo: ' .. full_context.flip(), vim.log.levels.INFO)` | killed, 2 — *says nothing when it flips*; *tells once…* |

The five mutants of `plan.md` › *Verification mutants* › T44 map to this note's 1, 2, 3, 4 and 5.

Not mutated: the context argument of `untracked_diff()` — a wholly added file has no context to widen (P3), so removing it changes nothing git prints; the equivalent edit is not run.

## Suites

On Neovim 0.12.5 (git 2.50.1), on the tree pushed: `make test` — 2586 cases in 76 groups, `Fails (0)`, exit 0 (2551 after T43's fix round plus 35: `test_git_diffs` 12, `test_changes_full_context` 23). Files run alone while working: `test_git_diffs` 44 (32 + 12), `test_changes_full_context` 23, `test_doc` 44, each `Fails (0)`. `make lint`: StyLua clean, selene 0 errors, 0 warnings.

## Open threads

- An Enter in flight when `F` is pressed arrives in the context it was asked in; the next Enter reads in the new one. The window is the length of one git read.
- A diff shown in two windows: `F` places the cursor of the window it was pressed in only; the other window's cursor keeps its row, which Neovim clamps.
- `F` shadows Vim's `F{char}` in a diff buffer (A105); no `<Plug>` mapping stands for it.

## Task lines

The wave holds its marks (rule 6). The line T44 would take:

- [X] T44 — a full-context diff toggle (C15, C13; D48): `F` in a diff the changes pane showed re-reads it with the whole file as context, in the same buffer, and every diff shown after opens the same way until `F` flips it back, for the editor's life; for a file, a commit, *Uncommitted* and *Session work*, another worktree's too (PR PRNUMBER, into `dev`, wave 10) — regular. The five mutants of `plan.md` › *Verification mutants* › T44 map to this note's mutants 1, 2, 3, 4 and 5.

## Commits

Recorded after the merge.
