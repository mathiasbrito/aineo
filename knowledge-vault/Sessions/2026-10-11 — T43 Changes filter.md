# 2026-10-11 — T43 Changes filter

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet, A104; the first two commits carry `Claude Opus 5.5 (1M context)` in their `Co-Authored-By:` trailer, which names the wrong model and is not rewritten, A116; the fix round's commits name Sonnet 5.5)
**Branch:** `feature/t43-changes-filter` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D47, D19, D33, D41, D46, C13, C15, T43
- [[Implementation/Waves/00010-changes-filter/plan]] and [[Implementation/Waves/00010-changes-filter/brief-t43-changes-filter]] (the orchestrator's rulings A93–A111, to be read as the orchestrator's assumptions, never the user's decisions)
- Rests on: [[Sessions/2026-10-08 — T38 Changes worktrees]] (the other worktrees' sections, unchanged), [[Sessions/2026-10-09 — T42 Focus diff]] (Enter's focus move, unchanged)

## What was done

**The git home (C13), `lua/aineo/git/`** — six new reads, each asynchronous, bounded, never raising:
- `commit_files(found, commit, done)` — `git show --format= --name-status -z -M --root --no-show-signature --diff-merges=first-parent`: a commit's files against its first parent; a merge lists what it brought in (`evidence/w10-probes.txt`, P2); a root commit lists its files, whatever `log.showRoot` says; a signed commit's list is not preceded by git's signature line, whatever `log.showSignature` says; an empty commit none.
- `commit_file_diff(found, commit, change, done)` — the commit's header and one file's change, a rename asked with both paths (as `tracked_diff()` does).
- `uncommitted_files(found, done)`, `uncommitted_file_diff(found, change, done)`, `uncommitted_diff(found, done)` — what differs from `HEAD`, read as `HEAD` is **now** (`repository.read_head()`), not as the repository was found: before the first commit every file is new.
- `diff_since(found, base, done)` — the whole diff from a base (the empty tree for none) to the working tree, the untracked files (an untracked repository with no commit left out) entered through `git add --intent-to-add --pathspec-from-file` on the private index copy (P4), their paths in a NUL-separated file beside it; `uncommitted_diff` is the same from `HEAD`.
- `commit_diff` now shows a merge against its first parent (`--diff-merges=first-parent` in `COMMIT_HEADER`).

**The changes home (C15), `lua/aineo/changes/`** — still requiring only `aineo.git`:
- `filter.lua` (new): the three kinds of filter, `key()` (a commit's id, or a NUL-led key no id can equal), `same()`.
- `pause.lua` (new): `restartable(ms, act)`, one timer made at the first restart and not running between a pause's end and the next restart.
- `entry_diff.lua` (new): how an entry's diff is read, named and told, by filter kind and by what it is (a file or the whole line); the other worktrees' entries keep their reads and names.
- `lines.lua`: the commits window's two fixed lines and the files window's first line (`Files in: …`), whole in the new `AineoChangesFilter` group (`colours.lua`, linked to `Title`); `No uncommitted changes` and `No files in this commit`; `*` marks dropped under a commit. An `Entry` carries `filter` for the editor's own worktree's commits-window lines and files.
- `init.lua`: `session.selected` (the filter the cursor last selected), `session.listed` (the filter whose files the files window lists, with its list), `session.cursor_unplaced`. The files window is read for the selected filter through the same `window_read()` as before, so a filter change is one read of the window, ordered with every other, and the files window keeps its first line and list until the new list arrives. `CursorMoved` in the commits buffer restarts one 150 ms pause (`SELECTION_PAUSE_MS`); at its end, a line that lists a filter other than the selected one selects it and asks for the read. *Session work* is selected again, the cursor with it, in `follow_changes_session()`, when the commits buffer is made anew, and when the selected commit is not among the commits read.
- `pages.lua`: `line_of(buffer, key)`, the line that lists an entry key.

**`doc/aineo.txt`** — *aineo-panes*' changes-pane item, *aineo-changes* (the files window, the commits window, Enter), the colours paragraph and `hl-AineoChangesFilter`, and two LIMITS items under *The changes pane*. `tests/test_doc.lua` stays green.

## Decisions and departures from the brief

- **A filter change reads the whole files window again, the other worktrees' sections included** (through `window_read()`), where the brief says only that the files window "is read for it". A second read path for the editor's own list would need its own ordering against the first (two reads of one window in flight); `window_read()` already gives one read at a time with the editor's own list ahead of the next worktree's. Recorded in LIMITS. Rejected: the second path.
- **Six exports, not four reads:** the brief's four reads name `uncommitted` as one; Enter on a file and on the line each need `HEAD` as it is now, so `uncommitted_file_diff` and `uncommitted_diff` exist beside `uncommitted_files`.
- **No `BufWinEnter` placing of the cursor:** it survived its mutant (12) and was removed; the cursor is put on *Session work* by the first page written with the line in a window, which every showing of the pane produces by reading it. (The first push also removed the `cursor_unplaced` guard and `--root` as "dead"; the fix round shows both reachable and restores them, under "Fix round" below.)

## Unit list (stated before the first test)

1. `commit_files`: kinds against the parent; root and empty; a merge's first parent; an option-like id refused.
2. `uncommitted_files`: staged, unstaged, untracked; clean; before the first commit; `HEAD` of now.
3. `commit_diff` of a merge; `commit_file_diff`: header and one file; a rename; a merge; an option-like id.
4. `uncommitted_file_diff`: from `HEAD`; untracked; before the first commit.
5. The whole diffs: from `HEAD`, from a base, from no base; the real index untouched; a clean checkout.
6. The commits window's fixed lines; the cursor on *Session work* (first showing, late showing, made anew, kept on a re-read).
7. The files window's first line; *Uncommitted*, a commit, an empty commit; the pause (once, after it, files unchanged before it); a line that lists no filter; the window closed within the pause; follow another session; the selected commit gone.
8. The save marks under *Session work*, *Uncommitted* and a commit.
9. Enter: a file under each filter; the whole diffs; a commit.
10. The colours and the group.
11. The pins D47 moves, in the suites below.

## Red and green

**Seen red (before the code):** `tests/test_git_changes.lua` 8 (`commit_files` ×4, `uncommitted_files` ×4: `git.commit_files`/`git.uncommitted_files` absent); `tests/test_git_diffs.lua` 12 of 13 (the merge `commit_diff` by content, `commit_file_diff` ×4, `uncommitted_file_diff` ×3, the whole diff ×4); `tests/test_changes_filter.lua` 26 of 26 (the first run, each failing on the missing lines or the missing entries).

**Arrived green:** `test_git_diffs.lua` › *the whole diff* › *leaves the real index as it was, the untracked files untracked* — green by nature while the function was missing (the raise is caught by `_G.await`); killed by mutant 6 once it existed. `test_changes_filter.lua` › *has its cursor on Session work again when its buffer is made anew* — pinning code written ahead of its test; killed by mutant 2c. `test_changes_filter.lua` › *is not followed once the window closed within the pause, telling nothing* — pinning a guard written ahead of its test; killed by mutant 8b.

**Changed after a mutant survived (the first version of the test was wrong):** *is read after a pause, once…* survived mutant 1 (no pause) twice. First, its keys were sent so fast that Neovim ran one `CursorMoved`; then, with each key seen, a read already under way (the watch re-reading after the commits) made the window's reads coalesce into the last selection (`aineo.changes.serial`), hiding the reads a missing pause makes. The case now stubs the watch, waits until no git call of the home is outstanding, and sends its keys 10 ms apart. Killed by assertion since.

**Pins moved** (each line D47 changes, in the files that pin it): `tests/test_changes.lua`, `tests/test_changes_sessions.lua`, `tests/test_changes_worktrees.lua`, `tests/test_entry_changes.lua`, `tests/test_entry_panes.lua`. The expectations of the changes pane's lists gained the two or one first lines; the Enter cases move the cursor to a file's or a commit's line first (`j`, or a cursor line one or two lower); the colour pins gained the group of the new lines (`below_files_heading()`, `below_commit_filters()`). `tests/test_layout_panes.lua`, `tests/test_entry_session_handover.lua` and `tests/test_entry_session_switch.lua` needed no change (they assert a list *contains* a line, or none of the pane's lines). `tests/test_layout_diffs.lua` pins the layout's own diffs and needed none.

## Mutants

Each applied to a copy of the committed file and restored in the same call; the covering suite is the new filter suite, or the git suites for the git reads. A kill is an equality assertion read from the output, never a Lua error.

| # | Literal edit | Result |
|---|---|---|
| 1 | `init.lua`: `      selection_pause.restart()` → `      select_filter_at_cursor()` (no pause) | killed — *is read after a pause, once…*: `{ "uncommitted_files", "commit_files" }` against `{ "commit_files" }` |
| 2 | `init.lua`, in `M.pane_buffers()`: `select_session_work()` → `session.selected = filter.UNCOMMITTED` and the cursor to be placed (*Session work* not selected) | killed — 22 cases |
| 2a | `init.lua`, in `begin_session()`: `selected = filter.SESSION_WORK,` → `selected = filter.UNCOMMITTED,` | survived: shadowed — `M.pane_buffers()` selects *Session work* before any read the session starts can run; the field is kept for its type |
| 2b | `init.lua`: `nvim_win_set_cursor(window, { line, 0 })` → `{ 1, 0 }` (the cursor left on line 1) | killed — 5 cases |
| 2c | `init.lua`: the reset on a commits buffer made anew removed | killed — *has its cursor on Session work again when its buffer is made anew* |
| 3 | `git/changes.lua`: `'--diff-merges=first-parent',` removed from `commit_files` | killed — *the files a commit changed…for a merge, those it brought in* (`test_git_changes.lua`) |
| 4 | `lines.lua`: `local saved = kind == 'commit' and {} or view.saved` → `local saved = view.saved` | killed — *the save marks are dropped under a commit*: `"* M a.txt"` against `"  M a.txt"` |
| 5 | `entry_diff.lua`: `git.uncommitted_file_diff(…)` → `git.file_diff(source.repository, source.base, …)` | killed — *Enter on a file under Uncommitted shows its diff from HEAD*: `-one` against `-two` |
| 6 | `git/diffs.lua`: the `environment = environment,` line of the `git add --intent-to-add` run removed (the real index) | killed — 4 cases, the real-index one: `" A new.txt"` against `"?? new.txt"` |
| 7 | `git/diffs.lua`: `if #paths == 0 then` → `if true then` (no untracked file entered) | killed — 3 cases |
| 8 | `init.lua`: `and not session.cursor_unplaced` removed from `select_filter_at_cursor()` | survived the first round's suite, and was wrongly called unreachable and removed; reachable with git slower than the pause, restored and pinned in the fix round (8 again, below) |
| 8b | `init.lua`: `and vim.api.nvim_win_is_valid(window)` removed | killed — *is not followed once the window closed within the pause*: "Invalid window id" in `:messages` |
| 9 | `init.lua`: `and not lists_commit(session.selected, since.commits)` → `and false` | killed — *…when the selected commit is no longer listed* |
| 10 | `init.lua`: `select_session_work()` removed from `follow_changes_session()` | killed — *…when the pane follows another Claude session* |
| 12 | `init.lua`: the `BufWinEnter` placing of the cursor emptied | survived — redundant; the autocommand was removed |
| 15 | `lines.lua`: `filter = filter.of_commit(commit)` removed from a commit's entry | killed — 8 cases |
| 17 | `git/changes.lua`: `found.head` read in place of `HEAD` of now in `uncommitted_files` | killed — *are read against the HEAD of now* |
| 18 | `git/changes.lua`: `'--root',` removed from `commit_files` | survived the first round's suite, and was wrongly called redundant and removed; `log.showRoot=false` makes it needed, restored and pinned in the fix round (18 again, below) |

The table holds 21 mutants of the first round (1, 2, 2a, 2b, 2c, 3, 4, 5, 6, 7, 8, 8b, 9, 10, 12, 15, 17, 18, 19, 20, 21); the packet's own "22" was a miscount. Mutants 6 and 7 were measured on the code as it was before the fix round rewrote the `git add` run; the fix round's table measures them again on the new code.
| 19 | `git/diffs.lua`: a rename asked with its new path alone (`false and { old, new }`) | killed — *of a renamed file is its rename, asked with both paths* |
| 20 | `git/diffs.lua`: `'--diff-merges=first-parent',` removed from `COMMIT_HEADER` | killed — the two merge cases of `test_git_diffs.lua` |
| 21 | `init.lua`: *Uncommitted* read with `git.changed_files(repository, base, …)` | killed — 6 cases |

## Suites

On Neovim 0.12.5 (git 2.50.1), on the tree pushed: `make test` — 2543 cases in 75 groups, `Fails (0)`, exit 0 (2494 at wave 9's close plus 49 new: `test_changes_filter.lua` 28, `test_git_changes.lua` 8, `test_git_diffs.lua` 13). Files run alone while working: `test_changes_filter` 28, `test_changes` 126, `test_changes_sessions` 80, `test_changes_worktrees` 40, `test_entry_changes` 13, `test_entry_panes` 86, `test_entry_session_handover` 12, `test_entry_session_switch` 15, `test_layout_panes` 38, `test_git_changes` 17, `test_git_diffs` 30, `test_doc` 44, each `Fails (0)`. `make lint`: StyLua clean, selene 0 errors, 0 warnings.

## Fix round — the two reviews of PR #159

**The orchestrator's assumptions (A115–A117), to report to the user, none a decision of the user's:** A115 — A95's "everywhere" stands: Enter on another worktree's merge commit shows its diff against the first parent too (`COMMIT_HEADER` is shared; the help now says so; it departs from the brief's "every line of another worktree, and what Enter does on it, stays exactly as today" for merge commits only). A116 — the pushed commits keep their trailers; the fix round's commits name Sonnet 5.5, the model the implementer ran on. A117 — a surviving mutant does not make its code dead: code is deleted only once the state is shown unreachable.

| Finding | What was done | Case (red first) |
|---|---|---|
| Attack 1, `log.showSignature=true` | `--no-show-signature` in `commit_files` | `test_git_changes.lua` › *are those of a signed commit whatever log.showSignature says* (ssh-signed): red, then green |
| Attack 2, `log.showRoot=false` | `--root` restored (`doc/aineo.txt` "a root commit its files" true again) | › *are every file of a root commit whatever log.showRoot says* |
| Attack 3, the unplaced cursor | the `cursor_unplaced` guard restored; the first round's "unreachable" was wrong: a commits page written before a slow `git log` shows the cursor on line 1 | `test_changes_filter.lua` › *keeps Session work selected when its buffer is made anew and git answers slower than the pause* (`Files in: Uncommitted`, cursor `{1,0}` before) |
| Attack 4, an untracked repository with no commit | `ls-files` entries ending in `/` left out of the list | `test_git_diffs.lua` › *leaves out an untracked repository with no commit…* |
| Attack 5, the argument limit | the paths go in a NUL-separated file beside the private index (`--pathspec-from-file`, `--pathspec-file-nul`), removed after git ran; the LIMITS item is gone | › *names its untracked files to git in a file, removed afterwards, whatever they are called* (names `-x.txt`, `[ab].txt`, `a b.txt`; the stand-in git logs the call). No 14,000-file case |
| Attack 6, a failed read | a failed read of another filter lists that filter with no files, under its failure line; a failed read of the filter already listed keeps its files | `test_changes_filter.lua` › *failing to read the files of a commit says so under that commit’s own first line* |
| Attack 7 | A115; help and PR say it; no code change | — |
| Tests 1 | | `test_changes_worktrees.lua` › *a cursor on another worktree’s commit or heading keeps the filter* (arrived green; killer mA) |
| Tests 2 | | `test_changes_filter.lua` › *restarts its pause at every move of the cursor, reading once after the last* (keys 60 ms apart; arrived green; killer mT) |
| Tests 3 | case renamed *keeps the first line and the list until the new list arrives* (it pins the synchronous half only; a gated read would pin the rest) | — |
| Tests 4, 6, 7 | the table's count is 21 and mutant 2's map is 2b and 2c (above); the LIMITS sentence reworded; the `## Task lines` line in the peers' form | — |
| Tests 5 | A116 | — |

**Mutants of the fix round** (literal edits, each restored in the same call, every kill an assertion): mA (`lines.lua`, `in_worktree()` adds `filter = entry.filter or (entry.commit and filter.of_commit(entry.commit))`) killed by the new worktrees case (`Files in: c9b2a57 The agent’s` for `Files in: Session work`); mT (`pause.lua`, `timer:stop()` → `if timer:is_active() then return end`) killed (`{ "commit_files", "commit_files" }`); 8 (the guard removed) killed (`Files in: Uncommitted`, `{ 1, 0 }`); mFail (`if not failure or not (…)` → `if not failure then`) killed; 18 (`--root` removed) killed; mSig (`--no-show-signature` removed) killed; mNested (`return not vim.endswith(path, '/')` → `return true`) killed; mRemove (`os.remove(list)` removed) killed; mNul (`--pathspec-file-nul` removed) killed; mEnv (`environment = environment,` removed from the `add` run) killed ×6; 7 (`if #paths == 0` → `if true`) killed ×5 (four by assertion, one by a crash after its failed precondition).

**Suites.** `make test`, Neovim 0.12.5, the tree pushed: 2551 cases in 75 groups, `Fails (0)` (2543 + 8: `test_git_changes` +2, `test_git_diffs` +2, `test_changes_filter` +3, `test_changes_worktrees` +1). `make lint` clean.

## Open threads

- The orchestrator's check, and the reviewers, should look first at: the `serial` coalescing of a filter change with the watch's reads (a filter change is one read of the window and the other worktrees follow it); `place_commits_cursor()` called from `show_commits()` and from nothing else; the Enter cases that now step `j` first.
- A hold of textlock that refuses the commits page after a reset leaves the cursor on a stale row until the next write; no `CursorMoved` can happen meanwhile.

## Task lines

Marked done in the v1 plan note by wave 10's closing knowledge pass (PR #159, wave 10; released in v0.2.20). The line as the wave holds it:

- [X] T43 — the commits window as a filter (C15, C13; D47): *Uncommitted* and *Session work* above the session's commits, the line under the cursor choosing, after a 150 ms pause, what the files window lists (named on its first line), Enter's diff within the filter and the two whole diffs, `*` marks under those two only, the other worktrees unchanged (PR #159, into `dev`, wave 10) — regular. The five mutants of `plan.md` › *Verification mutants* › T43 map to this note's mutants 1, 2b and 2c, 3, 4 and 5.

## Commits

Recorded after the merge, by wave 10's closing knowledge pass. PR #159 merged by rebase as `a0e0134` … `5c7e21d` (3 commits); the orchestrator verified the pull request's head `ec30c46`, rebased on `dev` `e6a0295`: the whole suite 2551 cases, `Fails (0)`, lint clean, and the mutant dropping `--no-show-signature` killed by assertion. Released in v0.2.20 (PR #160, `main` `f647cfd`).

| Branch | `dev` | Subject |
|---|---|---|
| `8ea7f3f` | `a0e0134` | Filter the files window by the commits window's cursor line (T43) |
| `eb6f308` | `6498026` | Drop what no mutant could see; pin the pause and the reselection (T43) |
| `ec30c46` | `5c7e21d` | Answer the review of T43: restore what the mutants hid, fix four reads |

The `Branch` column is the pull request's own commits (`refs/pull/159/head`); the verified head `ec30c46` is the last of them. The session note itself is in the packet's first commit; the fix round's note text is in the third.
