# Reviewer brief — template

One `Agent` call per dimension — `subagent_type: "reviewer"`, or the specialist whose domain the pull request touches (SKILL §6); `model: "opus"` for every dimension, the re-measure and the brief review (SKILL §1) — all of a pull request's reviewers in one message. The definition carries the charter (worktree, shared state, kill-counting, report shape); the brief carries the dimension, the pull request, and the author's claims to re-measure. After a fix round, one call with the `re-measure` block. Before a wave is dispatched, one call with the `brief` block, whose subject is the orchestrator's own packet briefs — the head is `origin/dev` and there is no pull request yet.

---

**Your role: review, dimension <attack | test-integrity | records | guarantee | reader | re-measure | brief>.** A specialist reads `.claude/agents/reviewer.md` first; it binds unchanged.

You are the **<dimension>** reviewer for pull request **#<n>**.

## The pull request

- Head: `<sha>` on `<branch>`. Read `gh pr view <n> --json body -q .body` and `git log --format=%B <base>..<sha>`.
- Files: <list from `gh pr view <n> --json files`>.
- The author's report: `<absolute path to the report file>` — every claim in it is yours to re-measure.
- Your resources: `review_<dimension>_<slug>` — lower case, digits and underscores only: `.claude/scripts/prepare-worktree.sh` refuses a hyphen, so `test-integrity` is `review_integrity_<slug>` and a slug `t1-tooling` becomes `t1_tooling`.
- Baseline: `dev` at the packet's branch point, `<sha>`, measured — never a branch's verification count.

## Your dimension

<paste exactly one of the blocks below>

### attack

Your single question: **can the guarantee this pull request claims be defeated?** As the identity the guarantee binds, over the real interface, never a simulation. Probe the stated guarantee from every direction the system offers — every path to the data or the action, the write side as well as the read side, error messages for what they leak, what a less-privileged owner or a concurrent session would change, whether a reversal (a rollback, a `down()`) restores the prior state (run it). Known and accepted bounds recorded in the plan are not findings unless you find them worse than stated. Every attack: the exact command, the identity it ran as, the result.

### test-integrity

Your single question: **do the tests prove what their names claim, or are they green for other reasons?** For each test: what else would make it pass? Determine the red-able set (which tests fail with the change removed or minimised) and compare it with the author's account of reds. Re-run at least four of the author's mutants, rebuilding whatever is applied once before each, and record the actual failing tests and the actual failure kind — assertion or crash. Add mutants the author did not try. Look for fixtures whose values coincide, assertions satisfied by an empty result, checks that name more than they prove, order dependence, logic in tests, and whether the actor in the test is genuinely the identity the guarantee binds. Run every mutant the author reports as surviving on **both** the accepting and the refusing path, and when the author says a pin is impossible, try to build it. Record every mutant as its **literal edit**.

### records

Your single question: **does this comply with the repository's own rules, and is every record it leaves behind true?** Read the rules first: root `CLAUDE.md`, the four skills in `.claude/skills/`, the vault's `CLAUDE.md` files, `Review/How pre-merge review runs here.md`, and the constitution once the project has one. Then check **every** checkable statement — not a sample — in the commit messages, the pull request body, the session note, any decision rider, the task text and the docs the packet touched: counts (tests, reds, mutants, files), citations (does the cited ID say what is claimed?), tense (does a record credit merged code with something only an intermediate state did?), and internal consistency across the records. Then skills compliance in the code: docstrings self-contained and describing the code rather than the change; no narrative in source; imports through module entry points; commit message standard; branch prefix; nothing secret in the diff; `[[wikilinks]]` resolving; author and branch on the session note; commit hashes deferred to post-merge.

No suite run is needed for this dimension; run `.claude/scripts/prepare-worktree.sh` anyway for the worktree's dependencies, and release what it created.

### guarantee

**Two dimensions collapsed into one, for a test-only change (SKILL §6): your subject is the guarantee, your instrument is the tests.** Answer the attack block's question and the test-integrity block's question in one review, as the identity the guarantee binds over the real interface, and label yourself `guarantee` in the report.

### reader

**For a documentation packet — a guide, a runbook, anything written to teach.** Your single question: **does this teach a developer joining the project what the subject is, correctly?** Your instrument is reading, and the **order is the method**:

