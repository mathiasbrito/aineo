**Your role: implement.** A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md` — you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the aineo v1 plan: T3, the layout. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*:

> T3 — Layout (C2) and the file column with its redirect (C9)

It rests on: **C2** (the three windows, widths per D4/D6, all three pinned against resizing, `\o` restores it), **C9** (the file column and its `BufWinEnter` redirect; `:q` in it returns to three windows), **D4** (Claude 50 % left; Report about 2/3 over Input about 1/3 on the right; the startup empty buffer becomes Input), **D5**, **D6** (equal thirds with a file column), **D7** (a file opened from an aineo window is redirected, the aineo window keeps its buffer), **D13** (`layout.report_height`), **F3** and **A5** (`'winfixbuf'` refuses where D7 redirects). Read those rows in the plan, not this summary of them.

### What the layout is handed, and what it owns — fixed in this wave's three briefs

- The **Claude terminal buffer** belongs to `aineo.claude` (T4, this wave) and the **Report buffer** to `aineo.report` (T5, this wave). The layout may `require` only `aineo.config` (the `modularity` direction table), so it **receives** those two buffers from its caller — the composition root, wired in T7 — and shows them; it never creates, writes or deletes them. Your tests hand it stand-ins: a terminal buffer running a harmless command for Claude's, a **named** scratch buffer for the Report's (T5's Report buffer carries a name from creation — see below).
- The **Input buffer** is the layout's own — T6 (send) will read it through the layout's entry point. It is not a file (`'buftype'` `nofile`, so the redirect never takes it for one), it is kept when hidden, and **it carries a name from the moment it becomes Input** — a name that is not a file path, such as `aineo://input`. *Measured by the brief review (Nvim 0.11.6):* `:edit <file>` from a window showing an **unnamed, empty** buffer reuses that buffer — `'buftype'` `nofile`, listed or not, `'modifiable'` on or off — so an empty, unnamed Input (or Report) would become the user's file; a named scratch buffer is not reused. The Report buffer T5 hands over is named for the same reason.
- "Report read-only to the user" (C2) is a property of the Report buffer, so it is T5's; nothing in this packet sets it.

### The behaviours — the orchestrator's reading of T3, one test each; the seams are yours

Geometry is asserted with `nvim_win_get_position`, `nvim_win_get_width` and `nvim_win_get_height` in a child Neovim of a fixed size, with the tolerance the separators and status lines cost stated once in the test.

- **L1 Open.** Opening the layout in a tab holding one window gives three windows: Claude's buffer on the left, half the columns (D4); on the right the Report above the Input, the Report taking `layout.report_height` of the right column's height (D13, default 2/3). The cursor ends in the Input window (the orchestrator's reading: the user types there first).
- **L2 The startup buffer becomes Input (D4).** When the current window shows the unnamed, empty, unmodified buffer Neovim starts with, that very buffer becomes Input — named as above, with no empty buffer left behind in the buffer list. Otherwise a new Input buffer is created. Test: `:edit <file>` in the Input window while Input is **empty** leaves Input's number, name and `'buftype'` intact, and the file goes to the file column (L7).
- **L3 Other windows.** Opening in a tab with more windows leaves three windows in that tab (plus the file column of L7 when the current window showed a file); the buffers of the windows it closed stay loaded — the orchestrator's reading; no row decides where the layout opens.
- **L4 Pinned (C2).** After `:wincmd =`, the three windows keep their widths and heights; and after a window in the tab is split and closed, the layout puts its sizes back. *Measured by the brief review* in a mini.test child (80×24, all three windows with `'winfixwidth'` and `'winfixheight'`): `:wincmd =` kept every size, but `:split` then `:close` in Input took the Report from 14 to 10 rows, `:vsplit` then `:close` in Input took Claude from 40 to 20 columns, and `:topleft vnew` then `:close` took Claude to 61 — **the options alone do not hold C2's pin**, so the layout re-applies its sizes when a window in its tab is closed (the orchestrator's reading: `WinClosed`, or whatever event you measure to fire). Tests: `:wincmd =`; `:split`/`:close` in Input; `:vsplit`/`:close` in Input; with the file column open (D6), `:vertical botright new`/`:close`.
- **L5 Restore (`\o`).** Opening again while the layout is open creates no window and puts back D4's proportions after the user resized one; after one of the three windows was closed, opening again brings it back with its buffer.
- **L6 Resize.** After the editor's size changes (`VimResized`), the proportions of D4 (or D6 with a file column) are re-applied — the orchestrator's reading: a pinned window would otherwise keep its old width.
- **L7 The redirect (C9, D7).** A buffer whose `'buftype'` is empty — a file — shown in any of the three aineo windows (`:edit`, `:buffer`, a quickfix jump) is moved to the **file column**, created between Claude's column and the right column on first use; the aineo window gets its own buffer back, the same buffer number with its content intact; the cursor ends in the file column. One test per aineo window, Claude's terminal window included.
- **L8 Equal thirds (D6).** With the file column open, Claude's column, the file column and the right column each take a third of the columns; the Report and Input keep their split of the right column.
- **L9 Reuse.** A second file opened from an aineo window goes to the existing file column; no fourth column appears. A file opened from inside the file column stays there.
- **L10 Closing the file column (C9).** `:q` in the file column's last window returns to three windows at D4's proportions.
- **L11 Not files.** A buffer with a non-empty `'buftype'` (help, a terminal, a scratch buffer) shown in an aineo window is left to Neovim — the orchestrator's reading, recorded as a limit for the MVP review.
- **L12 Focus.** The layout's entry point moves the cursor to the Claude, Report or Input window — what `\c`, `\r` and `\i` will call (T7) — reopening the layout first when that window is gone (the orchestrator's reading).
- **L13 Inert when closed.** With no layout open, opening a file anywhere redirects nothing.

