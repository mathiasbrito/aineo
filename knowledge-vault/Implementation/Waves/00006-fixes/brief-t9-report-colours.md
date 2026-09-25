**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T9 | Report colours (C6): the time in `Comment`'s colour and `[status]` in a colour of its status, as highlight groups a user can override — a small fix (the user, 2026-09-25) | T8 | active |

It rests on C6 (the Report's format and rendering) and C10 (which supersedes C6's rendered line and colours the icon like the status — a later packet, T11, adds the icon; this packet adds no icon and does not change a line's text).

### The behaviours — one test each, each seen red first

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
- **RC4 — a user's colours win, and survive a colour scheme.** The groups are defined as defaults (`default = true`), so a user's own `:highlight` of a group, or a colour scheme that defines it, wins. They are still linked after `:colorscheme` changes the scheme.
- **RC5 — every path shows them.** Reports shown again from the saved records when the Report opens get the same colours as a report that arrives while it is open.
- **RC6 — the text is unchanged.** Every line's text is what it was: the existing tests of the rendered lines stay green unchanged.
- **RC7 — nothing at startup.** Loading aineo defines no highlight group and adds no autocommand. The frozen pins `tests/test_plugin.lua` › *loads the configuration alone in a headless start* and *defines :Aineo, its <Plug> mappings, the prefix mappings and, once started, the StdinReadPost autocommand alone* stay as they are and green. The groups are defined when the Report first shows a report, or later.

The seam is yours under `tdd`. For example, the render could return its highlight spans beside its lines, where the `HH:MM` and `[status]` columns are known, rather than matching the text afterwards (RC3).

### Facts, checked against `origin/dev` (`9af91a6`)

- `lua/aineo/report/render.lua` › `M.render_report(report, time)` builds the header as `('%s [%s] %s — %s'):format(time:sub(12, 16), report.status, …)`, and indents details by `DETAILS_INDENT`, the width of `'HH:MM '`.
- `lua/aineo/report/buffer.lua` › `M.append_lines(buffer, lines)` writes lines. `lua/aineo/report/init.lua` renders saved records in `show_records()` (around its line 105) and a new report around its line 169.
- Saved reports are kept as JSON records (`lua/aineo/report/records.lua`, `vim.json.encode(record)`), rendered each time they are shown. So colours apply to old reports too.
- `git grep -n -E "nvim_set_hl|ColorScheme" origin/dev -- lua plugin` prints nothing: aineo defines no highlight group today.
- The Report's tests that name the rendered text are `tests/test_report_buffer.lua`, `tests/test_entry_report.lua`, `tests/test_mcp_delivery.lua` and `tests/test_mcp_blocked_editor.lua` (`git grep -l`). The last two belong to T13 in this wave.

### Baseline

- **On 0.11.6** (D10's minimum): the code at `9af91a6` is identical to `a9f8027`, which ran 727 cases, `Fails (0)` (the wave-5 verification).
- **On 0.12.5**, the host's `nvim` since 2026-09-25: 727 cases, `Fails (8)` (`evidence/baseline-0.12.5.txt`). None of the eight is yours; T13 fixes them in parallel.
- **So run the whole suite on both versions:**
  - with `<scratchpad>/nvim-0.11.6/nvim-macos-arm64/bin/nvim` first on `PATH`, where it must be green;
  - with the host's 0.12.5, where it must show those eight failures and no other.

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
- **The help is shared under rule 2's section exception.** Before you push, re-run the merge check against each branch that exists of T13 and T12: `git fetch origin && git merge-tree --write-tree <your head> origin/bugfix/t13-neovim-0-12`, and likewise with `origin/feature/t12-claude-numbers` (exit 0 and no conflict listed means clean). Report the result.
- **Session note:** `knowledge-vault/Sessions/2026-09-25 — T9 Report colours.md`.
- **Scratch prefix:** `t9-`, under `<scratchpad>` — the orchestrator's scratch directory, which your dispatch message names.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- The user asked for "Time as comment color, [<status/state>] some color" (2026-09-25).
- The user called this a small fix ("Small fixes where allowed").
- The colour of each status (RC2) is the orchestrator's reading, for the user to confirm. Name it in your session note's *Readings for the MVP review*.
- The icon at the line's start is C10 and packet T11, which is not yours.

## Budget

One behaviour with its tests: a small packet. If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t9-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