1. **Read the text before anything else in the repository** — not the code, not the vault, not the brief, not the author's report.
2. **Write what you now believe**, in your own words, to `<scratchpad>/reader-<n>-beliefs.md`, before you open anything else: what the thing does, who may do what with it, what stops it being bypassed, what happens at its edges, what is still open — and, for each thing the text tells a developer to *do*, what you would type tomorrow. Fifteen to thirty sentences. **Save the file before step 3**: a belief re-read after the code is no longer one the text gave you.
3. **Then read the code and the vault it cites**, and label every belief **true**, **false**, **vague** (you had to guess — name the guess) or **missing** (something a developer would need that the text never said).
4. **Every diagram:** could you explain it back without the prose; do its labels name things you then found in the code, spelled as the code spells them.
5. **The usage section as a recipe, tried in your head against the code:** does every step name the real function, command and file, and would a snippet it tells you to copy actually run **where the text tells you to put it**.
6. **The open section:** is what is not built said plainly, or softened; is a bound stated as a bound.
7. **Length is not a finding; unteachable length is.** Name every passage a new developer cannot follow without opening the code first, and every term used before it is defined.

Findings: each false, vague or missing belief with the sentence that caused it (file and line) and the passage that would have prevented it. REFUTED is a belief you suspected the text had wrong and found it had not. This dimension does not replace **records**; a documentation packet takes both.

### re-measure

You run alone, after the fix round, against the new head — `<sha>` — and your question is narrower than a review's: **does every claim the fix round makes hold on this head, and did the round introduce the failure it was correcting?** Read `git diff <reviewed sha>..<sha>` first. Then, as literal edits against the new code: re-run every survivor the first round reported **as the reviewer's literal edit** ("all now die" is the claim to distrust most) and record the failing tests and the kind; re-run every pin the reviewers built and the author adopted; re-run at least eight rows of the redone mutant table, including every row whose label names a line, a count or a site the round changed. Reproduce the fix's own red the way the author says it was seen. Check the counts: tests against the red/green split, the mutant table's rows against its summary line, and the same numbers in commit message, pull request body, session note and task text. Check the records the round rewrote: the residue of every refuted phrase, `## Commits` deferred, wikilinks resolving, the new commit saying what was wrong in the first. Where a claim holds, say so.

<the path of the fix round's report, the path of the first round's findings it answers — and the orchestrator's own decisions in the fix-round message, labelled as the orchestrator's: they are claims too>

### brief

You run alone, before the wave is dispatched, detached at `origin/dev` (`<sha>`), and your subject is not a pull request but the orchestrator's **packet briefs** — the files named below, exactly as they will be sent — together with the wave plan. Your single question: **would an implementer acting on this brief be misled by anything in it?**

For each brief, every checkable statement, not a sample: **task ids** — grep each one cited, and for every phrase of the form "X is created by T0nn", read that line and say whether it does; **paths and symbols** — `git ls-tree origin/dev <path>` for every path the brief says exists or does not, `git grep -n <symbol> origin/dev` for every symbol named; **spec and decision citations** — does the cited ID say what the brief claims, read at its row; **standards citations** — an RFC section, a manual chapter is read at its raw source; **arithmetic** — recompute every number, and for every datum supplied for a test decide whether it is wrong in exactly one way (negative) or valid (positive); **counts** — the baseline against the output that measured the base sha; **evidence** — every probe statement a fact rests on ran without error; **instructions** — each one you would refuse as the implementer, with the reason; **plan mutants** — the test each is expected to fail exists on the base, or the brief tells the packet to write it. Then the **boundary**: is every registration file and counting pin the packet will move inside it; is every document the change will invalidate named; does anything it forbids contradict what the task needs; is the session-note filename free and distinct across the wave; are scratch prefixes distinct. Then the **six rules** across the wave's briefs, recomputed from the briefs rather than from the plan: dependencies, file sets disjoint including registration files (with `git merge-file` where hunks sit near each other), at most one schema packet, no dependency change, no undecided decision, task lines non-adjacent (show the gaps). Finally the **slots**: every field of the template present and non-empty, the budget stated, the report shape named.

You change nothing and dispatch nothing. Your report goes to the orchestrator, who corrects the briefs and dispatches.

<the wave plan's path and the path of each brief file>

## Report

Exactly the shape in your definition, then the cleanup confirmation. For a `brief` review: findings per brief, labelled CONFIRMED (a statement that is false or misleading, with the check that shows it) / REFUTED (a statement you tried to fault and could not) / MISSING (a slot, a boundary item, a rule not met); then the six-rules table as you recomputed it; then the verdict per brief — dispatch as written, dispatch after these corrections, or do not dispatch.
