# 2026-10-12 — T53 Files window keys

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t53-files-keys` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D34, D46, D47, D48, D55–D57, C13, C15, T53
- Wave plan: [[Implementation/Waves/00013-worktrees-landed/plan]]; brief and its dispatch amendment: [[Implementation/Waves/00013-worktrees-landed/brief-t53-files-keys]]
- Rests on: [[Sessions/2026-10-12 — T50 Worktree filter]], [[Sessions/2026-10-12 — T51 Landed reads]], [[Sessions/2026-10-12 — T52 Landed]]

## What was done

A file listed under a commit opens as that commit has it, and the files window gains `h` and `l` (D57; the user's U4 (a)). The orchestrator's rulings O17 (a) = A152, O18 (a) = A153 and the plan's A4 = A157 are its assumptions under the user's instruction of 2026-10-06, not the user's decisions.

- **`gf`** (`lua/aineo/changes/commit_file.lua`, new; `init.lua`'s `show_commit_file()`): on a file listed under a commit of the session, a landed one or another worktree's, or under *Landed*, the file as that commit (under *Landed*, the working branch's commit the commits window last read) has it, read through `git.file_at_commit()` in the editor's repository, which shares the object store of the others. The buffer is `aineo://show/{id}/{path}` (`diffs.file_buffer()`): read-only, not modifiable, wiped once hidden, `'filetype'` from `vim.filetype.match()` on the path and the content, shown in the middle column through the session's `show_diff` with the cursor moved to it. A file the commit deleted (`path_missing`) opens nothing and is told as deleted in that commit; any other failure is told once, naming the file. Under *Uncommitted*, *Session work* and another worktree's whole change `gf` is T45's.
- **`l`** is Enter's function on the same line: Enter's diff, in Enter's buffer.
- **`h`** (`lua/aineo/changes/head_diff.lua`, new): the listed file's entry marked `against_head`; `entry_diff.read()` and `name()` hand a marked entry to `head_diff`, so `F`, the focus move, the last-key rule and the failure messages are Enter's. Per filter: a commit (session's or landed) straight to `HEAD` (`git.file_diff_straight()`, `HEAD` from `git.resolve_commit()`), `aineo://head/commit/{id}/{path}`; another worktree's commit, to that worktree's `HEAD`, in its repository, `aineo://worktree{top}//head/commit/{id}/{path}`; *Landed*, from `HEAD` straight to the working branch's commit, `aineo://head/landed/{path}`; *Uncommitted* and *Session work*, `git.uncommitted_file_diff()`, `aineo://uncommitted/{path}`; another worktree's whole change, `aineo://worktree{top}//head/{path}`.
- **`diffs.lua`**: the one shown-buffer mechanism serves `diff_buffer()` and the new `file_buffer()`. **`init.lua`**: `show_buffer()` (the show, the focus move, the no-room and error messages) is split from `show_diff()`; `show_last()` takes a `Showing` (a name and a `show` function), so one counter orders the last of Enter, `l`, `h` and `gf`.
- **`doc/aineo.txt`**: *aineo-changes*: the `gf` paragraph (a commit's file; the working tree's file under Uncommitted and Session work; the worktree refusal narrowed to its whole change) and a paragraph for `h` and `l`. LIMITS had nothing on `gf`.

## Dispatch amendment

The first commit (A179) re-checks the brief against `dev` `70a52bc`; it found no fact that changes what to build. The amendment says `lines.lua` is outside the boundary, so the `HEAD` reading is carried by a field on a copy of the entry (`head_diff.of()`), not by a new field of `aineo.changes.Entry`.

## Unit list

1. `gf` under a session commit shows the commit's text; 2. not modifiable; 3. through `show_diff`, the cursor moved; 4. the filetype of the path and the content; 5. *Landed*; 6. a landed commit; 7. a file the commit deleted; 8. any other failure, told once; 9. no room; 10. read while textlock holds; 11. two keys, the last one's file; a late failure not told; 12. the quoted name; 13. cut at 1 MiB; 14. another worktree's commit; *Landed* gone; *Uncommitted* unchanged. Then `l` (Enter's), `h` under a commit, a landed commit, *Landed*, *Session work* and *Uncommitted*, another worktree's commit and whole change, a file `HEAD` lacks, a rename, lines that list no file, the focus move and `F`, the last of `h` and `l`, the maps' scope and their return with the buffer, the failures, the quoted name.

