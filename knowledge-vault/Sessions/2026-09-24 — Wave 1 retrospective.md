# Wave 1 retrospective

**Author:** Mathias Santos de Brito, with Claude — the orchestrator (Opus 5.5, session `619e5f9a`)
**Branch:** `knowledge/wave1-close-wave2-plan-v2` (supersedes PR #6's `knowledge/wave1-close-wave2-plan`)

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
| records, #1 | `reviewer` | by its findings' headings 5 CONFIRMED, 4 MISSING, 2 UNVERIFIABLE (its own summary line said 4 and 5 — the records review of PR #6 counted the headings) |
| records, #2 | `reviewer` | 8 CONFIRMED, 1 MISSING, 2 UNVERIFIABLE |
| brief, wave 1 | `reviewer` | 14 findings, five of them places that would mislead; one (config keys) went to the user |
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
| the `claude-code-guide` agent (the user's question about a local API, before the plan) | 8 | 46,673 | 66 | 46,665 | 231,652 | 397 |
| the orchestrator's session (the whole session up to 2026-09-24 05:49:30 CEST, scaffold and convergence included) | 398 | 365,020 | 836 | 1,585,875 | 163,974,196 | 597,808 |

Cache reads dominate every row: an agent's cost grows with the square of its turns, as the orchestrate skill says. The T1 implementer, carrying its packet and its fix round in one context, is by far the largest agent row; the correction, given to a fresh agent, cost less than half of it.

## Deviations and disclosures

- **PR #5's third commit (`798275d`, was `22906c6`) merged checked only by the orchestrator**, against the orchestrate skill's §7 ("reviewed before they merge, always"): the records review covered `12353b2`, the second commit answered its findings, and the third brought the pass to T1's corrected head with new sentences (the run limit, the removed variables, the guard trap) that no reviewer read before the merge.
- **The integrity reviewer of PR #4 disclosed** that during its M1, MU6 and one R11 run a runner resolved paths under the developer's home; its before-and-after `stat` of the shada and the log and a `find -newer` showed nothing written.
- **T2's first run inherited the orchestrating session's `CLAUDE*` variables**, the Remote Control bridge's among them, for about 80 s before it was stopped; every later run removed them.
- **The orchestrator edited the user's own Neovim configuration**, at the user's request: a lazy.nvim spec loading aineo from `~/Development/Personal/aineo-dev`, and snacks.nvim's dashboard turned off ("the aineo should open"). Both are uncommitted in the user's configuration repository.
- **PR #6 pushed a claude.ai Remote Control link** inside the recorded terminal bytes (the brief review of wave 2, finding 16). It was replaced before anything merged, and PR #6 was closed unmerged in favour of this pull request, so `dev`'s history never carries it; the closed pull request's commit still does.

## Commits

- T1: [[Sessions/2026-09-23 — T1 tooling foundation]] › *Commits* (`5edf69f` … `7284c00`).
- The ai pass, PR #5: `12353b2`, `83c263e`, `798275d`.
- This knowledge pass: recorded after its merge by the next one.

## Decisions & reasoning

- **A pushed commit's false message is corrected by a new commit, never rewritten** — decided by the orchestrator over the records reviewer of #4, who suggested rewriting `711fcc5`; `c63fecb` (was `f36a06f`) says what was wrong.
- **The runner owns the exit status, and its guards read only its own state** — the fix round's decision, then the correction's after the re-measure refuted a guard on mini.test's `is_executing()`.
- **The suite's isolation lives in the `Makefile` and the minimal init, not in `prepare_project`** — T1's placement, recorded in the specialists' files by PR #5.
- **`VIMRUNTIME` from a parent Neovim stays** — the orchestrator's decision in the correction brief: unsetting it breaks development builds of Neovim.
- **T4 runs beside T5 in wave 2, by injection** — reversing the dependency added in `c0a908a` after the records review of PR #2 (finding 3: T4 uses C5 and C6); injection answers that finding's concern, since T4 receives both and builds neither. The orchestrator's plan, after the user asked on 2026-09-24 to plan and implement the Claude session now.

## Learnings extracted

- [[Learnings/mini.test v0.18.0 hangs instead of failing]]
- [[Learnings/A test case can end a mini.test run green]]
- [[Learnings/NVIM_LOG_FILE leaks past XDG isolation]]
- [[Learnings/Claude Code's interactive CLI in a Neovim terminal]]

**What the process taught** (adjustments landed in PR #5): a resource name holds no hyphen; never a bare `cd` into a worktree — a subshell instead; the orchestrator's own measurements are claims too — its "footer absent at startup" came from a run that had inherited another session's variables, and the records review of #5 caught it. **A re-measure is worth its cost when a round replaces a mechanism:** the fix round's counts and records were right, and its new runner was still defeatable.

## Open threads

- **Before T7 is dispatched:** Q5 (a startup dashboard against the autostart) is converged with the user — the plan's Q5 row says so; an earlier draft of this note moved it to the MVP review, which no one decided.
- **For the MVP review:** the fourteen readings the wave-2 briefs take where the plan's rows are silent ([[Implementation/Waves/00002-layout-session-report/plan]] › *Decisions for the user*).
- **For T7:** `setup()` with a table that contains itself raises a stack overflow since the correction (T1's session note, *Limits*); the composition root resolves the configuration.
- **The Learning *Claude Code's interactive CLI in a Neovim terminal*** is not titled as a claim and holds several facts (the records review of PR #6, finding 8). Renaming or splitting it changes the trap links in `.claude/agents/neovim-claude-code-integrator.md`, so it waits for the wave-2 adjustment pass (`ai/`), which lands before that wave's knowledge pass.
