**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D68 and for the recommendations O4, O5 and O7–O12 of `plan.md` in this folder. **It is dispatched once T66 has merged.** Your first commit re-checks every fact below against the `dev` you start from. A fact that moved is a dated amendment, which the orchestrator writes at the end of this brief before dispatch (A163), and the amendment wins over the body. A fact you find moved after dispatch is a spec conflict for your report.

## Objective

The task, verbatim from the task list:

> | T69 | The terminal pane and the shell home (C12; D18, D68): `aineo.layout` gains a third pane, `terminal`, the tab's shell in the Report's window over Input, switched in place as the other two; the agent pane shows again when the shell ends or its buffer is wiped, the Report's window reopened in place when the wipe closed it; a new `lua/aineo/shell/` starts `'shell'` in an unlisted terminal of its own, in the directory it is given, with `AINEO_CHILD` set, wipes it when the shell ends, and stops it when let go, one copy per tab through `new()`; no key yet, and no behaviour change for the user | T60, T66 | planned — wave 16 |

It rests on:
- **D68**, the user's decision of a shell terminal as a third pane, persistent until closed, wiped on close with the agent pane shown again, one per tab;
- D18 (its windows and sizes stay put), D59 (the landing), D25 (Claude's terminal at its end), D63 (one copy per tab);
- C2, C12; C8, D10, D26, D29.

### The behaviour — one test each, seen failing first

**The layout's third pane (`lua/aineo/layout/init.lua`)**

1. `show_pane('terminal', arrangement)` shows the shell's terminal, the arrangement's new `shell` buffer, in the Report's window. Input stays in Input's window. The windows stay, by window ID, at their sizes (D18), and the cursor stays where it was. A layout copy (`new()`) does the same in its own tab.
   - The arrangement's `shell` is optional. Without it, the layout keeps the shell handed last, as it keeps the changes pane's buffers.
   - Asked for the terminal pane with no live shell handed, it raises an error naming `arrangement.shell` after opening the layout and before switching anything, as it does for `arrangement.changes`.
   - The validation's words become `'agent', 'changes' or 'terminal'`.
2. `focus_pane('terminal', …)` lands the cursor in the shell's window, the Report's (D59). It enters no mode. Terminal mode is the composition root's (T70).
3. Each switch among the three panes works in place, in each direction. The view each buffer had comes back with it, as it does between two panes today. The agent pane shown again wraps the Report and Input. A report that arrived while the terminal pane showed is followed when the Report shows again, as under the changes pane.
4. Asked for the pane it shows, the layout changes nothing. Input in Input's window under the terminal pane is that pane's own buffer, not a stray buffer of the agent pane. `OTHER_PANE` and `shows_a_buffer_of()` assume two panes, so generalize them: a window showing a buffer that is `pane`'s own there is never a reason to switch again (mutant 5).
5. `focus('input', …)` under the terminal pane moves the cursor to Input and leaves the shell shown (O5). `focus('report', …)` shows the agent pane first, as under the changes pane. `focus('claude', …)` leaves the pane.
6. When the shell ends while it shows, by `exit` with any status, the layout shows the agent pane in place before the buffer goes. The Report's window stays the same window (Q8; mutant 2).
7. When the shell's buffer is wiped while the terminal pane shows, by Neovim's own handler on `exit` 0 (Q1), `:bdelete!` or `:bwipeout!` (Q4, Q5), Neovim has closed the Report's window before any buffer event (Q7). The layout then shows the agent pane, with the Report's window reopened in its place above Input and the proportions put back. It raises nothing (mutant 1).
8. In 6 and 7, the cursor lands in the Report when it was in the shell's window. Otherwise it stays where it is, in whichever window and tab page.
9. A shell's end or wipe while another pane shows changes no window. The layout forgets that shell, so a later `show_pane('terminal')` with no new shell handed raises as in 1.
10. `open()` while the terminal pane is the pane shown, its shell alive, shows the shell again. With its shell gone, it opens on the agent pane.
11. Each layout copy reacts to its own shell's end and wipe only. Ending tab 2's shell leaves tab 1's terminal pane as it is.

**The shell home (`lua/aineo/shell/`, new)**

12. `require('aineo.shell')` is one copy, the first tab's. `new()` gives another, whose functions are called as fields, like wave 15's homes (A237). Each copy has at most one shell.
13. `start(settings)` starts the shell when none lives, and returns its buffer:
    - the command is `'shell'`, run as `:terminal` with no argument runs it (O8);
    - its directory is `settings.cwd` (Q10);
    - its environment is the editor's own, with `AINEO_CHILD=1` added (O10, Q9);
    - its buffer is unlisted, as Claude's terminal is (R3), and kept while hidden (`'bufhidden'` `hide`), whatever the user's `'hidden'`;
    - it is started without being shown, and the composition root shows it.

    While the copy's shell lives, `start()` returns the same buffer and starts nothing (mutant 4).
    - It raises an error naming `'shell'` and the program when that program is not executable, and starts nothing.
    - A `settings.cwd` that is not an existing directory raises an error naming `settings.cwd`.
14. `shell_buffer()` gives the copy's live shell buffer, or `nil`.
15. When the shell's job ends, with any status, the copy wipes its buffer, deferred past the `TermClose` that told it (O12, Q2, Q3), so that the layout's own handler (6) runs first. A buffer that Neovim's handler, `:bd!` or `:bw!` wiped already is simply forgotten. Nothing raises.
16. `stop()` stops the shell's job and wipes its buffer at once, for a tab's close (O13). With no shell, it does nothing. `let_go()` on a copy stops it and removes its handlers.
17. Two copies' shells are two jobs and two buffers. Each copy's handlers act on its own buffer only, and their autocommand groups have names of their own per copy.

### Facts, checked on `dev` `e05a1e3` — re-check them

- `lua/aineo/layout/init.lua` (1558 lines):
  - `make_layout(input_name, group_name)` makes each layout, and `M.new()` (1548) gives copies. Their handlers are in `watch_windows()` (882).
  - `PANE_BUFFERS` (133), `OTHER_PANE` (1075), `shows_a_buffer_of()` (1082), `switch_pane()` (1129), `can_show_in_place()` (1158), `show_pane()` (1354), `PANE_LANDING` (1379), `focus_pane()` (1392), `focus()` (1303) with `must_open_to_focus()` (1280), `take_arrangement()` (919), `reopen_closed_windows()` (722) and `wrap_agent_pane()` (302).
  - The `Pane` alias is `'agent'|'changes'`, and the `Arrangement` class has no `shell`.
- `lua/aineo/claude/init.lua`: `CHILD_ENVIRONMENT` (40) and `run_in_terminal()` (246) start Claude's terminal job in an unlisted buffer through `nvim_buf_call()`. That is the pattern to follow, not a module to require: the shell home requires no other aineo home.
- `tests/test_layout_panes.lua` pins today's two-pane rules, and they stay true. `tests/test_layout_copies.lua` pins the copies.
- Evidence: `evidence/w16-probes.txt` › Q1–Q10. Q1 is the trap: Neovim's own `TermClose` handler deletes the buffer before aineo's `TermClose` runs, when the command is `'shell'` exactly and the status is 0.

**Test isolation.** The suites isolate `XDG_*`, not `HOME`, so a test shell must never be the user's interactive shell with its startup files. Set `'shell'` in each test to `sh` or a fixture script under `tests/`, and check the end, the wipe and the directory with that. Never run the real `claude`.

### Baseline

The dispatch message pastes the counts of the test files you run, measured on the `dev` you start from.

Read first:
- `plan.md` in this folder (*The model*, *Measured before planning*, O4, O5, O7–O12);
- the v1 plan note's D18, D59, D63 and **D68**, and C12;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t69-terminal-pane` from `origin/dev`, once T66 has merged.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t69_terminal_pane`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/layout/init.lua`;
  - a new `lua/aineo/shell/`;
  - new `tests/test_layout_terminal_pane.lua` and `tests/test_shell.lua`, and `tests/test_layout_panes.lua` and `tests/test_layout_copies.lua` where a pin moves;
  - your session note.
- **You must not touch:**
  - `plugin/aineo.lua`, `lua/aineo/health.lua` and `doc/aineo.txt`, which T67, T68 and then T70 change;
  - every other home under `lua/aineo/`;
  - `tests/helpers/` (put what you need in your new test files);
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Keep the interfaces.** Every export of `aineo.layout` keeps its name, its arguments and its promises for the two panes of today. Update the module's header and each changed function's docstring for the third pane. Give `aineo.shell` a header docstring saying its one concern.
- **Session note:** `knowledge-vault/Sessions/<date> — T69 Terminal pane.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t69-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run the test files you touch, plus `tests/test_layout_tabs.lua`, `tests/test_layout_file_column.lua` and `tests/test_layout_proportions.lua`.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on their covering files.

## What was decided already

- **The user's decision, 2026-10-14 (D68):** a third pane in the right column, like `\pa` and `\g`, persistent until closed, destroyed on `exit` or `:bd` with the agent pane (the Report) shown again, one per tab. The words are quoted in `plan.md` › *The user's words*.
- **The orchestrator's assumptions:** O4 (the Report's window, Input below), O5 (`\i` leaves the shell shown), O7 (a new shell home), O8 (`'shell'`, unlisted), O9 (the directory the composition root gives), O10 (`AINEO_CHILD`), and O12 (every end shows the agent pane). Record them in the session note and the pull request as the orchestrator's rulings, never as the user's.
- **Rejected:** the whole column for the shell (O4 (b), against D18); the shell in the layout or the Claude home (O7 (b), (c)); a non-zero exit left on screen (O12 (b)).
- **Not yours:** the key, Terminal mode on arrival, the tab's close, the health check and the help (T70).

## Budget

Medium: a third pane in one home and a small new home, with about twenty new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial: the shell home first, then the pane, then its end.

## Report

Write it in your definition's shape, to `<scratchpad>/t69-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- the shell home's interface, exactly as T70 will call it;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s T69 mutants. Name the test that kills each.

## The orchestrator's rulings — 2026-10-14, before dispatch

`plan.md` › *The orchestrator's rulings* rules O1–O14 as their (a), A279–A292, which this brief is written for. Record them as the orchestrator's assumptions, never as the user's decisions. Your first commit is a dated amendment re-checking this brief against the `dev` you start from.

## Amendment — 2026-10-15, at dispatch

Written by the implementer at dispatch, as A256 and A278 did for wave 15. The assumptions named here are the orchestrator's, never the user's decisions. This amendment wins over the body.

- **The facts since `e05a1e3`.** `dev` at `1f771ea` holds wave 15's stage 2 (T66, tabs, with its fix round) and T71. None of the brief's facts moved:
  - `lua/aineo/layout/init.lua` still has 1558 lines, and every line the brief gives holds: `make_layout()` (64), `PANE_BUFFERS` (133), `wrap_agent_pane()` (302), `reopen_closed_windows()` (722), `watch_windows()` (882), `take_arrangement()` (919), `OTHER_PANE` (1075), `shows_a_buffer_of()` (1082), `switch_pane()` (1129), `can_show_in_place()` (1158), `must_open_to_focus()` (1280), `M.focus()` (1303), `M.show_pane()` (1354), `PANE_LANDING` (1379), `M.focus_pane()` (1392), `M.new()` (1548). The layout's last commit is `5942eba`: T66 did not change it. The `Pane` alias is still `'agent'|'changes'`, and `Arrangement` has no `shell`.
  - `lua/aineo/claude/init.lua` still has `CHILD_ENVIRONMENT` (40) and `run_in_terminal()` (246).
  - The baseline, measured on this tree on Neovim 0.12.5 (all files green): `tests/test_layout_panes.lua` 42 cases, `tests/test_layout_copies.lua` 47, `tests/test_layout_tabs.lua` 5, `tests/test_layout_file_column.lua` 57, `tests/test_layout_proportions.lua` 25.
- **What T66 handed over** (its amendment and corrections, A258, A261, A299, A305). The shell home follows the shape of the other homes: a copy per tab through `new()`, a `let_go()` on copies that stops the shell and removes the copy's handlers, and `stop()`, which T70 calls from the tab's close. The module's own copy serves the first tab for the editor's life and has no `let_go()`, as the claude, report, draft and changes homes' modules have none (A299: the first tab's homes are reused, so a closed first tab leaves its copy empty through `stop()`, not retired). The pane's calls reach the current tab's layout, and that routing is the composition root's, so T69 changes none of it.
- **The brief's text, read with the dispatch.** Two sentences are read as follows, and neither changes what is built:
  - Mutant 2 (the agent pane not put back before the shell home's wipe) can be killed only with the shell home and the layout together. The layout's cases start their shell through the shell home, and `a shell that ends while the terminal pane shows › gives the Report's window back…` is the one that kills it.
  - Mutant 5 (Input taken as the agent pane's buffer in the in-place check) is pinned by a case in which the user has put a buffer of their own in the Report's window under the terminal pane and asks for the terminal pane again: the buffer must stay. The case also asserts that Input's window and view are unchanged.
- **The boundary stands:** `plugin/aineo.lua` is untouched by T69.
