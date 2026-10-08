# 2026-10-08 — T38 Changes worktrees

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t38-changes-worktrees` · **Pull request:** into `dev`, a regular packet of wave 9, stage 2

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D18, D19, D22, D31–D35, D41, C13, C15
- [[Planning/aineo — worktrees and session switches]] › P1–P5
- [[Ideas/The changes pane follows the agents' worktrees]]
- `Implementation/Waves/00009-worktrees-sessions/plan.md` (wave 9) › *Verification mutants* › T38, A8, A9, A22, and `brief-t38-changes-worktrees.md` with its amendments and corrections to 2026-10-08
- `Implementation/Waves/00009-worktrees-sessions/evidence/w9-probes.txt` (A1–A3)
- [[Sessions/2026-09-27 — T23 git home]], [[Sessions/2026-10-05 — T25 Changes pane]], [[Sessions/2026-10-07 — T32 Changes colours]], [[Sessions/2026-10-07 — T37 Changes per session]]

## What was done, and why

The user asked on 2026-10-06 that the changes pane (`\pc`) also follow the agents' worktrees; D31–D35 (the user's answers of 2026-10-07) say how. This packet builds them in the git home (C13) and the changes home (C15); the composition root is untouched.

- **The git home** (`lua/aineo/git/`): `list_worktrees(found, done)` reads `git worktree list --porcelain -z`, the worktree `found` is first, then git's order; an entry marked `prunable` or `bare`, and one whose directory is gone, are left out (D31, A8, A9). `worktree_base(found, worktree, done)` is D32: the merge base with the upstream of the editor's branch, with the branch when it has none, with the editor's `HEAD` when detached, read from the editor's top level at every call. `repository.read_upstream()` resolves `<branch>@{upstream}`. New file `lua/aineo/git/worktrees.lua`.
- **The changes home** (`lua/aineo/changes/`): each window shows the editor's own section first, exactly as before and under no heading (D33, T38-1), then a section per other worktree under `Worktree <folder> (<branch>|detached)`, with its files or commits, or "No files changed in this worktree" / "No commits in this worktree". New file `lua/aineo/changes/worktrees.lua` reads, for one window, the worktree list and each other worktree's list (find, base, list), one after another.
- **One read at a time per window** (D35): `window_read()` replaces `list_read()`. A read is the editor's own list (shown as soon as git answers, with T37's guards kept), then the other worktrees'; the window is written again at the end only when it shows or showed another worktree, so a repository with no other worktree writes each window exactly as before. Every watch call reads both windows' other worktrees; the editor's own commits are still read only when its branch moved.
- **Enter** (D34): on another worktree's file, that worktree's diff from the base its list was read from; on its commit, that commit's diff; names `aineo://worktree<top>/diff/<path>` and `aineo://worktree<top>/commit/<id>`. A heading lists no entry.
- **Failures**: a worktree whose find, base or list fails shows git's words under its heading, over the list it last showed; a failed worktree list keeps the sections under one line after the editor's own; a worktree whose directory is gone by its read's answer is dropped, not told.
- **The help**, inside the three fences: *aineo-panes*' changes item; *aineo-changes* (first paragraph to the watch failure), with a new paragraph on the other worktrees; LIMITS › *The changes pane*, one item added.

## Decisions & reasoning

- **D31–D35** are the user's answers of 2026-10-07; **A8 and A9** are the orchestrator's assumptions, built as written.
- **No shared history, or no commit yet, reads with no base** (the brief's *Not measured* left the choice): `merge-base` exits 1 for unrelated histories and 128 for an unborn `HEAD`; both give `nil`, so such a worktree lists every file as new and every commit as its own, rather than a failure under its heading. Same when the editor's worktree has no commit.
- **The failed list's line goes after the editor's section**, where the other sections are. The brief words it "keeps the editor's own section working as today, under one line in git's words", which in the help's idiom puts the line above; D33 (a binding row) puts the editor's section first, so D33 won. Reported as a reading.
- **The heading's words** are the packet's: `Worktree <folder> (<branch>)`, `detached` in the branch's place, in `AineoChangesNote` as a line that lists nothing (a new group would need a tag in *Colours*, outside this packet's fences).
- **D32's base is read per worktree** from the editor's `HEAD` (`read_head` + upstream + `merge-base`), and each worktree's repository by `find_repository()`: about ten git processes per worktree per window. Declarative over cheap; the measured cost is in the help and below.
- **One read per window, not two.** A second reader for the other worktrees, beside the editor's own, kept every existing timing but broke D35's "one read at a time per window"; rejected. The cost: a window's read now ends once its worktree list has answered, a few tens of milliseconds after its own list shows, which moved three pins (below).
- **`*` across editors and before the follow** (T38-1, T38-2, the ruling on T39-2): three sentences of *aineo-changes* are worded for the behaviour once T39 merges (A22: no wave-9 release before T39). The 1.5 s is `SETTLE_MS` in `lua/aineo/claude/readiness.lua` (read, line 27).

