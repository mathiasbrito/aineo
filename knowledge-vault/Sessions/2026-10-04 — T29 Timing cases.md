# 2026-10-04 — T29 Timing cases

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t29-timing-cases` · **Pull request:** #97 into `dev` (a regular packet, test-only)

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › *Implementation plan*, T29
- Wave plan: `Implementation/Waves/00006-fixes/plan.md`; brief: `brief-t29-timing-cases.md`; brief review: `brief-review-t27-t29.md` › *T29*
- Rests on: [[Sessions/2026-09-26 — T17 Report paths]] (RP4, M10), [[Sessions/2026-09-26 — T10 Report links]] (X11, N21), [[Sessions/2026-09-27 — T22 parallel runner]] (the flakes), MR133 and MR159 in [[Review/2026-09-24 — v1 MVP readings review]], [[Learnings/vim.wait does not time out under an event flood]]

## Context

**Goal:** T29. The Report's two timing cases fail only when the Report's own work exceeds their bound, not when the host is busy. These are `tests/test_report_paths.lua`'s *of a line of distinct paths take at most the time limit, on arrival and on :edit* and `tests/test_report_links.lua`'s *a long line › shows in the Report, and again on :edit, within the time limit*. Test-only; the 2 s bound does not change.

**Why:** both cases timed the step once with `vim.uv.hrtime()`. Failures recorded while the drawing was unchanged:
- 1 of 1434 cases in the 0.11.6 verification of PR #85;
- every run made beside five or six whole suites;
- the links 1 000 000 `)` row, 2 of 10 at loads 128–253.

## What was done (the state after the fix round)

- **`tests/helpers/fastest_time.lua`** (new) exports `within_limit(child, timing, limit)`. `timing` is `{ start, steps }`: `start` starts the child ready for the steps, and `steps` times them, returning seconds by step.
  - **Each step is judged by its fastest of up to three attempts.** Each attempt runs in a child started afresh. The attempts end at the first one after which every step has come within the limit.
  - **Before an attempt is timed, its child is started again until its LuaJIT compiles code.** A hot loop must leave `jit.util.traceinfo(1)` non-nil; at most five starts, then an error naming the count.
  - The verdict strings are unchanged: "within the limit", or the fastest time, such as "2.4 s".
- **Both cases** return each step's wall-clock seconds (`hrtime`) and are judged through `within_limit()`, against the unchanged `TIME_LIMIT_SECONDS = 2`.
- **`tests/test_fastest_time.lua`** (new) pins the helper in 7 cases, the JIT guard among them.
- **`tests/helpers/work_time.lua`,** the first round's helper, is removed.

**RP4 keeps its meaning,** "within 2 s on this host": the cases measure wall time again, so waiting and other processes' work count. **There is no reading to put to the user.** The first round's reading ("within 2 s of work on this host's performance cores") is withdrawn with the form it described.

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
  - **A fresh series on 0.12.5, 20 paths runs and 20 links runs** (`t29-pass-B.txt`, loads 7.7–11.6): 20/20 and 20/20, with no crash. The crash came once in 60 quiet paths runs on 0.12.5 in this round.
- **Under `taskpolicy -b`,** 3 runs each, as the orchestrator asked to be reported:
  - paths fails every run: arrival 3.7–3.8 s on 0.12.5, 3.6–3.9 s on 0.11.6;
  - links passes every run.

  All three attempts run on the slow cores, so the fastest of three is still over 2 s.

### Under load: five whole suites

Five `make test` runs side by side, each in a clone of this branch under `.tests/` (one clone each, so their fixtures do not collide), with my narrowed cases looping on both versions in separate processes (`t29-underload-*.txt`):

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

## Verification

- **Whole suite skipped (D28):** the user's decision of 2026-10-04. A test-only packet is one the orchestrator dispatched whose branch changes nothing outside `tests/` except its own session note and task lines. T29 is one.
  - The changed or added test files, and every test file that requires the changed or added helper, ran on both versions on `2d5722f`, before the user's decision of 2026-10-05 dropped 0.11.6. These are `tests/test_report_paths.lua`, `tests/test_report_links.lua` and `tests/test_fastest_time.lua` (`grep -rl fastest_time tests scripts lua plugin`).
  - The orchestrator's combined verification runs the whole suite once per version.
- **Lint:** `make lint` clean (StyLua, selene). The deep-require check prints nothing for the changed files.

## Decisions & reasoning

- **(A) over (B)** (the orchestrator's decision 2): (A) met the mutant criteria. It is portable, needs no fallback, and counts waiting and other processes' work, so RP4 keeps its meaning.
- **Each step judged on its own fastest attempt,** not one attempt for both steps. A drawing that is really over the bound is over in every attempt, so this costs no kill: all slowing mutants died 10 of 10.
- **A child that compiles no code is restarted, never measured.** Measuring it would time LuaJIT's failure, not aineo's drawing. Five starts bound the retries; at 5 of 60 a start, five failures in a row are about 4 in a million.
- **A crash stays a failure.** The helper does not retry a child that dies: a crash in the drawing is a defect, never a slow attempt.

## Task lines

The wave holds its marks; the knowledge pass applies this one:

- [X] T29 — both timing cases judge each step by its fastest wall time in up to three attempts, each in a fresh child whose LuaJIT compiles code (`tests/helpers/fastest_time.lua`, pinned by `tests/test_fastest_time.lua`), the 2 s bound and RP4's meaning kept. M10, X11, N21, MK2, MK5, W3 and PROC are killed 10 of 10 on 0.12.5, and also on 0.11.6 before the user dropped it on 2026-10-05. The correct drawing passes quiet, 20/20 and 20/20 on 0.12.5, with one earlier run lost to a LuaJIT crash. It also passes beside five side-by-side suites; the in-suite control was refused by the permission classifier. It fails under `taskpolicy -b`, which was dropped as a requirement.

## Limits

- The five-suite condition was measured beside the suites, not inside them (above).
- MK2 on 0.11.6 sits 0–5% over the bound. A drawing that much slower than RP4 is caught by a wall-clock bound only while the host is quiet.
- Under `taskpolicy -b` the paths case fails, as the old form did.

## Open threads

- **For the orchestrator:** the in-suite control and the 20/20 run inside five side-by-side suites, which the permission classifier refused me.
- **The 0.12.5 LuaJIT crash** in a child during the paths step (once in about 20 quiet runs here). Not attributed; the crash report is named above.

## Commits

*Recorded after the merge.*
