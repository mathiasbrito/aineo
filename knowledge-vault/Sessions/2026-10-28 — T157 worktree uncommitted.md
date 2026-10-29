# 2026-10-28 — T157 worktree uncommitted

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t157-worktree-uncommitted` (from `dev` at 39709514) · **Pull request:** into `dev`

A regular packet of wave 21 (D26: the whole suite once before the push). Every worktree other than the editor's that the changes pane's commits window lists, reported by an agent or found by git, has its own *Uncommitted* line first under its heading, listing what that worktree has not committed yet, so the user can follow an agent's work in flight (D133, A653).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D133 row (A653 inside it) and the T157 row
- [[Sessions/2026-10-20 — T108 reported work]], [[Sessions/2026-10-21 — T112 reported notice]], [[Sessions/2026-10-21 — T113 diff base]], [[Sessions/2026-10-21 — T114 tree commits]] — the worktree sections and the reported work this line joins
- `lua/aineo/changes/{filter,lines,copy,entry_diff,init}.lua`, `tests/test_changes_worktree_uncommitted.lua`, `doc/aineo.txt`, `README.md`

## Task lines

- [X] T157 each other worktree's Uncommitted line (D133, A653, A654, A655, A657, A658; D135, A656) — added during review: the Reported tree's `Uncommitted` under each checked-out branch; the fix round: no Against of the editor's for a worktree with no repository, read once listed, read at a report, the chosen worktree watched while the pane shows: `filter.of_worktree_uncommitted()`; the row `Uncommitted — <folder> (<branch>)` first under each other worktree's heading, in the default view and shown alone (`s`, `\g`, the reported work), kept chosen across `\g`; its files read with `git.uncommitted_files()` in the worktree's repository, again at every read of the pane; a file's diff, the whole diff and `h` read with the editor's own readers there, in `aineo://worktree{top}//uncommitted[/{path}]`; a worktree whose read failed lists its section's failure; save marks kept to the editor's worktree; help and README. No key changed.

## What was done, and why

- **One filter kind, carrying the worktree.** The line's filter is the editor's own kind, `uncommitted`, with the worktree's section in it, as a worktree's commits carry theirs. Its key (`<top>\0\0uncommitted`), its reselection across refreshes (`reselect_in_worktrees()`'s generic branch), the Against line (read in the worktree by `against_read`) and `h` (`head_diff`'s `source_in_worktree_of()`) then work with no new branch. A new kind was rejected: every table keyed by kind would have needed a fifth row saying the same thing.
- **The editor's readers, with the worktree's repository** (A653 (1)): `copy.lua`'s `read_worktree_files()` calls `git.uncommitted_files(section.repository, …)`; `entry_diff.lua`'s `read_in_worktree()` calls `git.uncommitted_file_diff()` and `git.uncommitted_diff()`. They read through the private index copy and pass `GIT_OPTIONAL_LOCKS=0`, so nothing is written in the agent's worktree (A653 (2)).
- **Read again at every read of the pane** (A653 (3)): `read_files()` re-reads another worktree's Uncommitted at every call, as it did its whole change, since the agent's edits do not change the editor's own files.
- **No repository, no error** (A653 (3)): a worktree whose first read failed has no repository; its Uncommitted lists the section's failure, else "the worktree is gone".
- **Save marks are the editor's** — the `*` of a file the user saved marks the editor's own worktree's paths only; under another worktree's Uncommitted a file of the same path is not marked.
- **The name** (A653 (4)): `Uncommitted — <folder> (<branch>)`, the worktree's name as its heading gives it, on the line itself and in `Files in:`; a diff that fails is told as `Uncommitted in the worktree <folder>`.

## Unit list (stated before the first test)

1. The line sits first under a git-found worktree's heading.
2. Selected, it lists the worktree's staged, unstaged and untracked files, from its `HEAD`.
3. A clean worktree with commits says "No uncommitted changes".
4. The user's saves mark none of its files.
5. Enter on a file shows its diff from the worktree's `HEAD`, named for the worktree.
6. One path in two worktrees: two buffers, each its worktree's.
7. Enter on the line shows the whole diff from the worktree's `HEAD`.
8. A worktree whose read fails: the line, its failure listed, no error.
9. A diff of that line that fails is told naming Uncommitted and the worktree.
10. The watch re-reads it, the editor's files unchanged, the line kept selected.
11. The pane's refresh (`refresh_shown_pane()`) keeps it selected once the agent commits.
12. A removed worktree: back to Session work, no error.
13. The line under a reported worktree's heading, shown alone.
14. `h` on a file shows Enter's diff (added for the help's claim).
15. A654, sent during the build: the line in the view of a worktree shown alone with `s`.
16. A654: `\g` back and forth keeps it chosen.

