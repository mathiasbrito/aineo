# Tracking

One folder per **upstream subject we do not control but must stay current with**. Knowledge that is expensive to build, goes stale silently, and matters across the project.

## Subjects that belong here

Anything a decision rests on that someone else can change:

- **Vendor pricing** — a provider's rates, tiers, fixed fees and quotas that a cost model depends on.
- **Regulation** — rules, guidance and enforcement that bound what the product may do or retain.
- **Upstream frameworks and platforms** — release cadence, deprecations and breaking changes.
- **Tooling** — Claude Code, spec-kit and other agent tooling whose behaviour the orchestration relies on.

## Structure per subject

```
Tracking/<Subject>/
├── <Subject>.md          # the tracker: current state, timeline, watch items, refresh recipe
├── <Subject> — <version or date>.md   # one note per version or evaluation
├── input/                # drop zone for unprocessed documents
└── assets/               # local files, reached only via [[wikilink]]
```

`Tracking/input/` is the triage inbox for documents whose subject is not decided yet.

## The tracker note must carry

- **Current state** — what is true today, with the date it was verified.
- **Timeline** — what changed and when.
- **Watch items** — the specific things that would hurt us if they moved, and what breaks if they do.
- **A refresh recipe** — the exact steps to re-verify. Without this the tracker rots, because the next person will not know where the number came from.
- **Impact** — which decisions or specs depend on this. Link them.

## Rules

- **Every figure carries the date it was verified.** An undated figure is unusable.
- When a tracked number changes, **find every decision that depends on it** and say whether it still holds.
- `input/` may be listed (`ls`) during a refresh; it is never bulk-read.
- `assets/` is reached only through a link from a note.
- Watch-item lifecycle: no marker (live) → `#needs-review` (not verified against the current code) → `#deprecated` or `~~struck~~` with status and date.

Templates: `[[Templates/Tracking Template]]`, `[[Templates/Tracking Entry Template]]`. Index: `[[Tracking/Tracking]]`.
