**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, and `.claude/agents/neovim-claude-code-integrator.md` for the session it wires.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> **Awaits the converge round, and stage 1.** Written with the recommended options of [[Planning/aineo — worktrees and session switches]] › P7 (a), P9 (a), P10 (b) and P11 (a). It is not dispatched until the user has answered the round (D37, D39–D41 in the v1 plan note), M6 is measured, and T35, T36 and T37 have merged: it wires what they build. The entry points they add are named by their pull requests; the amendment before dispatch names them, gives the line numbers of `plugin/aineo.lua` as T33 and T35 leave it, and quotes the help's fence.

## Objective

The task, verbatim from the task list:

> | T39 | The panes follow a session switch (C1, C12; P7–P11 once agreed): when Claude Code switches session, the composition root shows that session's Report and changes pane — and its draft under P10 (a) — whichever pane is shown | T35, T36, T37 | planned — wave 9 |

It rests on: C1 (the composition root wires the homes), C12 and D18 (the panes; D18's PD3: a report that arrived while hidden shows when `\pa` brings the Report back), D21 (`\o` keeps the pane), C3 as T35 leaves it, C6 as T36 leaves it, C15 as T37 leaves it; the D rows the round adds (D37–D41); wave 8's T33 (the status line follows Claude Code's terminal title); D26 and D29.

### The behaviour, under the recommended options (awaits the converge round)

- **At every start of Claude Code**, the composition root tells the report home and the changes home the session Claude Code starts on (T35's "which session"), so the Report shows that session's reports (T36) and the changes pane that session's base and marks (T37). The first start in an editor moves the directory's reports to that session (T36's history move).
- **At a switch** (T35's callback, with the new id and its source): the same two calls with the new session. Whichever pane is shown, the shown windows show the new session's content at once; the hidden pane shows it when it is next shown (`\pa`, `\pc`, `\o`, a layout built anew), as D18's PD3 and the changes pane's re-read on showing already do.
- **Input** is not touched (P10 (b)): the draft stays the directory's. Under P10 (a) the amendment adds the draft swap.
- **The status line** (T33) follows Claude Code's terminal title by itself; this packet adds nothing to it. M6 says what the title is after an in-session `/resume` and after `/clear`; if it does not name the new session, the help says so.
- **Nothing happens** for a `SessionStart` of the session already followed (T35 calls nothing back), while Neovim quits, or before the layout has ever opened (the homes are told, the windows do not exist yet).
- **The help** says that aineo follows a switch made inside Claude Code, what follows it (Report, changes pane, the session resumed next), what does not (Input's draft), and where hooks do not run (T35's LIMITS subsection), in *aineo-claude-session*'s paragraph T35 wrote.

### Facts, checked against `origin/dev` `9b8707f` (re-checked after T33, T35, T36 and T37 merge)

- `plugin/aineo.lua`:
  - `kept_places()`, lines 148–152; `give_report_environment()`, lines 159–171; `keep_input_draft()`, lines 180–187;
  - `started_claude_terminal()`, lines 211–234: starts the session, hands `on_terminal_replaced`, then calls `aineo.changes`' `begin_session()` (lines 227–232). T33 and T35 change it;
  - `changes_pane()`, lines 256–260 (`refresh_shown_pane()`, then `pane_buffers()`); `arrangement()`, lines 271–279; `open()`, 286–290; `focus()`, 303–313; `show_pane()`, 323–336.
- `lua/aineo/changes/init.lua` › `M.refresh_shown_pane()`, line 541: reads both lists again while either buffer is shown.
- Tests through the entry point that start the fake Claude Code: `tests/helpers/entry.lua` (`use_fake()`), `tests/helpers/claude_session.lua` (`fake()`, `wait_for_status()`); `tests/test_entry_claude_resume.lua` (11 cases), `tests/test_entry_report.lua` (4), `tests/test_entry_changes.lua` (12), `tests/test_entry_panes.lua` (86). T35 teaches the fake to run a `--settings` hook on keys standing for `/clear` and `/resume <id>`.
- [[Learnings/A test child that quits with aineo's Claude Code running waits 4.4 s for the stop by keys]]: end each child's terminals before it quits, as `tests/test_entry_panes.lua` does since T25.

### Baseline

On `9b8707f`, Neovim 0.12.5: 1807 cases, `Fails (0)` (`Implementation/Waves/00008-small-fixes/evidence/baseline-9b8707f.txt`). Every file above changes before this packet runs; the dispatch message pastes the counts on the `dev` you start from.

Read first: the v1 plan note's C1, C3, C6, C12, C15, D18, D21, D23 and the D rows the round adds; [[Planning/aineo — worktrees and session switches]] › P7–P11; `knowledge-vault/Projects/aineo.md`; the session notes of T33, T35, T36 and T37; `Sessions/2026-10-05 — T24 Panes.md`; `plan.md` in this folder.

## Boundary

- **Branch:** `feature/t39-panes-follow-switch` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t39_panes_follow_switch` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `plugin/aineo.lua` — the switch's wiring in `started_claude_terminal()` and what it calls; **not** the autostart (`start_up` and what it reaches); a new `tests/test_entry_session_switch.lua`; `tests/test_entry_claude_resume.lua`, `tests/test_entry_report.lua` and `tests/test_entry_changes.lua` where a case must change (name each in your report); `doc/aineo.txt` inside the fence below; your session note.
- **You must not touch:** every file under `lua/` — a home that lacks what the wiring needs is a spec conflict for your report, not a change here; `tests/helpers/` (the fake is T35's); every other file under `scripts/` and `tests/`, `tests/test_doc.lua` included (run it); T38's files (`lua/aineo/git/`, `lua/aineo/changes/`, `tests/test_git_worktrees.lua`, `tests/test_changes*.lua`), which run at the same time; the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`. Yours: the paragraph of *aineo-claude-session* on switches that T35 wrote (the amendment quotes its first and last line). T38 owns *aineo-changes* from `The files window, \`aineo://changes-files\`, lists every file that differs` to `windows say so until the pane is shown again, which starts it again.`, and LIMITS › `The changes pane ~`. Before you push, merge with its branch if it exists (`git merge-tree --write-tree <your head> origin/feature/t38-changes-worktrees`), run `make test_file FILE=tests/test_doc.lua` on the merged tree, and report it.
- **Session note:** `knowledge-vault/Sessions/<date> — T39 Panes follow switch.md`, with a `## Task lines` section.
- **Scratch prefix:** `t39-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5 only; the test files you touch and the entry suites above while you work; the whole suite once before each push — `plugin/aineo.lua` is the composition root every entry suite loads; mutants on their covering files. Never the real `claude`.

## The tests

Each behaviour gets one test, seen failing first, through the entry point with the fake Claude Code:
- after a start, a report lands in the started session's records, and the changes pane's base is that session's;
- an in-session `/resume` of another session shows that session's reports in the shown Report, and its base in the changes pane when it is shown;
- a switch while the changes pane is hidden shows the new session's lists at `\pc`;
- `/clear` shows an empty Report and a base of `HEAD` then;
- `/resume` back to the first session brings its Report and its base back;
- a `SessionStart` of the followed session changes nothing: the Report's lines and cursor stay;
- Input keeps its text across a switch;
- a new editor in the directory resumes the switched-to session and shows its Report;
- the help through `tests/test_doc.lua`.

The verification runs the plan's four mutants for T39. Name in your report the test that kills each.

## What was decided already

- The user's request, 2026-10-06 (`plan.md` › *Ask*), and the answers to P7–P11, which the amendment gives.
- D18's PD1–PD6 and D21 stand: a switch does not change which pane is shown, nor move the cursor out of its window.

## Budget

Medium: wiring in the composition root, about nine entry cases and a help paragraph. If it grows past that, stop at a green, reviewed, pushed state and report.

## Report

In your definition's shape, to `<scratchpad>/t39-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the test files that ran and the whole suite's counts.
