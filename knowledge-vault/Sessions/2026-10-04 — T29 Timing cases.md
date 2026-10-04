# 2026-10-04 — T29 Timing cases

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t29-timing-cases` · **Pull request:** into `dev` (a regular packet, test-only)

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › *Implementation plan*, T29
- Wave plan: `Implementation/Waves/00006-fixes/plan.md`; brief: `brief-t29-timing-cases.md`; brief review: `brief-review-t27-t29.md` › *T29*
- Rests on: [[Sessions/2026-09-26 — T17 Report paths]] (RP4, M10), [[Sessions/2026-09-26 — T10 Report links]] (X11, N21), [[Sessions/2026-09-27 — T22 parallel runner]] (the flakes), MR133 and MR159 in [[Review/2026-09-24 — v1 MVP readings review]], [[Learnings/vim.wait does not time out under an event flood]]

## Context

**Goal:** T29. The Report's two timing cases fail only when the Report's own work exceeds their bound, not when the host is busy. These are `tests/test_report_paths.lua`'s *of a line of distinct paths take at most the time limit, on arrival and on :edit* and `tests/test_report_links.lua`'s *a long line › shows in the Report, and again on :edit, within the time limit*. Test-only; the 2 s bound does not change.

**Why:** both cases timed the step with `vim.uv.hrtime()`. A busy host failed them while the drawing was unchanged:
- 1 of 1434 cases in the 0.11.6 verification of PR #85;
- every run made beside five or six whole suites;
- the links 1 000 000 `)` row, 2 of 10 at loads 128–253.

## What was done

- **`tests/helpers/work_time.lua`** (new) exports `within_limit(step, limit)` and its own `PATH`; the child `dofile()`s it.
  - **Work time** is the step's processor time (`vim.uv.getrusage()`, user plus system), scaled by `REFERENCE_SECONDS / max(reference before, reference after)`.
  - **The reference** is a fixed plain-Lua workload: 200 000 short strings formatted, joined and scanned. It is timed in the same process just before and just after the step. Garbage is collected before each of the three timings.
  - **`REFERENCE_SECONDS` = 0.044 s** is that workload on this host's performance cores at rest: the middle of 0.035–0.053 s, measured on both versions.
- **Both cases** now ask `within_limit()` instead of reading `hrtime`, against the same `TIME_LIMIT_SECONDS = 2`. The verdict strings are unchanged: "within the limit", or the time, such as "11.1 s".

## How the form was chosen (by measurement)

The host is an Apple M1 Max, 8 performance and 2 efficiency cores. Every probe ran one Neovim at a time: `make test_file` on a copy under `.tests/`, quiet and under `taskpolicy -b`, on 0.12.5 and 0.11.6. No busy loops and no parallel suites were started; two other packets shared the host. Each probe started a fresh child per row. Processor seconds below are `getrusage`, wall seconds `hrtime`.

| measure (paths step, 209 674 distinct paths) | quiet | `taskpolicy -b` |
|---|---|---|
| wall, arrival / `:edit` | 0.86–1.0 s | 6.4–13.5 s (the red: 16.7 s, 18.6 s) |
| processor time | 0.86–1.06 s | 2.37–2.81 s; **8.3–8.9 s** once, while other processes pushed the load to 68 |
| over the plain-Lua reference, collected first | 19–23 references | 14.3–18.3 references |
| work time (× 0.044 s) | 0.84–1.01 s | 0.63–0.81 s |

- **CPU time against 2 s: rejected.** It fails under `-b` (2.4–2.8 s), and a load spike reached 8.9 s.
- **Linearity (the step at N over the step at N/10): rejected.** The ratios held (paths 9.8–10.8, links 7.6–8), but the form turns a time bound into a growth check. T10's fix round ruled that out ("one size bounds a time, it never shows how time grows"). It also misses a uniformly slower drawing.
- **Neovim-API and `fs_stat` reference workloads: rejected.** Under load they drifted (paths over API, 15 → 28; over `fs_stat`, 4 → 8), where the plain-Lua one held (5.5–9.0 throughout, before the garbage collection was added).
- **Without collecting first,** the reference after the step took about twice as long as the one before (0.12 against 0.065 s), from the step's garbage. Collecting before each timing made the two agree.

**What RP4 now means.** "Within 2 s on this host" now reads "within 2 s of work, in seconds of this host's performance cores at rest". A quiet run of the paths case measures about the same as before (MR159's about 1–1.2 s). A step's waiting no longer counts. This is a reading for the user (see *Open threads*).

## Unit list (stated before the first edit)

1. The paths timing case measures the step's work: it passes under `taskpolicy -b` on both versions, and fails under M10.
2. The links timing case measures the same way: it passes under `taskpolicy -b` on both versions, and fails under X11.
3. Each case runs against the waiting mutant W3; its result is reported.

The helper arrived with unit 1. The calibration constant and the way work is measured are one piece of knowledge, and both files would otherwise hold a copy.

## Red and green

**Seen red, by assertion, on `origin/dev` `985f1ee` under `taskpolicy -b`** (the copies under `.tests/` narrowed to the timing groups; logs `t29-red-*.log`):

| case | 0.12.5 | 0.11.6 |
|---|---|---|
| paths | arrival `16.7 s` (load 12.8) | arrival `18.6 s` (load 15.3) |
| links › `("https://a", ")", 1000000)` | arrival `4.1 s` (load 14.3) | arrival `2.2 s` (load 19.7) |
| links › `("", "https://a\128", 8000)` | arrival `2.4 s` | arrival `4.3 s` |

The `\128` row's step costs 0.035–0.038 s of processor time quiet and about 0.1 s under `-b`. Its wall time under `-b` is waiting: background QoS also throttles the disk, and arrival writes the record (`records.append_record`).

**Baseline before the first edit** (`985f1ee`, whole files, quiet, loads 8.6–14): paths 90 cases and links 83, `Fails (0)`, on both versions.

**Green, on the committed tree `418c271`** (`t29-final-*.log`, loads 9.5–21):
- whole files, quiet: paths 90 cases and links 83, `Fails (0)`, on both versions;
- the narrowed timing groups (paths 1 case, links 4): `Fails (0)` quiet and under `taskpolicy -b`, on both versions.

**Arrived green:** none. Both cases were red under `-b` before the change, and each change was seen red under its mutant.

## Mutants

Each literal edit was applied from a pristine copy, run and restored in one call (`.tests/t29-mutant.py`), against the copy narrowed to the case's group. The counts are on the committed tree `418c271`, after the last edit to the files.

| id | literal edit | 0.12.5 | 0.11.6 |
|---|---|---|---|
| M10 (T17) | `lua/aineo/report/paths.lua:85` `    local first, run_last = text:find(RUN, position)` → `    local rest = text:sub(position)` ⏎ `    local first, run_last = rest:find(RUN)` ⏎ `    if first then` ⏎ `      first, run_last = first + position - 1, run_last + position - 1` ⏎ `    end` | killed by assertion: arrival `"11.1 s"` | killed by assertion: arrival `"12.3 s"` |
| X11 (T10) | `lua/aineo/report/links.lua`, after the bracket branch's `last = last - 1` (`:71`): `      candidate = candidate:sub(1, last)` | killed by assertion, the 1 000 000 `)` row: arrival `"54.8 s"` | killed by assertion: arrival `"58.3 s"` |
| N21 (T10) | `links.lua:65` `  while last > 0 do` → `  while last > 0 and #candidate:sub(1, last):gsub('%)', '') >= 0 do`, against the `)` × 20 000 row alone | 5 of 5 by assertion, `2.1–2.5 s` | 5 of 5, `2.1–2.4 s` (`edit` twice) |
| W3 (waiting) | `lua/aineo/report/render.lua`, first line of `M.render_records`: `  vim.uv.sleep(3000)` | **survived** both cases; on the whole suite, killed by assertion in 2 of 1434 cases, neither a timing case (below) | **survived** both cases |

