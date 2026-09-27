# 2026-09-27 — T12 Claude line numbers

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t12-claude-numbers` · **Pull request:** into `dev` (a regular packet)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (D16, D27; C1, C2, C7; D13)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t12-claude-numbers.md` with its `## Amendment — 2026-09-27`, and the brief reviews `brief-review.md` (T12's part) and `brief-review-t12-amendment.md` (findings 1 to 15)
- [[Sessions/2026-09-25 — T7 entry point]] — how the prefix is mapped
- [[Sessions/2026-09-27 — T19 Claude resume]] — `follow_claude_terminal()`, the fallback's hand-off to the layout
- [[Sessions/2026-09-26 — T21 Claude exit]] — a Claude window left on an empty buffer after a wipe

## Context

**Goal:** T12, under D16 and D27: `\tcn` toggles the line numbers of Claude's window, through `:Aineo claude-numbers` and `<Plug>(aineo-claude-numbers)` beside it (C1), with its line in `:checkhealth aineo` (C7) and its help.

The user's request, 2026-09-25: “A toogle for line number for the claude buffer "\tcn" as the command” (D16). D27, the user's decision of 2026-09-27, asked after the amended brief review measured that aineo starts each terminal hidden: “Stay as I left it (Recommended)” — aineo remembers the toggle for as long as the editor runs and applies it to every new Claude terminal in that window — over “Reset with each terminal”.

## What was done

- **`lua/aineo/layout/init.lua`** (C2): one new entry point, `toggle_claude_numbers()`. It hides `'number'` and `'relativenumber'` when Claude's window shows either, remembering what it showed, and otherwise shows those again, or `'number'` alone when the window never had any. It sets them for the buffer the window shows, as `:setlocal` does (`vim.wo[win][0]`, T16's idiom). The values it set are kept in the layout's state for the editor's life, and `keep_claude_numbers()` shows them again at the end of `open()` and in `follow_claude_terminal()`, only while Claude's window shows Claude's terminal. Without a Claude window — none made, closed, or left on an empty buffer once its terminal was wiped — it warns once at `WARN` and changes nothing. `focus()`'s own test for a gone window is now the shared `shows_own_buffer()`, which the toggle uses too.
- **`plugin/aineo.lua`** (C1): `claude-numbers` in `SUBCOMMANDS`, `ACTIONS` (requiring the layout inside the callback) and `PREFIX_KEYS` (`tcn`); `:Aineo`'s description; `map_prefix()`'s and `PREFIX_KEYS`' docstrings. `start_up` and `run()` untouched.
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

Every test the packet adds, once each. "Crash" means the red was an error, not an assertion.

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

Each a literal edit of the committed file (`64116f2`), run alone from a pristine copy against a narrowed copy of its group under `.tests/t12-*.lua` (`make test_file`), restored and compared byte for byte (`.claude/local/orchestrator/t12-mutants.py`). All ran on 0.12.5.

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

## Decisions & reasoning

- **Where the window logic lives:** the layout (C2), as the brief says; `plugin/aineo.lua` only calls `toggle_claude_numbers()`, and nothing reaches into the layout's tables.
- **The toggle warns itself**, as the layout already warns of a file column with no room, and as Send warns: `aineo: no line numbers toggled — there is no Claude window; open aineo’s layout to make one`, after Send's `aineo: nothing sent — there is no Input; open aineo’s layout to make one`.
- **The toggle decides from what Claude's window shows now,** not from what it remembers: that is what the user sees when they press the key (CN1).
- **`:setlocal` scope, and a re-apply (D27):** the only form that keeps CN3, measured by the brief review (finding 1a) and pinned here (M11).
- **The re-apply only while Claude's window shows Claude's terminal**, so another buffer there keeps the user's numbers (L11, M6).
- **`focus()` and the toggle share `shows_own_buffer()`**, so "no Claude window" means one thing in both (the amendment's "as `focus()` counts it").

## Readings for the MVP review

The orchestrator's, as the brief and its amendment give them:
- the subcommand `claude-numbers` and `<Plug>(aineo-claude-numbers)`;
- CN1 clears `'relativenumber'` together with `'number'`;
- CN2 restores the values the window had when they were hidden, and gives `'number'` to a window that never had any;
- CN4's warning is the toggle's own, at `WARN`, not an error through `run()`;
- CN4b: from another tab, `\tcn` toggles Claude's window in the layout's tab;
- `\o`'s rebuilt Claude window keeps the numbers hidden (Neovim's own behaviour, and D27's re-apply);
- a user's own `\t` or `\tc` now waits for `'timeoutlen'`; the help says so beside the `\sa` example.

The author's:
- **`\o` re-applies the remembered toggle on every open**, not only when a new terminal came: a user's own `:setlocal number` in Claude's window after `\tcn` lasts until the next `\o`.
- **A window split from Claude's window, showing the terminal, shows the numbers hidden too**: Neovim copies a window's local options on a split. Another buffer in that split shows the user's own. Measured on 0.12.5 and 0.11.6 by a throwaway probe run through `make test_file` (`split_terminal = false`, `split_other = true`).

## Task lines

The wave holds its marks (rule 6). The line T12 would take:

- [X] T12 — `\tcn` toggles the line numbers of Claude's window (D16), with `:Aineo claude-numbers`, `<Plug>(aineo-claude-numbers)`, its health line and help; the toggle lasts the editor's life across every new Claude terminal (D27) — regular.

## Limits

- **Another buffer shown in Claude's window** (a help buffer, which the layout does not move to the file column): the toggle acts on it, for that buffer, since it acts on whatever the window shows. When the user later brings Claude's terminal back into that window by hand (`:buffer`), Neovim gives it the numbers it last had there, which may not be the remembered toggle until the next `\o`. Measured on both versions by the same probe: the toggle pressed while another buffer showed there hid that buffer's numbers, and the terminal brought back with `nvim_win_set_buf()` showed its own (`help_after_toggle = false`, `terminal_back_by_hand = true`).
- **The memory is the editor's**: a new Neovim starts with the user's own numbers (D27).
- **"No `TermOpen` autocommand reaches Claude's window"** is the brief review's measurement on both versions, not re-measured here; the pins run without any `TermOpen` autocommand of the user's.

## Open threads

- None of the packet's own.

## Commits

*Recorded after the merge.*
