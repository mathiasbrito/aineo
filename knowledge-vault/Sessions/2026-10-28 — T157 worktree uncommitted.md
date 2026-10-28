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

- [X] T157 each other worktree's Uncommitted line (D133, A653, A654): `filter.of_worktree_uncommitted()`; the row `Uncommitted — <folder> (<branch>)` first under each other worktree's heading, in the default view and shown alone (`s`, `\g`, the reported work), kept chosen across `\g`; its files read with `git.uncommitted_files()` in the worktree's repository, again at every read of the pane; a file's diff, the whole diff and `h` read with the editor's own readers there, in `aineo://worktree{top}//uncommitted[/{path}]`; a worktree whose read failed lists its section's failure; save marks kept to the editor's worktree; help and README. No key changed.

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

## Open threads

- **The Reported tree's branch lines.** A653 (1) places the line in each worktree's section (default view's other worktrees, and the focused view); the Reported tree atop the default view keeps its own shape (a worktree line, its branch lines and their commits) with no Uncommitted line of its own. Its checked-out branch line already picks the worktree's whole change, uncommitted files included. Whether the tree should also get an Uncommitted line under the checked-out branch is the user's to say.
- **A653 (3) names `R` among the pane's refreshes; the changes pane has no `R` key** (`R` puts back a default text elsewhere). The pane is read again by its watch, when it is shown again (`refresh_shown_pane()`) and at a report; the help names those, and the line is read again at each.
- The label of an agent's call is not on a worktree section, so the name says the folder and the branch (A653 (4) gave `<worktree label or branch>` as an example).

## Commits

*Recorded after the merge.*
