# 2026-09-23 — Orchestration and knowledge vault scaffold

**Author:** Mathias Santos de Brito, with Claude
**Branch:** none at first — the folder was not a git repository; then the bootstrap on `main` (pushed by the user), `ai/wave1-prep` (#1) and `knowledge/v1-plan` (#2)

## Context
**Project:** [[Projects/aineo]]
**Goal:** Replicate the agent-orchestration structure of Correria's `.claude/` folder and the template structure of its `knowledge-vault/` in aineo, without any Correria project content.

## What was done

Built from `~/Development/Personal/Correria` as it stood on 2026-09-23.

**Copied unchanged:** `.claude/settings.json` (the two `PreToolUse` hooks); `.claude/hooks/command-shape.sh` and `record-review.sh`; the `tdd`, `clean-code` and `documentation-discipline` skills (byte-identical to the user's global copies and free of project references).

**Copied, then stripped of Correria wording:** `guard-protected-branch.sh`, `require-review-before-commit.sh` (the review checklist now names the root `CLAUDE.md` and the constitution once one exists, instead of Correria's principle numbers), `test-hooks.sh`, `.githooks/` (`install.sh`, `pre-commit`, `pre-push`). The hook suite ran after the edits: **78 passed**.

**Generalised — every mechanism kept, the Correria stack, domains, IDs and wave history removed:**
- `.claude/skills/orchestrate/SKILL.md` and its three prompts (`packet-brief`, `reviewer-brief`, `fix-round`) — the ten sections, the six parallel-safety rules, the brief review, the wave claim, the three-fold review with the `guarantee`, `reader`, `re-measure` and `brief` blocks, the fresh-context correction, the orchestrator's own verification, landing order, ledger and cleanup. Each rule that Correria learned from a specific wave is kept as the rule and its reason, without the wave's history.
- `.claude/agents/implementer.md` and `reviewer.md` — database-specific rules (TypeORM migrations, `correria_app`, `template_postgis`) restated as rules about any shared or applied-once state.
- `.claude/skills/modularity/SKILL.md` — language-agnostic; the module-home table and the lint's patterns are left for the project to fill.
- `.claude/scripts/prepare-worktree.sh` — the name check, the main-checkout refusal and a `.worktreeinclude` check are generic; the stack-specific setup is an empty `prepare_project` function.
- Root `CLAUDE.md` — the vault rule, the four binding skills, the commit-message standard, the branch rule and its enforcement, the review gate. The product description and the constitution section are placeholders.
- `knowledge-vault/` — the root `CLAUDE.md` and `README.md`, a `CLAUDE.md` in every folder, the ten templates, an empty `Tracking/Tracking.md` index, a generic `Skills/Orchestrate.md` and `Review/How pre-merge review runs here.md`, and a stub `Projects/aineo.md`.

**Left out on purpose:**
- The five Correria specialists (`database-expert`, `nestjs-backend-developer`, `ionic-frontend-developer`, `backend-security-expert`, `devops-infra-expert`) — domain content. How to add specialists is in [[Skills/Orchestrate]].
- `drop-agent-databases.sh` — PostgreSQL-specific; a cleanup script belongs beside `prepare-worktree.sh` once per-agent resources exist.
- spec-kit (`speckit-*` skills and `.specify/`) — tooling, not structure; installs fresh with `specify init --here --ai claude` (0.10.1 is on this machine, the version Correria uses). The orchestration is written against a task list with dependencies, which spec-kit's `tasks.md` provides.
- Every Correria note, plan, wave, review, learning and tracking subject; `.claude/settings.local.json` (per host, gitignored).

- **v1 converged with the user** in two rounds of the `converge` skill: layout A, the file column with its redirect and equal thirds, the `\` prefix, the MCP report tool, and C1–C9 as proposed. Recorded as [[Planning/aineo — v1 agent console]] (D1–D12, C1–C9, T1–T8), reviewed by a records reviewer before merge (#2).
- **The user took the orchestrator role for v1** with merging delegated; the orchestrator's first passes are #1 (the agent configuration wave 1 needs) and #2 (the plan).

## Commits

| Hash | Repo | Description |
|------|------|-------------|
| `511e289` | aineo (`main`, `dev`) | Bootstrap aineo with its orchestration and knowledge vault — committed and pushed by the user |

The hashes of #1 and #2 are recorded after they merge.

## Decisions & reasoning

- **Distil, do not transcribe, the orchestrate skill.** Correria's skill carries thirty waves of dated history inside its rules; the history is Correria's record, and the rules stand without it.
- **`prepare-worktree.sh` keeps a stable interface with an empty body.** The charters call it as their second step, so the call is the same whatever the stack becomes.
- **The vault overrides the personal brain vault for aineo work**, as Correria's does; the brain gets only a pointer note.
- **Orchestration runs on Opus only** (the user's decision, after the scaffold). Correria allocates by role and by risk — Opus on attack and on guarantee-carrying implementers, Sonnet on records, test-integrity, re-measure and brief reviews; here every role is Opus, including the orchestrator session. Pinned as `model: opus` in both agent definitions, passed as `model: "opus"` on every `Agent` call by the skill and both brief templates, and checked for the session before the first dispatch. The re-measure after a round that moved a guard keeps the attack question; only the model distinction went away.

- **A Neovim Lua specialist, `neovim-lua-developer`** (the user's request, after the Opus decision), added beside `implementer` and `reviewer` and in the shape `Skills/Orchestrate.md` prescribes: the generalists' frontmatter, a first instruction to read the charter its brief names, then *what bites here*, *tests*, *traps already paid for* (empty) and *what you add to a review*. Every Neovim fact in it was read in 0.11.6's `$VIMRUNTIME/doc` or measured with a headless probe on 0.11.6, not written from memory — `vim.system`'s `on_exit` runs in a fast event where `nvim_buf_set_lines` fails; `nvim_create_augroup(name, {})` left 0 autocommands on re-creation; an on-disk edit reached `require` only after `package.loaded[name] = nil`; `table.unpack` is `nil` and `unpack` and `bit` present; `--clean` keeps `stdpath('config')` off `'runtimepath'`. Routed in SKILL §4 (a table of files → type) and §6 (on at least one dimension of a change to the plugin's Lua, vimdoc or harness); both charters name it.

- **Claude Code's local interfaces, researched** (the user asked whether Claude Code has a local API). A `claude-code-guide` agent read the docs; its report was checked against the 2.1.280 CLI before it was relayed, and three claims fell: `claude mcp serve` exists (reported unconfirmed); no `daemon` command is listed in `claude --help` (reported to exist); the hook name `CommandPost` and "won't break between releases" could not be confirmed. Answer given: no local HTTP API; headless stream-json (documented), the IDE WebSocket MCP protocol (partly documented, community Lua implementation in `coder/claudecode.nvim`), `claude mcp serve`, hooks.
- **A second specialist, `neovim-claude-code-integrator`** (the user's request). Built on the raw docs (`headless`, `cli-reference`, `agent-sdk/typescript`, read with `curl`, not through a summary) and on measurements listed in [[Skills/Orchestrate]] § Specialists. Routed in SKILL §4 ahead of `neovim-lua-developer`, and on attack in §6; both charters name it.
- **The structure became a template** (the user's request, before any aineo-specific code): `git@github.com:mathiasbrito/claude-project.git`, bootstrap commit `a1f53a8`, extracted from this scaffold with project names as `__PROJECT__`, the model policy set per project, and this project's two specialists in an inactive `.claude/agent-library/`. Recorded in the personal brain vault, since the template is not aineo knowledge. The extraction found one defect that aineo shared: `.claude/hooks/record-review.sh` read the branch with `git rev-parse --abbrev-ref HEAD`, which fails before a repository's first commit; both copies now use `git symbolic-ref --short -q HEAD` (hook suite 78 passed).

## Learnings extracted
- none

## Open threads

- Whether to adopt spec-kit; until then the v1 plan's D# and C# rows are the spec (root `CLAUDE.md`, vault `CLAUDE.md`).
- T2 waits for the user to trust this folder in Claude Code once.
- Wave 1 (T1): the brief is reviewed, the wave claimed and dispatched after #2 and #1 merge.
- aineo still carries the Opus-only text where the template now has a per-project policy section; realign on an `ai/` branch when convenient.
