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
- **v1 is an agent console** (converged with the user in two rounds, 2026-09-23): Claude Code's interactive TUI in a terminal on the left, Agent Report over Input on the right, files in a middle column, every command behind `\`, reports through an MCP tool. Decisions D1–D11, components C1–C9 and tasks T1–T8 in [[Planning/aineo — v1 agent console]]. That resolved, from the list below: the supported Nvim minimum (0.11, D10), the test runner (mini.test with a fake `claude`, D10), the integration's direction (the interactive TUI plus an MCP report tool — neither headless stream-json nor the IDE protocol, D2 and D8), and who answers permission prompts (the user, in the terminal, D11). The formatter and linter followed the same evening: StyLua + selene (Q3).


## Known gotchas

- **The first `claude` launch in a folder shows the workspace-trust dialog**, defaulting to "No, exit" (measured 2026-09-23). The user answers it; aineo never does.


## Where the work stands
<!-- What is done, what is in flight, and the queue the orchestrator composes the next wave from. -->

**Queue:** v1, tasks T1–T8 of [[Planning/aineo — v1 agent console]] — T1 (tooling foundation) first; T2 (measuring paste and interactive MCP flags against the real CLI) needs the user to trust a folder once.

**Host limits for orchestration:** <!-- per host: the number of agents it runs at once, and why -->

**Decisions awaiting the user:**
- The oldest `claude` version supported (2.1.280 is installed).

## Changelog
| Date | Session | Summary |
|------|---------|---------|
| 2026-09-23 | [[Sessions/2026-09-23 — Orchestration and knowledge vault scaffold]] | Agent orchestration (`.claude/`) and this knowledge vault scaffolded from Correria's structure, without its project content |
