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
- **The suite** (T1): `make deps`, `make test`, `make test_file FILE=<path>`, `make lint`, `make format` — the root `CLAUDE.md` says what each does. About 87 s for the whole suite on Macbook-Mathias at the end of wave 1; 454 cases in 256 s at the end of wave 2; 491 cases in 365 s at the end of wave 3; 613 cases in 431 s at the end of wave 4; 727 cases in 463 s at the end of wave 5 (the orchestrator's verification of `a9f8027`) — most of it the Claude session's and Send's tests, which drive real processes. `make format` can abort intermittently ([[Learnings/StyLua 2.5.2 in-place formatting aborts intermittently]]); `make lint` decides.
- **Hooks:** `.claude/hooks/test-hooks.sh` after touching any hook.
- **The user's Neovim loads aineo from a release: `~/Development/Personal/aineo-release`**, a clone detached at the latest release tag — `v0.1.0` since 2026-09-25 — through the lazy.nvim spec `~/.config/nvim/lua/plugins/aineo.lua`, which is the user's own and is not committed by the orchestrator. It moves only when the user asks for a new release (the user, 2026-09-25: "it keeps stable while we develop. until I ask for a new release"). `~/Development/Personal/aineo-dev` stays a clone of `dev` for trying merged work, and is no longer fast-forwarded after each merge.
- **How a release is cut** (the orchestrator's method, 2026-09-25, when GitHub refused to rebase v0.1.0 — not yet put to the user): a `release/vX.Y.Z` branch into `main` by pull request, **squash-merged** — GitHub refused to rebase v0.1.0's 139 commits, and branch protection forbids merge commits — then an annotated tag `vX.Y.Z` on `main` whose message names the `dev` commit it was cut from. `main` holds its bootstrap commit, `511e289`, and then one commit per release. The next release branches from `origin/main` and cherry-picks `dev`'s commits after the previous tag's `dev` commit; `git diff <dev commit> origin/main` must then be empty.


## Key decisions
<!-- D# rows with their reasoning, or links to the Planning notes that hold them. -->

- **Orchestration runs on Opus only** (the user, 2026-09-23) — the orchestrator and every agent it dispatches. See [[Skills/Orchestrate]] § Design decisions.
- **A Neovim plugin specialist, `neovim-lua-developer`** (the user, 2026-09-23), beside the generalist `implementer` and `reviewer`. See [[Skills/Orchestrate]] § Specialists.
- **A Claude Code integration specialist, `neovim-claude-code-integrator`** (the user, 2026-09-23), which also binds `neovim-lua-developer`'s rules. Same section.
- **Implementers run at `high` effort, reviewers at `xhigh`** (the user, 2026-09-24) — through the reviewer variants `neovim-lua-reviewer` and `neovim-claude-code-reviewer`; a fix round or a correction goes to a fresh agent once its author's context passes 400 K (the orchestrator's threshold). See [[Sessions/2026-09-24 — Wave 2 retrospective]].
- **Send works while Claude is in a turn, and Claude Code queues the message (D14)**; **aineo takes the screen from a startup dashboard (D15)** — both the user's, 2026-09-24, in [[Planning/aineo — v1 agent console]].
- **Wave shapes beside the ordinary wave** (the user, 2026-09-25): a **rolling wave** grows one packet at a time, each converged with the user and then run as an ordinary packet (PR #23); a **small fix**, only when the user calls a packet one, runs with two reviews in place of three and no re-measure unless a mechanism moved (PRs #24, #25). Both are in the orchestrate skill, §3.
- **v1 is an agent console** (converged with the user in two rounds, 2026-09-23): Claude Code's interactive TUI in a terminal on the left, Agent Report over Input on the right, files in a middle column, every command behind `\`, reports through an MCP tool. Decisions D1–D13, components C1–C9 and tasks T1–T8 in [[Planning/aineo — v1 agent console]]. That resolved the decisions this note listed as awaiting the user: the supported Nvim minimum (0.11, D10), the test runner (mini.test with a fake `claude`, D10), the integration's direction (the interactive TUI plus an MCP report tool — neither headless stream-json nor the IDE protocol, D2 and D8), and who answers permission prompts (the user, in the terminal, D11). The formatter and linter followed the same evening: StyLua + selene (D12).


## Known gotchas

- **The first `claude` launch in this folder showed the workspace-trust dialog**, with "No, exit" selected (measured 2026-09-23, F6). The user answers it; aineo never does.
- **The user's `maplocalleader` is `\`**, aineo's prefix (R3): nothing uses `<LocalLeader>` today, and aineo never overwrites a mapping.
- **Claude Code auto-updates**: 2.1.280 in the afternoon of 2026-09-23, 2.1.281 by 21:50, 2.1.282 by the morning of 2026-09-25 (`claude --version`: `2.1.282 (Claude Code)`). Waves 2–4 measured 2.1.281; a version-sensitive fact names the version it was measured on.
- **A bare `nvim` now starts aineo and the real Claude Code** in the folder it opens (T7, 2026-09-25) — the user's own editor included, through `~/Development/Personal/aineo-release`. Opt out with `vim.g.aineo = { autostart = false }`.
- **GitHub had no branch protection on `main` or `dev` when the orchestrator looked on 2026-09-25 at 15:41, and nothing records it ever being set**, although the root `CLAUDE.md` described it: the Claude hook and the git hooks were the only guards. The user had it turned on that day — a pull request required, linear history, no force push or deletion, admins included.
- **Neovim 0.11.6's `vim.wait()` does not time out while a child floods its output**, so `SystemObj:wait(ms)` bounds nothing then: [[Learnings/vim.wait does not time out under an event flood]].
- **The interactive CLI's behaviour in a terminal is measured, not documented** — readiness, paste, how it stops: [[Learnings/Claude Code's interactive CLI in a Neovim terminal]]. Its input box stays on screen during a turn, and a message submitted then is queued (wave 3's evidence); its footer shows the user's own settings, so it is no readiness signal.
- **Neovim traps the wave-2 packets met** — [[Learnings/A hidden terminal buffer starts at five rows]], [[Learnings/sockconnect's on_data hands a zero byte over as a newline]], [[Learnings/A deleted scratch buffer written to again blocks quitting]], [[Learnings/nvim --clean still loads plugins from the system site directories]].
- **A test run's exit status is only as good as the runner that decides it** — [[Learnings/mini.test v0.18.0 hangs instead of failing]], [[Learnings/A test case can end a mini.test run green]], [[Learnings/NVIM_LOG_FILE leaks past XDG isolation]].


## Where the work stands
<!-- What is done, what is in flight, and the queue the orchestrator composes the next wave from. -->

**Done:** wave 1 — T1, the tooling foundation (PR #4, 2026-09-24; [[Implementation/Waves/00001-tooling/plan]]). T2 — measured by the orchestrator in the folder the user trusted, recorded in the wave-2 plan's *Measured before planning*. Wave 2 — T3 the layout (PR #9), T5 the report channel (PR #10), T4 the Claude session (PR #11), all 2026-09-24 ([[Implementation/Waves/00002-layout-session-report/plan]]); each home stands alone. Wave 3 — T6 Send (PR #15, 2026-09-25; [[Implementation/Waves/00003-send/plan]]). Wave 4 — T7 the entry point (PR #17, 2026-09-25; [[Implementation/Waves/00004-entry/plan]]): `:Aineo`, the `<Plug>` and `\` mappings, the autostart with D15, the composition of every home.

Wave 5 — T8, `:checkhealth aineo` and `doc/aineo.txt` (PRs #21 and #22, 2026-09-25; [[Implementation/Waves/00005-health/plan]]). **v1 is complete (T1–T8) and released as `v0.1.0`** (PR #26, `main` at `b59a54e`, 2026-09-25).

Wave 6 — `00006-fixes`, a rolling wave of the user's fixes, claimed 2026-09-25 ([[Implementation/Waves/00006-fixes/plan]]; retrospective begun in [[Sessions/2026-09-26 — Wave 6 retrospective]]):
- **Landed:** T9, the Report's colours, a small fix (PR #30, 2026-09-26). The time links to `Comment`, and `[status]` to a diagnostic group of its status, as `:highlight default link` groups a user can override.
- **In review:** T13, Neovim 0.12 compatibility (PR #31).
- **Next, in order:** T14, Input kept as a draft (D17), then T12, `\tcn` (D16). T10 (Report links, a small fix) and T11 (the report icon, C10) are to be planned later in the wave.

**Next:**
- The MVP review with the user, with [[Review/2026-09-24 — v1 MVP readings review]] (MR1–MR95) as its agenda.
- Wave 7, converged with the user on 2026-09-25 and not yet planned: a changes pane beside the agent pane, and sending only Input's selection. Its rows are D18–D20, C12 and C13 in [[Planning/aineo — v1 agent console]]. Its plan comes once T14 and T12 are underway, and its packets start after them, since they change the same layout and entry code. Q6 and Q7 go to the user first.

**Open threads:**
- T5's `tests/test_mcp_blocked_editor.lua` writes a `v:null` file into the checkout's root when its editor autostarts — latent while the suites' preset holds; a fix belongs to T5's home.
- The terminal of the last session is kept twice, by the Claude home and by the composition root.
- The MCP server reports `serverInfo.version = '0.0.0'` (`lua/aineo/mcp/protocol.lua`, pinned by `tests/test_mcp_relay.lua`) while the release is `v0.1.0`.
- The version check's timer kills the process group although the early return always does too (an equivalent mutant at the wave-5 verification); its own kill is redundant, and in a same-pass race it can make a command the check killed read as a failed one (the records review of PR #27). A timer that only sets the flag stays bounded.
- The prefix keys' subcommand table (`s o r i c`) is kept twice, in `plugin/aineo.lua` and `lua/aineo/health.lua` (T8); a change to one without the other fails the prefix group's keys comparison.
- The Learning *Claude Code's interactive CLI in a Neovim terminal* split into claims, carried from wave 2.

**Host limits for orchestration:** Macbook-Mathias — 3 agents at once (10 CPUs, 64 GiB; the orchestrate skill's default of 3 parallel implementers, applied to all agents).

**Decisions awaiting the user:**
- The oldest `claude` version supported (2.1.281 is installed) — MR28 of the MVP readings.
- The readings and limits of [[Review/2026-09-24 — v1 MVP readings review]], at the MVP review — among them MR77 (`prefix = ''` refused) and MR92 (the leader warning), both the orchestrator's readings.
- The release method — squash-merge into `main`, later releases cherry-picked from `dev` (the orchestrator's, 2026-09-25).

## Changelog
| Date | Session | Summary |
|------|---------|---------|
| 2026-09-23 | [[Sessions/2026-09-23 — Orchestration and knowledge vault scaffold]] | Agent orchestration (`.claude/`) and this knowledge vault scaffolded from Correria's structure, without its project content |
| 2026-09-23 | [[Sessions/2026-09-23 — Orchestration and knowledge vault scaffold]] | v1 converged with the user in two rounds — [[Planning/aineo — v1 agent console]]; bootstrap `511e289` on `main` and `dev` |
| 2026-09-24 | [[Sessions/2026-09-24 — Wave 1 retrospective]] | Wave 1 landed: T1 (PR #4, `5edf69f` … `7284c00`), the ai pass (PR #5, `12353b2` … `798275d`); T2 measured; wave 2 planned |
| 2026-09-24 | [[Sessions/2026-09-24 — Wave 2 retrospective]] | Wave 2 landed: T3 (PR #9, `b47be4e` … `c1e3962`), T5 (PR #10, `adf4815` … `e006d58`), T4 (PR #11, `f6b4beb` … `c7a9c99`), the effort pass (PR #12); D14 and D15 decided by the user; wave 3 (T6) planned |
| 2026-09-25 | [[Sessions/2026-09-25 — Wave 3 retrospective]] | Wave 3 landed: T6 Send (PR #15, `1826fe9` … `bb0e185`); the `ai/` pass on narrowed mutant runs (PR #14); wave 4 (T7) planned |
| 2026-09-25 | [[Sessions/2026-09-25 — Wave 4 retrospective]] | Wave 4 landed: T7 the entry point (PR #17, `fa6b28c` … `201873b`); `ai/` passes #18 (worktree cd guard) and #19 (suites' isolation documented); wave 5 (T8) planned |
| 2026-09-25 | [[Sessions/2026-09-25 — Wave 5 retrospective]] | Wave 5 landed: T8 health and help (PR #21, `bf0bfad` … `1916dee`; PR #22, `7c9a12f`, `22ce027`) — v1 complete. `ai/` passes #23 (the rolling wave, `0f83767`, `f13d3db`) and #24/#25 (the small-fix class, `0ed0bbe`, `025d5d2`, `4d05f84`). Release `v0.1.0` (PR #26, `b59a54e`); GitHub branch protection turned on for `main` and `dev`. |
| 2026-09-26 | [[Sessions/2026-09-26 — Wave 6 retrospective]] | Wave 6 (rolling): T9, the Report's colours, landed as a small fix (PR #30, `a86a69c` … `3d67b05`) |
