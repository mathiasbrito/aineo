**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and the *What bites here* and *Tests* sections of `.claude/agents/neovim-lua-developer.md`.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D73, for the recommended answers U1 (a), U2 (a) and U3 (a), and for O4–O10 and O13 (a) of `plan.md` in this folder. **It is dispatched once T74 has merged.** Before dispatch the orchestrator writes a dated amendment at the end of this brief for each fact that moved, and for any answer or ruling other than (a). The amendment wins over the body.

## Objective

The task, verbatim from the task list:

> | T75 | The tab activity in its homes (C1, C3; D73, proposed): `aineo.claude` keeps on each Claude terminal whether its Claude Code is busy, from the glyph its title begins with (◐ or ◑ busy, anything else not), not busy before the first title and after the exit; `aineo.tabs` keeps each held tab's activity — busy, or unseen when it stopped being busy while its tab page was not the current one, until the tab is marked seen — and draws it after the title, ◒ and ◓ alternating twice a second while busy and ● while unseen, with one timer for the editor that runs only while a tab is busy; the fake `claude` gains a mode whose title shows Claude Code 2.1.301's busy glyphs; no wiring yet, and no behaviour change for the user | T65, T33, T74 | planned — wave 17 |

It rests on:
- **D73**, the user's decision of an activity indicator, ◒ and ◓ alternating while active, nothing when nothing is new;
- D63, D64, **D69** (the title `<number>: <session name>`), D71 (the tab line's groups);
- C1, C3; C8, D10, D26, D29.

### The behaviour — one test each, seen failing first

**`aineo.claude`: busy (O4, O5)**

1. `b:aineo_session_busy` of a Claude terminal is `true` while its `b:term_title` begins with ◐ (U+25D0) or ◑ (U+25D1), followed by a space or nothing (mutant 1). Write it in the same watcher that keeps `b:aineo_session_name` (`lua/aineo/claude/session_name.lua` › `watch_title()`, `keep_name()`).
2. It is `false` for every other title: `✳ <name>`, a name with no glyph, an empty title, and the terminal's own `term://…` name. It is also `false` from `keep_name_and_folder()` on, before any title.
3. It is set only when its value changes, as `keep_name()` sets the name. A title alternating ◐ and ◑ writes `true` once.
4. `forget_name()`, at every exit (A19), sets it `false` (mutant 2). That covers a Claude Code killed or hung up while busy, whose last title stays.
5. `b:aineo_session_name` is unchanged by all of this: `◐ <name>` and `◑ <name>` give `<name>` (A2 measured that they already do; pin it).

   Test through `require('aineo.claude')`, as `tests/test_claude.lua` › *the session's name* does: a `sh` script of the test's own sets titles (`IDLE_SCRIPT`, `start_idle_session()` there).

**`aineo.tabs`: activity (O6)**

6. `set_busy(tab, busy)` tells the tabs home whether the held tab page `tab` is busy. `activity(tab)` gives `'busy'`, `'unseen'` or `nil`. `mark_seen(tab)` tells it the tab was seen. These names are the brief's proposal: choose others if the code reads better, and say so.
   - A tab told busy has `'busy'`.
   - A tab told not busy after busy, while it is not the current tab page, has `'unseen'`.
   - In the current tab page it has `nil` (mutant 3).
7. `'unseen'` stays until `mark_seen(tab)`, then `nil`. A tab that becomes busy again is `'busy'`, and `'unseen'` again only if it ends away from the current tab page.
8. A tab page not held has no activity, and `set_busy()` on it changes nothing. `let_go(tab)` and `closed()` forget the activity of the tabs they let go (mutant 5).
9. Arguments are checked with `vim.validate()`, as `hold()` checks its own.

**`aineo.tabs`: the title (O8, O9, O10; U2 (a))**

10. A held tab's title is `<number>: <name>` with nothing after it while it has no activity. That is D69's form, unchanged; pin the existing *title()* cases.
11. While busy, the title is `<number>: <name> ◒` or `<number>: <name> ◓`, by the editor's one frame. While unseen it is `<number>: <name> ●`. The indicator comes after the cut name: a 60-cell name gives its 23 cells, `…`, a space and the indicator.
12. The tab line (`tabline()`) draws the indicator in the title's own group, and its fit counts the indicator's cells (`width_of()` measures the whole title already). `require('aineo').tab_title({n})` gives the same text. Update its docstring in `lua/aineo/init.lua`.

**`aineo.tabs`: the timer (O7)**

13. While at least one held tab is busy, one `vim.uv` timer for the editor flips the frame every 500 ms and redraws the tab line (`:redrawtabline`, on the main loop). Pin it with a bounded wait for the other glyph.
14. When no held tab is busy (each told not busy, let go, or closed), the timer stops (mutant 4). The count of active `vim.uv` timers is then what it was before the first tab became busy (`vim.uv.walk()`). A second busy tab starts no second timer.
15. A change of activity redraws the tab line at once, without waiting for a tick.

**The fake (O13)**

16. `tests/helpers/fake_claude.lua` gains the mode `busy-title`, for T76's entry tests:
    - it draws the startup screen as `ready` does, which titles the terminal `✳ Claude Code`;
    - it titles the terminal `◐ Claude Code` and `◑ Claude Code` alternately, with OSC 0 as the recordings do;
    - it goes back to `✳ Claude Code` after a time an environment variable sets (name it beside `AINEO_FAKE_CLAUDE_EXIT_CODE`), or on Enter.

    Its docstring cites `knowledge-vault/Implementation/Waves/00017-tab-activity/evidence/w17-claude-title.txt` (B1, B2), Claude Code 2.1.301, read from the binary and never recorded. It is synthetic, as the fixtures named `synthetic-*` are. Pin the mode with one case, in the suite that pins the fake's other modes, if one does.

### Facts, checked against `dev` `42b6b4c` — re-check them at dispatch

- `lua/aineo/claude/session_name.lua` (187 lines):
  - `without_status_glyph()` strips one non-letter, non-digit first character followed by a space;
  - `keep_name()` writes `b:aineo_session_name` on a change only, and schedules `redrawstatus!`;
  - `watch_title()` adds the dictionary watcher on `b:term_title`;
  - `forget_name()` and `keep_name_and_folder()` are the home's calls (`lua/aineo/claude/init.lua` lines 457 and 519).
- `lua/aineo/tabs/init.lua` (269 lines):
  - `name_of_held` keyed by tab page handle; `hold()`, `let_go()`, `held()`, `closed()`, `number()`, `title()`, `tabline()`;
  - `title()` is `('%d: %s'):format(number, titles.cut(name))`;
  - the home requires `aineo.config` alone, as the direction table of `.claude/skills/modularity/SKILL.md` allows it; keep it so.
- `lua/aineo/tabs/tabline.lua` › `width_of()` measures each title with `nvim_strwidth()`. `lua/aineo/tabs/titles.lua` › `cut()` counts the name alone (24 cells).
- `lua/aineo/init.lua` › `tab_title()` returns `require('aineo.tabs').title()`.
- Evidence:
  - `evidence/w17-claude-title.txt` B1–B4: the glyphs, busy and waiting, the frozen frame, the multiplexer;
  - `evidence/w17-probes.txt`:
    - A1: ◒ and ◓ are one cell whatever `'ambiwidth'` says, ● two under `double`; none of the six glyphs is a letter or a digit (`charclass()` 1 or 3);
    - A2: a hidden terminal's title changes reach the watcher;
    - A4, A5: a tab-line redraw costs 45–60 µs, and the timer 0.35 ms of CPU per tick.

**Test isolation.** Never run the real `claude`; the suites' `PATH` guard stops a bare `claude`. Title scripts are `sh` scripts under the test's fixture directory. Every wait is bounded (`vim.wait` or the helpers' timed attempts). A timer test does not depend on the host's load beyond a bound of a few frames.

### Baseline

The dispatch message pastes the counts of `tests/test_claude.lua`, `tests/test_tabs.lua` and `tests/test_tabs_highlights.lua` on the `dev` you start from.

Read first:
- `plan.md` in this folder: *Feasibility*, *The model*, U1–U3, O4–O10, O13;
- the v1 plan note's **D73**, D69 and D71, and C1 and C3;
- `knowledge-vault/Learnings/Claude Code sets its terminal title by OSC 0 and clears it when it exits.md`;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t75-tab-activity-homes` from `origin/dev`, once T74 has merged.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t75_tab_activity_homes`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/claude/session_name.lua`, and the docstrings of `lua/aineo/claude/init.lua` that describe the terminal's `b:` variables;
  - `lua/aineo/tabs/init.lua`, `lua/aineo/tabs/titles.lua`, and a new file in `lua/aineo/tabs/` for the activity and its timer;
  - `lua/aineo/init.lua`: `tab_title()`'s docstring;
  - `tests/helpers/fake_claude.lua`, **additions only**; run every test file that requires it;
  - new `tests/test_claude_busy.lua` and `tests/test_tabs_activity.lua` (or new sets in `tests/test_claude.lua` and `tests/test_tabs.lua`, if that reads better), and `tests/test_tabs.lua` where a pin moves;
  - your session note.
- **You must not touch:**
  - the composition root (`plugin/aineo.lua`, `lua/aineo/entry/`), which is T76's;
  - `lua/aineo/health.lua` and `doc/aineo.txt`, which are T76's. The help describes nothing the user can see before T76;
  - every other home, and `lua/aineo/config/`, since no setting is added;
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **No new edge between homes:** `aineo.tabs` still requires `aineo.config` alone, and `aineo.claude` requires nothing new. Print and list §1's deep-require check in your pull request.
- **Session note:** `knowledge-vault/Sessions/<date> — T75 Tab activity homes.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t75-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run the test files you touch, plus `tests/test_claude.lua`, `tests/test_tabs.lua`, `tests/test_tabs_highlights.lua`, and every file that requires `tests/helpers/fake_claude.lua` once you have changed it.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on their covering files.

## What was decided already

- **The user's decision, 2026-10-15 (D73):** an activity indicator on the tab, ◒ and ◓ alternating while the agent or its subagents are active, nothing when nothing is new, if it costs the editor nothing to speak of. The words are quoted in `plan.md` › *The user's words*.
- **The user's answers** U1–U3, as the dispatch's amendment gives them. This body is written for the (a)s:
  - ● for unseen output;
  - the indicator after the name;
  - no multiplexer fallback.
- **The orchestrator's assumptions:** O4–O10 and O13. Record them in the session note and the pull request as the orchestrator's rulings, never as the user's decisions.
- **Rejected:**
  - any first glyph but ✳ as busy (O4 (b));
  - Claude Code's own frames as the clock (O7 (c));
  - `on_lines` for unseen text (`evidence/w17-probes.txt` A3).

## Budget

Medium: two homes with about twenty new cases, and one fake mode. If it grows past that, stop at a green, reviewed, pushed state and report a true partial: the busy reading first, then the activity and the title, then the timer, then the fake.

## Report

Write it in your definition's shape, to `<scratchpad>/t75-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- each test file whose pins moved, and why;
- the whole suite's counts;
- the deep-require check's output.

The orchestrator's verification runs `plan.md`'s T75 mutants. Name the test that kills each.
