# 2026-10-04 — T29 Timing cases

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t29-timing-cases` · **Pull request:** #97 into `dev` (a regular packet, test-only)

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › *Implementation plan*, T29
- Wave plan: `Implementation/Waves/00006-fixes/plan.md`; brief: `brief-t29-timing-cases.md`; brief review: `brief-review-t27-t29.md` › *T29*
- The correction's brief: `.claude/local/orchestrator/orch-correction-97.md`; the re-measure it corrects: `remeasure97/remeasure-t29-report.md`, findings 1–8
- Rests on: [[Sessions/2026-09-26 — T17 Report paths]] (RP4, M10), [[Sessions/2026-09-26 — T10 Report links]] (X11, N21), [[Sessions/2026-09-27 — T22 parallel runner]] (the flakes), MR133 and MR159 in [[Review/2026-09-24 — v1 MVP readings review]], [[Learnings/vim.wait does not time out under an event flood]]

## Context

**Goal:** T29. The Report's two timing cases fail only when the Report's own work exceeds their bound, not when the host is busy. These are `tests/test_report_paths.lua`'s *of a line of distinct paths take at most the time limit, on arrival and on :edit* and `tests/test_report_links.lua`'s *a long line › shows in the Report, and again on :edit, within the time limit*. Test-only; the 2 s bound does not change.

**Why:** both cases timed the step once with `vim.uv.hrtime()`. Failures recorded while the drawing was unchanged:
- 1 of 1434 cases in the 0.11.6 verification of PR #85;
- every run made beside five or six whole suites;
- the links 1 000 000 `)` row, 2 of 10 at loads 128–253.

## What was done (the state after the correction)

- **`tests/helpers/timed_attempts.lua`** (new; the fix round's `fastest_time.lua`, renamed by the correction because it no longer judges the fastest attempt) exports `within_limit(child, timing, limit)`. `timing` is `{ start, steps }`: `start` starts the child ready for the steps, and `steps` times them, returning seconds by step.
  - **Each step is judged by its second-fastest of up to three attempts.** The attempts end once every step's second-fastest time is within the limit, so two attempts at least.
  - **Each attempt's child starts in a home of its own:** the four `XDG_*` variables point into a new `attempt-XXXXXX` directory under the test file's home while it starts, and are restored after; an error from the start is raised as it was.
  - **Before an attempt is timed, its child is started again until its LuaJIT compiles code:** a hot loop must leave `jit.util.traceinfo(1)` non-nil. After five starts with no compiling JIT, the fifth child is timed all the same.
  - The verdict strings: "within the limit", or the second-fastest time, such as "2.4 s".
- **Both cases** return each step's wall-clock seconds (`hrtime`) and are judged through `within_limit()`, against the unchanged `TIME_LIMIT_SECONDS = 2`.
- **`tests/test_timed_attempts.lua`** (new; the fix round's `tests/test_fastest_time.lua`, renamed with it) pins the helper in 11 cases.
- **`tests/helpers/work_time.lua`,** the first round's helper, is removed.

**What RP4 now reads, accepted by the user.** The cases judge the step's second-fastest wall time over three fresh processes, each with its own home and a compiling JIT where five starts give one. That is not T17's "within 2 s on this host" unchanged: a drawing over the bound in one process of three passes. The orchestrator put the reading to the user, who answered on 2026-10-05: **"ok on the reading, skip the five-suite run"**. RP4 now reads: **the step's second-fastest wall time over three fresh processes is within 2 s on this host.**

**Wrong in this note's fix-round version** (the re-measure's finding 1): "RP4 keeps its meaning … There is no reading to put to the user". The fastest of three passed a drawing slow in half of its processes 8 of 8 times (INT), so the fix round's form did change RP4's meaning, to "within 2 s in the fastest of up to three fresh processes".

## The first round (`418c271`) and why it was replaced

The first form scaled the step's processor time (`getrusage`) by a plain-Lua reference workload (0.044 s on this host), timed just before and after it in the same process. The review of PR #97 (guarantee and records, one review; findings 1–11) measured that it did not hold:
- **Finding 1.** On 0.11.6 about one child in twelve has a LuaJIT that compiles no code. There the reference costs about 10 times more and the step about 3 times, so the reading falls 3–10 times. MK5, at 1.85 times the bound, passed once in 40 runs.
- **Finding 2.** A reference timed on slower cores than the step read a correct drawing 3–4 times lighter.
- **Findings 3 and 4.** N21 survived 9 of 16 runs quiet and 10 of 10 under `-b`; MK2 survived 7 of 12. The old wall-clock form kills both every time.
- **Finding 5.** Waiting (W3) and work in another process (PROC) were not counted.

**Corrections to this note's first version** (findings 6–8). Each was wrong as written:
- **"8.3–8.9 s once, while other processes pushed the load to 68"** (the table, *How the form was chosen*, *Limits*). That row, and the calibration row `ref 0.459/0.475 … ratio 5.7` labelled quiet, were children in finding 1's LuaJIT state, not load.
- **"Neovim-API and `fs_stat` reference workloads: rejected … over `fs_stat`, 4 → 8".** The `fs_stat` drift rests on that one row alone. Without it, the `fs_stat` reading held as well as the plain-Lua one (3.7–4.8 quiet, 3.5–4.6 under `-b`). The API reference did drift (quiet 16.2–22.3, `-b` 12.8–15.6).
- **N21 "killed 10 of 10 on the final tree, 19 of 20 before"** (the task line, the mutant table, commit `418c271`'s message). The counts were true of those runs, but the form did not guarantee them: the review's 16 quiet runs killed 7.
- **"What RP4 now means … within 2 s of work, in seconds of this host's performance cores at rest".** The review measured that bound at 1.8–3.4 s on a quiet host, and at about 7–8 s in a child whose LuaJIT compiles nothing (finding 7). The reading is withdrawn, since the form is gone.

`2d5722f`'s message names `418c271`'s two wrong statements.

### The first round's measurements (rows kept, the spike row corrected above)

Host: Apple M1 Max, 8 performance and 2 efficiency cores. One Neovim at a time, on a copy under `.tests/`, quiet and under `taskpolicy -b`, on 0.12.5 and 0.11.6.

| measure (paths step, 209 674 distinct paths) | quiet | `taskpolicy -b` |
|---|---|---|
| wall, arrival / `:edit` | 0.86–1.0 s | 6.4–13.5 s (the red: 16.7 s, 18.6 s) |
| processor time | 0.86–1.06 s | 2.37–2.81 s; 8.3–8.9 s in one 0.11.6 child whose LuaJIT compiled nothing (see above) |
| over the plain-Lua reference, collected first | 19–23 references | 14.3–18.3 references |
| work time (× 0.044 s) | 0.84–1.01 s | 0.63–0.81 s |

Rejected in the first round:
- **CPU time against 2 s:** it fails under `-b`.
- **Linearity:** it turns T10's time bound into a growth check ("one size bounds a time, it never shows how time grows").

### The first round's red, green and mutants (superseded; rows kept)

**Seen red, by assertion, on `origin/dev` `985f1ee` under `taskpolicy -b`** (`t29-red-*.log`):

| case | 0.12.5 | 0.11.6 |
|---|---|---|
| paths | arrival `16.7 s` (load 12.8) | arrival `18.6 s` (load 15.3) |
| links › `("https://a", ")", 1000000)` | arrival `4.1 s` (load 14.3) | arrival `2.2 s` (load 19.7) |
| links › `("", "https://a\128", 8000)` | arrival `2.4 s` | arrival `4.3 s` |

**Baseline** (`985f1ee`, whole files, quiet, loads 8.6–14): paths 90 cases and links 83, `Fails (0)`, on both versions.

**Mutants on `418c271`:**

| id | literal edit | 0.12.5 | 0.11.6 |
|---|---|---|---|
| M10 (T17) | `paths.lua:85` `    local first, run_last = text:find(RUN, position)` → `    local rest = text:sub(position)` ⏎ `    local first, run_last = rest:find(RUN)` ⏎ `    if first then` ⏎ `      first, run_last = first + position - 1, run_last + position - 1` ⏎ `    end` | killed by assertion, `"11.1 s"` | killed, `"12.3 s"` |
| X11 (T10) | `links.lua`, after the bracket branch's `last = last - 1` (`:71`): `      candidate = candidate:sub(1, last)` | killed, `"54.8 s"` | killed, `"58.3 s"` |
| N21 (T10) | `links.lua:65` `  while last > 0 do` → `  while last > 0 and #candidate:sub(1, last):gsub('%)', '') >= 0 do`, the `)` × 20 000 row | 5 of 5 in these runs, at the bound (corrected above) | 5 of 5 in these runs, at the bound (corrected above) |
| W3 (waiting) | `render.lua`, first line of `M.render_records`: `  vim.uv.sleep(3000)` | survived both cases; whole suite: killed in 2 relay cases by their 5 s confirmation | survived both cases |

