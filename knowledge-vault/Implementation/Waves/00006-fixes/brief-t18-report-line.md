**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T18 | Report line without the icon (C14, D24): `HH:MM [status] task — summary`, `[status]` bold in its status's colour, the details under the `[status]` — a small fix, over the orchestrator's stated concern that it needs a new row (the user, 2026-09-26) | T10 | active |

It rests on D24 and C14, which supersede C10, and on the user's words of 2026-09-26 (*What was decided already*).

### The behaviours — RL1 to RL3 tested, each test seen red first; RL4 and RL5 are invariants

- **RL1 — no icon.** A report's header is `HH:MM [status] task — summary`: it starts with the time, and no icon shows anywhere a report is drawn. The details start under the `[status]`'s `[`, six cells in (`HH:MM ` is six ASCII cells), for every status, whatever `'ambiwidth'` or `setcellwidths()` say.
- **RL2 — `[status]` bold, in its status's colour.** `[status]`, brackets included, shows bold, in the colour of its status's group (`colours.STATUS_GROUPS`), on every drawing path: a report received, the Report opened on saved records, `:edit` in the Report, the Report made anew after `:bdelete`, `:bwipeout` or `:bunload`.
  - **The status's colour wins over the bold's.** Whatever colour a user or a colour scheme gives the bold's group, or the group it links to, `[status]` keeps its status group's colour. Test it on the screen with a foreground given to that group. Measured on both versions (`evidence/report-line-bold.txt`): a second mark at the same priority placed after the status's mark (A2s), or above it (A2, priority 4097), shows the bold group's colour; placed before it (A2t), or below it (A3, priority 4095), it shows the status's colour. `buffer.append_rendering()` places every colour at the default priority, in the order `render.lua` lists them, so the natural edit, appending the bold after the status's colour in `header_colours()`, is A2s. On Neovim's default colours `@markup.strong` has no foreground, so only a test that gives it one sees the difference.
  - **Measure it on the screen,** not in the extmarks or the groups' definitions alone. mini.test's child has no UI, and needs none; attaching one from the test's Neovim killed the channel (the brief review). Read a cell in the child with `vim.api.nvim__inspect_cell(1, row, col)`, an internal API: its second element holds `foreground` (RGB) and `bold`. Cells read in the same request as its first call in a child decode wrongly, and reads after a redraw are right (measured on both versions): make one call you discard, run `:redraw`, then read. `child.get_screenshot()`'s attributes are codes that compare two cells; they name no colour and no bold. `nvim_get_hl()` reports `bold` on a group linked with `nvim_set_hl(…, { link = …, bold = true })`, which draws no bold. Say in your note how your test reads the cells.
  - **A user's colour still wins, and bold stays removable.** A user's or a colour scheme's colour for a status group still shows on `[status]`, bold; `:highlight clear` brings back the default link, bold. A user can turn the bold off without losing the status's colour. The brief review measured every mechanism on the screen, on both versions (`evidence/report-line-bold.txt`):
    - `nvim_set_hl` with `link` and `bold` together draws no bold: the link wins (B1);
    - `:highlight default` with attributes (`gui=bold`) loses the bold at `:highlight clear`, until the Report shows reports again (A9b, A9c);
    - `hl_mode` changes nothing for `hl_group` (A10);
    - one mark whose `hl_group` is a list draws right, but `nvim_buf_get_extmarks(…, { details = true })` reports only its last group (D1);
    - **a group of its own, defined as T9's are (`:highlight default link`), linked to `@markup.strong`, and drawn beneath the status's colour, meets every clause** (A1, A3–A7, A2t): its bold survives `:highlight clear` (A5), and `:highlight AineoReportStatusBold gui=NONE cterm=NONE` or `:highlight link AineoReportStatusBold NONE` turns the bold off, the colour kept, through aineo's next definition (A6, A7).

    So the bold is **`AineoReportStatusBold`**, `:highlight default link AineoReportStatusBold @markup.strong`, listed in the help as `*hl-AineoReportStatusBold*` beside T9's groups. On both versions, the built-in groups that are bold and nothing else are `@markup.strong`, `CursorLineNr`, `PmenuMatch`, `PmenuMatchSel` and `TabLineSel`; only `@markup.strong` means strong text, and colour schemes commonly colour the others. How the marks are laid, by priority or by order, is yours under `tdd`.
- **RL3 — the time and nothing else changes colour.** The time stays in `AineoReportTime`; the task, the summary and the details show in no group, apart from T10's links (`AineoReportLink`).
- **RL4 — T10's links stay whole (an invariant).** Every link keeps its `url` and its group. Its columns move with the text: a link in the header starts four bytes earlier (the icon and its space are gone), a link in the details two cells earlier (the indent is 6, not 8). `tests/test_report_links.lua`'s rows assert columns counted from the old indent and header: move them, and keep every row's text and url as it is. RL1–RL5 of T10's brief hold on the moved columns.
- **RL5 — nothing else changes (an invariant).** The Report follows the newest report; the saved records are unchanged (`format.lua`, `records.lua`); the report format and the report tool are unchanged.

The seam is yours under `tdd`. T11 put the icon in `render_report()` (`lua/aineo/report/render.lua:125–142`, `STATUS_ICONS` at `:21`) and its colour in `header_colours()` (`:72–92`); `details_indent()` (`:60–62`) measures the prefix with `nvim_strwidth()`, which stays right for an ASCII prefix.

### Facts, checked against `origin/dev` (`d30ff4d`)

