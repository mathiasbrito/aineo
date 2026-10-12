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
| M4 | `lines.lua` `files_window()`: `  local files = page_of(file_window_rows(view))` → `  local files = page_of(vim.list_extend(file_window_rows(view), worktree_rows(view.worktrees)))`; `init.lua` `files_page()`: `    worktree = listed and listed.worktree,` → `    worktree = listed and listed.worktree,` and, on a line after it, `    worktrees = session.commits_others,` (plan 4) | killed, 6 of 6 |
| M5 | `pages.lua`: `local lists_another_filter = false` (plan 5) | killed, 1: the view case |
| M6 | `init.lua` `reselect_in_worktrees()`: `  if not section then` / `    select_session_work()` / `    read_files(true)` → `  if not section then` / `    read_files(true)` | killed, 1 |
| M7 | `init.lua` `reselect_in_worktrees()`: `    select_filter(filter.of_worktree(section))` → `    select_session_work()` | killed, 1 |
| M8 | `init.lua`: `ask_for_files(with_own or session.selected.kind == 'worktree')` → `ask_for_files(with_own)` | killed, 1: the watch case |
| M9 | `init.lua`: `and not session.selected.worktree` removed | killed, 2 |
| M10 | `entry_diff.lua`: `return 'since-base'` → `return 'since_base'` | killed, 1 |
| M11 | `entry_diff.lua` `worktree_diff_name()`: `if entry.change and entry.filter.kind == 'commit' then` → `if false then` | killed, 1 |
| M11b | `entry_diff.lua` `read_in_worktree()`: `elseif entry.change and entry.filter.kind == 'commit' then` → `elseif false then` | killed, 1 |
| M12 | `init.lua` `filter_named()`: `return filter.in_worktree(named, section_as_last_read(named.worktree))` → `return named` | killed, 1 |
| M13 | `lines.lua`: `MARKS_SAVES` gains `worktree = true` | killed, 1: the heading case's `*` |
| M14 | `worktrees.lua` `read_worktree()`: `read_section(read, worktree, comparison, done)` → `read_section(read, worktree, nil, done)` | killed, 5 |
| M15 | `init.lua`, the files window's `window_read({`: `  read_own = read_selected_files,` → the same line followed by `  read_list = function(repository, base, done)`, `    git.changed_files(repository, base, done, session.settings.git)`, `  end,` and `  others_field = 'commits_others',` | killed, 4 of 6 on the reads group, the new case among them |
| M16 | `init.lua` `take_own` of the files window: `if not failure or not (listed and filter.same(listed.filter, listing.filter)) then` → `if true then` | killed, 1: *keeps its files under git's words* |
| M17 | `lines.lua` `heading_row()`: `  row.entry = { key = filter.key(listed_under), filter = listed_under, worktree = section }` → `  row.entry = { key = filter.key(listed_under), worktree = section }` | killed, 3 |

