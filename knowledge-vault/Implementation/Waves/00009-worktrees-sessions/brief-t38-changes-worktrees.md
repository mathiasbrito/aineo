**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> **Agreed and amended, 2026-10-07; stage 2.** The user answered the converge round on 2026-10-07: P1–P5 are their recommended options, now D31–D35 in the v1 plan note — the options this brief was written with. Wave 8's T32 merged (PR #127), and every fact below was read again at `dev` `f98bd9d`. It is not dispatched until T37 has merged (stage 2: both change `lua/aineo/changes/` and *aineo-changes*); T37 moves `lua/aineo/changes/init.lua` and the help's LIMITS item, so a dated amendment before dispatch gives those line numbers and fences again. Dispatched at once with T39 (S (a)). **Corrected 2026-10-07 from the brief review** (`brief-review.md` in this folder, T38-1 to T38-8, W-2 and W-4): the corrections are made in the body, and *Correction — 2026-10-07, from the brief review*, at the end, lists each; the stage-2 amendment re-checks them against the `dev` this packet starts from.

## Objective

The task, verbatim from the task list:

> | T38 | The changes pane follows the repository's worktrees (C15, C13; D31–D35): beside the editor's own checkout, each of the repository's worktrees with its files and commits since its base, Enter showing their diffs; worktrees appearing and going followed | T23, T37 | planned — wave 9 |