## The fix round (2026-10-04)

**The orchestrator's decisions** (`orch-fixround-97.md`):
1. The JIT check is required, and pinned.
2. Choose (A), wall-clock best of three in fresh children with a working JIT, or (B), instructions retired, by measurement. (A) is preferred.
3. The criteria:
   - every slowing mutant (M10, X11, N21, MK2, MK5, W3, PROC) killed 10 of 10 on each version;
   - the correct drawing passes 20 of 20 quiet, and 20 of 20 under five whole suites side by side;
   - `taskpolicy -b` is dropped as a requirement, but what the form does under it is reported.

**(A) was taken.** It met the mutant criteria and the quiet criterion except for one Neovim crash. It held under the load I could make, though not as the case runs inside a suite (below). (B) was not built.

**0.11.6 dropped (the user, 2026-10-05):** "we test only against the most actual neovim version, no need to compatibility with the older one anymore. We need to save time." The orchestrator relayed it once every 0.11.6 run below had already ended; nothing ran on 0.11.6 after it. The 0.11.6 numbers below are what was measured before the decision. The JIT guard stays in the helper; it needs no further measurement.

**The orchestrator also cut M10's and X11's runs to three per version.** Both sit five times or more over the bound. That message came after their runs had ended, so ten runs per version are recorded.

