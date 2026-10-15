**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D68 and for the recommendations O6, O9–O11, O13 and O14 of `plan.md` in this folder. **It is dispatched in stage 2, once T69, T67 and T68 have merged** (O1). Before dispatch the orchestrator re-checks every fact below on the `dev` it dispatches on, against what T66–T69 merged, and writes a dated amendment at the end of this brief for each fact that moved (A163). The amendment wins over the body.

## Objective

The task, verbatim from the task list:

> | T70 | The terminal pane's key (C1, C7; D58, D68): `:Aineo pane terminal`, `<Plug>(aineo-pane-terminal)`, `\pt` and its twin `<C-\>pt` show the current aineo tab's shell in its terminal pane, starting it in the folder when none runs, and land in it in Terminal mode; a tab's close stops its shell; with the health check and the help | T69, T67, T68 | planned — wave 16 |

It rests on:
- **D68**, the user's decision of a shell terminal as a third pane, persistent until closed, one per tab;
- D18, D52, D53, D58, D59, D63, D66;
- C1, C7, C12; C8, D10, D26, D29.

### The behaviour — one test each, seen failing first

**The key (O6, O11)**

1. `:Aineo pane terminal`, `<Plug>(aineo-pane-terminal)`, `\pt`, and `<C-\>pt` in Terminal and Insert mode do the same thing in the current aineo tab, or from any other tab in the aineo tab used last, moving there (A238):
   - start the tab's shell when none runs (`aineo.shell`'s copy for the tab, T69), in the folder (`places.working_directory`, A241), whatever `:cd` or `:tcd` says (mutant 4);
   - show it in the tab's terminal pane through the layout's `focus_pane('terminal', …)`, opening or restoring the layout first as `\pa` does;
   - leave the cursor in the shell, in Terminal mode, as `\c` leaves it in Claude's prompt (mutant 2).
2. Pressed again while the shell runs, shown or hidden by `\pa` or `\g`, the key shows the same buffer, with its output, and starts nothing (mutant 1).
3. Every arrangement the composition root hands the layout carries the tab's live shell as `shell`, or none. So `\o` restores the terminal pane while the shell lives.
4. `:Aineo pane` completes `agent`, `changes` and `terminal`, and its usage line names all three (mutant 5).
5. The twin leaves the mode first (`LEAVE_MODE`, D58, A169), under the same skips as every twin. The key is mapped only where the user has not mapped it. No existing key changes, and `\c` still acts at once (D53).
6. When `'shell'` is not executable, the key tells the user once, with an error naming `'shell'`, and changes no pane.
7. `\pa` and `\g` while the shell shows hide it, and it runs on. `\r` shows the agent pane, `\i` moves to Input with the shell still shown, and `\c` moves to Claude (O5, T69). After the shell's `exit`, the Report is back with the cursor in it (T69). Test these through the keys.

**Tabs**

8. Each aineo tab has its own shell. `\pt` in tab 2 starts tab 2's, and leaves tab 1's shell and pane as they were.
9. A tab's close stops its shell and wipes its buffer, before the tab's Claude Code's stop (O13; mutant 3). That covers both:
   - a close by Neovim's commands (`:tabclose`; T66, A251);
   - `\Q` (T67, A250).

   The other tabs' shells run on.
10. The quit adds nothing for the shell. Neovim hangs it up (Q11, Q12), and the stop of every Claude Code is unchanged. Pin that `:qa` with a running shell quits and leaves no shell process.

**Environment, health and help (O10, O14)**

11. The autostart in a Neovim started inside the shell does not run, since `$AINEO_CHILD` is set (T69). `:checkhealth aineo`'s line for that reason names the shell beside Claude's terminal.
12. `:checkhealth aineo` lists `\pt` in *Prefix mappings* and `<C-\>pt` in *Terminal prefix mappings*. It says which shell the pane runs (`'shell'`), with a warning when its program is not executable.
13. The help:
    - *Panes* (`*aineo-panes*`): three panes; the terminal pane, its window and sizes, persistence, Terminal mode on arrival, the end by `exit` or `:bd!`, and one shell per tab;
    - COMMANDS (`:Aineo-pane`): `terminal`;
    - MAPPINGS: `<Plug>(aineo-pane-terminal)` and `aineo-\pt`;
    - *aineo-terminal-keys*: `<C-\>pt`;
    - HEALTH CHECK: the lines of 11 and 12;
    - LIMITS, a new `The terminal pane ~`: `:bd` needs `!` (E89, Q6); a `nvim` in the shell does not autostart; the next start brings no shell back; the quit ends it as Neovim ends every terminal.

    `tests/test_doc.lua` derives the tags the plugin defines. Run it.

