# Review

Point-in-time reviews — code, architecture, security, dependencies, compliance with the binding documents — and the fixes they produce. Also the standing convention for pre-merge review: `[[Review/How pre-merge review runs here]]`.

## Naming

`YYYY-MM-DD — <scope> review.md`, e.g. `2026-10-15 — authentication review.md`.

## Required content

- **Scope** — exactly what was reviewed, at which commit or branch.
- **Findings** as `R1`, `R2`… each with: what is wrong, a concrete failure scenario (inputs → wrong outcome), `file:line` evidence, and severity.
- **Principle check** — call out any finding that violates a binding principle, by number. Those outrank ordinary bugs.
- **Disposition** per finding: *found* → *fixed* (with commit) or *won't-fix* (with the reason).

## Rules

- **IDs are permanent** and tracked to closure. A review with unresolved findings stays open.
- A finding without a concrete failure scenario is an opinion — either sharpen it or drop it.
- When a finding grows into feature-sized work, create a `[[Planning/...]]` note and link it from the finding.
- Link the `[[Sessions/...]]` where the review ran and where the fixes landed.
- Evidence a review cites goes under `Review/evidence/<date>-<slug>/` as plain text.

Template: `[[Templates/Review Template]]`.
