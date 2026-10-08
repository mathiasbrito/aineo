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

~~The verification runs the plan's five mutants for T39, each an edit of this packet's own wiring in `plugin/aineo.lua` (T39-4).~~ *(2026-10-08: superseded; the list and its count are in "Correction — 2026-10-08, from the brief review", below, T39-6.)* Name in your report the test that kills each.

## What was decided already

- The user's request, 2026-10-06 (`plan.md` › *Ask*), and the answers to P7–P11, D37–D41, which the amendment gives.
- The orchestrator's assumptions A1 (a switch is a `SessionStart` after the followed id's `SessionEnd`, T35's) and A2 (the started id followed until a hook names another), to be reported to the user; build on them as written. T19's fallback is a switch: D38's own case (T35-1).
- The orchestrator's rulings, to be reported to the user: the homes hold a session told before their environment, so the first start is not reordered (T36-1, T39-3); the changes pane's checks pin the session followed alone (T39-5).
- D18's PD1–PD6 and D21 stand: a switch does not change which pane is shown, nor move the cursor out of its window.

## Budget

~~Medium: wiring in the composition root to three homes, about twelve entry cases, one case of `tests/test_entry_panes.lua` moved, a help paragraph and one LIMITS sentence. If it grows past that, stop at a green, reviewed, pushed state and report.~~ *(2026-10-08: superseded; the budget is restated in "Correction — 2026-10-08, from the brief review", below, T39-6.)*

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

## Amendment — 2026-10-08, at dispatch