## Red and green

Seen red, for the intended reason (read from the output): `gf` under a session commit (`aineo://show/...` expected, the working tree's path got); `gf` under *Landed* (the working tree's path got); deleted-file, unreadable and no-room cases of `gf` (the nil text or the missing `told` in the first design); `l` and `h` under a commit (nothing shown, the 20 s wait ran out); `h` under *Landed*, under *Session work*, under *Uncommitted*, under another worktree's commit (the name without the worktree), and under its whole change (the read for its kind missing).

Arrived green, with the reason: the landed commit's file (the commit kind already covers it; killer T1 below); the `gf` filetype, not-modifiable and middle-column cases (`file_buffer()` and `show_commit_file()` were written in the same unit as the first case); the 1 MiB cut and the quoted name of `gf`, the late failure, *Landed* gone and another worktree's commit (code written ahead of their tests); `gf` under *Uncommitted* (unchanged code); for `h`, a renamed file, a file `HEAD` lacks, a landed commit (the commit kind covers them), the lines listing no file, the maps' scope and their return with the buffer, `HEAD` naming no commit, *Landed* gone, the unreadable diff, the last of `h` and `l`, the quoted name of `h`, the focus move and `F` (the shared pipeline). Each has its mutant below.

## Mutants

Literal edits (`.tests/t53-mut.lua`, ids T/G on the `gf` commits, T/H on the `h` and `l` commits; the `gf` ones ran on `test_changes_open_file.lua` before the keys existed, T1 re-run there, T2–T5 and H on `test_changes_keys.lua`), each applied to a copy and restored in the same call, run on the case's own file. Kinds are read from the output.