- **N21 sits at the bound.** It costs 2.0–2.6 s of work, against 2.4–2.7 s of wall time under the old form, which killed it 8 of 8 (`t29-oldn21-*.log`). The new form loses the time the old one counted for the garbage left before the step and for waiting.
  - Before the last docstring edit and the helper's `work_seconds` becoming private (code otherwise identical), it missed once in 20 runs (0.11.6). In 10 more on the committed tree it missed none.
  - The constant was not moved to kill N21: that would fit the bound to the mutant. N21 is not one of the mutants the brief requires.
  - N21 was run only on the 20 000 row. On the 1 000 000 row its rescan runs for hours; the first attempt was stopped by its pids, and `links.lua` came back pristine.
- **W3 is missed by design.** Waiting is not work. The old form killed it, at arrival `6.9 s` on both versions (`t29-oldw3-*.log`): the sleep runs twice on arrival.
  - No wall-clock bound could keep that kill and pass `-b`: the honest paths step under `-b` takes 16.7–18.6 s of wall time, more than W3 takes quiet.
  - Whole suite under W3 (0.12.5 only, `t29-final-w3-whole-12.log`, 871 s, load 6.8 → 8.7): `Fails (2)`, both by assertion, both in the relay's delivery cases. The editor did not confirm the report within the relay's 5 s, because arrival slept twice:
    - `tests/test_mcp_blocked_editor.lua` › *a report that opens a Report with a warning › is confirmed before the warning can hold the editor* (`Cause: different types`);
    - `tests/test_mcp_delivery.lua` › *a report › reaches the editor the relay was given, and renders in its Report* (`Cause: different values … "aineo sent the report, but the editor did not confirm it within 5 s …"`).

    A drawing that waits 5 s or more on arrival is therefore still caught by the relay's confirmation bound; one that waits less, or only on `:edit`, is caught by no case.
