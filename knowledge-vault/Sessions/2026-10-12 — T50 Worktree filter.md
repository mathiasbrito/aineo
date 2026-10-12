# 2026-10-12 — T50 Worktree filter

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t50-worktree-filter` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D32–D35, D46–D48, D55, D57, C15, T50
- Wave plan: [[Implementation/Waves/00013-worktrees-landed/plan]]; brief: [[Implementation/Waves/00013-worktrees-landed/brief-t50-worktree-filter]]
- Rests on: [[Sessions/2026-10-11 — T43 Changes filter]], [[Sessions/2026-10-12 — T49 Scroll filter]]

## What was done

The user's report (wave 13) was that moving over the commits changed nothing in the files window. Another worktree's lines kept the last filter (A110), and every other worktree's files sat below the selected filter's list. T50 makes another worktree's heading and commits filters of their own (D55) and the files window one list (D57, U3 (a)). The orchestrator's rulings A136–A142 (O1–O7, all (a)) are the orchestrator's assumptions, not the user's decisions; A154 (D32's bases unchanged) stays an open thread for the user.

- **`filter.lua`** — `aineo.changes.Filter` gains `worktree` and a `worktree` kind. `key()` tells another worktree's filters from the editor's own and from each other: the top level, a byte no path holds, then the commit id; or two such bytes and the kind for the whole change. `of_worktree()`, `of_worktree_commit()`, `in_worktree()`.
- **`lines.lua`** — a worktree's heading and its commit rows list filters (the heading is still coloured as a note); the files window lists the selected filter's files alone, its first line `Files in: ` and the worktree's heading, or the commit's line and `(worktree <folder>)`; no `*` mark under a worktree filter. The `SectionLines` abstraction is gone: only the commits window lists worktrees now. `Page.filter_key` carries the filter's key.
- **`pages.lua`** — a write for another filter than the previous one puts every window's cursor on line 1, which brings the view to the top (O5 (a)); the same filter keeps the cursor on its entry.
- **`worktrees.lua`** — `read_worktree()` reads one worktree on its own: comparison, repository, base (D32), list.
- **`init.lua`** — `read_selected_files()` reads in the filter's worktree (a commit's files in the repository the commits window found; a whole change from a base read again, in that worktree); the files window reads no other worktree (`window_read()` takes no others); a watch call reads a worktree's whole change always (D35); `reselect_in_worktrees()` applies O4 (a); the editor's own commit-gone rule no longer reaches a worktree's commit.
- **`entry_diff.lua`** — `aineo://worktree{top}//commit/{id}/{path}` for a file under a worktree's commit, `aineo://worktree{top}//since-base` for the heading's whole diff (`git.diff_since()`, its untracked files in) (O6 (a), O7 (a)).
- **`doc/aineo.txt`** — *aineo-changes* (first line, choices, Enter, `gf`, reads), *Colours*, LIMITS; and, beyond the brief's list, *aineo-panes* (one sentence) and the opening paragraph of *aineo-changes*, which the change made false. The LIMITS figures measured with both windows reading every worktree (0.7 to 1.6 seconds, 72 git processes) were dropped, not re-measured.

## Unit list

1. A cursor on another worktree's commit lists that commit's files, read in that worktree, the first line naming it.
2. A cursor on its heading lists its files since its base, unmarked.
3. An empty whole change and an empty commit say so.
4. Under Uncommitted, Session work and the editor's commit, no other worktree's section.
5. The same commit in two worktrees is two filters.
6. A line that lists no filter keeps the last one.
7. Every files window shows its first line at a change of filter (cause 3).
8. Enter: a file under a whole change, a file under a commit, the heading; the commit's own as before.
9. Reselection: worktree gone, commit amended, commit kept across a read.
10. The base read again; a watch call reads the whole change; a failed read; the files window reads the editor's files alone; the branch named as last read.
11. The pins moved; the help.

## Red and green

**Seen red** (the intended failure, read from the output): the six cases of *the filter in another worktree* (`tests/test_changes_filter.lua`), each against the code before this change — `Files in: Session work` where `Files in: <id7> … (worktree agent)` or `Files in: Worktree agent (agent)` was expected, a worktree's heading and files listed under the editor's own filters, `what happened in time` for the second filter of one commit. They were first written in `tests/test_changes_worktrees.lua`, seen red there, and moved to the file of the filter.

**Arrived green, pinning code written ahead of its test:** *the filter … puts the cursor of every files window on its first line* (killed by M5); *the selection of another worktree* › *goes back to Session work* (M6), *names the worktree's branch* (M12); *the files window under another worktree's whole change* › *reads the base again* (M14), *is read again at every call of the watch* (M8), *keeps its files under git's words* (M16) and *lists the filter with no files* (the first read of a filter has nothing to keep: no mutant of its own); *the reads … of the files window read the editor's files alone* (M15); *Enter … on a file under another worktree's commit* (M11, M11b) and *on another worktree's heading* (M10).

**Seen red while the code was wrong:** *becomes the worktree's whole change, the cursor on its heading* — `Files in: Session work` where `Files in: Worktree agent (agent)` was expected: the editor's own commit-gone rule (`take_own` of the commits read) reset a worktree's commit to Session work at every read. Fixed (`and not session.selected.worktree`); *stays its commit when the lists are read again* was added for it and arrived green, killed by M9.

