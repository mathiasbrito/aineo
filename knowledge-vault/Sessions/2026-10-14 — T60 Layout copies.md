# 2026-10-14 — T60 Layout copies

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t60-layout-copies` · **Pull request:** #205, into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C2, C9, C12, D4, D6, D18, D25, D59, D63, T60
- [[Implementation/Waves/00015-tabs/plan]] › *The model*, O4, O5, *Verification mutants* › T60
- [[Implementation/Waves/00015-tabs/brief-t60-layout-copies]]
- `Implementation/Waves/00015-tabs/evidence/w15-probes.txt` › P1, P4, P5
- The head of `dev` this branch starts from: `9ca0abc`

Stage 1 of wave 15 changes nothing the user sees: with one layout aineo acts as before. O4 and O5 (A234–A255) are the orchestrator's assumptions under the user's instruction of 2026-10-06, not the user's decisions; the user decided the tabs, the one folder and the per-tab Report and Input (D63).

## What was done

`aineo.layout` gained `new()`. The module body of `lua/aineo/layout/init.lua` became `make_layout(input_name, group_name)`, which returns a table of the eight functions (`open`, `focus`, `show_pane`, `focus_pane`, `show_diff`, `follow_claude_terminal`, `toggle_claude_numbers`, `input_buffer`) over a `state` of its own. The module is the first layout, `make_layout('aineo://input', 'aineo.layout')`, so every caller and suite of today stands; `new()` makes the next, counting the layouts made since the module loaded. The form is O4 (a)'s cheapest: the module body wrapped in a function, which is why `git diff -w` is the readable diff where plain `git diff` shows the whole file re-indented (`git diff -w --numstat 9ca0abc -- lua`: 74 added and 18 removed lines before the fix round, 108 and 21 after it).

Per-editor resources a layout holds, each made unique per layout:

| Resource | The module's layout | A layout `new()` makes |
|---|---|---|
| Input's buffer name (P1: a second buffer cannot take a name, E95; `buffer_named_input()` would also take another layout's Input as its own) | `aineo://input` | `aineo://input-<n>` |
| The autocommand group of its handlers (P4: `nvim_create_augroup(…, {})` clears a group made again) | `aineo.layout` | `aineo.layout.<n>` |
| Windows, buffers, pane, views, proportions, Claude's line numbers and status line, diffs (P5: one file-level `state`) | its `state` | its own `state`, closed over by the layout's functions |

The handlers needed no change beyond that: each reads its own `state`, so a window or buffer of another layout is not one of its roles. `lua/aineo/layout/columns.lua` keeps no state and stays shared.

A layout whose tab page was closed has no window (P1: the handle is invalid), and its next `open()` opens it in the current tab as a layout whose windows are all gone opens today; its handlers go on doing nothing once its windows are invalid.

No file outside `lua/aineo/layout/init.lua`, `lua/aineo/layout/columns.lua` (the fix round), `tests/test_layout_copies.lua` and this note changed; `plugin/aineo.lua` and the other homes are untouched, and the help needs nothing (nothing the user sees moved). The brief's facts were checked against `dev` `9ca0abc` and had not moved: `state` at line 46, `layout_tab()` at 165, `open()` at 1203, the input name at 529 and 588, `watch_windows()` at 849 — no amendment (A256).

## Unit list

1. `new()` gives a layout with the module's eight functions as fields, a different one each call.
2. Two layouts in two tabs: opening the second leaves the first's windows, buffers and sizes as they were; the second holds its three windows in its own tab; a third layout does the same beside them.
3. Each layout's Input has a name no other buffer holds, the module's keeping `aineo://input`; wiping one leaves the other's.
4. `focus()`, `focus_pane()` and `show_pane()` act in the layout's own tab and move to it from another; a pane shown in one layout leaves the other's right column alone.
5. The handlers of one layout leave the other's alone, whichever opened last: proportions on `VimResized`/`TabEnter`, Input kept a scratch buffer, a file redirected to the middle column of its own tab, the Terminal-mode exit, Claude's window closed with its wiped terminal.
6. `show_diff()` shows the diff in its layout's file column, in its tab.
7. `follow_claude_terminal()` and `toggle_claude_numbers()` act on their layout's Claude window.
8. A layout whose tab page closed opens in the current tab and raises nothing.