## Unit list (stated before the first test)

Git home, `tests/test_git_worktrees.lua`: (1) listed from the main worktree, it first; (2) from a linked one, it first; (3) a detached and a locked one kept; (4) a prunable one left out; (5) a newline in a path read whole; (6) a `bare` entry left out, a bare repository's linked worktree listed; (7) a locked worktree whose directory is gone left out; (8) no head before a first commit; (9) the base with the upstream; (10) with the branch when no upstream; (11) with the editor's `HEAD`, read now, when detached; (12) none for no shared history; (13) none before the worktree's first commit; (14) none while the editor's has no commit.

Changes home, `tests/test_changes_worktrees.lua`: (15) files window, own first then sections; (16) commits window likewise; (17) a detached heading; (18) a worktree with nothing changed, each window; (19) Enter on another worktree's file; (20) on its commit; (21) on a heading; (22) two worktrees' diffs of one path; (23) a worktree added after the first showing; (24) a commit in another worktree; (25) a worktree removed; (26) a worktree's find, base or list failing; (27) a later failure keeps the list; (28) the worktree list failing, each window; (29) a later list failure keeps the sections; (30) a worktree removed while read; (31) one read at a time per window with several worktrees.

## Red and green

Each red was read as the behaviour missing, from the output.

| Test | Red message (or why green) |
|---|---|
| (1) `the worktrees` › `are listed from the main one, it first, then a linked one` | `different values at key "result", left = nil` — `list_worktrees` did not exist |
| (2) `… from a linked one, it first, then the main one` | `"result"->1->"branch", left = "main", right = "side"` |
| (3) `keep a linked one` › `that is` ×2 | **arrived green**: the parser reads only the fields it names. Killed by G1, G2 (run) |
| (4) `leave out one git marks prunable…` | red in its first form (directory removed): `"result"->2` was the gone worktree. Sharpened after the A9 unit (only its `.git` removed), so the mark alone leaves it out: then **arrived green**, the code existing. Killed by mutant 1 (run) |
| (5) `read a path holding a newline whole` | **arrived green**: `-z` was in the first implementation. Killed by mutant 5 (run) |
| (6) `of a bare repository leave out its bare entry…` | `"result"->2` was `bare.git` (a first run failed on the fixture — `invalid reference` — not a valid red; fixed) |
| (7) `leave out a locked one whose directory is gone…` | `"result"->2` was the gone worktree |
| (8) `give no head commit for one before its first commit` | `head`, left = `"0000…0000"` |
| (9) `the base of a worktree` › `… upstream of the editor's branch` | `"result", left = nil` — `worktree_base` did not exist (a first run failed on the fixture's start point; fixed) |
| (10) `… editor's branch when that has no upstream` | `failure`, `code = 129`, `usage: git merge-base` |
| (11) `… editor's HEAD, as it is now, when that is detached` | `"result", left = nil` — the nil branch raised |
| (12) `… none when it shares no history…` | `failure`, `{ code = 1, message = "", reason = "failed" }` |
| (13) `… none before its first commit` | `failure`, `code = 129` |
| (14) `… none while the editor's has no commit yet` | **arrived green**: the guard of (13) takes `other` too. Killed by G4 (run) |
| (15) `the files window` › `lists the editor's files first…` | `Left: { "  M notes.txt" }` |
| (16) `the commits window` › `lists the editor's commits first…` | `Left: { "No commits on this session" }` |
| (17) `heads a detached worktree's section so` | `Left: { "No files changed on this session" }` — the heading raised on a nil branch |
| (18) `a worktree with nothing changed` ×2 | key 3 missing in each window |
| (19) `Enter` › `on another worktree's file…` | `name`, left = `"aineo://diff/notes.txt"`, text `{ "" }` |
| (20) `… on another worktree's commit…` | `name`, left = `"aineo://commit/<id>"` |
| (21) `… on another worktree's heading does nothing…` | **arrived green**: a heading row lists no entry. Killed by G5 (run) |
| (22) `… on one path in two worktrees shows two diff buffers…` | **arrived green**: the names of (19). Killed by mutant 3 (run) |
| (23) `the worktrees followed` › `show one added…` | **arrived green**: every watch call already read the files window whole. Killed by mutant 4 (run) |
| (24) `… show a commit made in another worktree…` | key 3, left = `"No commits in this worktree"` |
| (25) `… drop one removed…, its diff left as it was` | **arrived green**: the list no longer names it. Killed by R1 (run) |
| (26) `a worktree whose read fails` ×3 | `ls-files`: key 2 missing (the page could not be built); then `rev-parse`: key 2 missing, `merge-base`: key 3 `"  A notes.txt"` |
| (27) `a worktree whose later read fails` › `keeps the list it showed…` | key 4 missing (it first ran three times inside (26)'s parametrized set; moved to a set of its own) |
| (28) `a list of worktrees that fails` ×2 | key 2 missing in each window |
| (29) `a later list of worktrees that fails` › `keeps the worktrees it showed…` | key 3 missing |
| (30) `a worktree removed while it is read` › `is dropped…` | key 2, left = `"Worktree agent (agent)"` with `fatal: cannot change to '…/agent'` |
| (31) `the reads` › `of a window stay one at a time…` | **arrived green**: `window_read()` and the sequential loop. Killed by G9 and G9b (run) |

**Pins moved in suites this packet may change**, each red first in the run that found it:
- `tests/test_changes.lua`: `SPY_ON_GIT` spies `list_worktrees`, and `wait_for_the_reads()` waits for it; `the reads` › `run one at a time…` waits for the first read to end before it saves (it timed out on "three reads answered", the saves coalescing into the first read's worktree list); `leave no timer running…` (red: `uv = 1`) passes through the same wait; `the pane` › `starts no watch and reads no list until it is first shown…` asserts `list_worktrees = 0` (red on the new key).
- `tests/test_entry_changes.lua`: `COUNT_FINDS` counts `_G.worktree_lists`, and `wait_for_the_reads()` waits for them (`shown once reads its files once` was red: `Left: 1, Right: 2`).

## Mutants

Each ran alone, from a pristine copy, on a copy of its test file narrowed to the group that targets it (`.tests/t38-*.lua` wrappers that load the file and clear the other groups), on the final code, Neovim 0.12.5.

| # | Literal edit | Group | Result |
|---|---|---|---|
| 1 | `LEFT_OUT_MARKS = { prunable = true, bare = true }` → `{ bare = true }` | `the worktrees` | killed, assertion: `leave out one git marks prunable…` |
| 2 | `merge_base(run, worktree, upstream or head, done)` → `merge_base(run, worktree, head, done)` | `the base of a worktree` | killed, assertion: `… upstream of the editor's branch` |
| 3 | `diff_name()`: `if entry.worktree then` → `if false then` | `Enter` | killed, assertion: (19), (20), (22) |
| 4 | `read_other_worktrees()` lists once: a module-level `listed_once` answered (scheduled) in place of `git.list_worktrees` after the first list | `the worktrees followed` | killed, assertion: `show one added…` |
| 5 | `{ 'worktree', 'list', '--porcelain', '-z' }` → without `'-z'`, and `vim.split(output, '\0'` → `'\n'` | `the worktrees` | killed, assertion: the newline case alone |
| 6 | `files_window()`: `vim.list_extend(own_file_rows(view), worktree_rows(…))` → `vim.list_extend(worktree_rows(…), own_file_rows(view))` | `the files window` | killed, assertion: both cases |
| 7 | `LEFT_OUT_MARKS` → `{ prunable = true }` | `the worktrees` | killed, assertion: the bare case |
| 8 | `if not listed.left_out and vim.uv.fs_stat(worktree.top) then` → `if not listed.left_out then` | `the worktrees` | killed, assertion: the locked-gone case |
| 9 | `own_file_rows()`'s last return wrapped as `vim.list_extend({ note("Worktree repo (main)") }, …)` | `the files window` | killed, assertion: both cases |
| G1 | `LEFT_OUT_MARKS` gains `detached = true` | `the worktrees` | killed, assertion: `keep a linked one` (detached) |
| G2 | `LEFT_OUT_MARKS` gains `locked = true` | `the worktrees` | killed, assertion: `keep a linked one` (locked) |
| G4 | `if not (worktree.head and other) then` → `if not worktree.head then` | `the base of a worktree` | killed, assertion: `… while the editor's has no commit yet` (`code = 129`) |
| G5 | the heading row given `entry = { key = section.top, change = { path = 'notes.txt', kind = 'modified' }, worktree = section }` | `Enter` | killed, assertion: `{ 2, {} }` against `{ 1, {} }` |
| G9 | `ended()` inserted after `reads.take_own(failure, answer)` | `the reads` | killed, assertion: `start`, `start` in the log |
| G9b | the worktrees of one read read side by side (all `read_section` calls at once, `done` on the last answer) | `the reads` | killed, assertion: `start`, `start` in the log |
| F1 | `read_commits(change.branch_moved)` → `if change.branch_moved then read_commits(true) end` | `the worktrees followed` | killed, assertion: `show a commit made in another worktree…` |
| D1 | `elseif vim.uv.fs_stat(worktree.top) then` → `elseif true then` | failure groups | killed, assertion: `is dropped, not told as a failure` |
| K1 | `if before then` (copying the last list) → `if false then` | failure groups | killed, assertion: `keeps the list it showed…` |
| L1 | `done({ sections = read.before.sections, failure = failure })` → `sections = {}` | failure groups | killed, assertion: `keeps the worktrees it showed…` |
| L2 | `shows_any()`: `return #others.sections > 0 or others.failure ~= nil` → `return #others.sections > 0` | failure groups | killed, assertion: both windows of (28) |
| R1 | `done({ sections = sections })` → `done({ sections = #sections > 0 and sections or read.before.sections })` | `the worktrees followed` | killed, assertion: `drop one removed…` |

Not mutated: the "its diff left as it was" half of (25) — no code wipes a diff, so there is nothing to remove.

## Verification

**Whole suite** (`make test`, Neovim 0.12.5, on the tree pushed — `feature/t38-changes-worktrees` rebased on `dev` `132da01`, knowledge-only since `f27ee69`): **2265 cases in 66 groups, `Fails (0) and Notes (0)`, exit 0** — `dev`'s 2229 and this packet's 36 (`tests/test_git_worktrees.lua` 15, `tests/test_changes_worktrees.lua` 21). The files moved kept their counts: `tests/test_changes.lua` 120, `tests/test_entry_changes.lua` 12; and those run without change: `tests/test_changes_sessions.lua` 61, `tests/test_entry_panes.lua` 86, `tests/test_layout_diffs.lua` 10, `tests/test_doc.lua` 44. `make lint`: StyLua and selene clean. `tests/helpers/git_repo.lua` was not changed, so the files requiring it ran only in the whole suite.

**Read time with five worktrees** (`.tests/t38-measure.lua`, not committed): a fixture with five other worktrees, each with a commit, a modified file and a new one; both windows read again after `refresh_shown_pane()`, timed until each window's six list reads answered: 1257, 1304, 1267, 1176, 1250, 1503, 1367 ms (seven runs; median 1267). About a quarter of a second of git per worktree for each window; the editor's own lines show first.

**Merge check with T39 and T40** (brief, *Rule 2*): neither `feature/t39-panes-follow-switch` nor a T40 branch existed on `origin` when this packet pushed (`git ls-remote --heads origin`), so there was nothing to merge; `tests/test_doc.lua` ran on this branch's tree. The second of T38 and T39 to push runs the check.

## Task lines

- T38 — built on `feature/t38-changes-worktrees`; D31–D35, A8, A9 as written; a worktree with no shared history or no commit reads with no base; the failed list's line follows the editor's section (D33). Open: the read cost per worktree (below).

## Open threads

- **Cost.** About ten git processes per worktree per window at every read: 1.2–1.5 s for both windows with five worktrees on a small repository. Computing the editor's comparison commit once per read, and the worktree's repository from the list rather than by `find_repository()`, would cut it by about half; not done (the git home's interface would grow a step a caller must order).
- **Messages name no worktree.** A diff of another worktree that cannot be read, or finds no room, is told by its path alone ("the diff of notes.txt …").
- **Linux** was not run: what the editor's watch sees of other worktrees there is worded "may" in LIMITS.

## Commits

*Recorded after the merge.*
