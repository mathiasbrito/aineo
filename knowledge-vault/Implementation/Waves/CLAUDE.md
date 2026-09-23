# Waves

One folder per orchestration wave — the plan, the packet briefs exactly as dispatched, the brief review that checked them, and the evidence the briefs cite. The orchestrate skill (`.claude/skills/orchestrate/SKILL.md`) plans here, dispatches from here and closes here.

## Why this folder exists

A plan that exists only in the session that wrote it cannot be read by a second session, cannot be handed to another host without a bundle, and leaves no history of what was planned against what was built. Here a plan is a commit: reviewed before it is dispatched, merged before any implementer sees it, and closed with what landed.

## Naming

`Waves/<NNNNN>-<slug>/` — five digits, the wave's number, then a slug for the wave's subject: `00001-foundations`. Inside:

- `plan.md` — the plan, from `[[Templates/Wave Plan Template]]`: frontmatter with the status, the composition, the six-rules table, the baseline, what was measured before planning, the decisions put to the user and their answers, the reviewer allocation, the verification mutants.
- `brief-<slug>.md` — one packet brief per packet, exactly as dispatched (the `Agent` call names this path).
- `brief-review.md` — the brief reviewer's report, verbatim.
- `evidence/` — the measurements the briefs cite as plain-text files (`*.txt`, `*.sh`): the planning probe and its output, the baseline's measurement output. Text, never binaries — binaries go to `Attachments/`.

## Status — the lock between sessions

The frontmatter's `status` is the only thing that says whether a wave is free to run:

| status | meaning | who sets it |
|---|---|---|
| `planned` | briefs written and reviewed; not dispatched | the orchestrator that planned it, in the pull request that adds the folder |
| `claimed` | dispatched; implementers running or reviews under way — with `claimed_by` (host, per-host mark, session id) and `claimed_at` | the orchestrator that dispatches, in a `knowledge/` commit merged before the first `Agent` call |
| `landed` | every packet merged and the knowledge pass done — with `landed_at` and the pull requests | the knowledge pass |
| `superseded` | not run; replaced by a later wave, which the note names | whoever replaces it |

**One orchestrator session per host.** A session that finds a `claimed` wave whose `claimed_by` names its own host *and another session* does not plan or dispatch until that wave is `landed` or the claim is withdrawn by the session that holds it — two sessions on one host would share its services, its dependency install and the memory that bounds its agents, and cannot see each other's agents. One session may hold several claimed waves at once when their file sets are disjoint by the six rules recomputed across the waves, its agents counted once against the host's limit. A second host may claim a wave beside another host's on the same terms — disjoint file sets — with its own limit.

**`claimed_by` names the host by something that tells hosts apart.** Two clones of one machine image share a hostname and may share a machine id too, so the claim carries the hostname, a per-host mark (`/etc/machine-id`, or `ioreg -rd1 -c IOPlatformExpertDevice | grep IOPlatformUUID` on macOS) **and the session id** — the session id is the field that discriminates; the other two say where to look.

## Rules

- **Merged before dispatch.** The plan's pull request lands on `dev` before any implementer is dispatched, and the briefs the implementers read are the merged ones — a brief is a claim like any other, and a claim on `dev` has a hash.
- **Nothing here is edited in place after dispatch** except the frontmatter's status and the closing section (`## Landed`): a correction to a brief mid-wave is a fix-round message in the ledger, recorded in the retrospective, never a rewrite of what was sent. A brief amended *before* its packet is dispatched gets a dated section, reviewed like the original.
- **The ledger stays out.** `orchestration-ledger.md` is one session's working state and lives in its scratch directory; the retrospective in `Sessions/` is the record of what happened. The plan says what was intended.
- **Paths cited in a brief are repository paths or paths under this folder**, so a brief resolves on any host. A report an agent writes goes to the session's scratch directory, as the charters say; a brief names that by its role (`<scratchpad>/<slug>-report-<stage>.md`), not by an absolute path.
- Link `[[Projects/aineo]]`, the retrospective that closes the wave, and the plan the composition came from (`Planning/` or the project note's queue).
- The six-rules table is recomputed by the brief reviewer from the briefs, never copied from the ledger.

Template: `[[Templates/Wave Plan Template]]`.
