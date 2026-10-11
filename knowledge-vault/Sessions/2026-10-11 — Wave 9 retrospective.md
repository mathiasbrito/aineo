# Wave 9 retrospective

**Author:** Mathias Santos de Brito, with Claude — knowledge-writer agent (Sonnet 5.5), for the orchestrator's session `55110cd0`
**Branch:** `knowledge/w9-landed`, cut from `dev` `536a694` after the last merge and release; this pass lands the wave.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D31–D46, T35–T42
- `Implementation/Waves/00009-worktrees-sessions/plan.md` — its *Landed* holds each stage's record, the departures and the complete list of assumptions, A1–A92
- The packets: [[Sessions/2026-10-07 — T35 Session switch]], [[Sessions/2026-10-07 — T36 Report per session]], [[Sessions/2026-10-07 — T37 Changes per session]], [[Sessions/2026-10-08 — T38 Changes worktrees]], [[Sessions/2026-10-08 — T39 Panes follow switch]], [[Sessions/2026-10-09 — T42 Focus diff]], [[Sessions/2026-10-10 — T40 Lost editor]], [[Sessions/2026-10-10 — T41 Dead session handover]], and the helper fix, [[Sessions/2026-10-10-b — Fixture mkdir race]]
- [[Sessions/2026-10-07 — Wave 8 retrospective]], the wave before

## Context

On 2026-10-06 the user sent two requests in the series that wave 8 opened: the changes pane should follow the agents' worktrees, and aineo should detect a session change made inside Claude Code and reload the Report and the changes pane with that session's content, which meant that the content of sessions must survive switches as well as exit. Neither was a small fix. The converge round put eleven decisions (P1–P11) to the user, who answered on 2026-10-07 with every recommendation but one: Input's draft is kept per session, not per directory (D40), "because it is used to catalog changes and notes that goes to the prompt". Those became D31–D41. During the wave the user decided D42–D44 (reports whose editor has quit, the hook's deliverer, the user's own `--settings`), D45 (a dead session handed to its replacement) and, between the stages, D46 (Enter moves the cursor to its diff).

The wave was rolling and ran in three stages: T35, T36 and T37 (2026-10-07 and 2026-10-08); T38 and T39 (2026-10-09), with T42 as a small fix between them; and T40 and T41 (2026-10-10 and 2026-10-11), with a test-helper fix beside them. It ran under the user's instruction of 2026-10-06 to assume the orchestrator's recommendations and report them afterwards: A1–A92, in the plan's *Landed*.

## What was done

### What each packet delivered

