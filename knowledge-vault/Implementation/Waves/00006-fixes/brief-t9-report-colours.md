**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T9 | Report colours (C6): the time in `Comment`'s colour and `[status]` in a colour of its status, as highlight groups a user can override — a small fix (the user, 2026-09-25) | T8 | active |

It rests on C6, the Report's format and rendering. C10 is context only: it supersedes C6's rendered line and colours the icon like the status. A later packet (the icon, C10) adds the icon; this packet adds no icon and does not change a line's text.

### The behaviours — RC1 to RC5 one test each, each seen red first; RC6 and RC7 are invariants

- **RC1 — the time.** In every Report line that starts a report, the `HH:MM` is shown in the highlight group `AineoReportTime`, which links by default to `Comment`.
- **RC2 — the status.** The `[status]`, brackets included, is shown in a group of its status:

  | status | group | default link |
  |---|---|---|
  | `started` | `AineoReportStarted` | `DiagnosticInfo` |
  | `progress` | `AineoReportProgress` | `DiagnosticHint` |
  | `blocked` | `AineoReportBlocked` | `DiagnosticWarn` |
  | `done` | `AineoReportDone` | `DiagnosticOk` |
  | `failed` | `AineoReportFailed` | `DiagnosticError` |

- **RC3 — only what the render placed.** The colours cover exactly the columns the render wrote the time and the status into. A task, summary or details line that contains text like `[done]` or `12:34` gets no colour.
- **RC4 — a user's colours win, and survive a colour scheme.** The groups are defined as defaults (`default = true`).
  - A user's `:highlight`, or a colour scheme's, made before the Report first shows a report, wins.
  - After `:colorscheme` switches to a scheme that does not define a group, the group is linked to its default again. That includes a group the earlier scheme had defined before aineo first defined it.
  - Measured by the brief review on 0.11.6 and 0.12.5: a default link aineo sets first survives `:colorscheme` and `:highlight clear` without being defined again. So only a test in which a scheme defined the group *before* aineo's first definition, then a scheme without it is loaded, shows whether aineo defines the groups again.
- **RC5 — every path shows them.** A report that arrives while the Report is open is coloured. So are reports shown again from the saved records, both when the Report opens and when `:edit` in the Report empties it and `BufReadCmd` fills it again through `show_records()` (`lua/aineo/report/buffer.lua`, lines 41–61). No refill leaves stale colour behind.
- **RC6 — the text is unchanged (an invariant).** Every line's text is what it was: the existing tests of the rendered lines stay green unchanged. Show that they can fail: a mutant that changes one character of the rendered header turns them red.
- **RC7 — nothing at startup.** Loading aineo defines no highlight group and adds no autocommand. The frozen pins `tests/test_plugin.lua` › *loads the configuration alone in a headless start* and *defines :Aineo, its <Plug> mappings, the prefix mappings and, once started, the StdinReadPost autocommand alone* stay as they are and green. The groups are defined when the Report first shows a report, or later. This is an invariant, green on `dev` today. Show that its pins can fail: a mutant that defines the groups at `require('aineo.report')`, or in `plugin/aineo.lua`, turns a pin red.

The seam is yours under `tdd`. For example, the render could return its highlight spans beside its lines, where the `HH:MM` and `[status]` columns are known, rather than matching the text afterwards (RC3).

### Facts, checked against `origin/dev` (`9af91a6`)

- `lua/aineo/report/render.lua` › `M.render_report(report, time)` builds the header as `('%s [%s] %s — %s'):format(time:sub(12, 16), report.status, …)`, and indents details by `DETAILS_INDENT`, the width of `'HH:MM '`.
- `lua/aineo/report/buffer.lua` › `M.append_lines(buffer, lines)` writes lines. `lua/aineo/report/init.lua` renders saved records in `show_records()` (around its line 105) and a new report around its line 169.
- Saved reports are kept as JSON records (`lua/aineo/report/records.lua`, `vim.json.encode(record)`), rendered each time they are shown. So colours apply to old reports too.
- `git grep -n -E "nvim_set_hl|ColorScheme" origin/dev -- lua plugin` prints nothing: aineo defines no highlight group today.
- The Report's tests that name the rendered text are `tests/test_report_buffer.lua`, `tests/test_entry_report.lua`, `tests/test_mcp_delivery.lua` and `tests/test_mcp_blocked_editor.lua` (`git grep -l`). The last two belong to T13 in this wave.

### Baseline

