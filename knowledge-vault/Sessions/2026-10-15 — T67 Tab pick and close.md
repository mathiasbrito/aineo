# 2026-10-15 — T67 Tab pick and close

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`, on Sonnet)
**Branch:** `feature/t67-tab-pick-close` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C1, C3, C7, D49, D51, D62, D63, D65, D66, T67
- [[Implementation/Waves/00015-tabs/plan]] › *The user's answers* (U1 (a)), O17–O19 (A234–A255), *Verification mutants* › T67
- [[Implementation/Waves/00015-tabs/brief-t67-tab-pick-close]], with its dated amendment at dispatch
- [[Sessions/2026-10-14 — T66 Tabs]] (the tab registry, `release_tab()`, `finish_closing()`, the reused first tab, A305/A306), [[Sessions/2026-10-14 — T48 Attach]]

Wave 15, stage 3. D65 and D66 are the user's decisions on the shape ("\S loads in a new tab", a way to close a tab); U1 was answered (a). The key `\Q`, a tab closed any way closed alike, the move to a tab that shows the session and the `[tab <n>]` mark are the orchestrator's assumptions O17–O19, never the user's decisions. Measured on Neovim 0.12.5; the suites run a fake `claude` (D10), so the real Claude Code's behaviour in a new tab stays the user's check.

## What was done

- **`\S` in a new tab (`plugin/aineo.lua`, `lua/aineo/claude/agents.lua`).**
  - The list's rows mark each session a tab of this editor shows `[tab <n>]`; `standing()` and `row()` take the tab pages that show a session in place of one own session id, and say `shown`.
  - A pick settles by standing (`settles_by_standing()`): a shown session moves to its tab and starts nothing; a session of another folder, a background one without a short id, and one running elsewhere that cannot be joined are refused with today's words and open no tab.
  - Any other pick reads the list again and opens a tab after the current one (`open_new_tab(start)`): `join_session()` for a session another process runs (attach, or resume with the warning), `replace_session()` with `{ id, resumed = true }` otherwise. Both run on a copy that has no session, so no new claude function was needed. The cursor ends in the new tab's Claude window in Terminal mode; the id is kept for the folder.
  - Removed with the write into the current tab: `switch_to_session()`, `join_running_session()`, `take_listed_session()`, the prompt check of a pick, `already_shown()` and `PROMPT_HOLDS_TEXT`.
- **Closing a tab.** `:Aineo tab close`, `<Plug>(aineo-tab-close)`, `\Q`, `<C-\>Q`: from an aineo tab while another remains, `:tabclose` (the T66 close does the rest); on the last aineo tab, `:qa`; from a tab page that is not aineo's, `aineo: this tab holds no Claude Code session`.
- **A306: the stop of a closed tab does not hold the editor.** `stop.stop_together_in_background()` and `aineo.claude`'s `stop_sessions_in_background()` step the same keys and waits as the blocking stop from a timer, and are left to the quit once `v:exiting` is set (the quit stops every home in `started_homes`, the ones still stopping among them). `finish_closing()` uses it. `new_tab()` no longer refuses while a stop runs: the first tab's homes are taken up again only once their Claude Code has ended, and a tab opened before is made of copies.
- **Keys, health, help.** `\Q` and `<C-\>Q` in the health check's prefix and terminal sections; the help's intro, *aineo-tabs*, `:Aineo-sessions`, `:Aineo-new`, `:Aineo-tab`, `<Plug>(aineo-tab-close)`, `\Q`, `<C-\>Q`, HEALTH CHECK and LIMITS (*The session list*, *The new session key*, *Several tabs*).

## Decisions and spec conflicts

- **Rulings of the orchestrator on the packet's readings, 2026-10-15 (assumptions, never the user's decisions).**
  - **A314:** a pick no longer refuses on "Claude Code exited" or "a claim made while the menu was open" (it writes into no current tab); the list still refuses while the current tab's Claude Code is not ready or a claim holds. Two cases pin it.
  - **A315:** the list, the standing and a new tab's start use `kept_places().working_directory` (D63), not the current tab's `session_directory()`; for a single-tab Neovim after `:cd` the first tab keeps `getcwd()` (A298), the list does not.
  - **A316:** `aineo.claude`'s now-unused `stop_sessions()` stays for the refactor packet (A303).
  - **A318:** `finish_closing()` is the first line of `new_tab()`, so the pending close-stop runs while the first tab's homes still hold the start it stops.
  - **A319:** a pick of a session whose closed tab's Claude Code still stops is refused, naming the session, via a `stopping` list beside `closing`.
  - **A320:** with two tabs on one session, a pick from a tab that shows it stays there, otherwise it moves to the lowest numbered tab that shows it.
- **The boundary was widened** to `lua/aineo/claude/stop.lua` and `lua/aineo/claude/init.lua` (A306, the standing and row forwards), to `tests/helpers/entry_tabs.lua` (`open_tab_when_stopped()` removed, a typed-key probe added), to `tests/test_entry.lua`, `tests/test_entry_prefix.lua`, `tests/test_entry_terminal_keys.lua`, `tests/test_plugin.lua` and `tests/test_health.lua` where a pin of the keys moved, and to a new `tests/test_claude_stop_background.lua`. Declared in the brief's amendment.
- **A blocked editor is told apart by typed keys, not by requests.** `vim.wait` serves the test's RPC requests while a stop waits, so `child.lua_get('1')` answers in 4 ms even under the old blocking stop (measured); only a typed key waits. The pin types `:lua …` and waits for the flag (`tabs.type_probe()`), and a first version that timed RPC requests passed on the old code and was dropped.
- **`plugin/aineo.lua` grew and shrank:** the pick code is shorter than before (three functions and two messages gone), the close and the helpers add about 80 lines. The tab code stays in the file (A303).
- **The folder's list of tabs** is T65's file and T68's to write: closing writes none, so "it leaves the folder's tabs" (U1) is T68's mutant 5.

## Red and green

One line per group of cases; *killer* is a mutant below, *—* says none was run.

| Cases | Status | Killer |
|---|---|---|
| `test_claude_agents`: row `[tab 1]`, `[tab 3]` ×2 (3 of 7 rows) | red `[running elsewhere]` / `[another folder]` for `[tab n]` | PM11 |
| … standing `shown` ×3 (3 of 7 rows) | red `elsewhere` for `shown` | PM11 |
| … the eight other rows of both tables (14 in all) | green by nature: today's standings | — |
| `test_claude_stop_background`: 7 cases | red `attempt to call field 'stop_sessions_in_background' (a nil value)` (the 6th, the raise, red on its message) | PM8 (returns at once), PM13 |
| … a quit goes on without the background stop's keys (deaf) | written after the code, green; killed by PM13 (4 Ctrl-C expected, more seen) | PM13 |
| `test_entry_tab_close`: handles typed keys while a deaf Claude Code stops, and that Claude Code still ends | red: the probe not answered in 1.5 s (the key waited 11.2 s) | PM8 via `test_claude_stop_background`; the entry case: `finish_closing()` blocking |
| … opens a tab made of copies while the first tab's Claude Code still stops | red: 1 tab page of 2 (refused) | PM7 |
| … the close by command, `<Plug>`, `\Q`, `<C-\>Q` in Terminal and Insert mode (5 rows) | red: the second Claude Code never ended | PM5, PM6 |
| … lets the copies go, takes the entry off and saves the draft | red: copies left | — |
| … a tab attached to a background session: Ctrl+Z alone | red: no `detach` | PM3 |
| … the last tab quits as `:qa` does (2 cases), refuses with unsaved changes, closes nothing from a plain tab page | red: `\Q` mapped nothing | PM4, PM5, PM6 |
| … is left to the quit when Neovim quits while the tab's Claude Code still stops | written after the code, green | — |
| `test_entry_sessions`: rows (3 cases, first row `[tab 1]`; a two-tab case) | red `[running elsewhere]` for `[tab n]` | PM11 |
| … a pick of this terminal's row; of a row another tab shows | red: window `terminal`; tab 2 for tab 1 | PM1, PM12 |
| … a pick of a switchable row (opens the tab, writes nothing, keeps the id, with a draft, after an exit, after a claim, from Terminal mode, by a link) | red: 1 tab page of 2 | PM2, PM9, PM10 |
| … attach (taken since the list, running, with a draft, both kinds) and the resume with the warning | red: 1 tab page of 2 | PM10 |
| … an attached window stays attached when another session is picked | red: 1 tab page of 2 | — |
| … after the first tab closed | written after the code, green; shares the reopen path | — |
| … refusals (no id, gone, relist, another folder ×3, no pid, no short id) | green by nature: the refusal and no tab were both true before | — |
| pins moved: `:Aineo` usage, completion and description, `test_plugin`, `test_health`, `test_entry_prefix`, `test_entry_terminal_keys`, `test_entry` | red against the old keys, green on this tree | — |

## Mutants

Each is the literal edit applied to the committed file, run on a narrowed copy of the covering test file, then restored with `git checkout`. Kills are assertions.

| # | Edit | Killed by |
|---|---|---|
| PM1 (plan 1) | `settles_by_standing()`: `return standing ~= 'switchable' and standing ~= 'shown'` for `return standing ~= 'switchable'` | sessions › a pick of a row another tab shows |
| PM2 (plan 2) | `pick_listed_session()`: after `opened.start_on_session(current, now)` add `homes.claude.write_to_session('\27[200~/resume ' .. current.session_id .. '\27[201~\r')` | sessions › writes nothing into the current tab; made while the prompt holds a draft |
| PM3 (plan 3) | `stop.lua` `PRESSES_BY_WAY`: `detach = { { keys = CTRL_C, … } }` for `CTRL_Z` | close › a tab attached to a background session |
| PM4 (plan 4) | `close_current_tab()`: `vim.cmd('qall!')` for `vim.cmd.qall()` | close › the last tab with unsaved changes (first run a crash, a closed channel; the case was changed and the mutant run again: assertion) |
| PM5 | `close_current_tab()`: `#remaining >= 1` for `#remaining > 1` | close › the last tab ×2 |
| PM6 | `close_current_tab()`: delete the `if not tab_of_current_page()` block | close › from a tab page that is not aineo's |
| PM7 | `first_tab_can_be_taken_up_again()`: `return not vim.tbl_contains(tab_list, module_tab)` | close › opens a tab made of copies |
| PM8 | `stop_sessions_in_background()`: `stop_running_sessions(homes_to_stop(sessions)); vim.schedule(on_done)` for the background stop | stop background › returns at once |
| PM9 | `open_new_tab()`: `start = function(tab) tab.start_in_new_tab() end` for `start = start or …` | sessions › a switchable row opens a tab |
| PM10 | `claude_terminal_on_session()`: `if true then` for `if claude.can_join_session(listed) then` | sessions › a switchable row; attaches a new tab |
| PM11 | `agents.standing()`: `if false then return 'shown'` | agents › row ×3, standing ×3 |
| PM12 | `settles_by_standing()`: delete `vim.api.nvim_set_current_tabpage(page)` | sessions › a row another tab shows |
| PM13 | `stop.stop_together_in_background()`: delete the `v:exiting` guard | stop background › a quit goes on without the background stop's keys |

