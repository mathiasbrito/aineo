# Wave 3 retrospective

**Author:** Mathias Santos de Brito, with Claude — the orchestrator (Opus 5.5, session `619e5f9a`)
**Branch:** `knowledge/wave3-close-wave4-plan`

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] · [[Implementation/Waves/00003-send/plan]] · [[Implementation/Waves/00004-entry/plan]]
- The packet's own record: [[Sessions/2026-09-24 — T6 Send]]
- Before it: [[Sessions/2026-09-24 — Wave 2 retrospective]] · The MVP agenda: [[Review/2026-09-24 — v1 MVP readings review]]

## Context

**Goal:** land T6, Send (C4), under the orchestrate skill, merging delegated to the orchestrator.

Before planning it, the orchestrator measured Claude Code 2.1.281 during a turn. The input box stays on screen, so the session reads ready, and a message sent then is queued. It put the resulting open question to the user with the consequences stated: D14, Send works during a turn. Q5 went to the user at the same time, for T7: D15, aineo takes the screen from a startup dashboard.

## What was done

**Timeline** (CEST; the times the orchestrator wrote into its ledger, read from the clock in the same call — a step can precede its line by some minutes; the measurements are timed by their evidence files):

| When | Step |
|---|---|
| 09-24 17:14–17:15 | T6 measured on the real CLI: a paste and Enter in one write at idle and during a turn (three model turns) |
| 17:20 | the user decides D14 and D15 |
| 17:40 | PR #13: wave 2's close and wave 3's plan; a brief review and a records review |
| 17:41–17:46 | for T7: the report tool measured end to end on the real CLI (one model turn); Neovim's startup events measured (no Claude) |
| 17:55–17:56 | the brief review's findings 4 and 6 measured again through aineo's own watcher (three model turns) |
| 18:04 | #13 corrected and merged, wave 3 claimed, T6 dispatched (`neovim-claude-code-integrator`; its transcript starts 18:04:43) |
| 18:06–18:20 | PR #14, the `ai/` pass on narrowed mutant runs: reviewed, corrected, merged |
| 19:17 | PR #15 (T6) in: 479 cases; three reviews |
| 19:36–20:57 | the reviews in; 20:00–20:02 the split-marker question measured on the real CLI (no model turn) |
| 20:58 | one fix round to the author |
| 22:31 | the round in; a re-measure with the attack question |
| 09-25 00:26 | the re-measure refuted the round's clear-before-write when the write fails; one bounded correction to a fresh agent |
| 01:20–01:47 | the correction in; the orchestrator's verification; merged |

