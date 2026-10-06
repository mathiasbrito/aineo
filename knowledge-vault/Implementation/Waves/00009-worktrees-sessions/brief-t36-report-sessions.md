**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> **Awaits the converge round.** Written with the recommended options of [[Planning/aineo — worktrees and session switches]] › P9 (a) with history (i), and P10 (b) — so the draft is **not** in this packet. It is not dispatched until the user has answered the round and the agreed rows are D39 and D40 in the v1 plan note, M5 is measured, and wave 8's T34 has merged (both change `lua/aineo/report/`). Under P10 (a) the amendment adds `lua/aineo/draft/` and *aineo-draft* to this packet, and gives the behaviour.

## Objective

The task, verbatim from the task list:

> | T36 | The Report per session (C6; P9 once agreed, and P10 under its option (a)): reports are kept per Claude session id, a report under the session aineo follows when it arrives, and the Report can be shown for another session; the working directory's records become the session kept for it — the behaviour awaits the converge round | T5, wave 8's T34, the round | planned — wave 9 |

It rests on: C6 (the report's format, rendering and records, "persisted under `stdpath('state')`"), C14 (the Report line), D8 (reports through the MCP tool), D17 (Input's draft per directory, unchanged under P10 (b)), D26 and D29; and P9's alternatives.

### The behaviour, under the recommended options (awaits the converge round)

- **One records file per Claude session**, under the same `stdpath('state')/aineo/reports/` folder as today, named so that no session id can make an invalid or colliding name (today's files are named by a SHA-256; keep a scheme of that kind, and say which in the help).
- **The report home follows a session.** A new entry point (its name is yours) tells the home which session's records the Report shows and keeps reports under: it shows that session's records in the Report, in place of what it showed, and keeps every report received from then on in that session's file. A session with no records yet shows an empty Report. Following the session already followed changes nothing (the Report's lines, its cursor and its windows stay).
- **Before the home is told any session**, it keeps and shows the working directory's records exactly as today. Nothing in this packet calls the new entry point: T39 wires it to the composition root once T35 says which session Claude Code is on. So `dev` behaves as before when this packet merges.
- **History, (i):** the first time the home follows a session in an editor, when the working directory's records file exists and that session has none, the directory's file **becomes** the session's (moved, not copied), so every report shown today stays shown, with that session. When both exist, neither is touched, and the session's are shown. A move that fails is told once as a warning, as the home tells a records failure today, and the session's file is used from then on.
- **A report is kept under the session followed when it arrives** — Claude Code's MCP server cannot say which session sent it (B2; M5 measures whether it is even the same server process after a switch).
- **What stays:** the records' format (`{ time, report }`), the 2 MiB shown and the cut at 4 MiB (`RECORDS_KEPT_BYTES`), the owner-only permissions, the rendering, links, paths and colours (T10, T17, T18, and T34's layout).

### Facts, checked against `origin/dev` `9b8707f` (re-checked after T34 merges)

- `lua/aineo/report/records.lua`:
  - `M.records_file(state_directory, working_directory)`, lines 30–37: `<state>/aineo/reports/<sha256(working_directory)>.jsonl`;
  - `RECORDS_KEPT_BYTES`, line 21, 2 MiB; `OWNER_ONLY`, line 15;
  - `M.append_record()`, line 170; `M.read_records()`, line 215.
- `lua/aineo/report/init.lua`:
  - `aineo.report.Environment`, lines 15–18: `clock`, `state_directory`, `working_directory`;
  - `M.set_report_environment()`, lines 51–57;
  - `report_view`, line 25: `{ buffer, records_file }`, chosen once in `M.report_buffer()`, lines 244–255;
  - `show_records()`, lines 209–218, and `open_report_buffer()`, lines 226–232, which shows the records again when the user `:edit`s the Report;
  - `show_and_keep()`, lines 267–280, appends to `report_view.records_file`.
- `plugin/aineo.lua` › `give_report_environment()`, lines 159–171: the working directory of `kept_places()` (lines 148–152), the first one, for the editor's life. This packet does not change it.
- Tests that pin the records' place: `tests/test_entry_report.lua` line 109 (the file named by the directory's SHA-256, under `nvim/aineo/reports/`), and `tests/test_report_buffer.lua`'s group `the records`, from line 605 (`records_file_holding()` at line 631, the cut, the permissions, a folder that cannot be written). They stay true before the home follows a session.
- `doc/aineo.txt` › *aineo-report*'s last paragraph, `Reports are kept per working directory, under \`stdpath('state')\` in` … `the working directory of its own moment.` (as T34 leaves it — the amendment quotes it).
- **B2** (`evidence/w9-probes.txt`): Claude Code 2.1.281's MCP messages carry no session id.

