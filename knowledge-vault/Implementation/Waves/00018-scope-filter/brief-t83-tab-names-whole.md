**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D78 and for O20–O23 (a) of `plan.md` in this folder (*Decisions for the orchestrator* › *The name cut*). Before dispatch the orchestrator writes a dated amendment at the end of this brief for each fact that moved and for any ruling other than (a). The amendment wins over the body.

## Objective

The task, verbatim from the task list:

> | T83 | A tab's name whole while the tab line has room (C1; D78): aineo's tab line draws every title whole while all fit `'columns'`; when they do not, the longest names are cut first to one cap they share, `…` included, never below 8 cells, the number, the indicator and `tabs.padding` never cut; below the floor, the run around the current tab as today; `tab_title()` gives the whole name; with the help | T72, T80 | planned — wave 18 (first) |

It rests on:
- **D78**, the user's decision: "aineo should do that only if there is no horizontal space enough" — a name is cut only when the line has no room for the names whole;
- D69 (the title, whose "cut to 24 cells" D78 supersedes), D71 (`tabs.padding`), D73 (the indicator);
- C1; C8, D10, D26, D29.

### The behaviour — one test each, seen failing first

**Whole while it fits (D78)**

1. With every title fitting `'columns'` — `<number>: <name>`, the indicator when there is one, and `tabs.padding` either side, all counted — every name is drawn whole, however long. Pin: at 200 columns, padding 2, three tabs named `session <n>, fixing the tab line` (30 cells) draw all three names whole (mutant 1).
2. A name of exactly the room left is whole: the line exactly `'columns'` wide is drawn whole, one cell less cuts.

**Cut, the longest first (O20 (a))**

3. When the whole titles do not fit, aineo cuts each name wider than one cap to that cap, as `titles.cut()` cuts today — the longest prefix of whole characters, then `…`, a wide character or a composed one never parted — and leaves every name no wider than the cap whole. The cap is the widest at which the line fits. Pin: at 80 columns, padding 2, the three 30-cell names are cut to 19 cells and all three show: `'  1: session 1, fixing …    2: session 2, fixing …    3: session 3, fixing …  '` (78 cells).
4. The room a short name leaves goes to the long ones: at 80 columns, padding 2, a tab named `a` and one named for 70 cells, the long name is cut to 65 cells (mutant 4).
5. The current tab's name counts as any other: the same pins hold whichever tab is current.
6. The padding counts: the cap at padding 0, 2 and 4 is the one that fits each (mutant 2); keep the parametrised case of `tests/test_tabs.lua` (*counts the padding in the width of the titles it fits*), its expected counts moved to what the new rule draws.
7. The indicator counts and is never cut: at 81 columns, padding 2, three 30-cell names, the last tab busy, the names are cut to 19 cells and all three titles show, the last ending ` ◒` (mutant 3). Its glyph's width is what `nvim_strwidth()` says, so `'ambiwidth'` is honoured as today.

**The floor (O21 (a))**

8. No name is cut below 8 cells, `…` included. When the titles do not fit even with every long name at 8 cells, the line draws the run of titles around the current tab that fits, as `run_around_current()` does today, each long name at 8 cells. Pin at 30 columns, padding 2, three 30-cell names, each tab current in turn.
9. A name shorter than the floor is never padded or cut: `1: a` stays `1: a` at any width.

**`tab_title()` and the title (O22 (a))**

