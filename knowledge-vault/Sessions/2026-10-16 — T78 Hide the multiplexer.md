# 2026-10-16 — T78 Hide the multiplexer

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`, on Sonnet)
**Branch:** `feature/t78-hide-multiplexer` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D73 (the activity indicator), C1, C3, C7
- `Implementation/Waves/00017-tab-activity/plan.md` — *Feasibility* (the multiplexer gate), U3, O12
- `Implementation/Waves/00017-tab-activity/evidence/w17-claude-title.txt` — B4, the multiplexer gate read from Claude Code 2.1.301
- [[Sessions/2026-10-16 — T76 Tab activity wiring]] — the indicator this makes work inside a multiplexer

Measured on Neovim 0.12.5, the host's newest release, and Claude Code 2.1.301's program (read, not run).

## The user's words and the rulings it rests on

After v0.2.41 the user, who runs Neovim inside tmux, saw no indicator. Asked how the indicator should learn a tab is busy, the user chose "Hide tmux from Claude (Recommended)": aineo removes `TMUX` (and `STY`, `ZELLIJ`) from the environment of the Claude Code it starts, so its title animates; its tmux-aware features are then off inside aineo. This is the user's decision (it answers wave 17's U3 as (c), correcting the earlier answer about the user's setup; the knowledge pass gives it a D-number).

Amendment to the dispatch, the user's words, 2026-10-16: "but this must be configurable in aineo, and must be enabled by default, and documented in the docs an README". Recorded as the user's decision. The repository has no README at its root, so none is written here: a README packet follows T78 (A383) and covers the setting.

The orchestrator's assumptions, never the user's decisions: **A379** (every start runs without `TMUX`, `TMUX_PANE`, `STY`, `ZELLIJ`; nothing else of the environment changes; only Claude Code's environment), **A380** (health), **A381** (help), **A382** (`claude.hide_multiplexer`, boolean, default `true`, validated like the other settings, `false` restores the editor's environment and the health warning).

## Task lines

- [X] T78 Hide the terminal multiplexer from the Claude Code aineo starts — done on `feature/t78-hide-multiplexer`: `claude.hide_multiplexer` (boolean, default `true`; `lua/aineo/config/init.lua`); `lua/aineo/claude/environment.lua` builds the job environment (`clear_env` with the editor's environment as Neovim gives a terminal job it, minus `TMUX`, `TMUX_PANE`, `STY`, `ZELLIJ`, plus `AINEO_CHILD=1`; the editor's environment unchanged with `false`), used by `launch()` for every start of Claude Code; the composition root passes the setting (`entry/tab.lua`); the Tab line section of `:checkhealth aineo` says aineo starts Claude Code without the variables and warns of them only with `false`; the help has the setting's entry, the Tab line paragraph and the *activity indicator* limits entry; the fake `claude` in the mode `busy-title` keeps its title still under `TMUX`, `STY` or `ZELLIJ` as Claude Code 2.1.301 does. The shell terminal and every other job keep the editor's environment. The README is not in this packet.

## The steps

1. *Setting*: `claude.hide_multiplexer`, default `true`, refused when not a boolean (`test_config.lua`).
2. *The environment of Claude Code's job*: hidden with `true`, the editor's with `false`, the rest of the environment passed (`test_claude.lua`).
3. *Fidelity*: a hidden job's whole environment equals a plain job's, the multiplexer variables apart, with and without true colour. `jobstart()` merges `env` into the editor's environment and cannot unset a variable; `clear_env` defines the whole environment, and Neovim 0.12.5 then no longer sets `TERM`, drops `COLORTERM` (no true colour), `VIM`, `VIMRUNTIME` and `NVIM_LISTEN_ADDRESS`, which `environment.lua` therefore does itself. Neovim still sets `NVIM` to its own address under `clear_env`, so the copy drops the inherited `NVIM` (measured with a probe; `NVIM_LOG_FILE` is kept by a plain job here, whatever `:help jobstart-env` says).
4. *The setting reaches every start* (`entry/tab.lua` › `claude_settings()`, all starts through `launch()`): a tab inside tmux shows ◒/◓ (`test_entry_tab_activity.lua`); with `false` it shows nothing.
5. *The shell pane keeps `TMUX`* (`test_shell.lua`).
6. *Health*: the new line, no multiplexer warning with `true`, the warning kept with `false`, `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` warned either way, the wrong value named.
7. *Help*: the setting's entry (`aineo-config-claude.hide_multiplexer`), the health paragraph, the limits entry.

**Decided inside the packet.**

- The variables hidden are `TMUX`, `TMUX_PANE`, `STY`, `ZELLIJ`. Read in Claude Code 2.1.301's program: its multiplexer test (`D_t`) reads `TMUX`, `ZELLIJ` and `STY`; `TMUX_PANE` is read only beside `TMUX` (the pane it names). No other variable of the three multiplexers was found. Its probe of the terminal (the reply to a version query) can also report one; no variable hides that, and Neovim's terminal answers none.
- Rejected: an `env -u` wrapper (changes the job's argv, visible to every process), and unsetting the variables in the editor around `jobstart()` (a user's `TermOpen` autocommand would run without them).
- The multiplexer warning's advice (A377's wording) is unchanged for `false`; it could also name the setting.

## What arrived green, and why

- *`keeps … false` (`gives Claude Code the editor's multiplexer variables when told to keep the multiplexer`)*: green by nature (the pre-T78 behaviour); killed by M4 and M10.
- *`the configuration … is reported wrong, naming claude.hide_multiplexer`* (`test_health.lua`): spent by step 1's setting (the health check reports the config home's refusal); no mutant breaks it separately, M15 breaks the validator in `test_config.lua`.
- *`still warns of CLAUDE_CODE_DISABLE_TERMINAL_TITLE while claude.hide_multiplexer is true`*, *`does not say aineo hides … false`*, the multiplexer rows of the warns case under `false`: green by nature before the health change; killed by M18, M16.
- *`leaves the editor's multiplexer variables to the shell`*: green by nature (the shell was never changed); killed by M21.
- *`names the setting that is malformed` rows for `hide_multiplexer`*: written after the validation line (`validate_settings()`), so green; killed by M9.