| # | Edit | Killed by |
|---|---|---|
| T1 | `commit_file.lua`: `lists_file_at_a_commit` returns false (the plan's 1) | assertion, 13 (`gf` opens the working tree's file) |
| T2 | `head_diff.lua`: `M.of()` returns `entry` (h is l; the plan's 2) | assertion, 13 |
| T3 | `init.lua`: the keys `'l'` and `'h'` swapped (the plan's 3) | assertion, 15 |
| T4 | `diffs.lua`: `file_buffer()` leaves `'modifiable'` on (the plan's 4) | assertion, 1 |
| T5 | `init.lua`: `buffer = buffer,` removed from `h`'s options (the plan's 5) | assertion, 3 (the commits window, a diff, another buffer) |
| G3 | `diffs.lua`: `filetype or ''` → `''` | assertion, 2 |
| G4 | `diffs.lua`: `vim.filetype.match({ filename = path, contents = text })` → `{ filename = path }` | assertion, 1 (the shebang script) |
| G5 | `commit_file.lua`: `'commit' or … == 'landed'` → `'commit'` | assertion, 2 |
| G6 | `commit_file.lua`: `failure.reason == 'path_missing'` → `~=` | assertion, 2 |
| G8 | `init.lua`: `show_last()`'s stale branch removed | survived `test_changes_open_file.lua`; assertion, 3, in `test_changes.lua` (the textlock-then-another-file cases) |
| G8b | `init.lua`: the `this_enter ~= enters` guard of `show_commit_file()`'s read removed | assertion, 1 (the late failure, added after G8 showed the guard unpinned) |
| G9 | `init.lua`: `buffer ~= nil and show_buffer(…)` → `buffer == nil or show_buffer(…)` | assertion, 1 (the textlock case; the wait ran out) |
| G10 | `init.lua`: `lines.words_of(unreadable)` → `''` | assertion, 1 (*Landed* gone) |
| G11 | `init.lua`: the no-room `told` → the path alone | assertion, 1 |
| G12 | `commit_file.lua`: `return entry.change ~= nil and not entry.worktree and (…` | assertion, 1 (another worktree's commit) |
| G13 | `diffs.lua`: `lines_shown_for(content, 'file')` → `'diff'` | assertion, 1 |
| G15 | `commit_file.lua`: the path unquoted in `M.name()` | assertion, 1 |
| H6 | `head_diff.lua`: `session_work` folder `'uncommitted'` → `'head'` | assertion, 1 |
| H6b | `head_diff.lua`: `uncommitted` folder `'uncommitted'` → `'head'` | assertion, 1 (`h` under *Uncommitted*) |
| H7 | `head_diff.lua`: `from HEAD, to the tip` swapped (landed) | assertion, 1 |
| H8 | `head_diff.lua`: the commit and `HEAD` swapped (commit) | assertion, 6 |
| H9 | `head_diff.lua`: `in_worktree.repository = source.repository` | assertion, 2 |
| H10 | `head_diff.lua`: `if not entry.worktree then` → `if true then` in `M.name()` | assertion, 2 |
| H11 | `entry_diff.lua`: the `head_diff.name()` dispatch removed | assertion, 10 |
| H12 | `entry_diff.lua`: the `head_diff.read()` dispatch removed | assertion, 11 |
| H15 | `head_diff.lua`: the `if not head then done(NO_HEAD)` block removed | assertion, 1 |
| H16 | `head_diff.lua`: the unreadable-*Landed* guard removed | assertion, 1 |
| H17 | `head_diff.lua`: the path unquoted in `M.name()` | assertion, 1 |
| H18 | `init.lua`: `local entry = diffed(listed)` → `listed` | assertion, 14 |
| H14 | `init.lua`: the `if not listed then return end` guard of `show_diff_at_cursor()` removed | **crash class**: the plugin's callback raised (`vim.validate` in `diffed`) and `type_keys` surfaced it; 4 cases |

## Departures and unsettled

- **The commit's file is cut at the 1 MiB the diffs are cut at**, with a last line `aineo cut this file at 1 MiB: …`, where the brief says the buffer holds "the bytes git printed". Syntax on a longer text costs the editor more than a reader gains; reported, one case pins it, and it is the orchestrator's to overrule.
- A buffer's `'readonly'` is not set: "read-only" is read as the diffs' (`'modifiable'` off, a scratch buffer), the plan's mutant 4.
- A commit of another worktree is read in the editor's repository (T51: the object store is shared) and `h` in the worktree's own repository; a worktree section with no repository cannot list a file, so `head_diff` has no branch for it and a nil repository would raise.
- `gf` and `h` on a file of a commit keep no index of the files shown: each key reads the text again.
- The real layout was exercised in a scratch case, outside the suite (`tests/test_entry_changes.lua` is not in the boundary): `gf` under a commit showed `aineo://show/{id}/notes.txt` in the file column with `'filetype'` `text` and `'modifiable'` off; `h` then took the same middle window with `aineo://head/commit/{id}/notes.txt`.

## Pins moved

- `tests/test_changes_open_file.lua`: the case `under a commit filter opens the working tree's file` is replaced by `under a commit shows the file as the commit had it, not the working tree's file` (A2 of T45 is replaced by D57); `BEGIN_AND_SHOW` takes a working branch and a `_G.no_room`.
- A race in the file's new helper: the session's base is read after `begin_session()`, so a commit made at once could become the base; the helpers wait for the commits window to say `No commits on this session` first.

## Whole suite

Once on the tree pushed (Neovim 0.12.5, host): **2892 cases**, 82 groups, `Fails (1)`: `test_changes_filter.lua` › *the commits window › has its cursor on Session work again when its buffer is made anew* (`{1,0}` for `{2,0}`). It is a timing flake of code this packet does not touch: that file alone, three runs on this tree, failed 1 of 3 (the same case); five runs on `origin/dev` `70a52bc` in a detached worktree, 1 of 5 (the same case). 2848 cases before this packet (T52's count), 44 added here.

## Task lines

- T53 `[X]` (`feature/t53-files-keys`, into `dev`) — a commit's file opens from that commit under `gf`; `h` and `l` in the files window (C15, C13; D57): `l` is Enter's diff, `h` the file against `HEAD` by filter, `gf` shows the file read-only in the middle column; U4 (a) is the user's; the orchestrator's rulings A152, A153, A157 are its assumptions.

## Commits

Recorded after the merge.
