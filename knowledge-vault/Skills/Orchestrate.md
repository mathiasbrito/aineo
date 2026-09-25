# Orchestrate

**Tags:** #skill
**Location:** `.claude/skills/orchestrate/SKILL.md`, with templates in `.claude/skills/orchestrate/prompts/` and the agent definitions it dispatches in `.claude/agents/implementer.md` and `.claude/agents/reviewer.md`
**Project:** [[Projects/aineo]]
**Invocation:** `/orchestrate <scope> [parallel=…] [merge=…]`, or by the user assigning the orchestrator role at session start

## Purpose

Runs the work as an orchestrator: plans waves of tasks from the task list under six parallel-safety rules, dispatches worktree-isolated `implementer` agents with the four mandatory skills preloaded, collects their pull requests, dispatches the three-fold review as `reviewer` agents, returns the findings to the implementer for one round, re-measures, verifies the final head itself, and records — hashes after the merge, on a `knowledge/` branch. **The orchestrator writes no application code.**

Why the review runs three ways in isolation: [[Review/How pre-merge review runs here]].

## SKILL.md

```yaml
---
name: orchestrate
description: Run the work as an orchestrator — plan waves of tasks from the task list, dispatch worktree-isolated implementer agents bound by the four mandatory skills and the specs, collect their pull requests, dispatch the three-fold review, return findings for one fix round, verify, and record. Every agent it dispatches, and the orchestrator itself, runs on Opus. Use when the user assigns the orchestrator role, names the effort, and points at tasks or a phase to deliver.
argument-hint: "<scope: task ids or phase> [parallel=<n>] [merge=<no|delegated>]"
---
```

## Configuration

| Field | Value | Why |
|---|---|---|
| `argument-hint` | scope, optional parallel / merge | the brief in one line; no model option — every role is Opus |
| `disable-model-invocation` | unset | the user assigns the role; the model may also recognise the situation |
| `user-invocable` | default (yes) | `/orchestrate <brief>` |

Section map (the file at the path above is the source of truth):

| § | Section | What it binds |
|---|---------|---------------|
| 1 | The brief | What the user supplies at session start, the defaults, and how model and effort reach agents — every role on Opus, pinned in the definitions and passed on every `Agent` call, the orchestrator session checked to be on Opus; effort inherited from the session; a wave is a measurement of the process and of cost |
| 2 | Preconditions | Main checkout on `dev`, services up, no wave claimed on this host by another session, no leftover agent state (list, never sweep), session in the main checkout |
| 3 | Wave planning | Packet and wave; the six parallel-safety rules (dependencies, disjoint file sets including registration files, one schema packet, no dependency change, no undecided decision, non-adjacent task lines); the plan committed under `Implementation/Waves/` before dispatch; ownership of task lines, session notes, the project note and hashes |
| 4 | Dispatch | Briefs written to files and **reviewed by a `brief` reviewer before dispatch**; the wave claimed; one message per wave, each prompt a path; agent type by the packet's files; every fact in a brief checked against the branch, properties not data, documentation the change invalidates inside the boundary |
| 5 | Collect | Never predict a pending result; cut-off agents resumed by message; file list checked against the boundary and the forbidden set; partials decided, not finished by hand |
| 6 | Review | Three reviewers per PR (two when test-only or a small fix the user calls one, records + reader for docs), all landed before the one fix round; reports travel as files; a re-measure after the round — carrying the attack question when it moved a guard; one bounded correction in a fresh context; the orchestrator's own verification with literal mutants shown applied; the orchestrator's own statements are claims |
| 7 | Landing | Merging is the user's unless delegated, and refused to agents by the branch guard; per-file identity proof; hashes only after the merge, on a `knowledge/` branch; passes land ai → tasks → knowledge; the ai pass and Learnings reviewed before merge |
| 8 | The ledger | Scratchpad file rewritten on every state change, timestamps from `date`; copied into the session note before compaction; per-context cost from the transcript |
| 9 | Cleanup | Worktrees and `worktree-agent-*` branches, per-agent resources, orphan loops and runs by pid, scratch archived — every wave |
| 10 | Why | Anthropic's multi-agent findings; a report is a claim, not evidence; what the mechanisms do not do |

## Agent definitions

