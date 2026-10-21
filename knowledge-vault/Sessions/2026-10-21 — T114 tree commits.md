# 2026-10-21 — T114 tree commits

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t114-tree-commits` · **Pull request:** into `dev`

A small feature (D30: no whole suite before the push). Each branch line of the Reported tree lists, beneath it, the commits from the base the line shows to the branch's tip (D102, A540). Built on `bugfix/t112-reported-notice`, which was about to merge; the branch rebases onto `dev` with `git rebase --onto origin/dev ef78be1` once it does.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D102, A540 (inside D102's row), T114; D100, A531, A534, A536 (the tree and its bases), D30
- [[Sessions/2026-10-21 — T111 reported tree]] — the tree whose branch lines gain commits
- `lua/aineo/changes/tree_commits.lua` (new), `lines.lua` (`tree_commit_rows()`), `copy.lua` (`read_tree_commits()`, `take_tree_commits()`), `reports.lua` (`TreeLine.commits`)
- `doc/aineo.txt` — `aineo-changes-reported-section`; `README.md`
- `tests/test_changes_tree_commit_lines.lua`, `test_changes_tree_commits.lua`, `test_changes_tree_commits_pane.lua` (new); `test_changes_announce.lua`, `test_changes_keep_view.lua` (three expectations of the whole tree)

## Task lines

- [X] T114 Commits under each branch of the Reported tree (C15; D102, A540, A531, A536, D30): a pure module `aineo.changes.tree_commits` (`wanted()` the branch lines whose work the pane has read and whose line shows a base, each pair of branch and base once; `read()` resolves `refs/heads/<name>` and lists `<base>..<tip>` with `aineo.git`'s `commits_between()`, one branch after another, a failed read leaving no entry; `commits_of()` the commits of a line, by branch and the base its line shows) read by the changes home after the reported branches (`read_tree_commits()`), kept in the session by branch and base, and given to each branch line as `commits`; `lines.lua` draws them (`tree_commit_rows()`: six cells in, the commit line of the window, each listing the files of the commit in that branch as a commit of a branch shown alone does, at most `MOST_TREE_COMMITS` (20), then `… N more` in `AineoChangesNote` picking what the branch's line picks); a tree commit the branch no longer lists gives way to Session work in the default view; the help and the README — done, PR to follow

## What was done

- **The lines.** `lines.lua` gives a branch's row, after it, a row per commit of the `commits` its `TreeLine` carries: the window's commit line (`commit_text()`) behind an indent one depth below the branch's (six cells), its colours moved by the indent, its entry the one a commit of a branch shown alone has (`filter.of_branch_commit()`, key `\0branch\0<name>\0<id>`), so the files window, Enter, `l`, `<BS>`, `gf` and the diff keys act through the entry as they do on any commit of a branch. Past `MOST_TREE_COMMITS` (20) one row `… <n> more` in `AineoChangesNote` shares the branch line's entry, so Enter picks the branch.
- **The read.** `tree_commits.wanted()` takes the lines whose work the pane has read (`read_base`) and whose report gave a base (the line shows a hash, not `?`); the commits are read from exactly that `read_base`, so the base is the one the line shows after a rebase (A531) and on the editor's own worktree (A536). `read()` runs inside the serial read of the commits window, after the reported branches, one branch after another, off the main loop; the home keeps the result by branch and base, so a line is given commits only when they were read from the base it shows, and the tree draws without them until then. Every read of the commits window reads them again.
- **The selection.** A tree commit the branch no longer lists (reset, rebase) gives way to Session work and the files window is read for it, in the default view; the focused view and the graph keep their own selection.

## Decisions

- A540, read from the brief's spec file; D102's row is appended to the plan note with A540 inside it, and a T114 row.
- **A line that shows `from ?` lists no commits.** A540 says the base is exactly the one the line shows; `?` shows none, and `wanted()` leaves such a line out although the pane did read its work from its own base. Listing them from that base would put commits under a line that shows no base. Reported as an open point.
- **The `… <N> more` line is indented six cells**, like the commit lines it ends, and coloured from its first character, not the indent. A540 says "one line" without its indent.
- **A tree commit's filter is the branch's commit** (`of_branch_commit(name, commit)`), not the session's own (`of_commit`): the same commit may stand under two branches or in the session's own list, and the keys must tell them apart. `gf` on a file listed under it opens the branch's checked-out worktree's file, or tells it is checked out nowhere, as for a commit of a branch shown alone.
- `choose_for_shown_view()` was left as it was at first (A542); the attack review found a commit of a reported branch selected in the focused reported view dropped at the switch back, and A545 changed it (below).

## What was seen red

- `test_changes_tree_commit_lines` — 4 cases: below its line, six cells in, newest first, as any commit line is (`different values at key 2, left = "    feature/a * from 0123456", right = "      2222222 …"`); below a checked-out branch's line too; the colours; the files of the commit (`filter` read `worktree`, not `commit`, the entry being the next line's).
- `test_changes_tree_commits` — 8 cases: the four `wanted` cases and the `commits_of` case (`attempt to call field 'wanted'` / `'key'` nil), and the three readings (`key` nil; `t: expected table, got nil`), with the module file empty.
- `test_changes_tree_commits_pane` — the first case, a checked-out branch's commits below its line from the base the line shows (the tree had no commit line where one was expected).

## What arrived green, and why

- `test_changes_tree_commit_lines` | none for a branch with no commit past its base: green by nature (nothing to draw); killed by the mutant that gives an unread line a placeholder commit (L7).
- `test_changes_tree_commit_lines` | the four cap cases (20 with none left out, 23, 21, the line that picks the branch): pin the cap written in the same unit as the lines; killed by L1–L4.
- `test_changes_tree_commits_pane` | not-checked-out branch, after a rebase, the editor's own worktree's branch, nothing past the base, the cap, the new commit on a later read, the files window following, Enter, `l` and `<BS>`, drawing before the read: pin the reading and wiring that the first pane case drove; killed by C1, R, L7, L1, C3, L6 and the held reading (below).
- `gives way to Session work once the branch no longer lists it` first arrived green for the wrong reason: the cursor, still in the commits window, was put on the Session work line by the shrinking page and the selection followed it; the mutant that disables the reselect (C2) survived it. The case now leaves the commits window first; C2 is killed by an assertion.

## Mutants

Each applied to a copy of the committed file, run on the test files named, restored. `tree_commits.lua` is `T`, `lines.lua` `L`, `copy.lua` `C`.

| Edit | Run on | Killed by |
|---|---|---|
| L1 `lines.lua`: `M.MOST_TREE_COMMITS = 20` → `21` | `test_changes_tree_commit_lines`; `test_changes_tree_commits_pane` | assertion, 3 cases; assertion, the cap case |
| L2 `lines.lua`: `if #commits > M.MOST_TREE_COMMITS then` → `>=` | `test_changes_tree_commit_lines` | assertion, 1 case |
| L3 `lines.lua`: `math.min(#commits, M.MOST_TREE_COMMITS)` → `math.min(#commits, M.MOST_TREE_COMMITS - 1)` | `test_changes_tree_commit_lines` | assertion, 4 cases |
| L4 `lines.lua`: `more_commits_row(#commits - M.MOST_TREE_COMMITS, …)` → `… + 1` | `test_changes_tree_commit_lines` | assertion, 2 cases |
| L5 `lines.lua`: `(' '):rep((line.depth + 1) * INDENT_CELLS)` → `(' '):rep(line.depth * INDENT_CELLS)` | `test_changes_tree_commit_lines` | assertion, 6 cases |
| L6 `lines.lua`: the tree commit's entry without `filter = listed_under` (the files window not following a tree commit) | `test_changes_tree_commits_pane`; `test_changes_tree_commit_lines` | assertion, 3 cases (following, `l`, reselect); a Lua error in `entry_diff.lua` (E5108), the Enter case; assertion, 1 case |
| L7 `lines.lua`: `local commits = line.commits or {}` → `… or { <one placeholder commit> }` | `test_changes_tree_commit_lines`; `test_changes_tree_commits_pane` | assertion, 3 cases; assertion, 2 cases (the not-checked-out branch, the unread tree) |
| C1 the commits read from the pane's own base: `copy.lua` passes `own_base = reading.base` and `tree_commits.lua` counts `read.own_base..tip` in place of `item.base..tip` | `test_changes_tree_commits_pane` | assertion, 3 cases (checked-out, not checked out, after a rebase) |
| R the commits read from the reported base: `tree_commits.lua` `wanted()` and `commits_of()` use `line.branch.base` in place of `line.read_base` | `test_changes_tree_commits_pane` | assertion, 3 cases (not checked out, after a rebase, the editor's own); the checked-out case survives, as its reported base is the effective one |
| C2 `copy.lua` `take_tree_commits()`: `and not scope.page_lists(commits_page(), selected)` → `and false` | `test_changes_tree_commits_pane` | survived the first version of the case; assertion, 1 case once it left the commits window |
| C3 `copy.lua` `read_tree_commits()`: returns at once when `next(reading.tree_commits)` is set (not read again) | `test_changes_tree_commits_pane` | assertion, 3 cases |
| T1 `tree_commits.lua` `wanted()`: `line.branch and line.branch.base and line.read_base` → `line.branch and line.read_base` | `test_changes_tree_commits` | assertion, 1 case |
| T2 `tree_commits.lua` `wanted()`: `if not seen[key] then` → `if true then` | `test_changes_tree_commits` | assertion, 1 case |

## Runs

On the tree pushed, each file on its own (D30): `test_changes_tree_commit_lines` 9 cases, `test_changes_tree_commits` 8, `test_changes_tree_commits_pane` 12, `test_changes_announce` 46, `test_changes_keep_view` 85, `test_changes_graph_pane` 27, `test_doc` 82: green. `make lint` clean (StyLua, selene: 0 errors, 0 warnings). Also green, run before the last edit and unchanged since by the code: `test_entry_reported_work`, `test_entry_explorer_pick`, `test_entry_session_handover`, `test_changes_reports`, `test_changes_scope`, `test_changes`.

## Fix round of PR #311 (A545)

Four rulings, each test-first on `feature/t114-tree-commits`; D30: the files touched and those that reach the changed code were run one at a time, no whole suite.

- **`take_branch()` (P1).** A tree commit selected in the default view while a branch picked with `s` waits behind it keeps its files through a read: the swap for the branch's whole change applies only when the commit belongs to the branch and the branch is the view shown alone. Case: `keeps its files through a read while a branch picked with s waits behind the default view`, red before the change.
- **The cursor through a redraw (P2, P4).** `write_page()` puts the cursor back on the line listing its entry nearest the line it was on. Cases: the line saying more are left out stays (5 against 26 red), a commit listed under two worktrees stays on its copy (7 against 12 red).
- **A tree commit acts in its worktree (P3).** When the branch is checked out in a worktree other than the editor's, each commit under its line carries that worktree as the commits window last listed it (`TreeLine.worktree_section`, given by `reported_lines()`): its filter is the worktree's commit of the branch, so the files window names the worktree (`(worktree agent-1)` where it said `(branch feature/a)`), Enter shows the diff as the worktree's own section does, and `h` compares against the worktree's `HEAD`. The key gains the worktree's top level before the branch's, so a commit stands apart from the same commit in the worktree's own section. A branch checked out in the editor's own worktree or nowhere carries none. Because the files window now reads the commit through the worktree, `reselect_in_worktrees()` leaves a tree commit to `take_tree_commits()`; without that the existing case `gives way to Session work once the branch no longer lists it` ended on the worktree's whole change (seen red). Cases: the entry of a commit under another worktree's branch, under the editor's own, `h` against the worktree's `HEAD` (red; and red again with the section not given), Enter in the worktree.
- **`choose_for_shown_view()`.** Keeps a selection the default view lists, a tree commit included, and its docstring no longer says the default view lists every filter but a branch's. Case: a commit of a reported branch selected in the focused view stays selected, cursor on its tree line (cursor on Session work, 9 against 7, red).

Runs of the fix round, each file on its own, no whole suite: `test_changes_tree_commit_lines` 11 cases, `test_changes_tree_commits_pane` 17, `test_changes_tree_commits` 8, `test_changes_reported_tree` 20, `test_changes_reports` 13, `test_changes_announce` 46, `test_changes_author_column` 22, `test_changes_author_pane` 13, `test_changes_copies` 22, `test_changes_edit_file` 22, `test_changes_filter` 40, `test_changes_follow` 27, `test_changes_full_context` 33, `test_changes_graph` 43, `test_changes_graph_pane` 27, `test_changes_keep_view` 85, `test_changes_keys` 52, `test_changes_landed` 40, `test_changes_open_file` 56, `test_changes_scope` 87, `test_changes_sessions` 80, `test_changes_worktrees` 67, `test_changes` 126, `test_entry_changes` 44, `test_entry_claim` 22, `test_entry_explorer_pick` 9, `test_entry_reported_work` 11, `test_entry_session_handover` 12, `test_entry_report` 4, `test_doc` 82: green. `make lint` clean.

Not given a case of its own: `gf` and `<S-CR>` (they read the entry's worktree through the files window; the entry is pinned, and before the change `<S-CR>` already found the checked-out worktree of the branch).

Open: a branch listed under a worktree that has another branch checked out, while a third worktree has it, carries no worktree (A545 gives the worktree of the node only when it has the branch checked out); the orchestrator's ruling if it should.

## Open threads

- `from ?` lines list no commits (above): the orchestrator's ruling to keep or change.
- `D101` and `T113` are on `feature/t113-diff-base`, in flight; D102's and T114's rows are appended after D100's and T112's and will meet theirs at the rebase. If T113 lands first, a tree commit line shows `Against:` as any commit line does, once the branch is rebased onto it.
- **Commits** — recorded after the merge.
