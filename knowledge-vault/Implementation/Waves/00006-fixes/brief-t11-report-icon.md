**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T11 | Report icon (C10): each report's header starts with the icon of its status — `▸` started, `◐` progress, `⊘` blocked, `✓` done, `✗` failed — coloured like the status, with the details still under the status | T9 | active |

It rests on:
- **C10**, which supersedes C6's rendered line: `<icon> HH:MM [status] task — summary`, the icon by status, coloured like the status, and the details indented under the status;
- **C6** for the rest of the Report, which stands;
- **T9**, merged as PR #30: the groups `AineoReportTime` and `AineoReport<Status>`, defined by `lua/aineo/report/colours.lua`.

### The behaviours — IC1 to IC5 tested, each test seen red first; IC6 and IC7 are invariants

- **IC1 — the icon by status.** A report's header is `<icon> HH:MM [status] task — summary`: the icon of its status, one space, then the header as it is today. Its test is parametrized over the five statuses, so a swap of any two icons fails it.

  | status | icon | code point |
  |---|---|---|
  | `started` | `▸` | U+25B8 |
  | `progress` | `◐` | U+25D0 |
  | `blocked` | `⊘` | U+2298 |
  | `done` | `✓` | U+2713 |
  | `failed` | `✗` | U+2717 |

- **IC2 — the icon's colour.** The icon is shown in the group of its status, the one `[status]` is shown in (`colours.STATUS_GROUPS`). The colour covers the icon's bytes alone: the space after it has no colour.
- **IC3 — the time and the status keep their colours at their new columns.** T9's RC1 to RC3 hold on the new header:
  - the `HH:MM` in `AineoReportTime`;
  - the `[status]`, brackets included, in its status's group;
  - nothing else coloured — not text like an icon, `[done]` or `12:34` in a task, a summary or details.

  T9's colour pins in `tests/test_report_colours.lua` are moved, never deleted. Each moves by 4 bytes, the icon's 3 and its space, and gains the icon's span in its status's group; no span is deleted. So `spans_of(<status group>)` returns two spans where it returned one.
- **IC4 — the details stay under the status.** Each details line is indented by the display width of what comes before `[status]` in its header: `<icon> HH:MM `.
  - **The width is measured,** with `vim.fn.strdisplaywidth()` or `vim.api.nvim_strwidth()`, at each rendering. It is never derived from `'ambiwidth'`, and never kept from an earlier rendering: both `'ambiwidth'` and `setcellwidths()` change it (`evidence/icon-widths.txt`, both versions):
    - with Neovim's defaults every icon is one cell, so the width is 8;
    - under `'ambiwidth'` `double`, `◐` is two cells and the others stay one, so a `progress` report's details are indented 9;
    - `setcellwidths({ { 0x2713, 0x2713, 2 } })` makes `✓` two cells, so a `done` report's details are indented 9; an entry can also make `◐` one cell under `double`.
  - **Each report's details keep the width of the rendering that drew them.** A report that arrives after a change of width is drawn with the new width. Reports already shown keep theirs until `:edit` in the Report redraws every report with the new width (`init.lua:117`, through the Report's `BufReadCmd`); a new report renders only itself (`init.lua:179`).
  - **Its tests:**
    - Neovim's defaults, width 8;
    - a `progress` report under `'ambiwidth'` `double`, width 9;
    - a `done` report under `setcellwidths({ { 0x2713, 0x2713, 2 } })`, width 9;
    - the sequence: a `progress` report with details under `single`, then `'ambiwidth'` `double`, a second `progress` report, then `:edit` — 8 then 9, then 9 and 9 after `:edit`.
    
    Each test sets the option or the cell widths after the child has loaded the report home, as `report_editor.start()` does, so that a table of widths computed when `render.lua` loads fails it.
  - This is the orchestrator's reading of C10's "indented under the status". Name it in your session note's *Readings for the MVP review*.