### Unit list (fix round)

1. A step within the limit in one of up to three attempts is within the limit.
2. A step over the limit in every attempt shows its fastest time.
3. Each step is judged on its own fastest attempt.
4. The attempts end at the first whose steps are all within the limit.
5. The attempts are three at most.
6. A child whose LuaJIT compiles no code is started again before it is timed.
7. A child that compiles no code in five starts raises an error.
8. Both timing cases time wall-clock seconds and are judged by the helper.

**Seen red:** units 1–7, each by assertion, against a stub `within_limit` that returned `{}` (`t29-fr-red-12.log`, 0.12.5, `Fails (7)`). Unit 7's Cause was `different values at key 1, left = true, right = false`; the others named the missing key. Unit 6 is also red under H1 (the guard removed): `"compiled" = "3.0 s"`.
**Arrived green:** unit 8. It had no red of its own; it uses units 1–7. Its killers are the slowing mutants below, all run.

### Helper mutants (each run once per version, against `tests/test_fastest_time.lua`)

| id | literal edit of `tests/helpers/fastest_time.lua` | both versions |
|---|---|---|
| H1 | `    if child.lua_get(COMPILES_CODE) then` → `    if true then` | killed by assertion (2 cases), `"compiled" … "3.0 s"` |
| H2 | `local ATTEMPTS = 3` → `local ATTEMPTS = 1` | killed (4 cases) |
| H3 | `    if all_within(fastest, limit) then` ⏎ `      break` ⏎ `    end` → removed | killed (1 case) |
| H4 | `      fastest[step] = math.min(fastest[step] or math.huge, seconds)` → `      fastest[step] = seconds` | killed (2 cases), `"4.0 s"` against `"2.5 s"` |
| H5 | `local STARTS_FOR_A_COMPILING_CHILD = 5` → `= 4` | killed (1 case), `left = 4, right = 5` |