- **Every mutant reached the code.** The elapsed time of each run moved with it (M10 28–29 s, X11 115–118 s, W3 12 s and 37–38 s, against 1–2 s unmutated). `git status` showed `lua/` clean after each.

## Verification

- **Whole suite skipped (D28).** The user's decision of 2026-10-04 is "yes, skip the full suite for test-only packets", relayed by the orchestrator mid-packet. A test-only packet is one the orchestrator dispatched whose branch changes nothing outside `tests/` except its own session note and task lines. T29 is one: it changes `tests/test_report_paths.lua` and `tests/test_report_links.lua`, adds `tests/helpers/work_time.lua`, and adds this note.
  - Before the push, every changed or added test file and every test file that requires the added helper ran on both versions. These are the same two files (`grep -rl work_time tests scripts lua plugin`). The narrowed copies also ran under `taskpolicy -b`.
  - The orchestrator's combined verification runs the whole suite once per version.
- **W3 on the whole suite,** as a survivor of the two files: killed in 2 cases, by the relay's 5 s confirmation (see *Mutants*). It ran on 0.12.5 only, one 871 s run, to spare the host.
- **Lint:** `make lint` clean (StyLua, selene). The deep-require check prints nothing for the three files.

## Decisions & reasoning

- **The form: CPU time scaled by a plain-Lua reference, the 2 s bound kept.** It is the brief's second candidate, chosen on the table above. It keeps T10's reading that the case bounds a time, and keeps RP4's 2 s as seconds of this host's performance cores.
- **The slower of the two references scales the step,** so that a step on a slower core than one of the two references is not counted as more work.
- **Garbage collected before each timing,** so the step and the reference start from the same heap.

## Task lines

The wave holds its marks; the knowledge pass applies this one:

- [X] T29 — both timing cases measure work with `tests/helpers/work_time.lua` (processor time scaled by a plain-Lua reference workload, the 2 s bound kept): green under `taskpolicy -b` on 0.12.5 and 0.11.6, red under M10 and X11 by assertion; a waiting drawing (W3) is no longer caught, by design; N21 now sits at the bound (killed 10 of 10 on the final tree, 19 of 20 before).

## Limits

- `REFERENCE_SECONDS` was measured on this host. On another host the cases scale with its speed through the reference, but no other host was measured.
- The original flake's condition, five or six whole suites side by side at loads 128–253, was not reproduced: the brief forbids host-wide load. `taskpolicy -b` stood in for it, together with a spike to load 68 from other processes that the 0.11.6 probe ran through.
- In that spike the reference slowed about ten times and the step three, and the paths step read 5.7 references. Under such a spike a slowed drawing reads lighter than it is; M10 and X11 still sit at 11–58 s of work.

## Open threads

- **For the user, through the orchestrator:**
  - RP4's "within 2 s on this host" now reads "within 2 s of work on this host's performance cores". A drawing that waits is caught only when it holds arrival past the relay's 5 s confirmation;
  - N21's margin is now 2.0–2.6 s against the 2 s bound.

## Commits

*Recorded after the merge.*
