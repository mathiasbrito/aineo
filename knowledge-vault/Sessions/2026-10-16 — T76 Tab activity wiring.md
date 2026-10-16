# 2026-10-16 — T76 Tab activity wiring

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t76-tab-activity-wiring` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D63, D64, D69, D71, D73 (as the wave's plan writes it), C1, C7
- `Implementation/Waves/00017-tab-activity/plan.md` — *Feasibility*, *The model*, U1–U3, O6, O10–O12 (A359, A363, A365), *Verification mutants*
- `Implementation/Waves/00017-tab-activity/brief-t76-tab-activity-wiring.md` — the brief and its dated amendment at dispatch
- [[Sessions/2026-10-15 — T75 Tab activity homes]] — the homes this wires
- [[Learnings/Claude Code sets its terminal title by OSC 0 and clears it when it exits]]

Measured on Neovim 0.12.5, the host's newest release.

## The user's words and the rulings it rests on

The user's decision, 2026-10-15 (D73), and the answers U1 (a: ● marks unseen output) and U2 (a: the indicator after the name) are quoted in the plan. U3 (a) is the user's answer about their setup. Everything else is the orchestrator's ruling, recorded here as such and never as the user's decision: A359 (unseen set away from the current tab page, cleared at `TabEnter`), A363 (`tab_title()` includes the indicator), A364 (`'showtabline'` left alone), A365 (the health line, its warnings and the help).

## Task lines

- [X] T76 The tab activity wired — done on `feature/t76-tab-activity-wiring`: the composition root watches `b:aineo_session_busy` of every Claude terminal a tab runs (`lua/aineo/entry/busy_watch.lua`, followed from `tab.lua` at a start, a replacement and an attached terminal's replacement) and tells `aineo.tabs` through `set_busy()`, again at `hold_tab()`; a wiped busy terminal tells not busy; `TabEnter` marks the tab page entered seen; `:checkhealth aineo` says what the indicator reads and warns for `CLAUDE_CODE_DISABLE_TERMINAL_TITLE`, `TMUX`, `STY` and `ZELLIJ`; the help covers the indicator in `aineo-tabs`, `aineo-tab_title`, the health check and a limits entry; reviews pending.

## The steps

Units, in the order they were built.

1. *Amendment at dispatch*: the brief's facts against `dev` `82d3b65` (T74 moved the wiring into `lua/aineo/entry/`).
2. *A busy tab shows ◒ or ◓ on its own title* (`tab.lua` › `follow_claude_terminal_activity()`, `busy_watch.lua`).
3. *● when a spell ends away from the user*; *`\2` takes it off* (`TabEnter` in `opening.lua` › `hold_tab()`); a tab page that is not aineo's marks nothing.
4. *The tab is told again at `hold_tab()`* when the terminal went busy while the layout opened.
5. *The close of a busy tab* (by `:tabclose` and by `:Aineo tab close`) ends the animation at once; a wiped busy terminal ends it too (`BufWipeout`); a removed variable reads as not busy.
6. *A replacement terminal is followed*: one that replaces a resume with no conversation, and one that replaces an attached terminal.
7. *Health*: the Tab line section's line and four warnings.
8. *Help*.

**Decided inside the packet.**

- *The `TabEnter` mark is in a handler of its own* (`opening.lua` › `hold_tab()`, beside the `TabClosed` one), not in `editors.lua`'s handler as the brief has it: that one is made at the first entry write, which needs the panes to follow a session, so a first spell that ended before it would never clear. Declared in the brief's amendment.
- *One new file in the entry home*, `busy_watch.lua`, so that `tab.lua` (1600 lines) gains two calls and one small function, and the watcher has one concern.
- *A terminal the tab left tells nothing* was built (a guard comparing the terminal with the tab's) and removed: measured, a terminal a tab leaves is wiped inside the swap that replaces it, before the tab holds the new one, so no flow reached the guard (mutants B4 and B7 survived every case I could build).
- *A health variable counts as set when it is not nil.* Whether Claude Code treats an empty or false value as unset was not measured.

## What arrived green, and why

Of the 16 cases in `tests/test_entry_tab_activity.lua`, 3 were seen red (below). The rest arrived green, and each is pinned by a mutant that fails it:

- *leaves ● … when its spell ends while another tab is current*, *shows ◒ and ◓ in turn*, *leaves no indicator on the tab the user is in*, *the close of a busy tab* (2), *a tab line of the user's*: green by nature, the first unit's wiring already told the tabs home and T75's homes did the rest. Killers: W1, W3, B6 (assertions).
- *that is not aineo's takes the ● off no title*: green by nature (nothing marks a non-aineo tab page). Killer: B11, an assertion.
- *is not busy once its terminal is wiped*: written after `BufWipeout` was; killer B2, an assertion.
- *is followed in the terminal that replaces the one Claude Code found no conversation for*, *… that replaces an attached one*, *is no longer busy … replaced by one that is not*: written after the code. Killers: B5, B10, B2.
- *is not busy once its variable is removed*: written after a survivor (B1) showed `change.new == true` unpinned; green on the code, killed by B1.
- *tells the tabs home once for each change, however often the tab is opened*: written after a survivor (B8); green on the code, killed by B8.

**This packet departed from the rule that every unit is driven by a test seen failing first** for the wiring of the replacement terminals, the wipe, the removed variable and the once-per-terminal guard: the code was written with the first unit's follow function and the tests after, each then proven by its mutant. That is a substitute, not the rule.

## Seen red

1. `a busy Claude Code › puts ◒ or ◓ on the title of its own tab, and none on another tab's`: `Left: { false, "1: Claude Code" } / Right: { true, "1: Claude Code" }`.
2. `entering a tab › by its number takes the ● off its title`: `Left: "2: Claude Code ●" / Right: "2: Claude Code"`.
3. `a busy Claude Code › is told again when its tab page is held, if it went busy while the layout opened`: `Left: false / Right: true`.
4. `the tab line` in `tests/test_health.lua`, 7 cases: the three that said which tab line is in use (`Left` without the line `- the activity indicator on a tab reads the title Claude Code sets on its terminal: :help |aineo-tabs|`) and the four `warns, naming the variable` cases (`Left: nil` for the line they read). `does not warn about activity when none of the variables is set` arrived green, since nothing warned.

