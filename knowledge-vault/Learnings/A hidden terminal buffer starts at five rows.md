# A hidden terminal buffer starts at five rows

**Tags:** #neovim #terminal #trap
**Discovered:** [[Sessions/2026-09-24 — T4 Claude session]]
**Applies to:** [[Projects/aineo]]

## The insight

In Neovim 0.11.6, `jobstart(cmd, { term = true })` called for a buffer no window shows runs the terminal in Neovim's autocommand window, and the process first sees that window's size — 5 rows at 80 columns on an 80×24 screen — whatever `width` and `height` the call passes, since those options do not apply to a terminal. A full-screen program that draws its first screen then draws it for 5 rows. Show the buffer in its window before the program draws: shown in the same tick, or from a `vim.schedule()` callback, the process saw the window's size.

## Example

T4's probe (`Implementation/Waves/00002-layout-session-report/evidence/t4-probe-size.lua`, output `t4-probe-size-out.txt`, Neovim 0.11.6, screen 80×24) ran `stty size` in a terminal job: hidden with no size, `5 80`; hidden with `width = 120, height = 40`, `5 80`; shown in a window just after the start, `22 80`. The replayed Claude Code screen lost its prompt at 5 rows, so a test waiting for readiness failed until the test helper showed the buffer at once. The correction's own probe found why readiness still read 5 rows while hidden: `win_findbuf()` returns the autocommand window (`type=autocmd`, height 5) during the first change. `start_session()`'s docstring states the obligation for its caller (`lua/aineo/claude/init.lua`, *Show a new buffer in a window before Claude Code draws its first screen*); T7, which shows it on the left, inherits it.

## Why it matters

Any plugin that starts a TUI in a terminal buffer it shows later — a floating terminal toggled open, a split made after the job starts — hands the program a 5-row screen for its first draw, and a program that does not redraw on `SIGWINCH` keeps it. The width follows `'columns'` of the autocommand window, so a test on an 80-column screen cannot see a width bug either. Measured on Neovim 0.11.6 by T4's probe; the attack review of PR #11 measured the `vim.schedule()` case.
