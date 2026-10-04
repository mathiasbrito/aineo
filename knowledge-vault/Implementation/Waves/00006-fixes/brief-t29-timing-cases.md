**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the plan's *Implementation plan*:

> T29 — The Report's two timing cases fail only when the Report's own work exceeds their bound, not when the host is busy (C6, C14, T10, T17): `tests/test_report_paths.lua`'s *of a line of distinct paths take at most the time limit* and `tests/test_report_links.lua`'s *a long line shows … within the time limit* measure the work the drawing does, so other processes on the host cannot fail them, while a drawing that really exceeds the bound still fails them; test-only.

It rests on T17's RP4, "drawn on arrival and after `:edit` within 2 s on this host, on both versions" (`Implementation/Waves/00006-fixes/brief-t17-report-paths.md`), and on T10's equivalent bound for links. The bound does not change; only what the cases measure does.

### Facts, checked against `origin/dev` `40324f7`

- **Both cases measure wall-clock time.** In the child, each takes `vim.uv.hrtime()` before and after a step, for a report's arrival and for `:edit` in the Report, against `TIME_LIMIT_SECONDS = 2`:
  - `tests/test_report_paths.lua:385–429`, `TIMED_DISTINCT_PATHS`: 209 674 distinct four-byte paths;
  - `tests/test_report_links.lua:338–380`, `TIMED_ARRIVAL_AND_EDIT`.
- **The work takes about 1–1.2 s on this host** for the paths case: MR159, measured in T17's packet, fix round and re-measure. So the margin to 2 s is small, and wall time grows with the host's load.
- **How often they fail:**
  - The paths case failed on 0.11.6 at loads 131, 115 and 29, and passed at 95 and 38–48 (wave 6's retrospective › *Open threads*).
  - Under T22's runner it failed once in 1434 in the orchestrator's 0.11.6 verification of PR #85.
  - It fails in every run made with five or six whole suites side by side (T22's re-measure).
  - The links case failed 2 of 10 at loads 128–253, with `arrival = "5.2 s"` (T22's session note, the flakes table).
- **Only these two cases in the suite assert a wall-clock bound on aineo's own drawing.** Other `hrtime` users (`tests/test_health.lua`, `tests/test_git_process.lua`, `tests/test_entry_claude_exit.lua`) bound processes' waits. They are not in this packet; leave them.

### Baseline

`dev` `40324f7` is code-identical to `176fd21`: the orchestrator's verification ran 1434 cases in 197 s per version (`plan.md` › *Landed*, T22). Your own baseline is both files on `origin/dev`, run before your first edit, on both versions, with the host's load recorded.

Read first: T17's brief, RP4; MR133 and MR159 in `Review/2026-09-24 — v1 MVP readings review.md`; T17's session note, `Sessions/2026-09-26 — T17 Report paths.md` (its timings); [[Learnings/vim.wait does not time out under an event flood]], for how this project bounds time.

## Boundary

- **Branch:** `bugfix/t29-timing-cases` from `origin/dev`.
- **Class:** regular, test-only. Reviews: guarantee and records.
- **Model:** `opus`.
- **Resources:** `impl_t29_timing_cases`.
- **You may touch:**
  - `tests/test_report_paths.lua`;
  - `tests/test_report_links.lua`;
  - a new helper under `tests/helpers/`, if both files share it;
  - your session note.

  The task list's mark is held: write a `## Task lines` section in your session note.
- **You must not touch:**
  - `lua/` and `plugin/`: a drawing that is too slow is a finding for your report, not a fix;
  - `scripts/`, the `Makefile` and `doc/`;
  - the other two packets' files (`doc/aineo.txt`, `tests/test_report_colours.lua`, `tests/test_doc.lua`, `scripts/minimal_init.lua`, `tests/helpers/child.lua`, `tests/helpers/entry_editor.lua`, `tests/helpers/claude_session.lua`, `tests/test_entry_guard.lua`);
  - the project note;
  - never `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude` or `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/2026-10-04 — T29 Timing cases.md`.
- **Scratch prefix:** `t29-`.

## What was decided already

- **The user, 2026-10-04:** "check 1 to 3 and close 6". Item 3 was put to the user on 2026-10-01 as "T17's timing test … The packet would make it fail only when the checks really exceed their time limit. Only the test changes."
- **The links case is added by the orchestrator.** It has the same mechanism and the same flake (T22's flakes table), and adding it costs the same file pattern.
- **What to measure is yours, by measurement.** The candidate is the child process's own CPU time (`vim.uv.getrusage()`, user plus system) around each step, in place of wall time. Before you adopt it, measure on both versions:
  - **Load-independence:** the step's CPU time is about the same idle and under heavy load. Load all cores with busy processes that you start and stop by pid.
  - **The wall-clock form's failure:** the same load fails today's case. Pin that as the red.
  - **Still a bound:** a mutant that makes the drawing really slower still fails the new case. Two candidates: one file-system check per occurrence rather than per distinct candidate (RP4's own rule), or a busy-wait added inside the step.
  - **Nothing hidden:** CPU time does not miss work the step hands to another process or thread.

  If CPU time does not hold, report what does, measured.

## The tests

- **The red:** the current case, under load you start, fails by assertion on both versions. Keep the log.
- **The green:** the new form passes under the same load, and is red under a slowing mutant, on both versions.
- **Kill counts:** each kill by assertion, with its `Cause` line.

## How the suites run in this packet — the orchestrator's decision of 2026-10-04

The user asked, on 2026-10-04: "Please be carefull with the testing strategy, since each run is taking too long, try to optimize." Under D26, for this packet:

- **While you work:** run only `tests/test_report_paths.lua` and `tests/test_report_links.lua` (`make test_file FILE=…`), on both versions. Narrow each to the timing group with a copy where you can.
- **Before you push: those two files, on both versions, idle and under your load. Not the whole suite.** Each test file runs in its own Neovim and home since T22, and only these two files change, so no other file's outcome can change. The orchestrator's verification runs the whole suite once per version, on this wave's last three packets merged together.
- **Mutants:** on these two files only, never on the whole suite.
- **Stop every process you start, by pid,** your load generators included, when each run ends.
- **For 0.11.6** (the dispatch message names `<0.11.6 bin>`, the host's 0.11.6 build): `env -u VIMRUNTIME PATH=<0.11.6 bin>:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make …`.
- **Pushing:** if `git push` fails with `Permission denied (publickey)`, push for that command only with

  `git -c credential.helper= -c 'credential.helper=!gh auth git-credential' -c 'url.https://github.com/.insteadOf=git@github.com:' push -u origin bugfix/t29-timing-cases`

## Budget

Two cases rewritten, with one helper at most. If it is larger, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `.claude/local/orchestrator/t29-report-packet.md` in your worktree. Open the pull request into `dev` before you report, and put every verification claim a reviewer can re-measure in its body, with the loads.
