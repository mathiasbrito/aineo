# Neovim 0.12 hands a log file it could not open to its children in __NVIM_LOG_FILE_WANT

**Tags:** #neovim #neovim-0.12 #testing #isolation #trap #measured
**Discovered:** [[Sessions/2026-09-27 — T22 parallel runner]] (the brief review of PR #75, F1) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

Neovim 0.12.5 may be unable to open the `NVIM_LOG_FILE` it was given, because the file's directory does not exist or the path is a directory. It then does three things:
- it logs to `stdpath('state')/nvim.log` instead;
- it sets `NVIM_LOG_FILE` to that fallback;
- it exports `__NVIM_LOG_FILE_WANT`, holding the path it wanted.

Every Neovim started below it inherits both variables. At startup, 100 ms after `VimEnter`, each one says through `vim.notify()`:

```
log: "<wanted>" not accessible, logging to: "<its own>"
```

It says so even when it was given a log file of its own that opens fine: the check compares the inherited wanted path with the Neovim's own `NVIM_LOG_FILE`, not with whether that file opens.

0.11.6 falls back to `stdpath('state')/log` without a word and exports no such variable.

## Example

- **The brief review of PR #75** (T22's brief, at `d1b2331`; its code is `dev` `aaa326a`), 0.12.5, each test file run alone in a fresh `.tests/`.
  - `make` started the runner with `NVIM_LOG_FILE=$(TEST_HOME)/state/nvim/log`, whose directory a fresh checkout does not have. Every Neovim below it then printed the notice where a test read aineo's own message.
  - The fake `claude` is a Neovim too, so the notice also landed in Claude's terminal. Readiness and Send failed there.
  - In all, 73 cases in 8 files failed, and `tests/test_mcp_blocked_editor.lua` hung until the run's limit. The same files passed with the directory present, and on 0.11.6.
- **What T22 does** (the `Makefile`):
  - it makes the log directory before the runner starts (`mkdir -p '$(TEST_LOG_DIRECTORY)'`);
  - it empties the variable for the test recipes: `test test_file: override __NVIM_LOG_FILE_WANT :=`, with `export __NVIM_LOG_FILE_WANT` beside it (`5dd3928` on `dev`).
  - The `export` is needed because GNU Make 3.81 passes a recipe the command line's or `MAKEFLAGS`' value of a variable it does not export, whatever a target's `override` says. T22's re-measure measured that.
- **This pass, in bare Neovim** (2026-09-28, `probe-log-fallback.lua` in `Implementation/Waves/00006-fixes/evidence/learnings-probes.txt`). It was run with `NVIM_LOG_FILE=<scratch>/no-such-dir/log`, a directory that did not exist. Each child is `nvim --clean --headless --embed`, and its `:messages` were read 400 ms after it started:

  ```
  log: "<scratch>/no-such-dir/log" not accessible, logging to: "<scratch>/xdg-0.12.5/state/nvim/nvim.log"
  0.12.5
  parent: NVIM_LOG_FILE=<scratch>/xdg-0.12.5/state/nvim/nvim.log __NVIM_LOG_FILE_WANT=<scratch>/no-such-dir/log
  child, environment inherited: NVIM_LOG_FILE=<scratch>/xdg-0.12.5/state/nvim/nvim.log __NVIM_LOG_FILE_WANT=<scratch>/no-such-dir/log messages='log: "<scratch>/no-such-dir/log" not accessible, logging to: "<scratch>/xdg-0.12.5/state/nvim/nvim.log"'
  child, its own NVIM_LOG_FILE in a directory that exists: NVIM_LOG_FILE=<scratch>/child-log/log __NVIM_LOG_FILE_WANT=<scratch>/no-such-dir/log messages='log: "<scratch>/no-such-dir/log" not accessible, logging to: "<scratch>/child-log/log"'

  0.11.6+ge8b87a554f
  parent: NVIM_LOG_FILE=<scratch>/xdg-0.11.6/state/nvim/log __NVIM_LOG_FILE_WANT=unset
  child, environment inherited: NVIM_LOG_FILE=<scratch>/xdg-0.11.6/state/nvim/log __NVIM_LOG_FILE_WANT=unset messages=(none)
  child, its own NVIM_LOG_FILE in a directory that exists: NVIM_LOG_FILE=<scratch>/child-log/log __NVIM_LOG_FILE_WANT=unset messages=(none)
  ```

  The first line is the 0.12.5 parent's own notice, on its stderr.

**Why.** Read by this pass: the C source at both tags (fetched with `gh api`), and the Lua in the release's own runtime.
- **0.12.5's fallback.** `src/nvim/log.c` › `log_path_init()` at `v0.12.5` (l.63–109) handles a user-set `NVIM_LOG_FILE` that is empty, a directory or cannot be created:
  1. it sets `__NVIM_LOG_FILE_WANT` to that path;
  2. it falls back to `stdpath('state')/nvim.log`, then to `nvim.log` in the current directory, then to stderr;
  3. it sets `NVIM_LOG_FILE` to the fallback.
- **0.11.6's fallback.** At `v0.11.6` (l.66–100), the fallbacks are `stdpath('state')/log`, then `.nvimlog`, and no such variable is set.
- **The notice.** `runtime/lua/vim/_core/log.lua` › `check_log_file()` at 0.12.5 is called at `VimEnter` from `_core/defaults.lua` (l.556–565, "Warn if $NVIM_LOG_FILE or $XDG_STATE_HOME are inaccessible. #38039"). It returns in Ex mode, or when `__NVIM_LOG_FILE_WANT` is unset. Otherwise it warns, through `vim.defer_fn(…, 100)`, when the Neovim's own `NVIM_LOG_FILE` is empty or differs from the wanted path.

## Why it matters

This leaks past XDG isolation just as `NVIM_LOG_FILE` itself does ([[Learnings/NVIM_LOG_FILE leaks past XDG isolation]]). A harness that sets `NVIM_LOG_FILE` must:
- create its directory before the first Neovim starts;
- clear `__NVIM_LOG_FILE_WANT` for every Neovim it starts.

Otherwise every test that reads messages, or a terminal's screen, reads the notice.

**Limits:**
- T22's brief put the fallback "beside" the wanted file. That holds only when the wanted file sits in `stdpath('state')`, as the `Makefile`'s does.
- Measured on 0.11.6 and 0.12.5, macOS; 0.12.0–0.12.4 were not measured.
