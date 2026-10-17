# 2026-10-17 — T82 Changes scope branch

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t82-changes-scope-branch` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Implementation/Waves/00018-scope-filter/plan]] and its brief `brief-t82-changes-scope-branch` (with the amendment at dispatch this packet wrote, as its first commit)
- [[Sessions/2026-10-16 — T81 Changes scope worktree]] — the scope, `s` and `\g` this packet extends
- [[Planning/aineo — v1 agent console]] › D76 (the scope), D32, D55, D60, C13, C15
- `doc/aineo.txt` — *aineo-changes*, *aineo-changes-s*, *:Aineo-pane*, *hl-AineoChangesFilter*

D76 and the answers U1–U3 and the toggle are the user's. A391–A403 are the orchestrator's assumptions, never the user's decisions; the decisions listed under *Decided beyond the brief* are the implementer's, for the orchestrator to rule.

## Task lines

- [X] T82 The changes pane shows one branch alone (C13, C15; D76) — done on `feature/t82-changes-scope-branch`: `aineo.git` lists the local branches (`git/branches.lua`, `git.list_branches()`); `s`'s one list offers, after the worktrees, each `[branch] <name>` no worktree has checked out other than the working branch; a pick shows `Branch <name>` and its commits since its base (a new `changes/branch.lua`, the base read by the worktrees' rule through `worktrees.read_base_of()`), chooses its whole change, the committed files from base to tip, with Enter, `l`, `h` and `gf` as under Landed (`entry_diff.lua`, `head_diff.lua`, `commit_file.lua`); a branch that names no commit clears the scope, told once; help under *aineo-changes-s*.

## What was done, and why

- **The git home.** `git.list_branches(found, done, options)` reads `refs/heads/` with `for-each-ref --sort=refname --sort=-committerdate`, the format `%(objectname)%00%(refname)`; the names are cut from the full reference, so a branch a tag shares its name with is listed as it is named (`%(refname:short)` answers `heads/x`). Newest commit first; equal dates by name.
- **The list `s` offers.** `branch.read_candidates()` reads, one git at a time, the branches, the worktrees as they are now (`git.list_worktrees()`) and the working branch's name; `scope.items_of(others, candidates)` builds the items: the worktrees as T81 gave them, then `[branch] <name>`, the name quoted as `lines.quoted_path()` quotes it. A branch is left out when a worktree, the editor's own included, has it checked out, or when it is the working branch, short names compared (`origin/dev` is `dev`; a working branch that names a local branch is that branch alone). `offer_scopes()` reads them when `s` is pressed and opens the picker once they are read; a second press while they are read does nothing; a home let go meanwhile opens none.
- **The scope.** `Scope` is a worktree's (`top`) or a branch's (`branch`); `scope.members_shown()` gives the commits window a list of `{ worktree }` or `{ branch }` members, so that T84's reported set joins the same list. `session.branch` holds what the commits window last read of the branch (`aineo.changes.BranchSection`: name, tip, base, commits, or `names_no_commit`, or the failure over what was known).
- **The read.** `branch.read()` resolves `refs/heads/<name>` (never another reference of the name), reads the base with `worktrees.read_base_of()` — the seam made beside `read_worktree()`: the merge base of the tip with the commit the working branch names, else with the comparison commit, D60's rule, not restated — and the commits `base..tip` (`git.commits_between()`), every commit of the tip when there is no base (A402). It runs after the worktrees in the commits window's one serial read (`window_read`'s `read_scope`), at every read, shown alone or not, and nothing is kept: the tip and the base are read anew.
- **The view.** `lines.lua`: `Branch <name>` whole in `AineoChangesFilter` (`filter_row()`), then the commits as `commit_rows()` lists them, each under a `commit` filter carrying `branch` (`filter.of_branch_commit()`, told apart by key `\0branch\0<name>\0<id>`), or `No commits on this branch`, or the failure line. The files window: `Files in: Branch <name>` and `git.files_between(base, tip)` as the commits window last read them (committed files only, no `*`), `No files changed on this branch`; under a commit `Files in: <id> <subject> (branch <name>)`, read in the editor's repository.
- **The diffs.** A `branch` kind in `entry_diff` (whole: `git.diff_between(base, tip)`, `aineo://branch/{name}//since-base`; a file: `git.file_diff_between()`, `…//diff/{path}`), in `head_diff` (from `HEAD` straight to the tip, `…//head/{path}`) and in `commit_file` (the file as the tip has it, `aineo://show/{tip}/{path}`). A commit of the branch needs no code: it is a `commit` filter, so `aineo://commit/{id}`, `aineo://head/commit/{id}/{path}` and `aineo://show/{id}/{path}` are the editor's own commits' diffs. `DiffSource` gained `branch`.
- **Gone, reset, toggle.** `take_branch()` keeps what was read: a branch that names no commit clears the scope, the focused view and `session.branch`, selects *Session work* when the selection was the branch's, and tells `aineo: Branch <name> is gone; the changes pane shows the default view` once at `INFO`; a selected commit the branch no longer lists gives way to its whole change; the files are read again when the tip or the base moved. A branch checked out in a new worktree stays the scope. `choose_for_shown_view()` gives a branch's selection way to *Session work* in the default view (A423 had removed the fallback for worktrees, whose filters the default view lists; the default view lists no branch), and `take_own` leaves a selected commit that carries a branch alone, as it does for Landed's and a worktree's.
- **Boundary.** `lua/aineo/git/` and `lua/aineo/changes/` and `doc/aineo.txt`, `tests/test_changes_scope.lua`, `tests/test_git_branches.lua`; the composition root, every other home, `README.md` (it lists no key of the pane) and `.claude/` are untouched. The deep-require check (`grep -rnE "require\(['\"]aineo\.[a-z_]+\." lua plugin tests scripts`) prints 164 lines, none from outside a home that reaches into another: every line is a home's own files requiring one another, or a test's stub; the new ones are `changes/branch.lua` (requires `aineo.changes.worktrees`, `aineo.changes.working_branch`), `changes/copy.lua`, `entry_diff.lua`, `head_diff.lua` and `commit_file.lua` requiring `aineo.changes.branch`, and `git/init.lua` requiring `aineo.git.branches`, which requires `aineo.git.process`. No new edge between homes, no cycle.

