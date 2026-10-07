# 2026-10-07 — T35 Session switch

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t35-session-switch` · **Pull request:** into `dev` (a regular packet)

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C3, C5, D11, D23, D25, D36, D37, D38, T19, T35
- [[Planning/aineo — worktrees and session switches]] › P6–P8
- Wave plan: `Implementation/Waves/00009-worktrees-sessions/plan.md` › *Measured with the real Claude Code*, *Assumptions to report to the user* (A1–A4), *Verification mutants* T35 1–12; brief: `brief-t35-session-switch.md` with its *Amendment* and *Correction — 2026-10-07*; `brief-review.md` (T35-1 to T35-13, W-2 to W-4)
- Evidence: `evidence/w9-real-claude-sessions.txt` (M1–M8, Claude Code 2.1.292), `evidence/w9-probes.txt` (B1, B4, D-docs)
- Rests on: [[Sessions/2026-09-27 — T19 Claude resume]] (the fallback), [[Sessions/2026-10-07 — T33 Claude window name]] (the claude home as T33 left it), [[Learnings/An RPC request to a Neovim at a hit-enter prompt waits until it is answered]]

## Context

aineo resumed the session it started in a directory even after the user switched inside Claude Code (`/clear`, `/resume`, `/branch`), and T39's panes need to know which session Claude Code is on. D36 chose a `SessionStart` hook given through `--settings`, D37 says what is a switch, D38 which session resumes next; M1–M8 shaped the rest into A1–A4.

## What was done

- **`lua/aineo/claude/arguments.lua`**: `claude_arguments(settings, start_token)` adds `--settings` before `--allowedTools`: one JSON object holding only `hooks`, with one `SessionStart` and one `SessionEnd` entry, each a `type: "command"` hook with no matcher and `timeout` 5 (seconds). The command is the hook relay run as aineo's MCP server is run — `<editor_program> --headless --clean --cmd 'set noloadplugins' -l <hook_relay.lua> <editor_address> <start token> <event>` — every word single-quoted for a POSIX shell, a `'` written `'\''` (T35-2). The timeout: far above the relay's measured ~20 ms and a loaded host's Neovim start, far below Claude Code's 600 s default; the hook returns at once, so it bounds only a relay that hangs.
- **`lua/aineo/claude/hook_relay.lua`** (new): the hook, and the composition root of its process. As the hook it reads stdin, and for an object with a string `session_id` starts itself again, detached (its own session, no standard stream), as the *deliverer*, then exits 0 — about 20 ms. As the deliverer it sends the editor one RPC notification calling `require('aineo.claude').receive_session_event(event, id, source or reason, token)`, then waits for the answer to a request sent behind it on the same connection before closing; an editor it cannot reach, or that ends while it waits, ends it quietly (T35-10). It never writes on stdout or stderr, and reads the address from its command line, never `$NVIM`. See *Decided over the brief* for why the deliverer exists.
- **`lua/aineo/claude/init.lua`**: `Settings` gains `editor_address`, `editor_program` (both validated as strings) and the optional `on_session_switched(id, source, left, reason)`. Each `launch()` has a start token (a launch counter) and follows the id it started on (A2); `M.session_id()` returns the id followed now, nil before any start. `M.receive_session_event()` schedules `take_session_event()`, which drops anything while Neovim quits (`v:exiting`), for another start's token (T35-8), or for an id `session_ids.is_session_id()` refuses (M4); a `SessionEnd` of the followed id marks it ending with its reason; a `SessionStart` of another id after that mark is a switch (A1 as reworded, T35-4): `follow_switch()` follows the new id, keeps it for the directory (D38) and calls `on_session_switched`. A `SessionStart` of the followed id does nothing (it does not clear the mark: with one deliverer per hook, a late startup `SessionStart` must not cancel a switch). A start whose session differs from the one followed before it — T19's fallback (T35-1) and a later start in another directory — calls `on_session_switched(<new>, 'startup' | 'resume', <old>)` after `on_terminal_replaced`; an editor's first start calls nothing.
- **`lua/aineo/claude/session_ids.lua`**: `is_session_id()` exported, its check unchanged (M4).
- **`plugin/aineo.lua`** › `started_claude_terminal()`: hands `editor_address = vim.v.servername` and `editor_program = vim.v.progpath`. Nothing else (T39 wires the switch).
- **`tests/helpers/fake_claude.lua`**: with `AINEO_FAKE_CLAUDE_HOOKS` set it runs the `--settings` hooks through `sh -c`, the hook's JSON on stdin and the inherited `NVIM` in its environment (T35-3), waiting for each: `SessionStart` at start (`startup` / `resume`); `/clear`, `/resume <id>`, `/branch` as `SessionEnd` (`clear`, `resume`, `resume`) then `SessionStart` (`clear`, `resume`, `fork`); `/compact` as `SessionStart` (`compact`) alone; `SessionEnd` (`prompt_input_exit`) at an exit by keys only (T35-13). Each run is recorded as `{ hook, session_id, cause, code }`.
- **`tests/helpers/claude_session.lua`**: `editor_address`/`editor_program` in the stand-in settings; `start_noting_switches()`, `start_again_noting_switches()`, `wait_for_session_switches()`, `session_id()`, `hook_input()`, `hook_command()`, `run_session_hook()` (a hook run as Claude Code runs one), `wait_for_deliveries()` (no deliverer left for the child, then one scheduled round: the deterministic way to assert that nothing was called back).
- **Tests**: `tests/test_claude_switch.lua` (new, 43 cases), `tests/test_claude.lua` (+3 malformed-setting rows; the flag-count pin now names `--settings` and 11 words).
- **`doc/aineo.txt`**, the four places: *aineo-install* names 2.1.292 for the switch; *aineo-claude-session*'s last paragraph rewritten (D38); *aineo-report* "five additions", the hooks among them, beside a project's own hooks as M2 measured; LIMITS › `Session switches ~` (trust dialog, `allowManagedHooksOnly`, `disableAllHooks`, what was not seen, the deliverer).

## Decided over the brief, on measurement

The brief's relay "sends the editor one RPC notification … then exits". Measured on Neovim 0.12.5 (probes below): **a notification whose connection its peer closed before the editor handled it is dropped when the editor has a message of another channel to handle first.** In the suite, the busy-editor case lost the notification every time the test polled the woken child; with a plain `nvim --listen` and a probe client it was lost after a 2 s busy spell whenever one request came as the editor woke, and delivered when nothing else came; and with a real Neovim TUI in a terminal job (the user's own setup: the TUI is a client of its server), held at a hit-enter prompt and left with Enter, it was lost 3 times out of 3 — the brief's own named case. Keeping the connection open until the editor answers a request behind the notification delivered it every time (idle: 20 ms; at the prompt: once Enter came). But a hook that waits holds Claude Code's in-session `/resume` (M8, A3). So the hook now starts a detached deliverer and returns in about 20 ms; the deliverer waits. Rejected: the relay waiting itself (holds `/resume` for as long as a prompt lasts, then Claude Code's timeout kills it and the switch is lost); a bounded wait (the same loss after the bound). The plan's mutant 1 (a request in place of the notification) therefore no longer changes anything observable — the waiting moved out of Claude Code's way — and its observable is carried by m1 (the hook delivering itself) and m1c (the deliverer closing without waiting).

Not decided here: whether two deliverers can reach a busy editor out of order (a `SessionStart` before its `SessionEnd` would drop that switch). Idle, the 0.1 s between the two hooks (M1) and ~20 ms deliveries keep them in order; at a prompt, the order the editor accepts two pending connections in was not measured.

### The probes (Neovim 0.12.5, macOS; scripts under the worktree's `.tests/`, not committed)

```
t35-probe-busy.lua — the brief's relay, an editor sleeping 2 s, then polled by another channel every N ms
poll every 20   seen: not within 6 s
poll every 200  seen: not within 6 s
poll every none seen: after the sleep

