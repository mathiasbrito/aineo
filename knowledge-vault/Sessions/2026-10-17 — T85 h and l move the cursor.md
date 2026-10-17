# 2026-10-17 — T85 h and l keep the cursor in the files window

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `bugfix/t85-hl-cursor` · **Pull request:** into `dev`

The file's name keeps the packet's first title; the packet's purpose changed with the user's correction below.

## Links

- [[Projects/aineo]]
- [[Sessions/2026-10-09 — T42 Focus diff]] — Enter moves the cursor to its diff (D46); this packet leaves that as it is
- `doc/aineo.txt` — the `l` and `h` paragraph of *aineo-changes*

## Task lines

- [X] T85 `l` and `h` in the changes pane's files window show the file's diff and keep the cursor in the files window, on that line, in Normal mode; only Enter moves the cursor to the diff (the user's decision, 2026-10-17) — done on `bugfix/t85-hl-cursor`: `aineo.changes` (`copy.lua`: `show_diff_at_cursor()` takes the rule for which window's cursor moves, `cursor_follows_the_key()` for Enter, `cursor_stays()` for `l` and `h`; `show_buffer()` moves no cursor when given no window), the help's `l` and `h` paragraph.

## The user's words

First message: "When navigating through the files in the git panel, 'l' and 'h' do not move the cursor to the file panel, only if the user press enter."

Correction: "no, you got me wrong, enter moves the cursor, the behavior change is that l and h now moves the cursor, in the new behavior it will not."

The first message was read as a defect (the help said `l` and `h` move the cursor, and they did). The correction makes the change a decision: `l` and `h` show the diff and leave the cursor in the files window, so the user can move down the files with the diff following; Enter alone moves the cursor to the diff.

## What was done, and why

- Before the correction, 44 cases of a scratch copy of `tests/test_changes_keys.lua` measured that `l`, `h` and Enter each moved the cursor to the diff under a commit, Session work, Uncommitted and Landed, and on a second press: there was no defect, only the behaviour the user now asks to change.
- `l`, `h` and Enter all went through `show_diff_at_cursor()`, which gave `show_buffer()` the window the key was pressed in so the cursor followed. The function now takes the rule for that window: Enter's `open_entry()` passes `cursor_follows_the_key`, and `preview_entry()` (`l`) and `preview_entry_against_head()` (`h`) pass `cursor_stays`, which gives no window, so `show_buffer()` moves nothing. Every other behaviour of the three keys shares the path and is unchanged: no room, a failure, "is as HEAD has it", only the last key's diff when keys are pressed again before one was read.
- `gf`, which has its own path, still moves the cursor, as the help says.
- The help says `l` and `h` keep the cursor in the files window, on that line, in Normal mode, and that `F` works in the diff they show once the cursor is there. No other help sentence or the README said otherwise (`grep` for "cursor" over `doc/aineo.txt` and `README.md`).

## Seen red, arrived green

Twelve new tests in `tests/test_changes_keys.lua` were seen red, each with `buffer = "aineo://…"` (the diff's buffer) where `"aineo://changes-files"` was expected: `l` and `h` keep the cursor on the file's line under a commit, Session work, Uncommitted, Landed and another worktree's whole change (ten), `l` on the same file again, and `h` then `l` on another line before the first is read.

`l` then Enter moves the cursor to the diff arrived green: Enter's behaviour was already so; its killer is the third mutant below. The existing test that pressed `h` and then `F` in the current window now enters the diff's window before `F`, since `h` no longer moves the cursor there.

## Mutants

Run on `tests/test_changes_keys.lua`, one at a time, each restored from a copy of `lua/aineo/changes/copy.lua`.

| Literal edit | Result |
|---|---|
| `preview_entry`: `cursor_stays` → `cursor_follows_the_key` | killed by assertion, 7 cases |
| `preview_entry_against_head`: `cursor_stays` → `cursor_follows_the_key` | killed by assertion, 5 cases |
| `open_entry`: `cursor_follows_the_key` → `cursor_stays` | killed by assertion, 2 cases |
| `show_buffer`: drop `pressed_in and` | equivalent: `nvim_get_current_win()` never returns nil, so the comparison with a nil window is false |

## Open threads

None.

## Commits

Recorded after the merge.
