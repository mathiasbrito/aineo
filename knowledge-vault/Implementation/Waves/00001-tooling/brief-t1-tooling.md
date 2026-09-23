**Your role: implement.** A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md` — you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the aineo v1 plan: T1, the tooling foundation. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*:

> T1 — Tooling foundation (C8) and the entry-point skeleton (C1), as a packet: the mini.test harness and its make targets (deps, test, lint, format), the suites' isolation from the developer's editor and Claude state, the `plugin/aineo.lua` and `lua/aineo/init.lua` skeletons, and `lua/aineo/config/` with `vim.g.aineo` validation. The agent-configuration part — `.gitignore`, the `modularity` table, the Nvim minimum in the root `CLAUDE.md` (before the packet), and the commands in `CLAUDE.md` and any `prepare_project` step (after it) — is the orchestrator's `ai/` pass, because no implementer edits those files

It rests on: **C8** (tooling), **C1** (the entry-point skeleton), **D10** (Nvim ≥ 0.11; mini.test; the real Claude never runs in the suite), **D12** (StyLua + selene) and **D13** (the v1 settings — added by the user on 2026-09-23, after the brief review of this wave). Read those rows in the plan, and its *Authority* section, not this summary of them. The fake `claude` is **not** in this packet: it belongs to T4 (C3).

### The behaviours — the orchestrator's reading of T1, one test each where a test can see it; the seams are yours

- **B1 `make deps`** fetches mini.nvim into `deps/mini.nvim` at a pinned release — a tag or a commit sha written in the Makefile, never a branch. A second run with the pin already present makes no network call. The newest tag at planning was `v0.18.0` (`evidence/planning-probe.txt`); the pin is your choice, stated in the report.
- **B2 `make test`** runs every `tests/**/test_*.lua` headless under mini.test and exits non-zero when any case fails — **and also, within a bounded time, on each of these inputs, where the brief review measured mini.nvim v0.18.0 hanging instead of exiting** (with a watchdog): a test file that fails to parse; a test file that `require`s a missing module at top level; a run that collects zero cases. Reproduce each hang first, under a watchdog of your own, and say what you saw. Because the default collection is `tests/**/test_*.lua`, no helper file is named `test_*.lua`.
- **B3 `make test_file FILE=<path>`** runs one file, and exits non-zero when the path does not exist (measured hanging at v0.18.0 too).
- **B4 Isolation — of the runner as well as every child.** Every Neovim the suite starts, **including the runner process `make test` launches**, resolves `stdpath('config')`, `stdpath('data')`, `stdpath('state')` and `stdpath('cache')` inside the checkout's `.tests/`, sees `CLAUDE_CONFIG_DIR` inside `.tests/`, writes no shada outside `.tests/`, and has no entry of the developer's config (`~/.config/nvim`, its `after/`, its `pack/`) on its `'runtimepath'`. Set the `XDG_*` variables **at one site** — the Makefile or the minimal init, not `prepare_project` (the specialist's *Tests* section names `prepare_project`; that line is corrected in the next `ai/` pass, and you must not edit it). Pin: a test that reads those values **in the runner and in a child** and asserts each lies under `.tests/`.
  - **Measure before you build, without touching the user's state.** The brief review measured that the plain `TESTING.md` invocation (`-u scripts/minimal_init.lua --noplugin`) writes `stdpath('state')/shada/main.shada` under the user's home on exit — through both `qa!` and `cquit` — and that its `'runtimepath'` carries the user's config and a plugin from it. Any measurement you make of the plain invocation runs with `-i NONE`, and says what `stdpath('state')` and `'runtimepath'` showed.
- **B5 `make lint`** runs `stylua --check` over the Lua sources and `selene` with a configuration that knows Neovim's `vim` global, and exits non-zero when either fails. Show, in the report, that a planted undefined global in a scratch copy is refused — a measurement, not a committed failing file.
- **B6 `make format`** runs StyLua in place, configured in `.stylua.toml` (your settings, stated in the report).
- **B7 `plugin/aineo.lua`** loads once (a `vim.g.loaded_aineo` guard; a second `:source` does nothing) and requires no `aineo` module at startup. **Pin, in a child started so that `plugin/` is sourced** (not under `--noplugin`, which skips it — the brief review measured the eager-require mutant surviving there): first assert `vim.g.loaded_aineo == true`, proving the file ran; then that `package.loaded` holds no key beginning with `aineo`. It defines nothing else yet — commands, mappings and autostart are T7's. **Once merged, this file runs at every start of the user's own editor** (`~/Development/Personal/aineo-dev`, loaded by lazy.nvim with `lazy = false` — `Projects/aineo.md` › *Environment & setup*): it must raise nothing and change nothing there.
- **B8 `lua/aineo/init.lua`** is the public Lua API: `setup(opts)` records the options for the configuration to resolve and does nothing else (`:h lua-plugin-init`). It may be called any number of times; the last call's table is the one used — calls do not accumulate.
- **B9 `lua/aineo/config/`** is the configuration home, and it is **pure**: it never reads `vim.g` itself (the `modularity` skill §4, "nothing ambient"; `neovim-lua-developer.md`, ambient reads enter at the composition root). It is handed the value of `vim.g.aineo` and the `setup` options as arguments, merges them over the defaults in that order (defaults, then `vim.g.aineo`, then `setup` — the later, explicit one wins), checks every value with `vim.validate(name, value, validator)` — a wrong type raising an error that names the key's full path (`claude.cmd`, not `cmd`) — and returns the configuration together with the list of unknown keys (the orchestrator's reading: returned, not raised, so a later health check can report them; no component row names that report yet). The v1 settings, from **D13**:

  | key | type | default |
  |---|---|---|
  | `prefix` | string, or `false` to map nothing (C1: "configurable or off") | `"\\"` (one backslash) |
  | `autostart` | boolean | `true` |
  | `claude.cmd` | list of strings, at least one (the orchestrator's reading: an empty list names no command) | `{ "claude" }` |
  | `layout.report_height` | number strictly between 0 and 1 | `2/3` |

  One test each: the defaults; a `vim.g.aineo` value overriding them; `setup` over `vim.g.aineo`; each key's wrong type, named by its path; `prefix = false` accepted; an unknown key returned; `report_height` refused at exactly 0, at exactly 1, and outside the range.

### Baseline

No Lua suite exists. `.claude/hooks/test-hooks.sh`: **78 passed, exit status 0**, run on a checkout at `origin/dev` = `17b8edffcadf7b4ca92ec0679aabe0344256ab30` whose `.claude/hooks/` and `.claude/settings.json` show no difference from `origin/dev` (`evidence/baseline.txt`).

### Facts, checked against `origin/dev`

Paths under `evidence/` are in `knowledge-vault/Implementation/Waves/00001-tooling/`.

- `origin/dev` is `17b8edf`: the bootstrap, the v1 plan (#2) and the wave-1 agent configuration (#1). Its top level is `.claude`, `.githooks`, `.gitignore`, `.worktreeinclude`, `CLAUDE.md`, `knowledge-vault` — no `lua/`, `plugin/`, `tests/`, `scripts/` or `Makefile` (`git ls-tree --name-only origin/dev`, in `evidence/baseline.txt`).
- `.gitignore` ignores `/deps/` and `/.tests/` — the root directories only (`git show origin/dev:.gitignore`).
- The `modularity` skill's §1 names the homes you create (`lua/aineo/config/`, `lua/aineo/init.lua`, `plugin/aineo.lua`, with `scripts/` and `tests/` — `tests/helpers/` for shared support — as non-home rows), its direction table (`aineo.config` requires no aineo home; `aineo` requires only `aineo.config`), and the interim deep-`require` check that stands in for a lint — run it before you report (`git show origin/dev:.claude/skills/modularity/SKILL.md`).
- The root `CLAUDE.md` › *Read this first* names the plan's D# and C# rows as the spec, Nvim ≥ 0.11, mini.test with the real Claude never in the suite (D10), and StyLua + selene (D12) (`git show origin/dev:CLAUDE.md`).
- On the host: Nvim 0.11.6, StyLua 2.5.2, selene 0.31.0 (`evidence/planning-probe.txt`).
- `.worktreeinclude` lists no file, and `prepare_project` in `.claude/scripts/prepare-worktree.sh` is empty: running the script validates the name and the worktree and does nothing else.
- This packet adds a dependency (mini.nvim, under the gitignored `/deps/`), so it runs alone in its wave. It installs into your worktree's `deps/` only — never into the main checkout's.

Read first: the plan's *Authority*, *Decisions & reasoning* (D1, D3, D4, D10, D12, D13), *Architecture* (C1, C3, C8) and *Implementation plan* (T1); `knowledge-vault/Projects/aineo.md`; the root `CLAUDE.md` › *Read this first*; `.claude/agents/neovim-lua-developer.md` › *What bites here* and *Tests*; the `modularity` skill's §1 and §4; mini.nvim's `TESTING.md` and `doc/mini-test.txt` at the tag you pin.

## Boundary

- **Branch:** `feature/t1-tooling` from `origin/dev`.
- **Model:** `opus` — every role in this project runs on Opus (D9).
- **Resources:** `impl_t1_tooling` — pass it to `.claude/scripts/prepare-worktree.sh`; no database exists in this project.
- **You may touch:** `Makefile`; `scripts/` (the minimal init and any runner script — tooling, not a home); `tests/` (suites and `tests/helpers/`); `plugin/aineo.lua`; `lua/aineo/init.lua`; `lua/aineo/config/`; `.stylua.toml`; the selene configuration and its Neovim standard-library file; in the plan note, **the Status cell of the T1 row only**, set to `in review — PR #<n>` when you open the pull request; and the session note below. No existing documentation describes what you change (there is no `README.md` or `doc/` on `dev`), so no document is invalidated — if you find one, it is inside your boundary and you report it.
- **You must not touch:** `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`; any other home under `lua/aineo/` (T3–T6's); `doc/` (T8's); the project note. The commands your make targets define go into the root `CLAUDE.md` through the orchestrator's `ai/` pass after you land: name them in your report's OPEN field, with anything `prepare_project` should do.
- **Session note:** `knowledge-vault/Sessions/<YYYY-MM-DD> — T1 tooling foundation.md`, the date read from `date` on the day you start; if that name exists, `knowledge-vault/Sessions/<YYYY-MM-DD>-b — T1 tooling foundation.md`.
- **Scratch prefix:** `t1-` on every file you write under the shared scratchpad, which the dispatch message names.
- Anything the task needs that lies outside the boundary is a **spec conflict** for your report, not a reason to widen it.

