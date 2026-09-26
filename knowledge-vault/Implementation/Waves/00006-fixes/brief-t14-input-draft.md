**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T14 | Input keeps unsent text as a draft (D17): saved per working directory beside the Reports shortly after each change and at quit, restored into an empty Input when aineo opens there, cleared with Input when Send clears it | T8 | active |

It rests on:
- **D17** — the user's decision of 2026-09-25, below;
- **C11** — the draft home, new in this packet;
- **C2** — the layout, whose Input is a scratch buffer;
- **C4** — Send clears Input;
- **C6** — the Reports are kept per working directory under `stdpath('state')`.

### The problem, measured

Input is a `nofile` scratch buffer (`lua/aineo/layout/init.lua`, `make_scratch()`), and Neovim never counts such a buffer as unsaved. Measured on Neovim 0.12.5 and 0.11.6 (`evidence/nofile-quit.txt`):
- a `nofile` buffer holding text quits with exit 0, and the text is gone;
- a file buffer gives `E37: No write since last change`.

### The behaviours

ID1 to ID7 get one test each, seen red first. ID8 is an invariant.

- **ID1 — saved shortly after each change.**
  - A change to Input's text is written to the draft within a short delay. Choose the delay and state it.
  - **An Input that becomes empty empties the draft at once**, with no delay, the way Send leaves it.
  - Changes are seen through `nvim_buf_attach`'s `on_lines`. The brief review measured `TextChanged` firing 0 times, and `on_lines` once, for an API change to a buffer that is not current — which is what Send makes.
- **ID2 — a pending change is saved at quit, and nothing else.**
  - At quit, a change not yet saved (one inside the delay) is saved. Nothing else is written.
  - **A restore is not a change.**
  - So an editor that quits later never writes back an older text, and a text already sent never comes back (D17: the last change wins).
  - The quit save never makes `:qa` refuse and never raises. It writes at most one file.
- **ID3 — restored into a new or emptied Input, never over text.** The draft is restored only into an Input it has not been handed before, or one whose text was dropped without a change. That means the first time the layout opens in this editor, or after the Input buffer was wiped or deleted (`:bdelete` drops the text with no `on_lines`, measured by the brief review). It is restored only when that Input is empty.
  - So `\s` followed within the delay by `\o`, `\i`, `\c` or `\r` restores nothing.
  - An Input that holds text is never overwritten.
- **ID4 — cleared with Input.**
  - When Send clears Input, the draft is cleared at once (ID1).
  - The test sends through `plugin/aineo.lua`'s `:Aineo send` from **another window**, since Send changes a buffer that is not current. It reads the draft file **before** any quit.
  - `tests/helpers/send.lua` opens the layout directly, bypassing `plugin/aineo.lua`, so it cannot drive this test.
  - No change to the Send home is needed.
- **ID5 — where and how it is written.**
  - The draft is kept under `stdpath('state')`, beside the Reports (C6), keyed by the same working directory: `give_report_environment()` (`plugin/aineo.lua:56–70`) takes `vim.fn.getcwd()` at line 67, once. Never in the working directory.
  - Follow `lua/aineo/report/records.lua`'s three measured patterns:
    - a temporary file unique to the editor, `('%s.%d.cut'):format(target, vim.uv.os_getpid())`, renamed over the target, and following a symlink through `fs_realpath` (lines 99–116);
    - `0600` on every file it creates (`OWNER_ONLY`, lines 13–15 and 79). A draft is the user's unsent text verbatim;
    - `make_directory()` (lines 133–154), which retries a `mkdir()` another editor raced.
  - **Copy the patterns, do not import them:** the report home is outside your boundary and its records are internal to it. Name that as a reading.
  - "A crash mid-write leaves the previous draft or the new one" is shown red only through an injected write failure. So the draft home takes its file writes as a declared dependency, and the test makes one fail after truncating.
- **ID6 — two editors, one folder.** Two editors in one working directory share one draft, and the last change wins. With ID2 and a temporary name unique to each editor, nothing is torn, and no rename fails spuriously (the brief review measured a shared temporary name leaving `""`, then `ENOENT`). Record the sharing in the help's text.
- **ID7 — failures never raise.** A draft that cannot be read or written gives a warning at `WARN` starting `aineo: `, at most once per editor for reading and once for writing. The draft never raises: not into the user's typing, not out of `open()` or `focus()`, and not from a quit handler.
  - An error raised out of `open()` reaches `run()`, which reports it at `ERROR` and, on the autostart, records `open-failed` (`plugin/aineo.lua:195–203` and 353–358), although the layout opened.
  - An error or an `ERROR` notification at exit holds Neovim at a hit-enter prompt: `getout()`, `src/nvim/main.c:855–859` at v0.12.5 and 797–801 at v0.11.6, read by the brief review.
- **ID8 — nothing at startup (an invariant).** Loading aineo loads no draft module and adds no autocommand. The frozen pins in `tests/test_plugin.lua` stay as they are and green. The brief review killed both startup mutants by assertion with those pins, so show that they still kill yours.