It rests on: D31–D35 (agreed 2026-10-07), which extend D18 (the right column's two windows stay put), D19 (the changes pane: its lists, Enter, the read-only diff, the refresh) and D22 (every commit) from one checkout to the repository's worktrees; C13 (the git home: every git call asynchronous and time-bounded) and C15 (the changes home); T23's watch and T25's one-read-at-a-time rule; D26 and D29. The idea it graduates: [[Ideas/The changes pane follows the agents' worktrees]].

### The behaviour (D31–D35)

- **Which worktrees (D31).** Every worktree `git worktree list --porcelain -z` lists for the session's repository. The editor's own — the one `begin_session()`'s directory is in, matched by `find_repository().top`, not by `getcwd()` (T38-7) — first, as today; then the others in git's order. One marked `prunable` is left out. A locked one is shown. Two more are left out, each the orchestrator's assumption, to report to the user:
  - **an entry marked `bare` (A8).** With a bare main repository, the list's first entry is `worktree <path>/bare.git` and `bare`, with no `HEAD`; `git status` and `rev-parse --show-toplevel` there fail with "fatal: this operation must be run in a work tree" (128), and `find_repository()` answers `not_a_repository` with the same words. Shown, it would be a section that always fails. A linked worktree of a bare repository works (`find_repository()` gives `common_directory = <path>/bare.git`) and is shown (brief review, T38-2);
  - **a worktree, locked or not, whose directory does not exist (A9)**, as a prunable one is. A locked worktree whose directory is gone is listed `locked`, never `prunable`, and `git worktree prune` keeps it; every read there fails with "fatal: cannot change to '<path>': No such file or directory" (128). Claude Code locks every worktree its agents use (A1b), so this is the common case of a gone one (brief review, T38-3).
- **Each other worktree's base (D32).** Its merge base with the upstream of the branch the editor's worktree is on; when that branch has no upstream, with that branch; when the editor's worktree is detached, with its `HEAD`. Read again at every read: nothing is kept. The editor's own keeps the session's base (D19, and T37's per session).
- **The windows (D33).** The editor's own section is **today's lines, with no heading**, exactly as today. Only the other worktrees get a section under a heading line — its folder's name and its branch, or `detached` — with that worktree's files (top window) or commits (bottom window) under it, in today's line format, or that worktree's own "nothing changed" / "no commits" line. So a user with no other worktree sees exactly today's lines, and `tests/test_entry_panes.lua`, which pins `{ 'No files changed on this session' }` and `{ 'No commits on this session' }` (178–201), stays true without being touched (D33; brief review, T38-1).
- **Enter (D34).** On a file of another worktree, that worktree's unified diff of the file from that worktree's base, read-only in the middle column, as today; on its commit, that commit's diff; on a heading line, nothing. A diff's buffer name carries the worktree, so two worktrees' diffs of one path never share a name; the editor's own diffs keep today's names (`aineo://diff/<path>`, `aineo://commit/<id>`). No key opens another worktree's file.
- **Following them (D35).** No watch per worktree. The worktree list and every worktree's lists are read again whenever the editor's own watch calls back and whenever the pane is shown (T25's triggers), one read at a time per window, a trigger during a read reading once more after it. A worktree added shows at the next read; one removed goes at the next read, with its diffs left as they are; a read of a worktree removed meanwhile is dropped, not shown as a failure.
- **Failures.** A worktree whose lists cannot be read shows git's words under its heading, as T25 shows a failed read today, and the other sections stay. A list of worktrees that cannot be read keeps the editor's own section working as today, under one line in git's words.
- **What stays:** D18's two windows, the cursor kept on its entry while it is listed (T25), T32's colours for every section's lines, the one-at-a-time reads, the watch's start at the first showing.

### Facts, checked against `origin/dev` `f98bd9d` (wave 8 merged; re-checked after T37 merges)

- **A1** (`evidence/w9-probes.txt`): the porcelain list's fields (`worktree`, `HEAD`, `branch refs/heads/…` or `detached`, `locked [reason]`, `prunable <why>`, and `bare` for a bare main repository, T38-2), one blank line between worktrees, the main worktree first, the same from any worktree; with `-z`, each field ends in a NUL and each worktree in an empty field. **Without `-z`, git 2.50.1 prints whole a path holding a space, `é`, a tab, `"` or `\`; only a newline in a path splits its line** (`worktree <path>/wt` / `newline`). `-z` reads the newline whole too (brief review, T38-4, re-measured: the `-z` parse holds for a space, a tab, a quote, a backslash and a newline). 20–32 ms.
- **What git answers at the edges** (the brief review's `t38`, git 2.50.1; `brief-review.md`, T38-7):
  - **no shared history** (an orphan branch): `merge-base` prints nothing and exits 1;
  - **an unborn worktree** is listed with `HEAD 0000000000000000000000000000000000000000`, and `merge-base HEAD …` fails with "fatal: Not a valid object name HEAD" (128);
  - **no upstream:** `dev@{upstream}` fails with "no upstream configured" (128); in a detached worktree, `HEAD@{upstream}` fails with "HEAD does not point to a branch" (128);
  - **paths:** the list and `--show-toplevel` both give resolved paths, so the editor's own worktree is matched by `find_repository().top`, not by `getcwd()`.
- **A1b:** Claude Code's agents' worktrees sit under `<top>/.claude/worktrees/`, are locked, and may be detached.
- **A2:** the merge base with `origin/dev` lists an agent's own commits and files only; with `dev` it adds upstream commits the user has not pulled. `git merge-base` 19–56 ms; `git rev-parse --abbrev-ref <branch>@{upstream}` 18–26 ms and answers `origin/dev`.
- **A3:** the editor's own watch already calls back on `git worktree add`, `remove` and `prune`, on any worktree's commit, and on a file written in a worktree nested in the top level — not on one written in a worktree outside it. A linked worktree's repository, as `find_repository()` gives it, has the main one's `common_directory` and `git_directory` `<main>/.git/worktrees/<name>`.
- `lua/aineo/git/`:
  - `init.lua`: `find_repository()` (line 40), `changed_files(found, base, done, options)` (53), `commits_since()` (65), `file_diff()` (79), `commit_diff()` (91), `watch_repository()` (114). Its docstring, lines 1–18, binds: asynchronous, bounded, never raising, `done` called once on the main loop, answers independent of the user's git settings.
  - `repository.lua`: `aineo.git.Repository`, lines 8–13 (`top`, `git_directory`, `common_directory`, `head`, `branch`); `locate()`, lines 54–86 (`rev-parse --show-toplevel --absolute-git-dir --path-format=absolute --git-common-dir`); `read_head()`, line 95; `comparison_base()`, lines 157–168.
  - Wave 8 did not change `lua/aineo/git/`.
  - `process.lua`: `DEFAULT_LIMIT_MS = 10000`, line 13; the settings and environment every git gets, and the editor's variables no git sees, lines 15–76.
- `lua/aineo/changes/` at `f98bd9d`, as T32 left it (T37 moves `init.lua` before this packet starts): `lines.lua` — `file_line()` line 73, `NO_FILES` line 221, `files_window()` line 254, `commit_line()` line 288, `commits_window()` line 326, and T32's colours on each line (`file_colours()` line 90, `commit_colours()` line 298, `note()` line 160, `failure_line()` line 169); `pages.lua` — `write_page()` line 60, `entry_at()` line 88, the colours' namespace `PANE_COLOURS` line 10; T32's new `colours.lua`, the highlight groups (`KIND_GROUPS` line 8, `define_changes_colours()` line 55); `init.lua` — `read_files` line 132, `read_commits` line 144, `follow_change()` line 158, `diff_name()` lines 365–370, `open_entry()` line 478.
- The modularity table (`.claude/skills/modularity/SKILL.md`): `aineo.git` requires no aineo home; `aineo.changes` requires `aineo.git` alone. A new file inside `lua/aineo/git/` is the home's own and changes no row; a new home would need the orchestrator's `ai/` pass first.

**Not measured** (for you, on 0.12.5, in fixture repositories under `tests/helpers/git_repo.lua`'s isolation): the read time with five worktrees on the fixture you build. What `merge-base` answers with no shared history, or for an unborn worktree, is measured now (above): handle each as a read with no base, or as git's words under the heading, and say what you chose.

### Baseline

At `f98bd9d`, Neovim 0.12.5: 1929 cases in 60 groups, `Fails (0)` — T33's last whole-suite run, on code identical to `f98bd9d`'s (`plan.md` › *Baseline*). Since the first brief (`9b8707f`: `tests/test_changes.lua` 93), T32 brought `tests/test_changes.lua` to 120 cases at its correction; the git suites and `tests/test_layout_diffs.lua` are files wave 8 did not change (`tests/test_git_watch.lua` 33, `tests/test_git_repository.lua` 9, `tests/test_git_changes.lua` 9, `tests/test_git_commits.lua` 5, `tests/test_git_diffs.lua` 17, `tests/test_layout_diffs.lua` 10, by the first baseline). T37 changes the changes suites again; the dispatch message pastes the counts on the `dev` you start from.

Read first: the v1 plan note's D18, D19, D22, C13, C15 and D31–D35; [[Planning/aineo — worktrees and session switches]] › P1–P5 and its outcome; [[Ideas/The changes pane follows the agents' worktrees]]; `knowledge-vault/Projects/aineo.md`; `Sessions/2026-09-27 — T23 git home.md`; `Sessions/2026-10-05 — T25 Changes pane.md`; the session notes of T32 and T37; the Learnings [[Learnings/GIT_OPTIONAL_LOCKS=0 does not keep git diff from taking index.lock]], [[Learnings/A watch on a file git replaces goes silent after the replacement]], [[Learnings/libuv ignores fs_event's recursive flag on Linux]]; `plan.md` and `evidence/w9-probes.txt` in this folder (A1–A3).

## Boundary

- **Branch:** `feature/t38-changes-worktrees` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t38_changes_worktrees` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/git/` (`init.lua` for new exports, a new `worktrees.lua`, `repository.lua` for the upstream); `lua/aineo/changes/` (`init.lua`, `lines.lua`, `pages.lua`, and a new file when a concern needs one); new `tests/test_git_worktrees.lua` and `tests/test_changes_worktrees.lua`; `tests/test_changes.lua`, `tests/test_entry_changes.lua` and `tests/test_layout_diffs.lua` where a pin moves (name each in your report); `tests/helpers/git_repo.lua` to build worktrees in a fixture — **additions only: no existing function of it changes**, since T39's new suite may require it at the same time (a shared helper: run every test file that requires it; brief review, T38-6); `doc/aineo.txt` inside the fences below; your session note.
- **Keep `aineo.changes`' interface as T37 leaves it** (brief review, T38-5): T39, at the same time, calls `begin_session()`, T37's follow entry point, `refresh_shown_pane()` and `pane_buffers()`. Their names, arguments and what they promise stay; what they do inside may change.
- **You must not touch:** `plugin/aineo.lua` (T39's, at the same time) — the changes home finds the worktrees itself through `aineo.git`, and the composition root hands it nothing new; `tests/test_entry_panes.lua` (T39's, at the same time: the editor's own lines stay exactly today's, so it needs nothing from you; T38-1, T39-1); every other file under `lua/`, `plugin/`, `scripts/` and `tests/` — `tests/test_doc.lua` included (run it); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`. Yours: *aineo-changes* from `The files window, \`aineo://changes-files\`, lists every file that differs` to `windows say so until the pane is shown again, which starts it again.`; LIMITS › `The changes pane ~` whole, from `The changes pane ~` to `on the line again shows it, the other buffer giving its name up.` (the amendment quotes them as T32 and T37 leave them); and *aineo-panes*'s changes-pane item, from `- The changes pane: \`aineo://changes-files\` in the Report's place, over` to `out, or kept unnamed when you changed its text.` (lines 105–110 at `f98bd9d`), which says the pane lists "the session's changed files and its commits" and no other worktree's (brief review, T38-8). In LIMITS › `The changes pane ~`, name what P5 (a) does not see: a file written in a worktree outside the top level until its `git add`, commit, a save or a showing; Linux, where neither a nested worktree's writes nor a worktree's coming are seen until then; and the cost per worktree. T39 owns a paragraph of *aineo-claude-session* and one item of LIMITS › `Claude's window name ~` at the same time: before you push, merge with its branch if it exists (`git merge-tree --write-tree <your head> origin/feature/t39-panes-follow-switch`), run `make test_file FILE=tests/test_doc.lua` on the merged tree, and report it.
- **Session note:** `knowledge-vault/Sessions/<date> — T38 Changes worktrees.md`, with a `## Task lines` section. `<date>` is the dispatch message's date, written `YYYY-MM-DD`, which that message gives; the orchestrator checks the name is free before dispatch (W-4).
- **Scratch prefix:** `t38-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5 only; the test files you touch, `tests/test_entry_panes.lua` (it reads the pane's lines; run it, do not edit it), every test file that requires `tests/helpers/git_repo.lua` if you change it, and the baseline table's while you work; the whole suite once before each push; mutants on their covering files. Git only in fixture repositories, never the checkout's.
- **Modularity:** no new home; `aineo.changes` requires `aineo.git` alone; `aineo.git` keeps no state but its watches ("the base is its caller's").

## The tests

Each behaviour gets one test, seen failing first:
- the git home lists a repository's worktrees from any of them, the editor's first, a prunable one left out, a locked and a detached one kept, a path holding a newline whole (a space does not split without `-z`, so only a newline tests the parse; T38-4);
- an entry marked `bare` is left out, and a linked worktree of a bare repository is listed (A8);
- a worktree whose directory does not exist is left out, locked or not (A9);
- the git home gives a worktree's base as D32 says, in each of its three cases;
- the files window shows the editor's own lines first, exactly today's and under no heading, then a section per other worktree under its heading; the commits window likewise (D33, T38-1);
- a worktree with nothing changed shows its own empty line;
- Enter on another worktree's file shows that worktree's diff from its base, under a name that carries the worktree; on its commit, the commit's diff; on a heading, nothing;
- two worktrees' diffs of one path are two buffers;
- a worktree added after the first showing shows once the editor's watch calls back; one removed goes;
- a worktree whose read fails shows git's words under its heading, the others unchanged;
- the reads stay one at a time per window with several worktrees.

The help is not in that list: `tests/test_doc.lua` pins the tags, the 78-column width and the help file's shape (`tests/test_doc.lua:59–208`), and no text, so no paragraph can be seen failing there, and you may not edit that file. **`tests/test_doc.lua` stays green on the merged trees** (W-2).

The verification runs the plan's nine mutants for T38. Name in your report the test that kills each.

## What was decided already

- The user's request, 2026-10-06 (`plan.md` › *Ask*), and the user's answers to P1–P5, D31–D35, which the amendment gives.
- D18: the two windows stay put. D19: the diff is read-only, unified, in the middle column. D33: the editor's own section is today's lines, with no heading.
- The orchestrator's assumptions A8 (a `bare` entry left out) and A9 (a worktree whose directory does not exist left out, locked or not), to be reported to the user; build them as written.

## Budget

Large: a worktree list and a base in the git home, sections and per-worktree diffs in the changes home, about seventeen cases and three help places. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t38-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the test files that ran, the read time you measured with several worktrees, and the whole suite's counts.

## Amendment — 2026-10-07: the user's answers and the facts at `f98bd9d`

**The user's answers.** The orchestrator put P1–P11 to the user as a table, each with its options and its recommendation, and M, R and S for the wave. The user answered, verbatim: "p10 must be one per session, why, because it is used to catalog changes and notes that goes to the prompt with \s, other than that all your recommendations are fine, so when wave 8 finishes start right streight wave 9." So P1–P5 are (a), D31–D35: the options this brief was written with. Its body stands, each behaviour now naming its row. S is (a): this packet and T39 go at once, after stage 1. R is (a): a release is cut when this packet merges, feature A whole.

**The measurements** (`evidence/w9-real-claude-sessions.txt`, the orchestrator's, 2026-10-07) are of Claude Code's sessions and change nothing here.

**Facts that moved since `9b8707f`** (the body gives them at `f98bd9d`): T32 moved `lines.lua` (`file_line()` 67 → 73, `NO_FILES` 149 → 221, `files_window()` 180 → 254, `commit_line()` 211 → 288, `commits_window()` 229 → 326) and `pages.lua` (`write_page()` 36 → 60, `entry_at()` 63 → 88), and added `colours.lua`; every section's lines now carry T32's colours, which the body's *What stays* keeps. `lua/aineo/git/` did not move; the docstring is lines 1–18 and `Repository` lines 8–13 (read one line off before). The help's fences, `The files window, …` … `… which starts it again.` (lines 148–206) and LIMITS › `The changes pane ~` (lines 994–1021), did not move with wave 8; T37 changes both `init.lua` and the LIMITS item before this packet, so the amendment at dispatch gives them again. The baseline is 1929 cases at `f98bd9d`.

## Correction — 2026-10-07, from the brief review

The brief review (`brief-review.md` in this folder, on `ed83367`) found this brief not dispatchable as written: eight findings, T38-1 to T38-8, and two that every brief shares, W-2 and W-4. No packet had been dispatched, so each correction is made in the body above, as the review words it, and listed here; the stage-2 amendment re-checks them against the `dev` this packet starts from. Where the review left a choice, the orchestrator ruled under the user's instruction of 2026-10-06 ("assume your recommendations and report what they were after you finish"); each ruling is named below as **the orchestrator's assumption, to report to the user**, or as a D row's own text. None is the user's answer.

- **T38-1 — D33, not an assumption.** The editor's own section is today's lines, with no heading; only other worktrees get one. This packet does not touch `tests/test_entry_panes.lua`, which T39 holds, and runs it: *The windows*; *Boundary*; the windows' test; mutant 9.
- **T38-2 — A8, the orchestrator's assumption, to report to the user.** A worktree entry marked `bare` is left out: *Which worktrees*; *Facts* (A1); a test; mutant 7.
- **T38-3 — A9, the orchestrator's assumption, to report to the user.** A worktree, locked or not, whose directory does not exist is left out, as a prunable one is: *Which worktrees*; a test; mutant 8.
- **T38-4:** without `-z` only a newline splits a path's line; the list's test and mutant 5 use a path holding a newline, and A1 is reworded here and in `plan.md`.
- **T38-5:** *Boundary* keeps `aineo.changes`' interface as T37 leaves it.
- **T38-6:** `tests/helpers/git_repo.lua` takes additions only.
- **T38-7:** git's answers with no shared history, for an unborn worktree and with no upstream, and the editor's worktree matched by `find_repository().top`: *Facts*; *Which worktrees*; *Not measured*.
- **T38-8:** *aineo-panes*'s changes-pane item joins this packet's help places: *Boundary*.
- **W-2:** the help is out of the red-first list; `tests/test_doc.lua` stays green on the merged trees.
- **W-4:** the session note's `<date>` is the dispatch message's: *Boundary*.

**Mutants** (`plan.md` › *Verification mutants*, T38): 5 reworded to a newline; 7 (A8), 8 (A9) and 9 (a heading above the editor's own section, T38-1) added.

## Amendment — 2026-10-08, at dispatch

**Base: `dev` `dc5ff70`.** Stage 1 has merged: T35 (PR #137), T36 (PR #135) and T37 (PR #136), each through two fix rounds and two re-measures. Every path, symbol, line range and help fence this brief cites was read again at `dc5ff70` with `git grep -n` (by the agent that wrote this amendment, for the orchestrator). The body and the earlier sections stand except where this section says a fact moved. Start your branch from the `origin/dev` the dispatch message names, and re-check against it if it is not `dc5ff70`.

### Facts that held at `dc5ff70`

- **`lua/aineo/git/` did not change** (`git diff --stat f98bd9d dc5ff70 -- lua/aineo/git` prints nothing). Every line the body gives stands: `init.lua`'s docstring 1–18, `find_repository()` 40, `changed_files()` 53, `commits_since()` 65, `file_diff()` 79, `commit_diff()` 91, `watch_repository()` 114; `repository.lua`'s `aineo.git.Repository` 8–13, `locate()` 54–86, `read_head()` 95, `comparison_base()` 157–168; `process.lua`'s `DEFAULT_LIMIT_MS` 13 and lines 15–76.
- **`lines.lua`, `pages.lua` and `colours.lua` did not change.** `file_line()` 73, `file_colours()` 90, `note()` 160, `failure_line()` 169, `NO_FILES` 221, `files_window()` 254, `commit_line()` 288, `commit_colours()` 298, `commits_window()` 326; `PANE_COLOURS` 10, `write_page()` 60, `entry_at()` 88; `KIND_GROUPS` 8, `define_changes_colours()` 55.
- **The modularity table** (`.claude/skills/modularity/SKILL.md`, lines 39–40): `aineo.git` requires no aineo home, and `aineo.changes` requires `aineo.git` alone. T37's new `kept.lua` is inside the changes home and requires no other home. No test or lint list enumerates the files of either home, so a new `lua/aineo/git/worktrees.lua` moves no list.
- **`tests/test_entry_panes.lua` did not change.** It still pins `{ 'No files changed on this session' }` and `{ 'No commits on this session' }` (`NO_FILES` and `NO_COMMITS` at 178–179, the case at 183–194, `LISTINGS` at 199–202). It is T39's. Do not edit it: run it.
- **`tests/test_doc.lua` did not change.** It still pins the tags, the 78-column width and the help file's shape (59–208), and no text.
- `tests/helpers/git_repo.lua`, `tests/test_entry_changes.lua` and `tests/test_layout_diffs.lua` did not change.

### Facts that moved

- **`lua/aineo/changes/init.lua`, as T37 left it** (`git grep -n` at `dc5ff70`):
  - `read_files` 132 → **193** and `read_commits` 144 → **201**. They are no longer bare `serial.one_at_a_time()` reads. Each is `list_read(read, take, show)` (173–190): it reads nothing while the session looks for its base, and drops an answer for a base that is no longer current (`is_current_base()`, 157–159). T37's note offers it to this packet: "`list_read()` drops answers for another base, which T38's sections may reuse per worktree."
  - `follow_change()` 158 → **213**; `diff_name()` 365–370 → **683–688**, its body unchanged; `open_entry()` 478 → **796**.
  - `M.begin_session()` 328 → **606**; `M.refresh_shown_pane()` 541 → **859**; `M.pane_buffers()` 558 → **876**.
  - New, T37's: `M.follow_changes_session(followed)` **656**, its argument `aineo.changes.FollowedSession` **510–512** (`id`, `state_directory`), `find` 476, `keep()` 346, `take_head()` 520, and `held_bases` 61.
- **`lua/aineo/changes/kept.lua`, new (T37).** It keeps one owner-only JSON file per Claude Code session under `<state>/aineo/changes-sessions/`, named by the id's SHA-256 (`kept_base_file()` 22). The file holds the top level, the base and the saved paths. D41 keeps the editor's own worktree's base there, and "the other worktrees' bases are D32's, read and never kept". Nothing of another worktree goes into `kept.lua`.
- **T37 reads `HEAD` with a second `git.find_repository()`** (`take_head()`, 520–541), because the git home offers no other read of it. If this packet adds a read of `HEAD` to the git home, T37's behaviour stays as it is. `tests/test_changes_sessions.lua` counts the finds (`wait_for_finds`), and `tests/test_entry_changes.lua` counts them too (`finds_answered`, `finds_asked`).
- **The interface to keep** (T38-5, now with its names). T39 calls the first two of these at every start and at every switch, at the same time as this packet; T40, after T39, calls `follow_changes_session()` for a claim (`plan.md` › *Packet T40*, rule 5):
  - `begin_session(settings)` (606), whose `aineo.changes.SessionSettings` (18–22) is `directory`, `show_diff` and `git?`;
  - `follow_changes_session({ id, state_directory })` (656);
  - `refresh_shown_pane()` (859);
  - `pane_buffers()` (876).

  Their names, their arguments and what they promise stay. What they do inside may change.
- **A suite this packet now runs and may change: `tests/test_changes_sessions.lua`** (T37's, 61 cases). It drives the home this packet rewrites. *You may touch* gains it where a pin moves; name each change in your report. T39's boundary forbids `tests/test_changes*.lua`, so the two packets stay disjoint.
- **`tests/helpers/git_repo.lua` is now required by 13 files.** They are `tests/test_changes.lua`, `tests/test_changes_sessions.lua`, `tests/test_entry_changes.lua`, `tests/test_entry_panes.lua`, `tests/test_entry_send_selection.lua`, and the eight git suites: `tests/test_git_changes.lua`, `test_git_commits.lua`, `test_git_configuration.lua`, `test_git_diffs.lua`, `test_git_lock.lua`, `test_git_process.lua`, `test_git_repository.lua` and `test_git_watch.lua`. If you add to the helper, run every one of them. Additions only, as before (T38-6).
- **The help, `doc/aineo.txt`, as T37 and T35 left it.** Each fence is quoted by its first and last line, as they stand at `dc5ff70`:
  - *aineo-panes*'s changes-pane item is now lines **106–111** (was 105–110). It runs from `- The changes pane: \`aineo://changes-files\` in the Report's place, over` to `  out, or kept unnamed when you changed its text.`
  - *aineo-changes* is now **widened to the section's first paragraph**, lines **141–211** (the files-window part was 148–206). It runs from `The changes pane lists what changed in your repository since the base of` to `windows say so until the pane is shown again, which starts it again.`
    - **Why it is widened.** T37 has merged, and its first paragraph (141–151) says the pane "lists what changed in your repository since the base of the Claude Code session it shows" — no longer the whole of it once other worktrees show. No open packet edits that paragraph: T39's places are in *aineo-claude-session* and LIMITS, and T40's places (`plan.md` › *Packet T40*, rule 2) are not in *aineo-changes*.
    - **One sentence there is already stale.** "The `*` marks a file you saved from this editor since the base was taken" (162–163). Since T37's fix round, two editors on one session keep each other's marks (its attack finding 5, `keep()` merging the saves), so a `*` can mark a save made in another editor. T37's note left this for later. Correct it here.
  - LIMITS › `The changes pane ~` is now lines **1128–1174** (was 994–1021), whole. It runs from `The changes pane ~` to `  on the line again shows it, the other buffer giving its name up.` T37's item `- A restart of Claude Code in another working directory keeps the first` (1141–1153) and its new item `- Two editors following one session in one repository keep the first` (1154–1161) are inside it. Keep what they say true.

### The rulings that bind this packet

Each comes from the plan or from a stage-1 session note. Each ruling is the orchestrator's, to report to the user; none is a D row.

- **No wave-9 release before T39 merges** (`plan.md` A22; T36's and T37's fix rounds). R (a) cut a release when this packet merges. If it merges first, that release waits for T39's, and the two may be one. Help that describes T39's wiring may stand on `dev` meanwhile.
- **`tests/test_entry_panes.lua` is T39's** (T39-1). This packet does not touch it. Under D33 the editor's own lines stay exactly today's, so the file needs nothing from this packet.
- **D33: the editor's own section has no heading** (T38-1). Only other worktrees get a heading line. Mutant 9 checks it.
- **A8: an entry marked `bare` is left out**, and a linked worktree of a bare repository is shown. Mutant 7.
- **A9: a worktree whose directory does not exist is left out, locked or not.** Mutant 8.
- **T39's checks of the changes pane pin only the session it follows** (T39-5): the editor's own entries, by content, in repositories with no other worktree. The lines of other worktrees are this packet's alone.
- **Other worktrees' bases are never kept** (D41's last sentence). The editor's own base and marks stay T37's, per session.

### Counts on `dc5ff70`

Measured with `make test_file`, Neovim 0.12.5, each file alone. Every file printed `Fails (0) and Notes (0)` and exited 0.

| Test file | Cases |
|---|---|
| `tests/test_git_watch.lua` | 33 |
| `tests/test_git_repository.lua` | 9 |
| `tests/test_git_changes.lua` | 9 |
| `tests/test_git_commits.lua` | 5 |
| `tests/test_git_diffs.lua` | 17 |
| `tests/test_git_configuration.lua` | 9 |
| `tests/test_git_lock.lua` | 8 |
| `tests/test_git_process.lua` | 11 |
| `tests/test_changes.lua` | 120 |
| `tests/test_changes_sessions.lua` | 61 |
| `tests/test_entry_changes.lua` | 12 |
| `tests/test_layout_diffs.lua` | 10 |
| `tests/test_entry_panes.lua` (run, not edited) | 86 |
| `tests/test_entry_send_selection.lua` (requires `git_repo.lua`) | 9 |
| `tests/test_doc.lua` | 44 |

The whole suite on `dev` is **2229 cases** (the orchestrator's count). This amendment ran no whole suite.

### Rule 2 against T39, recomputed on `dc5ff70`

- **Code.** This packet's code is `lua/aineo/git/` and `lua/aineo/changes/`. T39's is `plugin/aineo.lua` alone: its boundary forbids every file under `lua/`. They are disjoint.
- **Tests.** This packet's tests are the git suites, `tests/test_changes.lua`, `tests/test_changes_sessions.lua`, the new `tests/test_git_worktrees.lua` and `tests/test_changes_worktrees.lua`, `tests/test_entry_changes.lua`, `tests/test_layout_diffs.lua`, and additions to `tests/helpers/git_repo.lua`. T39's are the new `tests/test_entry_session_switch.lua`, `tests/test_entry_claude_resume.lua`, `tests/test_entry_report.lua`, `tests/test_entry_draft.lua` and `tests/test_entry_panes.lua`. They are disjoint.
  - `git_repo.lua` is shared by additions only (T38-6).
  - `aineo.changes`' interface is shared, and kept as it is (above).
- **No registration file** is shared. Neither packet adds a module home. mini.test collects `tests/**/test_*.lua` by glob, and no list names a home's files.
- **`doc/aineo.txt`, under the section exception.**
  - This packet's places are 106–111, 141–211 and 1128–1174.
  - T39's are *aineo-claude-session*'s paragraph on switches, from `aineo follows a switch you make inside Claude Code: \`/clear\`, \`/resume\`` to `terminal in the same directory.` (327–338), and the first sentence of LIMITS › `Claude's window name ~`'s last item, from `- Not measured, and so not known to show: a title Claude Code generates` to `` `--resume`, and the glyph while Claude Code is busy. `` (1186–1188, the sentence ending mid-line).
  - Unchanged lines separate the nearest pair. Lines 212–326 hold *Colours*, *The file column* and the start of *aineo-claude-session*. Lines 1175–1185 hold the blank line, `Claude's window name ~` and its first three items.
  - **Measured.** `git merge-file` ran on worst-case edits of `dc5ff70`'s help: every fenced line of each packet rewritten, and a line added after each fence. Each fence's first and last line was checked against the quotes above before editing. Result: 0 conflicts, with all 127 of this packet's lines and all 17 of T39's in the merged file.
- **So T38 and T39 can still run at once** (S (a)). Before you push, merge with T39's branch if it exists, as the body says: `git merge-tree --write-tree <your head> origin/feature/t39-panes-follow-switch`. On the merged tree, run `make test_file FILE=tests/test_doc.lua`, and also T39's `tests/test_entry_session_switch.lua`, since that suite drives this home through the composition root. Report all three.
- **T40.** T40 waits for T39's merge (its plan's rule 1) and may then run beside this packet. Its plan found the two disjoint: it calls `follow_changes_session()`, whose interface this packet keeps, and none of its files or help places is this packet's. If T40 has a branch when you push, merge with it too, and run `tests/test_doc.lua` on that tree. Both packets add help tags, and `:helptags` refuses one defined twice (E154).
