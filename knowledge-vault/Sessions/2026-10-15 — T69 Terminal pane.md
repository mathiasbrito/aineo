# 2026-10-15 — T69 Terminal pane

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t69-terminal-pane` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D18, D25, D59, D63, **D68**, C2, C12
- [[Implementation/Waves/00016-terminal-pane/plan]] › O4, O5, O7–O12 (the orchestrator's assumptions A279–A292, never the user's decisions) and *Verification mutants*
- [[Implementation/Waves/00016-terminal-pane/brief-t69-terminal-pane]], with its dispatch amendment
- [[Sessions/2026-10-14 — T66 Tabs]] (the shape of a copy per tab)

Stage 1 of wave 16: the layout's third pane, `terminal`, and the new shell home `lua/aineo/shell/`. No key, no composition-root change, no help and no health line: those are T70's. Measured on Neovim 0.12.5.

## Task lines

- [X] T69 The terminal pane and the shell home (C12; D18, D68) — done on `feature/t69-terminal-pane`: `aineo.layout` shows the shell's terminal in the Report's window over Input as a third pane (`show_pane('terminal')`, `focus_pane('terminal')`), gives the agent pane back in place when the shell ends and reopens the Report's window in place when a wipe closed it, and forgets a shell that ended; the new `aineo.shell` starts `'shell'` in an unlisted terminal in the given directory with `AINEO_CHILD=1`, wipes it when it ends and stops it on `stop()` and `let_go()`, one copy per tab through `new()`. No key yet, no behaviour change for the user. Left to T70: the key, Terminal mode on arrival, the tab's close, the health check and the help.

## What was built

**The shell home** (`lua/aineo/shell/init.lua`, requires no aineo home). The interface T70 calls, on the module (the first tab's copy) and on each `new()` copy alike:

- `start(settings)` with `settings = { cwd = <existing directory> }` returns the shell's buffer. The buffer is unlisted, `'bufhidden'` `hide`, shown in no window; the shell is `'shell'` split as `:terminal` splits it, with the editor's environment and `AINEO_CHILD=1`. While the copy's shell lives it returns the same buffer and starts nothing. It raises naming `settings.cwd`, or `'shell'` and the program.
- `shell_buffer()` gives the live shell's buffer or `nil`.
- `stop()` stops the shell's job, wipes the buffer at once and forgets the shell; nothing without a shell.
- `let_go()`, on copies only: `stop()` and the copy's autocommand group removed.

The end of the shell's process (`TermClose`, any status) makes the copy forget the shell and wipe the buffer from `vim.schedule`, after every `TermClose` handler. A buffer wiped sooner (Neovim's own handler on `exit` 0 for a shell run as `'shell'` alone, `:bdelete!`, `:bwipeout!`, or a command no handler sees) is forgotten by the next `shell_buffer()` or `start()`. Handlers sit in the group `aineo.shell` (module) or `aineo.shell.<n>` (copy).

**The layout** (`lua/aineo/layout/init.lua`).

- `Pane` gains `'terminal'`, `Arrangement` gains the optional `shell`. `PANE_BUFFERS.terminal = { report = 'shell', input = 'input' }`; `PANE_LANDING.terminal = 'report'`.
- `OTHER_PANE` and `shows_a_buffer_of()` are replaced by `shows_a_buffer_of_another_pane()`: a window showing a buffer the pane asked for shows there too never counts.
- `focus('input')` under the terminal pane leaves the shell shown (`focus_shows_agent_pane()`); `focus('report')` shows the agent pane first.
- `watch_shell()` adds three handlers to the layout's group:
  - `TermClose`: while the Report's window exists, the agent pane shows in place (so the Report's window stays the same window), and the shell is forgotten, whichever pane shows.
  - `WinClosed`: notes whether the cursor was in the Report's window when it closed with the shell in it.
  - `BufWipeout`: the shell is forgotten, the agent pane becomes the pane shown at once, and, from `vim.schedule`, the agent pane is shown again: the Report's window is opened again above Input when the wipe closed it (and not when the user had closed it earlier), the proportions are put back, and the cursor goes to the Report if it was in the shell's window and stays where it is otherwise.

## The orchestrator's rulings applied (assumptions, never the user's decisions)

A279–A292 (O1–O14 of the wave plan) as the brief was written for them: the shell takes the Report's window (O4); `\i` leaves the shell shown, `\r` shows the agent pane (O5); a new home, `aineo.shell` (O7); `'shell'`, unlisted (O8); the directory is the caller's (O9); `AINEO_CHILD=1` (O10); every end shows the agent pane (O12). Not built here, by the brief: the key, Terminal mode on arrival (O6, O11), the tab's close (O13), health and help (O14).

## Unit list (stated before the first test)

Shell home: (1) module and `new()` copies, functions as fields; (2) `start()` returns a terminal running `'shell'`; (3) its directory; (4) `AINEO_CHILD`; (5) the editor's environment otherwise; (6) unlisted, kept hidden, not shown; (7) same buffer while alive; (8) not executable; (9) bad directory; (10) `shell_buffer()`; (11) the end of the shell, any status; (12) the wipe waits past `TermClose`; (13) a buffer wiped by hand; (14) `stop()`; (15) two copies; (16) `let_go()`.

Layout: (17) the terminal pane in the Report's window; (18) the arrangement's shell optional; (19) refused without a shell; (20) the landing; (21) asked for again; (22) switches among three panes, views, arrival, wrap; (23) `focus()`; (24) the shell ends; (25) the shell is wiped; (26) the cursor; (27) another pane showing; (28) `open()`; (29) copies.

## Red and green, test by test

`tests/test_shell.lua`, 31 cases at the first push (39 after the fix round). **Seen red** (message in the run): `new()` copy and the three fields (4 cases, `module 'aineo.shell' not found`); `start()` returns a terminal (`Invalid 'name': Expected Lua string`, the function returned nothing); cwd; `AINEO_CHILD`; same buffer while alive; non-executable program; bad `settings.cwd` (3 cases); `shell_buffer()`; the end of a shell (4 cases); `stop()`; `let_go()`. The cwd case's first red was a wrong reason (the terminal wraps a long path over screen rows); the test was changed to print the directory's name, and its red was seen again with `cwd` taken out.

**Arrived green**, each with its reason and the mutant that kills it:
- environment otherwise (default of `jobstart()`; S16 `clear_env = true`); unlisted and hidden (`nvim_create_buf(false, true)`; S3, S4); shown in no window (S8); quoted words (tokenizer written with `start()`, ahead of its case; S11); the deferral past `TermClose` (written ahead; S5, killed by assertion); a buffer wiped by hand (written ahead; S15 kills the `BufWipeout` forget for `exit 0`); `stop()` with no shell (empty stub); the three `two homes` cases and the `let_go` field case (code written ahead of them; S2 kills them by assertion).

`tests/test_layout_terminal_pane.lua`, 52 cases at the first push (61 after the fix round). **Seen red**: the terminal pane in the Report's window (`expected 'agent' or 'changes'`); focus landing (`nvim_set_current_win`: no landing); asked for again (2 cases, `attempt to index a nil value` in `shows_a_buffer_of()`; the first case's own red was hidden by an error in the test, so its kill is shown by mutant L5); `focus('input')` (2 cases); the shell ends, same window; the shell wiped (3 cases, then 2 of them again after the first design closed over the wipe's own `TermClose`); the moved pin in `tests/test_layout_panes.lua` (`'agent' or 'changes'` words). The unwiped-terminal case (3 cases) was written after mutant L9 survived; it is red against that mutant, not against missing code.

**Arrived green**: the arrangement's shell optional (2) and the refusal naming `arrangement.shell` (the error and `take_arrangement` were written with the first unit; L10, L12); the six switches, the scrolled views, the arrival followed and the wrap (generic through `PANE_BUFFERS`; L16 kills the switches); `focus('report')` and `focus('claude')`; the cursor cases (9; L7, L8, L14, L15); another pane showing (6; L9, L12); `open()` (2; L1 kills the second, L10 the first); the two layouts (4; L1, L2); the reopened layout's next shell.

## Mutants — literal edits, run on the committed final tree

Shell home, on `tests/test_shell.lua`; layout, on `tests/test_layout_terminal_pane.lua`. Every row is killed; the kind is read from the run's output. The wave plan's mutants are the rows marked W.

| # | Edit | Killed by |
|---|---|---|
| S1 (W3) | `lua/aineo/shell/init.lua`: `env = CHILD_ENVIRONMENT` removed from the `jobstart()` options | assertion: `gives the shell AINEO_CHILD=1` |
| S2 (W4) | `new()`: `local home = make_shell(group_name)` → `local home = M` | assertion: 6 cases (`gives a home of its own…`, `two homes` ×3, `a home let go` ×2) |
| S3 | `nvim_create_buf(false, true)` → `(true, true)` | assertion: `makes an unlisted buffer…` |
| S4 | `nvim_create_buf(false, true)` → `(false, false)` | assertion: same case (`'bufhidden'` is not `hide`) |
| S5 | the `TermClose` handler wipes at once instead of `wipe_later(buffer)` | assertion: `leaves its buffer for the handlers of the TermClose…`; crash: the two `:bd!`/`:bw!` cases |
| S6 | the `if shell then return shell.buffer end` removed from `start()` | assertion: `gives the same buffer and starts nothing…` |
| S7 | `cwd = settings.cwd, ` removed | assertion: `starts the shell in settings.cwd` |
| S8 | `nvim_set_current_buf(buffer)` added before `return buffer` in `start()` | assertion: `shows the buffer in no window` |
| S9 | `pcall(vim.api.nvim_del_augroup_by_name, group_name)` removed from `let_go` | assertion: `stops its shell and removes its handlers…` |
| S11 | `shell_words()` replaced by `vim.split(vim.o.shell, ' ', { trimempty = true })` | assertion: `reads a backslash before a double quote…`; crash: the quoted-word case (`'shell': '"…' is not executable`) |
| S12 | the `nvim_buf_delete` of `stop()` removed | assertion: `ends the shell's process and wipes its buffer at once`, the refused-wipe case and the `let_go` case |
| S13 | `ensure_executable(words[1] or '')` removed | assertion: the non-executable case |
| S14 | the `settings.cwd` validation removed | assertion: 3 cases |
| S15 (first push only) | the `BufWipeout` handler's `forget(buffer)` emptied | assertion: the `exit 0` cases of `a shell that ends` (2); the handler is gone since the fix round |
| S16 | `clear_env = true` added to the options | assertion: `leaves the editor's own environment to the shell` |
| L1 (W1) | `lua/aineo/layout/init.lua`: the `BufWipeout` callback `show_agent_pane_as_shell_is_wiped` emptied | assertion ×12 (Report's window not reopened, cursor cases, copies), crash ×1 |
| L2 (W2) | the `TermClose` callback `show_agent_pane_as_shell_ends` emptied | assertion: `gives the Report's window back…`, `a shell that ends and is not wiped`; crash: `shows the agent pane again as the next shell ends` |
| L5 (W5) | `shows_a_buffer_of_another_pane()` returns `is_buffer_of_another_pane(pane, role, shown)` without the `shown ~= state.buffers[PANE_BUFFERS[pane][role]]` test | assertion: `changes nothing, a buffer shown in the Report's window by hand included` |
| L6 | `focus_shows_agent_pane()` → `role == 'report' or role == 'input'` | assertion: `moves the cursor to Input and leaves the shell shown`; crash: `opens nothing for Input when the Report was wiped` |
| L7 | `had_cursor = vim.api.nvim_get_current_win() == window` → `had_cursor = false` | assertion: `lands in the Report…` for `exit 0` and `bwipeout!` |
| L8 | the `elseif cursor_was_in_shell_window then set_current_win(report)` branch → `elseif false then` | assertion ×2, crash ×1 |
| L9 | the final `forget_shell()` of the `TermClose` handler removed | assertion: `a shell that ends and is not wiped` ×3 |
| L10 | `arrangement.shell or state.buffers.shell` → `arrangement.shell` | crash ×3 (`keeps the shell handed last…`, `wraps a Report new to its window`, `open() … reopened`) |
| L11 | `PANE_LANDING.terminal = 'report'` → `'input'` | assertion: the landing case |
| L12 | the terminal's refusal text names `arrangement.changes` | assertion ×10 |
| L14 | the `if not has_window('report') then return end` of the `TermClose` handler removed | assertion ×7 (`:bd!` and `:bw!` paths) |
| L15 | `reopen_agent_pane(cursor_was_in_shell_window)` → `reopen_agent_pane(true)` | assertion ×4 (`stays in Claude's window`, another tab page) |
| L16 | `PANE_BUFFERS.terminal.input` = `'input'` → `'commits'` | assertion and crash ×14 |

Three survivors of the first run: the saved view cleared in `forget_shell()` (no editor-visible effect, since buffer numbers are never reused; the line is gone), L9 (real; it has its case), and `jobstop()` before the wipe in `stop()`, first removed as equivalent and put back in the fix round (A309): a wipe Neovim refuses, as inside an expression mapping, left the process running with nobody owning it, so it was not equivalent. S10, L3, L4 and L13 were numbered and never run; the table has the 28 first-run rows, then the fix round's.

## Fix round (the two reviews of the pull request; A308–A313, the orchestrator's assumptions)

Every fix has a case seen red first, except where said.

- **A308, a shell wiped where no handler sees it** (a user's `TermClose` handler that deletes the terminal, a `stop()` run in a `TabClosed` autocommand: autocommands that are not nested run no `BufWipeout`). `start()` and `shell_buffer()` forget a shell whose buffer is gone; the layout's `TermClose` handler takes a terminal that is gone for a wipe; `open()` forgets a gone shell and makes the agent pane the pane. Cases: the user's handler in Lua with `exit 3` and in Vimscript with `'shell'` `sh` and `exit`; `stop()` from an autocommand, followed by `open()`, `focus('report')` or `show_pane('agent')`; the shell home's `shell_buffer()` and `start()` after such a wipe. The home's `BufWipeout` handler became redundant (its mutant survived) and is gone. The extra forgets in `focus()` and `show_pane()` that the attack's measured fix had were dropped too: both call `open()` when a window is gone.
- **A309, `stop()`**: `jobstop()` is back before the wipe. Case: `stop()` in an expression mapping, where Neovim refuses the wipe (E565), ends the process, the buffer goes once it has ended, and `start()` makes exactly one new shell.
- **A310, a folder the shell cannot enter** is refused before the start, naming `settings.cwd` (`vim.uv.fs_access(dir, 'X')`). Case: a directory of mode 600.
- **A311, splitting `'shell'`**: spaces and tabs only separate words, and inside double quotes a backslash before a double quote or a backslash stands for that character. Two cases: a program named `q"sh` and one with a newline in its name.
- **A312**: when the shell ends, only the Report's window its wipe closed is opened again; a Report window the user closed stays closed, and Input's is never opened. The ID of a Report window that closed on its own is kept for this. Cases: the Report closed then `exit 3`; Input closed then `exit 0`.
- **A313**: with `'winfixbuf'` on the shell's window, nothing is said when the home's wipe, a tick later, shows the agent pane; when the agent pane still cannot show, one warning, in Neovim's own words without the source file and line. Cases: `exit 3` with the home; a terminal nothing wipes.
- **Tests review 1, 2, 3, 4**: a case for `settings` that are not a table (arrived green: the line existed; its mutant F3 is killed); the case for a later arrangement without a shell asserts that the pane is shown, so L10 is killed by assertion; the dispatch amendment's sentence is reworded; the mutant-number gaps are stated under the table.

### Mutants of the fix round, run on the final tree (assertion kills unless noted)

| # | Edit | Killed by |
|---|---|---|
| F1 | `shell_words()`: the separator test `(character == ' ' or character == '\t')` → `character:match('%s')` | `splits shell at spaces and tabs only…` |
| F2 | the backslash branch `elseif quoted and character == '\\' and …` → `elseif false and …` | `reads a backslash before a double quote…` |
| F3 | `vim.validate('settings', settings, 'table')` removed | 2 cases (`refuses settings that are not a table…`) |
| F4 | `and vim.uv.fs_access(value, 'X') == true` removed | `refuses a directory the shell cannot enter…` |
| F5 | `vim.fn.jobstop(vim.bo[stopped.buffer].channel)` removed from `stop()` | `called where Neovim refuses the wipe…` |
| F6 | `forget_wiped_shell()` removed from `start()` | `is replaced by a new, live shell at the next start()` |
| F7 | `forget_wiped_shell()` removed from `shell_buffer()` | `is no longer the shell_buffer()` and 2 more |
| F8 | `forget_wiped_shell()` removed after `take_arrangement()` in `M.open()` | the 3 `a shell stopped where no handler sees it` cases |
| F11 | the `if not vim.api.nvim_buf_is_valid(event.buf)` redirect removed from the `TermClose` handler | 2 `a shell wiped where no handler sees it` cases |
| F12 | `and state.left_closed_shell_window ~= state.windows.report` removed | `leaves the Report's window closed` |
| F13 | `open_report_window()` → `reopen_closed_windows()` in `reopen_agent_pane()` | `reopens the Report's window when its wipe closed it, and leaves Input's closed` |
| F14 | `if state.buffers.shell == buffer then` → `if true then` in `warn_unless_wiped_meanwhile()` | `tells nothing when its wipe, a tick later…` |
| F15 | `without_source_location()` returns `tostring(message)` | `tells once, without a file or a line…` |
| F16 | `warn_unless_wiped_meanwhile(event.buf, failure)` removed | same case |
| F17 | `state.left_closed_shell_window = window` removed | `leaves the Report's window closed` |

S1–S9, S11–S14 and S16, and L1, L2, L5–L12 and L14–L16 of the table above were run again on this tree, with S12's edit widened to the block that now holds the `jobstop()` and L7–L9 and L15 following the rewritten code (L7: `local note = { had_cursor = false }`; L8: `if false and has_window('report') then`; L9: the final `forget_shell()` of the `TermClose` handler removed; L15: `reopen_agent_pane(true)`); all are killed, L10 now by assertion too. S15 (the home's `BufWipeout` handler emptied) survived once the lazy forget existed; the handler is gone.

## Decisions made in the packet

- **`'shell'` is split by the home**, not handed to `:terminal`, because a terminal started with `nvim_create_buf()` and `jobstart()` is the pattern the claude home uses and the buffer must stay unshown. The split follows what Neovim does (whitespace, a double-quoted stretch keeps its spaces; measured on 0.12.5 with `:terminal`). Leading whitespace in `'shell'` is skipped; Neovim's own `:terminal` rejects it.
- **The wipe case is two paths**, not one: Neovim's own handler and `:bd!`/`:bw!` close the Report's window before any buffer event (Q1, Q4, Q5), so the layout cannot show the agent pane in place there; it opens the layout again once the command is done. A shell that ends with its window still there is answered in place from `TermClose`.
- **`watch_shell()` is separate from `watch_windows()`**, so the existing function and its docstring are untouched; `M.open()` calls both, and the group is cleared only by the first.
- **The orchestrator's rulings on the two reviews of the pull request, A308–A313** (assumptions, never the user's decisions), applied in the fix round below.
- **No `jobstart()` failure branch** in the shell home. Every way to fail is checked before it runs, and a directory the shell cannot enter did not make `jobstart()` fail (measured with a mode 000 directory), so no case can reach one.

