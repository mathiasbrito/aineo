# Wave 13 retrospective

**Author:** Mathias Santos de Brito, with Claude — knowledge-writer agent (Sonnet 5.5), for the orchestrator's session
**Branch:** `knowledge/w13-landed`, cut from `dev` `29f2f00` after the last merge and release; this pass lands the wave.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D55, D56, D57, D58, T49–T54
- `Implementation/Waves/00013-worktrees-landed/plan.md` — its *Landed* holds each packet's record, the departures and the rulings made after dispatch (A135, A158–A163, A167–A184); the plan holds A136–A157
- The packets: [[Sessions/2026-10-12 — T49 Scroll filter]], [[Sessions/2026-10-12 — T50 Worktree filter]], [[Sessions/2026-10-12 — T51 Landed reads]], [[Sessions/2026-10-12 — T52 Landed]], [[Sessions/2026-10-12 — T53 Files window keys]], [[Sessions/2026-10-12 — T54 Terminal keys]]
- [[Sessions/2026-10-12 — Wave 11 retrospective]], the wave before

## Context

On 2026-10-12 the user looked at the changes pane in a session with many commits and saw that, wherever the cursor went, the files list was the same; the user asked for a *Landed* option, because an orchestrator dispatches work to several agents, each in its own worktree, and the work that has merged into the working branch should show too. The orchestrator diagnosed the first point with a read-only probe: the filter worked on the editor's own lines, other worktrees' commits kept the last filter (A110), and a scroll from another window never reached the files window. The user approved the plan ("yes, go ahead with the plan"): the scroll fix at once as a small fix (T49), then a wave for the one-list files window and other worktrees' lines (T50), the git reads (T51), *Landed* (T52) and the files window's keys (T53). A second message of the same day added what the user expected of the filter: the files only for the selected commit, opened from that commit, with `h` against `HEAD` and `l` against the previous version. During the wave the user asked for `<C-\>` twins of the `\` keys, which became T54.

## What was done

- **T49, the commits filter follows a scroll** (PR #171, released in v0.2.24): a `WinScrolled` autocmd, a small fix under D30.
- **T51, the git reads** (PR #175) and **T50, the files window as one list with another worktree's lines in the filter** (PR #177, re-applied from #176), released in v0.2.25.
- **T52, *Landed*** (PR #180) and **T54, the `<C-\>` twins** (PR #181, D58), released in v0.2.26.
- **T53, `gf` from a commit, and `h` and `l` in the files window** (PR #183), released in v0.2.27.
- **The suite** grew from 2708 cases at the wave's base to 3015.

### What worked

- **The user's own probes of the pane.** The report that the files list never changed, and the second message about what a filter must show, set the wave's content; the orchestrator's diagnosis confirmed the first with measurements before any plan was written.
- **Parallel packets on disjoint homes.** T51 (the git home) ran beside T50 (the changes home), T54 (the keys) beside T52 and T53; the six-rules table kept their files apart, and only the help passage collided.
- **Re-applying a conflicting pull request instead of rebasing it.** The plan (#173 as #174) and T50 (#176 as #177) kept their pushed history; the cost was a closed pull request each.
- **Reviews that found wrong data, not only wrong text.** T51's `--` file returned another file's bytes; T52's heading kept the old branch name over the new branch's files; T54's twins could hijack typing under a user's own `<C-\>` mapping. Each was measured by a probe and fixed in the one round.

### What cost most

- **Help passages rewritten by two packets at once.** T50 and T51 both rewrote the same passage of `doc/aineo.txt`, so T50's pull request conflicted once T51 merged and the orchestrator merged the help by hand.
- **Host load ending a whole run.** The first whole run on T54 hit its 16-minute limit while a virtual machine and T53's build loaded the host; the failing files passed alone, and the check was rerun with fewer jobs and a longer limit.
- **A host that stopped answering.** During T51's fix round the Xcode licence lapsed, git and make exited, and the checks of #175 and #176 waited until the user restored them; T50's author ran the suites by hand with the same variables.
- **A flaky case outside the boundary.** `test_changes_filter` › *cursor on Session work when made anew* failed on `dev` as well and showed in T53's whole run; the tests review found its cause (a wait too short under a slow `git log`) and A184 fixed it outside the packet's boundary.

### What to change

- **One packet owns each help section per stage.** Two packets rewriting one passage of the help is a conflict the six-rules table does not see; the table should list the help passages by name and make a second packet wait or amend after the first merges.
- **Whole suites run with fewer jobs under load.** When a virtual machine or another build shares the host, start the run with `AINEO_TEST_JOBS=4` and a longer limit, rather than rerunning after the limit ends it.
- **The flaky case is waited for, not retried.** The wait for the reads counts git's calls; a fixed sleep is not a wait.

## Deviations and disclosures

- **T49 was dispatched before the wave's plan** and read in place of a guarantee review (A135), under D30.
- **T54 has no brief in the wave's folder**: the user asked for it during the wave, and the orchestrator's dispatch carried A167–A170.
- **PR #174 and PR #177 are re-applications**, not rebases; the original pull requests #173 and #176 were not merged.

## Decisions & reasoning

- **The user's:** the plan of 2026-10-12 and its answers U1–U4 (a setting for the working branch, a *Landed* heading with its commits, one list always, `h` and `l` everywhere); D58, with the user's two answers (Terminal and Insert mode; the same letters as `\`); the park of wave 12 ("let's drop this issue we are hunting, I will try to reproduce it first").
- **The orchestrator's, under the instruction of 2026-10-06:** A135, A136–A157 before dispatch, A158–A163, A167–A184 at the dispatches and fix rounds.

## Open threads

- **The assumptions go to the user:** A135, A136–A163, A167–A184.
- **A154:** D32's worktree bases are not changed; whether the comparison should become the working branch is the user's.
- **A183:** a huge blob is read whole before T53's 1 MiB cut, in the git home.
- **Wave 12 is parked** (its plan is PR #179, open) until the user reproduces the blank background-session window.
- **T50:** a worktree removed during a whole-change read lists "No files changed in this worktree" for a moment; the LIMITS cost figures wait for a re-measure.
- **The MVP review awaits the user.**

## Commits

- T49, PR #171: `3df18ab` on `dev`. Released in v0.2.24, PR #172, `main` `19e4be3`.
- The wave's plan, PR #174: `42c0c3b` and `8a09eec` on `dev`.
- T51, PR #175: `7c3118a` … `56e63ab` on `dev` (4 commits). T50, PR #177: `57d4473` … `322fc41` on `dev` (5 commits). Released in v0.2.25, PR #178, `main` `f59a7d8`.
- T52, PR #180: `30eee93` … `70a52bc` on `dev` (5 commits). T54, PR #181: `72f842a` … `191f819` on `dev` (2 commits). Released in v0.2.26, PR #182, `main` `32c012c`.
- T53, PR #183: `e728523` … `29f2f00` on `dev` (14 commits). Released in v0.2.27, PR #184, `main` `bfef6c9`.
- This knowledge pass, which lands the wave: its hashes are recorded after its merge, by the next pass.
