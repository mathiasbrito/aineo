# Wave 7 retrospective

**Author:** Mathias Santos de Brito, with Claude — the orchestrator (Opus 5.5, session `938616f1`)
**Branch:** begun on `knowledge/w7-t23-landed`, T23's knowledge pass. Each later packet's pass extends this note.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D18–D22, C12, C13
- `Implementation/Waves/00007-panes/plan.md`
- [[Sessions/2026-09-27 — T23 git home]]
- [[Sessions/2026-09-26 — Wave 6 retrospective]], the wave it ran beside

## Context

Wave 7 builds what v1's plan still lacks: the right column's two panes (D18, D21), the changes pane with the session's files and commits (D19, D22), and a Visual-mode Send with undo (D20). It was planned on 2026-09-27 as a rolling wave of four packets: T23, the git home; T24, the panes; T25, the changes pane; T26, Visual Send.

T23 opened it beside wave 6's open packets, since all its files were new. Later that evening the user paused the wave: "we will not continue towards wave 7, finish the current work and wait my go to start wave 7". T23, already in its fix round, was finished. T24–T26 wait for the user's go. The wave stays claimed.

## What was done

**Timeline** (CEST; the times the orchestrator wrote into its ledger, read from the clock in the same call — a step can precede its line by some minutes):

