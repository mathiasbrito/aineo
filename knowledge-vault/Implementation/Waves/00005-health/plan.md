---
wave: 00005
status: planned
planned_by: the orchestrator (Claude, Opus 5.5) for Mathias Santos de Brito — host Macbook-Mathias
planned_at: 2026-09-25 08:13 CEST
base: 201873b
claimed_by:
claimed_at:
landed_at:
---

# Wave 5 — health and help

**Planned by:** the orchestrator · **Base:** `201873b` — wave 4 landed: T7, the entry point (PR #17).
**Ask:** "move on with the implementation until you have all the functionalities implemented, I will then review the first MVP" — the user, 2026-09-23 23:41 CEST. T8 is the last task before that review.
**Composition from:** [[Planning/aineo — v1 agent console]] › *Implementation plan*, and [[Projects/aineo]] › *Where the work stands*.

## Baseline

`make test` on `201873b`: **613 cases, `Fails (0)`, exit 0**, 431 s; `.claude/hooks/test-hooks.sh`: **105 passed** — `evidence/baseline.txt`.

## Measured before planning

- `claude --version` (`evidence/claude-version.txt`, no session, no model turn): `2.1.282 (Claude Code)` in 20 ms. Claude Code had updated itself from 2.1.281, which waves 2–4 measured.
- T7 records no reason for the autostart's decision (`plugin/aineo.lua`, `start_up()`, read on `201873b`), and some of its inputs exist only at startup. So T8's boundary opens `plugin/aineo.lua` for that record alone.

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| `t8-health` | T8 | `neovim-lua-developer` / opus (effort `high`) | `lua/aineo/health.lua` (new), `doc/aineo.txt` (new), `plugin/aineo.lua` (HB5's record only, in an editor variable), `tests/test_health.lua` and `tests/test_doc.lua` (new), new `tests/helpers/health*`, new modes in `tests/helpers/fake_claude.lua`, `tests/fixtures/health/**`, its session note | none | no | none — readings stated (the version bound, warning or error per line, HB5's reasons) | held |

1. **Dependencies.** T8 depends on T7 (the plan's row), which has landed.
2. **File sets.** One packet. PR #19, an `ai/` pass, touches only agent documentation and the root `CLAUDE.md`.
3. **Schema.** None.
4. **Dependency change.** None.
5. **Decisions.** C7 names the four checks. MR73 and MR38 were left to T8 by earlier packets. That the health check starts nothing is the orchestrator's reading of C7.
6. **Task lines.** Marks held.

## Host and reviewers

- Host: Macbook-Mathias — limit 3 agents at once.
- Implementer: `neovim-lua-developer` at `high`. Reviewers at `xhigh`, all Opus:
  - **attack** — `neovim-claude-code-reviewer`: `claude.cmd` run with `--version`, and the autostart record;
  - **test-integrity** — `neovim-lua-reviewer`;
  - **records** — `reviewer`, with the *reader* question for the help: can a new user install, configure and use aineo from `:help aineo` alone?
- Session note `Sessions/2026-09-25 — T8 health and help.md`; branch `feature/t8-health`; resources `impl_t8_health`, `review_<dimension>_t8`.

## Decisions for the user

None open before dispatch. The MVP review follows this wave.

## Verification mutants

T8 — literal edits on the final head, each killed by assertion:

- **M24** — the version check skipped;
- **M25** — the autostart reason not recorded;
- **M26** — unknown keys not reported;
- **M27** — one subcommand's tag removed from the help.

## Briefs

- `brief-t8-health.md` — the T8 packet.
- `brief-review.md` — the brief reviewer's report, verbatim but for paths (Opus, at PR #20's head `f63b2dc`; cut off once by a stream timeout and resumed): **dispatch after corrections**, findings 1–3 required. Every CONFIRMED and MISSING item is corrected in `brief-t8-health.md`: one reading of the version check, the whole `claude.cmd` with `--version`, tested with a script of its own (1); HB5's record in an editor variable, T1's two `test_plugin.lua` pins frozen (2); the effective local leader, unset meaning `\` (3); HB5's missing reasons and their order (4); `wait()` returning `nil` (5); "passes" meaning no error (6); HB1's wording (7); HB4's fifth case (8); the pins, the documentation to keep true, and the Claude home's private check (9).

## Landed

<filled by the knowledge pass>
