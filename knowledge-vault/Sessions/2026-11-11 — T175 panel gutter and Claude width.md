# 2026-11-11 — T175 panel gutter and Claude width

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t175-claude-width-after-layout-move` (from `dev` at 2953260c) · **Pull request:** into `dev` (number recorded after the merge)

T175 (A734, A728): Claude's terminal drawing in a few columns after a layout move; then, folded in on the user's words during the packet, A735 and its replacement D152 / A736: every panel shows no line numbers, sign, fold or status column unless `\tn` brings them back. A small fix of the user's prompt-driven waves (D30): the test files it touches while working and `make lint`, no whole suite (the orchestrator runs it).

## Links

- [[Projects/aineo]]
- [[Sessions/2026-11-11 — T174 file beside explorer]] — the explorer column, the mirror and `explorer.numbers` this builds on

## The width report

User: "whe I do mirror, it works, but the claude panel is in the correct size with claude occupying only 4 columns"; before it (A728), after a swap and its undo, "the size of the pane is correctly set but claude occupy only part of it".

**Measured, not reproduced.** A pty that appends `stty size` at every SIGWINCH (`sh -c`, `trap … WINCH`, a `sleep & wait` loop so a signal is served at once) ran as Claude's `claude.cmd` through `:Aineo open` on a 240-column screen with the explorer column, and as a terminal in the layout helper's child:

| Move | Sizes the pty logged after the layout settled |
|---|---|
| `:Aineo layout mirror`, mirror twice, swap, swap twice, `layout left`, `layout right`, with and without the explorer column | none (the window stays 99 columns, 120 without the explorer) |
| `:Aineo explorer column` off and on | 120, then 99 — each a settled size |
| the same, with a `:redraw` in the autocommand of every window event (`WinNew`, `WinEnter`, `WinLeave`, `BufWinEnter`, `BufWinLeave`, `WinResized`, `WinClosed`) | the same |
| the same, with a `vim.wait(30)` in those autocommands | the same |
| a global `statuscolumn`, `signcolumn=yes`, `foldcolumn=2` | the pty is the window less 4: `textoff` 4 in Claude's window, 95 of 99 |

The start of every run logged `5 240`, then `39 99`: the pty is created before its window and resized once.

**A737 — the user's second report** (top priority): "we have a big bug with claude changing its number of columns visible and changes are made in the layout, for example, I closed the report panel, only the explorer, file and claude remained, but claude reduced the number of columns visible of its panel just to a few"; Claude's window about 85 columns, Claude drawing in 12-15, five tab pages open. Measured the same way (a `claude.cmd` that logs `$$ stty size` at each SIGWINCH, 240 columns, explorer column on the left, a file column), with the windows of every tab listed (any window of any tab showing Claude's terminal, floats included):

| Change | Sizes the pty logged | Windows afterwards |
|---|---|---|
| close the Report; close Input; close both (Claude 65 → 66); `:q` on the Report; close the Report then `\o` | none; none; `66`; none; none | one window shows the terminal, no float, no other tab |
| `\z` (column zoom) and back; close the Report while `\z` is on | none | the same |
| `:Aineo explorer column` off, on | `79`, `65` | the same |
| editor 240 → 160 → 240 columns | `39`, `65` (Claude's window was 39 at 160) | the same |
| `\Z` (full zoom) on the Report and off | **`1`, then `65`** | the same |
| `\Z` on the Report, then close the Report (and Input) | `1`, `65` (and `66`) | Claude 65 / 66 |
| `\Z` on the file column, then close the Report | `1` and no more: the zoom stays, Claude's window is one column | Claude 1 column, by design while zoomed |
| three tab pages, the Report and Input closed in tab 2 and the Report in tab 3, or `:q` on the Report in tab 1 | each tab's Claude logs only its own sizes (`39 99`, then `39 199` in the tab whose panes closed) | no terminal in a window of another tab |

**Cause (found by the attack review of PR #418, measured on the head `6076c309`; my own measurements above only resized the editor with the layout's tab shown).** When the editor is resized, every tab's layout runs `keep_proportions()` from its `VimResized` handler, hidden tabs included. `set_column_widths()` reads the new `vim.o.columns`, while a hidden tab's windows keep the old editor's sizes until the tab is entered, so the proportions squeeze Claude's window, and Neovim sizes a terminal from its windows in every tab: the hidden tab's Claude Code is told a squeezed width while the user is in another tab. With the explorer column on the right (the default), growing the editor from 80 to 150 columns told the hidden tab's Claude `27 4` (A734's four columns); the layout harness gave `22 14` (A737's 12-15, with five tabs open); 160 to 240 gave `27 51`. Shrinking, or the explorer on the left, was right. On entering the tab the pty gets its window's size, and the fresh resize follows; but Claude Code's fullscreen renderer (the user runs `/tui` fullscreen) may act on the squeezed resize and not on the later one, which is what the user saw. **Not proven** with the real Claude Code, which was never run; it is the only path measured that puts a size narrower than its window into a pty with the fake. The other changes measured (closing panes, `:q`, `\o`, `\z`, `\E`, an editor resize with the tab shown, a swap, a mirror) leave the pty at its window's size, and the full zoom's own one column stays.

**Fix.** Three places, in `aineo.layout` and `aineo.layout.fresh_size`:

1. The cause: the `VimResized` handler puts the proportions back only for the layout whose tab is shown (`keep_proportions_of_the_tab_shown()`); `TabEnter` puts them back for a tab entered later, as `watch_windows()` always said. A hidden tab's Claude is told nothing while hidden.
2. The brief's fallback, for any other cause: once Claude's window changed size (a zoom ending, a column closing, the editor resized), 100 ms after the last change the terminal's pty is told `columns - 1` and, 300 ms later, the window's size again (`jobresize()` twice, measured to work on a terminal's job and to be kept by Neovim across redraws), so Claude Code sees a fresh resize. A busy process serves a signal between its tasks and sees only the last of two sizes told within that time: with a 30 ms gap a process busy for 200 ms saw the final width alone, with 300 ms both. Skipped while a window is zoomed fully and when Claude's window keeps its size, so the move pins hold for a swap and a mirror.
3. The size the nudge uses is the largest over every window showing Claude's terminal in any tab (`win_findbuf()`), as Neovim sizes a terminal: measured, `:tab sbuffer` of Claude's terminal opened an 80 column window, and the pty went to 80; the first version's nudge then left it at the layout window's 26 and nothing corrected it.

It does not remove the full zoom's own one-column state.

Pins and tests: `tests/test_layout_move_pty_sizes.lua` (swap, mirror, explorer side: the pty logs at most the final size; explorer off and wider: the final size and its fresh resize), `tests/test_layout_fresh_pty_size.lua` (explorer closing, the editor resized, a full zoom ending: the last two sizes are the window's after a different one, at most four in all; no more once settled; none while fully zoomed; none when the window keeps its size, a Report closing included) and `tests/test_entry_claude_pty_size.lua` (the user's case through `:Aineo open`: the Report and Input closed with the file and the explorer left) and `tests/test_layout_pty_sizes_across_tabs.lua` (a tab that is not shown while the editor grows: no width narrower than it had; entering it gives the window's size; Claude's terminal in two windows: the largest size; a busy process: sees the narrower size and then the window's; a run of 30 resizes: at most one nudge pair, 33 sizes in all). The helper `tests/helpers/pty_recorder.lua` waited for the pty's *first* recorded size to equal the window's (`vim.list_slice(…, -1)` takes from the start), so every case waited out its 3 s limit; it now reads the last.

## D152 / A736 — the panels' gutter

User (D152): "any panel other than a file do not show the line numbers columns, they must show only the pane separator thin line… they are taking too much space… however we need a `<key>` that quickly bring the numbers back, as a toggle." It replaces A735 (an explorer-only gutter, written first and thrown away with its tests) and A731 (1)(2).

- **One owner**: `aineo.layout.gutter` (`lua/aineo/layout/gutter.lua`), a file of the layout home: `is_panel_buffer()` (`buftype` not empty, or a name starting `aineo://`), `hide()` and `show()`, window-local (`vim.wo[window][0]`, `setlocal x<`). The layout keeps `state.panel_numbers` and applies it to the panel windows (its three roles, the explorer column's, the run pane's) when a buffer enters them (`BufWinEnter`), when the layout opens, and when the explorer column opens. A file in a panel's window gets the user's own back; a window that is no panel is never touched.
- **API**: `arrangement.panel_numbers` (validated, kept when not handed), `set_panel_numbers(boolean)`, `panel_numbers()`.
- **Entry**: `aineo.entry.panel_numbers` (the session's choice, as `layout_side` is), handed to every tab's arrangement; `:Aineo panel-numbers`, `<Plug>(aineo-panel-numbers)`, `\tn` and `<C-\>tn`, in every aineo tab at once, from the tab the user sees.
- **Settings**: `layout.panel_numbers` (default `false`); `explorer.numbers` stays, as its old name, and is no look of the explorer any more (`look.DEFAULT.numbers` and the explorer home's own hiding are gone; the home's tests of it moved to `tests/test_layout_panel_gutter.lua` and `tests/test_entry_panel_numbers.lua`).
- **`\tcn`** stays: Claude's window keeps the numbers it set whatever the panels show, and with the panels' numbers off it starts without any, so the first press shows 'number' (the layout and entry suites of `\tcn` run with `panel_numbers = true`, the world they were written in; two new cases cover the default).

## Unit list (as sliced)

1. The width: a pty that logs every size, and the move cases (above).
2. A panel shows no gutter by default: Claude, the Report, Input, the explorer column, a pane's buffer.
3. A file keeps the user's gutter, in the file column and in a panel's window; a window that is no panel is untouched.
4. `set_panel_numbers()` both ways, `panel_numbers()`, the arrangement field and its validation.
5. The entry: command, `<Plug>`, key, every tab, a tab made later, `\tcn` left alone.
6. `layout.panel_numbers`, `explorer.numbers` as its old name, docs and key lists.
7. A737: every change of Claude's window size is followed by a fresh resize of its pty (`aineo.layout.fresh_size`), none for a window that keeps its size or while fully zoomed.

## Red, and green by design

Seen red (the layout cases, before the layout code): 16 of the 20 in `test_layout_panel_gutter.lua` (the four panels' gutters, the pane switch, the five API and arrangement cases that call what did not exist, the refusals, the hidden-from-the-start case). `test_layout_fresh_pty_size.lua`: 5 of 8 red before the handler (explorer closing, editor resized, full zoom ending and the two close cases, of which the Report-closing case was dropped: Claude's window keeps its size there, and the Report and Input closing do not resize Claude's window in the 80-column harness), the rest green by design (no resize while fully zoomed, none when the window keeps its size, none again once settled). The entry cases of `test_entry_panel_numbers.lua` and `test_entry_claude_pty_size.lua` were written after the code they test, so they were not seen red; each is killed by a mutant above. Green by nature: the file and no-panel window cases (current behaviour pinned), the move pins.

## Mutants

Each applied alone to the file, run against the test file that exercises it, the file restored after; every kill is by assertion (crashes 0 in each run).

| Edit | Killed by |
|---|---|
| `gutter.hide`: drop `statuscolumn = ''` | 14 layout cases |
| `keep_panel_gutter`: never hide (`if true then return`) | 14 |
| `keep_panel_gutter`: hide files, not panels (`or gutter.is_panel_buffer(`) | 15 |
| `restyle_panel_gutters`: `false and` for `state.panel_numbers and` | 1 (`gives every panel the user's own settings`) |
| `is_panel_buffer`: drop the `aineo://` name clause | 4 |
| `watch_windows`: the gutter handler an empty function | 4 |
| `M.open()`: drop `keep_panel_gutters()` | 4 |
| `take_arrangement`: drop `panel_numbers` | 2 |
| `validate_arrangement`: drop the `panel_numbers` check | 1 |
| `keeps_claude_numbers` returns false | 1 (`test_layout_claude_numbers`) |
| `ACTIONS['panel-numbers']`: `break` after the first tab | 1 |
| `panel_numbers.current`: drop `or config.explorer.numbers` / drop the choice / `shown = true` | 1 / 1 / 3 |
| tab arrangement: drop `panel_numbers` | 4 |
| keys row `tn` renamed `tnx` | 1 |
| `watch_windows`: the `WinResized` handler an empty function | 4 (`test_layout_fresh_pty_size`) |
| `give_claude_terminal_a_fresh_size`: drop the `state.full_zoom` guard | 2 (needed the `'winminwidth'` = 5 case) |
| `fresh_size.give`: `width - 1` → `width` | 4 |
| `fresh_size.give`: `width < 2` → `width < 0` | 2 (needed the one-column case) |
| the handler's `vim.list_contains(…, state.windows.claude)` → true | 2 |
| `move_column()`: `vim.wait(30)` after each `nvim_win_set_config` | 4 of `test_layout_move_pty_sizes` |
| `watch_windows`: drop the debounce (`timer:stop()`/`close()`) | first version survived; killed by the run of 30 resizes, 40 columns apart, 15 ms apart (more than 33 sizes) after the review |
| the handler or `fresh_size.give` opens a `vim.uv.new_timer()` it leaves open | 3 / 1 (`the layout's timers for the fresh size`) |
| `VimResized`: no guard for a tab that is not shown | 1 (`test_layout_pty_sizes_across_tabs`) |
| `claude_terminal_size`: the layout's window only / the smallest window | 1 / 1 |
| `fresh_size.GAP_MS` 300 → 30 | 1 (the busy process sees only the final size) |
| `keep_panel_gutter`: drop `gutter.show` for a file (first version) | survived, **equivalent**: Neovim gives a file shown in the window its first-time global values (the case passes without it, for a never-shown file too), so the branch was removed |

Two survivors of the first run (the full-zoom guard and `width < 0`) were killed by cases added for them; the first `vim.cmd('redraw')` mutant of the width pins survives, as recorded above.


## Open threads

- **The width report (A737, A734, A728): the cause measured is the hidden tab's resize, not proven with the real Claude Code.** The fallback is in; the full zoom still puts Claude Code at one column while it lasts. If it comes back, measure the real Claude Code's own redraw on a resize with the user's config (snacks and its statuscolumn).
- `explorer.numbers` as an old name has no deprecation message; the brief asked for the documented old name only.

## Commits

*Recorded after the merge.* Pre-rebase hashes of the branch, for the PR's reviewers only: `9dbe4c31` (pins), `6076c309` (panel gutter and fresh size), `3f92b722` (office timer and walkthrough cases); the round that adds the hidden tab's resize guard follows them.