10. `require('aineo').tab_title(n)` gives the name whole, with its indicator (mutant 5). `require('aineo.tabs').title(tab)` gives it whole too; aineo's own line does the fitting.
11. A held tab whose name function raises, or holds a NUL, still draws, as today (`tests/test_tabs.lua`, *says the buffer's tail for a held tab whose name() holds a NUL*).

### Where the code goes

- **`lua/aineo/tabs/titles.lua`**: `cut()` takes the room it cuts to (the cap), in place of the fixed 24 cells; `MAX_NAME_CELLS` goes; a floor constant comes, named for what it is.
- **`lua/aineo/tabs/tabline.lua`**: the fit — the cap from the entries, `'columns'` and the padding, then the cut names, then today's run around the current tab when even the floor does not fit. Keep it pure: entries in, a format out. An entry carries its number, its name and its indicator apart, so that only the name is cut.
- **`lua/aineo/tabs/init.lua`**: `title()` gives the whole name; `tabline()` hands the format the parts of each title. Its docstrings say so.
- **`lua/aineo/init.lua`**: `tab_title()`'s docstring alone — "cut to fit" becomes the whole name.

### Facts, checked against `dev` `2a74b16` — re-check them at dispatch

- `lua/aineo/tabs/titles.lua` (67 lines): `MAX_NAME_CELLS = 24`, `ELLIPSIS`, `longest_prefix_within()`, `cut(name)`, `buffer_tail(tab)`.
- `lua/aineo/tabs/tabline.lua` (90 lines): `aineo.tabs.TabLineEntry` (`number`, `title`, `current`), `format_of()`, `width_of()`, `run_around_current()`, `format(entries, columns, padding)`.
- `lua/aineo/tabs/init.lua` (398 lines): `title(tab)` at 230 cuts with `titles.cut()` and appends the indicator; `tabline()` at 271 builds the entries and calls `tabline_format.format(entries, vim.o.columns, padding())`; `'tabline'` is `%!v:lua.require'aineo.tabs'.tabline()`, so Neovim calls it at every redraw, a resize included.
- `lua/aineo/init.lua`: `tab_title(number)` returns `require('aineo.tabs').title(tab_page)`; its docstring says "cut to fit (`:help aineo-tabs`)".
- `doc/aineo.txt`: *aineo-tabs*, "cut to 24 cells" (around line 230); *aineo-tab_title* (line 246).
- `README.md`: names `tab_title(n)` (line 151) and `tabs.padding` (line 132), and no cut — re-check.
- Pins that move: `tests/test_tabs.lua`, the *title()* cases that cut at 24 cells (215–245, 807–816) and the *tabline()* cases over three long names (720–800); `tests/test_tabs_activity.lua`, *says the indicator after the 23 cells and the ellipsis of a cut name* (223). Each moves to the new rule, its name with it; a case about cutting moves to the line, where the cut now is.

**Test isolation.** The tab suites run in a child Neovim; set `vim.o.columns` there. Every wait is bounded.

### Baseline

The dispatch message pastes the counts of `tests/test_tabs.lua` and `tests/test_tabs_activity.lua` on the `dev` you start from.

Read first:
- `plan.md` in this folder: *The user's additions*, *Today's report server and tab line*, *The model* items 20–24, O20–O23;
- the v1 plan note's **D78**, D69, D71, D73;
- `doc/aineo.txt` › *aineo-tabs*, *aineo-tab_title*, *aineo-tabline*.

## Boundary

- **Branch:** `feature/t83-tab-names-whole` from `origin/dev`.
- **Class:** regular (O23 (a)), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it.
- **Resources:** `impl_t83_tab_names_whole`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/tabs/titles.lua`, `lua/aineo/tabs/tabline.lua`, `lua/aineo/tabs/init.lua`;
  - `lua/aineo/init.lua`: `tab_title()`'s docstring alone;
  - `doc/aineo.txt`: *aineo-tabs* (the sentence on the cut) and *aineo-tab_title*;
  - `README.md`, only where it says a name is cut;
  - `tests/test_tabs.lua`, `tests/test_tabs_activity.lua`;
  - your session note.
- **You must not touch:** every other home; `lua/aineo/config/` (no setting is added); `plugin/aineo.lua`; the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **No new edge between homes.** Print and list §1's deep-require check in your pull request.
- **Session note:** `knowledge-vault/Sessions/<date> — T83 Tab names whole.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t83-`.
- **How the suite runs (D26, D29):** on the newest Neovim release. While you work, run `tests/test_tabs.lua` and `tests/test_tabs_activity.lua`. Run the whole suite (`make test`) once before each push. Run mutants on their covering files.

## What was decided already

- **The user's decision, 2026-10-16 (D78):** "aineo should do that only if there is no horizontal space enough". The exchange is quoted in `plan.md` › *The user's additions*.
- **The orchestrator's assumptions:** O20–O23. Record them in the session note and the pull request as the orchestrator's rulings, never as the user's decisions.
- **Rejected:** the current tab's name kept whole (O20 (b)); every name cut by the same share (O20 (c)); 24 cells as the floor (O21 (b)); `tab_title()` cut to 24 cells (O22 (b)); a setting for the floor; tabs that fill the whole width, which the user tried and did not decide.

## Budget

Small: one pure fit in `tabline.lua`, a cap parameter for `cut()`, two docstrings, two help sentences, about twelve cases, most of them pins that move. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

Write it in your definition's shape, to `<scratchpad>/t83-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- each pin that moved, and why;
- the whole suite's counts;
- the deep-require check's output.

The orchestrator's verification runs `plan.md`'s T83 mutants. Name the test that kills each.
