# 2026-10-15 — T70 Terminal pane key

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t70-terminal-pane-key` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D18, D52, D53, D58, D59, D63, D66, **D68**, C1, C7, C12
- [[Implementation/Waves/00016-terminal-pane/plan]] › O6, O9–O11, O13, O14 (the orchestrator's assumptions A279–A292, never the user's decisions) and *Verification mutants* › T70
- [[Implementation/Waves/00016-terminal-pane/brief-t70-terminal-pane-key]], with its dispatch amendment
- [[Sessions/2026-10-15 — T69 Terminal pane]] (the shell home and the layout's third pane), [[Sessions/2026-10-14 — T66 Tabs]] and [[Sessions/2026-10-15 — T67 Tab pick and close]] (the close path)

Stage 2 of wave 16: the key, the composition root, the tab's close, the health check and the help for the terminal pane T69 built. Measured on Neovim 0.12.5, on a host whose load average was above 100 for most of the work.

## Task lines

- [X] T70 The terminal pane's key (C1, C7; D58, D68) — done on `feature/t70-terminal-pane-key`: `:Aineo pane terminal`, `<Plug>(aineo-pane-terminal)`, `\pt` and `<C-\>pt` start the current tab's shell in the folder when it runs none, show it in the terminal pane and land in it in Terminal mode; a tab's close stops its shell before its Claude Code's stop; `:checkhealth aineo` lists the keys and says which `'shell'` the pane runs; the help covers the pane, the command, the mappings, the health lines and LIMITS. Reviews and the pull request's merge are open; the knowledge pass marks the line.

## What was built

**`plugin/aineo.lua`** (hunks: `SUBCOMMAND_WORDS`, the `aineo.entry.Homes` class and its docstring, `arrangement()`, a new `focus_terminal()` beside `focus_pane()`, `actions`, `release()`, `finish_closing()`, `module_homes()`, `copied_homes()`, the `ACTIONS` list, `PREFIX_KEYS` and the command's description).

- A tab's homes gain `shell`: the module `aineo.shell` for the first tab, `aineo.shell.new()` for every copy.
- `arrangement()` hands the layout `shell = homes.shell.shell_buffer()`, so every arrangement carries the tab's live shell, or none.
- `focus_terminal()`: `homes.shell.start({ cwd = kept_places().working_directory })` first, so that a `'shell'` that cannot run raises before the layout is touched and changes no pane; then `focus_pane('terminal')`, which opens or restores the layout as `\pa` does; then `startinsert`, as `focus_claude()` asks for Terminal mode.
- The close: `release()` lets the copy's shell go (`let_go()`, after the layout's) as the tab page closes, which stops the shell and removes its handlers at once, as for every other copy; `finish_closing()` stops each closing tab's shell (`aineo.shell`'s `stop()`) at its head, before it starts the background stop of the Claude Codes, which covers the first tab's shell (the module has no `let_go()`) outside `TabClosed`, where a wipe runs none of the layout's handlers (T69, A308), and keeps a Claude Code that takes seconds to stop from keeping any shell alive.
- The quit adds nothing: `finish_closing()` returns while Neovim quits, and Neovim hangs up the shell (Q11, Q12).

**`lua/aineo/health.lua`**: the `\pt` line in *Prefix mappings* and `<C-\>pt` in *Terminal prefix mappings* (the list `PREFIX_KEYS`); a new section *Shell terminal*, between *Claude Code* and *Server socket*, that says which `'shell'` the pane runs, and warns, with advice, when its first word is not executable; the `inside-claude` line names the shell terminal beside Claude's. The check still loads only the configuration and the Claude session home.

**`doc/aineo.txt`**: the introduction's keys; *aineo-layout*; *aineo-panes* (three panes, the terminal pane's window and sizes, its folder and environment, Terminal mode on arrival, persistence, the end by `exit`, `:bdelete!` and `:bwipeout!`, the refusal when `'shell'` cannot run); *aineo-tabs* (a shell of its own per tab, the close); `:Aineo-pane`; `<Plug>(aineo-pane-terminal)`; `aineo-\pt`; *aineo-terminal-keys* and `aineo-<C-\>pt`; the autostart's list; HEALTH CHECK (*Shell terminal*, the two key sections); LIMITS (*The terminal pane*).

## The orchestrator's rulings applied (assumptions, never the user's decisions)

A279–A292 (O1–O14 of the wave plan): the key `\pt` with `:Aineo pane terminal`, `<Plug>(aineo-pane-terminal)` and the twin `<C-\>pt` (O6); the folder, whatever `:cd` or `:tcd` says (O9); `AINEO_CHILD` in the shell's environment, named in the health check (O10); Terminal mode on every arrival (O11); a tab's close stops its shell, the quit adds nothing (O13); health and help (O14).

## Spec conflicts

None. The first version of the close ran the copy's `let_go()` from `finish()`, after the Claude Code's stop; T66's case *lets its copies go* failed with the shell's autocommand group left, and the close is as the dispatch message asked: `let_go()` from `release()`, the stop of the first tab's shell scheduled at the head of `finish_closing()`. The brief's amendment carries a dated correction.

## Unit list (stated before the first test)

Key: (1) the three doors show the shell in the Report's window; (2) Terminal mode on arrival; (3) pressed again, the same shell with its output, starting nothing; (4) the folder, whatever `:tcd` says; (5) the layout opens first when none is open; (6) `\o` shows the terminal pane again; (7) a `'shell'` that cannot run: one error, no pane changed, no layout opened; (8) `<C-\>pt` from Terminal and Insert mode; (9) from a tab page that is none of aineo's; (10) `\pa`, `\g`, `\r`, `\i`, `\c` while the shell shows, and the end by `exit`. Tabs: (11) a shell of its own per tab; (12) a close by `:tabclose` and by `\Q` stops the shell and wipes its buffer, the other tab's runs on; (13) before the Claude Code's stop; (14) the first tab's close and its reuse; (15) `:qa` leaves no shell. Pins that move: (16) the command's description, its usage, its completion; (17) the mappings and the twins; (18) the user's own mapping of `\pt` and `<C-\>pt`. Health: (19) the key lines; (20) `Shell terminal`; (21) the `inside-claude` line. Help: (22) the tags.

## Red and green, test by test

**How the loop ran.** The first test (the three doors) was seen red; the production code that made it pass was written whole (`focus_terminal()` with its Terminal mode, the homes, the arrangement's shell), so the next nine cases of `tests/test_entry_terminal_pane.lua` arrived green and are pinned by a mutant each, below. The tab's close was driven by cases seen red first, and T66's pin of the second tab's groups turned red a second time and moved the design (see *Decisions*).

`tests/test_entry_terminal_pane.lua`, 30 cases, with the new helper `tests/helpers/entry_shell.lua`.

**Seen red** (message in the run):
- the three doors, *shows a shell in the Report's window, telling the user nothing, by* (3): the windows stayed `terminal, aineo://report, aineo://input` for `\pt` and `<Plug>(aineo-pane-terminal)` (neither mapped); `:Aineo pane terminal` told `aineo: :Aineo pane takes one of agent, changes`.
- *a tab that closes › stops its shell and wipes its buffer…* and *…before its Claude Code, which ignores its keys…* (2 ways each, 4): `eq(has_ended(pid), true)` got `false`, the shell kept running after `:tabclose` and after `\Q`.
- the pins that moved, against the new production code before the pin was edited: `test_entry.lua` (the command's description, 1), `test_entry_panes.lua` (usage and completion, 8), `test_plugin.lua` (the mapping list, 1), `test_health.lua` (12: the four new cases and the key lists), `test_doc.lua` (4: the cases for `<Plug>(aineo-pane-terminal)`, `aineo-\pt`, `aineo-<C-\>pt` and the derived list).
- the second tab's group list with `aineo.shell.2`, against the first design (the copy's `let_go()` from `finish()`): `test_entry_tabs_close.lua › lets its copies go…` and `test_entry_tab_close.lua › lets the tab's copies go…` (2), both `Left: { "aineo.shell.2" }, Right: {}`.