- **On 0.11.6** (D10's minimum), the downloaded build: 727 cases, `Fails (0)` at `9af91a6` (`evidence/baseline-0.11.6.txt`).
- **On 0.12.5**: 727 cases, `Fails (8)`, measured on the downloaded 0.12.5 build (`evidence/baseline-0.12.5.txt`). The brief review reproduced the eight on the host's Homebrew 0.12.5, file by file. None of the eight is yours; T13 fixes them in parallel.
- **So run the whole suite on both versions:**
  - **On 0.11.6, where it must be green.** Put the downloaded build first on `PATH` in this literal form; the worktree guard refuses `PATH=…:$PATH make`:

    ```
    env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test
    ```

    Children started through `vim.v.progpath` then run 0.11.6 too.
  - **On the host's 0.12.5**, where it must show those eight failures and no other.

  Report both counts.

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › C6 and C10;
- `doc/aineo.txt` › `*aineo-report*`;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `bugfix/t9-report-colours` from `origin/dev`.
- **Class:** **small fix** (the orchestrate skill, §3), called by the user on 2026-09-25: "Small fixes where allowed", for the Report's colours. It changes one behaviour, the Report's colours, in `lua/aineo/report/` with its tests.
  - If it needs a file outside *You may touch*, or reaches `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/health.lua`, `lua/aineo/init.lua`, `plugin/aineo.lua`, `scripts/`, `tests/helpers/` or the `Makefile`, stop at a green, pushed state and report a true partial.
  - Title the pull request `Small fix: colour the Report's time and status`. No commit subject says "small" (root `CLAUDE.md`).
  - Re-run every mutant survivor on the test files the pull request adds or modifies.
- **Model:** `opus`.
- **Resources:** `impl_t9_report_colours`.
- **You may touch:**
  - `lua/aineo/report/`, including a new file there;
  - `tests/test_report_buffer.lua`, `tests/test_entry_report.lua`, or a new `tests/test_report_colours.lua`;
  - `doc/aineo.txt`, **only inside the `*aineo-report*` section** — the colours and the six groups, with a tag for each (`*hl-AineoReportTime*` and so on). The help's `CONTENTS` and every other section stay as they are.
  - your session note.
  - The documentation this change invalidates is `doc/aineo.txt` › `*aineo-report*`. Correct it in the same change and say so in your report.
- **You must not touch:**
  - `plugin/aineo.lua`, `lua/aineo/layout/`, `lua/aineo/health.lua`, `lua/aineo/mcp/`, `lua/aineo/claude/`, `tests/test_plugin.lua`, `tests/test_health.lua`, `tests/test_mcp_delivery.lua`, `tests/test_mcp_blocked_editor.lua`, `tests/helpers/`, and `doc/aineo.txt` outside `*aineo-report*`. T13 and T12 own these in this wave. T13's help edit sits under `*aineo-install*`; T12's sit under `*aineo-commands*`, `*aineo-mappings*` and `*aineo-keys*`.
  - The task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note instead.
  - The project note.
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your section** runs from its first line, `8. THE AGENT REPORT                                             *aineo-report*` (line 253 at `9af91a6`), to its last, `the working directory of its own moment.` (line 280).
  - **The other packets:** T13 edits the section from `2. REQUIREMENTS AND INSTALLATION                               *aineo-install*` to ``|aineo-configuration|; then run `:checkhealth aineo` (|aineo-health|).`` (lines 36–48). T12, dispatched after T13's merge, edits `4. COMMANDS …*aineo-commands*` to `of both (|aineo-health|).` (lines 89–177).
  - Every hunk stays inside your section.
  - **Before you push:** merge with each branch that exists — `git fetch origin && git merge-tree --write-tree <your head> origin/bugfix/t13-neovim-0-12`, and likewise with `origin/feature/t12-claude-numbers` (exit 0 and no conflict listed means clean). Then run `make test_file FILE=tests/test_doc.lua` on the merged `doc/aineo.txt`, which catches a tag both sides added (E154). Report both results.
- **Session note:** `knowledge-vault/Sessions/2026-09-25 — T9 Report colours.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). The harness refuses writes outside your worktree. Prefix every file there with `t9-`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. You read and run its Neovim builds there, and write nothing.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- The user asked for "Time as comment color, [<status/state>] some color" (2026-09-25).
- The user called this a small fix ("Small fixes where allowed").
- The colour of each status (RC2) is the orchestrator's reading, for the user to confirm. Name it in your session note's *Readings for the MVP review*.
- The icon at the line's start is C10, a later packet's, not yours.

## Budget

One behaviour with its tests: a small packet. If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t9-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