### Facts to re-check at dispatch

Read on `dev` `e05a1e3`, before T66–T69. Use the merged names.
- `plugin/aineo.lua` (1887 lines):
  - `SUBCOMMAND_WORDS` (43), `arrangement()` (704), `focus_pane()` (768), `focus_claude()` (805), `ACTIONS` (1452), `PREFIX_KEYS` (1573), `map_terminal_prefix()` (1668) and `NOT_BARE_INTERACTIVE` (1726);
  - T66 makes these per tab and holds each tab's copies. Add the tab's shell copy to that record, so that the close of T66 and T67 lets it go.
- `lua/aineo/health.lua`: `PREFIX_KEYS` (299) and the autostart's `inside-claude` line (524).
- T69 gives `aineo.shell`'s `new()`, `start(settings)`, `shell_buffer()`, `stop()` and `let_go()`, and the layout's `terminal` pane with the arrangement's `shell`. Use what its pull request says it merged.
- Pins that list the subcommands or keys: `tests/test_entry.lua`, `tests/test_entry_panes.lua`, `tests/test_entry_prefix.lua`, `tests/test_entry_terminal_keys.lua`, `tests/test_health.lua`, and those T66–T68 added.
- Evidence: `evidence/w16-probes.txt` › Q6, Q9, Q11, Q12.

**Test isolation.** The suites isolate `XDG_*`, not `HOME`. Set `'shell'` in each test to `sh` or a fixture script under `tests/`, never the user's interactive shell. Never run the real `claude`.

### Baseline

The dispatch message pastes the whole suite's counts on the `dev` you start from.

Read first:
- `plan.md` in this folder (*The model*, O6, O9–O11, O13, O14);
- the T69 session note and pull request;
- the v1 plan note's D18, D58, D59, D63 and **D68**, and C1;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t70-terminal-pane-key` from `origin/dev`, once T69, T67 and T68 have merged.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t70_terminal_pane_key`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `plugin/aineo.lua` and `lua/aineo/health.lua`;
  - a new `tests/test_entry_terminal_pane.lua`, and the entry and health suites where a pin moves;
  - `tests/helpers/`, **additions only**; if you add to a helper, run every test file that requires it;
  - `doc/aineo.txt`: the sections named in 13, and the INTRODUCTION's list of keys;
  - your session note.
- **You must not touch:**
  - every home under `lua/aineo/`, the layout and `aineo.shell` included. If T69's merged interface lacks what you need, that is a **spec conflict** for your report, not a reason to change the home;
  - `lua/aineo/config/`, since no setting is added;
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/<date> — T70 Terminal pane key.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t70-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run the test files you touch, plus `tests/test_entry_panes.lua`, `tests/test_entry_terminal_keys.lua`, `tests/test_health.lua` and `tests/test_doc.lua`, and the tab suites T66–T68 added.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on their covering files.

## What was decided already

- **The user's decision, 2026-10-14 (D68):** a key opens a shell terminal as a third pane of the right column, like `\pa` and `\g`; it persists until the user closes it; closing it destroys the buffer and shows the agent pane again; one per tab. The words are quoted in `plan.md` › *The user's words*.
- **The orchestrator's assumptions:** O6 (the key `\pt`), O9 (the folder), O10 (`AINEO_CHILD`), O11 (Terminal mode on arrival), O13 (a tab's close stops it, and the quit adds nothing), and O14 (the health and help). Record them in the session note and the pull request as the orchestrator's rulings, never as the user's.
- **Rejected:** `\t`, which would make `\tcn` wait (O6 (c)); the window's `getcwd()` (O9 (b)); the editor's environment unchanged (O10 (b)).

## Budget

Medium: one action, its key and its twin, the tab's close, the health lines and the help, with about fifteen new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial: the key first, then the tab's close, then health and help.

## Report

Write it in your definition's shape, to `<scratchpad>/t70-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- each test file whose pins moved, and why;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s T70 mutants. Name the test that kills each.

## The orchestrator's rulings — 2026-10-14, before dispatch

`plan.md` › *The orchestrator's rulings* rules O1–O14 as their (a), A279–A292, which this brief is written for. Record them as the orchestrator's assumptions, never as the user's decisions. Your first commit is a dated amendment re-checking this brief against the `dev` you start from.