## A654, added during the build

The orchestrator ruled, while the packet was built, that the view of a worktree shown alone (`s`, `\g`) shows the line too and that `\g` keeps it chosen; a branch shown alone is unchanged. `scope_rows()` already gave every worktree shown alone the line (unit 13, for reported work), and `choose_for_shown_view()` keeps any filter the page lists, so both cases arrived green; each was then killed by a mutant run on its group (M11b, M17). The help said that view showed "no Uncommitted"; it now says the worktree's own line is there and none of yours, and that `\g` keeps a chosen Uncommitted.

## Seen red

Nine of the sixteen cases of `tests/test_changes_worktree_uncommitted.lua`, each red for the missing behaviour:

| Case | Red |
|---|---|
| the line sits first under its heading, before its commits | key 5: the commit's line where `Uncommitted — agent (agent)` was expected |
| it lists the worktree's staged, unstaged and untracked files once selected | key 2: `  A committed.txt` (the worktree's whole change, from its base) where `  M notes.txt` was expected. Its first run arrived green: the fixture's agent had no commit, so its base was its `HEAD`; the fixture gained a commit of the agent's before any code was written, and the case went red |
| it marks none of its files as saved by the user | key 2: `* M notes.txt` where `  M notes.txt` was expected |
| Enter on a file shows its diff from that worktree's `HEAD`, named for it | `last[1]`: `-one` (from the base) where `-committed` was expected |
| Enter on the line shows its whole diff from that worktree's `HEAD` | `last[1]`: `-one` where `-committed` was expected |
| a worktree whose read fails shows its line, lists git's words, never an error | the files window stayed `Files in: Session work`: the selection's read indexed the section's missing repository |
| … tells the diff of its Uncommitted unreadable, naming it and its worktree | `the diff of the worktree agent` where `the diff of Uncommitted in the worktree agent` was expected |
| the watch reads it again, the editor's own files unchanged, and keeps it selected | key 3: nil where `  ? new.txt` was expected |
| the line sits first under a reported worktree's heading, shown alone | key 2: the commit's line where `Uncommitted — agent-1 (feature/a)` was expected |

## Arrived green, and why

| Case | Why | Killed by |
|---|---|---|
| a clean worktree with commits says "No uncommitted changes" | spent by the files read of unit 2 | M4 |
| one path in two worktrees: two buffers, each its worktree's | spent by unit 5's reader and the `worktree{top}//` prefix the worktree's names already had | M6, M7 |
| the pane's refresh keeps it selected once the agent commits | green by nature: `reselect_in_worktrees()` keeps any filter of a listed worktree | M3 |
| a removed worktree's Uncommitted gives way to Session work, with no error | green by nature: the same function drops a filter whose worktree is gone | M15 |
| `h` on a file shows Enter's diff, from that worktree's `HEAD` | green by nature: `head_diff` reads every filter of another worktree in that worktree | M14 |
| the worktree shown alone with `s` lists its Uncommitted line under its heading (A654) | spent by unit 13's row in `scope_rows()`, which every worktree shown alone gets | M11b |
| it stays chosen as `\g` switches back and forth (A654) | green by nature: `choose_for_shown_view()` keeps any filter the page lists, by its key | M11b, M17 |

## Mutants

Each run alone, on the code of the commit `Give each other worktree its own Uncommitted line…` (the code is unchanged after it), the source copied aside and restored in the same call, against a copy of the new test file narrowed to the group named. Every kill is an assertion of the case.

