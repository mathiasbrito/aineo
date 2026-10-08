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

- **`lua/aineo/claude/arguments.lua`**: `claude_arguments(settings, start_token)` adds `--settings` before `--allowedTools`: one JSON object holding only `hooks`, with one `SessionStart` and one `SessionEnd` entry, each a `type: "command"` hook with no matcher and `timeout` 5 (seconds). The command is the hook relay run as aineo's MCP server is run — `<editor_program> --headless --clean --cmd 'set noloadplugins' -l <hook_relay.lua> <editor_address> <start token> <event>` — every word single-quoted for a POSIX shell, a `'` written `'\''` (T35-2). The timeout: Claude Code's documentation gives a command hook 600 s by default, and the `SessionEnd` hooks of an exit, a `/clear` or an in-session `/resume` 1.5 s in all, a budget a hook's own `timeout` raises (D-docs; the attack review read the same from the hooks page). 5 s is below the first and above the second: far above the hook's own run (20–43 ms, median 26 ms, in the attack review's 24 runs) and a Neovim start on a loaded host, so that a loaded host does not stop a `SessionEnd` hook before it has started its deliverer, which would lose that switch; in return, a hook that stalls holds `/clear` up to 5 s rather than 1.5 s. Whether a hook's own `timeout` lifts `SessionEnd`'s 1.5 s was read, not measured (the real `claude` is never run here).
- **`lua/aineo/claude/hook_relay.lua`** (new): the hook, and the composition root of its process. As the hook it reads stdin, and for an object with a string `session_id` starts itself again, detached (its own session, no standard stream), as the *deliverer*, then exits 0 — 20–43 ms (the attack review's 24 runs, median 26 ms). As the deliverer it sends the editor one RPC notification calling `require('aineo.claude').receive_session_event(event, id, source or reason, token)`, then waits for the answer to a request sent behind it on the same connection before closing; an editor it cannot reach, or that ends while it waits, ends it quietly (T35-10). It never writes on stdout or stderr, and reads the address from its command line, never `$NVIM`. See *Decided over the brief* for why the deliverer exists.
- **`lua/aineo/claude/init.lua`**: `Settings` gains `editor_address`, `editor_program` (both validated as strings) and the optional `on_session_switched(id, source, left, reason)`. Each `launch()` has a start token (a launch counter) and follows the id it started on (A2); `M.session_id()` returns the id followed now, nil before any start. `M.receive_session_event()` schedules `take_session_event()`, which drops anything while Neovim quits (`v:exiting`), for another start's token (T35-8), or for an id `session_ids.is_session_id()` refuses (M4); a `SessionEnd` of the followed id marks it ending with its reason; a `SessionStart` of another id after that mark is a switch (A1 as reworded, T35-4): `follow_switch()` follows the new id, keeps it for the directory (D38) and calls `on_session_switched`. A `SessionStart` of the followed id does nothing (it does not clear the mark: with one deliverer per hook, a late startup `SessionStart` must not cancel a switch). A start whose session differs from the one followed before it — T19's fallback (T35-1) and a later start in another directory — calls `on_session_switched(<new>, 'startup' | 'resume', <old>)` after `on_terminal_replaced`; an editor's first start calls nothing.
- **`lua/aineo/claude/session_ids.lua`**: `is_session_id()` exported, its check unchanged (M4).
- **`plugin/aineo.lua`** › `started_claude_terminal()`: hands `editor_address = vim.v.servername` and `editor_program = vim.v.progpath`. Nothing else (T39 wires the switch).
- **`tests/helpers/fake_claude.lua`**: with `AINEO_FAKE_CLAUDE_HOOKS` set it runs the `--settings` hooks through `sh -c`, the hook's JSON on stdin and the inherited `NVIM` in its environment (T35-3), waiting for each: `SessionStart` at start (`startup` / `resume`); `/clear`, `/resume <id>`, `/branch` as `SessionEnd` (`clear`, `resume`, `resume`) then `SessionStart` (`clear`, `resume`, `fork`); `/compact` as `SessionStart` (`compact`) alone; `SessionEnd` (`prompt_input_exit`) at an exit by keys only (T35-13). Each run is recorded as `{ hook, session_id, cause, code }`.
- **`tests/helpers/claude_session.lua`**: `editor_address`/`editor_program` in the stand-in settings; `start_noting_switches()`, `start_again_noting_switches()`, `wait_for_session_switches()`, `session_id()`, `hook_input()`, `hook_command()`, `run_session_hook()` (a hook run as Claude Code runs one), `wait_for_deliveries()` (no deliverer left for the child, then one scheduled round: the deterministic way to assert that nothing was called back).
- **Tests**: `tests/test_claude_switch.lua` (new, 43 cases), `tests/test_claude.lua` (+3 malformed-setting rows; the flag-count pin now names `--settings` and 11 words).
- **`doc/aineo.txt`**, the four places: *aineo-install* names 2.1.292 for the switch; *aineo-claude-session*'s last paragraph rewritten (D38); *aineo-report* "five additions", the hooks among them, beside a project's own hooks as M2 measured; LIMITS › `Session switches ~` (trust dialog, `allowManagedHooksOnly`, `disableAllHooks`, what was not seen, the deliverer).

## Decided over the brief, on measurement

**This departed from D36, the user's row, not only from the brief and the orchestrator's A3** (PR #137's records review, finding 1): D36 says the relay "sends the editor one RPC notification, never a request". The packet chose without the user; it should have reported a spec conflict. The user decided it on 2026-10-07 as **D43**, answering "Accept the helper (Recommended)": "the hook starts a detached deliverer that notifies the editor and waits for its answer, then exits, or exits when the editor is gone. It supersedes D36's \"one notification, never a request\"." The D row itself is written by the knowledge pass.

The brief's relay "sends the editor one RPC notification … then exits". Measured on Neovim 0.12.5 (probes below): **a notification whose connection its peer closed before the editor handled it is dropped when the editor has a message of another channel to handle first.** In the suite, the busy-editor case lost the notification every time the test polled the woken child; with a plain `nvim --listen` and a probe client it was lost after a 2 s busy spell whenever one request came as the editor woke, and delivered when nothing else came; and with a real Neovim TUI in a terminal job (the user's own setup: the TUI is a client of its server), held at a hit-enter prompt and left with Enter, it was lost 3 times out of 3 — the brief's own named case. Keeping the connection open until the editor answers a request behind the notification delivered it every time (idle: 20 ms; at the prompt: once Enter came). But a hook that waits holds Claude Code's in-session `/resume` (M8, A3). So the hook now starts a detached deliverer and returns in about 20 ms; the deliverer waits. Rejected: the relay waiting itself (holds `/resume` for as long as a prompt lasts, then Claude Code's timeout kills it and the switch is lost); a bounded wait (the same loss after the bound). The plan's mutant 1 (a request in place of the notification) therefore no longer changes anything observable — the waiting moved out of Claude Code's way — and its observable is carried by m1 (the hook delivering itself) and m1c (the deliverer closing without waiting).

Not decided here, and closed by the fix round: whether two deliverers can reach a busy editor out of order. The attack review measured the deliverers' own start-up as the race (arrival gap at idle 18–66 ms, each deliverer 43–106 ms from hook to arrival) and built a case that holds the `SessionEnd`'s delivery back; the fix round pairs the two by when their hooks ran (*Fix round*, F1).

### The probes (Neovim 0.12.5, macOS)

The scripts are kept for the knowledge pass in the orchestrator's local store, `.claude/local/orchestrator/t35-probes/` (copied there in the fix round from the author's worktree, with a README naming each); their outputs are below. The time in "seen after 0.027 ms" is from the relay's exit to the first poll.

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

Run one at a time from a byte copy of the file (`.tests/t35-mutant.lua`: each edit must match its old text exactly once), each on the group of `tests/test_claude_switch.lua` that targets it (a copy of the file with every other group removed), on the final tree `07ae776`. Every kill below was read as an assertion (`Failed expectation`), its count equal to the run's `Fails`. The first pass of the final table ran into the host's DNS outage: m6 and m9 hit the run's 960 s limit with one case done, printing `Fails (0)` and "still running when the run ended", m7 and m8 printed `Fails (1)` with one case done, and m7's own-group output was overwritten before it could be checked; all four were run again on `07ae776` after the network came back, and finished (corrected from the records review, finding 8). m1b's whole-suite run (1975 cases) finished at 07:54:46, before `a7448dd` and `07ae776` were committed, on a tree that differed from `07ae776` in tests only; its whole-file run kept no output. This table is the packet's, on `07ae776`; the fix round's mutants, on its own tree, are in *Fix round*.

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

## Fix round

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`), a fresh agent; resources `impl_t35_fix`. From `c2a6cee`, on PR #137's three reviews (attack, test integrity, records) and the user's answers of 2026-10-07. Neovim 0.12.5; the real `claude` never ran.

