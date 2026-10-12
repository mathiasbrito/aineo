# 2026-10-11 — T46 Claude sessions key

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`, on Sonnet, A123)
**Branch:** `feature/t46-sessions` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D49 (and its notes of 2026-10-11: R1 (b), R2 (a), R3 (a); the fix round's note), D51, **D52** and **D53** (added here), C1, C3, T46, **T47** (added here)
- [[Implementation/Waves/00011-names-and-sessions/plan]] (*Round 3*, *The orchestrator's rulings*, *Verification mutants* › T46) and [[Implementation/Waves/00011-names-and-sessions/brief-t46-sessions]] with its *Amendment — 2026-10-11, at dispatch: built now, M7 and M8 measured*. **A114** is superseded by the user's "Build it now"; **A119** (the integrator), **A120** (a claim refuses as Send does), **A121** (the cursor), **A123** (Sonnet), **A129** (the amendment is the first commit), **A130** (`--cwd <folder> --all` always), **A131** (the background service is named in the help, not guarded), **A133** (the switch is written as Send writes) and **A134** (an entry started in another folder is refused) are the orchestrator's assumptions, never the user's decisions. **A132** (no `\pc` alias) was one until the user answered "Remove now" on 2026-10-11 (D52's note).
- Rests on: [[Sessions/2026-10-11 — T45 Open a named file]] (the dispatch-amendment form), the session notes of T7, T20, T35 and T39 (Send's refusals, the claims, the hook follow), and the fixtures `tests/fixtures/claude/startup-2.1.281.bytes` and `draft-2.1.281.bytes`.

## What was done

**The Claude home (C3), `lua/aineo/claude/`:**
- `prompt.lua` (new): `shows_text(window)` — the prompt shows text unless the input box is one line and the terminal's cursor sits right after the prompt glyph on it. The window must be in Terminal mode, where Neovim 0.12.5 keeps the window's cursor on the terminal's (measured on the fake's screens: row 20, byte 5 on the empty prompt; row 20, byte 13 at the end of the recorded draft). A screen with no input box reads as text; a draft whose cursor was moved back to its start reads as empty (R2 (a)'s one miss, pinned).
- `readiness.lua`: the input box's rule is `input_box(lines)` now, exported with `shown_screen(buffer)`, so the text check reads the box as the readiness check does; the watch is unchanged (declared widening).
- `agents.lua` (new): `list_sessions(command, folder, on_done)` runs `claude.cmd` + `agents --json --cwd <folder> --all` in a process group of its own, asynchronously, stopped at 5 s, past 1 MiB of output and when Neovim quits; every failure is told in its own words (cannot run, exit code with the first line of stderr, a signal — `vim.system` reports a killed process as code 0, so the signal is read on its own —, not JSON, not a list). An entry is kept when it carries a `sessionId` string; a field of the wrong type is left out. `standing()` (`own`, `elsewhere` for an entry with a `pid`, `switchable`), `name()` and `row()` build the list's rows and marks.
- `init.lua`: exports `list_sessions`, `session_standing`, `session_row`, `listed_session_name`, `session_directory` and `prompt_shows_text` (declared widening; no existing function touched).

**The composition root, `plugin/aineo.lua`:** `sessions` in `SUBCOMMANDS` (after `claude-numbers`), `ACTIONS` and `PREFIX_KEYS` (`S` — first built as `cs`, see the fix round), so `:Aineo sessions`, `<Plug>(aineo-sessions)` and `\S` do one thing. `list_sessions()` refuses while Claude Code is not ready or a claim of another session holds (Send's words, `no session list` for `nothing sent`), reads the list, and `offer_sessions()` shows it in `vim.ui.select`; `pick_listed_session()` refuses the own session and a session running elsewhere, and `switch_to_session()` re-checks readiness and claim, moves to Claude's window (`focus_claude()`), waits for Terminal mode, reads the cursor, and either writes `/resume <id>` and Enter in one write or, on text, puts the window and the mode back (`return_to()`) and says to clear the prompt. The `TermEnter` handler a switch waits for is removed when Terminal mode is not entered within a second.

**The health check:** `\S` in the prefix-mappings list. **`doc/aineo.txt`:** the introduction, *:Aineo-sessions*, *<Plug>(aineo-sessions)*, *aineo-\S*, the passage on keys that wait for `'timeoutlen'`, and a *The session list* subsection of *aineo-limits* (A131: the background service, the unlisted own session, the unmeasured single write; a declared widening).

**The fake `claude`:** `agents --json` answers before the terminal is put in raw mode — it records its arguments (without an `ended` line), prints the array `AINEO_FAKE_CLAUDE_AGENTS` names (`[]` when unset) and exits 0, or exits with `AINEO_FAKE_CLAUDE_AGENTS_EXIT` and prints nothing. It can print both of M7's entry shapes (a background session with neither `pid` nor `status`; an interactive one with both).

**The user's second request, via the orchestrator (D52, T47, A132):** the changes pane's key is `\g`, in place of `\pc`; `\pa`, `:Aineo pane changes` and `<Plug>(aineo-pane-changes)` do not change, and no `\pc` alias is kept. `PREFIX_KEYS`, the health list, the help, and every suite that typed or pinned `\pc` follow. D52 and T47 are rows in the v1 plan note, with a dated note on D18, C12 and T24 (the rows that define the key); the orchestrator asked for these rows, the packet's brief did not allow the plan note.

**The brief:** the *Amendment — 2026-10-11, at dispatch* (A129) is the first commit, with M7's shape (no user's path, id or name), M8, A129–A131, the moved facts and the widenings, which later commits extended (section 11 of the help; five suites that typed `\c`).

## Fix round (PR #167, head after `e2f5327`)

The two reviews of `d742c9a` (attack, `neovim-claude-code-reviewer`; tests and records, `records-reviewer`) and the user's two answers. **Two decisions of the user, 2026-10-11** (recorded as D53, with a dated note on D49 and on D52):

- **Q:** "The attack review found a problem with the \cs key. If you type \c and then a message starting with 's' (for example \cshow me the diff), aineo now runs \cs, and the rest ('how me…') edits your code buffer instead of reaching Claude. Before \cs existed, that text went to Claude's prompt. No mapping option can avoid it while \cs starts with \c. Which key should open the session list?" **A:** "\S (Recommended)" (option text: "Capital S for sessions. Nothing else starts with \S, so \c jumps to Claude at once again and your typing reaches the prompt.")
- **Q:** "With \pc gone (shipped v0.2.12–v0.2.22), muscle memory typing \pc now does what Vim does with unmapped keys: it pastes the register and leaves an operator waiting. I removed it with no alias. Should \pc stay for one release, opening the changes pane and saying 'use \g'?" **A:** "Remove now" (option text: "As built: \pc is unmapped from v0.2.23.") — A132 is the user's decision.

**Attack findings, and what was done** (each case red first unless a row says otherwise):

1. **HIGH, any string in `sessionId` typed into the terminal:** only an id that passes `session_ids.is_session_id()` is listed (`agents.lua`), and `pick_listed_session()` checks the id again where a menu hands it in; the probe's `"x\r!touch pwned\r"` reaches nothing. The reviewer's second guard "before the write" is not added: `switch_to_session()` is reached only after that check, with a record `list_sessions()` filtered, so the state it would guard cannot occur (A117).
2. **HIGH, `\c` + a message starting with `s` ran `\cs`:** the user's answer, `\S`. Case in `tests/test_entry_claude_mode.lua`: `\c` followed at once by `show me the diff` reaches Claude's prompt and leaves the file buffer alone (red against `cs`). The `entry.press()` the `\c` suites got for the wait is kept where harmless; the busy-editor case is back to its original form.
3. **MEDIUM, "running elsewhere" failed open:** a listed session carries `running` when its entry has a `pid` or a `status` at all, whatever their types; the pin that expected the opposite moved.
4. **MEDIUM, the standing came from a stale list:** the pick reads the list again and switches only a session still listed and still switchable; three cases (taken since, gone, the second read fails).
5. **A133, unverifiable on the real CLI:** the switch is a bracketed paste of `/resume <id>` followed by Enter, in one write, as Send writes (`send/init.lua` 93, measured on 2.1.281); the fake strips the paste markers. The orchestrator's ruling said "then `\r` as its own write, as Send does"; Send writes both in one write, and this follows its code. Still unmeasured: that Claude Code takes a pasted `/resume` as a command.
6. **LOW, a refusal from Claude's window in Normal mode left Terminal mode on, and the timeout path never put the cursor back:** `return_to()` calls `stopinsert` when the origin is the current window, and the timeout path calls it (two cases; the Normal-mode one first passed vacuously and is killed by F6).
7. **LOW, repeated presses:** one read at a time; a second `\S` says `a session list is still being read` and starts nothing (case: `\S\S` typed together).
8. **LOW, `\pc`:** removed with no alias, the user's answer.
9. **A134, sessions started in another folder:** an entry whose `cwd` is not the folder listed (compared by real path; an entry with no `cwd` counts as another) is marked `[another folder]` and refused, with its folder in the message; a link to the folder still switches.

**Tests and records findings:** 1 the `exited` guard is pinned (a case in `tests/test_claude_agents.lua` that holds the cleanup back and fires `VimLeavePre`; its mutant is T1 below); 2 this note lists every mutant as its literal edit; 3 `:Aineo`'s `desc` lists `sessions`, with a case; 4 the help's own-mapping passage now names `\gs` and `\g`, and says nothing of `\c` (it waits for nothing); 5 `input_box()`'s docstring no longer reads as the definition of "no input box"; 6 the bare `vim.wait(2000)` is gone with the case's original form; 7 the count: **62 of the first whole run's 64 failures** were the `\c` suites (51 + 9 + 2), the other 2 `test_entry_panes.lua`'s pin of the subcommand list.

**Records:** `Projects/aineo.md` names `\g` and `\S`; D53 and the dated notes are in the v1 plan note.

## Decisions and departures from the brief

- **One write, a bracketed paste of `/resume <id>` and Enter** (A133, fix round). First built as the raw text `/resume <id>\r`, because the fake switched on exactly that chunk; the attack review preferred Send's measured form, and the fake now strips the markers. That Claude Code takes a pasted `/resume` as a command is **not measured**; the help's limits say so.
- **No options argument** for the 5 s bound and the 1 MiB limit (no caller overrides them); the tests run the defaults. The health check bounds `--version` at 3 s; the list is given 5 s because a first `claude agents` may start Claude Code's service (A131, unmeasured).
- **A guard against pressing `\S` again while a list is read** was added in the fix round (finding 7).
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
11. The fix round: `\S` (D53); the id guard; `running`; the second read at the pick; the paste; the cursor after a refusal; one read at a time; another folder; the reviews' records.

## Red and green

**Seen red (before the code):** *prompt* — the two first cases (missing function), *a one-line draft, the cursor at its end* (`false`, wanted `true`); *agents* — the argv (missing function, then no record from the fake), the entries, the exit code, not JSON, five non-lists, malformed entries (`not a list` for a `null` in the array), the stderr line, a command that cannot be run (`ENOENT` raised), a signal (code 0, `not JSON`), the row and standing cases (missing functions; two of seven red for a wrong `...` in the test), the directory cases; *entry* — the rows, the argv (`/` after `:cd /`), the own pick, the elsewhere pick, the switch, the draft refusal, three refusals before the list, the claim, a failed list, an empty list, the menu that raises, the exit and the claim in the meantime, **Terminal mode not entered** (the lingering handler wrote `/resume` when Terminal mode was entered later), **a pick in Insert mode** (the mode was Normal); the moved pins (subcommands, mappings, health, help tags) and the suites that blocked on `\c`; D52: *is shown by `\g`, and `\pc` is mapped to nothing*.

**Arrived green, and why:** the prompt's cursor-row, moved-back-draft, first-line-draft, dialog and not-Terminal-mode cases (the cursor rule was written whole after the first red; killed by P1–P5); the bound, the output limit and the quit cases of `list_sessions()` — their red step cannot be taken safely (an unbounded `yes` hung the first attempt and had to be stopped by its pid), killed by A10–A13; the three entry points and the usage case (the wiring is generic; killed by M5); the cancelled pick (killed by M19); *Terminal mode already entered* (killed by M13); the `\cs` mapping rows of `tests/test_entry_prefix.lua` (killed by M5).

**Suites (Neovim 0.12.5, on the host, on the tree pushed after the fix round):** `make test` 2708 cases in 80 groups, `Fails (0)`; `make lint` clean. The first whole run (before the first push) had 64 failures, 62 of them the `\c` suites, fixed then; the second ended with `Fails (1)`, `tests/test_health.lua` › the Ctrl-C timing case, which passed alone three times and did not fail in the last run. `tests/test_claude_prompt.lua` 8 cases, `tests/test_claude_agents.lua` 32, `tests/test_entry_sessions.lua` 33. The merge of the branch with `dev` (`a0627fe`, unmoved) is clean; `tests/test_doc.lua` 44, `Fails (0)`.

## Mutants

Each is a literal edit (`old` → `new`, `\n` a line break), applied to the file named, run on the covering test file and restored in the same step, on the tree of the fix round's last commit; the count is the failing cases and how many of them failed by assertion (`Failed expectation`). A survivor is named as one. **plan 1–5** are the plan's *Verification mutants* › T46; the others are the packet's own.

- **plan 1 / M1 no readiness check** — `plugin/aineo.lua`: `  if status == 'ready' then\n    return false\n  end\n  vim.notify(outcome .. NOT_READY` → `  if true then\n    return false\n  end\n  vim.notify(outcome .. NOT_READY` — tests/test_entry_sessions.lua: 4 failing, 4 by assertion
- **plan 2 / M2 no text check** — `plugin/aineo.lua`: `if claude.prompt_shows_text(vim.api.nvim_get_current_win()) then` → `if false then` — tests/test_entry_sessions.lua: 3 failing, 3 by assertion
- **plan 3 / M3 no running-elsewhere refusal** — `plugin/aineo.lua`: `  elseif standing == 'elsewhere' then\n` → `  elseif false then\n`; `  return standing ~= 'switchable'` → `  return standing == 'own' or standing == 'another_folder'` — tests/test_entry_sessions.lua: 2 failing, 2 by assertion
- **plan 4 / M4 --cwd dropped** — `lua/aineo/claude/agents.lua`: `{ 'agents', '--json', '--cwd', folder, '--all' }` → `{ 'agents', '--json', '--all' }` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **plan 5 / M5 sessions out of SUBCOMMANDS** — `plugin/aineo.lua`: `'claude-numbers', 'sessions', 'pane', 'claim' }` → `'claude-numbers', 'pane', 'claim' }` — tests/test_entry_sessions.lua: 30 failing, 25 by assertion
- **M6 cursor not put back after a text refusal** — `plugin/aineo.lua`: `        return_to(origin)\n` → (removed) — tests/test_entry_sessions.lua: 3 failing, 3 by assertion
- **M7 own row switches** — `plugin/aineo.lua`: `  if standing == 'own' then` → `  if false then` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **M8 no claim refusal before the list** — `plugin/aineo.lua`: `    or refuses_while_claimed(NO_LIST)\n` → (removed) — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **M9 no claim refusal at the pick** — `plugin/aineo.lua`: `if refuses_while_not_ready(NOT_SWITCHED) or refuses_while_claimed(NOT_SWITCHED) then` → `if refuses_while_not_ready(NOT_SWITCHED) then` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **M10 no readiness check at the pick** — `plugin/aineo.lua`: `if refuses_while_not_ready(NOT_SWITCHED) or refuses_while_claimed(NOT_SWITCHED) then` → `if refuses_while_claimed(NOT_SWITCHED) then` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **M11 no paste markers** — `plugin/aineo.lua`: `PASTE_START .. '/resume ' .. listed.session_id .. PASTE_END .. '\r')` → `'/resume ' .. listed.session_id .. '\r')` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **M11b Enter not written** — `plugin/aineo.lua`: `listed.session_id .. PASTE_END .. '\r')` → `listed.session_id .. PASTE_END)` — tests/test_entry_sessions.lua: 3 failing, 3 by assertion
- **M12 folder is the editor cwd** — `plugin/aineo.lua`: `local directory = require('aineo.claude').session_directory()` → `local directory = vim.fn.getcwd()` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **M13 no immediate branch** — `plugin/aineo.lua`: `if vim.api.nvim_get_current_buf() == terminal and vim.api.nvim_get_mode().mode == 't' then` → `if false then` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **M14 autocmd kept after the timeout** — `plugin/aineo.lua`: `      vim.api.nvim_del_autocmd(autocommand)\n` → (removed) — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **M15 errors not caught in the read callback** — `plugin/aineo.lua`: `      run(function()\n        on_read(listed, problem)\n      end)` → `      on_read(listed, problem)` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **M16 problem not told** — `plugin/aineo.lua`: `  if problem then\n    vim.notify(NO_LIST .. problem, vim.log.levels.WARN)\n    return\n  end\n` → `  if problem then\n    return\n  end\n` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **M17 empty list offered** — `plugin/aineo.lua`: `  if #listed == 0 then\n` → `  if false then\n` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **M18 Insert mode not restored** — `plugin/aineo.lua`: `  if vim.startswith(origin.mode, 'i') then\n    vim.api.nvim_create_autocmd('ModeChanged', {\n      pattern = 't:*',\n      once = true,\n      callback = function()\n        vim.schedule(vim.cmd.startinsert)\n      end,\n    })\n  end\n` → (removed) — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **M19 a cancelled pick acted on** — `plugin/aineo.lua`: `    if picked then\n      run(function()\n        pick_listed_session(picked)\n      end)\n    end` → `    run(function()\n      pick_listed_session(picked)\n    end)` — tests/test_entry_sessions.lua: 2 failing, 2 by assertion
- **F1 pick id not checked** — `plugin/aineo.lua`: `  if not claude.is_session_id(listed.session_id) then` → `  if false then` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **F2 listed id not checked** — `lua/aineo/claude/agents.lua`: `  if not session_ids.is_session_id(session_id) then` → `  if false then` — tests/test_claude_agents.lua: 3 failing, 3 by assertion
- **F3 running by pid only** — `lua/aineo/claude/agents.lua`: `    running = (entry.pid ~= nil or entry.status ~= nil) or nil,` → `    running = entry.pid ~= nil or nil,` — tests/test_claude_agents.lua: 1 failing, 1 by assertion
- **F3b running by status only** — `lua/aineo/claude/agents.lua`: `    running = (entry.pid ~= nil or entry.status ~= nil) or nil,` → `    running = entry.status ~= nil or nil,` — tests/test_claude_agents.lua: 1 failing, 1 by assertion
- **F4 standing not read again** — `plugin/aineo.lua`: `    if not refuses_by_standing(current) then\n      switch_to_session(current)\n    end` → `    switch_to_session(current)` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **F4b a session no longer listed switched** — `plugin/aineo.lua`: `    if not current then\n      vim.notify(NOT_SWITCHED .. name .. ' is no longer listed', vim.log.levels.WARN)\n      return\n    end\n` → `    current = current or listed\n` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **F4c read-again problem not told** — `plugin/aineo.lua`: `    if problem then\n      vim.notify(NOT_SWITCHED .. problem, vim.log.levels.WARN)\n      return\n    end\n` → `    if problem then\n      return\n    end\n` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **F6 Terminal mode not left** — `plugin/aineo.lua`: `  if origin.window == vim.api.nvim_get_current_win() and origin.mode ~= 't' then\n    vim.cmd.stopinsert()\n  end\n` → (removed) — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **F6b timeout does not put the cursor back** — `plugin/aineo.lua`: `  end, function()\n    return_to(origin)\n  end)` → `  end, function() end)` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **F7 second read allowed** — `plugin/aineo.lua`: `  if not session_read_in_flight then\n    return false\n  end` → `  if true then\n    return false\n  end` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **F7b read never marked running** — `plugin/aineo.lua`: `  )\n  session_read_in_flight = true\nend` → `  )\nend` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **F7c read never marked finished** — `plugin/aineo.lua`: `      session_read_in_flight = false\n      run(function()\n        on_read` → `      run(function()\n        on_read` — tests/test_entry_sessions.lua: 11 failing, 11 by assertion
- **F9 folder not compared** — `lua/aineo/claude/agents.lua`: `  if not session.cwd or not same_directory(session.cwd, folder) then` → `  if false then` — tests/test_claude_agents.lua: 3 failing, 3 by assertion; tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **F9b links not resolved** — `lua/aineo/claude/agents.lua`: `  return (vim.uv.fs_realpath(first) or first) == (vim.uv.fs_realpath(second) or second)` → `  return first == second` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **F9c an entry with no cwd taken as in the folder** — `lua/aineo/claude/agents.lua`: `  if not session.cwd or not same_directory(session.cwd, folder) then` → `  if session.cwd and not same_directory(session.cwd, folder) then` — tests/test_claude_agents.lua: 1 failing, 1 by assertion
- **F9d no place told** — `plugin/aineo.lua`: `    started_in and (', ' .. started_in) or ''` → `    ''` — tests/test_entry_sessions.lua: 1 failing, 1 by assertion
- **T3 desc without sessions** — `plugin/aineo.lua`: `claude-numbers, sessions, pane agent\|changes or claim [id]',` → `claude-numbers, pane agent\|changes or claim [id]',` — tests/test_entry.lua: 1 failing, 1 by assertion
- **T1 exited guard removed** — `lua/aineo/claude/agents.lua`: `    if not exited then\n      vim.uv.kill(-process.pid, 'sigkill')\n    end` → `    do\n      vim.uv.kill(-process.pid, 'sigkill')\n    end` — tests/test_claude_agents.lua: 1 failing, 1 by assertion
- **A1 --all dropped** — `lua/aineo/claude/agents.lua`: `{ 'agents', '--json', '--cwd', folder, '--all' }` → `{ 'agents', '--json', '--cwd', folder }` — tests/test_claude_agents.lua: 1 failing, 1 by assertion
- **A2 --cwd dropped** — `lua/aineo/claude/agents.lua`: `{ 'agents', '--json', '--cwd', folder, '--all' }` → `{ 'agents', '--json', '--all' }` — tests/test_claude_agents.lua: 1 failing, 1 by assertion
- **A3 state ignored** — `lua/aineo/claude/agents.lua`: `typed_field(entry, 'status', 'string') or typed_field(entry, 'state', 'string')` → `typed_field(entry, 'status', 'string')` — tests/test_claude_agents.lua: 3 failing, 3 by assertion
- **A4 islist check removed** — `lua/aineo/claude/agents.lua`: `if type(entries) ~= 'table' or not vim.islist(entries) then` → `if type(entries) ~= 'table' then` — tests/test_claude_agents.lua: 1 failing, 1 by assertion
- **A5 decode not protected** — `lua/aineo/claude/agents.lua`: `local decoded, entries = pcall(vim.json.decode, output, { luanil = { object = true } })` → `local decoded, entries = true, vim.json.decode(output, { luanil = { object = true } })` — tests/test_claude_agents.lua: 2 failing, 1 by assertion
- **A6 field type not checked** — `lua/aineo/claude/agents.lua`: `  return type(value) == expected and value or nil` → `  return value` — tests/test_claude_agents.lua: 2 failing, 2 by assertion
- **A7 non-object entry not skipped** — `lua/aineo/claude/agents.lua`: `  if type(entry) ~= 'table' then\n    return nil\n  end\n` → (removed) — tests/test_claude_agents.lua: 1 failing, 1 by assertion
- **A8 stderr line dropped** — `lua/aineo/claude/agents.lua`: `    return nil, reason and (told .. ': ' .. reason) or told` → `    return nil, told` — tests/test_claude_agents.lua: 1 failing, 1 by assertion
- **A9 spawn failure not told** — `lua/aineo/claude/agents.lua`: `      on_done(nil, ('could not run %s: %s'):format(COMMAND_NAME, failure))` → `      on_done({}, nil)` — tests/test_claude_agents.lua: 1 failing, 1 by assertion
- **A10 timeout does not kill** — `lua/aineo/claude/agents.lua`: `    run.timed_out = true\n    kill_group()` → `    run.timed_out = true` — tests/test_claude_agents.lua: 1 failing, 1 by assertion
- **A11 kills the process, not its group** — `lua/aineo/claude/agents.lua`: `vim.uv.kill(-process.pid, 'sigkill')` → `vim.uv.kill(process.pid, 'sigkill')` — tests/test_claude_agents.lua: 2 failing, 2 by assertion
- **A12 oversize does not kill** — `lua/aineo/claude/agents.lua`: `        run.printed_too_much = true\n        kill_group()` → `        run.printed_too_much = true` — tests/test_claude_agents.lua: 1 failing, 1 by assertion
- **A13 quit does not kill** — `lua/aineo/claude/agents.lua`: `vim.api.nvim_create_autocmd('VimLeavePre', { callback = kill_group })` → `vim.api.nvim_create_autocmd('VimLeavePre', { callback = function() end })` — tests/test_claude_agents.lua: 1 failing, 1 by assertion
- **A14 signal not told** — `lua/aineo/claude/agents.lua`: `  if run.signal ~= 0 then\n    return nil, ('%s was ended by signal %d'):format(COMMAND_NAME, run.signal)\n  end\n` → (removed) — tests/test_claude_agents.lua: 1 failing, 1 by assertion
- **A15 own session not first** — `lua/aineo/claude/agents.lua`: `  if session.session_id == own_session_id then\n    return 'own'\n  end\n  if session.running then\n    return 'elsewhere'\n  end` → `  if session.running then\n    return 'elsewhere'\n  end\n  if session.session_id == own_session_id then\n    return 'own'\n  end` — tests/test_claude_agents.lua: 3 failing, 3 by assertion
- **A16 running ignored** — `lua/aineo/claude/agents.lua`: `  if session.running then\n    return 'elsewhere'\n  end\n` → (removed) — tests/test_claude_agents.lua: 2 failing, 2 by assertion
- **A17 unnamed id 7 characters** — `lua/aineo/claude/agents.lua`: `local UNNAMED_ID_LENGTH = 8` → `local UNNAMED_ID_LENGTH = 7` — tests/test_claude_agents.lua: 1 failing, 1 by assertion
- **A18 mark dropped** — `lua/aineo/claude/agents.lua`: `  local mark = STANDING_MARKS[M.standing(session, own_session_id, folder)]\n  if mark then\n    table.insert(words, mark)\n  end\n` → (removed) — tests/test_claude_agents.lua: 3 failing, 3 by assertion
- **A19 status left out of the row** — `lua/aineo/claude/agents.lua`: `for _, word in ipairs({ session.kind or false, session.status or false }) do` → `for _, word in ipairs({ session.kind or false }) do` — tests/test_claude_agents.lua: 3 failing, 3 by assertion
- **A20 directory is the editor cwd** — `lua/aineo/claude/init.lua`: `  return session and session.settings.cwd` → `  return vim.fn.getcwd()` — tests/test_claude_agents.lua: 2 failing, 2 by assertion
- **P1 row check dropped** — `lua/aineo/claude/prompt.lua`: `  if row - first_line + 1 ~= box.prompt then\n    return true\n  end\n` → (removed) — tests/test_claude_prompt.lua: 1 failing, 1 by assertion
- **P2 one-line check dropped** — `lua/aineo/claude/prompt.lua`: `if not box or box.rule ~= box.prompt + 1 then` → `if not box then` — tests/test_claude_prompt.lua: 1 failing, 1 by assertion
- **P3 no box reads as empty** — `lua/aineo/claude/prompt.lua`: `  if not box or box.rule ~= box.prompt + 1 then\n    return true\n  end` → `  if not box then\n    return false\n  end\n  if box.rule ~= box.prompt + 1 then\n    return true\n  end` — tests/test_claude_prompt.lua: 1 failing, 1 by assertion
- **P4 text before the cursor ignored** — `lua/aineo/claude/prompt.lua`: `  return screen[box.prompt]:sub(1, column):match(EMPTY_PROMPT_BEFORE_CURSOR) == nil` → `  return false` — tests/test_claude_prompt.lua: 1 failing, 1 by assertion
- **P5 any text before the cursor is empty** — `lua/aineo/claude/prompt.lua`: `'^❯[ \194\160]*$'` → `'^❯.*$'` — tests/test_claude_prompt.lua: 1 failing, 1 by assertion
- **K1 sessions key back to cs** — `plugin/aineo.lua`: `  sessions = 'S',` → `  sessions = 'cs',` — tests/test_entry_prefix.lua: 5 failing, 5 by assertion; tests/test_plugin.lua: 1 failing, 1 by assertion; tests/test_entry_claude_mode.lua: 1 failing, 1 by assertion
- **D52 changes key back to pc** — `plugin/aineo.lua`: `  ['pane changes'] = 'g',` → `  ['pane changes'] = 'pc',` — tests/test_entry_prefix.lua: 5 failing, 5 by assertion; tests/test_plugin.lua: 1 failing, 1 by assertion
- **D52b health changes key back to pc** — `lua/aineo/health.lua`: `{ key = 'g', plug = '<Plug>(aineo-pane-changes)', mode = 'n' },` → `{ key = 'pc', plug = '<Plug>(aineo-pane-changes)', mode = 'n' },` — tests/test_health.lua: 8 failing, 8 by assertion
- **K1b health sessions key back to cs** — `lua/aineo/health.lua`: `{ key = 'S', plug = '<Plug>(aineo-sessions)', mode = 'n' },` → `{ key = 'cs', plug = '<Plug>(aineo-sessions)', mode = 'n' },` — tests/test_health.lua: 8 failing, 8 by assertion

