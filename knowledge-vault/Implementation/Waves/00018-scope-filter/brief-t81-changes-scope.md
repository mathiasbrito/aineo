**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D76, for the recommended answers U1 (a) and U3 (a), and for O4–O9 and O12 (a) of `plan.md` in this folder. Before dispatch the orchestrator writes a dated amendment at the end of this brief for each fact that moved, and for any answer or ruling other than (a). The amendment wins over the body.

## Objective

The task, verbatim from the task list:

> | T81 | The changes pane shows one worktree alone (C1, C15; D76): each changes home keeps a scope, none or one other worktree; `s` in either window of the pane offers the other worktrees in `vim.ui.select`; a scope's view is the worktree's name on the first line — its whole change — and its commits below, nothing else; picking selects its whole change and the files window follows; `\g` (`:Aineo pane changes`) clears the scope and shows the default view, the choice kept when that view lists it; a worktree no longer listed, or another Claude Code session followed, clears it, the first told once; per tab, never on disk; with the help | T63, T74 | planned — wave 18 |

It rests on:
- **D76**, the user's decision: one worktree or branch alone, its name first, nothing else, `\g` back to the default view;
- D33–D35, **D47** (the commits window as the files window's filter), D55, **D60** (a worktree's base);
- C1, C15; C8, D10, D26, D29.

### The behaviour — one test each, seen failing first

**The scope view (D76; O4)**

1. With a scope on another worktree, the commits window's first line is that worktree's heading as `lua/aineo/changes/lines.lua` › `worktree_heading()` writes it, `Worktree <folder> (<branch>)` or `(detached)`, whole in `AineoChangesFilter`. Its entry is that worktree's whole-change filter (`filter.of_worktree()`), so that Enter on it shows `aineo://worktree{top}//since-base` as the heading does today.
2. Below it, the worktree's commits as its section lists them today, or `No commits in this worktree`, and the failure line its section shows when its read failed. Pin with a worktree of two commits.
3. Nothing else is listed: not *Uncommitted*, not *Session work*, not the session's commits or their notes (the base no longer behind `HEAD`), not Landed, not another worktree, not the line saying the worktrees could not be listed (mutant 1). Pin the whole page's text.
4. Without a scope, the page is today's, unchanged: every existing pin of `tests/test_changes*.lua` holds.

**Picking (U1 (a); O5, O12)**

5. `s` in Normal mode, in the commits window and in the files window, calls `vim.ui.select` with the other worktrees the commits window last listed, in that order, each shown by its heading (`format_item`), prompt `Show alone in the changes pane`. It is a buffer-local map of each pane buffer, made again whenever the buffer is made anew, as Enter is (`copy.lua` › `pane_buffer()`); `s` stays Vim's own in every other buffer. Test it as `tests/test_entry_sessions.lua` does, by replacing `vim.ui.select` in the child.
6. Picking a worktree sets the scope, selects its whole change, puts the cursor on the first line, and the files window's first line reads `Files in: Worktree <folder> (<branch>)` with that worktree's files (mutant 5). Dismissing the picker (`on_choice(nil)`) changes nothing.
7. Moving the cursor onto one of the scope's commits chooses it as today: `Files in: <id> <subject> (worktree <folder>)`.
8. `s` under a scope offers the same list; picking another worktree replaces the scope.
9. With no other worktree listed, `s` opens no picker and tells `aineo: no other worktree or branch to show alone`, once, at `INFO`. While the session has no repository, `s` opens no picker and tells why, in the words the windows show. A `vim.ui.select` that raises is told once, as `\S`'s failing menu is (`tests/test_entry_sessions.lua`, *the menu failed*).

**Leaving the scope (D76; U3 (a); O6)**

