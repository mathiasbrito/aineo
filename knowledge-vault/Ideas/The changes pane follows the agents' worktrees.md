# The changes pane follows the agents' worktrees

#idea/ready

**Graduated** to [[Planning/aineo — worktrees and session switches]] › P1–P5 (2026-10-06), proposed for the user's converge round; wave 9's T38 builds it once agreed.

**Raised by:** the user, 2026-10-06, to consider after the MVP review. Recorded by the orchestrator. Not a commitment.

## The idea

The changes pane (D19, C15, T25) lists what changed in the one checkout the editor is in, since the session's base. When the work is done by agents in their own git worktrees, the pane could also show those worktrees: each one's changed files and commits since its base, with Enter's diff working there too.

## Problem it solves

The work happens out of the pane's sight under the orchestrate skill's way of working. Implementer and reviewer agents each work in a worktree of their own under `.claude/worktrees/`, on their own branches, and that folder is git-ignored. The user's checkout stays on `dev`, untouched, until a pull request merges and `dev` is pulled.

On 2026-10-06 the user opened the pane with v0.2.12 while T26 was being built in a worktree. The pane said "No files changed on this session" and "No commits on this session". That is correct by D19, but it shows nothing of the work in progress.

## Prior art & inspiration

- `git worktree list --porcelain` lists every worktree of a repository, with its path, its `HEAD` and its branch.
- T23's git home (`lua/aineo/git/`) already gives one directory's repository, its changed files, its commits since a base, and a watch. Each worktree is such a directory.

## Technical considerations

- **The session's base per worktree.** The base could be the worktree's merge base with `dev`, or its `HEAD` when the pane first saw it. D19's "the session's base" is one commit today.
- **The layout.** The files and commits windows could be grouped by worktree, or have a worktree picker. D18's two windows stay put.
- **The cost.** One watch and one set of reads per worktree. T25's measurements of a large repository (L5, L7) apply to each.
- **Lifetime.** Worktrees come and go as agents start and finish. The list must follow `git worktree add` and `remove`.
- **Binding documents.** It changes D19's "files that differ from the session's base" from one repository to several, so it needs a converge round and a new D row. C15 (the changes home) would grow; the `modularity` skill's rows for `aineo.changes` may need a new dependency.

## What would have to be true

- The user wants to watch agents' work as it happens, not only once it is merged.
- Watching several worktrees stays cheap enough. T25's watch, which runs on a show, measured about one read per second under a writer.

## What would kill it

- The orchestrator's ledger and the Agent Report already give enough of a view.
- The cost of many watches on a large repository.

## Open questions

- Show every worktree, or only those under `.claude/worktrees/`?
- One merged list, or one section per worktree?
- Does Enter on a worktree's file open that worktree's file, or only its diff?

## Related

- [[Planning/aineo — v1 agent console]] › D18, D19, D22, C12, C13, C15
- [[Planning/aineo — worktrees and session switches]] › P1–P5, and [[Implementation/Waves/00009-worktrees-sessions/plan]]
- [[Projects/aineo]]
- [[Skills/Orchestrate]]

## Log

| Date | Note |
|------|------|
| 2026-10-06 | Raised by the user after seeing an empty changes pane while T26 was built in a worktree; to consider after the MVP review. |
| 2026-10-06 | Asked for by the user ("\pc panel should be able to also track agents worktrees … You alerady have some notes on that"). Measured (wave 9's A1–A3) and proposed as P1–P5, answering this note's open questions: every worktree, a section each, Enter showing only the diff — each with its alternatives, for the converge round. |