### Slowing mutants, on `2d5722f` (each 10 runs per version, one at a time, quiet; every kill by assertion, the `Cause` naming the first step over)

MK2 and MK5 are the review's literal edits of `init.lua:132`: `      answers[path] = names_file(path)` → `      for _ = 1, k do` ⏎ `        names_file(path)` ⏎ `      end` ⏎ `      answers[path] = names_file(path)`, with k = 2 and 5. PROC is the review's literal edit too: first line of `render.lua`'s `M.render_records`: `  vim.fn.system({ 'sh', '-c', 'i=0; while [ $i -lt 400000 ]; do i=$((i+1)); done' })`.

| mutant | case | 0.12.5 | 0.11.6 |
|---|---|---|---|
| M10 | paths | 10/10, arrival 15.4–19.7 s | 10/10, 14.5–16.7 s |
| X11 | links, 1 000 000 `)` | 10/10, 69.6–87.8 s | 10/10, 70.0–90.3 s |
| N21 | links, `)` × 20 000 | 10/10, 2.7 s | 10/10, 2.4 s |
| MK2 | paths | 10/10, 2.2–2.3 s | 10/10, 2.0–2.1 s |
| MK5 | paths | 10/10, 4.0–4.1 s | 10/10, 3.7–3.8 s |
| W3 | paths | 10/10, 6.9 s | 10/10, 6.9–7.0 s |
| PROC | paths | 10/10, 4.1 s | 10/10, 4.1–4.2 s |

- **MK2 on 0.11.6 sits 0–5% over the bound** (2.0–2.1 s, printed "2.0 s" when just over). It was killed in every run, but its margin is the thinnest.
- **The first X11 runner was set aside.** It ran the two versions side by side against one fixture directory, so each start emptied the other's. One run failed at `fixture.lua:19` ("cannot remove"), which is not a kill. Its lines are in `t29-kills-X11-aborted.txt`; the counts above come from a rerun with a fixture directory per version.

### The correct drawing, on `2d5722f`

- **Whole files, quiet:** `tests/test_fastest_time.lua` 7 cases, paths 90, links 83, `Fails (0)`, on both versions.
- **20 quiet runs of each narrowed case per version:**
  - links: 20/20 on both versions;
  - paths: 20/20 on 0.11.6, 19/20 on 0.12.5. The one failure was not a timing verdict: the child Neovim crashed during the step, and the harness raised "ch 4 was closed by the peer" at `fastest_time.lua:82`.
  - The crash report (`~/Library/Logs/DiagnosticReports/nvim-2026-10-04-214309.ips`) is 0.12.5's Homebrew Neovim: EXC_BAD_ACCESS (SIGSEGV), KERN_INVALID_ADDRESS "possible pointer authentication failure", inside `libluajit-5.1.2.1.1788856981.dylib`, two frames below `lua_pcall` ← `nlua_exec` ← `handle_nvim_exec_lua`, 94 ms after the child started.
  - **A fresh series on 0.12.5, 20 paths runs and 20 links runs** (`t29-pass-B.txt`, loads 7.7–11.6): 20/20 and 20/20, with no crash.
  - **The crash's rate, stated once** (the re-measure's finding 8). This note's fix-round version gave two rates, "once in 60 quiet paths runs" here and "once in about 20 quiet runs" under *Open threads*; neither holds as written, and the author's scratch is gone, so the 60 cannot be checked. What the records show: one crash in the 40 quiet runs of the narrowed paths case on 0.12.5 that this note lists (the earlier series' 20 and the fresh series' 20), one in the re-measure's 72 runs of a paths-case file, and none in the correction's 42 (below).