After the fix round's first run no mutant survived. In the first round two survived once and were fixed with a case: the Insert-mode restore (it was also broken) and the one-line check of the prompt (the draft replayed alone had no box). The `exited` guard of `kill_group()`, which the first version called unpinned, is T1.

## Task lines

- T46 `[X]` (PR into `dev`, wave 11; the plan's five mutants are rows 1–5 of the first table) — `\S`, `:Aineo sessions` and `<Plug>(aineo-sessions)` list the sessions Claude Code lists for the folder it started in, in `vim.ui.select`, mark this terminal's and those running elsewhere, refuse them and refuse while the prompt shows text (by the cursor) or Claude Code is not ready or a claim holds, and otherwise write `/resume <id>` and Enter; D49, D51. Under the orchestrator's A119–A121, A123, A129–A131, A133, A134 and the user's D53. The paste of `/resume` is unmeasured on the real Claude Code.
- T47 `[X]` (in T46's pull request) — the changes pane's key is `\g`, in place of `\pc` (D52); no alias (A132).

## Open threads

- That Claude Code takes a pasted `/resume <id>` followed by Enter in one write as a command is unmeasured (the fake takes it).
- Whether `claude agents --json` starts Claude Code's background service, and whether it lists aineo's own interactive session (M7 did not report), are unmeasured (A131).
- Two menus open at once, answered at once, are not guarded; each pick reads the list again and checks readiness and the prompt's text, but the second reads the screen the first switch left.
- `tests/test_health.lua` › the Ctrl-C case is timing-sensitive under load.
- The wave plan still names `\cs` and `\pc` in its text (not edited after dispatch).

## Commits

Recorded after the merge, by the wave 11 closing knowledge pass. PR #167 merged by rebase as `55e6d32` … `7278d07` (13 commits), now `83f3342` … `f319ff3` on `dev`. The orchestrator verified the pull request's head `3df71aa` on `dev` `a0627fe`: the whole suite 2708 cases, `Fails (0)`, lint clean, and the two session-id guards' mutants (in the list's reader, and at the pick) killed, by 3 and 1 failures. It then pushed one records commit, `7278d07`, which names A132 the user's decision without a pronoun. Released in v0.2.23 (PR #168, `main` `9d2e1ee`).

| Branch | `dev` | Subject |
|---|---|---|
| `55e6d32` | `83f3342` | Record T46's dispatch amendment: built now, M7 and M8 measured |
| `834cb01` | `4a88f87` | Read whether Claude Code's prompt shows text by the terminal's cursor |
| `70c1b70` | `a0114b5` | List the sessions Claude Code lists, from claude agents --json |
| `3b77737` | `4e505e4` | Mark each listed session by where a pick may take it |
| `d39577f` | `2c024f8` | Add \cs, aineo's own list of Claude Code's sessions, and switch to a pick |
| `51dc333` | `ee50b03` | Put Insert mode back after a refused \cs pick that came in Insert mode |
| `8d02396` | `1ab5af1` | Move the suites' pins that \cs made stale: \c now waits for an s |
| `1c15955` | `777e8d8` | Show the changes pane with \g, not \pc |
| `d742c9a` | `26a82d2` | Record T46's session note, D52 and T47, and the amendment's widenings |
| `3c449d4` | `3181233` | Open the session list with \S, so \c acts at once again |
| `e2f5327` | `5c6eed0` | Answer the attack review of \S: guard the id, list again at the pick |
| `3df71aa` | `ac25b4a` | Record T46's fix round: D53, the literal mutants and the settled counts |
| `7278d07` | `f319ff3` | Name A132 the user's decision without a pronoun |

The `Branch` column is the pull request's own commits (`refs/pull/167/head`); the orchestrator's `7278d07` is the last of them. The first commit carries the brief's dispatch amendment (A129). The subjects name `\cs` as they were written; the key became `\S` in the commit "Open the session list with \S" (D53).
