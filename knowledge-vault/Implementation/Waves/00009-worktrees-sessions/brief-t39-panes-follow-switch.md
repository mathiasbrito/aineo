**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, and `.claude/agents/neovim-claude-code-integrator.md` for the session it wires.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> **Agreed and amended, 2026-10-07; stage 2.** The user answered the converge round on 2026-10-07: P7, P9 and P11 are (a), now D37, D39 and D41; **P10 is per session**, over the recommendation, now D40 — so this packet also swaps Input's draft at a switch, through the draft home T36 builds. The orchestrator measured M6 and M7 the same day (`evidence/w9-real-claude-sessions.txt`). Wave 8's T33 merged (PR #129), and every fact below was read again at `dev` `f98bd9d`. It is not dispatched until T35, T36 and T37 have merged: it wires what they build. The entry points they add are named by their pull requests; the amendment at dispatch names them, gives the line numbers of `plugin/aineo.lua` as T35 leaves it, and quotes the help's fence. Dispatched at once with T38 (S (a)). **Corrected 2026-10-07 from the brief review** (`brief-review.md` in this folder, T39-1 to T39-7, W-2 and W-4): the corrections are made in the body, and *Correction — 2026-10-07, from the brief review*, at the end, lists each; the stage-2 amendment re-checks them against the `dev` this packet starts from.

## Objective

The task, verbatim from the task list:

> | T39 | The panes follow a session switch (C1, C12; D37–D41): at every start and when Claude Code switches session, the composition root shows that session's Report, changes pane and Input draft, whichever pane is shown | T35, T36, T37, M6 | planned — wave 9 |

It rests on: D37–D41 (agreed 2026-10-07); C1 (the composition root wires the homes), C12 and D18 (the panes; D18's PD3: a report that arrived while hidden shows when `\pa` brings the Report back), D21 (`\o` keeps the pane), C3 as T35 leaves it, C6 and C11 as T36 leaves them, C15 as T37 leaves it; wave 8's T33 (the status line follows Claude Code's terminal title); D26 and D29.

### The behaviour (D37–D41)

- **At every start of Claude Code**, the composition root tells the report home, the changes home and the draft home the session Claude Code starts on — the id aineo started it on, which T35's "which session" gives at once, without waiting for a hook (A2: in a folder not yet trusted no hook runs at all, M7) — so the Report shows that session's reports (T36), the changes pane that session's base and marks (T37), and Input that session's draft (T36). The first start in an editor moves the directory's reports and draft to that session (T36's moves).
- **The order at the first start** (brief review, T39-3; the orchestrator's ruling on T36-1). At the first `:Aineo open`, `started_claude_terminal()` runs as an argument of `arrangement()` (`plugin/aineo.lua:290`), so the homes are told the session there — before `give_report_environment()` (`arrangement()`'s first line, 273) and before `keep_input_draft()` (291), which gives the draft home its environment and hands it Input. That order stays: T36's homes hold a session told before their environment and before `keep_draft()`, and T37's holds a follow until `begin_session()` has found the repository. In `started_claude_terminal()`, call `begin_session()` first, then the changes home's follow.
- **At a switch** (T35's `on_session_switched`, with the new id, its source and the session left): the same three calls with the new session. Whichever pane is shown, the shown windows show the new session's content at once; the hidden pane shows it when it is next shown (`\pa`, `\pc`, `\o`, a layout built anew), as D18's PD3 and the changes pane's re-read on showing already do.
- **T19's fallback is a switch** (D38; brief review, T35-1 and T39-2). When a resume finds no conversation and the claude home starts a new id in its place, T35 calls `on_session_switched(<new id>, 'startup', <old id>)`; wire it as every switch, so the three homes follow the new id. Today `on_terminal_replaced` (`plugin/aineo.lua:222–225`) only re-points the terminal, and every report, base, mark and draft would stay under the session that found no conversation.
- **Textlock** (brief review, T39-6). The switch reaches the homes from T35's scheduled callback, which can run under textlock ([[Learnings/A scheduled callback can run under textlock, where Neovim refuses a buffer change with E565]]). The buffer changes are the homes' — T36 makes a refused swap again at `SafeState` — and the composition root makes no buffer change of its own there.
- **Input** (D40): at a switch, Input's text is kept as the old session's draft and the new session's draft, or nothing, takes its place, as T36's draft home does when told. The user's reason: "p10 must be one per session, why, because it is used to catalog changes and notes that goes to the prompt with \s". A switch while the user types in Input does not leave them in another mode or window (D18, D21).
- **The status line** (T33) follows Claude Code's terminal title by itself; this packet adds nothing to it. M6 measured that the title follows the session — `✳ Claude Code` for a session with no title yet, its title after a turn and after `/resume`, `✳ <first prompt> (Branch)` after `/branch` — but is not an id: two sessions can share one. The help says so.
- **Nothing happens** for a `SessionStart` of the session already followed (T35 calls nothing back), while Neovim quits, or before the layout has ever opened (the homes are told, the windows do not exist yet).
- **The help** says that aineo follows a switch made inside Claude Code, what follows it (the Report, the changes pane, Input's draft, the session resumed next, and the status line through the title), that the title is not an id, and where hooks do not run (T35's LIMITS subsection), in *aineo-claude-session*'s paragraph T35 wrote. And LIMITS › `Claude's window name ~`'s first sentence of its last item, "Not measured, and so not known to show: a title Claude Code generates from your first prompt, a name `/rename` gives, the title after `--resume`, and the glyph while Claude Code is busy.", goes stale: M6 measured a title after the first turn and the title after an in-session `/resume` (brief review, T39-7). Say what M6 measured, and keep unmeasured what it did not: a name `/rename` gives, the title of a start with `--resume`, and the glyph while Claude Code is busy.

### Facts, checked against `origin/dev` `f98bd9d` (wave 8 merged; re-checked after T35, T36 and T37 merge)

- `plugin/aineo.lua`:
  - `kept_places()`, lines 148–152; `give_report_environment()`, lines 159–171; `keep_input_draft()`, lines 180–187, which gives the draft home its environment the first time and hands it the layout's Input (`keep_draft()`);
  - `started_claude_terminal()`, lines 211–234: starts the session, hands `on_terminal_replaced` (222–225), then calls `aineo.changes`' `begin_session()` (lines 227–232). T33 did not change it; T35 does;
  - `open()`, 288–292: `arrangement(config, started_claude_terminal(config))` at 290, then `keep_input_draft()` at 291;
  - `changes_pane()`, lines 256–260 (`refresh_shown_pane()`, then `pane_buffers()`); `arrangement()`, lines 272–281, which gives the report home its environment first (273) and since T33 also hands the layout Claude's status line (`claude_statusline`, line 279); `focus()`, 305–315; `show_pane()`, 325–338.
- `lua/aineo/changes/init.lua` › `M.refresh_shown_pane()`, line 541: reads both lists again while either buffer is shown.
- Tests through the entry point that start the fake Claude Code: `tests/helpers/entry.lua` (`use_fake()`), `tests/helpers/claude_session.lua` (`fake()`, `wait_for_status()`); `tests/test_entry_claude_resume.lua` (11 cases), `tests/test_entry_report.lua` (4), `tests/test_entry_draft.lua`, `tests/test_entry_changes.lua` (12), `tests/test_entry_panes.lua` (86), and T33's `tests/test_entry_claude_name.lua`. T35 teaches the fake to run the `SessionEnd` and `SessionStart` hooks on keys standing for `/clear`, `/resume <id>`, `/branch` and `/compact`, as M1 measured them.
- **A case this packet breaks** (brief review, T39-1): `tests/test_entry_panes.lua:601–619` writes the directory's draft through `own_draft()` (565–575) and waits for `read_draft(draft) == 'then run the tests\n'` in the directory's file. Once the homes follow the started session and the directory's draft moves at the first start (A6), the typed text goes to the session's file, and the case fails. That file is yours (*Boundary*).
- **The help's LIMITS item** this packet makes stale (T39-7): `doc/aineo.txt` › LIMITS › `Claude's window name ~`, the item's first sentence from `- Not measured, and so not known to show: a title Claude Code generates` to `` `--resume`, and the glyph while Claude Code is busy. `` (lines 1033–1035 at `f98bd9d`); the rest of that item, from `A glyph is left out` on, is T33's and stays as it is.
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
- **You may touch:** `plugin/aineo.lua` — the wiring of the start and the switch in `started_claude_terminal()` and what it calls, `keep_input_draft()` included; **not** the autostart (`start_up` and what it reaches); a new `tests/test_entry_session_switch.lua`; `tests/test_entry_claude_resume.lua`, `tests/test_entry_report.lua`, `tests/test_entry_draft.lua` and **`tests/test_entry_panes.lua`** where a case must change — the draft case at 601–619 among them (T39-1) — naming each in your report; not `tests/test_entry_changes.lua`, which T38 may change at the same time: check the changes pane in your new suite, for the session it follows alone (*The tests*); `doc/aineo.txt` inside the two places below; your session note.
- **You must not touch:** every file under `lua/` — a home that lacks what the wiring needs is a spec conflict for your report, not a change here; `tests/helpers/` (the fake is T35's); every other file under `scripts/` and `tests/`, `tests/test_doc.lua` included (run it); T38's files (`lua/aineo/git/`, `lua/aineo/changes/`, `tests/test_git_worktrees.lua`, `tests/test_changes*.lua`, `tests/test_entry_changes.lua`), which run at the same time; the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`. Yours: the paragraph of *aineo-claude-session* on switches that T35 wrote (the amendment quotes its first and last line); and LIMITS › `Claude's window name ~`'s first sentence of its last item, quoted in *Facts* (T39-7). T38 owns *aineo-panes*'s changes-pane item, and *aineo-changes* from `The files window, \`aineo://changes-files\`, lists every file that differs` to `windows say so until the pane is shown again, which starts it again.`, and LIMITS › `The changes pane ~`. Before you push, merge with its branch if it exists (`git merge-tree --write-tree <your head> origin/feature/t38-changes-worktrees`), run `make test_file FILE=tests/test_doc.lua` on the merged tree, and report it.
- **Session note:** `knowledge-vault/Sessions/<date> — T39 Panes follow switch.md`, with a `## Task lines` section. `<date>` is the dispatch message's date, written `YYYY-MM-DD`, which that message gives; the orchestrator checks the name is free before dispatch (W-4).
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
- T19's fallback: the fake with `AINEO_FAKE_CLAUDE_CONVERSATIONS` finding no conversation for the resumed id; then a report lands in the new session's records, the changes pane's base is the new session's, and Input's draft is kept under the new session (T39-2);
- at the first `:Aineo open`, told before the environment and before Input is kept, Input holds the started session's draft and the Report its reports (T39-3).

**What the changes pane's checks may pin** (the orchestrator's ruling on T39-5): T38 changes the pane's lines at the same time, for other worktrees. Check the pane only for what T38 does not change — the session it follows: the editor's own entries, by content (a file listed, a commit listed, the `*` of a save), in fixture repositories with no other worktree, never another worktree's section. Under D33 the editor's own lines stay exactly today's.

The help is not in that list: `tests/test_doc.lua` pins the tags, the 78-column width and the help file's shape (`tests/test_doc.lua:59–208`), and no text, so no paragraph can be seen failing there, and you may not edit that file. **`tests/test_doc.lua` stays green on the merged trees** (W-2).

The verification runs the plan's five mutants for T39, each an edit of this packet's own wiring in `plugin/aineo.lua` (T39-4). Name in your report the test that kills each.

## What was decided already

- The user's request, 2026-10-06 (`plan.md` › *Ask*), and the answers to P7–P11, D37–D41, which the amendment gives.
- The orchestrator's assumptions A1 (a switch is a `SessionStart` after the followed id's `SessionEnd`, T35's) and A2 (the started id followed until a hook names another), to be reported to the user; build on them as written. T19's fallback is a switch: D38's own case (T35-1).
- The orchestrator's rulings, to be reported to the user: the homes hold a session told before their environment, so the first start is not reordered (T36-1, T39-3); the changes pane's checks pin the session followed alone (T39-5).
- D18's PD1–PD6 and D21 stand: a switch does not change which pane is shown, nor move the cursor out of its window.

## Budget

Medium: wiring in the composition root to three homes, about twelve entry cases, one case of `tests/test_entry_panes.lua` moved, a help paragraph and one LIMITS sentence. If it grows past that, stop at a green, reviewed, pushed state and report.

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

## Correction — 2026-10-07, from the brief review

The brief review (`brief-review.md` in this folder, on `ed83367`) found this brief not dispatchable as written: seven findings, T39-1 to T39-7, and two that every brief shares, W-2 and W-4. No packet had been dispatched, so each correction is made in the body above, as the review words it, and listed here; the stage-2 amendment re-checks them against the `dev` this packet starts from. Where the review left a choice, the orchestrator ruled under the user's instruction of 2026-10-06 ("assume your recommendations and report what they were after you finish"); each ruling is named below as **the orchestrator's assumption, to report to the user**, or as a D row's own case. None is the user's answer.

- **T39-1 — the orchestrator's ruling, to report to the user.** `tests/test_entry_panes.lua` joins this packet's boundary, its draft case at 601–619 among the cases that may change; T38 must not touch it, and the plan's six-rules table says so: *Facts*; *Boundary*.
- **T39-2 — D38's own case (T35-1), not an assumption.** T19's fallback reaches the homes: T35 reports it through `on_session_switched(<new id>, 'startup', <old id>)`, and this packet wires it as every switch: *The behaviour*; an entry test; mutant 4.
- **T39-3 — the orchestrator's ruling on T36-1, to report to the user.** The homes hold a session told before their environment, so the first start is not reordered; the order is said, `begin_session()` before the changes home's follow: *The order at the first start*; an entry test.
- **T39-4:** the first plan's mutants 3 (`v:exiting`) and 4 (a `SessionStart` of the same id) were T35's, T36's and T37's code; they move to those packets (T35's 10, T36's 10), and T39's list holds edits of its own wiring (`plan.md`). Of the review's four suggestions, two are taken — the fallback's switch not wired (4) and the started session not told at the start (3); "the draft home told after `keep_draft()`" and "the changes home told before `begin_session()`" are left out, since T36 and T37 now hold a session told early, which makes both equivalent.
- **T39-5 — the orchestrator's ruling, to report to the user.** The new suite checks the changes pane only for what T38 does not change: the session it follows, not the lines of other worktrees: *The tests*, "What the changes pane's checks may pin".
- **T39-6:** textlock: the Learning is cited, and the buffer changes are the homes': *The behaviour*.
- **T39-7:** LIMITS › `Claude's window name ~`'s "Not measured" sentence joins this packet's help places, and says what M6 measured: *The behaviour*, *Facts*, *Boundary*.
- **W-2:** the help is out of the red-first list; `tests/test_doc.lua` stays green on the merged trees.
- **W-4:** the session note's `<date>` is the dispatch message's: *Boundary*.

**Mutants** (`plan.md` › *Verification mutants*, T39): 1, 2 and 5 stand; 3 is now the started session not told at the start, and 4 the switch callback ignored for a start's `startup` source.
