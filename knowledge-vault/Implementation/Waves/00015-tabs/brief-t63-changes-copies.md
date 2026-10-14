**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D63 as proposed and for the recommendations O4, O5 and O12 of `plan.md` in this folder. If the orchestrator ruled otherwise, a dated amendment at the end of this brief says so, and it wins over the body.

## Objective

The task, verbatim from the task list:

> | T63 | One changes pane per tab (C15; D63, proposed): `aineo.changes` gains `new()`, a changes home of its own whose session, base and saves, pane buffers, selection, diffs and watch are kept apart from every other copy's; no copy's buffer wipes or takes the name of another's; the full-context toggle stays one per editor (D48); the module's own functions stay one such copy, so every caller and suite of today stands | T48 part 2 | planned — wave 15 |

It rests on:
- **D63**, the user's decision of tabs, and the proposed parts.
- **C15 and C13**: the changes home and the git home.
- D19, D22, D31–D35, D41, D45–D48, D55–D57 and D60, which hold per copy.
- C8, D10, D26, D29.

### What a copy must do — one test each, seen failing first

1. `require('aineo.changes').new()` returns a changes home with `begin_session`, `follow_changes_session`, `hand_over_changes_session`, `refresh_shown_pane` and `pane_buffers`, called as fields. Each call gives a copy of its own. The module stays one copy.
2. Each copy's `begin_session()` begins its own session: the first call of each copy is heeded, as the module's first call is today. A second copy's begin leaves the first's base, saves and lists as they were.
3. Each copy's pane buffers are its own, under names no other buffer holds. The module's keep `aineo://changes-files` and `aineo://changes-commits`. Making the second copy's pane wipes nothing of the first's (P4: `free_name()` wipes the holder of a name today).
4. Two copies following two sessions keep and show each session's own base and saves (D41). A save marks the saved file in each copy whose session's repository holds it, as a save is marked today.
5. The cursor's filter (D47) is per copy. Moving in one copy's commits window selects that copy's filter, and leaves the other's files window as it was.
6. Enter on the same file, or `gf` on the same commit's file, in two copies' panes: each shows its diff in the window its own `show_diff` gives. Neither wipes the other's diff buffer nor closes its window. Each diff buffer's name is one no other copy's buffer holds, and the module's copy keeps today's names (`aineo://show/…`, `aineo://worktree…`, `aineo://<filter>…`).
7. The `F` toggle (D48) is one per editor, as D48 says "for the editor's life". A flip in one copy's diff opens the next diff of every copy the same way.
8. Each copy runs its own watch (O12 (a)) and stops it at quit. The handlers of one copy leave the other's alone, and no copy's group removes another's: the saves, `VimLeavePre`, `BufWinEnter`, `CursorMoved` and `WinScrolled` (P4: `aineo_changes` and `aineo_changes_commits_scroll` are cleared when made again).

### Facts, checked at `bugfix/t48-attach` `e0989f2` (the home is the same on `dev` `1354cad`)

**`lua/aineo/changes/init.lua`** (1768 lines):
- State: `session` (79), `followed_before_beginning` (84), `held_bases` (92), `buffers` (102), `refused` (184), the window reads (446, 609), `landed_reads` (570), `keeping_failure_told` (740), `find` (922), `shown_diffs` (1206), `rereads` (1237), `enters` (1406), `window_moved` (1642), `selection_pause` (1689).
- Exports: `begin_session` (1052), `follow_changes_session` (1107), `hand_over_changes_session` (1163), `refresh_shown_pane` (1734), `pane_buffers` (1752).
- `begin_session()` makes the group `aineo_changes`, cleared when made again (1067), with the saves and `VimLeavePre`'s stop of the watch (1075). The commits window's scroll handler is in `aineo_changes_commits_scroll` (1707).
- The pane buffers are named at 1754 and 1759 through `scratch.named_scratch_buffer()`.

**Elsewhere in the home:**
- `lua/aineo/changes/scratch.lua`: `free_name()` (11) wipes every other buffer that holds a name, unless the user changed its text.
- Diff and commit-file names: `commit_file.lua:82`, `head_diff.lua:183-185`, `entry_diff.lua:221-223`.
- `lua/aineo/changes/full_context.lua`: `current` (10), the `F` toggle, one per editor.
- `diffs.lua`'s `shown_by_buffer` (111) and `pages.lua`'s `pages` (14) are kept by buffer. They may stay shared if every buffer is one copy's.
- `aineo.changes` requires `aineo.git` and its own files alone (C15). Keep it so.

Evidence: `evidence/w15-probes.txt` › P4, P5.

### Baseline

This plan ran no suite. The dispatch message pastes the counts of the test files you run, measured on the `dev` you start from.

Read first:
- `plan.md` in this folder (*The model*, O4, O5, O12);
- the v1 plan note's C13, C15, D41, D47, D48 and **D63**;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t63-changes-copies` from `origin/dev`.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t63_changes_copies`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/changes/`;
  - a new `tests/test_changes_copies.lua`, and the `tests/test_changes*.lua` files where a pin moves (none should);
  - your session note.
- **You must not touch:**
  - `lua/aineo/git/`, and every other home under `lua/`;
  - `plugin/aineo.lua`;
  - `tests/helpers/` (put what you need in your new test file; `tests/helpers/git_repo.lua` is read-only here);
  - `doc/aineo.txt`;
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Keep the interfaces.** Every export of `aineo.changes` keeps its name, its arguments and its promises, and the module acts as today. Add `new()`, with its docstring and the home's header saying what a copy is.
- **Session note:** `knowledge-vault/Sessions/<date> — T63 Changes copies.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t63-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run the test files you touch, plus `tests/test_changes.lua`, `tests/test_changes_sessions.lua`, `tests/test_changes_filter.lua` and `tests/test_changes_open_file.lua`.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on their covering files.
  - Never run the real `claude`.

## What was decided already

- **The user's decision, 2026-10-14:** tabs, each with its own changes pane, in the orchestrator's confirmation of the user's "report and input is per tab" (D63, `plan.md` › *The user's words*).
- **The orchestrator's assumptions** (O4, O5, O12): one copy per tab behind the same functions, the module as the first; one watch per copy. Record them in the session note and the pull request as such, never as the user's.
- **Rejected:** one watch shared across copies (O12 (b)), which changes the git home's interface for a cost not measured.

## Budget

Medium to large: the largest home given copies, with about ten new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

Write it in your definition's shape, to `<scratchpad>/t63-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- each name and group you made unique per copy, and how;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s T63 mutants. Name the test that kills each.
