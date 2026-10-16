**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D73, for the recommended answers U1 (a) and U3 (a), and for O6 and O10–O12 (a) of `plan.md` in this folder. **It is dispatched once T75 has merged**, which follows T74. Before dispatch the orchestrator writes a dated amendment at the end of this brief, for:
> - each fact that moved, with T74's and T75's merged names;
> - any answer or ruling other than (a).
>
> The amendment wins over the body.

## Objective

The task, verbatim from the task list:

> | T76 | The tab activity wired (C1, C7; D73, proposed): the composition root hands the tabs home each aineo tab's busy state, from every Claude terminal the tab runs, and marks a tab seen when its tab page is entered; a tab's close lets its activity go; `:checkhealth aineo` says what the indicator reads and warns where it cannot show (no title, a terminal multiplexer); with the help | T75, T74 | planned — wave 17 |

It rests on:
- **D73**, the user's decision of an activity indicator;
- D63, D64, D66, D69, D71;
- C1, C7; C8, D10, D26, D29.

### The behaviour — one test each, seen failing first

**The wiring (O6)**

1. For each aineo tab, the composition root watches `b:aineo_session_busy` (T75) of the tab's Claude terminal. On each change it tells the tabs home (`set_busy()`, or T75's merged name) for that tab's tab page (mutant 1).
   - The watch follows every terminal the tab's Claude Code runs in: the first start, a start on a new session, a replacement of the terminal, a session picked into the tab.
   - Today the root calls `redraw_tab_line_when_named()` at each of those places (`plugin/aineo.lua` lines 1118, 1204 and 1683 on `dev` `42b6b4c`). Put the busy watch beside it, wherever T74 moved it.
2. Each tab's watch reaches its own tab page alone. With two tabs, tab 2's busy Claude Code puts the indicator on tab 2's title and none on tab 1's (mutant 3).
3. Entering an aineo tab's tab page marks it seen. Add this to the `TabEnter` handler the root has (`make_editor_handlers()` on `dev` `42b6b4c`): a title ending in ● loses it (mutant 2). Entering a non-aineo tab page marks nothing.
4. A tab's close, by `\Q` or by Neovim's commands, lets its activity go with its title, through T75's `let_go()` or `closed()` (mutant 5). Once no tab is busy, no timer of aineo's runs.
5. End to end, with the fake in `busy-title` mode (T75) in tab 2 and tab 1 current:
   - tab 2's title shows ◒ or ◓, then the other, within a bounded wait;
   - once the fake's title is `✳ Claude Code` again, tab 2's title ends in ●;
   - `\2` clears it.
6. In the current tab, the same run ends with no indicator at all (O6).

**`require('aineo').tab_title()` (O10)**

7. With a `'tabline'` of the user's own, `require('aineo').tab_title({n})` gives the title with its indicator, and the tab line is redrawn while a tab is busy.

**Health (O12)**

8. `:checkhealth aineo` says, in the section that says which tab line is in use, that the indicator reads Claude Code's terminal title (`:help aineo-tabs`).
9. It warns when the editor's environment has `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` set, naming it: Claude Code then sets no title, so no tab shows activity.
10. It warns when the editor's environment has `TMUX`, `STY` or `ZELLIJ` set, naming the variable: Claude Code then keeps its title still, so no tab shows activity (U3 (a); mutant 4). Each warning tells the user what to do: the help's LIMITS entry.

**Help (O11, O12)**

