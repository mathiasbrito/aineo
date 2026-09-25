**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T14 | Input keeps unsent text as a draft (D17): saved per working directory beside the Reports shortly after each change and at quit, restored into an empty Input when aineo opens there, cleared with Input when Send clears it | T8 | active |

It rests on:
- **D17** — the user's decision of 2026-09-25, below;
- **C2** — the layout, whose Input is a scratch buffer;
- **C4** — Send clears Input;
- **C6** — the Reports are kept per working directory under `stdpath('state')`.

### The problem, measured

Input is a `nofile` scratch buffer (`lua/aineo/layout/init.lua:358`, `make_scratch()`). Neovim never counts such a buffer as unsaved. The orchestrator measured on 2026-09-25, with the host's Neovim 0.12.5:
- `nvim --clean --headless -i NONE -n -c 'enew | setlocal buftype=nofile bufhidden=hide | call setline(1, "an unsent draft") | set modified' -c 'qa'` exited 0, and the text was gone;
- the same with a normal buffer gave `E37: No write since last change`.

So an unsent Input is lost at quit, silently.

### The behaviours — one test each, each seen red first

- **ID1 — saved shortly after each change.** Text typed into Input, or put there any other way, is written to the draft within a short delay after the change. Choose the delay and state it.
- **ID2 — saved at quit.** Quitting saves the draft, whatever the delay's state. The save never blocks or noticeably slows a quit, and never makes `:qa` refuse.
- **ID3 — restored.** When aineo opens its layout in a working directory that has a draft, and Input is empty, Input shows the draft.
  - This holds for the autostart, `\o` and every other way the layout opens.
  - An Input that already holds text is never overwritten.
- **ID4 — cleared with Input.** When Send clears Input, the draft is cleared too: its file is removed or emptied, so the next start restores nothing. No change to the Send home is needed: the draft follows Input's text.
- **ID5 — where it lives.**
  - The draft is kept under `stdpath('state')`, beside the Reports (C6), keyed by the same working directory the Reports use: `give_report_environment()`, `plugin/aineo.lua` line 57, with `vim.fn.getcwd()` taken the first time.
  - Never in the working directory.
  - It is written so that a crash mid-write leaves the previous draft or the new one, never a torn file.
- **ID6 — two editors, one folder.** Two editors open in one working directory share one draft, and the last change wins (the user accepted this). Nothing is corrupted. Record it in the help's text.
- **ID7 — failures.** A draft that cannot be read or written gives one warning starting `aineo: `. It never raises into the user's typing, and never stops a quit.
- **ID8 — nothing at startup.** Loading aineo loads no draft module and adds no autocommand. The frozen pins in `tests/test_plugin.lua` stay as they are and green. The draft is first touched when the layout opens.

### Where it lives

A new module home, for example `lua/aineo/draft/`, keeping one buffer's text in one file. The composition root, `plugin/aineo.lua`, gives it its environment next to `give_report_environment()`, and hands it Input once the layout has opened.
- The layout keeps making Input as it does.
- The seam is yours under `tdd` and `modularity`: an entry point, dependencies declared, no reaching into the layout's tables.

### Facts, checked against `origin/dev` (`d35dc4f`)

- **`lua/aineo/layout/init.lua`:**
  - `make_scratch()`, from line 353, sets `buftype = 'nofile'`, `bufhidden = 'hide'`, `buflisted = false` and `swapfile = false`;
  - `take_input_buffer()` makes the startup buffer Input when it is unnamed and empty;
  - public `M.input_buffer()` (line 653).
- **`plugin/aineo.lua`:**
  - `give_report_environment()` (lines 55–69) passes `state_directory = vim.fn.stdpath('state')` and `working_directory = vim.fn.getcwd()` once;
  - `open()` (line 131) and `focus()` open the layout through `arrangement()`, which calls it.