t35-probe-busy.lua (second form)
1: after 2 s of polls 0 then after 3 s alone 0          (lost, not delayed)
2: idle editor, polled: seen after 0.027 ms
3: one request as it wakes 0 then 3 s alone 0           (lost)

t35-probe-hold.lua — a relay that holds its connection open N ms after notifying
hold 0, request on waking     seen 0, later 0; relay 19 ms
hold 3000, request on waking  seen 0, later 1; relay 3022 ms

t35-probe-hitenter.lua — a real TUI (`nvim --clean --listen …` in a terminal job) at a hit-enter prompt, Enter pressed after the relay ended
prompt true, hold 0: mode r blocking true; relay 20 ms, code 0; seen 0   (×3)
prompt false, hold 0: mode n blocking false; relay 22 ms, code 0; seen 1
prompt true, hold 3000: … relay 3024 ms; seen 0

t35-probe-confirm.lua — the relay waits for the answer to a request behind its notification; Enter pressed 1 s after it started
prompt true: relay 1007 ms, code 0; seen 1   (×3, 1004–1007 ms)
prompt false: relay 20 ms, code 0; seen 1

t35-probe-detached.lua — the hook starts a detached deliverer that does the same, and exits
prompt true: relay 21 ms, code 0; seen 1   (×3, 19–27 ms)
prompt false: relay 23 ms, code 0; seen 1
no deliverer left (pgrep)
```

## Unit list (stated before the first test)

1. `--settings` holds only `hooks`, one `SessionStart` and one `SessionEnd` command hook, no matcher, a timeout.
2. `--settings` right before `--allowedTools`, new and resumed.
3. `editor_address`, `editor_program`, `on_session_switched` malformed are named.
4. The relay tells its editor the event, the id, the source or reason and the token; nothing on stdout.
5. Input that is not an object with a string `session_id` tells nothing; exit 0.
6. `$NVIM` naming another editor, and unset: the editor on the command line is told.
7. An editor that cannot be reached: exit 0, nothing on stdout or stderr.
8. A busy editor: the relay ends at once, and the editor is told once free.
9. `session_id()`: nil before a start; the started id (new, resumed) with no hook.
10. `SessionEnd`(followed) + `SessionStart`(new): told once, followed, kept so the next start resumes it; a `SessionStart` of the followed id tells nothing.
11. Tells nothing: a `SessionStart` with no `SessionEnd` before it, a `SessionEnd` alone, a malformed id, an earlier start's token, Neovim quitting.
12. A start in place of the followed session: T19's fallback told and followed; a start in another directory told; a restart on the followed id tells nothing.
13. The hook reaches the editor with a space and a `'` in both paths.
14. Through the fake's keys: `/clear`, `/resume`, `/branch` reach the callback; `/compact` and an exit do not.