## Seen red

- `test_config.lua`: the defaults, `takes a setting …`, `merges …` and the refusal rows (8 failures) before the setting.
- `test_claude.lua`: *runs Claude Code without the multiplexer variables …* (`different values at key "STY", left = "set-in-the-editor", right = vim.NIL`); *gives the process the editor's server address as NVIM* after the first `clear_env` version kept the inherited `NVIM` (a failure that led to step 3's `NVIM` rule); the fidelity cases (`different values at key 6`, the fake's record path, until both runs shared one fake).
- `test_claude_busy.lua`: *keeps the title ✳ through a busy spell when TMUX is in its environment* (`left = "◐ Claude Code"`).
- `test_entry_tab_activity.lua`: with the composition root's line removed, all 27 cases failed (the start refused `settings.hide_multiplexer`); restored, the new cases pass.
- `test_health.lua`: the three *is said to be …* cases and *warns of no multiplexer variable …* (4).
- `test_doc.lua`: *has a tag for every … setting* and *has the tag aineo-config-claude.hide_multiplexer* (2).

## Mutants

Each was run as its literal edit, one at a time, from a pristine copy, against a copy of its test file narrowed to the cases that exercise it, on the final tree (`b683b81` and the session note). Every kill is an assertion failure (`Failed expectation`), none a crash.

| # | File: the literal edit | Killed by (failures) |
|---|---|---|
| M1 | `environment.lua`: `{ 'TMUX', 'TMUX_PANE', 'STY', 'ZELLIJ' }` → `{ 'TMUX', 'STY', 'ZELLIJ' }` | hide case, 2 fidelity cases (3) |
| M2 | `environment.lua`: `clear_env = true }` → `clear_env = false }` | 3 |
| M3 | `environment.lua`: `vim.tbl_extend('force', environment, CHILD_MARKER)` → `environment` | 3 |
| M4 | `environment.lua`: `if not hide_multiplexer then` → `if hide_multiplexer then` | 4 |
| M5 | `environment.lua`: the line `  environment.NVIM = nil` deleted | 2 fidelity cases and *… server address as NVIM* (3) |
| M6 | `environment.lua`: `environment.TERM = TERMINAL_JOB_TERM` → `environment.TERM = environment.TERM` | 2 fidelity cases |
| M7 | `environment.lua`: `editor.has_true_colour and 'truecolor' or nil` → `'truecolor'` | 1 (the case without true colour) |
| M8 | `environment.lua`: `{ 'NVIM_LISTEN_ADDRESS', 'VIM', 'VIMRUNTIME' }` → `{ 'NVIM_LISTEN_ADDRESS', 'VIMRUNTIME' }` | 2 |
| M9 | `claude/init.lua`: the `vim.validate('settings.hide_multiplexer', …)` line → empty | 2 (*names the setting that is malformed*) |
| M10 | `claude/init.lua`: `}, settings.hide_multiplexer)` → `}, true)` | *keeps … false* (1) |
| M10b | the same → `}, false)` | 3 |
| M11 | `claude/init.lua`: `has_true_colour = vim.o.termguicolors` → `has_true_colour = false` | 1 |
| M12 | `entry/tab.lua`: `hide_multiplexer = config.claude.hide_multiplexer,` → `hide_multiplexer = true,` | *… inside tmux and claude.hide_multiplexer is false* (1) |
| M13 | the same → `hide_multiplexer = false,` | *puts ◒ or ◓ … inside tmux* (1) |
| M14 | `config/init.lua`: the setting's `default = true` → `default = false` | 5 |
| M15 | `config/init.lua`: the setting's `validator = 'boolean'` → `validator = function() return true end` | 2 |
| M16 | `health.lua`: `local is_hiding = resolved_config ~= nil and resolved_config.claude.hide_multiplexer` → `local is_hiding = true` | 5 |
| M17 | the same → `local is_hiding = false` | 4 |
| M18 | `health.lua`: `local is_hidden = is_hiding and variable.is_hidden_by_aineo` → `local is_hidden = is_hiding` | 7 |
| M19 | `health.lua`: `is_hidden_by_aineo = true,` deleted from the `STY` entry | 1 |
| M19b | the same, `ZELLIJ` | 1 |
| M19c | the same, `TMUX` | 1 |
| M20 | `fake_claude.lua`: `runs_under_a_multiplexer() and { IDLE_TITLE }` → `false and { IDLE_TITLE }` | 1 |
| M20b | `fake_claude.lua`: `{ 'TMUX', 'STY', 'ZELLIJ' }` → `{ 'STY', 'ZELLIJ' }` | 1 |
| M21 | `shell/init.lua`: `env = CHILD_ENVIRONMENT })` → `env = CHILD_ENVIRONMENT, clear_env = true })` | *leaves the editor's multiplexer variables to the shell* (1) |

An earlier version of `environment.lua` set `NVIM` from the editor's address; its mutant (`NVIM` removed) survived, because Neovim sets `NVIM` itself under `clear_env` (a probe: the job got its own address with no `NVIM` in `env`), so that line was dropped.

## Verification

D30: the test files the packet touches on Neovim 0.12.5 and no whole suite. `make lint` clean. Files run on the final tree (`b683b81`): `test_config.lua` 52, `test_claude.lua` 123, `test_claude_busy.lua` 31, `test_entry_tab_activity.lua` 27, `test_shell.lua` 41, `test_health.lua` 138, `test_doc.lua` 54, `test_entry_tabs.lua` 38, `test_claude_attach.lua` 18, each with no failure. Files that start Claude Code through the changed `launch()`, run one commit earlier (the last commit changed only how `NVIM` is set), green: `test_claude_resume.lua` 62, `test_claude_switch.lua` 100, `test_claude_ready.lua` 12, `test_entry_terminal_pane.lua` 38, `test_entry_claude_resume.lua` 13, `test_plugin.lua` 5, `test_aineo.lua` 14. Every Claude Code start in the suite now goes through `clear_env`, since the stand-in settings carry `hide_multiplexer = true`; the orchestrator's whole run covers the rest.

## Spec conflicts

None. The brief said to keep `clear_env` inside `aineo.claude`; it is (`environment.lua`, required only by `claude/init.lua`).

## Open threads

- The README packet (A383) covers the setting.
- The multiplexer warning's advice could name `claude.hide_multiplexer`; left as A377 wrote it.
- `environment.lua` mirrors what Neovim 0.12.5 gives a terminal job; the fidelity test fails when a later Neovim changes that.
- Unmeasured: Claude Code's own terminal probe reporting a multiplexer through a reply Neovim's terminal does not give.

## Commits

Recorded after the merge.