- **Under `taskpolicy -b`,** 3 runs each, as the orchestrator asked to be reported:
  - paths fails every run: arrival 3.7–3.8 s on 0.12.5, 3.6–3.9 s on 0.11.6;
  - links passes every run.

  All three attempts run on the slow cores, so the fastest of three is still over 2 s.

### Under load: five whole suites

Five `make test` runs side by side, in clones of this branch under `.tests/`, with my narrowed cases looping on both versions in separate processes (`t29-underload-*.txt`). In A2 and A3 each suite had a clone of its own, so their fixtures did not collide; in A1 the five shared one clone and collided. **Wrong in the PR body and the author's report** (the re-measure's finding 3): "236/236 … each in its own clone". The own-clone count is 156/156 (A2 and A3); the other 80/80 are A1's, whose suites collided.

| load run | cases looped | loads | result |
|---|---|---|---|
| A1 (five suites in one clone; they collided and ended in about 4 min) | new paths, new links | 21–184 | 80/80 pass |
| A2 (one clone each) | new paths, new links | 18–140 | 96/96 pass |
| A3 (one clone each) | old paths (`985f1ee`), new paths, new links | 77–190 | new: 60/60 pass; old: 29/30 pass, 1 fail (0.11.6, arrival `3.0 s`, load 187) |

- **The condition is not reproduced by these runs.** The old form failed only 1 of 30, where T22's record has it failing every run. In T22's runs the case ran *inside* one of the five suites. A control of that form — five suites of `985f1ee` side by side, counting their own timing cases — was the next step. Auto mode's permission classifier refused it as interfering with other workloads, and I did not pursue it otherwise.
- **So the 20/20 criterion under five side-by-side suites is unmet as specified.** What stands is 156/156 passes of the new cases beside such suites, at loads up to 190, against the old form's 29/30 there.

### LuaJIT on 0.11.6 (for the knowledge pass, finding 11)

`.tests/t29-jitprobe.lua` started a child 60 times per version, ran fastest_time's own hot loop in each, then timed a 200 000-string plain-Lua loop:

| version | children whose LuaJIT compiled no trace | plain-Lua loop, compiling children | the same, no trace |
|---|---|---|---|
| 0.11.6 (`v0.11.6+ge8b87a554f`) | **5 of 60** | 0.030–0.037 s | 0.259–0.269 s |
| 0.12.5 (Homebrew) | 0 of 60 | 0.032–0.043 s | — |

This agrees with the review's 9 of 112 harness children on 0.11.6 and 0 of 117 on 0.12.5, and with its trace error 27 ("failed to allocate mcode memory").

## The correction (2026-10-05)

A fresh agent's bounded correction of the re-measure of `4ed9549` (`remeasure97/remeasure-t29-report.md`). **The orchestrator's decisions** (`orch-correction-97.md`):
1. Finding 1: judge each step by the second-fastest of three attempts, the re-measure's measured fix, credited; pinned red first under INT's shape.
2. Finding 4: each attempt in a home of its own; pinned red first under WARM's shape.
3. Finding 6: after five starts with no compiling JIT, time the child anyway.
4. Finding 7: the re-measure's stronger pin, which kills H12, credited.
5. Findings 3 and 8: 156 for 236, the crash rate stated once, the Limits line saying what was measured; corrected in this note and in the PR body, by a commit that names the wrong statements.
6. Finding 2 stays a recorded limit; the user then skipped the five-suite run (below).
7. Finding 5, the LuaJIT crash, is a recorded limit, not caused by T29.

Only 0.12.5 ran (D29); no whole suite ran (D28). Every run was one Neovim run at a time, at loads 10.0–20.7 made by other agents' processes; I started no host-wide load.

### Unit list (correction)

1. A step within the limit in only one of three attempts shows its second-fastest time.
2. Each attempt's child starts in a home no earlier attempt has drawn in.
3. The attempts leave the test's own home as they found it, and raise what a failing start raised.
4. A child that compiles no code in five starts is timed after its fifth start.
5. The JIT pin sees a timed child that is not the checked one (H12).

