**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D63 as proposed and for the recommendations O4 and O5 of `plan.md` in this folder. If the orchestrator ruled otherwise, a dated amendment at the end of this brief says so, and it wins over the body.

## Objective

The task, verbatim from the task list:

> | T60 | One layout per tab (C2, C9, C12; D63, proposed): `aineo.layout` gains `new()`, a layout of its own, its three windows, Input, file column, pane and proportions kept apart from every other layout's, in the tab page it opens in; the module's own functions stay one such layout, so every caller and suite of today stands; no behaviour changes with one layout | T48 part 2 | planned — wave 15 |

It rests on:
- **D63**, the user's decision of tabs with their own Report and Input, and the proposed parts.
- **C2, C9 and C12**: the layout, the file column and the panes.
- D4, D6, D18, D59, and D25 (a wiped Claude terminal).
- C8, D10, D26, D29.

### What a layout must do — one test each, seen failing first

1. `require('aineo.layout').new()` returns a layout with the same functions as the module: `open`, `focus`, `show_pane`, `focus_pane`, `show_diff`, `follow_claude_terminal`, `toggle_claude_numbers` and `input_buffer`, called as fields. Each call of `new()` gives a layout of its own. The module stays one layout, so its callers and suites keep working.
2. Two layouts opened in two tab pages each hold their three windows in their own tab. Opening the second leaves the first's windows, buffers and sizes as they were.
3. Each layout has an Input of its own, under a name no other buffer holds. The module's layout keeps `aineo://input`. Making a second Input raises no E95 (P1), and wiping one layout's Input leaves the other's.
4. `focus(role)`, `focus_pane(pane)` and `show_pane(pane)` of a layout act in that layout's tab, moving to it from any other tab as the one layout does today (`tests/test_layout_tabs.lua`). The changes pane shown in one layout leaves the other's right column on its own pane.
5. The handlers of one layout leave the other's alone, and neither copy's handlers remove the other's:
   - proportions kept on `VimResized`, `WinClosed` and `TabEnter`;
   - Input kept a scratch buffer;
   - a file shown in a layout window redirected to that layout's middle column;
   - Claude's window's numbers and status line;
   - the Terminal-mode exit of D25 and the wiped terminal's close.

   A file opened from the second layout's Input lands in the second tab's middle column.
6. `show_diff(diff)` of a layout shows the diff in that layout's file column, in its tab.
7. `follow_claude_terminal(terminal)` and `toggle_claude_numbers()` act on that layout's Claude window only.
8. A layout whose tab page was closed (P1: the handle is invalid) has no window. Its next `open()` opens it in the current tab, as a layout whose windows are all gone opens today, and it raises nothing.

### Facts, checked at `bugfix/t48-attach` `e0989f2` (the layout is the same on `dev` `1354cad`)

These are read in `lua/aineo/layout/init.lua`:
- The layout's state is one file-level table, `state` (line 46): windows, buffers, the pane, the views, the proportions, Claude's numbers and status line, the diffs.
- `layout_tab()` (165) finds the layout's tab from its windows. `open()` (1203) moves to it (1207).
- The windows are made in the current tab, closing its other windows (623–660).
- `INPUT_NAME = 'aineo://input'` (529) is set with `nvim_buf_set_name()` (588). A second buffer cannot take it (P1: E95).
- `watch_windows()` (849) makes its handlers in the group `aineo.layout`, which `nvim_create_augroup(…, {})` clears when made again. Those are `BufWinEnter` (three), `WinClosed`, `VimResized`, `TabEnter`, `TermClose` (two), `TermEnter` and `BufWipeout`. Each is global, so each must act on its own layout's windows and buffers only.
- `lua/aineo/layout/columns.lua` keeps no file-level state.
- `tests/test_layout_tabs.lua` pins today's tab rules for one layout. They stay true for the module's layout.

Evidence: `evidence/w15-probes.txt` › P1, P4, P5.

### Baseline

This plan ran no suite. The dispatch message pastes the counts of the test files you run, measured on the `dev` you start from.

Read first:
- `plan.md` in this folder (*The model*, O4, O5);
- the v1 plan note's C2, C9, C12, D4, D6, D18, D25, D59 and **D63**;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t60-layout-copies` from `origin/dev`, once T48 part 2 has merged.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t60_layout_copies`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/layout/`;
  - a new `tests/test_layout_copies.lua`, and the `tests/test_layout*.lua` files where a pin moves (none should);
  - your session note.
- **You must not touch:**
  - `plugin/aineo.lua`, which T66 changes in stage 2;
  - every other home under `lua/`;
  - `doc/aineo.txt`, since nothing the user sees changes;
  - `tests/helpers/` (put what you need in your new test file);
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Keep the interfaces.** Every export of `aineo.layout` keeps its name, its arguments and its promises, and the module acts as today. Add `new()`, and say in the module's header docstring what a layout is and what the module's own functions are.
- **Session note:** `knowledge-vault/Sessions/<date> — T60 Layout copies.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t60-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run the test files you touch, plus `tests/test_layout_tabs.lua` and `tests/test_layout_file_column.lua`.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on their covering files.
  - Never run the real `claude`.

## What was decided already

- **The user's decision, 2026-10-14:** tabs, each with its own Report and Input, only sessions of one folder (D63, quoted in `plan.md` › *The user's words*).
- **The orchestrator's assumptions** (O4, O5): one copy per tab behind the same functions, with the module as the first copy. Record them in the session note and the pull request as such, never as the user's.
- **Rejected:** a tab key on every function (O4 (b)); one state swapped at `TabEnter` (O4 (c)).
- **Not yours:** which tab a layout opens in, and when. The composition root decides (T66): it opens a tab page, then opens a layout there.

## Budget

Medium: one home given copies, with about ten new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

Write it in your definition's shape, to `<scratchpad>/t60-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- each per-editor resource you made unique per layout, and how;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s T60 mutants. Name the test that kills each.

## The orchestrator's rulings — 2026-10-14, before dispatch

`plan.md` › *The user's answers* (U1–U3, the user's decisions) and *The orchestrator's rulings* (O1–O22 → A234–A255, each its (a)) bind this brief, which is written for them. Record A234–A255 as the orchestrator's assumptions, never as the user's decisions.
