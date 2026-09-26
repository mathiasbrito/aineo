# 2026-09-26 — T20 Claude terminal mode

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t20-claude-terminal-mode` · **Pull request:** #58 into `dev` (a small fix, orchestrate §3)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C1, C3; D10)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t20-claude-terminal-mode.md` and its brief review `brief-review-t20-claude-terminal-mode.md` (F1–F11)
- [[Review/2026-09-24 — v1 MVP readings review]], which holds MR124, the unreadable draft's hit-enter prompt
- The fix round's inputs: the guarantee review (findings G1–G4, its mutants G1, G2 and G5) and the records review (findings R1–R8) of pull request #58, and the orchestrator's decisions 1–11 for the round

## Context

**Goal:** T20. The user asked on 2026-09-26: "also one more feature '\c' must move to the claude window in insert mode, cursor on the prompt", and chose "Small fix, right after T14 (Recommended)". `\c` now leaves the user typing to Claude: Terminal mode in Claude's window, unless Claude's session has ended. It rests on C1, the entry point; no spec row changes.

## What was done

- **`plugin/aineo.lua`:** a new local `focus_claude()`, which is now `ACTIONS.claude`. It calls `focus('claude')`, then runs `vim.cmd.startinsert()` when `can_type_to_claude()` holds: the current buffer is the session's terminal (`claude_terminal`), and `require('aineo.claude').session_status()` is not `'exited'`. The buffer check came in the fix round (G2).
  - `:startinsert` takes effect when the outermost mapping or command ends, in the window that is current then (the brief review's F2). That is Claude's window, unless a caller moves the cursor on (G3).
  - `focus()`'s docstring now says it enters no mode itself, and that Terminal mode ends as the cursor leaves Claude's window (R4).
  - Nothing in the autostart changed.
- **`tests/test_entry_claude_mode.lua`:** a new file of 12 cases, 10 in the packet and 2 in the fix round. Every case types its keys with `child.type_keys()`, which leaves Terminal and Insert mode pending, and reads `nvim_get_mode().mode` in the child right after (F3).
- **`doc/aineo.txt`:**
  - The introduction's sentence on the prefix keys now says `\c` moves in Terminal mode, unless Claude Code has exited. The exception came in the fix round (R6).
  - `*:Aineo-claude*` says it enters Terminal mode, reaching Claude Code's prompt or its dialog, and stays in Normal mode once Claude Code has exited.
  - `<Plug>(aineo-claude)` and `\c` point to it and are unchanged.

## Unit list and red/green

The slicing, stated before the first test:

1. CT1: `\c` from the Report or Input, the layout open, enters Terminal mode in Claude's window.
2. CT1: the same from the file column.
3. CT1: `\c` with Claude's window closed reopens it in Terminal mode.
4. CT1: `\c` from another tab moves to the layout's tab in Terminal mode.
5. CT1: `\c` while Claude Code shows a dialog as it starts (`'starting'`) enters Terminal mode.
6. CT1: `\c` after Claude exited and its terminal was wiped with `:bwipeout!` starts a new session (`'exited'` before the focus, `'starting'` after it) and enters Terminal mode.
7. CT2: `\c` on an ended session moves to Claude's window and stays in Normal mode (`'nt'`).
8. CT4: `\r` and `\i` move to their window in Normal mode.

**Seen red — 3 cases, each failing on the intended assertion:**

| Case | Red |
|---|---|
| `\c` › `enters Terminal mode in Claude's window, from the right column` › `after` + `Aineo report` | on `dev`'s code: the current window `terminal` as expected, then `Left: "nt"`, `Right: "t"` |
| … + `Aineo input` | the same |
| `\c` › `stays in Normal mode in Claude's window once Claude's session has ended` | with unit 1's code, an unconditional `vim.cmd.startinsert()`: `Left: "t"`, `Right: "nt"` |

The two unit-1 cases were seen red before they waited for a `'ready'` session. That wait was added after M2 showed that every `ready` case still ran on a `'starting'` one (see *Decisions*). On the final file, M1 (`dev`'s behaviour) turns both red on the same assertion, and so does `dev`'s literal `plugin/aineo.lua` (the records review).

**Arrived green — 7 cases.** Each is killed by a mutant that was run, and every kill was an assertion failure (`Failed expectation for equality`, `Left: "nt"` or `Left: "i"`):

- **Units 2 to 6, 5 cases:** the file column, Claude's closed window, another tab, the dialog at start, and the new session after a `:bwipeout!`.
  - *Why green:* spent by unit 1's code, which entered Terminal mode after every `focus('claude')`.
  - *Killer:* M1 kills all five. M2 kills the dialog and the wipe. M2b kills the file column, the closed window and the other tab. M3b kills the wipe.
- **Unit 8, 2 cases:** `\r and \i` › `move to their window in Normal mode` + `r` / `i`.
  - *Why green:* an invariant; neither action changes.
  - *Killer:* M5 (`r`), M6 (`i`), M7 (both).

Total: 3 red + 7 green = 10. Every case appears once.

**Fix round — 2 cases, each seen red on `f187132` by assertion, on 0.12.5 and 0.11.6.** They are the guarantee review's probes P4 and P4b (G2), adopted with its measured guard:

| Case | Red on `f187132`, both versions |
|---|---|
| `\c` › `leaves a buffer other than Claude's terminal, shown in Claude's window, in Normal mode` | `Left: "i"`, `Right: "n"` |
| `\c` › `leaves a terminal of the user's own, shown in Claude's window, in Normal mode` | `Left: "t"`, `Right: "nt"` |

Total: 10 + 2 = 12. Every case appears once.

## Mutants

A driver applied each edit to `plugin/aineo.lua` from a pristine copy, as one literal replacement that it checked was unique. It ran `make test_file` on the target, then restored the file and checked it was byte-identical. Mutants ran one at a time, on 0.12.5.

### The packet's table, at `f187132`

Each mutant ran against a copy of `tests/test_entry_claude_mode.lua` narrowed to the set it targets: the `\c` set (8 cases) or the `\r and \i` set (2 cases). The table was re-run after the last edit to the test file, and again at the rebased head. It holds eight mutants, M2b among them. Commit `f187132`'s message calls them "M1-M7", which is wrong (R7).

| Id | Literal edit | Run against | Result |
|---|---|---|---|
| M1 | delete the line `    vim.cmd.startinsert()` in `focus_claude()` (`dev`'s behaviour) | `\c`, 8 cases | killed by 7 assertions; the 8th, CT2, is not its target |
| M2 | `session_status() ~= 'exited' then` → `session_status() == 'ready' then` | the same | killed by 2 assertions: the dialog at start, the wipe |
| M2b | `session_status() ~= 'exited' then` → `session_status() == 'starting' then` | the same | killed by 5 assertions: right column ×2, file column, closed window, another tab |
| M3 | `focus('claude')` moved after the `if … end`, so the session is read before the focus | the same | killed by 1 assertion: the wipe (F1) |
| M4 | `session_status() ~= 'exited' then` → `session_status() or true then` | the same | killed by 1 assertion: CT2 (`Left: "t"`) |
| M5 | `vim.cmd.startinsert()` added after `focus('report')` in `ACTIONS.report` | `\r and \i`, 2 cases | killed by 1 assertion (`r`, `Left: "i"`) |
| M6 | `vim.cmd.startinsert()` added after `focus('input')` in `ACTIONS.input` | the same | killed by 1 assertion (`i`, `Left: "i"`) |
| M7 | `vim.cmd.startinsert()` added as `focus()`'s last line | the same | on the narrowed copy, killed by 2 assertions. On the whole file (the guarantee review) it also fails the right-column `Aineo input` case by assertion, and 3 cases crash during setup with `E21`. |

No mutant survived.

### The fix round's table, at `a2bd21a`

Each mutant ran against the whole of `tests/test_entry_claude_mode.lua` (12 cases), the test file the pull request adds (the small-fix rule). Only an assertion failure counts as a kill; crashes are listed beside it.

| Id | Literal edit | Result |
|---|---|---|
| M1 | delete the line `    vim.cmd.startinsert()` in `focus_claude()` (`dev`'s behaviour) | killed by 7 assertions: every CT1 case |
| M2 | `session_status() ~= 'exited'` → `session_status() == 'ready'` | killed by 2 assertions: the dialog at start, the wipe |
| M2b | `session_status() ~= 'exited'` → `session_status() == 'starting'` | killed by 5 assertions: right column ×2, file column, closed window, another tab |
| M3 | `focus('claude')` moved after the `if … end` | killed by 7 assertions: every CT1 case, since the buffer is then read before the move |
| M3b | `local status = require('aineo.claude').session_status()` added before `focus('claude')`, and the condition becomes `vim.api.nvim_get_current_buf() == claude_terminal and status ~= 'exited'`: only the session is read before the move (the guarantee's G5) | killed by 1 assertion: the wipe (F1) |
| M4 | `session_status() ~= 'exited'` → `session_status() ~= 'never'` | killed by 1 assertion: CT2 (`Left: "t"`) |
| M5 | `vim.cmd.startinsert()` added after `focus('report')` in `ACTIONS.report` | killed by 1 assertion (`r`, `Left: "i"`); 5 cases crash during setup with `E21` |
| M6 | `vim.cmd.startinsert()` added after `focus('input')` in `ACTIONS.input` | killed by 2 assertions: `i`, and the right-column `Aineo input` case |
| M7 | `vim.cmd.startinsert()` added as `focus()`'s last line | killed by 3 assertions: `r`, `i`, and the right-column `Aineo input` case; 5 cases crash with `E21` |
| M8 | `can_type_to_claude()`'s body → `return require('aineo.claude').session_status() ~= 'exited'` (the buffer check removed; the orchestrator's decision 1 for the round) | killed by 2 assertions: the two fix-round cases |
| M9 | `local was_open = claude_terminal ~= nil and #vim.fn.win_findbuf(claude_terminal) > 0` added before `focus('claude')`, and the condition becomes `was_open and can_type_to_claude()` (the plan's fifth verification mutant, the guarantee's G2) | killed by 2 assertions: the closed window, the wipe |

No mutant survived.

## Decisions & reasoning

1. **The seam is a new local `focus_claude()`, not a flag on `focus()`.** A flag would select between two behaviours (clean-code §2). `focus()` still serves all three roles and enters no mode itself.
2. **The session is read after `focus('claude')`** (the brief's CT2, the brief review's F1). A focus that reopens the layout after the ended session's terminal was wiped starts a new session, and the read must see it. M3b is the mutant that reads it first; the wipe case kills it.
3. **The `ready` cases wait for `'ready'` before `\c`.** At first, M2 (`== 'ready'`) killed all seven CT1 cases. That showed the fake had not yet become ready when `\c` was typed right after `:Aineo open`, so no case ran on a ready session. With the wait, the ready cases kill M2b (`== 'starting'`) and the starting cases kill M2. The guarantee review measured that the wait hides no race: without it the file is green, and M2b survives.
4. **The restarted session in the wipe case is a `trust` fake.** It stays `'starting'`, so the case's `'starting'` read does not race a `ready` fake becoming ready.
5. **The wipe is `:bwipeout!`**, as `tests/test_entry.lua`'s wipe cases do, and the case now says so in its name.
   - The packet's version of this decision said a key typed in Terminal mode on the exited terminal reaches the same state. That was false (G1).
   - From the layout's own tab, such a key leaves Claude's window open on an empty buffer. The layout's `redirect()` then raises `Invalid buffer id` (`lua/aineo/layout/init.lua:327`) and opens an extra window, and the next `\c` starts no session.
   - From another tab the window closes, and `\c` works. See *Limits*.
6. **No test for `<Plug>(aineo-claude)` or `:Aineo claude`:** CT3 is an invariant, a reading. `\c` maps to `<Plug>(aineo-claude)`, which runs `ACTIONS.claude`, as `:Aineo claude` does.
7. **Terminal mode only in Claude's own terminal** (fix round, G2; the orchestrator's decision 1).
   - The layout knows Claude's window by its id, so a scratch buffer or a terminal of the user's own shown there took the keys meant for Claude.
   - The guard is the guarantee review's, measured there and adopted red-first.
   - It compares the current buffer with the kept `claude_terminal`, not with `current_claude_terminal()` as decision 1 named it. That function starts a session when the terminal is gone, which a question must not do, and after `focus('claude')` the two name the same terminal.

## Verification

The branch was cut from `dev` at `3116949`. T10 (PR #52) merged into `dev` while this packet was in progress, and the branch was rebased onto `d30ff4d` without a conflict. T10 changed `doc/aineo.txt` outside this packet's lines, and neither `plugin/aineo.lua` nor `tests/helpers/`.

Measured on the host, one run at a time. Each whole-run log starts with `nvim --version`'s first line, under the same `PATH` as the run.

- **Fix round, at `a2bd21a` (the code the branch ships), load averages up to 156:**
  - **0.12.5, `make test`** (`NVIM v0.12.5`): 985 cases, 32 groups, `Fails (0)`, exit 0: `dev`'s 973 and this file's 12.
  - **0.11.6** (`NVIM v0.11.6`, the brief's literal `env PATH=… make test`): 985 cases, 32 groups, `Fails (0)`, exit 0.
  - **`make lint`:** StyLua and selene clean (0 errors, 0 warnings).
  - The new file alone, `f187132`'s code with the two fix-round cases: `Fails (2)` on each version, as *Unit list* shows.
- **Packet, at the rebased head `af5a887`:** 983 cases, 32 groups, `Fails (0)`, on each version. The packet's version of this note said 31 groups, a count carried from the run before the rebase (R2); T10's `tests/test_report_links.lua` is the 32nd. The packet's two logs named no Neovim version (the records review's U1).
- **Packet, before the rebase, on `3116949`:** 900 cases, 31 groups, on each version. 0.12.5: `Fails (0)`. 0.11.6: `Fails (1)`, `tests/test_health.lua` › `Claude Code` › `leaves the editor free to wait when Ctrl-C ends a check of a command that writes without end` (`tests/test_health.lua:336`, `Left: false`), a file the brief names as failing spuriously under load. Alone, at a load of 52: 78 cases, `Fails (0)`.
- **Mutants:** the two tables above, on 0.12.5.
- The existing cases of `tests/test_entry*.lua`, `tests/test_plugin.lua` and `tests/test_health.lua` are unchanged and green (CT4). `tests/test_doc.lua` is green on the merged help, T10's lines included.

## Readings for the MVP review

For the user to confirm — numbered MR135–MR137 in [[Review/2026-09-24 — v1 MVP readings review]] by the knowledge pass (MR137 is the fix round's guard: `\c` stays in Normal mode when Claude's window shows another buffer), with the limits MR138–MR140:
- **CT3 — one action, three ways in (MR135).** `\c`, `<Plug>(aineo-claude)` and `:Aineo claude` all run `ACTIONS.claude`, so all three enter Terminal mode. The user asked for `\c`; the other two follow because they are one action.
  - **From a user's callback** (G3, R5; MR136): Terminal mode starts when the outermost mapping or command ends, in the window current then.
  - So a user mapping that runs `:Aineo claude` and then `wincmd p` leaves the user in Insert mode in Input. Measured by the guarantee's P3 and the records review's probe B, on both versions.
  - The help's `*:Aineo-claude*` describes the command as typed, which is always outermost, so the help is not changed.
- **CT2's bound (the brief review's F6, widened by G4; MR138).** `\c` reads the session as the editor knows it when the key runs.
  - **A busy editor:** a `\c` typed while the editor is busy as Claude Code exits is handled before Neovim sees the exit, so it enters Terminal mode. The brief review measured it 6 of 6 times on each version, and the guarantee review 1 of 1; `jobwait()` does not help.
  - **Or Claude Code exits after `\c` entered Terminal mode — at its start, too:** the next key erases the exit message, and then meets the layout's error (G1). Measured by the guarantee's P9b, on both versions:
    - the first `\c` opens the layout on a session that exits 200 ms later, as a Claude Code failing at startup would;
    - the mode is `t` at the key, and still `t` after `'exited'`;
    - `x` then wipes the terminal and its exit message.
  - **This is a change T20 makes:** on `dev` the same key gives only `E21`, and the terminal and its exit stay on screen.
  - Not tested: the race is intrinsic, and what follows the wipe is the layout's (see *Limits*).
- **An unreadable draft (the brief review's F7, with MR124; MR139).** When `\c` opens the layout and the draft cannot be read, its warning holds a hit-enter prompt.
  - The key that answers it, other than Enter, Space or CTRL-C, now reaches Claude Code instead of running as a Normal-mode command.
  - A fix would reach the draft home, which this small fix may not touch.

## Task lines

The wave holds its marks (rule 6). The line T20 would take:

- [X] T20 — `\c` moves to Claude's window in Terminal mode, the cursor in Claude's prompt; when Claude's session has ended, it stays in Normal mode (C1) — a small fix (the user, 2026-09-26). `<Plug>(aineo-claude)` and `:Aineo claude` run the same action (CT3, a reading for the MVP review).

## Limits

- **CT2's bound (F6, G4):** above, in *Readings*.
- **A key that wipes the ended terminal from the layout's own tab** (G1). The defect is older than T20; T20 makes the path more common. Measured by the guarantee review, on both versions:
  - Claude's window stays open on an empty buffer.
  - The layout's `redirect()` raises `Invalid buffer id` (`lua/aineo/layout/init.lua:327`, where `nvim_win_set_buf()` is given the wiped role buffer) and opens an extra window.
  - The next `\c` moves to that empty buffer, in Normal mode, and starts no session.
  - From another tab the window closes, and `\c` starts a new session in Terminal mode.
  - On `dev`, `\c` then `i` on the exited terminal gives the same result. T20 makes Terminal mode in Claude's window the usual state, so the path is now the common one.
  - The fix belongs in the layout home, outside this small fix.
- **The draft's hit-enter prompt (F7):** above, in *Readings*.
- **Focus reporting (the brief review's F8; MR140).** The recorded Claude Code enables it (`ESC[?1004h`), so entering Terminal mode sends Claude `ESC[I` and leaving it sends `ESC[O`. A test that reads what the fake received after `\c` sees them.

## Open threads

- **The layout's `redirect()` on a wiped role buffer** (G1, *Limits*). This is a follow-up; the orchestrator takes it to the user.
  - The help's paragraph after `*:Aineo-claude*` ("…or once the terminal was wiped") is outside this packet's lines, and is left for that follow-up. A key-wipe from the layout's own tab defeats that promise today.
- **The shared help's merge check (rule 2).** T10's branch `bugfix/t10-report-links` had merged and been deleted before the check, so the brief's merge check against it could not run. The rebase onto `d30ff4d`, which holds T10's help, took its place. There was no conflict, and `tests/test_doc.lua` was green in the whole runs at the rebased head.
- **Learning candidate for the knowledge pass:** in a child Neovim, a `ready` fake is still `'starting'` right after `:Aineo open`. A case meant for a ready session waits for `'ready'` (decision 3); otherwise a mutant on the status survives unseen.

## Commits

Merged by rebase into `dev` on 2026-09-26, PR #58. The knowledge pass maps each commit of the branch to its hash on `dev`:

| on the branch | on `dev` | subject |
|---|---|---|
| `af5a887` | `5b625a5` | Enter Terminal mode in Claude's window on \c |
| `f187132` | `e1f182d` | Record T20's session: Claude terminal mode, red/green, mutants |
| `a2bd21a` | `309a532` | Enter Terminal mode on \c only in Claude's own terminal |
| `617e4a5` | `ac42fd3` | Correct T20's session note after its guarantee and records reviews |

Released in `v0.2.5` (PR #63, `main` at `0d4c8b4`).
