---
wave: 00003
status: planned
planned_by: the orchestrator (Claude, Opus 5.5) for Mathias Santos de Brito — host Macbook-Mathias
planned_at: 2026-09-24 17:37 CEST
base: c7a9c99
claimed_by:
claimed_at:
landed_at:
---

# Wave 3 — Send

**Planned by:** the orchestrator · **Base:** `c7a9c99` — wave 2 landed: T3 (PR #9), T5 (PR #10), T4 (PR #11) and the effort pass (PR #12).
**Ask:** "move on with the implementation until you have all the functionalities implemented, I will then review the first MVP" — the user, 2026-09-23 23:41 CEST.
**Composition from:** [[Planning/aineo — v1 agent console]] › *Implementation plan*, and [[Projects/aineo]] › *Where the work stands*.

## Baseline

`make test` on `c7a9c99`: **454 cases, `Fails (0)`, exit 0**, 256 s — measured by the orchestrator on 2026-09-24 (17:13–17:17 CEST) on T4's files laid over `08caf0e`, a tree identical to `c7a9c99` (`git diff --stat origin/dev` on it printed nothing after the merge); `.claude/hooks/test-hooks.sh`: **78 passed**, exit 0, at `c7a9c99`, 17:34 CEST — `evidence/baseline.txt`.

## Measured before planning

By the orchestrator, against the real Claude Code 2.1.281 in the aineo folder the user trusted, every `CLAUDE*` variable removed, no `--permission-mode` (aineo passes none, D11), three model turns — `evidence/t6-summary.txt`, the driver `evidence/t6-driver.lua`:

- A bracketed paste and Enter written **in one write** submit one message at idle — T2 had measured them as two writes (Q1).
- **During a turn the input box stays on screen**, so the session reads `'ready'`; only the footer's "esc to interrupt" and the spinner line mark the turn.
- A paste and Enter written **during a turn are queued** ("Press up to edit queued messages") and run when the turn ends.
- The idle footer showed the user's own setting ("auto mode on"), never "? for shortcuts" — the footer is no readiness signal, as T2 found.

Quoted there for T6 (the re-measure of PR #11, finding 8): the session turns `'starting'` 10.8–29.5 ms after a dialog's bytes reach the terminal; a redraw of the input box split into two writes 20 ms or more apart turns it `'starting'` for about 1.5 s.

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| `t6-send` | T6 | `neovim-claude-code-integrator` / opus (effort `high`) | `lua/aineo/send/**` (new), one new export in `lua/aineo/claude/init.lua`, `tests/test_send*.lua` (new), new modes and helpers in `tests/helpers/fake_claude.lua` and `tests/helpers/claude_session.lua`, new `tests/helpers/send*`, `tests/fixtures/send/**`, its session note | none | no | none — D14 decided by the user (below); readings stated (SD4) | held |

1. **Dependencies.** T6 depends on T2, T3 and T4 (the plan's row) — all landed.
2. **File sets.** One packet. Registration files: none — no file on `origin/dev` lists the homes or the test files, and no test pins `aineo.claude`'s exports (`git grep -nE "tbl_keys\(require\('aineo\.claude|aineo\.send|test_send" origin/dev -- tests scripts Makefile lua plugin` prints nothing); `tests/test_aineo.lua` pins only the root's `setup`, which T6 does not touch.
3. **Schema.** None in this project.
4. **Dependency change.** None.
5. **Decisions.** C4 left the behaviour during a turn open — the measurement above showed the session reads `'ready'` then. Put to the user and decided before this plan (D14, below). The empty-Input rule is a reading for the MVP review.
6. **Task lines.** One packet; the marks are held all the same, as in wave 2 — the packet writes a `## Task lines` section and the knowledge pass marks the row.

## Host and reviewers

- Host: Macbook-Mathias (10 CPUs, 64 GiB; platform UUID prefix `CF989BF4`) — limit 3 agents at once.
- Implementer at `high` effort; reviewers at `xhigh` (the user, 2026-09-24): **attack** — `neovim-claude-code-reviewer`; **test-integrity** — `neovim-lua-reviewer`; **records** — `reviewer`. All on Opus (D9).
- Session note `Sessions/<date> — T6 Send.md`; branch `feature/t6-send`; resources `impl_t6_send`, `review_<dimension>_t6` — no hyphen in a resource name.
- A fix round or a correction goes to a fresh agent once its author's context passes 400 K (the orchestrator's threshold).

## Decisions for the user

1. **Send while a turn runs** — asked 2026-09-24 with the measurement above. (a) *Send; Claude queues it* (recommended): `\s` works while Claude works and Claude Code runs the message after the turn, as typing in its terminal does; the risk stated with it — a permission dialog drawn in the ~11–30 ms before the session notices it takes Send's Enter, which picks its highlighted "1. Yes", against D11 — recorded as a limit. (b) *Refuse while a turn runs*: closes that race, since a permission dialog appears only in a turn, at the cost of queueing from Input and one more screen signature. **The user chose (a)** → D14.
2. **Q5, a startup dashboard against the autostart** — asked the same day, for T7 (wave 4). (a) *aineo takes the screen* (recommended): on a bare start aineo opens its layout even when a dashboard drew first; with `autostart = false` the dashboard shows as before; T7 handles the startup order against dashboards that open on `VimEnter` or later. (b) *Yield to the dashboard*: aineo never opens by itself while a dashboard is enabled. **The user chose (a)** → D15.

## Verification mutants

T6 — each a literal edit on the final head, applied and shown with `git diff HEAD` before the run, killed by assertion:

- **M13** — the text and `\r` written without the bracketed-paste markers.
- **M14** — the readiness check skipped.
- **M15** — Input left as it was after a send.
- **M16** — Input's text passed through unchanged, so an `ESC[201~` in it ends the paste early.

## Briefs

- `brief-t6-send.md` — the T6 packet.
- `brief-review.md` — the brief reviewer's report, verbatim.

## Landed

<filled by the knowledge pass>
