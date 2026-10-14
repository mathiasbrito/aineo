**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D64 and D67 as proposed, for the user's answer U3 (a), and for the recommendations O15 and O21 of `plan.md` in this folder. If the user answered otherwise or the orchestrator ruled otherwise, a dated amendment at the end of this brief says so, and it wins over the body.

## Objective

The task, verbatim from the task list:

> | T65 | The tabs home (C1, C2; D64, D67, proposed): a new `lua/aineo/tabs/` that holds the tab pages aineo shows a session in, gives each tab's number and title — `<number> <name>`, the number its place as Neovim counts it (U3) — draws the tab line while the user's `'tabline'` is empty, finds the tabs held that have closed, and keeps per folder the ordered list of the tabs' sessions with the tab current at quit | T48 part 2 | planned — wave 15 |

It rests on:
- **D64 and D67**, proposed. The user's decision in D64 is that `\<number>` moves to the tab whose title shows that number.
- U3 (a): the number is the tab's place.
- **C1 and C2**.
- D23, D38 (the kept id per folder), T33 (the session's name).
- C8, D10, D26, D29.

### What the home must do — one test each, seen failing first

**Tabs held**

1. `require('aineo.tabs')` holds tab pages by handle. `hold(tab, name)` holds `tab`, whose title's name is what `name()` gives when the title is drawn. `let_go(tab)` lets it go. `held()` gives the held tabs that still exist, in the order of their places.
2. `closed()` gives each held tab whose page no longer exists, and lets it go, so that a second call gives none. A tab closed by `:tabclose` is found. A tab moved by `:tabmove` is not (P1: the handle stays, the number changes).
3. `number(tab)` is the tab's place, as `{n}gt` counts it (`nvim_tabpage_get_number()`), held or not. After `:tabmove 0` or the close of a tab before it, the number follows.

**Titles and the tab line**

4. `title(tab)`:
   - is `<number> <name>` for a held tab, the name being what its `name()` gives;
   - is `<number> <the current window's buffer name, its tail>` for any other tab, `[No Name]` when it has none;
   - cuts a name longer than 24 display cells to 23 cells and `…`, on a character's edge.
5. `tabline()` gives a `'tabline'` that draws every tab page's title, each in `%<number>T` click regions. The current tab is in `TabLineSel`, the others in `TabLine`, and the rest of the line in `TabLineFill`. A `%` in a name draws as written. Test it with `nvim_eval_statusline(…, { use_tabline = true })`.
6. `draw_tabline()` sets `'tabline'` to an expression that calls `tabline()` when `'tabline'` is empty, and leaves a user's own value in place. It returns whether aineo's is in use. Called again, it changes nothing. It never touches `'showtabline'` (P1: 1 by default, so the line shows from two tabs on).

**The folder's tabs (D67)**

7. `keep_tabs(state_directory, folder, tabs)` writes `tabs` for `folder`: `{ sessions = { <id>, … }, current = <place> }`. It goes into one file per folder under `<state_directory>/aineo/claude-tabs/`, named by the folder's SHA-256, readable by the user alone (0600), and written whole by a replacement that a write cut short leaves as it was. That is the way `lua/aineo/claude/session_ids.lua` writes the kept id.
8. `kept_tabs(state_directory, folder)` reads it back: the same order and the same `current`. It reads none (nil) when:
   - the file is missing, unreadable, or not that shape;
   - the list is empty;
   - any id is of another form than a lower-case version-4 UUID, since each becomes an argument to `--resume`, as D38's check says;
   - `current` is not a place in the list.

   It raises nothing.
9. Two folders keep two lists. A list kept for one folder is not read for another.

### Facts, checked on `dev` `1354cad` and `bugfix/t48-attach` `e0989f2`

- No `lua/aineo/tabs/` exists. No aineo code reads or sets `'tabline'` or `'showtabline'`, or handles `TabClosed` (`git grep -n tabline\|TabClosed -- lua plugin`). `lua/aineo/layout/init.lua` uses `TabEnter` for proportions only.
- P1 (`evidence/w15-probes.txt`):
  - a tab's handle is stable, and its number is its place;
  - `TabClosed`'s `<afile>` is the number and the handle is already invalid;
  - `{n}gt` past the last tab does nothing;
  - `'tabline'` is empty and `'showtabline'` 1 by default.
- The kept id's file and its writes: `lua/aineo/claude/session_ids.lua`.
  - `kept_id_file()` names the file by the folder's SHA-256 under `aineo/claude-sessions/`.
  - `is_session_id()` gives the id check.
  - `replace_file()` writes beside it and renames, owner-only.

  The tabs home requires no other aineo home (`modularity`). It holds its own form check and its own write, as `lua/aineo/mcp/delivery.lua` holds its own id check, or it takes them as arguments. Say which in its header.
- The session's name on a Claude terminal is `b:aineo_session_name` (T33). The composition root gives `name()` (T66). This home reads no buffer variable of another home.

### Baseline

This plan ran no suite. The dispatch message pastes the counts of the test files you run, measured on the `dev` you start from.

Read first:
- `plan.md` in this folder (*The model*, U3, O15, O21);
- the v1 plan note's C1, C2, D23, D38, **D64** and **D67**;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t65-tabs-home` from `origin/dev`.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t65_tabs_home`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - a new `lua/aineo/tabs/` (its `init.lua` the one entry point, and files of its own beside it);
  - a new `tests/test_tabs.lua`;
  - your session note.
- **You must not touch:**
  - every existing file under `lua/`, `plugin/`, `scripts/` and `tests/` (`tests/helpers/` included);
  - `doc/aineo.txt`, since nothing calls the home yet (T66 tells it);
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/<date> — T65 Tabs home.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t65-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run `tests/test_tabs.lua`.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on `tests/test_tabs.lua`.
  - Never run the real `claude`.

## What was decided already

- **The user's decision, 2026-10-14:** `\<number>` moves to the tab "being number a reference number that appears on the tab title" (D64, `plan.md` › *The user's words*).
- **The user's answer U3**, pasted by the dispatch message. This brief is written for (a), the tab's place.
- **The orchestrator's assumptions** (O15, O21): aineo's tab line only while the user's is empty, a name cut at 24 cells, and the list in a file of its own beside the kept id, which stays as it is. Record them in the session note and the pull request as such, never as the user's.
- **Rejected:** a setting for the tab line (O15 (b)); the list inside the kept id's file (O21 (b)), which an older aineo would read as no id.

## Budget

Medium: a new home of three concerns (tabs, titles, the list), each small, with about fifteen cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

Write it in your definition's shape, to `<scratchpad>/t65-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- the home's interface, as its docstrings give it;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s T65 mutants. Name the test that kills each.
