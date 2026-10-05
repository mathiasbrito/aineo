# A hidden terminal buffer starts at five rows

**Tags:** #neovim #terminal #trap
**Discovered:** [[Sessions/2026-09-24 — T4 Claude session]] · measured on 0.12.5 in [[Sessions/2026-10-05 — T30 Drop Neovim 0.11]]
**Applies to:** [[Projects/aineo]]

## The insight

In Neovim 0.11.6 and 0.12.5, `jobstart(cmd, { term = true })` called for a buffer no window shows runs the terminal in Neovim's autocommand window, and the process first sees that window's size — 5 rows, as wide as the editor. On 0.11.6 that held whatever `width` and `height` the call passed, since those options do not apply to a terminal; 0.12.5 was measured without them. A full-screen program that draws its first screen then draws it for 5 rows. Show the buffer in its window before the program draws. On 0.11.6, shown in the same tick or from a `vim.schedule()` callback, the process saw the window's size. On 0.12.5 it has the window's size about 50 ms after it starts, but a size it reads as it starts can still be 5 rows.

## Example

T4's probe (`Implementation/Waves/00002-layout-session-report/evidence/t4-probe-size.lua`, output `t4-probe-size-out.txt`, Neovim 0.11.6, screen 80×24) ran `stty size` in a terminal job: hidden with no size, `5 80`; hidden with `width = 120, height = 40`, `5 80`; shown in a window just after the start, `22 80`. The replayed Claude Code screen lost its prompt at 5 rows, so a test waiting for readiness failed until the test helper showed the buffer at once. The correction's own probe found why readiness still read 5 rows while hidden: `win_findbuf()` returns the autocommand window (`type=autocmd`, height 5) during the first change. `start_session()`'s docstring states the obligation for its caller (`lua/aineo/claude/init.lua`, *Show a new buffer in a window before Claude Code draws its first screen*); T7, which shows it on the left, inherits it.

On Neovim 0.12.5 (`Implementation/Waves/00007-panes/evidence/t30-probes.txt` › C1–C4 and *C2, C4 and the same tick*):
- hidden, `5 80` in an 80-column editor and `5 200` in a 200-column one; shown in the current window of 22 rows, `22 80` and `22 200`;
- `win_findbuf()` at the first `on_lines` calls of a hidden terminal gives the autocommand window, 5 rows high, and then no window (`autocmd:5 | none`);
- `stty size` at about 0, 50 and 350 ms after the start, the buffer shown in the same tick (three runs) or from `vim.schedule()` (two runs): `5 80`, then `22 80`, then `22 80`; shown 500 ms later: `5 80` throughout. The records review of PR #108 got 22 rows from the start for `vim.schedule()` under `nvim --clean --headless -l`, so the first read depends on the process.

## Why it matters

Any plugin that starts a TUI in a terminal buffer it shows later — a floating terminal toggled open, a split made after the job starts — hands the program a 5-row screen for its first draw, and a program that does not redraw on `SIGWINCH` keeps it. The width follows `'columns'` of the autocommand window, so a test on an 80-column screen cannot see a width bug either. Measured on Neovim 0.11.6 by T4's probe; the attack review of PR #11 measured the `vim.schedule()` case. Measured on 0.12.5 by T30's probes and PR #108's reviews. How the size changes once windows show the terminal: [[Learnings/Neovim resizes a terminal to the tallest window showing it only when those windows change or Terminal mode is entered]].
