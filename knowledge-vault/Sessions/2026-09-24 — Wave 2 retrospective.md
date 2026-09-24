# Wave 2 retrospective

**Author:** Mathias Santos de Brito, with Claude — the orchestrator (Opus 5.5, session `619e5f9a`)
**Branch:** `knowledge/wave2-close-wave3-plan`

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] · [[Implementation/Waves/00002-layout-session-report/plan]] · [[Implementation/Waves/00003-send/plan]]
- The packets' own records: [[Sessions/2026-09-24 — T3 layout]], [[Sessions/2026-09-24 — T4 Claude session]], [[Sessions/2026-09-24 — T5 report channel]]
- Before it: [[Sessions/2026-09-24 — Wave 1 retrospective]] · The MVP agenda it produced: [[Review/2026-09-24 — v1 MVP readings review]]

## Context

**Goal:** land T3 (the layout), T4 (the Claude session) and T5 (the report channel) in parallel under the orchestrate skill, merging delegated to the orchestrator. T4 ran beside T5 by injection — the composition root hands the session the servers entry, the tools to allow and the instructions — after the user asked on 2026-09-24: "Plan also the implementation of the plumbing of the claude agent with his window on the left, given that he received the instruction to report on it. after planning implement it."

## What was done

**Timeline** (CEST, 2026-09-24; the times the orchestrator wrote into its ledger, read from the clock in the same call):

