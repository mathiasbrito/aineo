---
wave: 00002
status: planned
planned_by: the orchestrator (Claude, Opus 5.5) for Mathias Santos de Brito — host Macbook-Mathias
planned_at: 2026-09-24 05:48 CEST
base: 798275d
claimed_by:
claimed_at:
landed_at:
---

# Wave 2 — the layout, the Claude session and the report channel

**Planned by:** the orchestrator · **Base:** `798275d` — wave 1 landed: T1 (PR #4, `5edf69f` … `7284c00`) and the wave-1 `ai/` pass (PR #5, `12353b2` … `798275d`).
**Ask:** "move on with the implementation until you have all the functionalities implemented, I will then review the first MVP" — the user, 2026-09-23 23:41 CEST; and, for T4, "Plan also the implementation of the plumbing of the claude agent with his window on the left, given that he received the instruction to report on it. after planning implement it." — the user, 2026-09-24.
**Composition from:** [[Planning/aineo — v1 agent console]] › *Implementation plan*, and [[Projects/aineo]] › *Where the work stands*.

## Baseline

`make test`: **111 cases, `Fails (0)`, exit 0** — measured by the orchestrator on 2026-09-24 at `5b323d8`, PR #4's final head, which is code-identical to `798275d` (`git diff --stat 5b323d8 798275d -- lua plugin scripts tests Makefile neovim.yml selene.toml .stylua.toml` prints nothing). `.claude/hooks/test-hooks.sh`: **78 passed, exit 0**, at `798275d`, 2026-09-24 05:47 CEST. Both in `evidence/baseline.txt`.


## Measured before planning

All by the orchestrator against the real Claude Code in the aineo folder — after the user trusted it on 2026-09-23, except the trust dialog's screen (before) — with every `CLAUDE*` variable of the orchestrating session removed, except in T2's first run (`t2-run1-screens.txt`), which inherited them and is kept as the reason the later runs removed them. The raw evidence is under `evidence/`; the account tier and home path in it are replaced (this repository is public).

- **T2 (Q1, Q2, Q4 at idle)** — 2026-09-23, Claude Code 2.1.281: `evidence/t2-summary.txt`, the driver `t2-driver.lua`, the MCP probe `t2-mcp_probe.py`, the screens `t2-run1-screens.txt` and `t2-run2-screens.txt`. Two model turns.
- **The MCP startup handshake** — 2026-09-24, no model turn: `evidence/t2-handshake.txt` (driver `t2-handshake-driver.lua`, probe `t2-handshake-probe.py`). `initialize` (protocol `2025-11-25`, `id` 0), `notifications/initialized`, `tools/list`; the server's environment carries `NVIM`, `AINEO_CHILD` and the entry's `env`.
- **Q4 in the middle of a turn, and the fixture bytes** — 2026-09-24, two model turns, each interrupted within seconds: `evidence/t4-summary.txt`, `t4-screens.txt`, `t4-driver.lua`, and the raw terminal bytes of a start, an unsubmitted paste and an exit, `t4-claude-2.1.281-startup-paste-exit.bytes.txt`. One Ctrl-C ends a turn and keeps the process; a double Ctrl-C ends a session at idle, but not during a turn.
- **The trust dialog's screen** — 2026-09-23 (F6), Claude Code 2.1.280: `evidence/t4-trust-dialog-screen.txt`.

This closes T2's measurement: Q1 and Q2 resolved, Q4 resolved for an idle prompt and for a turn. T2's fixture recording is these files; the fake `claude` that replays them is T4's (C3).

## Why T4 runs beside T5

The plan's T4 row depends on T5 because the Claude session registers the report server (C3, C5). The session needs only three values from T5's homes — the `mcpServers` entry, the tool names to pre-allow and the instructions text — and the composition root can hand them over (the `modularity` skill §4: a module receives its collaborators). So `aineo.claude` requires neither `aineo.mcp` nor `aineo.report`; both briefs fix the three shapes; the end-to-end check, a Claude calling the real `report` tool, moves to T7, which wires the homes. The user asked on 2026-09-24 for the session to be planned and implemented now. The plan's T4 row is amended in this pull request to say so — the *Depends on* cell, not a D# or C# row.

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| `t3-layout` | T3 | `neovim-lua-developer` / opus | `lua/aineo/layout/**`, `tests/test_layout*.lua`, new `tests/helpers/layout*`, its session note | none | no | none — readings stated (L1, L3, L6, L11, L12) | held |
| `t4-claude-session` | T4 | `neovim-claude-code-integrator` / opus | `lua/aineo/claude/**`, `tests/test_claude*.lua`, new `tests/helpers/claude*` and `tests/helpers/fake_claude*`, `tests/fixtures/claude/**`, its session note | none | no | none — readings stated (S3, S6, S7) | held |
| `t5-report-channel` | T5 | `neovim-claude-code-integrator` / opus | `lua/aineo/mcp/**`, `lua/aineo/report/**`, `tests/test_mcp*.lua`, `tests/test_report*.lua`, new `tests/helpers/mcp*` and `tests/helpers/report*`, `tests/fixtures/mcp/**`, its session note | none | no | none — readings stated (R2, R3, R4, R5) | held |

1. **Dependencies.** T3: T1 (landed). T4: T1 (landed), T2 (closed by the measurements above), T5 — removed by injection (above). T5: T1, T2.
2. **File sets.** Disjoint by home and by file-name prefix. Registration files: none shared — no file on `origin/dev` lists the homes or the test files — `git grep -nE "aineo\.(layout|claude|mcp|report|send)|test_(layout|claude|mcp|report)" origin/dev -- tests scripts Makefile lua plugin neovim.yml selene.toml .stylua.toml` prints nothing, while the same search for `layout` finds `lua/aineo/config/init.lua:50` (the positive control); `make test` collects `tests/**/test_*.lua` by pattern. No packet edits T1's helpers, `scripts/` or the `Makefile`.
3. **Schema.** None in this project.
4. **Dependency change.** None: mini.nvim stays at T1's pin; no packet adds a dependency.
5. **Decisions.** The D# and C# rows fix each behaviour; where a brief reads a detail the rows leave open, it says "the orchestrator's reading", and those readings go to the user at the MVP review (below).
6. **Task lines.** T3, T4 and T5 are rows 3, 4 and 5 of one table, adjacent — **marks held**: no packet edits the plan; each writes a `## Task lines` section in its session note, and the knowledge pass marks the rows.

## Host and reviewers

- Host: Macbook-Mathias (10 CPUs, 64 GiB; platform UUID prefix `CF989BF4`) — limit 3 agents at once. The three implementers take the limit; reviews run per pull request as the implementers finish, three at a time.
- Reviewers, all on Opus (D9):
  - **T3**: attack — `neovim-lua-developer`; test-integrity — `reviewer`; records — `reviewer`.
  - **T4**: attack — `neovim-claude-code-integrator`; test-integrity — `neovim-lua-developer`; records — `reviewer`.
  - **T5**: attack — `neovim-claude-code-integrator`; test-integrity — `neovim-lua-developer`; records — `reviewer`.
- Session notes: `Sessions/<date> — T3 layout.md`, `— T4 Claude session.md`, `— T5 report channel.md`.
- Branches `feature/t3-layout`, `feature/t4-claude-session`, `feature/t5-report-channel`; resources `impl_t3_layout`, `impl_t4_claude`, `impl_t5_report`, `review_<dimension>_<t3|t4|t5>` — no hyphen in a resource name (`prepare-worktree.sh` refuses one).

## Decisions for the user

None open before dispatch. The readings the briefs take where the rows are silent are listed for the MVP review:

1. L1 — the cursor starts in Input. 2. L3 — opening the layout closes the tab's other windows (their buffers stay loaded). 3. L6 — the layout re-applies its proportions when the editor is resized. 4. L11 — only file buffers are redirected to the file column; help and other special buffers are left to Neovim. 5. S3 — the Claude process inherits the editor's environment unchanged, plus `AINEO_CHILD`. 6. S6 — a restart wipes the dead terminal buffer. 7. S7 — quitting Neovim takes a few seconds while Claude is stopped by keys (one Ctrl-C, then a double Ctrl-C), with `jobstop` as the fallback. 8. R2 — a newline in a report's task or summary becomes a space. 9. R3 — the Report follows the newest report. 10. R4 — the Report is kept per working directory and reloaded on start. 11. R5 — when Claude is told to report.

## Verification mutants

Run by the orchestrator on each final head, each a literal edit shown applied with `git diff HEAD` before the run:

- **T4:** M4 — the `--mcp-config` entry's empty `env` built as `{}`; M5 — readiness without the trust-dialog condition; M6 — the stop sequence without its first single Ctrl-C.
- **T5:** M7 — `capabilities.tools` built as `{}`; M8 — `blocked` removed from the list of statuses; M9 — one persistence file for every directory.
- **T3:** M10 — Claude's window's width not pinned; M11 — the redirect leaves the file in the aineo window; M12 — a new file column on every redirect.

## Briefs

- `brief-t3-layout.md`, `brief-t4-claude-session.md`, `brief-t5-report-channel.md` — the packets.
- `brief-review.md` — the brief reviewer's report, verbatim.

## Landed

<!-- filled by the knowledge pass -->