| When | Step |
|---|---|
| 09-27 13:27 | Wave 7 planned (PR #76, opened 13:30); the planning probe on both versions |
| 09-27 13:59 | T23's brief review in: dispatch after corrections, 18 findings |
| 09-27 14:02 | The plan corrected on a new branch (PR #78, replacing #76, whose pushed branch conflicted with `dev`) and claimed; the modularity rows (PR #77); both merged; T23 dispatched |
| 09-27 16:06 | T23 in: PR #79, 1238 cases. The author's context was 522 K, so the fix round goes to a fresh agent. Two reviews dispatched; records queued for a slot |
| 09-27 17:16–17:29 | The attack, test-integrity and records reviews in |
| 09-27 17:30 | The fix round sent to a fresh agent |
| 09-27 20:16 | The user paused wave 7. The fix round came in the same minute |
| 09-27 20:16 | The fix round in (1260 cases): mechanisms replaced, so the re-measure ran with the attack question |
| 09-27 21:25 | The re-measure in: the round held; four findings. The bounded correction sent to a fresh agent at 21:43 |
| 09-27 22:49 | The correction in (1265 cases); the orchestrator's verification started |
| 09-27 23:57 | PR #79 merged after the verification (1328 cases on both versions, 23 mutants killed). No release |

**Findings, per review** (the verdicts are the reviewers'):

| Review | Agent | Result |
|---|---|---|
| brief, T23 | `reviewer` | dispatch after corrections, 18 findings. `git diff` takes `index.lock` despite `GIT_OPTIONAL_LOCKS=0`; a `logs/HEAD` watch dies after `git gc`; Linux ignores the recursive flag; fixtures under `.tests/` sit inside the checkout's repository; the tests' git isolation already existed; GH7's list was incomplete; the modularity tables list every home |
| attack, #79 | `neovim-lua-reviewer` | defeatable on its central claims. The private copy hid a same-second edit (5 of 5); the bound killed git only; paths read as pathspecs; a signal counted as an answer; carriage returns stripped; the watch could be starved; index-only changes unreported (a spec gap); the editor's `GIT_*` variables reached git |
| test-integrity, #79 | `reviewer` | seven cases green for the wrong reasons: the watch and process cases, and the gc case, which passed under the very mutant it was written for. Eleven survivors; pins built for eight |
| records, #79 | `reviewer` | the arrived-green table named killers that did not kill; 31 of 75 mutants were descriptions; mutant labels reused the project's ID prefixes; the minimum git (2.31) rested on a false recall |
| re-measure, #79, with the attack question | `neovim-lua-reviewer` | the round held. The bound still waited for a process git leaves running; reads could run a repository hook; the round's `GIT_LITERAL_PATHSPECS` broke on an editor's `GIT_ICASE_PATHSPECS`; M2 unpinned |

**Rounds on #79, regular:**
- the packet, 1238 cases;
- a fix round by a fresh agent (the author's context was 522 K), 1260 cases, which replaced the bound's kill, the burst's end and what the watch reports;
- a re-measure with the attack question;
- a bounded correction by a fresh agent, 1265 cases;
- 1328 laid over `dev`, which by then held T19: the whole suite once per version, and the mutants on their covering files (D26).

**Cost, per context** — read from the transcripts with `.claude/scripts/agent-context.py`:

| context | requests | last request's context | input (uncached) | cache write | cache read | output |
|---|---|---|---|---|---|---|
| brief review, T23 — `reviewer` | 90 | 280,080 | 180 | 259,141 | 14,410,169 | 3,149 |
| T23 implementer, packet — `neovim-lua-developer` | 296 | 522,343 | 592 | 2,824,609 | 96,131,092 | 47,654 |
| attack review, #79 — `neovim-lua-reviewer` | 173 | 380,559 | 346 | 1,063,130 | 42,226,979 | 4,232 |
| test-integrity review, #79 — `reviewer` | 123 | 361,787 | 246 | 1,530,026 | 25,702,529 | 17,028 |
| records review, #79 — `reviewer` | 115 | 319,840 | 230 | 298,638 | 22,880,149 | 10,237 |
| fix round, #79 — `neovim-lua-developer` | 271 | 602,628 | 542 | 5,062,366 | 98,274,997 | 27,027 |
| re-measure, #79 — `neovim-lua-reviewer` | 200 | 460,343 | 400 | 734,112 | 54,373,798 | 9,506 |
| bounded correction, #79 — `neovim-lua-developer` | 147 | 289,809 | 294 | 1,017,805 | 27,661,962 | 16,029 |

Not in the table: the orchestrator's own context.

## Deviations and disclosures

- **A conflict inside the orchestrator's brief:** GH2 asked for a `copied` kind, and GH7 for `-M`, which turns copy detection off. The author kept GH7, and the orchestrator accepted it as its own brief's conflict (MR188).
- **The brief's first "measured" facts were not all measured where they mattered.** Its brief review found `git diff`'s lock and the `logs/HEAD` watch's death after `git gc`. The probe had measured only an empty commit.
- **The fix round wrote outside its worktree once.** A `Write` created a placeholder file in a new folder beside the developer's projects; it removed the file and its folder at once, and the orchestrator confirmed the folder was gone.
- **The fix round's first 0.11.6 mutant run was invalid:** 0.12.5's `VIMRUNTIME` leaked into it. It was re-run.
- **The re-measure's host load reached 921**, while T22's side-by-side runs measured beside it. Its timings name their loads.
- **The orchestrator's verification missed a covering file for M2:** its list gave `test_git_lock.lua`, but the correction pinned M2 in `test_git_process.lua`. M2 was killed by assertion in the whole suite instead.
- **T23 landed with the wave paused.** The user's instruction came while its fix round ran. The orchestrator read "finish the current work" as including T23, said so to the user, and started nothing else of wave 7.

## Decisions & reasoning

- **T23 beside wave 6** — the orchestrator: all its files were new, and a session may hold two claimed waves whose files are disjoint (orchestrate §2).
- **An index write counts as a change of the list** — the orchestrator's decision on the attack review's finding 7. A commit that changes no file then reports one too (MR189); T25 re-reads the list, and nothing is lost.
- **The user's and the repository's attributes stay in force** — the orchestrator's decision on the re-measure's finding 4. GH7 makes the home independent by flags, not by switching the user's files off, and attributes also decide what counts as changed (MR190).
- **Wave 7 paused after T23** — the user, 2026-09-27.

## Open threads

- **T24–T26** wait for the user's go. D20's four clauses are to be settled before T26's dispatch or at the MVP review.
- **The copied kind** (MR188): T25, or the user, decides whether a copy should show as copied.
- **Linux** was not run (MR192).
- **A descendant of git outside its group** holds the answer back past the limit (MR196).

## Commits

- The wave-7 plan and its claim, PR #78: `9666cb0`, `5c6481e`.
- The modularity rows for the git home, PR #77 (`ai/`): `1c931c8`.
- T23, PR #79: `2f44c73` … `da18aa6` (19 commits) — [[Sessions/2026-09-27 — T23 git home]].
- This knowledge pass: recorded after its merge by the next one.
