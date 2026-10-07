# A window opened with nvim_open_win and enter false fires BufWinEnter but not BufEnter

**Tags:** #neovim #autocommands #windows #measured
**Discovered:** [[Sessions/2026-10-07 — T34 Report layout]] (the guarantee review of PR #128, finding 1) · [[Sessions/2026-10-07 — Wave 8 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

`nvim_open_win(buffer, false, …)` shows a buffer in a new window without entering it. That fires `BufWinEnter` for the buffer, with the new window current while the autocommand runs, and **no `BufEnter`** until the window is entered. `nvim_win_set_buf()` on a window that is not current fires both, again with that window current inside the callbacks.

So a buffer that must set something for every window showing it hooks `BufWinEnter`, and can set a window option with `vim.wo[0][0]` there: window 0 is the window being shown in, even though the caller's window is current before and after.

## Example

- **T34** gives each window showing the Report `'breakindentopt'` from a buffer-local `BufWinEnter` (`lua/aineo/report/buffer.lua`; `be90050` on `dev`). The layout opens the Report's window with `nvim_open_win(own_buffer('report'), false, { split = 'above', … })` and never enters it (`lua/aineo/layout/init.lua`). The packet's tests showed the Report in the current window only, so `'BufWinEnter'` → `'BufEnter'` (r4) survived every file; the guarantee review of PR #128 measured that it brought back the user's complaint in the real layout, the header continuing at column 1 (finding 1). Its two cases, adopted by the correction, open the Report with `nvim_open_win(report, false, …)` and kill r4 by assertion (`2158f16` on `dev`).
- **The packet's own probe** (`t34-probe1.lua`, in T34's session note): a buffer-local `BufWinEnter` setting `vim.wo[0][0].breakindentopt`, the buffer shown by `nvim_win_set_buf()` in a window that is not current, saw that window as current, and only it took the option.
- **This pass**, in bare Neovim 0.12.5 (`probe-unentered-window.lua` in [[Attachments/learnings-probes-2026-10-07.txt]]): `nvim_open_win(…, false)` fired `BufWinEnter` alone, with window 1001 current inside it and 1000 after; `nvim_win_set_buf(1002, …)` from window 1000 fired `BufEnter` and `BufWinEnter`, both with 1002 current; entering 1001 later fired `WinEnter` and `BufEnter`.

**Why.** Neovim's help, `autocmd.txt`: `BufWinEnter` is "After a buffer is displayed in a window", and `BufEnter` "After entering (visiting, switching-to) a new or existing buffer". That `nvim_win_set_buf()` on another window fires `BufEnter` while `nvim_open_win(…, false)` does not is measured, not read from the source.

## Why it matters

- A test that shows a buffer in the current window exercises both events at once, and cannot tell a `BufEnter` hook from a `BufWinEnter` one. A case must show the buffer the way the real caller does.
- `vim.fn.bufwinid(buffer)` inside the callback names only the first window showing the buffer; the review's r7 used it and missed a second window. `vim.wo[0][0]` names the right one.
- **Limits:** measured on 0.12.5, for a split window; a floating window was not measured.