**The user's decisions** (the D rows are the knowledge pass's to write):
- **D43** — "Accept the helper (Recommended)": "the hook starts a detached deliverer that notifies the editor and waits for its answer, then exits, or exits when the editor is gone. It supersedes D36's \"one notification, never a request\"." The deliverer stays; D36 and D43 are named here, in the PR body and in the help's LIMITS where it states the mechanism.
- **D44** — "Merge them (Recommended)": "aineo reads your `--settings` (a file or inline JSON), adds its two hooks beside yours, and passes one `--settings`. Nothing of yours is dropped. If it cannot read yours, it starts Claude without its hooks and warns once, so switches aren't followed."

**The orchestrator's rulings, to report to the user as its assumptions:** attack finding 2 fixed by the reviewer's F1 (pair `SessionEnd` and `SessionStart` by when each hook ran); attack finding 3, A1 stands (a lost `SessionEnd` leaves that Claude Code's later switches unfollowed, said in LIMITS); attack finding 4, an `on_session_switched` that raises is caught and warned.

### What changed

- **D44, `arguments.lua`**: `claude_command(settings, session_words, start_token)` builds the whole command and replaces `claude_arguments()`. It finds the last `--settings` of `claude.cmd` (`--settings <value>` or `--settings=<value>`; Claude Code 2.1.292 reads the last, attack review, read from its binary), tells inline settings from a file as Claude Code 2.1.292 does (read from its binary, `sks()`: inline when, trimmed, it begins with `{` and ends with `}`), and takes a relative file name from Claude Code's working directory (as Claude Code 2.1.292 does: the re-measure read it from its binary, not run, `$F` → `kn()`: `f.resolve(process.cwd(), s)` at `eagerLoadSettings`, with no `~` expansion — *Fix round 2*), adds aineo's two entries after the user's own for each event, and passes one `--settings` in aineo's place before `--allowedTools`. A value it cannot read — a missing file, no JSON object, JSON that does not parse, `hooks` not an object, an event's entries not a list — leaves `claude.cmd` whole, adds no hooks, and `launch()` warns once: "aineo: cannot read claude.cmd's --settings (…): Claude Code starts without aineo's session hooks, so a session switch inside it is not followed". Empty JSON objects of the user's survive the round trip (measured: `vim.json.decode` marks them, `encode` writes `{}`).
- **F1, `hook_relay.lua` and `init.lua`** (the attack reviewer's `f1-fix.diff`, adopted red-first): the hook takes `vim.uv.hrtime()` as it begins and the deliverer passes it as `receive_session_event()`'s fifth argument; the receiver pairs a `SessionEnd` of the followed id and a `SessionStart` of another by when their hooks ran, whichever arrives first, keeping an early `SessionStart` until a `SessionEnd` whose hook ran before it; one whose hook ran before the `SessionEnd` is never a switch (A1). Without the time (an older relay) it pairs by arrival, as before.
- **Attack finding 4, `init.lua`**: `tell_switch()` calls `on_session_switched` under `pcall` and warns "aineo: on_session_switched failed: …", for a start, the fallback and a hook alike.
- Records: docstrings 5a (a failed swap calls neither callback, though `session_id()` names the new session), 5b, 5c; the relay's statement of the drop narrowed to what was measured; `HOOK_TIMEOUT_SECONDS` and the fake's default name the 1.5 s `SessionEnd` budget; `start_deliverer()` and `take_session_event()` take records past three parameters; the helper's `session_id(child)` is `followed_session_id(child)` (modularity §6). The probe scripts are in `.claude/local/orchestrator/t35-probes/`.
- Help: *aineo-config-claude.cmd* (widened by the fix-round brief), *aineo-report*'s fifth addition, LIMITS › *Session switches*.

### Findings

| Review | Finding | Outcome |
|---|---|---|
| attack | 1, a user's `--settings` overridden | fixed (D44): 4 merge rows, the user's hooks kept, 5 unread rows |
| attack | 2, pairing by arrival | fixed (F1): the late-`SessionEnd` case through a proxy, the reversed case, the ran-first case ×2, the hook-time pin |
| attack | 3, one lost `SessionEnd` deafens the process | not changed (A1 stands, the orchestrator's ruling); said in LIMITS and in `receive_session_event()`'s docstring |
| attack | 4, a raising callback | fixed: two cases, a start in another directory and a switch by hooks |
| attack | 5–10 | refuted by the review; nothing to do |
| tests | 1, the hit-enter mechanism unpinned | fixed: the reviewer's TUI case, killing r3 |
| tests | 2, `vim.wait(1500)` | fixed: the quit case waits for the deliverers, then a scheduled round; m10 killed |
| tests | 3, `leaves nothing running` vacuous | fixed: a deliverer seen running before `child.stop()`; r21 kills it |
| tests | 4, r6 and r7 | fixed: two cases |
| tests | 5, quoting | fixed: the fixture `switch-quoted it's $HOME "here"`; r10 killed |
| tests | 6, TCP | fixed: an editor on `serverstart('127.0.0.1:0')`; r5 killed |
| tests | 7, raised errors unseen | fixed: `post_case` checks `v:errmsg` on *a session switch*; m2crash killed by it |
| records | 1, D36 | named in the note (*Decided over the brief*), the PR body and the help; the D row is the knowledge pass's |
| records | 2, the Learning's wording | narrowed in the relay's docstring and *Open threads* |
| records | 3, the probes | copied to `.claude/local/orchestrator/t35-probes/` with a README |
| records | 4, what T35 makes false elsewhere (D36, D37, `plan.md` A3 and mutant 1, `brief-review.md`, P6, T39's brief, the hit-enter Learning) | not this packet's: the knowledge pass's, by the fix-round brief |
| records | 5, docstrings | 5a–5d fixed |
| records | 6, the timeout | both defaults and the trade-off in the note, `HOOK_TIMEOUT_SECONDS` and the fake |
| records | 7, `allowManagedHooksOnly` | the help says both clauses were read, not measured |
| records | 8, counts | corrected in this note and the PR body: 46 cases, not 47; the deep-require check prints 51 lines in 6 homes, each inside its own; m1b's suite run preceded `07ae776`; the m6–m9 wording |
| records | 9, the helper's name | renamed |

**Not done, out of this packet:** the D rows D43 and D44, `plan.md`'s A3 and mutant 1 text, T39's brief (the knowledge pass's). The tests reviewer's other note — after a `/resume` of the followed session itself (`SessionEnd` A, `SessionStart` A) the `SessionEnd` mark stays, so a later `SessionStart` with no `SessionEnd` and a later hook time is taken as a switch — is left open; with F1's hook times, a same-id `SessionStart` that ran after the mark could clear it, but no brief asked for it. Closed by *Fix round 2* (finding 2).

### Red and green, fix round

**Seen red, by unit, each for the intended reason:** the F1 receiver cases (reversed: `Left: {}`; end-first: a switch made); the hook-time pin (`Left: "userdata"`); the D44 cases ×9 (two `--settings`: `Left: 2`, and the user's word with aineo's JSON after it); the raising callback ×2 (`Left: false` from `pcall(start_session)`; `Left: {…, {}}`, no warning). **On the final test file against `c2a6cee`'s three production files**, 16 of the 21 new cases fail, each by assertion (`Fails (17)`, 17 `Failed expectation`: the raising-hook case fails twice, its own assertion and the `post_case` check): the 10 D44 rows (the list-file row among them), the hook-time pin, the proxy case, the reversed case, the end-first row and both raising-callback cases.

**Arrived green, 5 new cases and 5 changed ones, each with the mutant that kills it (run):** the start-first row (m9, m2crash), the TCP case (r5), the hit-enter TUI case (r3, m1, m1c), the mark-cleared case (r6), the other-session `SessionEnd` case (r7); changed: the quoting fixture (r10), the quit case's wait (m10), `leaves nothing running` (r21), the `post_case` check (m2crash), the list-file row (D11, which had survived the group before the row was added).

### Mutants, fix round

Each a literal edit on `2ad91a5`'s code (later commits change only docstrings, the help, a test row and this note), from a byte copy restored and checked after each (`.tests/t35fix/mut.py`), run alone on the copy of `tests/test_claude_switch.lua` narrowed to the group that targets it. Every kill below is an assertion: each run's `Failed expectation` count equals its `Fails`.

| # | Literal edit | Group | Result |
|---|---|---|---|
| FM1 | `init.lua`: `      follow_switch(session, early.id, early.source)` deleted | a session switch | killed, 2: the proxy case, the reversed case |
| FM2 | `init.lua`: `if ending and (not ending.ran or not told.ran or ending.ran < told.ran) then` → `if ending then` | a session switch | killed, 1: the end-first row |
| FM3 | `hook_relay.lua`: `    tonumber(ran) or vim.NIL,` → `    vim.NIL,` | the hook relay; a session switch | killed, 1 (hook-time pin); 1 (proxy case) |
| FM4 | the same line → `    vim.uv.hrtime(),` (the deliverer's own time) | the hook relay; a session switch | killed, 1 (hook-time pin); survived the switch group |
| D1 | `arguments.lua`: `for index = #cmd, 1, -1 do` → `for index = 0, 1, -1 do` | start_session() | killed, 9 |
| D2 | `return { cmd = vim.list_extend(cmd, settings.cmd, given.last + 1), settings = merged }` → `return { cmd = settings.cmd, settings = merged }` | start_session() | killed, 5 |
| D3 | `local path = vim.startswith(value, '/') and value or vim.fs.joinpath(cwd, value)` → `local path = value` | start_session() | killed, 1: the relative file |
| D4 | `if not (vim.startswith(text, '{') and vim.endswith(text, '}')) then` → `if true then` | start_session() | killed, 3 |
| D5 | `vim.list_extend(given, { entry })` → `vim.list_extend({ entry }, given)` | start_session() | killed, 1: the user's hooks kept |
| D6 | the unread return gains `settings = add_hook_entries(vim.empty_dict(), entries),` | start_session() | killed, 4 |
| D7 | `init.lua`: `if unread then` → `if false then` | start_session() | killed, 4 |
| D8 | `if not is_object(settings.hooks) then` → `if false then` | start_session() | killed, 1 |
| D9 | `if type(given) ~= 'table' or not vim.islist(given) then` → `if type(given) ~= 'table' then` | start_session() | killed, 1 |
| D10 | `elseif vim.startswith(cmd[index], JOINED_SETTINGS_FLAG) then` → `elseif false then` | start_session() | killed, 1: the joined form |
| D11 | `if not is_object(settings) then` → `if false then` | start_session() | survived the group; killed, 1, by the list-file row added for it |
| A1 | `init.lua`: `pcall(settings.on_session_switched, …)` → `true, settings.on_session_switched(…)` | a session switch; a start in place | killed, 1 (+ its `post_case`); 1 |
| A2 | `if not told then` → `if false then` | a session switch; a start in place | killed, 1; 1 |
| r3 | `hook_relay.lua`: the confirmation → `vim.rpcrequest(channel, 'nvim_get_mode')` | the hook relay | killed, 1: the hit-enter TUI case |
| r5 | `local mode = address:match('^[^/]+:%d+$') and 'tcp' or 'pipe'` → `local mode = 'pipe'` | the hook relay | killed, 1: TCP |
| r21 | `start_deliverer(address, start_token, { … })` → `local _ = start_deliverer` | the hook relay | killed, 16, `leaves nothing running` among them |
| m10 | `vim.v.exiting ~= vim.NIL\n    or not session` → `not session` | a session switch | killed, 1: the quit case, with the deterministic wait |
| r6 | `  running.ending = nil` deleted | a session switch | killed, 1: the mark-cleared case |
| r7 | `if told.event == 'SessionEnd' and told.id == session.followed then` → `if told.event == 'SessionEnd' then` | a session switch | killed, 1: the other-session case |
| r10 | `arguments.lua`: `return "'" .. word:gsub(…) .. "'"` → `return '"' .. word .. '"'` | start_session() | killed, 1: the quoting case |
| m2crash | `if ending and (…) then` → `if not ending or ending.ran < told.ran then` (follow_switch then indexes a nil `ending`) | a session switch | killed, 8; the no-`SessionEnd` case by its `post_case` (`Left` the scheduled callback's error) |
| m1 | the hook delivers itself: `start_deliverer(…)` → `pcall(deliver, address, { …, ran })` | the hook relay | killed, 3: busy (duration), leaves nothing running, hit-enter |
| m1c | the confirmation request deleted | the hook relay | killed, 2: busy, hit-enter |
| m2 | `elseif told.event == 'SessionStart' and told.id ~= session.followed then` → `elseif told.event == 'SessionStart' then` | a session switch; keys | killed, 1; survived the keys group |
| m3 | `  keep_session_id(running.settings, id)` deleted | a session switch | killed, 1 |
| m4 | `--settings` moved after the tools (`return claude_settings and vim.list_extend(words, { SETTINGS_FLAG, … }) or words`) | start_session() | killed, 2 |
| m5 | `start_deliverer(os.getenv('NVIM') or '', …)` | the hook relay | killed, 16 |
| m6 | `    or not session_ids.is_session_id(told.id)` deleted | a session switch | killed, 3 |
| m7 | `follow_switch(session, told.id, told.cause)` added after the `ending` mark | a session switch; keys | killed, 16; 5 |
| m8 | `    followed = choice.id,` deleted | session_id() | killed, 2 |
| m9 | `if ending and (…) then` → `if true then`, and `running.ending.reason` → `(running.ending or {}).reason` | a session switch | killed, 7 |
| m11 | `tell_session_replaced(settings, left)` deleted in `start_new_session_in_place()` | a start in place | killed, 1 |
| m12 | `    or session.start_token ~= told.start_token` deleted | a session switch | killed, 1 |

D1's and D6's counts (9 and 4) were taken on the group before the list-file row was added; on this round's final group they kill 10 and 5 (the re-measure, finding 9).

Summary: 37 mutants; 36 killed by assertion on their group, D11 killed once its row was added; FM4 and m2 each survive one of their two groups and die on the other. The fix round ran none of m13–m20 or f1–f3 again: their code is unchanged, and the packet's table killed each.

### Counts (Neovim 0.12.5, host)

- `tests/test_claude_switch.lua` 64 cases (43 + 21), `tests/test_claude.lua` 117, `tests/test_claude_resume.lua` 49, `tests/test_doc.lua` 44, each `Fails (0)`.
- Whole suite on `ac5d6a4` (the code and tests pushed): 1996 cases, 61 groups, `Fails (0)`; on `d3c9be2`, before a docstring correction, the same. `dev` was 1929; the packet left 1975.
- `make lint` clean; the deep-require check prints 51 lines, each inside its own home (changes 9, claude 5, git 15, layout 1, mcp 7, report 14).
- `git merge-tree --write-tree` of `d3c9be2` with `origin/feature/t36-report-sessions` (`199910a`) and with `origin/feature/t37-changes-sessions` (`0442ade`): both clean; `tests/test_doc.lua` 44, `Fails (0)`, on each merged help.

## Fix round 2

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`), a fresh agent; resources `impl_t35_fix2`. From `83a5029`, on the re-measure of PR #137 after its first fix round (its findings 1–9). Neovim 0.12.5 on the host; the real `claude` never ran; nothing was written outside the worktree (a probe of Neovim's temporary directory ran with `TMPDIR` inside it).

**The orchestrator's rulings, to report to the user as its assumptions:**
- **Finding 1:** the merged settings go into a file only the user can read and write (0600), in Neovim's own temporary directory (`vim.fn.tempname()`), and `--settings` names that file. Nothing of the user's settings reaches argv. With no `--settings` in `claude.cmd`, aineo's own hooks stay inline. This still meets D44's words ("passes one `--settings`"); the file is a mechanism the user has not seen.
- **Finding 4:** the unread-settings warning is one line of at most 60 characters; where the reason (a long path, the parser's words) does not fit, it is left out — it is left out always, since the short line is 60 characters.
- **No decision IDs in the user manual:** "(D36, D43)" is gone from `doc/aineo.txt`; the IDs stay in this note and the PR body. The one other `D#` in the help, `` `(D18, C12, #31)` `` in *aineo-report*, is kept: it is an example of how a report writes references, quoted from the instructions aineo gives Claude (`lua/aineo/report/instructions.lua`, pinned by `tests/test_report.lua`), not a citation of aineo's decisions. Flagged for the orchestrator.

### What changed

- **Finding 1, `arguments.lua`:** `settings_with_hooks()` writes the merged settings with `write_private_file()`: `vim.uv.fs_open(vim.fn.tempname(), 'wx', 0600)`, written whole or refused. A file that cannot be written counts as unread: `claude.cmd` passes whole, no hooks, one warning. `claude_arguments()` takes the `--settings` word, not a table. Measured on 0.12.5 (`.tests/fx2/tempdir-probe.lua`, `TMPDIR` in the worktree): the per-process directory `rwx------`, its parent `nvim.<user>` `rwx------`, the file `rw-------`; after Neovim exits only the shared `nvim.<user>` is left. A Neovim ended by a signal leaves the file in its 0700 directory (not measured).
- **Findings 2 and 7, `init.lua`:** the receiver no longer keeps a mark and a list of early starts. Each start holds the hooks it was told (`unpaired`) until a switch pairs them, in the order their hooks ran — `ran_before()`, by the hook's `hrtime`, or by the order they reached the editor where one gives none (an `arrival` counter, `hooks_received`): the first `SessionEnd` of the session followed and the first `SessionStart` whose hook ran after it are a switch, none when that `SessionStart` is of the same id (a `/resume` of it), and every hook that ran up to that `SessionStart` is let go (`follow_switches()`, a loop, so that two switches resolve in turn). The reviewer's measured patch (`fix-init.diff`) was adopted red-first for U1–U3, and then replaced: under it, a `SessionEnd` of the session switched to that reached the editor before that session's `SessionStart` was dropped, so two switches in that order still ended on the first (row 2 of the out-of-order case, red under it by assertion).
- **Finding 3, the help:** *aineo-config-claude.cmd* says a `--settings` a wrapper script adds itself is not among `claude.cmd`'s words, so aineo cannot see it and Claude Code 2.1.292 reads aineo's, the last; "A wrapper works" became "Claude Code started through another program works, its words all in the list" (the `npx` example).
- **Finding 4:** `SETTINGS_UNREAD_WARNING`, "aineo: claude.cmd's --settings unread; switches not followed" (60 characters), the reason no longer computed (`read_settings()`, `add_hook_entries()` and `write_private_file()` return nil, `claude_command()` returns a boolean). Measured at 80×24 by a case in `tests/test_entry_startup.lua`: the line shows and Neovim is in Normal mode, not blocking; on the head the same case fails by assertion. The help's *The 80-column start* says so.
- **Finding 5:** the N2 pin (three rows: file, JSON, joined) and the N1 pin, the re-measure's, in the start group; and a merge row for inline JSON with blanks around it, which kills N3.
- **Finding 6:** the warning comes from `start_session()`, once per call, from the start's `settings_unread`; `launch()` no longer warns, so T19's fallback start does not warn again.
- **Finding 8:** `regular_file_text()` reads a file only when `fs_stat` says it is a regular file (a symbolic link to one is followed): a FIFO no longer holds the start, and a directory or a device gives the short warning.
- **Finding 9:** the record in *Fix round* › *What changed* now says how 2.1.292 resolves a relative `--settings` (the re-measure's reading of its binary, not run: against `process.cwd()`), and `read_settings()`'s docstring says aineo's `cwd` is where Claude Code resolves one from; under the first round's mutant table, D1's and D6's counts on the final group (10 and 5).
- **The help's IDs:** "(D36, D43)" removed from LIMITS › *Session switches*.
- **A flake, found on the way:** *the hook relay* › *tells an editor held at a hit-enter prompt* waited for the socket file, which exists from `bind()`, before Neovim listens; its first connection was refused once in six runs of the file (`Vim:connection failed: connection refused`). It now waits, bounded, for a connection that succeeds (`connect_when_listening()`); six runs alone, all green. `tests/helpers/report_tui.lua:92` has the same wait; outside this round's files, left as an open thread.

### Red and green, fix round 2

**Unit list, stated before the first test:** U1 a `SessionStart` alone after a `/resume` of the session followed is no switch (through the hooks); U2 the same, its `SessionStart` reaching the editor first; U3–U4 two switches out of order end on the last session (the re-measure's order, then the second session's `SessionEnd` before its `SessionStart`); N2 and N1 pins; U8 a 1.5 MB settings file starts Claude Code; U9 nothing of the user's settings on argv; U10 the file is 0600; U11 the file is gone once Neovim exits; U12 a file that cannot be written is unread; U13 the short warning; U14 no prompt at 80×24; U15 a FIFO does not hold the start; U16 the fallback does not warn again; then the help and the records.

**Seen red, each its own step, each by assertion:** U1 (`Left: { { { id = "063cc43c…", reason = "resume", source = "fork" … } }, "063cc43c…" }`, a switch made); U2 (the same, reversed); U3 (`left = nil` at the second switch: stuck on the first new session); U4, red under the reviewer's patch (the same); U8 (`Left: 0`, the fake never started); U10 (`Left: "rw-r--r--"`); U12 (`Left: { {}, 0 }`); U13 (six rows: the long message with its reason); U15 (`started` 0, the start held until the test opened the FIFO's other end); U16 (two warnings).

**On the final test files against `83a5029`'s `arguments.lua` and `init.lua`** (`.tests/fx2/red_at_head.sh`, restored and checked): `tests/test_claude_switch.lua` fails 26 of its then 85 cases — 20 by assertion (the 15 new cases red there and the 5 unread rows changed for the short warning) and 6 by a crash (`E484`), the six rows that now read the file `--settings` names, changed by design; `tests/test_entry_startup.lua` fails the 80-column case by assertion.

**Arrived green, each with the mutant that kills it (run):** the reversed-order row (spent by U4; R3, R4, R7); the two untimed rows (pin the arrival-order fallback, kept from the head through U4's rewrite; R5 and R8 kill the first, R5b the second); the N2 pins (N2: file and JSON rows, the joined row by D10) and the N1 pin (N1) — pins the re-measure built; U9 ×2 (spent by U8; P1); U11 (green by nature, Neovim removes its temporary directory; P1, P3); U14 (spent by U13; W3); the directory and device rows (spent by U13 and U15; P7, W1); the blanks row (pins the trim; N3); the same-moment case (pins `<`; R6).

### Mutants, fix round 2

Literal edits on `ba53337`'s code (the next commit adds only a test case), each from a byte copy restored and checked (`restored True` every run, `.tests/fx2/mutants.py`, log `.tests/fx2/mutants.log`), each on a copy of the test file narrowed to the group that exercises it. Every kill is an assertion (`Fails` = `Failed expectation`) except where a crash count is named.

| # | Literal edit | Group | Result |
|---|---|---|---|
| N1 | `arguments.lua`: `  for index = #cmd, 1, -1 do` → `  for index = 1, #cmd do` | start | killed, 1: the N1 pin |
| N2 | `      return { first = index, last = index + 1, value = cmd[index + 1] }` → `…last = index, …` | start | killed, 3: two N2 rows, U9 as JSON |
| N3 | `  local text = vim.trim(value)` → `  local text = value` | start | killed, 1: the blanks row |
| D1 | `  for index = #cmd, 1, -1 do` → `  for index = 0, 1, -1 do` | start | killed, 21 by assertion (22 fails, 1 crash) |
| D3 | `    text = regular_file_text(vim.startswith(value, '/') and value or vim.fs.joinpath(cwd, value))` → `    text = regular_file_text(value)` | start | killed, 1 |
| D4 | `  if not (vim.startswith(text, '{') and vim.endswith(text, '}')) then` → `  if true then` | start | killed, 9 by assertion (10 fails, 1 crash) |
| D9 | `    if type(given) ~= 'table' or not vim.islist(given) then` → `    if type(given) ~= 'table' then` | start | killed, 1 |
| D10 | `    elseif vim.startswith(cmd[index], JOINED_SETTINGS_FLAG) then` → `    elseif false then` | start | killed, 2 |
| D11 | `  if not decoded or not is_object(settings) then` → `  if not decoded then` | start | killed, 1 |
| P1 | `  local file = merged and write_private_file(vim.json.encode(merged))` → `  local file = merged and vim.json.encode(merged)` | start | killed, 6 by assertion (U8, U9 ×2, U10, U11, U12; 7 crashes of the rows that read the file) |
| P2 | `vim.uv.fs_open(path, 'wx', PRIVATE_FILE_MODE)` → `vim.uv.fs_open(path, 'wx', 420)` | start | killed, 1: U10 |
| P3 | `  local path = vim.fn.tempname()` → `  local path = vim.fs.joinpath(vim.fn.stdpath('state'), 'aineo-settings-' .. vim.uv.hrtime())` | start | killed, 2: U11, U12 |
| P4 | the `if not file then return nil end` after `fs_open` deleted | start | killed, 1: U12 |
| P5 | `  if written ~= #text then` → `  if false then` | start | **survived**: a short write needs a full disk or a file-size limit; not built, said in *Open threads* |
| P6 | `  if not stat or stat.type ~= 'file' then` → `  if not stat then` | start | killed, 1: U15 |
| P7 | `    return { cmd = settings.cmd, unread = true }` → `    return { cmd = settings.cmd }` | start | killed, 9 |
| W1 | `init.lua`: `  if session.settings_unread then` → `  if false then` | start | killed, 9 |
| W2 | the warning moved back into `launch()` (deleted from `start_session()`, added after `claude_command()`) | in place | killed, 1: U16 |
| W3 | `SETTINGS_UNREAD_WARNING` → the head's long sentence | 80-column start | killed, 1: U14 |
| R1 | `    if start.id ~= running.followed then` → `    if true then` | switch | killed, 3: U1, U2, the same-after-end case |
| R2 | the start's filter gains `and event.id ~= running.followed` (the head's mark left by a same-id start) | switch | killed, 3: the same |
| R3 | `running.unpaired = vim.tbl_filter(…)` → `running.unpaired = {}` | switch | killed, 3: the three out-of-order rows |
| R4 | `    if is_wanted(event) and (not first or ran_before(event, first)) then` → `    if is_wanted(event) and not first then` (N5's analog: first in arrival order) | switch | killed, 1: the reversed row |
| R5 | `  return earlier.arrival < later.arrival` → `  return false` | switch | killed, 1: untimed row 1 |
| R5b | the same line → `  return true` | switch | killed, 1: untimed row 2 |
| R6 | `    return earlier.ran < later.ran` → `    return earlier.ran <= later.ran` | switch; whole file | survived both; killed, 1, by the same-moment case added for it |
| R7 | `      return event.event == 'SessionEnd' and event.id == running.followed` → `      return event.event == 'SessionEnd'` | switch | killed, 2 |
| R8 | `  hooks_received = hooks_received + 1` deleted | switch | killed, 1: untimed row 1 |
| R9 | `follow_switch(running, start.id, start.cause, ending.cause)` → `…, start.cause, start.cause)` | switch; whole file | survived the group (its switches give equal source and reason); killed, 1, on the whole file by *through Claude Code's keys* (`/branch`: `resume`, `fork`) |
| m6 | `    or not session_ids.is_session_id(told.id)` deleted | switch | killed, 3 |
| m12 | `    or session.start_token ~= told.start_token` deleted | switch | killed, 1 |
| m10 | `    vim.v.exiting ~= vim.NIL\n    or not session` → `    not session` | switch | killed, 1 |
| m3 | `  keep_session_id(running.settings, id)` deleted | switch | killed, 1 |
| r3 | `hook_relay.lua`: the confirmation → `vim.rpcrequest(channel, 'nvim_get_mode')` | relay | killed, 1: the hit-enter case, with its new connection wait |

The re-measure's survivors: N1, N2, N3 die by assertion; N5's line is gone with the early starts, and R4, its analog in the new code, dies. Summary: 34 mutants; 33 killed by assertion on their group or file (R6 once its case was added, R9 on the whole file), P5 survives (named), and none of FM1–FM4, r6, r7, m2, m9, N4 or the first round's D2, D5–D8 applies any more as a literal edit (their lines are gone).

### Counts, fix round 2 (Neovim 0.12.5, host)

- `tests/test_claude_switch.lua` 87 cases (64 + 23), `tests/test_entry_startup.lua` 29 (28 + 1), `tests/test_claude.lua` 117, `tests/test_claude_resume.lua` 49, `tests/test_doc.lua` 44, each `Fails (0)`.
- **Whole suite** on `4c2fe7e` (the code and tests pushed): 2020 cases, 61 groups, `Fails (0) and Notes (0)`, exit 0.
- `make lint` clean; the deep-require check prints 51 lines, as before (no require added).
- `git merge-tree --write-tree` of `4c2fe7e` with `origin/dev` (`aa3cb74`, T36 merged in it as PR #135) and with `origin/feature/t37-changes-sessions` (`9690b5a`): both clean; `tests/test_doc.lua` 44, `Fails (0)`, on each merged help.

### Branch commits, fix round 2

`94956ac` (the code, tests and help), `ba53337` (the N3 row), `4c2fe7e` (the same-moment case), and the commit of this section — pre-merge hashes, which the rebase merge replaces; the merged ones go in *Commits*.

## Correction

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`), a fresh agent; resources `impl_t35_correction`. From `e738bf7`, on the second re-measure of PR #137 (`.claude/local/orchestrator/remeasure2-137/remeasure2-t35.md`, its findings 1–8), the orchestrator's correction brief naming exactly what to do. Neovim 0.12.5 on the host; the real `claude` never ran; nothing written outside the worktree but Neovim's own temporary directory, which the suite's children use as before.

**The orchestrator's ruling, to report to the user as its assumption — finding 5:** the one-line start warning stays as it is, and `:checkhealth aineo` reports an unreadable or unusable `--settings` in `claude.cmd`, with the reason. This widened the packet's boundary to `lua/aineo/health.lua` and `tests/test_health.lua`.

### What changed

- **Finding 1, `init.lua`:** a start records when its process ended (`ended_at`, `vim.uv.hrtime()`), and a hook whose hook began after that is refused (`take_session_event()`): an exit's held `SessionEnd` no longer pairs with a later `SessionStart` that a teammate or a background session — started by Claude Code with this start's `--settings`, so with aineo's hooks — tells. The re-measure's two-line fix (`fix-exit.diff`), adopted red-first with its case.
- **Finding 2:** the re-measure's three pins, adopted: a symbolic link planted at the next `tempname()` is not written through (kills P8), a write cut short under a 256 KiB file size limit passes the user's `--settings` as it is with the warning (kills P5), a symbolic link to a regular file is merged (kills P9). The fake reads a `--settings` value that is not inline JSON as a file, as Claude Code 2.1.292 tells them apart (`settings_text()`), and a `/clear` runs through hooks in such a file end to end.
- **Finding 4, `arguments.lua`:** a settings file beginning with a UTF-8 byte order mark, an empty one, and one of blanks alone are read as Claude Code 2.1.292 reads them (the mark dropped; blanks an empty object) and merged (the re-measure's `fix-bom.diff`, the mark a named constant).
- **Finding 5, `arguments.lua`, `init.lua`, `health.lua`:** the readers return why they refuse (`regular_file_text()`, `read_settings()` with the settings' source, `hooks_problem()` split out of `add_hook_entries()`, `settings_taking_hooks()`); what a start does is unchanged. `aineo.claude` exports `given_settings_verdict(cmd, cwd)`; `health.lua` requires `aineo.claude` (the direction table allows it) and, when `claude.cmd` gives a `--settings`, reports either "claude.cmd's --settings takes aineo's session hooks" or a warning naming why, read from the editor's working directory. Whether the private file can be written is not checked. The check now loads the `aineo.claude` home: the passive-check case lists the homes loaded, `aineo.claude` among them, instead of every module.
- **Finding 6:** `write_private_file()` unlinks its file after a short write. LIMITS › *The settings file* says a Neovim killed by SIGKILL leaves the 0600 file, the user's settings in it; a hangup and SIGTERM remove it (the re-measure's `lifetime.out`). This also answers fix round 2's "(not measured)".
- **Findings 1, 3 and 7, the help:** LIMITS › *Session switches* says teammates and background sessions are given the `--settings`, aineo's hooks among them, and that hooks after the exit are ignored; *The settings file* says Claude Code reads the file once, and that teammates and background sessions, and their restarts, read it again at their own start and fail once Neovim has removed it (read in 2.1.292's binary by the re-measure, not run); *aineo-config-claude.cmd* says a wrapper's `--settings` before aineo's words is overridden and one after them, after `"$@"`, overrides aineo's hooks without a warning, and points at `:checkhealth`. The removal at exit is kept: a durable file under `stdpath('state')` was the re-measure's alternative, left to the orchestrator, and the brief asks for the help.
- **Finding 8:** the PR body's own-red count, re-measured on round 2's final switch file (below).

### Red and green, correction

**Unit list, stated before the first test:** C1 a `SessionStart` whose hook ran after Claude Code exited is no switch; C2 the P8, P5 and P9 pins; C3 the fake reads a settings file, and a `/clear` through one; C4 a settings file with a byte order mark, empty, or of blanks is merged; C5 no partial file after a short write; C6 health: the ok line, the warning with each reason, a relative path from the editor's working directory; then the help, the records.

**Seen red, each its own step:** C1 by assertion (`followed` the other id, one switch, the next start resuming it); C3 by a crash, the missing behaviour itself (`Can't send data to closed stream`: the fake died decoding a path as JSON); C4 by assertion, 3 of 3 (the user's path passed as it was); C5 by assertion (file `1` left in the temporary directory); C6's ok line by assertion, and its nine reasons by assertion, 9 of 9.

**Arrived green, each with the mutant that kills it (run):** the three pins of C2 (code written in fix round 2: P8, P5, P9); C6's relative path (pins the `getcwd()` the check passes: H1); C7, a switch whose hooks ran before the exit but reach the editor after it is followed (added when X3 survived the switch group: pins the direction of C1's comparison; X3). The passive-check case was changed, not added: it now names homes.

### Mutants, correction

Literal edits on the final code (`a5d3295`'s production files; later commits change the help and tests only), each applied from a byte copy, run, restored and checked (`restored True` on every row; `.tests/cor/mut.py`, log `.tests/cor/mut.log`), on a copy of its test file narrowed to the group that exercises it; a survivor then on the whole switch file. "Killed, n" counts `Failed expectation` lines; every kill is an assertion unless a crash is named.

| # | Literal edit | Run on | Result |
|---|---|---|---|
| X1 | `init.lua`: `      launched.ended_at = vim.uv.hrtime()` deleted | switch (28) | killed, 1: C1 |
| X2 | `    or (session.ended_at and told.ran and told.ran > session.ended_at)` deleted | switch (28) | killed, 1: C1 |
| X3 | `told.ran > session.ended_at` → `told.ran < session.ended_at` | switch (28); C7 | survived the group; killed, 1, by C7 |
| R4 | `    if is_wanted(event) and (not first or ran_before(event, first)) then` → `    if is_wanted(event) and not first then` | switch | killed, 1 |
| R12 | the same line → `… (not first or ran_before(first, event)) then` | switch | killed, 2 |
| R13 | `      return ran_before(start, event)` → `      return ran_before(ending, event) and event ~= start` | switch; whole file | survived the group, the whole file (97) and the whole suite (2041) — 3 runs of the suite: one exited 2 with `Fails (0)` in its saved output and no failing case named, two exited 0; not a kill. Near-equivalent, as the re-measure said |
| r8 | `  vim.schedule(function()\n    take_session_event({` → `  local run_now = function(f)\n    f()\n  end\n  run_now(function()\n    take_session_event({` | switch; whole file | survived the group, the whole file and the whole suite (round 1's low survivor) |
| N1 | `arguments.lua`: `  for index = #cmd, 1, -1 do` → `  for index = 1, #cmd do` | start (35) | killed, 1 |
| N2 | `      return { first = index, last = index + 1, value = cmd[index + 1] }` → `…last = index, …` | start | killed, 3 |
| N3 | `  local trimmed = vim.trim(value)` → `  local trimmed = value` (the re-measure's N3 on the renamed line) | start | killed, 1 |
| W4 | `    vim.notify(SETTINGS_UNREAD_WARNING, vim.log.levels.WARN)` → `…INFO)` | start | killed, 11 |
| P5 | `  if written ~= #text then` → `  if false then` | start | killed, 2: the short-write pin and C5 |
| P8 | `vim.uv.fs_open(path, 'wx', PRIVATE_FILE_MODE)` → `vim.uv.fs_open(path, 'w', PRIVATE_FILE_MODE)` | start | killed, 1: the planted-link pin |
| P9 | `  local stat, stat_problem = vim.uv.fs_stat(path)` → `…fs_lstat(path)` | start | killed, 1: the symbolic-link pin |
| P10 | `  vim.uv.fs_close(file)\n  if written` → `  if written` | start; whole file | survived the group, the whole file and the whole suite (one leaked descriptor per start; near-equivalent) |
| U1 | `    vim.uv.fs_unlink(path)` deleted | C5 | killed, 1 |
| B1 | `    text = text:sub(#BYTE_ORDER_MARK + 1)` deleted | C4 (3) | killed, 1 |
| B2 | `  if vim.trim(text) == '' then\n    return vim.empty_dict(), nil, source\n  end` deleted | C4 (3) | killed, 2 |
| A1 | `  problem = hooks_problem(settings, source)` → `  problem = nil` | start | killed, 2 |
| A2 | `    if given and not (type(given) == 'table' and vim.islist(given)) then` → `    if false then` | start | killed, 1 |
| A3 | `  if not settings.hooks then\n    return nil\n  end` deleted (in `hooks_problem()`) | start | killed, 15 by assertion (16 fails, 1 crash) |
| A5 | `  return { problem = problem }` → `  return {}` | C6 (10) | killed, 9 |
| FK | `fake_claude.lua`: `  return table.concat(vim.fn.readfile(value), '\n')` → `  return value` | C3 | killed, 1: its start-hook check |
| H1 | `health.lua`: `given_settings_verdict(command, vim.fn.getcwd())` → `given_settings_verdict(command, '/')` | C6's relative case | killed, 1 |
| H2 | `  if verdict.problem then` → `  if false then` | C6 (10) | killed, 9 |
| H3 | `  if verdict == nil then\n    return\n  end` deleted | Claude Code (34) | killed, 15 |
| r1 | `hook_relay.lua`: `    detached = true,` deleted | relay (18); whole file | survived the group, the whole file and the whole suite (round 1's low survivor) |
| r13 | `tell_session_replaced(settings, left)` moved before `on_terminal_replaced` | in place (6); whole file | survived the group, the whole file and the whole suite (round 1's low survivor) |

**Summary: 28 mutants — 23 killed by assertion (X3 by C7, added for it), 5 survive the whole suite: R13 and P10, near-equivalent, and r8, r1, r13, round 1's low survivors, none in this correction's brief.** The re-measure's P5, P8 and P9 now die on their pins.

**Finding 8, re-measured** (`.tests/cor/red83.py`: `e738bf7`'s `tests/test_claude_switch.lua` and fake, against `83a5029`'s `arguments.lua` and `init.lua`, swapped from byte copies and restored): 27 of 87 fail — 20 by `Failed expectation`, 7 by `E484` — as the re-measure counted. The PR body now says so; *Red and green, fix round 2* above keeps its "then 85", which was true of the file at that step.

### Counts, correction (Neovim 0.12.5, host)

- **Whole suite** on `3d77a20` (the code and tests pushed; the next commit is this note): 2041 cases, 61 groups, `Fails (0) and Notes (0)`, exit 0. Fix round 2's head `4c2fe7e` was 2020.
- `tests/test_claude_switch.lua` 97 (87 + 10), `tests/test_health.lua` 92 (81 + 11), `tests/test_claude.lua` 117, `tests/test_claude_resume.lua` 49, `tests/test_entry_startup.lua` 29, `tests/test_doc.lua` 44 — each from that run, `Fails (0)`.
- `make lint` clean; the deep-require check prints no line from outside a home (one new edge, `health.lua` → `aineo.claude`, an entry point, which the direction table allows).

### Open threads, correction

- **For the orchestrator and the user:** finding 5's ruling is an assumption; the user has not seen the health line. The check now loads `aineo.claude` (the passive-check case changed to name homes).
- Not closed by finding 1's fix: a teammate's or background session's `SessionStart` that lands inside the ~0.1 s between a live switch's two hooks (the re-measure's note).
- The settings file's removal at exit stays; teammates and background-session restarts after Neovim exits fail (help, LIMITS). A durable 0600 file under `stdpath('state')` would avoid it, at the cost of the removal — the orchestrator's call.
- The health check's "measured on Claude Code 2.1.281" line predates T35's 2.1.292 facts (the re-measure's note for records; not this correction's).

## Task lines

T35 — done (PR #137 into `dev`, `feature/t35-session-switch`): every start of Claude Code passes one `--settings` holding a `SessionStart` and a `SessionEnd` command hook (no matcher, timeout 5 s) before `--allowedTools` — added after the hooks of a `--settings` in `claude.cmd`, inline or a regular file, the two together written to a 0600 file in Neovim's temporary directory that the one `--settings` names, nothing of the user's on argv (D44; the file, the orchestrator's ruling); one aineo cannot read, add to or write passes as it is, without aineo's hooks, with one 60-character warning per start — running `lua/aineo/claude/hook_relay.lua` as the MCP relay is run with the editor's address, a per-start token and the event, every word shell-quoted; the hook starts a detached deliverer and exits in 20–43 ms, and the deliverer notifies the editor, naming when its hook began, and waits for an answer behind the notification (D43, superseding D36's "never a request", on measurement: Neovim 0.12.5 drops a notification whose sender closed first when the editor could not run it at once and a channel connected earlier has a message waiting — 3 of 3 at a hit-enter prompt); `aineo.claude` follows the started id (A2, `session_id()`), takes a switch as the first `SessionStart` of another id whose hook ran after the followed id's `SessionEnd`, holding hooks until they pair, in whatever order they reach the editor (A1, F1; a same-id `SessionStart` pairs it with no switch), keeps it for the directory (D38) and calls `on_session_switched(id, source, left, reason)`, an error of which is warned and goes no further, and tells a start that replaces the followed session (T19's fallback, T35-1) the same way; hooks of another start, malformed ids and anything while quitting are dropped; the fake runs the hooks on `/clear`, `/resume`, `/branch`, `/compact` and an exit by keys; help in four places and `claude.cmd`; 91 cases (87 in the new file, 3 rows, 1 pin moved, 1 in the startup file); mutants in the session note; open: a lost `SessionEnd` leaves that Claude Code's later switches unfollowed (A1); the correction refuses hooks that ran after the start's Claude Code exited, reads a settings file with a byte order mark or of blanks, removes a partial file, reports an unusable `--settings` of `claude.cmd` with its reason in `:checkhealth aineo` (the orchestrator's ruling), and adds 10 cases to the new file (97) and 11 to `tests/test_health.lua` (92).

## Open threads

- **For the orchestrator and the user:** the deliverer departs from the brief's relay (above). The plan's mutant 1 no longer has an observable; m1 and m1c carry it.
- **A Learning for the adjustment pass** (outside this packet's boundary), worded as narrowly as the records review measured it (finding 2): "Neovim 0.12.5 drops an RPC notification whose sender closed the connection before the editor ran it, when the editor could not run it at once (busy, or at a hit-enter prompt) and a channel connected earlier has a message waiting too: the TUI's keys, another client's request or notification. Keep the connection open until the answer to a request sent behind the notification arrives." A channel connected *after* the closed one did not cause the loss (3 of 3 delivered), and a connection held open delayed the notification rather than losing it. [[Learnings/An RPC request to a Neovim at a hit-enter prompt waits until it is answered]] should link to it. It bears on every relay that notifies and exits, the MCP relay's report path aside (it waits for an answer).
- ~~Two deliverers reaching a busy editor out of order were not measured~~ — measured by the attack review and closed by the fix round's F1 (*Fix round*).
- ~~The hit-enter case is in the probes only~~ — the fix round adopted the test-integrity review's case, a real TUI in a terminal job of the child, held at a hit-enter prompt (*Fix round*).
- **Fix round 2, left open:** ~~P5 — a short write of the settings file is refused, but no case makes one~~ — pinned by the correction (a 256 KiB file size limit). A `SessionStart` that reaches the editor after a later `SessionStart` can still be paired too late: after `SessionEnd(A)`, a fork's `SessionStart(B)` that arrives before the `/resume`'s own `SessionStart(A)` is taken as the switch — the order cannot be known without waiting, and neither the re-measure's patch nor this round's receiver waits. ~~The settings file of a Neovim ended by a signal stays in its 0700 directory (not measured)~~ — measured by the second re-measure: SIGKILL only; in LIMITS since the correction. `tests/helpers/report_tui.lua:92` waits for a socket file as the hit-enter case did, which can refuse the first connection; outside this round's files. ~~The fake reads its hooks from inline `--settings` only~~ — it reads a file since the correction, and a `/clear` runs through one.
- The fake's hook input is the documented common fields plus the source or reason M1 measured; M1 did not record the whole input, so it is not a recording.
- `git merge-tree --write-tree` of this branch's head `6fb592a` with `origin/feature/t36-report-sessions` (`fe112c4`) and with `origin/feature/t37-changes-sessions` (`0442ade`): both clean, and `tests/test_doc.lua` 44 cases, `Fails (0)`, on each merged tree (W-2).

## Commits

*Recorded after the merge.*