## Red and green

Counts: `tests/test_claude_switch.lua` 43 cases; `tests/test_claude.lua` 117 (114 + 3 rows); `tests/test_claude_resume.lua` 49, unchanged.

**Seen red (29):**
- `start_session()` › `gives Claude Code a SessionStart and a SessionEnd command hook as --settings, and no other setting` — `Left: {}` (no `--settings`).
- `tests/test_claude.lua` › `names the setting that is malformed` + `editor_address, 1` and `editor_program, false` — `attempt to index local 'word' (a number value)` / `(a boolean value)` where `settings%.editor_…` was expected; + `on_session_switched, 'a callback'` — `Observed no error`.
- `the hook relay` › `tells its editor the event, …` + `SessionStart, resume` and `SessionEnd, clear` — `Left: {}` (no relay file: it exited 1).
- `the hook relay` › `tells nothing of an input that is not an object with a string session_id, and exits 0` ×7 — `not JSON` and `''`: `Left: 1` (exit code); `[]`, a JSON string, `{}`, `session_id` 7 and null: the stand-in noted `{ "SessionStart", vim.NIL|7, … }` before the sentinel.
- `the hook relay` › `exits 0 and writes nothing when its editor cannot be reached` — `Left: { 1, "", "E5113: Lua chunk: Vim:connection failed: connection refused …" }`.
- `the hook relay` › `ends at once when its editor is busy, which is told once it is free` — red on the brief's relay, `Left: {}`: the notification lost while the test polled the woken child (the run before it failed on a fault of the test itself, the address read after the child was put to sleep; not counted).
- `session_id()` › `is nil before any session has started`, `is the new session’s id …`, `is the resumed session’s id …` — `attempt to call field 'session_id' (a nil value)`.
- `a session switch` › `is told once …`, `makes the session switched to the one followed`, `keeps the session switched to for the directory, …`, `is not made by a SessionStart of the session followed` (its sentinel switch: `Left: {}`) — no receiver yet.
- `a session switch` › `is not made to an id of another form than Claude Code’s` ×3, `is not made by a hook of an earlier start`, `is not followed while Neovim quits` — each switched (`Left` holding the switch; the quit case resumed `063cc43c-…`).
- `a start in place of the session followed` › `that a resume with no conversation makes is told once, …`, `in another directory is told as a switch …` — `Left: {}`.

