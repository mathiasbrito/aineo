# 2026-09-26 — T20 Claude terminal mode

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t20-claude-terminal-mode` · **Pull request:** into `dev` (a small fix, orchestrate §3)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C1, C3; D10)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t20-claude-terminal-mode.md` and its brief review `brief-review-t20-claude-terminal-mode.md` (F1–F9)
- [[Review/2026-09-24 — v1 MVP readings review]], which holds MR124, the unreadable draft's hit-enter prompt

## Context

**Goal:** T20. The user asked on 2026-09-26: "also one more feature '\c' must move to the claude window in insert mode, cursor on the prompt", and chose "Small fix, right after T14 (Recommended)". `\c` now leaves the user typing to Claude: Terminal mode in Claude's window, unless Claude's session has ended. It rests on C1, the entry point; no spec row changes.

## What was done

- **`plugin/aineo.lua`:** a new local `focus_claude()`, which is now `ACTIONS.claude`. It calls `focus('claude')`, then reads `require('aineo.claude').session_status()` and runs `vim.cmd.startinsert()` unless the status is `'exited'`. `:startinsert` takes effect when the callback or command ends, in the window that is current then (the brief review's F2), which is Claude's. `focus()`'s docstring now says it leaves the mode as it is and points at `focus_claude()`. Nothing in the autostart changed.
- **`tests/test_entry_claude_mode.lua`:** a new file of 10 cases. Every case types its keys with `child.type_keys()`, which leaves Terminal and Insert mode pending, and reads `nvim_get_mode().mode` in the child right after (F3).
- **`doc/aineo.txt`:** the introduction's sentence on the prefix keys now says `\c` moves in Terminal mode. `*:Aineo-claude*` says it enters Terminal mode, reaching Claude Code's prompt or its dialog, and stays in Normal mode once Claude Code has exited. `<Plug>(aineo-claude)` and `\c` point to it and are unchanged.

## Unit list and red/green

The slicing, stated before the first test:

1. CT1: `\c` from the Report or Input, the layout open, enters Terminal mode in Claude's window.
2. CT1: the same from the file column.
3. CT1: `\c` with Claude's window closed reopens it in Terminal mode.
4. CT1: `\c` from another tab moves to the layout's tab in Terminal mode.
5. CT1: `\c` while Claude Code shows a dialog as it starts (`'starting'`) enters Terminal mode.
6. CT1: `\c` after Claude exited and its terminal was wiped starts a new session (`'exited'` before the focus, `'starting'` after it) and enters Terminal mode.
7. CT2: `\c` on an ended session moves to Claude's window and stays in Normal mode (`'nt'`).
8. CT4: `\r` and `\i` move to their window in Normal mode.

**Seen red — 3 cases, each failing on the intended assertion:**

| Case | Red |
|---|---|
| `\c` › `enters Terminal mode in Claude's window, from the right column` › `after` + `Aineo report` | on `dev`'s code: the current window `terminal` as expected, then `Left: "nt"`, `Right: "t"` |
| … + `Aineo input` | the same |
| `\c` › `stays in Normal mode in Claude's window once Claude's session has ended` | with unit 1's code, an unconditional `vim.cmd.startinsert()`: `Left: "t"`, `Right: "nt"` |

The two unit-1 cases were seen red before they waited for a `'ready'` session; that wait was added after M2 showed every `ready` case still ran on a `'starting'` one (see *Decisions*). On the final file, M1 — `dev`'s behaviour — turns both red on the same assertion.

**Arrived green — 7 cases.** Each is killed by a mutant that was run, and every kill was an assertion failure (`Failed expectation for equality`, `Left: "nt"` or `Left: "i"`):

- **Units 2 to 6, 5 cases:** the file column, Claude's closed window, another tab, the dialog at start, and the new session after a wipe.
  - *Why green:* spent by unit 1's code, which entered Terminal mode after every `focus('claude')`.
  - *Killer:* M1 kills all five. M2 kills the dialog and the wipe; M2b kills the file column, the closed window and the other tab; M3 kills the wipe.
- **Unit 8, 2 cases:** `\r and \i` › `move to their window in Normal mode` + `r` / `i`.
  - *Why green:* an invariant; neither action changes.
  - *Killer:* M5 (`r`), M6 (`i`), M7 (both).

Total: 3 red + 7 green = 10. Every case appears once.

## Mutants

Each mutant is a literal edit to `plugin/aineo.lua` at the shipped head. Each was applied from a pristine copy and run alone, then restored and compared with the copy, against a copy of `tests/test_entry_claude_mode.lua` narrowed to the set it targets: `.tests/t20-c.lua` (the `\c` set, 8 cases) or `.tests/t20-ri.lua` (the `\r and \i` set, 2 cases). The driver was `/tmp/t20-mutate.py`. The whole table was re-run after the last edit to the test file, and again at the rebased head.

| Id | Literal edit | Run against | Result |
|---|---|---|---|
| M1 | delete the line `    vim.cmd.startinsert()` in `focus_claude()` (`dev`'s behaviour) | `\c`, 8 cases | killed by 7 assertions; the 8th, CT2, is not its target |
| M2 | `session_status() ~= 'exited' then` → `session_status() == 'ready' then` | the same | killed by 2 assertions: the dialog at start, the wipe |
| M2b | `session_status() ~= 'exited' then` → `session_status() == 'starting' then` | the same | killed by 5 assertions: right column ×2, file column, closed window, another tab |
| M3 | `focus('claude')` moved after the `if … end`, so the session is read before the focus | the same | killed by 1 assertion: the wipe (F1) |
| M4 | `session_status() ~= 'exited' then` → `session_status() or true then` | the same | killed by 1 assertion: CT2 (`Left: "t"`) |
| M5 | `vim.cmd.startinsert()` added after `focus('report')` in `ACTIONS.report` | `\r and \i`, 2 cases | killed by 1 assertion (`r`, `Left: "i"`) |
| M6 | `vim.cmd.startinsert()` added after `focus('input')` in `ACTIONS.input` | the same | killed by 1 assertion (`i`, `Left: "i"`) |
| M7 | `vim.cmd.startinsert()` added as `focus()`'s last line | the same | killed by 2 assertions |

No mutant survived.

## Decisions & reasoning

1. **The seam is a new local `focus_claude()`, not a flag on `focus()`.** A flag would select between two behaviours (clean-code §2). `focus()` still serves all three roles and leaves the mode alone.
2. **The session is read after `focus('claude')`** (the brief's CT2, the brief review's F1). A focus that reopens the layout after the ended session's terminal was wiped starts a new session, and the read must see it. M3 is the mutant that reads it first; the wipe case kills it.
3. **The `ready` cases wait for `'ready'` before `\c`.** M2 (`== 'ready'`) at first killed all seven CT1 cases, which showed that the fake had not become ready when `\c` was typed right after `:Aineo open`: no case ran on a ready session. With the wait, M2b (`== 'starting'`) is killed by the ready cases and M2 by the starting ones.
4. **The restarted session in the wipe case is a `trust` fake**, which stays `'starting'`, so the case's `'starting'` read does not race a `ready` fake becoming ready.
5. **The wipe is `:bwipeout!`**, as `tests/test_entry.lua`'s wipe cases do, rather than a key typed in Terminal mode on the exited terminal: both leave the terminal buffer gone and Claude's window closed, which is the state `\c` then meets.
6. **No test for `<Plug>(aineo-claude)` or `:Aineo claude`:** CT3 is an invariant, a reading. `\c` maps to `<Plug>(aineo-claude)`, which runs `ACTIONS.claude`, as `:Aineo claude` does.

## Verification

The branch was cut from `dev` at `3116949`. T10 (PR #52) merged into `dev` while this packet was in progress, and the branch was rebased onto `d30ff4d` without a conflict. T10 changed `doc/aineo.txt` outside this packet's lines, and neither `plugin/aineo.lua` nor `tests/helpers/`.

Measured on the host, one run at a time, at load averages between 20 and 136:

- **At the rebased head, 0.12.5, `make test`:** 983 cases, 31 groups, `Fails (0)`, exit 0: `dev`'s 973 and this file's 10.
- **At the rebased head, 0.11.6, `make test`** (the brief's literal `env PATH=… make test`): 983 cases, `Fails (0)`, exit 0.
- **Before the rebase, on `3116949`:** 900 cases on each version (`dev`'s 890 and this file's 10). 0.12.5: `Fails (0)`. 0.11.6: `Fails (1)`, `tests/test_health.lua` › `Claude Code` › `leaves the editor free to wait when Ctrl-C ends a check of a command that writes without end` (`tests/test_health.lua:336`, `Left: false`), a file the brief names as failing spuriously under load. Alone, at a load of 52: 78 cases, `Fails (0)`.
- **`make lint`:** StyLua and selene clean (0 errors, 0 warnings).
- **Mutants:** the table above, run on 0.12.5 only, re-run at the rebased head with the same results.
- The existing cases of `tests/test_entry*.lua`, `tests/test_plugin.lua` and `tests/test_health.lua` are unchanged and green (CT4). `tests/test_doc.lua` is green on the merged help, T10's lines included.

## Readings for the MVP review

For the user to confirm:
- **CT3 — one action, three ways in.** `\c`, `<Plug>(aineo-claude)` and `:Aineo claude` all run `ACTIONS.claude`, so all three enter Terminal mode. The user asked for `\c`; the other two follow because they are one action.
- **CT2's bound (the brief review's F6).** `\c` reads the session as the editor knows it when the key runs. A `\c` typed while the editor is busy as Claude Code exits is handled before Neovim sees the exit: it enters Terminal mode, and the next key closes the terminal, as it does today when Claude Code exits under the user's typing. The brief review measured it 6 of 6 times on each version; `jobwait()` does not help. Not tested: it is intrinsic.
- **An unreadable draft (the brief review's F7, with MR124).** When `\c` opens the layout and the draft cannot be read, its warning holds a hit-enter prompt. The key that answers it, other than Enter, Space or CTRL-C, now reaches Claude Code instead of running as a Normal-mode command. A fix would reach the draft home, which this small fix may not touch.

## Task lines

The wave holds its marks (rule 6). The line T20 would take:

- [X] T20 — `\c` (with `<Plug>(aineo-claude)` and `:Aineo claude`, one action) moves to Claude's window and enters Terminal mode there, the cursor in Claude's prompt or its dialog; when Claude's session has ended, read after the move, it stays in Normal mode. A small fix.

## Limits

- **CT2's race (F6):** above, in *Readings*.
- **The draft's hit-enter prompt (F7):** above, in *Readings*.
- **Focus reporting (the brief review's F8).** The recorded Claude Code enables it (`ESC[?1004h`), so entering Terminal mode sends Claude `ESC[I` and leaving it sends `ESC[O`. A test that reads what the fake received after `\c` sees them.

## Open threads

- **The shared help's merge check (rule 2).** T10's branch `bugfix/t10-report-links` had merged and been deleted before the check, so the brief's `git merge-tree` against it could not run. The rebase onto `d30ff4d`, which holds T10's help, took its place: no conflict, and `tests/test_doc.lua` green in both whole runs at the rebased head.
- **Learning candidate for the knowledge pass:** in a child Neovim, a `ready` fake is still `'starting'` right after `:Aineo open`. A case meant for a ready session waits for `'ready'` (decision 3); otherwise a mutant on the status survives unseen.

## Commits

*Recorded after the merge* — hashes change on rebase.