| Definition | Frontmatter that matters | Charter |
|---|---|---|
| `implementer` | `isolation: worktree`, `skills: [tdd, clean-code, documentation-discipline, modularity]`, `model: opus`, `effort: high` | Branch from `origin/dev` first; own resources; slice, red, green, refactor; honest accounting of tests that arrive green; mutate every path; mutants as literal edits from pristine copies; every count measured against the tree shipped; citations name what was read; stay in the boundary; stage by name, review record, `git commit` run directly, rich commit; PR into `dev`; never merge; own task lines and the session note the brief names; fixed report shape written to a file |
| `reviewer` | `isolation: worktree`, `model: opus`, `effort: xhigh` | Detach at the PR head — or at `origin/dev` for a brief review; own resources; kill-counting rule; never touch shared state; re-measure every claim on every path; build and measure the fix when you can; concrete failure scenario per finding; never commit, push, open or merge; fixed report shape written to a file |

The dimension a reviewer takes — attack, test-integrity, records, the collapsed `guarantee`, `reader` for documentation, the post-fix-round `re-measure`, or the pre-dispatch `brief` review — is a block in `prompts/reviewer-brief.md`, so the isolation charter exists once.

### Specialists

| Definition | Domain | Home dimension | Added |
|---|---|---|---|
| `neovim-lua-developer` | Neovim plugin development in Lua — runtime layout and lazy loading, configuration apart from initialization, `<Plug>` mappings, the API's three indexing conventions, fast callbacks and `vim.schedule`, subprocesses without a shell, augroups and highlight defaults, deprecations, LuaCATS and vimdoc, health checks, headless test isolation from the developer's editor | implementer for `lua/`, `plugin/`, `ftplugin/`, `doc/`; attack or test-integrity on any pull request touching them | 2026-09-23, [[Sessions/2026-09-23 — Orchestration and knowledge vault scaffold]] |
| `neovim-claude-code-integrator` | Neovim ↔ Claude Code — driving `claude -p` over stream-json (process, NDJSON codec, capabilities, interrupts, permission host, sessions) and hosting Claude's IDE connection (loopback WebSocket MCP server, lock file, auth token, RFC 6455 framing); binds `neovim-lua-developer`'s rules on top of the charter | implementer for the integration's homes; **attack** on any pull request touching them | 2026-09-23, same session |
| `neovim-lua-reviewer`, `neovim-claude-code-reviewer` | the two specialists above, dispatched to review: thin definitions binding `reviewer.md` and the specialist's file unchanged, at `effort: xhigh` where the implementing specialists run at `high` — an `Agent` call cannot set effort, so a role's effort needs its own definition | every review dimension the specialist would take; the re-measure | 2026-09-24, PR #12, [[Sessions/2026-09-24 — Wave 2 retrospective]] |

Its facts were read in Nvim 0.11.6's `$VIMRUNTIME/doc` (chiefly `:h lua-plugin`) or measured headless on 0.11.6, and marked as such in the definition: a `vim.system` `on_exit` runs in a fast event where the API refuses; re-creating an augroup clears it; `require` serves the cached module after an edit on disk until `package.loaded` is cleared; `table.unpack` is `nil` on the LuaJIT build; `--clean` keeps the user's config off `'runtimepath'`. Its *traps already paid for* section is empty until the adjustment pass adds the first.

`neovim-claude-code-integrator`'s documentation facts were read raw from code.claude.com (`headless`, `cli-reference`, `agent-sdk/typescript`) for Claude Code 2.1.280, and its measured facts run on this Mac: JSON `null` decodes to the truthy `vim.NIL`; `vim.json.encode({})` is `[]`; Neovim has `vim.base64` and SHA-256 but no SHA-1; `vim.uv.random(32)` returns 32 bytes; a `vim.system` stdout callback runs in a fast event; the JetBrains lock files here are `0644` in a `0755` directory, which aineo does not copy. It sorts Claude Code's surfaces into three tiers — documented, observable but undocumented (the IDE protocol's tool names, found in the 2.1.280 binary), community — and requires every tier-2 fact to be pinned by a recorded transcript and a version. It reads `neovim-lua-developer.md` after its charter, so the Neovim rules have one home.

### Adding specialists

When the project's domains are known, a specialist is **dual-role over the shared charters**: the same frontmatter as the generalists (`model: opus`, `isolation: worktree`, the four skills preloaded), a first instruction to read `implementer.md` or `reviewer.md` as the brief names the role and obey it unchanged, then three sections — *what bites here* (the repository's rules for the domain, with their IDs), *traps this repository has already paid for* (Learnings and task ids), *what you add to a review* (per dimension). Facts that bite are stated; everything else is a pointer into the vault and the specs, so a definition stays near fifty dense lines and the knowledge has one home. Add the routing row to SKILL §4 in the same `ai/` change. Rejected shapes: implementer clones per domain (a security specialist is worth more as the attack reviewer than as a writer), and domain blocks pasted into briefs (not selectable by name, not an identity).