- **IC5 — every path shows the icon.** Three paths show it:
  - a report that arrives while the Report is open;
  - the saved records shown when the Report opens;
  - the refill after `:edit` in the Report.

  One render serves all three today: `render.render_records()`, at `lua/aineo/report/init.lua:117` (saved records, and the refill through the Report's `BufReadCmd`) and `:179` (a new report). So IC5's test goes green with IC1's code. **Write it and see it red before the render changes, beside IC1's**; written after IC1, it is green at once. The moved pins on those paths are listed under *Facts*.
- **IC6 — the rest of the line is unchanged (an invariant).** The time, the status, the task, the summary and the text of the details are what they were. The saved records' format is unchanged (`lua/aineo/report/records.lua` is outside your boundary), so reports saved before this change show with the icon.
  - **Every text pin you change** changes in exactly two ways: the icon and its space before a header, and a details line's indent, 6 → 8 under the defaults.
  - **Every colour pin** moves by 4 bytes and gains the icon's span (IC3).
  - **Two patterns change**, not pins: `REPORT_LINES` in `tests/test_entry_report.lua` and `REPORT_HEADERS` in `tests/test_report_buffer.lua` (*Facts*).
  - **`tests/test_mcp_blocked_editor.lua`'s `first:report_lines({ … })`** (line 49 at `dbc96c9`) is a wait's target, not an assertion: left unmoved, it waits out its 5 s and stays green. Move it with the others. Only the records review can see it.
  - The records review compares every changed pin with its old line.
- **IC7 — nothing at startup (an invariant).** T9's RC7 holds: loading aineo defines no highlight group and adds no autocommand. `tests/test_plugin.lua`'s frozen pins and `tests/test_report_colours.lua` › *the groups* stay green.

The seam is yours under `tdd`. For example, the icons could sit beside `colours.STATUS_GROUPS`, keyed by status, and the render could place the icon's colour span as it places the status's.

### Facts, checked against `origin/dev` (`dbc96c9`)

- **The render.** `lua/aineo/report/render.lua`:
  - `render_report()` (lines 50–74) builds the header as `('%s %s %s — %s'):format(clock_time, bracketed_status, …)`;
  - it colours byte columns: the time at `0` to `#clock_time`, and the status from `#clock_time + 1`;
  - `DETAILS_INDENT` (line 20) is `(' '):rep(#'HH:MM ')`, six spaces.
- **The icons' sizes** (`evidence/icon-widths.txt`, measured with `strdisplaywidth` on 0.12.5 and 0.11.6):
  - each icon is 3 bytes in UTF-8;
  - under `'ambiwidth'` `single`, each is 1 cell;
  - under `double`, `◐` is 2 cells and the others 1.

  - `setcellwidths()` changes an icon's width either way, on both versions.

  A column counted in bytes and an indent counted in cells therefore differ.
- **The pins over a rendered line.** The headers are from `git grep -n -E "\[(started|progress|blocked|done|failed)\] " origin/dev -- tests`; the brief review added the rest by running a reference render over the whole suite (41 failing cases, all in these five files):
  - `tests/test_report_buffer.lua`:
    - headers at lines 45, 59, 75, 87, 164, 176, 191, 236, 414, 415, 434, 587, 711, 772 and 800;
    - details pins at 60–61, indented six spaces;
    - `REPORT_HEADERS` (lines 394–398) keeps the lines that match `^%d` as headers. With the icon first it keeps none, so the cases at 414, 415 and 434 fail on a count of 0 however their pins move. The pattern changes with them.
  - `tests/test_entry_report.lua`:
    - lines 48 and 70;
    - its `REPORT_LINES` (lines 12–16) replaces a leading `^%d%d:%d%d ` with `HH:MM `. That pattern stops matching once the icon leads the line, and the case at line 48 then fails on the real time.
  - `tests/test_mcp_delivery.lua`: headers at 142, 181, 229, 248 and 268; details at 249–250, indented six spaces.
  - `tests/test_mcp_blocked_editor.lua`: lines 49, 94 and 95. Line 49 is a wait's target (IC6).
  - `tests/test_report_colours.lua`, every colour pin: line 78; the parametrized statuses at 83–87 with line 101; line 116; lines 128–133; lines 160–163; lines 199–202.
  - The pins on the paths IC5 names: `tests/test_report_buffer.lua:164` (`:edit`), `:236` (re-created after a delete), `:587`, `:772` and `:800` (records shown when the Report opens), and `tests/test_report_colours.lua:160–163` and `:199–202`.
  - Line numbers are `dbc96c9`'s. T13 (PR #31) moves `tests/test_mcp_blocked_editor.lua`'s; the dated amendment below gives the new ones.
- **The help.** `doc/aineo.txt` › `*aineo-report*` (lines 253–305 at `dbc96c9`; T13 moves every line from 39 on down by one):
  - it shows the line at 269–270, `HH:MM [status] task — summary` over `details, indented under the status`;
  - it describes the colours at 275–285;
  - it lists the groups at 287–298, each with what it colours.

### Baseline

- **At `dbc96c9`**, which is code-identical to PR #30's verified head `40bc378` (`evidence/baseline-dbc96c9.txt`):
  - 0.11.6: 747 cases, `Fails (0)`;
  - 0.12.5: 747 cases, `Fails (8)` — the eight T13 fixes.
- **Your base is `origin/dev` after T13 merges.** The orchestrator dispatches you only then. Before dispatch it re-checks every fact above against that `dev` and records any change as a dated amendment of this brief, below: the counts with their evidence file, and the moved line numbers. On that base, both versions must be green.
- **Run the whole suite on both versions, one at a time.** Under load, `test_send.lua`, `session_status()` and `tests/test_health.lua:336` fail spuriously; re-run a surprising failure alone before you believe it.
  - On the host's 0.12.5: `make test`.
  - On 0.11.6, D10's minimum, put the downloaded build first on `PATH` in this literal form. The worktree guard refuses `PATH=…:$PATH make`.

    ```
    env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test
    ```

  Report both counts.

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › C6 and C10;
- `knowledge-vault/Sessions/2026-09-25 — T9 Report colours.md` › *Limits*;
- `doc/aineo.txt` › `*aineo-report*`;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t11-report-icon` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t11_report_icon`.
- **You may touch:**
  - `lua/aineo/report/render.lua`, and `lua/aineo/report/colours.lua` if the icons live beside the groups;
  - `tests/test_report_buffer.lua`, `tests/test_report_colours.lua` and `tests/test_entry_report.lua`;
  - `tests/test_mcp_delivery.lua` and `tests/test_mcp_blocked_editor.lua`, **only** their pins over a rendered line (IC6);
  - `doc/aineo.txt`, **only inside** `*aineo-report*`: the line with its icon, the icons by status, the icon's colour, and each group's row naming the icon beside `[status]`;
  - your session note.
  - The documentation this change invalidates is `doc/aineo.txt` › `*aineo-report*`, and the docstrings of `render.lua` and `colours.lua` that describe the line or what a group colours. Correct them in the same change and say so in your report.
- **You must not touch:**
  - `lua/aineo/report/records.lua`, `format.lua`, `buffer.lua`, `instructions.lua` and `init.lua`;
  - `lua/aineo/mcp/`, `lua/aineo/claude/`, `lua/aineo/send/`, `lua/aineo/layout/`, `lua/aineo/health.lua`, `plugin/aineo.lua`;
  - `tests/test_plugin.lua`, `scripts/`, `tests/helpers/`, the `Makefile`;
  - `doc/aineo.txt` outside `*aineo-report*`. T14 owns `*aineo-layout*`, and T12 owns `*aineo-commands*` to `*aineo-keys*`;
  - the task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note;
  - the project note;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your section** runs from its first line, `8. THE AGENT REPORT                                             *aineo-report*`, to its last, `the working directory of its own moment.`.
  - **The other packets:**
    - T14 edits from `3. THE LAYOUT                                                   *aineo-layout*` to ``lives in one tab; from another tab, `\o` moves you to it.``;
    - T12, after T14, edits from `4. COMMANDS                                                   *aineo-commands*` to `of both (|aineo-health|).`.
  - Every hunk stays inside your section.
  - **Before you push**, for each branch of theirs that exists and is unmerged (`origin/feature/t14-input-draft`, `origin/feature/t12-claude-numbers`):
    1. `git fetch origin && git merge-tree --write-tree <your head> <branch>`. Exit 0 and no conflict listed means clean; it prints the merged tree's id.
    2. `git show <tree id>:doc/aineo.txt > doc/aineo.txt`.
    3. `make test_file FILE=tests/test_doc.lua`.
    4. `git checkout HEAD -- doc/aineo.txt`.

    Report the results.
- **Session note:** `knowledge-vault/Sessions/<the day you are dispatched> — T11 Report icon.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). The harness refuses writes outside your worktree. Prefix every file there with `t11-`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. You read and run its Neovim builds there, and write nothing.
- **Never run the real `claude`.**
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- **The user asked for** "an icon in the beginning (icons from unicode, but only the ones terminal styled)" (2026-09-25).
- **Asked which icons**, the user chose "Unicode set" — `▸` started, `◐` progress, `⊘` blocked, `✓` done, `✗` failed — over the other options offered. That is C10.
  - The option described the icons as "each one column wide". That holds only with Neovim's defaults: `'ambiwidth'` `double` and `setcellwidths()` change it. IC4 is measured.
- **The status colours are T9's reading**, awaiting the user's MVP review. Use the groups; do not choose colours.
- **The Report's links**, the user's fix 4, are a later packet's. This packet adds no link handling.

## Budget

One behaviour — the icon, its colour and the details' indent — with its pins moved across five test files. A small-to-medium packet. If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t11-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.

## Amendment — 2026-09-26, before dispatch

T13 (PR #31) and T15 (PR #39) have merged. This section re-checks every fact above against `origin/dev` at `d86a0f9`, and where this section and the text above differ, this section holds.

### Base and baseline

- **Your base is `origin/dev` at `d86a0f9`** or later.
- **Its suite is green on both versions:** 776 cases, `Fails (0)`, on 0.12.5 and on 0.11.6 (`evidence/baseline-d86a0f9.txt`, the orchestrator's verification of the code `d86a0f9` holds). "Both versions must be green" now holds from the start.

### Facts that moved

- **`tests/test_mcp_blocked_editor.lua`:** the header pins are at lines 75, 120 and 121, not 49, 94 and 95. Line 75, `first:report_lines({ … })`, is the wait's target that IC6 names.
- **The help, `*aineo-report*`:** lines 254–317, not 253–305. The fence's first and last lines are unchanged, quoted as in *Boundary*.
  - The line and its details: 270–271.
  - *Colours*: 287–297.
  - The groups: 299–310.
  - T15 added, inside the section, what the appended instructions ask of a report. Leave it as it is.

### Facts that held

`git diff --stat dbc96c9 d86a0f9` prints nothing for each of these:
- `lua/aineo/report/render.lua`;
- `lua/aineo/report/colours.lua`;
- `tests/test_report_buffer.lua`;
- `tests/test_entry_report.lua`;
- `tests/test_report_colours.lua`.

Every line cited above for them holds. `tests/test_mcp_delivery.lua` keeps its headers at 142, 181, 229, 248 and 268, and its details pins at 249–250.

### The other packets now

- **T16** (PR #40, open) edits `*aineo-layout*`, from `3. THE LAYOUT                                                   *aineo-layout*` to ``lives in one tab; from another tab, `\o` moves you to it.``.
- **T14** runs beside you once T16 has merged, and edits the same section, `*aineo-layout*`.
- **T12** follows T14, and edits from `4. COMMANDS                                                   *aineo-commands*` to `of both (|aineo-health|).`.
- **Before you push**, run the merge check of *Boundary* against each of `origin/bugfix/t16-right-column-wrap` and `origin/feature/t14-input-draft` that exists and is unmerged. Run `test_doc.lua` on both versions.