10. `\g` — the `pane changes` action, `lua/aineo/entry/tab.lua` › `focus_pane('changes')` — clears the scope of the acting tab's changes home and shows the default view, read again as today. Whether the changes pane or another pane was shown before (U3 (a)). Test through `:Aineo pane changes` in `tests/test_entry_changes.lua` (mutant 3). The home gains one call for it (name it for what it does: `show_default_view()`, say); `refresh_shown_pane()` stays as it is.
11. After `\g`, the choice stays when the default view lists it — the worktree's heading or one of its commits — and the cursor is on its line; when it does not, *Session work* is chosen, the cursor on it.
12. `\g` with no scope behaves as today: `\g keeps your line` (the help) holds.

**The scope gone, another session, per tab (O7, O8, O9)**

13. A read of the worktrees that no longer lists the scope's worktree — `git worktree remove`, or its directory removed and pruned — clears the scope, chooses *Session work*, shows the default view, and tells `aineo: Worktree <folder> (<branch>) is gone; the changes pane shows the default view`, once, at `INFO` (mutant 4). This takes the place of `copy.lua` › `reselect_in_worktrees()`'s *Session work* rule under a scope; without a scope that rule is unchanged and tells nothing.
14. A scope's commit no longer listed (the agent amended or rebased it) becomes the scope's whole change, the cursor on the first line, as the rule is today.
15. Following another Claude Code session (`follow_changes_session()`) clears the scope, with the choice back to *Session work* as today; nothing is told.
16. Two tabs' changes homes scope apart: a scope set in one tab's pane leaves the other's default view (mutant 2). Test with `require('aineo.changes').new()` as `tests/test_changes_copies.lua` does.
17. The reads are those of today, whatever the scope: under a scope, the commits window still reads the session's commits, Landed and every worktree, and `\g` shows the default view from what was read before it reads again (O8). Pin it by a commit made in the editor's worktree under a scope, listed at once after `\g`.

### Where the code goes

- **`lua/aineo/changes/scope.lua`** (new, private to the home): the scope's values and the pure rules — the picker's items from what the commits window last listed, the name of a scope, and what a read that no longer lists the scope comes to. No state, no git.
- **`lua/aineo/changes/lines.lua`** › `commits_window(view)`: `aineo.changes.CommitsView` gains the scope; the page under a scope is the scope's heading row (in the filter group) and its section's rows.
- **`lua/aineo/changes/copy.lua`**: the home's state (`aineo.changes.Session` or the home, as the code reads better: the scope must not outlive the home, and `follow_changes_session()` clears it), the `s` map, the picker, the default-view call, the clearing in `reselect_in_worktrees()`. `aineo.changes.Home` gains that call in its `---@class`. Keep each function one job; `copy.lua` is long already, so put every rule that needs no state in `scope.lua`.
- **`lua/aineo/entry/tab.lua`** › `focus_pane()`: under `pane == 'changes'`, the new call in place of `refresh_shown_pane()` (it reads the pane again itself).

### Facts, checked against `dev` `b10b47a` — re-check them at dispatch

- `lua/aineo/changes/copy.lua` (1851 lines): `pane_buffer()` at 1667 maps Enter in both pane buffers; `reselect_in_worktrees()` at 540; `follow_changes_session()` at 1152; `refresh_shown_pane()` at 1780; `select_filter()`, `select_session_work()`, `place_commits_cursor()` and `cursor_unplaced` place the cursor on a chosen line.
- `lua/aineo/changes/lines.lua` (673 lines): `commits_window()`, `own_commit_rows()`, `landed_rows()`, `worktree_rows()`, `heading_row()` (a note today), `filter_row()`, `worktree_heading()`, `filter_name()`.
- `lua/aineo/changes/filter.lua` (111 lines): `of_worktree()`, `key()`, `same()`, `in_worktree()`.
- `lua/aineo/entry/tab.lua` (1645 lines): `focus_pane()` at 903 calls `homes.changes.refresh_shown_pane()` for `changes`; the `pane changes` action at 1469.
- The pane's keys today: Enter (both windows), `gf`, `l`, `h` (files window), `F` (diffs). `s` is mapped nowhere in the pane.
- `tests/test_changes_worktrees.lua` (1928 lines) holds `add_worktree()` and the reading helpers; `tests/test_entry_changes.lua` (482 lines) drives the pane through `:Aineo`; `tests/test_entry_sessions.lua` replaces `vim.ui.select`.

