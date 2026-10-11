# Wave 10 retrospective

**Author:** Mathias Santos de Brito, with Claude — knowledge-writer agent (Sonnet 5.5), for the orchestrator's session
**Branch:** `knowledge/w10-landed`, cut from `dev` `32283d1` after the last merge and release; this pass lands the wave.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D47, D48, T43, T44
- `Implementation/Waves/00010-changes-filter/plan.md` — its *Landed* holds each packet's record, the departures and the rulings made after dispatch (A115–A117, A124, A125); the plan holds A93–A111
- The packets: [[Sessions/2026-10-11 — T43 Changes filter]], [[Sessions/2026-10-11 — T44 Full-context diffs]]
- [[Sessions/2026-10-11 — Wave 9 retrospective]], the wave before

## Context

On 2026-10-10 the user asked for two features: the commits window as a filter of the files window (*Uncommitted*, *Session work*, then the commits), and a toggle that shows a diff with the whole file as context. Both became rows, D47 and D48, in wave 10's planning, and the user chose the options the same day. The wave ran two regular packets in two stages, T43 then T44 (T44 re-reads the four diffs T43 makes), under the user's instruction of 2026-10-11 to minimise tokens, use Sonnet where suitable and avoid over-testing.

## What was done

- **T43, the commits window as a filter** (PR #159, released in v0.2.20): two fixed lines above the commits, the cursor line choosing after a 150 ms pause what the files window lists, Enter's diffs within the filter and the two whole diffs (D47).
- **T44, the full-context toggle** (PR #161, released in v0.2.21): `F` re-reads a diff in the same buffer with the whole file as context, remembered for the editor's life, the cursor kept on the same line of the same file (D48).
- **The suite** grew from 2494 cases to 2551 after T43 and 2594 after T44.
- **The wave's shape** (A104): Sonnet implementers, two reviews per packet (the attack on Opus, tests and records together on Sonnet), one fix round, then the orchestrator's check: the whole suite, lint and one mutant.

### What worked

- **Sonnet implementers on fully written briefs.** Both packets came back complete against their briefs; the fix rounds found bugs in edge cases, not missing behaviour.
- **One fix round answered every finding.** Neither packet needed a second round or a re-measure; the orchestrator's check passed on each fix round's head.
- **The attack review found the worst bugs both times.** T43's signed commit and root commit under a user's git settings, and the selection landing on *Uncommitted* when git is slower than the pause; T44's cursor going into another file when the files of a whole diff change between two reads.

### What cost most

- **Survivor mutants read as dead code.** T43's first round deleted two guards its mutants had not killed (`cursor_unplaced` and `--root`) as unreachable; the attack review reached both, and the fix round restored them under A117.
- **The first two commits of T43 carried the wrong model in their trailers** (A116), the dispatch having named Opus for a Sonnet agent; pushed history was not rewritten.

### What to change

- **Fold a dispatch amendment into the implementer's first commit** (A124), as T44 did, instead of a separate amendment pull request: it found no conflict and cost one commit.
- **A mutant survivor is a missing case before it is dead code** (A117): write the case that reaches the guard, and delete code only when the state is shown unreachable.

## Deviations and disclosures

- **The attack review of PR #159 found A95 and the brief disagreeing** about another worktree's merge commit; the orchestrator ruled A95's "everywhere" (A115).
- **A125 reads the brief's `F` item** as "the opposite of what the buffer shows", where D48 says "the same diff": reported with the wave.
- **T44's amendment is the implementer's own first commit** (A124), where A93 had planned a separate one.

## Decisions & reasoning

- **The user's:** D47 and D48, and the options chosen on 2026-10-10 (*The user's answers* in the plan); the instruction of 2026-10-11 to minimise tokens, use Sonnet where suitable and avoid over-testing.
- **The orchestrator's, under the instruction of 2026-10-06:** A93–A111 before dispatch; A115–A117 at T43's fix round; A124 at T44's dispatch, confirmed at its fix round; A125 at T44's fix round.

## Open threads

- **The assumptions go to the user:** A93–A111, A115–A117, A124 and A125.
- **Wave 11:** T45 (`gf`, in flight) and T46 (`\cs`, after the MVP review and the user's manual checks M7 and M8; O9 unruled).
- **T44's three small edges:** a second git read when an Enter's read arrives after `F`; a diff buffer wiped between `F` and its read skipped silently; `F` shadowing Vim's `F{char}` in a diff buffer.
- **Wave 9's threads stand:** T36's directory moves (A91), two `--settings` on Claude Code's argv, `tests/test_entry_panes.lua`'s child death and the test Neovims left after runs, `tests/test_health.lua`'s Ctrl-C timing case under load, T39's O2.

## Commits

- T43, PR #159: `a0e0134` … `5c7e21d` (3 commits). Released in v0.2.20, PR #160, `main` `f647cfd`.
- T44, PR #161: `0b09db7` … `32283d1` (5 commits). Released in v0.2.21, PR #162, `main` `50a28da`.
- This knowledge pass, which lands the wave: its hashes are recorded after its merge, by the next pass.
