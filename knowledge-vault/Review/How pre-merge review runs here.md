# How pre-merge review runs here

**Every substantial pull request goes to three reviewers before merge, one per dimension, each in its own git worktree and its own isolated resources.** This note is the convention and its *why*; the executable form is the `reviewer` agent definition in `.claude/agents/reviewer.md`, the dimension blocks in `.claude/skills/orchestrate/prompts/reviewer-brief.md`, and the `orchestrate` skill that dispatches them — see [[Skills/Orchestrate]]. If the two ever disagree, fix the one that is wrong and say so here.

**What takes fewer than three, and why.** A test-only change takes two: attack and test-integrity collapse into one `guarantee` review whose subject is the guarantee and whose instrument is the tests. A documentation packet takes `records` and `reader`. The orchestrator's own passes — the adjustment pass on an `ai/` branch, the tasks pass, the knowledge pass's Learnings — take one `records` reviewer each before they merge: they change no guarantee and carry the highest cost per false sentence. A wave's plan and briefs take the `brief` review. Nothing that lands application code takes fewer than three — except a **small fix** the user calls one (orchestrate §3; the user, 2026-09-25: "whenever I call for a small-fix we use the new small-fix rules"). It changes one behaviour in one module home outside the Claude Code integration, process handling, the autostart and the shared test harness, and takes `guarantee` (by the implementing specialist at `high`) and `records`. Mutant survivors are re-run on the test files the pull request touches, and there is a re-measure only when the fix round moved a mechanism. What it gives up is the separate attack review at `xhigh` and, when no mechanism moved, the re-measure. The narrowing only reports more survivors, so it lets no defect through. It exists because a regular packet takes four to seven hours of wall clock (T8: 65, 58 and 48 minutes for its first three stages), and a one-behaviour fix does not need a separate attack review to be caught.

## The three dimensions

One reviewer per dimension, launched together, each told explicitly what the others cover so it does not drift into their territory.

| Dimension | Its question |
|---|---|
| **Attack** | Can the guarantee be defeated? Adversarial, empirical, hostile to the design. |
| **Test integrity** | Do the tests prove what their names claim, or are they green for other reasons? |
| **Records & skills** | Does this comply with the repository's own rules, and is every record it leaves behind *true*? |

The dimensions are not decoration. Attack finds defeats nobody told the author about; test integrity finds suites passing for the wrong reason; records finds false decision rows, false task text and false citations that neither of the others looks at. Their findings rarely overlap.

## Isolation, and why each part exists

**Give each reviewer its own git worktree.** Reviewers sharing one checkout contaminate each other: a probe appears inside another reviewer's run, suites see phantom failures, and a checkout moved by one is moved for all. A worktree made by hand is not enough on its own — a subagent's `cd` does not persist between tool calls, so the git hooks judge the main checkout rather than the worktree. `isolation: worktree` on the agent definition puts the agent's working directory inside the worktree, and the review gate then sees the right index.

**Give each its own isolated resources** — its own test database, its own containers, its own ports — named distinctively (`review_<dimension>_<slug>`), created by `prepare-worktree.sh` and released at the end. Tell each reviewer never to touch the developer's own resources or another agent's.

**Tell them the scratchpad is shared.** Ask for uniquely-named scratch files, prefixed by dimension.

**`.claude/worktrees/` is gitignored**, because a finished worktree left on disk is offered to `git add` as an embedded repository. Clean up after every round: `git worktree remove --force`, `git worktree prune`, delete the leftover `worktree-agent-*` branches, release the resources.

## What to tell every reviewer, without exception

- **A mutant must reach the running system.** Anything applied once — a migration, generated code, a build artifact — does not re-apply when its source is edited, and every mutant of it appears to survive. Rebuild or recreate per mutation.
- **A kill counts only when the mutant executed and the assertion is what failed.** Check the failure message, not the failure count. A mutation that breaks compilation kills tests by crashing them.
- **Re-measure; do not accept the author's numbers.** The point of the round is independent verification. Every claim in the pull request should be reproduced or marked UNVERIFIABLE.
- **Report format:** numbered findings, each labelled CONFIRMED / REFUTED / UNVERIFIABLE / MISSING, ranked by severity, each with a concrete failure scenario and `file:line` or command output. *A finding without a concrete failure scenario is an opinion — sharpen it or drop it.*

## Working the results

**Wait for all of them before changing anything**, then do one round. Fixing each report as it lands produces overlapping edits and a second round that breaks the first round's fix. The one exception is a live security defect, which does not wait.

**Re-measure the round.** A fix round is new code written under pressure; one re-measure against the new head checks every claim the round makes and whether it introduced the failure it was correcting — with the attack question added when the round moved a guard. Then one bounded correction, and the orchestrator verifies the final head itself with a literal mutant.

**Re-verify negative findings yourself.** "All mutations killed", "no false positives", "cleanup complete" are the claims most likely to be corrupted by a bad harness or a collision. Positive findings — *this leaked*, *this survived* — are cheap to reproduce and usually hold.

**Expect to be wrong about your own work.** Reviewers falsify what re-reading the code does not: a defence stated against the wrong threat, a fix wired into the harness but not the entry point, a decision record cited for a fact it never contained, a "tests each seen failing first" claim that was false.

## Related

- [[Skills/Orchestrate]]
- `Learnings/` about verification proving less than it claims — link each here as it is written.
  - [[Learnings/A test case can end a mini.test run green]] — an exit status the runner did not decide from the cases it counted.
  - [[Learnings/mini.test v0.18.0 hangs instead of failing]] — a broken suite that reads as a hang, never as a failure.
