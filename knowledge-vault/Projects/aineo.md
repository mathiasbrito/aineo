# aineo

## Overview
**Path:** `~/Development/Personal/aineo`
**Stack:** <!-- to decide -->
**Description:** <!-- what aineo is, for whom, and what it deliberately is not -->

## Architecture
<!-- How the pieces fit. Link the Planning notes that decided it. -->


## Environment & setup

- **Per clone, once:** `./.githooks/install.sh` — sets `core.hooksPath` and `remote.origin.prune`. Without it the git-level branch guard is inert.
- **Agent worktrees:** `.claude/scripts/prepare-worktree.sh`'s `prepare_project` is empty until the stack is decided; `.worktreeinclude` lists the gitignored files every worktree needs.
- **Hooks:** `.claude/hooks/test-hooks.sh` after touching any hook.


## Key decisions
<!-- D# rows with their reasoning, or links to the Planning notes that hold them. -->

- **Orchestration runs on Opus only** (the user, 2026-09-23) — the orchestrator and every agent it dispatches. See [[Skills/Orchestrate]] § Design decisions.
- **A Neovim plugin specialist, `neovim-lua-developer`** (the user, 2026-09-23), beside the generalist `implementer` and `reviewer`. See [[Skills/Orchestrate]] § Specialists.
- **A Claude Code integration specialist, `neovim-claude-code-integrator`** (the user, 2026-09-23), which also binds `neovim-lua-developer`'s rules. Same section.


## Known gotchas


## Where the work stands
<!-- What is done, what is in flight, and the queue the orchestrator composes the next wave from. -->

**Host limits for orchestration:** <!-- per host: the number of agents it runs at once, and why -->

**Decisions awaiting the user** — the specialist treats each as a decision until it is recorded here:
- The oldest Nvim version the plugin supports (0.11.6 is installed on this Mac).
- The test runner — busted with nlua, mini.test, or plenary's harness — and with it `prepare_project` (headless Nvim, `XDG_*` directories inside the worktree).
- The formatter and linter (StyLua, luacheck or selene, lua-language-server for the annotations); none is installed on this Mac yet.
- **The integration's direction** — aineo drives Claude (headless `claude -p` over stream-json), hosts Claude's IDE connection (a WebSocket MCP server Claude Code connects to), or both.
- **Who answers Claude's permission prompts** — an MCP tool named with `--permission-prompt-tool`, the in-stream `control_request` host, or `--permission-prompts none` with a fixed permission mode — and the oldest `claude` version supported (2.1.280 is installed; `--permission-prompts` needs 2.1.259, `capabilities` 2.1.205).

## Changelog
| Date | Session | Summary |
|------|---------|---------|
| 2026-09-23 | [[Sessions/2026-09-23 — Orchestration and knowledge vault scaffold]] | Agent orchestration (`.claude/`) and this knowledge vault scaffolded from Correria's structure, without its project content |
