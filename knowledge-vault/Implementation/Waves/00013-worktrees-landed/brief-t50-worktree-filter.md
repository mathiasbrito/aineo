**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> Written for the user's U3 (a) and the recommendations O3–O7 of `plan.md`. If the user answered U3 otherwise, or the orchestrator ruled otherwise, a dated amendment at the end of this brief says so, and it wins over the body. Dispatched only once T49 (the commits filter following a scroll) has merged.

## Objective

The task, verbatim from the task list:

> | T50 | The files window as one list, and another worktree's lines in the filter (C15; D55, D57, D47, D33, D34): under a commit the files window lists that commit's files and nothing else; the cursor on another worktree's commit in the commits window filters the files window to that commit's files, read in that worktree, and Enter on one of them shows its change in that commit; the selection names the worktree with the commit; the files window shows its first line at a change of filter; what it shows under *Uncommitted* and *Session work*, and what a worktree's heading selects, as the user answers U3 | T43, T49 | planned — wave 13 |

It rests on: **D55** and **D57** (the user's words, quoted in the rows and in `plan.md` › *The user's words*; why the filter did not feel like one, `plan.md` › *Why the filter did not feel like one*); D47 and wave 10's A94–A100 (T43's filter, its pause, its words, its diffs); D32 (a worktree's base, read again at every read); D33–D35 (the worktrees' sections, Enter, the reads); D46 (Enter's focus move); D48 (`F`); C13 and C15 (`aineo.changes` requires `aineo.git` alone); D26, D29.

### The behaviour — one test each, seen failing first

**The commits window** (its lines do not change)
1. Another worktree's heading line lists an entry whose filter is that worktree's whole change since its base. Each of its commits lists an entry whose filter is that commit, in that worktree. Every entry's key stays unique: no key of another worktree's, of the editor's own lines, of a file path or of a commit id equals it, and a filter's key is the key of the entry that lists it (`pages.line_of()` finds the selected line by it).
2. The cursor on such a line selects its filter after the pause, as on the editor's own lines (A96). A line that lists no filter — a worktree's empty line, a failure line, the line saying the worktrees could not be listed — keeps the last filter.
3. The same commit listed in two worktrees is two filters: moving from one to the other reads the files window again.

**The files window — one list (D57; U3 (a))**
4. It lists the selected filter's files alone: its first line, then that filter's rows; **no other worktree's heading or files**, under any filter — under a commit by D57, under *Uncommitted* and *Session work* by U3 (a).
4b. At a change of filter, once the new filter's list is written, each window showing the files buffer has its cursor on the first line and its view at the top; a read again of the same filter keeps the cursor on its entry, as today (O5 (a), cause 3).
5. Its first line under a worktree's whole change reads `Files in: ` and the worktree's heading as the commits window shows it (`lines.worktree_heading()`); under one of its commits, `Files in: <id7> <subject> (worktree <folder>)`, `<folder>` quoted as the heading quotes it (O3 (a)).
6. Under a worktree's whole change: its files since its base, as today's section lists them, unmarked, or `No files changed in this worktree`. The base is read as D32 reads it, again at each read, in that worktree.
7. Under one of its commits: the files that commit changed against its first parent, read in that worktree (`git.commit_files()` given the worktree's repository), unmarked, or `No files in this commit`.
8. A read that fails keeps today's rule (T43): the files shown stay when they are the filter's; for another filter, the window lists that filter with no files under the failure's line.
9. The files window is read again as today: under a worktree's whole change, at every read of the pane — a showing, a save, every call of the watch (D35); under a commit, a read again is allowed, not required.
10. When the commits window's read no longer lists the selected filter's worktree, *Session work* is selected again, the cursor with it (as A97 does for a commit gone). When it lists the worktree but no longer the selected commit — the agent amended or rebased it — that worktree's whole change is selected, the cursor moved to its heading (O4 (a)).
11. The files window no longer reads the other worktrees' file lists for sections it no longer shows; the commits window reads every worktree as today. One read of each window at a time stays (D35, `window_read()`).

**Enter**
12. On a file under a worktree's whole change: today's diff from its base, in `aineo://worktree{top}//diff/{path}` (D34).
13. On a file under one of its commits: the commit's header, then that file's change, as `git.commit_file_diff()` gives it, read in that worktree, in `aineo://worktree{top}//commit/{id}/{path}`, `{id}` the full id (O6 (a), O7 (a)).
14. In the commits window, on a worktree's heading: the whole diff of that worktree from its base to its working tree, its untracked files included (`git.diff_since()` given the worktree's repository and base), in `aineo://worktree{top}//since-base` (O6 (a)). It replaces D34's "Enter on a heading does nothing". On a worktree's commit, as today.
15. `F` (D48) works in every new diff, as in the others; Enter's focus move (D46) and its last-Enter rule stay.
16. `gf` stays as today in this packet (D34, T45): T53 makes it open a commit's file from that commit (D57).

The help is not in that list: `tests/test_doc.lua` pins tags, width and shape, no text. It stays green.

### Facts, checked against `origin/dev` `1dc3186`

Line numbers are `1dc3186`'s; T49 changes `lua/aineo/changes/init.lua`'s autocmds before you start, so read them again on the `dev` you branch from.

- `lua/aineo/changes/filter.lua`: `aineo.changes.Filter` (7) has `kind` and `commit?`; `key()` (34) keys a commit on its id alone and a fixed line on `'\0' .. kind`; `same()` (47).
- `lua/aineo/changes/lines.lua`: `aineo.changes.Entry` (104) has `key`, `change?`, `commit?`, `filter?`, `worktree?`; `in_worktree()` (311) builds another worktree's entries with key `top .. '\0' .. key` and **no `filter`**; `worktree_heading()` (297) is a note row with no entry; `files_window()` (475) appends every worktree's section after the editor's rows; `filter_name()` (403), `files_in_row()` (426), `NO_WORKTREE_FILES` (264), `NO_COMMIT_FILES` (248).
- `lua/aineo/changes/pages.lua`: `write_page()` keeps each window's cursor on the entry it was on, by key, else on its line number — which keeps a files window scrolled into a section the new filter no longer lists (cause 3).
- `lua/aineo/changes/init.lua`: `files_page()` 96 passes `worktrees = session.files_others`; `window_read()` 253 reads the editor's own list, then the other worktrees' (`aineo.changes.worktrees`); `read_selected_files()` 304 reads `session.repository` alone; `read_files` 324; `select_session_work()` 342; `read_commits` 362 resets a commit gone (`lists_commit()`, 352); `follow_change()` 391 reads the files window at every watch call; `select_filter_at_cursor()` 1261 takes the entry's `filter`; `pane_buffers()` 1334.
- `lua/aineo/changes/worktrees.lua`: `read_other_worktrees()` lists the worktrees, reads the comparison once (`git.comparison_commit()`), then each worktree's repository, base (`git.worktree_base()`) and list; `aineo.changes.WorktreeSection` carries `top`, `branch`, `repository`, `base`.
- `lua/aineo/changes/entry_diff.lua`: `read()` (64) reads another worktree's entry by `entry.commit` or `entry.change` alone, from `entry.worktree`; `name()` (134) gives `aineo://worktree{top}//diff/{path}` and `aineo://worktree{top}//commit/{id}`; `told_name()` (152).
- `lua/aineo/git/init.lua` already gives every read this packet needs, each taking a repository: `changed_files()`, `commit_files()`, `file_diff()`, `commit_file_diff()`, `diff_since()`, `commit_diff()`. P6 (`evidence/w13-probes.txt`): the editor's repository can read a worktree's commit too, but the brief asks for the worktree's own repository, as D34's reads use.
- **Tests that pin the files window's worktree sections and will move** (`git grep -c` at `1dc3186` for the worktree lines): `tests/test_changes_worktrees.lua` (46), `tests/test_changes_open_file.lua` (3), `tests/test_changes_full_context.lua` (1). Change a pin only where D55, D57 and U3 change the line it pins, and name each changed test file in your report.

### Baseline

2708 cases at wave 11's close (`plan.md` › *Baseline*). The dispatch message pastes the counts of the files you run.

Read first: the v1 plan note's D32–D35, D47, **D55**, **D57**, C15; `plan.md` in this folder; `knowledge-vault/Implementation/Waves/00010-changes-filter/brief-t43-changes-filter.md` and that plan's *Landed*; T49's session note; `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t50-worktree-filter` from `origin/dev`.
- **Class:** regular.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t50_worktree_filter` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/changes/` (`init.lua`, `lines.lua`, `filter.lua`, `entry_diff.lua`, `worktrees.lua`, `pages.lua`; a new file when a concern needs one); `tests/test_changes_filter.lua`, `tests/test_changes_worktrees.lua`, and the changes and entry suites where a pin moves; `tests/helpers/git_repo.lua`, **additions only**, running every test file that requires it if you add to it; `doc/aineo.txt` — *aineo-changes* from `The first line of the files window, \`aineo://changes-files\`, names what it` to `windows say so until the pane is shown again, which starts it again.`, its *Colours* paragraph, and LIMITS › `The changes pane ~` (the item "Choosing another line in the commits window reads the files window again, the other worktrees' sections with it" becomes false); your session note. Correct in the same commit what the change makes false there, and say in your report what you corrected.
- **You must not touch:** `lua/aineo/git/` (T51 runs beside you there); `plugin/aineo.lua`; every other file under `lua/`, `plugin/`, `scripts/` and `tests/`, `tests/test_doc.lua` included (run it); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Keep `aineo.changes`' interface:** `begin_session()`, `follow_changes_session()`, `hand_over_changes_session()`, `refresh_shown_pane()`, `pane_buffers()` keep their names, arguments and promises. T52 builds *Landed* on the filter you leave: a filter that names the repository it is read in.
- **Session note:** `knowledge-vault/Sessions/<date> — T50 Worktree filter.md`, `<date>` the dispatch message's, with a `## Task lines` section.
- **Scratch prefix:** `t50-`.
- **How the suite runs (D26, D29):** the newest Neovim release. While you work, the test files you touch, plus `tests/test_entry_panes.lua` and `tests/test_doc.lua`; the whole suite (`make test`) once before each push; mutants on their covering files. git only in fixture repositories (`tests/helpers/git_repo.lua`), never the checkout's.

## What was decided already

- D55 and D57 as the user gave them. Do not re-open that another worktree's commit filters the files window, that a commit's files show alone, nor D47's pause, words and marks.
- U3 as the user answered it (this body: (a)), and the orchestrator's rulings on O3–O7 (`plan.md`).
- D32's base, D35's reads, D46's focus move, D48's `F`, T45's `gf` stay.

## Budget

Large: the filter generalised to another worktree, the files window as one list, its view at a change of filter, the files read in the filter's worktree, the reset rules, two new diff names and the help — about twenty new cases, and pins moved in `tests/test_changes_worktrees.lua`. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t50-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, each test file whose pins moved and why, and the whole suite's counts. The orchestrator's verification runs `plan.md`'s five T50 mutants: name the test that kills each.

## The orchestrator's rulings — 2026-10-12, before dispatch

- **The user's answer** (`plan.md` › *The user's answers — 2026-10-12*, verbatim there): U3 (a), "No, one list always (Recommended)". It is the user's decision, recorded on D55 and D57; this body was written for it and stands unchanged.
- **The orchestrator's rulings**, each the (a) this body is written for: A136 (O1), A137 (O2), A138 (O3), A139 (O4), A140 (O5), A141 (O6), A142 (O7); and the plan's assumptions as A154–A157. These are the orchestrator's assumptions under the user's instruction of 2026-10-06, to record in the session note and the PR body as such, never as the user's decisions. A154 (D32's worktree bases unchanged) stays an open thread for the user.
- No answer holds this packet: it is dispatched once T49 has merged.
