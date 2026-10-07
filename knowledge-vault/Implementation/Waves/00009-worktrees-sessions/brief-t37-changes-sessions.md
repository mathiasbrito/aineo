**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> **Agreed and amended, 2026-10-07.** The user answered the converge round on 2026-10-07: P11 is (a), now D41, and P7 is (a), now D37 — the options this brief was written with. Wave 8's T32 merged (PR #127), and every fact below was read again at `dev` `f98bd9d`. **Corrected 2026-10-07 from the brief review** (`brief-review.md` in this folder, T37-1 to T37-3, W-2 and W-4): the corrections are made in the body, and *Correction — 2026-10-07, from the brief review*, at the end, lists each. Still before dispatch: wave 8's finish (the user's go: "when wave 8 finishes start right streight wave 9"). The *Amendment — 2026-10-07* at the end gives the answers.

## Objective

The task, verbatim from the task list:

> | T37 | The changes pane per session (C15; D37, D41): the session's base and the user's save marks are kept per Claude session id and survive exit; the pane can be shown for another session, a session not seen before taking `HEAD` then as its base | T25, wave 8's T32 | planned — wave 9 |

It rests on: D41 (the changes pane per session) and D37 (`/clear` a new, empty session), agreed 2026-10-07; D19 (the changes pane), whose clause "The session starts when aineo first starts Claude Code in this editor and lasts the editor's life: a restart of Claude keeps the same list and commits" D41 supersedes; D22 (the commits window updates on every commit); C15 (the changes home), C13 (the git home); D26 and D29; and P11's alternatives.

### The behaviour (D41, D37)

- **What is kept, per Claude session id:** the repository's top level, the base commit (or that there was none, before a first commit), and the paths the user saved, relative to the top level — under `stdpath('state')/aineo/` in a folder of its own, one file per session, owner-only, named so that no id can make an invalid or colliding name. It is written when the base is taken and whenever a new path is marked; a write that fails is told once as a warning and the pane goes on from memory.
- **The changes home follows a session.** A new entry point (its name is yours) tells the home which session the pane is for: the pane then shows that session's base and marks, read back from what is kept; for a session with nothing kept, the base is `HEAD` at that moment — the repository of the directory `begin_session()` was given — and the marks empty, and both are kept from then on. Following the session already followed changes nothing. The watch and the reads (T25's one-at-a-time rule) go on as before; the lists are read again for the new base.
- **Before the home is told any session**, it behaves exactly as today: the base is `HEAD` at `begin_session()`'s first call, in memory, for the editor's life. Nothing in this packet calls the new entry point: T39 wires it once T35 says which session Claude Code is on. So `dev` behaves as before when this packet merges, and `tests/test_entry_changes.lua`'s group `the session` stays true.
- **A follow before the repository is found.** T39 will call `begin_session()` and then the follow at once, at every start, and `begin_session()`'s look for the repository is asynchronous (`find`, lines 249–269, started at 356). So the follow always arrives before the repository is found. It is held: once the repository is found, the session's kept base is read, or, for a session with nothing kept, the base `HEAD` names then is taken and kept — **never a base of nil kept** for a repository that has a commit. A follow before any `begin_session()` is held the same way until its first call. (Brief review, T37-1.)
- **A kept base for another repository** (the session's top level is not the repository `begin_session()` found) is not used: the session takes `HEAD` then, as an unseen one does, and says nothing. **That replacement base is held in memory, and the marks made under it too: the kept record of the session's base is never written over.** Otherwise a `:cd` to repository B and a restart that resumes B's session in an editor whose changes home still holds repository A would write A's `HEAD` over the session's record of B, and an editor later in B would lose the session's base (brief review, T37-2). *(A5, the orchestrator's assumption, to report to the user: the round did not ask it.)*
- **A kept base git no longer has** (garbage-collected, a different clone) makes the reads fail as T25's failed read does today, under one line in git's words; the base is kept.
- **What stays:** the windows, their lines and buffers, Enter's diffs, the watch, and T32's colours.

### Facts, checked against `origin/dev` `f98bd9d` (wave 8 merged)

Wave 8's T32 changed `lua/aineo/changes/lines.lua` and `pages.lua` and added `colours.lua`; `init.lua` did not move, nor did `lua/aineo/git/`.

- `lua/aineo/changes/init.lua`:
  - `aineo.changes.SessionSettings`, lines 16–19: `directory`, `show_diff`, `git?`;
  - `aineo.changes.Session`, lines 22–36: `repository`, `absence`, `base`, `changes`, `commits`, `saved` ("the files the user saved since the session began, by path relative to the top level"), `early_saves`, `shown`, `watch`;
  - `session`, line 39, one for the editor's life;
  - `mark_saved()`, lines 233–240;
  - `find`, lines 249–269: the first repository found is the session's, its `head` the base (`session.base = repository.head`), and the early saves are marked;
  - `note_save()`, lines 312–320;
  - `M.begin_session()`, lines 328–357: heeds its first call alone ("a restart of Claude Code calls it again");
  - `M.refresh_shown_pane()`, line 541; `M.pane_buffers()`, line 558.
- `plugin/aineo.lua` › `started_claude_terminal()`, lines 227–232, calls `begin_session({ directory = working_directory, show_diff = … })` after each start. This packet does not change it.
- `lua/aineo/git/init.lua`: `find_repository()`, line 40; `changed_files(found, base, done, options)`, line 53; `commits_since()`, line 65. `base` nil means "before the first commit" (`repository.lua` › `comparison_base()`, lines 157–168).
- Tests that pin the session: `tests/test_entry_changes.lua` group `the session` (line 102): it "begins at the first start of Claude Code", "outlives a restart of Claude Code", and "does not begin at a start that fails"; `tests/test_changes.lua` group `the user’s saves` (line 2069). They stay true before the home follows a session.
- `doc/aineo.txt`, unchanged by T32 at these lines: *aineo-changes*'s first paragraph, `The changes pane lists what changed in your repository since aineo first` … `takes both.` (lines 140–146), and LIMITS › `The changes pane ~`'s item `- A restart of Claude Code in another working directory keeps the first` … `repository and its base.` (lines 1007–1008).

### Baseline

At `f98bd9d`, Neovim 0.12.5: 1929 cases in 60 groups, `Fails (0)` — T33's last whole-suite run, on code identical to `f98bd9d`'s (`plan.md` › *Baseline*). Since the first brief (`9b8707f`: `tests/test_changes.lua` 93), T32 brought `tests/test_changes.lua` to 120 cases at its correction (T32's session note); `tests/test_entry_changes.lua` (12), `tests/test_entry_panes.lua` (86) and `tests/test_git_watch.lua` (33) are as T32's session note and the first baseline give them. The dispatch message pastes the counts on the `dev` you start from.

Read first: the v1 plan note's D19, D22, C13, C15, D37 and D41; [[Planning/aineo — worktrees and session switches]] › P7, P11 and its outcome; `knowledge-vault/Projects/aineo.md`; `Sessions/2026-10-05 — T25 Changes pane.md`; `Sessions/2026-10-07 — T32 Changes colours.md`; the Learnings [[Learnings/A scheduled callback can run under textlock, where Neovim refuses a buffer change with E565]] and [[Learnings/Neovim runs scheduled callbacks during a later VimLeavePre and after VimLeave]]; `plan.md` in this folder.

## Boundary

- **Branch:** `feature/t37-changes-sessions` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t37_changes_sessions` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/changes/init.lua` and one new file in `lua/aineo/changes/` for what is kept; `tests/test_changes.lua` where a case must change, a new `tests/test_changes_sessions.lua`; `doc/aineo.txt` inside the fences below; your session note.
- **You must not touch:** `plugin/aineo.lua` (T35's and T39's); `lua/aineo/git/` (T38's, in stage 2) — if the home needs something of git it does not offer, that is a spec conflict for your report; every other file under `lua/`, `plugin/`, `scripts/` and `tests/` — `tests/test_entry_changes.lua` and `tests/test_doc.lua` included (run them); T35's files (`lua/aineo/claude/`, `tests/helpers/fake_claude.lua`, `tests/test_claude*.lua`) and T36's (`lua/aineo/report/`, `tests/test_report*.lua`); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`. Yours: *aineo-changes*'s first paragraph, from `The changes pane lists what changed in your repository since aineo first` to `takes both.`; and LIMITS › `The changes pane ~`'s item from `- A restart of Claude Code in another working directory keeps the first` to `repository and its base.` T35 owns *aineo-claude-session* and a new LIMITS subsection after `Stopping Claude Code on quit ~`; T36 owns *aineo-report*'s last paragraph. Before you push, merge with each of their branches that exists (`git merge-tree --write-tree <your head> origin/feature/t35-session-switch`, the same for `origin/feature/t36-report-sessions`), run `make test_file FILE=tests/test_doc.lua` on each merged tree, and report both.
- **Session note:** `knowledge-vault/Sessions/<date> — T37 Changes per session.md`, with a `## Task lines` section. `<date>` is the dispatch message's date, written `YYYY-MM-DD`, which that message gives; the orchestrator checks the name is free before dispatch (W-4).
- **Scratch prefix:** `t37-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5 only; the test files you touch and the baseline table's while you work; the whole suite once before each push; mutants on their covering files. Git in the tests only through the suites' fixture repositories (`tests/helpers/git_repo.lua`), never the checkout's.
- **Modularity:** `aineo.changes` keeps requiring `aineo.git` and its own files alone (`.claude/skills/modularity/SKILL.md`). It learns of a session by being told.

## The tests

Each behaviour gets one test, seen failing first:
- following a session for the first time takes `HEAD` as its base and keeps it; a commit made since is listed;
- a later editor following the same session reads the base and the marks back: the commit and the `*` are listed as before, after a restart of the editor;
- following another session shows its own base and marks, and following the first again brings the first's back;
- a save marks the path under the session followed, and it is kept at once;
- a follow that comes before `begin_session()`'s look has found the repository keeps the base `HEAD` names once it is found, never nil (T37-1);
- a kept base of another repository is not used, and the kept record is left as it was, base and marks (A5, T37-2);
- a write of what is kept that fails warns once and the pane goes on;
- before any follow, the session is the editor's, as today: `tests/test_entry_changes.lua`'s `the session` group passes unchanged.

The help is not in that list: `tests/test_doc.lua` pins the tags, the 78-column width and the help file's shape (`tests/test_doc.lua:59–208`), and no text, so no paragraph can be seen failing there, and you may not edit that file. **`tests/test_doc.lua` stays green on the merged trees** (W-2).

The verification runs the plan's six mutants for T37. Name in your report the test that kills each.

## What was decided already

- The user's request, 2026-10-06, and the user's answers to P7 and P11, D37 and D41, which the amendment gives.
- D19's lists, Enter and refresh stand; D22 stands.
- The orchestrator's assumption A5, as reworded on 2026-10-07, to be reported to the user; build it as written.

## Budget

Medium: a small kept file per session, one entry point that swaps the base and the marks, a follow held until the repository is found, about ten cases and a help paragraph. If it grows past that, stop at a green, reviewed, pushed state and report.

## Report

In your definition's shape, to `<scratchpad>/t37-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the test files that ran and the whole suite's counts.

## Amendment — 2026-10-07: the user's answers and the facts at `f98bd9d`

**The user's answers.** The orchestrator put P1–P11 to the user as a table, each with its options and its recommendation, and M, R and S for the wave. The user answered, verbatim: "p10 must be one per session, why, because it is used to catalog changes and notes that goes to the prompt with \s, other than that all your recommendations are fine, so when wave 8 finishes start right streight wave 9." So P11 is (a), D41, and P7 is (a), D37: the options this brief was written with. Its body stands; its "awaits the converge round" markers are gone. P10, per session, is T36's and T39's, not this packet's.

**The measurements** (`evidence/w9-real-claude-sessions.txt`, the orchestrator's, 2026-10-07) change nothing here: this packet is told a session and never learns one from Claude Code.

**A reading the round did not ask** (the planning's, A5, for the brief review and the user): a kept base of another repository is not used.

**Facts that moved since `9b8707f`:** none in `lua/aineo/changes/init.lua`, `lua/aineo/git/` or `plugin/aineo.lua`; `comparison_base()` ends at line 168 (read two lines long before; the code did not move). T32 added `lua/aineo/changes/colours.lua` and moved `lines.lua` and `pages.lua`, which this packet does not touch. The help's two fences did not move. The baseline is 1929 cases at `f98bd9d`, `tests/test_changes.lua` 120 at T32's correction.

## Correction — 2026-10-07, from the brief review

The brief review (`brief-review.md` in this folder, on `ed83367`) found that this brief would mislead in three places, T37-1 to T37-3, and in two that every brief shares, W-2 and W-4. No packet had been dispatched, so each correction is made in the body above, as the review words it, and listed here. Where the review left a choice, the orchestrator ruled under the user's instruction of 2026-10-06 ("assume your recommendations and report what they were after you finish"); the ruling is **the orchestrator's assumption, to report to the user**, never the user's answer nor a D row.

- **T37-1:** a follow that arrives before `begin_session()`'s look has found the repository is held, and keeps the base `HEAD` names once it is found, never nil: *A follow before the repository is found*; a test. That bullet also holds a follow made before any `begin_session()`, so the order T39 calls them in cannot lose a session (T39-3).
- **T37-2 — A5, reworded, the orchestrator's assumption, to report to the user.** The replacement base is held in memory; the kept record of a session's base is never written over. Marks made under the replacement base are held in memory too, since writing them would write over that record: *A kept base for another repository*; a test; mutant 6.
- **T37-3:** mutant 5's parenthesis names `begin_session()`'s first-call rule, not D19's clause, which D41 supersedes (`plan.md`).
- **W-2:** the help is out of the red-first list; `tests/test_doc.lua` stays green on the merged trees.
- **W-4:** the session note's `<date>` is the dispatch message's: *Boundary*.

**Mutants** (`plan.md` › *Verification mutants*, T37): 5 reworded; 6 (A5's replacement base written over the kept record) added. Mutant 4 is now killed by the T37-1 test.
