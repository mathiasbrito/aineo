# 2026-09-24 — T4 Claude session

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t4-claude-session` · **Pull request:** #11, into `dev`

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C3; D2, D8, D10, D11, D13; R1, R2, Q4, F6)
- [[Implementation/Waves/00002-layout-session-report/plan]] and its brief `brief-t4-claude-session.md`
- [[Learnings/Claude Code's interactive CLI in a Neovim terminal]] — the measurements the waits rest on
- Evidence used: `Implementation/Waves/00002-layout-session-report/evidence/` — `t4-summary.txt`, `t2-summary.txt`, `t4-screens.txt`, `t4-trust-dialog-screen.txt`, `t4-claude-2.1.281-startup-paste-exit.bytes.txt`

## Context

**Goal:** T4 — "Claude session (C3): start, flags, environment, readiness, restart, stop on quit, and the fake `claude` its suites run" — asked for by the user on 2026-09-24 ("Plan also the implementation of the plumbing of the claude agent with his window on the left … after planning implement it"). T4 runs beside T5 by injection: `aineo.claude` requires no other home; the composition root (T7) hands it the MCP servers, the tools to pre-allow and the instructions.

## What was done

**`lua/aineo/claude/`** — a home of four files behind `init.lua`:

- `init.lua` — `start_session(settings)` and `session_status()`. One Claude Code at a time; a start while one runs returns its buffer; a start after it exited launches a new terminal, puts it in every window that showed the dead one, then wipes the dead one. Settings are validated with `vim.validate`; a command that cannot run leaves no buffer and re-raises `jobstart()`'s error. Registers the stop on `VimLeavePre` (augroup `aineo.claude`) whenever it starts a process.
- `arguments.lua` — `--mcp-config <json>`, `--append-system-prompt <text>`, `--allowedTools <tool>…`; an empty server `env` is written as a JSON object.
- `readiness.lua` — ready when the screen shows `❯` and not "trust this folder", after a settle of 1.5 s; watched with `nvim_buf_attach`'s `on_lines`.
- `stop.lua` — one Ctrl-C, wait 2.5 s; Ctrl-C, 0.3 s, Ctrl-C, wait 4 s; `jobstop()`, wait 5 s. Returns as soon as Claude has exited; bounded at 11.8 s.

**Tests** — `tests/test_claude.lua` (34 cases), the helper `tests/helpers/claude_session.lua`, the fakes `tests/helpers/fake_claude.lua` (`nvim --clean -l`, raw mode by `stty`, modes `ready`, `trust`, `busy`, `exit`) and `tests/helpers/fake_claude_deaf.sh` (POSIX sh), the fixtures `tests/fixtures/claude/startup-2.1.281.bytes` (the first 1540 bytes of the recording, cut before the frame with the Remote Control link) and `trust-dialog-2.1.280.bytes`.

**Suite:** 111 cases before, 145 after, `Fails (0)`, 120 s on this Mac; `tests/test_claude.lua` alone about 35 s; `make lint` clean. The modularity deep-require check prints three lines, all `lua/aineo/claude/init.lua` requiring its own `arguments`, `readiness` and `stop`.

## Decisions & reasoning

The brief left these to the packet; each is a reading for the MVP review unless marked otherwise.

- **Readiness settle: 1.5 s** after the prompt appears (the wave plan's item 14). It is the only wait T2 measured before input; no shorter one was tried. It is how long Send (C4) will refuse input after the prompt shows.
- **The trust dialog is recognised by "trust this folder"**, not by "trust": the startup banner shows the folder's path, which may hold the word. Open: whether an accepted dialog leaves its text in the terminal's scrollback, which would hold readiness back — unmeasured.
- **Stop timings** (S7), derived from the phases measured on 2.1.281: the single press then 2.5 s (the one mid-turn stop that worked waited 2.5 s); the double press 0.3 s apart (0.3 s exits, 1.2 s does not); 4 s for the exit (1.6–2.5 s after the second press); `jobstop()` then 5 s. `:qa` with Claude idle takes about 5 s (the plan's reading 7).
- **The fallback's wait is measured, not guessed** (Nvim 0.11.6, this Mac): a terminal job that ignores the hangup survives `:qa` as an orphan; after `jobstop()` Neovim sends SIGTERM at 2.0 s and SIGKILL at 4.0 s. So the stop waits 5 s after `jobstop()`, and no Claude outlives the editor.
- **The deaf fake is POSIX sh.** A `nvim -l` script cannot ignore a hangup: it exited 1 within 2 ms of `jobstop()` whatever its own handler did. With such a fake the fallback is indistinguishable from Neovim's own exit, which hangs every terminal up. The sh fake ignores keys, the hangup and SIGTERM — a stuck process — so only the fallback's wait ends it.
- **A fifth fake mode, `exit`**, which shows the startup screen and exits with a chosen code: S5 needs an exit code other than 0, and S4 an exit inside the settle.
- **The working directory is a setting** (`settings.cwd`), not a read of the editor's: the home reads no ambient state; T7 passes `getcwd()`.
- **Show the new buffer at once.** A terminal started in a hidden buffer gets the size of Neovim's autocommand window — 5 rows at 80 columns, measured — where the recorded screen loses its prompt; `jobstart()`'s `width` and `height` are ignored for a terminal. Shown in the same tick, the process first sees the window's size (22 rows, measured). The docstring says so; T7 must show it before yielding.
- **`--allowedTools` comes last, one word per tool**: the CLI reference (code.claude.com, `cli-reference.md`, read 2026-09-24) documents it as taking the following words up to the next flag.
- **The terminal buffer is unlisted** (`nvim_create_buf(false, true)`): `:bnext` does not land on it.
- **The Lua fake never reopens its terminal.** After the mutant runs three fakes were found alive as orphans (PPID 1), up to an hour old; sampled, each sat in `luv_new_tty` → `uv_tty_init` → `open()`, the reopen libuv makes of a terminal by its path, blocked because Neovim had closed the terminal while the fake started. Neovim's own handlers in the fake catch the hangup and SIGTERM, so only a SIGKILL ends such a process, and all three came from runs with no stop registered (before S7, and the `noquit` mutant). Hanging a fake up at every 4 ms of its first 120 ms: the fake with `vim.uv.new_tty()` needed about 2 s (Neovim's SIGTERM) after 7 of 217 hang-ups, 20–32 ms after its start; the fake that sets raw mode with `stty` and uses pipes on descriptors 0 and 1 ended within 9 ms after each of 93 (`t4-probe-race.sh` in the wave's scratchpad). No suite test pins it: the window is a race a test would hit only some of the time. Node's terminal streams go through the same libuv call, so a real Claude hung up in its first milliseconds may behave alike (an inference, not measured); the 5 s fallback wait leaves room for Neovim's SIGKILL.

## Red, green and mutants

**Units, in the order they were written** — 28 test functions, 34 cases (one function parametrized six ways): 28 cases seen red, 6 arrived green. The suite went from 111 cases to 145.

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

Arrived green, each with the mutant that kills it (run on the final head, below):

- passes each word of the command to the process unchanged — `jobstart()` given a list, spent by unit 1 — `shell`
- passes no flag beyond the servers, the instructions and the tools — spent by units 3, 5, 6 — `flag`
- gives the process the editor's server address as `NVIM` — Neovim's own for every job — `nvim`
- passes every other variable of the editor on unchanged — `jobstart()`'s `env` extends — `clearenv`
- leaves the terminal showing Neovim's exit line — Neovim's own — `wipeonexit`
- is not ready once Claude has exited, even right after its prompt — spent by unit 11's order — `order`

**Mutant table** — literal edits, one at a time, each file copied aside and restored byte for byte, each run as `make test_file FILE=tests/test_claude.lua` on the final code head (the commit "Stop the fake claude from hanging when its terminal closes early"; the summary is `t4-mutants-summary-final.txt`); kinds read from mini.test's output. The scripts and logs are `t4-make-mutants.lua`, `t4-mutant.sh`, `t4-run-mutants.sh` and `t4-mutant-<label>.txt` in the wave's shared scratchpad.

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

**Tally:** 19 mutants, 19 killed by an assertion — as on the table's second run, before the fake's fix. Its first run found two weak spots, fixed in "Keep a failed session test from stopping the whole run" before the second: under `shell` and `clearenv` the teardown's Ctrl-C raised inside `MiniTest.finally()`, which stalled the run instead of failing a test; and `noguard` was killed by a crash.

## Task lines

- T4 — Claude session (C3): done in this packet, `feature/t4-claude-session`; readings for the MVP review: the 1.5 s settle, the stop's waits (about 5 s to quit with Claude idle, 11.8 s at most), the trust-dialog words, the unlisted buffer.

## Commits

*Recorded after the merge.*

## Open threads

- T7 must show `start_session()`'s buffer in the same tick (see *Decisions*).
- Other startup dialogs that carry `❯` (login, theme, an API-key question) would read as ready; only the trust dialog is recognised.
- The fake's echo is exercised by no T4 test; T6's paste tests are its first user.
- An empty `allowed_tools` list would still pass a bare `--allowedTools`; the contract always gives one tool.
- A learning for the knowledge pass (outside this packet's boundary): terminal jobs and quitting Neovim 0.11.6 — a hidden terminal is 5 rows; a job that ignores the hangup outlives `:qa`; `jobstop()` escalates to SIGTERM at 2.0 s and SIGKILL at 4.0 s; a `nvim -l` script cannot ignore a hangup.
