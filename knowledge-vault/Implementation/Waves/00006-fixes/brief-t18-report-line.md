**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T18 | Report line without the icon (C14, D24): `HH:MM [status] task — summary`, `[status]` bold in its status's colour, the details under the `[status]` — a small fix, over the orchestrator's stated concern that it needs a new row (the user, 2026-09-26) | T10 | active |

It rests on D24 and C14, which supersede C10, and on the user's words of 2026-09-26 (*What was decided already*).

### The behaviours — RL1 to RL3 tested, each test seen red first; RL4 and RL5 are invariants

- **RL1 — no icon.** A report's header is `HH:MM [status] task — summary`: it starts with the time, and no icon shows anywhere a report is drawn. The details start under the `[status]`'s `[`, six cells in (`HH:MM ` is six ASCII cells), for every status, whatever `'ambiwidth'` or `setcellwidths()` say.
- **RL2 — `[status]` bold, in its status's colour.** `[status]`, brackets included, shows bold, in the colour of its status's group (`colours.STATUS_GROUPS`), on every drawing path: a report received, the Report opened on saved records, `:edit` in the Report, the Report made anew after `:bdelete`, `:bwipeout` or `:bunload`.
  - **Measure it on the screen,** not in the extmarks alone: in a child with a UI, the cells of `[status]` carry the status group's foreground and bold, on both versions. Say how your test reads them (`child.get_screenshot()`'s attributes, or `nvim__inspect_cell`, or another way you measure).
  - **A user's colour still wins, and bold stays removable.** A user's or a colour scheme's colour for a status group still shows on `[status]`, bold; `:highlight clear` brings back the default link, bold. A user can turn the bold off without losing the status's colour. How — a group of its own for the bold, layered over the status's, or another way — is yours to measure: a `:highlight default link` carries no attributes, so bold cannot ride on the status groups' default links (T9's mechanism, `colours.define_report_colours()`). Whatever group you add is defined as T9's are, with `default`, and listed in the help.
- **RL3 — the time and nothing else changes colour.** The time stays in `AineoReportTime`; the task, the summary and the details show in no group, apart from T10's links (`AineoReportLink`).
- **RL4 — T10's links stay whole (an invariant).** Every link keeps its `url` and its group. Its columns move with the text: a link in the header starts four bytes earlier (the icon and its space are gone), a link in the details two cells earlier (the indent is 6, not 8). `tests/test_report_links.lua`'s rows assert columns counted from the old indent and header: move them, and keep every row's text and url as it is. RL1–RL5 of T10's brief hold on the moved columns.
- **RL5 — nothing else changes (an invariant).** The Report follows the newest report; the saved records are unchanged (`format.lua`, `records.lua`); the report format and the report tool are unchanged.

The seam is yours under `tdd`. T11 put the icon in `render_report()` (`lua/aineo/report/render.lua:125–142`, `STATUS_ICONS` at `:21`) and its colour in `header_colours()` (`:72–92`); `details_indent()` (`:60–62`) measures the prefix with `nvim_strwidth()`, which stays right for an ASCII prefix.

### Facts, checked against `origin/dev` (`d30ff4d`)

- **The pins over the old line:** the icon or its indent is asserted in
  - `tests/test_report_buffer.lua` (38 lines with an icon, and T11's width cases: `'ambiwidth'` `double`, mixed widths in both orders, the narrow wrapping window, the Report made anew);
  - `tests/test_report_colours.lua` (the icon's group, 3 lines with an icon);
  - `tests/test_report_links.lua` (every row's columns, counted from the indent 8 and the header's icon);
  - `tests/test_entry_report.lua:48` and `:70`;
  - `tests/test_mcp_blocked_editor.lua:76–77` and `:123–124`, and `tests/test_mcp_delivery.lua:142`, `:181`, `:229`, `:248` and `:268`.
- **The help:** `doc/aineo.txt` › `*aineo-report*` shows `<icon> HH:MM [status] task — summary` (line 315), names the icons (line 318), says the details start under the `[status]` "however wide the icon shows" (line 320), and in *Colours* (`Colours ~`, line 353) says the Report shows "the icon and the `[status]`" in the group of its status; the status groups' entries (lines 368–377) name each icon.
- **The readings the user kept,** now moot: MR102 (the indent by the icon's width) is marked "moot once T18 lands" in `knowledge-vault/Review/2026-09-24 — v1 MVP readings review.md`.

### Baseline

- `dev` at `d30ff4d`, T10 merged: 973 cases, `Fails (0)`, on 0.12.5 and 0.11.6 (`evidence/baseline-d30ff4d.txt`, the orchestrator's verification of PR #52, whose tree has the same code). If T20 (PR open) merges before you start, re-measure the baseline on your base.
- **Run the whole suite on both versions, one at a time.** Under load, `test_send.lua`, the `session_status()` cases of `test_claude.lua`, `tests/test_health.lua:336`, `test_entry*.lua` and `tests/test_mcp_blocked_editor.lua` fail spuriously; re-run a surprising failure alone before you believe it. A whole 0.12.5 run that stops at the 960 s limit is not a result: re-run it, and run the stalled file alone. Check `uptime` before a whole run.
  - On the host's 0.12.5: `make test`.
  - On 0.11.6, in this literal form (the worktree guard refuses `PATH=…:$PATH make`):

    ```
    env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test
    ```

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › D24, C14 (and C10, struck), C6;
- `doc/aineo.txt` › `*aineo-report*`;
- `knowledge-vault/Sessions/2026-09-25 — T9 Report colours.md` (how the groups are defined, and their limit);
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `bugfix/t18-report-line` from `origin/dev`.
- **Class:** **small fix** (the orchestrate skill, §3), called by the user on 2026-09-26 ("Small fix, after T10") over the orchestrator's stated concern that replacing C10 needs a new row, which the small-fix rules exclude. It changes one behaviour, the Report's line, in `lua/aineo/report/`, with its tests.
  - If it needs a file outside *You may touch*, or reaches any of these, stop at a green, pushed state and report a true partial: `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/health.lua`, `lua/aineo/init.lua`, `plugin/aineo.lua`, `scripts/`, `tests/helpers/`, the `Makefile`.
  - Title the pull request `Small fix: the Report line without its icon, [status] bold`. No commit subject says "small" (root `CLAUDE.md`).
  - Re-run every mutant survivor on the test files the pull request adds or modifies.
- **Model:** `opus`.
- **Resources:** `impl_t18_report_line`.
- **You may touch:**
  - `lua/aineo/report/`: `render.lua`, `colours.lua`, `buffer.lua`, `init.lua`;
  - `tests/test_report*.lua` and `tests/test_entry_report.lua`, the pins over the old line and new cases;
  - `tests/test_mcp_delivery.lua` and `tests/test_mcp_blocked_editor.lua`, **only the expected Report lines** — nothing else in them;
  - `doc/aineo.txt`, **only inside `*aineo-report*`**;
  - your session note.
  - The documentation this change invalidates is that help section and the Report home's docstrings. Correct them in the same change and say so in your report.
- **You must not touch:**
  - `plugin/aineo.lua`, `lua/aineo/layout/`, `lua/aineo/draft/`, `lua/aineo/mcp/`;
  - the report format or the saved records (`lua/aineo/report/format.lua`, `records.lua`), and T10's rule (`lua/aineo/report/links.lua`);
  - `tests/test_plugin.lua`'s frozen pins, `tests/helpers/`;
  - `doc/aineo.txt` outside `*aineo-report*`. T20 (PR open) edits the introduction's summary sentence and `*aineo-commands*`;
  - the task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note;
  - the project note, the MVP readings review;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your section** runs from its first line, `8. THE AGENT REPORT                                             *aineo-report*`, to the line before `9. THE AUTOSTART`.
  - **The other packet:** T20 edits the introduction's sentence from ``Every command sits behind one prefix key, `\` by default, in Normal mode:`` to ``and `\c` move to the Report, Input and Claude.``, and `*aineo-commands*`' entry from `*:Aineo-claude*` to ``:Aineo claude		Moves the cursor to Claude's terminal.``.
  - Every hunk stays inside your section.
  - **Before you push**, for `origin/bugfix/t20-claude-terminal-mode` if it exists and is unmerged:
    1. `git fetch origin && git merge-tree --write-tree <your head> origin/bugfix/t20-claude-terminal-mode`;
    2. `git show <tree id>:doc/aineo.txt > doc/aineo.txt` and `git show <tree id>:tests/test_doc.lua > tests/test_doc.lua`;
    3. `make test_file FILE=tests/test_doc.lua`, on both versions;
    4. `git checkout HEAD -- doc/aineo.txt tests/test_doc.lua`.

    Report the results.
- **Session note:** `knowledge-vault/Sessions/<the day you are dispatched> — T18 Report line.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). Prefix every file there with `t18-`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. You read and run its Neovim builds there, and write nothing.
- **Never run the real `claude`,** and never open a browser.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- **The user, 2026-09-26, after seeing T11's icon:** "the icon position is not as I imagined... it is not good... <time> [ <icon> <message_type ] is what I imagine, refactor as an small fix..." Asked to choose the form, the user declined the question to clarify, then: "remove the Icon, just make the banned [<type>] bold then...".
- **Asked how it should run**, as put to the user: "Removing the icon and making [status] bold replaces C10, the spec row for the Report line, with a new row. Small fixes exclude a change that needs a new row, so I propose a regular packet. How should it run?" The user chose "Small fix, after T10" over "Regular, before T10 (Recommended)" and "Small fix anyway, before T10".
- **The rows:** D24 records the decision, and C14, superseding C10, the line. C14 carries over unchanged the time in `Comment`'s colour (T9) and the details under the `[status]` (C10).
- **The orchestrator's readings, for your note's *Readings for the MVP review*:**
  - the brackets are bold with the word, as C6 and T9 colour them with it;
  - the bold can be turned off apart from the colour (RL2).

## Budget

One behaviour, with many pins to move: a small packet with a wide test diff. If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t18-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