**Base: `dev` `dc5ff70`.** Stage 1 has merged: T35 (PR #137), T36 (PR #135) and T37 (PR #136), each through two fix rounds and two re-measures. Every path, symbol, line range and help fence this brief cites was read again at `dc5ff70` with `git grep -n` (by the agent that wrote this amendment, for the orchestrator). The body and the earlier sections stand except where this section says a fact moved. Start your branch from the `origin/dev` the dispatch message names, and re-check against it if it is not `dc5ff70`.

### Facts that moved, and those that held

- **`plugin/aineo.lua`.**
  - T35 changed it in `started_claude_terminal()` alone, four lines added and one changed:
    - its docstring now says the session's hooks are "told the editor's address and program";
    - it now passes `editor_address = vim.v.servername` and `editor_program = vim.v.progpath` (223–224).
  - Nothing else in the file changed. The ranges now:
    - `kept_places()` 148–152, `give_report_environment()` 159–171 and `keep_input_draft()` 180–187 held;
    - `started_claude_terminal()` 211–234 → **212–237**: its docstring 195–209, `on_terminal_replaced` 222–225 → **225–228**, and the `begin_session()` call 227–232 → **230–235**;
    - `current_claude_terminal()` **245–250**;
    - `changes_pane()` 256–260 → **259–263**;
    - `arrangement()` 272–281 → **275–284**, its first line, `give_report_environment()`, 273 → **276**, and `claude_statusline` 279 → **282**;
    - `open()` 288–292 → **291–295**: `arrangement(config, started_claude_terminal(config))` 290 → **293**, and `keep_input_draft()` 291 → **294**;
    - `focus()` 305–315 → **308–318**;
    - `show_pane()` 325–338 → **328–341**.
- **`lua/aineo/changes/init.lua`, as T37 left it:**
  - `M.refresh_shown_pane()` 541 → **859**;
  - `M.begin_session()` **606**;
  - `M.follow_changes_session()` **656**;
  - `M.pane_buffers()` **876**.
- **`tests/test_entry_panes.lua` did not change.** Its draft case is still 601–619, its `own_draft()` still 565–575, and it still waits for `read_draft(draft) == 'then run the tests\n'` in the directory's file.
- **The fake runs the hooks only when asked.** `tests/helpers/fake_claude.lua` runs the `--settings` hooks only when `AINEO_FAKE_CLAUDE_HOOKS` is set (its header, 35–49), through `sh -c` as Claude Code 2.1.292 ran them. It runs them on:
  - its start;
  - the keys `/clear`, `/resume <id>`, `/branch` and `/compact`, each then Enter;
  - an exit by its keys.

  Pass the variable as `claude_session.fake(name, mode, extra_environment)`'s third argument. With it unset the fake runs no hook, which is the folder not yet trusted of A2. `AINEO_FAKE_CLAUDE_CONVERSATIONS` gives T19's no-conversation exit.
- **Helpers.** `tests/helpers/claude_session.lua` now has `wait_for_deliveries(child)` (322): no deliverer left, then one scheduled round. It is the deterministic way to assert that nothing was called back after a hook. It also has `press_keys(child, buffer, keys)` (558). Neither helper is yours to edit.
- **The help, `doc/aineo.txt`.** Each fence is quoted by its first and last line, as they stand at `dc5ff70`:
  - **T35's paragraph on switches**, in *aineo-claude-session* (named here, as the body promised): lines **327–338**, from `aineo follows a switch you make inside Claude Code: \`/clear\`, \`/resume\`` to `terminal in the same directory.` Line 326 above it is empty, and below it come the empty line 339 and `Input's draft ~` (340).
  - **LIMITS › `Claude's window name ~`'s "Not measured" sentence** (T39-7): 1033–1035 → **1186–1188**, from `- Not measured, and so not known to show: a title Claude Code generates` to `` `--resume`, and the glyph while Claude Code is busy. `` The sentence ends mid-line 1188. The rest of the item, from `A glyph is left out` (1188) to `not among them, whatever 'iskeyword' holds.` (1191), is T33's and stays.
  - **A third place: *aineo-send*'s `Undo ~` paragraph**, lines **731–737**, from `` `u` in Input brings back what a Send removed, one `u` per Send: Input's text `` to `(|aineo-limits|).`
    - **Why it is added.** Once this packet wires the switch, a draft swap ends what `u` can reach: no `u` reaches a change or a Send made before it (T36's *aineo-draft* text, 364–366). This paragraph still says only "one `u` per Send".
    - T36's note left it "for T39 or the knowledge pass" (records finding 5), and no open packet edits it. Say there what a switch does to `u`; LIMITS › `Undo after a Send ~` (1099–1109) stays as it is.
- **`tests/test_doc.lua` did not change.** It still pins 59–208: the tags, the width and the help's shape.

### The three homes' entry points, as merged

**T35 — `aineo.claude`** (`lua/aineo/claude/init.lua`):
- **The callback.** `aineo.claude.Settings`' field (24), verbatim: "`on_session_switched? fun(id: string, source: string?, left: string, reason: string?)` called when the session followed changes (`session_id()`): with the new id, how Claude Code started it (`clear`, `resume`, `fork`; `startup` or `resume` for a start that takes the place of the session followed), the id left, and why Claude Code left it (`clear`, `resume`; none for a start). Never for an editor's first start. An error it raises is told the user as a warning and goes no further".
  - It is checked as `vim.validate('settings.on_session_switched', settings.on_session_switched, 'function', true)` (148).
  - It is called only by `tell_switch()` (352–361), as `pcall(settings.on_session_switched, switch.id, switch.source, switch.left, switch.reason)`. An error becomes the warning `aineo: on_session_switched failed: …`.
  - **The fourth argument, `reason`,** is the `SessionEnd`'s reason: `clear` for `/clear`, `resume` for `/resume` and `/branch` (M1). A start passes none.
- **Its three callers:**
  - **A switch told by the hooks.** `follow_switch()` (570–575) runs from a callback scheduled by `receive_session_event()` (`take_session_event()`, 655–667). It keeps the new id for the directory first (D38), then calls back with `source` `clear`, `resume` or `fork`, and `reason` `clear` or `resume`. Before that, `take_session_event()` drops:
    - a hook while Neovim quits (`v:exiting`);
    - a hook of another start's token;
    - an id `is_session_id()` refuses;
    - a hook that ran after the start's Claude Code exited.
  - **A start whose session is another than the one followed before it.** `M.start_session()` (523–535) calls `tell_session_replaced(settings, left)` (372–377) itself, so the call comes **inside `start_session()`, before it returns** — that is, before `started_claude_terminal()` reaches `begin_session()`. The source is `resume` when that start resumed an id and `startup` when it is new, and there is no reason. Two cases make it:
    - a later start in another directory, after a `:cd`;
    - a restart after another Neovim's switch in the same directory changed the kept id (D38: "the last switch in either wins").

    It is never called at an editor's first start, nor at a restart on the session followed.
  - **T19's fallback.** `start_new_session_in_place()` (400–416) runs from a scheduled callback. It always starts a new id (`resumed = false`, 404), so its source is always **`startup`**. It calls `on_terminal_replaced(terminal)` first (412–414), then `tell_session_replaced()` (415), whose `left` is the id that found no conversation. It calls neither when the new start fails.
- **Which session.** `M.session_id()` (743–745) is `session and session.followed`. That is the id a start launched on, set in `launch()` without waiting for a hook (A2), then each switch's id. It is nil before any start, and it keeps the last id once Claude Code has exited.

**T36 — `aineo.report` and `aineo.draft`:**
- **`follow_report_session(session_id)`** (`lua/aineo/report/init.lua` 426–441):
  - It checks its argument with `vim.validate('session_id', session_id, 'string')` and raises an error naming `session_id` otherwise.
  - The session it follows already changes nothing, the Report's lines and cursor included.
  - **Before its environment is given,** it only sets the session it follows: the follow is held.
  - `set_report_environment()` (120–129) then moves the working directory's records to that session, once per editor (`move_directory_records_once()`, 92). The Report, once `report_buffer()` makes it, shows that session's records (`kept_records_file()`, 297).
  - With its environment given, a follow moves the directory's records once, and, once the Report exists, swaps its records file and shows the session's records (`show_followed_records()`). A swap textlock refuses (E565) is made again at `SafeState`.
- **`follow_draft_session(session_id)`** (`lua/aineo/draft/init.lua` 826–845):
  - It checks its argument the same way. The session it follows already changes nothing.
  - **First, even before its environment is given,** each kept buffer is pinned to the file its text came from, and a change not saved yet is saved there at once. Before `keep_draft()` there is no kept buffer.
  - Then it sets the session it follows. **Without an environment it stops there: the follow is held.**
  - `set_draft_environment()` (702–707) then moves the directory's draft to that session, once per editor (`move_directory_draft_once()`, 379), and `keep_draft()` (745) restores that session's draft into the buffer it is handed — **only an empty one**.
  - With its environment given, a follow moves the directory's draft once, then puts the session's draft, or nothing, in place of every kept buffer's text (`replace_with_kept_draft()`). That swap is not saved and not undoable; under textlock it is made at `SafeState`.

**T37 — `aineo.changes`** (`lua/aineo/changes/init.lua`):
- **`follow_changes_session(followed)`** (656–675) takes `followed`, an `aineo.changes.FollowedSession` (510–512): `{ id = <Claude Code's session id>, state_directory = <stdpath('state')> }`.
  - **It checks no argument.**
  - It must be called on the main loop: from a fast event it raises E5560, as its docstring says.
- **Before `begin_session()`,** it only keeps `followed` (`followed_before_beginning`; the latest follow wins). `begin_session()` (606–636) makes it the session's.
- **After `begin_session()` but before the first look has found the repository,** it sets the session followed and returns. `find` (476–499) then takes that session's kept base and saves when one was kept for this repository (`use_kept_base()`), else `HEAD` from that look, which it keeps (`keep()`). Nothing is kept before the repository is found.
- **Once the repository is found,** a follow restores a base this editor held for the session, or the kept one, and reads both lists again. Otherwise it looks for `HEAD` again from the repository's top level (`take_head()`, 520–541), while both windows say aineo is reading.
- The session it follows already changes nothing.
- Its state directory is `kept_places().state_directory` (T37's note: "call `begin_session()` and then `follow_changes_session({ id = <session id>, state_directory = kept_places().state_directory })` at every start and every switch").

### The order T39 wires them

**At the first start.** This is `open()`, and also `focus()` and `show_pane()` when they must open the layout: each runs `started_claude_terminal()` as `arrangement()`'s argument, so it runs before `arrangement()`'s body.
1. `aineo.claude.start_session({ …, on_session_switched = <T39's handler> })` (216–229). An editor's first start calls nothing back.
2. `aineo.changes.begin_session({ directory, show_diff })` (230–235), as today.
3. **T39 tells the three homes `aineo.claude.session_id()`:**
   - `follow_report_session(id)` and `follow_draft_session(id)`, each held: no environment yet, and the draft home keeps no buffer yet;
   - `follow_changes_session({ id = id, state_directory = kept_places().state_directory })`, held in the session until `find` answers.
4. `arrangement()`: `give_report_environment()` (276) moves the directory's records to the session when it has none of its own, then `report_buffer()` (279) shows its records.
5. `aineo.layout.open(…)`.
6. `keep_input_draft()` (294): `set_draft_environment(kept_places())`, given once (`draft_environment_given`, 174), moves the directory's draft to the session when it has none of its own. Then `keep_draft(<the Input layout.open has just made>)` restores the session's draft into that empty buffer.

The ruling on T36-1 and T39-3 stands. The first start is not reordered; `begin_session()` comes before the changes home's follow (step 2 before step 3).

**At a later start, `\o` or `:Aineo open` after an exit.**
- When the start's session is another, `start_session()` calls T39's handler before it returns, and the homes, their environments given by then, follow at once.
- `begin_session()` then does nothing.
- Step 3's telling then names the session already followed, and changes nothing.

On a restart on the same session nothing is called back, and step 3 changes nothing.

**At a switch** — the hooks' `/clear`, `/resume`, `/branch` (`follow_switch()`), or T19's fallback (after `on_terminal_replaced`) — T39's handler tells the three homes the new `id` the same way.
- Each runs from a callback Neovim scheduled, so it can run under textlock. The homes make a refused swap again at `SafeState` (T39-6).
- ~~`on_session_switched`'s `source` and `reason` change nothing in the wiring: every source, `startup` included, is told (mutant 4).~~ *(2026-10-08: superseded; the gate is the start's confirmation, not the source, and mutant 4 is retired. See "Correction — 2026-10-08, from the brief review", below, T39-9.)*

**T36's notes bind this order.** Keep it, or say so in your report as a spec conflict:
- **The held-session path.** `follow_draft_session()`'s docstring (810–815) says: "`M.keep_draft()` reads that draft only into an empty buffer: a buffer handed it holding text is not checked against a held session's draft that cannot be read, and its first change replaces that draft, unwarned. A caller that holds a session hands `M.keep_draft()` an empty buffer, as `plugin/aineo.lua` does with the Input it has just made, which keeps that unreached." The finding behind it, FX4, was not taken (T36's *Correction* › *Not done*).
- **The second environment.** The same note's AD21 (a second environment) is not adopted, because "the composition root gives the environment once".

So:
- ~~the draft home is told a session before its environment only at the first start, in step 3;~~ *(2026-10-08: superseded; step 3 is gone, and the draft home is told a session only at a confirmation or a confirmed switch. See "Correction — 2026-10-08, from the brief review", below, T39-9.)*
- `keep_input_draft()` hands `keep_draft()` only the Input `layout.open()` has just made;
- `draft_environment_given` keeps the environment to one call.

**Shape.** A function of the composition root that tells the three homes one session is one way to keep the start (step 3) and the switch alike. It is also the place T40, after this packet, writes its editor entry and holds this wiring while a claim of another session holds (`plan.md` › *Packet T40*, A25). The seam is yours, under `tdd`.

### The rulings that bind this packet

Each is the orchestrator's, to report to the user, and none is a D row.

- **No wave-9 release before T39 merges** (`plan.md` A22; T36's and T37's fix rounds). This packet's merge is the release of feature B. If T38 merged first, its release waits for this one, and the two may be one.
- **`tests/test_entry_panes.lua` is this packet's** (T39-1), and T38 does not touch it.
- **D33: the editor's own section of the changes pane has no heading** (T38-1). Its lines stay exactly today's, so this packet's checks of the pane hold whatever T38 does to other worktrees' sections.
- **A8 and A9** (T38's: a `bare` entry, and a worktree whose directory is gone, left out) do not reach this packet. Its fixtures have no other worktree.
- **T39-5: the changes pane's checks pin only the session followed.** That means the editor's own entries, by content, in fixture repositories with no other worktree.
- **The homes hold a session told early** (the rulings on T36-1, T37-1). The first start is not reordered (above).
- **T35's rulings this packet builds on:**
  - A1, a switch is a `SessionStart` after the followed id's `SessionEnd`, paired by hook time (F1);
  - an `on_session_switched` that raises is warned, and goes no further;
  - hooks after the start's Claude Code exited are dropped.

### Counts on `dc5ff70`

Measured with `make test_file`, Neovim 0.12.5, each file alone. Every file printed `Fails (0) and Notes (0)` and exited 0.

| Test file | Cases | Why it runs |
|---|---|---|
| `tests/test_entry_panes.lua` | 86 | yours; its draft case moves |
| `tests/test_entry_claude_resume.lua` | 11 | yours where a case moves |
| `tests/test_entry_report.lua` | 4 | yours; its directory-records case (109) moves once the first start follows a session |
| `tests/test_entry_draft.lua` | 17 | yours where a case moves |
| `tests/test_entry_changes.lua` | 12 | T38's; run, never edited |
| `tests/test_entry_send_selection.lua` | 9 | run, not yours: *u in Input* › *after the draft was restored* (279) writes the directory's draft, which the first start now moves to the session |
| `tests/test_entry_claude_name.lua` | 11 | run (T33's status line) |
| `tests/test_entry_startup.lua` | 29 | run (the autostart reaches `started_claude_terminal()`) |
| `tests/test_entry.lua` | 48 | run |
| `tests/test_entry_claude_exit.lua` | 61 | run |
| `tests/test_plugin.lua` | 5 | run (its autocommand pin) |
| `tests/test_doc.lua` | 44 | run |
| `tests/test_claude_switch.lua` | 98 | run, not yours (T35's homes) |
| `tests/test_report_sessions.lua` | 47 | run, not yours (T36's) |
| `tests/test_draft_sessions.lua` | 79 | run, not yours (T36's) |
| `tests/test_changes_sessions.lua` | 61 | run, not yours (T37's; T38's to change) |

The whole suite on `dev` is **2229 cases** (the orchestrator's count). This amendment ran no whole suite. A file outside your boundary that goes red under your wiring is a spec conflict for your report, not an edit: that includes `tests/test_entry_send_selection.lua` and `tests/test_entry_changes.lua`.

### Rule 2 against T38, recomputed on `dc5ff70`

- **Code.** This packet's is `plugin/aineo.lua`. T38's is `lua/aineo/git/` and `lua/aineo/changes/`. They are disjoint.
- **Tests.** This packet's are the new `tests/test_entry_session_switch.lua` and the four entry suites above. T38's are the git suites, `tests/test_changes.lua`, `tests/test_changes_sessions.lua`, its two new suites, `tests/test_entry_changes.lua` and `tests/test_layout_diffs.lua`. They are disjoint.
  - `tests/helpers/git_repo.lua` is shared: T38 adds to it only, and your suite may require it.
  - `aineo.changes`' interface — `begin_session()`, `follow_changes_session()`, `refresh_shown_pane()`, `pane_buffers()` — is kept by T38 as T37 left it.
- **No registration file** is shared, and neither packet adds a module home.
- **`doc/aineo.txt`, under the section exception.**
  - This packet's places are 327–338, 731–737 and 1186–1188.
  - T38's places, as its own amendment gives them, are *aineo-panes*'s changes-pane item, 106–111; *aineo-changes* from its first paragraph to the end of its failures paragraph, 141–211, widened in that amendment; and LIMITS › `The changes pane ~` whole, 1128–1174.
  - The nearest pairs are separated by unchanged lines: 212–326 (*Colours*, *The file column*, the start of *aineo-claude-session*), and 1175–1185 (`Claude's window name ~` and its first three items). The `Undo ~` paragraph is far from both.
  - **Measured.** `git merge-file` ran on worst-case edits of `dc5ff70`'s help: every fenced line of both packets rewritten, and a line added after each fence. Each fence's first and last line was checked against its quote first. Result: 0 conflicts, with all 25 of this packet's lines and all 127 of T38's kept.
- **So T38 and T39 can still run at once** (S (a)). Before you push, merge with T38's branch if it exists: `git merge-tree --write-tree <your head> origin/feature/t38-changes-worktrees`. On the merged tree, run `make test_file FILE=tests/test_doc.lua`, your `tests/test_entry_session_switch.lua` and `tests/test_entry_changes.lua`, and report each.
- **T40 waits for this packet's merge** (its plan's rule 1). It then edits the same function and `tests/test_entry_panes.lua`, so nothing of T40 runs beside you.

### For the orchestrator, before dispatch: T19's fallback strands what the first follow moved

This consequence of the ruling that T19's fallback is a switch (T35-1, T39-2, D38's own case) was found by reading the merged code; no probe ran it. Neither the plan nor the briefs state it. It is not this packet's to decide: the remedy lies in the homes, outside this boundary.

- **When a start resumes a kept id with no conversation** (D38: "a `/clear` session in which nothing was sent"; or a start in which nothing was sent before the editor quit), step 3 first tells the homes that id. At the first start in an editor, that follow moves the working directory's records and draft to it (D39's history (i), A6).
- About 1.5 s later the fallback switches to a new id. `follow_draft_session()` then:
  - saves Input's text as the dead session's draft;
  - puts the new session's draft in its place — none, so Input is emptied (T36's *with no draft empties Input*).

  The Report shows the new session's records, which are none. The changes pane takes `HEAD`, and the marks made under the dead session go with it.
- The dead session can never be resumed (its id is replaced as the one kept, D38). So the draft typed for it, and on the first start the directory's whole history, is shown again only by a follow of that id: T40's `:Aineo claim <id>`, typed whole. Today's per-directory draft does not lose it.
- **The common case.** Notes typed in Input after a `/clear`, or in an editor where nothing was sent, then a quit and a new editor: the notes leave Input at the next start.
- **Both readings are open to the orchestrator** (or to the user, as a converge question):
  - (a) build as written — the fallback is a switch like any other — and name the case in LIMITS;
  - (b) the homes give a session that found no conversation's records, draft and kept base to the session that replaces it, which takes a change in `lua/aineo/report/`, `lua/aineo/draft/` and `lua/aineo/changes/`, outside this boundary.

  ~~Until the orchestrator rules, this packet builds (a). Its test of the fallback (T39-2) asserts what (a) gives, and its report names the case.~~ *(2026-10-08: the user answered on 2026-10-07, and chose neither reading. The panes wait for the resume to be confirmed: see the next section, "Amendment — 2026-10-08, the user's answer on a dead resume". This packet does not build (a).)*

## Amendment — 2026-10-08, the user's answer on a dead resume

**Base: `dev` `dc5ff70`**, as in the first amendment. This section was written by a second amending agent (Claude, Opus 5.5) for the orchestrator. Where it says so, it supersedes the body and the first amendment. Nothing above was edited except the first amendment's last paragraph, which now points here. The measurements are in `evidence/w9-t39-confirmation-probes.txt` (C1–C7), taken on `dc5ff70` with Neovim 0.12.5 and the suite's fake. The real Claude Code never ran.

### The question and the answer

The orchestrator put the first amendment's open case to the user on 2026-10-07 (AskUserQuestion). The question, verbatim:

> "When aineo resumes a kept session that has no conversation (common after a /clear with nothing sent), Claude Code starts a fresh session about 1.5 s later. As built, the panes first move the folder's Report and Input draft into the dead session, then switch to the new one: your Input text and marks are left behind in the dead session for good. How should T39 handle it?"

The user chose **"Wait for the resume (Recommended)"**, verbatim:

> "T39 tells the Report, Input and changes panel which session to follow only once the resume is confirmed (Claude Code ready, or its session-start hook), so nothing moves into a session that turns out dead. Stays inside T39 if the Claude home can say when a start is ready; the brief review checks that first."

**This is the user's decision, not an assumption.** It settles *For the orchestrator, before dispatch: T19's fallback strands what the first follow moved*, above: neither reading (a) nor reading (b) is built.

### What "the resume is confirmed" means

When each signal reaches the editor, in milliseconds after the start is launched (C1–C5):

| Signal | A resume that finds its conversation | A resume that finds none | A new session (no `--resume`) | No hook runs (A2) |
|---|---|---|---|---|
| **Claude Code ready**: `Start.ready`, which `session_status()` reports as `ready` | about 1550 | **never**; its replacement is ready about 1545 after its own launch, about 2990 after the first start | about 1550 | the same as with hooks, in all three cases |
| **The start's own `SessionStart` hook** (`resume` or `startup`) | about 80 | none in the fake; **never measured on the real Claude Code** | about 84 | none |
| **T19's fallback detection** | — | the replacement launches about 1440 after the start; then `on_terminal_replaced`, then `on_session_switched(<new>, 'startup', <dead>, nil)` | — | the same |

**The confirmation is readiness:** the first time a start's Claude Code is ready for input. The design rests on that alone, for these reasons.

- **It comes in every case.** It needs no hook, so it comes in a folder where none runs (A2) and under settings aineo cannot add its hooks to. A resume that finds no conversation never reaches it (C2): Claude Code 2.1.283 drew no screen of its own then (wave 6, `00006-fixes/evidence/claude-resume-q8.txt`).
- **The hook is left out.** The user's answer names both signals, so this choice is the amender's reading, for the brief review and the orchestrator to confirm:
  - M7: no hook runs before a trust dialog is answered.
  - It was never measured whether the real Claude Code runs `SessionStart(resume)` on a resume that finds no conversation. Wave 6's runs had no hooks, and M1–M8 resumed no such id (C3). If it does run, a confirmation by hook would confirm the dead id: the very strand the user's answer rules out.
  - The fake runs its hook in `trust` mode while the dialog shows (C4), and the real Claude Code does not. A confirmation by hook would pass the suite where the real Claude Code behaves otherwise.
  - The cost: the panes follow about 1.47 s later than the hook would let them (C3).
  - A measurement could admit the hook later as an earlier signal. It would be the orchestrator's, taken with the user's leave as M1–M8 were: the real Claude Code 2.1.292 resuming an id with no conversation, under a `SessionStart` hook.
- **T19's fallback detection is no confirmation.** It says only that a start failed. Its replacement waits for its own readiness, like any start.
- **A start is confirmed once.** Readiness that goes and comes back with a dialog (C6) does not confirm it again.
- **A start whose Claude Code exits first is never confirmed,** even though its settle timer can fire after the exit (C7).

### What the claude home exposes, and what T39 adds

**The state is exposed, the moment is not.** `session_status()` (`lua/aineo/claude/init.lua` 537–558) reads `Start.ready`, which the readiness watch sets in `launch()` (283–285). Nothing tells a caller when a start becomes ready. Meanwhile `on_session_switched` is called for a start before it is ready (C5), and for the fallback (C2). **So the claude home does not yet say when a start is ready, and the user's condition "stays inside T39 if…" is not met as things stand.**

**T39 adds one callback to `aineo.claude.Settings`**, for instance `on_session_ready? fun(id: string)`. The name is the implementer's, under `clean-code`; the contract binds:
- It is called once per start: each `launch()`, the fallback's included, the first time readiness reports that start ready.
- ~~It is called only while that start is still the session and its process has not ended (C7).~~ *(2026-10-08: superseded; it is also never called once Neovim is quitting. See "Correction — 2026-10-08, from the brief review", below, T39-1.)*
- It is called with the id the start follows at that moment (`followed`).
- It is called in the same callback that sets `ready`, after setting it. So a test that waits for `session_status()` to say `ready` sees the callback already called.
- It is validated as `on_session_switched` is (`'function', true`). An error it raises becomes a warning, as in `tell_switch()`, and goes no further.
- It runs from readiness's deferred callback: on the main loop, which the changes home's follow requires (E5560), and possibly under textlock (T39-6).
- It is never called for a resume that finds no conversation, a dialog never answered, or a Claude Code that exits before its input box settles.

**Rejected: a poll.** The composition root could poll `session_status()` on a timer at each start, and T39 would stay inside `plugin/aineo.lua`, as the user's answer hoped. It is rejected because:
- it runs a timer per start for something the home already knows;
- it adds up to one timer period of latency;
- it makes a caller read how the home works rather than what it says (`modularity`).

The answer named that condition, so the orchestrator may report the widening to the user.

**Rejected: the claude home holding its own start-switch calls until confirmation.** That would change T35's merged contract: the call inside `start_session()` before it returns, which `tests/test_claude_switch.lua` pins (*a start in place of the session followed* › *in another directory is told as a switch to the session it resumes*). T35's tests are not T39's to move.

**The boundary is widened**, for this one file. This replaces the body's ban on "every file under `lua/`" here:
- **`lua/aineo/claude/init.lua`, in these places only:**
  - the `aineo.claude.Settings` class (14–24), gaining one field after 24;
  - the `aineo.claude.Start` alias (31–38), when a field is added there;
  - `validate_settings()` (130–149), one line;
  - ~~`launch()` (255–298): its docstring and its readiness callback (283–285);~~ *(2026-10-08: superseded; the fence in `launch()` is widened. See "Correction — 2026-10-08, from the brief review", below, T39-7.)*
  - `M.start_session()`'s docstring (455–522).

  Not `readiness.lua`, not any other file of `lua/aineo/claude/`, and nothing else under `lua/`.
- **A new `tests/test_claude_ready.lua`** tests the callback.
- **Run, not edited:** `tests/test_claude.lua` (117 cases on `dc5ff70`), `tests/test_claude_resume.lua` (49) and `tests/test_claude_switch.lua` (98), each measured with `make test_file`, `Fails (0)`.
- **The fake needs nothing new.** Every mode the tests below use exists: `ready`, `trust`, `asks`, `exit`, and `AINEO_FAKE_CLAUDE_CONVERSATIONS`. `tests/helpers/` stays out of bounds.
- **`.claude/agents/neovim-claude-code-integrator.md` binds this edit**, since it is code that runs Claude Code. The brief's first line already has it read.

### The wiring, under the wait

T39 tells the three homes a session in two cases only:
1. **At a start's confirmation** (`on_session_ready(id)`): the three follows with `id`, as the first amendment's step 3 named them: report, then draft, then changes with `kept_places().state_directory`.
2. **At a switch told while the running start is confirmed**: the hooks' `/clear`, `/resume` and `/branch` (`follow_switch()`), which only a running Claude Code makes. These are told at once, as before.

**A switch that arrives before the running start is confirmed is not told.** That covers the start's own call inside `start_session()` (a later start whose session is another, C5) and T19's fallback's call (C2). The confirmation that follows tells `session_id()`. By then that names the replacement, or, after a hook switch made before the confirmation, the id switched to.

**One way to know whether the running start is confirmed** (the seam is yours, under `tdd`): a flag in the composition root.
- It is set at `on_session_ready`.
- It is cleared before `start_session()` is called whenever no Claude Code runs (`session_status()` nil or `exited`, the only case in which it launches one).
- ~~It is cleared in `on_terminal_replaced`, which T35 calls before the fallback's switch.~~ *(2026-10-08: superseded; dropped. See "Correction — 2026-10-08, from the brief review", below, T39-12.)*
- **Clear it before the call, not after it returns:** the start's own switch comes before `start_session()` returns, in the same millisecond (C5).

**This supersedes the first amendment's *The order T39 wires them*:**
- **Step 3 is gone.** `started_claude_terminal()` no longer tells the homes anything. Steps 1, 2, 4, 5 and 6 stand.
- **At the first start nothing is told before the homes' environment or `keep_draft()`.** The confirmation comes at least 1.5 s after `open()`, `focus()` or `show_pane()` has returned (C1). So:
  - ~~T36's held-session paths are not reached at all: `keep_draft()` with a held session (A47) and the second environment (AD21);~~ *(2026-10-08: superseded; reachable when `layout.open()` raises after the start, and still safe. See "Correction — 2026-10-08, from the brief review", below, T39-9.)*
  - `begin_session()` has run, and its look has usually found the repository, before the changes home's first follow.
- **"At a later start… the homes… follow at once" no longer holds.** They follow at that start's confirmation.
- **The switches T39 tells at once are the hooks' only.** The first amendment's "At a switch — … or T19's fallback (after `on_terminal_replaced`) — T39's handler tells the three homes the new `id` the same way" now covers the hooks' switches, and only once the start is confirmed. The fallback's switch is held, and its new session is told at its own confirmation.
- **Every telling now comes from a callback Neovim scheduled** (readiness's timer or the hooks'), never from inside `start_session()`. The textlock rule (T39-6) covers both.

**The body is superseded the same way:**
- *The behaviour*'s first item now reads: the composition root tells the three homes the session Claude Code starts on **once that start is confirmed**. It still waits for no hook (A2), since readiness needs none.
- *The order at the first start* and *T19's fallback is a switch* are replaced by this section. For the claude home, the fallback stays D38's switch (T35-1, T35's mutant 11). For the panes it is a start, followed at its confirmation.
- *Nothing happens* gains a case: no telling for a start that is not confirmed.

### What the panes show while unconfirmed

**At an editor's first start: the folder's own records and draft, untouched.**
- No home follows a session yet.
  - The Report shows the directory's records (`kept_records_file()`).
  - `keep_draft()` restores the directory's draft into the new Input.
  - The changes pane's base is `HEAD` as `begin_session()`'s look finds it. This editor's saves are held in memory, and nothing is kept: `keep()` keeps nothing while no session is followed.
- What is typed in Input is saved as the directory's draft. No report can arrive before Claude Code is ready.
- **At the confirmation of `id`:**
  - the directory's records and draft move to `id` when it has none of its own (A6 as corrected), with the text typed meanwhile, and the Report and Input show them;
  - when `id` has records or a draft of its own (a resume of a session that kept them), the panes show those, and the directory's files stay for the next editor's first follow (A6).

**At a later start, the homes follow `S`,** a session confirmed earlier. The panes keep showing `S`'s records, draft and base, untouched, and what is typed in Input is `S`'s draft. At the new start's confirmation the homes follow it, which keeps Input's text as `S`'s draft (D40).

**A consequence the wait adds.** This was read from T37's code, not probed.
- At the confirmation, the changes home takes `id`'s kept base and saves, or else `HEAD` at that moment with no saves (`use_kept_base()` replaces the saves; `take_head()`).
- ~~So a file saved in this editor before the confirmation loses its `*` in the pane: in the first 1.5 s after a start, or 3 s after a dead resume (C1, C2). The file is still listed against the base.~~ *(2026-10-08: superseded; the window is however long the start stays unconfirmed. See "Correction — 2026-10-08, from the brief review", below, T39-2.)*
- Without the wait, the follow arrived before the repository was found, and `find` carried those saves over (`early_saves`).
- ~~This is `lua/aineo/changes/`, which is T38's, so this packet does not change it. T39's paragraph of the help names it. The orchestrator may give it to T38 or to a later packet.~~ *(2026-10-08: superseded; the orchestrator has ruled: the behaviour stays, and T38's help says so. See "Correction — 2026-10-08, from the brief review", below, T39-2.)*

### If confirmation never comes

Three cases:
- a folder not yet trusted, whose dialog is answered "No, exit";
- a Claude Code that exits, or is stopped, before its input box settles (C7);
- a `claude.cmd` that never draws Claude Code's input box.

In each:
- **Nothing moves.** The homes are told nothing for that start. At a first start the folder's records and draft stay where they are and stay shown; at a later start, the session followed before does. What is typed is saved there, and nothing is lost.
- **A dialog still up is waited out.** The panes follow once it is answered "Yes" and the input box settles. What follows a "Yes" on the real Claude Code was not seen (M7). Readiness's recorded screens include the trust dialog of 2.1.280.
- **The next start waits for its own confirmation.** Nothing carries over from the unconfirmed one.
- **No timeout confirms.** A start that never becomes ready is never followed.

### A later start on another session

T35 calls `on_session_switched` inside `start_session()`, before it returns (C5; the first amendment, *T35 — `aineo.claude`* › *A start whose session is another*). Under the wait, T39 does not tell the homes then, because that start is not confirmed. They follow at its confirmation, with `session_id()` at that moment:
- the start's own id;
- or, when the start resumed an id with no conversation, the fallback's new id (C5: ready at 5807 ms).

Until then the panes stay on the session followed before.

### What the wait does not reach — for the orchestrator, before dispatch

This was found by reading the merged code, not probed. The user's question calls the case "common after a /clear with nothing sent". ~~The wait keeps the folder's records and draft out of a session that turns out dead, and with them what is typed while a start is unconfirmed.~~ *(2026-10-08: superseded; it keeps them out of a session that is dead at its start only. See "Correction — 2026-10-08, from the brief review", below, T39-8.)* **It does not reach what was kept under a session while that session was confirmed and alive.**

- **After a `/clear` with nothing sent,** the panes follow its new id `X` at once, since it is a hook switch of a confirmed start.
  - Input is emptied, because `X` has no draft (D40). The notes typed after that are `X`'s draft, and the marks are `X`'s.
  - Quit, then open a new editor. The start resumes `X`, finds no conversation, and the fallback's new session `Y` is followed at its confirmation.
  - `X`'s draft, marks and records stay under `X`, which is never resumed again (D38). Only T40's `:Aineo claim <id>` shows them.
- The same holds for a start in which nothing was sent before Claude Code exited, followed by `\o`.
- **So in the very case the question names, the notes typed after the `/clear` still leave Input.** The question said "your Input text and marks are left behind in the dead session for good". The wait answers that for the folder's move and for the wait's own window, not for these notes.
- **Reaching them needs the homes** to give a dead session's draft, records and kept base to its replacement. That is the first amendment's reading (b), in `lua/aineo/report/`, `lua/aineo/draft/` and `lua/aineo/changes/`, outside this boundary.
- Whether to ask the user is the orchestrator's call. Until then, T39's paragraph of the help (327–338) names the case, and so does this packet's report.

### Mutants and tests for the wait

These replace the plan's T39 list (`plan.md` › *Verification mutants* › T39) where they say so; that list is not edited here.

**The plan's mutants:**
- 1, 2 and 5 stand.
- **3 now reads:** the started session is not told at its confirmation, because the callback is not wired. With no hook (A2), a report sent after `ready` lands in the directory's records, not the started session's.
- **4 is retired.** It ignores the switch callback for `startup`. Under the wait the fallback's switch is not told by design, so the edit changes nothing a test can see.

**New, each an edit of `plugin/aineo.lua`, on `tests/test_entry_session_switch.lua`:**
- **6. The homes are told at the start, before confirmation** (the first amendment's step 3 kept). A first start on a kept id with no conversation strands the draft: the directory's draft moves into the dead id, Input is emptied at the fallback, and the new session has no draft.
- **7. A switch is told while the start is unconfirmed** (the hold dropped). A later start in another directory resumes an id with no conversation. Text typed in Input right after that start is saved as the dead id's draft, not as the draft of the session left. The dead resume gives about 1.4 s for the typing (C5).
- **8. The hold is never lifted** (the flag is not set at confirmation). A `/clear` after `ready` is not followed, and the Report keeps the old session's reports.
- ~~**9. A timeout stands in for the confirmation** (the homes told after a fixed delay). Under the fake's `trust` mode, the folder's draft moves into the start's id.~~ *(2026-10-08: superseded; mutant 9 is given as a literal edit. See "Correction — 2026-10-08, from the brief review", below, T39-5.)*

**New, each an edit of `lua/aineo/claude/init.lua`, on `tests/test_claude_ready.lua`:**
- **10. The callback is called at the launch, not at readiness.** A resume with no conversation calls it with the id it could not resume.
- **11. It is called at every readiness, not only the first.** The `asks` mode's dialog (Enter, then Esc, C6) calls it twice.
- **12. The start guard is dropped.** The `exit` mode's start, which becomes ready after its exit (C7), calls it.

**The tests**, each seen failing first. They replace *The tests*' first item, the fallback item (T39-2) and the first-open item (T39-3):
- **Before confirmation and after `ready`**, with no hook (A2):
  - before confirmation, the Report shows the directory's records and Input shows the directory's draft;
  - after `ready`, a report lands in the started session's records, Input holds that session's draft, and the changes pane's base is that session's.
- **T19's fallback at a first start** (mutant 6):
  - the directory's draft and records become the new session's, and so does what was typed in Input before the fallback;
  - no draft, records or kept base exists for the id that found no conversation.
- **A later start in another directory**, resuming an id with no conversation (mutant 7): what is typed before confirmation stays the old session's draft, and the panes follow the new session at its `ready`.
- **Confirmation never comes** (mutant 9): the `trust` mode, checked after a bounded wait longer than a dead resume's 3 s (C2), with the bound named in the test.
  - The folder's draft and records stay the directory's.
  - Typed text is saved there.
  - ~~No session file is made.~~ *(2026-10-08: superseded; T35 keeps a new id's `aineo/claude-sessions/` file at the start. The assertion is "no records, draft or kept-base file for the session". See "Correction — 2026-10-08, from the brief review", below, T39-5.)*
- **A hook switch after `ready` is told at once** (mutant 8). The body's `/clear` test does this, once it waits for `ready` first.
- **In `tests/test_claude_ready.lua`**, the callback is:
  - called once, with the started id, after `ready`, both for a resume that finds its conversation and for a new session;
  - never called for a resume with no conversation, but called once for its replacement, with the new id;
  - called once across the `asks` dialog;
  - never called under `exit`;
  - when it raises, warned of, and the session goes on.

**Wait for `ready`, not for a time,** wherever a test needs the confirmation (`claude_session.wait_for_status(child, 'ready')`). The callback runs inside the readiness callback that sets it.

~~**T39-1 still holds, now through the confirmation.** The draft case at `tests/test_entry_panes.lua` 601–619 waits for the typed text in the directory's file. Under the wait the text is there until `ready`, then moves to the session's file. Whether that case changes depends on when it types. If it changes, name it in your report. The same goes for `tests/test_entry_report.lua` (109) and `tests/test_entry_send_selection.lua` (279): their moves now happen at the confirmation, not at the start.~~ *(2026-10-08: superseded by the measured forecast. See "Correction — 2026-10-08, from the brief review", below, T39-4.)*

### Rule 2, rechecked

**Against T38: disjoint.**
- *Code:* this packet's is now `plugin/aineo.lua` and `lua/aineo/claude/init.lua`; T38's is `lua/aineo/git/` and `lua/aineo/changes/`.
- *Tests:* `tests/test_claude_ready.lua` (new) joins this packet's, and T38 touches no `tests/test_claude*.lua`.
- *Help:* this packet's places are unchanged (327–338, 731–737, 1186–1188), so the first amendment's merge measurement stands. ~~The lost `*` is told in T39's paragraph, not in T38's *aineo-changes*.~~ *(2026-10-08: superseded; T38 words it in *aineo-changes*, and T39's paragraph points there. See "Correction — 2026-10-08, from the brief review", below, T39-2.)*
- **T38 and T39 can still run at once** (S (a)).

**Against T40: sequenced, and T40's amendment must build on this.**
- T40's plan holds `lua/aineo/claude/`: `hook_relay.lua`, `arguments.lua`, `session_ids.lua`, and in `init.lua` the start token and the `is_session_id()` re-export.
- In `plugin/aineo.lua`, T40 holds:
  - the editor's entry, written "where T39's wiring tells the homes a session";
  - "T39's switch and start wiring held while a claim of another session holds".
- `launch()` holds the start token (270–271) and now this callback, so both packets edit it. Rule 1 already makes T40 wait for T39's merge, so the two never run at once.
- **T40's dispatch amendment must build on what T39 adds:**
  - the `Settings` field and its once-per-start contract;
  - `launch()` as T39 leaves it;
  - the wiring's two kinds of telling. The editor's entry is written at a confirmation and at a confirmed switch, never at a start, and a claim's hold must cover the confirmation as well as the switches.

  T40's plan says none of this; its amendment adds it.

**Against T35–T37: merged.** T35's contract is extended, not changed: one new optional field. `on_session_switched`'s calls and their order stay as T35's tests pin them.

**The six-rules table** (`plan.md` › *Packets*) gains, in T39's row, `lua/aineo/claude/init.lua` (in the places above) and `tests/test_claude_ready.lua`. That table is not edited here: the brief review recomputes it (`Waves/CLAUDE.md`).

### Stage 1's knowledge pass: what it named false in this brief

Stage 1's knowledge pass named two statements of this brief false:
- that the switch reaches the homes from T35's scheduled callback (*The behaviour* › *Textlock*);
- that the callback takes three arguments (*At a switch*: "with the new id, its source and the session left"; *T19's fallback is a switch*: `on_session_switched(<new id>, 'startup', <old id>)`).

The first amendment already gives the true statement, and it is the one that stands (*The three homes' entry points, as merged* › *T35 — `aineo.claude`*):
- the callback takes four arguments, `(id, source, left, reason)`;
- a later start whose session is another calls it synchronously, inside `start_session()`, before it returns.

This section relies on that statement and does not give a second one. Under the wait, T39 does not pass that synchronous call on to the homes (*A later start on another session*). Every telling therefore comes from a scheduled callback, and the body's textlock item holds as written for what the homes are told.

## Amendment — 2026-10-08, the user's answers on the hand-over and the ready signal

**Base: `dev` `dc5ff70`**, as in both earlier amendments. Written by the same amending agent (Claude, Opus 5.5), for the orchestrator, after the user answered two of the questions the previous section left open. Nothing above is edited. Where this section settles something the previous one left to the orchestrator or to the brief review, it says which.

### The hand-over of a dead session: the user's answer

The orchestrator asked the user, on 2026-10-08 (AskUserQuestion), whether a dead session's draft, Report and changes base should be handed to the session that replaces it. The user chose **"Yes, as packet T41 (Recommended)"**, verbatim:

> "When a resume finds no conversation and Claude Code starts a fresh session, the fresh session takes over the dead one's Input draft, Report records and changes base. A small separate packet after T38 and T39, since it touches the report, draft and changes homes that T38 is changing."

**This is the user's decision, not an assumption.** It settles the previous section's *What the wait does not reach — for the orchestrator, before dispatch*:
- **T39 does not build the hand-over.** That is the first amendment's reading (b), and it now belongs to **T41**: a packet of its own after T38 and T39. It changes `lua/aineo/report/`, `lua/aineo/draft/` and `lua/aineo/changes/`, which stay outside T39's boundary.
- **T41 is planned in its own knowledge pull request,** after PR #140 merges. This brief does not plan it, and gives it no boundary, tests or mutants.
- **T39's wait stands as the previous section gives it.** The panes follow a start only once it is confirmed. At T19's fallback, T39 follows the replacement at its confirmation. Nothing in T39 moves a dead session's files.
- **The help and the report.** Until T41 merges, the case stays as the previous section describes it: what was kept under a session while it was alive stays there when a later resume of it finds no conversation.
  - T39's paragraph of the help (327–338) names the case in one sentence, which T41 will make false and replace.
  - Your report names the case and points to T41.
  - A test or a mutant of T39 that pins the stranded state is not wanted: T41 would move it. T39's fallback tests assert only what the wait gives (the previous section's mutants 6 and 7).

### The ready signal: the user's answer

The orchestrator asked the user, on 2026-10-08 (AskUserQuestion), how T39 should get the signal that a start is ready. The user chose **"Add one callback (Recommended)"**, verbatim:

> "T39 adds a single "start is ready" callback to `lua/aineo/claude/init.lua` (fenced to the settings, `launch()` and docs), with its own test file. Clean and testable; T40 later builds on it."

**This is the user's decision, not an assumption.** It settles the previous section's *What the claude home exposes, and what T39 adds*:
- **The widening into the claude home is the user's,** not the amender's reading. The user's first answer said "Stays inside T39 if the Claude home can say when a start is ready". The home cannot, as things stand, so the user chose the callback over the poll. The previous section's "the orchestrator may report the widening to the user" is done.
- **The boundary is as the previous section fences it:**
  - `lua/aineo/claude/init.lua`: the `Settings` class (14–24), the `Start` alias (31–38) when needed, `validate_settings()` (130–149), `launch()` (255–298) and `M.start_session()`'s docstring (455–522);
  - a new `tests/test_claude_ready.lua`.

  The callback's contract, the rejected poll and the rejected hold of T35's calls stand as written there.
- **"T40 later builds on it"** agrees with the previous section's *Rule 2, rechecked*: T40's dispatch amendment builds on the callback, on `launch()` as T39 leaves it, and on the wiring's two kinds of telling.
- **Still the amender's reading, not settled by this answer:** that the confirmation is readiness alone, with the start's own `SessionStart` hook left out. The user's first answer named both signals; this one names "a single 'start is ready' callback", which is the readiness signal. The brief review confirms it.

### The attack review

T39's attack review goes to **`neovim-claude-code-reviewer`**, as `plan.md` › *Host and reviewers* already gives it for T39 ("the switch crosses the Claude integration"). Test integrity and records go to `reviewer`. The previous section's widening into `lua/aineo/claude/init.lua` gives that reviewer a second reason: this packet now edits code that runs Claude Code. The implementer reads `.claude/agents/neovim-claude-code-integrator.md`, as the brief's first line says.

### The save marks lost before confirmation: T38's code

The previous section names a consequence of the wait, read from T37's code and not probed. At a start's confirmation, the changes home takes the session's kept base and saves, or `HEAD` and no saves (`use_kept_base()`, `take_head()`). So a file saved in this editor before the confirmation loses its `*` in the pane. The file is still listed against the base.
- **That code is `lua/aineo/changes/init.lua`, which T38 owns** while it runs. T39 does not change it, and must not work around it in `plugin/aineo.lua`, for example by telling the changes home earlier than the other two homes. That would bring back the strand the wait removes, for the base.
- ~~**Named for T38's brief review,** to decide whether T38 carries this editor's unfollowed saves into the first follow, or leaves the case to LIMITS. The decision is the orchestrator's, on that review.~~
- ~~**Until it decides,** T39's paragraph of the help names it in one sentence. If T38 takes it, T39 drops that sentence; whichever of the two merges second checks the help on the merged tree.~~ *(2026-10-08: both superseded; the orchestrator has ruled. The behaviour stays, T38 words it in *aineo-changes*, and T39 writes no lost-`*` sentence. See "Correction — 2026-10-08, from the brief review", below, T39-2.)*
- T39's tests do not pin the lost mark~~: T38 may change it~~. *(2026-10-08: the reason is superseded; T38 keeps the behaviour and words it. The tests still do not pin it. See "Correction — 2026-10-08, from the brief review", below, T39-2.)*

## Correction — 2026-10-08, from the brief review

The stage-2 brief review (`brief-review-stage2.md` in this folder, on `e5ef23a`, against `dev` `dc5ff70`) found this brief dispatchable only after corrections: thirteen findings, T39-1 to T39-13. No packet had been dispatched, so each is applied here. Each superseded line above is struck through with a dated pointer to this section (T39-9), and nothing else above was edited. Where the review left a choice, the orchestrator ruled under the user's instruction of 2026-10-06 ("assume your recommendations and report what they were after you finish"). Each such ruling is named below as **the orchestrator's assumption, to report to the user**. None is the user's answer.

**Base.** `origin/dev` is now `2fdda81` (PR #140, stage 1's knowledge pass). It changed no code, test, help or script: `git diff --stat dc5ff70 2fdda81 -- lua plugin tests doc scripts Makefile` prints nothing. Every line number in this brief holds there. Start from the `origin/dev` the dispatch message names.

**Implementer type (T39-13) — the orchestrator's assumption, to report to the user.** This packet is dispatched as **`neovim-claude-code-integrator`**, not `neovim-lua-developer`, since it now edits `lua/aineo/claude/init.lua`, code that runs Claude Code. That agent binds its own rules and every rule of `.claude/agents/neovim-lua-developer.md`, and it was T35's type. Read both, as the first line says. The attack review stays with `neovim-claude-code-reviewer`; test integrity and records stay with `reviewer`. `plan.md` › *Packets* (T39's row), › *Host and reviewers* and › *Briefs* still name `neovim-lua-developer`. This section supersedes them for T39, and the wave's knowledge pass records the change there.

**Read first** also: `evidence/w9-t39-confirmation-probes.txt` (C1–C7) and `lua/aineo/claude/readiness.lua` (read, not edited).

### T39-1 — the confirmation never runs once Neovim is quitting (the orchestrator's assumption, to report to the user)

The review measured it. A `ready` fake was started and the child ran `:qall!` 400 ms later. The callback still ran while `stop_on_quit()`'s `VimLeavePre` waited for Claude Code to stop: `v:exiting` was set, and the process had not yet ended. `readiness.watch()`'s `vim.defer_fn()` timer runs inside that wait's event loop. Told then, the homes would move the folder's records and draft into a session in which nothing was sent. That is the strand the wait exists to close, reached by quitting within about 1.5 s of `nvim`.

- **The contract gains a clause.** The ready callback is called only while that start is still the session, its process has not ended (C7), **and Neovim is not quitting (`v:exiting` is not set)**. This replaces the struck line in *What the claude home exposes, and what T39 adds*. It follows T35's own pattern: `take_session_event()` and the fallback drop work once `v:exiting` is set.
- **A test in `tests/test_claude_ready.lua`:** the callback writes a file; the child quits 400 ms after the start; no file is written.
- **Mutant 13**, an edit of `lua/aineo/claude/init.lua`, on `tests/test_claude_ready.lua`: the `v:exiting` guard dropped. The test above kills it.
- It reaches T40 too: see *For T40's dispatch amendment*, below.

### T39-2 — the save marks lost before the confirmation stay lost (the orchestrator's assumption, to report to the user)

**Ruling: the lost `*` stays, as the review recommends.** A file saved before a start is confirmed is not marked for that session. That matches D19's definition: the `*` marks a save since the base, and under the wait the base is taken at the confirmation, so a save before it predates the base.

- **The behaviour is measured** (the review's `probe_wait.lua`, the changes home alone). Before any follow the line is `{ "* M notes.txt" }`; after the first follow it is `{ "  M notes.txt" }`; the kept record holds `"saved":[]`. The cause is `use_kept_base()` (`lua/aineo/changes/init.lua` 399–401), which sets `session.saved = {}` when nothing was kept for the session, and `take_head()`, which keeps no saves.
- **The window is wider than this brief said.** It is however long the start stays unconfirmed: a trust or MCP-server dialog left up, or a real Claude Code's startup, which was not measured. The 1.5 s, or 3 s after a dead resume (C1, C2), is only the fake's timing.
- **At a later start,** saves made before the new start's confirmation are marked for the session followed before, `S`.
- **It is not T38's code to change,** and not this packet's. Carrying the unfollowed saves would rewrite T37's documented contract (`follow_changes_session()`'s docstring, 638–654: "`HEAD` at this moment … and no saves").
- **T38 writes the help sentence,** in *aineo-changes*, where the `*` is described (162–164). T38's brief names it as T38's to word.
- **This packet writes no lost-`*` sentence.** Where its paragraph of *aineo-claude-session* needs the point, it refers to `|aineo-changes|`. Its tests still do not pin the lost mark.
- **No workaround here.** This packet still must not tell the changes home earlier than the other two homes in `plugin/aineo.lua` (the previous amendment's last section).

### T39-3 — text typed in Input before the confirmation can leave Input (the orchestrator's assumption, to report to the user)

The review measured it with `probe_wait.lua`, the draft home alone, in the wait's order:
1. the environment;
2. `keep_draft(<empty Input>)`;
3. `notes typed while unconfirmed` typed;
4. `follow_draft_session(<an id with a draft>)`.

Input then holds the session's own draft, and the directory's draft file holds the typed text. `move_directory_draft_once()` refuses with `EEXIST` and moves nothing.

- **The case.** When the confirmed session has a draft of its own, the text typed in Input before the confirmation stays in the folder's draft and leaves Input. It comes back only at some editor's *first* follow of a session with no draft (*aineo-draft*, help 368–371).
- **Who meets it.** Every editor in a directory after the one whose first follow moved the folder's files, when it resumes a session that kept a draft. Input shows nothing until `ready`, so a user who types at once loses that text from view at the confirmation. Under the old design (a follow at the start) it did not happen.
- **Name it** in this packet's paragraph of *aineo-claude-session* (327–338) and in the report.
- **T41's planning reads this as A61's case.** The question is whether T41, which already hands a dead session's draft over, also takes text typed in Input before the first confirmation. A61 is T41's planning's to write; this brief does not decide it.
- **This packet's tests must not pin the opposite.** No test asserts that the typed text ends in the session's draft when the session has a draft of its own.

### T39-4 — which entry cases move under the wait (measured)

The review ran the entry suites on a minimal build of the wait (the callback in `launch()`'s readiness callback, and the flag wiring in `plugin/aineo.lua`), Neovim 0.12.5. This replaces the struck forecast in *Mutants and tests for the wait*:

| Test file | Cases | Under the wait |
|---|---|---|
| `tests/test_entry_draft.lua` | 17 | **4 red**: yours to change (below) |
| `tests/test_entry_panes.lua` | 86 | 86 green, but 601–619 only by timing: yours to make deterministic (below) |
| `tests/test_entry_report.lua` | 4 | green, and stays as it is |
| `tests/test_entry_send_selection.lua` | 9 | green (not yours; run it) |
| `tests/test_entry_claude_resume.lua` | 11 | green |
| `tests/test_entry_changes.lua` | 12 | green (T38's; run it) |
| `tests/test_entry_claude_name.lua` | 11 | green |
| `tests/test_entry_startup.lua` | 29 | green |
| `tests/test_entry.lua` | 48 | green |
| `tests/test_entry_claude_exit.lua` | 61 | green |
| `tests/test_plugin.lua` | 5 | green |

- **The four `tests/test_entry_draft.lua` cases join this packet's work.** Each reads the directory's draft file after the confirmation has moved it:
  - *:Aineo send* › *from another window empties the draft with Input, at once* (94);
  - *:bdelete of Input* › *while the layout is open brings the draft back and keeps what is typed after it* (189);
  - *:bdelete of Input while its window is closed* › *then \r or \c, then \i, brings the draft back and keeps what is typed after it* (219), with `{ "r" }` and with `{ "c" }`.

  Change each to what the wait gives. Either wait for `ready` and read the session's draft, or, where the case is about the directory's draft, use a fake that never becomes ready. Name each in your report.
- **`tests/test_entry_panes.lua:601–619` is made deterministic.** It asserts the typed text in the directory's file. That holds only between the 1 s save (`SAVE_DELAY_MS`) and the confirmation's move (`SETTLE_MS`): a window of 530–590 ms in five runs (typed at 26–49 ms, in the file from 1037–1055 ms, moved at 1582–1636 ms). Typing later than about 0.5 s after the open turns it red. Either wait for `ready` and then assert the session's file, or assert the directory's file only under a fake that never becomes ready.
- **`tests/test_entry_report.lua` does not move.** The `mcp-client` fake reports at once and exits before its input box settles (`tests/helpers/fake_claude.lua` 706–708), so it is never confirmed. Its directory cases now pin the unconfirmed path, and stay as they are.
- **The build was the reviewer's, not yours.** Name in your report any case outside this table that moves under your build. One outside your boundary that goes red is a spec conflict.

### T39-5 — mutant 9 as a literal edit, and the bounds of the negative tests

- **Mutant 9 now reads**, as an edit of `plugin/aineo.lua`, on `tests/test_entry_session_switch.lua`: the ready callback not wired, and at the start, in its place, `vim.defer_fn(function() tell(require('aineo.claude').session_id()) end, 2000)`. Here `tell` stands for this packet's function that tells the three homes a session. Under the fake's `trust` mode, the folder's draft then moves into the start's id.
- **The `trust` test's wait is timed, and its bound is named:** at least 4000 ms after the start. That is above the mutant's 2000 ms and above a dead resume's 3 s (C2). "Wait for `ready`, not for a time" cannot apply where `ready` never comes.
- **The `exit` test's wait** ("never called under `exit`") **is timed too**, since `session_status()` never says `ready` there. Its bound is at least 3000 ms (twice `SETTLE_MS`, 1500) after the fake's first screen, named in the test.
- **"No session file is made" now reads "no records, draft or kept-base file for the session".** T35 keeps a new id's `aineo/claude-sessions/` file at the start.

### T39-6 — the budget and the mutants, restated

**Budget: large.**
- a ready callback in the claude home, and a new `tests/test_claude_ready.lua` of about eight cases, T39-1's and T39-11's included;
- the wiring in the composition root to three homes;
- in `tests/test_entry_session_switch.lua`, about twelve entry cases, and about five more for the wait;
- four cases of `tests/test_entry_draft.lua` and one of `tests/test_entry_panes.lua` moved;
- three help places;
- twelve mutants.

If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

**The mutants the verification runs for T39: twelve.** Name in your report the test that kills each.
- On `tests/test_entry_session_switch.lua`, edits of `plugin/aineo.lua`: the plan's 1, 2 and 5; 3 as the previous amendment rewords it; 6, 7 and 8; 9 as T39-5 gives it.
- On `tests/test_claude_ready.lua`, edits of `lua/aineo/claude/init.lua`: 10, 11, 12, and 13 (T39-1).
- 4 is retired (the previous amendment).

### T39-7 — the fence in `launch()`, widened

This replaces the struck `launch()` item of the boundary. In `lua/aineo/claude/init.lua` you may also change:
- **`launch()` 255–298 whole, except the start token (270–271)**, which is T40's. For instance: a once-per-start flag left `nil` in `launched` (273–281), the guard and the call in the readiness callback (283–285), and its docstring.
- **One of these two**, so the `pcall`-and-warn is not written twice:
  - one helper placed directly before `launch()`;
  - or `tell_switch()` (352–361) generalised to call either callback. Its callers' behaviour and its warning `aineo: on_session_switched failed: …` stay exactly as they are.

`tests/test_claude.lua`, `tests/test_claude_resume.lua` and `tests/test_claude_switch.lua` stay green and are not edited. The rest of the fence stands: the `Settings` class (14–24), the `Start` alias (31–38) when a field is added, `validate_settings()` (130–149), and `M.start_session()`'s docstring (455–522). Nothing else under `lua/`.

### T39-8 — what the wait keeps out, said exactly

The wait keeps the folder's records and draft out of a session that is dead **at its start**. It does not keep them out of a session that is confirmed and later turns out dead: a confirmed session in which nothing is ever sent is dead at its next resume. For example:
1. a first start after the upgrade resumes a kept id that is dead;
2. the fallback's new session is confirmed, and the folder's history moves into it at that confirmation;
3. nothing is sent, and the editor quits;
4. the next resume of that session finds no conversation, and the folder's history is stranded under it.

It stays stranded until **T41** hands a dead session's files to its replacement. Name this case with T41 where the help and your report name the stranded notes (*What the wait does not reach*).

### T39-9 — superseded statements, struck through

Each of these is struck above with a dated pointer:
- *The tests*' "five mutants" (T39-6);
- the *Budget* (T39-6);
- "every source, `startup` included, is told (mutant 4)": the gate is the start's confirmation, not the source;
- "the draft home is told a session before its environment only at the first start, in step 3": step 3 is gone;
- "T36's held-session paths are not reached at all": they are reachable when `layout.open()` raises after the start, so `keep_input_draft()` is skipped. It is still safe: `keep_draft()` is then handed a new, empty Input.

The lines superseded by T39-1, T39-2, T39-4, T39-5, T39-7 and T39-8 are struck the same way.

### T39-10 — where a report after `ready` comes from

The test "after `ready`, a report lands in the started session's records" needs a report sent after `ready`. The fake cannot send one: `mcp-client` reports at its start and exits unready. Send it one of two ways:
- through `tests/helpers/mcp_relay.lua`'s `start_relay()` (157), run and not edited;
- or through the editor's own RPC, the Lua `require('aineo.report').receive_report(...)` that `lua/aineo/mcp/editor.lua` (8) sends.

The fake still needs nothing new, and `tests/helpers/` stays out of bounds.

### T39-11 — a test for the callback's validation

`tests/test_claude_ready.lua` gains a case: the claude home names `settings.<the callback's name>` when it is not a function, and starts nothing. T35's equivalent sits in `tests/test_claude.lua`'s parametrised table (282–285), which this packet may not edit.

### T39-12 — no clearing of the flag in `on_terminal_replaced`

No input sets the flag before a fallback: a confirmed start would have to exit 1 showing "No conversation found with session ID: <its own id>". So a clear there could never be seen failing, as `tdd` requires.

**It is dropped.** The clear before `start_session()` covers every start the composition root makes. This replaces the third item of *One way to know whether the running start is confirmed*. The review offered two options ("call it defensive with no test, or drop it"); taking the second is the correcting agent's reading, for the orchestrator to confirm.

### For T40's dispatch amendment

The review's notes for T40, recorded here for its amendment:
- **"At every start" reads "at every start's confirmation".** T40's brief says its entry is written "at every start of Claude Code" (its line 77), and it holds "T39's start wiring" (its line 152). Under the wait, T39 tells the homes at a start's confirmation and at a confirmed switch, never at a start.
- **"No wave-9 packet touches section 7" is false** once this packet edits `Undo ~` (731–737, in *aineo-send*). T40's seventh help place, *aineo-send*'s paragraph of refusals, is in the same section.
- **The `v:exiting` guard (T39-1) reaches T40 too.** T40 writes its editor entry where this packet tells the homes. Without the guard, a confirmation that ran after T40's `VimLeavePre` removed the entry would write a stale one.
