# aineo Knowledge Vault

**This is the project's knowledge vault. It lives in the repository and is shared by everyone working on aineo.**

> [!IMPORTANT]
> **This vault replaces any personal vault for all aineo work.**
>
> Some contributors keep a private Obsidian vault of their own (for example `~/Development/brain/`) and have global instructions telling them — and their agents — to record work there. **Inside this repository, those instructions do not apply.** aineo knowledge is written *here*, in `knowledge-vault/`, and nowhere else.
>
> The rule is symmetrical and absolute:
> - **Never** write aineo notes into a personal vault.
> - **Never** copy notes from a personal vault into this one without deleting the original — a fact in two places diverges, and then neither can be trusted.
> - **Never** read a personal vault for aineo context. If something is missing here, it is missing; add it here.
>
> A note that is genuinely personal (a contributor's own working habits, an unrelated project) belongs in that contributor's own vault, not here. A note about aineo belongs here even if only one person will ever read it.

This is an Obsidian vault. Open the `knowledge-vault/` folder as a vault; `[[wikilinks]]` resolve across it.

## Why it is in the repo

Sessions end and chats are lost. Decisions, their reasoning, and the traps discovered along the way are expensive to rebuild and impossible to recover from the diff. Committing them means:

- A new contributor reads the vault and knows *why* the code is shaped the way it is.
- Decisions carry stable IDs (`D3`, `C7`, `R5`) that survive into commit messages and specs.
- Reviews and their findings are tracked to closure rather than evaporating.
- Orchestration waves are planned, claimed and closed here, so a second session or a second host can read what is running.
- The knowledge is versioned, reviewable and diffable like everything else.

## Structure

```
knowledge-vault/
├── CLAUDE.md         # this file — the vault's manual
├── Sessions/         # dated log, one note per work session, per author
├── Projects/         # architecture, environment, gotchas — the living overview
├── Planning/         # feature plans: decisions, components, task breakdown (D#/C#/T#)
├── Implementation/   # Waves/: one folder per orchestration wave — the plan, the briefs, the status that locks it
├── Review/           # review findings (R#) tracked found → fixed; how pre-merge review runs
├── Learnings/        # reusable knowledge, one atomic concept per note
├── References/       # pointers to external docs, dashboards, tickets
├── Tracking/         # upstream subjects that go stale: vendor pricing, regulation, tooling
├── Ideas/            # concepts maturing toward implementation
├── Skills/           # this repo's Claude Code skills
├── Templates/        # note templates
└── Attachments/      # binaries reached only via [[wikilink]]
```

## Relationship to the binding documents

The vault is context, not law, and must not drift into the documents that are — with the one exception the table names: a plan the root `CLAUDE.md` names as the spec.

| | Holds | Authority |
|---|---|---|
| The constitution (`.specify/memory/constitution.md`, once the project adopts spec-kit) | The principles | **Binding.** Governs all code. |
| The specs (`specs/`) | What the system must do — requirements | **Binding.** Drives implementation. |
| A plan's D# and C# rows, while the root `CLAUDE.md` names that plan as the spec (v1: [[Planning/aineo — v1 agent console]]) | What the system must do, until specs exist | **Binding.** Changed only through a converge round with the user; superseded by a new ID, never edited in place. |
| `knowledge-vault/` | Why we chose it, what we rejected, what bit us | **Context.** Explains, never overrides. |

If the vault and a spec disagree, **the spec wins and the vault is wrong** — fix the vault. If the vault and the constitution disagree, the constitution wins.

## Branch rule

**Never commit or push to `main` or `dev`** — not for a note, not for a typo, not once. Vault edits follow the same flow as code: a `knowledge/` branch (vault only), then a pull request. Enforced by a Claude `PreToolUse` hook and by `.githooks/`; see the branch section in the repository's root `CLAUDE.md`.

## Working rules

**Retrieval, before starting work.** Read `Projects/aineo.md`. Check `Planning/` for an active plan on the feature, `Implementation/Waves/` for a wave that is `planned` or `claimed`, and `Review/` for open findings. Check `Tracking/` when the work touches an upstream subject that changes under us. Search `Learnings/`. Skim recent `Sessions/` for open threads.

**Capture, after meaningful work.** Write a session note. Update the project note. Extract any reusable learning. Register commit hashes in the session note — after the merge.

**IDs are permanent.** Once `D3` means something, it means that forever. Never renumber. To drop an item, mark it `#deprecated` or `~~superseded~~` so the ID stays reserved and old references still resolve.

**Multi-author.** Every session note names its author. Every plan note names who defined it. When you change a decision someone else made, say who made it and why it changed — do not silently overwrite.

**Link liberally.** The graph is the point. Session → Project, Session → Learnings, Plan → Project, Review → Plan, Wave → Plan, Tracking → Project.

**Keep it a reference, not a transcript.** Prune what is no longer true. Prefer updating a note over adding a near-duplicate.

**Absolute dates.** Write `2026-09-23`, never "last week" — the reader is months away.

## Files not to sweep

- **`Attachments/`** — open a file only when a note you are reading links it. Never glob or bulk-read.
- **`Tracking/**/input/`** — a drop zone. Listing it (`ls`) is required by the refresh protocol; bulk-reading it is not.
- **`Implementation/Waves/*/evidence/`** — read the file a brief cites, not the folder.