## Mutants

Each was run as its literal edit, one at a time, from a pristine copy of the file, against the test file that exercises it (`tests/test_entry_tab_activity.lua`, or `tests/test_health.lua` for H), on the final tree. Killed means a failing assertion (`Failed expectation`), the number of failures read from the output equal to the number of assertion failures, but where a row says crash.

| # | File: the edit | Killed by (failures) |
|---|---|---|
| W1 | plan 1, `tab.lua`: `busy_watch.tell_when_busy_changes(terminal, tell_tabs_home_busy)` → `local _ = nil` | 11 assertions: every case that waits for ◒ or ◓ (the held-late case still passes, since `hold_tab()` tells) |
| W2 | plan 2, `opening.lua`: `require('aineo.tabs').mark_seen(vim.api.nvim_get_current_tabpage())` → `local _ = nil` | *by its number takes the ● off its title* (1) |
| W3 | plan 3, `tab.lua`: `set_busy(bound_page, busy)` → `set_busy(vim.api.nvim_list_tabpages()[1], busy)` | 7 assertions, among them *puts ◒ or ◓ on the title of its own tab, and none on another tab's* |
| W4 | plan 4, `health.lua`: the `TMUX` entry of `SILENT_TITLE_VARIABLES` removed | *warns … when TMUX is set* (1) |
| W5 | plan 5, `closing.lua`: `ipairs(require('aineo.tabs').closed())` → `ipairs({})` | *the close of a busy tab* ×2 (2): the animation ran on after the close, to stop at its next frame |
| B1 | `busy_watch.lua`: `tell_once_raised(change.new == true)` → `tell_once_raised(change.new)` | *is not busy once its variable is removed* (1) |
| B2 | `busy_watch.lua`: the `BufWipeout` autocommand removed | *is not busy once its terminal is wiped* and *is no longer busy … replaced by one that is not* (2) |
| B3 | `opening.lua`: `tabs.set_busy(tab.page(), tab.is_busy())` removed | *is told again when its tab page is held* (1) |
| B5 | `tab.lua`: in `on_terminal_replaced`, `follow_claude_terminal_activity(terminal)` → `redraw_tab_line_when_named(terminal)` | *… that replaces the one Claude Code found no conversation for* (1) |
| B6 | `tab.lua`: in `begin_claude()`, `follow_claude_terminal_activity(claude_terminal)` → `redraw_tab_line_when_named(claude_terminal)` | 8 assertions |
| B8 | `busy_watch.lua`: the `if vim.b[terminal].aineo_busy_watched then return end` guard removed | *tells the tabs home once for each change* (1) |
| B9 | `opening.lua`: `pattern = 'nomatch',` added to the `TabEnter` autocommand | *by its number takes the ● off its title* (1) |
| B10 | `tab.lua`: in `replace_claude_terminal()`, `follow_claude_terminal_activity(terminal)` → `redraw_tab_line_when_named(terminal)` | *… that replaces an attached one* (1) |
| B11 | `opening.lua`: `mark_seen(vim.api.nvim_get_current_tabpage())` → `mark_seen(vim.api.nvim_list_tabpages()[2])` | *that is not aineo's takes the ● off no title* (assertion); *the close of a busy tab › :tabclose* (crash: the `TabEnter` handler raised on a tab page that was gone) |
| H1 | `health.lua`: `if vim.env[variable.name] ~= nil then` → `== nil` | 8 assertions |
| H2 | `health.lua`: the `vim.health.info` of what the indicator reads removed | 7 assertions |
| H3 | `health.lua`: `name = 'CLAUDE_CODE_DISABLE_TERMINAL_TITLE'` → `'CLAUDE_CODE_DISABLE_TERMINAL_TITLES'` | the `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` case (1) |
| H4 | `health.lua`: `name = 'ZELLIJ'` → `'ZELLIJ2'` | the `ZELLIJ` case (1) |
| H5 | `health.lua`: `name = 'STY'` → `'STY2'` | the `STY` case (1) |

