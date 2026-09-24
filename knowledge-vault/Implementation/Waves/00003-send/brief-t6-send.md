**Your role: implement.** Your worktree starts from `main`, whose `.claude/` is stale: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` — you are dispatched as that specialist — and the *What bites here* and *Tests* sections of `.claude/agents/neovim-lua-developer.md`, which bind you too.

You are dispatched by the orchestrator to implement **one packet** of the aineo v1 plan: T6, Send. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*:

> T6 — Send (C4)

It rests on: **C4** — "Send (`\s`): the Input buffer as one bracketed paste plus Enter into the terminal, then Input cleared; refused while Claude is not ready (trust dialog, startup) or Input is empty" — and **D14** (the user, 2026-09-24: Send works while a turn runs, and Claude Code queues the message; the dialog race below is a recorded limit), **D11** (aineo answers no prompt), **Q1** (resolved: a bracketed paste lands unsubmitted and Enter submits it as one message), **D10** (the real Claude never runs in the suite). Read those rows in the plan, not this summary of them. The `\s` mapping itself is T7's (C1): this packet builds what `\s` calls.

### The behaviours — the orchestrator's reading of C4 and D14, one test each; the seams are yours

- **SD1 Send.** `require('aineo.send').send()` — no arguments; T7 maps `\s` to it — writes the Input buffer's text into Claude's terminal as **one bracketed paste followed by Enter**: `ESC[200~`, the text, `ESC[201~`, `\r`. The text is Input's lines joined by `\n`. *Measured* (`evidence/t6-summary.txt`, 2026-09-24, Claude Code 2.1.281): the paste and the Enter written in **one** write, at idle, submitted one message; *measured* in T2 (Q1): a two-line paste lands as two lines in the input box, unsubmitted, and Enter submits both lines as one message. Assert on the bytes the fake received, whole.
- **SD2 Input cleared.** After a send, Input is empty, and it is still aineo's Input — the named, `nofile`, unlisted buffer the layout owns (T3's properties hold after the clear; pin one of them).
- **SD3 Refused while Claude is not ready.** When `require('aineo.claude').session_status()` is not `'ready'` — no session yet, `'starting'` (startup, and while a dialog shows: trust, MCP-server approval, permission), `'exited'` — Send writes nothing to the terminal, leaves Input as it was, and tells the user once why (`vim.notify`, naming the state in the user's words). The status is read **when `send()` runs**, not remembered from earlier.
- **SD4 Refused when Input is empty** — the same way: nothing written, one message. What counts as empty is your reading (lines of only whitespace?), stated, pinned, and routed to *Readings for the MVP review*.
- **SD5 Refused when there is no Input** — before the layout first opened `require('aineo.layout').input_buffer()` returns `nil`; a buffer id that is no longer valid is the same case. One message, nothing written.
- **SD6 During a turn, Send sends (D14).** *Measured* (`evidence/t6-summary.txt`): during a turn the input box stays on screen — so the session reads `'ready'` — and a paste plus Enter in one write is **queued** by Claude Code 2.1.281 ("Press up to edit queued messages") and runs when the turn ends. Pin that a session in a turn (T4's fake has a `busy` mode) receives the paste and the Enter.
- **SD7 The text cannot end the paste early.** Input's text may hold anything a user pasted into it — an `ESC[201~` among it would end the bracketed paste, and whatever follows, a `\r` included, would reach Claude as typed keys. No byte sequence in Input ends the paste before Send's own `ESC[201~`. How (removing the escape byte, or the sequence) is yours, stated in the docstring and pinned on the bytes the fake received for an Input holding `ESC[201~` then `\r` then text.
- **SD8 The text arrives whole.** Multi-byte UTF-8 (`é`, `❯`, an emoji) and long text reach the terminal byte for byte — measure what one `chansend()` does with a text of 100 KiB and say whether you split the write, and why.

### The limit D14 accepts — recorded, not closed

*Measured by the re-measure of PR #11* (finding 8, `evidence/t6-summary.txt` quotes it): the session turns `'starting'` 10.8 to 29.5 ms (ten cycles) after a permission dialog's bytes reach the terminal. A Send inside that window writes its paste and its Enter into the dialog, and Enter picks the dialog's highlighted choice (`❯ 1. Yes`) — an answered prompt, against D11. The user accepted this as a limit on 2026-09-24 (D14). Record it in the session note's limits with those figures, and do not claim the send path closes it. Also measured there: a redraw of the input box that reaches the terminal in two writes 20 ms or more apart turns the session `'starting'` for about 1.5 s (the settle) — a paste's own redraw included — so a second Send soon after a first may be refused; say what your tests saw.

### Facts, checked against `origin/dev`

Paths under `evidence/` are in `knowledge-vault/Implementation/Waves/00003-send/`. `<scratchpad>` is the orchestrating session's scratch directory, which the dispatch message names.

- `origin/dev` is `c7a9c99`: wave 2 landed — T3 (PR #9), T5 (PR #10), T4 (PR #11), and the effort pass (PR #12).
- **The session's public interface** (`lua/aineo/claude/init.lua`): `start_session(settings)` returns the terminal buffer Claude Code runs in; `session_status()` returns `'ready'`, `'starting'` or `'exited'` (with the exit code), or nothing before a session has started. **Nothing exported writes to the session's terminal.** This packet adds **one** export to `aineo.claude` for that — its name and shape are yours; it writes only while a session's process runs, and changes none of T4's behaviours (`tests/test_claude.lua`, 65 cases, stays green unchanged).
- **The layout's public interface** (`lua/aineo/layout/init.lua`): `open(arrangement)`, `focus(role, arrangement)`, `input_buffer()` — the Input buffer, or `nil` before the layout first opened.
- **Direction** (`.claude/skills/modularity/SKILL.md` §1): `aineo.send` may require `aineo.config`, `aineo.claude` and `aineo.layout` — through their entry points, never `aineo.claude.<file>`. The interim check `grep -rnE "require\(['\"]aineo\.[a-z_]+\." lua plugin tests scripts` prints only intra-home requires on `origin/dev`; run it before you report and mark each line it prints.
- **The fake `claude`** (`tests/helpers/fake_claude.lua`, T4): run as `nvim --clean -l tests/helpers/fake_claude.lua` through `claude.cmd`; records every chunk it receives as `{ received }` lines in the file `AINEO_FAKE_CLAUDE_RECORD` names; modes by `AINEO_FAKE_CLAUDE_MODE` — `ready` (the startup screen; echoes what it receives), `trust` and `mcp-server` (those dialogs, never ready), `busy` (in a turn), `asks` (the startup screen, then a permission dialog when it receives Enter), `asks-at-once` (a permission dialog right after startup), and more — the `MODES` table lists them. The session's test helper is `tests/helpers/claude_session.lua`. Use them; a new mode you need is added beside the others, leaving the existing ones unchanged.
- **The suite** (root `CLAUDE.md`): `make deps`, `make test`, `make test_file FILE=<path>`, `make lint`, `make format`; every Neovim it starts is isolated under `.tests/`.
- **Ambient reads** enter at the composition root or through an injected dependency (`neovim-lua-developer.md` › *What bites here*): `send()` reaches the session and the layout through their homes, which is the direction table's allowance, not an ambient read.
- The real `claude` never runs in your packet: not in a test, not in a measurement. The measurements above are the orchestrator's.

### Baseline

`make test` on `c7a9c99`: **454 cases, `Fails (0)`, exit 0**, 256 s — measured by the orchestrator on 2026-09-24 (17:13–17:17 CEST) on T4's files laid over `08caf0e`, a tree identical to `c7a9c99` (`git diff --stat origin/dev` on it printed nothing after the merge); `.claude/hooks/test-hooks.sh`: **78 passed**, exit 0, at `c7a9c99`, 17:34 CEST (`evidence/baseline.txt`).

Read first: the plan's *Decisions & reasoning* (D11, D14), *Architecture* (C3, C4), *Risks and unknowns* (Q1); `knowledge-vault/Projects/aineo.md`; the `modularity` skill §1, §2 and §4; `knowledge-vault/Sessions/2026-09-24 — T4 Claude session.md` › *Readings for the MVP review* and its limits; the evidence named above.

## Boundary

- **Branch:** `feature/t6-send` from `origin/dev`.
- **Model:** `opus` — every role in this project runs on Opus (D9).
- **Resources:** `impl_t6_send` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/send/` (new); **one new export and its docstring** in `lua/aineo/claude/init.lua`, with the lines it needs there; `tests/test_send*.lua` (new) — the new export's tests there or in `tests/test_claude.lua`, as new cases only; `tests/helpers/fake_claude.lua` and `tests/helpers/claude_session.lua` — new modes and helpers only, the existing ones unchanged; new files under `tests/helpers/` whose names begin with `send`; new fixtures under `tests/fixtures/send/`; and the session note below. No existing document describes Send.
- **You must not touch:** the other homes — `lua/aineo/layout/`, `lua/aineo/mcp/`, `lua/aineo/report/`, `lua/aineo/config/`, `lua/aineo/init.lua`, `plugin/aineo.lua` (the mapping is T7's); T1's `scripts/`, `Makefile` and helpers; the plan note (**the wave holds its task marks** — write a `## Task lines` section in your session note); the project note; and never `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude` or `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/<YYYY-MM-DD> — T6 Send.md`, the date read from `date` on the day you start.
- **Scratch prefix:** `t6-` on every file you write under the shared scratchpad.
- Anything the task needs outside the boundary is a **spec conflict** for your report, not a reason to widen it.

## What was decided already

- **Send while a turn runs sends, and Claude Code queues it** — D14, the user, 2026-09-24, over the alternative of refusing during a turn (which would close the dialog race, since a permission dialog appears only in a turn, at the cost of queueing from Input). The risk was put to the user with the option and accepted.
- **One bracketed paste plus Enter** — C4; Q1 measured it.
- **aineo answers no prompt** — D11: nothing in Send presses a key a dialog would read as an answer on purpose; the race above is the recorded exception D14 accepts.

## Verification mutants — the orchestrator runs these on your final head

Each is a literal edit, applied and shown with `git diff HEAD` before the run. Write the tests that kill them — by assertion — and name, for each, the test that fails:

- **M13** — write the text and `\r` without the bracketed-paste markers → the SD1 test fails on the bytes received.
- **M14** — skip the readiness check → the SD3 *trust* (or *starting*) test fails: bytes reached the terminal.
- **M15** — leave Input as it was after a send → the SD2 test fails.
- **M16** — pass Input's text through unchanged (no protection of the paste's end) → the SD7 test fails.

## Readings

Every choice you make where C4, D14 and this brief are silent goes to a *Readings for the MVP review* section of your session note, each named once, with the same list in the pull request body and your report — the empty-Input rule (SD4) and the refusal messages' wording among them.

## Budget

Small to medium: one new home (`aineo.send`, one public function), one export in `aineo.claude`, the tests, and at most two new fake modes. If it is larger than that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t6-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure — the bytes the fake received for SD1, SD6 and SD7, and the M13–M16 killing tests. **Keep your context small:** send test and mutant output to files and read back the summary line and the failing names; run a mutant against the test file that targets it.
