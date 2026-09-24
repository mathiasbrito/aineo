# Packet brief — template

Fill every slot. Draft it as `<scratchpad>/orch-brief-<slug>.md`, have it reviewed (the `brief` block of `reviewer-brief.md`), commit the corrected brief as `knowledge-vault/Implementation/Waves/<NNNNN>-<slug>/brief-<slug>.md` with the plan (SKILL §3) and merge it, then send its path as the `prompt` of an `Agent` call with `subagent_type` chosen by the packet's files — `implementer`, or the specialist whose domain the packet touches (SKILL §4) — and `model: "opus"` (SKILL §1: every role in this project runs on Opus). The brief states the model in its Boundary, so the record shows who wrote the code. The agent's definition already carries the charter (worktree rules, shared state, how to work, how to land, the report shape); the brief carries only what is specific to this packet.

---

**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged.

You are dispatched by the orchestrator to implement **one packet** of `<path to the task list>`. Your definition tells you how to work; this brief tells you what.

## Objective

Tasks, verbatim from the task list:

<paste each task line in full, including its stable-ID citations>

They rest on: <requirement and success-criterion IDs in the spec; D# rows in `knowledge-vault/Planning/<project> — <feature>.md`; principles of the constitution; any task that constrains this — each id looked up, never recalled>.

### Facts, checked against `origin/dev`

<each fact with how it was checked — `git ls-tree origin/dev <path>`, `git grep -n`, a computation you ran, the evidence file under `evidence/` whose statement produced it. State properties the implementer must construct, not test data: a datum you supply for a negative case must be wrong in exactly one way, and the safer brief supplies none.>

### Baseline

<the suite counts, pasted from the output that measured the base sha — and the evidence file that holds it>

Read first: <the spec, plan and data-model sections, by heading>; `knowledge-vault/Projects/<project>.md`; <vault notes that hold context for this packet, e.g. the session note that opened the task>.

## Boundary

- **Branch:** `feature/<slug>` from `origin/dev`.
- **Model:** `opus` — every role in this project runs on Opus (SKILL §1).
- **Resources:** `impl_<slug>`, the slug's hyphens written as underscores (`prepare-worktree.sh` refuses a hyphen) — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** <files and modules, explicitly; include the entry point you may add exports to, every registration list and every pin that counts what you add, every list a new module home changes, the test files, the task list — **your own lines only**, or **no marks** when the wave holds its marks (SKILL §3 rule 6), in which case: *a `## Task lines` section in your session note, one paragraph per task in the closed lines' style* — and the session note you will create> — and the documentation this change invalidates: <the README paragraph, the plan's tree entry, the data-model row — named by file and section; correct them in the same commit and say in your report what you corrected>.
- **You must not touch:** <files other packets in this wave own; the project note; the schema if another packet holds it this wave; the dependency manifest and lockfile unless this packet is a dependency change> — and never `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude` or `.gitignore`, which change every agent and belong on an `ai/` branch.
- **Session note:** `knowledge-vault/Sessions/<YYYY-MM-DD>[-<letter>] — <topic>.md` — this exact filename, chosen by the orchestrator so it collides with no other packet's.
- **Scratch prefix:** `<slug>-` on every file you write under the shared scratchpad.
- Anything the tasks need that lies outside the boundary is a **spec conflict** for your report, not a reason to widen it.

## What was decided already

<for a task that needed a decision: the decision as the user made it, verbatim, and the alternatives rejected — so the agent does not re-open it>

## Budget

This packet is <small: one test/implementation pair | medium: a cluster of N tasks | large: a new entity or subsystem with its tests>. If you find it larger than that, stop at a green, reviewed, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/<slug>-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