## Design decisions

- **Effort by role (the user, 2026-09-24: "keep xhigh for reviewers, set implementers to high").** `implementer`, `neovim-lua-developer` and `neovim-claude-code-integrator` run at `high`; `reviewer`, `neovim-lua-reviewer` and `neovim-claude-code-reviewer` at `xhigh` — except a small fix's `guarantee` review, which the implementing specialist takes at `high` (the user, 2026-09-25, accepting the orchestrator's proposal of normal effort for small fixes). The frontmatter carries it, since an `Agent` call takes a model but no effort; verified in the transcripts of wave 2's last agents — a reviewer's requests carry `"effort":"xhigh"`, an implementer's `"high"`.
- **A fix round or a correction goes to a fresh agent once its author's context passes 400 K** — the orchestrator's threshold since 2026-09-24, after the user's concern about an author at 964 K; not a measured limit. `.claude/scripts/agent-context.py` reads an agent's context from its transcript.
- **Opus for every role (the user, 2026-09-23).** The orchestrator, every implementer, every review dimension, the brief review, the re-measure and the correction run on Opus. Enforced in three places: `model: opus` in both definitions, `model: "opus"` on every `Agent` call (SKILL §1, §4, §6 and both brief templates), and the orchestrator's own check of the session's model before the first dispatch. The by-role-and-by-risk allocation Correria uses — Opus on attack and on guarantee-carrying implementers, Sonnet on the checklist dimensions — was not adopted, so the model is not a cost lever here; turns, context lifetime, role-specific loading and write-once artefacts are. [[Sessions/2026-09-23 — Orchestration and knowledge vault scaffold]].

## Supporting files

- `.claude/scripts/prepare-worktree.sh <impl_slug|review_dimension_slug>` — validates the agent's resource name, refuses to run in the main checkout, checks every file `.worktreeinclude` lists arrived, then runs `prepare_project` — **empty until the project has a stack**; fill it on an `ai/` branch with the dependency linking and the isolated test resources the suites need.
- `.claude/hooks/guard-protected-branch.sh` and `require-review-before-commit.sh`, with `command-shape.sh` sourced by both — the branch guard, the review gate, the refusal of git writes hidden behind a wrapper, and the refusal of `gh pr merge` from any subagent. `test-hooks.sh` is their regression suite.
- `.worktreeinclude` — gitignored files copied into every worktree Claude Code creates.
- A per-agent resource cleanup script (by exact name, and a list/sweep by kind) belongs beside `prepare-worktree.sh` once the project's per-agent resources exist; names reaching SQL or a shell are validated by construction, never escaped by care.

## Known limits

- A subagent worktree is created from the repository's default branch, not `dev`; the charters compensate by fetching `origin/dev` first.
- Agent definitions may not load immediately after `.claude/agents/` is first created in a running session. The fallback — `general-purpose` with `isolation: worktree` and the charter pasted — works.
- Claude Code's isolation refuses git and file-edit tools that reach the main checkout, not a shell command with an absolute path; the hooks refuse the git writes they can read, not one in a script they cannot open. Text plus the orchestrator's file-list check is what holds the file boundary.
- The orchestrator's brief is the least-reviewed artefact of a wave, which is why the brief review exists; the fix-round message is not reviewed the same way, and the re-measure carries the orchestrator's decisions from it as claims instead.

## Related

- [[Review/How pre-merge review runs here]]
- [[Implementation/Waves/CLAUDE|Waves]]
- [[Sessions/2026-09-23 — Orchestration and knowledge vault scaffold]]
