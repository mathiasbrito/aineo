**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, and `.claude/agents/neovim-claude-code-integrator.md` for the session it wires.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> **Agreed and amended, 2026-10-07; stage 2.** The user answered the converge round on 2026-10-07: P7, P9 and P11 are (a), now D37, D39 and D41; **P10 is per session**, over the recommendation, now D40 — so this packet also swaps Input's draft at a switch, through the draft home T36 builds. The orchestrator measured M6 and M7 the same day (`evidence/w9-real-claude-sessions.txt`). Wave 8's T33 merged (PR #129), and every fact below was read again at `dev` `f98bd9d`. It is not dispatched until T35, T36 and T37 have merged: it wires what they build. The entry points they add are named by their pull requests; the amendment at dispatch names them, gives the line numbers of `plugin/aineo.lua` as T35 leaves it, and quotes the help's fence. Dispatched at once with T38 (S (a)).

## Objective

The task, verbatim from the task list:

> | T39 | The panes follow a session switch (C1, C12; D37–D41): at every start and when Claude Code switches session, the composition root shows that session's Report, changes pane and Input draft, whichever pane is shown | T35, T36, T37, M6 | planned — wave 9 |

It rests on: D37–D41 (agreed 2026-10-07); C1 (the composition root wires the homes), C12 and D18 (the panes; D18's PD3: a report that arrived while hidden shows when `\pa` brings the Report back), D21 (`\o` keeps the pane), C3 as T35 leaves it, C6 and C11 as T36 leaves them, C15 as T37 leaves it; wave 8's T33 (the status line follows Claude Code's terminal title); D26 and D29.

### The behaviour (D37–D41)

- **At every start of Claude Code**, the composition root tells the report home, the changes home and the draft home the session Claude Code starts on — the id aineo started it on, which T35's "which session" gives at once, without waiting for a hook (A2: in a folder not yet trusted no hook runs at all, M7) — so the Report shows that session's reports (T36), the changes pane that session's base and marks (T37), and Input that session's draft (T36). The first start in an editor moves the directory's reports and draft to that session (T36's moves).
- **At a switch** (T35's callback, with the new id, its source and the session left): the same three calls with the new session. Whichever pane is shown, the shown windows show the new session's content at once; the hidden pane shows it when it is next shown (`\pa`, `\pc`, `\o`, a layout built anew), as D18's PD3 and the changes pane's re-read on showing already do.
- **Input** (D40): at a switch, Input's text is kept as the old session's draft and the new session's draft, or nothing, takes its place, as T36's draft home does when told. The user's reason: "p10 must be one per session, why, because it is used to catalog changes and notes that goes to the prompt with \s". A switch while the user types in Input does not leave them in another mode or window (D18, D21).
- **The status line** (T33) follows Claude Code's terminal title by itself; this packet adds nothing to it. M6 measured that the title follows the session — `✳ Claude Code` for a session with no title yet, its title after a turn and after `/resume`, `✳ <first prompt> (Branch)` after `/branch` — but is not an id: two sessions can share one. The help says so.
- **Nothing happens** for a `SessionStart` of the session already followed (T35 calls nothing back), while Neovim quits, or before the layout has ever opened (the homes are told, the windows do not exist yet).
- **The help** says that aineo follows a switch made inside Claude Code, what follows it (the Report, the changes pane, Input's draft, the session resumed next, and the status line through the title), that the title is not an id, and where hooks do not run (T35's LIMITS subsection), in *aineo-claude-session*'s paragraph T35 wrote.

### Facts, checked against `origin/dev` `f98bd9d` (wave 8 merged; re-checked after T35, T36 and T37 merge)

- `plugin/aineo.lua`:
  - `kept_places()`, lines 148–152; `give_report_environment()`, lines 159–171; `keep_input_draft()`, lines 180–187, which hands the layout's Input to the draft home (`keep_draft()`);
  - `started_claude_terminal()`, lines 211–234: starts the session, hands `on_terminal_replaced`, then calls `aineo.changes`' `begin_session()` (lines 227–232). T33 did not change it; T35 does;
  - `changes_pane()`, lines 256–260 (`refresh_shown_pane()`, then `pane_buffers()`); `arrangement()`, lines 272–281, which since T33 also hands the layout Claude's status line (`claude_statusline`, line 279); `open()`, 288–292; `focus()`, 305–315; `show_pane()`, 325–338.
- `lua/aineo/changes/init.lua` › `M.refresh_shown_pane()`, line 541: reads both lists again while either buffer is shown.
- Tests through the entry point that start the fake Claude Code: `tests/helpers/entry.lua` (`use_fake()`), `tests/helpers/claude_session.lua` (`fake()`, `wait_for_status()`); `tests/test_entry_claude_resume.lua` (11 cases), `tests/test_entry_report.lua` (4), `tests/test_entry_draft.lua`, `tests/test_entry_changes.lua` (12), `tests/test_entry_panes.lua` (86), and T33's `tests/test_entry_claude_name.lua`. T35 teaches the fake to run the `SessionEnd` and `SessionStart` hooks on keys standing for `/clear`, `/resume <id>`, `/branch` and `/compact`, as M1 measured them.
- **M6 and M7** (`evidence/w9-real-claude-sessions.txt`): the title follows the session but is not an id; in a folder not yet trusted nothing runs — no hook, no MCP server, no title — until the dialog is answered.
- [[Learnings/A test child that quits with aineo's Claude Code running waits 4.4 s for the stop by keys]]: end each child's terminals before it quits, as `tests/test_entry_panes.lua` does since T25.

### Baseline

At `f98bd9d`, Neovim 0.12.5: 1929 cases in 60 groups, `Fails (0)` — T33's last whole-suite run, on code identical to `f98bd9d`'s (`plan.md` › *Baseline*). Every file above changes again before this packet runs; the dispatch message pastes the counts on the `dev` you start from.

Read first: the v1 plan note's C1, C3, C6, C11, C12, C15, D17, D18, D21, D23 and D37–D41; [[Planning/aineo — worktrees and session switches]] › P7–P11 and its outcome; `knowledge-vault/Projects/aineo.md`; the session notes of T33, T35, T36 and T37; `Sessions/2026-10-05 — T24 Panes.md`; `plan.md` (*Assumptions to report to the user*, A2) and `evidence/w9-real-claude-sessions.txt` in this folder.

## Boundary

- **Branch:** `feature/t39-panes-follow-switch` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t39_panes_follow_switch` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `plugin/aineo.lua` — the wiring of the start and the switch in `started_claude_terminal()` and what it calls, `keep_input_draft()` included; **not** the autostart (`start_up` and what it reaches); a new `tests/test_entry_session_switch.lua`; `tests/test_entry_claude_resume.lua`, `tests/test_entry_report.lua` and `tests/test_entry_draft.lua` where a case must change (name each in your report) — not `tests/test_entry_changes.lua`, which T38 may change at the same time: check the changes pane in your new suite; `doc/aineo.txt` inside the fence below; your session note.
- **You must not touch:** every file under `lua/` — a home that lacks what the wiring needs is a spec conflict for your report, not a change here; `tests/helpers/` (the fake is T35's); every other file under `scripts/` and `tests/`, `tests/test_doc.lua` included (run it); T38's files (`lua/aineo/git/`, `lua/aineo/changes/`, `tests/test_git_worktrees.lua`, `tests/test_changes*.lua`, `tests/test_entry_changes.lua`), which run at the same time; the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`. Yours: the paragraph of *aineo-claude-session* on switches that T35 wrote (the amendment quotes its first and last line). T38 owns *aineo-changes* from `The files window, \`aineo://changes-files\`, lists every file that differs` to `windows say so until the pane is shown again, which starts it again.`, and LIMITS › `The changes pane ~`. Before you push, merge with its branch if it exists (`git merge-tree --write-tree <your head> origin/feature/t38-changes-worktrees`), run `make test_file FILE=tests/test_doc.lua` on the merged tree, and report it.
- **Session note:** `knowledge-vault/Sessions/<date> — T39 Panes follow switch.md`, with a `## Task lines` section.
- **Scratch prefix:** `t39-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5 only; the test files you touch and the entry suites above while you work; the whole suite once before each push — `plugin/aineo.lua` is the composition root every entry suite loads; mutants on their covering files. Never the real `claude`.

## The tests

Each behaviour gets one test, seen failing first, through the entry point with the fake Claude Code:
- after a start, a report lands in the started session's records, the changes pane's base is that session's, and Input holds that session's draft — with the fake running no hook at all, as in a folder not yet trusted (A2);
- an in-session `/resume` of another session shows that session's reports in the shown Report, and its base in the changes pane when it is shown;
- a switch while the changes pane is hidden shows the new session's lists at `\pc`;
- `/clear` shows an empty Report and a base of `HEAD` then;
- `/resume` back to the first session brings its Report, its base and its draft back;
- a `SessionStart` of the followed session (`/compact`) changes nothing: the Report's lines and cursor, and Input's text, stay;
- a switch keeps Input's text as the old session's draft and puts the new session's draft, or nothing, in Input (D40);
- `/branch` is followed as a switch, as `/clear` and `/resume` are;
- a new editor in the directory resumes the switched-to session and shows its Report and its draft;
- the help through `tests/test_doc.lua`.

The verification runs the plan's five mutants for T39. Name in your report the test that kills each.

## What was decided already

- The user's request, 2026-10-06 (`plan.md` › *Ask*), and the answers to P7–P11, D37–D41, which the amendment gives.
- The orchestrator's assumption A2 (the started id followed until a hook names another), to be reported to the user; build it as written.
- D18's PD1–PD6 and D21 stand: a switch does not change which pane is shown, nor move the cursor out of its window.

## Budget

Medium: wiring in the composition root to three homes, about ten entry cases and a help paragraph. If it grows past that, stop at a green, reviewed, pushed state and report.

## Report

In your definition's shape, to `<scratchpad>/t39-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the test files that ran and the whole suite's counts.

## Amendment — 2026-10-07: the user's answers, the measurements, and the facts at `f98bd9d`

**The user's answers.** The orchestrator put P1–P11 to the user as a table, each with its options and its recommendation first, and M, R and S for the wave. The user answered, verbatim: "p10 must be one per session, why, because it is used to catalog changes and notes that goes to the prompt with \s, other than that all your recommendations are fine, so when wave 8 finishes start right streight wave 9."
- P7, P9 and P11 are (a): D37, D39, D41, as this brief was written.
- **P10 is per session**, over the recommendation: D40. The proposal note letters it (a); the table put to the user lettered it (b). This brief first left Input alone; it now tells the draft home the session at every start and every switch, and its tests check the swap. The plan's T39 mutant 5 is the draft home not told.
- S is (a): this packet and T38 go at once. R is (a): a release is cut when this packet merges, feature B whole.

**The measurements** (`evidence/w9-real-claude-sessions.txt`, the orchestrator's, 2026-10-07):
- M6: the title follows the session, so the status line needs nothing new; the title is not an id, and the help says so.
- M7: nothing runs before a folder's trust dialog is answered. So the homes are told the started session at the start, never waiting for a hook: the orchestrator's assumption A2, reported to the user.
- M1: `/branch` is a switch too (`fork`), and `/compact` none. The tests cover both.

**Facts that moved since `9b8707f`** (the body gives them at `f98bd9d`): T33 changed `plugin/aineo.lua`'s `arrangement()` (271–279 → 272–281, handing Claude's status line), so `open()`, `focus()` and `show_pane()` moved by two lines; `started_claude_terminal()`, `kept_places()`, `give_report_environment()` and `keep_input_draft()` did not move. T33 added `tests/test_entry_claude_name.lua`. `tests/test_entry_changes.lua` leaves this packet's boundary: T38's first brief admits it too, and the two run at once. The baseline is 1929 cases at `f98bd9d`.
