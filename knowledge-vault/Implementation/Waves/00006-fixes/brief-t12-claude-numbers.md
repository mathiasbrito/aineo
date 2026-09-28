**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T12 | `\tcn` toggles the line numbers of Claude's window (D16), with its `:Aineo` subcommand, `<Plug>` mapping, health check and help | T8 | active |

It rests on:
- **D16** — "`\tcn` toggles the line numbers of Claude's window, with `:Aineo claude-numbers` and `<Plug>(aineo-claude-numbers)` beside it, as for every command (C1)";
- **C1** — the entry point: the prefix is mapped only where the user has not mapped it, configurable or off;
- **C2** — the layout;
- **C7** — the health check;
- **D13** — `prefix`.

### The behaviours — one test each, each seen red first

- **CN1 — hide.** With the layout open and line numbers shown in Claude's window (`'number'` or `'relativenumber'` on), `\tcn` in Normal mode turns both off in that window.
- **CN2 — show again.** Pressed again, `\tcn` restores the values that window had when they were hidden. A Claude window that never had line numbers gets `'number'`.
- **CN3 — only Claude's window.** No other window's options change. The current window, the cursor and the mode stay where they were.
- **CN4 — no Claude window.** When the layout has no Claude window — the layout is closed, or its Claude window was closed — the command changes nothing.
  - It notifies one warning of its own (`vim.log.levels.WARN`), starting `aineo: ` and naming why, and does not raise — as Send refuses (`aineo: nothing sent — …`).
  - `run()` reports only errors (`plugin/aineo.lua:201`), and it is reached by `start_up`, which you may not change. So the warning is the command's own.
- **CN4b — from another tab.** From a tab other than the layout's, `\tcn` toggles Claude's window in the layout's tab. It counts as "no Claude window" only when the layout has none.
- **CN5 — the three doors.**
  - `:Aineo claude-numbers` and `<Plug>(aineo-claude-numbers)` do what `\tcn` does.
  - `:Aineo` completion offers `claude-numbers`.
  - `:Aineo` without a known subcommand lists six: `USAGE` is built from `SUBCOMMANDS` (`plugin/aineo.lua:30`), and `tests/helpers/entry.lua:18` pins its text.
- **CN6 — the prefix rule.**
  - `<prefix>tcn` is mapped under the same rule as the other five keys: never over the user's own global mapping of that sequence.
  - It follows a changed `prefix`.
  - `prefix = false` maps nothing.
- **CN7 — health.** `:checkhealth aineo` checks `<prefix>tcn` as it checks the other keys.
  - `lua/aineo/health.lua`'s key table gains the key.
  - The test that compares it with `plugin/aineo.lua`'s mappings (`tests/test_health.lua:600`) stays green.
  - The per-key lists at lines 499–503, 615–619, 630–634, 758–762 and 816–820 gain a line, and the two counts at lines 562 and 597 go from 5 to 6.
- **CN8 — help.**
  - `doc/aineo.txt` documents the command, the `<Plug>` mapping and the key, with the tags the derived-tag test in `tests/test_doc.lua` requires: `:Aineo-claude-numbers`, `<Plug>(aineo-claude-numbers)` and `aineo-\tcn`.
  - These edits go **only inside** `*aineo-commands*`, `*aineo-mappings*` and `*aineo-keys*`.

**Where the window logic lives.** Finding Claude's window and changing its options belongs to the layout (C2). The layout exposes only `open`, `focus` and `input_buffer` today, so add a public function there. Do not reach into its tables from `plugin/aineo.lua` (`modularity`). The function's shape is yours under `tdd`.

### Facts, checked against `origin/dev` (`9af91a6`)

- **`plugin/aineo.lua`:**
  - `SUBCOMMANDS = { 'send', 'open', 'report', 'input', 'claude' }` (line 27);
  - `ACTIONS` (line 152) and `run(action)` (line 195);
  - `PREFIX_KEYS = { send = 's', open = 'o', report = 'r', input = 'i', claude = 'c' }` (line 220);
  - the prefix mapping builds `prefix .. PREFIX_KEYS[subcommand]` (line 247). Every key today is one character; `tcn` is the first of three;
  - `USAGE` is built from `SUBCOMMANDS` (line 30);
  - `:Aineo`'s description, `desc = 'aineo: send, open, report, input or claude'` (line 437), goes stale unless changed.