### Baseline

On `9b8707f`, Neovim 0.12.5: 1807 cases, `Fails (0)` (`Implementation/Waves/00008-small-fixes/evidence/baseline-9b8707f.txt`). Among them: `tests/test_report.lua` 55, `tests/test_report_buffer.lua` 67, `tests/test_report_paths.lua` 90, `tests/test_report_links.lua` 83, `tests/test_report_colours.lua` 64, `tests/test_mcp_delivery.lua` 25, `tests/test_entry_report.lua` 4, `tests/test_doc.lua` 44. Wave 8's T34 changes several; the dispatch message pastes the counts on the `dev` you start from.

Read first: the v1 plan note's C6, C14, D8, D17 and the D rows the round adds (D39, D40); [[Planning/aineo — worktrees and session switches]] › P9, P10; `knowledge-vault/Projects/aineo.md`; `Sessions/2026-09-24 — T5 report channel.md`; T34's session note once merged; `plan.md` and `evidence/w9-probes.txt` in this folder.

## Boundary

- **Branch:** `feature/t36-report-sessions` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t36_report_sessions` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/report/records.lua` and `lua/aineo/report/init.lua`; `tests/test_report.lua`, `tests/test_report_buffer.lua` where a records case must change, `tests/test_entry_report.lua` only if its pin must change (it should not), a new `tests/test_report_sessions.lua`; `doc/aineo.txt` inside the fence below; your session note.
- **You must not touch:** `plugin/aineo.lua` (T35's and T39's); every other file under `lua/`, `plugin/`, `scripts/` and `tests/` — `lua/aineo/draft/` and `tests/test_draft.lua` included under P10 (b), `tests/test_doc.lua` (run it); T35's files (`lua/aineo/claude/`, `tests/helpers/fake_claude.lua`, `tests/test_claude*.lua`) and T37's (`lua/aineo/changes/`, `tests/test_changes*.lua`); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`. Yours: *aineo-report*'s last paragraph, from `Reports are kept per working directory, under \`stdpath('state')\` in` to `the working directory of its own moment.` — say what is kept per session, the history's move, and that until the session is followed the working directory's records are shown. T35 owns *aineo-claude-session* and a new LIMITS subsection after `Stopping Claude Code on quit ~`; T37 owns *aineo-changes*'s first paragraph and one LIMITS item. Before you push, merge with each of their branches that exists (`git merge-tree --write-tree <your head> origin/feature/t35-session-switch`, the same for `origin/feature/t37-changes-sessions`), run `make test_file FILE=tests/test_doc.lua` on each merged tree, and report both.
- **Session note:** `knowledge-vault/Sessions/<date> — T36 Report per session.md`, with a `## Task lines` section.
- **Scratch prefix:** `t36-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5 only; the test files you touch and the baseline table's while you work; the whole suite once before each push; mutants on their covering files. Never the real `claude`.
- **Modularity:** `aineo.report` keeps requiring `aineo.config` alone (`.claude/skills/modularity/SKILL.md`). It learns of a session by being told, never by requiring `aineo.claude`.

## The tests

Each behaviour gets one test, seen failing first:
- following a session shows that session's records and keeps the next report there;
- following another session replaces the Report's lines with that session's, and a report then lands in the new session's file only;
- following the session already followed leaves the Report's lines and cursor as they were;
- a session with no records shows an empty Report;
- the first follow moves the directory's records to the session; a later follow of another session moves nothing; when both files exist, neither is touched;
- a move that fails warns once, and the session's file is used;
- before any follow, the records are the directory's, as `tests/test_entry_report.lua` pins;
- a Report wiped and made again (`report_buffer()`) shows the followed session's records, not the directory's.

The verification runs the plan's five mutants for T36. Name in your report the test that kills each.

## What was decided already

- The user's request, 2026-10-06, and the user's answers to P9 and P10, which the amendment gives.
- C6's report format and the 2 MiB bound stand.

## Budget

Medium: a records file chosen by session, one entry point that swaps what the Report shows, a one-time move, about eight cases and a help paragraph. If it grows past that, stop at a green, reviewed, pushed state and report.

## Report

In your definition's shape, to `<scratchpad>/t36-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the test files that ran and the whole suite's counts.