## What was decided already

- **StyLua + selene** — D12, the user's choice over StyLua alone and over deferring both.
- **mini.test; the real Claude never runs in the suite** — D10, agreed with the user.
- **The four settings, their types and defaults** — D13, the user's choice on 2026-09-23. A key D13 does not name is not added.

## Verification mutants — the orchestrator runs these on your final head

Each is a literal edit, applied and shown with `git diff HEAD` before the run. Write the tests that kill them, and name in your report, for each, the test that fails:

- **M1** — delete the one line that sets `XDG_STATE_HOME` (which is why B4 wants a single site) → the B4 isolation test fails, for the runner and for the child.
- **M2** — in `plugin/aineo.lua`, add `require('aineo')` at top level → the B7 test fails (and it cannot pass by never sourcing the file: its first assertion is `vim.g.loaded_aineo == true`).
- **M3** — in `lua/aineo/config/`, remove the range check on `layout.report_height` → the B9 out-of-range tests fail.

## Budget

Medium: five make targets (`deps`, `test`, `test_file`, `lint`, `format`), two skeleton files, and one home with its tests. If it is larger than that, stop at a green, reviewed, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t1-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure — including the B2 and B3 hang reproductions and their fixes, the B4 measurement of the plain invocation under `-i NONE`, the B5 planted-global refusal, and the M1–M3 killing tests.
