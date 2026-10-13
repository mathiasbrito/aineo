# 2026-10-13 — T56 Commit file read

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `bugfix/t56-commit-file-read` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D57, D60, D61, C13, C15, T53, T56
- Wave plan: [[Implementation/Waves/00014-cut-bases-new-session/plan]] › O4–O8, A196–A203, and the fix round's A213–A216 (brief, last section); brief: [[Implementation/Waves/00014-cut-bases-new-session/brief-t56-commit-file-read]]
- Rests on: [[Sessions/2026-10-12 — T51 Landed reads]], [[Sessions/2026-10-12 — T53 Files window keys]]; wave 13's A182, A183

## What was done

A commit's file is read no further than `gf` shows it (wave 13's A183). The orchestrator's rulings O4–O8 = A196–A203, all (a), are its assumptions under the user's instruction of 2026-10-06, not the user's decisions.

- **The runner** (`lua/aineo/git/process.lua`): `aineo.git.Request` gains `first_stdout_bytes`. A request that sets it is run with a `stdout` function that keeps the first bytes up to the bound; once they have come, every process of git's group is killed (the time limit's own `kill_group()`), and the run answers with them, `Output.cut = true`. The answer wins over a signal and over the time limit that fires meanwhile. A git that exits before the bound answers as before; one that is stopped by the time limit, or ended by any other signal, before the bound fails as before. A request with no bound is collected whole by `vim.system()` as before.
- **The read** (`lua/aineo/git/content.lua`, `init.lua`): `ls-tree` runs with `-l`; the entry's size is read from the same line (`%S+` after the id, `-` for an entry that is no file, so a directory and a submodule still fail as before). `git.file_at_commit(found, commit, path, done, options, first_bytes)` calls `done(nil, text, size)`; `cat-file` is bounded only when the file is larger than `first_bytes`.
- **The changes home** (`lua/aineo/changes/diffs.lua`, `commit_file.lua`, `init.lua`'s `show_commit_file()`): `diffs.BYTES_NEEDED_OF_A_FILE` is `SHOWN_BYTES` plus 4 (plus 6 after the fix round, A214), passed by `show_commit_file()` through `commit_file.read(revision, path, options, first_bytes, done)`; `diffs.file_buffer(name, path, content, size)` writes the note from git's size. The display rule stays in the changes home; the diff buffer's note still comes from the text's length.
- **`doc/aineo.txt`**: *aineo-changes*'s `gf` paragraph (the note gives the file's whole size; git is stopped at the 1 MiB) and a LIMITS › *The changes pane* item for a large file under a commit. The LIMITS item on a large diff keeps "git still gives the whole diff first" (O8 (a)).

A measurement on a 32 MiB fixture file, in a headless Neovim 0.12.5 (`.tests/t56-measure.lua`, two runs of each): the read with no bound took 49–51 ms and grew the editor by 63–68 MiB; with `first_bytes` = 1 MiB + 4 it took 30–31 ms and grew it by 1.0 MiB, and `size` was 33 552 000 in both.

## Unit list

1. `file_at_commit()` gives the file's size beside its text (`ls-tree -l`); 2. a file larger than `first_bytes` gives its first bytes exactly and its whole size; 3. a file no larger gives its whole text; 4. no `first_bytes` gives a large file whole; 5. the runner stops git, and every process it started, once the bytes have come; 6. the bytes arrive in pieces and the answer is still exactly the bound; 7. a git that ends before the bound answers as without one; 8. a git ended by a signal before the bound fails; 9. a git that runs past its limit before the bound is `timed_out`; 10. nothing left behind by a bounded run; 11. `gf` tells the size git gave; 12. `gf` cuts a first line longer than 1 MiB on a character's edge.

## Red and green

Seen red, for the intended reason (read from the output): unit 1 (`size` nil); unit 2 (`text` the whole file, not the first 100 000 bytes); unit 5 and unit 6 (the stand-in git ran to the 10 s limit: `timed_out` where an answer was expected); unit 11 and unit 12, once `show_commit_file()` asked for `BYTES_NEEDED_OF_A_FILE` and before the note used git's size (the note gave 1048580, the bytes read, as the file's size, where it is 1144000 and, for the wide line, 1200001).

