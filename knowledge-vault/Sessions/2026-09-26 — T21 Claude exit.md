# 2026-09-26 — T21 Claude exit

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t21-claude-exit` · **Pull request:** #64 into `dev` (a regular packet, the user, 2026-09-26), with one fix round on 2026-09-26/27

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (D25; C1, C2, C3; D10)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t21-claude-exit.md` and the brief review `brief-review-t19-t21.md` (T21-1 to T21-8)
- [[Sessions/2026-09-26 — T20 Claude terminal mode]], whose *Limits* (G1) and *Readings* (CT2's bound) this packet answers
- T20's guarantee review of pull request #58, findings 1 and 4, with its probes
- The fix round's inputs: PR #64's attack review (A1–A5), test-integrity review (I1–I6) and records review (R1–R8), and the orchestrator's decisions 1–8 for the round

## Context

**Goal:** T21, under D25. When Claude Code exited while the user was in its prompt, Neovim closed its terminal on the next key and the exit went with it. From the layout's own tab the wipe also broke the layout: Claude's window stayed on an empty buffer, `redirect()` tried to put the wiped terminal back, raising `Invalid buffer id` after opening an extra file column (R8), and `\c` then landed on that empty buffer and started nothing. T20 made the path common. The user chose "Both, regular (Recommended)" (D25).

## What was done

What the code does at the pull request's head (`7c9f6cd`). The fix round changed the first round's EX2 and its `TermEnter` check; see *Fix round*.

- **`lua/aineo/layout/init.lua`**, the layout home, which knows Claude's window and terminal:
  - `leave_terminal_mode_as_claude_exits()`, on `TermClose`: `:stopinsert` when the closing terminal is Claude's (`state.buffers.claude`) and the current buffer, in whatever window (EX1).
  - `remember_claude_exit()`, on `TermClose`: keeps Claude's terminal as `state.ended_claude_terminal`. `refuse_terminal_mode_once_claude_exited()`, on `TermEnter`: `:stopinsert` in that terminal. So `i`, `a`, `I`, `A` or `:startinsert` followed by typing closes nothing (EX1, T21-1), and nothing waits on the process (A5).
  - `close_claude_window_when_wiped()`, on `BufWipeout` of Claude's terminal: when Claude's window shows the wiped terminal, or the unnamed, empty buffer Neovim puts there (before the wipe for a running terminal, after it for an ended one), it schedules the close; the close runs only if the window still shows an unnamed, empty buffer (the attack review's fixA). `close_when_possible()` closes it and raises nothing when Neovim will not close it (E444, E11).
  - `M.focus()` counts a window whose role buffer was wiped as gone, and opens the layout again (the attack review's fixB).
  - `redirect()` does nothing when the window's own buffer no longer exists, so it never tries to put a wiped buffer back (EX2).
  - The autocommands live in the `aineo.layout` group, made anew by each `open()`.
- **`tests/test_entry_claude_exit.lua`**: 50 cases, driven through the entry point (`\c`, `:Aineo open`, `:Aineo claude`) and the fake `claude`.
- **`doc/aineo.txt`**, inside `*:Aineo-claude*` … `an exited Claude Code.`: a paragraph on what the exit does, and the wipe paragraph (see *Fix round*).

## Unit list and red/green — the packet (at `214a005`)

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
12. EX2: Claude's window as Neovim's last window: no error, no window added.
13. EX2: wiped from another tab: no error, and `\c` starts Claude Code again.

Units 6–8 were written after 1 and 5 on purpose: the minimum code for 1 and 5 was an unguarded `:stopinsert`, so each guard was asked for by a red. On `ac42fd3` itself, 15 of the packet's 27 cases are red and these three guards green (the test-integrity review's I6); the five *typing on* cases are red there through `child.type_keys()` raising the layout's error, not through their own assertion.

**Seen red — 13 cases in 7 tests:**

| Test | Red |
|---|---|
| returns Normal mode in Claude's window when Claude Code exits at its start, after `\c` | mode `"t"`, expected `"nt"` |
| leaves Insert mode in Input as it is | `"n"`, expected `"i"` (the unguarded handler) |
| another terminal's exit › leaves Terminal mode in that terminal as Neovim does | `"nt"`, expected `"t"` (the handler guarded only on the current buffer) |
| keeps Claude's ended terminal in Normal mode, whatever is typed on, after `i` / `a` / `I` / `A` / `:startinsert<CR>` (5) | windows `{ "", "", "aineo://report", "aineo://input" }`, expected `{ "terminal", … }` |
| another terminal's exit › lets i enter Terminal mode in that ended terminal as Neovim does | `"nt"`, expected `"t"` (the `TermEnter` handler on any ended terminal) |
| a wiped Claude terminal › closes Claude's window, raising no error, after `bwipeout!` / `bdelete!` (2) | `v:errmsg` = `…layout/init.lua:327: Invalid buffer id: 2` |
| a wiped Claude terminal › raises no error and adds no window when Claude's window is Neovim's last (2; named "…the only one of its tab" until the fix round) | first `…:327: Invalid buffer id: 2`; with the `redirect()` guard in, `…: Vim:E444: Cannot close last window` |

An existing case went red on the way and drove a guard: `tests/test_entry.lua` › `:Aineo open` › *after Claude has exited starts a new Claude in the layout*, windows `{ "aineo://report", "aineo://input" }`, under a first `BufWipeout` handler that closed Claude's window for any wipe of `state.buffers.claude` — `replace_terminal()` wipes the old terminal after showing the new one there.

**Arrived green — 14 cases:**

| Test | Why | Killer, run |
|---|---|---|
| returns Normal mode … when Claude Code exits while the user is in its prompt | spent by unit 1 | M1, assertion |
| returns Normal mode once Neovim sees an exit that a busy editor handled `\c` before | spent by unit 1 | M1, assertion |
| keeps Claude's exit on screen when a key follows it | spent by unit 1 | M1, assertion |
| a wiped Claude terminal › lets `\c` start Claude Code again, in Terminal mode (2) | spent by unit 9 | M14, M15, M6, assertion |
| a wiped Claude terminal › lets the keys of the right column move there once `\c` restarted Claude Code (4) | green by nature: `M.focus()`. The name claimed a restart the case did not assert (I2); corrected in the fix round | M16, assertion |
| a wiped Claude terminal › raises no error when the command that wipes it closes Claude's window too (2) | pins the `nvim_win_is_valid()` check written ahead of it | M10, assertion |
| a wiped Claude terminal › lets `\c` start Claude Code again, raising no error, when wiped from another tab (2) | green by nature: Neovim closes Claude's window before `BufWipeout`; pins the `has_window()` guard | M8, M6, assertion |
| another buffer wiped in Claude's window › gives Claude's window its terminal back when Neovim keeps the window open, Claude's terminal unlisted | pins the `event.buf ~= state.buffers.claude` guard; built to kill M7 | M7, assertion |

## Mutants — the packet (at `214a005`)

Each is a literal edit of `lua/aineo/layout/init.lua` at `214a005`, applied and restored by `.tests/t21-mutate.py` (in the worktree, not committed), and run against a narrowed copy of the test file that holds its group (`.tests/t21-narrow.py`; M9: `tests/test_entry.lua`), on 0.12.5. Its logs are not headed with the Neovim that ran them (R4); the test-integrity review re-ran all sixteen on 0.12.5 against the whole file and reproduced every row.

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
| M12 | `close_unless_last()`'s `error(failure, 0)` removed | wiped; the whole suite (an unheaded log, R4) | survived. **Not equivalent** (A4, I1): with the command-line window opened right after the wipe, `nvim_win_hide()` raises `E11`, which the code re-raised and M12 swallowed |
| M13 | `redirect()`'s `or not vim.api.nvim_buf_is_valid(state.buffers[role])` removed | wiped | killed, 2 assertions |
| M14 | the close runs inside `BufWipeout`, not scheduled | wiped | killed, 4 assertions |
| M15 | the `BufWipeout` autocommand removed | wiped | killed, 4 assertions |
| M16 | `M.focus()` moves to `state.windows.claude` for every role | wiped | killed, 4 assertions |

**M12's first record was false.** The packet called M12 "equivalent in every state measured", saying `nvim_win_hide()` raised only E444 "in the three states that can fail". What was measured (R5): E444 for Neovim's last window alone (the unit-12 case) and beside a float (`.tests/t21-spike4.lua`, both versions); with another tab open, no error, the tab closing, with or without a float (spike4, both versions). The states were window counts only; the command-line window was not tried. The fix round removed the re-raise (decision 2), so M12 no longer applies.

## Fix round (PR #64, 2026-09-26/27)

The three reviews of PR #64 reproduced the packet's counts, reds and kills, and found EX2 defeated on paths the packet had not tried, a freeze in EX1's refusal, and records to correct. The orchestrator's decisions 1–8 set the round; every behaviour change was driven red-first against `70a43c7`'s code, on 0.12.5 and 0.11.6, by assertion.

**What changed:**
- **A1–A3, decision 1: EX2 re-keyed, the attack review's fix adopted and credited.**
  - A1: for a *running* terminal Neovim shows the empty buffer before `BufWipeout`, so the packet's guard ("the window shows the wiped terminal") never matched, and the window stayed. The packet's decision 3 (`BufWipeout` before the empty buffer) held only for an ended terminal.
  - A2: the scheduled close closed whatever the window showed when it ran: `:bwipeout! | Aineo open` lost the new Claude Code's window (a regression from `dev`), and `:bwipeout! | edit <file>` left the file in no window.
  - fixA: close when, at `BufWipeout`, the window shows the wiped terminal or an unnamed, empty buffer, and only if it still shows an unnamed, empty buffer when the callback runs.
  - A3, fixB: `M.focus()` counts a window whose role buffer was wiped as gone, so `\c` recovers wherever Claude's window survives a wipe: Neovim's last window, a user's non-`nested` `TermClose` wipe, the command-line window. **This lifts the packet's limit on Neovim's last window.**
- **A4, I1, decision 2: the close raises nothing.** `close_unless_last()` became `close_when_possible()`, a `pcall` that leaves a window Neovim will not close (E444, E11) as it is; fixB recovers it. The packet's "every other error is raised" is withdrawn.
- **A5, decision 3: no wait on a stopped job.** `has_ended()`'s `jobwait({channel}, 0)` blocked about 4 s on a job `jobstop()` had stopped but that still ran (the deaf fake). The packet's decision 2 had rejected a record kept by `TermClose`; it is adopted: `remember_claude_exit()` and `state.ended_claude_terminal`.
- **I2–I5, decisions 4–7: tests.** The right-column cases assert the restart (`starting`); the helpers assert the exit they wait for; pins A (Claude's terminal current in another tab's window) and B (`| close | Aineo claude`) are added; a typed exit through `claude_session.end_by_keys()` is added.
- **R1–R8, decision 8: records**, in this note, the help and the pull request.

**The round's cases — 23 new, 8 changed, 2 renamed:**

Seen red on `70a43c7`'s code — 16 cases, by assertion, on 0.12.5 and on 0.11.6 (`t21-fr-red-0125.log`, `t21-fr-red-0116.log`, both headed):

| Test | Red on `70a43c7` | Green after |
|---|---|---|
| returns at once when i is typed in Claude's terminal whose stopped process still runs | `false` (the `i` took about 4 s) | the record (decision 3) |
| a wiped Claude terminal › lets `\c` start Claude Code again when Claude's window was Neovim's last (2) | `"exited"` | fixB |
| a wiped Claude terminal › keeps the window of the Claude Code that :Aineo open starts in the same command line (2) | windows `{ "aineo://report", "aineo://input" }` | fixA |
| a wiped Claude terminal › keeps in view the file the same command line opens in Claude's window (2) | windows `{ "aineo://report", "aineo://input" }` | fixA |
| a wiped Claude terminal › raises no error when the command-line window opens right after it (2) | `v:errmsg` = `vim.schedule callback: E11: …` (0.11.6: `Error executing vim.schedule lua callback: E11: …`) | decision 2 |
| a wiped Claude terminal › lets `\c` start Claude Code again once the command-line window that opened right after it is closed (2) | `"exited"` | decision 2 with fixB |
| a wiped running Claude terminal › closes Claude's window, raising no error (2) | windows `{ "", "aineo://report", "aineo://input" }` | fixA |
| a wiped running Claude terminal › lets `\c` start Claude Code again, in Terminal mode (2) | `"exited"` | fixA |
| a user's TermClose autocommand that wipes Claude's terminal › lets `\c` start Claude Code again | `"exited"` | fixB |

The attack review's seven candidate cases are among them; its first candidate, with two act–assert steps, became the two *wiped running* cases. The command-line-window pair's first version pressed `<C-c>` in the command-line window, which drops into Command-line mode, so its `\c` was typed into the command line; it closes that window with `:quit<CR>`, and was seen red again on `70a43c7`'s code after the change.

Arrived green — 7 new cases, and the 8 changed ones, each with its killer run (the 2 renamed *Neovim's last* cases are unchanged):

| Test | Why | Killer, run |
|---|---|---|
| returns Normal mode in Claude's window when Claude Code exits on the keys the user types to it (I5) | spent by unit 1 | M1 (0.12.5, 0.11.6) and R3 (0.12.5), assertion |
| returns Normal mode when Claude Code exits while the user is in its terminal in another tab's window (pin A, I3) | spent by unit 1; pins the buffer key | R11, assertion, 0.12.5 and 0.11.6 |
| a wiped Claude terminal › keeps the window Claude's window reopened in the same command line (pin B, I3) (2) | green on `70a43c7`, where R12 killed it (the test-integrity review, both versions). After fixA R12 no longer reaches it: the callback's re-check keeps the reopened window, whose buffer is the new terminal | R12b, assertion |
| a wiped Claude terminal › keeps an empty buffer the same command line opens in Claude's window once it reopened (2) | built to kill R12 after fixA | R12, assertion, 0.12.5 and 0.11.6 |
| a Claude terminal wiped while Claude's window shows another buffer › keeps the empty buffer the same command line opens there | built to kill F15 | F15, assertion, 0.12.5 and 0.11.6 |
| the right-column cases, now asserting `starting` after `\c` (4, I2) | changed | red on `ac42fd3`'s layout (BASE), 4 assertions; M16, 4 assertions. F14 (the `BufWipeout` autocommand removed, the old M15) no longer kills them: fixB restarts Claude Code without it |
| *in its prompt*, *Input*, and the two *another terminal's exit* cases, their waits now asserted (I4) | changed | T1 (the helpers' two `jobstop` lines deleted), 4 assertions |

## Mutants — the fix round

Each is a literal edit applied by `.tests/t21-fr-mutate.py` from a pristine copy of the file, byte-for-byte restored, its log headed with `uptime` and `nvim --version | head -1`. EX1 mutants ran against the test file narrowed to *Claude Code's exit* and *another terminal's exit*; EX2 mutants against *a wiped Claude terminal*, *a wiped running Claude terminal*, *a user's TermClose autocommand…* and *another buffer wiped…*; on 0.12.5 unless marked; code at `e0a89e1`, pins at `7c9f6cd`.

| # | Literal edit | Result |
|---|---|---|
| F1 | `if shown ~= event.buf and not is_unnamed_and_empty(shown) then` → `if shown ~= event.buf then` | killed, 2 (the running wipe) |
| F2 | the same line → `if not is_unnamed_and_empty(shown) then` | killed, 2 (the ended wipe) |
| F3 | the callback's `vim.api.nvim_win_is_valid(window) and is_unnamed_and_empty(…)` → `vim.api.nvim_win_is_valid(window)` | killed, 4 (`:Aineo open`, `edit`) |
| F4 | `M.focus()`: `or not vim.api.nvim_buf_is_valid(state.buffers[role])` removed | killed, 5 |
| F5 | `close_when_possible()`: `pcall(vim.api.nvim_win_hide, window)` → `vim.api.nvim_win_hide(window)` | killed, 4 (last window, command-line window) |
| F6 | `remember_claude_exit()`: `state.ended_claude_terminal = event.buf` removed | killed, 5 |
| F7 | its guard removed: `state.ended_claude_terminal = event.buf` for every terminal | killed, 1 (another ended terminal) |
| F8 | `refuse_terminal_mode_once_claude_exited()`: `event.buf == state.ended_claude_terminal` → `event.buf == state.buffers.claude` | survived its group; the whole suite: killed, 18 (T20's `\c` cases and every restart in Terminal mode) |
| F9 | the `remember_claude_exit` autocommand removed | killed, 5 |
| F10 | the callback's `vim.api.nvim_win_is_valid(window) and` removed | killed, 2 (`| close`) |
| F11 | `or not has_window('claude')` removed | killed, 2 (another tab) |
| F12 | `event.buf ~= state.buffers.claude or` removed | killed, 1 (another buffer) |
| F13 | the close runs inside `BufWipeout`, not scheduled | killed, 2 |
| F14 | the `BufWipeout` autocommand removed | killed, 4 |
| F15 | the `local shown …` check at the wipe removed | survived the EX2 group; killed, 1, by its pin (0.12.5 and 0.11.6) |
| M1 | `leave_terminal_mode_as_claude_exits()`: `vim.cmd.stopinsert()` removed | killed, 11 (0.12.5 and 0.11.6) |
| M2 | its buffer guard removed | killed, 1 |
| M3 | its current-buffer guard removed | killed, 1 |
| M4 | `refuse_terminal_mode_once_claude_exited()`: `vim.cmd.stopinsert()` removed | killed, 5 |
| M13 | `redirect()`'s guard removed | killed, 12 |
| M16 | `M.focus()` moves to `state.windows.claude` for every role | killed, 4 |
| R3 | the `leave_terminal_mode_as_claude_exits` autocommand removed | killed, 11 |
| R11 | `leave_terminal_mode_as_claude_exits()` keyed on Claude's window: `… and vim.api.nvim_get_current_win() == state.windows.claude` | killed, 1 (pin A), 0.12.5 and 0.11.6 |
| R12 | the callback reads `state.windows.claude`, not the captured window | survived the EX2 group; killed, 2, by its pin (0.12.5 and 0.11.6) |
| R12b | the callback's `if … then close_when_possible(window) end` → `close_when_possible(state.windows.claude)` | killed, 2 (pin B) |
| T1 | the helpers' two `jobstop` lines deleted (a test mutant) | killed, 4 |
| BASE | `ac42fd3`'s whole layout file | the right-column cases: killed, 4 |

## Decisions & reasoning

1. **EX1 keys on Claude's terminal buffer**, `state.buffers.claude`, not on Claude's window: the terminal is what a key would close, whichever window shows it. Put to the MVP review as a reading (R1).
2. **Superseded in the fix round (A5, decision 3).** The packet read `jobwait({channel}, 0)` to tell an ended job, "rather than a flag the `TermClose` handler would keep: it reads the state the key would meet". That wait blocked about 4 s on a stopped job that still ran; the record kept by `TermClose` replaced it, and `TermClose`'s `:stopinsert` covers the moments before Neovim sees the exit.
3. **Corrected in the fix round (A1).** The packet said `BufWipeout` fires before the empty buffer enters the window (`BufWipeout:2`, then `BufEnter:4`, `BufWinEnter:4`, both versions). That holds for an **ended** terminal only; for a running one Neovim shows the empty buffer first.
4. **Superseded (A1, A2, fixA).** The packet closed the window only when it showed the wiped terminal at `BufWipeout`. Now: the wiped terminal or an unnamed, empty buffer at the wipe, and an unnamed, empty buffer still when the close runs. `\o`'s restart (`replace_terminal()` shows the new terminal first) keeps its window through both checks.
5. **Superseded (A4, decision 2).** The packet let Neovim's `E444` decide and raised every other error. The close now raises nothing, and `M.focus()` (fixB) recovers a window left open.
6. **The typed-Ctrl-C path through Neovim is not driven.** Neovim sends a typed Ctrl-C as `ESC[99;5u` once the fake's recorded screen enables the kitty keyboard protocol (`ESC[>5u`; Neovim answers its query with `ESC[?5u`) (R7), on 0.12.5 **and 0.11.6** (I5), and the fake reads only `\3`. The self-exit on keys is driven instead by `claude_session.end_by_keys()`, which sends `\3\3` to the pty (I5, decision 7); the in-prompt case ends Claude Code by hangup.

## Verification

- **The packet**, at `214a005`: `make test` 1012 cases, `Fails (0)`, on 0.12.5 (load 30–46) and 0.11.6 (load 52–79); the baseline 985 (`evidence/baseline-525b22b.txt`).
- **The fix round**, at `e0a89e1`: 1032 cases, `Fails (0)`, exit 0, on 0.12.5 and 0.11.6. At `7c9f6cd`, after the last edit to code or tests: 1035 cases, `Fails (0)`, exit 0, on 0.12.5 (load 175 at the start) and on 0.11.6 (load 113 at the start) (`t21-fr-final-0125.log`, `t21-fr-final-0116.log`, headed). The baseline 985 plus 50 cases in this file.
- `make lint`: clean. The deep-require check prints only lines inside their own homes; this change adds none.
- **The merge check against T18.** At the packet: `git merge-tree --write-tree 214a005 origin/bugfix/t18-report-line` printed `92f4237`, no conflict, and `tests/test_doc.lua` gave `Fails (0)` on the merged help; the packet's two logs were byte-identical and unheaded (R4). The records review re-measured it headed, on 0.12.5 and 0.11.6 (`records-merge-doc-0125.log`, `records-merge-doc-0116.log`). T18 has since merged into `dev`.

## Readings for the MVP review

- **EX1 applies to Claude's window only: another terminal of the user's keeps Neovim's own behaviour** (the orchestrator's reading 1, as the brief gives it).
- **EX1 keys on Claude's terminal, not on Claude's window** (the author's reading; EX1 and reading 1 say "only Claude's window"). Normal mode returns, and Terminal mode is refused after the exit, wherever Claude's terminal is the current buffer: a window of another tab that shows it counts too, measured (pin A; the records review's probe). Input's Insert mode and any other terminal keep Neovim's behaviour.
- **EX1 leaves the user in Normal mode even when they were typing when Claude Code exited:** a key they type then is a Normal-mode command, and Terminal mode is not entered again on the ended terminal.
- **EX1 is written in the layout home (C2's module)** by the orchestrator's choice, so that T19 can change the Claude home after it: C3's row names the behaviour, not its module.

## Task lines

The wave holds its marks (rule 6). The line T21 would take:

- [X] T21 — Claude's exit keeps the layout (D25, C2, C3): Normal mode returns in Claude's terminal when Claude Code exits while the user is in it, and Terminal mode is not entered again there; a wiped Claude terminal, running or ended, closes Claude's window with no error and no extra window, and `\c` then starts Claude Code again, also where Neovim keeps that window open — regular (the user, 2026-09-26), with one fix round (PR #64's reviews).

## Limits

- **A typed exit through Neovim is not driven** (R3). A typed double Ctrl-C reaches the fake as `ESC[99;5u` on 0.12.5 and 0.11.6, which it does not decode, and the fake has no `/exit`. The self-exit on keys is driven through `end_by_keys()` (`\3\3` to the pty), and the in-prompt case through a hangup.
- **The busy-editor case** asserts the end state. Whether the exit landed during the 1.5 s the editor was kept busy is not observed; T20's brief review (F6) measured that order 6 of 6 times on each version (R6).
- **A terminal the Claude home replaces on its own** (T19-1): `state.buffers.claude` still names the old one, so EX1 and EX2 do not apply to the replacement until the layout is told. That is T19's to carry.
- **A window Neovim will not close stays on the empty buffer** until a focus opens the layout again: Neovim's last window, the window the command-line window was opened from.

## Open threads

- **Input and the Report after a wipe**, measured by the attack review (R5, R6): with fixB, `\i` and `\r` remake them in their windows; before it, they landed on the empty buffer.
- **Learning candidate:** a typed Ctrl-C reaches a kitty-keyboard-enabled terminal (`ESC[>5u`) as `ESC[99;5u` on 0.12.5 and 0.11.6; the fake `claude` does not decode it.
- **Learning candidate:** for a running terminal, `:bwipeout` puts Neovim's empty buffer in the window before `BufWipeout`; for an ended one, after.

## Commits

*Recorded after the merge.*