- **T35, the session switch** (PR #137): Claude Code started with `SessionStart` and `SessionEnd` command hooks through a merged `--settings` file; a detached deliverer tells the editor and waits for its answer (D43); the claude home follows the session, takes a switch only after the followed id's `SessionEnd`, and keeps the session for the directory (D38).
- **T36, the Report and Input's draft per session** (PR #135): one records file and one draft per Claude session id (D39, D40).
- **T37, the changes pane per session** (PR #136): the base and the save marks kept per session (D41).
- **T38, the changes pane follows the worktrees** (PR #142): beside the editor's own checkout, each of the repository's worktrees with its files and commits, Enter showing their diffs (D31–D35).
- **T39, the panes follow a switch** (PR #143): the Report, Input's draft and the changes pane show the session Claude Code is on, at a start's confirmation and at every switch.
- **T42, Enter moves the cursor to its diff** (PR #146, D46, a small fix).
- **T40, reports from a Claude Code whose editor has quit** (PR #150): a report finds a claimant, the starting editor, another Neovim that shows its session, or the session's records on disk, and `:Aineo claim [id]` lets a Neovim follow a session its terminal does not run (D42, D43).
- **The test-helper fix** (PR #152, test-only): the fixtures' `mkdir` retried when another Neovim wins the race (E739).
- **T41, a dead session handed to its replacement** (PR #154): when a resume finds no conversation, the fresh session takes the dead one's Report records, Input draft, changes base and save marks (D45).
- **Released** in four versions: v0.2.16 (T35–T39), v0.2.17 (T42), v0.2.18 (T40), v0.2.19 (T41 and the helper fix).

**The suite** grew from 1929 cases at the wave's base to 2229 at stage 1's end, 2325 at stage 2's, 2422 after T40, 2427 after the helper fix and 2494 after T41. The orchestrator's whole-suite verifications in stage 2 and stage 3 each took between 4:38 and 5:15.

### What worked

- **The hook relay was measured before it was planned.** The orchestrator ran M1–M8 with the real Claude Code, with the user's leave, and the planning measured the relay's reach and cost (a notification reached an idle editor 18–21 ms after the spawn and the relay ended in 19–22 ms; a request would wait on an editor at a hit-enter prompt). The briefs rested on measured events, not on documentation: a switch is a `SessionEnd` of the old id then a `SessionStart` of the new one, `/compact` is a `SessionStart` alone, and the fallback of a dead resume arrives in the same tick as the replacement. T41's mutant that drops the `source == 'startup'` condition could be called equivalent in practice because of that last fact.
- **The rulings were recorded as numbered assumptions.** Each choice an agent or a review left open became an A-number with its reason and its source, in the brief when it came before dispatch and in the session note and PR body when it came from a fix round, and the plan lists them whole. The A90 and A91 rulings, for instance, name the widening of T41's boundary and the cases deleted for it, so a reader of the diff finds the reason.
- **The model rule and the orchestrator's cost rule held.** The model rule of 2026-10-08 is the user's (Sonnet for records reviews and vault work that decides nothing, Opus for the rest); one fix round per packet and no re-measure agent after it are the orchestrator's recommendation (A75). Every stage-3 packet ran attack, tests and records reviews, one fix round and the orchestrator's own verification; both fix rounds closed their findings with pins that were each seen failing against a mutant.
- **The reviews kept finding what the build did not.** Both packets were whole-suite green before their reviews, and each review dimension found something the others did not: attack found wrong-session paths and races, test integrity found false greens and unpinned rulings, records found help sentences the code contradicted.
- **The orchestrator's checks were literal.** The verifications applied the plan's mutants as written, by assertion, and recorded the one that survives with its reason.

### What cost most

- **T40's size.** 80 cases and 3 commits in the packet, a fourth commit and 17 more cases in its fix round, three reviews, the attack review alone with six findings. The whole suite was green at 2405 when the reviews began, and the attack review still found two paths by which a report reached the wrong session: a listed editor or a claimant that followed no session took a report of any session into its directory records (finding 1), and a hook stalled for more than a second inside the lock lost the other hook's write, so later reports were delivered as the old session's (finding 4).
- **The same shape in T41, smaller.** With a claim held, a report of the fresh session was kept in the directory's records and later shown in an unrelated session's Report (attack finding 1, A90). It rested on T40's A83, which T41's amendment had named and ruled on (A86), A86 had accepted that such a report stays with the directory's records unshown; the review showed a later follow of an unrelated session showing it.
- **Two interruptions of the work itself.** The attack and tests reviews of PR #154 were cut off by an API usage limit on the evening of 2026-10-10 and resumed after it. Earlier, the work was paused on 2026-10-08 at the user's word with T38's and T39's fix rounds in flight, and on 2026-10-09 the user held T40 until the go, after T38 and T39 had merged.
- **A flake in a shared helper.** `tests/helpers/fixture.lua` failed T40's baseline run once with E739 on a fresh worktree; it cost a ruling (A81), a test-only packet and a review the orchestrator made itself (A92).

### What to change

- **Clean agent worktrees after each merge.** The user's rule of 2026-10-09 ("it is important to clean up after a merge"): on 2026-10-08 the orchestrator had found 85 leftover test Neovims whose parent was 1 and whose working directories were under agent worktrees, two spinning a CPU core for three and a half days. The agents' test children leak, and `tests/test_entry_panes.lua`'s child death was measured at 3 of 15 runs on `dev`. A look at the runner's and the harness's teardown is still owed.
- **Stop what a run starts.** Every stage-3 dispatch told the agent to list the Neovims its runs left and stop them by pid; that is the agents' half. The runner's half is the open thread.
- **Keep the records review on Sonnet.** It caught the orchestrator's own misattribution: the stage-2 knowledge pass's brief said one fix round was the user's, when it was the orchestrator's cost rule (PR #148's records review, fixed before the merge).
- **Put the cost rules into orchestrate §6.** T40's and T41's reviewers lines depart from §6 (A80, A89), and the departure is recorded in each dispatch message; an `ai/` change should make §6 say so.

## Deviations and disclosures

- **T40's fix round and T41's were not re-measured** (A75, A80), where orchestrate §6 asks for it; the orchestrator's suite and mutants stood in for it.
- **The helper fix had no review agent** (A92): the orchestrator read its diff.
- **T41 widened into T40's function** by one condition (A90) and deleted twelve cases with A91; both are in the plan's *Landed* with their reasons.
- **A58 and A60 depart from "Wait for the resume (Recommended)"**, the user's answer of 2026-10-08; they are reported to the user together.
- **T36's directory moves keep their shared-file window** on APFS (link then unlink), named in LIMITS as an open limit, over the attack review's finding 3 on T41: T41's own moves are renames, T36's are not T41's to change (A91).

## Decisions & reasoning

- **The user's:** D31–D41 (the converge round of 2026-10-07, Input's draft per session over the recommendation); D42–D44 during stage 1; D45 (2026-10-08, "Yes, as packet T41 (Recommended)"); D46 (2026-10-09); the model-by-task rule of 2026-10-08; the clean-up rule of 2026-10-09; and the instruction to assume the orchestrator's recommendations and report them.
- **The orchestrator's, under that instruction:** one fix round per packet and no re-measure (A75), and A1–A92, in the plan's *Landed*, each with the review or the question that raised it. A76–A82 and A86–A89 were written at the two dispatches, A83–A85 and A90–A91 at the two fix rounds, and A92 for the helper fix.

## Open threads

- **The assumptions go to the user:** A1–A92 and MR322–MR356, as the user asked ("report what they were after you finish so I can check").
- **Wave 10 is next:** the commits window as a filter (Uncommitted, Session work, commits; the user's request of 2026-10-10) and a full-context diff toggle (`F`, remembered). D47 and D48 are written by wave 10's planning.
- **T36's directory moves** (link then unlink) keep a shared-file window on APFS (A91).
- **Two `--settings` in `claude.cmd`:** the earlier one stays on Claude Code's argv.
- **`tests/test_entry_panes.lua`'s child death** and test Neovims left running after runs.
- **`tests/test_health.lua`'s Ctrl-C timing case** fails under load and passes alone.
- **T39's O2:** the ready callback wrapped in `vim.schedule` passes every case (A72).

## Commits

- The stage-2 and stage-1 knowledge passes: see [[Sessions/2026-10-08 — T38 Changes worktrees]] and the plan's *Landed* for their hashes.
- T40, PR #150: `1a7eb83` … `0ed6681` (4 commits) — [[Sessions/2026-10-10 — T40 Lost editor]]. Released in v0.2.18, PR #151, `main` `e2d4252`.
- The helper fix, PR #152: `81846cb` — [[Sessions/2026-10-10-b — Fixture mkdir race]].
- T41, PR #154: `445b116` … `536a694` (13 commits) — [[Sessions/2026-10-10 — T41 Dead session handover]]. Released in v0.2.19, PR #155, `main` `befe50b`.
- This knowledge pass, which lands the wave: its hashes are recorded after its merge, by the next pass.
