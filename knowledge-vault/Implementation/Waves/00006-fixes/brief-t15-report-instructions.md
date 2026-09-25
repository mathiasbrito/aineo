**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T15 | Report instructions (C6): Claude is asked to write each report for a person, in plain language — what is reported and how, never why; a plan (`started`) lists the features planned, a `done` what was done; references at the end, in parentheses, by number only — a small fix (the user, 2026-09-26) | T8 | active |

It rests on:
- **C6**: "the appended prompt tells Claude when to report". This packet adds *how to write* a report to that prompt.
- **The user's words** of 2026-09-26, under *What was decided already*.

### The behaviours — RI1 to RI4 tested, each test seen red first; RI5 and RI6 are invariants

Each is a property of the text `report_instructions()` returns (`lua/aineo/report/instructions.lua`), which aineo appends to Claude's system prompt. The wording is yours; the content is not.

- **RI1 — for a person, whats and hows.** The instructions tell Claude:
  - to write every report for a person, in plain language, describing what is being reported;
  - to say what was done or planned, and how;
  - never to explain the reasons for decisions — no whys.
- **RI2 — a plan lists its features.** When Claude reports a plan to be implemented, with status `started`, `details` lists the features planned, one per line.
- **RI3 — a `done` lists what was done.** When Claude reports `done`, `details` lists what was done — the features — one per line.
- **RI4 — references at the end, by number only.** References to documents go at the very end of the report, in parentheses, by number or ID only, with no explanation. The documents are decisions, components, tasks, issues, pull requests and docs. For example: `(D18, C12, #31)`.
  - "The very end" is the last line of `details`, or the end of `summary` when a report has no details.
  - Give the example in the instructions.
- **RI5 — the rest stands (an invariant).** These stay as they are, and every existing case of `tests/test_report.lua` › `report_instructions()` stays green unchanged:
  - the tool's name;
  - the four fields;
  - the statuses and the moment to report each (`lua/aineo/report/format.lua`, `STATUSES`, lines 9–13).
- **RI6 — nothing else changes (an invariant).** None of these changes:
  - the report format and its validation;
  - the MCP tool's schema and description (`lua/aineo/mcp/protocol.lua:32`);
  - how the Report renders a report.

  A running Claude session keeps the instructions it started with. New instructions reach Claude when aineo next starts it: the prompt is given at start (`plugin/aineo.lua:92`, `instructions = report.report_instructions(…)`).

The seam is yours under `tdd`. For example, `report_instructions()` could gain a block of lines on how to write a report, built like `field_lines()` and `status_lines()`.

### Facts, checked against `origin/dev` (`2596241`)

- **`lua/aineo/report/instructions.lua`:**
  - `field_lines()` (lines 20–30) tells `summary` "one line saying what happened", and `details` "optional further lines, such as the files you changed or the question the user must answer";
  - `status_lines()` (lines 32–39) gives each status's moment from `format.STATUSES`;
  - `report_instructions(tool_name)` (lines 41–58) joins them.
- **The pins:** `tests/test_report.lua` lines 134–170 check that the instructions:
  - name the tool;
  - name each field;
  - give each status's moment.

  `tests/test_entry.lua:18` reads `report_instructions()` as an expression and pins no text.
- **The help:** `doc/aineo.txt` › `*aineo-report*`, lines 255–257, says aineo appends "instructions … telling Claude when to call the report tool". That stops being the whole truth.

### Baseline

- `dev` at `2596241` has the same code as `dbc96c9`: `git diff --stat dbc96c9 2596241 -- lua plugin tests doc scripts Makefile` prints nothing. So `evidence/baseline-dbc96c9.txt` holds:
  - 0.11.6: 747 cases, `Fails (0)`;
  - 0.12.5: 747 cases, `Fails (8)`, the eight T13 fixes.