**Findings, per review** (the verdicts are the reviewers', counted from each report's own headings; each report in the orchestrator's scratch directory):

| Review | Agent | Result |
|---|---|---|
| brief, wave 3 | `reviewer` | 10 CONFIRMED, 4 MISSING; "dispatch after corrections" — among them T4's `busy` mode not being a turn on screen, and the fake's echo taking the box away |
| records, #13 (wave-2 close) | `reviewer` | 6 CONFIRMED, 2 MISSING, 1 UNVERIFIABLE — the MVP list missed nine limits the notes record |
| records, #14 (`ai/` pass) | `reviewer` | 3 CONFIRMED, 5 REFUTED — the rule still allowed the whole-file loop it was written to stop, and its counts were wrong |
| attack, #15 | `neovim-claude-code-reviewer` | 4 CONFIRMED, 1 surviving mutant, 1 UNVERIFIABLE — control bytes other than ESC passed into the paste; a clear failing after the write; the permission dialog's footer miscited |
| test-integrity, #15 | `neovim-lua-reviewer` | 4 CONFIRMED, 2 MISSING, 5 REFUTED, 1 UNVERIFIABLE — "one write" claimed but unpinned; the turn cases on a screen showing no turn |
| records, #15 | `reviewer` | 6 CONFIRMED; its twelve re-measured claims held — the `send()` docstring stated an inference as fact |
| re-measure, #15 | `neovim-claude-code-reviewer` | 2 CONFIRMED, 1 MISSING, 1 REFUTED, 1 UNVERIFIABLE — the round's claims held, and its reordering introduced one failure |

**Rounds on #15:** the packet (479 cases, 23 mutants); one fix round (489 cases, 41 mutants); one bounded correction (491 cases). The orchestrator's verification of the final head is in [[Implementation/Waves/00003-send/plan]] › *Landed*.

**Cost, per context** — read from the transcripts with `.claude/scripts/agent-context.py`, one row per API request deduplicated by request id:

| context | requests | last request's context | input (uncached) | cache write | cache read | output |
|---|---|---|---|---|---|---|
| records review, #13 — `reviewer` | 143 | 268,458 | 286 | 267,330 | 22,142,222 | 2,468 |
| brief review, wave 3 — `reviewer` | 72 | 183,915 | 144 | 163,706 | 8,664,218 | 5,653 |
| records review, #14 — `reviewer` | 53 | 115,162 | 106 | 99,263 | 4,033,926 | 1,417 |
| T6 implementer, packet + fix round — `neovim-claude-code-integrator` | 215 | 444,297 | 432 | 3,335,981 | 51,517,246 | 13,484 |
| attack review, #15 — `neovim-claude-code-reviewer` | 77 | 240,709 | 154 | 405,728 | 11,473,353 | 6,578 |
| test-integrity review, #15 — `neovim-lua-reviewer` | 100 | 258,054 | 200 | 1,864,010 | 14,058,948 | 11,079 |
| records review, #15 — `reviewer` | 99 | 206,789 | 198 | 190,890 | 14,262,468 | 3,443 |
| re-measure, #15 — `neovim-claude-code-reviewer` | 123 | 308,670 | 246 | 2,162,330 | 21,789,294 | 12,321 |
| bounded correction, #15 — `neovim-claude-code-integrator` | 74 | 184,993 | 180 | 474,657 | 9,705,787 | 6,020 |

The T6 implementer carried its packet and its fix round in one context and ended at 444,297 tokens — past the 400 K threshold only at the end of its fix round, so the correction went to a fresh agent. The authors of wave 2 reached 597,626–964,041, and each handed a round over earlier. A packet sized to one component, and agents told to keep test and mutant output out of their context, kept the author under the threshold until its round was done.

## Deviations and disclosures

- **PR #13's corrections merged checked only by the orchestrator** (`eb2f9fe`, now `eb7931a`). They answered its two reviews' findings, and no reviewer read them before the merge. The same holds for PR #14's second commit (`0b52d7f`).
- **The orchestrator slipped into a worktree with a bare `cd` once more**, at 01:29 during T6's verification. It moved back at once and wrote nothing there. This is the third slip (the other two are in the wave-2 retrospective) against a rule the skill states since PR #5, so the next `ai/` pass looks for a mechanical guard.
- **The orchestrator's own mutant script crashed once:** M16's output was not valid UTF-8. It left M16 applied in the verification worktree; the file was restored from `HEAD`, the status shown clean, and the run resumed from M16.
- **The orchestrator's records carried a miscited dialog footer** into D14, R4, MR49, the T6 brief, the wave-3 plan and the wave-2 retrospective: "Enter to confirm" for the permission dialog, whose footer reads "Esc to cancel · Tab to amend" (the attack review of #15, finding 6). Each is corrected with a dated note — except the T6 brief and the wave-3 plan's *Decisions*, which stay as dispatched (`Implementation/Waves/CLAUDE.md`); their correction is recorded in the wave-3 plan's *Landed*. The first version of this pass rewrote both in place; the records review of PR #16 (finding 1) caught it.
- **The orchestrator recorded a test route that does not work.** For T7 it wrote that an `nvim --embed` job with a UI attached over RPC gives tests a UI-attached start. Its own output lacked the line a live child writes a second later, and the orchestrator misread that. The brief review of wave 4 (finding 1) measured the child exiting about 10 ms after the attach, and the evidence, the plan and the brief were corrected before dispatch.
- **Seven model turns of the real Claude Code** ran for wave 3's and wave 4's measurements, each with every `CLAUDE*` variable removed, in the folder the user trusted; the split-marker sweep ran none.

## Commits

- T6, PR #15: `1826fe9` … `bb0e185` (8 commits) — [[Sessions/2026-09-24 — T6 Send]] › *Commits*.
- The wave-2 close and wave-3 plan, PR #13: `6651641`, `eb7931a`, `e179a6c`.
- The `ai/` pass, PR #14: `643ebd8`, `0b52d7f`.
- This knowledge pass: recorded after its merge by the next one.

## Decisions & reasoning

- **D14 — Send works during a turn** and **D15 — aineo takes the screen from a dashboard**: the user, 2026-09-24, each put with its consequence ([[Planning/aineo — v1 agent console]]).
- **A mutant runs by default against a copy of its test file narrowed to its group** (PR #14): the orchestrator's pass, after the wave-2 fix round that looped a whole file twice.
- **Send removes control bytes, not only ESC**, and **clears Input before writing, putting it back if the write fails** — the attack reviewer's measured fix, then the re-measure's, adopted by the fix round and the correction.

## Learnings extracted

- [[Learnings/StyLua 2.5.2 in-place formatting aborts intermittently]]

**What the process taught:**
- The re-measure paid for itself again: the fix round's reordering, made to stop a double send, created a lost Input on a failed write.
- Measuring the real CLI while the reviews ran answered two questions no fake could: the marker split, and readiness during a turn.
- The brief review found the brief's test route unsound. T4's `busy` mode draws no turn on screen, so SD6's pin would have proved nothing about a turn.

## Open threads

- **For T7 (wave 4):**
  - `\s` must not be an `<expr>` mapping, since Send's clear fails under textlock;
  - the fake's 80-column screens need Claude's window at least 80 columns wide — a child of 160 columns, or 240 with a file column;
  - the wave-4 plan and brief carry both.
- **Choices T8 records:** where T7 writes why autostart ran; MR38.
- **The next `ai/` pass:**
  - a guard against a bare `cd` into a worktree;
  - the Learning *Claude Code's interactive CLI in a Neovim terminal* split into claims — with the measurements of waves 2 and 3: a message queued during a turn, readiness during a turn, the paste marker — and its trap links.
