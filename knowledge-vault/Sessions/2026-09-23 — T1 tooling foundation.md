# 2026-09-23 — T1 tooling foundation

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t1-tooling` · **Pull request:** #4

## Links

- **Project:** [[Projects/aineo]]
- **Plan:** [[Planning/aineo — v1 agent console]] — T1, C1, C8, D10, D12, D13
- **Wave:** [[Implementation/Waves/00001-tooling/plan]] · the brief `Implementation/Waves/00001-tooling/brief-t1-tooling.md` · its review `brief-review.md`

## Context

**Goal:** T1 lays the tooling every later packet stands on: the mini.test harness and its make targets, the suites' isolation from the developer's editor and Claude state, the `plugin/aineo.lua` and `lua/aineo/init.lua` skeletons, and `lua/aineo/config/` with `vim.g.aineo` validation.

## What was done

**Make targets.**

- `deps`: mini.nvim pinned by commit `1345d19`, which is tag v0.18.0.
- `test`: every `tests/**/test_*.lua`.
- `test_file FILE=<path>`: one file.
- `lint`: `stylua --check`, then `selene`.
- `format`: StyLua in place.

**Files.**

- `scripts/minimal_init.lua`: the init for the runner and for every child.
- `scripts/run_tests.lua`: the runner, under `nvim -l`.
- `plugin/aineo.lua`: a guard and nothing else.
- `lua/aineo/init.lua`: `setup()` and `setup_options()`.
- `lua/aineo/config/init.lua`: `resolve_config()`, pure.
- `.stylua.toml`, `selene.toml`, `neovim.yml`.
- Six test files and four helpers.

**Result.** The suite holds 59 cases, all passing. `make lint` is clean. The hooks suite reports 78 passed, as before.

## Why it is shaped this way

**The runner exits instead of hanging (B2, B3).** With mini.nvim v0.18.0, the invocation TESTING.md proposes never exits in four cases:

- a test file that fails to parse;
- a top-level `require` of a missing module;
- zero cases;
- `run_file` on a missing path.

Each was reproduced under a 10 s watchdog: exit status 142, killed by the watchdog. Under `nvim -l`, any Lua error ends Neovim with exit 1 and shada is off. The runner refuses zero collected cases, because under `-l` a run with nothing to test would otherwise end green. It waits for mini.test's scheduled queue with `vim.wait`. A spike measured that this wait carries cases that nest `vim.system():wait()` and a child Neovim.

**Isolation is set at one site, the Makefile (B4).** `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME` and `CLAUDE_CONFIG_DIR` are target-specific exports on `test test_file`, into `.tests/`. Why the Makefile:

- The minimal init runs too late: `'runtimepath'` and the log location are fixed before any init runs.
- `prepare_project` would leave `make test` unisolated outside a worktree.

Measured first, with `-i NONE`: the plain invocation resolves every stdpath under the developer's home, and puts `~/.config/nvim` and its `after/` on `'runtimepath'`. The developer's shada and log kept the same mtime and size through every run of this session.

**The harness tests run make from an empty directory.** Each target is run through `make -f <checkout>/Makefile` from `.tests/empty`:

- A runner that ignored `FILE` would collect nothing there, rather than start the suite inside itself.
- A hung run is stopped with its whole process group. `vim.system():wait(timeout)` kills only `make`, and the orphaned Neovim keeps the pipes open, so `wait` returns `nil`. This was learned from the first, invalid red.
- Every git the suites start runs without the developer's git configuration (`GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_NOSYSTEM=1`).

**`aineo.config` is pure (B9).** It is handed `vim.g.aineo` and the `setup()` options, so no module reads ambient state, per `modularity` §4. Resolution works setting by setting, in the order setup, then `vim.g.aineo`, then the default, and `false` counts as given. `vim.tbl_deep_extend` was rejected: an empty list overrides the default. Every value either source gives is checked, and an error names its full path. Unknown keys are returned, sorted, each once.

## Decisions & reasoning

- **The pin is a commit, not a tag,** so the tag cannot move under the suite. `make deps` checks the commit checked out, asking only that directory's own `.git`. A match reaches no remote; a changed pin fetches it.
- **StyLua `syntax = "Lua51"`,** so `goto` and other 5.2+ syntax fail `make lint`. Measured: `LuaJIT` syntax accepts `goto`. selene's standard is `lua51` plus the global `vim`, and nothing else.
- **A wrong `vim.g.aineo` value is refused even when `setup()` overrides it.** This is my reading of B9's "checks every value". The brief did not say which values count.
- **`require('aineo').setup_options()` is a public function.** It returns the options `setup()` recorded, so a composition root can hand them to `resolve_config()`. It widens the API beyond `setup()`, and T7 should confirm it or replace it.
- **Dropped unit, "a list replaces whole".** Nothing realistic fails it: per-setting resolution replaces a list whole, and so does `vim.tbl_deep_extend` for a non-empty list (measured).

## What arrived green, and what killed it

The runner-level account:

- **Exits 0 on a passing file:** infrastructure written ahead of the test. Killed by the recipe dropping `'$(FILE)'`.
- **Fails on a failing case:** mini's `1cquit`. Killed by `quit_on_finish = false`.
- **Missing module, missing path, no file named:** spent by the `-l` runner. Killed by the stock `-c … run_file` recipe.

The rest:

- **The runner's `'runtimepath'`:** spent by the `XDG_CONFIG_HOME` line, which kills it.
- **The child's stdpaths and `CLAUDE_CONFIG_DIR`:** spent by the exports. Killed by M1 and the other export deletions.
- **The child's `'runtimepath'`:** green by nature, through mini.test's `--clean`. Killed by a probe path added to the child's `'runtimepath'`; deleting `XDG_CONFIG_HOME` does not kill it.
- **`setup()` replacing without merging:** killed by an accumulating `tbl_deep_extend`.
- **Per-setting merge:** killed by picking one source whole.
- **`deps` reaching no remote:** killed by `if true` in the recipe.

The full literal mutant table is in PR #4. All 22 mutants were run on `f4a6e8b`. 21 were killed by assertions; the runner's time-limit branch survived. Measured in scratch with a 2 s limit and a stalled queue, that branch turns a false exit 0 into exit 1.

## Commits

*Recorded after the merge.*

## Open threads

- **For the `ai/` pass.**
  - The root `CLAUDE.md` gets the commands: `make deps`, `make test`, `make test_file FILE=<path>`, `make lint`, `make format`.
  - `prepare_project` needs no step: `make test` isolates itself and fetches the pin on first use.
  - `neovim-lua-developer.md` › *Tests* should say the isolation lives in the Makefile, not in `prepare_project`.
- **For T7.**
  - Who calls `resolve_config(vim.g.aineo, require('aineo').setup_options())`, and when. Nothing reads `vim.g.aineo` yet.
  - Whether an empty-string `prefix` is refused. D13 allows any string, and `''` would map the bare keys.
  - How a `vim.validate` error reaches the user.
- **For T8.** The unknown keys `resolve_config()` returns are for the health check to report.
- **Limit.** A test case that blocks inside its own `vim.wait` is not bounded by the runner's 30-minute limit. The limit bounds a stalled mini.test queue only.