## Fix round (A314–A320)

Each new behaviour had its case seen failing first; the cases and mutants are literal below.

| Case | Status | Killer |
|---|---|---|
| close › opened in the same command as the close of the first tab, whose Claude Code had exited, reaches ready (A318) | red: no start recorded for the new tab | FM1 |
| sessions › a pick of the session of a tab just closed, whose Claude Code still stops, opens no tab and says so; once it has stopped it opens one (A319) | red: the old warning `also open in another Claude Code` | FM2, FM6 |
| sessions › a pick of a session two tabs show, from a tab that shows it, stays in that tab (A320) | red: moved to tab 1 | FM4, FM3 |
| sessions › … from a tab that does not, moves to the lowest numbered of them (A320) | green by nature: the lowest was the behaviour; it pins the mark and the move | FM3 |
| stop background › marks none of the sessions stopped when one is no session home (tests 3) | written against the survivor M-B; first version survived because `start_copy()` waited 5 s for the gated fake, the list run timed out and the start had launched; `start_copy()` waits for nothing now | FM5 |
| close › stops nothing and quits nothing while a buffer has unsaved changes: waits for the E37 message or a Ctrl-C (tests 6) | green, kept | PM4b |
| hygiene: `stop_the_child()` with `pcall` (tests 2); help grammar and reflow (tests 7); two titles; docstring clause (attack 4 = tests 1) | — | — |

