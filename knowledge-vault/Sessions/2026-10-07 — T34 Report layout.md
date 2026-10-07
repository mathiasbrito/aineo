# 2026-10-07 — T34 Report layout

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t34-report-layout` · **Pull request:** into `dev` (a small fix, orchestrate §3)

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C6, C14, D24, T16, T17, T18, T29, T34; D30 (no whole suite before a push for this small fix), D29
- Wave plan: `Implementation/Waves/00008-small-fixes/plan.md` › T34, *Assumptions to report to the user* (A9, A10, A11, A16), *Verification mutants* (T34 1–8); brief: `brief-t34-report-layout.md` with its *Amendment — 2026-10-06*
- Probes it rests on: `Implementation/Waves/00008-small-fixes/evidence/w8-probes.txt` › P1 (where a wrapped Report line continues), P4 (`'breakindentopt'` from the Report's own `BufWinEnter`)

## Context

The user, 2026-10-06: a long Report line, wrapped under T16's `'wrap'`, `'linebreak'` and `'breakindent'`, started at the first column; it should resume under the `[` of its `[status]`, and every line after the first should read as a list item, `- text`. The user answered T34-1 (a) and T34-2 (a); A9, A10, A11 and A16 are the orchestrator's assumptions under the user's instruction of 2026-10-06, built as the brief's amendment says.

## What was done

- **`lua/aineo/report/render.lua`.** Each details line renders through `details_item()`: the six-space `DETAILS_INDENT`, `ITEM_MARKER` (`- `), then `item_text()`, which drops a leading `-`, `*`, `+` or `•` and its one space (T34-2 (a), A10). A line that is empty, white space alone, or a marker alone renders `""` (A9, A10); a trailing `\n`'s last line stays, as `""`. Links and paths are still found on the final lines, so each mark moves with the text. New export `M.CONTINUATION_PATTERN`, built from the constants: `^\(\d\d:\d\d \|      - \)`.
- **`lua/aineo/report/buffer.lua`.** `create_report_buffer()` gives the buffer that pattern as `'formatlistpat'`. A buffer-local `BufWinEnter`, in the `aineo_report` group (now made once per Report, holding both autocommands), sets `'breakindentopt'` `list:-1` as `:setlocal` does (`vim.wo[0][0]`). The layout home is untouched: P4 measured that the report home can do this alone, and the probe in this session (below) that `BufWinEnter` runs with the target window current, even from `nvim_win_set_buf()` on a window that is not.
- **`doc/aineo.txt`**, inside T34's two sections: *aineo-report*'s example and its paragraph on items, markers and empty lines; a new paragraph on wrapping (under the `[`, under the text, the narrow Report and `min:20` (A11), the user's `'showbreak'` (A16), `list:-1` set each time a window shows the Report, `'breakindent'`/`'wrap'` off); *aineo-layout*'s wrap paragraph points to it.
- **Pins moved by the two bytes of `- `** (none of their meaning changed): `tests/test_report_buffer.lua`, the 18 rendered details lines and `EVERY_STATUS_FAULTS`; `tests/test_report_links.lua`, 54 rows of *a link in the details*, the wikipedia row, line 103's single link, `LINKS_OF_TWO_REPORTS` and the five `gx` columns (6, 12, 11, 12, 11 → 8, 14, 13, 14, 13); `tests/test_report_paths.lua`, four path pins, every `double_click_in_report(2, …)` byte but the past-the-end 30, the selection `{ 'v', 7, 9, 2 }` → `{ 'v', 9, 11, 2 }`, the parametrized bytes `{10, 20}` → `{12, 22}` and `{9, 21}` → `{11, 23}`, and `input_cell_where_the_report_draws_a_path()`'s byte 12 → 14; `tests/test_mcp_delivery.lua` lines 249–250. `tests/test_report_colours.lua` did not change and stays green: the `- ` takes no colour.

### Probe (this session, Neovim 0.12.5)

`.claude/local/orchestrator/t34-probe1.lua`: a buffer-local `BufWinEnter` setting `vim.wo[0][0].breakindentopt`, the buffer shown by `nvim_win_set_buf()` in a window that is not current. Output: `callback cur=1000` / `first=1000 second=1001 cur=1001 first.bio="list:-1" second.bio=""` — the target window is current inside the callback, and only it takes the option.

## Unit list (stated before the first test)

1. A details line renders as an item, `      - text` (the existing pin, moved).
2. An empty details line, and one of white space alone, render as `""`; a trailing `\n` keeps its last line, `""` (A9).
3. The references line renders as an item.
4. A line Claude marked `- x`, `* x`, `+ x`, `• x` shows `      - x`; a marker-only line renders `""`; a leading-space marker and `1. ` are kept (A10).
5. A wrapped header continues under the `[` (column 7), and with `'number'` on.
6. A wrapped item continues under its text (column 9).
7. In a 24-column Report an item continues at column 5 (A11).
8. The option holds in a split of the Report's window; not for another buffer later shown in that window, nor in a split's other buffer.
9. It holds for a Report made anew after a wipe, and after `:edit`.
10. Moved pins: links, paths, `gx`, double-click, MCP delivery.

Added during the work: the user's `'showbreak'` case (A16, so the help's sentence is measured), and, after mutant 13 survived, the case of the Report shown again after the user emptied the option.

## Seen red, arrived green

All in `tests/test_report_buffer.lua` (67 → 97 cases), Neovim 0.12.5.

**Seen red (15 cases, 5 tests):**
- *renders each line of its details below it as an item, starting under its status* (renamed from *… indented under its status*): `left = "      Changed three files", right = "      - Changed three files"`.
- *renders a details line that is empty, or white space alone, as an empty line* — 3 rows, each `left = "      - …"` (`"      - "`, `"      -   \t "`, `"      - "`), `right = ""`.
- *renders a details line Claude marked as an item with aineo's marker in place of its own* — 10 rows, e.g. `left = "      - - x", right = "      - x"`, `left = "      - •", right = ""`.
- *a wrapped report › continues its first line under the [ of its status*: `Left: 1, Right: 7` — the user's complaint, measured.
- *a wrapped report › continues a details line under its text, not under its -*: `Left: 7, Right: 9`.

**Arrived green (16 cases, 11 tests)** — each with the mutant that kills it, run on the final tree:
- *renders any other details line as an item, keeping its text as written* — 6 rows (`(D18, C12, #31)`, `  - x`, `1. x`, `-x`, `**x**`, `•x`): green by nature of unit 1's code, which keeps the text as written. Killed by M3b (all six), M11 (`  - x`), M12 (`-x`, `**x**`, `•x`).
- *… with 'number' on*: Neovim shifts every column by the number column. Killed by M1, M14.
- *… the width of the user's 'showbreak' past the [*: Neovim's own drawing (A16). Killed by M1, M10, M14.
- *narrower than 28 columns continues a details line further left, keeping 20 columns of text*: Neovim's `min:20`, which the code leaves in place (A11). Killed by M9.
- *in a window split from the Report's*: a split copies the window's options. Killed by M4, M14.
- *leaves Neovim's wrapping to another buffer shown later in the Report's window* and *… in a window split from the Report's*: spent by unit 5's `vim.wo[0][0]`. First written with an other buffer that had no `'breakindent'`, under which M2a and M2b survived; the other buffer now wraps as the layout makes Input wrap, and both kill them.
- *again when shown again after the user empties 'breakindentopt'*: spent by unit 5 (the autocommand runs at each showing); added after M13 survived. Killed by M4, M13, M14.
- *after the user edits the Report again*: the window keeps its option across `:edit`, and `BufWinEnter` runs again. Killed by M4, M14.
- *in a Report made anew after the user wipes it out*: spent by unit 5 (the autocommand is made with each Report). Killed by M6.

## Mutants (on the final tree `f95c538`, each its literal edit from a copy of the file, one at a time, on the three files the plan names, 0.12.5)

Driver: `.claude/local/orchestrator/t34-mutants.py` (in the worktree's scratch); output `t34-mutants-final.txt`. Every kill below is an assertion; no mutant crashed a case.

| # | Literal edit | `test_report_buffer` | `links` | `paths` |
|---|---|---|---|---|
| 1 (plan 1) | render: `[[^\(\d\d:\d\d \|]]` → `[[^\(]]` | 3 | 0 | 0 |
| 2a (plan 2) | buffer: `vim.wo[0][0].breakindentopt` → `vim.o.breakindentopt` | 2 | 0 | 0 |
| 2b (plan 2) | buffer: `vim.wo[0][0].breakindentopt` → `vim.wo[0].breakindentopt` | 2 | 0 | 0 |
| 3a (plan 3) | render: `local lines = { header }` → `local lines = { ITEM_MARKER .. header }` | 62 | 2 | 1 |
| 3b (plan 3) | render: `return DETAILS_INDENT .. ITEM_MARKER .. text` → `return DETAILS_INDENT .. text` | 31 | 61 | 13 |
| 4 (plan 4) | buffer: `'list:-1'` → `'shift:6'` | 5 | 0 | 0 |
| 5 (plan 5) | render: links and paths found on `unmarked`, the lines built as `DETAILS_INDENT .. line` | 0 | 61 | 63 |
| 6 (plan 6) | buffer: the `BufWinEnter` made only `if not M.made_once` | 1 | 0 | 0 |
| 7 (plan 7) | render: `{ '-', '*', '+', '•' }` → `{ '-', '*', '•' }` | 2 | 0 | 0 |
| 8 (plan 8) | render: the blank line's `return ''` → `return DETAILS_INDENT .. ''` | 8 | 0 | 0 |
| 9 | buffer: `'list:-1'` → `'list:-1,min:0'` | 1 | 0 | 0 |
| 10 | buffer: the callback also sets `vim.wo[0][0].showbreak = 'NONE'` | 1 | 0 | 0 |
| 11 | render: `item_text()` starts with `line = (line:gsub('^%s+', ''))` | 1 | 0 | 0 |
| 12 | render: the `if vim.startswith(rest, ' ')` branch → `return (rest:gsub('^ ', ''))` | 3 | 0 | 0 |
| 13 | buffer: the `BufWinEnter` given `once = true` | 1 | 0 | 0 |
| 14 | buffer: the `formatlistpat` line deleted | 8 | 0 | 0 |

Survivors before the corrections (on `2f2cf30`): 2a and 2b (0 in all three files), 13 (0). Each is killed on the final tree.

## Suites (0.12.5)

No whole suite before the push: D30, for this small fix. The eight files of the brief, on the final tree, each `Fails (0)`: `test_report_buffer` 97 (was 67), `test_report_links` 83, `test_report_paths` 90, `test_report_colours` 64, `test_report` 55, `test_mcp_delivery` 25, `test_entry_panes` 86, `test_doc` 44. T29's timing cases (*a long line …*, *of a line of distinct paths …*) are among them, unchanged. `make lint` (StyLua and selene): clean.

**The shared help.** My head merged with `origin/bugfix/t32-changes-colours` (`bfa7bba`) by `git merge-tree --write-tree`: clean, tree `e699dc8`; `tests/test_doc.lua` run inside that tree: 44 cases, `Fails (0)`. `origin/feature/t33-claude-window-name` did not exist when I pushed; the orchestrator runs that check when it lands.

## Task lines

The wave holds its marks. For the knowledge pass:

- **T34** — done — PR into `dev`, wave 8 (each details line an item, `      - text`, Claude's own `- `/`* `/`+ `/`• ` replaced, a blank or marker-only line `""` (T34-1 (a), T34-2 (a), A9, A10); the Report's `'formatlistpat'` and its own `BufWinEnter` setting `'breakindentopt'` `list:-1` as `:setlocal` does, so a wrapped header continues under the `[` and an item under its text, Neovim's `min:20` and the user's `'showbreak'` kept (A11, A16); link, path, `gx` and double-click pins moved by 2; `tests/test_report_buffer.lua` 67 → 97 cases)

## Open threads

- **T33's merge check** did not run: its branch was not pushed when this packet pushed.
- **`'breakindentopt'` replaces the user's own** in a window showing the Report (an `sbr` or `shift:` the user set globally is not kept there). The brief names `list:-1` and no merge with the user's value; the help says the Report gets `list:-1`.
- **The `aineo_report` group** now holds the Report's `BufWinEnter` beside its `BufReadCmd`; a Report kept unnamed for the user's text (`free_name_held_by()`) loses both when the next Report clears the group, as it lost the `BufReadCmd` before.

## Correction — 2026-10-07, after the review of PR #128

A fresh implementer agent (`neovim-lua-developer`) took the review's three findings, as the orchestrator bounded them. The sections above record the packet as it was at `2a18c45`; this one records what changed, and its numbers replace theirs where they differ.

### The revised A11 — the orchestrator's assumption under the user's instruction of 2026-10-06

The user asked that a wrapped line continue under the `[`, and an item under its text. With the file column open (D6), an 80-column screen gives the Report 26 columns, and there Neovim's `min:20` put a wrapped item back at column 7, under its `-` (the review, finding 2). The orchestrator revised A11: the Report's windows take `'breakindentopt'` `list:-1,min:10`. That is the orchestrator's assumption under the user's instruction of 2026-10-06, not the user's answer, and goes to the user with the other assumptions. Rejected: `min:0`, which keeps the indents at any width but leaves three or four cells of text at 12 columns (the review's table).

Measured in this session on Neovim 0.12.5 (`.claude/local/orchestrator/t34cor/t34cor-probe-widths.lua`, `screenpos()` in a window of each width):

| Report width | header continues at | item continues at |
|---|---|---|
| 18 to 30 | 7 | 9 |
| 17 | 7 | 8 |
| 16 | 7 | 7 |
| 15 | 6 | 6 |
| 14 | 5 | 5 |
| 12 | 3 | 3 |

So the hanging indents hold down to 18 columns. The orchestrator's instruction named the limit "below 20 columns"; that is a bound, and the help states the exact one: "A Report narrower than 18 columns continues a wrapped line further left, to keep 10 columns of text". *aineo-report* also names the option's new value.

### What changed

- `lua/aineo/report/buffer.lua`: `CONTINUE_UNDER_LIST_MATCH` is `'list:-1,min:10'`; its docstring takes the review's wording (finding 3) and says the new limit.
- `doc/aineo.txt`: *aineo-layout*'s clause in the review's wording (a wrapped line continues under the `[` of its `[status]`, or under an item's text), no longer claiming "under its text" whatever the user's settings; *aineo-report*'s narrow-width sentence and the option's value.
- `tests/test_report_buffer.lua`, 97 → 101 cases:
  - the review's two cases (finding 1), which show the Report as the layout does, in a window opened with `nvim_open_win(…, false)` and never entered: *continues a details line under its text in a window opened on it without entering it* and *… in a second window opened on it while another shows it*;
  - *continues a details line under its text in a Report 26 columns wide, a third of an 80-column screen*, and its header twin;
  - the 24-column pin of the old A11 (*narrower than 28 columns … keeping 20 columns of text*, column 5) is superseded and becomes *narrower than 18 columns continues a details line further left, keeping 10 columns of text*, 16 columns, column 7.

### Seen red, arrived green (this correction)

- *… in a window opened on it without entering it*: seen red under the review's r4 (`nvim_create_autocmd('BufWinEnter'` → `nvim_create_autocmd('BufEnter'`), `Left: 7`, `Right: 9`, then green on the restored code. Its red can only be shown under a mutant: the code already did the right thing.
- *… in a second window opened on it while another shows it*: seen red under r7 (`vim.wo[0][0].breakindentopt = …` → `local window = vim.fn.bufwinid(buffer)` and `vim.wo[window][0].breakindentopt = …`), `Left: 7`, `Right: 9`.
- *… details line … in a Report 26 columns wide*: seen red under `min:20`, `Left: 7`, `Right: 9`; green with `min:10`.
- *… its first line … in a Report 26 columns wide*: arrived green. `min:20` already kept the header at 7 there, since its text is exactly 20 columns wide. Killed by `'list:-1,min:10'` → `'list:-1,min:21'`, `Left: 6`, `Right: 7`.
- *narrower than 18 columns …*: rewritten from the superseded pin after the green step, so not seen red on its own. Killed by the shipped value `'list:-1'` (`Left: 1`), by `min:0` (9), `min:9` (8) and `min:11` (6), each against `Right: 7`.

### Mutants (on `b444839`, each a literal edit of `lua/aineo/report/buffer.lua` from a copy, one at a time, on `tests/test_report_buffer.lua` narrowed to *a wrapped report*, 15 cases)

| # | literal edit | cases failed | every kill by assertion |
|---|---|---|---|
| r4 | `nvim_create_autocmd('BufWinEnter'` → `nvim_create_autocmd('BufEnter'` | 2 | both finding-1 cases, 7/9 |
| r7 | `      vim.wo[0][0].breakindentopt = CONTINUE_UNDER_LIST_MATCH` → `      local window = vim.fn.bufwinid(buffer)` / `      vim.wo[window][0].breakindentopt = CONTINUE_UNDER_LIST_MATCH` | 1 | the second-window case, 7/9 |
| min20 | `'list:-1,min:10'` → `'list:-1'` | 2 | the 26-column item 7/9; the 16-column case 1/7 |
| min21 | `'list:-1,min:10'` → `'list:-1,min:21'` | 4 | the 26-column header 6/7, among them |
| min0 | `'list:-1,min:10'` → `'list:-1,min:0'` | 1 | the 16-column case, 9/7 |
| min9 | `'list:-1,min:10'` → `'list:-1,min:9'` | 1 | the 16-column case, 8/7 |
| min11 | `'list:-1,min:10'` → `'list:-1,min:11'` | 1 | the 16-column case, 6/7 |
| p4 | `local CONTINUE_UNDER_LIST_MATCH = 'list:-1,min:10'` → `local CONTINUE_UNDER_LIST_MATCH = 'shift:6'` (the plan's mutant 4 on the new value) | 9 | e.g. *… not under its -*, 11/9 |
| p2a | `vim.wo[0][0].breakindentopt` → `vim.o.breakindentopt` | 2 | the two *leaves Neovim's wrapping …* cases, 4/1 |
| p2b | `vim.wo[0][0].breakindentopt` → `vim.wo[0].breakindentopt` | 2 | the same, 4/1 |
| r1 | `  vim.bo[buffer].formatlistpat = render.CONTINUATION_PATTERN` → `  vim.o.formatlistpat = render.CONTINUATION_PATTERN` | 11 | e.g. *continues its first line under the [*, 4/7 |

No survivor, so none went on to the other files. `render.lua` did not change, and its mutants are as the table above records.

### Suites (0.12.5)

No whole suite: D30, for this small fix. The brief's eight files, each `Fails (0)`, are in the correction's report and the PR body. `make lint`: clean. The help merged with `origin/bugfix/t32-changes-colours` (`bfa7bba`): clean, and `tests/test_doc.lua` on the merged tree has 44 cases, `Fails (0)`. `origin/feature/t33-claude-window-name` still does not exist.

### Task line, corrected

This replaces the *Task lines* paragraph above for the knowledge pass:

- **T34** — done — PR into `dev`, wave 8 (each details line an item, `      - text`, Claude's own `- `/`* `/`+ `/`• ` replaced, a blank or marker-only line `""` (T34-1 (a), T34-2 (a), A9, A10); the Report's `'formatlistpat'` and its own `BufWinEnter` setting `'breakindentopt'` `list:-1,min:10` as `:setlocal` does, so a wrapped header continues under the `[` and an item under its text down to 18 columns, the user's `'showbreak'` kept (A11 as revised by the orchestrator under the user's instruction of 2026-10-06, A16); link, path, `gx` and double-click pins moved by 2; `tests/test_report_buffer.lua` 67 → 101 cases)

## Commits

Recorded after the merge, by wave 8's knowledge pass. PR #128 merged by rebase on 2026-10-06 (23:14 UTC; 2026-10-07 01:14 CEST), the first of wave 8; `dev` `cabe3a3`, whose tree is the tree of the orchestrator's verified head `a21f466` (`git diff --stat a21f466 cabe3a3` prints nothing). Released in `v0.2.15` with T32 and T33 (PR #130, squash-merged into `main` as `f9cec19`, whose tree is `dev` `f98bd9d`'s). The task line for the plan is the *Correction*'s, which replaces *Task lines*.

The first three are the packet's; the last three are the bounded correction's, after the guarantee and records review.

| Branch | `dev` | Subject |
|---|---|---|
| `2f2cf30` | `be90050` | Show a report's details as items that wrap under their text |
| `f95c538` | `6af2179` | Pin the Report's wrapping where mutants found it unpinned |
| `2a18c45` | `a272b08` | Record T34's session: the Report's layout as items |
| `19896a1` | `2158f16` | Pin the Report's wrap in windows the layout opens unentered |
| `b444839` | `bd2caa0` | Keep the Report's hanging indents down to 18 columns |
| `a21f466` | `cabe3a3` | Record T34's correction: the revised A11 and the unentered window |
