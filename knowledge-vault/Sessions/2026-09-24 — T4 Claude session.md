# 2026-09-24 — T4 Claude session

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t4-claude-session` · **Pull request:** #11, into `dev`
**Fix round:** after the attack, test-integrity and records reviews of PR #11 (head `17d84e4`), by a second implementer agent on the same branch; its work is under *Fix round* below.

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C3; D2, D8, D10, D11, D13; R1, R2, Q4, F6)
- [[Implementation/Waves/00002-layout-session-report/plan]] and its brief `brief-t4-claude-session.md`
- [[Learnings/Claude Code's interactive CLI in a Neovim terminal]] — the measurements the waits rest on
- Evidence used: `Implementation/Waves/00002-layout-session-report/evidence/` — `t4-summary.txt`, `t2-summary.txt`, `t4-screens.txt`, `t4-trust-dialog-screen.txt`, `t4-claude-2.1.281-startup-paste-exit.bytes.txt`, and, in the fix round, `t2-run2-screens.txt` (the permission dialog and the prompt after it) and the orchestrator's recording of the MCP-server approval dialog (2.1.281, 2026-09-24 09:37 CEST), copied into `tests/fixtures/claude/`

## Context

**Goal:** T4 — "Claude session (C3): start, flags, environment, readiness, restart, stop on quit, and the fake `claude` its suites run" — asked for by the user on 2026-09-24 ("Plan also the implementation of the plumbing of the claude agent with his window on the left … after planning implement it"). T4 runs beside T5 by injection: `aineo.claude` requires no other home; the composition root (T7) hands it the MCP servers, the tools to pre-allow and the instructions.

## What was done

**`lua/aineo/claude/`** — a home of four files behind `init.lua`, as it stands after the fix round:

- `init.lua` — `start_session(settings)` and `session_status()`. One Claude Code at a time; a start while one runs returns its buffer; a start after it exited — or after its terminal was wiped — launches a new terminal, puts it in every window that showed the old one, then wipes the old one. Settings are validated with `vim.validate`, `cwd` as a directory that exists; a command that cannot run leaves no buffer and raises an error naming the command, `jobstart()`'s own or, under `:silent!`, aineo's. Registers the stop on `VimLeavePre` (augroup `aineo.claude`) whenever it starts a process.
- `arguments.lua` — `--mcp-config <json>`, `--append-system-prompt <text>`, `--allowedTools <tool>…`; an empty server map and an empty or missing server `env` are written as JSON objects.
- `readiness.lua` — ready while the screen's rows show Claude Code's input box (a rule, the line opening with `❯`, a draft's continuation lines, a rule) and it has shown unbroken for 1.5 s; not ready while a dialog takes its place; read again at every change of the buffer (`nvim_buf_attach`'s `on_lines`).
- `stop.lua` — one Ctrl-C, wait 2.5 s; Ctrl-C, 0.3 s, Ctrl-C, wait 4 s; `jobstop()`, wait 5 s. Returns as soon as Claude has exited; bounded at 11.8 s; each wait runs to its deadline through a Ctrl-C pressed in the editor; never raises.

**Tests** — `tests/test_claude.lua` (45 test functions, one parametrized nine ways: 53 cases), the helper `tests/helpers/claude_session.lua`, the fakes `tests/helpers/fake_claude.lua` (`nvim --clean -l`, raw mode by `stty`; modes `ready`, `trust`, `trust-in-two-writes`, `mcp-server`, `asks`, `asks-at-once`, `draft`, `verbose`, `busy`, `exit`) and `tests/helpers/fake_claude_deaf.sh` (POSIX sh), and the fixtures under `tests/fixtures/claude/`: `startup-2.1.281.bytes` (the first 1540 bytes of the recording, cut before the frame with the Remote Control link), `trust-dialog-2.1.280.screen`, `mcp-server-dialog-2.1.281.bytes`, `permission-dialog-2.1.281.screen`, `permission-denied-2.1.281.screen` and `draft-2.1.281.bytes`, each with a header naming its version, date and source.

**Suite:** 111 cases before the packet, 145 after it, 164 after the fix round, each `Fails (0)`; the fix round's full run took 196 s on this Mac. `make lint` clean. The modularity deep-require check prints three lines, all `lua/aineo/claude/init.lua` requiring its own `arguments`, `readiness` and `stop`.

## Decisions & reasoning

Each bullet is marked **reading** — sent to the MVP review, listed once under *Readings for the MVP review* — or **the packet's own**, a choice about the code or its tests that changes nothing the user sees.

- **Readiness settle: 1.5 s** after the input box appears, unbroken (**reading**; the wave plan's item 14). It is the only wait before input any measured run used; no shorter one was tried. It is how long Send (C4) will refuse input after the prompt shows.
- **Readiness is Claude Code's input box on the screen now** (**reading**; the orchestrator's decision 1, refined in the fix round): a rule, a line opening with `❯`, the lines a draft continues on (two spaces in), and a rule — among the screen's rows only. Every recorded dialog carries `❯` on an indented choice between no rules, so none reads as ready: the 2.1.280 trust dialog (`❯ No, exit` selected), the 2.1.281 MCP-server approval dialog and the 2.1.281 permission dialog. The packet first recognised the trust dialog by the words "trust this folder"; the fix round replaced that — see *Fix round*.
- **A session that was ready and shows a dialog reports `'starting'` again** (**reading**): S4 names three states, and no fourth (such as "asking") was added.
- **Stop timings** (**reading**; S7, the plan's item 7), derived from the phases measured on 2.1.281: the single press then 2.5 s (the one stop measured in a turn pressed the double Ctrl-C 2.5 s later and exited; how soon a turn ends was not measured); the double press 0.3 s apart (0.3 s exits, 1.2 s does not); 4 s for the exit (1.6 and 2.5 s after the second press in the two runs); `jobstop()` then 5 s; 11.8 s at most. **Quitting with Claude idle takes about 4.4–5.3 s — computed from the stop's own waits (2.8 s) plus the exit measured after a double press (1.6–2.5 s), not measured end to end**; with the fake, 4.4 s.
- **The fallback's wait is measured, not guessed** (the packet's own; Nvim 0.11.6, this Mac): a terminal job that ignores the hangup survives `:qa` as an orphan; after `jobstop()` Neovim sends SIGTERM at 2.0 s and SIGKILL at 4.0 s. So the stop waits 5 s after `jobstop()`, and no Claude outlives the editor.
- **The deaf fake is POSIX sh** (the packet's own). A `nvim -l` script cannot ignore a hangup: it exited 1 within 2 ms of `jobstop()` whatever its own handler did. With such a fake the fallback is indistinguishable from Neovim's own exit, which hangs every terminal up. The sh fake ignores keys, the hangup and SIGTERM — a stuck process — so only the fallback's wait ends it. **It departs from S8's recording contract:** it records `{"argv":[],"pid":…}` — an empty list, not the arguments it was started with — and only its Ctrl-C bytes, not every byte it receives.
- **The fake's modes** (**reading**, as the orchestrator routed it): `exit`, which shows the startup screen and exits with a chosen code (S5 needs an exit code other than 0, and S4 an exit inside the settle), and the fix round's `trust-in-two-writes`, `mcp-server`, `asks`, `asks-at-once`, `draft` and `verbose`.
- **The working directory is an argument** (**reading**): `settings.cwd`, not a read of the editor's, since the home reads no ambient state; T7 passes `getcwd()`. Since the fix round it must name a directory that exists, or the start is refused naming `settings.cwd` (records R9: chosen over only rewording the docstring).
- **Show the new buffer before Claude draws** (the packet's own; T7's obligation). A terminal started in a hidden buffer gets the size of Neovim's autocommand window — 5 rows at 80 columns, measured — where the recorded screen loses its prompt; `jobstart()`'s `width` and `height` are ignored for a terminal. Shown in the same tick, the process first saw the window's size (22 rows, measured by the packet); the attack review measured the same when the buffer was shown from a `vim.schedule()` callback, so "the same tick" is enough but more than needed. The docstring says so.
- **`--allowedTools` comes last, one word per tool** (**reading**): Claude Code's CLI reference (`cli-reference.md`, as the packet saved it on 2026-09-24) gives that flag a three-tool example of several words, and calls `--mcp-config`'s values space-separated; that a multi-word flag takes the following words up to the next flag is inferred from those examples, not stated. `--mcp-config`'s one word is followed by a flag.
- **The terminal buffer is unlisted** (**reading**; `nvim_create_buf(false, true)`): `:bnext` does not land on it. Pinned since the fix round.
- **A running session whose terminal was wiped counts as ended** (**reading**; fix round): a start then launches a new Claude Code while the old one is being hung up by the wipe, and `start_session()` never returns the wiped buffer.
- **The Lua fake never reopens its terminal** (the packet's own). After the mutant runs three fakes were found alive as orphans (PPID 1), up to an hour old; sampled, each sat in `luv_new_tty` → `uv_tty_init` → `open()`, the reopen libuv makes of a terminal by its path, blocked because Neovim had closed the terminal while the fake started. Neovim's own handlers in the fake catch the hangup and SIGTERM, so only a SIGKILL ends such a process, and all three came from runs with no stop registered (before S7, and the `noquit` mutant). The fake that sets raw mode with `stty` and uses pipes on descriptors 0 and 1 ended within 11 ms of each hang-up in the one sweep whose output was kept (31 hang-ups, every 4 ms of its first 120 ms; `t4-probe-race-out.txt` in the orchestrating session's scratchpad). **Corrected in the fix round:** the packet recorded "within 9 ms after each of 93" — the kept sweep shows 11 ms (`delay 12 ms: code=1 after 11 ms`) — and "7 of 217 hang-ups needed about 2 s" with `vim.uv.new_tty()`; the other sweeps' outputs were overwritten, so the 93, the 9 ms and the 7 of 217 are unverifiable. No suite test pins it: the window is a race a test would hit only some of the time. Node's terminal streams go through the same libuv call, so a real Claude hung up in its first milliseconds may behave alike (an inference, not measured); the 5 s fallback wait leaves room for Neovim's SIGKILL.

## Readings for the MVP review

The choices the packet and its fix round made where the rows and the brief were silent, each named once; the Task line and the pull request list the same nine.

1. **S4 settle** — Claude Code counts as ready 1.5 s after its input box shows, unbroken (the plan's item 14).
2. **S4 readiness signature** — ready while the screen shows Claude Code's input box (a rule, the `❯` line, a draft's lines, a rule); not ready while a dialog takes its place (trust, MCP-server approval, permission); ready again when it returns; only the screen's rows are read.
3. **S4 state after a dialog** — a session that was ready reports `'starting'` while a dialog shows.
4. **S7 stop timings** — one Ctrl-C, 2.5 s; a double Ctrl-C 0.3 s apart, 4 s; `jobstop()`, 5 s; 11.8 s at most; about 4.4–5.3 s to quit with Claude idle, computed from the stop's waits plus the measured exit, not measured end to end (the plan's item 7).
5. **The unlisted terminal buffer.**
6. **`--allowedTools` last, one word per tool.**
7. **`cwd` as an argument** (`settings.cwd`, which T7 fills with `getcwd()`), refused unless it names a directory that exists.
8. **A wiped running terminal ends the session**: a start then launches a new Claude Code.
9. **The fake's modes**: `exit`, and the fix round's `trust-in-two-writes`, `mcp-server`, `asks`, `asks-at-once`, `draft` and `verbose`.

## Red, green and mutants — the packet

**Units, in the order they were written** — 29 test functions, 34 cases (one function parametrized six ways; the packet's note first said 28 functions): 28 cases seen red, 6 arrived green. The suite went from 111 cases to 145.

Seen red, each for the missing behaviour:

1. runs the command in a new terminal buffer — `module 'aineo.claude' not found`
2. runs the command in the directory it is given — the fake's cwd was the checkout
3. gives Claude the MCP servers as one `--mcp-config` — no such word (`{}`)
4. writes the env of a server without variables as a JSON object — the text held `"env":[]`
5. pre-allows each tool it is given with `--allowedTools` — `{}`
6. appends the instructions to the system prompt byte for byte — `{}`
7. marks the process with `AINEO_CHILD=1` — `vim.NIL`
8. returns the running session instead of starting another — buffer 3, expected 2
9. `session_status()` is starting as soon as the session starts — `attempt to call field 'session_status'`
10. reports nothing before a session starts — `{ "starting" }`
11. is exited, with the exit code — `{ "starting" }`, expected `{ "exited", 3 }`
12. is ready once the prompt shows with no trust dialog — `{ "starting" }` (a second failure after the first green step was the test harness: a hidden terminal is 5 rows high and the replayed prompt did not fit; the helper now shows the buffer at once, as the layout will)
13. stays starting for a moment after the prompt shows — `{ "ready" }`
14. never becomes ready behind the workspace-trust dialog — `{ "ready" }`
15. starts Claude again in a new terminal once it has exited — the same buffer
16. shows the new terminal in every window that showed the old one — `{}`, expected `{ 1002, 1000 }`
17. wipes the terminal of the Claude that exited — valid
18. starts Claude again after the old terminal was wiped — `Invalid buffer id: 2` from `nvim_buf_delete`
19. quitting Neovim stops an idle Claude by a double Ctrl-C — `{ ended = "hangup", code = 129 }`: **what `:qa` did before this change**
20. ends a turn with one Ctrl-C before the double Ctrl-C — turn interrupted, then `hangup` 129 (only the double press existed)
21. leaves no Claude that ignores its keys and the hangup running — first written against a `nvim -l` deaf mode and a record of how it ended, seen red with no fallback (only `sighup` recorded); rewritten when that fake proved unable to ignore a hangup, and seen red in its final form with a 3 s wait after `jobstop()`: the sh fake was alive, an orphan of PPID 1
22. leaves nothing behind but the error when the command cannot run — 2 buffers, expected 1
23–28. names the setting that is malformed, and starts nothing (`cmd` string, `cmd` empty, `cwd`, `mcp_servers`, `allowed_tools`, `instructions`) — errors from `jobstart()` and `vim.list_extend`, and no error at all for `instructions = false`

Arrived green, each with the mutant that kills it (run on the packet's final head, below):

- passes each word of the command to the process unchanged — `jobstart()` given a list, spent by unit 1 — `shell`
- passes no flag beyond the servers, the instructions and the tools — spent by units 3, 5, 6 — `flag`
- gives the process the editor's server address as `NVIM` — Neovim's own for every job — `nvim`
- passes every other variable of the editor on unchanged — `jobstart()`'s `env` extends — `clearenv`
- leaves the terminal showing Neovim's exit line — Neovim's own — `wipeonexit`
- is not ready once Claude has exited, even right after its prompt — spent by unit 11's order — `order`

Renamed in the fix round, as the design they pin changed: 12 is now *is ready once its input box shows*, and 13 *stays starting for 1.2 s after the prompt shows* (its assertion now holds 1.2 s, not one round trip).

**The packet's mutant table** — at the packet's final code head (the commit "Stop the fake claude from hanging when its terminal closes early"), literal edits, one at a time, each file copied aside and restored byte for byte, each run as `make test_file FILE=tests/test_claude.lua`; kinds read from mini.test's output. The scripts and logs (`t4-make-mutants.lua`, `t4-mutant.sh`, `t4-run-mutants.sh`, `t4-mutant-<label>.txt`, the summary `t4-mutants-summary-final.txt`) were in the orchestrating session's scratchpad and are not kept in the vault. Re-run on the fix round's head in the table under *Fix round*.

| Label | File | Literal edit | Killed by (kind) |
|---|---|---|---|
| **M4** | `arguments.lua` | `{ env = vim.empty_dict() }` → `{ env = {} }` | writes the env of a server without variables as a JSON object (assertion) |
| **M5** | `readiness.lua` | `… ~= nil and screen:find(TRUST_DIALOG, 1, true) == nil` → `… ~= nil` | never becomes ready behind the workspace-trust dialog (assertion) |
| **M6** | `stop.lua` | delete `{ keys = CTRL_C, then_wait_ms = 2500 },` | ends a turn with one Ctrl-C before the double Ctrl-C (assertion); leaves no Claude … running (assertion: 2 presses, not 3) |
| shell | `init.lua` | `jobstart(command, options)` → `jobstart(table.concat(command, ' '), options)` | passes each word … unchanged (assertion: nil — through the shell the instructions' quotes and newline break the command, so no fake starts; 23 cases fail) |
| flag | `arguments.lua` | add `'--permission-mode', 'acceptEdits',` before `'--allowedTools',` | passes no flag beyond … (assertion) |
| nvim | `init.lua` | `{ AINEO_CHILD = '1' }` → `{ AINEO_CHILD = '1', NVIM = 'elsewhere' }` | gives the process the editor's server address as NVIM (assertion) |
| clearenv | `init.lua` | add `clear_env = true,` after `env = CHILD_ENVIRONMENT,` | passes every other variable … (assertion: nil — the fake cannot start without its record variable; 22 cases fail) |
| wipeonexit | `init.lua` | after `launched.exit_code = exit_code` add `vim.schedule(function() vim.api.nvim_buf_delete(launched.buffer, { force = true }) end)` | leaves the terminal showing Neovim's exit line (assertion); also two restart tests |
| order | `init.lua` | check `session.ready` before `session.exit_code` in `session_status()` | is not ready once Claude has exited … (assertion) |
| wipefirst | `init.lua` | `nvim_buf_delete(buffer, …)` moved before the `win_findbuf` loop | shows the new terminal in every window that showed the old one (assertion) |
| nofallback | `stop.lua` | delete `vim.fn.jobstop(job)` and its `vim.wait` | leaves no Claude that ignores its keys and the hangup running (assertion) |
| shortwait | `stop.lua` | `EXIT_AFTER_HANGUP_MS = 5000` → `3000` | leaves no Claude … running (assertion) |
| nosettle | `readiness.lua` | `SETTLE_MS = 1500` → `0` | stays starting for a moment after the prompt shows (assertion) |
| nocleanup | `init.lua` | drop `vim.api.nvim_buf_delete(buffer, { force = true })` from the failed-start branch | leaves nothing behind but the error … (assertion) |
| noguard | `init.lua` | delete the `nvim_buf_is_valid` early return in `replace_terminal()` | starts Claude again after the old terminal was wiped (assertion: `expect.no_error`) |
| noquit | `init.lua` | delete the `stop_on_quit()` call in `start_session()` | the three quit tests (assertion) |
| novalidate | `init.lua` | delete the `settings.instructions` validation | names the setting that is malformed, `instructions` (assertion) |
| deadreturn | `init.lua` | `if is_running() then` → `if session then` in `start_session()` | starts Claude again in a new terminal … (assertion); wipes the terminal … (assertion) |
| trustword | `readiness.lua` | `TRUST_DIALOG = 'trust this folder'` → `'no such dialog text'` | never becomes ready behind the workspace-trust dialog (assertion) |

**Tally:** 19 mutants, 19 killed by an assertion — as on the table's second run, before the fake's fix. Its first run found two weak spots, fixed in "Keep a failed session test from stopping the whole run" before the second: under `shell` and `clearenv` the teardown's Ctrl-C raised inside `MiniTest.finally()`, which stalled the run instead of failing a test; and `noguard` was killed by a crash. The review of PR #11 then found six survivors of its own edits (test-integrity) and one of the attack review's (`4000 → 50`); all are re-run below.

## Fix round

Worked as one round from the three review reports of PR #11 at `17d84e4` and the orchestrator's thirteen decisions, by an implementer agent in a fresh context; every production change driven by a test seen red first.

**What changed, and why.**

- **Readiness (attack A1, A2, A7; decision 1).** A dialog drawn in two writes read as ready (A1: the settle fired on a screen seen once); the 2.1.281 MCP-server approval dialog read as ready (A2 — its recording, taken by the orchestrator on 2026-09-24, confirmed the render the attack review could not); readiness never went away once set, so a permission dialog after ready still read as ready (the attack review's note for T6); and every buffer change joined the whole scrollback (A7). Readiness is now the input box on the screen's rows, read again at every change, with the settle dropped by any change that takes the box away.
- **Two parts of decision 1 refuted, with recorded evidence.** (a) *A rule directly below the prompt line*: the 2.1.281 frame after a two-line bracketed paste (`draft-2.1.281.bytes`, from `t4-claude-2.1.281-startup-paste-exit.bytes.txt`) and the message a mid-turn Ctrl-C returns to the box (`t4-screens.txt`, MIDTURN-ONE) put a continuation line between the prompt line and the rule; under "directly below" the session read as not ready with a draft in the box (the red of *is ready with a draft of several lines in the prompt*). The box now takes a draft's continuation lines. (b) *No trust text, no "Enter to confirm"*: the box's shape alone rejects every recorded dialog, so no test could be red for want of the words, and the words would read a draft or a transcript holding them as a dialog. The old trust-text condition was dropped while green, so the wave plan's M5 has no literal target on this head; its intent — readiness that a dialog cannot satisfy — is the mutant `glyphalone` below.
- **The stop (attack A3, A4, A8; decisions 2, 3, 6).** A Ctrl-C pressed in the editor ended every `vim.wait()` at once, so a busy Claude was hung up (129) and a deaf one outlived the editor (A3); each wait now runs to its own deadline, on a libuv timer rather than the attack review's clock, through such presses. A key sent to a terminal that had closed while its exit was not yet seen raised in `VimLeavePre`, which skipped every later exit handler (A4); the stop now goes on to the hang-up (the attack review's `fix-closed-channel.diff`). The test was first written with the attack review's `bdelete! | qall` reproduction and seen red with it; the round's own mutant run then showed that reproduction no longer reaches the stop — in Neovim 0.11.6 `:bdelete!` makes a terminal buffer invalid (probe: `valid=false`), and a wiped terminal now ends the session — so the guard's mutant survived. The test now closes the channel the attack review's other way (its finding 4, fifth case): an earlier `VimLeavePre` handler that stops every job ("Close Claude's terminal by an earlier exit handler in the stop test"). The fake exits 1.6 s after a double press, the faster of the two recorded exits (test-integrity F4, attack A8), so the 4 s wait is pinned.
- **The start (attack A6, A9; records R9; the test-integrity note on wiped buffers).** A start under `:silent!` whose `jobstart()` returned -1 wedged the session (A6); a result of 0 or -1 is now a failed start (the attack review's `fix-jobstart.diff`). A terminal wiped while Claude ran kept counting as running until its `on_exit`, so `start_session()` returned the wiped buffer; a wiped terminal now ends the session. A missing `cwd` raised Neovim's E475, naming neither setting nor command (R9); it is now refused naming `settings.cwd`. An empty server map encoded as `[]`, and an entry without `env` raised (A9); both now encode as objects.
- **Tests (test-integrity F1–F6, adopted as measured).** F1 `child.cmd('new')` in the restart-windows test; F2 the exact argument count, 7; F3 the idle quit ends the editor (`jobwait`); F4 above; F5 the deaf fake's whole process group gone; F6 a folder named `~/trusted/aineo`. Also the unlisted buffer, a non-string element of `cmd` and of `allowed_tools`, the settle held for 1.2 s, and the crash kills of finding 8 turned into expectation failures (a nil pid, a wiped buffer's `'buftype'`, the arrange state of the restart-after-wipe test).
- **Records (R2, R3, R5, R7, R8, R9, R10, R11, R12).** Docstrings name each Claude Code behaviour's version and state raw mode as unmeasured (Q4); "Press Ctrl-C again to exit" is the recorded 2.1.281 screen (the byte recording holds it after the first Ctrl-C at a prompt with a draft), which answers R2's point that no screen showed a second-press request. They name versions and in-repository fixtures, not the vault's evidence files: `documentation-discipline` keeps working documents out of docstrings. R3 — the false "within 9 ms" — is corrected above and in the commit "Correct T4's records and the race figures 1123943 stated", not by rewriting `1123943`, which is pushed.

**Seen red — 12 cases**, each for the missing behaviour:

1. never becomes ready behind a dialog drawn in two writes — `{ "ready" }`, expected `{ "starting" }` (A1)
2. never becomes ready behind the MCP-server approval dialog — `{ "ready" }` (A2)
3. is not ready while a permission dialog asks the user — `{ "ready" }`, expected `{ "starting" }`
4. is ready with a draft of several lines in the prompt — `{ "starting" }`, expected `{ "ready" }` (under the "directly below" rule)
5. is ready soon after a long output before the prompt — `{ "starting" }` after 5 s with the whole buffer scanned; the file took 86 s (A7)
6. ends a turn by keys though Ctrl-C is pressed in the editor meanwhile — `code` 129, expected 0 (A3)
7. lets later exit handlers run when Claude's terminal has just closed — `{}`, expected `{ "ran" }` (A4; seen red with `bdelete! | qall`, before the wiped-terminal change; its final form, an earlier handler stopping every job, fails under the mutant `nosendguard`)
8. starts Claude after a start that failed under `:silent!` — the fake never started (A6)
9. returns a live terminal when the running one was just wiped — `false`, expected `true`
10. names the setting that is malformed, `cwd = '/nonexistent/aineo/directory'` — `Vim:E475: Invalid argument: expected valid directory` did not match `settings%.cwd` (R9)
11. writes an empty map of servers as a JSON object — `'{"mcpServers":[]}'` (A9)
12. writes an empty env for a server that names no env — `vim/shared.lua:0: t: expected table, got nil` (A9)

**Arrived green — 8 cases**, each with its killer (run below):

- is ready again once the prompt returns after a dialog — spent by unit 3 — `detachondialog`
- never becomes ready when a dialog replaces the prompt at once — spent by unit 1's invalidation — `noinvalidate`
- leaves no deaf Claude running though Ctrl-C is pressed in the editor — spent by unit 6 — `plainhangupwait`
- keeps its terminal off the buffer list — the packet's reading — `listed`
- is ready when the folder's name holds the word trust (F6) — green by the box's shape — `trustwords`
- names the setting that is malformed, `cmd = { 'claude', 1 }` and `allowed_tools = { 1 }` — the packet's list check — `anyword`
- stays starting for 1.2 s after the prompt shows (rewritten) — the settle — `settle50`

Strengthened without a new case: F1, F2, F3, F5, the fake's F4 and the finding-8 guards, each killed below by the reviewer's own edit.

**Mutant table — the fix round's final code head** (`d9b5421`): literal edits, one at a time, each file copied aside and restored byte for byte, each run as `make test_file FILE=tests/test_claude.lua` (53 cases); kinds read from mini.test's output (an expectation failure is an assertion). The packet's rows keep their labels and edits; a reviewer's surviving edit is its own row, as the reviewer wrote it. Script and logs: `t4f-mutants.py`, `t4f-mutants-final-summary.txt`, `t4f-final-mutant-<label>.txt` in the orchestrating session's scratchpad. Deaf fakes that a mutant left alive (`nofallback`, `shortwait`, `noquit`, `pidkill`, `plainhangupwait`) were killed by pid after the run.

| Label | Whose | Literal edit | Result (kind) |
|---|---|---|---|
| **M4** | wave plan | `arguments.lua` `{ env = vim.empty_dict() }` → `{ env = {} }` | killed: writes the env of a server without variables as a JSON object; writes an empty env for a server that names no env (assertion) |
| **M5** | wave plan | `readiness.lua` drop `and screen:find(TRUST_DIALOG, 1, true) == nil` | **no target** — the trust-text condition was removed while green; its intent is `glyphalone` |
| **M6** | wave plan | `stop.lua` delete `{ keys = CTRL_C, then_wait_ms = 2500 },` | killed: ends a turn with one Ctrl-C before the double Ctrl-C; ends a turn by keys though Ctrl-C is pressed …; leaves no Claude that ignores its keys … (assertion) |
| shell | packet | `jobstart(command, …)` → `jobstart(table.concat(command, ' '), …)` | killed: 36 cases, every one an expectation failure |
| flag | packet | add `'--permission-mode', 'acceptEdits',` before `'--allowedTools',` | killed: passes no flag beyond … (assertion) |
| nvim | packet | `{ AINEO_CHILD = '1' }` → `{ AINEO_CHILD = '1', NVIM = 'elsewhere' }` | killed: … server address as NVIM (assertion) |
| clearenv | packet | add `clear_env = true,` | killed: 35 cases, every one an expectation failure |
| wipeonexit | packet | wipe the buffer on exit | killed: exit line; every window; restart after wipe (assertion) |
| order | packet | `session.ready` checked before `session.exit_code` | **survived** — equivalent in the state it is about: a probe under this mutant made the session ready, ended it by keys and read `{ "exited", 0 }`, because Neovim's `[Process exited 0]` overwrites the box's lower rule (`t4f-probe-order.txt`), as the recorded MIDTURN-DOUBLE screen shows for 2.1.281, so readiness is already false |
| wipefirst | packet | wipe before the `win_findbuf` loop | killed: shows the new terminal in every window … (assertion) |
| nofallback | packet | delete `vim.fn.jobstop(job)` and its wait | killed: both deaf tests (assertion) |
| shortwait | packet | `EXIT_AFTER_HANGUP_MS = 5000` → `3000` | killed: both deaf tests (assertion) |
| nosettle | packet | `SETTLE_MS = 1500` → `0` | killed: stays starting for 1.2 s … (assertion) |
| nocleanup | packet | drop the buffer's deletion from the failed-start branch | killed: leaves nothing behind but the error … (assertion) |
| noguard | packet | delete `replace_terminal()`'s `nvim_buf_is_valid` return | killed: starts Claude again after the old terminal was wiped (assertion); also a crash in returns a live terminal when the running one was just wiped |
| noquit | packet | delete the `stop_on_quit()` call | killed: the five quit tests that watch the fake (assertion) |
| novalidate | packet | delete the `settings.instructions` validation | killed: `instructions = false` (assertion) |
| deadreturn | packet | `if is_running() then` → `if session then` | killed: four restart tests (assertion) |
| trustword | packet | `TRUST_DIALOG` → `'no such dialog text'` | **no target** (the constant is gone) |
| exitwait50 | attack A8 | `{ keys = CTRL_C, then_wait_ms = 4000 },` → `… = 50 },` | killed: idle quit; busy quit; busy quit with Ctrl-C in the editor (assertion: 129 ≠ 0) |
| exitwait20 | test-integrity 3 | `then_wait_ms = 4000` → `20` | killed: the same three (assertion) |
| turnwait1100 | test-integrity 3 | `then_wait_ms = 2500` → `1100` | **survived** — a limit: how soon a turn ends was never measured; the fake's 1000 ms is invented |
| allwindows | test-integrity 1 | `ipairs(vim.fn.win_findbuf(buffer))` → `ipairs(vim.api.nvim_list_wins())` | killed: shows the new terminal in every window … (assertion) |
| shortflag | test-integrity 2 | `'-c',` before `'--mcp-config',` | killed: passes no flag beyond … (assertion) |
| noearlyreturn | test-integrity 4 | `return not is_running()` → `return false` | killed: stops an idle Claude by a double Ctrl-C (assertion: `jobwait` −1) |
| listed | test-integrity 7 | `nvim_create_buf(false, true)` → `(true, true)` | killed: keeps its terminal off the buffer list (assertion) |
| anyword | test-integrity 7 | `return type(word) == 'string'` → `return true` | killed: `cmd = { 'claude', 1 }`, `allowed_tools = { 1 }` (assertion) |
| settle50 | test-integrity 7 | `SETTLE_MS = 1500` → `50` | killed: stays starting for 1.2 s … (assertion) |
| pidkill | test-integrity 5 | `vim.fn.jobstop(job)` → `vim.uv.kill(vim.fn.jobpid(job), 'sigkill')` | killed: both deaf tests (assertion: the process group), and the closed-terminal test |
| trustbroad | test-integrity 6 | `TRUST_DIALOG` → `'trust'` | **no target**; its intent is `trustwords` |
| trustother | test-integrity 6 | `TRUST_DIALOG` → `'Accessing workspace'` | **no target** (the reviewer called it equivalent) |
| glyphalone | fix round | `holds_input_box()` returns true when `❯` is anywhere on the screen | killed: trust, MCP-server, permission, prompt-returns, two-writes and at-once tests (assertion) — M5's intent |
| trustwords | fix round | `holds_input_box()` returns false when "trust" is anywhere on the screen | killed: is ready when the folder's name holds the word trust (assertion) |
| noruleabove | fix round | drop `and is_rule(lines[index - 1])` | **survived** — equivalent on every recorded screen: the rule below alone rejects them |
| norulebelow | fix round | `if is_rule(lines[below]) then return true end` → `return true` | **survived** — equivalent on every recorded screen: the rule above alone rejects them |
| nodraft | fix round | delete the draft-continuation `while` loop | killed: is ready with a draft of several lines … (assertion) |
| fullscan | fix round | `-vim.o.lines - 1` → `0` | killed: is ready soon after a long output … (assertion) |
| noinvalidate | fix round | drop `settle = nil` where the box is gone | killed: never becomes ready when a dialog replaces the prompt at once (assertion) |
| stickyready | fix round | delete the `ready = false; on_change(false)` block | killed: permission dialog; prompt returns (assertion) |
| detachondialog | fix round | `return true` (detach) after `on_change(false)` | killed: is ready again once the prompt returns … (assertion) |
| plainwaits | fix round | key waits → `vim.wait(press.then_wait_ms, has_exited, 20)` | killed: ends a turn by keys though Ctrl-C is pressed … (assertion) |
| plainhangupwait | fix round | the wait after `jobstop()` → `vim.wait(…)` | killed: leaves no deaf Claude running though Ctrl-C is pressed … (assertion) |
| nosendguard | fix round | the `pcall` guard → a bare `nvim_chan_send` | killed: lets later exit handlers run … (assertion) |
| nojobcheck | fix round | `if not started or job <= 0 then` → `if not started then` | killed: starts Claude after a start that failed under `:silent!` (assertion) |
| novalidbuffer | fix round | drop `and vim.api.nvim_buf_is_valid(session.buffer)` | killed: returns a live terminal when the running one was just wiped (assertion) |
| nodircheck | fix round | drop `and vim.fn.isdirectory(value) == 1` | killed: `cwd = '/nonexistent/aineo/directory'` (assertion) |
| tblmap | fix round | the server loop → `vim.tbl_map(encodable_server, …)` | killed: writes an empty map of servers as a JSON object (assertion) |
| envnil | fix round | drop `server.env ~= nil and` | killed: writes an empty env for a server that names no env (assertion) |

**Tally:** 48 labels — 40 killed by an assertion, 4 survived (`order` and the two rules, equivalent on the recorded screens; `turnwait1100`, a limit), 4 with no target on this head (`M5`, `trustword`, `trustbroad`, `trustother`). **M4, M5, M6 on this head:** M4 is killed by the two env tests, M6 by the three turn-and-deaf quit tests, and M5 has no literal target; `glyphalone`, its intent, is killed by six readiness tests.

## Task lines

- T4 — Claude session (C3): done in this packet and its fix round, `feature/t4-claude-session`; readings for the MVP review: the 1.5 s settle, the input-box readiness signature, `'starting'` while a dialog shows, the stop's waits (about 4.4–5.3 s to quit with Claude idle, computed; 11.8 s at most), the unlisted buffer, `--allowedTools` last, `cwd` as an argument that must exist, a wiped running terminal ends the session, the fake's modes.

## Commits

*Recorded after the merge.*

## Open threads

- **For T6/C4:** `'ready'` means the input box is on screen with no dialog in its place — not that Enter is safe in every sense: during a turn the 2.1.281 input box stays on screen (`t4-screens.txt`, MIDTURN), so a session reads `'ready'` while a turn runs, and Enter then queues a message (unmeasured). Send must not treat `'ready'` as "no turn is running".
- **A5, recorded as a limit (no code change):** a `VimLeavePre` handler registered before aineo's that raises makes Neovim 0.11.6 skip aineo's stop; Claude then gets Neovim's own hangup (129), and a hung one outlives the editor. aineo registers its handler when a session starts, so any plugin's startup handler runs first. T8 (health and vimdoc) will name it.
- **turnwait1100, a limit:** no measurement exists of how soon a turn ends after one Ctrl-C, so the 2.5 s wait after the first press is pinned only against the fake's invented 1000 ms (a 1.1 s wait survives).
- **Dialogs never recorded** — login, theme, an API-key question, or any a later version adds — read as not ready only if they draw no input box of their own; unmeasured. Each new Claude Code version's dialogs should be recorded and replayed as the MCP-server and permission dialogs are.
- **The rules above and below the box:** each alone rejects every recorded dialog and transcript line, so the mutants dropping one of them survive as equivalent on the recorded screens; both are kept, as the orchestrator's reading and the attack review's measured fix had them.
- **`vim.o.lines` in `readiness.lua`:** the screen is read as the buffer's last `'lines'` rows, an ambient editor option read at each scan so that a resize is followed; injecting it would move the same read into `init.lua`, which is not the composition root either.
- **A two-line draft, not a longer one, is recorded;** a draft that wraps or grows past the box's rows is unmeasured.
- **For the knowledge pass (records R6):** the measurements behind the packet's departures (`t4-probe-kill`, `t4-probe-size`, `t4-probe-deaf`, `t4-probe-hupdeaf`, `t4-probe-race`, the `t4-sample-*` stacks, the mutant logs) and the fix round's (`t4f-*`) are in the orchestrating session's scratchpad, not in the wave's `evidence/`, which a packet may not write; they will not outlive the session unless copied.
- **For the orchestrator (records R4):** the packet read its specialist charter from `main`, where agent worktrees start, before switching to the branch.
- The fake's echo is exercised by no T4 test; T6's paste tests are its first user.
- An empty `allowed_tools` list would still pass a bare `--allowedTools`; the contract always gives one tool.
- A learning for the knowledge pass (outside this packet's boundary): terminal jobs and quitting Neovim 0.11.6 — a hidden terminal is 5 rows; a job that ignores the hangup outlives `:qa`; `jobstop()` escalates to SIGTERM at 2.0 s and SIGKILL at 4.0 s; a `nvim -l` script cannot ignore a hangup; `vim.wait()` returns at once on a Ctrl-C (the attack review's measurement).