### The quit path, measured by the brief review

- **aineo's stop comes first, and can wait.** `aineo.claude`'s stop is a `VimLeavePre` handler, registered when a session starts (`lua/aineo/claude/init.lua:51–63`) and moved last when a new session starts after the last one exited. It can block up to 11.8 s before a handler after it runs.
- **A Lua error in an earlier handler does not skip later ones. An uncaught Vimscript `throw` does,** on both versions.
- **`BufUnload` fires for every loaded buffer before `VimLeavePre`** (`main.c:804–812`, then 824, at v0.12.5). It is a hook that does not depend on the order of `VimLeavePre` handlers.

Choose the quit hook and say why. Whatever you choose, **the limit is recorded in the help's text**: an earlier quit handler that throws skips the quit save, and then only the delayed save holds, losing at most the last delay's typing.

### Where it lives

- **A new module home, `lua/aineo/draft/` (C11),** keeps one buffer's text in one file.
- **The composition root, `plugin/aineo.lua`,** gives it its environment next to `give_report_environment()`, and hands it Input.
  - Input does not exist while `arrangement()` runs on the first open. So the hand-off comes **after** `open()` returns, and after `focus()` returns when its callback opened the layout. Only `plugin/aineo.lua` opens the layout in production code (the brief review).
  - A first `\i`, `\r` or `\c` on a closed layout must hand Input over too, and a test says so.
- **The layout keeps making Input as it does.** The draft reaches Input through the public `layout.input_buffer()` and sees its changes through `on_lines`. The seam is yours under `tdd` and `modularity`: an entry point, dependencies declared, no reaching into the layout's tables.

### Facts, checked against `origin/dev` (`d35dc4f`)

- **`lua/aineo/layout/init.lua`:**
  - `make_scratch()` sets `buftype = 'nofile'`, `bufhidden = 'hide'`, `buflisted = false` and `swapfile = false`;
  - `take_input_buffer()` makes the startup buffer Input when it is unnamed and empty;
  - public `M.input_buffer()`;
  - `M.open` restores the layout while it is open.
- **`plugin/aineo.lua`:**
  - `give_report_environment()` (lines 56–70);
  - `open()` (lines 131–134) and `focus()` open the layout through `arrangement()`;
  - `run()` (lines 195–203).