Arrived green, with the reason: unit 3 (git's output, whole, already was the text; killer: none distinct from unit 2's, m7 below survives because a bound at or above the size is the same text); unit 4 (unit 1's code); units 7–10 (the runner ignored the bound before it was written, so a git that ends early, by a signal or by its limit, answered as it does; killers m1, m3, m3a; unit 10 was slow, two 10 s limits, until the bound existed); units 11 and 12 are green on today's buffer before the read is bounded, which is why they were written before the changes home asked for fewer bytes (red above) and are killed by m4, m6, m10.

## Mutants

Each row is the literal edit (file: before → after), applied to the tree at `c4d8264`, run on `tests/test_git_process.lua`, `tests/test_git_repository.lua` and `tests/test_changes_open_file.lua`, and restored in the same call. Kinds read from the output: every kill is an assertion failure (`Fails (n)` with the named case), none a crash.

| # | Edit | Result |
|---|---|---|
| m1 | `process.lua`: `local first_bytes = request.first_stdout_bytes and collect_first_bytes(request.first_stdout_bytes, stop)` → `local first_bytes = nil` | killed by assertion: process "is stopped once the bytes asked for have come…", "gives exactly the bytes asked for when they come in pieces"; repository "larger than the bytes asked for gives exactly its first bytes…". Survives in `test_changes_open_file.lua` alone: what `gf` shows does not change when git is not stopped (the cost does) |
| m2 | `process.lua`: `if cut then` (first line of `outcome()`) → `if false then` | killed by assertion: the same three, and four of `gf`'s ("shows a file larger than 1 MiB cut…", the note's size, the wide line, "writes the note…once again after :edit!") |
| m3 | `process.lua`: `local cut = first_bytes ~= nil and first_bytes.reached()` → `local cut = first_bytes ~= nil and result.signal == 9` | killed by assertion: process "ended by a signal before reaching the bound…", "running past its limit before reaching the bound…" |
| m3a | `process.lua`: `if result.signal ~= 0 then` → `if result.signal ~= 0 and result.signal ~= 9 then` | killed by assertion: process "ended by a signal before reaching the bound…" |
| m4 | `diffs.lua`: `shown_of(content, 'file', size)` → `shown_of(content, 'file', #content)` | killed by assertion: `gf` "tells in the note how much of the whole file is shown…", the wide line |
| m5 | `content.lua`: `'ls-tree', '-l', '-z'` → `'ls-tree', '-z'` | killed by assertion: 14 repository cases and 16 of `gf`'s (the entry no longer matches) |
| m6 | `diffs.lua`: `LONGEST_CHARACTER_BYTES = 4` → `= 0` | killed by assertion: `gf` "tells in the note…", the wide line |
| m7 | `content.lua`: `first_bytes ~= nil and entry.size > first_bytes` → `first_bytes ~= nil` | survived all three files: a file no larger than the bound is read bounded at its own size, with the same text and size; the only difference is a kill of a git that has just printed its last byte. Not dead code (A117): the guard keeps that kill off the common path |
| m8 | `process.lua`: `local piece = data:sub(1, wanted - size)` → `local piece = data` | killed by assertion: the same three as m1 (the answer holds more than the bound) |
| m9 | `process.lua`: `collect_first_bytes(request.first_stdout_bytes, stop)` → `collect_first_bytes(request.first_stdout_bytes, function() end)` | killed by assertion: process "is stopped once the bytes asked for have come…" (git is not stopped). Survives the repository and `gf` files: only the cost differs |
| m10 | `content.lua`: `done(nil, file.stdout, entry.size)` → `done(nil, file.stdout, #file.stdout)` | killed by assertion: process "is stopped once…" (size), repository "larger than the bytes asked for…", `gf`'s note and wide line |

The plan's five mutants map to: 1 = m1 (and m8), 2 = m2, 3 = m3 (and m3a), 4 = m4, 5 = m5.

## Pins that moved

`tests/test_changes_open_file.lua`: the stand-ins of `git.file_at_commit` (lines 524, 554, 555, 708) now give a size as the third value, since the contract does (`"in the commit\n"` 14, `"b text\n"` and `"a text\n"` 7). No other pin moved.

## Decisions and open threads

- The rulings A199–A203 (O4–O8, all (a)) are the orchestrator's assumptions, not the user's decisions. What lost: O4 (b) `cat-file -s`, one more process, and (c) no size, a note that says "more than 1 MiB"; O5 (b) a file larger than the bound not read at all, which loses the first MiB the buffer shows today, and (c) a second bound that skips a read past a far larger size, with no measured need; O6 (b) new words saying git was stopped; O7 (b) the bound as a constant inside the git home, which would make it know a display rule; O8 (b) was not on the table, Enter's diffs are left out (A203) and stay an open thread.
- `Output.cut` was set in the first commit and read by nothing; the fix round dropped it (A215).
- A bounded request whose git reaches the bound and exits on its own with a non-answer code (a race of a few microseconds) is answered with the bytes.
- Enter's diffs still read whole (O8 (a)); LIMITS says so.

## Fix round

The two reviews of PR #192 (attack on Opus; tests and records on Sonnet) found the following; the orchestrator's rulings A213–A216 are in the brief's last section, as its assumptions. Each was driven by a case seen failing first, unless said.

