# Wave 6 retrospective

**Author:** Mathias Santos de Brito, with Claude — the orchestrator (Opus 5.5, session `938616f1`)
**Branch:** `knowledge/w6-t9-landed`, the first packet's knowledge pass. Each later packet's pass extends this note.

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] · [[Implementation/Waves/00006-fixes/plan]]
- The packets' own records: [[Sessions/2026-09-25 — T9 Report colours]]
- Before it: [[Sessions/2026-09-25 — Wave 5 retrospective]] · The MVP agenda: [[Review/2026-09-24 — v1 MVP readings review]]

## Context

**Goal:** land the fixes the user asked for after trying `v0.1.0`, one packet at a time, in a rolling wave (the user, 2026-09-25: "One ongoing wave"). Merging is delegated to the orchestrator.

The user named five fixes:
1. Ctrl+N — dropped: "No new key".
2. `\tcn` toggles Claude's line numbers — T12, regular, D16.
3. Faint suggestions in Claude's prompt — needs Neovim 0.12. The user upgraded. The suite on 0.12.5 failed eight cases, which became T13, regular ("Yes, first").
4. Links — the terminal part may already work, and the user was asked to try ⌘-click. The Report part is T10, a small fix, to plan later.
5. The Report's colours — T9, a small fix. Its icon is T11, regular, C10, to plan later.

The user classed them "Small fixes where allowed".

During the wave, the user decided three more changes:
- unsent Input is kept as a draft — D17, T14;
- wave 7, the changes pane and sending only Input's selection, converged and not yet planned.

## What was done

**Timeline** (CEST; the times the orchestrator wrote into its ledger, read from the clock in the same call — a step can precede its line by some minutes):

| When | Step |
|---|---|
| 09-25 17:42 | Intake of the user's five fixes. Measured: Claude Code 2.1.282 binds Ctrl+N in four contexts; Neovim 0.11.6's terminal drops SGR 2 (dim) and 0.12.0 renders it; 0.11.6 already parses OSC 8 links |
| 09-25 17:57 | Baseline on the host's 0.12.5 at `9af91a6`: 727 cases, `Fails (8)` → T13 |
| 09-25 18:01 | PR #28, the vimdoc section exception: records review, corrected, merged. Baseline on a downloaded 0.11.6: 727 cases, `Fails (0)` |
| 09-25 18:23 | The brief review of the plan, T9, T13 and T12: 24 findings. Paused at the user's request |
| 09-25 20:35 | The 24 findings corrected, the wave claimed, PR #29 merged; T13 and T9 dispatched |
| 09-25 21:13 | T9 in: PR #30, 741 cases. The guarantee and records reviews dispatched |
| 09-25 21:37–21:47 | Guarantee in (G1–G4) and records in (R1–R5). The fix round sent to the author |
| 09-25 22:07 | T13 in: PR #31. Its attack and test-integrity reviews dispatched; records queued for a free slot |
| 09-25 22:12 | T9's fix round in (744 cases): the mechanism moved, so the re-measure ran with the attack question |
| 09-25 22:46 | T9's re-measure in: one limit introduced, two surviving mutants. The limit accepted, and the bounded correction sent to a fresh agent |
| 09-25 23:05 | The user decided D17 → T14 |
| 09-25 23:12 | T9's correction in (747 cases) |
| 09-25 23:20–23:29 | T13's attack, test-integrity and records reviews in. The fix round sent to the author. Wave 7 converged with the user |
| 09-25 23:47 | PR #32 (T14's section, brief and brief review) merged |
| 09-26 00:16 | PR #30 merged after the orchestrator's verification |

