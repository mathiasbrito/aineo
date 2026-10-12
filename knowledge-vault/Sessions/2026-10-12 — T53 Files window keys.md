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

- **`gf`** (`lua/aineo/changes/commit_file.lua`, new; `init.lua`'s `show_commit_file()`): on a file listed under a commit of the session, a landed one or another worktree's, or under *Landed*, the file as that commit (under *Landed*, the working branch's commit the commits window last read) has it, read through `git.file_at_commit()` in the repository of the worktree that lists the commit, the editor's otherwise (first read in the editor's repository; corrected in the fix round). The buffer is `aineo://show/{id}/{path}` (`diffs.file_buffer()`): read-only, not modifiable, wiped once hidden, `'filetype'` from `vim.filetype.match()` on the path and the content, shown in the middle column through the session's `show_diff` with the cursor moved to it. A file the commit deleted (`path_missing`) opens nothing and is told as deleted in that commit; any other failure is told once, naming the file. Under *Uncommitted*, *Session work* and another worktree's whole change `gf` is T45's.
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

Arrived green, with the reason: the landed commit's file (the commit kind already covers it; killer M1 below); the `gf` filetype, not-modifiable and middle-column cases (`file_buffer()` and `show_commit_file()` were written in the same unit as the first case); the 1 MiB cut and the quoted name of `gf`, the late failure, *Landed* gone and another worktree's commit (code written ahead of their tests); `gf` under *Uncommitted* (unchanged code); for `h`, a renamed file, a file `HEAD` lacks, a landed commit (the commit kind covers them), the lines listing no file, the maps' scope and their return with the buffer, `HEAD` naming no commit, *Landed* gone, the unreadable diff, the last of `h` and `l`, the quoted name of `h`, the focus move and `F` (the shared pipeline). Each has its mutant below.

## Mutants

Each row is the literal edit (file: before → after), applied to a copy of the file at the commit named, run on the test file that covers it, restored in the same call. A row run on `140dbe3`/`d49e1c8` (the `gf` commits) or on `d103e9d`/`8818993` (the `h` and `l` commits) names code that the fix round changed in places; the fix round's own mutants are F1–F11 below. Kinds are read from the output. The ids are M1–M30 in the order below; no id is skipped.

| # | Edit | Killed by |
|---|---|---|
| M1 (plan 1) | `commit_file.lua`: `return entry.change ~= nil and (entry.filter.kind == 'commit' or entry.filter.kind == 'landed')` → `do return false end` | assertion, 13 |
| M2 (plan 2) | `head_diff.lua`: `return vim.tbl_extend('force', entry, { against_head = true })` → `return entry` | assertion, 13 |
| M3 (plan 3) | `init.lua`: in `map_compare_keys()`, `vim.keymap.set('n', 'l', function()` and `vim.keymap.set('n', 'h', function()` exchanged | assertion, 15 |
| M4 (plan 4) | `diffs.lua`: `return shown_buffer(name, text, filetype or '')` → `local made = shown_buffer(name, text, filetype or '') if made then vim.bo[made].modifiable = true end return made` | assertion, 1 |
| M5 (plan 5) | `init.lua`: `buffer = buffer,` deleted from the options of the `h` map | assertion, 3 (the commits window, a diff, another buffer) |
| M6 | `diffs.lua`: `return shown_buffer(name, text, filetype or '')` → `return shown_buffer(name, text, '')` | assertion, 2 |
| M7 | `diffs.lua`: `vim.filetype.match({ filename = path, contents = text })` → `vim.filetype.match({ filename = path })` | assertion, 1 (the shebang script) |
| M8 | `commit_file.lua`: `entry.filter.kind == 'commit' or entry.filter.kind == 'landed'` → `entry.filter.kind == 'commit'` | assertion, 2 |
| M9 | `commit_file.lua`: `failure.reason == 'path_missing'` → `failure.reason ~= 'path_missing'` | assertion, 2 |
| M10 | `init.lua`: in `show_last()`, `if this_enter ~= enters then if diffs.wipe_unshown(showing.name) then return end elseif showing.show(text) then` → `if showing.show(text) then` | survived `test_changes_open_file.lua`; assertion, 3 in `test_changes.lua` (the textlock-then-another-file cases) |
| M11 | `init.lua`: in `show_commit_file()`, the lines `if this_enter ~= enters then return end` after `commit_file.read(…, function(failure, text)` deleted | assertion, 1 (the late failure, added after M10 showed the guard unpinned) |
| M12 | `init.lua`: `return buffer ~= nil and show_buffer(buffer, window, told)` → `return buffer == nil or show_buffer(buffer, window, told)` | assertion, 1 (the textlock case; the wait ran out) |
| M13 | `init.lua`: `lines.words_of(unreadable)` → `''` | assertion, 1 |
| M14 | `init.lua`: `local told = ('%s in %s'):format(lines.quoted_path(path), revision.told)` → `local told = lines.quoted_path(path)` | assertion, 1 |
| M15 | `commit_file.lua`: `return entry.change ~= nil and (` → `return entry.change ~= nil and not entry.worktree and (` | assertion, 1 |
| M16 | `diffs.lua`: `lines_shown_for(content, 'file')` → `lines_shown_for(content, 'diff')` (the code before the fix round) | assertion, 1 |
| M17 | `commit_file.lua`: `revision.commit, lines.quoted_path(path))` → `revision.commit, path)` | assertion, 1 |
| M18 | `head_diff.lua`: in the folders, `session_work = function() return 'uncommitted' end` → `… return 'head' end` | assertion, 1 |
| M19 | `head_diff.lua`: in the folders, `uncommitted = function() return 'uncommitted' end` → `… return 'head' end` | assertion, 1 (`h` under Uncommitted) |
| M20 | `head_diff.lua`: in `READS.landed`, `source.repository, head, source.landed.tip,` → `source.repository, source.landed.tip, head,` | assertion, 1 |
| M21 | `head_diff.lua`: in `READS.commit`, `source.repository, entry.filter.commit.id, head,` → `source.repository, head, entry.filter.commit.id,` | assertion, 6 |
| M22 | `head_diff.lua`: `in_worktree.repository = entry.worktree.repository` → `in_worktree.repository = source.repository` | assertion, 2 |
| M23 | `head_diff.lua`: in `M.name()`, `if not entry.worktree then` → `if true then` | assertion, 2 |
| M24 | `entry_diff.lua`: `if head_diff.is_against_head(entry) then return head_diff.name(entry) end` deleted from `M.name()` | assertion, 10 |
| M25 | `entry_diff.lua`: `if head_diff.is_against_head(entry) then head_diff.read(entry, source, done) return end` deleted from `M.read()` | assertion, 11 |
| M26 | `head_diff.lua`: `if not head then done(NO_HEAD) return end` deleted from `READS.commit` | assertion, 1 |
| M27 | `head_diff.lua`: `if not (source.landed and source.landed.tip) then done(landed.unreadable(source.landed)) return end` deleted | assertion, 1 |
| M28 | `head_diff.lua`: `'/' .. lines.quoted_path(entry.change.path)` → `'/' .. entry.change.path` in `M.name()` | assertion, 1 |
| M29 | `init.lua`: `local entry = diffed(listed)` → `local entry = listed` | assertion, 14 |
| M30 | `init.lua`: `if not listed then return end` deleted from `show_diff_at_cursor()` | crash class at `d103e9d` (the plugin's callback raised out of `type_keys`); assertion, 4, since the fix round's `pcall` form (`pressed` false) |

## Departures and unsettled

- **The commit's file buffer is cut at the 1 MiB the diffs are cut at**, where the brief says the buffer holds "the bytes git printed". The fix round (A182) tells the cut as a virtual line under the last line shown, so the buffer holds only the file's bytes up to the bound.
- `'readonly'` is left off: "read-only" is read as the diffs' (`'modifiable'` off, a scratch buffer), the plan's mutant 4.
- A commit of another worktree was first read in the editor's repository (a departure from item 1 of the brief, "in the repository the filter names"); the fix round reads it in that worktree's (attack finding 2, corrected). A worktree section with no repository cannot list a file, so `head_diff` has no branch for it and a nil repository would raise; `commit_file` falls back to the editor's repository.
- Reading a huge blob whole before the cut (`gf` on a 128 MiB file: 270 MiB resident in the child, a read git cannot print within its time limit fails as `timed_out`) is an open thread for the git home (`lua/aineo/git/`): `file_at_commit` could read the size with `ls-tree -l` and stop at the bound. Outside this packet (A183).
- `gf` and `h` keep no index of the files shown: each key reads the text again.
- The real layout was exercised in a scratch case, outside the suite (`tests/test_entry_changes.lua` is not in the boundary): `gf` under a commit showed `aineo://show/{id}/notes.txt` in the file column with `'filetype'` `text` and `'modifiable'` off; `h` then took the same middle window with `aineo://head/commit/{id}/notes.txt`.
- The help's `h` and `l` paragraph sits after `a fault to report.`, the end of the plan's range for T53, before the paragraph on `F`: adjacent, merges clean with T54.

## Pins moved

- `tests/test_changes_open_file.lua`: the case `under a commit filter opens the working tree's file` is replaced by `under a commit shows the file as the commit had it, not the working tree's file` (A2 of T45 is replaced by D57); `BEGIN_AND_SHOW` takes a working branch and a `_G.no_room`.
- A race in the file's new helper: the session's base is read after `begin_session()`, so a commit made at once could become the base; the helpers wait for the commits window to say `No commits on this session` first.

## Fix round — the reviews of PR #183

The orchestrator's rulings A180–A184 are its assumptions under the user's instruction of 2026-10-06, not the user's decisions. Each change was driven by a case seen failing first.

| Finding | Done |
|---|---|
| Attack 1 (a working-tree `gf` did not count as the last key) | Red: `after l before its diff was read, leaves the file shown alone` (the stale diff `aineo://diff/notes.txt` was shown, 1 buffer, in place of the opened file). `enters = enters + 1` in `open_file_at_cursor()` before `open_listed_file()`; the docstring of `enters` says what it counts. |
| Attack 2 (`gf` under another worktree's commit read in the editor's repository) | Red: `reads it in that worktree's repository` (a clone at the worktree's path: nothing shown, a refusal told). `commit_file.revision_of()` reads in `entry.worktree.repository`, else the editor's; docstring too. A departure of the first round, corrected. |
| A180 (attack 3, `h` on a file as `HEAD` has it) | Red: two cases (Session work once committed; the newest commit): no message in time. An empty diff against `HEAD` is not shown; `aineo: <quoted path> is as HEAD has it` once, INFO; the focus stays (`head_diff.told_unchanged()`). |
| A181 (attack 4, `HEAD` naming no commit under Landed) | Red: `h` under Landed with `resolve_commit` giving nil showed a diff from nothing. The check is in `with_head()`, so every filter refuses with `HEAD names no commit`. |
| A182 (attack 5, the 1 MiB note a buffer line) | Red: two cases (a virtual line under a last line that is the file's; one note after `:edit!`). `diffs.file_buffer()` tells the cut as an extmark `virt_lines` in its own namespace, cleared and set at each write; a cut diff keeps its last line. |
| A183 (attack 6, the whole blob read before the cut) | An open thread for the git home, named under *Departures and unsettled*. |
| A184 (tests 1, the flaky case) | `tests/test_changes_filter.lua` › *has its cursor on Session work again when its buffer is made anew*: with `git log` slowed to 0.5 s and the old wait it failed (`{1,0}` for `{2,0}`); with the wait of its neighbour (`QUIET_WATCH .. COUNT_GIT_CALLS`, then `git_asked > asked and git_asked == git_answered`) it passed twice. |
| Tests 2 | The no-file guard's case presses through `pcall` and asserts `pressed`; with the guard removed (M30) it fails by assertion in 4 cases. |
| Tests 3 | The deleted-file, no-room and Landed-gone cases name `say "hi".txt`; each of the reviewer's three unquoting edits fails one of them. |
| Tests 4 | The PR body names `'readonly'` left off and counts 25 more mutants. |
| Tests 5 | The mutant table above gives every row's literal edit, in order, with no pointer to an untracked file. |

### Mutants of the fix round

Literal edits at the commits of the round, each restored in the same call; every kill is an assertion.

| # | Edit | Killed by |
|---|---|---|
| F1 | `init.lua`: `enters = enters + 1` deleted before `open_file.open_listed_file(entry, session.repository.top)` | 1 (`after l before its diff was read`) |
| F2 | `commit_file.lua`: `repository = entry.worktree and entry.worktree.repository or source.repository,` → `repository = source.repository,` | 1 (the clone case) |
| F3 | `head_diff.lua`: in `with_head()`, `elseif not head then done(NO_HEAD) else` → `else` | 2 (under a commit and under Landed) |
| F4 | `init.lua`: `if head_diff.is_against_head(entry) and diff == '' then` → `if false then` | 2 |
| F5 | `diffs.lua`: `if shown.note then vim.api.nvim_buf_set_extmark(` → `if false then vim.api.nvim_buf_set_extmark(` | 2 |
| F6 | `diffs.lua`: `vim.api.nvim_buf_clear_namespace(buffer, NOTES, 0, -1)` deleted | 1 (`:edit!` leaves two notes) |
| F7 | `diffs.lua`: `math.max(#shown.lines - 1, 0), 0, {` → `0, 0, {` | 1 |
| F8 | `diffs.lua`: in `M.diff_buffer()`, `table.insert(shown.lines, shown.note) shown.note = nil` → `shown.note = shown.note` | 2 in `test_changes.lua` (a cut diff's last line) |
| F9 | `commit_file.lua`: `local file = lines.quoted_path(path)` → `local file = path` | 1 |
| F10 | `init.lua`: `('%s in %s'):format(lines.quoted_path(path), revision.told)` → `('%s in %s'):format(path, revision.told)` | 1 |
| F11 | `init.lua`: the `could not be read` message's `lines.quoted_path(path),` → `path,` | 1 |

## Whole suite

First push (`e9aea3f`; Neovim 0.12.5, host): 2892 cases, 82 groups, `Fails (1)`: the made-anew cursor case of `test_changes_filter.lua`, a timing flake (alone 1 of 3 runs on that tree, 1 of 5 on `origin/dev` `70a52bc`), fixed in the fix round (A184).

Fix round, on the tree pushed (Neovim 0.12.5, host, default jobs): **2899 cases**, 82 groups, `Fails (0)`. 2848 before the packet; 44 added in the first round and 7 in the fix round (3 in `test_changes_keys.lua`, 4 in `test_changes_open_file.lua`).

## Task lines

- T53 `[X]` (`feature/t53-files-keys`, into `dev`) — a commit's file opens from that commit under `gf`; `h` and `l` in the files window (C15, C13; D57): `l` is Enter's diff, `h` the file against `HEAD` by filter, `gf` shows the file read-only in the middle column; U4 (a) is the user's; the orchestrator's rulings A152, A153, A157 are its assumptions.

## Commits

Recorded after the merge, by the wave 13 knowledge pass. PR #183 merged by rebase as `1a38fab` … `19f33dc` (14 commits), now `e728523` … `29f2f00` on `dev`. The orchestrator's check on `dev` `191f819` plus T53: the whole suite 3015 cases, `Fails (0)`, lint clean, and the last-key mutant killed. Released in v0.2.27 (PR #184, `main` `bfef6c9`).

| Branch | `dev` | Subject |
|---|---|---|
| `1a38fab` | `e728523` | Record the dispatch amendment of T53's brief against dev 70a52bc |
| `140dbe3` | `f957383` | Show a commit's file as that commit has it under gf |
| `d49e1c8` | `6ae08b6` | Pin a late failure and the quoted name of a commit's file |
| `d103e9d` | `20b2fe7` | Add h and l to the files window: a file against HEAD or its parent |
| `8818993` | `e80521e` | Name the diffs against HEAD from one folder per filter kind |
| `e9aea3f` | `08fc000` | Record the session of T53, the files window keys |
| `36de2fd` | `efecaff` | Wait for the reads in the made-anew cursor case |
| `88b4fa0` | `5da6e7b` | Count a working-tree gf as the last key, read a worktree's commit there |
| `a283bcd` | `143bd50` | Refuse h when HEAD names no commit, under every filter |
| `232ea18` | `b14f832` | Say a file is as HEAD has it instead of showing an empty h diff |
| `7b7529b` | `386000e` | Tell the cut of a commit's file as a virtual line, not a buffer line |
| `3e453f0` | `f581cff` | Pin the no-file guard by assertion and the quoted names in gf's messages |
| `07d2d74` | `70b2f61` | Say in the help what the fix round of T53 changed |
| `19f33dc` | `29f2f00` | Record T53's fix round in the session note |