- If T13 (PR #31) has merged when you start, both versions are green. Otherwise 0.12.5 shows those eight and no other.
- **Run the whole suite on both versions, one at a time.** Under load, `test_send.lua`, `session_status()`, `tests/test_health.lua:336` and `tests/test_mcp_blocked_editor.lua` fail spuriously; re-run a surprising failure alone before you believe it. Check `uptime` before a whole run.
  - On the host's 0.12.5: `make test`.
  - On 0.11.6, in this literal form (the worktree guard refuses `PATH=…:$PATH make`):

    ```
    env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test
    ```

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › C6;
- `doc/aineo.txt` › `*aineo-report*`;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `bugfix/t15-report-instructions` from `origin/dev`.
- **Class:** **small fix** (the orchestrate skill, §3), called by the user on 2026-09-26 ("Right, as a small fix"). It changes one behaviour, the instructions, in `lua/aineo/report/`, with its tests.
  - If it needs a file outside *You may touch*, or reaches any of these, stop at a green, pushed state and report a true partial: `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/health.lua`, `lua/aineo/init.lua`, `plugin/aineo.lua`, `scripts/`, `tests/helpers/`, the `Makefile`.
  - Title the pull request `Small fix: tell Claude how to write a report`. No commit subject says "small" (root `CLAUDE.md`).
  - Re-run every mutant survivor on the test files the pull request adds or modifies.
- **Model:** `opus`.
- **Resources:** `impl_t15_report_instructions`.
- **You may touch:**
  - `lua/aineo/report/instructions.lua`;
  - `tests/test_report.lua`, new cases only;
  - `doc/aineo.txt`, **only inside `*aineo-report*`**: the sentence on the appended instructions, and a short description of what they ask;
  - your session note.
  - The documentation this change invalidates is that help sentence and `instructions.lua`'s docstrings. Correct them in the same change and say so in your report.
- **You must not touch:**
  - `lua/aineo/report/format.lua`, `render.lua`, `colours.lua` and every other file of the report home;
  - `lua/aineo/mcp/`, `plugin/aineo.lua`, `lua/aineo/layout/`;
  - `doc/aineo.txt` outside `*aineo-report*`. T16 edits `*aineo-layout*`, T13 `*aineo-install*`;
  - the task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note;
  - the project note;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your section** runs from its first line, `8. THE AGENT REPORT                                             *aineo-report*`, to its last, `the working directory of its own moment.`.
  - **The other packets:**
    - T16 edits from `3. THE LAYOUT                                                   *aineo-layout*` to ``lives in one tab; from another tab, `\o` moves you to it.``;
    - T13 (PR #31) edits from `2. REQUIREMENTS AND INSTALLATION                               *aineo-install*` to ``|aineo-configuration|; then run `:checkhealth aineo` (|aineo-health|).``.
    - T11, which also owns `*aineo-report*`, is dispatched only after you merge.
  - Every hunk stays inside your section.
  - **Before you push**, for each of `origin/bugfix/t16-right-column-wrap` and `origin/bugfix/t13-neovim-0-12` that exists and is unmerged:
    1. `git fetch origin && git merge-tree --write-tree <your head> <branch>`. Exit 0 and no conflict listed means clean; it prints the merged tree's id.
    2. `git show <tree id>:doc/aineo.txt > doc/aineo.txt`.
    3. `make test_file FILE=tests/test_doc.lua`.
    4. `git checkout HEAD -- doc/aineo.txt`.

    Report the results.
- **Session note:** `knowledge-vault/Sessions/<the day you are dispatched> — T15 Report instructions.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). The harness refuses writes outside your worktree. Prefix every file there with `t15-`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. You read and run its Neovim builds there, and write nothing.
- **Never run the real `claude`.**
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- **The user asked, on 2026-09-26:** "for the agent it must be clear that the report window is to report in a human language, with description of what is being reported, if it is a plan to be implemented, to list the features planned, if it is a done, to list what was done, which features, references to docs, must appear at the end between () only citing numbers. We do not want explanations about decisions and whys, the report window are the whats and how. This is just an adjustment to what should be asked to the agent in the session."
- **The orchestrator restated it** as RI1–RI4: a plan is a `started` report, its features one per line in `details`, and references are given like `(D18, C12, #31)` at the very end. The user answered "Right, as a small fix".
- **Unchanged:**
  - the other statuses keep their moments;
  - the report format;
  - the Report's rendering;
  - the tool.

## Budget

One behaviour with its tests: a small packet. If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t15-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
