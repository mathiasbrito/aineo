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
- **D32's base is read per worktree** from the editor's `HEAD` (`read_head` + upstream + `merge-base`), and each worktree's repository by `find_repository()`: about ten git processes per worktree per window. Declarative over cheap; the measured cost is in the help and below. *(Fix round: the editor's comparison commit is read once per window read since V1, and a refresh with five worktrees runs 72 git processes, not 96 — *Fix round* below.)*
- **One read per window, not two.** A second reader for the other worktrees, beside the editor's own, kept every existing timing but broke D35's "one read at a time per window"; rejected. The cost: a window's read now ends once its worktree list and every other worktree's list have answered — a few tens of milliseconds after its own list shows when there is no other worktree, 1.1 to 2.1 s with five (the records review's probe) — which moved three pins (below). *(Corrected in the fix round: it said the read ends once the worktree list has answered.)*
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

**Counted once each** (corrected in the fix round, records review finding 6): 26 cases seen red in their final form and 10 arrived green, one of the ten, (4), seen red in an earlier form and sharpened afterwards. The PR body said 27 seen red and listed the same ten as arrived green, 37 for 36 cases; the packet report said 27 and 9.

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

**Whole suite** (`make test`, Neovim 0.12.5, on the tree pushed — `feature/t38-changes-worktrees` rebased on `dev` `132da01`, knowledge-only since `f27ee69`): **2265 cases in 66 groups, `Fails (0) and Notes (0)`, exit 0** — `dev`'s 2229 and this packet's 36 (`tests/test_git_worktrees.lua` 15, `tests/test_changes_worktrees.lua` 21). The files moved kept their counts: `tests/test_changes.lua` 120, `tests/test_entry_changes.lua` 12; and those run without change: `tests/test_changes_sessions.lua` 61, `tests/test_entry_panes.lua` 86, `tests/test_layout_diffs.lua` 10, `tests/test_doc.lua` 44. `make lint` was **not** clean on the pushed head, though this note, the PR body and the packet report said so: StyLua 2.5.2 wanted `tests/test_changes_worktrees.lua` 600–606 formatted, a block that came in with `ff47247` (records review finding 1); selene was clean. Corrected in the fix round. `tests/helpers/git_repo.lua` was not changed, so the files requiring it ran only in the whole suite.

**Read time with five worktrees** (`.tests/t38-measure.lua`, not committed): a fixture with five other worktrees, each with a commit, a modified file and a new one; both windows read again after `refresh_shown_pane()`, timed until each window's six list reads answered: 1257, 1304, 1267, 1176, 1250, 1503, 1367 ms (seven runs; median 1267). About a quarter of a second of git per worktree for each window; the editor's own lines show first within one read, not before a read already running ends (attack review finding 2; corrected in the fix round).

**Merge check with T39 and T40** (brief, *Rule 2*): neither `feature/t39-panes-follow-switch` nor a T40 branch existed on `origin` when this packet pushed (`git ls-remote --heads origin`), so there was nothing to merge; `tests/test_doc.lua` ran on this branch's tree. The second of T38 and T39 to push runs the check.

## Task lines

- T38 — done in `feature/t38-changes-worktrees`, PR #142 (wave 9, stage 2): D31–D35, A8, A9 as written; a worktree with no shared history or no commit reads with no base; the failed list's line follows the editor's section (D33); fix round: worktrees known by their resolved path and git directory, the own list read between other worktrees (V3), the comparison commit read once per window read (V1); no release yet (released with T39, A22).

## Open threads

- **Cost.** About ten git processes per worktree per window at every read: 1.2–1.5 s for both windows with five worktrees on a small repository. Computing the editor's comparison commit once per read, and the worktree's repository from the list rather than by `find_repository()`, would cut it by about half; not done (the git home's interface would grow a step a caller must order). *(Fix round: the comparison commit is read once per window read (V1); the worktree's repository is still found by git, which finding 1's identity check needs.)*
- **Messages name no worktree.** A diff of another worktree that cannot be read, or finds no room, is told by its path alone ("the diff of notes.txt …"). *(Fix round: they name it.)*
- **Linux** was not run: what the editor's watch sees of other worktrees there is worded "may" in LIMITS.

## Fix round

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`), a fresh agent. **Branch:** `feature/t38-changes-worktrees-fix`, pushed to `feature/t38-changes-worktrees`, PR #142. The one fix round, from the attack, test-integrity and records reviews of `2dd926a`.

### The orchestrator's rulings — assumptions to report to the user

- **FR-1 (attack finding 2): V3, not V2.** D35's "one read at a time per window" is kept as one git at a time per window. An own list asked during the other worktrees' read is read before the next worktree's, not after them all. It still waits for the worktree read in progress: one worktree's steps, or one slow git (the reviewer measured 5.2 s behind a 5 s `merge-base`). V2 is not taken: a separate read for the own list would let two gits of one window run at once. It is a reading of D35 for the user, if the user wants the own list never held.
- **FR-2 (attack finding 3): V1.** The editor's comparison commit is read once per window read. The git home's `worktree_base(found, worktree)` becomes `comparison_commit(found)` and `worktree_base(worktree, comparison)`. With five worktrees, a refresh of both windows runs 72 git processes, against 96 before. It takes 0.7 to 1.6 s until every read has answered (seven runs, median 1.1 s, the host shared). That is still above D35's computed "about 0.6 s of git per second for five worktrees under a writer". The measured figure goes to the user, since D35's acceptance rested on the estimate.
- **FR-3 (the packet's reading, attack finding 6):** a worktree whose path holds a newline stays listed, and its section says only that its read failed. LIMITS now says so. Building the section's repository from the list was not chosen: finding 1's identity check needs git's own answer for the directory.
- **FR-4 (the packet's reading, attack finding 7):** messages about another worktree's diff end the name with `in the worktree <folder>`, the heading's folder name.
- **FR-5 (the packet's reading, attack finding 1):** a listed directory that git finds in another repository than the listed worktree is dropped, as A9 drops a gone one, not told as a failure.

### The spec conflict, a reading for the user

The failed worktree list's line goes **after** the editor's own lines, over the sections last shown. The brief's "keeps the editor's own section working as today, under one line in git's words" would, in T25's idiom, put the line above the editor's section. D33, the user's row, puts the editor's worktree first, "as today". All three reviews judged the author's placement D33's meaning (attack, *The author's spec conflict*; tests, finding 8; records, finding 13). No code changed. It is recorded here for the knowledge pass to put before the user, with the packet's other readings:
- no base for an unrelated or unborn worktree, or while the editor's has no commit;
- the heading's words, and the lines that list nothing;
- FR-1 to FR-5.

### Red → green

| Item | Test | Red, or why green |
|---|---|---|
| Attack 1 | `the editor's own worktree` › `is shown alone, as ever, in a repository whose git directory is separate` | `Left: { "  M notes.txt", "Worktree store.git (main)", "The last refresh failed: fatal: this operation must be run in a work tree" }` |
| | `… in a submodule` | **arrived green**: spent by the git-directory clause. Killed by I1a (run) |
| | `… is shown once, a linked one whose folder moved and left a link behind` | key 4, `"Worktree mine (mine)"`: the editor's own worktree again |
| | `… is not listed as a locked one whose .git is gone, its folder inside the top level` | `Left: { "  M notes.txt", "Worktree agent (agent)", "  M notes.txt" }` |
| | `… in a submodule's linked worktree lists the submodule's checkout as another` | **arrived green**, the reviewer's control. Killed by I1e (run) |
| | git home `the worktrees` › `of a submodule give its checkout's top level…`, `of a repository whose git directory is separate…` | **arrived green**: spent by the list's fix. Killed by I1a and I1c (run) |
| | git home `… are listed from a linked one whose folder moved and left a link behind, it first` | **arrived green**, added after I1b survived the pane's group (the section check masked it). Killed by I1b (run) |
| Attack 2 (V3) | `the reads` › `of the editor's own list, asked during the other worktrees', show it before the next worktree is read` | `Left: "No files changed on this session"`, `Right: "  ? saved.txt"` |
| Attack 3 (V1) | `the reads` › `of a window read the editor's branch once, however many worktrees` | `Left: 6`, `Right: 2`, on the committed code. The git home's six `the base of a worktree` cases were red on the new interface (`comparison_commit` missing) |
| | `a worktree whose later read fails` › `… when the editor's branch cannot be read` | **arrived green**: the failure path was written with the split. Killed by V1b (run) |
| | `the reads` › `of a window read nothing of the editor's branch with no other worktree` | **arrived green**, added after V1c survived its group. Killed by V1c (run) |
| Attack 4 / tests 4 | `the reads` › `of the editor's commits, asked during a read, stay asked when a later call asks without them` | **arrived green**, a pin. Killed by M1 (run) |
| Attack 5 | `Enter` › `on two worktrees' files whose top level and path join alike shows two diff buffers` | `Left: false`. The two Enter cases pinning the names then failed on the old form and moved to `//` |
| Attack 7 | `a diff of another worktree that fails` › `is told naming its worktree` | `left = "aineo: the diff of notes.txt could not be read: fatal: broken"` |
| Tests 1 (PR1) | `Enter` › `on another worktree's file shows its diff from that worktree's base, neither the session's nor a HEAD` | **arrived green**, a pin. Killed by E2, E4, E1b (run). The old case was renamed `… shows its diff, named for the worktree` |
| Tests 2 (PR2) | `the commits window` › `no longer lists another worktree's commit once the editor's branch holds it, its base read again` | **arrived green**, a pin. Killed by B3 (run) |
| Tests 3 (PR6) | `the reads` › `of a window stay one at a time…` waits for every git home call to answer, then asserts six `changed_files` asks | the case changed, not added. Killed by Q1 and SQ (run, `Left: 8`) |
| Tests 5 (PR5) | `the files window` › `lists another worktree with no shared history, every file new`, and the commits window's | **arrived green**, pins. Killed by N1 (run) |
| Tests 6 (PR4) | `the files window` › `colours another worktree's heading as a note, and its files as the editor's` | **arrived green**, a pin. Killed by C1, C2 (run) |
| Tests 7 (PR3) | `the files window` › `keeps the cursor on another worktree's entry while one of the same path is listed above it` | **arrived green**, a pin. Killed by KY (run) |

New cases: 21, 18 in `tests/test_changes_worktrees.lua` (now 39) and 3 in `tests/test_git_worktrees.lua` (now 18). Counted once each: **7 seen red** (separate git directory, moved, locked, own list between, branch read once, joined names, failed-diff message) and **14 arrived green**. Changed cases, not counted in the 21: the git home's six base cases, red on the new interface; the two Enter name pins, red on the old form; and PR6's case.

### Mutants

Each is its literal edit, applied alone from a copy, run on a copy of its test file narrowed to the groups named, and restored. The edits are in `.tests/t38fix-mutants.lua` (scratch, not committed). All kills are assertion failures; none was a Lua error.

| # | Edit | Groups | Result |
|---|---|---|---|
| I1a | `if top == found.top or top == found.git_directory then` → `if top == found.top then` | cw `the editor's own worktree`; gw `the worktrees` | killed: 2 + 2 cases |
| I1b | `local top = vim.uv.fs_realpath(worktree.top)` → `local top = vim.uv.fs_stat(worktree.top) and worktree.top` | cw own; gw `the worktrees` | survived cw own (the section check drops the moved worktree); killed by gw's moved case |
| I1c | `worktree.top = found.top` before `table.insert(own, worktree)` removed | gw `the worktrees` | killed: 2 cases |
| I1d | `if not is_listed_worktree(repository, worktree) then` → `if false then` | cw own | killed |
| I1e | `… or repository.git_directory == worktree.top` dropped | cw own | killed (the control) |
| V3a | `before_each_worktree = read_own_then,` → `before_each_worktree = function(proceed) proceed() end,` | cw `the reads` | killed |
| V1a | `read_section()` also starts `git.comparison_commit(read.found, function() end, read.git)` | cw `the reads` | killed |
| V1b | `section.failure = comparison_failure` → `section.failure = nil` | cw `a worktree whose later read fails` | killed |
| V1c | `if #others == 0 then` → `if false then` | cw own; cw `the reads` | survived cw own; killed by the no-other-worktree case |
| M1 / Q2 | `own_asked = own_asked or with_own` → `own_asked = with_own` | cw `the reads` | killed |
| Q1 | `serial.one_at_a_time(` in `window_read()` → a local queue running every ask (`pending` counter) | cw `the reads` | killed (`Left: 8`) |
| SQ | `serial.lua`'s `asked_again` a counter | cw `the reads` | killed (`Left: 8`) |
| N5 | `'aineo://worktree%s//%s'` → `'aineo://worktree%s/%s'` | cw `Enter` | killed: 3 cases |
| N7 | `told_name()`'s `if entry.worktree then` → `if false then` | cw `a diff of another worktree that fails` | killed |
| E1b | `or_failed(function(base)` → `or_failed(function(_) local base = read.found.head` | cw `Enter`, `the commits window`, `the files window` | killed: 3 cases |
| E2 | `entry.worktree.base` → `session.base` in `read_diff()` | cw `Enter` | killed |
| E4 | `entry.worktree.base` → `entry.worktree.repository.head` | cw `Enter` | killed |
| B3 | `git.worktree_base(` → `(section.base and function(_, _, answer) answer(nil, section.base) end or git.worktree_base)(` | cw `the commits window` | killed |
| N1 | a nil base told as `fatal: no base` before `read.read_list(` | cw files and commits windows | killed: 2 cases |
| C1 | the heading row `note(…)` → `{ line = … }` | cw `the files window` | killed |
| C2 | `in_worktree()` gains `colours = {},` | cw `the files window` | killed |
| KY | `key = section.top .. '\0' .. entry.key,` → `key = entry.key,` | cw `the files window` | killed |

### Records corrected

- `make lint` failed on the pushed head (records 1). StyLua now formats `tests/test_changes_worktrees.lua`, and *Verification* above says what was false. The PR body is corrected too. The packet report lies outside this branch.
- The help: records findings 2 to 5 in the review's wording, and finding 11. LIMITS gives the cost and time measured after V1 (finding 7, attack 3), the slow git that still delays the own list (attack 2), and the newline path (attack 6). The names now use `//` (attack 5).
- The counts: the double-counted arrived-green case (finding 6), the read's end (finding 8) and the per-window cost, each above.
- The docstrings: the git home's `list_worktrees()` says which worktrees are left out (finding 9). `find` no longer cites `read_files()` (finding 10).
- The task line is in the closed lines' style (finding 12).

### Verification

- **Whole suite** (`make test`, Neovim 0.12.5, on `64549bf` with this note uncommitted, the tree pushed): **2286 cases in 66 groups, `Fails (0) and Notes (0)`**, exit 0. That is the packet's 2265 plus this round's 21.
- **Touched files** at the end (`make test_file`, each `Fails (0)`):
  - `tests/test_changes_worktrees.lua` 39 and `tests/test_git_worktrees.lua` 18;
  - `tests/test_changes.lua` 120, `tests/test_entry_changes.lua` 12, `tests/test_changes_sessions.lua` 61;
  - `tests/test_doc.lua` 44, `tests/test_entry_panes.lua` 86, `tests/test_layout_diffs.lua` 10.
- `make lint`: StyLua and selene, 0 errors and 0 warnings.
- **Merge check with T39** (`origin/feature/t39-panes-follow-switch` at `5eb5a6f`): `git merge-tree --write-tree` gave tree `3da8ca0`, no conflict. Extracted under the scratch `.tests/`, it passed `tests/test_doc.lua` 44, `tests/test_entry_session_switch.lua` 12, `tests/test_entry_changes.lua` 12 and `tests/test_changes_worktrees.lua` 39, each `Fails (0)`.

## Commits

Recorded after the merge, by wave 9's stage-2 knowledge pass. PR #142 merged by rebase on 2026-10-09 (17:47 UTC; 19:47 CEST), first of stage 2, as `2c67c5c` … `89cefc2` (13 commits), on `dev` `fc3a257`. The orchestrator verified the pull request's head `cc8a053`, rebased on `dev` `fc3a257`: the whole suite `Fails (0)` in 5:14, lint clean, the plan's mutants 7, 8, 6 and 3 applied literally, each killed by assertion (1, 1, 7 and 3 failures). Released in v0.2.16, with T39 (one release for both, the orchestrator's ruling).

The first four are the packet's, the next one its session note, the next six the fix round's code, tests and help, and the last the fix round's note.

| Branch | `dev` | Subject |
|---|---|---|
| `d2ec9d8` | `2c67c5c` | List a repository's worktrees and read each one's base in the git home |
| `5cc2061` | `77745e7` | List each other worktree's files and commits in the changes pane |
| `ff47247` | `0129ecb` | Follow, diff and report failures of the other worktrees in the pane |
| `aa7fa97` | `85f396e` | Document the changes pane's other worktrees, and pin the prunable mark |
| `2dd926a` | `eec9fe7` | Record T38's session: the changes pane follows the worktrees |
| `7e59965` | `5512781` | Know each worktree by what git resolves, not by its listed path |
| `11aa489` | `88a30e6` | Read the editor's own list between other worktrees' reads |
| `17e552d` | `4a4de69` | Read the editor's comparison commit once per window read |
| `9a9703b` | `d9750c8` | Pin the own-list ask, part diff names by //, name worktrees |
| `3f85f06` | `36c854a` | Pin worktree bases, re-reads, colours and cursor in the pane |
| `96eff41` | `ab9d7c2` | Correct the changes pane's help to what the fixes and T39 do |
| `64549bf` | `028a260` | Pin the resolved path of a moved worktree and V1's short cut |
| `2f7abce` | `89cefc2` | Record T38's fix round and correct the packet's records |

The `Branch` column is the pull request's own commits (`refs/pull/142/head`); the verified head `cc8a053` was those commits rebased on `fc3a257`.
