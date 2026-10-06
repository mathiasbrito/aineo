**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> **Awaits the converge round.** Written with the recommended options of [[Planning/aineo — worktrees and session switches]] › P1 (a), P2 (a), P3 (a), P4 (a) and P5 (a). It is not dispatched until the user has answered the round and the agreed rows are D31–D35 in the v1 plan note, and T37 has merged (stage 2: both change `lua/aineo/changes/` and *aineo-changes*). Every fact below was read at `9b8707f`; wave 8's T32 and this wave's T37 change `lua/aineo/changes/`, so the amendment before dispatch gives the line numbers and the help's fences again.

## Objective

The task, verbatim from the task list:

> | T38 | The changes pane follows the repository's worktrees (C15, C13; P1–P5 once agreed): beside the editor's own checkout, each of the repository's worktrees with its files and commits since its base, Enter showing their diffs; worktrees appearing and going followed — the behaviour awaits the converge round | T23, T37 | planned — wave 9 |

It rests on: D18 (the right column's two windows stay put), D19 (the changes pane: its lists, Enter, the read-only diff, the refresh) and D22 (every commit), which D31–D35 extend from one checkout to the repository's worktrees once agreed; C13 (the git home: every git call asynchronous and time-bounded) and C15 (the changes home); T23's watch and T25's one-read-at-a-time rule; D26 and D29. The idea it graduates: [[Ideas/The changes pane follows the agents' worktrees]].

### The behaviour, under the recommended options (awaits the converge round)

- **Which worktrees (P1 (a)).** Every worktree `git worktree list --porcelain -z` lists for the session's repository. The editor's own — the one `begin_session()`'s directory is in — first, as today, under its own heading; then the others in git's order. One marked `prunable` is left out. A locked one is shown.
- **Each other worktree's base (P2 (a)).** Its merge base with the upstream of the branch the editor's worktree is on; when that branch has no upstream, with that branch; when the editor's worktree is detached, with its `HEAD`. Read again at every read: nothing is kept. The editor's own keeps the session's base (D19, and T37's per session).
- **The windows (P3 (a)).** In each window, a heading line per worktree — its folder's name and its branch, or `detached` — and under it that worktree's files (top window) or commits (bottom window), in today's line format, or that worktree's "nothing changed" / "no commits" line. The editor's own section keeps today's lines, so a user with no other worktree sees a heading above today's list and nothing else changes. (Whether the editor's own section has a heading when it is the only worktree is the implementer's to propose in the report, one test each way not required.)
- **Enter (P4 (a)).** On a file of another worktree, that worktree's unified diff of the file from that worktree's base, read-only in the middle column, as today; on its commit, that commit's diff; on a heading line, nothing. A diff's buffer name carries the worktree, so two worktrees' diffs of one path never share a name; the editor's own diffs keep today's names (`aineo://diff/<path>`, `aineo://commit/<id>`). No key opens another worktree's file.
- **Following them (P5 (a)).** No watch per worktree. The worktree list and every worktree's lists are read again whenever the editor's own watch calls back and whenever the pane is shown (T25's triggers), one read at a time per window, a trigger during a read reading once more after it. A worktree added shows at the next read; one removed goes at the next read, with its diffs left as they are; a read of a worktree removed meanwhile is dropped, not shown as a failure.
- **Failures.** A worktree whose lists cannot be read shows git's words under its heading, as T25 shows a failed read today, and the other sections stay. A list of worktrees that cannot be read keeps the editor's own section working as today, under one line in git's words.
- **What stays:** D18's two windows, the cursor kept on its entry while it is listed (T25), T32's colours for every section's lines, the one-at-a-time reads, the watch's start at the first showing.

### Facts, checked against `origin/dev` `9b8707f` (re-checked after T32 and T37 merge)

- **A1** (`evidence/w9-probes.txt`): the porcelain list's fields (`worktree`, `HEAD`, `branch refs/heads/…` or `detached`, `locked [reason]`, `prunable <why>`), one blank line between worktrees, the main worktree first, the same from any worktree; with `-z`, each field ends in a NUL and each worktree in an empty field; a path with a space or `é` reads whole. 20–32 ms.
- **A1b:** Claude Code's agents' worktrees sit under `<top>/.claude/worktrees/`, are locked, and may be detached.
- **A2:** the merge base with `origin/dev` lists an agent's own commits and files only; with `dev` it adds upstream commits the user has not pulled. `git merge-base` 19–56 ms; `git rev-parse --abbrev-ref <branch>@{upstream}` 18–26 ms and answers `origin/dev`.
- **A3:** the editor's own watch already calls back on `git worktree add`, `remove` and `prune`, on any worktree's commit, and on a file written in a worktree nested in the top level — not on one written in a worktree outside it. A linked worktree's repository, as `find_repository()` gives it, has the main one's `common_directory` and `git_directory` `<main>/.git/worktrees/<name>`.
- `lua/aineo/git/`:
  - `init.lua`: `find_repository()` (line 40), `changed_files(found, base, done, options)` (53), `commits_since()` (65), `file_diff()` (79), `commit_diff()` (91), `watch_repository()` (114). Its docstring, lines 1–17, binds: asynchronous, bounded, never raising, `done` called once on the main loop, answers independent of the user's git settings.
  - `repository.lua`: `aineo.git.Repository`, lines 7–13; `locate()`, lines 54–86 (`rev-parse --show-toplevel --absolute-git-dir --path-format=absolute --git-common-dir`); `read_head()`, line 95; `comparison_base()`, line 157.
  - `process.lua`: `DEFAULT_LIMIT_MS = 10000`, line 13; the settings and environment every git gets, and the editor's variables no git sees, lines 15–76.
- `lua/aineo/changes/` (at `9b8707f`; T32 and T37 move them): `lines.lua` — `file_line()` line 67, `files_window()` line 180, `NO_FILES` line 149, `commit_line()` line 211, `commits_window()` line 229; `pages.lua` — `write_page()` line 36, `entry_at()` line 63; `init.lua` — `read_files` line 132, `read_commits` line 144, `follow_change()` line 158, `diff_name()` lines 365–370, `open_entry()` line 478.
- The modularity table (`.claude/skills/modularity/SKILL.md`): `aineo.git` requires no aineo home; `aineo.changes` requires `aineo.git` alone. A new file inside `lua/aineo/git/` is the home's own and changes no row; a new home would need the orchestrator's `ai/` pass first.

**Not measured** (for you, on 0.12.5, in fixture repositories under `tests/helpers/git_repo.lua`'s isolation): the read time with five worktrees on the fixture you build; what `merge-base` answers when a worktree's `HEAD` shares no history with the base (an orphan branch) — handle it as a read with no base, and say what you chose.

### Baseline

On `9b8707f`, Neovim 0.12.5: 1807 cases, `Fails (0)` (`Implementation/Waves/00008-small-fixes/evidence/baseline-9b8707f.txt`). Among them: `tests/test_changes.lua` 93, `tests/test_entry_changes.lua` 12, `tests/test_git_watch.lua` 33, `tests/test_git_repository.lua` 9, `tests/test_git_changes.lua` 9, `tests/test_git_commits.lua` 5, `tests/test_git_diffs.lua` 17, `tests/test_layout_diffs.lua` 10, `tests/test_doc.lua` 44. T32 and T37 change the changes suites; the dispatch message pastes the counts on the `dev` you start from.

Read first: the v1 plan note's D18, D19, D22, C13, C15 and the D rows the round adds (D31–D35); [[Planning/aineo — worktrees and session switches]] › P1–P5; [[Ideas/The changes pane follows the agents' worktrees]]; `knowledge-vault/Projects/aineo.md`; `Sessions/2026-09-27 — T23 git home.md`; `Sessions/2026-10-05 — T25 Changes pane.md`; the session notes of T32 and T37; the Learnings [[Learnings/GIT_OPTIONAL_LOCKS=0 does not keep git diff from taking index.lock]], [[Learnings/A watch on a file git replaces goes silent after the replacement]], [[Learnings/libuv ignores fs_event's recursive flag on Linux]]; `plan.md` and `evidence/w9-probes.txt` in this folder (A1–A3).

## Boundary

- **Branch:** `feature/t38-changes-worktrees` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t38_changes_worktrees` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/git/` (`init.lua` for new exports, a new `worktrees.lua`, `repository.lua` for the upstream); `lua/aineo/changes/` (`init.lua`, `lines.lua`, `pages.lua`, and a new file when a concern needs one); new `tests/test_git_worktrees.lua` and `tests/test_changes_worktrees.lua`; `tests/test_changes.lua`, `tests/test_entry_changes.lua` and `tests/test_layout_diffs.lua` where a pin moves (name each in your report); `tests/helpers/git_repo.lua` to build worktrees in a fixture (a shared helper: run every test file that requires it); `doc/aineo.txt` inside the fences below; your session note.
- **You must not touch:** `plugin/aineo.lua` (T39's, at the same time) — the changes home finds the worktrees itself through `aineo.git`, and the composition root hands it nothing new; every other file under `lua/`, `plugin/`, `scripts/` and `tests/` — `tests/test_doc.lua` included (run it); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`. Yours: *aineo-changes* from `The files window, \`aineo://changes-files\`, lists every file that differs` to `windows say so until the pane is shown again, which starts it again.`, and LIMITS › `The changes pane ~` whole, from `The changes pane ~` to `on the line again shows it, the other buffer giving its name up.` (the amendment quotes them as T32 and T37 leave them). Name there what P5 (a) does not see: a file written in a worktree outside the top level until its `git add`, commit, a save or a showing; Linux, where neither a nested worktree's writes nor a worktree's coming are seen until then; and the cost per worktree. T39 owns a paragraph of *aineo-claude-session* at the same time: before you push, merge with its branch if it exists (`git merge-tree --write-tree <your head> origin/feature/t39-panes-follow-switch`), run `make test_file FILE=tests/test_doc.lua` on the merged tree, and report it.
- **Session note:** `knowledge-vault/Sessions/<date> — T38 Changes worktrees.md`, with a `## Task lines` section.
- **Scratch prefix:** `t38-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5 only; the test files you touch, every test file that requires `tests/helpers/git_repo.lua` if you change it, and the baseline table's while you work; the whole suite once before each push; mutants on their covering files. Git only in fixture repositories, never the checkout's.
- **Modularity:** no new home; `aineo.changes` requires `aineo.git` alone; `aineo.git` keeps no state but its watches ("the base is its caller's").

## The tests

Each behaviour gets one test, seen failing first:
- the git home lists a repository's worktrees from any of them, the editor's first, a prunable one left out, a locked and a detached one kept, a path with a space whole;
- the git home gives a worktree's base as P2 (a) says, in each of its three cases;
- the files window shows a section per worktree under its heading, the editor's first with today's lines; the commits window likewise;
- a worktree with nothing changed shows its own empty line;
- Enter on another worktree's file shows that worktree's diff from its base, under a name that carries the worktree; on its commit, the commit's diff; on a heading, nothing;
- two worktrees' diffs of one path are two buffers;
- a worktree added after the first showing shows once the editor's watch calls back; one removed goes;
- a worktree whose read fails shows git's words under its heading, the others unchanged;
- the reads stay one at a time per window with several worktrees;
- the help through `tests/test_doc.lua`.

The verification runs the plan's six mutants for T38. Name in your report the test that kills each.

## What was decided already

- The user's request, 2026-10-06 (`plan.md` › *Ask*), and the user's answers to P1–P5, which the amendment gives.
- D18: the two windows stay put. D19: the diff is read-only, unified, in the middle column.

## Budget

Large: a worktree list and a base in the git home, sections and per-worktree diffs in the changes home, about fourteen cases and a help section. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t38-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the test files that ran, the read time you measured with several worktrees, and the whole suite's counts.