## Spec conflicts

None. The brief's text read two ways, recorded in its dispatch amendment: mutant 5 is observed through a buffer shown by hand, not through Input's view; mutant 2 needs the home and the layout together.

## Hunks of `plugin/aineo.lua` touched

None.

## Limits recorded (the attack review's)

- A shell that exits 0 in a tab the user is not in makes Neovim visit that tab and come back (`TabLeave`/`TabEnter` and `WinEnter` fire), because the layout opens its Report window with the layout's tab current. The mode and the cursor stay where they were, and no key goes astray. Not fixed: the orchestrator ruled no fix.
- A shell that runs `trap '' HUP` dies only from Neovim's SIGKILL after four seconds, and a `nohup` child survives, as with `:terminal` and `jobstop()`.
- `'shell'` leading spaces: skipped, where `:terminal` rejects them.

## Open threads

- Terminal mode on arrival and the user's `exit` typed while in Terminal mode were probed only in headless mode (the mode after a buffer switch inside `TermClose` was `n`); T70 owns the mode and should pin it with its key.
- The Report's window refusing the agent pane (`'winfixbuf'`) as the shell ends leaves the shell remembered until the home's wipe, a tick later, shows the agent pane; the user is told only if that does not happen (fix round, A313).
- `doc/aineo.txt`, `lua/aineo/health.lua` and `plugin/aineo.lua` are untouched by the boundary; T70 documents the pane, the key and the shell home's settings.

## Commits

- PR #215, `feature/t69-terminal-pane`, head `20511a9` (10 commits), merged by rebase into `dev` as `6366eaa` (the brief's amendment at dispatch), `b0c36d6` (the shell home), `1a0a6a6` (the layout's third pane), `7594c30` (the layout's forgetting of a shell that ends, pinned), `a405bdb` (this note), `8c0efd9` (the fix round: the shell home), `b5c4a23` (the fix round: the layout), `1a82f86` (the fix round tightened), `57f458a` (the shell home's `BufWipeout` handler dropped), `c551c1a` (the fix round in this note).
- Released in v0.2.35 (PR #217, `main` `6ccd054`).
