# Wave 1 retrospective

**Author:** Mathias Santos de Brito, with Claude — the orchestrator (Opus 5.5, session `619e5f9a`)
**Branch:** `knowledge/wave1-close-wave2-plan`

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] · [[Implementation/Waves/00001-tooling/plan]] · [[Implementation/Waves/00002-layout-session-report/plan]]
- The packet's own record: [[Sessions/2026-09-23 — T1 tooling foundation]]
- Before it: [[Sessions/2026-09-23 — Orchestration and knowledge vault scaffold]]

## Context

**Goal:** land T1 — the tooling every later packet stands on — under the orchestrate skill, with merging delegated by the user ("Delegate to the orchestrator, you assume the role of orchestrator", 2026-09-23), and measure T2 against the real Claude Code once the user trusted the folder. The user's standing order since 2026-09-23 23:41 CEST: "move on with the implementation until you have all the functionalities implemented, I will then review the first MVP".

## What was done

**Timeline** (CEST; the times the orchestrator wrote into its ledger, read from the clock in the same call — a step can precede its line by some minutes; the wave-2 measurements are timed by their evidence files):

| When | Step |
|---|---|
| 09-23 22:38 | bootstrap `511e289` pushed by the user; PRs #1 (wave-1 agent configuration) and #2 (the v1 plan), each with one records review and one fix round |
| 22:51 | #2 and #1 merged; the user's Neovim set to load aineo from a clone of `dev` |
| 22:53 | brief review of wave 1 dispatched; it found five places that would mislead — among them config keys backed by no plan row, which the user settled as D13 |
| 23:25 | PR #3: the wave-1 plan and its claim; 23:26 T1 dispatched |
| 23:49 | the user trusted the folder; T2 measured by the orchestrator (Q1, Q2, Q4 at idle) |
| 09-24 00:17 | PR #4 (T1) under review: attack, test-integrity, records |
| 00:46 | one fix round to the author, ten orchestrator decisions |
| 00:55–00:59 | while it ran: the MCP handshake recorded, Q4 measured during a turn, the fixture bytes recorded — for wave 2 |
| 02:31 | the fix round in; the re-measure dispatched with the attack question |
| 02:34–02:54 | the ai pass (PR #5) opened, reviewed and corrected |
| 03:37 | the re-measure refuted the new runner's exit status; one bounded correction to a fresh agent |
| 05:44–05:45 | the correction in; the orchestrator's verification of `5b323d8` |
| 05:46 | #4 and #5 merged; then this knowledge pass |

**Findings, per review** (each report in the orchestrator's scratch directory; the verdicts are the reviewers'):

| Review | Agent | Result |
|---|---|---|
| records, #1 | `reviewer` | 4 CONFIRMED, 5 MISSING |
| records, #2 | `reviewer` | 8 CONFIRMED, 1 MISSING, 2 UNVERIFIABLE |
| brief, wave 1 | `reviewer` | five misleading places; one (config keys) went to the user |
| attack, #4 | `neovim-lua-developer` | A1–A10 — the exit status defeated five ways, the log leak, a shadowable pin, unchecked `deps/`, silent empty files, dotted keys, `FILE` pasted into a shell string |
| test-integrity, #4 | `reviewer` | I1–I12 — six measured fixes; 38 mutants, 10 surviving |
| records, #4 | `reviewer` | R1–R11 — 8 CONFIRMED, 1 MISSING, 1 UNVERIFIABLE |
| re-measure, #4 | `neovim-lua-developer` | the round's records held; its runner did not — a failing run could still exit 0; runs unbounded; `make deps` blind to git's status |
| records, #5 | `reviewer` | 10 CONFIRMED, 2 MISSING, 1 UNVERIFIABLE — among them the orchestrator's own false footer claim |

**Rounds on #4:** the packet (37 tests, 59 cases); one fix round (81 cases); one bounded correction (111 cases). The orchestrator's verification of the final head killed M1–M3 and three reverted re-measure findings, each by assertion ([[Implementation/Waves/00001-tooling/plan]] › *Landed*).

**Cost, per context** — read from the transcripts, one row per API request deduplicated by request id; tokens as the transcripts' `usage` reports them:

| context | requests | last request's context | input (uncached) | cache write | cache read | output |
|---|---|---|---|---|---|---|
| records review, PR #1 (ai prep) — `reviewer` | 44 | 170,386 | 88 | 170,384 | 4,490,548 | 1,528 |
| records review, PR #2 (v1 plan) — `reviewer` | 52 | 145,301 | 104 | 145,299 | 4,466,637 | 1,890 |
| brief review, wave 1 — `reviewer` | 72 | 216,883 | 144 | 216,881 | 9,767,596 | 1,655 |
| T1 implementer, packet + fix round — `neovim-lua-developer` | 266 | 771,677 | 534 | 4,851,543 | 109,978,690 | 36,341 |
| attack review, PR #4 — `neovim-lua-developer` | 105 | 286,996 | 210 | 266,297 | 20,214,108 | 4,741 |
| test-integrity review, PR #4 — `reviewer` | 72 | 228,086 | 144 | 212,187 | 10,194,608 | 1,705 |
| records review, PR #4 — `reviewer` | 91 | 263,101 | 182 | 235,323 | 14,458,343 | 2,372 |
| re-measure, PR #4 — `neovim-lua-developer` | 193 | 438,041 | 396 | 1,845,938 | 56,361,885 | 5,773 |
| bounded correction, PR #4 — `neovim-lua-developer` | 165 | 484,170 | 332 | 1,679,833 | 47,494,615 | 6,875 |
| records review, PR #5 (ai pass) — `reviewer` | 82 | 248,020 | 164 | 232,121 | 13,098,842 | 2,762 |
| the orchestrator's session (whole session so far, scaffold and convergence included) | 398 | 365,020 | 836 | 1,585,875 | 163,974,196 | 597,808 |

Cache reads dominate every row: an agent's cost grows with the square of its turns, as the orchestrate skill says. The T1 implementer, carrying its packet and its fix round in one context, is by far the largest agent row; the correction, given to a fresh agent, cost less than half of it.

## Commits

- T1: [[Sessions/2026-09-23 — T1 tooling foundation]] › *Commits* (`5edf69f` … `7284c00`).
- The ai pass, PR #5: `12353b2`, `83c263e`, `798275d`.
- This knowledge pass: recorded after its merge by the next one.

## Decisions & reasoning

- **A pushed commit's false message is corrected by a new commit, never rewritten** — decided by the orchestrator over the records reviewer of #4, who suggested rewriting `711fcc5`; `c63fecb` (was `f36a06f`) says what was wrong.
- **The runner owns the exit status, and its guards read only its own state** — the fix round's decision, then the correction's after the re-measure refuted a guard on mini.test's `is_executing()`.
- **The suite's isolation lives in the `Makefile` and the minimal init, not in `prepare_project`** — T1's placement, recorded in the specialists' files by PR #5.
- **`VIMRUNTIME` from a parent Neovim stays** — the orchestrator's decision in the correction brief: unsetting it breaks development builds of Neovim.
- **T4 runs beside T5 in wave 2, by injection** — the orchestrator's plan, after the user asked on 2026-09-24 to plan and implement the Claude session now.

## Learnings extracted

- [[Learnings/mini.test v0.18.0 hangs instead of failing]]
- [[Learnings/A test case can end a mini.test run green]]
- [[Learnings/NVIM_LOG_FILE leaks past XDG isolation]]
- [[Learnings/Claude Code's interactive CLI in a Neovim terminal]]

**What the process taught** (adjustments landed in PR #5): a resource name holds no hyphen; never a bare `cd` into a worktree — a subshell instead; the orchestrator's own measurements are claims too — its "footer absent at startup" came from a run that had inherited another session's variables, and the records review of #5 caught it. **A re-measure is worth its cost when a round replaces a mechanism:** the fix round's counts and records were right, and its new runner was still defeatable.

## Open threads

- **For the MVP review:** Q5 (a startup dashboard against the autostart); the eleven readings the wave-2 briefs take where the plan's rows are silent ([[Implementation/Waves/00002-layout-session-report/plan]] › *Decisions for the user*).
- **For T7:** `setup()` with a table that contains itself raises a stack overflow since the correction (T1's session note, *Limits*); the composition root resolves the configuration.
- **Outside this repository:** the template's PR #1 in `claude-project` awaits the user's merge.
- **Claude Code usage:** the measurement screens of 2026-09-24 showed the account at 79 % of its weekly limit, which bounds how many agents a wave should run at once.
