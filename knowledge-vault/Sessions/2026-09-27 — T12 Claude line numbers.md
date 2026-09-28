# 2026-09-27 — T12 Claude line numbers

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t12-claude-numbers` · **Pull request:** #84 into `dev` (a regular packet); its fix round by the same implementer agent

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (D16, D27; C1, C2, C7; D13)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t12-claude-numbers.md` with its `## Amendment — 2026-09-27`, and the brief reviews `brief-review.md` (T12's part) and `brief-review-t12-amendment.md` (findings 1 to 15)
- [[Sessions/2026-09-25 — T7 entry point]] — how the prefix is mapped
- [[Sessions/2026-09-27 — T19 Claude resume]] — `follow_claude_terminal()`, the fallback's hand-off to the layout
- [[Sessions/2026-09-26 — T21 Claude exit]] — a Claude window left on an empty buffer after a wipe
- PR #84's three reviews — attack (A1 to A5), test integrity (I1 to I13), records (R1 to R8) — answered by the fix round below

## Context

**Goal:** T12, under D16 and D27: `\tcn` toggles the line numbers of Claude's window, through `:Aineo claude-numbers` and `<Plug>(aineo-claude-numbers)` beside it (C1), with its line in `:checkhealth aineo` (C7) and its help.

The user's request, 2026-09-25: “A toogle for line number for the claude buffer "\tcn" as the command” (D16). D27, the user's decision of 2026-09-27, asked after the amended brief review measured that aineo starts each terminal hidden: “Stay as I left it (Recommended)” — aineo remembers the toggle for as long as the editor runs and applies it to every new Claude terminal in that window — over “Reset with each terminal”.

## What was done

- **`lua/aineo/layout/init.lua`** (C2): one new entry point, `toggle_claude_numbers()`. It hides `'number'` and `'relativenumber'` when Claude's window shows either, remembering what it showed, and otherwise shows those again, or `'number'` alone when the window never had any. It sets them for the buffer the window shows, as `:setlocal` does (`vim.wo[win][0]`, T16's idiom). The values it set are kept in the layout's state for the editor's life, and `keep_claude_numbers()` shows them again at the end of `open()` and in `follow_claude_terminal()`, only while Claude's window shows Claude's terminal. Without a Claude window — none made, closed, or left on an empty buffer once its terminal was wiped — it warns once at `WARN` and changes nothing. `focus()`'s own test for a gone window is now the shared `shows_own_buffer()`, which the toggle uses too. **Corrected by the fix round:** "'number' alone when the window never had any" was false — the toggle gives `'number'` alone whenever it has hidden none before, which includes a window whose numbers the user cleared by hand (A4, R5); "left on an empty buffer" leaves out a Claude window left on a file Neovim showed there after a wipe, where the toggle warns too (A5); `shows_own_buffer()` is renamed `has_window_and_buffer()`, since it never checks that the window shows the buffer (R2); and the re-apply is narrowed to a new terminal or a new window (A1, below).
- **`plugin/aineo.lua`** (C1): `claude-numbers` in `SUBCOMMANDS`, `ACTIONS` (requiring the layout inside the callback) and `PREFIX_KEYS` (`tcn`); `:Aineo`'s description; `map_prefix()`'s and `PREFIX_KEYS`' docstrings. `start_up` and `run()` untouched. **Boundary note (R8, added by the fix round):** `map_prefix()` is reached by `start_up`, which the brief put out of bounds; its docstring-only edit ("keys", and the sentence on a user's mapping of only the start of a sequence) was forced by `documentation-discipline`, and the packet's report filed it as "in the brief", which it was not.
- **`lua/aineo/health.lua`** (C7): one record, `{ key = 'tcn', subcommand = 'claude-numbers' }`; `check_prefix_key()`, the only reader of `key`, builds `prefix .. key` and takes three characters as it takes one.
- **`doc/aineo.txt`**: the introduction's key list; in `*aineo-commands*`, "six actions" and `*:Aineo-claude-numbers*`; in `*aineo-mappings*`, `*<Plug>(aineo-claude-numbers)*`; in `Prefix keys ~`, "these keys" for "one key", `*aineo-\tcn*`, and the overlap paragraph's other direction (a user's own `\t` or `\tc` waits for `'timeoutlen'`). T19's sentence "Of the actions, only `open` restarts an exited Claude Code" stays true.
- **Tests:** `tests/test_layout_claude_numbers.lua` (new, 14 cases), `tests/test_entry_claude_numbers.lua` (new, 9 cases), `tests/test_entry_prefix.lua` (a `tcn` row in the parametrized prefix cases, and two cases for a user's own `\t` and `\tc`), and the pins of the subcommand list: `tests/helpers/entry.lua`'s `M.USAGE`, `tests/test_entry.lua`'s completion pin and its four "five" case names, `tests/test_plugin.lua`'s keymap list, and `tests/test_health.lua`'s five per-key lists, two counts and nine index reads.

## Unit list (stated before the first test)

1. L1 — the toggle hides `'number'` and `'relativenumber'` in Claude's window.
2. L2 — toggled again, it shows the values the window had (three combinations).
3. L3 — a Claude window that never had line numbers gets `'number'`.
4. L4 — no other window's numbers change: the Report, Input, the file column.
5. L5 — the current window, its cursor and the mode stay.
6. L6 — never opened: one warning, nothing changed.
7. L7 — Claude's window closed: the same.
8. L8 — Claude's window left on an empty buffer after its terminal was wiped: the same.
9. L9 — from another tab: Claude's window in the layout's tab is toggled; the tab, window and cursor stay.
10. L10 — never toggled, a new terminal keeps the user's numbers.
11. E1 — the three doors, `\tcn`, `<Plug>(aineo-claude-numbers)` and `:Aineo claude-numbers`, with the completion, usage, keymap and prefix pins.
12. E2 — through a door, with no layout: one warning, no error.
13. E3 — a user's own `\t` or `\tc` stays, and `\tcn` is mapped too.
14. H — the health check's key.
15. D — the help's tags.
16. CN9 — hidden numbers stay hidden in the terminal `\o` restarts Claude Code in.
17. CN9 — and in the new session T19's fallback starts.
18. CN9 — and in the terminal `\c` starts once Claude's terminal was wiped.
19. CN3 — a file opened from Claude's window shows the user's numbers.
20. Claude's window that `\o` opens again after a close stays hidden.

L11 joined the list during unit 17: `follow_claude_terminal()`'s docstring said it re-applies the numbers when Claude's window shows the new terminal, and the code did not check that; a test pinned it before the check was written.

## Red and green

Every test the packet adds, once each. "Crash" means the red was an error, not an assertion. 18 of the 30 were seen red and 12 arrived green. Two reds began with a crash: L1, which then failed by assertion, and L3, which only ever failed by a crash. **Corrected by the fix round (R3):** the packet's report said "SEEN RED: 20" and the brief carried "3 first by a crash"; both were false — this table was right.

| Test | Status |
|---|---|
| layout › toggling › hides `'number'` and `'relativenumber'` | red: first `attempt to call field 'toggle_claude_numbers' (a nil value)` (crash), then, with the empty function, assertion `{number = true, relativenumber = true}` against `{false, false}` |
| layout › again › shows the line numbers Claude's window had (×3) | red, assertion: `{false, false}` against each combination |
| layout › toggling › gives `'number'` when it never had line numbers | red, crash: `attempt to index local 'numbers' (a nil value)` — the missing default itself |
| layout › toggling › leaves the other windows' numbers | green by nature (`vim.wo[window][0]` names Claude's window); killed by M1 |
| layout › toggling › leaves the current window, cursor and mode | green by nature; killed by M2 |
| layout › another tab › hides them in the layout's tab | green by nature (an option set by window id works across tabs, as the brief review measured); killed by M3 |
| layout › another tab › leaves the tab, window and cursor | green by nature; killed by M4 |
| layout › never toggled › user's own numbers for a new terminal | green by nature (nothing is applied before a toggle); killed by M5 |
| layout › once hidden › not given to another buffer when following a terminal | red, assertion: `{false, false}` against `{true, false}` |
| layout › no Claude window › never opened | red, assertion: `succeeded = false, told = {}` |
| layout › no Claude window › Claude's window closed | red, assertion: `succeeded = false, told = {}` |
| layout › no Claude window › left on an empty buffer after a wipe | red, assertion: `numbers = {false, false}, told = {}` |
| entry › are hidden, telling the user nothing, by (×3 doors) | red, assertion: `{true, false}` against `{false, false}` |
| entry › once hidden › stay hidden in the terminal `\o` restarts | red, assertion: `{true, false}` against `{false, false}` |
| entry › once hidden › stay hidden after the fallback | red, assertion: the same |
| entry › once hidden › stay hidden in the terminal `\c` starts after a wipe | green, spent by the `\o` unit (`keep_claude_numbers()` after `reopen_closed_windows()`); killed by M9 and M10a |
| entry › once hidden › stay hidden in the window `\o` reopens | green: Neovim gives the reopened window the terminal's last options, and `keep_claude_numbers()` re-applies them; M10a (the re-apply removed) survives, M10b (the brief's first reading: reset to the user's defaults) kills it |
| entry › once hidden › a file opened from Claude's window shows the user's own | green by nature (`:setlocal` scope); killed by M11 (the `:set` form) |
| entry › with no layout › `\tcn` warns once | green, spent by L6 and E1; killed by M12 |
| prefix › `tcn` row of four prefix cases | red, assertion: `maparg` empty |
| prefix › `tcn` row of "maps nothing when it is false" | green by nature (nothing was mapped); killed by M14 |
| prefix › a user's own `\t` / `\tc` stays, and `\tcn` is mapped (×2) | green, spent by E1; killed by M13 |

The existing pins changed for E1, H and D were each seen red before the code: `test_entry.lua`'s four renamed cases (narrowed copy of its `:Aineo` group, `Fails (4)`), `test_plugin.lua`'s keymap list (`Fails (1)`), `test_health.lua` (`Fails (17)`: the 16 edited pins and the comparison with `plugin/aineo.lua`'s mappings at line 600), `test_doc.lua`'s derived-tag case (`Left: { ":Aineo-claude-numbers", "<Plug>(aineo-claude-numbers)", "aineo-\\tcn" }`).

## Mutants

Each a literal edit of the committed file (`64116f2`), run alone from a pristine copy against a narrowed copy of its group under `.tests/t12-*.lua` (`make test_file`), restored and compared byte for byte (`.claude/local/orchestrator/t12-mutants.py`). All ran on 0.12.5; the logs name neither the Neovim nor the sha (R4), so "0.12.5" rests on the host's `nvim` being 0.12.5.

**Added by the fix round (R7):** there is no M8. The runner, the logs and the author's notes never defined one: the number was skipped, and no mutant was run and dropped. Of the 14 that ran, none survived; the PR body's "none survived" was true only of those. The test-integrity review ran 20 more on `430937e`, and 6 of them survived the whole suite on 0.12.5 (its R4, R5, R7, R10, R18, R19). Each is killed on both versions by a pin the fix round adopted (below).

| # | Literal edit | Group | Result |
|---|---|---|---|
| M1 | `show_line_numbers()`: `vim.wo[window][0].number = …` / `.relativenumber = …` → `vim.o.number = …` / `vim.o.relativenumber = …` | layout › toggling (4) | killed, assertion, 3 of 4 (the other windows' case among them) |
| M2 | toggle: `vim.api.nvim_set_current_win(state.windows.claude)` before `local shown = …` | layout › toggling (4) | killed, assertion (current window case) |
| M3 | toggle's guard: `or vim.api.nvim_win_get_tabpage(state.windows.claude) ~= vim.api.nvim_get_current_tabpage()` added | layout › another tab (2) | killed, assertion (hides in the layout's tab) |
| M4 | toggle: `vim.api.nvim_set_current_tabpage(vim.api.nvim_win_get_tabpage(state.windows.claude))` before `local shown = …` | layout › another tab (2) | killed, assertion (tab, window, cursor) |
| M5 | state: `claude_numbers = nil` → `claude_numbers = { number = false, relativenumber = false }` | layout › never toggled (1) | killed, assertion |
| M6 | `keep_claude_numbers()`: `has_window('claude') and vim.api.nvim_win_get_buf(state.windows.claude) == state.buffers.claude` → `shows_own_buffer('claude')` | layout › once hidden (1) | killed, assertion |
| M7 | toggle's guard: `shows_own_buffer('claude')` → `has_window('claude')` | layout › no Claude window (3) | killed, assertion (the wiped case) |
| M9 | `open()`: `keep_claude_numbers()` moved from after `wrap_right_column()` to right after `validate_arrangement(arrangement)` | entry › once hidden (5) | killed, assertion: `\o` and the wiped route |
| M10a | `open()`: `keep_claude_numbers()` removed | entry › once hidden (5) | killed, assertion: `\o` and the wiped route; the reopened-window case survives (Neovim's own behaviour) |
| M10b | M10a, plus in `reopen_closed_windows()` after Claude's window opens: `vim.wo[state.windows.claude][0].number = vim.go.number` and `….relativenumber = vim.go.relativenumber` | entry › once hidden (5) | killed, assertion: `\o`, the wiped route and the reopened window |
| M11 | `show_line_numbers()`: `vim.wo[window][0].…` → `vim.wo[window].…` (the `:set` form) | entry › once hidden (5) | killed, assertion (the file case) |
| M12 | toggle: `vim.notify(NO_CLAUDE_WINDOW, vim.log.levels.WARN)` / `return` → `error(NO_CLAUDE_WINDOW, 0)` | entry › with no layout (1) | killed, assertion (an `ERROR` through `run()`) |
| M13 | `has_global_mapping()`: `or vim.startswith(typed, mapping.lhsraw)` added | prefix › the user's own mapping (5) | killed, assertion: both overlap cases |
| M14 | `map_prefix()`: `vim.keymap.set('n', '\\tcn', plug_mapping('claude-numbers'))` before the `return` of `prefix == false` | prefix › the prefix (30) | killed, assertion: the `tcn` row of "maps nothing" |

## Verification

Whole suite, `make test`, run on the code of commit `64116f2`. The one later commit adds only this note.
- **0.12.5** (the host's `nvim`): `Total number of cases: 1257`, `Fails (0) and Notes (0)`, exit 0, 938 s. `vm.loadavg` was `201.55 162.60 117.89` before and `185.84 166.49 146.69` after.
- **0.11.6** (`<builds>/nvim-0.11.6/nvim-macos-arm64/bin` first on `PATH`): `Total number of cases: 1257`, `Fails (0) and Notes (0)`, exit 0, 919 s. `vm.loadavg` was `216.14 174.61 150.06` before and `210.40 153.18 152.41` after. T17's timing case in `tests/test_report_paths.lua` passed.
- **The count:** the baseline's 1227 cases, plus 14 in the layout suite, 9 in the entry suite, and 7 in the prefix file (five `tcn` rows and two overlap cases).
- **Lint:** `make lint` passes: StyLua is clean, and selene reports `0 errors, 0 warnings`.
- **§1 deep-require check of `modularity`:** it prints only requires inside a module's own directory, and none is new.
- **Added by the fix round (R4):** these two suite logs name neither the Neovim that ran nor the sha, and they are byte-identical (`cmp`). The version rests on the `PATH` of each command and the sha on the timestamps. The fix round's logs carry `nvim --version`, `uptime` and the sha at their head.

## Decisions & reasoning

- **Where the window logic lives:** the layout (C2), as the brief says; `plugin/aineo.lua` only calls `toggle_claude_numbers()`, and nothing reaches into the layout's tables.
- **The toggle warns itself**, as the layout already warns of a file column with no room, and as Send warns: `aineo: no line numbers toggled — there is no Claude window; open aineo’s layout to make one`, after Send's `aineo: nothing sent — there is no Input; open aineo’s layout to make one`.
- **The toggle decides from what Claude's window shows now,** not from what it remembers: that is what the user sees when they press the key (CN1).
- **`:setlocal` scope, and a re-apply (D27):** the only form that keeps CN3, measured by the brief review (finding 1a) and pinned here (M11).
- **The re-apply only while Claude's window shows Claude's terminal**, so another buffer there keeps the user's numbers (L11, M6).
- **`focus()` and the toggle share `shows_own_buffer()`**, so "no Claude window" means one thing in both (the amendment's "as `focus()` counts it"). **Corrected by the fix round (R2):** the helper is now `has_window_and_buffer()`. It checks that the window exists and that its buffer was not wiped, never that the window shows that buffer. That is why `\tcn` acts on a help buffer shown in Claude's window: the guard passes while Claude's terminal is valid anywhere.

## Readings for the MVP review

The orchestrator's, as the brief and its amendment give them:
- the subcommand `claude-numbers` and `<Plug>(aineo-claude-numbers)`;
- CN1 clears `'relativenumber'` together with `'number'`;
- CN2 restores the values the window had when they were hidden, and gives `'number'` to a window that never had any — in the code, to a window whose numbers aineo has hidden none of before (A4);
- CN4's warning is the toggle's own, at `WARN`, not an error through `run()`;
- CN4b: from another tab, `\tcn` toggles Claude's window in the layout's tab;
- `\o`'s rebuilt Claude window keeps the numbers hidden (Neovim's own behaviour, and D27's re-apply);
- a user's own `\t` or `\tc` now waits for `'timeoutlen'`; the help says so beside the `\sa` example.

The author's:
- ~~**`\o` re-applies the remembered toggle on every open**~~ — **withdrawn by the fix round.** It was true of `430937e`, but no probe of the author's measured it; the records review measured it (`records84-probe.lua`, both versions). The attack review then showed the re-apply fought the user on `\i` and `\r` too (A1), and the orchestrator's decision 1 narrowed it: numbers the user sets by hand in Claude's window stay until a new terminal or a new window comes.
- **A window split from Claude's window, showing the terminal, shows the numbers hidden too**: Neovim copies a window's local options on a split. Another buffer in that split shows the user's own. **Corrected by the fix round (R1):** "Measured on 0.12.5 and 0.11.6 by a throwaway probe run through `make test_file`" named a probe whose results were written to a file that went with the author's worktree; the probe logs on record are byte-identical and hold no value, and the script left in the scratchpad is another file, a print script that never tested this reading. The records review measured it with `records84-probe.lua` on `430937e`, green on both versions (`{ split_terminal = false, split_other = true }`), and the fix round re-ran that probe on its own code: green on both versions.

The orchestrator's, from the fix round (A3), which the user may change at the review:
- **A toggle pressed while Claude's window shows another buffer** (a help buffer, a `:terminal` of the user's) acts on that buffer, and is the remembered choice: Claude's terminal gets the same numbers when it next comes back to that window, by hand or by aineo, and so does every new Claude terminal there. A terminal whose numbers were `'number'` and `'relativenumber'` then loses its `'relativenumber'` if the toggle, pressed on a buffer with none, gave `'number'` alone (the attack review's LP3). It loses it too when the toggle hid that buffer's numbers: they are recorded as the ones to show again (`claude_numbers_before_hiding`), so the next toggle gives Claude's terminal that buffer's numbers, not its own — a buffer showing `'number'` alone gives it `'number'` alone (the re-measure's finding 2, its probe RP8, on both versions). **So a toggle on another buffer does two things:** it sets the numbers Claude's terminal gets when it next comes back, and, when it hides, the numbers every later toggle shows again. The help says both since the correction.

## The fix round (PR #84's three reviews)

The same implementer agent, on `feature/t12-claude-numbers` from `430937e`, under the orchestrator's fix-round brief (decisions 1 to 18).

### What changed

- **The re-apply, by D27's letter (A1, decision 1).** It used to re-apply at the end of every `open()`, so `\o`, and `\i` or `\r` reopening a window, undid numbers the user set by hand after `\tcn`. The layout now remembers the window and the buffer the toggle's numbers were last shown for (`claude_numbers_shown_in`, set by `show_claude_numbers()`). `keep_claude_numbers()` re-applies only when `misses_claude_numbers()` holds: Claude's window shows Claude's terminal, and that window or that terminal is new. This is the attack review's fix A (`fixA.diff`), adopted and credited.
- **A terminal brought back by hand (A2, decision 2).** A `BufWinEnter` autocommand for Claude's terminal (`keep_claude_numbers_on_entry()`) calls the re-apply. This is the attack review's fix B (`fixAB.diff`), adopted and credited.
- **A3 (decision 3):** no code. The limit and the readings say what the toggle does on another buffer.
- **Records (R2):** `shows_own_buffer()` → `has_window_and_buffer()`.
- **Help, docstrings and `ABSOLUTE_LINE_NUMBERS`' comment:** they now describe the re-apply as the code does (R6). `'number'` alone comes "when aineo has hidden none before" (A4, R5). The warning covers a Claude window left on a file after a wipe (A5).
- **The help entry moved** below the paragraphs that describe `claude`, which it had split from their command (noted by the attack review for records).
- **Adopted pins (I1 to I7),** each credited to the test-integrity review:
  - D27 for a toggle that showed numbers (I1).
  - `open()`'s build branch after the layout's tab was closed (I2).
  - The `\o`-reopen pin that proves aineo's re-apply, not Neovim's restore (I3).
  - L1 over all three combinations, and L2's first toggle checked (I4).
  - L11 with a terminal, and a terminal of the user's own in another tab (I5). The latter now hands the layout a new Claude terminal: under fix A, reopening with the same terminal re-applies nothing, so R5 survived the pin as built, and both new files whole, on 0.12.5.
  - A user's own mapping of each whole key sequence (I6).
  - The no-layout case asserting the window's numbers (I7).

### Seen red first, on `430937e`, by assertion, on 0.12.5 and 0.11.6

| Test | Red |
|---|---|
| entry › set by hand after `\tcn` › stay as the user set them, on `\o` / `\i` (Input's window closed) / `\r` (the Report's closed) | `number`: `left = false, right = true`, ×3, both versions |
| entry › once hidden › stay hidden in the new session's terminal the user brings back by hand, after the fallback started it while another buffer showed there | `number`: `left = true, right = false`, both versions |
| layout › toggled while Claude's window showed another buffer › are given to Claude's terminal when it comes back | `number`: `left = true, right = false`, both versions |

The fallback case first failed on 0.12.5 for two wrong reasons, each corrected before its red was counted:
- a wait on readiness `ready`, which a terminal shown in no window never reaches (T19's recorded limit A5);
- a `...` inside a nested function.

### Mutants of the fix round

Each is a literal edit of the committed code (`9a12815`–`5c1ee7c`). Each was run alone against a narrowed copy of its group (`.claude/local/orchestrator/t12f-mutants.py`, logs `t12f-mutant-<id>-<version>.log`, each headed by `nvim --version`, `uptime` and the sha). After each run the source was restored and compared byte for byte with the committed file.
- The author's 14 are re-taken on this code.
- The test-integrity review's mutants that the adopted pins answer are adapted to this code. Their text differs from the review's literal edits where the code moved, and the table says how.
- F1–F5 test fixes A and B.

| # | Literal edit (on this code) | Group | 0.12.5 | 0.11.6 |
|---|---|---|---|---|
| M1 | `show_line_numbers()`: `vim.wo[window][0].X =` → `vim.o.X =` | layout › toggling + when it shows them (6) | killed 5/6 | — |
| M2 | toggle: `vim.api.nvim_set_current_win(state.windows.claude)` before `local shown` | layout › toggling (3) | killed 1/3 | — |
| M3 | toggle guard: `or vim.api.nvim_win_get_tabpage(state.windows.claude) ~= vim.api.nvim_get_current_tabpage()` | layout › another tab (2) | killed 1/2 | — |
| M4 | toggle: `vim.api.nvim_set_current_tabpage(vim.api.nvim_win_get_tabpage(state.windows.claude))` before `local shown` | layout › another tab (2) | killed 1/2 | — |
| M5 | state: `claude_numbers = nil` → `{ number = false, relativenumber = false }` | layout › never toggled (1) | killed | — |
| M6 | `misses_claude_numbers()`: `and has_window('claude')` + `and vim.api.nvim_win_get_buf(state.windows.claude) == state.buffers.claude` → `and has_window_and_buffer('claude')` | layout › once hidden (2) | killed 1/2 | — |
| M7 | toggle guard: `has_window_and_buffer('claude')` → `has_window('claude')` | layout › no Claude window (3) | killed 1/3 | — |
| M9 | `open()`: `keep_claude_numbers()` moved to right after `validate_arrangement(arrangement)` | entry › once hidden (8) | killed 4/8 | — |
| M10a | `open()`: `keep_claude_numbers()` removed | entry › once hidden (8) | killed 4/8, the adopted I3 pin among them; the older reopen pin still survives it | killed 4/8 |
| M10b | M10a, plus a reset to `vim.go.number`/`vim.go.relativenumber` in `reopen_closed_windows()` | entry › once hidden (8) | killed 5/8 | — |
| M11 | `show_line_numbers()`: `vim.wo[window][0].X` → `vim.wo[window].X` | entry › once hidden (8) | killed 1/8 (the file) | — |
| M12 | toggle: `vim.notify(NO_CLAUDE_WINDOW, vim.log.levels.WARN)` + `return` → `error(NO_CLAUDE_WINDOW, 0)` | entry › no layout (1) | killed | — |
| M13 | `has_global_mapping()`: `or vim.startswith(typed, mapping.lhsraw)` | prefix › the user's own mapping (11) | killed 2/11 | — |
| M14 | `map_prefix()`: `vim.keymap.set('n', '\\tcn', plug_mapping('claude-numbers'))` before the `prefix == false` return | prefix › the prefix (30) | killed 1/30 | — |
| R3 | `follow_claude_terminal()`: `keep_claude_numbers()` removed | entry › once hidden (8) | killed 1/8 (the fallback) | — |
| R4 | `misses_claude_numbers()`: `… nvim_win_get_buf(state.windows.claude) == state.buffers.claude` → `vim.bo[vim.api.nvim_win_get_buf(state.windows.claude)].buftype == 'terminal'` | layout › once hidden (2) | killed 1/2 (I5, L11 with a terminal) | killed 1/2 |
| R5 | `keep_claude_numbers()`: after `show_claude_numbers(state.windows.claude)`, every window showing a terminal given `state.claude_numbers` | layout › once hidden (2) | survived the pin as adopted, and both new files whole (18, 16); killed 1/2 by the pin as extended | killed 1/2 |
| R7 | `map_prefix()`: `if not has_global_mapping(keys) then` → `if subcommand == 'claude-numbers' or not has_global_mapping(keys) then` | prefix › the user's own mapping (11) | killed 1/11 (I6, the `tcn` row) | killed 1/11 |
| R10 | `open()`: `keep_claude_numbers()` moved into the restore branch after `show_buffers()` | entry › once hidden (8) | killed 1/8 (I2) | killed 1/8 |
| R13 | toggle: `do return end` before `local shown` | layout › again (3) | killed 3/3 (I4, L2) | killed 3/3 |
| R18 | `misses_claude_numbers()`: `and not state.claude_numbers.number` added | entry › once shown (1) | killed (I1) | killed |
| R19 | toggle: `if shown.relativenumber and not shown.number then return end` after `local shown` | layout › when it shows them (3) | killed 1/3 (I4, `{false, true}`) | killed 1/3 |
| R21 | toggle guard: `show_line_numbers(vim.api.nvim_get_current_win(), NO_LINE_NUMBERS)` after the warning | entry › no layout (1) | killed (I7) | killed |
| F1 | `misses_claude_numbers()`: the `and not (shown_in … )` clause removed (fix A undone) | entry › set by hand (3) | killed 3/3 | killed 3/3 |
| F2 | `watch_windows()`: the `BufWinEnter` for `keep_claude_numbers_on_entry` removed (fix B undone) | entry › once hidden (8) | killed 1/8 (the fallback by hand) | killed 1/8 |
| F3 | the same edit as F2 | layout › toggled on another buffer (1) | killed | killed |
| F4 | `show_claude_numbers()`: `buffer = vim.api.nvim_win_get_buf(window)` → `buffer = state.buffers.claude` | layout › toggled on another buffer (1) | killed | killed |
| F5 | `misses_claude_numbers()`: `and shown_in.window == state.windows.claude` removed | entry › once hidden (8) | killed 1/8 (I3) | — |

Every kill in the table is an assertion (`Failed expectation`); none is a crash. R5 is the one mutant that survived a first run. It is killed on both versions by the pin as extended.

### Verification

Whole suite, `make test`, on the code of `5c1ee7c`; the commit after it touches only this note. Logs: `t12f-suite-012.log` and `t12f-suite-011.log`, each headed by `nvim --version`, `uptime` and the sha.
- **0.12.5:** `Total number of cases: 1274`, `Fails (0) and Notes (0)`, exit 0, 929 s. The tree was clean at the start. Load averages were `173.40 178.25 140.51` before and `218.61 215.83 188.98` after.
- **0.11.6:** `Total number of cases: 1274`, `Fails (1)`, exit 2, 958 s. The one tracked change at the start was this note, which no test reads. Load averages were `212.92 214.64 188.87` before and `156.53 147.28 162.03` after.
  - The failure is T17's timing case in `tests/test_report_paths.lua`, *of a line of distinct paths take at most the time limit, on arrival and on :edit*: `arrival = "3.5 s"`, `edit = "3.5 s"`. The amended brief names it as intermittent on 0.11.6, not this packet's to change, and not holding the push.
  - Re-run alone on 0.11.6 (`t12f-paths-011-run1.log`), it passed 90/90 on the first try. Load averages were `158.09 148.24 162.03` before and `160.81 149.30 162.16` after.
- **The count:** 1274 = the packet's 1257, plus 4 layout cases, 7 entry cases and 6 prefix cases.
- **Lint:** `make lint` passes: StyLua is clean, and selene reports `0 errors`.

## The correction (the re-measure of PR #84, findings 1–3)

A fresh implementer agent, on `feature/t12-claude-numbers` from `6f7e6cf`, under the orchestrator's correction brief. Scope: the re-measure's findings 1 to 3, nothing else.

- **Finding 1 — fixed.** The help's "numbers you set yourself … stay" was pinned only while Claude's terminal never left Claude's window: mutant G16 survived the whole suite. The set-by-hand group now has a fourth row, the re-measure's pin (`remeasure-pin-byhand.lua`), adopted unchanged and credited: a scratch buffer shown in Claude's window, then `\o` brings the same terminal back through `show_buffers()`.
  - It **arrived green** at the head, 4/4 on both versions: the behaviour exists since fix A and fix B.
  - **G16**, the literal edit: in `keep_claude_numbers_on_entry()`, `  if event.buf == state.buffers.claude then\n    keep_claude_numbers()\n  end` → `  if event.buf == state.buffers.claude then\n    state.claude_numbers_shown_in = nil\n    keep_claude_numbers()\n  end`. Run on the group narrowed to set-by-hand (4 cases), on `85967df`: **killed 1/4 by assertion on 0.12.5 and on 0.11.6**, the new row only, `different values at key "number", left = false, right = true` (`t12c-mutant-G16-0.12.log`, `t12c-mutant-G16-0.11.log`).
- **Finding 2 — recorded.** The orchestrator's decision A3 stands: no code. The help's first sentence now says the toggle shows the numbers "as they were when aineo last hid them, whichever buffer Claude's window showed then", and its other-buffer sentence says that numbers hidden there are those the next toggle shows Claude's terminal again, in place of its own. The A3 reading above names both effects.
- **Finding 3 — fixed.** `misses_claude_numbers()`'s gloss now names its third case: the toggle last shown there for another buffer.

### Verification of the correction

On the code of `85967df`; the commit after it touches only this note, the one tracked change at the start of each run, which no test reads. Logs `t12c-*.log` in the correction's scratchpad, each headed by `nvim --version`, `uptime` and the sha.
- **The touched files, both versions:** `tests/test_entry_claude_numbers.lua` 17 cases (16 before, and the new row), `Fails (0)`; `tests/test_doc.lua` 36 cases, `Fails (0)`.
- **Whole suite, `make test`, 0.12.5:** `Total number of cases: 1275`, `Fails (0) and Notes (0)`, exit 0, from 01:35 to 01:51 (load averages `88.62 127.01 128.52` at the start).
- **Whole suite, 0.11.6:** `Total number of cases: 1275`, `Fails (0) and Notes (0)`, exit 0, from 01:51 to 02:07 (load averages `19.34 30.09 64.18` at the start, `39.59 38.61 48.05` at the end). T17's timing case passed.
- **The count:** 1275 = the fix round's 1274, plus the new row.
- **Lint:** `make lint` passes: StyLua is clean, and selene reports `0 errors`.

## Task lines

The wave holds its marks (rule 6). The line T12 would take:

- [X] T12 — `\tcn` toggles the line numbers of Claude's window (D16), with `:Aineo claude-numbers`, `<Plug>(aineo-claude-numbers)`, its health line and help; the toggle lasts the editor's life across every new Claude terminal (D27) — regular.

## Limits

- **Another buffer shown in Claude's window** (a help buffer, which the layout does not move to the file column): the toggle acts on it, for that buffer, and remembers it, since it acts on whatever the window shows. **Corrected by the fix round:** this limit said that Claude's terminal brought back by hand showed its own last numbers until the next `\o`. That was true of `430937e` (the records review's `records84-probe.lua`, both versions), but the author's own measurement of it was not on record (R1). Since the fix round's `BufWinEnter` (A2, fix B), the terminal gets the toggled numbers as soon as it comes back: pinned by *toggled while Claude's window showed another buffer, are given to Claude's terminal when it comes back*, and the records probe's limit case now fails on exactly that value on both versions. It is recorded as a reading, the orchestrator's decision (A3), above.
- **The memory is the editor's**: a new Neovim starts with the user's own numbers (D27).
- **"No `TermOpen` autocommand reaches Claude's window"** is the brief review's measurement on both versions, not re-measured here; the pins run without any `TermOpen` autocommand of the user's.

## Open threads

- None of the packet's own.

## Commits

*Recorded after the merge.*
