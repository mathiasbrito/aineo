# 2026-09-26 — T21 Claude exit

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t21-claude-exit` · **Pull request:** into `dev` (a regular packet, the user, 2026-09-26)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (D25; C1, C2, C3; D10)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t21-claude-exit.md` and the brief review `brief-review-t19-t21.md` (T21-1 to T21-8)
- [[Sessions/2026-09-26 — T20 Claude terminal mode]], whose *Limits* (G1) and *Readings* (CT2's bound) this packet answers
- T20's guarantee review of pull request #58, findings 1 and 4, with its probes

## Context

**Goal:** T21, under D25. When Claude Code exited while the user was in its prompt, Neovim closed its terminal on the next key and the exit went with it. From the layout's own tab the wipe also broke the layout: Claude's window stayed on an empty buffer, `redirect()` put the wiped terminal back and raised `Invalid buffer id` after opening an extra file column, and `\c` then landed on that empty buffer and started nothing. T20 made the path common. The user chose "Both, regular (Recommended)" (D25).

## What was done

- **`lua/aineo/layout/init.lua`**, the layout home, which knows Claude's window and terminal:
  - `leave_terminal_mode_as_claude_exits()`, on `TermClose`: `:stopinsert` when the closing terminal is Claude's (`state.buffers.claude`) and the current buffer (EX1).
  - `refuse_terminal_mode_once_claude_exited()`, on `TermEnter`: `:stopinsert` in Claude's terminal once its job has ended (`has_ended()`: `jobwait({channel}, 0)` is no longer `-1`). So `i`, `a`, `I`, `A` or `:startinsert` followed by typing closes nothing (EX1, the brief review's T21-1).
  - `close_claude_window_when_wiped()`, on `BufWipeout`: when Claude's terminal is wiped while Claude's window shows it, that window is closed once the wipe is done (`vim.schedule`), unless it is Neovim's last window (`close_unless_last()`, which tolerates `E444` only and raises anything else, as `open_window_above()` does with `E36`) (EX2).
  - `redirect()` does nothing when the window's own buffer no longer exists, so it never puts a wiped buffer back (EX2).
  - The three autocommands live in the `aineo.layout` group, made anew by each `open()`.
  - Docstrings: the handlers, `has_ended()`, `close_unless_last()`, `redirect()`, `watch_windows()` and `M.open()`.
