# Neovim resizes a terminal to the tallest window showing it only when those windows change or Terminal mode is entered

**Tags:** #neovim #terminal #windows #measured
**Discovered:** [[Sessions/2026-10-05 — T30 Drop Neovim 0.11]] (T30's probe C4, PR #108's attack review and the guarantee review of its fix round)
**Applies to:** [[Projects/aineo]]

## The insight

In Neovim 0.12.5 a terminal's size is the height of the tallest window that shows its buffer, in any tab page. Neovim sets it only at certain moments:
- a window showing the terminal opens, closes or changes size;
- a window switches to or from its buffer;
- Terminal mode is entered.

Redraws alone do not resize it, and nor does moving the cursor into a taller window. While no window shows it, the terminal keeps its rows.

So the size is not always the tallest window's. A terminal started in a window that already shows it has that window's height until one of those moments. A terminal started hidden has 5 rows until a window shows it ([[Learnings/A hidden terminal buffer starts at five rows]]).

## Example

T30's probe C4 ran `stty size` in a loop in a mini.test child, with the windows' heights printed beside each size (`Implementation/Waves/00007-panes/evidence/t30-probes.txt` › C1–C4):

| setup | then | size |
|---|---|---|
| started in a 7-row window, also shown in a 14-row one | 1 s with no redraw, or redrawn every 50 ms | `7 80` |
| the same | the cursor enters the taller window | `7 80` |
| the same | the shorter window resized to 6 (heights 6 and 15) | `15 80` |
| the same | a third window of 3 rows opened on it (heights 3, 11 and 6) | `11 80` |
| started hidden | shown in windows of 7 and 14 rows | `14 80` |
| started hidden | shown in 3 rows here and 21 in another tab page | `21 80`, and still `21 80` once the window here is resized to 4 |

PR #108's attack review measured the other triggers, with every window's height read before and after so that no open or resize explains a change. Its probes are in the orchestrator's scratch.

| setup | then | size |
|---|---|---|
| started in a 7-row window; windows of 3 (another buffer), 7 and 10 rows | Terminal mode entered | `7 80` → `10 80`, heights unchanged |
| the same | the 3-row window switched to the terminal | `7 80` → `10 80` |
| started hidden; shown here in 5 rows and in another tab page in 21 | `tabclose 2` | `21 80` → `5 80` |

The guarantee review of the fix round re-measured them. Its controls (doing nothing, and `wincmd t`) left `7 80` as it was. When every window left the terminal, it stayed at `21 80`. One trap in measuring: `tabnew` then `tabclose` resized the terminal too, because the tab line takes a row from every window while two tab pages exist, which is a change of size.

**Why.** The attack review read Neovim v0.12.5's sources: `terminal_check_size()` (`src/nvim/terminal.c:771`) takes the tallest window showing the buffer. Its callers include:
- closing a window (`src/nvim/window.c:3081`, `:3319`);
- a window switching buffers (`src/nvim/buffer.c:1756`, `:1855`; `src/nvim/ex_cmds.c:2956–2959`);
- entering Terminal mode (`src/nvim/terminal.c:912`);
- `nvim_open_term()`;
- a change of the number column's width.

Nothing calls it on a redraw.

**In aineo.** `shown_rows()` in `lua/aineo/claude/readiness.lua` reads Claude Code's screen as the tallest window's rows. That holds because the session starts its terminal hidden: `launch()` creates a fresh buffer and starts the job in it through `nvim_buf_call()`. T30's fix round restated the docstring in the attack review's measured words.

## Where it applies again

- Any code that infers a terminal's rows from the heights of its windows. It is right only after one of the triggers. A terminal started inside a window, then shown in a taller one only by moving the cursor, has the first window's rows. aineo has no such path today (the T30 session note's *Open threads*).
- A probe that measures a terminal's size must change the windows, or enter Terminal mode, before it reads, and must print the heights it got. Two of T30's C4 rows were labelled with heights the probe never set, and only the printed heights showed it (PR #108's records review, finding 4).
- **Limits:**
  - measured on Neovim 0.12.5 under macOS only; the triggers were not measured on 0.11.6;
  - `nvim_open_term()` and the number column's width were read from the source, not measured;
  - the width was 80 columns throughout; how the width is chosen when windows differ in width was not measured.