Two mutants of a first version of the wiring survived every case I could build, and the code they stand for was removed: B4 (`if terminal == claude_terminal then` around `tell_tabs_home_busy(busy)`) and B7 (`tell_tabs_home_busy(is_busy())` at the end of `follow_claude_terminal_activity()`). I tried the resume with no conversation, the attached replacement and a restart after an exit: in each, the old terminal is wiped inside the swap (`aineo.claude`), before the tab holds the new one, so a terminal the tab left never speaks after the swap.

## Verification

- `tests/test_entry_tab_activity.lua`: 16 cases, new. `tests/test_health.lua`: 121 cases (the three Tab line pins moved to expect the indicator line and clear `TMUX`, `STY`, `ZELLIJ` and `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` in their child, and 5 cases added). `tests/test_doc.lua` 53 cases, green with no new tag. The suites the brief names (`test_entry_tabs`, `test_entry_tab_close`, `test_entry_tabs_close`, `test_entry_claude_name`) and `test_entry_tab_reopen` and `test_entry_tabs_routing` green.
- The whole suite on the tree pushed (but for this note), Neovim 0.12.5, the host's load about 270: `AINEO_TEST_JOBS=3 AINEO_TEST_RUN_LIMIT_MS=2700000 make test` gave **4081 cases, `Fails (0)`** (4060 on `dev` before, plus 16 and 5). Two runs at `AINEO_TEST_JOBS=4` each failed one case that passes alone and in a rerun of its file: `tests/test_entry_claude_exit.lua` › *another terminal's exit › lets i enter Terminal mode in that ended terminal as Neovim does* (mode `n`, wanted `t`) and `tests/test_entry_panes.lua` › *a switch refused in the command-line window › leaves the column as it was, and the key switches once it is closed*. Both read modes or windows after a key and are timing-sensitive; neither touches the tab activity. Not measured on `dev` at that load.
- `make lint` clean (StyLua and selene).
- The deep-require check prints no line in this packet's files other than requires inside the entry home (`tab.lua` requiring `aineo.entry.busy_watch`, `busy_watch.lua` requiring `aineo.entry.errors`); `opening.lua` and `tab.lua` reach `aineo.tabs` through its entry point.

## Spec conflicts

None found. The brief's facts moved by name only (its amendment); the `TabEnter` handler's place is a declared widening, not a conflict.

## Open threads

- The glyphs and the reading of the title are tier 2 (T75's note): the user's checks M1–M4 of the plan are the real measurement.
- `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` is warned about when set to anything. Claude Code's reading of `0` or an empty value was not measured.
- The `Claude's window name` entry of the limits still says the glyph while Claude Code is busy is not measured; it is still true, and the new entry says where the indicator reads it.

## Commits

Recorded after the merge.