**Arrived green**, each with its reason and the mutant that kills it (the table below):
- *leaves the cursor in the shell, in Terminal mode, by* (3) and *the twin `<C-\>pt`* (2): the `startinsert` was written with the first unit; M2.
- *shows the same shell again, with its output, and starts none, after `\pa` hid it*: `start()` answers the live shell (T69); M1.
- *starts the shell in the folder, whatever `:tcd` says*: the folder was written with the first unit; M4.
- *opens the layout first, around a Claude Code it starts, when none is open* and *is shown again by `\o` once the layout's windows are gone*: the arrangement's shell was written with the first unit; M6.
- *when 'shell' is not executable* (2): the order, start before the layout, was written with the first unit; M7.
- *moves to the aineo tab used last, from a tab page that is none of aineo's*: `acting_tab()` is generic (T66); M10.
- *while the terminal pane shows › the key of another pane or window* (5): T69's layout through the keys, O5; L6 kills the `\i` row and X1 (a `\pa` that stops the shell, the tests review's) the `\pa` row; the `\g`, `\r` and `\c` rows pin behaviour that existed, with no mutant of T70's code that reaches them.
- *a shell that ends › gives the Report back…*: T69's layout through the key; L1.
- *each tab* (2): `new()` per tab (T66, T69); M11 kills the first, and the second (the other tab's pane is left as it was) has no mutant of T70's code that reaches it.
- *the first tab that closes* (2: the reuse of the first tab, and the stop before a Claude Code that ignores its keys): the stop at the head of `finish_closing()`; M3a, M3c.
- *quitting › with a shell running quits, and leaves no shell process*: Neovim's hangup (Q11, Q12); Q1 survived, see below.

Pins that moved or were added in the other files, seen red where listed above and green after:
- `tests/test_entry_panes.lua` (100 cases, 98 before): `PANE_USAGE` and the completion rows name `terminal`; two rows added (`Aineo pane t`, `Aineo pane terminal now`).
- `tests/test_entry_prefix.lua` (152, 144 before): `pt` in the key list; the user's own mapping of `\pt` and of `<C-\>pt` stays; `\p` of the user's leaves `\pt` mapped.
- `tests/test_entry_terminal_keys.lua` (204, 196 before): `pt` among the twins, in each of the four tests that run over them.
- `tests/test_plugin.lua` (5): the four mappings of the list. `tests/test_entry.lua` (50): the description.
- `tests/test_health.lua` (113, 109 before): the `\pt` and `<C-\>pt` lines, the indexes of the leader warnings (23 to 24, 22 to 23, 41 to 43), the late-prefix list, the `inside-claude` line, and four new cases of *Shell terminal* (one parametrized case of three rows, a plain `'shell'`, one with an argument and one with a quoted program, and the warning).
- `tests/test_doc.lua` (51, 48 before): the three tags.
- `tests/helpers/entry_tabs.lua`: `aineo.shell.2` among the second tab's groups, which `test_entry_tabs_close.lua` (17), `test_entry_tab_close.lua` (15) and `test_entry_tabs.lua` (37) read; `tests/helpers/entry_shell.lua` is new (the shell's buffer and pid, typing and waiting).
- The files that require `entry_tabs.lua` and were not run for the pin: `test_entry_sessions.lua` and `test_entry_tabs_routing.lua` run in the whole suite.