- **The pins over the old line.** The brief review removed the icon from `render.lua` and ran each file alone on 0.12.5. Cases failing: `test_report_buffer.lua` 40, `test_report_colours.lua` 17, `test_report_links.lua` 63 (the `gx` rows not among them), `test_entry_report.lua` 2, `test_mcp_blocked_editor.lua` 2, `test_mcp_delivery.lua` 5, `test_report.lua` 0. The icon or its indent is asserted in:
  - `tests/test_report_buffer.lua`: 38 lines with an icon; `EVERY_STATUS_FAULTS` (`:219–246`), whose pattern `'^[^%s%d]+ %d%d:%d%d %['` requires an icon, and its case's name, "shows with an icon"; `REPORT_HEADERS`' docstring (`:643–645`), "a header starts with its icon", which stays green but goes false; T11's width cases (`'ambiwidth'` `double`, mixed widths in both orders, the narrow wrapping window, the Report made anew).
  - `tests/test_report_colours.lua`: every time and status span, each 4 bytes earlier (`:78`, `:100–104`, `:127`, `:142–146`, `:159–163`, `:175–182`, `:209–212`, `:248–251`); the set `the icon` (`:81–105`) and the case names that say "icon". `REPORT_COLOURS` (`:25–31`) lists every extmark of every namespace, so a second mark for the bold adds a row per header.
  - `tests/test_report_links.lua`: every row's columns, counted from the indent 8 and the header's icon. In `REPORT_MARKS`' case (`:132–147`), the row `{ 0, 0, 3, 'AineoReportDone', vim.NIL }` is the icon's own mark: delete it; rename the case, which names the icon; add a row for the bold's mark. **The `gx` rows (`:399–411`) move too, each column 2 earlier:** left as they are they stay green, with the cursor two bytes inside each link (measured: 5 of 5 pass with the icon removed).
  - `tests/test_entry_report.lua`: `REPORT_LINES` (`:13–16`), whose pattern `'^(%S+ )%d%d:%d%d '` only matches after an icon, and whose docstring says the time "follows the icon"; left as it is, `:48` fails on the real local time, not on the icon. And `:48`, `:70`.
  - `tests/test_mcp_blocked_editor.lua:76–77` and `:123–124`; `tests/test_mcp_delivery.lua:142`, `:181`, `:229`, `:248–250` (the two details lines at `:249–250` carry the 8-space indent) and `:268`.
- **The help:** `doc/aineo.txt` › `*aineo-report*`:
  - lines 315–316, the example: `<icon> HH:MM [status] task — summary`, its details line indented 17, under the `[status]` after `<icon> `; it becomes 10;
  - lines 318–319 name the icons;
  - lines 320–324, the whole sentence from "The details start under the `[status]` however wide the icon shows" to "…or the Report made anew after you delete it.", goes false: with an ASCII prefix the indent never changes. "The Report follows the newest report." stays;
  - *Colours* (`Colours ~`, line 353): the Report shows "the icon and the `[status]`" in the group of its status (lines 354–355);
  - the status groups' entries (lines 368–377) name each icon.
  - **If T20 has merged,** find these lines by their text: T20 adds 6 lines above the section.
- **The readings the user kept,** now moot: MR102 (the indent by the icon's width) is marked "moot once T18 lands" in `knowledge-vault/Review/2026-09-24 — v1 MVP readings review.md`.

### Baseline

- `dev` at `d30ff4d`, T10 merged: 973 cases, `Fails (0)`, on 0.12.5 and 0.11.6 (`evidence/baseline-d30ff4d.txt`, the orchestrator's verification of PR #52, whose tree has the same code). If T20 (PR #58, under review; it may merge while you work) merges before you start, re-measure the baseline on your base.
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
  - `doc/aineo.txt` outside `*aineo-report*`. T20 (PR #58) edits the introduction's summary sentence and `*aineo-commands*`;
  - the task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note;
  - the project note, the MVP readings review;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your section** runs from its first line, `8. THE AGENT REPORT                                             *aineo-report*`, to its last line of text, `the working directory of its own moment.`.
  - **The other packet:** T20 edits the introduction's sentence from ``Every command sits behind one prefix key, `\` by default, in Normal mode:`` to ``and `\c` move to the Report, Input and Claude.``, and `*aineo-commands*`' entry from `*:Aineo-claude*` to ``:Aineo claude		Moves the cursor to Claude's terminal.``.
  - Every hunk stays inside your section.
  - **Before you push**, for `origin/bugfix/t20-claude-terminal-mode` if it exists and is unmerged:
    1. `git fetch origin && git merge-tree --write-tree <your head> origin/bugfix/t20-claude-terminal-mode`; report any conflict it prints, in any file;
    2. `git show <tree id>:doc/aineo.txt > doc/aineo.txt` and `git show <tree id>:tests/test_doc.lua > tests/test_doc.lua`;
    3. `make test_file FILE=tests/test_doc.lua`, on both versions;
    4. `git checkout HEAD -- doc/aineo.txt tests/test_doc.lua`.

    Report the results. If T20 has merged, the rebase onto `dev` takes the check's place: say so.
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
  - the bold can be turned off apart from the colour (RL2);
  - the bold is a group of its own, `AineoReportStatusBold`, linked by default to `@markup.strong`, the only built-in group that is bold and nothing else and means strong text. So a colour scheme's style for Markdown bold — its background, italic, underline, or bold turned off — also styles `[status]`'s bold; its colour does not, since the status's colour wins (RL2).

## Budget

One behaviour, with many pins to move: a small packet with a wide test diff. If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t18-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
