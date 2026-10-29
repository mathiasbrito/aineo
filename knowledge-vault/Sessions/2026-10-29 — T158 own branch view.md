# 2026-10-29 — T158 own branch view

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t158-own-branch-view` (from `dev` at 99372f41) · **Pull request:** into `dev`

A regular packet of wave 21 (D26: the whole suite once before the push). A branch an agent reports in the editor's own worktree, while that worktree has it checked out, now has a view of its own in the changes pane, as another worktree's branch has (D134, A659). Before it, Enter on that worktree's lines showed the default view, so `\g` had nothing to switch to after the report.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D134 row (A659 inside it) and the T158 row
- [[Sessions/2026-10-28 — T157 worktree uncommitted]] — the worktree shown alone and its Uncommitted line (A653–A658), whose pieces this view reuses
- [[Sessions/2026-10-21 — T113 diff base]], [[Sessions/2026-10-21 — T114 tree commits]] — the reported base and the Reported tree
- `lua/aineo/changes/{reports,lines,filter,scope,worktrees,copy}.lua`, `tests/test_changes_own_view.lua`, `doc/aineo.txt`, `README.md`

## Task lines

- [X] T158 your own reported branch's view (D134, A659): your own worktree's line, its checked-out branch's and that branch's `Uncommitted` (and their `s` items) show `Worktree <folder> (<branch>) · yours`, your own Uncommitted, your commits from the reported base (the session's base for `from ?`); the heading lists the whole change from that base, uncommitted included; `\g` switches it with the default view; kept on disk and restored; ended as a scope ends once the branch is not checked out or not reported; help `aineo-changes-own-branch-view`, README. No key changed.

## What was done, and why

- **The pick.** `reports.own_checked_out_branch()` gives the branch reported of your own worktree that it has checked out. While there is one, your worktree's line and its branch's pick `{ top = <your top>, own_worktree = true }` in place of the default view's `{ own = true }`; otherwise they keep the old pick (A659 (2): a branch reported and not checked out stays a branch alone).
- **One read, reused.** `worktrees.read_section()` now takes the reader of its own base. Other worktrees pass the merge base with the working branch (`base_against()`); `read_own_worktree()` passes the session's base, the one the default view reads. The reported base goes through the same `read_effective_base()` as every reported base: it is used while it is behind `HEAD` and descends from the session's base, else the session's base (help, "Each reported branch is read from the base its report gave …"). No second reader was written.
- **The rows.** The section is marked `own`; `lines.worktree_heading()` adds ` · yours`, and `filter.uncommitted_in()` / `filter.commit_in()` give its rows the editor's own Uncommitted and commit filters. The choice is then the same filter in both views, so `\g` keeps it.
- **Kept in the session.** `copy.lua` reads the section after the reported work at every read of the commits window (`read_own_section()`), while your branch is reported, and keeps it in `session.own_section`. `keep_scope_listed_in()` and `reselect_in_worktrees()` leave your own worktree to that read; `end_own_view_unless_reported()` ends the view as a scope ends, told once with `scope.gone()`'s words, and gives a whole-change choice back to Session work; `take_own_section()` chooses the whole change once the commit chosen is gone (an amend).
- **Restored.** `scope.restored_view()` restores a kept pick of your own worktree while its checked-out branch is reported (`restored_pick()`).

## Unit list (stated before the first test)

1. Your own worktree's lines pick it alone while its checked-out branch is reported, else the default view.
2. The tree's rows for those lines list its whole change; the Uncommitted under its branch stays your own.
3. Shown alone, its heading says ` · yours`, then your own Uncommitted, then its commits as your own.
4. Enter on its worktree's line and its branch's line shows it alone, commits from the reported base.
5. Enter on the branch's Uncommitted shows it alone, your Uncommitted chosen.
6. The files window lists the whole change from the reported base, uncommitted included.
7. A branch reported with no base reads from the default view's base.
8. Its three `s` items show it alone.
9. `\g` switches it with the default view.
10. It is kept on disk and shown again after aineo starts again.
11. It chooses its whole change once the commit chosen is gone.
12. It ends once your worktree has another branch checked out.

## Red and green

Seen red:
- unit 1, `the lines | pick the editor’s own worktree alone while its checked-out branch is reported…` — `different values at key branch 2->"own", left = true, right = nil`.
- unit 2, `the Reported section | chooses the editor’s own worktree’s whole change on its lines, and its own Uncommitted under its branch` — the Uncommitted entry's `filter.worktree` was the worktree, expected none.
- unit 3, two at once (a deviation from one red at a time): `lists its heading marked as yours…` — `left = "Worktree main (main)", right = "Worktree main (main) · yours"`; `chooses its whole change on its heading…` — the Uncommitted entry carried the worktree.
- unit 4, `Enter | on the editor’s own worktree’s lines shows it alone… | line {worktree, 3}` and `{branch, 4}` — the commits window still listed `Reported` first.
- unit 10, `the view | is kept on disk and shown again once aineo starts again` — the default view came back.

Arrived green, each pinning code written in an earlier unit, each with the mutant that kills it (all run):
- `pick the editor’s own work … while no branch it has checked out is reported` (reported tree, and its row test in `test_changes_reports.lua`) — M3.
- the four `the editor’s own checked-out branch` cases — M5 (all four).
- unit 5, the rewritten `test_changes_worktree_uncommitted.lua` case `shows, at Enter on the editor’s own branch’s Uncommitted, its own worktree alone…` and the rewritten `test_changes_announce.lua` case `picked by Enter on its line, from a worktree picked, shows it alone…` — both were the old behaviour's tests, red on the new code; M15 and M2a.
- units 6, 7, 8, 9, 11, 12 — M11 / M1, M10, M2a and M15, M2b, M14 / M17, M13.

## Mutants

Each the literal edit, applied to a pristine copy, run on its covering file, restored (`t158-mutants.py` in the session's scratchpad). Every kill is an assertion.

| Id | Edit | File run | Killed by |
|---|---|---|---|
| M1 (A659's first) | `read_own_worktree()`: `read_section(read, …` → `read_section(vim.tbl_extend('force', read, { base_of = function() return nil end }), …` — the view's base the session's | own_view | 10 assertions |
| M2a (A659's second, the old behaviour) | `show_item()`: an `own_worktree` item shows `show_own_work()` | own_view | 11 assertions |
| M2b | `toggle_focused_view()`: `has_focused_view` false for your own worktree's scope | own_view | 1 (`\g`) |
| M3 | `worktree_pick()`: `if M.own_checked_out_branch(…) then` → `if true then` | reported_tree | 1 |
| M4 | same → `if false then` | reported_tree | 1 |
| M5 | `own_checked_out_branch()`: `return reported.name == own.worktree.branch` → `return true` | reported_tree | 4 |
| M6 | `tree_uncommitted_filter()`: `… or line.picks.own_worktree` dropped | reports | 1 |
| M7 | `worktree_heading()`: `(section.own and YOURS or '')` → `''` | reports | 1 |
| M8 | `uncommitted_in()`: `if worktree.own` → `if false` | reports | 2 |
| M9 | `commit_in()`: `if worktree.own` → `if false` | reports | 1 |
| M10 | `read_own_worktree()`: `base_read(nil, read.session_base, …)` → `base_read(nil, nil, nil)` | own_view | 1 (`from ?`) |
| M11 | `read_worktree_files()`: always `worktrees.read_worktree` | own_view | 2 |
| M12 | `restored_pick()`: `return nil` for your own worktree | own_view | 1 |
| M13 | `read_own_section()`: `end_own_view_unless_reported()` dropped | own_view | 1 |
| M14 | `take_own_section()`: `if shows_own_view and …` → `if false` | own_view | 1 |
| M15 | `show_worktree_alone()`: always `filter.of_worktree(section)` | own_view | 1 (`s` item 4) |
| M16 | `keep_scope_listed_in()`: the own-top guard dropped | own_view | 2 |
| M17 | `reselect_in_worktrees()`: the own-top guard dropped | own_view | 1 |

## Runs

- Each touched file on the final code: `test_changes_own_view` (11 cases), `test_changes_reports`, `test_changes_reported_tree`, `test_changes_announce`, `test_changes_worktree_uncommitted`, `test_changes_worktrees`, `test_changes_tree_commits_pane`, `test_changes_keep_view`, `test_changes_scope`, `test_changes_base_origin`, `test_doc`: `Fails (0)`.
- `make lint`: StyLua clean, selene 0 errors, 0 warnings.
- The whole suite (`make test`), once, on the code pushed, on the host's Neovim 0.12.5: 8769 cases in 266 groups, `Fails (0) and Notes (0)`, exit 0.

## Decisions

- **D134 / A659**, as ruled. ~~Read as the help reads every reported base: the reported base only while it is behind `HEAD` and descends from the session's base (`read_effective_base()`)~~ — superseded by A660 (1): for this view, the reported base whenever it is in `HEAD`'s history.
- The tree's own worktree and branch lines, resting under the cursor, now choose the own view's whole change rather than Session work, as any worktree's line chooses its whole change: the choice then has a line in both views at `\g`.
- ~~The branch line's `from` still shows the session's base (A659 (3), the default view unchanged)~~ — superseded by A660 (2): it shows the view's base.

## A660 — the orchestrator's rulings on the two readings

The first reading above, the shared guard, would have hidden the user's own case, so A660 overrules it. The second reading stood in part: the tree line kept the session's base, and A660 (2) now ties it to the view. The rest of what this note records as decided is accepted (A660 (3)).

- **A660 (1), the view's base** — `57e887f7`. For the view of your own worktree alone, the reported base is used whenever it is an ancestor of `HEAD` (`worktrees.read_reported_in_head()`). The session's base is used when it is not in `HEAD`'s history or git cannot place it. `read_section()` is now given that choice beside its own-base reader (`BaseReads`); the other worktrees keep `read_effective_base()`.
  - Red: `Enter | on a branch reported from a commit older than the session’s base shows its commits from that commit`, `different values at key 4, left = nil, right = "… Before the session"`.
  - A second red, from the gap this opened: a commit the view lists from behind the session's base is not among the session's commits, so the commits read gave it back to Session work. `Enter | on a commit made before the session’s base keeps it chosen through a read`, `left = "Files in: Session work"`. Fixed by `own_section_lists()`.
- **A660 (2), the tree line** — `837a79ef`. The line of your own checked-out branch shows, and lists its commits from, the base its view was last read from (`read_base_of()`). The commits window reads the view before the tree's commits, so both move in one read.
  - Red: the announce case, renamed `shows on its checked-out branch’s line the base its view reads, and the commits from it`, `left = "    main * from b218b15", right = "    main * from 8f998b3"`.
  - The tree-commits pane case that pinned the session's base on that line was rewritten the same way.
  - The help's sentence names the view's base.
- **A pin for the base outside the history** — `1d46284d`. MA3 survived the own-view file, so one case was added after the code: `on a branch reported from a commit not in its history shows the commits from the default view’s base`. It was never seen red on its own; MA3 fails it.

### Mutants (A660)

Run the same way as the table above, on the committed tree; every kill is an assertion.

| Id | Edit | File run | Killed by |
|---|---|---|---|
| MA1 (A660's own) | `read_own_worktree()`: `choose = M.read_reported_in_head,` → `choose = M.read_effective_base,`, the shared guard used for the view | own_view | 2 (older base; commit kept chosen) |
| MA2 | the commits read's `take_own`: `and not own_section_lists(session.selected)` dropped | own_view | 1 (commit kept chosen) |
| MA3 | `read_reported_in_head()`: `if failure or not reported_in_tip then` → `if failure then` | own_view | survived, 0 of 13; after `1d46284d`, 1 (base outside the history) |
| MB1 | `read_base_of()`: the own line's `return own and … own.base or session.base` → `return session.base` | tree_commits_pane | 1 |
| MB1b | the same edit | announce | 1 |

### Runs after A660

Each was run on the final code, with `Fails (0)`: `test_changes_own_view` (14 cases), `test_changes_announce`, `test_changes_tree_commits_pane`, `test_changes_worktree_uncommitted`, `test_changes_keep_view`, `test_changes_tree_commit_lines`, `test_changes_worktrees`, `test_changes_base_origin` and `test_doc`. `make lint` is clean. The whole suite was not run again, as A660 asks.

## Open threads

- ~~The branch line's `from` and its commits read from the session's base while the view reads from the reported base~~ — closed by A660 (2).
- A report that takes your branch away ends the view at the pane's next read, not at the report while the pane is hidden.
- The words that end it are a scope's: "… · yours is gone; the changes pane shows the default view", though the worktree is not gone.

## Commits

*Recorded after the merge.*
