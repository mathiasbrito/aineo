**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> **Agreed and amended, 2026-10-07.** The user answered the converge round on 2026-10-07: P9 is (a) with history (i), now D39; **P10 is per session**, over the recommendation, now D40 — so **Input's draft is in this packet**, beside the Report (*The draft per session*, below). Wave 8's T34 merged (PR #128), and every fact below was read again at `dev` `f98bd9d`. The orchestrator measured M5 the same day (`evidence/w9-real-claude-sessions.txt`). **Corrected 2026-10-07 from the brief review** (`brief-review.md` in this folder, T36-1 to T36-6, W-2 and W-4): the corrections are made in the body, and *Correction — 2026-10-07, from the brief review*, at the end, lists each. Still before dispatch: wave 8's finish (the user's go: "when wave 8 finishes start right streight wave 9"). The *Amendment — 2026-10-07* at the end gives the answers.

## Objective

The task, verbatim from the task list:

> | T36 | The Report and Input's draft per session (C6, C11; D39, D40): reports are kept per Claude session id, a report under the session aineo follows when it arrives, and the Report can be shown for another session; the working directory's records become the session kept for it; Input's draft is kept per Claude session id, and following another session keeps Input's text as the old session's draft and puts the new session's in its place | T5, wave 8's T34, M5 | planned — wave 9 |

It rests on: D39 (the Report per session) and D40 (Input's draft per session), agreed 2026-10-07; C6 (the report's format, rendering and records, "persisted under `stdpath('state')`"), C14 (the Report line), D8 (reports through the MCP tool); C11 and D17 (Input's draft), whose "per working directory" D40 supersedes and whose saving and restoring stand; D26 and D29; and P9's and P10's alternatives.

### The behaviour — the Report (D39)

The user's answer: "all your recommendations are fine" (the whole answer is in the amendment).

- **One records file per Claude session**, under the same `stdpath('state')/aineo/reports/` folder as today, named so that no session id can make an invalid or colliding name (today's files are named by a SHA-256; keep a scheme of that kind, and say which in the help).
- **The report home follows a session.** A new entry point (its name is yours) tells the home which session's records the Report shows and keeps reports under: it shows that session's records in the Report, in place of what it showed, and keeps every report received from then on in that session's file. A session with no records yet shows an empty Report. Following the session already followed changes nothing (the Report's lines, its cursor and its windows stay).
- **Before the home is told any session**, it keeps and shows the working directory's records exactly as today. Nothing in this packet calls the new entry point: T39 wires it to the composition root once T35 says which session Claude Code is on. So `dev` behaves as before when this packet merges.
- **Told before its environment (the orchestrator's ruling on T36-1, to report to the user).** The home accepts a session before `set_report_environment()` has given it a state directory and a working directory, and holds it until then: when the environment arrives, the Report shows that session's records and the move below runs. Today the home raises without an environment (`lua/aineo/report/init.lua:64–69`), and at the first `:Aineo open` T39 will tell it the session before the composition root gives the environment: `started_claude_terminal()` is evaluated as an argument of `arrangement()` (`plugin/aineo.lua:290`), whose first line gives the environment (273). T39 does not reorder that start.
- **History, (i):** the first time the home follows a session in an editor, when the working directory's records file exists and that session has none, the directory's file **becomes** the session's (moved, not copied), so every report shown today stays shown, with that session. When both exist, neither is touched, and the session's are shown — so a directory file written after the first move, by an older aineo in another editor say, is never shown again. A move that fails is told once as a warning, as the home tells a records failure today, and the session's file is used from then on.
- **Two Neovims following one session** share its records, each appending to the one file, as two in one directory share them today (A7, the orchestrator's assumption, to report to the user).
- **Textlock.** Showing another session's records is a change of the Report's lines made from T35's scheduled callback, through T39. [[Learnings/A scheduled callback can run under textlock, where Neovim refuses a buffer change with E565]] names "a report rendered into the Report" among the places it applies. A change Neovim refuses (`E565` alone; any other error is raised again) is made again at the editor's next `SafeState`, and again at the one after while it is still refused, as the changes home's `show_page()` does (`lua/aineo/changes/init.lua:84–115`, with `scratch.write_text()` telling the refusal from another error); the session is followed either way.
- **A report is kept under the session followed when it arrives** — Claude Code's MCP server cannot say which session sent it (B2). M5 measured one MCP server for Claude Code's whole life, never restarted by a switch, its `CLAUDE_CODE_SESSION_ID` the first session's and stale after `/clear`, `/resume` or `/branch`: so nothing here reads a session from the MCP server or its environment (A4).
- **What stays:** the records' format (`{ time, report }`), the 2 MiB shown and the cut at 4 MiB (`RECORDS_KEPT_BYTES`), the owner-only permissions, the rendering, links, paths and colours (T10, T17, T18, and T34's layout).

### The behaviour — the draft per session (D40)

The user's reason for P10, verbatim: "p10 must be one per session, why, because it is used to catalog changes and notes that goes to the prompt with \s". Input is where the user gathers the changes and notes meant for one session's prompt.

- **One draft file per Claude session**, under the same `stdpath('state')/aineo/drafts/` folder as today, named so that no session id can make an invalid or colliding name, nor collide with a directory's draft file (today's are `<sha256(working directory)>.txt`); say the scheme in the help. Owner-only, written as today.
- **The draft home follows a session.** A new entry point (its name is yours; give it the report home's shape) tells the home which session's draft Input holds. Following another session, in this order:
  1. a change of Input not yet saved is saved, at once, as the draft of what the home kept until now — the old session, or the directory before any follow;
  2. the home keeps for the new session from then on;
  3. Input's text is replaced by the new session's draft, or emptied when it has none — **whatever Input holds**, unlike D17's restore at opening, which never overwrites text: the old text is not lost, it is the old session's draft, and comes back when that session is followed again (D40).
  The replacement is not a change of the user's, as D17's restore is not: `u` does not take it out, and it is not saved as either session's draft but the new one's own.
- **Following the session already followed changes nothing**: Input's text, its cursor and its undo stay.
- **Before the home is told any session**, it keeps and restores the working directory's draft exactly as today (D17, C11). Nothing in this packet calls the new entry point: T39 wires it, at every start and every switch. So `dev` behaves as before when this packet merges, and `tests/test_entry_draft.lua` stays true unchanged.
- **Told before its environment, or before Input is kept (the orchestrator's ruling on T36-1, to report to the user).** The home accepts a session before `set_draft_environment()` and before `keep_draft()`, and holds it: `keep_draft()` then restores **that session's** draft, and the move below runs when the environment arrives. At the first `:Aineo open`, T39 will tell the home the session in `started_claude_terminal()` (`plugin/aineo.lua:290`), before `keep_input_draft()` (291), which gives the environment the first time and hands the home Input (`plugin/aineo.lua:180–187`); today the home indexes its environment in `draft_file()`'s callers (`lua/aineo/draft/init.lua:160`, `278`), so a follow there would fail. T39 does not reorder that start.
- **The directory's draft, the first time (A6 — the orchestrator's assumption, to report to the user).** The first time the home follows a session in an editor — at the first start, which comes before `keep_draft()` and before the environment (above) — when the working directory's draft file exists and that session has none, the directory's draft **becomes** the session's (moved, not copied), as D39's history (i) does for the reports. Without it, the first start after this change would empty an Input that held a draft. When both exist, neither is touched, and the session's is shown. **Its cost:** a directory draft written after the first move — by an older aineo running in another editor, say — is never shown again. A move that fails is told once as a warning, as the home tells a write failure today.
- **Two Neovims following one session** share its draft, the last change winning, as D17 says of two in one directory (A7, the orchestrator's assumption, to report to the user).
- **Textlock.** Replacing Input's text at a follow is a buffer change made from T35's scheduled callback, through T39; [[Learnings/A scheduled callback can run under textlock, where Neovim refuses a buffer change with E565]] names "a draft restored into Input" among the places it applies. A replacement Neovim refuses (`E565` alone) is made again at the editor's next `SafeState`, and again at the one after while it is still refused, as the changes home's `show_page()` does (`lua/aineo/changes/init.lua:84–115`). The old session's text is saved as its draft before the replacement is tried (step 1 above), so a replacement made at `SafeState` loses nothing.
- **What stays:** the save a second after each change, the save at once when Input empties, the saves at quit and at unload, the warnings once per editor, nothing raised (D17, C11).

### Facts, checked against `origin/dev` `f98bd9d` (wave 8 merged)

- `lua/aineo/report/records.lua`:
  - `M.records_file(state_directory, working_directory)`, lines 30–37: `<state>/aineo/reports/<sha256(working_directory)>.jsonl`;
  - `RECORDS_KEPT_BYTES`, line 21, 2 MiB; `OWNER_ONLY`, line 15;
  - `M.append_record()`, line 170; `M.read_records()`, line 215.
- `lua/aineo/report/init.lua`:
  - `aineo.report.Environment`, lines 15–18: `clock`, `state_directory`, `working_directory`;
  - `M.set_report_environment()`, lines 51–57;
  - `report_view`, line 25: `{ buffer, records_file }`, chosen once in `M.report_buffer()`, lines 244–254;
  - `show_records()`, lines 209–217, and `open_report_buffer()`, lines 226–232, which shows the records again when the user `:edit`s the Report;
  - `show_and_keep()`, lines 267–280, appends to `report_view.records_file`; `M.receive_report()`, lines 292–298.
  - Wave 8's T34 changed `lua/aineo/report/buffer.lua` and `render.lua` only; `init.lua` and `records.lua` did not move.
- `lua/aineo/draft/init.lua` (424 lines, one file; it requires no aineo home):
  - `aineo.draft.Environment`, lines 26–29: `state_directory`, `working_directory`, `files?`; `environment`, line 63, set by `M.set_draft_environment()`, lines 348–350;
  - `kept`, line 71, the buffers kept, each with its `pending` watch;
  - `draft_file(state_directory, working_directory)`, lines 78–85: `<state>/aineo/drafts/<sha256(working_directory)>.txt`;
  - `read_draft()`, lines 159–174; `restore_draft()`, lines 181–198, which puts the draft in with `'undolevels'` at -1, so `u` does not take it out;
  - `write_draft()`, lines 277–285; `save()`, lines 291–296; `save_pending_change()`, lines 303–308; `take_in_change()`, lines 328–338 (an emptied Input empties the draft at once, other text saved `SAVE_DELAY_MS`, 1000 ms, later, line 11);
  - `M.keep_draft(buffer)`, lines 381–422: restores the draft into an empty buffer only, then follows its changes (`nvim_buf_attach`), and saves at `BufUnload` and `QuitPre`.
- `plugin/aineo.lua` › `give_report_environment()`, lines 159–171, and `keep_input_draft()`, lines 180–187: both homes are given the state directory and the working directory of `kept_places()` (lines 148–152), the first one, for the editor's life. This packet changes neither.
- Tests that pin the records' place: `tests/test_entry_report.lua` line 109 (the file named by the directory's SHA-256, under `nvim/aineo/reports/`), and `tests/test_report_buffer.lua`'s group `the records`, from line 942 (`records_file_holding()` at line 968, the cut, the permissions, a folder that cannot be written; T34 moved them from 605 and 631). The draft's: `tests/test_draft.lua` and `tests/test_entry_draft.lua`. They stay true before the homes follow a session.
- `doc/aineo.txt`, unchanged by wave 8 at these lines: *aineo-report*'s last paragraph, `Reports are kept per working directory, under \`stdpath('state')\` in` … `the working directory of its own moment.` (lines 841–846); *aineo-draft*'s body, `What you write in Input is kept as a draft, one per working directory,` … `you type there.` (lines 329–362), under `Input's draft ~` (line 327) and its tag (line 328).
- **B2** (`evidence/w9-probes.txt`): Claude Code 2.1.281's MCP messages carry no session id. **M5** (`evidence/w9-real-claude-sessions.txt`): one MCP server for Claude Code's life, its session id stale after a switch.

### Baseline

At `f98bd9d`, Neovim 0.12.5: 1929 cases in 60 groups, `Fails (0)` — T33's last whole-suite run, on code identical to `f98bd9d`'s (`plan.md` › *Baseline*). Since the first brief (`9b8707f`), T34 brought `tests/test_report_buffer.lua` from 67 cases to 101 — 97 at its packet's push, and 4 more in its fix round (T34's session note; 101 by mini.test's collection at `f98bd9d`, brief review, T36-4) and reworked `tests/test_report_links.lua` and `tests/test_report_paths.lua`; `tests/test_report.lua` (55), `tests/test_entry_report.lua` (4) and the draft suites are files wave 8 did not change. The dispatch message pastes the counts on the `dev` you start from.

Read first: the v1 plan note's C6, C11, C14, D8, D17, D39 and D40; [[Planning/aineo — worktrees and session switches]] › P9, P10 and its outcome; `knowledge-vault/Projects/aineo.md`; `Sessions/2026-09-24 — T5 report channel.md`; `Sessions/2026-09-26 — T14 Input draft.md` (the draft home's packet); `Sessions/2026-10-07 — T34 Report layout.md`; [[Learnings/A scheduled callback can run under textlock, where Neovim refuses a buffer change with E565]]; `plan.md` (*Assumptions to report to the user*, A4, A6 and A7) and `evidence/w9-probes.txt` and `evidence/w9-real-claude-sessions.txt` in this folder.

## Boundary

- **Branch:** `feature/t36-report-sessions` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t36_report_sessions` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/report/records.lua` and `lua/aineo/report/init.lua`; `lua/aineo/draft/init.lua`, and one new file in `lua/aineo/draft/` if a concern needs one; `tests/test_report.lua`, `tests/test_report_buffer.lua` where a records case must change, `tests/test_entry_report.lua` only if its pin must change (it should not), a new `tests/test_report_sessions.lua`; `tests/test_draft.lua` where a case must change, a new `tests/test_draft_sessions.lua`; `doc/aineo.txt` inside the two fences below; your session note.
- **You must not touch:** `plugin/aineo.lua` (T35's and T39's); every other file under `lua/`, `plugin/`, `scripts/` and `tests/` — `tests/test_entry_draft.lua` and `tests/test_doc.lua` included (run them); T35's files (`lua/aineo/claude/`, `tests/helpers/fake_claude.lua`, `tests/test_claude*.lua`) and T37's (`lua/aineo/changes/`, `tests/test_changes*.lua`); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`. Yours: *aineo-report*'s last paragraph, from `Reports are kept per working directory, under \`stdpath('state')\` in` to `the working directory of its own moment.` — say what is kept per session, the history's move, and that until the session is followed the working directory's records are shown. And *aineo-draft*'s body, from `What you write in Input is kept as a draft, one per working directory,` to `you type there.` — say that the draft is kept per Claude session, what a follow does to Input, the directory's draft's move, and that until a session is followed it is the working directory's; leave `Input's draft ~` and its tag line as they are, since T35's fence ends three lines above them, at `same session.`. T35 owns *aineo-claude-session* and a new LIMITS subsection after `Stopping Claude Code on quit ~`; T37 owns *aineo-changes*'s first paragraph and one LIMITS item. Before you push, merge with each of their branches that exists (`git merge-tree --write-tree <your head> origin/feature/t35-session-switch`, the same for `origin/feature/t37-changes-sessions`), run `make test_file FILE=tests/test_doc.lua` on each merged tree, and report both.
- **Session note:** `knowledge-vault/Sessions/<date> — T36 Report per session.md`, with a `## Task lines` section. `<date>` is the dispatch message's date, written `YYYY-MM-DD`, which that message gives; the orchestrator checks the name is free before dispatch (W-4).
- **Scratch prefix:** `t36-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5 only; the test files you touch and the baseline table's while you work; the whole suite once before each push; mutants on their covering files. Never the real `claude`.
- **Modularity:** `aineo.report` keeps requiring at most `aineo.config`, and `aineo.draft` no aineo home (`.claude/skills/modularity/SKILL.md`, the direction table). Each learns of a session by being told, never by requiring `aineo.claude`; neither requires the other.

## The tests

Each behaviour gets one test, seen failing first:
- following a session shows that session's records and keeps the next report there;
- following another session replaces the Report's lines with that session's, and a report then lands in the new session's file only;
- following the session already followed leaves the Report's lines and cursor as they were;
- a session with no records shows an empty Report;
- the first follow moves the directory's records to the session; when both files exist, neither is touched;
- a later follow of another session moves nothing, **with a directory records file planted again before that later follow**: without the planted file the directory's file is already gone, and the test passes for the mutant that moves at every follow (T36-3);
- a move that fails warns once, and the session's file is used;
- a session told before `set_report_environment()` is held: once the environment is given, the Report shows that session's records, the first move runs, and the next report lands in the session's file (T36-1);
- a follow refused under textlock is made at a later `SafeState`: one test holds textlock (an `<expr>` mapping waiting in `getcharstr()`, one of the Learning's holds) while the follow lands, and the Report shows the new session's records once the hold ends, with no retry left (T36-2);
- before any follow, the records are the directory's, as `tests/test_entry_report.lua` pins;
- a Report wiped and made again (`report_buffer()`) shows the followed session's records, not the directory's;
- the draft: following a session puts its draft into Input, replacing Input's text, and keeps the next change under that session; following the first session again brings its text back;
- a change not yet saved when a follow comes is saved as the old session's draft, not lost and not the new one's;
- the replacement is no change of the user's: `u` does not take it out, and it is saved under no session but the new one;
- following the session already followed leaves Input's text, cursor and undo as they were;
- a session with no draft empties Input;
- the first follow moves the directory's draft to the session; when both exist, neither is touched; a move that fails warns once;
- a later follow moves nothing, with a directory draft file planted again before it (T36-3);
- a session told before `set_draft_environment()` and before `keep_draft()` is held: `keep_draft()` restores that session's draft, and the first move runs once the environment is given (T36-1);
- before any follow, the draft is the directory's, as `tests/test_draft.lua` and `tests/test_entry_draft.lua` pin.

The help is not in that list: `tests/test_doc.lua` pins the tags, the 78-column width and the help file's shape (`tests/test_doc.lua:59–208`), and no text, so no paragraph can be seen failing there, and you may not edit that file. **`tests/test_doc.lua` stays green on the merged trees** (W-2).

The verification runs the plan's eleven mutants for T36. Name in your report the test that kills each.

## What was decided already

- The user's request, 2026-10-06, and the user's answers to P9 and P10, D39 and D40, which the amendment gives.
- C6's report format and the 2 MiB bound stand; D17's saving and restoring stand, per session.
- The orchestrator's assumptions A4, A6 and A7, and its ruling that both homes hold a session told before their environment (T36-1), to be reported to the user; build them as written.

## Budget

Medium to large: a records file and a draft file chosen by session, one entry point in each home, a one-time move in each, a session held until the environment comes, about twenty cases and two help paragraphs. If it grows past that, stop at a green, reviewed, pushed state and report.

## Report

In your definition's shape, to `<scratchpad>/t36-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the test files that ran and the whole suite's counts.

## Amendment — 2026-10-07: the user's answers, the measurements, and the facts at `f98bd9d`

**The user's answers.** The orchestrator put P1–P11 to the user as a table, each with its options and its recommendation first, and M, R and S for the wave. The user answered, verbatim: "p10 must be one per session, why, because it is used to catalog changes and notes that goes to the prompt with \s, other than that all your recommendations are fine, so when wave 8 finishes start right streight wave 9."
- P9 is (a) with history (i): D39. The Report's half of this brief, written with it, stands.
- **P10 is per session**, over the recommendation: D40. The proposal note letters it (a); the table put to the user, recommendation first, lettered it (b). This brief first left the draft out under the recommendation; it now holds it: *The behaviour — the draft per session*, the draft home in *Boundary*, its fence in `doc/aineo.txt`, its tests, and the plan's mutants 6–8. T39 wires it.

**The measurements** (`evidence/w9-real-claude-sessions.txt`, the orchestrator's, 2026-10-07). M5: one MCP server for Claude Code's life, its `CLAUDE_CODE_SESSION_ID` stale after a switch. D39's rule — a report kept under the session followed when it arrives — stands, and this packet reads no session from the MCP server (the orchestrator's assumption A4, reported to the user).

**Readings the round did not ask** (the planning's, for the brief review and the user): A6, the directory's draft moved to the first session followed, as D39's history (i) moves the records; and two Neovims on one session sharing its draft, last change winning, as D17 says of one directory.

**Facts that moved since `9b8707f`** (the body gives them at `f98bd9d`): `M.report_buffer()` ends at line 254 and `show_records()` at 217 (both read one line long before; the code did not move); `tests/test_report_buffer.lua`'s group `the records` is at line 942 and `records_file_holding()` at 968 (T34 added cases above them; they were 605 and 631); the draft home's lines are new to this brief. `records.lua`, `init.lua`, `plugin/aineo.lua`'s two hand-overs and the help's two fences did not move. The baseline is 1929 cases at `f98bd9d`.

## Correction — 2026-10-07, from the brief review

The brief review (`brief-review.md` in this folder, on `ed83367`) found that this brief would mislead in six places, T36-1 to T36-6, and in two that every brief shares, W-2 and W-4. No packet had been dispatched, so each correction is made in the body above, as the review words it, and listed here. Where the review left a choice, the orchestrator ruled under the user's instruction of 2026-10-06 ("assume your recommendations and report what they were after you finish"); each ruling is **the orchestrator's assumption, to report to the user**, never the user's answer nor a D row.

- **T36-1 — the orchestrator's ruling, to report to the user.** The report home and the draft home accept the session they follow before their environment is given, and hold it until then; `keep_draft()` restores the held session's draft. T39 need not reorder the first start, and says the order (T39-3): *Told before its environment* in both halves; two tests.
- **T36-2:** textlock: the Learning is cited in both halves and in *Read first*; a refused swap is made again at `SafeState`, as the changes home's `show_page()` does; a test of one hold.
- **T36-3:** the "later follow moves nothing" tests plant a directory file again first, for the records and for the draft; mutant 2 reworded in `plan.md`, and mutant 9 added for the draft.
- **T36-4:** `tests/test_report_buffer.lua` has 101 cases at `f98bd9d`, not 97: *Baseline*.
- **T36-5 — A7, the orchestrator's assumption, to report to the user.** Two Neovims on one session share its draft and its Report: both halves of *The behaviour*.
- **T36-6:** A6 names its cost — a directory draft written after the first move is never shown again — and the order at the first start; the same cost is named for the records under *History, (i)*.
- **W-2:** the help is out of the red-first list; `tests/test_doc.lua` stays green on the merged trees.
- **W-4:** the session note's `<date>` is the dispatch message's: *Boundary*.

**Mutants** (`plan.md` › *Verification mutants*, T36): 2 reworded; 9 (the draft's analogue of 2), 10 (following the session already followed shows its records again, which the first plan put under T39 as its mutant 4; the code is this packet's) and 11 (a session told before the environment dropped) added.