| When | Step |
|---|---|
| 06:28 | wave 2 claimed (PR #8) and dispatched: T3 `neovim-lua-developer`, T4 and T5 `neovim-claude-code-integrator` |
| 07:31–08:40 | the three packets in — PR #9 (T3, 185 cases), PR #10 (T5, 214), PR #11 (T4, 145); reviews start as slots free, three agents at most |
| 07:58–10:28 | nine reviews: attack, test-integrity and records on each pull request |
| 08:40–09:05 | fix rounds sent to the T3 and T5 authors |
| 09:38 | the orchestrator records Claude Code's MCP-server approval dialog (no model turn) — new evidence for T4's readiness |
| 10:08 | the user: "one of the tasks are already in 966K tokens, I'm worried about the quality of the work with a context full" — the T5 author was at 964,041 tokens; its round finished in a fresh agent, and T4's fix round went to a fresh agent too |
| 10:31–11:37 | T3: re-measure, bounded correction by a fresh agent, the orchestrator's verification, merged |
| 11:42–12:42 | T5: re-measure, bounded correction by a fresh agent, verification, merged |
| 12:36–12:53 | the user: "keep xhigh for reviewers, set implementers to high" — PR #12 (effort by role), reviewed and merged |
| 15:06–16:56 | T4: fix round in (after a 90-minute whole-file mutant loop), re-measure, bounded correction by a fresh agent |
| 17:08–17:32 | T4: the orchestrator's verification — on its head and on its files laid over `dev` — merged |

**Findings, per review** (the verdicts are the reviewers'; each report in the orchestrator's scratch directory, its findings in the pull request's rounds and the packet's session note):

| Review | Agent | Result |
|---|---|---|
| records, PR #6 (wave-1 close) | `reviewer` | 9 CONFIRMED, 2 MISSING, 1 UNVERIFIABLE — among them Q5 moved to the MVP review with no record of anyone deciding it |
| brief, wave 2 | `reviewer` | 16 CONFIRMED, 1 MISSING, 1 UNVERIFIABLE; every brief "dispatch after corrections"; finding 16 a claude.ai Remote Control link in committed bytes — PR #6 closed unmerged, replaced by #7 |
| attack, #9 (T3) | `neovim-lua-developer` | 12 CONFIRMED and a note, with a measured prototype fix |
| test-integrity, #9 | `reviewer` | I1–I8, seven measured test fixes |
| records, #9 | `reviewer` | 6 CONFIRMED, 1 MISSING, 2 UNVERIFIABLE — the readings numbered `R#`, colliding with the plan's risks |
| re-measure, #9 | `neovim-lua-developer` | 11 findings: one defect the round introduced (a user's window taken for the file column), one fix that held only under `'nohidden'`, a restored session's Input name, record and pin gaps, and three limits present before the round |
| attack, #10 (T5) | `neovim-claude-code-integrator` | 8 CONFIRMED, 1 MISSING, 1 UNVERIFIABLE; the central guarantee (hostile fields rendered as text) held |
| test-integrity, #10 | `neovim-lua-developer` | I1–I7, measured fixes |
| records, #10 | `reviewer` | 6 findings — the mutant ledger, tests hard-coding the relay's path, schema and validator disagreeing on `null` |
| re-measure, #10 | `neovim-claude-code-integrator` | counts held; 11 findings, four of them introduced by the round — the answer reader not binary-safe among them — and one present before it |
| attack, #11 (T4) | `neovim-claude-code-integrator` | 8 CONFIRMED, 1 MISSING — readiness checked once, the MCP-server dialog read as ready |
| test-integrity, #11 | `neovim-lua-developer` | 8 CONFIRMED, 2 REFUTED groups |
| records, #11 | `reviewer` | 8 CONFIRMED, 4 MISSING — the readings a different list in every record |
| re-measure, #11 | `neovim-claude-code-reviewer` | counts held; 10 CONFIRMED, 2 REFUTED — a wiped terminal skipping the stop, an unenterable `cwd` running a copy of the editor |
| records, #12 (effort) | `reviewer` | 11 findings — the 400 K rule credited to the user when it is the orchestrator's |

**Rounds per pull request:** each of #9, #10 and #11 took a packet, one fix round, one re-measure with the attack question and one bounded correction by a fresh agent. Suite at the merge: T3's head 242 cases, T5's 258, T4's 176 — and `dev` with all three, measured on T4's files laid over `dev` before the merge: **454 cases, `Fails (0)`**.

**The orchestrator's verification** — literal mutants on each final head, each applied, shown with `git diff HEAD`, run, restored; every one killed — by assertion on T4's and T5's heads, while on T3's only the summary lines were kept ([[Implementation/Waves/00002-layout-session-report/plan]] › *Landed*).

**Cost, per context** — read from the transcripts with `.claude/scripts/agent-context.py`, one row per API request deduplicated by request id; tokens as the transcripts' `usage` reports them:

| context | requests | last request's context | input (uncached) | cache write | cache read | output |
|---|---|---|---|---|---|---|
| records review, PR #6 — `reviewer` | 108 | 307,355 | 216 | 303,322 | 19,285,892 | 2,090 |
| brief review, wave 2 — `reviewer` | 90 | 335,800 | 180 | 335,798 | 18,762,293 | 1,808 |
| T3 implementer, packet + fix round — `neovim-lua-developer` | 368 | 759,082 | 742 | 2,640,195 | 164,496,034 | 43,752 |
| T4 implementer, packet — `neovim-claude-code-integrator` | 271 | 597,626 | 542 | 2,071,290 | 96,084,768 | 38,748 |
| T5 implementer, packet + most of its fix round — `neovim-claude-code-integrator` | 420 | 964,041 | 842 | 1,558,810 | 222,958,356 | 48,207 |
| attack review, #9 — `neovim-lua-developer` | 71 | 277,310 | 142 | 347,515 | 12,538,623 | 4,282 |
| test-integrity review, #9 — `reviewer` | 86 | 311,858 | 172 | 295,959 | 16,471,019 | 2,385 |
| records review, #9 — `reviewer` | 66 | 259,383 | 132 | 240,255 | 10,710,370 | 1,743 |
| attack review, #10 — `neovim-claude-code-integrator` | 116 | 295,832 | 232 | 270,347 | 22,769,157 | 2,343 |
| test-integrity review, #10 — `neovim-lua-developer` | 71 | 305,289 | 142 | 289,390 | 13,156,602 | 2,060 |
| records review, #10 — `reviewer` | 99 | 323,564 | 198 | 307,151 | 20,918,787 | 3,599 |
| attack review, #11 — `neovim-claude-code-integrator` | 103 | 324,607 | 206 | 306,257 | 22,395,493 | 2,416 |
| test-integrity review, #11 — `neovim-lua-developer` | 119 | 299,326 | 238 | 1,208,847 | 22,167,628 | 3,350 |
| records review, #11 — `reviewer` | 87 | 301,439 | 174 | 285,540 | 16,782,926 | 3,633 |
| T5 fix round, finished by a fresh agent — `neovim-claude-code-integrator` | 166 | 481,562 | 332 | 464,862 | 51,612,941 | 17,405 |
| re-measure, #9 — `neovim-lua-developer` | 132 | 504,029 | 264 | 485,882 | 41,851,730 | 4,808 |
| bounded correction, #9 — `neovim-lua-developer` | 207 | 425,416 | 414 | 764,570 | 53,395,840 | 34,577 |
| re-measure, #10 — `neovim-claude-code-integrator` | 161 | 371,480 | 322 | 624,575 | 36,921,540 | 3,984 |
| bounded correction, #10 — `neovim-claude-code-integrator` | 233 | 515,017 | 466 | 492,557 | 69,881,680 | 8,446 |
| records review, #12 — `reviewer` | 70 | 203,270 | 140 | 187,371 | 9,024,125 | 2,122 |
| T4 fix round, a fresh agent — `neovim-claude-code-integrator` | 168 | 490,397 | 344 | 1,819,068 | 52,372,471 | 41,291 |
| re-measure, #11 — `neovim-claude-code-reviewer` | 134 | 383,246 | 268 | 367,148 | 32,541,020 | 2,938 |
| bounded correction, #11 — `neovim-claude-code-integrator` | 144 | 353,620 | 288 | 644,631 | 33,919,737 | 30,256 |

The three packet authors are the three largest rows, as in wave 1: an implementer that carries its packet into its fix round pays for every earlier turn again on each later one. The T5 author's last request carried 964,041 tokens; the agent that finished its round started fresh and ended at 481,562. Since the user's concern at 10:08, a fix round or a correction goes to a fresh agent once its author's context passes 400 K — a threshold the orchestrator chose, not a measured limit.

## Deviations and disclosures

- **A fix round ran for 90 minutes on mutants.** T4's fix-round agent re-ran its 48-row mutant table against the whole test file, one after another (16,654 s for the round). Nothing was stuck; the user asked whether it was. The next `ai/` pass says to run a mutant against the tests that target it.
- **The T4 packet read its charter from `main`** (the records review of #11, finding 4): agent worktrees start from `main`, whose `.claude/` was then the bootstrap's. Every brief since says to check out the branch before reading `.claude/`.
- **T4's branch predated T3 and T5 on `dev`**, so its head alone could not show the three together. The orchestrator laid T4's 20 files — all of them added, none changed — over `origin/dev` and ran the whole suite there before the merge (454 cases, `Fails (0)`).
- **The orchestrator's working directory slipped into a worktree twice** — once at 01:04 while planning, once at 17:07 during T4's verification — each by a bare `cd`, each moved back at once with nothing written there. The rule against it is in the orchestrate skill since PR #5.
- **The orchestrator measured the real Claude Code for wave 3** — three model turns in the folder the user trusted, every `CLAUDE*` variable removed — and put two decisions to the user before planning T6 and T7 (below).

## Commits

- T3, PR #9: `b47be4e` … `c1e3962` (20 commits) — [[Sessions/2026-09-24 — T3 layout]] › *Commits*.
- T5, PR #10: `adf4815` … `e006d58` (30 commits) — [[Sessions/2026-09-24 — T5 report channel]] › *Commits*.
- T4, PR #11: `f6b4beb` … `c7a9c99` (16 commits) — [[Sessions/2026-09-24 — T4 Claude session]] › *Commits*.
- The effort pass, PR #12: `fdb8ec0`, `08caf0e`.
- The wave-1 close, PR #7: `d5cb724`; the wave-2 claim, PR #8: `8725632`.
- This knowledge pass: recorded after its merge by the next one.

## Decisions & reasoning

- **A fix round or a correction goes to a fresh agent once its author's context passes 400 K** — the orchestrator's threshold, set after the user's concern about a 966 K context; recorded in the orchestrate skill by PR #12.
- **Implementers run at `high` effort, reviewers at `xhigh`** — the user, 2026-09-24 ("keep xhigh for reviewers, set implementers to high"); the reviewer variants `neovim-lua-reviewer` and `neovim-claude-code-reviewer` carry it, since an `Agent` call cannot set effort. Verified in the transcripts: a reviewer's requests carry `"effort":"xhigh"`, an implementer's `"high"`.
- **Send works while a turn runs, and Claude Code queues the message (D14)** — the user, 2026-09-24, over refusing during a turn, with the risk stated in the option: a permission dialog drawn in the 11–30 ms before the session notices it would take Send's Enter. Recorded as a limit.
- **On a bare start, aineo takes the screen from a startup dashboard (D15, resolving Q5)** — the user, 2026-09-24, over yielding to it.

## Learnings extracted

- [[Learnings/sockconnect's on_data hands a zero byte over as a newline]]
- [[Learnings/A deleted scratch buffer written to again blocks quitting]]
- [[Learnings/nvim --clean still loads plugins from the system site directories]]
- [[Learnings/A hidden terminal buffer starts at five rows]]

**What the process taught:** a re-measure paid for itself on every pull request of this wave — each found defects its fix round had introduced or left unfixed; the size of a context, not the quality of an agent, decided when to hand a round over; and a mutant run against a whole file is the slowest step of a round when the file drives real processes.

## Open threads

- **For wave 3 (T6):** `'ready'` is not "no turn running"; the 11–30 ms readiness lag after a dialog is D14's accepted limit — [[Implementation/Waves/00003-send/plan]].
- **For T7:** D15 (take the screen from a dashboard); `setup()` with a table that contains itself raises a stack overflow (T1's limits); show Claude's buffer at once — a hidden terminal gets five rows; whether Claude Code accepts `"type": ["string", "null"]` for `details` (MR33); an end-to-end test with the fake `claude` calling the report tool; the Report's E95 after a restored session.
- **For T8:** name MR38 (an erroring earlier `VimLeavePre` handler skips aineo's stop) in the health check and the help.
- **Mutant runs are the slow step of a round.** T4's fix round ran each of its 48 rows against the whole of `tests/test_claude.lua` (53 cases that drive real processes) — the 90 minutes; its correction ran each mutant against a copy of that file narrowed to the group the mutant targets, under `.tests/` ([[Sessions/2026-09-24 — T4 Claude session]] › *Correction*). The next `ai/` pass makes that the rule in the implementer and reviewer charters.
- **For the next knowledge and `ai/` passes:** the Learning *Claude Code's interactive CLI in a Neovim terminal* is split into claims (the records review of PR #6, finding 8) — adding wave 3's measurement that Claude Code queues a message submitted during a turn — and the trap links in `.claude/agents/neovim-claude-code-integrator.md` follow.