## Mutants

Each is the literal edit applied to a copy of the working tree, run on a narrowed copy of the covering test file (`make test_file`), the copy removed after. Every kill is an assertion (`Failed expectation for equality`; the count of those equals the count of failures), not a crash, except where a row says otherwise. The wave plan's mutants are the rows marked W.

| # | Edit | Killed by |
|---|---|---|
| M1 (W1) | `plugin/aineo.lua`: `homes.shell.stop()` added before `homes.shell.start({ cwd = … })` in `focus_terminal()` | *shows the same shell again…*: the second `\pt` gave buffer 7 where 6 was expected |
| M2 (W2) | `vim.cmd.startinsert()` removed from `focus_terminal()` | the 3 *leaves the cursor in the shell…* and the 2 twin cases (5 of 5) |
| M3a | the `for _, tab in ipairs(finishing) do run(tab.homes.shell.stop) end` loop of `finish_closing()` removed | *the first tab that closes*, both cases (2 of 6); the copies are let go by `release()` |
| M3c (W3) | the loop of M3a removed and `homes.shell.let_go or leave_as_it_is,` removed from `release()` | all 6: the 4 *a tab that closes* and the 2 *the first tab that closes* |
| M4 (W4) | `cwd = kept_places().working_directory` → `cwd = vim.fn.getcwd()` | *starts the shell in the folder, whatever `:tcd` says* |
| M5 (W5) | `'terminal'` removed from `SUBCOMMAND_WORDS.pane` | narrowed to the doors group: 2 of the 3 doors (`\pt`, `<Plug>`) by assertion, `ACTION_ARGUMENTS` being built from the words; `:Aineo pane terminal` still runs, as `ACTIONS` lists it by name. On the cases of the doors and the twin (15) it fails 13: 11 by assertion and 2 by a Lua error (`bad argument #3 to '__index'`, where the shell buffer is nil), the tests review's measure |
| P2 | the same edit, run on `tests/test_entry_panes.lua` › `:Aineo pane` | 10 of 18: the usage rows (4) and the completion rows (6) |
| M6 | `shell = homes.shell.shell_buffer(),` removed from `arrangement()` | *opens the layout first…* and *is shown again by `\o`…* |
| M7 | the `pcall(focus_pane, 'terminal')` moved before `homes.shell.start(…)` | *opens no layout when none is open* (`arrangement.shell: expected…` told, the layout opened); run on the first version both cases died, on the fixed tree the other passes because the failure is re-raised the same way |
| M8 | `homes.shell.let_go or leave_as_it_is,` removed from `release()` | `test_entry_tabs_close.lua › lets its copies go…` |
| M9 | `['pane terminal'] = focus_terminal,` removed from `actions` | the 3 doors |
| M10 | `acting_tab().actions[argument]()` → `tab_of_current_page().actions[argument]()` | *moves to the aineo tab used last…* |
| M11 | `shell = require('aineo.shell').new(),` → `shell = require('aineo.shell'),` in `copied_homes()` | *each tab › has a shell of its own…* (1 of 2) |
| T1 | `local HAS_NO_TWIN = { send = true }` → `{ send = true, ['pane terminal'] = true }` | `test_entry_terminal_keys.lua › the terminal prefix … each key mapped` for `pt`, in `t` and `i` |
| P1 | `['pane terminal'] = 'pt',` removed from `PREFIX_KEYS` | `test_entry_prefix.lua › the prefix … is \ by default` for `pt` |
| L6 | T69's: `lua/aineo/layout/init.lua`, `focus_shows_agent_pane()` → `return role == 'report' or role == 'input'` | the `\i` row of *while the terminal pane shows* |
| L1 | T69's: `show_agent_pane_as_shell_is_wiped()` returns before `local was_shown = …` | *a shell that ends…* |
| H1 | `lua/aineo/health.lua`: the `pt` entry of `PREFIX_KEYS` removed | the two *are reported in place* cases of the prefix sections |
| H2 | `shell:match('^%s*"([^"]*)"') or ` removed from `shell_program()` | the quoted `'shell'` case |
| H3 | `executable(program) == 0` → `== 1` in `check_shell()` | 4 of 4 |
| H4 | the `inside-claude` text without `or shell terminal` | the `inside-claude` case |
| H5 | `check_shell()` removed from `M.check()` | 4 of 4 |
| Q1 | `lua/aineo/shell/init.lua`: `detach = true` added to the `jobstart()` options | **survived** the quit case (1 of 1 passed) |