The fixed waits that prove an absence stay where no event exists to wait on: `vim.wait(300)` in the three pick cases (this tab's own row, a row another tab shows, the write into the current tab) and the wait of the same-command case for a stale stop to show (`STALE_STOP_REACHES_MS`, 6 s, ending at the first Ctrl-C or exit).

| # | Edit | Killed by |
|---|---|---|
| FM1 | `new_tab()`: delete the first line `finish_closing()` | close › opened in the same command |
| FM2 | `settles_by_standing()`: `elseif false then` for `elseif stops_in_closed_tab(listed.session_id) then` | sessions › a pick of the session of a tab just closed |
| FM3 | `sessions_shown_in_tabs()`: `math.max(shown[id] or 0, tab_number(tab))` for `math.min(shown[id] or math.huge, tab_number(tab))` | sessions › two tabs show ×2 |
| FM4 | `settles_by_standing()`: `if page and current then` for `if page and not (current and current.session_id() == listed.session_id) then` | sessions › from a tab that shows it, stays |
| FM5 | `homes_to_stop()`: mark `home.session.stopped = true` inside the validating loop, delete the second loop | stop background › marks none of the sessions |
| FM6 | `finish_closing()`: delete the removal from `stopping` in `finish_each()` | sessions › a pick of the session of a tab just closed (it never opens one after the stop) |
| PM4b | `close_current_tab()`: `vim.cmd('qall!')` for `vim.cmd.qall()` | close › unsaved changes, by the Ctrl-C count assertion (the lines before it pass under the mutant, as the tests review measured) |

## Suites

- Whole suite, on the code tree `66d8709`, Neovim 0.12.5, on the host, `AINEO_TEST_JOBS=4 AINEO_TEST_RUN_LIMIT_MS=2700000 make test` (the host was loaded by other agents' suites, load average 35 and more): 3721 cases in 98 files, `Fails (0)`. After the fix round, on the code tree of its last code commit, the same command: 3726 cases in 98 files, `Fails (0)` (load average 20 and more). The first whole run, before the last two test additions, ran 3720 cases in 98 files with one failure, the usage text pinned in `tests/test_entry.lua`, which was then moved.
- `make lint`: stylua and selene clean.

## Open threads

- M1 and M2 of the plan (two real Claude Codes) and a pick with the real Claude Code are the user's checks (D10).
- `stop_sessions()` is unused by the plugin (above).
- Two tabs on one session: the list marks the lowest place; no case pins the choice between two.
- The folder's list of tabs (U1's "leaves the folder's tabs") is T68's.
- A quit that comes while a background stop is mid-way presses the quit's keys again from the start for that tab: harmless (the Claude Code is on its way out) and one stop longer at worst.

## Task lines

- [X] T67 — held; the knowledge pass marks it after the merge. Decided on the line: the pick no longer refuses when the current tab's Claude Code has exited or a claim was made meanwhile; the list still refuses while the current tab's Claude Code is not ready; `stop_sessions()` is unused and left; the stop of a closed tab is in the background (A306) and a tab opened while the first tab still stops is made of copies.

## Commits

- PR #216, `feature/t67-tab-pick-close`, head `1732462` (7 commits), merged by rebase into `dev` as `48df991` (the brief's amendment at dispatch), `aa52db9` (a pick of `\S` in a new tab, and `\Q`), `4c9bb19` (the pick after the first tab closed, and the refused quit, pinned), `afcb72b` (this note), `c970f30` (the fix round: the close-stop of a reused tab, the closing pick, two tabs on one session), `d44ad8b` (the marks-none case sees a start still waiting for the list), `5b99ffc` (the fix round in this note).
- Released in v0.2.35 (PR #217, `main` `6ccd054`).