- **Attack 1, HIGH (a regression).** A blob that `ls-tree -l` lists as `BAD` gave `size = nil`; `entry.size > first_bytes` raised in the scheduled callback and `done` was never called. Red first: `tests/test_git_repository.lua` "whose object git cannot read is a failure in git’s words, never raised" (`calls` 0 against 1), "is read whole when git gives no size for it" (`attempt to compare number with nil`), and `tests/test_changes_open_file.lua` "whose object git cannot read tells git’s words once, naming the file" (the stack trace was told). The fix: `file_request()` bounds only when `entry.size ~= nil`; `done` gets `entry.size or #file.stdout`, pinned by "whose size git does not give has the length of its text for its size" (arrived green, written ahead of its mutant f9).
- **Attack 2 (A213).** Help, LIMITS, `git/init.lua` and `content.lua` claim only the editor's bound; a bounded `cat-file` carries `-c core.bigFileThreshold=1m`. Red first: "read within a bound lets git stream a packed file that is not a delta" (first argument `cat-file` where `-c` was expected).
- **Attack 3 (A214).** `LONGEST_CHARACTER_BYTES = 6`. Red first: `gf` "cuts a first line whose six-byte lead stands at the bound as it would be cut whole" (shown 1048576, expected 1048575).
- **Attack 4 (A215).** `Output.cut` dropped (`outcome()` still takes `cut` as a parameter).
- **Tests 1.** `gf` "asks git for the bytes it shows and six more, no more of the file", the stand-in recording its sixth argument (red: 1048580 against 1048582).
- **Tests 2.** "is stopped with a process it started that holds its output" (a `sleep 30 &` descendant holding git's output). Arrived green on the head; killed f2 below.
- **Tests 3.** "bounds git’s output only when the file is larger than the bytes asked for" (13 and 14 against a 13-byte file, and 12), by a fake `run`; arrived green, killed f3.
- **Tests 4.** The help sentence was missing "shown"; fixed with A213's wording.
- **Tests 5, 6.** The task line is in the closed lines' style; the Decisions name A199–A203 and what lost. The first commit's message, which said A196 to A212, is left as pushed.
- **Tests 7.** "is answered, not timed out, when its limit runs out as the bytes asked for come": the child's main loop is held for 1.5 s once the read has started, so that the 500 ms limit and the bytes both wait to be seen. Arrived green; killed f4. An escaping descendant cannot reach `cut and timed_out`: git leads its own session (`detach`), so `kill(-pid)` always reaches it and the process handle closes at its exit, which is why the loop is held instead.
- **Tests 8.** The "leaves nothing behind" case asserts the text as well.

Mutants of the fix round (literal edits, on the tree at `a808552`, on the named files, each restored in the same call):

| # | Edit | Result |
|---|---|---|
| f1 (G1) | `changes/init.lua`: `diffs.BYTES_NEEDED_OF_A_FILE,` → `nil,` | killed by assertion: `test_changes_open_file.lua` "asks git for the bytes it shows and six more…" |
| f2 (G2) | `process.lua`: `collect_first_bytes(request.first_stdout_bytes, stop)` → `collect_first_bytes(request.first_stdout_bytes, function() if not ended then process:kill('sigkill') end end)` | killed by assertion: `test_git_process.lua` "is stopped with a process it started that holds its output" |
| f3 (m7) | `content.lua`: `first_bytes ~= nil and entry.size ~= nil and entry.size > first_bytes` → `first_bytes ~= nil and entry.size ~= nil` | killed by assertion: "bounds git’s output only when…" for 13 and 14. m7 was not equivalent: a fake `run` sees the request |
| f4 | `process.lua`: `if cut then` → `if cut and not timed_out then` (the two checks of `outcome()` swapped in effect) | killed by assertion: "is answered, not timed out, when its limit runs out as the bytes asked for come" |
| f5 | `content.lua`: `first_bytes ~= nil and entry.size ~= nil and entry.size > first_bytes` → `first_bytes ~= nil and entry.size > first_bytes` | killed: by assertion in "whose object git cannot read…" (repository and `gf`), by a Lua error (`attempt to compare number with nil`, a crash) in "is read whole when git gives no size for it" |
| f7 | `diffs.lua`: `LONGEST_CHARACTER_BYTES = 6` → `= 4` | killed by assertion: "asks git for the bytes…" and the six-byte lead |
| f8 | `content.lua`: the line `request.arguments = vim.list_extend(vim.list_slice(STREAMING_SETTINGS), request.arguments)` removed | killed by assertion: "read within a bound lets git stream a packed file that is not a delta" |
| f9 | `content.lua`: `done(nil, file.stdout, entry.size or #file.stdout)` → `done(nil, file.stdout, entry.size)` | killed by assertion: "whose size git does not give has the length of its text for its size" (the first run, before that case was written, survived both files) |

## Task lines

- T56 `[X]` (`bugfix/t56-commit-file-read`, into `dev`) — a commit's file is read no further than `gf` shows it (C13, C15; wave 13's A183): the git home reads the file's size from `ls-tree -l`, in the call that finds the file, and stops `git cat-file` once the bytes `gf` asks for (`SHOWN_BYTES` plus 6) have come; the buffer and its note's words are unchanged, the note giving git's size; the rulings A199–A203 and A213–A216 are the orchestrator's assumptions.

## Commits

- PR #192, `bugfix/t56-commit-file-read`, head `934a3e5` (4 commits), merged by rebase into `dev` as `62ef90a` (the bounded read), `c2909c6` (this note), `e58133f` (the fix round), `0fa01e4`.
- Released in v0.2.30 (PR #194, `main` `df18964`).
