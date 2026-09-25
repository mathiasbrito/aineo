# NVIM_LOG_FILE leaks past XDG isolation

**Tags:** #testing #neovim #isolation #trap
**Discovered:** [[Sessions/2026-09-23 — T1 tooling foundation]]
**Applies to:** [[Projects/aineo]]

## The insight

Setting `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME` and `XDG_CACHE_HOME` does not fully isolate a test Neovim when the suite is started from inside another Neovim: Neovim exports `NVIM_LOG_FILE=<its stdpath('state')>/log` to every process it starts, and an inherited `NVIM_LOG_FILE` wins over the one a child would derive from its own `XDG_STATE_HOME`. So a suite run from `:terminal`, from `:!make test`, or from aineo's own Claude terminal would write its log lines into the developer's `~/.local/state/nvim/log` — measured with a stand-in path, never the developer's own log.

## Example

The attack review of PR #4 (T1) measured it: a scratch-isolated `nvim --headless --clean -i NONE` asked for `vim.fn.system({'env'})` printed `NVIM_LOG_FILE=<scratch>/xdg/state/nvim/log`; `NVIM_LOG_FILE=<stand-in> make test_file` with a case that provoked a warning wrote the warning into the stand-in. The suite's isolation test could not see it from a plain shell, where the runner derives the path itself. The fix — the `Makefile` setting `NVIM_LOG_FILE` under `.tests/` for `test` and `test_file` (`Makefile:41`, added in `d10b6a5`) — was the reviewer's, measured, and T1's fix round adopted it red-first (T1's session note, *Isolation*).

## Why it matters

Isolation is the list of every variable that carries state, not the four `XDG_*` names: here `NVIM_LOG_FILE`, `CLAUDE_CONFIG_DIR`, the parent's `CLAUDE*` session markers, and `NVIM`, `NVIM_APPNAME`, `MYVIMRC`, `VIMINIT` and `AI_AGENT`, which T1's correction keeps from the runner (`Makefile:49`). An isolation test run only from a plain shell cannot catch a leak that happens only under a parent editor; the pin sets the outside value and asserts it does not arrive. Still open at T1's merge: `VIMRUNTIME` from a parent Neovim (left alone, since unsetting it breaks development builds).
