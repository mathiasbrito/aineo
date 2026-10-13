# 2026-10-13 — T57 Worktree base

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t57-worktree-base` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D32–D35, D41, D55, D56, D60, C15, T57
- Wave plan: [[Implementation/Waves/00014-cut-bases-new-session/plan]] › O9–O11, A204–A206; brief: [[Implementation/Waves/00014-cut-bases-new-session/brief-t57-worktree-base]], with its dispatch amendment (A220)
- Rests on: [[Sessions/2026-10-12 — T50 Worktree filter]] and [[Sessions/2026-10-12 — T52 Landed]], [[Sessions/2026-10-13 — T56 Commit file read]]; wave 13's A154 and A155

## What was done

Another worktree's base counts from the working branch (D60). D60 and the rulings A204–A206 (O9–O11, all (a)) are the orchestrator's assumptions under the user's go-ahead of 2026-10-13, not the user's decisions.

- **The shared name read** (`lua/aineo/changes/working_branch.lua`, new): `read(read, done)` finds the working branch's name (`changes.working_branch`, else the short name of `origin/HEAD`) and the commit it names now, and calls `done(failure, name, commit)`. `landed.lua`'s file-local `find_name()` is gone: *Landed* reads through it, and so do the worktree reads. The commit is read at every call and never kept.
- **The worktree reads** (`lua/aineo/changes/worktrees.lua`): `WorktreeRead` gains `working_branch` (the setting). A read of the other worktrees (`read_other_worktrees()`) and a read of one worktree's whole change (`read_worktree()`) read the working branch's commit once (`read_base_sources()`); each worktree's base (`read_base()`) is `git.worktree_base()` against that commit, and where that gives none — no working branch, a name that names no commit, no shared history (`worktree_base()` answers nil) — against D32's comparison commit, which `comparison_read_once()` reads at most once per read and only when a worktree needs it. When the name or the commit cannot be read, each section says why over what the window last listed for it, as a failed comparison read did.
- **The call sites** (`lua/aineo/changes/init.lua`): the two `WorktreeRead`s carry `session.settings.working_branch`. Nothing else changed there: behaviour 6 needed no change (see the amendment: `follow_change()` reads the commits window at `references_changed`, and `read_files()` asks again for a worktree's whole change).
- **The heading, Enter and `l`** count from the base stored in the section by the read (`entry_diff.lua` already reads `worktree.base`), so they follow the list with no change of their own.
- **`doc/aineo.txt`**: *aineo-changes*, the sentence on a worktree's base (the working branch, D32's as the fallback, a failed read of the working branch), and a LIMITS › *The changes pane* item (a worktree forked from the editor's own feature branch lists that branch's commits the working branch lacks; the cost of the read). The item on a rebase merge (A155) stays as it was.
- **`tests/helpers/git_repo.lua`**, additions only: `create_with_remote()`, `land_in_remote()`, `fetch_remote()`. `tests/test_changes_landed.lua` keeps its own file-local `with_remote()`, `land()` and `fetch()`, which the new helpers duplicate; moving it onto them is a follow-up outside this packet's files.

Git processes started by the first showing of the pane, one other worktree, counted by a logging stand-in for git (`.tests/` scratch, run on the tree before and after): with a working branch set and the worktree forked from it, **19 before, 17 after**; with no remote and no setting, **18 before, 19 after** (the one more is the read of `origin/HEAD` for the worktrees' base; the fallback to D32's comparison reads as before). With the working branch giving a base, D32's `@{upstream}` read is not run at all.

## Unit list

1. The commits window counts a worktree's commits from the working branch's commit (the editor behind); 2. the files window under its heading, from the same base; 3. Enter on the heading, from the same base; 4. `origin/HEAD` names the working branch when no setting does; 5. the setting wins over `origin/HEAD`; 6. no working branch: D32's base; 7. a name that names no commit: D32's base, its comparison read once however many worktrees; 8. a worktree sharing no history with the working branch: D32's base; 9. the working branch's commit read once for all worktrees, D32's comparison not read when the working branch gives the base; 10. a failed read of the working branch's commit: each section says why and keeps its list; 11. the same in the files window; 12. a fetch that moves the working branch moves the bases in both windows.

## Red and green

Seen red, for the intended reason (read from the output): units 1, 2 and 3 — the commits window and the files window listed the landed commit and `landed.txt` besides the agent's own (D32's base, the editor being at the older commit); Enter on the heading read the same.

Arrived green, with the reason: units 4–12. Units 1–3 were made green by the whole of the base logic, because the fifty cases of `tests/test_changes_worktrees.lua` that were green before had to stay green, which needs the fallback to D32 in the same step; each of the later cases therefore passed when first run. Each was then seen red under a mutant (below): unit 4 under M10; 5 under M3; 6 under M2; 7 under M2 and M6; 8 under M2 and M9; 9 under M3, M8 and M6; 10 and 11 under M1, M3 and M8; 12 under M4.

## Mutants

Each row is the literal edit (file: before → after), applied to the tree as pushed, run on the 12 cases of the new group of `tests/test_changes_worktrees.lua` (a copy of the file with the other groups removed), and restored in the same call. Every kill is an assertion failure (`Fails (n)` with the named cases), none a crash.

| # | Edit | Result |
|---|---|---|
| M1 (plan 1) | `worktrees.lua`: `if not sources.working_commit then` → `if true then` (the base is always D32's) | killed by assertion: 9 of 12 — the commits window, the files window, Enter on the heading, `origin/HEAD`, the setting, the read-once count, both failed-read cases, the fetch case. The three D32 cases pass, as they should |
| M2 (plan 2) | `worktrees.lua`: `local function against_comparison()` → the same followed by `if true then done(nil, nil) return end` (no fallback) | killed by assertion: "…where there is no working branch" (`base` listed), "…names no commit" and "…shares no history" |
| M3 (plan 3) | `worktrees.lua`: `working_branch = read.working_branch,` → `working_branch = nil,` (the setting ignored by the worktree reads) | killed by assertion: 8 cases, among them "…not from the remote’s default branch" |
| M4 (plan 4) | `worktrees.lua`: `done(nil, { working_commit = commit,` → `KEPT_COMMIT = KEPT_COMMIT or commit` then `done(nil, { working_commit = KEPT_COMMIT,` (the commit kept from the first read) | killed by assertion: "moves with the working branch once a fetch moves it" (the files window keeps `A agent.txt`) |
| M5 (plan 5), first run | `entry_diff.lua`: `git.diff_since(repository, worktree.base, done, options)` → `git.diff_since(repository, nil, done, options)` (a stand-in: Enter on the heading reads from a base that is not the list's) | killed by assertion: "shows its whole change since the working branch on Enter on the heading" (`a.txt` in the diff) |
| M5 (plan 5), literal | `worktrees.lua` `read_section()`: store `section.base` as the merge base with `sources.comparison` (D32's) instead of the base the list was read from, i.e. `section.repository, section.base, section.listed = repository, base, listed` → the same with `git.worktree_base(repository, comparison, …)`'s answer in place of `base`, inside `sources.comparison(function(_, comparison) … end)` | measured in the fix round, killed by assertion: 4 cases — Enter on the heading (`diff --git a/landed.txt` among the headers), the file diff on Enter and `l`, the read-once count (`@{upstream}` 1, not 0), the worktree with no commit |
| M6 | `worktrees.lua`: `if answered then` → `if false then` (D32's comparison read for every worktree) | killed by assertion: "…names no commit" (the `@{upstream}` count is 2, not 1) |
| M10 | `working_branch.lua`: `elseif name then` → `elseif false then` (the remote's default branch is never read as the working branch) | killed by assertion: unit 4, "is counted from the remote’s default branch when the setting names none" (M8 ignores the setting and does not touch it) |
| M8 | `working_branch.lua`: `if read.working_branch then` → `if false then` (the setting ignored by the name read, *Landed* too) | killed by assertion: 10 cases |
| M9 | `worktrees.lua`: `if failure or base then` → `if failure or true then` (no fallback where there is no shared history with the working branch) | killed by assertion: "…shares no history with the working branch" |

## Fix round

The two reviews of PR #196 (attack on Opus; tests and records on Sonnet) found the fallback and failure paths unpinned. The orchestrator's rulings A221 (the two git-home docstrings made false) and A222 (a worktree with no commit reads no base) are its assumptions under the user's instruction of 2026-10-06, not the user's decisions.

- **Attack 1.** A failed read of D32's comparison was pinned by nothing: the old case ("…when the editor’s branch cannot be read") breaks `symbolic-ref`, which the name read of `origin/HEAD` now meets first. Added "…whose base needs the editor’s comparison commit, the setting naming no commit" and "…the worktree whose base needs the editor’s comparison commit when that cannot be read, the others as ever" (an unrelated worktree fails, the one based on the working branch keeps its list with no failure line). The old case is retitled "…when the remote’s default branch cannot be read". Green on the head; killed MA by assertion.
- **Attack 2.** "…when the merge base with the working branch’s commit cannot be read, not counting from the editor’s comparison commit", a stand-in failing `merge-base` of that worktree against the landed commit. Green on the head; killed ME by assertion.
- **Attack 3.** "shows the diff of a file of its whole change from the working branch on Enter and on l": the landed commit and the agent both change `a.txt`, and both keys show `+agent` alone. Green on the head; killed MF and the literal D32-base mutant by assertion.
- **Attack 4 (A222).** Red first: "is not read at all for a worktree with no commit yet, the editor’s comparison commit neither" (one `@{upstream}` run where none is wanted). `read_base()` answers `done(nil, nil)` for a repository with no `head` before reading anything. Killed MH by assertion.
- **Records.** LIMITS says the working branch's commit is read twice by a commits-window read (the worktrees and *Landed*) and once by the files window under a worktree's whole change; *aineo-changes* says a worktree's whole change includes its uncommitted and untracked files. The docstrings of `git.worktree_base()` (`git/init.lua` and `git/worktrees.lua`) say the commit is the working branch's or the editor's comparison; the git home's code is untouched (A221). This note's unit 4 is attributed to M10, and M5 is measured literally (rows above).

Mutants of the fix round (literal edits, run on the 17 cases of the new group):

| # | Edit | Result |
|---|---|---|
| MA | `worktrees.lua` `against_comparison()`: `done(failure)` → `done(nil, nil)` | killed by assertion: 2 cases (the two of attack 1) |
| ME | `worktrees.lua` `read_base()`: `if failure or base then` → `if base then` | killed by assertion: 1 case (attack 2) |
| MF | `entry_diff.lua`: `git.file_diff(repository, worktree.base, entry.change, done, options)` → `git.file_diff(repository, nil, entry.change, done, options)` | killed by assertion: 1 case (attack 3) |
| MH | `worktrees.lua` `read_base()`: `if not repository.head then` → `if false then` | killed by assertion: 1 case (attack 4) |

## Pins that moved

None. The fifty cases of `tests/test_changes_worktrees.lua`, and `tests/test_changes_landed.lua` (40), `tests/test_changes_filter.lua` (40), `tests/test_entry_changes.lua` (16), `tests/test_doc.lua` (48) passed unchanged. The cases with a `Landed in origin/HEAD` or `Landed in origin/main` heading have no remote with a commit, so their worktrees read the same base through D32's fallback.

## Decisions and open threads

- **Facts that held:** behaviour 6 needed nothing; the git home needed nothing; `aineo.changes` still requires `aineo.git` alone; the grep for deep requires prints two lines, both inside `aineo.changes` (`worktrees.lua` and `landed.lua` requiring `aineo.changes.working_branch`).
- **The brief's step 4 reads D32's comparison "at most once per read of the window and only when it is needed".** It is read lazily by the first worktree that has no base from the working branch, and its answer, a failure included, serves the rest of the read. A failed comparison read now fails the sections that need it, where before it failed all of them upfront; with a working branch that gives every base it is never run.
- **A worktree with no commit yet** read the comparison commit although its base is nil either way; the fix round (A222) answers it with no base before any git is run.
- **Follow-up (outside this packet's files):** `tests/test_changes_landed.lua`'s local `with_remote()`, `land()`, `fetch()` can use `git_repo.create_with_remote()`, `land_in_remote()`, `fetch_remote()`.
- **Help for T58:** no hunk of `doc/aineo.txt` is outside *aineo-changes* and LIMITS › *The changes pane*.

## Task lines

- T57 `[X]` (`feature/t57-worktree-base`, into `dev`) — another worktree's base counts from the working branch (C15; D60, proposed; D32, D56): its merge base with the commit `changes.working_branch`, or `origin/HEAD`, names now, read once per read; D32's base where that gives none (no working branch, a name that names no commit, no shared history); a failed read of the working branch is told under each worktree; the heading, commits, files and diffs count from that base. The orchestrator's assumptions A204–A206 and A220, not the user's decisions.

## Commits

- PR #196, `feature/t57-worktree-base`, head `9551f88` (5 commits), merged by rebase into `dev` as `25597ed` (the dispatch amendment), `e296009` (the base from the working branch), `52b673d` (this note), `5b6eca9` (the fix round), `c170fcb`.
- Released in v0.2.32 (PR #197, `main` `31a3b23`).
