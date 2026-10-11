**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> Written for the recommendations O2–O8 of `plan.md` › *Decisions for the orchestrator*. If the orchestrator ruled otherwise, a dated amendment at the end of this brief says so, and it wins over the body.

## Objective

The task, verbatim from the task list:

> | T43 | The commits window as a filter (C15, C13; D47): the commits window starts with *Uncommitted* and *Session work*, then the session's commits; the line under the cursor there decides, after a short pause, what the files window lists for the editor's own worktree, and the files window names it on its first line; Enter on a file shows its diff within that filter, and Enter on *Uncommitted* or *Session work* their whole diff; `*` marks under *Uncommitted* and *Session work* only; the other worktrees' sections unchanged | T38, T42 | planned — wave 10 |

It rests on: **D47** (the user's request and answers, quoted verbatim in the row and in `plan.md` › *The user's answers*); D19 (the two windows, Enter, the read-only diff, the refresh); D33 (the editor's own section has no heading; the other worktrees' sections); D41 (the session's base and save marks, per Claude Code session); D46 (Enter moves the cursor to the diff); C13 (the git home: every git call asynchronous, bounded, never raising); C15 (the changes home, requiring only `aineo.git`); D26 and D29.

### The behaviour — one test each, seen failing first

Only the editor's own section changes. Every line of another worktree, and what Enter does on it, stays exactly as today (D33–D35).

**The commits window**
1. Its first line is `Uncommitted`, its second `Session work`, always, once the repository is found; then today's notes (a failed read, the base no longer behind `HEAD`), then the session's commits, or `No commits on this session`. Then the other worktrees' sections, as today. With no repository, both windows show today's no-repository page.
2. At the pane's first showing, and whenever the commits buffer is made anew, the cursor of the window showing it is on `Session work`. A later `\pc` keeps the user's line.

**The filter**
3. The line under the cursor in the commits window selects the filter: `Uncommitted`, `Session work`, or one of the session's commits. A line that lists none of these — a note, another worktree's heading or commit, an empty line — keeps the last filter.
4. The files window is read for a new filter only after a pause: every `CursorMoved` in the commits buffer restarts **one** timer of 150 ms (a named constant); when it ends, if the line under the cursor selects a filter other than the one shown, the files window is read for it. Moving over three commits inside the pause reads once, for the last.
5. The files window keeps its first line and its list until the new filter's list arrives, then shows both. Its first line always names what it lists.
6. The selection goes back to `Session work`, with the cursor, when the pane follows another Claude Code session (`follow_changes_session()`), and when the selected commit is no longer listed after the commits window is read again (a reset, a rebase).

**The files window**
7. Its first line names the filter: `Files in: Uncommitted`, `Files in: Session work`, or `Files in: ` followed by the commit's line as the commits window shows it (`M.commit_line()`: the 7-character id and the subject).
8. Under `Uncommitted`: every file that differs from `HEAD`, staged or not, and the untracked files the ignore rules leave in, in today's line format, `*` marks shown; or `No uncommitted changes`. Before the first commit, every file counts as new, as `Session work` does with no base.
9. Under `Session work`: today's list, from the session's base, `*` marks shown; or today's `No files changed on this session`.
10. Under a commit: the files that commit changed, against its first parent, with no `*` mark on any line; or `No files in this commit` (an empty commit). A root commit lists its files. **A merge commit lists the files it brought in against its first parent** (`--diff-merges=first-parent`; git lists none by default — `evidence/w10-probes.txt`, P2).
11. The files window is read again as today (the watch, a save, a showing) for `Uncommitted` and `Session work`. A commit's files never change, so reading it again is allowed but not required.
12. Today's notes stay, below the first line: a failed read, `M.NOT_WATCHED`. Then the other worktrees' sections, as today.

**Enter**
13. In the files window, on a file: its diff within the filter shown —
    - `Session work`: from the base, as today, in today's buffer `aineo://diff/{path}`;
    - `Uncommitted`: from `HEAD` to the working tree (an untracked file wholly added, as today), in `aineo://uncommitted/{path}`;
    - a commit: the commit's header, then that file's change in it, as `git show <id> -- <path>` gives it with the options `diffs.lua` already passes (a rename asked with both paths, as `tracked_diff()` does; a merge against its first parent), in `aineo://commit/{id}/{path}`, `{id}` the full id.
    `{path}` is quoted as `lines.quoted_path()` quotes it, as today.
14. In the commits window, on `Uncommitted`: the whole diff from `HEAD` to the working tree, **the untracked files included**, in `aineo://uncommitted`; on `Session work`: the whole diff from the session's base (the empty tree before the first commit) to the working tree, untracked files included, in `aineo://session-work`; on a commit: today's commit diff in `aineo://commit/{id}`, except that a merge is shown against its first parent.
15. The untracked files enter a whole diff through `git add --intent-to-add -- <paths>` on the private index copy (`lua/aineo/git/private_index.lua`'s `with_private_index()`), so the real index is never touched (`evidence/w10-probes.txt`, P4).
16. Everything T42 and T25 promise about Enter stays: the cursor moves to the diff's window in the user's mode while it is still in the pane (D46), only the last Enter's diff is shown, the no-room and failure messages, the textlock paths.

**Colours**
17. The two fixed lines of the commits window and the files window's first line show whole in a new group `AineoChangesFilter`, linked to `Title`, defined beside the others in `lua/aineo/changes/colours.lua`, overridable as they are.

The help is not in that list: `tests/test_doc.lua` pins tags, width and shape, no text. It stays green.

### Facts, checked against `origin/dev` `08c16b2`

- `lua/aineo/changes/init.lua`: `files_page()` 75, `commits_page()` 92, `window_read()` 201 (one read of a window at a time; the editor's own list then the other worktrees'), `read_files` 247, `read_commits` 264, `follow_change()` 285, `follow_repository()` 330, `follow_changes_session()` 743, `diff_name()` 834, `show_diff()` 885 (T42's focus move), `read_diff()` 924, `open_entry()` 975, `pane_buffer()` 1008 (the buffer-local `<CR>` at 1021).
- `lua/aineo/changes/lines.lua`: pure functions of their inputs. `own_file_rows()` 382, `M.files_window()` 401, `M.NO_FILES` 240, `M.NO_COMMITS` 414, `M.commit_line()` 428, `own_commit_rows()` 481, `M.commits_window()` 507. An `aineo.changes.Entry` (lines 103–107) has `key`, `change?`, `commit?`, `worktree?`: the fixed lines need entries a commit's 40-hex `key` cannot collide with.
- `lua/aineo/changes/pages.lua`: `write_page()` keeps each window's cursor on the entry it was on, by `key`; when the entry is gone, the cursor keeps its line number — behaviour 6 has to move it to `Session work` itself.
- `lua/aineo/git/`: `init.lua` exports `changed_files()` 55, `commits_since()` 67, `file_diff()` 81, `commit_diff()` 93; `diffs.lua` `UNIFIED_DIFF` 26, `COMMIT_HEADER` 43, `tracked_diff()` 106, `M.file_diff()` 131, `M.commit_diff()` 157; `changes.lua` `list_changes()` reads `diff --name-status -z -M` then `ls-files --others` on one private index; `repository.lua` `comparison_base()` gives the empty tree for a nil base. Every new read follows the home's docstring (`init.lua` 1–19): asynchronous, bounded, `done` called once on the main loop, never raising.
- **What git answers** (`evidence/w10-probes.txt`): P1, one read 38–88 ms on this repository; P2, merge, root and empty commits as in behaviour 10; P4, intent-to-add on a private index.
- **Tests that pin today's lines and will move** (`git grep -c` at `08c16b2` for the pane's empty lines and buffer names): `tests/test_changes.lua` (58 hits), `tests/test_changes_sessions.lua` (39), `tests/test_changes_worktrees.lua` (29), `tests/test_entry_panes.lua` (31 — it pins `{ 'No files changed on this session' }` and `{ 'No commits on this session' }` as whole buffers), `tests/test_entry_changes.lua` (7), `tests/test_layout_panes.lua` (4), `tests/test_entry_session_handover.lua` (2), `tests/test_entry_session_switch.lua` (1). Diff names: `tests/test_changes.lua` (18), `tests/test_entry_changes.lua` (11), `tests/test_layout_diffs.lua` (12). Change a pin only where D47 changes the line it pins, and name each changed test file in your report.
- The modularity table (`.claude/skills/modularity/SKILL.md`, lines 39–40): `aineo.git` requires no aineo home; `aineo.changes` requires `aineo.git` alone. A new file inside either home moves no list.

### Baseline

2494 cases at wave 9's close, on code identical to `08c16b2`'s (`plan.md` › *Baseline*). The dispatch message pastes the counts of the files you run.

Read first: the v1 plan note's D19, D33, D41, D46, **D47**, C13, C15; `plan.md` in this folder (*Measured before planning*, *Decisions for the orchestrator*, *Assumptions*); `evidence/w10-probes.txt`; `knowledge-vault/Projects/aineo.md`; the session notes of T25, T38 and T42 in `knowledge-vault/Sessions/`; [[Learnings/GIT_OPTIONAL_LOCKS=0 does not keep git diff from taking index.lock]].

## Boundary

- **Branch:** `feature/t43-changes-filter` from `origin/dev`.
- **Class:** regular.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › *Host and reviewers*, O12).
- **Resources:** `impl_t43_changes_filter` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/git/` (`init.lua` for new exports; `diffs.lua`, `changes.lua`, `history.lua`; a new file when a concern needs one); `lua/aineo/changes/` (`init.lua`, `lines.lua`, `pages.lua`, `colours.lua`; a new file when a concern needs one, such as the selection and its pause); a new `tests/test_changes_filter.lua`; the git suites `tests/test_git_*.lua`; the test files listed under *Facts* where a pin moves; `tests/helpers/git_repo.lua`, **additions only**, running every test file that requires it if you add to it; `doc/aineo.txt` — *aineo-panes*' changes-pane item (from `- The changes pane: \`aineo://changes-files\` in the Report's place, over` to `  kept unnamed when you changed its text.`), *aineo-changes* from `The files window, \`aineo://changes-files\`, lists every file that differs` to `windows say so until the pane is shown again, which starts it again.`, its *Colours* paragraph and group list (add `hl-AineoChangesFilter`), and LIMITS › `The changes pane ~`; your session note. Correct in the same commit what the change makes false there, and say in your report what you corrected.
- **You must not touch:** `plugin/aineo.lua` — the changes home needs nothing new from the composition root; `lua/aineo/layout/`; every other file under `lua/`, `plugin/`, `scripts/` and `tests/`, `tests/test_doc.lua` included (run it); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Keep `aineo.changes`' interface:** `begin_session()`, `follow_changes_session()`, `hand_over_changes_session()`, `refresh_shown_pane()`, `pane_buffers()` keep their names, arguments and promises; T44 builds on what you leave.
- **Session note:** `knowledge-vault/Sessions/<date> — T43 Changes filter.md`, `<date>` the dispatch message's, with a `## Task lines` section.
- **Scratch prefix:** `t43-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5. While you work, the test files you touch, plus `tests/test_entry_panes.lua` and `tests/test_doc.lua`; the whole suite (`make test`) once before each push; mutants on their covering files. git only in fixture repositories (`tests/helpers/git_repo.lua`), never the checkout's.

## What was decided already

- D47 as the user chose it (the row quotes it). Do not re-open the two fixed lines, the pause, the first-line name, the marks, the whole diffs, or the other worktrees staying as they are.
- The orchestrator's rulings on O2–O8 (`plan.md`); this body is written for (a) of each. Assumptions A4–A6 (`plan.md`) are built as written.
- D46 and T42's focus move, and every T25/T38 behaviour of Enter and the refresh, stay.

## Budget

Large: four new reads in the git home (a commit's files, a file in a commit, what differs from `HEAD`, a whole diff with the untracked files), the selection and its pause in the changes home, the new lines, the new diff names, and the help — about twenty new cases, and pins moved in several suites. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t43-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, each test file whose pins moved and why, and the whole suite's counts. The orchestrator's verification runs `plan.md`'s five T43 mutants: name the test that kills each.