Q1 is not a gap in T70's code: a pty job ends on the hangup of its terminal when Neovim exits whether or not Neovim hangs it up first (Neovim 0.12.5, macOS), so `detach` changes nothing the case can see. The case pins that nothing of aineo's keeps the shell alive through `:qa` (a shell that ignores the hangup is T69's recorded limit); no mutant of T70's code reaches it, and the survivor does not make the case dead (A117).

## Decisions made in the packet

- **The copy's `let_go()` runs from `release()`, the first tab's shell is stopped at the head of `finish_closing()`.** The first version ran `let_go()` from `finish()` and left the handlers until the Claude Code had stopped; T66's pin (a closed tab's copies are gone as soon as its entry is) failed with `aineo.shell.2`. Rejected: waiting in that pin for the stop, since it would loosen T66's contract for a home that is not T66's. A shell of a copy is thus stopped inside `TabClosed`, after the layout's handlers were let go; the first tab's, whose layout stays, outside it (T69, A308).
- **No guard on the cursor landing before `startinsert`.** The first version tested that the current buffer was the shell's before asking for Terminal mode; no case could make it false (`focus_pane('terminal')` raises or lands in the shell's window), so it was removed.
- **The program of `'shell'` in the health check is read in the check**, not asked of the shell home: the check loads only the configuration and the Claude session home (`tests/test_health.lua`), and the home's splitting is private. The first version took a leading quoted stretch or the first run of non-blanks and disagreed with `:terminal` on `/bin/s"h"` (a false warning), `"/bin/sh"x` (a false OK) and `"/bin/s\"h"`; the fix round (A342) copies the shell home's word rules, so the check and `:terminal` agree on those values. Exporting the program from `aineo.shell` is left for the refactor packet (A303).