### Facts, checked against `origin/dev`

- `origin/dev` is `798275d`: wave 1 landed — T1 (PR #4, rebased as `5edf69f` … `7284c00`) and the wave-1 `ai/` pass (PR #5: `12353b2`, `83c263e`, `798275d`). Its top level: `.claude`, `.githooks`, `.gitignore`, `.stylua.toml`, `.worktreeinclude`, `CLAUDE.md`, `Makefile`, `knowledge-vault`, `lua`, `neovim.yml`, `plugin`, `scripts`, `selene.toml`, `tests` (`git ls-tree --name-only origin/dev`). Under `lua/aineo/`: `init.lua` and `config/` only.
- **The suite** (root `CLAUDE.md` › *Read this first*): `make deps`, `make test`, `make test_file FILE=<path>`, `make lint`, `make format`. `make test` collects every `tests/**/test_*.lua` — a new test file needs no registration — and isolates every Neovim it starts, the runner included, under the checkout's `.tests/` (`XDG_*_HOME`, `CLAUDE_CONFIG_DIR`, `NVIM_LOG_FILE`; `stdpath('state')` is `.tests/state/nvim`). The runner ends a run at 16 minutes (`AINEO_TEST_RUN_LIMIT_MS`); the whole suite took 87, 88 and 87 s in the T1 correction's three runs at `5b323d8`, and 85 s in the brief review's run at `798275d` (this host).
- **Ambient reads enter at the composition root or through an injected dependency** (`neovim-lua-developer.md` › *What bites here*): the clock, the working directory, `stdpath()`, `v:progpath`, `vim.g` — a home that needs one takes it as a parameter or behind a function its caller can replace in a test, and says which in its report.
- **Helpers** are loaded with `dofile('tests/helpers/<name>.lua')` (`tests/test_plugin.lua:2`). `child.lua`'s `restart(child, extra_args)` (re)starts a child from `MiniTest.new_child_neovim()` with mini.test's own start arguments (`--clean`, headless, listening) and the suites' minimal init, so the child sources `plugin/` as a user's editor would; `fixture.lua` makes files under `.tests/fixtures/` (`directory(name)`, `write(name, lines)`); `make.lua` runs a Makefile target; `git.lua` runs git hermetically. T1's helpers are not yours to edit; add your own beside them.
- **The configuration home** `aineo.config` (`lua/aineo/config/init.lua`): `resolve_config(global_settings, setup_options)` returns the resolved table — `config.prefix`, `config.autostart`, `config.claude.cmd`, `config.layout.report_height` — and the unknown keys; `record_setup_options()` / `recorded_setup_options()` keep what `setup()` was given. Nothing calls `resolve_config` at startup yet: the composition root does, in T7, and hands each home the values it needs.
- The `modularity` skill's interim deep-`require` check — `grep -rnE "require\(['\"]aineo\.[a-z_]+\." lua plugin tests scripts` — prints nothing on `origin/dev`. Wave 2 is the first with homes of several files, and the check also prints a home's requires of **its own** files, which are allowed: a file inside `lua/aineo/<home>/` may require `aineo.<home>.<file>`; nothing outside that home may — not another home, not `plugin/`, `scripts/` or `tests/`, which use `require('aineo.<home>')` (the modularity skill §1 and §2; `neovim-lua-developer.md` › *What bites here*). Run it before you report and list every line it prints, each marked as a require inside its own home — any other line is a violation. The brief review of this wave measured the check flagging intra-home requires.

- `lua/aineo/layout/` does not exist on `origin/dev`; the `modularity` skill's §1 names it the home of C2 and C9, and its direction table lets `aineo.layout` require `aineo.config` only.
- F3, re-read by the records review of #2: `'winfixbuf'` makes `:edit` fail with E1513 rather than redirecting — hence the redirect (D7, A5).
- The user's own editor loads aineo from a clone of `dev` (`Projects/aineo.md` › *Environment & setup*): nothing in this packet may run at startup — the layout opens only when called (T7 calls it).

### Baseline

`make test`: **111 cases, `Fails (0)`, exit 0** — measured by the orchestrator on 2026-09-24 at `5b323d8`, PR #4's final head, which is code-identical to `798275d` (`git diff --stat 5b323d8 798275d -- lua plugin scripts tests Makefile neovim.yml selene.toml .stylua.toml` prints nothing). `.claude/hooks/test-hooks.sh`: **78 passed, exit 0**, at `798275d`, 2026-09-24 05:47 CEST. Both in `evidence/baseline.txt`.


Read first: the plan's *Authority*, *Decisions & reasoning* (D4–D7, D13), *Architecture* (C2, C9), *Alternatives rejected* (A5), *Accepted trade-offs*; `knowledge-vault/Projects/aineo.md`; the `modularity` skill §1, §2 and §4; `.claude/agents/neovim-lua-developer.md` › *What bites here* and *Tests*; `:h BufWinEnter`, `:h 'winfixwidth'`, `:h 'winfixheight'`, `:h 'buftype'`, `:h VimResized` in Nvim 0.11.6.

## Boundary

- **Branch:** `feature/t3-layout` from `origin/dev`.
- **Model:** `opus` — every role in this project runs on Opus (D9).
- **Resources:** `impl_t3_layout` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/layout/`; `tests/test_layout*.lua`; new files under `tests/helpers/` whose names begin with `layout`; and the session note below. No existing document describes the layout.
- **You must not touch:** the other homes — `lua/aineo/claude/` (T4, this wave), `lua/aineo/mcp/` and `lua/aineo/report/` (T5, this wave), `lua/aineo/send/`, `lua/aineo/init.lua`, `lua/aineo/config/`, `plugin/aineo.lua`; T1's existing files under `tests/helpers/`, `scripts/` and the `Makefile` (a need there is a spec conflict for your report); the plan note (**this wave holds its task marks** — write a `## Task lines` section in your session note instead); the project note; and never `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude` or `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/<YYYY-MM-DD> — T3 layout.md`, the date read from `date` on the day you start.
- **Scratch prefix:** `t3-` on every file you write under the shared scratchpad.
- Anything the task needs that lies outside the boundary is a **spec conflict** for your report, not a reason to widen it.

## What was decided already

- **Layout A, split vertically between the terminal and the Report/Input column** — D4, the user's choice.
- **Files in a middle column, not a new tab; equal thirds; redirect, not refuse** — D5, D6, D7, the user's choices.

## Verification mutants — the orchestrator runs these on your final head

Each is a literal edit, applied and shown with `git diff HEAD` before the run. Write the tests that kill them, and name in your report, for each, the test that fails:

- **M10** — disable the re-application of the layout's sizes when a window closes (wherever you put it) → the L4 split-and-close tests fail. (The brief review measured that removing `'winfixwidth'` from Claude's window alone is not separated from the pinned layout by `:wincmd =` in D4, where the two columns are already equal.)
- **M11** — in the redirect, leave the file in the aineo window (skip giving the aineo window its buffer back) → the L7 tests fail.
- **M12** — create a new file column on every redirect instead of reusing the open one → the L9 test fails.

## Budget

Medium to large: one home — the three-window layout and its restore, and the file column with its redirect. If it is larger than that, stop at a green, reviewed, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t3-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure — including the geometry tolerance and why, and the M10–M12 killing tests.
