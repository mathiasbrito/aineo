# Wave 18 retrospective

**Author:** Mathias Santos de Brito, with Claude — knowledge-writer agent (Sonnet 5.5), for the orchestrator's session
**Branch:** `knowledge/w18-landed`, cut from `dev` `4bf80e3` after the last merge and release; this pass lands the wave.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D76, D77, D78, T81–T84
- `Implementation/Waves/00018-scope-filter/plan.md` — its *Landed* holds each packet's record, the departures and the rulings A419–A441; its *Checks for the user* holds M1–M8
- The packets: [[Sessions/2026-10-16 — T83 Tab names whole]], [[Sessions/2026-10-16 — T81 Changes scope worktree]], [[Sessions/2026-10-17 — T82 Changes scope branch]], [[Sessions/2026-10-17 — T84 Announced work]]
- [[Sessions/2026-10-16 — Wave 17 retrospective]], the wave before

## Context

On 2026-10-16 the user found worktrees hard to find in a long session and asked for a way to select a worktree or a branch “as sort of a filter”, then for “a highly focused approach, no distractions”: the chosen worktree's or branch's name on the first line, `\g` again to return (D76). Before the plan was dispatched the user added two things in short answers: the agent tells aineo through the MCP server when it starts work on a new branch or worktree, subagents included, and the changes pane adjusts to it, the reports adding up (D77); and the tab names should be cut only when the line has no room (D78). The planning agent read the pane as it stood, the report server and the tab line, and the plan was amended three times as the answers came in. The orchestrator ruled the open points as A391–A418.

## What was done

- **T83** (PR #248, `v0.2.44`): tab names whole while the line has room, cut to one shared cap when not, never below 8 cells.
- **T81** (PR #249, `v0.2.45`): `s` and `\g`, one worktree alone in the changes pane.
- **T82** (PR #252, `v0.2.46`): the local branches in the same list and the branch's own view.
- **T84** (PR #254, `v0.2.47`): the `announce_work` tool, the `SubagentStart` hook that teaches subagents, and the reported set in the tab's pane.
- **The suite** grew from 4121 cases on T78's check to 4346 on the last whole run, which showed one failure, a flake in a file the packet did not touch (A441).

### What worked

- **The user shaped the design live in short answers.** Each answer was a decision the plan could carry whole (the list, the toggle, “tell me once”, pre-allowed and inform-only), and the plan's open questions were the ones the answers did not cover.
- **The attack reviews found what the tests could not.** T83's found a width measured in the current window instead of the tab line, which cut a name that fit and changed as the cursor moved between windows; T81's found the `\g` conflict, where the brief's reading of “shows” dropped the scope on every trip through Claude's window or a diff, against the user's own answer; T84's found the unbounded waiting reports and a wrong-tab routing no test caught; and across them, hostile names (a control character, an option-like branch name, an agent's string) reached nothing.
- **A spec conflict reported, not chosen.** The author of T81 built what the brief said; the attack review measured that it contradicted U3 (b), and the orchestrator ruled it (A426) rather than either side choosing.

### What cost most

- **The plan amended three times while answers came in,** each amendment re-checking the facts the earlier text had stated, and two packets (T83, T84) were added after the first questions went out.
- **A flake compared each time on `dev` and on the head.** The `test_entry_tabs` Insert twin failed once under load in T84's check; it took a measurement on `dev` and on the head before it was read as a flake (A441: 1 of 6 on `dev`, 0 of 6 with T84).
- **Records the reviews had to correct:** unrecorded rulings, mutant rows that were not literal edits, a count that did not match the code, a model named wrongly. Each was a small fix, and each cost a review's attention that the attack dimension could have had.

### What to change

- **Ask the toggle and scope questions together before planning.** What `\g` does from another pane and what an agent's report does to a pick were settled across the plan's amendments, one answer at a time; asked together, the plan would be written once.
- **Keep resource names without hyphens.** T83's tests-and-records review found that `prepare-worktree.sh` refuses a resource name with a hyphen (`review_tests-records_t83` was refused, `review_tests_records_t83` accepted).
- **Say in the brief which window a measure belongs to.** A width read in the current window differs from the same width in the tab line; T83's first cut used the call that follows the window and the attack review found it.

## Deviations and disclosures

- **T84 ran on Opus, the rest on Sonnet,** as the allocation said (A433): the MCP server, the start arguments and the permissions are security-sensitive. Its commits' trailers name Sonnet because the dispatch message gave that trailer; the note says so.
- **Nothing was run against a real Claude Code.** The tool's reports, the `SubagentStart` hook's text and the permission for a subagent's call are tested with a fake and a synthetic `tools/call`; the user's checks M6 and M7 are the real measurement.
- **Two mutants survive as equivalent** (T82's `heads/dev`, T83's search bound), and one edit of T81's toggle guard survives for lack of a negative wait; the notes say so.
- **T83's commit subject `edc237c` is 73 characters;** pushed history is not rewritten, and the note says so.

## Decisions & reasoning

- **The user's:** D76 and U1–U3 and the toggle, D77 and U4–U6, D78, 2026-10-16.
- **The orchestrator's, under the instructions of 2026-10-06 and 2026-10-14:** A391–A418 before dispatch, A419–A421 (T83), A422–A428 (T81), A429–A432 (T82), A433–A441 (T84); listed per packet in the plan's *Landed*.

## Open threads

- **The assumptions go to the user:** A391–A441.
- **The user's checks M1–M8 of this wave,** with the real Claude Code and agent worktrees: the real Claude Code calling `announce_work` from the main agent and from a subagent, and the permission for a subagent's call among them. Earlier waves' checks stay open in their plans.
- **Diff buffer names carry no repository label,** so two tabs on two repositories can share a diff buffer (pre-existing; found in T82's attack review).
- **Agent-team teammates that run as separate Claude Code processes** are not covered by `announce_work`.
- **A368, the split of `entry/tab.lua`** (about 1,600 lines): a follow-up packet.
- **The fill-the-width tab line** is the user's experiment, undecided.
- **The MVP review awaits the user.**

## Commits

- T83 PR #248 `067a0fa` … `b3a7a09`, released in `v0.2.44` (PR #250, `main` `e7e6d25`).
- T81 PR #249 `d76f5e9` … `bbf4400`, released in `v0.2.45` (PR #251, `main` `cb58183`).
- T82 PR #252 `e1750e0` … `813e17c`, released in `v0.2.46` (PR #253, `main` `0785409`).
- T84 PR #254 `5360966` … `4bf80e3`, released in `v0.2.47` (PR #255, `main` `32a7060`).
- This knowledge pass, which lands the wave: its hashes are recorded after its merge, by the next pass.
