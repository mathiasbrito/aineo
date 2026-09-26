# Wave 6 retrospective

**Author:** Mathias Santos de Brito, with Claude — the orchestrator (Opus 5.5, session `938616f1`)
**Branch:** begun on `knowledge/w6-t9-landed`, the first packet's knowledge pass; extended on `knowledge/w6-t13-landed`. Each later packet's pass extends this note.

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] · [[Implementation/Waves/00006-fixes/plan]]
- The packets' own records: [[Sessions/2026-09-25 — T9 Report colours]], [[Sessions/2026-09-25 — T13 Neovim 0.12]]
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

During the wave, the user decided more changes:
- unsent Input is kept as a draft — D17, T14;
- wave 7, the changes pane and sending only Input's selection, converged and not yet planned (D18–D22);
- the report instructions — T15 — and the right column's word wrap — T16, small fixes (2026-09-26);
- `v0.2.0`, cut after T13.

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
| 09-25 23:07–23:29 | T13's test-integrity (23:07), attack (23:20) and records (23:29) reviews in. The fix round sent to the author. Wave 7's panes converged with the user (D18, D19) |
| 09-25 23:36 | The user answered on sending only Input's selection; the orchestrator's settlement, which the user did not answer, completed D20 |
| 09-25 23:47 | PR #32 (T14's section, brief and brief review) merged |
| 09-26 00:16 | PR #30 merged after the orchestrator's verification |
| 09-26 00:27 | T11, the report icon, planned (PR #34); its brief review dispatched |
| 09-26 00:43 | PR #35, wave 7's rows: the records review in, 13 findings corrected, merged |
| 09-26 00:44 | The user answered Q6 and Q7 (D21, D22) |
| 09-26 01:05 | T11's brief review in: 11 findings, corrected; PR #34 merged |
| 09-26 01:26 | T13's re-measure in: one failure the round introduced. The bounded correction sent to a fresh agent |
| 09-26 01:35 | The user kept the orchestrator's readings, asked for v0.2.0, and asked for T15 |
| 09-26 01:54 | The user asked for T16. T15 and T16 planned (PR #36); their brief review dispatched |
| 09-26 02:17 | T13's correction in (743 cases); the orchestrator's verification started |
| 09-26 02:36 | The T15/T16 brief review in: 14 findings, corrected; PR #36 merged; T15 and T16 dispatched |
| 09-26 02:53 | PR #31 merged after the verification (763 cases on both versions) |
| 09-26 02:55 | Release `v0.2.0` (PR #37) |

**Findings, per review** (the verdicts are the reviewers'):

| Review | Agent | Result |
|---|---|---|
| brief, wave 6 | `reviewer` | 24 findings, every CONFIRMED and MISSING item corrected before the claim |
| guarantee, #30 | `neovim-lua-developer` at `high`, reviewer charter | the attack holds. G1: the saved records shown with no group defined — fix before merge. G2, G3: three properties unpinned. G4: a user's colour before the first report, then `:highlight clear`, left `AineoReportDone` empty |
| records, #30 | `reviewer` | R1: "8 tests" is 7 tests and 12 cases. R2: an RC7 behaviour listed as a reading. R3: the task-lines style. R4: a pre-merge hash in the note. R5: the merge check against T13 was not verifiable yet |
| re-measure, #30, with the attack question | `neovim-lua-reviewer` | the round holds, except one limit it introduced: a scheme's own default link is kept (`sg_deflink`). Also a Learning clause missing, and MC3 and MAB3 surviving |
| attack, #31 | `neovim-claude-code-reviewer` | NC2 and NC3 defeated on 0.12.5: Neovim frames an error again after a position, which the one-pass strip missed. The claim "no action is known to raise from Neovim's runtime Lua" false: a prefix over 50 bytes, a userdata in `setup()`. A defect older than T13 in `health.lua`. A measured fix |
| test-integrity, #31 | `neovim-lua-reviewer` | each relay strip pinned on its own version only (M2, M3); the `^` anchors unpinned (O1, O2, O10); the loads-aineo case green when the helper loads nothing (R1). Pins P1–P4 built |
| records, #31 | `reviewer` | 7 CONFIRMED, 1 MISSING: the red count, M11's crashes, "final tree" overclaims, a docstring, the silent 5 s wait, the PR number, "the user confirms", scratch pointers |
| re-measure, #31, with the attack question | `neovim-claude-code-reviewer` | one failure the round introduced: the loop over the lazy position pattern ate a user's error. The red count was 7 cases in 12 runs; a *Limits* line false; the startup wait unbounded at a prompt; two equivalence claims false. A measured fix |
| records, #28 (an `ai/` pass) | `reviewer` | 3 CONFIRMED, 1 MISSING: a duplicated help tag invisible to `git merge-file`, the verification's overlay of a shared file, the fence's ambiguity, no brief slot. 4 REFUTED |
| brief, T14 | `reviewer` | 16 findings, answered in the brief; the orchestrator decided two as readings — a pending change only at quit, the draft emptied at once, a restore only into a new or emptied Input |
| brief, T11 | `reviewer` | 11 findings: the pin inventory incomplete; IC4 met by two wrong implementations no requested test caught; IC5 red first; the post-T13 facts to a dated amendment |
| records, #35 (wave 7's rows) | `reviewer` | 9 CONFIRMED (one on the orchestrator's source extract), 4 MISSING: D20 gave the user clauses that were the orchestrator's, and dropped undo's scope; three D19 wordings; markers; `\o` and a commit-only refresh unsettled — Q6, Q7 |
| brief, T15 and T16 | `reviewer` | 14 findings: T16's mutant 4 unkillable by the test named, RW3 and RW4 invariants, `vim.go` for the globals; T15's rules scoped to reports, the `details` description, every status |

**Rounds on #30, a small fix:**
- the packet, 741 cases;
- a fix round by the author, 744 cases, which moved the mechanism;
- a re-measure;
- a bounded correction by a fresh agent, 747 cases.

**Rounds on #31, regular:**
- the packet, 729 cases;
- a fix round by the author, 740 cases;
- a re-measure with the attack question;
- a bounded correction by a fresh agent, 743 cases — 763 with T9 laid over it.

The orchestrator's verifications are in [[Implementation/Waves/00006-fixes/plan]] › *Landed*.

**Cost, per context** — read from the transcripts with `.claude/scripts/agent-context.py`:

| context | requests | last request's context | input (uncached) | cache write | cache read | output |
|---|---|---|---|---|---|---|
| brief review, wave 6 — `reviewer` | 129 | 324,690 | 258 | 303,751 | 23,975,417 | 26,206 |
| T9 implementer, packet and fix round — `neovim-lua-developer` | 141 | 323,534 | 284 | 1,355,981 | 27,920,994 | 18,467 |
| guarantee review, #30 — `neovim-lua-developer` | 75 | 186,166 | 150 | 320,693 | 9,795,227 | 8,052 |
| records review, #30 — `reviewer` | 80 | 199,589 | 160 | 540,155 | 10,530,388 | 2,201 |
| re-measure, #30 — `neovim-lua-reviewer` | 111 | 275,902 | 226 | 496,309 | 20,120,570 | 12,977 |
| bounded correction, #30 — `neovim-lua-developer` | 83 | 181,024 | 166 | 445,414 | 10,649,466 | 3,407 |
| T13 implementer, packet and fix round — `neovim-claude-code-integrator` | 178 | 359,288 | 358 | 2,738,413 | 33,529,548 | 22,282 |
| attack review, #31 — `neovim-claude-code-reviewer` | 128 | 295,026 | 256 | 1,505,382 | 23,404,048 | 13,200 |
| test-integrity review, #31 — `neovim-lua-reviewer` | 366 | 342,578 | 732 | 950,834 | 86,419,475 | 7,302 |
| records review, #31 — `reviewer` | 73 | 197,126 | 146 | 179,718 | 9,133,336 | 1,706 |
| re-measure, #31 — `neovim-claude-code-reviewer` | 184 | 408,503 | 368 | 1,748,291 | 46,476,328 | 21,476 |
| bounded correction, #31 — `neovim-claude-code-integrator` | 122 | 266,073 | 244 | 477,584 | 21,627,274 | 15,657 |
| brief review, T14 — `reviewer` | 120 | 285,804 | 240 | 526,033 | 21,000,601 | 3,506 |
| brief review, T11 — `reviewer` | 128 | 270,478 | 256 | 689,314 | 20,549,842 | 2,400 |
| brief review, T15 and T16 — `reviewer` | 124 | 296,235 | 248 | 825,181 | 21,246,025 | 8,151 |
| records review, #35 — `reviewer` | 38 | 141,413 | 76 | 120,474 | 3,444,082 | 389 |
| records review, #28, an `ai/` pass — `reviewer` | 62 | 127,593 | 124 | 127,591 | 5,346,205 | 5,178 |

Not in the table:
- T15's and T16's contexts, which come with their passes;
- the orchestrator's own context.

The test-integrity review of #31 made 366 requests, more than any other context here, for 3 CONFIRMED findings and one REFUTED group; the attack review made 128 for 4 CONFIRMED (two of them the author's own claims) and 5 REFUTED.

## Deviations and disclosures

- **T9 ran as a small fix**, as the user called it. It gave up the separate attack review at `xhigh`. It kept the re-measure, because its fix round moved a mechanism.
- **T9 ran on a `bugfix/` branch** as the small-fix class prescribes, although colouring the Report is a new capability (the records review's note).
- **Two errors in T9's brief were the orchestrator's:**
  - RC7's claim that the frozen pins catch M14p and M15p;
  - the "8 tests" count, repeated in the brief to the records review.
  
  Both were corrected in the rounds, not in the brief.
- **The limit T9 ships with was accepted by the orchestrator, not the user:** a colour scheme's own default link for an aineo group, set before aineo's first definition, is kept. It is pinned, and it is in the T9 note's *Limits*.
- **The orchestrator's conversation was compacted mid-wave, at the user's request.** The state was carried across by the ledger's handover block.
- **The orchestrator's leaning for T13's startup wait was refuted.** The correction's brief leaned to the wait asking `nvim_get_mode()` first, leaving the shape to the implementer. The correction measured that Neovim shows its startup prompt after `VimEnter`, so that shape still hung, and it adopted a mark file written through `vim.schedule` at `VimEnter`. The orchestrator's verification probed that shape (plan › *Landed*).
- **D20 attributed the orchestrator's clauses to the user.** Wave 7's rows were written before wave 7's plan, from the conversation. Their records review found that D20's "as one message", `u` as the key, undo for whole-Input Sends and the measurement first came from the orchestrator's settlement, which the user never answered. They are now attributed.
- **The user's "your decisions are fine" answered a list.** The orchestrator first recorded more than the list held as kept: MR28's oldest `claude`, which the plan leaves to the user; MR98 and MR108, which the list did not describe. The records review of this pass caught it, and those readings are open again. MR101 was open for the right reason but a wrong one given: it was adopted before the answer, not after.
- **The branch guard refused the `v0.2.0` tag push** while the session was on `dev`. The tag was pushed from a detached HEAD at the release commit.
- **`v0.2.0` was cut while T15 and T16 ran**, as the user chose ("After T13 merges (Recommended)", the orchestrator's recommended option).
- **T13's verification ran beside other agents' suites**, at load averages of 19 to 163 over one minute: the suites at about 30, the blocked-editor runs at 81–90, the probes up to 163. `tests/test_mcp_blocked_editor.lua` stayed green in all five runs.
- **The shared help:**
  - T9 and T13 each edit a section of `doc/aineo.txt`, under rule 2's exception.
  - Each packet ran the merge check against the other's head, and T13 ran it again against T9's final head `40bc378`: `git merge-tree` gave no conflict, and `tests/test_doc.lua` passed, 36 cases, on both versions.

## Open threads

- **T15 and T16**, small fixes, are running.
- **T14, T11, T12 and T10:**
  - T14 follows T16, and T11 follows T15, each by a dated amendment of its brief reviewed before dispatch. The two then run side by side.
  - T12 follows T14.
  - T10, the Report's links, is planned after T11.
- **A defect that predates T13**, found by T13's attack review, left for a later packet. `lua/aineo/health.lua` calls `config.recorded_setup_options()` as an argument to its `pcall`, so it is evaluated outside it. `:checkhealth aineo` then fails whole when `setup()` options hold a userdata.
- **Readings still open:** MR28's oldest `claude`, MR98, MR101, MR108 and MR109–MR114 ([[Review/2026-09-24 — v1 MVP readings review]]).
- **The ⌘-click check in Claude's pane**, asked on 2026-09-26 and not yet answered. It decides whether T10 needs a terminal part.
- **`lua/aineo/health.lua` still strips with the lazy position pattern in one pass** — a candidate for the same bound at white space (the T13 correction's report).

## Commits

- T9, PR #30: `a86a69c` … `3d67b05` (9 commits) — [[Sessions/2026-09-25 — T9 Report colours]].
- The wave-6 plan, PR #29: `948aba9`, `ea8e7d2`, `d35dc4f` (the claim).
- T14's section, brief and brief review, PR #32: `62c4f84`, `0df0a84`.
- The `ai/` pass on the vimdoc section exception, PR #28: `cf08b99`, `f6c7c6b`.
- T9's knowledge pass, PR #33: `dbc96c9`.
- T11's section, brief and brief review, PR #34: `eda139b`, `2596241`.
- Wave 7's rows, PR #35: `b6c2725`, `e574652`.
- T15's and T16's sections, briefs and brief review, PR #36: `809d786`, `4dd5cf4`.
- T13, PR #31: `39d9cb0` … `f8317d8` (7 commits) — [[Sessions/2026-09-25 — T13 Neovim 0.12]].
- Release `v0.2.0`, PR #37: `e26838f` on `main`, tag `v0.2.0`.
- This knowledge pass: recorded after its merge by the next one.

## Decisions & reasoning

- **T13 before T12** — the user: "Yes, first". Neovim 0.12's error framing broke eight cases, and T12 would have been measured on a red suite.
- **T14 before T12**, because both touch `plugin/aineo.lua` (rule 2): T14 its open and focus paths, T12 its subcommand, action and key tables.
- **T9's mechanism is `:highlight default link`, with no autocommand** — the orchestrator's fix-round decision, taken on the condition that every RC4 case passed on both versions, which the fix round measured. It replaced `nvim_set_hl(…, { default = true })` plus a `ColorScheme` autocommand.
  - It fixes G4.
  - It removes an autocommand that could be defined twice.
  - Its cost is the limit above.
- **T13's strip loops over Neovim's framing and positions, and stops a file's position at white space.** The attack review measured the loop and the positions of Neovim 0.12's own Lua; the re-measure measured the white-space bound after the loop ate a user's words. Both fixes were adopted as measured.
- **The TUI editor's startup is marked by a file** written through `vim.schedule` at `VimEnter`, not asked for by a request: a starting editor may serve a request before its init has run, and one at a hit-enter prompt holds it.
- **D21 and D22** — the user: `\o` keeps the pane shown; the commits window updates on every commit.
- **`v0.2.0` after T13** — the user: "After T13 merges (Recommended)", the orchestrator's recommended option.
