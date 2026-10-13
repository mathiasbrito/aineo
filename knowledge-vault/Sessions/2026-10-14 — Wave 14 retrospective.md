# Wave 14 retrospective

**Author:** Mathias Santos de Brito, with Claude — knowledge-writer agent (Sonnet 5.5), for the orchestrator's session
**Branch:** `knowledge/w14-landed`, cut from `dev` `bdc33ce` after the last merge and release; this pass lands the wave.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D60, D61, T55–T59, T48
- `Implementation/Waves/00014-cut-bases-new-session/plan.md` — its *Landed* holds each packet's record, the departures and the rulings A196–A222; its *Checks for the user* holds M1–M3
- `Implementation/Waves/00012-background-resume/plan.md` — its *Landed* holds part 1 of T48 and T55's place; the wave stays open for part 2
- The packets: [[Sessions/2026-10-13 — T56 Commit file read]], [[Sessions/2026-10-13 — T57 Worktree base]], [[Sessions/2026-10-13 — T58 New session key]], [[Sessions/2026-10-13 — T59 Quit flake]]; the records filled here: [[Sessions/2026-10-12 — T55 Pane cursor]], [[Sessions/2026-10-12 — T48 Resume elsewhere]]
- [[Sessions/2026-10-12 — Wave 13 retrospective]], the wave before

## Context

On 2026-10-13 the orchestrator listed what was left after wave 13: T48 part 2, held for the user's M16; the records of T55 and T48 part 1; the open threads A154 (agent worktrees compare against their existing base) and A183 (`gf` reads a huge file whole before cutting it); and the offered single key for a new session after `/exit`. The user answered "go ahead implement them". The orchestrator's planning agent wrote the plan (D60 and D61 proposed, O1–O17), the orchestrator ruled O1–O17 as A196–A212, and three packets ran: T56 and T58 at once, T57 after T56 because both change `lua/aineo/changes/init.lua`. T48 part 2 stayed held.

## What was done

- **T56, the bounded commit-file read** (PR #192, released in v0.2.30): the git runner stops git at a byte bound, `ls-tree -l` gives the size, and `gf` under a commit reads no more than it shows.
- **T58, `\N`** (PR #193, released in v0.2.31): `:Aineo new`, a new session after `/exit`, `/clear` at an empty prompt, four refusals.
- **T57, a worktree's base from the working branch** (PR #196, released in v0.2.32): the merge base with `changes.working_branch`, D32's base as the fallback.
- **T59, the quit flake** (PR #198, test-only, no release of its own): found while checking T58, and a small fix taken into the wave.
- **The records** of T55 and T48 part 1 (wave 12), and the commits of the wave's session notes.
- **The suite** grew from 3072 cases at the wave's base to 3163.

### What worked

- **Plans ruled and dispatched without waiting.** The user's one sentence became a plan with O1–O17, every recommendation ruled as an assumption, and stage 1 dispatched the same day; the user's checks (M1–M3) were collected at the end, not asked for on the way.
- **Parallel packets on disjoint homes.** T56 (git home, changes display) ran beside T58 (Claude home, entry), and the six-rules table put T57 after T56 for the files they share; no packet conflicted.
- **Reviewers' probes turned into tests.** The attack reviews came with runnable cases: T56's `BAD` size crash, T57's three unpinned failure paths, T58's draft-at-start limit. Each probe became a case in the fix round, seen killing its mutant.
- **A regression caught by the attack review.** T56's size compare crashed on a blob git could not read; the plan's own probe had said a blob always has a size (A216).

### What cost most

- **A flaky test read as load for days.** `test_claude.lua`'s Ctrl-C-while-quitting case failed in T56's whole run and T58's, and was first read as a load flake (it passed alone on T56). Only when it also failed alone on plain `dev`, 2 of 4 runs, was it measured, and the cause was the test helper's: it pressed Ctrl-C in the first milliseconds of `:qa`. T59 fixed it, with 5 of 40 failing before and 0 of 40 after.
- **Load flakes in whole runs.** A second case, *a list of worktrees that fails* › *leaves the editor's lines as ever*, failed 2 of 5 at a load average of 120. Whole runs again needed `AINEO_TEST_JOBS=4` and a long limit.
- **Docstrings outside a brief's boundary.** T57 made two git-home docstrings false and the brief barred the git home; the fix round (A221) corrected them anyway.

### What to change

- **Run a suspect case alone on plain `dev` the first time it fails, not the third.** A case that fails in a whole run and passes in its own file is not yet a load flake: run it alone on the base, a few times, before reading it as load. Here that would have found the helper's fault one packet earlier.
- **A brief that moves a function's meaning names its docstrings.** When a packet changes what an argument of another home's function means, the brief should put those docstrings inside the boundary.
- **A plan's probe does not assert what git does for every object.** "A blob always has a size" was false for a blob git cannot read; the probe should run a corrupt object too.

## Deviations and disclosures

- **T59 was added during the wave**, dispatched after T58's check, and has no brief in the wave's folder; the orchestrator's dispatch carried it.
- **T57's brief was amended at dispatch** (A220), as T52's was (A163).
- **T56's brief numbers were corrected in the fix round** (the bound's 6 bytes, `Output.cut` dropped, the size of a `BAD` blob), recorded in the session note and the plan, not in the brief (A214–A216).
- **D60 and D61 are proposed**, the orchestrator's assumptions under the user's go-ahead; nothing in them is the user's decision beyond that go-ahead.

## Decisions & reasoning

- **The user's:** "go ahead implement them" (2026-10-13), for A154, A183 and the new-session key. T48 part 2 stays held for M16.
- **The orchestrator's, under the instruction of 2026-10-06:** A196–A212 before dispatch; A213–A216 (T56), A217–A219 (T58), A220–A222 (T57) at the dispatches and fix rounds.

## Open threads

- **The assumptions go to the user:** A196–A222, with D60 and D61 to confirm.
- **The user's checks M1–M3 for `\N`**, with the real Claude Code: whether `/clear` clears the conversation; what happens with a turn running; what `/clear` before a one-line draft does.
- **A user's Ctrl-C right after `:qa`** skips the stop (the hangup still ends Claude Code); whether the plugin should handle it is undecided.
- **The git home's packed-delta cost**: a packed file stored as a delta is unpacked whole by git before the bound.
- **Duplicated test helpers**: `tests/test_changes_landed.lua` keeps file-local copies of `with_remote()`, `land()` and `fetch()`.
- **Enter's diffs** are still read whole before their 1 MiB cut.
- **Wave 12 stays open** for T48 part 2, held for the user's M16.
- **The MVP review awaits the user.**

## Commits

- The wave's plan, PR #191: `97a9832` and `20def68` on `dev`.
- T56, PR #192: `62ef90a` … `0fa01e4` on `dev` (4 commits). Released in v0.2.30, PR #194, `main` `df18964`.
- T58, PR #193: `6cd29e5` … `51ec1fa` on `dev` (3 commits). Released in v0.2.31, PR #195, `main` `d2b6882`.
- T57, PR #196: `25597ed` … `c170fcb` on `dev` (5 commits). Released in v0.2.32, PR #197, `main` `31a3b23`.
- T59, PR #198: `bdc33ce` on `dev`; no release of its own.
- This knowledge pass, which lands the wave: its hashes are recorded after its merge, by the next pass.
