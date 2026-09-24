# aineo

## Overview
**Path:** `~/Development/Personal/aineo`
**Stack:** Lua — a Neovim plugin for Nvim ≥ 0.11 (D10); tests on mini.test; StyLua and selene (D12)
**Description:** <!-- what aineo is, for whom, and what it deliberately is not -->

## Architecture
<!-- How the pieces fit. Link the Planning notes that decided it. -->


## Environment & setup

- **Per clone, once:** `./.githooks/install.sh` — sets `core.hooksPath` and `remote.origin.prune`. Without it the git-level branch guard is inert.
- **Agent worktrees:** `.claude/scripts/prepare-worktree.sh`'s `prepare_project` is empty and needs no step — `make test` isolates itself and fetches mini.nvim on first use (T1); `.worktreeinclude` lists the gitignored files every worktree needs.
- **The suite** (T1): `make deps`, `make test`, `make test_file FILE=<path>`, `make lint`, `make format` — the root `CLAUDE.md` says what each does. About 87 s for the whole suite on Macbook-Mathias at the end of wave 1.
- **Hooks:** `.claude/hooks/test-hooks.sh` after touching any hook.
- **The user's Neovim loads aineo from `~/Development/Personal/aineo-dev`** — a clone of `dev` holding merged pull requests only, through the lazy.nvim spec `~/.config/nvim/lua/plugins/aineo.lua` (2026-09-23, the user's request). The orchestrator fast-forwards it after every merge: `git -C ~/Development/Personal/aineo-dev pull --ff-only`.


## Key decisions
<!-- D# rows with their reasoning, or links to the Planning notes that hold them. -->

- **Orchestration runs on Opus only** (the user, 2026-09-23) — the orchestrator and every agent it dispatches. See [[Skills/Orchestrate]] § Design decisions.
- **A Neovim plugin specialist, `neovim-lua-developer`** (the user, 2026-09-23), beside the generalist `implementer` and `reviewer`. See [[Skills/Orchestrate]] § Specialists.
- **A Claude Code integration specialist, `neovim-claude-code-integrator`** (the user, 2026-09-23), which also binds `neovim-lua-developer`'s rules. Same section.
- **v1 is an agent console** (converged with the user in two rounds, 2026-09-23): Claude Code's interactive TUI in a terminal on the left, Agent Report over Input on the right, files in a middle column, every command behind `\`, reports through an MCP tool. Decisions D1–D11, components C1–C9 and tasks T1–T8 in [[Planning/aineo — v1 agent console]]. That resolved the decisions this note listed as awaiting the user: the supported Nvim minimum (0.11, D10), the test runner (mini.test with a fake `claude`, D10), the integration's direction (the interactive TUI plus an MCP report tool — neither headless stream-json nor the IDE protocol, D2 and D8), and who answers permission prompts (the user, in the terminal, D11). The formatter and linter followed the same evening: StyLua + selene (D12).


## Known gotchas

- **The first `claude` launch in this folder showed the workspace-trust dialog**, with "No, exit" selected (measured 2026-09-23, F6). The user answers it; aineo never does.
- **The user's `maplocalleader` is `\`**, aineo's prefix (R3): nothing uses `<LocalLeader>` today, and aineo never overwrites a mapping.
- **Claude Code auto-updates**: 2.1.280 in the afternoon of 2026-09-23, 2.1.281 by 21:50. A version-sensitive fact names the version it was measured on.
- **The interactive CLI's behaviour in a terminal is measured, not documented** — readiness, paste, how it stops: [[Learnings/Claude Code's interactive CLI in a Neovim terminal]].
- **A test run's exit status is only as good as the runner that decides it** — [[Learnings/mini.test v0.18.0 hangs instead of failing]], [[Learnings/A test case can end a mini.test run green]], [[Learnings/NVIM_LOG_FILE leaks past XDG isolation]].


## Where the work stands
<!-- What is done, what is in flight, and the queue the orchestrator composes the next wave from. -->

**Done:** wave 1 — T1, the tooling foundation (PR #4, 2026-09-24), and T2, measured by the orchestrator in the folder the user trusted ([[Implementation/Waves/00001-tooling/plan]]).

**Planned:** wave 2 — T3 (layout), T4 (the Claude session) and T5 (the report channel) in parallel ([[Implementation/Waves/00002-layout-session-report/plan]]); T4 no longer waits for T5, by injection.

**Queue after it:** T6 (send), then T7 (the entry point and autostart — where Q5, the startup dashboard, goes to the user at the MVP review), then T8 (health and vimdoc). The user reviews the MVP when T1–T8 are in (the user, 2026-09-23).

**Host limits for orchestration:** Macbook-Mathias — 3 agents at once (10 CPUs, 64 GiB; the default of the orchestrate skill).

**Decisions awaiting the user:**
- The oldest `claude` version supported (2.1.281 is installed).

## Changelog
| Date | Session | Summary |
|------|---------|---------|
| 2026-09-23 | [[Sessions/2026-09-23 — Orchestration and knowledge vault scaffold]] | Agent orchestration (`.claude/`) and this knowledge vault scaffolded from Correria's structure, without its project content |
| 2026-09-23 | [[Sessions/2026-09-23 — Orchestration and knowledge vault scaffold]] | v1 converged with the user in two rounds — [[Planning/aineo — v1 agent console]]; bootstrap `511e289` on `main` and `dev` |
| 2026-09-24 | [[Sessions/2026-09-24 — Wave 1 retrospective]] | Wave 1 landed: T1 (PR #4, `5edf69f` … `7284c00`), the ai pass (PR #5, `12353b2` … `798275d`); T2 measured; wave 2 planned |
