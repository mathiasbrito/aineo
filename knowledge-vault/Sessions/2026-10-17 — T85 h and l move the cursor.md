# 2026-10-17 — T85 h and l keep the cursor in the files window; \d closes the diff

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `bugfix/t85-hl-cursor` · **Pull request:** into `dev`

The file's name keeps the packet's first title; the packet's purpose changed twice, with the user's two messages below.

## Links

- [[Projects/aineo]]
- [[Sessions/2026-10-09 — T42 Focus diff]] — Enter moves the cursor to its diff (D46); this packet leaves that as it is
- `doc/aineo.txt` — the `l` and `h` paragraph of *aineo-changes*, *:Aineo-diff*, *aineo-file-column*, the keys and the `<Plug>` list

## Task lines

- [X] T85 `l` and `h` in the changes pane's files window show the file's diff and keep the cursor in the files window, on that line, in Normal mode; only Enter moves the cursor to the diff (the user's decision, 2026-10-17); and `\d`, `<C-\>d`, `<Plug>(aineo-diff-close)` and `:Aineo diff close` close the diff the changes pane shows, from anywhere in the tab (the user's addition, 2026-10-17) — done on `bugfix/t85-hl-cursor`: `aineo.changes` (`copy.lua`: `show_diff_at_cursor()` takes the rule for which window's cursor moves, `cursor_follows_the_key()` for Enter, `cursor_stays()` for `l` and `h`; `close_shown_diff()`), `aineo.entry` (`actions.lua`, `tab.lua`: the action `diff close`), `plugin/aineo.lua` (the subcommand `diff`, its word `close`, the key `d`), `aineo.health` (the key list), the help and the README's keys table.

## The user's words

First message: "When navigating through the files in the git panel, 'l' and 'h' do not move the cursor to the file panel, only if the user press enter."

Correction: "no, you got me wrong, enter moves the cursor, the behavior change is that l and h now moves the cursor, in the new behavior it will not."

The first message was read as a defect (the help said `l` and `h` move the cursor, and they did). The correction makes the change a decision: `l` and `h` show the diff and leave the cursor in the files window, so the user can move down the files with the diff following; Enter alone moves the cursor to the diff.

Addition: "add the following behavior, q in the diff view window, closes it". The orchestrator's reading (A442) was a buffer-local `q` in every diff buffer. Its withdrawal (A443), from the user: a global key instead, so that `q` stays Vim's own everywhere. `\d` (Normal mode), `<C-\>d` (Terminal and Insert mode), `<Plug>(aineo-diff-close)` and `:Aineo diff close` each close the diff the pane shows in the middle column, from anywhere in the tab. The `q` map was written and measured, then dropped before any commit.

## What was done, and why

- Before the correction, 44 cases of a scratch copy of `tests/test_changes_keys.lua` measured that `l`, `h` and Enter each moved the cursor to the diff under a commit, Session work, Uncommitted and Landed, and on a second press: there was no defect, only the behaviour the user now asks to change.
- `l`, `h` and Enter all went through `show_diff_at_cursor()`, which gave `show_buffer()` the window the key was pressed in so the cursor followed. The function now takes the rule for that window: Enter's `open_entry()` passes `cursor_follows_the_key`, and `preview_entry()` (`l`) and `preview_entry_against_head()` (`h`) pass `cursor_stays`, which gives no window, so `show_buffer()` moves nothing. Every other behaviour of the three keys shares the path and is unchanged: no room, a failure, "is as HEAD has it", only the last key's diff when keys are pressed again before one was read. `gf`, which has its own path, still moves the cursor.
- `close_shown_diff()` closes every window of the current tab page that shows a diff the home showed (`shown_diffs`), which are the buffers `F` is mapped in: the file buffers `gf` shows are not among them. A diff is wiped once hidden, so the next Enter, `l` or `h` shows it again. The cursor stays where it was, unless it was in a closed window: then it goes to the window of the tab page that shows the files buffer, on the line it was on. **Chosen where the brief left it open:** with the pane not on screen the cursor goes where Neovim puts it when a window closes; the layout's `WinClosed` handler puts the columns back as it does for any closed window, so the file column goes with its last window and Claude's column takes half of the screen again. A diff that is the only window of its tab page is not closed (Neovim refuses it, E444), and aineo tells "aineo: no diff to close" as for none.
- The action `diff close` is a tab action (`aineo.entry`'s `actions.lua`, routed by `acting_tab()` like the other tab actions, so from a tab page that is none of aineo's it acts on the aineo tab used last, as `\g` does); `tab.lua` hands it to the tab's changes home. Not in `REOPENS_TABS_FIRST`. `plugin/aineo.lua` has the subcommand `diff` with the word `close`, the prefix key `d` (twin `<C-\>d` follows from the existing rule), and the command's `desc`. **Key collision check:** `\d` and `<C-\>d` collide with no aineo key or prefix: the prefix keys are `\1`…`\9`, `\c`, `\g`, `\i`, `\N`, `\o`, `\p…`, `\Q`, `\r`, `\s`, `\S`, `\t…`, `\T`.
- The health check's key list has `d`, so `:checkhealth aineo` reports it and warns when it is not mapped.
- The help: the `l` and `h` paragraph says the cursor stays and that `\d` closes the diff; new *:Aineo-diff* (with the choices above), *aineo-file-column* (a tag on an existing heading, and a sentence), `<Plug>(aineo-diff-close)`, `\d` and `<C-\>d` in the keys, the introduction, the command's completion sentence; the README's keys table has `\d`.
- Boundary widened and declared: `plugin/aineo.lua`, `lua/aineo/entry/actions.lua`, `lua/aineo/entry/tab.lua`, `lua/aineo/health.lua`, `README.md`, and the tests that pin the key lists and the usage text (`tests/helpers/entry.lua`, `test_entry.lua`, `test_entry_panes.lua`, `test_entry_prefix.lua`, `test_entry_terminal_keys.lua`, `test_plugin.lua`, `test_health.lua`).

## Seen red, arrived green

`l` and `h` (commit 1): twelve tests in `tests/test_changes_keys.lua` were seen red, each with `buffer = "aineo://…"` (the diff's buffer) where `"aineo://changes-files"` was expected: `l` and `h` keep the cursor on the file's line under a commit, Session work, Uncommitted, Landed and another worktree's whole change (ten), `l` on the same file again, and `h` then `l` on another line before the first is read. `l` then Enter moves the cursor to the diff arrived green: Enter's behaviour was already so. The existing test that pressed `h` and then `F` in the current window now enters the diff's window before `F`.

`\d` (commit 2): nine tests of `close_shown_diff()` in `tests/test_changes_keys.lua` were seen red with "attempt to call field 'close_shown_diff' (a nil value)" (their first run also failed in the test, which read a wiped buffer's name after the close; fixed). Eleven tests in `tests/test_entry_changes.lua` were seen red: the three doors for the cursor in the diff, the three for Claude's window, the message for no diff, and the four of `:Aineo diff`'s usage and completion; the columns test was written after the action and arrived green, its killer being the first entry-layer mutant below. The pinned lists (prefix keys, twins, `<Plug>` and key list of `test_plugin.lua`, health lines, `:Aineo`'s subcommands, its `desc`, its usage) were changed with the code; the health tests' indices of the lines after the keys moved with them.

## Mutants

Run on the test file named, one at a time, each restored from a copy of the file.

| Literal edit | Result |
|---|---|
| `preview_entry`: `cursor_stays` → `cursor_follows_the_key` | killed by assertion, 7 cases (keys) |
| `preview_entry_against_head`: `cursor_stays` → `cursor_follows_the_key` | killed by assertion, 5 cases (keys) |
| `open_entry`: `cursor_follows_the_key` → `cursor_stays` | killed by assertion, 2 cases (keys) |
| `show_buffer`: drop `pressed_in and` | equivalent: `nvim_get_current_win()` never returns nil, so the comparison with a nil window is false |
| `close_shown_diff`: `if #closed == 0 then` → `if false then` | killed by assertion, 2 cases (keys) |
| `close_shown_diff`: `elseif vim.tbl_contains(closed, was_in) then` → `else` | killed by assertion, 2 cases (keys) |
| `windows_showing_a_diff`: `return shown_diffs[...] ~= nil` → `return true` | killed by assertion, 8 cases (keys) |
| `close_shown_diff`: `if #vim.api.nvim_tabpage_list_wins(0) == 1 then` → `if false then` | first run killed by a crash (E444); the test then ran the call in `pcall` and asserts it ran: killed by assertion, 1 case (keys) |
| `tab.lua`: `homes.changes.close_shown_diff()` → `homes.changes.refresh_shown_pane()` | killed by assertion, 8 cases (entry_changes) |

## Open threads

None.

## Commits

Recorded after the merge.