**Test isolation.** Never run the real `claude`; the suites' `PATH` guard stops a bare `claude`. Repositories and worktrees are made under the test's own directory. Every wait is bounded (`vim.wait` or the helpers' timed attempts).

### Baseline

The dispatch message pastes the counts of `tests/test_changes_worktrees.lua`, `tests/test_changes_keys.lua`, `tests/test_changes_copies.lua` and `tests/test_entry_changes.lua` on the `dev` you start from.

Read first:
- `plan.md` in this folder: *The user's words*, *Today's pane*, *The model*, U1, U3, O4–O9, O12;
- the v1 plan note's **D76**, D47, D60, and C15;
- `doc/aineo.txt` › *aineo-changes*;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t81-changes-scope` from `origin/dev`.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t81_changes_scope`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/changes/copy.lua`, `lua/aineo/changes/lines.lua`, `lua/aineo/changes/filter.lua` where needed, a new `lua/aineo/changes/scope.lua`, and `lua/aineo/changes/init.lua`'s docstring;
  - `lua/aineo/entry/tab.lua`: `focus_pane()` and its docstring alone;
  - `doc/aineo.txt`: *aineo-changes* — a paragraph on `s`, the scope view and `\g`; the sentence on `\g` and the cursor; the *Colours* paragraph where the first line's group is named; and the entry `*aineo-\g*` (and `:Aineo-pane`'s, if it says what `changes` does);
  - a new `tests/test_changes_scope.lua`, a new case set in `tests/test_entry_changes.lua`, and `tests/test_changes_worktrees.lua` and `tests/test_changes_keys.lua` where a pin moves;
  - your session note.
- **You must not touch:**
  - `aineo.git` and every other home; `lua/aineo/config/`, since no setting is added;
  - `plugin/aineo.lua`: `\g` keeps its action, and no subcommand is added (U1 (a));
  - `README.md`: it lists no key of the pane (checked on `b10b47a`); re-check, and report if it does;
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **No new edge between homes.** Print and list §1's deep-require check in your pull request.
- **Session note:** `knowledge-vault/Sessions/<date> — T81 Changes scope worktree.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t81-`.
- **How the suite runs (D26, D29):** on the newest Neovim release. While you work, run the test files you touch and `tests/test_changes_copies.lua`. Run the whole suite (`make test`) once before each push. Run mutants on their covering files.

## What was decided already

- **The user's decisions, 2026-10-16 (D76):** a worktree or a branch chosen "as sort of a filter"; "only the commits on this work tree or branch would be displayed"; "no distractions, first line is the worktree or branch name, to return the user does \g again, and comes back to the default view". The words are quoted in `plan.md` › *The user's words*.
- **The user's answers** U1 and U3, as the dispatch's amendment gives them. This body is written for the (a)s: `s` in the pane; every `\g` leaves the scope.
- **The orchestrator's assumptions:** O4–O9 and O12. Record them in the session note and the pull request as the orchestrator's rulings, never as the user's decisions.
- **Rejected:** a `Scope:` line above the heading (two lines for one choice); a picker entry to leave the scope (the user's way back is `\g`); reading only what is shown (O8 (b)); a scope on disk (O9 (b)).

## Budget

Medium: one new pure file, a page variant, a key and a picker, one composition-root line, about twenty cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial: the scope view first, then picking, then `\g`, then the scope gone.

## Report

Write it in your definition's shape, to `<scratchpad>/t81-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- each test file whose pins moved, and why;
- the whole suite's counts;
- the deep-require check's output.

The orchestrator's verification runs `plan.md`'s T81 mutants. Name the test that kills each.

## The orchestrator's rulings — 2026-10-16, before dispatch

`plan.md` › *The orchestrator's rulings* rules O1–O12 as their (a), A392–A403, and adds A391 (how the list marks its items), which this brief is written for. Record them as the orchestrator's assumptions, never as the user's decisions.

## Amendment — 2026-10-16, the user's answers, before dispatch

The user answered U1–U3 (`plan.md` › *The user's answers*, D76's dated note). U1 and U3 are not the (a)s this body was written for; where the body and this section differ, this section wins.

- **The task row now reads**, verbatim:

  > | T81 | The changes pane shows one worktree alone (C1, C15; D76): each changes home keeps a scope, none or one other worktree; `s` in either window of the pane offers one list in `vim.ui.select`, each item marked by its kind, the other worktrees marked `[worktree]`; a scope's view is the worktree's name on the first line — its whole change — and its commits below, nothing else; picking selects its whole change and the files window follows; `\g` (`:Aineo pane changes`) pressed while the pane shows clears the scope and shows the default view, the choice kept when that view lists it, and pressed from another pane shows the scope view again; a worktree no longer listed, or another Claude Code session followed, clears it, the first told once; per tab, never on disk; with the help | T63, T74 | planned — wave 18 |

- **Behaviour 5, the list (U1, the user's decision; A391).** `s` offers one list, which T82 extends with branches; build it so. Each item is marked by its kind: a worktree reads `[worktree] <folder> (<branch>)`, or `(detached)`, the folder and branch quoted as `worktree_heading()` quotes them. `format_item` gives that text, so a picker that searches (telescope, fzf-lua, snacks, dressing…) searches it. The items carry what a pick needs (the worktree's top level), never a parse of the text. Pin the text of each item.
- **Behaviour 10, `\g` (U3 (b), the user's decision).** Replace it with:
  - 10a. `\g` pressed while the changes pane already shows — either of the home's pane buffers in a window, as `refresh_shown_pane()` tells it, checked before the pane is shown — clears the scope and shows the default view, read again as today.
  - 10b. `\g` pressed from another pane — after `\pa` or `\pt`, or with the layout closed — shows the changes pane in its scope view, read again, the scope kept (mutant 3 of `plan.md`, as amended).

  The home's new call does both: it clears the scope only while its pane is shown, and reads the shown pane again as `refresh_shown_pane()` does; `focus_pane('changes')` calls it in that function's place.
- **Behaviour 11** applies to the `\g` of 10a alone. **Behaviour 12** is unchanged.
- **The help** says, under *aineo-changes*: `s` and its one list, each item marked; that Neovim's own `vim.ui.select` is a numbered list with no search, and a picker plugin that replaces it searches the list; the scope view; `\g` from the pane and from elsewhere (and `*aineo-\g*` likewise).
- **Rejected by the answers:** a subcommand (U1 (b)); every `\g` clearing (U3 (a)).

## Amendment — 2026-10-16, `\g` toggles, before dispatch

The user, verbatim, while D77 was adjusted: "the \g as a toggle is fine" (`plan.md` › *The user's additions*; *The model*, items 5 and 9 as amended). Where the body, the amendment above and this section differ, this section wins.

- **Behaviour 10a now reads:** `\g` pressed while the changes pane already shows switches between the default view and the scope view. From the scope view it shows the default view, read again; the scope is **kept**, hidden, not cleared. From the default view it shows the scope view again, read again, when a scope is kept; with none, it reads the pane again as today.
- **Behaviour 10b is unchanged:** from another pane, `\g` shows the changes pane in the view it was last left in — the scope view when the user left it there, the default view when the user had toggled to it — read again.
- **Behaviour 11** applies to the switch to the default view. **Behaviour 12** holds with no scope kept.
- **What ends a scope:** `s` replacing it, the scope gone (13), another session followed (15), the tab closed, the editor quit. `\g` no longer does.
- **Mutant 3** of `plan.md` stands as written. Add a case: `\g` twice in the pane returns to the scope view, its first line `Worktree …`.
- **T84**, later, adds a second kind of focused view, the reported set; build the toggle on "the focused view", not on the scope alone, so that T84 extends it without rewriting it. Name the home's call for what it does (`toggle_focused_view()`, say).
- **The help** says that `\g` in the pane toggles, and what it brings back from another pane.
