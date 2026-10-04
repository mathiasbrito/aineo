**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the plan's *Implementation plan*:

> T29 — The Report's two timing cases fail only when the Report's own work exceeds their bound, not when the host is busy (C6, C14, T10, T17): `tests/test_report_paths.lua`'s *of a line of distinct paths take at most the time limit* and `tests/test_report_links.lua`'s *a long line shows … within the time limit* measure the work the drawing does, so other processes on the host cannot fail them, while a drawing that really exceeds the bound still fails them; test-only.

It rests on T17's RP4, "drawn on arrival and after `:edit` within 2 s on this host, on both versions" (`Implementation/Waves/00006-fixes/brief-t17-report-paths.md`), and on T10's equivalent bound for links. The bound does not change; only what the cases measure does.

### Facts, checked against `origin/dev` `40324f7`

- **Both cases measure wall-clock time.** In the child, each takes `vim.uv.hrtime()` before and after a step, for a report's arrival and for `:edit` in the Report, against `TIME_LIMIT_SECONDS = 2`:
  - `tests/test_report_paths.lua:384–431`, `TIMED_DISTINCT_PATHS`: 209 674 distinct four-byte paths;
  - `tests/test_report_links.lua:339–387`, `TIMED_ARRIVAL_AND_EDIT`, four parametrized rows (`:368–375`). Only the 1 000 000 `)` row is on record as flaking.
- **The work takes about 1–1.2 s on this host** for the paths case: MR159, measured in T17's packet, fix round and re-measure. So the margin to 2 s is small, and wall time grows with the host's load.
- **How often they fail:**
  - The paths case failed on 0.11.6 at loads 131, 115 and 29, and passed at 95 and 38–48 (wave 6's retrospective › *Open threads*).
  - Under T22's runner it failed once in 1434 in the orchestrator's 0.11.6 verification of PR #85.
  - It fails in every run made with five or six whole suites side by side (T22's re-measure).
  - The links case failed 2 of 10 at loads 128–253, with `arrival = "5.2 s"` (T22's session note, the flakes table).
- **Only these two cases in the suite assert a wall-clock bound on aineo's own drawing.** Other `hrtime` users (`tests/test_health.lua`, `tests/test_git_process.lua`, `tests/test_entry_claude_exit.lua`) bound processes' waits. They are not in this packet; leave them.

### Baseline

`dev` `40324f7` is code-identical to `176fd21`: the orchestrator's verification ran 1434 cases in 197 s per version (`Implementation/Waves/00006-fixes/evidence/baseline-176fd21.txt`). Your own baseline is both files on `origin/dev`, run before your first edit, on both versions, with the host's load recorded.

Read first: `knowledge-vault/Projects/aineo.md`; T17's brief, RP4; T10's session note, `Sessions/2026-09-26 — T10 Report links.md`; MR133 and MR159 in `Review/2026-09-24 — v1 MVP readings review.md`; T17's session note, `Sessions/2026-09-26 — T17 Report paths.md` (its timings); [[Learnings/vim.wait does not time out under an event flood]], for how this project bounds time.

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
- **What to measure is yours, by measurement.** The brief review measured, on this host (an Apple M1 Max, 8 performance and 2 efficiency cores), on both versions:
  - **Busy processes do not reproduce the red.** Twelve and forty busy loops (load 22–40) left the paths step at 0.90 s arrival and 1.00 s `:edit`: the scheduler kept the child on a fast core. Its record of the red is five or six whole suites side by side, at loads 128–253.
  - **The efficiency cores do reproduce it.** Under `taskpolicy -b make test_file …`, macOS's background QoS, which runs on the efficiency cores, the same step took 5.6–11.2 s of wall time.
  - **CPU time is not core-independent.** On the efficiency cores the step costs 2.3–2.5 s of CPU, against 0.9–1.0 s on the performance cores. So `vim.uv.getrusage()` alone over a 2 s bound still fails there.
  - **CPU time cannot see waiting.** A drawing that sleeps or waits on I/O really exceeds the bound in wall time, and passes a CPU-time bound.

  Candidate forms, none adopted yet:
  - CPU time;
  - the step's time over a reference workload's, timed in the same process under the same conditions;
  - linearity: the step at N and at a fraction of N, timed alternately, against their ratio;
  - a combination, e.g. a scaling check plus a far higher wall-clock bound that catches waiting.

  Choose by measurement. The chosen form must:
  1. pass `taskpolicy -b` on both versions where today's case fails there;
  2. fail under T17's **M10** and T10's **X11**, the mutants these cases exist to kill, applied literally as their notes record them:
     - M10: `Sessions/2026-09-26 — T17 Report paths.md:183`, at `lua/aineo/report/paths.lua:85`;
     - X11: `Sessions/2026-09-26 — T10 Report links.md:267`, after `lua/aineo/report/links.lua:71`;
  3. be run against a waiting mutant, `vim.uv.sleep(3000)` inside the step. Report its result, and whether the form misses it.

  If the form changes what RP4's "within 2 s on this host" means, say so: the orchestrator records it as a reading for the user. A check per occurrence instead of per distinct candidate is **not** a slowing mutant here: the input's paths are all distinct, so it is equivalent on this input. The counting cases kill it.

## The tests

- **The red:** today's case, under `taskpolicy -b`, fails by assertion on both versions. Keep the log.
- **The green:** the new form passes under `taskpolicy -b`, and is red under M10 and X11, on both versions.
- **Kill counts:** each kill by assertion, with its `Cause` line.
- **No host-wide load.** Do not start busy loops or several suites: two other packets share the host. `taskpolicy -b` slows only the process it starts.

## How the suites run in this packet

The user asked, on 2026-10-04: "Please be carefull with the testing strategy, since each run is taking too long, try to optimize." D26 applies unchanged. The saving is in how often the whole suite runs:

- **While you work:** run only `tests/test_report_paths.lua` and `tests/test_report_links.lua` (`make test_file FILE=…`), on both versions. Narrow each to the timing group with a copy where you can.
- **Before you push:** those two files under `taskpolicy -b`, then the whole suite once per version on the tree you push (D26, binding). The orchestrator's verification runs the whole suite once per version, on this wave's last three packets merged together, not once per packet.
- **Mutants:** on these two files first; only a survivor goes on to the whole suite.
- **Stop every process you start, by pid,** when each run ends.
- **For 0.11.6** (the dispatch message names `<0.11.6 bin>`, the host's 0.11.6 build): `env -u VIMRUNTIME PATH=<0.11.6 bin>:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make …`.
- **Pushing:** if `git push` fails with `Permission denied (publickey)`, push for that command only with

  `git -c credential.helper= -c 'credential.helper=!gh auth git-credential' -c 'url.https://github.com/.insteadOf=git@github.com:' push -u origin bugfix/t29-timing-cases`

## Budget

Two cases rewritten, with one helper at most. If it is larger, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `.claude/local/orchestrator/t29-report-packet.md` in your worktree. Open the pull request into `dev` before you report, and put every verification claim a reviewer can re-measure in its body, with the loads.
