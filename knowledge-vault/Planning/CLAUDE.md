# Planning

Feature plans. When work is defined and agreed, its decisions, architecture and task breakdown live here in one living note per feature, tracked to completion.

## Why this folder exists

Agents and people structure work as numbered references — `D1`, `C2`, `T4` — and cite them back and forth. When the chat ends those references vanish and the reasoning goes with them. This folder gives them a permanent home.

## Naming

`aineo — <Feature Name>.md`. One living note per feature, not dated — it is updated as the plan evolves.

## Required content

- **ID legend** — state what each prefix means in this plan (`D#` decision, `C#` component, `R#` risk, `T#` task or trap). A plan whose IDs could collide with another's gives them a prefix of its own (`OD#` for an orchestration decision).
- **Decisions with reasoning** — the "why", which is what nobody can re-derive.
- **Architecture** — how it fits together.
- **Task breakdown** with dependencies by ID (`C3 depends on C1`).
- **Accepted risks**, and anything **decided over a stated objection**, with the objection recorded.
- **Done criteria** and an explicit **out of scope**.

## ID discipline — the whole point of the folder

- **IDs are permanent.** `D3` always means what it first meant. **Never renumber.**
- **Never delete an item to drop it** — mark `#deprecated` or `~~superseded~~` so the ID stays reserved and old references resolve.
- Completed items: `~~**C1 — <title>**~~ — **Done YYYY-MM-DD**`, with the commit in the session note.

## Rules

- Always link `[[Projects/aineo]]` and the `[[Sessions/...]]` where the feature was defined and implemented.
- A plan that contradicts the specs is wrong — the spec is binding. Fix the plan.
- Mark the plan complete when the feature ships, and record the shipping commits.

Template: `[[Templates/Planning Template]]`.
