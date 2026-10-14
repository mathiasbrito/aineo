**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md`, and `.claude/agents/neovim-lua-developer.md`, whose Neovim rules bind you too.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D63 and D64 as proposed, for the user's answer U3 (a), and for the recommendations O5–O16 and O18 of `plan.md` in this folder. **It is dispatched in stage 2, once T60–T65 have merged.** Before dispatch the orchestrator re-checks every fact below on the `dev` it dispatches on, against the interfaces stage 1 merged, and writes a dated amendment at the end of this brief for each that moved (A163). The amendment wins over the body.

## Objective

The task, verbatim from the task list:

> | T66 | Tabs (C1, C2, C3, C4, C6, C7, C11, C12, C15; D63, D64, proposed): each aineo tab holds its own Claude Code, Report, Input and changes pane, made from the homes' copies (T60–T63) and held by the tabs home (T65); `:Aineo tab new`, `\T` and `<C-\>T` open a tab on a new session; `\1`…`\9`, `<C-\>1`…`<C-\>9` and `:Aineo tab {n}` move to the tab of that number; titles and the tab line; a report reaches the tab whose Claude Code sent it, a session hook the tab whose start it names, and each tab is listed among the running editors (T64); a tab closed by Neovim's own commands stops its Claude Code and lets its copies go; with the health check and the help | T60, T61, T62, T63, T64, T65 | planned — wave 15 |

It rests on:
- **D63 and D64**: the user's decisions of tabs, per-tab Report and Input, and `\<number>`, with their proposed parts.
- U3 (a).
- C1–C4, C6, C7, C11, C12, C15.
- D23, D25, D36–D42, D45, D58, D59, D61.
- C8, D10, D26, D29.

### The behaviour — one test each, seen failing first

**One tab, as today**

1. The first open of aineo in an editor (the autostart or `\o`) makes the current tab page aineo's first tab. Its layout, Report, Input, changes pane and Claude Code are the homes' own module copies, and every entry suite of today passes unchanged. The tabs home holds the tab, with the title `1 <session name>`. aineo's tab line is drawn while the user's `'tabline'` is empty (O15).

**A new tab (O13)**

2. `:Aineo tab new`, `<Plug>(aineo-tab-new)`, `\T`, and `<C-\>T` in Terminal and Insert mode each open a new tab page after the current one. The new tab has a layout, a Report and draft, a changes pane and a Claude session home of its own (each home's `new()`). Its Claude Code starts on a new session id (D61's start), in the folder (O8). The cursor ends in its Claude window in Terminal mode. With no aineo tab yet, `\T` opens the first one in the current tab page, on a new id.
3. Every tab starts its Claude Code in the folder of the editor's first start (`places.working_directory`). After `:tcd` to another directory in the current tab, `\T` still starts Claude Code in the folder (P1, P8).

**Each tab its own**

4. A report of tab 2's Claude Code shows in tab 2's Report and in no other.
   - The composition root gives the report home its router (T62, O6):
     1. the tab whose Claude Code has the offer's `start_token` and whose panes follow the report's session;
     2. else a tab whose panes follow the session;
     3. else, `at_start`, the tab whose Claude Code has the token and whose panes follow none yet.
   - With no tab chosen, the report is declined and the report server searches on.
5. A `\s` in tab 2's Input sends to tab 2's Claude Code (T61's Send with its copy and Input). Every refusal of today holds per tab, the claim's among them (D42).
6. A `/clear` in tab 2's Claude Code makes tab 2's Report, draft and changes pane follow the new session (D36–D41), and leaves tab 1's as they were. Every per-session rule of today holds per tab: the confirmation before following, the dead resume's hand-over (D45), and the claims.
7. Each tab writes its own entry among the running editors, keyed by the tab (T64's `tab`). Quitting removes every entry of the editor. A switch told by another editor's Claude Code (`on_followed_switch()`) reaches each tab whose panes follow the session left, by a claim of it.
8. Every action acts on the current tab when it is an aineo tab, and from any other tab on the aineo tab used last, moving there (O5). That covers `\o`, `\r`, `\i`, `\c`, `\g`, `\pa`, `\tcn`, `\N`, `\S` (still the `/resume` of today until T67), `\s` and `:Aineo claim`.
9. Two tabs on one session (a `/resume` in one onto the other's session): both follow it, and aineo warns once, `aineo: this session is also open in tab <n>` (O9).
10. `:Aineo claim <id>` acts in the current tab. A claim of a session that another tab of this editor runs moves to that tab instead, and claims nothing (O11).

**The jumps (O14)**

11. `\1` … `\9`, `<Plug>(aineo-tab-1)` … `<Plug>(aineo-tab-9)`, and `:Aineo tab {n}` move to the tab page of that number, an aineo tab or not. The cursor lands where it was in that tab, in Normal mode.
    - With no such tab, nothing moves and a warning says `aineo: no tab <n>`.
    - `:Aineo tab` completes `new` and the open tabs' numbers, and refuses any other word as `:Aineo pane` refuses one.
12. The twins `<C-\>1` … `<C-\>9` in Terminal and Insert mode leave the mode first (`LEAVE_MODE`, D58), then move, under the same skips as every twin.

**Titles**

13. An aineo tab's title is `<n> <session name>`, the name its Claude terminal's (`b:aineo_session_name`, T33). When the name changes, the tab line is drawn again (`:redrawtabline`). `require('aineo').tab_title(n)` gives a tab's title, for a user's own tab line (O15).

**Closing by Neovim's own commands (O18)**

14. A tab closed by `:tabclose`, `:tabonly` or the close of its last window is found as closed (`TabClosed`, the tabs home's `closed()`). For that tab:
    - its Claude Code is stopped as quitting stops it (T61's `stop_session()`), Ctrl+Z for an attached one;
    - its Input's draft is saved;
    - its copies are let go: no handler, buffer or watch of theirs is left;
    - its entry is removed.

    The other tabs go on as they were. The key and what closing means for the folder's tabs come in T67 and T68.

**Quitting**

15. `:qa` with several tabs stops every tab's Claude Code at once (T61), and saves every tab's draft.

**Keys, health and help**

16. No existing key changes. `\c` still acts at once (D53).
    - No aineo key starts with a digit or `T`, and none of them begins one (O16).
    - `:checkhealth aineo` lists `\T`, `\1` … `\9` and their twins in *Prefix mappings* and *Terminal prefix mappings*, and says which tab line is in use.
17. The help.
    - A new section after *Panes*, `Tabs ~` with `*aineo-tabs*`, says:
      - what a tab holds;
      - that every tab is of the folder;
      - the keys and the titles;
      - what each action does from a tab that is not aineo's;
      - what closing a tab with Neovim's commands does.
    - COMMANDS gains `:Aineo-tab`. MAPPINGS gains the `<Plug>` list entries and the `aineo-\T`, `aineo-\1` (one tag for the nine) entries. *aineo-terminal-keys* gains the twins. HEALTH CHECK gains the lines.
    - LIMITS gains `Several tabs ~`: the quit's time, and one watch and one list run per tab.

    `tests/test_doc.lua` derives the tags the plugin defines (`TAGS_THE_PLUGIN_DEFINES`). Run it.

### Facts to re-check at dispatch

Read at `bugfix/t48-attach` `e0989f2`, before stage 1.
- `plugin/aineo.lua` (1887 lines) keeps one of everything at file level (P5): `places`, `claude_terminal`, `panes_session`, `claimed_by_id`, `claimed`, `start_confirmed`, `session_read_in_flight`, and the environment flags. Each of these but `places` becomes the tab's.
- Its functions call the homes' module functions: `follow_session()`, `replacement_callbacks()`, `claude_settings()`, `started_claude_terminal()`, `arrangement()`, `open()`, `focus()` and `focus_pane()`. With tabs they call the tab's copies.
- `SUBCOMMANDS` (28), `SUBCOMMAND_WORDS` (43), `ACTIONS` (1452), `PREFIX_KEYS` (1573), `LEAVE_MODE` (1591), `HAS_NO_TWIN` (1595) and `map_terminal_prefix()` (1668).
- The entry's handlers are made once by `make_entry_handlers()` (399): `FocusGained`, `VimLeavePre` and `on_followed_switch()`.
- Stage 1 gives:
  - `new()` on `aineo.layout`, `aineo.claude`, `aineo.report`, `aineo.draft` and `aineo.changes`;
  - `set_report_router()` on `aineo.report`;
  - `stop_session()` and `start_token()` on a claude copy;
  - Send's `{ session, input }`;
  - `tab` in `write_editor_entry()` and `remove_editor_entry()`;
  - `aineo.tabs` with `hold`, `let_go`, `held`, `closed`, `number`, `title`, `tabline` and `draw_tabline`.

  Their names here are the stage-1 briefs'. Use the merged ones.
- `lua/aineo/health.lua` holds its own `PREFIX_KEYS` list, which gains `T` and `1`–`9`.
- `lua/aineo/init.lua` is the public API (`setup()`), which gains `tab_title()`.
- Pins that list the subcommands or keys: `tests/test_entry.lua`, `tests/test_entry_panes.lua`, `tests/test_entry_prefix.lua`, `tests/test_entry_terminal_keys.lua` and `tests/test_health.lua`.

Evidence: `evidence/w15-probes.txt` › P1–P8.

**Unmeasured.** No suite runs the real Claude Code (D10). Two real Claude Codes in one editor, the reports of each reaching their tab, and the quit's time are the user's checks M1 and M2 (`plan.md` › *Checks for the user*). Name them in LIMITS where they bear.

### Baseline

The dispatch message pastes the whole suite's counts on the `dev` you start from, measured by the orchestrator after stage 1.

Read first:
- `plan.md` in this folder (*The model*, O5–O16, O18);
- the stage-1 session notes (T60–T65);
- the v1 plan note's C1–C4, C7, D36–D42, D58, **D63** and **D64**;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t66-tabs` from `origin/dev`.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t66_tabs`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `plugin/aineo.lua`, `lua/aineo/init.lua` (`tab_title()` alone) and `lua/aineo/health.lua`;
  - new `tests/test_entry_tabs.lua`, and more `tests/test_entry_tabs_*.lua` if it grows, and the entry and health suites where a pin moves;
  - `tests/helpers/`, **additions only**. If you add to a helper, run every test file that requires it;
  - `doc/aineo.txt`: the INTRODUCTION's keys, a new `Tabs ~` section after *Panes*, COMMANDS, MAPPINGS, *aineo-terminal-keys*, HEALTH CHECK, and LIMITS;
  - your session note.
- **You must not touch:**
  - every home under `lua/aineo/` but the two files named. If a home's merged copy lacks what you need, that is a **spec conflict** for your report, not a reason to change the home;
  - `lua/aineo/config/`, since no setting is added;
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/<date> — T66 Tabs.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t66-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run the test files you touch, plus `tests/test_entry_sessions.lua`, `tests/test_entry_session_switch.lua`, `tests/test_entry_claim.lua` and `tests/test_doc.lua`.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on their covering files.
  - Never run the real `claude`.

## What was decided already

- **The user's decisions, 2026-10-14**, verbatim in `plan.md` › *The user's words*:
  - tabs, each its own session;
  - only sessions of the same folder;
  - "report and input is per tab";
  - `\<number>` to the tab whose title shows that number.
- **The user's answer U3**, pasted by the dispatch message. This brief is written for (a).
- **The rest is the orchestrator's** (O5–O16, O18): the new-tab key, the folder rule, the routing, the entries, the titles, the jumps' misses, and two tabs on one session. Record them in the session note and the pull request as such, never as the user's decisions.
- **Rejected:** `\N` opening a tab (O13 (b)); routing by session alone (O6 (b)); the tab's own `getcwd()` (O8 (b)); a Claude Code left running in a closed tab (O18 (b)).
- **Not in this packet:** `\S` in a new tab, `\Q` and what closing means for the folder's tabs (T67); the folder's list and reopening (T68).

## Budget

Large: the composition root made per tab, with about thirty new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial: the per-tab composition and `\T` first, then the jumps and titles, then the close by Neovim's commands.

## Report

Write it in your definition's shape, to `<scratchpad>/t66-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- each test file whose pins moved, and why;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s T66 mutants. Name the test that kills each.

## The orchestrator's rulings — 2026-10-14, before dispatch

`plan.md` › *The user's answers* (U1–U3, the user's decisions) and *The orchestrator's rulings* (O1–O22 → A234–A255, each its (a)) bind this brief, which is written for them. Record A234–A255 as the orchestrator's assumptions, never as the user's decisions.