- **`tests/helpers/entry.lua:18`** pins `M.USAGE`, which `tests/test_entry.lua` asserts at lines 40, 55 and 65.
- **`tests/test_entry.lua:45`** pins completion to the five subcommands. Four case names say "five": lines 37, 44, 52 and 59.
- **`tests/test_entry_prefix.lua`** parametrizes its cases over `PREFIX_KEYS` at lines 7–13.
- **`tests/test_plugin.lua`'s pin at line 62**, after this packet, lists (sorted as the pin sorts): `'n <Plug>(aineo-claude)'`, `'n <Plug>(aineo-claude-numbers)'`, `'n <Plug>(aineo-input)'`, `'n <Plug>(aineo-open)'`, `'n <Plug>(aineo-report)'`, `'n <Plug>(aineo-send)'`, `'n \\c'`, `'n \\i'`, `'n \\o'`, `'n \\r'`, `'n \\s'`, `'n \\tcn'`. Its commands and autocommands are unchanged.
- **`lua/aineo/health.lua`:** its own `PREFIX_KEYS` at line 241.
- **`tests/test_health.lua`:** lists the five per-key lines in several cases, lines 499–503 and 615 among them. Each such list gains a sixth line.
- **`tests/test_plugin.lua` › *defines :Aineo, its <Plug> mappings, the prefix mappings and, once started, the StdinReadPost autocommand alone*** (line 62) counts every keymap `plugin/aineo.lua` defines. It gains `n <Plug>(aineo-claude-numbers)` and `n \tcn`. **That list is the only change to that file.** The pin *loads the configuration alone in a headless start* stays as it is.
- **`lua/aineo/layout/init.lua`:**
  - `---@alias aineo.layout.Role 'claude'|'report'|'input'` (line 16);
  - public `M.open`, `M.focus`, `M.input_buffer`; `role_of(window)` is internal (line 34).
