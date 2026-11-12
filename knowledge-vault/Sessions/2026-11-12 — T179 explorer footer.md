# 2026-11-12 — T179 the explorer's information moves to a footer

**Author:** the user, with Claude — implementer agent (Opus 5.5)
**Branch:** `feature/t179-explorer-footer` (from `origin/dev` at 7fe61737)

## Links

[[Projects/aineo]] — D155 and A745 as the brief holds them; D30 (small fix: the test files touched, no whole suite before a push; the orchestrator runs it).

## Why

The user, of the explorer's header line: "the infos in the top of the explorer are barely visible, maybe we could use the las 5 lines for informations, instead on the top..". The design proposed back was agreed with "go ahead": a footer on the explorer window's bottom rows, one item a line, the header line gone.

## What changed

- `lua/aineo/explorer/footer.lua` (new, pure): the footer's lines for a view and a window size — the title, the branch indented, the summary of the changes, the toggles, the filter; a line with nothing to say left out; the title alone below 12 rows; every line cut at its start with `…` to the width, by cells. The title, the branch and the filter show as the view quotes a name (the header showed them raw).
- `lua/aineo/explorer/footer_windows.lua` (new): one non-focusable floating window per window showing the explorer buffer (`relative = 'win'`, its bottom rows, `zindex = 1`, `style = 'minimal'`, no border), in whatever tab page; laid out again on `WinClosed`, `WinResized` and the explorer buffer's `BufWinEnter`/`BufWinLeave` (scheduled, coalesced) and at each render; closed with its window, when the window shows another buffer, and when the explorer buffer is wiped; recreated when something else closed it (`:only`, `:fclose`). Blank virtual lines after the tree's last line, as many as the tallest footer's rows, so the tree scrolls past it. The cursor is kept above the footer: on `CursorMoved`, the tree scrolls when the cursor went down under it, and the cursor moves up when the tree scrolled up and pushed it there (so `<C-y>` and the wheel still scroll); after a reveal (`\f`) every explorer window's cursor is kept above its footer.
- `tree.lua`: no header line; entries start on line 1; the no-match line stands alone. `header.lua` deleted. `decorate.lua`: no header highlight; it takes the flash group alone.
- `home.lua`: the footer groups (`AineoExplorerFooter` for the background, `…FooterTitle` → `Title`, `…FooterBranch` → `Identifier`, `…FooterSummary` → `AineoExplorerChanged`, `…FooterToggles` → `Comment`, `…FooterFilter` → `Special`, all `default = true`), `AineoExplorerHeader` removed; the failure rendering is the failure line alone; the keys' "nothing on the header" docstrings now say "a line with no entry".
- `doc/aineo.txt` (the explorer's example, the footer paragraph, `<C-l>` on a line with no entry, the branch-with-no-folder sentence, the six new groups in place of `AineoExplorerHeader`), `README.md` (the Header row becomes Footer).

## Decided

- Every footer line is cut at its start, not only the title: one rule, and a narrow window keeps the end of each line (the branch's end, `…dotfiles shown`).
- The padding is one set of virtual lines for the buffer, sized to the tallest footer of its windows.
- The cursor-keeping is beyond the brief's letter ("the last entries are reachable"): measured on 0.12.5, `G` with only the padding leaves the last entries under the footer, reachable only by `<C-e>`/`zb`.
- The footer follows `WinClosed` and `WinResized` alone: `WinNew`, `VimResized` and `TabEnter`, in the first version, survived their mutants and were measured redundant (a split resizes the window it splits; a window resized while another tab page showed is laid out by `WinResized` as its tab page is entered).
- `AineoExplorerHeader` is not kept: no code used it, and a link to a group that colours nothing would only mislead.

## Tests

New: `tests/test_explorer_footer.lua` (the composition, 10 cases), `tests/test_explorer_home_footer.lua` (the footer windows through the home and a fake git, in-process: 14 cases), `tests/test_explorer_footer_child.lua` (a child Neovim, where `CursorMoved` fires and the setup's scheduled callbacks have run before a case acts: the cursor, a height-only resize, a window showing another buffer, a window resized while another tab page showed; 5 cases), `tests/helpers/explorer_footer.lua` (reads a window's footer, in-process or in a child by its absolute path), and `tests/helpers/fake_explorer.lua` can fail to list. `tests/test_doc.lua` pins the six help tags. The explorer suites and the entry suites that looked at line 1 or sliced it off are moved to the footer and to entries from line 1; the case "the header does nothing with l" became "a line with no entry does nothing with l", on the no-match line.

## Mutants

Each run alone from a pristine copy, against the file named; every kill below is an assertion failure. On `footer.lua` (against `tests/test_explorer_footer.lua`): the empty-filter guard dropped, the branch line always added, `<` → `<=` at the 12-row threshold, `width < 1` → `width < 0`, `A` no longer new, the filter unquoted — all killed. On `footer_windows.lua`, `home.lua` and `tree.lua` (at d4b3c0d7):

| Mutant | Killed by |
|---|---|
| `state.footers.draw(shown)` removed from `render()` | home_footer, 13 cases |
| `{ 'WinClosed', 'WinResized' }` → `{ 'WinClosed' }` | footer_child: the height-only resize, the other tab page |
| → `{ 'WinResized' }` | home_footer: closes with its window |
| `{ 'BufWinEnter', 'BufWinLeave' }` → `{ 'BufWinEnter' }` | footer_child: a window showing another buffer |
| → `{ 'BufWinLeave' }` | home_footer, 4 cases |
| `BufWipeout` callback → `function() end` | home_footer: let go |
| `elseif not is_placed(…)` → `elseif false` | home_footer, 3 cases |
| `row = size.height - count` → `- count - 1` | home_footer, 3 cases |
| `focusable = false` → `true` | home_footer: the first case |
| `for _ = 1, rows` → `for _ = 2, rows` (room one line short) | home_footer: scrolls past the footer |
| `if scrolled_up then` → `if false then` | footer_child: scrolls up past it |
| `shown_footer.cursor_line = …` removed | footer_child: scrolls up past it |
| `state.footers.keep_cursors()` removed | home_footer: a file revealed |
| every line in `role_groups.title` | home_footer: groups |
| `AineoExplorerFooterTitle = 'Title'` → `'Comment'` | home_footer: groups |
| `#lines == 0` → `== 1` (no-match line) | tree: says so when no file matches |
| the tree's lines start with `'header'` again | tree, 29 cases |
| the failure rendering keeps a line before the failure | home_footer: git fails |

The first version also followed `WinNew`, `VimResized` and `TabEnter`; removing each survived both footer suites, and they were dropped. The red of the cursor's first child case was seen by running it with the keep's event renamed to one that never fires (`CursorMoved` → `CursorHoldI`); its in-process form had been red because `CursorMoved` does not fire there after `feedkeys`.

## Open threads

- A window one row high has a one-line footer over its only row.
- A window made shorter keeps its cursor where Vim leaves it, possibly under the footer, until the cursor next moves.
- Code that counts the windows of a tab page sees the footers (`lua/aineo/changes/copy.lua`'s `close_shown_diff()` counts `nvim_tabpage_list_wins(0)`); the whole suite run by the orchestrator is where such a count would show.

## Commits

Recorded after the merge.
