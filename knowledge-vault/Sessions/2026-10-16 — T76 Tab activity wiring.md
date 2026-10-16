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

The user's decision, 2026-10-15 (D73), and the answers U1 (a: ● marks unseen output), U2 (a: the indicator after the name) and U3 (a: no multiplexer fallback; the user's answer about their setup) are quoted in the plan. Everything else is the orchestrator's assumption, never the user's decision: **A354–A366** (the wave's rulings O1–O13: the shape, the models, the signal, the unseen mark A359, `tab_title()` A363, `'showtabline'` A364, the health line and help A365), **A372** (the three items T75's attack review handed this packet: a `BufWipeout` path for a wiped busy terminal, `change.new == true`, the state told again at `hold()`), and, from this packet's reviews, **A376** (the wipe is heard through `on_detach`), **A377** (health warns only for the values Claude Code acts on) and **A378** (the seen mark is scheduled and marks only a page still current).

## Task lines

- [X] T76 The tab activity wired — done on `feature/t76-tab-activity-wiring`: the composition root watches `b:aineo_session_busy` of every Claude terminal a tab runs (`lua/aineo/entry/busy_watch.lua`, followed from `tab.lua` at a start, a replacement and an attached terminal's replacement) and tells `aineo.tabs` through `set_busy()`, again at `hold_tab()`; a wiped busy terminal tells not busy, heard as the buffer's detach; `TabEnter` marks the tab page the user stays in seen; `:checkhealth aineo` says what the indicator reads and warns for `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` set to `1`, `true`, `yes` or `on`, and for a non-blank `TMUX`, `STY` or `ZELLIJ`; the help covers the indicator in `aineo-tabs`, `aineo-tab_title`, the health check and a limits entry; reviewed twice (attack, tests and records) and fixed in one round; merged as PR #236.

## The steps

Units, in the order they were built.

1. *Amendment at dispatch*: the brief's facts against `dev` `82d3b65` (T74 moved the wiring into `lua/aineo/entry/`).
2. *A busy tab shows ◒ or ◓ on its own title* (`tab.lua` › `follow_claude_terminal_activity()`, `busy_watch.lua`).
3. *● when a spell ends away from the user*; *`\2` takes it off* (`TabEnter` in `opening.lua` › `hold_tab()`); a tab page that is not aineo's marks nothing.
4. *The tab is told again at `hold_tab()`* when the terminal went busy while the layout opened.
5. *The close of a busy tab* (by `:tabclose` and by `:Aineo tab close`) ends the animation at once; a wiped busy terminal ends it too, however it was wiped (`on_detach`); a removed variable reads as not busy.
6. *A replacement terminal is followed*: one that replaces a resume with no conversation, and one that replaces an attached terminal.
7. *Health*: the Tab line section's line and four warnings.
8. *Help*.
9. *Fix round* (A376–A378 and the reviews' test and records findings): the wipe heard through `on_detach`; the seen mark scheduled; health warnings by value; the four weak cases assert their setup; a case for the error handling; both fixed sleeps gone; the help and this note corrected.

**Decided inside the packet.**

- *The `TabEnter` mark is in a handler of its own* (`opening.lua` › `hold_tab()`, beside the `TabClosed` one), not in `editors.lua`'s handler as the brief has it: that one is made at the first entry write, which needs the panes to follow a session, so a first spell that ended before it would never clear. Declared in the brief's amendment.
- *One new file in the entry home*, `busy_watch.lua`, so that `tab.lua` (1600 lines) gains two calls and one small function, and the watcher has one concern.
- *A terminal the tab left tells nothing* was built (a guard comparing the terminal with the tab's) and removed: measured, a terminal a tab leaves is wiped inside the swap that replaces it, before the tab holds the new one, so no flow reached the guard (mutants B4 and B7 survived every case I could build).
- *A health variable counts as set* when Claude Code acts on its value (A377): the attack review read the 2.1.301 program (not run), which parses `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` as a flag, true for `1`, `true`, `yes`, `on`, trimmed and in lower case, and `TMUX`, `STY` and `ZELLIJ` as strings whose blank value is unset. An empty variable is unset in Neovim 0.12.5 already.
- *The wipe is heard as `on_detach`, not `BufWipeout`* (A376): a `BufWipeout` autocommand does not run for a wipe made inside another autocommand that is not nested (a user's `TermClose` handler that deletes the ended buffer) nor under `:noautocmd`; the busy terminal then stayed busy and its timer ran on. B7 (`tell_tabs_home_busy(is_busy())` at follow) had a separating input only through that defect; with `on_detach` it has none, and stays removed.
- *The `hold_tab()` re-tell is pinned only through a stub.* The case replaces `layout.open` with a function that waits for the terminal to go busy first, to build the order (busy before the tab page is held). An unstubbed `Aineo open` was tried (tests review 3) and does not reach it: no natural flow was found to need the re-tell, so it is defensive code the stubbed case proves, not a flow measured.

## What arrived green, and why

`tests/test_entry_tab_activity.lua` has 25 cases: 6 seen red (below) and 19 that arrived green. `tests/test_health.lua` changed 21 cases: 14 seen red and 7 green. Each green case is pinned by a mutant that fails it.

Activity cases that arrived green (19):

- *leaves ● … when its spell ends while another tab is current*, *shows ◒ and ◓ in turn*, *leaves no indicator on the title of the tab the user is in*, *the close of a busy tab* (2), *a tab line of the user's*: green by nature, the first unit's wiring already told the tabs home and T75's homes did the rest. Killers: W1, W3 and B6 (each fails the case at its setup, which now asserts the tab went busy); W5 for the two close cases.
- *entering a tab by* `:tabnext`, `:2tabnext`, `gt`, `nvim_set_current_tabpage()`, `win_gotoid()` (5) and *by its number*: the existing mark already cleared them. Killers: W2, B9, D3.
- *that is not aineo's takes the ● off no title*: green by nature. Killer: B11.
- *is not busy once its terminal is wiped*: written after the wipe path. Killer: D1.
- *is followed in the terminal that replaces the one Claude Code found no conversation for* and *… that replaces an attached one*: written after the code. Killers: B5 and B10.
- *is no longer busy in the tab once an attached terminal is replaced by one that is not*: written after the code. Killer: W1 only, through its setup. Removing the wipe path does not fail it: the earlier version of this note claimed that kill, and it was wrong (the attack review measured 4 of 4 runs green).
- *is not busy once its variable is removed*: written after a survivor (B1). Killer: B1.
- *tells the tabs home once for each change, however often the tab is opened*: written after a survivor (B8). Killer: B8.
- *tells the user once, with one error, when the tabs home raises*: written after the tests review measured E1 surviving. Killer: E1.

Health cases that arrived green (7): *does not warn about activity when none of the variables is set* and the six *warns … when CLAUDE_CODE_DISABLE_TERMINAL_TITLE is set to* `1`, `true`, `yes`, `on`, `TRUE`, ` On ` (they hold on the code before A377 and pin its predicate). Killers: A1 to A4, H3.

**This packet departed from the rule that every unit is driven by a test seen failing first** for 19 of the 25 activity cases: the first unit's wiring covered the green-by-nature ones, and the replacement, wipe, removed-variable, once-per-terminal, error-handling and entering cases were written after their code, each then proven by its mutant. That is a substitute, not the rule. The cases of the fix round that changed behaviour (the wipe heard as `on_detach`, the scheduled mark, health by value) were seen red first.

## Seen red

Activity suite (6):

1. `a busy Claude Code › puts ◒ or ◓ on the title of its own tab, and none on another tab's`: `Left: { false, "1: Claude Code" } / Right: { true, "1: Claude Code" }`.
2. `entering a tab › by its number takes the ● off its title`: `Left: "2: Claude Code ●" / Right: "2: Claude Code"`.
3. `a busy Claude Code › is told again when its tab page is held, if it went busy while the layout opened`: `Left: false / Right: true`.
4. `… is not busy once a TermClose handler of the user's, not nested, wipes its ended terminal` (fix round): `Left: { true, true } / Right: { false, false }`.
5. `… is not busy once its terminal is wiped without autocommands` (fix round, `:noautocmd bwipeout!`): the same.
6. `entering a tab › for a moment, as aineo itself does, leaves the ● on its title` (fix round): `Left: "2: Claude Code" / Right: "2: Claude Code ●"`.

Health (14): the three cases that say which tab line is in use (the indicator line missing), the four `warns, naming the variable` cases (`Left: nil` for the line they read), and the seven `does not warn about activity when a variable Claude Code does not act on is set` cases of the fix round (`0`, `false`, `no`, `2`, and a blank `TMUX`, `STY`, `ZELLIJ` each warned).

## Mutants

Each was run as its literal edit, one at a time, from a pristine copy of the file, against the test file that exercises it (`tests/test_entry_tab_activity.lua`, or `tests/test_health.lua` for the health mutants), on the final tree. Every kill below is an assertion failure (`Failed expectation`), the number of failures read from the output equal to the number of assertion failures.

| # | File: the literal edit | Killed by (failures) |
|---|---|---|
| W1 | plan 1, `tab.lua`: `    busy_watch.tell_when_busy_changes(terminal, tell_tabs_home_busy)` → `    local _ = nil` | 24 of 25: every case but the held-late one (`hold_tab()` tells) |
| W2 | plan 2, `opening.lua`: `            require('aineo.tabs').mark_seen(entered)` → `            local _ = nil` | the 6 cases that enter a tab and expect the ● gone |
| W3 | plan 3, `tab.lua`: `      require('aineo.tabs').set_busy(bound_page, busy)` → `      require('aineo.tabs').set_busy(vim.api.nvim_list_tabpages()[1], busy)` | 20 |
| W4 | plan 4, `health.lua`: the table entry `{ name = 'TMUX', is_acted_on = is_not_blank, meaning = …, advice = … },` deleted | *warns … when TMUX is set* (1) |
| W5 | plan 5, `closing.lua`: `  for _, page in ipairs(require('aineo.tabs').closed()) do` → `  for _, page in ipairs({}) do` | *the close of a busy tab* ×2 (2) |
| B1 | `busy_watch.lua`: `      tell_once_raised(change.new == true)` → `      tell_once_raised(change.new)` | *is not busy once its variable is removed* (1) |
| B3 | `opening.lua`: the line `  tabs.set_busy(tab.page(), tab.is_busy())` deleted | *is told again when its tab page is held* (1) |
| B5 | `tab.lua`: in `on_terminal_replaced`, `        follow_claude_terminal_activity(terminal)` → `        redraw_tab_line_when_named(terminal)` | *… found no conversation for* (1) |
| B6 | `tab.lua`: in `begin_claude()`, `    follow_claude_terminal_activity(claude_terminal)` → `    redraw_tab_line_when_named(claude_terminal)` | 23 |
| B8 | `busy_watch.lua`: the guard `  if vim.b[terminal].aineo_busy_watched then` … `return` … `end` deleted | *tells the tabs home once for each change* (1) |
| B9 | `opening.lua`: in the `TabEnter` autocommand, `      group = group,` → `      group = group,` and a new line `      pattern = 'nomatch',` | the 6 entering cases (6) |
| B10 | `tab.lua`: in `replace_claude_terminal()`, `    follow_claude_terminal_activity(terminal)` → `    redraw_tab_line_when_named(terminal)` | *… that replaces an attached one* (1) |
| B11 | `opening.lua`: `            require('aineo.tabs').mark_seen(entered)` → `            require('aineo.tabs').mark_seen(vim.api.nvim_list_tabpages()[2])` | *for a moment … leaves the ●* and *that is not aineo's takes the ● off no title* (2) |
| D1 | `busy_watch.lua` (A376): the call `vim.api.nvim_buf_attach(terminal, false, { on_detach = … })` deleted | *is not busy once its terminal is wiped*, the `TermClose` case and the `:noautocmd` case (3) |
| D2 | `opening.lua` (A378): `if vim.api.nvim_get_current_tabpage() == entered then … end` → the `mark_seen(entered)` line alone | *for a moment, as aineo itself does, leaves the ●* (1) |
| D3 | `opening.lua`: `          if vim.api.nvim_get_current_tabpage() == entered then` → `          if false then` | the 6 entering cases (6) |
| E1 | `busy_watch.lua`: `    errors.run(function()` … `      tell(busy)` … `    end)` → `    tell(busy)` | *tells the user once, with one error* (1) |
| H1 | `health.lua`: `    if value ~= nil and variable.is_acted_on(value) then` → `    if value ~= nil then` | the 7 *does not warn … a variable Claude Code does not act on* cases (7) |
| H2 | `health.lua`: the `vim.health.info(` call that says what the indicator reads deleted | 7 (the three tab-line pins and the four warning cases) |
| H3 | `health.lua`: `    name = 'CLAUDE_CODE_DISABLE_TERMINAL_TITLE',` → `    name = 'CLAUDE_CODE_DISABLE_TERMINAL_TITLES',` | 7 |
| H4 | `health.lua`: `    name = 'ZELLIJ',` → `    name = 'ZELLIJ2',` | the `ZELLIJ` case (1) |
| H5 | `health.lua`: `    name = 'STY',` → `    name = 'STY2',` | the `STY` case (1) |
| A1 | `health.lua`: `vim.tbl_contains(CLAUDE_CODE_TRUE_VALUES, vim.trim(value):lower())` → `vim.tbl_contains(CLAUDE_CODE_TRUE_VALUES, vim.trim(value))` | `TRUE`, ` On ` (2) |
| A2 | the same → `vim.tbl_contains(CLAUDE_CODE_TRUE_VALUES, value:lower())` | ` On ` (1) |
| A3 | `health.lua`: `  return vim.trim(value) ~= ''` → `  return value ~= ''` | the 3 blank multiplexer cases (3) |
| A4 | `health.lua`: `local CLAUDE_CODE_TRUE_VALUES = { '1', 'true', 'yes', 'on' }` → `{ '1', 'true', 'yes' }` | `on`, ` On ` (2) |

The old B2 (the `BufWipeout` autocommand removed) is gone with the autocommand: D1 is its successor. B11 earlier also crashed in the `:tabclose` case (the unscheduled handler raised on a gone tab page); with the scheduled mark it does not.

Two mutants of a first version of the wiring survived every case I could build, and the code they stand for was removed: B4 (`if terminal == claude_terminal then` around `tell_tabs_home_busy(busy)`) and B7 (`tell_tabs_home_busy(is_busy())` at the end of `follow_claude_terminal_activity()`). In the resume with no conversation, the attached replacement and a restart after an exit, the old terminal is wiped inside the swap (`aineo.claude`), before the tab holds the new one, so a terminal the tab left never speaks after the swap. The attack review found a separating input for B7 (a user's non-nested `TermClose` wipe, then a restart); it exists only through the `BufWipeout` defect that D1 removes.

## Verification

- `tests/test_entry_tab_activity.lua`: 25 cases, new. `tests/test_health.lua`: 134 cases (the three Tab line pins moved to expect the indicator line and clear `TMUX`, `STY`, `ZELLIJ` and `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` in their child, and 18 cases added). `tests/test_doc.lua` 53 cases, green with no new tag.
- The whole suite: the pull request gives the counts of the last run on the pushed tree. The first push's run, `AINEO_TEST_JOBS=3 AINEO_TEST_RUN_LIMIT_MS=2700000 make test` at a host load of about 270, gave 4081 cases and `Fails (0)`, after two runs at four jobs each lost one timing-sensitive case that passes alone (`tests/test_entry_claude_exit.lua` › *lets i enter Terminal mode in that ended terminal as Neovim does*; `tests/test_entry_panes.lua` › *a switch refused in the command-line window …*).
- `make lint` clean (StyLua and selene).
- The deep-require check prints no line in this packet's files other than requires inside the entry home (`tab.lua` requiring `aineo.entry.busy_watch`, `busy_watch.lua` requiring `aineo.entry.errors`); `opening.lua` and `tab.lua` reach `aineo.tabs` through its entry point.

## Spec conflicts

None found. The brief's facts moved by name only (its amendment); the `TabEnter` handler's place is a declared widening, not a conflict.

## Open threads

- The glyphs and the reading of the title are tier 2 (T75's note): read from the 2.1.301 program, never seen in a real turn. The user's checks M1–M4 of the plan are the real measurement, and the help says so.
- The health values (`1`, `true`, `yes`, `on`; non-blank multiplexer variables) are the attack review's read of the program, not a run.
- The `hold_tab()` re-tell is defensive: proven only through a stubbed slow `layout.open`.
- Both limits entries that spoke of the busy glyph now say it is read from the program, not seen.

## Commits

- PR #236, `feature/t76-tab-activity-wiring`, head `779dffd` (10 commits), merged by rebase into `dev` as `2c530b4` (Amend T76's brief at dispatch against dev 82d3b65), `838ea68` (Wire each tab's busy state to the tabs home and mark a tab seen on entry), `f40a4a9` (Say what the activity indicator reads and warn where it cannot show), `7f4688d` (Document the activity indicator in the help), `7172059` (Tell the tab only what its terminals say, and pin three more flows), `3cdf9fe` (Pin the replacement follow and the once-per-terminal watch), `ed17d4b` (Record T76's session: the wiring, its mutants and the suite), `2bbf366` (Hear a wiped terminal as its detach, and mark a tab seen after the turn), `1369314` (Warn only for the values Claude Code acts on), `192c34f` (Correct T76's session note after its reviews). The orchestrator's check on the tree: 4103 cases, `Fails (0)`; the mutants on the detach hearing (3 failures) and the still-current mark (1) killed.
- Released in v0.2.41 (PR #237, `main` `8a1f46e`), with T75 and T77: the first release the user can see the indicator in.