- **Your Neovim config** (the user's, read-only on 2026-09-25) maps nothing under `\t`. Its `maplocalleader` is `\` (R3), which the health check already warns about.

### Baseline

**You are dispatched after T13 merges**, since T13 also changes `plugin/aineo.lua`, `lua/aineo/health.lua` and `tests/test_health.lua`. T13 makes the suite green on 0.12.5 and 0.11.6; its merge's counts are this packet's baseline. Before dispatch, the orchestrator re-checks every fact above against that `dev` and records any change as a dated amendment of this brief. Run the whole suite on both versions:
- the host's 0.12.5;
- `<scratchpad>/nvim-0.11.6/nvim-macos-arm64/bin/nvim` first on `PATH`.

Report both counts.

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › D16, C1, C2, C7, D13;
- `doc/aineo.txt` › `*aineo-commands*`, `*aineo-mappings*`, `*aineo-keys*`;
- `knowledge-vault/Sessions/2026-09-25 — T7 entry point.md` for how the prefix is mapped;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t12-claude-numbers` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t12_claude_numbers`.
- **You may touch:**
  - `plugin/aineo.lua`, its subcommand, action and key tables and `:Aineo`'s description (line 437) — not `start_up` or what it reaches, `run()` included;
  - `lua/aineo/layout/` and `tests/test_layout*.lua`, new cases only; every layout case that exists stays as it is and green;
  - `lua/aineo/health.lua`, its key table only, and `tests/test_health.lua`;
  - `tests/test_plugin.lua`, the one list named above;
  - `tests/test_entry_prefix.lua`, or a new `tests/test_entry_claude_numbers.lua`;
  - `tests/test_entry.lua`, its completion pin at line 45 and the four case names that say "five";
  - `tests/helpers/entry.lua`, `M.USAGE` only;
  - `doc/aineo.txt`, **only inside** `*aineo-commands*`, `*aineo-mappings*` and `*aineo-keys*`;
  - your session note.
  - The documentation this change invalidates: those three help sections. Correct them in the same change and say so in your report.
- **You must not touch:**
  - `lua/aineo/report/`, `tests/test_report_buffer.lua`, `tests/test_entry_report.lua`, `tests/test_report_colours.lua`, and `doc/aineo.txt` outside your section. T9 owns `*aineo-report*` in this wave.
  - `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/send/`.
  - `scripts/`, `tests/helpers/` other than `M.USAGE` in `entry.lua`, the `Makefile`.
  - The task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note instead.
  - The project note.
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your section** runs from its first line, `4. COMMANDS                                                   *aineo-commands*` (line 89 at `9af91a6`), to its last, `of both (|aineo-health|).` (line 177). That one range covers `*aineo-mappings*` and `Prefix keys ~`, which sits above `*aineo-keys*`.
  - **The other packet:** T9 edits from `8. THE AGENT REPORT                                             *aineo-report*` to `the working directory of its own moment.` (lines 253–280).
  - Every hunk stays inside your section.
  - **Before you push:** merge with T9's branch if it is still open — `git fetch origin && git merge-tree --write-tree <your head> origin/bugfix/t9-report-colours` (exit 0 and no conflict listed means clean). Then run `make test_file FILE=tests/test_doc.lua` on the merged `doc/aineo.txt`. Report both results.
- **Session note:** `knowledge-vault/Sessions/2026-09-25 — T12 Claude line numbers.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). The harness refuses writes outside your worktree. Prefix every file there with `t12-`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. You read and run its Neovim builds there, and write nothing. For 0.11.6, use the literal form `env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test`; the worktree guard refuses `PATH=…:$PATH make`.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- **The user's request** (2026-09-25): “A toogle for line number for the claude buffer "\tcn" as the command”. It is D16.
- **The orchestrator's readings, for the user to confirm.** Name each in your session note's *Readings for the MVP review*:
  - the subcommand and `<Plug>` names;
  - CN1's clearing of `'relativenumber'` together with `'number'`;
  - CN2's restoring of the earlier values;
  - CN4's warning of its own, at `WARN`, rather than an error through `run()`;
  - CN4b's toggle from another tab;
  - what `\o` does to a toggled window it rebuilds. The rebuilt window takes the user's defaults, unless you find a reason otherwise and report it.
- **Not in scope.** A Terminal-mode key to leave Claude's terminal was asked for and dropped by the user (2026-09-25: "No new key").

## Budget

Medium: one command through its three doors, a layout function, the health key and the help. If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t12-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.

## Amendment — 2026-09-27, against `dev` once PR #73 (T19) merges

This section amends the brief above. Where they differ, this section wins. Every fact above was checked on `9af91a6` (2026-09-25). Since then T13, T9, T14, T15, T16, T11, T10, T20, T18, T21, T17 and T19 have merged, and D26 has changed how the suite runs. The facts below were re-read on the tree PR #73 lands, `acc62d0` (`git merge-tree --write-tree origin/dev 6d5a013`), whose code is PR #73's head's.

### Facts, re-read

- **`plugin/aineo.lua`** (533 lines):
  - `SUBCOMMANDS` is at line 27 and `USAGE` at 30, unchanged;
  - `ACTIONS` is at line 232 (was 152), and `run(action)` at 290, whose `ERROR` notify is at 296 (was 195 and 201);
  - `PREFIX_KEYS` is at line 315 (was 220);
  - the prefix mapping builds `prefix .. PREFIX_KEYS[subcommand]` at line 342 (was 247);
  - `start_up` is at line 474;
  - `:Aineo`'s `desc = 'aineo: send, open, report, input or claude'` is at line 532 (was 437).
- **`tests/test_entry.lua`:** the four case names that say "five" are at lines 38, 45, 53 and 60 (were 37, 44, 52 and 59). The completion pin is at 46 (was 45).
- **`tests/test_entry.lua`** asserts `entry.USAGE` at lines 41, 56 and 66 (were 40, 55 and 65).
- **`tests/helpers/entry.lua:18`** `M.USAGE`, and **`tests/test_entry_prefix.lua`**'s `PREFIX_KEYS` at lines 7–13: unchanged.
- **`tests/test_plugin.lua`:** the pin is still at line 62; `'n <Plug>(aineo-claude)'` is at line 71.
- **`lua/aineo/health.lua`:** its key table `PREFIX_KEYS` is at line 253, a list of `{ key = 's', subcommand = 'send' }` records (was line 241, already the same list). T12's key is the first longer than one character: check every reader of `key` there.
  - `PREFIX_KEYS_PENDING` (line 447) says, while aineo's startup record says the keys are not mapped yet, why. Its text says "the prefix keys", and stays true.
- **`tests/test_health.lua`:**
  - the per-key lists are at lines 499–503, 615–619, 630–634, 758–762 and 816–820. The file is unchanged since `9af91a6`: the amendment's first draft said 816–820 no longer existed, and was wrong;
  - the two counts of 5 are at lines 562 and 597;
  - nine reads of the leader warning as line `[6]` become `[7]`: lines 513, 530, 546, 579, 650, 670, 834, 849 and 860;
  - the comparison at line 600, and line 741's check of the first line, stay green.
  - With the key tables changed alone, 16 of the file's 78 cases fail on 0.12.5, as the brief review measured, not the 7 the brief names. CN7's list above is read with these.
- **`lua/aineo/layout/`:**
  - `init.lua` (854 lines): `---@alias aineo.layout.Role 'claude'|'report'|'input'` at line 16, and `role_of(window)` at 37;
  - the public functions are `M.open` (786), `M.focus` (818), `M.follow_claude_terminal` (842, T19) and `M.input_buffer` (850);
  - `columns.lua` (T3) reads a tab's window tree;
  - the file column (C9, D5's "middle column", into which T17 opens paths) is a window of the layout's tab with no role. CN3's "no other window's options change" covers it.
- **`doc/aineo.txt`:** your section runs from `4. COMMANDS … *aineo-commands*` (line 168; was 89) to `of both (|aineo-health|).` (line 274; was 177). It holds:
  - `*aineo-mappings*` at line 221;
  - `Prefix keys ~` at 242;
  - `*aineo-keys*` at 243.

  Inside it, T19's sentence "Of the actions, only `open` restarts an exited Claude Code" (line 213) must stay true.

### What changed around the behaviours

- **A new terminal in Claude's window.** Claude's window gets a new terminal buffer without `\tcn` being pressed again:
  - `\o` restarts an exited Claude Code, its new terminal taking the old one's place in Claude's window;
  - T19's fallback replaces a terminal whose resume found no conversation (`follow_claude_terminal()`);
  - `\c`, `\r` and `\i` start one only once the terminal was wiped, into a Claude window Neovim could not close (help lines 204–215).
- **No `TermOpen` autocommand reaches Claude's window.** aineo starts each terminal in a hidden buffer (`nvim_buf_call()` around `jobstart()`). So neither Neovim's own `nvim.terminal` handler, which turns the numbers off, nor a user's `setlocal nonumber` acts there. The brief review measured it on both versions.
- **CN9 — the toggle stays as the user left it (D27, the user's decision of 2026-09-27).** aineo remembers the toggle for as long as the editor runs, and applies it to every new Claude terminal in that window, by each of the three routes above. The user presses `\tcn` once per editor session.
  - Set the options window-locally, as `:setlocal` does and as the layout already does for `'wrap'` (T16). A file opened from Claude's window then keeps the user's own numbers (CN3). As `:set` does, every buffer that later entered the window, and every file opened from it into the file column, would show them hidden too (the brief review).
  - The layout applies the remembered state wherever it puts a new terminal in Claude's window. Pin each of the three routes by its real path, in `tests/test_entry_claude_numbers.lua`:
    - `\o` after the fake exits;
    - T19's fallback;
    - a wiped terminal, then `\c`.
  - Also pin that a file opened from Claude's window after `\tcn` shows the user's numbers (CN3).
- **`\o`'s rebuilt window.** The brief's reading, "the rebuilt window takes the user's defaults", was wrong: Neovim gives a rebuilt Claude window the options the terminal last had, so its numbers stay hidden (the brief review measured it). By D27 that is the behaviour: pin it.
- **The layout's tab.** T14 and T21 changed `open()` and `focus()`. The toggle sets the options on the layout's Claude window from any tab. It goes through neither `M.open()`, which moves to the layout's tab and rebuilds closed windows, nor `M.focus()`, which moves the cursor. CN4b is re-measured on today's code.
- **CN4, one more case.** A Claude window left on an empty buffer after its terminal was wiped counts as no Claude window, as `focus()` counts it. Pin it.
- **One more reading:** a user's own mapping of `\t` or `\tc` now waits for `'timeoutlen'`. The help says so beside the `\sa` example.

### Boundary, amended

- **Branch:** `feature/t12-claude-numbers` from `origin/dev` after PR #73 merges.
- **Session note:** `knowledge-vault/Sessions/<the day you are dispatched> — T12 Claude line numbers.md`, not the 2026-09-25 name above.
- **Builds:** `<builds>/nvim-0.11.6/nvim-macos-arm64/bin/nvim` is in the orchestrator's scratch directory, which your dispatch message names. The *Baseline*'s `<scratchpad>/nvim-0.11.6/…` above is wrong.
- **The help is yours whole.** T9 merged long ago (PR #30), and no packet running beside you edits `doc/aineo.txt`: T22 and T23's boundaries exclude it. The merge check against `bugfix/t9-report-colours` is dropped. The documentation this change invalidates includes, beyond the three sections:
  - the introduction's key list (lines 25–28);
  - inside the section, line 171 ("five actions"), lines 244–245 ("one key") and lines 258–263.

  CN8's three tags work: `test_doc.lua` passed 36 of 36 with them added (the brief review).
- **Packets beside you,** all disjoint from your files by rule 2:
  - T22, the parallel test runner: `scripts/`, the `Makefile`, `tests/test_runner*.lua`, `tests/test_isolation.lua`, `tests/helpers/make.lua`, `tests/helpers/fixture.lua`;
  - T23, the git home: `lua/aineo/git/`, `tests/test_git_*.lua`, `tests/helpers/git_repo.lua`.
- **Fixture names:** give every fixture your cases make (`fixture.directory('…')`, `claude_session.fake('…')`) a name no other test file uses, prefixed `claude-numbers-`. Once T22 lands, files run side by side over one `.tests/fixtures/`.
- **How you run the suite (D26, the root `CLAUDE.md`):**
  - run the test files your change touches while you work;
  - a mutant runs on its narrowed group, then on the test files that exercise the code it breaks, and on the whole suite only if it survives those;
  - run the whole suite once, on both versions, on the tree you push.
- **Before your first run,** `mkdir -p .tests/state/nvim`. On 0.12.5 a fresh `.tests/` fails readiness and message cases without it, until T22 lands (measured by T22's brief review at `aaa326a`).
- **"Your Neovim config maps nothing under `\t`"** (the brief's *Facts*) was read on 2026-09-25 and not re-checked.

### Baseline, amended

`dev` `384c084`, where PR #73 merged (2026-09-27), whose code is the tree `acc62d0` the orchestrator's verification of PR #73 measured: 1227 cases on both versions:
- 0.12.5: `Fails (0)`, 869 s; the load averages at the run's end were 38, 75 and 83.
- 0.11.6: `Fails (1)`, 890 s, at load 131. The one failure is `tests/test_report_paths.lua` › *the file checks* › *of a line of distinct paths take at most the time limit, on arrival and on :edit*: `arrival = "3.7 s"`. That is T17's timing case, and T19 does not touch it. It fails intermittently on 0.11.6: the brief review saw it fail alone at load 29 (3.6 s) and pass five times at 38–48. If it fails in your run:
  - re-run its file alone, `env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test_file FILE=tests/test_report_paths.lua`, up to three times;
  - report each result with `sysctl -n vm.loadavg` before and after.

  It is not yours to change, and it does not hold your push.