Fix round (review of PR #176), same method, `tests/test_changes_full_context.lua` whole and narrowed copies of the others:

| # | Literal edit | Result |
|---|---|---|
| MA | `entry_diff.lua` `read_in_worktree()`: `git.commit_file_diff(repository, entry.filter.commit.id, entry.change, done, options)` → the same without `, options`; `git.diff_since(repository, worktree.base, done, options)` → the same without `, options` | survived the first round; killed by the two new F cases, 2 of 33 |
| MB | `init.lua` `read_worktree_files()`: `done(failure, { filter = selected, changes = changes, worktree = section })` → `done(nil, { filter = selected, changes = changes, worktree = section })` | survived the first round; killed by the new case on a failed read of a commit's files, 1 |
| MG | `init.lua` `read_worktree_files()`: `done(WORKTREE_GONE, { filter = selected, worktree = section })` → `done(nil, { filter = selected, changes = {}, worktree = section })` | killed by the new gone-worktree case, 1 |
| MS | `init.lua` `select_filters_from()`: `for key in pairs(vim.v.event) do` → `for key in pairs({ [vim.fn.expand('<amatch>')] = true }) do` (the pattern's window alone, as before) | killed by the new same-turn scroll case, 1 |

"No survivor" above holds for the edits listed, not for the code: MA and MB were two edits no one had listed.

## Open threads

- `gf` stays as T45 has it (T53 opens a commit's file from that commit, D57).
- A worktree removed while its whole change is being read lists "No files changed in this worktree" until the commits read, which follows, selects Session work.
- The files window under a worktree's commit is not read again at a watch call that moved nothing of the editor's (allowed, not required, by item 9).
- The LIMITS paragraph's cost figures were removed; a re-measure with the commits window alone reading the worktrees is open.

## Fix round

The attack and the tests-and-records reviews of PR #176 (orchestrator's rulings A161 and A162, assumptions under the user's instruction of 2026-10-06):

- A worktree gone at the read gives a failure (`the worktree is gone`), so the files window keeps its last list under the failure line (attack 1); case seen red first.
- T49's `WinScrolled` handler loops over the window keys of `vim.v.event` instead of reading `event.match` alone, which names only the first window that scrolled (attack 2, A161); case seen red first.
- That handler starts the selection pause only when the line under the scrolled window's cursor lists a filter other than the selected one (`other_filter_at_cursor()`, shared with `select_filter_at_cursor()`): started on every scroll, it left a timer running after the reads, which `tests/test_changes.lua` › *the reads leave no timer running once they have answered* caught, red first.
- `F` in the heading's diff and in a file under a worktree's commit, and a failed read of a worktree commit's files, adopted from the reviewer's patches; they arrived green on the tree and are killed by MA and MB.
- `lines.commit_rows` is file-local again, moved above its first use (A162); the `Entry.key` docstring names the keys of a worktree's lines; the blank lines between the tests of `test_changes_worktrees.lua` are back. The duplicate `add_worktree` of the filter file stays: sharing it means an addition to `tests/helpers/git_repo.lua` and a run of every file that requires it.
- The first commit's subject (75 characters) is pushed and left.
- The LIMITS cost figures stay dropped until a re-measure (A162).
- Neovim ran the suites with `git` resolved to a symbolic link to the Command Line Tools binary, because Apple's `git` and `make` stopped answering mid-session on an unaccepted Xcode license; the recipe of `make test` and `make test_file` was run by hand, with the same variables.

## Task lines

- T50 `[X]` (`feature/t50-worktree-filter`, into `dev`) — another worktree's heading and commits are filters of their own, read in that worktree (D55); the files window lists the selected filter's files alone under every filter, shows its first line at a change of filter, and Enter on a worktree's heading shows its whole diff from its base (D57, U3 (a); the orchestrator's rulings A136–A142). The cursor and the reselection rules are O4 (a); the branch of a worktree is named as the commits window last read it.

## Commits

Recorded after the merge, by the wave 13 knowledge pass. PR #176 conflicted with T51's rewrite of the same help passage once T51 had merged, so its commits were re-applied unchanged in content as PR #177 rather than rebasing the pushed branch (original heads: `8f8466b` … `d75ab2a`); PR #177 merged by rebase as `569a541` … `f272619`, now `57d4473` … `322fc41` on `dev` (5 commits). The orchestrator's check of T50 and T51 on one combined tree: the whole suite 2798 cases, `Fails (0)`, lint clean, and the mutant `done(WORKTREE_GONE, …)` → `done(nil, …)` killed. Released in v0.2.25 (PR #178, `main` `f59a7d8`).

| Branch | `dev` | Subject |
|---|---|---|
| `569a541` | `57d4473` | List another worktree's lines as filters; show the files window as one list |
| `c87792d` | `a43678c` | Record T50's session: the worktree filter, its mutants and open threads |
| `bfeeee2` | `0f0d8f2` | Fix T50's review findings: gone worktree, same-turn scroll, F, failed commit read |
| `82a1b60` | `d349437` | Start the selection pause only for a scroll that carries the cursor elsewhere |
| `f272619` | `322fc41` | Record T50's fix round in the session note |