## Decided beyond the brief

For the orchestrator to rule; none is the user's decision.

1. **`s` reads the worktrees afresh** (`git.list_worktrees()`) for the checked-out set, not `session.commits_others` and not the repository found at the session's start (`session.repository.branch`, which goes stale at a checkout). Pinned by a case that checks out `late` in the editor's worktree after the session began.
2. **With the worktrees unlisted and none known, no branch is read** and T81's words are told (`scope.why_not_ready()`): nothing then says which branches are checked out. T81's case for that line is unchanged. With the worktrees listed but the branches failing, the worktrees are offered and `aineo: the local branches could not be listed: <words>` is told once at `WARN` (A403's wording was not pinned by the brief). A failure of the second read of the worktrees, or of the working branch's name, counts as a failure of the branch listing.
3. **The working branch's short name** (brief 3, mutant 2): `origin/dev` hides the local `dev`; a working branch that names a local branch (`feature/dev`) hides that one alone, not `dev`. The name is `landed`'s: the setting's, else `origin/HEAD`'s, read at `s`.
4. **A second press of `s` while the branches are read opens no second picker**, and a home let go (a tab closed) meanwhile opens none.
5. **A branch deleted between the picker and the pick** is found gone by the read the pick asks for and told as any gone branch is (`aineo: Branch <name> is gone…`), not by T81's `picked_gone()` words.
6. **Words the brief left open:** `No files changed on this branch`, `Files in: <id> <subject> (branch <name>)`, `told` for `gf`'s failures `the branch <name>`.
7. **`Scope`, `lines.commits_window()`'s `scope`, `scope.sections_shown()`** changed shape (members instead of worktree sections; `sections_shown()` became `members_shown()`): no test pinned them directly.

## Baseline

On `dev` `bbf4400`, Neovim 0.12.5, each file alone: `tests/test_changes_scope.lua` 42 cases, `tests/test_changes_landed.lua` 40, `tests/test_changes_worktrees.lua` 67, `tests/test_git_changes.lua` 23, all `Fails (0) and Notes (0)`.

## Unit list, red and green

1. `git.list_branches` — newest first, tie by name, names `a/b` `x-1` `v1.2`, a tag of the same name, none before the first commit, no remote-tracking branch, git that cannot run (`tests/test_git_branches.lua`, 7 cases): **seen red ×7** (`list_branches` missing: the call raised, `result` nil); green by `git/branches.lua`.
2. `s` offers the branches (`tests/test_changes_scope.lua`, group *branches in s*, 10 cases): **seen red ×6** — the offered list held the worktrees alone (the list cases), the two cases with no other worktree found no picker, and the failing listing told nothing; **arrived green ×4**: *are not read once the worktrees could not be listed* (green by nature: nothing listed branches yet; killer B10), *leave out a working branch that names a local branch alone* (written after the rule it pins; killer B4), *a second press … opens no second picker* (the guard was written with the offer; killer B11) and *are not offered once the home was let go* (written after the guard; killer B13). The existing cases of group `s` needed no change but one: `press_s` now waits for the answer (a picker or a message), since the picker opens once the branches are read, and two cases wait with `wait_for_the_answer_to_s()`. Those are the pins that moved, and for that reason only.
3. A pick shows the branch alone (group *a branch*): **seen red ×3** — the default view stayed (the pick was ignored): the commits since the merge base with the working branch, *No commits on this branch*, and the commits since the merge base with the comparison commit where the working branch gives none. The colour of the first line is in the first case.
4. Its files, committed only, unmarked; a commit under the cursor; the commit kept when read again; no files (5 cases): **arrived green** — the code was written with unit 3 (the pick selects the whole change, `read_branch_files()`, `take_branch()`); killers M4, M5, M7, M8, M9, M10, M11, M15, M16.
5. Read again with the tip; reset below the selected commit; checked out in a new worktree; gone (deleted, renamed, hidden); `\g` (7 cases): **arrived green**, pinning `take_branch()` and `choose_for_shown_view()` written with unit 3; killers M20–M28. The hidden-gone case first let M24 survive (the final toggle waited for the default view and would have found the branch gone either way); it now asserts the message before the toggle.
6. The diffs, 10 cases: **seen red ×7** — a crash in `entry_diff.read()` (`OWN_READS` had no `branch` kind) for Enter on the heading, on a file and on a renamed file, for `l` and for the unreadable first read, a crash in `head_diff.read()` for `h`, and `gf` waiting for a buffer that never came; **arrived green ×3**: Enter on a commit of the branch and on a file under it, `h` and `gf` under a commit — a commit of the branch is a `commit` filter, so the editor's own commits' code serves; killers E12, E13, E14 (the two cases for `h` and `gf` were first red for a race in the test, the cursor moved before the selection was placed; they wait for the whole change now).

The cases the branch adds: 10 (*branches in s*) + 25 (*a branch*) = 35 in `tests/test_changes_scope.lua`, and 7 in the new `tests/test_git_branches.lua`.

## Mutants

Each is the literal edit, applied to the final tree (after the last production edit; the one assertion added afterwards is named), run on a copy of the test file narrowed to the groups that exercise it (`branches in s` and `s` for B*, `a branch` for M* and E*; `tests/test_git_branches.lua` for G*), and restored from a copy. Every kill below is an assertion; no run printed a Lua error or E5560.

| # | Plan | Edit | Result |
|---|---|---|---|
| G1 | | `git/branches.lua`: `'--sort=-committerdate',` → `'--sort=committerdate',` | killed ×1: *newest commit first* |
| G2 | | `git/branches.lua`: delete `'--sort=refname',` | **survives**, equivalent on git 2.54.0, which breaks equal dates by name itself; kept so the order does not rest on that |
| G3 | | `git/branches.lua`: `%(refname)` → `%(refname:short)` | killed ×5 |
| G4 | | `git/branches.lua`: `HEADS,` → `'refs/',` (remote-tracking branches listed) | killed ×2: the tag case, the remote case |
| B1 | 1 | `scope.lua`, `branches_offered()`: `ipairs(candidates.worktrees)` → `ipairs({})` (a branch a worktree has checked out is offered) | killed ×9 |
| B1a | 1 | the same loop over `vim.list_slice(candidates.worktrees, 2)` (the editor's own branch offered) | killed ×9 |
| B1b | 1 | the same loop over `{ candidates.worktrees[1] }` (the others' branches offered) | killed ×6 |
| B2 | 2 | `scope.lua`: `return not checked_out[branch.name] and not is_working_branch(…)` → `return not checked_out[branch.name]` (the working branch offered) | killed ×2 |
| B3 | | `scope.lua`: `return not listed[working] and name == working:match('^[^/]+/(.+)$')` → `return false` | killed ×1 |
| B4 | | the same line → `return name == working:match('^[^/]+/(.+)$')` | killed ×1 |
| B5 | | `scope.lua`: the loop over the offered branches wrapped in `vim.fn.reverse(…)` | killed ×1 |
| B6 | | `scope.lua`: `text = '[branch] ' .. lines.quoted_path(branch.name)` → `text = lines.quoted_path(branch.name)` | killed ×6 |
| B7 | | the same → `text = '[branch] ' .. branch.name` | killed ×1 |
| B8 | | `copy.lua`: `if failure then vim.notify(scope.branches_unlisted(failure), …)` → `if false then …` | killed ×1 |
| B9 | | `branch.lua`: the worktrees of the candidates → the editor's own branch as found at the session's start, the others as read | killed ×1 |
| B10 | | `scope.lua`: `if #known.others.sections == 0 and known.others.failure then` → `if false then` | killed ×2 |
| B11 | | `copy.lua`: delete `if offering then return end` | killed ×1 |
| B12 | | `copy.lua`: `if #items == 0 then` → `if false then` | killed ×1 |
| B13 | | `copy.lua`: delete `if released then return end` | killed ×1 |
| M1 | 3 | `branch.lua`: the base from `read.session_base`, handed `session.base` by `copy.lua` (the session's base, not the working branch's) | killed ×21 |
| M2 | | `worktrees.lua`, `read_base_of()`: `sources.comparison` → an answer of nil | killed ×1 |
| M4 | 4 | `copy.lua`, `read_branch_files()`: `git.files_between(…)` → `git.changed_files(session.repository, read.base, done, …)` (the working tree) | killed ×20 |
| M5 | | `lines.lua`: `MARKS_SAVES` gains `branch = true` | killed ×1 |
| M7 | | `copy.lua`, `show_branch_alone()`: delete `select_filter(filter.of_branch(item.branch))` | killed ×21 |
| M8 | | `copy.lua`, `take_own`: delete `and not session.selected.branch` | killed ×2 |
| M9 | | `lines.lua`: `filter.of_branch_commit(branch.name, commit)` → `filter.of_commit(commit)` | killed ×6 |
| M10 | | `lines.lua`: the `(branch <name>)` suffix of a commit's name deleted | killed ×6 |
| M11 | | `lines.lua`: the branch heading in `AineoChangesNote` instead of `AineoChangesFilter` | killed ×10 |
| M12 | | `lines.lua`: `No commits on this branch` → `No commits in this branch` | killed ×1 |
| M13 | | `lines.lua`: the note for no commit → `M.READING` | killed ×1 |
| M14 | | `copy.lua`: delete `read_scope = read_branch_scope,` | killed ×25 |
| M15 | | `copy.lua`, `take_branch()`: delete the re-read of the files when the tip or base moved | killed ×21 |
| M16 | | `lines.lua`: delete `branch = M.NO_BRANCH_FILES,` | killed ×21 |
| M20 | | `branch.lua`: `tip = read.before and read.before.tip or tip` before the failure check (the tip kept) | killed ×5 |
| M21 | 5 | `copy.lua`: `if read.names_no_commit then` → `if false then` (a deleted branch's scope kept) | killed ×3 |
| M22 | | `copy.lua`: delete the `vim.notify(scope.gone(current), …)` | killed ×3 |
| M23 | | `copy.lua`: delete the reselection of *Session work* in the gone branch | killed ×1 |
| M24 | | `copy.lua`: the branch read only `and session.focused` | killed ×1 (after the case was tightened) |
| M25 | | `copy.lua`: `if not lists_commit(selected, read.commits) then` → `if false then` | killed ×1 |
| M26 | | `copy.lua`: delete the default view's fallback to *Session work* for a branch's selection | killed ×1 |
| M27 | | `copy.lua`: a scope cleared when a worktree lists its branch | killed ×1 |
| M28 | | `copy.lua`: the scope view's choice `scope.whole_change_of(shown[1])` → `select_session_work()` | killed ×1 |
| E1 | | `entry_diff.lua`: `git.diff_between(…)` → `git.diff_since(source.repository, read.base, …)` (the working tree) | killed ×1 |
| E2 | | `entry_diff.lua`: a file's `git.file_diff_between(…)` → `git.file_diff(source.repository, read.base, …)` | killed ×2 |
| E3 | | `entry_diff.lua`: `//since-base` → `//since_base` | killed ×1 |
| E4 | | `entry_diff.lua`: `//diff/` → `//show/` | killed ×3 |
| E5 | | `head_diff.lua`: the branch's folder → `'head'` | killed ×1 |
| E6 | | `head_diff.lua`: `from`/`to` of `file_diff_straight(head, tip)` swapped | killed ×1 |
| E7 | | `head_diff.lua`: `head` → `source.branch.base` | killed ×1 (the case needs an own commit changing `x.txt`, which it makes) |
| E8 | | `commit_file.lua`: `branch = true` out of `LISTED_AT_A_COMMIT` | killed ×1 |
| E9 | | `commit_file.lua`: `commit = source.branch.tip` → `source.branch.base` | killed ×1 |
| E10 | | `entry_diff.lua`: `done(branch.unreadable(source.branch))` → another failure | killed ×1 |
| E11 | | `copy.lua`: delete `branch = session.branch,` from `diff_source()` | killed ×7 |
| E12 | | `entry_diff.lua`: `git.commit_diff(source.repository, entry.commit.id, …)` → `git.diff_since(source.repository, source.base, …)` | **survived** the case that read the buffer's name only; killed ×1 once it read the diff's file headers (the assertion added in the last commit; this row was run on that tree) |
| E13 | | `head_diff.lua`: the commit's `file_diff_straight(commit, head)` swapped | killed ×1 |
| E14 | | `commit_file.lua`: `commit = entry.filter.commit.id` → `source.repository.head` | killed ×1 |

The plan's mutants: 1 is B1/B1a/B1b, 2 is B2, 3 is M1, 4 is M4, 5 is M21. 56 mutants ran on the final tree; G2 survives as equivalent, E12 survived once and is killed.

## Suites

On Neovim 0.12.5, the host loaded, `AINEO_TEST_JOBS=4 AINEO_TEST_RUN_LIMIT_MS=2700000 make test` on the tree pushed (its code and tests as the last production and test commits left them; the note is the only file added after): 4258 cases in 108 files, `Fails (0) and Notes (0)`, exit 0. `tests/test_changes_scope.lua` 77 cases (42 before), `tests/test_git_branches.lua` 7 (new); the first whole run, before the help was wrapped, failed one case, *the help fits in 78 columns* — three lines of the new help were wider than 78 columns — and nothing else of 4258. `make lint`: StyLua and selene clean. Files run alone on `dev` `bbf4400`, for the baseline: see above.

## Open threads

- The rulings above are the orchestrator's to make.
- T84 adds the reported set to the same scope: `scope.members_shown()` and `lines.commits_window()`'s members list are where it joins; `branch.read_candidates()` and `scope.items_of()` are where its `[reported]` item would sit.
- `README.md` lists `\g` among the layout's keys and no key of the pane: unchanged, as the brief asked to check.

## Commits

Recorded after the merge.
