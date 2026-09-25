---
wave: <NNNNN>
status: planned
rolling: false
planned_by: <who, and the session's host>
planned_at: <YYYY-MM-DD HH:MM TZ — read from the clock>
base: <the dev sha the facts were checked on>
claimed_by:
claimed_at:
landed_at:
---

# Wave <N> — <subject>

**Planned by:** <author> · **Base:** `<sha>` (code-identical to `<verified sha>` by `git diff --stat <verified> <base> -- <source roots>` empty)
**Ask:** <the user's words that opened the planning>
**Composition from:** [[Projects/aineo]] queue / [[Planning/…]]

## Baseline

<the suite counts and where they were measured — the sha, the time, the evidence file under `evidence/`>

## Measured before planning

<what the probe measured, with the script and output under `evidence/`>

## Packets — the six-rules table

| packet | tasks (task-list lines) | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|

<rule 1 … rule 6, each recomputed by command>

## Host and reviewers

<the host's limit; the reviewer allocation per packet; session-note letters; per-agent resources; branches>

## Decisions for the user

<numbered, each with its options and consequences in plain terms, the recommendation first — and, after the go, the user's answer on the same line>

## Verification mutants

<per packet, the literal mutants the orchestrator's own verification will run>

## Briefs

- `brief-<slug>.md` …
- `brief-review.md` — verdicts: …

## Landed

<filled by the knowledge pass: the pull requests, the final measurement, the retrospective link — empty until then>