- **`lua/aineo/send/init.lua:118`** clears Input with `nvim_buf_set_lines(input, 0, -1, false, {})`, and restores it at line 121 if the write fails.
- **`lua/aineo/report/records.lua`:** `records_file()` (line 30) keeps the Reports in `<state>/aineo/reports/<sha256 of the working directory>.jsonl`. Follow it for the draft's path, for example `<state>/aineo/drafts/<sha256>.txt`.
- **When T13 (PR #31) merges,** only the help's line numbers move. That is why the fence below is quoted, not numbered.

### Baseline

**At `d35dc4f`**, whose code is identical to `9af91a6`, where the evidence was measured:
- 0.11.6: 727 cases, `Fails (0)` (`evidence/baseline-0.11.6.txt`);
- 0.12.5: 727 cases, `Fails (8)` (`evidence/baseline-0.12.5.txt`).

The brief review re-ran both at `091be6b`, whose code is the same: the same counts.

**This packet is dispatched after T13 (PR #31) merges**, since both change `plugin/aineo.lua`. T13 makes the suite green on both versions, and its merge's counts are this packet's baseline. Before dispatch the orchestrator re-checks every fact above against that `dev`, and records any change as a dated amendment.

**Run the whole suite on both versions, one at a time:**
- the host's 0.12.5;
- 0.11.6, with `env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test`. The worktree guard refuses `PATH=…:$PATH make`.

Under load, `test_send.lua`, `session_status()` and `tests/test_health.lua:336` fail spuriously; re-run a surprising failure alone. Report both counts.

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › D17, C11, C2, C4, C6;
- `doc/aineo.txt` › `*aineo-layout*`;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t14-input-draft` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t14_input_draft`.
- **You may touch:**
  - `lua/aineo/draft/` (new), and its new test files;
  - `plugin/aineo.lua`, only where the layout opens, or is focused open, and where the report environment is given — not `start_up`'s refusal checks, the key tables or the error framing;
  - `tests/test_entry_*.lua`, new files only, for the paths through `:Aineo open`, `\i` and the autostart;
  - `doc/aineo.txt`, only inside the section from its first line, `3. THE LAYOUT                                                   *aineo-layout*`, to its last, ``lives in one tab; from another tab, `\o` moves you to it.``. Say there:
    - that Input keeps a draft, where, and when it is restored and cleared;
    - ID6's sharing;
    - the quit-handler limit;
  - your session note.
  - The documentation this change invalidates is that section. Correct it in the same change and say so in your report.
- **You must not touch:**
  - `lua/aineo/layout/`: Input stays made as it is. If the draft cannot work without a change there, stop and report a spec conflict. The brief review found that it can.
  - `lua/aineo/send/`, `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/report/`, `lua/aineo/health.lua`.
  - `tests/test_plugin.lua`'s frozen pins.
  - `scripts/`, `tests/helpers/`, the `Makefile`.
  - `doc/aineo.txt` outside your section. T9 owns `*aineo-report*`, and T12, after you, owns `*aineo-commands*` to `*aineo-keys*`.
  - The task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note.
  - The project note.
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your section** is the one quoted above.
  - **T9** (PR #30), if still open, edits from `8. THE AGENT REPORT                                             *aineo-report*` to `the working directory of its own moment.`.
  - **Before you push**, for each open branch that edits the help:
    1. `git fetch origin && git merge-tree --write-tree <your head> <branch>`. Exit 0 and no conflict listed means clean; it prints the merged tree's id.
    2. `git show <tree id>:doc/aineo.txt > doc/aineo.txt`.
    3. `make test_file FILE=tests/test_doc.lua`.
    4. `git checkout HEAD -- doc/aineo.txt`.

    Report the results.
- **Session note:** `knowledge-vault/Sessions/<the day you are dispatched> — T14 Input draft.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). The harness refuses writes outside your worktree. Prefix every file with `t14-`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. You read and run its Neovim builds there, and write nothing.
- **Never run the real `claude`.** Confirm the guard holds before any autostart case runs.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

**The user, 2026-09-25**, asked how to fix "Unsent Input is lost", which they called "completly undesired behavior". Offered three options — keep a draft, refuse to quit, or both — they chose **"Keep it as a draft"**, as offered:
> Input is saved as a draft for the working directory, next to the saved Reports, shortly after each change and again at quit. When aineo opens in that folder with an empty Input, the draft comes back. Sending with \s clears Input and the draft together. Nothing asks you anything at quit, and the draft survives a crash too. The catch: two Neovims open in the same folder share one draft, and the last change wins.

That is D17. **The orchestrator's readings of it, for the user to confirm.** Name each in your session note's *Readings for the MVP review*, with your own:
- ID1's immediate emptying;
- ID2's "a pending change only";
- ID3's restore only into a new or emptied Input;
- ID5's copied patterns.

Your own readings are the save delay, the draft's file layout, and the quit hook.

## Budget

Medium: a new small home, its wiring in the composition root, and the help. If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t14-report-packet.md`, with the suite counts on both versions. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure. Name the report's absolute path in your final message.

## Amendment — 2026-09-26, before dispatch

T13 (PR #31), T15 (PR #39) and T16 (PR #40) have merged. This section re-checks every fact above against `origin/dev` at `7af0d47`. Where this section and the text above differ, this section holds.

### Base and baseline

- **Your base is `origin/dev` at `7af0d47`** or later.
- **Its suite is green on both versions:** 808 cases, `Fails (0)`, on 0.12.5 and on 0.11.6 (`evidence/baseline-7af0d47.txt`, from the orchestrator's verification of the code `7af0d47` holds).
- The whole suite must stay green on both versions.

### Facts that moved

- **"When T13 (PR #31) merges, only the help's line numbers move" is no longer true.**
  - T13 grew `plugin/aineo.lua`'s error framing.
  - T16 changed `lua/aineo/layout/init.lua` and your section of the help.
- **`plugin/aineo.lua` at `7af0d47`:**
  - `give_report_environment()`, lines 58–70;
  - `open()`, lines 131–134, and `focus()`, lines 143–148;
  - `run()`, lines 212–220. It reports at `ERROR` through `error_line()` (line 194).
  - On the autostart, `open_unless_session_restored()` (lines 365–377) records `open-failed` at line 374.
- **`lua/aineo/layout/init.lua` (T16):**
  - `open()` now also makes the Report's and Input's windows wrap long lines, for their own buffers (`wrap_right_column()`, called after `pin_windows()`).
  - Input is still made as before, and the draft still reaches it through `M.input_buffer()` (line 680).
  - T16's `tests/test_layout_wrap.lua` stays green unchanged.
- **The help, your section `*aineo-layout*`:** lines 52–94, not 51–86.
  - Its first and last lines are unchanged, quoted as in *Boundary*.
  - T16 added a paragraph on wrapping inside it. Leave it as it is, and keep your hunks apart from it by at least one unchanged line.
- **The Report's section is now T11's, not T9's.**
  - T11 runs beside you and edits from `8. THE AGENT REPORT                                             *aineo-report*` to `the working directory of its own moment.`, together with `lua/aineo/report/render.lua` and the report tests. None of these is in your boundary.
  - T9 and T15, which edited that section before, have merged.

### Facts that held

- `lua/aineo/claude/init.lua` (`VimLeavePre` at lines 51–63), `lua/aineo/send/init.lua` (lines 118 and 121), `lua/aineo/report/records.lua` (`records_file()`, line 30) and `tests/helpers/send.lua` are unchanged since `d35dc4f`: `git diff --stat` prints nothing for them.

### Before you push

Run the merge check of *Boundary* against each of these that exists and is unmerged:
- `origin/feature/t11-report-icon`;
- `origin/feature/t12-claude-numbers`.

Run `test_doc.lua` on both versions.
