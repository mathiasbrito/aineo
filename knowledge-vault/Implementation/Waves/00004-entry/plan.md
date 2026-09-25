---
wave: 00004
status: planned
planned_by: the orchestrator (Claude, Opus 5.5) for Mathias Santos de Brito — host Macbook-Mathias
planned_at: 2026-09-25 01:51 CEST
base: bb0e185
claimed_by:
claimed_at:
landed_at:
---

# Wave 4 — the entry point

**Planned by:** the orchestrator · **Base:** `bb0e185` — wave 3 landed: T6, Send (PR #15).
**Ask:** "move on with the implementation until you have all the functionalities implemented, I will then review the first MVP" — the user, 2026-09-23 23:41 CEST.
**Composition from:** [[Planning/aineo — v1 agent console]] › *Implementation plan*, and [[Projects/aineo]] › *Where the work stands*.

## Baseline

**491 cases, `Fails (0)`, exit 0**, 365 s — measured by the orchestrator on 2026-09-25 (01:13–01:20 CEST) at PR #15's final head `9706947` and on T6's files laid over `dev` `0b52d7f`; the merge, `bb0e185`, is per-file identical to `9706947` on T6's files. `.claude/hooks/test-hooks.sh`: **78 passed**, exit 0, at `bb0e185`, 01:51 CEST — `evidence/baseline.txt`.

## Measured before planning

By the orchestrator on 2026-09-24, on host Macbook-Mathias:

- **The whole report channel, wired by hand as T7 will wire it**, against the real Claude Code 2.1.281 — one model turn, every `CLAUDE*` variable removed, state under a scratch directory (`evidence/t7-summary.txt`, the driver `evidence/t7-driver.lua`):
  - Claude Code accepted aineo's report tool, its schema's `"details": {"type": ["string", "null"]}` included;
  - its call was relayed into the Report, rendered in C6's format;
  - the session ended by `/exit` with `'exited', 0`.

  This answers MR33 of [[Review/2026-09-24 — v1 MVP readings review]].
- **How Neovim 0.11.6 starts** — no Claude ran (`evidence/t7-startup-summary.txt`, the drivers `evidence/t7-startup-driver.lua` and `evidence/t7-embed-probe.lua`):
  - at `VimEnter` an interactive start already has a UI attached, and `--headless` has none;
  - a file argument makes `argc()` 1;
  - piped stdin fires `StdinReadPost` before `VimEnter`;
  - mini.test's own child is always `--headless`. *Corrected by the brief review:* the orchestrator first recorded an `nvim --embed` RPC job the test attaches a UI to as a test route — it exits 1 about 10 ms after the attach (the orchestrator's own output showed it and was misread). The route that works, measured by the brief review, is an interactive `nvim` in a terminal job of a mini.test child, queried over `--listen`.

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| `t7-entry` | T7 | `neovim-lua-developer` / opus (effort `high`) | `plugin/aineo.lua`, `lua/aineo/init.lua`, `lua/aineo/config/` (EP11 only), the `Makefile` and `scripts/minimal_init.lua` (the guard against the real `claude`, and `AINEO_CHILD` removed, only), `tests/test_plugin.lua`, `tests/test_aineo.lua`, `tests/test_config.lua`, `tests/test_entry*.lua` (new), new modes and helpers in `tests/helpers/fake_claude.lua` and `tests/helpers/claude_session.lua`, new `tests/helpers/entry*`, new files under `tests/fixtures/claude/`, `tests/fixtures/entry/**`, its session note | none | no | none — D15 decided by the user; readings stated (EP7's unnamed starts, EP8's dashboard moments) | held |

1. **Dependencies.** T7 depends on T3, T4, T5 and T6 (the plan's row), all landed. T8 depends on T7, so it waits for wave 5.
2. **File sets.** One packet. `tests/test_plugin.lua` › *defines no autocommand, command or mapping* is a pin T7 moves by design, and it is inside the boundary.
3. **Schema.** None.
4. **Dependency change.** None: no plugin manager or dashboard is added — the brief asks for stand-ins, or for sources read raw.
5. **Decisions.** Q5 was converged with the user on 2026-09-24 (D15). The starts D3 does not name, and the dashboards' opening moments, are readings for the MVP review.
6. **Task lines.** Marks held, as before.

## Host and reviewers

- Host: Macbook-Mathias — limit 3 agents at once.
- Implementer: `neovim-lua-developer` at `high`, since its files are `plugin/` and the root. Reviewers at `xhigh`, all Opus:
  - **attack** — `neovim-claude-code-reviewer`: the wiring into the Claude session, the fake's MCP-client mode, the autostart taking over a start;
  - **test-integrity** — `neovim-lua-reviewer`;
  - **records** — `reviewer`.
- Session note `Sessions/<date> — T7 entry point.md`; branch `feature/t7-entry`; resources `impl_t7_entry`, `review_<dimension>_t7`.

## Decisions for the user

None open before dispatch. Q5 was settled on 2026-09-24 as D15. T8 runs after T7 by default; running it beside T7 by injection was offered to the user as a way to save a wave.

## Verification mutants

T7 — literal edits on the final head, each killed by assertion:

- **M19** — autostart without the UI check (run narrowed, and only once the guard against the real `claude` is pinned);
- **M20** — the prefix mapping made over a user's mapping;
- **M21** — `mcp_servers('', v:progpath)` in place of `v:servername`;
- **M22** — autostart without the `$AINEO_CHILD` check;
- **M23** — autostart skipped while a dashboard's filetype shows.

## Briefs

- `brief-t7-entry.md` — the T7 packet.
- `brief-review.md` — the brief reviewer's report, verbatim (Opus, at PR #16's head `b02ecba`): **dispatch after corrections**, above all findings 1 and 2; the six rules hold; the baseline re-measured exactly (491, `Fails (0)`; hooks 78). Every CONFIRMED and MISSING item is corrected in `brief-t7-entry.md`, this plan and `evidence/`: the test route (1, 9) — the orchestrator's `--embed` route dies after the attach, and the terminal-job route replaces it; a guard so no suite Neovim can run the real `claude`, and `AINEO_CHILD` removed from the suites (2, 3); M22's one-condition cases (4); what EP10 lets load at `VimEnter` (5); C1/D13 over the specialist's "no global keymaps", unknown keys to the health check (6); the real mini.starter (7); `origin/dev` at dispatch (8); EP11's cases in `setup()`'s group (10); EP9's claim scoped (11); EP6's E565 and the readings named (12).

## Landed

<filled by the knowledge pass>
