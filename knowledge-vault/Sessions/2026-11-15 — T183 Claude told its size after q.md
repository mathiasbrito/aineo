# 2026-11-15 — T183 Claude told its size after q

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t183-claude-fresh-size-after-q` (from `dev` at bcd448c2) · **Pull request:** into `dev` (number recorded after the merge)

T183 (A743, D159): after `<C-l>` from the explorer column and then `q` in the explorer, Claude Code draws in one or two columns while its window has the right width, and Ctrl-L in Claude's terminal fixes it. A small fix of the user's prompt-driven waves (D30): the test files it touches and `make lint`, no whole suite.

## Links

- [[Projects/aineo]]
- [[Sessions/2026-11-11 — T175 panel gutter and Claude width]] — the fresh size (`aineo.layout.fresh_size`) this extends
- [[Sessions/2026-11-14 — T180 file focus keeps Claude's width]] — the focus that leaves Claude's window its width
- [[Sessions/2026-11-14 — T182 q closes the file column]] — the `q` this follows

## Measured

A terminal that appends `stty size` at its start and at every SIGWINCH ran as Claude's `claude.cmd` through `:Aineo open` at 240 columns, explorer column on the right, a file in the explorer's repository. Neovim 0.12.5, in a headless child and again in a child with a real terminal UI attached (a nested Neovim in a terminal buffer, driven over RPC); both gave the same sizes.

| Step | Sizes the pty logged (lines x columns) | Claude's window |
|---|---|---|
| `<C-l>` on a file (focus on) | none | 89 before and after |
| `q` in the explorer, focus on | **none** | 89 |
| `:q` in the file window, focus on | **none** | 89 |
| `l` on a file (no focus), then `q` | `59, 58, 59` after `l`; `89, 88, 89` after `q` | 59, then 89 |
| `l`, `<C-l>`, `q` | `89, 88, 89` after `q` | 59, then 89 |
| a second tab open, then `<C-l>`, `q` | none in either tab | 89 |
| the same with `:redraw` in the autocommand of every window event | the same | the same |

No transient size reached the pty on any of these, and no redraw drew one (a decoration provider logged the windows' widths at every redraw). The terminal's own screen was 89 columns wide after `q` too (a 300-character line wrapped at 89). Neovim hands the pty only the size the windows have when the event loop goes round; a width that goes to a sliver and back inside one command never reaches it, and a sliver drawn inside a command (a `:redraw!` and a wait between two `nvim_win_set_width()` calls) reached it as `2` then `89`, with no `WinResized` for Claude's window and no fresh size after it.

## Cause

**Not confirmed as a size the pty was told.** What the measurements pin is that with the file focus on, Claude's window keeps its width (T180) and so the pty is told nothing at all through `<C-l>` and `q`: Claude Code is given no resize, so nothing makes it lay its screen out again after the panes column returns, which is what Ctrl-L does by hand. Before T180 the width changed through the focus and the fresh size of T175 covered it. The guard runs only for a window listed in `WinResized`; a window that ends at the width it began with is never listed.

## Fix

`aineo.layout` gives Claude's terminal a fresh size (`give_claude_terminal_a_fresh_size_soon()`, the timer that `WinResized` already used, now a function of its own) when the file focus ends: in `M.open()` when the focus was applied, and in `restore_panes_column()` when the file column closes under an applied focus. Not special-cased to `q`: `q`, `:q` in the file window and `<C-l>` all end the focus through those two places. A focus that is only armed, starting a focus, and an `open()` with no focus on give none.

## Tests

- `tests/test_entry_claude_pty_size_file_focus.lua` (new): `q` in the explorer, `<C-l>` in the explorer and `:q` in the file window, each ending the focus, give a fresh resize at the window's size (the last size is the window's, the one before another, at most three in all); `q` closing the file column with no focus on (already given); none when the focus starts; none when the layout opens again with no focus on.
- `tests/test_layout_file_focus.lua`: the case "sees no size as the focus is armed, a file opens and the file column closes" now says the pty sees the size of its window again as the file column closes; arming and opening a file still show it none.

## Mutants

Each run on `tests/test_entry_claude_pty_size_file_focus.lua` and `tests/test_layout_file_focus.lua`, the source restored after:

| Mutant | Killed by |
|---|---|
| `restore_panes_column()` gives no fresh size | the entry file (`:q in the file window`) and `test_layout_file_focus.lua` |
| `M.open()` gives no fresh size | the entry file (`q in the explorer`) |
| `M.open()` gives one whether or not the focus was applied | the entry file (`the layout opens again with no file focus on`) |

## After the fix

| Step | Sizes the pty logged |
|---|---|
| `q` in the explorer, focus on | `88, 89` (was none) |
| `:q` in the file window, focus on | `88, 89` (was none) |
| `q` with no focus | `89, 88, 89` (unchanged) |

## Open threads

The cause stays unconfirmed as a size the pty was told: no measured sequence on this repository's fake terminals reproduces a transient. The fix makes Claude Code lay its screen out again once the panes column is back, which is what Ctrl-L does by hand. If the user still sees one or two columns, a log of the pty sizes on the user's own machine at the moment it happens (a `claude.cmd` that appends `stty size` at every SIGWINCH) is the next measurement.