### Seen red, and what arrived green

Each red is by assertion, in `tests/test_timed_attempts.lua` on 0.12.5 (`.tests/t29c-u*.log`):

| test | red against | Cause |
|---|---|---|
| *a step › within the limit in only one of three attempts shows its second-fastest time* (unit 1; attempts of 4.2, 1 and 4.4 s, INT's shape) | the fix round's helper | `left = "within the limit", right = "4.2 s"` |
| *a step › over the limit in every attempt shows its second-fastest time* (the fix round's pin, its contract changed) | the fix round's helper | `left = "2.5 s", right = "3.5 s"` |
| *the attempts › end once every step has come within the limit in two of them* (the fix round's pin, its contract changed: 2 attempts, not 1) | the fix round's helper | `different values` (1 against 2) |
| *the attempts › start their children in homes no earlier attempt has drawn in* (unit 2; a step slow on its home's first drawing, WARM's shape) | the helper after unit 1 | `left = "within the limit", right = "3.0 s"` |
| *a child › that compiles no code in five starts is timed after its fifth start* (unit 4; replaces *… raises an error*) | the helper after unit 2 | `different values at key 1, left = false, right = true` |
| *a child › whose LuaJIT compiles no code is started again before it is timed* (unit 5: its start now fails on every odd start too) | H12 | `"compiled", left = "3.0 s", right = "within the limit"`; H12 survived the old pin, `Fails (0)` |

The two contract-changed pins were updated after unit 1's implementation turned them red, and were then run against the fix round's helper, where they are red as listed.

**Arrived green, each with its killer run** (the literal edits are in the next table):
- *a step › within the limit in two of three attempts is within the limit* (the fix round's *… in one of the attempts …*, its data made three attempts): green on both forms; killed by S3.
- *a step › is judged on its own second-fastest attempt, apart from the other steps* (gains a third attempt): green on both forms; killed by S3.
- *the attempts › leave the test's own home as they found it* and *… raise what a start raised, with the test's own home as they found it* (unit 3): pinning code written with unit 2, ahead of its tests; killed by R1 (both) and R2 (the second).
- *the attempts › are three at most*: unchanged; killed by H2.

### Helper mutants (each run once on the final tree, against `tests/test_timed_attempts.lua`; every kill by assertion)

| id | literal edit of `tests/helpers/timed_attempts.lua` | result |
|---|---|---|
| H1 | `    if child.lua_get(COMPILES_CODE) then` → `    if true then` | killed, 2 cases |
| H2 | `local ATTEMPTS = 3` → `local ATTEMPTS = 1` | killed, 9 cases (`"inf s"`) |
| H3 | `    if all_within(judged, limit) then` ⏎ `      break` ⏎ `    end` → removed | killed, 2 cases |
| H5 | `local STARTS_FOR_A_COMPILING_CHILD = 5` → `= 4` | killed, `left = 4, right = 5` |
| H12 | `    if child.lua_get(COMPILES_CODE) then` ⏎ `      return` → the same with `      start()` before `return` | killed, `"compiled" = "3.0 s"` |
| R1 | `  for variable in pairs(XDG_BASE_DIRECTORIES) do` ⏎ `    vim.env[variable] = inherited[variable]` ⏎ `  end` → removed | killed, 2 cases |
| R2 | `  if not started then` ⏎ `    error(failure, 0)` ⏎ `  end` → removed | killed, `left = true, right = false` |
| F1 | `    in_a_home_of_its_own(function()` ⏎ `      start_compiling_child(child, timing.start)` ⏎ `    end)` → `    start_compiling_child(child, timing.start)` | killed, `"first_drawing" … "3.0 s"` |
| S1 | `    judged[step] = sorted[2] or math.huge` → `sorted[1]` (the fix round's fastest) | killed, 4 cases |
| S3 | the same → `sorted[3]` (the slowest) | killed, 6 cases |

The fix round's H4 (`math.min`) has no counterpart: that line is gone, and S1 replaces it.

### Case mutants, on `64eb574` (one run at a time; every kill by assertion, read from its `Cause`)

The narrowed copies come from the re-measure's `rm-narrow.py`, unchanged but for their names. INT and WARM are the re-measure's literal edits of `lua/aineo/report/init.lua` in `rm-mutant.py`: INT draws a per-process coin from `vim.uv.random` and, when it comes up slow, makes five extra `names_file(path)` calls a path; WARM makes them until a marker exists in the child's `stdpath('cache')`. The others are the edits in the fix round's table above.

| mutant | narrowed | whole file |
|---|---|---|
| INT | **killed 5 of 8**: exactly the runs whose children drew two slow coins (`T T F` ×3, `F T T` ×2), `arrival` 4.1–4.2 s; the 3 passes drew one slow coin or none (`T F F`, `F F`, `F T F`) | `test_report_paths.lua`, 4 runs: the timing case killed in 2 (`arrival = "4.1 s"`); the counting cases *… are one for each distinct path, however often it occurs* failed in all 4 |
| WARM | killed 2 of 2, `arrival = "4.1 s"` | killed, `arrival = "4.1 s"` |
| N21 | killed (`)` × 20 000), `"2.7 s"` | the `)` × 20 000 row killed, `"2.7 s"`; the run then outlasted the runner's 960 s limit, in the 1 000 000 row |
| MK2 | killed, `"2.3 s"` | killed, `"2.2 s"`, and the two counting cases failed |
| M10 | killed, `"18.9 s"` / `"16.3 s"` | killed, `"17.6 s"` / `"15.1 s"` |
| W3 | paths killed, `"7.0 s"` / `"4.0 s"`; links, all 4 rows, `"6.0"`–`"6.2 s"` | paths killed, `"7.0 s"`; links, all 4 rows |

A kill of INT needs two slow children of three: for a coin of one half, the single-attempt form's rate, as the re-measure measured. Under the fix round's form the re-measure saw 0 kills in 8.

### The correct drawing, on `64eb574`

- **Narrowed:** paths 10/10, links (all four rows) 10/10.
- **Whole files:** `test_report_paths.lua` 10/10 (90 cases each run), `test_report_links.lua` 10/10 (83 cases each run), and `tests/test_timed_attempts.lua` 11 cases, `Fails (0)`.
- No child crashed in the correction's 42 runs of a paths-case file, mutants included.

### The five-suite condition, skipped by the user

The re-measure's finding 2: the new form was never measured *inside* five side-by-side suites, the one condition in which T22 saw the old form fail every run, and the 156 runs beside them prove nothing about it, since the old form passed there too. Measuring it needs host-wide load. The user decided on 2026-10-05: "skip the five-suite run". It stays a recorded limit.

## Verification

- **Whole suite skipped (D28):** the user's decision of 2026-10-04. A test-only packet is one the orchestrator dispatched whose branch changes nothing outside `tests/` except its own session note and task lines. T29 is one.
  - The changed or added test files, and every test file that requires the helper, ran on 0.12.5 on `64eb574`: `tests/test_report_paths.lua`, `tests/test_report_links.lua` and `tests/test_timed_attempts.lua` (`grep -rl timed_attempts tests scripts lua plugin`).
  - The fix round ran its files on both versions, on `2d5722f`, before the user's decision of 2026-10-05 dropped 0.11.6.
  - The orchestrator's combined verification runs the whole suite.
- **Lint:** `make lint` clean (StyLua, selene). The deep-require check prints nothing for the changed files.

## Decisions & reasoning

- **(A) over (B)** (the orchestrator's decision 2): (A) met the mutant criteria. It is portable, needs no fallback, and counts waiting and other processes' work. **Wrong as first written:** "so RP4 keeps its meaning". Judging by the best of several processes changes it; the reading the user accepted is above.
- **Each step judged on its own attempts,** not one attempt for both steps. **Wrong as first written:** "A drawing that is really over the bound is over in every attempt, so this costs no kill". A drawing whose cost varies from process to process is not: on 0.12.5 `pairs()` visits string keys in a different order from one Neovim to the next (the re-measure's probe), and INT, over the bound in about half of its processes, passed the fastest of three 8 of 8 times. The correction judges the second-fastest of three.
- **A child that compiles no code is restarted, then timed all the same** (the correction; the fix round raised an error instead). A child without a JIT is only slower, so timing it can fail a correct drawing but never pass a slow one; on 0.12.5 the re-measure measured the correct drawing at 1.06–1.32 s in such a child, and MK2 still killed. Five starts bound the retries; at 5 of 60 a start on 0.11.6, five failures in a row are about 4 in a million.
- **A crash stays a failure.** The helper does not retry a child that dies: a crash in the drawing is a defect, never a slow attempt.

## Task lines

The wave held its marks. Wave 6's closing knowledge pass marks the plan's T29 row `done — PR #97, wave 6`. The line, as written for it:

- [X] T29 — both timing cases judge each step by its second-fastest wall time over three attempts, each in a fresh child with a home of its own and a LuaJIT that compiles code where five starts give one (`tests/helpers/timed_attempts.lua`, pinned by `tests/test_timed_attempts.lua`), the 2 s bound kept; RP4 now reads "the step's second-fastest wall time over three fresh processes is within 2 s on this host", accepted by the user on 2026-10-05 ("ok on the reading"). M10, X11, N21, MK2, MK5, W3 and PROC were killed 10 of 10 on 0.12.5 by the fix round's form; the correction killed INT (5 of 8, exactly its runs with two slow processes), WARM and H12, and N21, MK2, M10 and W3 once more, by assertion. The correct drawing passes 10/10 narrowed and 10/10 whole on each file. It was not measured inside five side-by-side suites, which the user skipped; it fails under `taskpolicy -b`, which was dropped as a requirement.

## Limits

- **The five-suite condition** was measured beside the suites, not inside them; the user skipped the in-suite run on 2026-10-05.
- **MK2's margin.** On 0.11.6, quiet, MK2 measured 2.0–2.1 s, 0–5% over the bound, and was killed in each of its 10 runs. Load only lengthens a wall time, so load cannot hide a drawing over the bound: the re-measure killed MK2 at load 25 → 51 and N21 at 16 → 25 on 0.12.5. What load threatens is the correct drawing. **Wrong as first written:** "A drawing that much slower than RP4 is caught by a wall-clock bound only while the host is quiet."
- **A drawing over the bound in one process of three passes;** that is the reading the user accepted.
- **Under `taskpolicy -b`** the paths case fails, as the old form did.
- **A child that crashes** fails the case; the helper does not retry it (the re-measure's finding 5, not caused by T29).

## Open threads

- **The 0.12.5 LuaJIT crash** in a child during the paths step, at the rate stated once under *The correct drawing, on `2d5722f`*. Not attributed: SIGSEGV inside `libluajit-5.1.2.1.1788856981.dylib` under `lua_pcall` ← `nlua_exec` ← `handle_nvim_exec_lua`, 92–94 ms after the child started, in both crash reports read.

## Commits

Recorded after the merge, by wave 6's closing knowledge pass. PR #97 merged by rebase on 2026-10-05 (00:27 UTC; 02:27 CEST); `dev` `d1b9225`. No release: the packet changes only tests.

| Branch | `dev` | Subject |
|---|---|---|
| `418c271` | `bd194da` | Bound the Report's timing cases by work, not wall time |
| `df4fd81` | `e213390` | Record T29's session: the timing cases' form and its kills |
| `2d5722f` | `83948a3` | Judge the timing cases by their fastest of three wall times |
| `4ed9549` | `b4573c4` | Correct T29's session note and record its fix round |
| `64eb574` | `7d762c5` | Judge the timing cases by their second-fastest of three homes |
| `0e55599` | `d1b9225` | Correct T29's records after the re-measure, with the user's reading |