| # | Literal edit | Group | Result |
|---|---|---|---|
| M1 | `copy.lua`: `git.uncommitted_files(section.repository,` → `git.uncommitted_files(session.repository,` (A653's "read from the editor's repository") | the line | killed by 2: `  ? editor.txt` listed; the reported worktree's `No uncommitted changes` |
| M2 | `copy.lua`: after `git.uncommitted_files(section.repository, function(failure, changes)`, insert `changes = changes and vim.tbl_filter(function(change) return change.kind ~= "untracked" end, changes)` (A653's "untracked files dropped") | the line | killed by 2: `? new.txt`, `? b.txt` missing |
| M3 | `copy.lua` `reselect_in_worktrees()`: before `else session.selected = filter.in_worktree(selected, section)`, insert `elseif selected.kind == "uncommitted" then select_filter(filter.of_worktree(section)) read_files(true)` (A653's "the selection lost on refresh") | the refresh | killed by 1: the commits cursor on 4, not 5 |
| M4 | `copy.lua`: `if selected.kind == 'uncommitted' then` (before `git.uncommitted_files`) → `if false then` | the line | killed by 3: `  A committed.txt`, `  A a.txt` listed |
| M5 | `lines.lua`: `MARKS_SAVES[kind] and not view.worktree and view.saved` → `MARKS_SAVES[kind] and view.saved` | the line | killed by 1: `* M notes.txt` |
| M6 | `entry_diff.lua`: `elseif entry.change and entry.filter.kind == 'uncommitted' then` (before `git.uncommitted_file_diff`) → `elseif false then` | Enter | killed by 2: `-one` |
| M7 | `entry_diff.lua` `M.name()`: `if not entry.worktree then` → `if not entry.worktree or entry.filter.kind == "uncommitted" then` | Enter | killed by 3: names `aineo://uncommitted…`; two worktrees share one buffer |
| M8 | `entry_diff.lua`: `elseif entry.filter.kind == 'uncommitted' then` (before `git.uncommitted_diff`) → `elseif false then` | Enter | killed by 1: `-one` |
| M9 | `entry_diff.lua` `told_name()`: `elseif entry.worktree and entry.filter.kind == 'uncommitted' then` → `elseif false then` | read fails | killed by 1: `the diff of the worktree agent` |
| M10 | `copy.lua` `read_files()`: `or (selected.kind == 'uncommitted' and selected.worktree ~= nil)` removed | the refresh | killed by 1: `? new.txt` missing |
| M11 | `lines.lua` `scope_rows()`: `table.insert(rows, worktree_uncommitted_row(member.worktree))` removed | the line | killed by 1: the reported worktree's line missing |
| M12 | `lines.lua` `worktree_rows()`: `table.insert(rows, worktree_uncommitted_row(section))` removed | the line | killed by 4 |
| M13 | `copy.lua`: `if selected.kind == 'uncommitted' and not section.repository then` → `if false then` | read fails | killed by 2: the files window stays on Session work (the child's callback raises; its message is not in the runner's output) |
| M14 | `head_diff.lua`: `in_worktree.repository = entry.worktree.repository` → `in_worktree.repository = source.repository` | h | killed by 1: `-one` |
| M15 | `copy.lua` `reselect_in_worktrees()`: `if not section then select_session_work() read_files(true)` → `if not section then return` | the refresh | killed by 1: the files window stays on the gone worktree's Uncommitted |
| M16 | `lines.lua`: `return 'Uncommitted — ' .. M.worktree_name(selected.worktree)` → `return 'Uncommitted'` | the line | killed by 5 |
| M11b | M11's edit (A654's "the line dropped from the alone view") | the worktree shown alone | killed by 2: the commit's line at key 2 |
| M17 | `copy.lua` `choose_for_shown_view()`: `if shown and not listed then` → `if shown and (not listed or session.selected.kind == "uncommitted") then` | the worktree shown alone | killed by 1: the commits cursor on 1, not 2, after switching back |

## Suites

The test files the change touches, each green on the final code: the new file (16 cases), and `test_changes_against_pane`, `test_changes_author_pane`, `test_changes_announce`, `test_changes_filter`, `test_changes_full_context`, `test_changes_keep_view`, `test_changes_keys`, `test_changes_landed`, `test_changes_open_file`, `test_changes_tree_commits_pane`, `test_changes_scope`, `test_changes_worktrees`, `test_entry_changes`, `test_entry_explorer_pick`, `test_entry_tabs_routing`, `test_changes_reported_tree`, `test_changes`, `test_changes_follow`, `test_doc`: Fails (0) each. Their earlier expectations gain the line after each heading and move their cursor lines by one below it. `make lint` clean. The whole suite: see the pull request.

After D135 and A657 (no whole suite: the orchestrator verifies): the new file, 29 cases, and `test_changes_worktrees`, `test_changes_scope`, `test_changes_announce`, `test_changes_keep_view`, `test_changes_filter`, `test_changes_follow`, `test_changes_keys`, `test_changes_open_file`, `test_changes_edit_file`, `test_changes_copies`, `test_changes_sessions`, `test_changes`, `test_entry_changes`, `test_entry_reported_work`, `test_changes_tree_commits_pane`, `test_changes_against_pane`, then `test_changes_reports`, `test_changes_tree_commit_lines`, `test_changes_against_read`, `test_changes_graph_pane`, `test_entry_explorer_pick`, `test_changes_reported_tree`, `test_doc`: Fails (0) each; `make lint` clean.

## D135 with A656, added during review: the Reported tree's Uncommitted line

The user asked for the line in the Reported tree too (D135). Under the line of a branch its worktree has checked out now, `Uncommitted`, six cells in, comes first before its commits (`lines.lua`'s `tree_uncommitted_row()`): another worktree's chooses `filter.of_worktree_uncommitted()` of that worktree, as the commits window last listed it or as git listed it at the report; the editor's own chooses `filter.UNCOMMITTED`, the default view's own line, no second reading (A656 (2)). Its pick carries `uncommitted = true` (`TreePick`, `ScopeItem`): Enter, and its item in `s` (`lines.report_items()`, `[reported]       Uncommitted`), show that worktree alone with its Uncommitted chosen, or keep the default view with the editor's own Uncommitted chosen (`show_worktree_alone()`, `show_own_work(uncommitted)`). Existing suites gain the line under each checked-out branch and move their lines and picker positions by one.

| Case (group `the Reported tree`) | Red, or green and why |
|---|---|
| lists Uncommitted first under the branch another worktree has checked out | red: key 5 the commit line where `      Uncommitted` was expected |
| lists no Uncommitted under a branch no worktree has checked out | red against the first, minimal code (a line under every branch): key 7 `      Uncommitted` where `Uncommitted` |
| lists, on another worktree's Uncommitted, that worktree's files | red: `Files in: Worktree agent-1 (feature/a)` (the row listed no entry) |
| lists, on the editor's own branch's Uncommitted, the editor's own Uncommitted | red, after the own branch of `tree_uncommitted_filter()`, written ahead, was taken out: `Files in: Uncommitted — repo (main)`; put back, green |
| shows, at Enter on another worktree's Uncommitted, that worktree alone, its Uncommitted chosen | red: the default view stayed |
| keeps, at Enter on the editor's own branch's Uncommitted, the default view with its Uncommitted chosen | red: cursor 3 (Session work's key) where 5 |
| offers another worktree's Uncommitted to s, whose pick does what Enter does | red: the item missing from the list |
| moves the Uncommitted to the branch the worktree checks out between two reads | green by nature: the tree is drawn anew from git's checkout at each read — killed by MA1 |

| # | Literal edit | Result |
|---|---|---|
| MA1 (A656: the line under a branch not checked out) | `lines.lua` `reported_rows()`: `if line.checked_out then table.insert(rows, tree_uncommitted_row(line))` → `if line.branch then …` | killed by 2, assertion |
| MA2 (A656: read from the editor's repository for another worktree) | `lines.lua` `tree_uncommitted_filter()`: `return filter.of_worktree_uncommitted(line.worktree_section or line.node.worktree)` → `return filter.UNCOMMITTED` | killed by 1, assertion: `Files in: Uncommitted` |

## A657, the fix round of the review of PR #387

| Ruling | What was built | Red | Mutant (literal edit) → result |
|---|---|---|---|
| 1 | `against_read.read()` reads nothing, `done({})` scheduled, for a filter of another worktree with no repository (the reviewer's measured fix) | `Against: 383b5c2 (agent, main) HEAD → working tree` where `Against: HEAD → working tree`, the editor's `HEAD` named | MB1 `if worktree and not worktree.repository then` → `if false then` → killed by 1, assertion |
| 2 | `read_worktree_files()` gives the section's failure alone (none: still reading); `reselect_in_worktrees()` reads the files once the listed section has the repository the chosen one lacked (the reviewer's measured fix) | `The last refresh failed: the worktree is gone` where `aineo is reading the repository` | MB2 `if unread and section.repository then` → `if false then` → killed by 1 (stays reading); MB2b the old `section.failure or WORKTREE_GONE` → killed by 1 |
| 3 | `take_waiting()`'s second branch reads the files, `read_files(false)` (the reviewer's measured fix) | key 3 nil where `  ? b.txt` after a second report | MB3 that `read_files(false)` removed → killed by 1 |
| 4 | `follow_chosen_worktree()`: while another worktree's Uncommitted is chosen and the pane shows, `git.watch_repository()` on that worktree, each call reading the files; stopped on another choice, the worktree gone, the pane hidden (`BufWinLeave`), let go, quit | `? new.txt` never listed; no watch of the worktree's folder ran (`_G.watched[agent]` nil) — both cases written before the code, each seen red | MB4 `follow_chosen_worktree()` removed from `show_files()` (the watch not started) → killed by 2; MB4b the `BufWinLeave` callback returns at once → killed by 1 (the watch kept after the pane hid) |
| 5 | the watch case counts the git home's calls and waits for the worktrees listed once more and every read answered before it asserts | test-only | M3 (its edit now inserted before `else local unread = …`) killed by this case 3 runs of 3, and by the pane-refresh case |

The suite's watch stand-in keeps the first watch asked, the session's, as `_G.on_change`, since a chosen worktree's watch is asked of the same function. The help says what the worktree's watch sees and its Linux limit (`aineo-limits`), and README.

## Open threads

- ~~The Reported tree's branch lines~~ — built as D135, A656.
- ~~A653 (3)'s `R`~~ — A655 (1) accepts the help's real reads.
- ~~The label in the line's name~~ — A655 (2) accepts the folder and branch.
- On Linux (non-recursive watch) the chosen worktree's watch sees changes in its top folder at once; changes in its subfolders, and what its agent stages, show when its agent commits or when the pane reads again for another reason (A658 (2)): a linked worktree's index lies in a subfolder of the common git directory.

## A658, the re-measure of PR #387

| Ruling | Commit | What was built | Red | Mutant (literal edit) → result |
|---|---|---|---|---|
| 1 | `Read a not-yet-listed worktree's Uncommitted once it is listed failing` | `reselect_in_worktrees()` reads when the section has a repository or a failure (the reviewer's measured fix) | from P15: stayed `aineo is reading the repository` where the commits window's failure line was expected | MC1 `if unread and (section.repository or section.failure) then` → `if unread and section.repository then` → killed by 1, assertion |
| 2 | `Say what the chosen worktree's watch sees on Linux, and how it fails` | the help's paragraph, `aineo-limits`, README and this note: on Linux the top folder at once; a subfolder's change, and a stage, at the agent's commit or another read | docs | — |
| 3 | `Watch no folder twice for a chosen worktree's Uncommitted` | `WatchOptions.working_tree_only` (`aineo.git.watch`'s fourth parameter is now the table `how`): the working tree alone, no `HEAD` read; the changes home asks for it, and starts no watch for a worktree under its own top while its own watch sees subfolders (`own_watch_sees()`) | outside the editor's top: choosing the line added 2 folders to the event loop's watches, not 1 (P1/P14); inside, with subfolders seen: a watch of it was started (P7b) | MC3 the option dropped (the duplicate watch restored) → killed by 2; MC3b `if repository and own_watch_sees(repository.top) then` → `if false then` → killed by 1 |
| 4 | `Tell a failed worktree watch and pin every way the watch stops` | cases from P1, P5, P16, P6: one start across two reads; stopped at `VimLeavePre`; stopped at `let_go()`; stopped on failure | the first three arrived green: the code came in the fix round before them | MW1 the same-top guard deleted → killed by 1; MW3 the `VimLeavePre` lines deleted → killed by 1 (`watched = true` at quit); MW4 `stop_worktree_watch()` deleted from `let_go()` → killed by 1; MW5 the stop deleted from the failure branch → killed by 1 |
| 5 | (same commit) | a failure is kept by the worktree's top and shown on the files window's failure line while that line is chosen (`chosen_worktree_watch_failure()`); no watch starts again until the line is chosen again or the pane shown again | the files window showed no failure | MC5 `if not repository or failed then` → `if not repository then` (restarted at the next read) → killed by 1 |

Each mutant ran alone on the group `the watch of the worktree chosen` (MC1 on `a reported worktree not listed yet`), its source restored in the same call; every kill an assertion. Under MC3 the case "lists a file the agent writes" failed too, besides the folder count.

Runs after A658 (no whole suite: the orchestrator verifies): the new file, 36 cases, and `test_git_watch`, `test_changes`, `test_changes_worktrees`, `test_changes_scope`, `test_changes_announce`, `test_changes_copies`, `test_changes_follow`, `test_changes_keep_view`, `test_changes_tree_commits_pane`, `test_entry_changes`, `test_entry_reported_work`, `test_entry_explorer`, `test_doc`: Fails (0) each; `make lint` clean.

## Commits

*Recorded after the merge.*