`tests/test_claude.lua` › `passes no flag beyond …` is an existing pin that the change moved; it failed as expected (`left = "--settings", right = nil` at key 5) and was rewritten with the behaviour.

**Arrived green (17), each with the mutant that kills it on the final tree:**
- `puts --settings right before --allowedTools` ×2 — spent by unit 1, which placed it there; m4.
- `gives hooks that reach the editor when its program’s path and the relay’s path hold a space and a quote` — pinning code written ahead of its test (the quoting of unit 1); m13.
- `the hook relay` › `writes nothing on its stdout` — its first red was the missing relay's exit 1, not stdout; m14.
- `tells the editor on its command line, not the one NVIM names`, `… when NVIM is unset` — the relay read its argument from its first version; m5.
- `leaves nothing running once its busy editor has ended` — green by nature of the deliverer's request failing when the editor's socket closes; m18.
- `a session switch` › `is not made by a SessionStart of another session with no SessionEnd before it`, `is not made by a SessionEnd alone, as at Claude Code’s exit` — the `ending` condition was written with the first switch unit; m9 and m7.
- `is not made by a SessionStart of the session followed after its own SessionEnd` — added when m2a survived the group; m2a.
- `a start in place …` › `that a resume with no conversation makes is followed` — spent by unit 9 (`launch()` follows its start's id); m17. `that resumes the session followed tells nothing` — green by nature; m15.
- `through Claude Code’s keys` › `a switch reaches on_session_switched` ×3, `/compact reaches nothing`, `an exit reaches nothing` — the fake's hook code was written before these cases ran; their first run failed on the keys reaching the terminal before the fake put it in raw mode (`/compact\n`), a fault of the test, fixed by waiting for the start hook. m2 and m7 on that group, and the fake's own f1, f2, f3.

## Mutants

Run one at a time from a byte copy of the file (`.tests/t35-mutant.lua`: each edit must match its old text exactly once), each on the group of `tests/test_claude_switch.lua` that targets it (a copy of the file with every other group removed), on the final tree `07ae776`. Every kill below was read as an assertion (`Failed expectation`), its count equal to the run's `Fails`. The first pass of the final table ran into the host's DNS outage: m6, m8 and m9 hit the run's 960 s limit with one case done and printed `Fails (0)`, and m7's own-group output was overwritten before it could be checked; all four were run again on `07ae776` after the network came back, and finished.

| # | Literal edit | Plan's # | Group | Result |
|---|---|---|---|---|
| m1 | `hook_relay.lua`: `  start_deliverer(address, start_token, event, input)` → `  pcall(deliver, address, { event, input.session_id, input[CAUSE_FIELDS[event]] or vim.NIL, start_token })` (the hook delivers itself) | 1, as this design carries it | the hook relay | killed, 1: `ends at once when its editor is busy, …` (`Left: false`, the duration) |
| m1b | `hook_relay.lua`: `vim.rpcnotify(channel, 'nvim_exec_lua', RECEIVE_SESSION_EVENT, …)` → `vim.rpcrequest(…)` | 1, literally | the hook relay, then the whole file, then the whole suite (1975 cases) | **survived, equivalent**: the deliverer is detached and waits for an answer either way, so Claude Code waits for neither; the state measured is a busy editor, the one the mutant is about |
| m1c | `hook_relay.lua`: the line `vim.rpcrequest(channel, 'nvim_exec_lua', CONFIRMATION, {})` deleted | — | the hook relay | killed, 1: the busy-editor case (`Left: {}`, the notification lost) |
| m2 | `init.lua`: `elseif event == 'SessionStart' and id ~= session.followed and session.ending then` → `elseif event == 'SessionStart' then`, and `running.ending.reason` → `(running.ending or {}).reason` (so the callback fires instead of crashing) | 2 | a session switch; keys | killed, 3 (`… of the session followed`, `… after its own SessionEnd`, `… with no SessionEnd before it`); keys 5 |
| m2a | the same line → `elseif event == 'SessionStart' and session.ending then` | — | a session switch | killed, 1: `… of the session followed after its own SessionEnd` (the case added when it survived) |
| m3 | `init.lua`: `  keep_session_id(running.settings, id)` deleted in `follow_switch()` | 3 | a session switch | killed, 1: `keeps the session switched to for the directory, …` (it survives the keys group, which reads no kept id) |
| m4 | `arguments.lua`: `'--settings', hook_settings(…)` moved from before `'--allowedTools'` to after the tools (`vim.list_extend(words, { '--settings', hook_settings(settings, start_token) })`) | 4 | start_session() | killed, 2: both rows of `puts --settings right before --allowedTools` |
| m5 | `hook_relay.lua`: `start_deliverer(address, …)` → `start_deliverer(os.getenv('NVIM') or '', …)` | 5 | the hook relay | killed, 12: every case that waits for a notification, the NVIM-elsewhere and NVIM-unset cases among them |
| m6 | `init.lua`: `    or not session_ids.is_session_id(id)` deleted | 6 | a session switch | killed, 3: the three malformed ids (the switch fires and the next start does not resume `started_on`) |
| m7 | `init.lua`: after `session.ending = { reason = cause }`, `follow_switch(session, id, cause)` added | 7 | a session switch; keys | killed, 10; keys 5 (`an exit reaches nothing` among them) |
| m8 | `init.lua`: `    followed = choice.id,` deleted in `launch()` | 8 | session_id() | killed, 2: the new and the resumed session's id |
| m9 | `init.lua`: the condition → `elseif event == 'SessionStart' and id ~= session.followed then`, and `running.ending.reason` → `(running.ending or {}).reason` | 9 | a session switch | killed, 1: `… with no SessionEnd before it` |
| m10 | `init.lua`: `vim.v.exiting ~= vim.NIL\n    or not session` → `not session` | 10 | a session switch | killed, 1: `is not followed while Neovim quits` |
| m11 | `init.lua`: `tell_session_replaced(settings, left)` deleted in `start_new_session_in_place()` | 11 | a start in place … | killed, 1: `that a resume with no conversation makes is told once, …` |
| m12 | `init.lua`: `    or session.start_token ~= start_token` deleted | 12 | a session switch | killed, 1: `is not made by a hook of an earlier start` |
| m13 | `arguments.lua`: `return "'" .. word:gsub("'", [['\'']]) .. "'"` → `return "'" .. word .. "'"` | — | start_session() | killed, 1: the space-and-quote case |
| m14 | `hook_relay.lua`: `io.stdout:write('x')` after `local input = hook_input()` | — | the hook relay | killed, 2: `writes nothing on its stdout`, `exits 0 and writes nothing when its editor cannot be reached` |
| m15 | `init.lua`: `if left and left ~= session.followed and settings.on_session_switched then` → `if left and settings.on_session_switched then` | — | a start in place … | killed, 2: the fallback told once; `that resumes the session followed tells nothing` |
| m16 | `init.lua`: `local source = session.choice.resumed and 'resume' or 'startup'` → `local source = 'startup'` | — | a start in place … | killed, 1: `in another directory …` |
| m17 | `init.lua`: `followed = choice.id,` → `followed = session and session.followed or choice.id,` | — | a start in place … | killed, 3: the fallback told and followed; another directory |
| m18 | `hook_relay.lua`: the confirmation → `pcall(vim.rpcrequest, channel, 'nvim_exec_lua', CONFIRMATION, {})` then `vim.uv.sleep(20000)` | — | the hook relay | killed, 1: `leaves nothing running once its busy editor has ended` |
| m19 | `hook_relay.lua`: `if read and type(input) == 'table' and type(input.session_id) == 'string' then` → `if read and type(input) == 'table' then` | — | the hook relay | killed, 4: the rows `[]`, `{}`, `session_id` 7 and null |
| m20 | `init.lua`: `return session and session.followed` → `return session and session.followed or ''` | — | session_id() | killed, 1: `is nil before any session has started` |
| f1 | `fake_claude.lua`: `/branch`'s `switch_session(new_session_id(), 'fork', 'resume')` → `'fork', 'clear'` | — | keys | killed, 1: the `/branch` row |
| f2 | `fake_claude.lua`: `/resume`'s `switch_session(resumed, 'resume', 'resume')` → `'clear', 'resume'` | — | keys | killed, 1: the `/resume` row |
| f3 | `fake_claude.lua`: `run_hooks('SessionEnd', current_session_id, 'prompt_input_exit')` deleted in `exit_by_keys` | — | keys | killed, 1: `an exit reaches nothing` |

## Task lines

T35 — done (PR into `dev`, `feature/t35-session-switch`): every start of Claude Code passes `--settings` with only a `SessionStart` and a `SessionEnd` command hook (no matcher, timeout 5 s) before `--allowedTools`, running `lua/aineo/claude/hook_relay.lua` as the MCP relay is run with the editor's address, a per-start token and the event, every word shell-quoted; the hook starts a detached deliverer and exits in ~20 ms, and the deliverer notifies the editor and waits for an answer behind the notification (decided over the brief on measurement: Neovim 0.12.5 drops a notification whose peer closed first when another channel's message comes first — 3 of 3 at a hit-enter prompt); `aineo.claude` follows the started id (A2, `session_id()`), takes a switch as a `SessionStart` of another id after the followed id's `SessionEnd` (A1), keeps it for the directory (D38) and calls `on_session_switched(id, source, left, reason)`, and tells a start that replaces the followed session (T19's fallback, T35-1) the same way; hooks of another start, malformed ids and anything while quitting are dropped; the fake runs the hooks on `/clear`, `/resume`, `/branch`, `/compact` and an exit by keys; help in four places; 47 cases (43 new file, 3 rows, 1 pin moved); mutants in the session note; open: deliverers' order at a busy editor, the hit-enter measurement in the suite (no UI there).