- **`lua/aineo/send/init.lua:118`** clears Input with `nvim_buf_set_lines(input, 0, -1, false, {})`, and restores it at line 121 if the write fails.
- **`lua/aineo/report/records.lua`** keeps the Reports in `<state>/aineo/reports/<sha256 of the working directory>.jsonl` (`records_file()`, line 30). Follow its pattern for the draft's path, for example `<state>/aineo/drafts/<sha256>.txt`.

### Baseline

This packet is dispatched after **T13 (PR #31)** merges, because both change `plugin/aineo.lua`. T13 makes the suite green on Neovim 0.12.5 and 0.11.6, and its merge's counts are this packet's baseline. Before dispatch the orchestrator re-checks every fact above against that `dev`, and records any change as a dated amendment.

Run the whole suite on both versions, one at a time:
- the host's 0.12.5;
- 0.11.6, with `env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test`. The worktree guard refuses `PATH=…:$PATH make`.

Report both counts.

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › D17, C2, C4, C6;
- `doc/aineo.txt` › `*aineo-layout*`;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t14-input-draft` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t14_input_draft`.
- **You may touch:**
  - a new home under `lua/aineo/` for the draft, and its new test files;
  - `plugin/aineo.lua`, only where the layout opens and the report environment is given — not `start_up`'s refusal checks, the key tables or the error framing;
  - `tests/test_entry_*.lua`, new files only, for the path through `:Aineo open` and the autostart;
  - `doc/aineo.txt`, only in the section from its first line, `3. THE LAYOUT                                                   *aineo-layout*` (line 51 at `d35dc4f`), to its last, `lives in one tab; from another tab, `\o` moves you to it.` (line 86). Say there that Input keeps a draft, where, when it is restored and cleared, and ID6's limit;
  - your session note.
  - The documentation this change invalidates is that section. Correct it in the same change and say so in your report.
- **You must not touch:**
  - `lua/aineo/layout/`: Input stays made as it is. If the draft cannot work without a change there, stop and report a spec conflict.
  - `lua/aineo/send/`, `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/report/`, `lua/aineo/health.lua`.
  - `tests/test_plugin.lua`'s frozen pins.
  - `scripts/`, `tests/helpers/`, the `Makefile`.
  - `doc/aineo.txt` outside your section. T9 owns `*aineo-report*`, and T12, after you, owns `*aineo-commands*` to `*aineo-keys*`.
  - The task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note.
  - The project note.
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your section** is lines 51–86 above.
  - **T9** (PR #30), if still open, edits from `8. THE AGENT REPORT … *aineo-report*` to `the working directory of its own moment.`.
  - **Before you push:** merge with each open branch that edits the help (`git merge-tree --write-tree <your head> <branch>`), then run `make test_file FILE=tests/test_doc.lua` on the merged file. Report both results.
- **Session note:** `knowledge-vault/Sessions/<the day you are dispatched> — T14 Input draft.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). The harness refuses writes outside your worktree. Prefix every file with `t14-`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. You read and run its Neovim builds there, and write nothing.
- **Never run the real `claude`.** Confirm the guard holds before any autostart case runs.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

**The user, 2026-09-25**, asked how to fix "Unsent Input is lost", which they called "completly undesired behavior". Offered three options — keep a draft, refuse to quit, or both — they chose **"Keep it as a draft"**, as offered:
> Input is saved as a draft for the working directory, next to the saved Reports, shortly after each change and again at quit. When aineo opens in that folder with an empty Input, the draft comes back. Sending with \s clears Input and the draft together. Nothing asks you anything at quit, and the draft survives a crash too. The catch: two Neovims open in the same folder share one draft, and the last change wins.

That is D17. The save delay (ID1) and the draft's file layout are yours. Name each in your session note's *Readings for the MVP review*.

## Budget

Medium: a new small home, its wiring in the composition root, and the help. If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t14-report-packet.md`, with the suite counts on both versions. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure. Name the report's absolute path in your final message.