**Findings, per review** (the verdicts are the reviewers'):

| Review | Agent | Result |
|---|---|---|
| brief, wave 6 | `reviewer` | 24 findings, every CONFIRMED and MISSING item corrected before the claim |
| guarantee, #30 | `neovim-lua-developer` at `high`, reviewer charter | the attack holds. G1: the saved records shown with no group defined — fix before merge. G2, G3: three properties unpinned. G4: a user's colour before the first report, then `:highlight clear`, left `AineoReportDone` empty |
| records, #30 | `reviewer` | R1: "8 tests" is 7 tests and 12 cases. R2: an RC7 behaviour listed as a reading. R3: the task-lines style. R4: a pre-merge hash in the note. R5: the merge check against T13 was not verifiable yet |
| re-measure, #30, with the attack question | `neovim-lua-reviewer` | the round holds, except one limit it introduced: a scheme's own default link is kept (`sg_deflink`). Also a Learning clause missing, and MC3 and MAB3 surviving |

**Rounds on #30, a small fix:**
- the packet, 741 cases;
- a fix round by the author, 744 cases, which moved the mechanism;
- a re-measure;
- a bounded correction by a fresh agent, 747 cases.

The orchestrator's verification is in [[Implementation/Waves/00006-fixes/plan]] › *Landed*.

**Cost, per context** — read from the transcripts with `.claude/scripts/agent-context.py`:

| context | requests | last request's context | input (uncached) | cache write | cache read | output |
|---|---|---|---|---|---|---|
| brief review, wave 6 — `reviewer` | 129 | 324,690 | 258 | 303,751 | 23,975,417 | 26,206 |
| T9 implementer, packet and fix round — `neovim-lua-developer` | 141 | 323,534 | 284 | 1,355,981 | 27,920,994 | 18,467 |
| guarantee review, #30 — `neovim-lua-developer` | 75 | 186,166 | 150 | 320,693 | 9,795,227 | 8,052 |
| records review, #30 — `reviewer` | 80 | 199,589 | 160 | 540,155 | 10,530,388 | 2,201 |
| re-measure, #30 — `neovim-lua-reviewer` | 111 | 275,902 | 226 | 496,309 | 20,120,570 | 12,977 |
| bounded correction, #30 — `neovim-lua-developer` | 83 | 181,024 | 166 | 445,414 | 10,649,466 | 3,407 |

Not in the table:
- PR #28's records review, an `ai/` pass run during the wave;
- T14's brief review;
- T13's contexts, which come with T13's pass;
- the orchestrator's own context.

## Deviations and disclosures

- **T9 ran as a small fix**, as the user called it. It gave up the separate attack review at `xhigh`. It kept the re-measure, because its fix round moved a mechanism.
- **T9 ran on a `bugfix/` branch** as the small-fix class prescribes, although colouring the Report is a new capability (the records review's note).
- **Two errors in T9's brief were the orchestrator's:**
  - RC7's claim that the frozen pins catch M14p and M15p;
  - the "8 tests" count, repeated in the brief to the records review.
  
  Both were corrected in the rounds, not in the brief.
- **The limit T9 ships with was accepted by the orchestrator, not the user:** a colour scheme's own default link for an aineo group, set before aineo's first definition, is kept. It is pinned, and it is in the T9 note's *Limits*.
- **The orchestrator's conversation was compacted mid-wave, at the user's request.** The state was carried across by the ledger's handover block.
- **The shared help:**
  - T9 and T13 each edit a section of `doc/aineo.txt`, under rule 2's exception.
  - Each packet ran the merge check against the other's head, and T13 ran it again against T9's final head `40bc378`: `git merge-tree` gave no conflict, and `tests/test_doc.lua` passed, 36 cases, on both versions.

## Open threads

- **T13, Neovim 0.12 compatibility (PR #31):** its fix round is in, and a re-measure with the attack question is running.
- **T14 and T12:** T14 follows T13's merge, and T12 follows T14. Each brief's facts are re-checked on the new `dev` before dispatch, and a moved fact is a dated amendment.
- **T10 and T11:** still to plan as dated sections, after T9 in the report home.
- **A defect that predates T13**, found by T13's attack review, left for a later packet. `lua/aineo/health.lua` calls `config.recorded_setup_options()` as an argument to its `pcall`, so it is evaluated outside it. The attack review measured that `:checkhealth aineo` then fails whole when `setup()` options hold a userdata.
- **The readings for the MVP review** that T9 adds: the status colours, in the T9 note's *Readings*.

## Commits

- T9, PR #30: `a86a69c` … `3d67b05` (9 commits) — [[Sessions/2026-09-25 — T9 Report colours]].
- The wave-6 plan, PR #29: `948aba9`, `ea8e7d2`, `d35dc4f` (the claim).
- T14's section, brief and brief review, PR #32: `62c4f84`, `0df0a84`.
- The `ai/` pass on the vimdoc section exception, PR #28: `cf08b99`, `f6c7c6b`.
- This knowledge pass: recorded after its merge by the next one.

## Decisions & reasoning

- **T13 before T12** — the user: "Yes, first". Neovim 0.12's error framing broke eight cases, and T12 would have been measured on a red suite.
- **T14 before T12**, because both touch `plugin/aineo.lua` (rule 2): T14 its open and focus paths, T12 its subcommand, action and key tables.
- **T9's mechanism is `:highlight default link`, with no autocommand** — the orchestrator's fix-round decision, taken on the condition that every RC4 case passed on both versions, which the fix round measured. It replaced `nvim_set_hl(…, { default = true })` plus a `ColorScheme` autocommand.
  - It fixes G4.
  - It removes an autocommand that could be defined twice.
  - Its cost is the limit above.
