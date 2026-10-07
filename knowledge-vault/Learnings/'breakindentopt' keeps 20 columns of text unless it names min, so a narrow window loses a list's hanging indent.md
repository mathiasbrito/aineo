# 'breakindentopt' keeps 20 columns of text unless it names min, so a narrow window loses a list's hanging indent

**Tags:** #neovim #wrap #breakindent #measured
**Discovered:** [[Sessions/2026-10-07 — T34 Report layout]] (the brief review of wave 8, finding 2.1; the guarantee review of PR #128, finding 2) · [[Sessions/2026-10-07 — Wave 8 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

`'breakindentopt'` `list:-1` makes a wrapped line that matches `'formatlistpat'` continue after the match — under a list item's text. But `'breakindentopt'` also has `min:`, the "minimum text width that will be kept after applying 'breakindent'", **20 by default**, and it applies whenever the value does not name `min:`. In a window too narrow to keep 20 columns after the indent, Neovim gives up indent first: the continuation moves left, column by column, until 20 columns of text remain, and at 20 columns or fewer it starts at column 1.

So a value meant to give a hanging indent should name `min:` for the narrowest window it must serve. Measured on 0.12.5, for a header continuing after `09:05 ` (column 7) and an item after `      - ` (column 9):

| value | 12 | 16 | 17 | 18 | 20 | 24 | 26 | 27 | 28 | 40 |
|---|---|---|---|---|---|---|---|---|---|---|
| `list:-1` (min 20) | 1/1 | 1/1 | 1/1 | 1/1 | 1/1 | 5/5 | 7/7 | 7/8 | 7/9 | 7/9 |
| `list:-1,min:10` | 3/3 | 7/7 | 7/8 | 7/9 | 7/9 | 7/9 | 7/9 | 7/9 | 7/9 | 7/9 |
| `list:-1,min:0` | 7/9 | 7/9 | 7/9 | 7/9 | 7/9 | 7/9 | 7/9 | 7/9 | 7/9 | 7/9 |

The column is `min(indent + 1, width - min + 1)`, and 1 when that is below 1: at 24 columns under `min:20` both continue at 5.

## Example

- **T34** gave each window showing the Report `'breakindentopt'` `list:-1`. The brief review measured the narrow-window break before dispatch (2.1), and A11 first kept `min:20`. The guarantee review of PR #128 measured it in the real layout: with the file column open, an 80-column screen gives the Report 26 columns, where a wrapped item continued at column 7, under its `-`, against the user's ask; a 64-column screen lost the header's indent too (finding 2). The orchestrator revised A11 to `list:-1,min:10`, and the correction measured that the indents hold down to 18 columns (`lua/aineo/report/buffer.lua`, `CONTINUE_UNDER_LIST_MATCH`; `bd2caa0` on `dev`). `tests/test_report_buffer.lua` pins a 26-column and a 16-column Report.
- **This pass**, in bare Neovim 0.12.5 (`probe-breakindent-min.lua` in [[Attachments/learnings-probes-2026-10-07.txt]]): the table above, read with `screenpos()` in a window of each width with `'wrap'`, `'linebreak'` and `'breakindent'` on. It agrees with the review's and the correction's tables.

**Why.** Neovim's help, `options.txt` › `'breakindentopt'`, on 0.12.5: `min:{n}` "Minimum text width that will be kept after applying 'breakindent', even if the resulting text should normally be narrower … (default: 20)". The formula above is fitted to the measurements, not read from the source.

## Why it matters

- A hanging indent tested only in a wide window looks done. The width that matters is the narrowest one the layout gives the window — here a third of the screen.
- `min:0` keeps the indent at any width, at the cost of a column of three or four cells of text in a very narrow window; T34 rejected it for that.
- `shift:` and `sbr` are other sub-options of the same option; setting the value window-locally replaces a user's own (MR319).
- **Limits:** measured on 0.12.5, with `'linebreak'` on; the guarantee review also measured `'number'`, which shifts every column by its width, and a `'showbreak'`, which moves the continuation by its width.