**Test bugs seen red and corrected:** the order git lists a new file after a modified one (`? new.txt` after `M notes.txt`), twice.

## Pins moved

- `tests/test_changes_worktrees.lua` — the files window no longer lists worktrees: the section tests now read them in the commits window and select the heading or a commit; the *Enter* tests select first; *the reads* tests count the commits window's reads (`log` for `ls-files`, one read of the editor's branch not two, `changed_files` once); *a worktree removed while it is read*, *a worktree whose read fails* and the list-failure tests read the commits window; the pin *Enter on another worktree's heading does nothing* is replaced by the new Enter on a heading.
- `tests/test_changes_open_file.lua` — `gf` on another worktree's file and the lines that list no file select the worktree's change first; the heading and note rows of the files window are gone.
- `tests/test_changes_full_context.lua` — *F in the diff of another worktree's file* selects the heading first.
- `tests/test_changes_filter.lua` — the new group and the view case.

## Mutants

Run from the committed tree, each restored in the same call, on a narrowed copy of the test file that exercises the code (`.tests/`, gitignored), every kill an assertion (`Failed expectation for equality`, read from the output):

| # | Literal edit | Result |
|---|---|---|
| M1 | `lines.lua` `commit_rows()`: `filter = listed_under,` → `filter = not worktree and listed_under or nil,` (plan's T50 mutant 1) | killed, 3 of 6: *a cursor on its commit*, *says so when…*, *one filter per worktree* |
| M2 | `filter.lua` `key()`: `return worktree .. filter.commit.id` → `return filter.commit.id` (plan 2) | killed, 1: *one filter per worktree for the same commit* |
| M3 | `init.lua`: `git.commit_files(section.repository, …` → `git.commit_files(session.repository, …` (plan 3) | killed, 2: *a cursor on its commit* (the recorded top level), *one filter per worktree* |
| M4 | the other worktrees' rows appended to the files window (`lines.lua`: `page_of(vim.list_extend(file_window_rows(view), worktree_rows(view.worktrees)))`; `init.lua`: `worktrees = session.commits_others`) (plan 4) | killed, 6 of 6 |
| M5 | `pages.lua`: `local lists_another_filter = false` (plan 5) | killed, 1: the view case |
| M6 | `init.lua`: `select_session_work()` removed from the worktree-gone branch | killed, 1 |
| M7 | `init.lua`: `select_filter(filter.of_worktree(section))` → `select_session_work()` | killed, 1 |
| M8 | `init.lua`: `ask_for_files(with_own or session.selected.kind == 'worktree')` → `ask_for_files(with_own)` | killed, 1: the watch case |
| M9 | `init.lua`: `and not session.selected.worktree` removed | killed, 2 |
| M10 | `entry_diff.lua`: `return 'since-base'` → `return 'since_base'` | killed, 1 |
| M11 | `entry_diff.lua` `worktree_diff_name()`: `if entry.change and entry.filter.kind == 'commit' then` → `if false then` | killed, 1 |
| M11b | `entry_diff.lua` `read_in_worktree()`: `elseif entry.change and entry.filter.kind == 'commit' then` → `elseif false then` | killed, 1 |
| M12 | `init.lua` `filter_named()`: `return filter.in_worktree(named, section_as_last_read(named.worktree))` → `return named` | killed, 1 |
| M13 | `lines.lua`: `MARKS_SAVES` gains `worktree = true` | killed, 1: the heading case's `*` |
| M14 | `worktrees.lua` `read_worktree()`: `read_section(read, worktree, comparison, done)` → `read_section(read, worktree, nil, done)` | killed, 5 |
| M15 | `init.lua`: the files window's `window_read()` given a `read_list` and `others_field = 'commits_others'` again (the files window reads every worktree's files) | killed, 4 of 6 on the reads group, the new case among them |
| M16 | `init.lua` `take_own` of the files window: `if not failure or not (listed and filter.same(listed.filter, listing.filter)) then` → `if true then` | killed, 1: *keeps its files under git's words* |
| M17 | `lines.lua` `heading_row()`: `filter = listed_under` removed from the entry | killed, 3 |

## Open threads

- `gf` stays as T45 has it (T53 opens a commit's file from that commit, D57).
- A worktree removed while its whole change is being read lists "No files changed in this worktree" until the commits read, which follows, selects Session work.
- The files window under a worktree's commit is not read again at a watch call that moved nothing of the editor's (allowed, not required, by item 9).
- The LIMITS paragraph's cost figures were removed; a re-measure with the commits window alone reading the worktrees is open.
- `lines.commit_rows()` is public in the file (used before its definition by `section_rows()`); it is not exported by `aineo.changes`.

## Task lines

- T50 `[X]` (`feature/t50-worktree-filter`, into `dev`) — another worktree's heading and commits are filters of their own, read in that worktree (D55); the files window lists the selected filter's files alone under every filter, shows its first line at a change of filter, and Enter on a worktree's heading shows its whole diff from its base (D57, U3 (a); the orchestrator's rulings A136–A142). The cursor and the reselection rules are O4 (a); the branch of a worktree is named as the commits window last read it.

## Commits

Recorded after the merge.