11. In `doc/aineo.txt`:
    - *aineo-tabs*, after the paragraph on titles: what the indicator shows (◒ and ◓ alternating while the tab's Claude Code or a subagent works; ● when it finished while you were in another tab, until you enter it; nothing otherwise), where it sits, and that it shows from two tab pages on with the default `'showtabline'`;
    - *aineo-tab_title*: the indicator is part of the title;
    - HEALTH CHECK: the lines of 8–10;
    - LIMITS, a new `The activity indicator ~`:
      - it reads the title Claude Code 2.1.301 puts on its terminal, and a later version may change it;
      - under tmux, screen or zellij, or with `CLAUDE_CODE_DISABLE_TERMINAL_TITLE`, no tab shows activity;
      - a background shell task is not activity;
      - a question or a permission dialog ends a busy spell, so a tab waiting on you shows ●, not ◒.

    `tests/test_doc.lua` derives the tags the plugin defines. Run it.

### Facts to re-check at dispatch

Read on `dev` `42b6b4c`, before T74 and T75. Use the merged names.
- `plugin/aineo.lua` (3120 lines), which T74 moves into `lua/aineo/entry/`:
  - `redraw_tab_line_when_named()` (594), the dictionary watcher on `b:aineo_session_name`;
  - its callers (1118, 1204, 1683);
  - `make_editor_handlers()` (617) and its `TabEnter` handler (637);
  - `tab.session_name` (2103), `tab.page` and `tabs.hold(tab.page(), tab.session_name)` (2270);
  - the release of closed tabs through `require('aineo.tabs').closed()` (2243).
- `lua/aineo/health.lua`: the tab-line report (780–800), and its pin in `tests/test_health.lua` (1449, 1476).
- T75 gives `b:aineo_session_busy`, the tabs home's activity calls, and the fake's `busy-title` mode. Use what its pull request says it merged.
- Evidence: `evidence/w17-claude-title.txt` B3, B4 (the frozen frame; the multiplexer and the disabled title).

**Test isolation.** The suites isolate `XDG_*` and `CLAUDE_CONFIG_DIR`, not `HOME`, and remove every inherited `CLAUDE*` variable. A health case that needs `TMUX`, `STY`, `ZELLIJ` or `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` sets it in its child Neovim alone, and the runner's own environment never has them. Never run the real `claude`. Every wait is bounded.

### Baseline

The dispatch message pastes the counts of the test files below on the `dev` you start from.

Read first:
- `plan.md` in this folder: *Feasibility*, *The model*, U1, U3, O6, O10–O12;
- T75's session note and pull request, and T74's;
- the v1 plan note's **D73**, D69 and D71, and C1 and C7;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t76-tab-activity-wiring` from `origin/dev`, once T75 has merged.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t76_tab_activity_wiring`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - the files of `lua/aineo/entry/` that make, start, enter and close a tab, as T74 merged them, and `plugin/aineo.lua` only where T74 left this wiring;
  - `lua/aineo/health.lua`;
  - `doc/aineo.txt`: the sections named in 11;
  - a new `tests/test_entry_tab_activity.lua`, and `tests/test_health.lua` and the entry tab suites where a pin moves;
  - `tests/helpers/`, **additions only**; if you add to a helper, run every test file that requires it;
  - your session note.
- **You must not touch:**
  - every home under `lua/aineo/` but `aineo.entry`, `aineo.tabs` and `aineo.claude` among them. If T75's merged interface lacks what you need, that is a **spec conflict** for your report, not a reason to change the home;
  - `lua/aineo/config/`, since no setting is added;
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/<date> — T76 Tab activity wiring.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t76-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run the test files you touch, plus `tests/test_entry_tabs.lua`, `tests/test_entry_tab_close.lua`, `tests/test_entry_tabs_close.lua`, `tests/test_entry_claude_name.lua`, `tests/test_health.lua` and `tests/test_doc.lua`.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on their covering files.

## What was decided already

- **The user's decision, 2026-10-15 (D73):** an activity indicator on the tab, ◒ and ◓ alternating while the agent or its subagents are active, nothing when nothing is new. The words are quoted in `plan.md` › *The user's words*.
- **The user's answers** U1 and U3, as the dispatch's amendment gives them. This body is written for the (a)s:
  - ● for unseen output, cleared at `TabEnter`;
  - no multiplexer fallback, and a health warning instead.
- **The orchestrator's assumptions:** O6 and O10–O12. Record them in the session note and the pull request as the orchestrator's rulings, never as the user's decisions.
- **Rejected:**
  - clearing only when the cursor enters the Claude window (O6 (c));
  - a separate `tab_activity()` (O10 (b));
  - touching `'showtabline'` (O11 (b)).

## Budget

Medium: one watch beside an existing one, the `TabEnter` mark, two health warnings and the help, with about twelve new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial: the wiring first, then health, then help.

## Report

Write it in your definition's shape, to `<scratchpad>/t76-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- each test file whose pins moved, and why;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s T76 mutants. Name the test that kills each.

## The orchestrator's rulings — 2026-10-15, before dispatch

The user answered U1–U3 with their (a) (`plan.md` › *The user's answers*), and `plan.md` › *The orchestrator's rulings* rules O1–O13 as their (a), A354–A366, which this brief is written for. Record them as the orchestrator's assumptions, never as the user's decisions.

## Amendment — 2026-10-16, at dispatch

The packet's implementer re-checked the brief's facts against `dev` `82d3b65`, which T74 (the composition root's body, now `lua/aineo/entry/`) and T75 (the homes) have merged. This is the orchestrator's assumption, as A256 was. One fact changes where a line goes, not what is built; the rest moved by name only.

- **Where the wiring lives now** (all in `lua/aineo/entry/`; `plugin/aineo.lua` is 598 lines of registrations and holds none of it):
  - `tab.lua` › `redraw_tab_line_when_named()` (line 121), called at 603 (`on_terminal_replaced`), 689 (`begin_claude()`, which every start, a pick of `\S` and a reopening go through) and 1168 (`replace_claude_terminal()`). The busy watch goes beside these three.
  - `tab.lua` › `tab.session_name` (1588), `tab.page` and `bound_page`, and `callbacks.on_bound` (574), which `opening.lua` › `hold_tab()` answers with `tabs.hold(tab.page(), tab.session_name)`.
  - `closing.lua` › `close_tabs_of_closed_pages()` calls `require('aineo.tabs').closed()`; the `TabClosed` handler is made in `hold_tab()`.
  - `editors.lua` › `make_editor_handlers()` holds the `TabEnter` handler, but `tab.lua` › `write_entry()` makes it, and it returns before that when the panes follow no session yet or the editor has no server address.
- **T75's merged names** are the brief's: `tabs.set_busy(tab, busy)` (a boolean, else it raises), `tabs.mark_seen(tab)`, `tabs.activity(tab)`, `tabs.let_go()` and `tabs.closed()` forgetting the activity and stopping the timer, `require('aineo').tab_title()` through `tabs.title()`; `b:aineo_session_busy` on the Claude terminal; the fake `claude`'s mode `busy-title` with `AINEO_FAKE_CLAUDE_BUSY_MS`. `set_busy()` leaves a tab page that is not held or does not exist as it is.
- **Where the brief is widened, and why:**
  - the `TabEnter` mark goes in a handler of its own in `opening.lua` › `hold_tab()`, beside the `TabClosed` one, and not in `editors.lua`: the handler there may not exist yet when the first tab ends a busy spell away from the user, and then nothing would clear the ●;
  - one new file in the entry home, `busy_watch.lua`, holds the watcher on `b:aineo_session_busy`, so that `tab.lua` (1608 lines) gains calls and no logic of its own;
  - the handed items of the dispatch (A372) are built: a `BufWipeout` path for a wiped busy terminal, `change.new == true`, and the state told again at `hold()`.
- **Health:** `lua/aineo/health.lua` › `check_tab_line()` (line 757) and its pins in `tests/test_health.lua` (1443, 1453, 1464) are as the brief reads. The suites do not remove `TMUX`, `STY` or `ZELLIJ` from a case's environment, so a case of the Tab line section clears them in its child.