- **`tests/test_entry_claude_exit.lua`**, a new file of 27 cases, driven through the entry point (`\c`, `:Aineo open`) and the fake `claude`.
- **`doc/aineo.txt`**, inside `*:Aineo-claude*` … `an exited Claude Code.`: a paragraph on what the exit now does, and the wipe paragraph now says the next `\c` starts Claude Code again, in a new terminal (the brief review's T21-7), and that the wipe closes Claude's window unless it was Neovim's last one.

## Unit list and red/green

The slicing, stated before the first test (EX1, then its negatives, then EX2):

1. EX1 at the start: `\c` on a Claude Code that exits at its start returns Normal mode.
2. EX1 in the prompt: an exit while the user is in Claude's prompt returns Normal mode.
3. EX1, CT2's bound: an exit a busy editor handled `\c` before returns Normal mode once seen.
4. EX1: the next key after the exit closes nothing.
5. EX1: `i`, `a`, `I`, `A`, `:startinsert`, then typing "fix this", closes nothing.
6. EX1 negative: Insert mode in Input stays when Claude Code exits.
7. EX1 negative: another terminal keeps Terminal mode when its process ends.
8. EX1 negative: `i` enters Terminal mode in another ended terminal.
9. EX2: `:bwipeout!` / `:bdelete!` from Claude's window, no other listed buffer: Claude's window closes, no error.
10. EX2: `\c` then starts Claude Code again, in Terminal mode.
11. EX2: `\r` and `\i` then move to their windows.
12. EX2: Claude's window as the only window of its tab: no error, no window added.
13. EX2: wiped from another tab: no error, and `\c` starts Claude Code again.

Units 6–8 were written after 1 and 5 on purpose: the minimum code for 1 and 5 was an unguarded `:stopinsert`, so each guard was asked for by a red.

**Seen red — 13 cases in 7 tests:**

| Test | Red |
|---|---|
| returns Normal mode in Claude's window when Claude Code exits at its start, after `\c` | mode `"t"`, expected `"nt"` |
| leaves Insert mode in Input as it is | `"n"`, expected `"i"` (the unguarded handler) |
| another terminal's exit › leaves Terminal mode in that terminal as Neovim does | `"nt"`, expected `"t"` (the handler guarded only on the current buffer) |
| keeps Claude's ended terminal in Normal mode, whatever is typed on, after `i` / `a` / `I` / `A` / `:startinsert<CR>` (5) | windows `{ "", "", "aineo://report", "aineo://input" }`, expected `{ "terminal", … }` |
| another terminal's exit › lets i enter Terminal mode in that ended terminal as Neovim does | `"nt"`, expected `"t"` (the `TermEnter` handler on any ended terminal) |
| a wiped Claude terminal › closes Claude's window, raising no error, after `bwipeout!` / `bdelete!` (2) | `v:errmsg` = `…layout/init.lua:327: Invalid buffer id: 2` |
| a wiped Claude terminal › raises no error and adds no window when Claude's window is the only one of its tab (2) | first `…:327: Invalid buffer id: 2`; with the `redirect()` guard in, `…: Vim:E444: Cannot close last window` |

An existing case went red on the way and drove a guard: `tests/test_entry.lua` › `:Aineo open` › *after Claude has exited starts a new Claude in the layout*, windows `{ "aineo://report", "aineo://input" }`, under a first `BufWipeout` handler that closed Claude's window for any wipe of `state.buffers.claude` — `replace_terminal()` wipes the old terminal after showing the new one there. The handler now closes the window only when it shows the wiped terminal.

**Arrived green — 14 cases:**

| Test | Why | Killer, run |
|---|---|---|
| returns Normal mode … when Claude Code exits while the user is in its prompt | spent by unit 1 | M1, assertion |
| returns Normal mode once Neovim sees an exit that a busy editor handled `\c` before | spent by unit 1 | M1, assertion |
| keeps Claude's exit on screen when a key follows it | spent by unit 1 | M1, assertion |
| a wiped Claude terminal › lets `\c` start Claude Code again, in Terminal mode (2) | spent by unit 9 | M14, M15, M6, assertion |
| a wiped Claude terminal › lets the keys of the right column move there once `\c` restarted Claude Code (4) | green by nature: `M.focus()` | M16, assertion |
| a wiped Claude terminal › raises no error when the command that wipes it closes Claude's window too (2) | pins the `nvim_win_is_valid()` check written ahead of it | M10, assertion |
| a wiped Claude terminal › lets `\c` start Claude Code again, raising no error, when wiped from another tab (2) | green by nature: Neovim closes Claude's window before `BufWipeout`; pins the `has_window()` guard | M8, M6, assertion |
| another buffer wiped in Claude's window › gives Claude's window its terminal back when Neovim keeps the window open, Claude's terminal unlisted | pins the `event.buf ~= state.buffers.claude` guard, which M7 removes; built to kill M7 | M7, assertion |

## Mutants

Each is a literal edit of `lua/aineo/layout/init.lua` at the committed head, applied and restored by `.tests/t21-mutate.py` (in the worktree, not committed), and run against a copy of `tests/test_entry_claude_exit.lua` narrowed to the group that targets it (`.tests/t21-narrow.py`), on 0.12.5.

| # | Edit | Group | Result |
|---|---|---|---|
| M1 | `leave_terminal_mode_as_claude_exits()`: `vim.cmd.stopinsert()` removed | exit | killed, 9 assertions |
| M2 | its `event.buf == state.buffers.claude and` removed | another terminal | killed, 1 assertion |
| M3 | its `and event.buf == vim.api.nvim_get_current_buf()` removed | exit | killed, 1 assertion (Input) |
| M4 | `refuse_terminal_mode_once_claude_exited()`: `vim.cmd.stopinsert()` removed | exit | killed, 5 assertions |
| M5 | its `event.buf == state.buffers.claude and` removed | another terminal | killed, 1 assertion |
| M6 | `has_ended()` returns `true` | wiped | killed, 4 assertions |
| M7 | `close_claude_window_when_wiped()`: `event.buf ~= state.buffers.claude or` removed | wiped: survived; another buffer | killed, 1 assertion |
| M8 | its `or not has_window('claude')` removed | wiped | killed, 2 assertions (a crash before the wipes went through `entry.command()`) |
| M9 | its `or vim.api.nvim_win_get_buf(state.windows.claude) ~= event.buf` removed | `tests/test_entry.lua` › `:Aineo open` | killed, 1 assertion |
| M10 | the scheduled `if vim.api.nvim_win_is_valid(window)` removed | wiped | killed, 2 assertions |
| M11 | `close_unless_last()` is `vim.api.nvim_win_hide(window)` | wiped | killed, 2 assertions |
| M12 | `close_unless_last()`'s `error(failure, 0)` removed | wiped; the whole suite | survived: see below |
| M13 | `redirect()`'s `or not vim.api.nvim_buf_is_valid(state.buffers[role])` removed | wiped | killed, 2 assertions |
| M14 | the close runs inside `BufWipeout`, not scheduled | wiped | killed, 4 assertions |
| M15 | the `BufWipeout` autocommand removed | wiped | killed, 4 assertions |
| M16 | `M.focus()` moves to `state.windows.claude` for every role | wiped | killed, 4 assertions |

**M12 survives, equivalent in every state measured:** `nvim_win_hide()` on a valid window raised only `E444` in the three states that can fail — Neovim's last window alone, beside a float, and with another tab (which closes the tab instead) — on 0.12.5 and 0.11.6 (`.tests/t21-spike4.lua`). The re-raise keeps any other failure visible, as the file's `open_window_above()` does for `E36`.

## Decisions & reasoning

1. **EX1 keys on Claude's terminal buffer**, `state.buffers.claude`, not on Claude's window: the terminal is what a key would close, whichever window shows it.
2. **`jobwait({channel}, 0)` tells an ended job** (`-3` once reaped, `-1` while running, measured on both versions), rather than a flag the `TermClose` handler would keep: it reads the state the key would meet.
3. **Claude's window closes on the wipe, in a scheduled callback.** `BufWipeout` fires before the empty buffer enters the window (`BufWipeout:2`, then `BufEnter:4`, `BufWinEnter:4`, and their scheduled callbacks in that order, both versions), so the close runs before `redirect()`'s.
4. **The window is closed only when it shows the wiped terminal at `BufWipeout`.** `\o`'s restart (`replace_terminal()`) shows the new terminal first, and the layout must keep that window.
5. **Neovim decides what "last window" means** (`E444`), rather than a predicate of the layout's.
6. **The typed-Ctrl-C path is not tested.** On 0.12.5 Neovim sends Ctrl-C as `ESC[99;5u` once the fake's recorded screen enables the kitty keyboard protocol (`ESC[?5u`), and the fake reads only `\3`, so it never exits. The in-prompt case ends Claude Code by hangup (`jobstop`) instead; `tests/helpers/` is outside the boundary.

## Verification

- `make test` at `214a005` (the code this note ships with): 0.12.5, 1012 cases, `Fails (0)`, exit 0 (load 30–46); 0.11.6, 1012 cases, `Fails (0)`, exit 0 (load 52–79). The baseline was 985 (`evidence/baseline-525b22b.txt`); this file adds 27.
- M12 against the whole suite on 0.12.5: 1012 cases, `Fails (0)`.
- `make lint`: clean. The deep-require check prints only lines inside their own homes; this change adds none.
- **The merge check against `origin/bugfix/t18-report-line` (`d7906dd`, unmerged):** `git merge-tree --write-tree 214a005 origin/bugfix/t18-report-line` printed the tree `92f4237` and no conflict. With its `doc/aineo.txt` and `tests/test_doc.lua` in place, `make test_file FILE=tests/test_doc.lua` gave `Fails (0)` on 0.12.5 and on 0.11.6; both files were then restored from `HEAD`.

## Readings for the MVP review

- **EX1 applies to Claude's terminal only:** another terminal of the user's keeps Neovim's own behaviour, and so does Input's Insert mode.
- **EX1 leaves the user in Normal mode even when they were typing when Claude Code exited:** a key they type then is a Normal-mode command, and Terminal mode is not entered again on the ended terminal.
- **EX1 is written in the layout home (C2's module)** by the orchestrator's choice, so that T19 can change the Claude home after it: C3's row names the behaviour, not its module.

## Task lines

The wave holds its marks (rule 6). The line T21 would take:

- [X] T21 — Claude's exit keeps the layout (D25, C2, C3): Normal mode returns in Claude's terminal when Claude Code exits while the user is in it, and Terminal mode is not entered again there; a wiped Claude terminal closes Claude's window with no error and no extra window, and `\c` then starts Claude Code again — regular (the user, 2026-09-26). Claude's window as Neovim's last window stays on an empty buffer, where `\c` starts nothing (a limit).

## Limits

- **Claude's window as Neovim's last window.** The wipe then raises no error and adds no window, but the window stays on Neovim's empty buffer, and `\c` moves there in Normal mode and starts nothing. `\o` restores the layout.
- **The busy-editor case** asserts the end state. Whether the exit landed during the 1.5 s the editor was kept busy is not observed; the brief review measured that order 6 of 6 times.
- **A terminal the Claude home replaces on its own** (T19-1): `state.buffers.claude` still names the old one, so EX1 and EX2 do not apply to the replacement until the layout is told. That is T19's to carry.

## Open threads

- **Input and the Report after a wipe.** The `redirect()` guard covers any role, but only Claude's window is closed on a wipe. What a wiped Input or Report, shown in its window with no other listed buffer, leaves behind was not measured.
- **Learning candidate:** a typed Ctrl-C reaches a kitty-keyboard-enabled terminal as `ESC[99;5u` on 0.12.5; the fake `claude` does not decode it.

## Commits

*Recorded after the merge.*
