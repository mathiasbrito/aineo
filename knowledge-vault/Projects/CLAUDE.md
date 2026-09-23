# Projects

The living overview of aineo: architecture, environment, and the things that cannot be derived from reading the code.

Unlike a personal vault, this folder describes **one** project. `aineo.md` is the main note. Add a second note only for a component substantial enough to have its own architecture and gotchas — and link it from `aineo.md`.

## What belongs here

- Architecture and how the pieces fit.
- Environment setup and its quirks — the things that waste an afternoon.
- **Key decisions with their reasoning**, especially where the obvious choice was rejected.
- Known gotchas and traps.
- **Where the work stands and the queue** — what the orchestrator composes the next wave from, and the host limits it plans against.
- A changelog linking to the `[[Sessions/...]]` notes that shaped it.

## What does not

- Requirements — those are the specs, which are binding. Do not restate them here; they will drift.
- The principles — those are the constitution. Reference them, never copy them.
- Anything true only for one contributor's machine, unless it will bite everyone.

## Rules

- **Update it every session that touches the project.** A stale project note is worse than none, because it is trusted.
- Focus on what a new contributor could not work out from the code in an hour.
- When a decision is superseded, say so and say why — keep the old reasoning visible.
- During an orchestration wave, this note is the orchestrator's alone, written once per wave on a `knowledge/` branch after the merges.

Template: `[[Templates/Project Template]]`.
