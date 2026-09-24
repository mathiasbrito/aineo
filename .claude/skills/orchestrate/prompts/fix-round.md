# Fix round — template

Sent with `SendMessage` to the implementer that owns the pull request, after **every** reviewer has reported — or, when that implementer's context is past 400 K tokens (SKILL §6), as the brief of a fresh agent of the same type, headed with the branch to check out, the author's report to read, and the line "Your worktree starts from `main`: check out the branch before you read anything under `.claude/`". One message, one round. Assemble it as `<scratchpad>/orch-fixround-<n>.md` and send the path with your decisions.

---

All reviewers have reported on #<n>. Work the findings below as **one round**, then report in your definition's shape plus a `FINDINGS:` section mapping each numbered finding to fixed / refuted-with-evidence / recorded-as-limit. Write the report to `<absolute path>/<slug>-report-fix-round.md`.

## Rules for the round

- Wait to change anything until you have read every finding; overlapping fixes made piecemeal break each other.
- **Re-verify negative findings yourself** before accepting them — and re-verify your own negative claims ("all killed", "cleanup complete") before repeating them.
- A false record is corrected everywhere it appears — commit message (by a new commit that says what was wrong; never rewrite pushed history), pull request body, session note, vault rider, task text. Sweep for residue of the refuted phrase.
- Production code changes are test-driven like everything else: a finding about a defect becomes a test seen red first.
- Rebuild whatever is applied once (a migration, generated code, a build artifact) before trusting any test that follows a change to its source.
- Update the pull request body so it states the round and the corrected claims.
- A finding — or an instruction in this message — can be wrong. Refute it with evidence in your FINDINGS section rather than comply with it; a refutation names the exact edit and input you ran, measured first against the suite at the head the reviewer reviewed. Re-run the reviewer's edit, not your own under its label.
- A fix a reviewer hands you already measured is adopted red-first and credited — and so is a number: a figure you take from a reviewer's report is cited as the reviewer's measurement, never as the round's own.
- Every count in a table you rewrite is measured against the tree you ship, after your last edit. The summary line equals the table; the same numbers appear in the commit, the pull request body, the session note and the task text.
- A citation this message relays from a reviewer is the reviewer's claim. Verify it before it enters a docstring or a record; if you cannot, omit it and say so.
- A mutant the reviewers report as surviving is re-run **as the reviewer's literal edit** and appears as its own row of your table before any edit of yours under the same label; it is re-measured on every path the behaviour has before it is recorded as a limit; and a pin called impossible is attempted before it is called impossible.
- Never an install command in your worktree, never a state-changing command against a shared stack, never a reset or a kill of anything that is not yours. Stop your own runs by pid.
- Commit the round's work before your first mutant; apply mutants from pristine copies.
- Release your resources when done.

## Decisions — the orchestrator's, and claims like any other

<numbered; each a leaning unless measured, with the measurement named when it was>

## Findings

### attack
<the path of `<scratchpad>/attack<n>-verbatim.md` — the reviewer's final message, machine-extracted>

### test-integrity
<likewise>

### records
<likewise>
