# 2026-10-11 — T46 Claude sessions key

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`, on Sonnet, A123)
**Branch:** `feature/t46-sessions` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D49 (and its notes of 2026-10-11: R1 (b), R2 (a), R3 (a)), D51, **D52** (added here), C1, C3, T46, **T47** (added here)
- [[Implementation/Waves/00011-names-and-sessions/plan]] (*Round 3*, *The orchestrator's rulings*, *Verification mutants* › T46) and [[Implementation/Waves/00011-names-and-sessions/brief-t46-sessions]] with its *Amendment — 2026-10-11, at dispatch: built now, M7 and M8 measured*. **A114** is superseded by the user's "Build it now"; **A119** (the integrator), **A120** (a claim refuses as Send does), **A121** (the cursor), **A123** (Sonnet), **A129** (the amendment is the first commit), **A130** (`--cwd <folder> --all` always), **A131** (the background service is named in the help, not guarded) and **A132** (no `\pc` alias) are the orchestrator's assumptions, never the user's decisions.
- Rests on: [[Sessions/2026-10-11 — T45 Open a named file]] (the dispatch-amendment form), the session notes of T7, T20, T35 and T39 (Send's refusals, the claims, the hook follow), and the fixtures `tests/fixtures/claude/startup-2.1.281.bytes` and `draft-2.1.281.bytes`.

## What was done

**The Claude home (C3), `lua/aineo/claude/`:**
- `prompt.lua` (new): `shows_text(window)` — the prompt shows text unless the input box is one line and the terminal's cursor sits right after the prompt glyph on it. The window must be in Terminal mode, where Neovim 0.12.5 keeps the window's cursor on the terminal's (measured on the fake's screens: row 20, byte 5 on the empty prompt; row 20, byte 13 at the end of the recorded draft). A screen with no input box reads as text; a draft whose cursor was moved back to its start reads as empty (R2 (a)'s one miss, pinned).
- `readiness.lua`: the input box's rule is `input_box(lines)` now, exported with `shown_screen(buffer)`, so the text check reads the box as the readiness check does; the watch is unchanged (declared widening).
- `agents.lua` (new): `list_sessions(command, folder, on_done)` runs `claude.cmd` + `agents --json --cwd <folder> --all` in a process group of its own, asynchronously, stopped at 5 s, past 1 MiB of output and when Neovim quits; every failure is told in its own words (cannot run, exit code with the first line of stderr, a signal — `vim.system` reports a killed process as code 0, so the signal is read on its own —, not JSON, not a list). An entry is kept when it carries a `sessionId` string; a field of the wrong type is left out. `standing()` (`own`, `elsewhere` for an entry with a `pid`, `switchable`), `name()` and `row()` build the list's rows and marks.
- `init.lua`: exports `list_sessions`, `session_standing`, `session_row`, `listed_session_name`, `session_directory` and `prompt_shows_text` (declared widening; no existing function touched).

**The composition root, `plugin/aineo.lua`:** `sessions` in `SUBCOMMANDS` (after `claude-numbers`), `ACTIONS` and `PREFIX_KEYS` (`cs`), so `:Aineo sessions`, `<Plug>(aineo-sessions)` and `\cs` do one thing. `list_sessions()` refuses while Claude Code is not ready or a claim of another session holds (Send's words, `no session list` for `nothing sent`), reads the list, and `offer_sessions()` shows it in `vim.ui.select`; `pick_listed_session()` refuses the own session and a session running elsewhere, and `switch_to_session()` re-checks readiness and claim, moves to Claude's window (`focus_claude()`), waits for Terminal mode, reads the cursor, and either writes `/resume <id>` and Enter in one write or, on text, puts the window and the mode back (`return_to()`) and says to clear the prompt. The `TermEnter` handler a switch waits for is removed when Terminal mode is not entered within a second.

**The health check:** `\cs` in the prefix-mappings list. **`doc/aineo.txt`:** the introduction, *:Aineo-sessions*, *<Plug>(aineo-sessions)*, *aineo-\cs*, the passage on keys that wait for `'timeoutlen'`, and a *The session list* subsection of *aineo-limits* (A131: the background service, the unlisted own session, the unmeasured single write; a declared widening).

**The fake `claude`:** `agents --json` answers before the terminal is put in raw mode — it records its arguments (without an `ended` line), prints the array `AINEO_FAKE_CLAUDE_AGENTS` names (`[]` when unset) and exits 0, or exits with `AINEO_FAKE_CLAUDE_AGENTS_EXIT` and prints nothing. It can print both of M7's entry shapes (a background session with neither `pid` nor `status`; an interactive one with both).

**The user's second request, via the orchestrator (D52, T47, A132):** the changes pane's key is `\g`, in place of `\pc`; `\pa`, `:Aineo pane changes` and `<Plug>(aineo-pane-changes)` do not change, and no `\pc` alias is kept. `PREFIX_KEYS`, the health list, the help, and every suite that typed or pinned `\pc` follow. D52 and T47 are rows in the v1 plan note, with a dated note on D18, C12 and T24 (the rows that define the key); the orchestrator asked for these rows, the packet's brief did not allow the plan note.

**The brief:** the *Amendment — 2026-10-11, at dispatch* (A129) is the first commit, with M7's shape (no user's path, id or name), M8, A129–A131, the moved facts and the widenings, which later commits extended (section 11 of the help; five suites that typed `\c`).

## Decisions and departures from the brief

- **One write, `/resume <id>` then Enter** (`/resume <id>\r`), because the fake switches on exactly that chunk (as D37's suites type it). Whether the real Claude Code takes the text and Enter of one write as a command is **not measured**; the help's limits say so. Rejected: a bracketed paste (Send's form), which the fake does not take as a command.
- **No options argument** for the 5 s bound and the 1 MiB limit (no caller overrides them); the tests run the defaults. The health check bounds `--version` at 3 s; the list is given 5 s because a first `claude agents` may start Claude Code's service (A131, unmeasured).
- **No guard against pressing `\cs` again while a list is read**: each run is bounded. A reviewer may ask for one.
- **A refusal puts the cursor back** (A121, behaviour 8), not "leaves the user in Claude's window" as the plan's round-2 note of O4 had it; the brief and A121 win. The Insert-mode restore found broken by its mutant: `startinsert` asked for while Terminal mode ends is lost, so it is asked for on `ModeChanged` out of `t`.
- **The text check lives in the Claude home and takes a window**, not a pure function over lines and a cursor: the cursor is the window's, and the cases replay Claude Code's recorded bytes into a terminal in a child Neovim.
- **`run` is forward-declared in `plugin/aineo.lua`** so the list's callbacks report an error once without moving the error framing above the actions.
- **Widened beyond the brief, all declared in the amendment:** `readiness.lua`, `claude/init.lua`, `tests/helpers/entry.lua`, `doc/aineo.txt` section 11, five suites that typed `\c` (`test_entry_claude_exit`, `_mode`, `_resume`, `_numbers`, `test_entry_panes`), and, for D52, `tests/test_entry_changes.lua`, `test_entry_session_switch.lua`, `test_entry_session_handover.lua`, `test_entry_send_selection.lua`, `test_doc.lua` and the plan note.
- **Fact checked:** "a `claude.cmd` that holds `--add-dir` or `--mcp-config` makes `claude agents --json` fail with `unknown option`" — the brief cites `agent-view.md`; I read that page (2026-10-11) and it says `--add-dir` and `--mcp-config` must come after `agents`.
- **Spec conflicts:** none found.

## Unit list (stated before the first test)

1. The prompt shows text, by the cursor (the measurement first, on the fake's recorded screens).
2. The list: the fake's `agents --json`, `list_sessions()` with its argv, entries, failures and bounds.
3. A listed session's standing and row.
4. The session's directory.
5. `:Aineo sessions`, `<Plug>`, `\cs`: the rows, the folder asked for.
6. A pick: this terminal's row, a row running elsewhere, a switch, the text refusal.
7. The refusals before the list (not started, starting, exited, a claim), a failed list, an empty list, a menu that raises.
8. The same checks at the pick, Terminal mode already entered, Terminal mode not entered, a pick that came in Insert mode.
9. The pins (subcommands, mappings, health), the help.
10. D52: the changes pane's key.

## Red and green

**Seen red (before the code):** *prompt* — the two first cases (missing function), *a one-line draft, the cursor at its end* (`false`, wanted `true`); *agents* — the argv (missing function, then no record from the fake), the entries, the exit code, not JSON, five non-lists, malformed entries (`not a list` for a `null` in the array), the stderr line, a command that cannot be run (`ENOENT` raised), a signal (code 0, `not JSON`), the row and standing cases (missing functions; two of seven red for a wrong `...` in the test), the directory cases; *entry* — the rows, the argv (`/` after `:cd /`), the own pick, the elsewhere pick, the switch, the draft refusal, three refusals before the list, the claim, a failed list, an empty list, the menu that raises, the exit and the claim in the meantime, **Terminal mode not entered** (the lingering handler wrote `/resume` when Terminal mode was entered later), **a pick in Insert mode** (the mode was Normal); the moved pins (subcommands, mappings, health, help tags) and the suites that blocked on `\c`; D52: *is shown by `\g`, and `\pc` is mapped to nothing*.

**Arrived green, and why:** the prompt's cursor-row, moved-back-draft, first-line-draft, dialog and not-Terminal-mode cases (the cursor rule was written whole after the first red; killed by P1–P5); the bound, the output limit and the quit cases of `list_sessions()` — their red step cannot be taken safely (an unbounded `yes` hung the first attempt and had to be stopped by its pid), killed by A10–A13; the three entry points and the usage case (the wiring is generic; killed by M5); the cancelled pick (killed by M19); *Terminal mode already entered* (killed by M13); the `\cs` mapping rows of `tests/test_entry_prefix.lua` (killed by M5).

**Suites (Neovim 0.12.5, on the host, on the tree pushed):** `make test` 2690 cases in 80 groups; `Fails (1)`: `tests/test_health.lua` › *leaves the editor free to wait when Ctrl-C ends a check of a command that writes without end*, a timing case that passes alone (three runs, `Fails (0)`) and failed twice under load — once beside the other suites, once in this whole run; it does not touch the code of this packet. The first whole run had 64 failures, the suites that typed `\c` (fixed, below). `tests/test_claude_prompt.lua` 8 cases, `tests/test_claude_agents.lua` 25, `tests/test_entry_sessions.lua` 25; `make lint` clean. The merge of the branch with `dev` (`a0627fe`, unmoved) is clean; `tests/test_doc.lua` on it: 44 cases, `Fails (0)`.

## Mutants

Each applied as its literal edit, run on the covering file, restored in the same step (`.tests/t46-batch.py` and `t46-batch2.py`, scratch scripts, not committed); all on the final tree but the D52 pair, which was run after it. An assertion is `Failed expectation` in the output.

| # | File | Literal edit | Result |
|---|---|---|---|
| plan 1 / M1 | `plugin/aineo.lua` | `if status == 'ready' then` → `if true then` | killed by assertion, 4 (the three refusals, the exit in the meantime) |
| plan 2 / M2 | same | `if claude.prompt_shows_text(vim.api.nvim_get_current_win()) then` → `if false then` | killed by assertion, 2 (the draft cases) |
| plan 3 / M3 | same | the `elseif standing == 'elsewhere' then … ` branch removed | killed by assertion, 1 |
| plan 4 / M4 | `claude/agents.lua` | `{ 'agents', '--json', '--cwd', folder, '--all' }` → without `'--cwd', folder` | killed by assertion, 1 (and A2 on `test_claude_agents.lua`) |
| plan 5 / M5 | `plugin/aineo.lua` | `'sessions'` removed from `SUBCOMMANDS` | killed by assertion, 21 of 23 (the rest by an error) |
| M6 | same | `return_to(origin)` removed | killed by assertion, 2 |
| M7 | same | `if standing == 'own' then` → `if false then` | killed by assertion, 1 |
| M8, M9 | same | `refuses_while_claimed(…)` removed before the list, and at the pick | each killed by assertion, 1 |
| M10 | same | the readiness check removed at the pick | killed by assertion, 1 |
| M11 | same | `'\r'` removed from the write | killed by assertion, 2 |
| M12 | same | `claude.session_directory()` → `vim.fn.getcwd()` | killed by assertion, 1 |
| M13 | same | the immediate Terminal-mode branch → `if false then` | killed by assertion, 1 |
| M14 | same | `vim.api.nvim_del_autocmd(autocommand)` removed | killed by assertion, 1 (the red above) |
| M15–M17 | same | `run(…)` removed around the list callback; the problem not told; the empty list offered | each killed by assertion, 1 |
| M18 | same | the Insert-mode restore removed | **survived** the first run (no case); killed by assertion, 1 after the case was written and the restore fixed |
| M19 | same | `if picked then` removed | killed by assertion, 2 |
| A1–A20 | `claude/agents.lua`, `claude/init.lua` | `--all` dropped; `--cwd` dropped; `state` ignored; `vim.islist` removed; decode unprotected; field types unchecked; non-object entries not skipped; stderr line dropped; spawn failure not told; the timeout and the oversize do not kill; the process and not its group killed; the quit hook empty; the signal not told; own-session order swapped; `pid` ignored; unnamed id 7 characters; mark dropped; status left out of the row; the directory is the editor's | each killed by assertion (1–3 cases each) |
| P1–P5 | `claude/prompt.lua` | the row check removed; the one-line check removed; no box reads as empty; the text before the cursor ignored; `'^❯.*$'` | each killed by assertion, 1 — P2 first **survived** (the recorded draft replayed alone has no box; the cases now replay the startup first) |
| D52 | `plugin/aineo.lua`, `lua/aineo/health.lua` | `['pane changes'] = 'g'` → `'pc'`; `{ key = 'g', … }` → `{ key = 'pc', … }` | killed by assertion: 5 + 1 and 8 |

Not pinned: the `exited` guard of `kill_group()` (a kill after the process has ended: the window is a few milliseconds and cannot be set up).

## Task lines

- T46 `[X]` (PR into `dev`, wave 11; the plan's five mutants are rows 1–5 of the first table) — `\cs`, `:Aineo sessions` and `<Plug>(aineo-sessions)` list the sessions Claude Code lists for the folder it started in, in `vim.ui.select`, mark this terminal's and those running elsewhere, refuse them and refuse while the prompt shows text (by the cursor) or Claude Code is not ready or a claim holds, and otherwise write `/resume <id>` and Enter; D49, D51. Under the orchestrator's A119–A121, A123, A129–A131. The single write is unmeasured on the real Claude Code.
- T47 `[X]` (in T46's pull request) — the changes pane's key is `\g`, in place of `\pc` (D52); no alias (A132).

## Open threads

- That Claude Code takes `/resume <id>` and Enter in one write as a command is unmeasured (the fake takes it); if it reads the Enter as part of a paste, the user sees the text in the prompt and no switch.
- Whether `claude agents --json` starts Claude Code's background service, and whether it lists aineo's own interactive session (M7 did not report), are unmeasured (A131).
- A flood of `\cs` presses starts one bounded run each; no guard.
- `tests/test_health.lua` › the Ctrl-C case is timing-sensitive under load.
- `Projects/aineo.md`, the README of the project and the wave plan still name `\pc` in places the packet may not touch.

## Commits

Recorded after the merge, by the T46 knowledge pass.