## Fix round (the attack and the tests-and-records reviews of the pull request; A341-A343, the orchestrator's assumptions)

Each fix has a case seen red first, except where said. Measured on Neovim 0.12.5.

- **A341, a layout that cannot open leaves no shell.** `focus_terminal()` starts the shell before the layout is touched; when `focus_pane('terminal')` then raises (Claude Code cannot start), the shell this call started is stopped and the layout's error re-raised. A shell that ran before the call stays. Cases: `claude.cmd` that cannot start, `\pt` -> one message, no terminal job, no shell buffer (red: one job, the shell); and the same with a shell that ran before and a Claude terminal wiped (arrived green: the shell stays, jobs and buffer as before; F2 kills it).
- **A342, the health check reads `'shell'` by Neovim's own word rules.** Cases (red): `/bin/s"h"` is reported as running (it warned), `"/bin/sh"x` warns naming `/bin/shx` (it was reported OK), `"/bin/s\"h"` warns naming `/bin/s"h`.
- **A343, a folder that is gone is said in the user's words.** `aineo: the folder aineo started in is gone, so no shell started: <dir>` (red: `settings.cwd: expected an existing directory…`; no pane changes, no shell starts).
- **Tests review 2-5, 8:** the docstring of `focus_pane()` names the terminal pane; the help's overlap paragraph says `\pa` and `\pt`; the health case count is four; the mutant table says what M5 and X1 do (above); the plan's T70 mutant 5 ("`:Aineo pane terminal` is refused with the usage line") does not hold, because `ACTIONS` lists the command by name: the knowledge pass amends the plan.
- **Tests review 6:** the same-shell case runs after `\pa` and after `\g` (arrived green; the nested-Neovim end-to-end case is not added, by the user's rule of 2026-10-11 against over-testing; the attack review's probe, a `nvim` typed into the shell, recorded `inside-claude`, and the same command under `env -u AINEO_CHILD` recorded `opened`).

| # | Edit | Killed by |
|---|---|---|
| F1 | the `if not ran_one then homes.shell.stop() end` of `focus_terminal()` removed | *stops the shell it started, telling the user once* |
| F2 | `if not ran_one then` -> `if true then` | *leaves a shell that ran before running* |
| F3 | the `isdirectory` check of `focus_terminal()` removed | *tells the user, in its own words, when the folder … is gone* |
| M1, M2, M4 | re-run on the fixed tree with the edits written for it (`homes.shell.stop()` before `start()`; `startinsert` removed; `local folder = vim.fn.getcwd()`) | M1 both rows of *after a key hid it*, M2 5 of 5, M4 the folder case |
| H6 | `quoted = not quoted` -> `quoted = quoted` in `shell_program()` | the `"/bin/s\"h"` row |
| H7 | the backslash branch of `shell_program()` -> `elseif false and …` | the `"/bin/s\"h"` row |

## Open threads

- The nested Neovim of brief item 11 is pinned in parts, not end to end: the shell's `AINEO_CHILD` (T69, `tests/test_shell.lua`), the autostart's refusal on `AINEO_CHILD` (`tests/test_entry_startup.lua`) and the health line (`tests/test_health.lua`). No case starts a `nvim` inside the shell; the attack review's probe did, and confirmed it (see the fix round).

## Commits

Recorded after the merge.