## Red and green

The red was taken against a stub, `function M.new() return M end` (the plan's mutant 1), with `init.lua` otherwise as on `dev`. The first runs, on the 31 cases then written, failed 20; the table below gives each case's state against the stub on the final 34 (23 fail, 11 arrive green). One case, the status line, first failed for a fault in the test (`win_findbuf` called with two arguments, E118) and was corrected before the factory; it is listed by what it does against the stub now.

`tests/test_layout_copies.lua`, 34 cases (the parametrized ones counted by row). "Stub" is `function M.new() return M end`; "assertion" and "crash" are read from the output (a crash is a Lua error in the test's own look at a window the stub took from its layout).

| Case | Against the stub | Killed, after, by |
|---|---|---|
| `new()` gives a layout with the module's function as a field (8 rows: `open`, `focus`, `show_pane`, `focus_pane`, `show_diff`, `follow_claude_terminal`, `toggle_claude_numbers`, `input_buffer`) | arrived green: the stub is the module, which has them | mutant A, 8 of 8 by assertion |
| `new()` gives a layout of its own on each call | red, assertion (`Left: true, Right: false`) | mutant 1, assertion |
| two layouts leave the first one's windows, buffers and sizes as they were once the second opens | red, assertion (`buffer`: 4 against 2) | mutant 1, assertion |
| two layouts hold the second one's three windows in its own tab | red, assertion (`{ 6 }` against `{ 4, 5, 1 }`) | mutant 1, assertion |
| two layouts give each Input a name of its own, the module's keeping `aineo://input` | red, assertion (no-equality on `aineo://input`) | mutants 1, 4, assertion |
| a third layout gets a window set and an Input of its own | written after the factory; red under mutant 1, assertion | mutant 5, assertion |
| the first one's Input stays when the second one's is wiped | red, assertion (`false` against `true`) | mutants 1, 4, assertion |
| `focus()` moves to the second one's tab from the first one's | red, assertion (tab 1 against 2) | mutant 1, assertion |
| `focus()` moves to the first one's tab from the second one's | red, assertion (buffer 5 against 3) | mutant 1, assertion |
| the changes pane shown in the first one leaves the second one's right column on the agent pane | red, assertion | mutants 1, 4, assertion |
| the changes pane shown in the second one leaves the first one's right column on the agent pane | red, assertion | mutants 1, 4, assertion |
| `focus_pane()` moves to the second one's tab, the cursor in its commits window | red, assertion (tab 1 against 2) | mutant 1, assertion |
| the handlers keep each layout at its proportions as the editor is resized, whichever opened last | red, crash (`Invalid 'win'`) | mutants 2, 3, 4, assertion |
| the handlers keep the first one's Input a scratch buffer once the second one opened | arrived green: with one shared state and one group the stub's handler serves it | mutant 2, assertion |
| the handlers keep the second one's Input a scratch buffer once the first one opened again | red, crash | mutant 2, assertion |
| a file opened in the second one's Input goes to the file column of its tab | red, assertion | mutant 3b, assertion |
| a file opened in the first one's Input goes to the file column of its tab | red, crash | mutants 2, 3b, assertion |
| `show_diff()` of the second one, called from the first one's tab, shows the diff in the file column of the second one's tab | red, assertion | mutant S1, assertion |
| the line numbers the second one toggled show in its Claude window, the first one's showing none | red, crash | mutant N1, assertion |
| the line numbers the first one toggled from the second one's tab show in its Claude window | red, crash | mutant N1, assertion |
| the Claude window draws the status line of its own layout for the terminal it follows | red, crash | mutant F1, assertion |
| Terminal mode ends as the second one's terminal ends | arrived green: the stub's handler serves its one layout | mutant I1, assertion |
| Terminal mode ends as the first one's terminal ends, once the second one opened | red, crash | mutants 2, I1, assertion |
| the Claude window closes with its terminal wiped there, the other layout's staying whole (2 rows: the second, the first) | written after the factory; red under mutant 1, crash | mutant 6, assertion, 2 of 2; mutant 2, 1 of 2 |
| a layout whose tab page was closed opens in the current tab, leaving the first one's tab alone | red, assertion (an extra buffer in the tab) | mutant 1, assertion |
| a layout whose tab page was closed has no window to toggle the line numbers of, and raises nothing | arrived green: the guard in `toggle_claude_numbers()` is the code of today | mutant T1, assertion |

Two cases were written after the factory and not seen red before it (the third layout, the wiped-terminal pair); each was seen failing under mutant 1, the stub's equivalent, before the mutants were run.

## Mutants

Each mutant is its literal edit to `lua/aineo/layout/init.lua`, applied to a copy and restored (`cmp` against the saved file after the last), run on `tests/test_layout_copies.lua` with the file built as at the head (34 cases). The numbering follows `plan.md` › *Verification mutants* › T60 for 1–3.

| Mutant (the literal edit) | Result |
|---|---|
| 1. in `M.new()`, after `layouts_made = layouts_made + 1`: `if true then return M end` | killed: 23 of 34, 14 by assertion and 9 by crash (the table above) |
| 2. in `M.new()`, `('aineo.layout.%d'):format(layouts_made)` → `'aineo.layout'` | killed by assertion: 6 (*proportions*, *first one's Input scratch*, *second one's Input scratch*, *file in the first one's Input*, *Terminal mode, first*, *wiped, first*); 5 before the wiped pair existed |
| 3. in `layout_tab()`, `return vim.api.nvim_win_get_tabpage(existing_windows()[1])` → `return vim.api.nvim_list_tabpages()[1]` | killed by assertion: 1 (*proportions*) in the first round; its file-column survivor was a gap in the cases, not a clean absence (fix round, below) |
| 3b. in `role_of()`, the final `return nil` → `return 'input'` (a layout takes any window for its Input's): the form plan mutant 3 takes in this design, where no table of layouts exists for a handler to look through | killed: 20 (18 in the first count, 20 in the reviewer's re-run and mine after it), among them *a file opened in the second one's Input goes to the file column of its tab* by assertion (the file lands beside the first layout's Claude window) |
| 4. in `M.new()`, `('aineo://input-%d'):format(layouts_made)` → `'aineo://input'` | killed by assertion: 7 |
| 5. in `M.new()`, the line `layouts_made = layouts_made + 1` deleted | killed by assertion: 1 (*a third layout*); a second layout alone survives it |
| 6. in `close_claude_window_when_wiped()`, `if true then return end` first | killed by assertion: 2 of 2. Run before the cases unlisted the other buffers (`UNLIST_BUT`) it survived: Neovim itself closed the window while another buffer was listed, so the first form of the case pinned Neovim and not the handler |
| A. in `M.new()`, `if true then return {} end` | killed by assertion: 33 of 34, among them the 8 function rows; *gives a layout of its own on each call* survives it (`{} ~= {}`) and is killed by 1 |
| S1. in `show_diff()`, `if has_any_window() then` → `if false then` | killed by assertion: 1 |
| N1. in `toggle_claude_numbers()`, `show_claude_numbers(state.windows.claude)` → `show_claude_numbers(vim.api.nvim_get_current_win())` | killed by assertion: 2 |
| F1. in `keep_claude_window_on_entry()`, the line `keep_claude_statusline()` deleted | killed by assertion: 1 (*status line*) |
| T1. in `toggle_claude_numbers()`, `if not has_window_and_buffer('claude') then` → `if false then` | killed by assertion: 1 |
| I1. in `leave_terminal_mode_as_claude_exits()`, `if event.buf == state.buffers.claude and event.buf == vim.api.nvim_get_current_buf() then vim.cmd.stopinsert() end` → `do end` | killed by assertion: 2 (both *Terminal mode* cases) |

Not covered by a case, named for the reviewers: `follow_claude_terminal()`'s own `state.buffers.claude = terminal` for a second layout (the status-line case reaches it only through `keep_claude_statusline()`), and a handler's behaviour after its layout's tab closed beyond doing nothing.

## Suites

All on Neovim 0.12.5, on the host, from the tree pushed (`lua/aineo/layout/init.lua` and `tests/test_layout_copies.lua` unchanged since the run; this note was written while it ran). The host's load average was 10 on 10 cores, so the whole suite ran as `AINEO_TEST_JOBS=4 AINEO_TEST_RUN_LIMIT_MS=2700000 make test`.

- `make test`: 3228 cases in 88 files, `Fails (0) and Notes (0)`; the make exit status was not captured, the summary was read.
- While working: `tests/test_layout_copies.lua` 34 cases, 0 fails; `tests/test_layout_tabs.lua` 5; `tests/test_layout_file_column.lua` 57; `tests/test_layout.lua` 44; `tests/test_layout_panes.lua` 42; `tests/test_layout_input.lua` 9 — all 0 fails, none edited.
- `make lint`: StyLua check clean, selene 0 errors, 0 warnings, 0 parse errors.
- The deep-`require` check prints no line outside a home; `lua/aineo/layout/init.lua` requires `aineo.layout.columns`, inside its own home.

## Open threads

- A closed tab's layout rebuilding itself in the current tab (attack 2 of the review): any call of a layout whose tab page closed — `open()`, `focus()`, `show_pane()`, `focus_pane()` — builds it in the current tab and hides that tab's other windows, the windows of another layout included; `show_diff()` of one opens a window above the current one. T66 must route every call to the current tab's layout, never call a closed one, and decide what the module's own layout becomes once tab 1 closes (A261; written into T66's dispatch).
- Opening a layout in a tab closes the tab's other windows but floating ones (as today): opening the second layout in the first one's tab hides the first one's windows. Which tab a layout opens in is T66's.

## Fix round (review of PR #205)

The orchestrator's rulings below are assumptions under the user's instruction of 2026-10-06, not the user's decisions.

| Finding | What was done |
|---|---|
| Attack 1 — no way to let a layout go (A258) | `let_go()` on a layout `new()` made: deletes its handler group (`pcall(nvim_del_augroup_by_name, …)`) and wipes its Input. The module's layout has none. Case *a layout let go* (3 cases). |
| Attack 3 — a reloaded module's `new()` adopts a live layout's Input and handlers (A259) | `new()` skips any number whose group `aineo.layout.<n>` exists (`has_group()`). Case *a layout made after the module was loaded again*. |
| Attack 4, tests F2 — plan mutant 3 survived the file-column cases; A260 | Cases *the file column of the second layout* (a second file opened in its Input reuses the column's window; a file opened while the first layout has a file column of its own) and a case on `columns.windows_between()` through the child (`require('aineo.layout.columns')`, as the changes suites reach their files; no other test reaches the layout home's file). `deepest_row_holding()` starts from `tree` only when it holds every window held, so no windows come back when no row holds them, as its docstring says. |
| Tests F1 — five handlers of a `new()` layout pinned by no case | Cases *the proportions of the second layout* (tab entered, editor resized, window of a file column closed) and *the Claude terminal of the second layout* (Terminal mode refused once the process is gone; once its end was seen, with `vim.uv.kill()` answering that the id still runs). |
| Tests F3–F6 — figures, count, PR field, literal I1, two docstrings | Fixed above and in the PR body; the header docstring names `aineo://input` and `aineo.layout`; `M.open`'s says "named by `input_name`" and "so named". |
| Attack 2 — a closed tab's layout rebuilding in the current tab (A261) | No change here; T66's. |

New cases, red first (against the head of the first round): the 3 *let go* cases (2 by a Lua error on the missing `let_go`, 1 by assertion), the reload case (assertion: the new layout's Input was the second layout's), the 2 `windows_between` rows (assertion: `{ 1001, 1002 }` against `{}`). The rest arrived green and are pinned by a mutant each.

| Mutant (literal edit to `lua/aineo/layout/init.lua` unless said) | Result on `tests/test_layout_copies.lua` (47 cases) |
|---|---|
| 3 (plan). `layout_tab()`: `return vim.api.nvim_win_get_tabpage(existing_windows()[1])` → `return vim.api.nvim_list_tabpages()[1]` | killed by assertion: *takes a second file opened in its Input in the window of the first* (1). With the hardening of `columns.lua` reverted too (`local node = tree`): 9 killed, the cross-tab case among them by a Lua error only |
| VR-c. `vim.api.nvim_create_autocmd('VimResized', { group = group, callback = keep_proportions })` → `callback = function() if group_name == 'aineo.layout' then keep_proportions() end end` | killed by assertion: *are put back as the editor is resized* |
| TT-c. the same for `'TabEnter'` | killed by assertion: *are put back when its tab is entered* |
| W-c. `vim.schedule(keep_proportions)` → `vim.schedule(function() if group_name == 'aineo.layout' then keep_proportions() end end)` | killed by assertion: *are put back as the window of a file column closes* |
| TE-c. `{ group = group, callback = refuse_terminal_mode_once_claude_exited }` → `callback = function(e) if group_name == 'aineo.layout' then refuse_terminal_mode_once_claude_exited(e) end end` | killed by assertion: both *Terminal mode* cases |
| TC-c. `{ group = group, callback = remember_claude_exit }` → the same shape | killed by assertion: *once its process ended and was seen to* |
| L1. delete `pcall(vim.api.nvim_del_augroup_by_name, group_name)` | killed by assertion (*leaves no handler group…*) |
| L2. delete the `if has_input() then … nvim_buf_delete … end` of `let_go()` | killed by assertion (same case) |
| L3. delete `layout.let_go = let_go` in `M.new()` | killed: the *offered by* case by assertion, the two others by a Lua error |
| L4. add `M.let_go = let_go` in `make_layout()` | killed by assertion (*is offered by the layouts new() makes, not by the module*) |
| L5. `nvim_del_augroup_by_name, group_name` → `'aineo.layout'` | killed by assertion (*leaves the first one redirecting…*) |
| R1. `new()`: the `repeat … until not has_group(…)` → `layouts_made = layouts_made + 1` | killed by assertion (the reload case) |
| `columns.lua`: `local node = holds_all(tree, windows) and tree or nil` → `local node = tree` | killed by assertion (both `windows_between` rows) |

Not killed by an assertion: the cross-tab file-column case (*takes a file opened in its Input while the first layout has a file column of its own*) fails under mutant 3 plus the reverted hardening only by a Lua error; with the hardening in place mutant 3 is harmless to it (the second layout's windows are no row of tab 1's tree), and the case that kills mutant 3 is the reuse case.

Suites after the fix round: `AINEO_TEST_JOBS=4 AINEO_TEST_RUN_LIMIT_MS=2700000 make test` on Neovim 0.12.5, on the host, from the tree pushed: 3241 cases in 88 files, `Fails (0) and Notes (0)`, make exit status 0 (a first run was cut by the laptop's suspension, its files reporting that they never started, and was discarded); `tests/test_layout_copies.lua` 47 cases; `make lint` clean.

## Task lines

- T60 `[X]` (`feature/t60-layout-copies`, into `dev`) — one layout per tab page (C2, C9, C12; D63): `aineo.layout.new()` makes a layout of its own — its three windows, Input (`aineo://input-<n>`), file column, pane, proportions, Claude's line numbers and status line, and its handlers (group `aineo.layout.<n>`), and a `let_go()` that removes the handlers and wipes the Input — the module serving as the first layout, so no caller and no suite moved. O4 and O5 are the orchestrator's assumptions (A234–A255), not the user's decisions.

## Commits

- PR #205, `feature/t60-layout-copies`, head `ea12e54` (2 commits), merged by rebase into `dev` as `ac29341` (a layout per tab page through `new()`), `5942eba` (let a `new()` layout go; the fix round's test gaps).
- Released in v0.2.34 (PR #214, `main` `8fe30d0`).
