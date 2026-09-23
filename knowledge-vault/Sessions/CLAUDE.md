# Sessions

A dated log of meaningful work. One note per session, per author.

## Naming

`YYYY-MM-DD — <topic>.md` — add a letter suffix for multiple sessions in one day: `2026-09-23-b — <topic>.md`. During an orchestration wave the orchestrator assigns each packet's filename in its brief, so two same-day packets cannot collide. A filename is an identifier once anything cites it; do not rename it afterwards.

## Required content

- **Author** — who did the work. This vault is shared; an unattributed note is a dead end when someone has a question. An agent's note names the human and the role: "<name>, with Claude — implementer agent".
- **Branch** — where the work was committed.
- **What** was done, concisely.
- **Why** — the goal or the request behind it.
- **Commits** — every hash produced, with branch and a one-line description. **Record them after the merge, never before.** `main` and `dev` require linear history, so a pull request lands by rebase and every commit is replayed under a **new SHA**: a hash written while the branch is still open names a commit that will exist on no branch, and a placeholder left for "the last one" is a hash nobody comes back for. Write the note with the work, on whatever branch the work is on, and leave the Commits section for a follow-up `knowledge/` branch cut from `dev` after the merge; `git log --oneline dev` then gives the hashes that will still resolve in a year. Commit messages follow the standard in the root `CLAUDE.md`: **never one-line**, rich, ID-citing, and retaining the `Co-Authored-By:` / `Claude-Session:` trailers as provenance.
- **Decisions** and their reasoning, by ID where they belong to a plan.
- **Links** to the `[[Projects/aineo]]` note, the wave plan if any, and any `[[Learnings/...]]` extracted.
- **Open threads** — what was left unfinished, explicitly, so the next person can pick it up.

## Rules

- Write it at the end of the work, not from memory a week later.
- Record what was **decided against an objection**, and who objected. That is the part nobody can reconstruct.
- If the session changed a decision from an earlier plan, link the plan and update it there too — the session note is the journal, the plan note is the state.
- A wave's retrospective is a session note: the ledger's content, the per-packet cost table, the findings by context type, and what the adjustment pass changed.
- Absolute dates only.

Template: `[[Templates/Session Template]]`.