## Open threads

- **For the orchestrator and the user:** the deliverer departs from the brief's relay (above). The plan's mutant 1 no longer has an observable; m1 and m1c carry it.
- **A Learning for the adjustment pass** (outside this packet's boundary): "Neovim 0.12.5 drops an RPC notification whose connection its peer closed before the editor handled it, when the editor has another channel's message to handle first" — the probes above. It bears on every relay that notifies and exits, the MCP relay's report path aside (it waits for an answer).
- Two deliverers reaching a busy editor out of order were not measured; a `SessionStart` taken before its `SessionEnd` drops that switch (the session stays the old one, as when hooks do not run).
- The suite cannot hold its child at a hit-enter prompt (no UI is attached), so the busy-editor case uses a sleeping child, which drops the brief's relay's notification the same way; the hit-enter case itself is in the probes only.
- The fake's hook input is the documented common fields plus the source or reason M1 measured; M1 did not record the whole input, so it is not a recording.
- `git merge-tree --write-tree` of this branch's head `6fb592a` with `origin/feature/t36-report-sessions` (`fe112c4`) and with `origin/feature/t37-changes-sessions` (`0442ade`): both clean, and `tests/test_doc.lua` 44 cases, `Fails (0)`, on each merged tree (W-2).

## Commits

*Recorded after the merge.*
