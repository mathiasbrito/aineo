# Brief review — T24 (panes) and T30 (drop Neovim 0.11), PR #103

Reviewer: `reviewer`, dimension **brief**, resource `review_brief_t24_t30`.
Head: `850c86f` (`origin/knowledge/w7-t24-t30-briefs`), on `origin/dev` `5db771e`. Checked out detached; `git log -1` → `850c86f Record the user's T24, D20 and D29 answers and plan T30`.
Host Neovim: `NVIM v0.12.5` (Homebrew, `/opt/homebrew/Cellar/neovim/0.12.5_1`). Nothing ran on 0.11. The real `claude` never ran: every probe had `tests/helpers/entry_guard/` first on `PATH` and its XDG homes, `NVIM_LOG_FILE` and `TMPDIR` inside this worktree.
Scratch: this folder, every file prefixed `brief-` (probe sources `brief-probe-*.lua`, outputs `brief-probe-*.out`, test runs `brief-run-*.log`).

The question: **would an implementer acting on either brief be misled by anything in it?**
Short answer: T24, in four places that decide behaviour (the draft on a pane-door open, PD3's trigger, the partial layout, the wrap reading), and by the absence of a mutant for any of the six answers. T30, in its C branches, which miss what 0.12.5 measurably does, in D's count of what pins the check, and in a boundary that leaves out three things its own instructions need.

---

## T24 — findings

### T24-1. MISSING (high): PD4 (a)'s open does not hand Input to the draft home, and the boundary does not allow the helper that would
- PD4 (a): "`\pa` and `\pc` with the layout not open open it first, showing that pane, as `\r`, `\i` and `\c` do."
- `\r`, `\i` and `\c` open through `focus()` (`plugin/aineo.lua:192–202`), which calls `keep_input_draft()` when the layout was opened (`:199–201`). `open()` does too (`:178`). The brief never names `keep_input_draft()`, and no PN case says a pane door's open hands Input over.
- **Failure scenario:** autostart off (or the layout closed in a fresh editor). The user presses `\pc`: the layout opens around a new Input that is never handed to the draft home. `\pa`, the user types in Input, quits: nothing is saved (D17), and the draft saved earlier never came back into Input.
- **The boundary:** the brief lets T24 touch in `plugin/aineo.lua` only "`SUBCOMMANDS`, `USAGE`, `complete_subcommand()`, `ACTIONS`; the `<Plug>` loop and `plug_mapping()`; `PREFIX_KEYS`, `map_prefix()`; `:Aineo`'s definition; `arrangement()`". The pane action needs `resolved_config()`, `arrangement(config, current_claude_terminal(config))` and `keep_input_draft()`, as `focus()` has. A new local function beside `focus()` is not on the list, and "anything outside this boundary is a spec conflict".
- **Correction:** add to PN2 "a layout opened by `\pa` or `\pc` is handed to the draft home, as `focus()` hands it (`plugin/aineo.lua:199–201`)"; add to *You may touch* "a new local function for the pane action, beside `focus()`, opening the layout as `focus()` does"; add a mutant (T24-3's M13b).

### T24-2. MISSING (medium-high): PD3 (b) leaves the no-arrival case open, and does not say where it can be built
- The amendment: "A report that arrives while the changes pane shows shows nothing then. `\pa` brings the Report back with its cursor at its last line, as an arrival would have put it."
- **Two readings, both pass a PD3 test:** (i) last line only when a report arrived while hidden; (ii) last line on every `\pa`. With (ii), a user reading line 50 of 100 who glances at `\pc` and back with nothing new loses their place. PN5 says the agent pane "comes back whole" but names buffers, text, the draft, the wrap and the reports, not the cursor.
- **Where:** `lua/aineo/report/` is forbidden, and `follow_last_line()` (`lua/aineo/report/buffer.lua:225–230`, called at `report/init.lua:276`) moves only the windows that show the Report. So PD3 (b) must be built in the layout home, from what it can see of the Report buffer at the switch (its `b:changedtick` or line count). The brief says neither, and an implementer who reaches for the report home will stop on a spec conflict.
- **Testable as described:** yes. P3, re-run (table below): a plain swap brings the Report back on line 100 of 130, so a case that asserts the last line after an arrival while hidden is red against a plain switch and against option (a).
- **Correction:** state (i) as the orchestrator's reading ("with no report arrived, `\pa` brings the Report back where it was"), pin it with a second PN5 case, and say "built in the layout home, from the Report buffer's change count at the switch; the report home is not touched".

### T24-3. MISSING (medium): no verification mutant pins any of the six answers
- M1–M10 kill the switch, `\o`'s pane, the redirect, the placeholder, the prefix, completion, an unknown pane, the health line and new buffers. None is the unchosen option of a PD. Every PD has a PN line (PN2: PD4 and PD5; PN3: PD6; PN5: PD3; PN6: PD1 and PD2), so the implementer is told to test them, but the orchestrator's verification never checks that those tests kill the alternative the user rejected.
- No M1–M10 stops killing under the chosen options: each targets a property independent of the PDs (M1 by PN3, which D21 fixes; M2 and M3 by PN1; the rest as named). Checked by reading each against PD1–PD6.
- **Correction:** add, as literal edits:
  - **M11 (PD1 b):** `M.focus()` moves to `state.windows[role]` without showing the agent pane. PN6 must kill it.
  - **M12 (PD3 a):** `\pa` leaves the Report's cursor where it was. PN5 must kill it.
  - **M13 (PD4 b):** `\pa` and `\pc` with the layout not open warn and open nothing. PN2 must kill it.
  - **M13b (T24-1):** the pane action opens the layout without `keep_input_draft()`. The new draft case must kill it.
  - **M14 (PD5 b):** a switch moves the cursor to the Report's place. PN2 must kill it.
  - **M15 (PD6 b):** `build()` shows the agent pane whatever was shown last. PN3 must kill it.

### T24-4. MISSING (medium): `\pa` and `\pc` with one of the right column's windows closed
- PD4's options were put as "never opened, or its three windows closed". The orchestrator's reading says "`\pa` with the agent pane shown … change[s] nothing". D18's switch is "in place", in two windows.
- **Failure scenario:** `:q` in Input's window, then `\pc`. One implementer shows the files window in the Report's place and the commits buffer nowhere. Another runs `M.open()` first, as `\i` would (`M.focus()` opens the layout when its window is gone, `lua/aineo/layout/init.lua:933–938`). Both satisfy the brief. Likewise `\pa` there "changes nothing" while `\i` would reopen Input.
- **Correction:** an orchestrator reading consistent with PD4 (a)'s "as `\r`, `\i` and `\c` do": "when either window of the right column is gone, `\pa` and `\pc` open the layout first (`M.open()`'s restore), then show the pane", with a PN2 case.

### T24-5. MISSING (medium): the wrap reading is unpinned, and `M.open()` breaks it by default
- Reading: "T16's wrap stays the Report's and Input's … The changes pane's buffers keep the user's own settings until T25 says otherwise."
- `M.open()` calls `wrap_right_column()` on every open and restore (`lua/aineo/layout/init.lua:912`). It writes `vim.wo[state.windows[role]][0]`, the window-local options of whatever buffer each right-column window shows (`:215–221`). Under PN3 (`\o` with the changes pane) and PD6 (a layout built anew on the changes pane), that buffer is a placeholder.
- **Failure scenario:** `set nowrap`, `\pc`, `\o`: the placeholders now wrap, and keep wrapping in those windows. No PN case and no mutant catches it.
- **Correction:** a PN3 line ("`\o` with the changes pane shown sets no option on the changes buffers; the Report and Input wrap again at `\pa`"), and a mutant: `wrap_right_column()` left applying to whatever the right column shows.

### T24-6. CONFIRMED (low-medium): the spec carries no record of PD1–PD6, and PD1 (a) reads against D21's words
- D21: "switching panes stays with `\pa` and `\pc` (D18)". PD1 (a) makes `\r` and `\i` show the agent pane too.
- The brief explains that D21's clause answered Q6, about `\o` alone, and the user chose PD1 (a) with that context. But the brief also says "Read them whole in the plan note". The root `CLAUDE.md` says "A packet that finds the plan, its brief and the code disagreeing reports a spec conflict; it does not choose", and the plan note (the spec) records PD1–PD6 nowhere. #103 annotated D20 and D29 for the same day's answers, but not D18 or D21.
- **Correction:** a dated annotation on D18 or D21 recording PD1–PD6 (or new D rows), as #103 did for D20.

### T24-7. CONFIRMED (low): two help places that T24 changes are not named among the places
- Section 4's `:Aineo report` and `:Aineo input` entries (`doc/aineo.txt:185–189`, "Moves the cursor to …"): under PD1 (a) they show the agent pane first. Section 4 is in the boundary, but its sub-list names only `:172`, the new `*:Aineo-pane*` and `205–216`.
- Section 7, *SEND* (`:376–395`): PD2 (a) sends Input while the changes pane hides it. Nothing there becomes false, but a user is not told, and the section is outside the boundary.
- **Correction:** add the two entries to section 4's sub-list. Either allow one sentence in section 7, or record that it stays silent.

### T24-8. CONFIRMED (low): the health pins at `[1]` and `[2]` depend on where `pane` lands in the completion order
- The brief lists the count pins (`563`, `598`) and the `[7]` pins. Three more pins index a key by position: `tests/test_health.lua:744` (`[1]`, `\s`) and `:797` and `:808` (`[2]`, `\o`). They hold only if `pane` comes after `open` in `SUBCOMMANDS`.
- The reading "the health check's keys follow `:Aineo`'s completion order" does not say where `pane` goes.
- **Correction:** say "`pane` goes last in `SUBCOMMANDS`" (or list the three pins).

### T24-9. CONFIRMED (low): stale facts in #103's records
- **The open pull request:** the plan's *Packet T24* recomputation says "The only open pull request is #102, this plan's own". `gh pr view 102` → `CLOSED` (2026-10-05T10:49:48Z). `gh pr list --state open` lists only #103.
- **The facts' base:** "Facts, checked against `origin/dev` (`d1b9225`)": `origin/dev` is `5db771e`. The code is identical (`git diff --stat d1b9225 5db771e -- . ':!knowledge-vault'` prints nothing), so this is a label only.
- **The pause:** the plan's *Landed* still says "T24–T26 wait for the user's go". The project note (`:84`) records the go as the orchestrator's reading of the user's 2026-10-04 words, with confirmation asked. #103 dispatches T24 without closing that line.
- **The 0.12 minimum and D20:** the root `CLAUDE.md:31` says "the 0.12 minimum is the orchestrator's reading of it, not yet answered". The project note says the same at `:5` and `:114`, and lists D20's clauses as awaiting the user at `:115`. #103 records both as answered, and both briefs tell the implementer to read the root `CLAUDE.md` and the project note. (`CLAUDE.md` is an `ai/` change; the project note is the knowledge pass's.)

### T24 — verified true (REFUTED as defects)
- Every line range and symbol under *Facts*, at `5db771e`:
  - `layout/init.lua`: 1012 lines, `ROLES` at 59, state at 27–42, and `76–78`, `187–191`, `195–200`, `208`, `215–221`, `419–438`, `436`, `445–454`, `522–541`, `619–636`, `656–669`, `779–808`, `896–916`, `907–908`, `929–940`, `990–1003`;
  - `columns.lua`: 100 lines;
  - `plugin/aineo.lua`: 544 lines, and `27`, `30`, `37–41`, `161–168`, `232–247`, `233–235`, `307–309`, `311–315`, `318–325`, `335–340`, `348–358`, `532–544`, `540`, `543`;
  - `health.lua`: `253–260`, `304–320`, `306`, `475–477`;
  - `send/init.lua`: `46–51` and `105–124`;
  - `draft/init.lua`: `352–358`;
  - `report/buffer.lua`: `101–104`, `125` and `225–230` (cited as `224–229`, the same function);
  - every test pin: `test_plugin.lua:65–84`; `test_entry.lua:38–66` (four case names); `helpers/entry.lua:18`; `test_entry_prefix.lua:7–14` and `89–103`; `test_health.lua`'s 9 lists, 2 counts and 9 `[7]`s, each at the line named; `test_doc.lua:74–106` and `110–161`; `helpers/layout.lua:98–100`; `helpers/send.lua:43–47` and `69–72`; `test_layout.lua:46`;
  - the help: `doc/aineo.txt` at 19, 25–30, 56, 58–75, 161–166, 169, 172, 205–216, 255, 280–304 and 610–622 (section headings at 18/19, 55/56, 168/169, 254/255, 585/586).
- `git grep -n pane 5db771e -- tests lua plugin doc` prints nothing.
- `git grep -n "aineo.layout'" 5db771e -- tests` finds only `require` calls, plus `tests/test_doc.lua:99` `'aineo-layout'`, which the unescaped `.` matches. The claim holds.
- The list of callers that build an arrangement is complete (`git grep -n "report_height\s*="`).
- The task row is verbatim (byte comparison with plan note line 151). The D18, D21 and C12 quotes match their rows (only the trailing period and the `\|` escape differ). The D19 and T25 quotes are present.
- T12 landed: `gh pr view 84` → `MERGED` 2026-09-28T01:29:42Z.
- The baseline: `evidence/baseline-cd29244.txt` says 1455 cases, `Fails (0)`, 197 s, guard 5/`Fails (0)`, lint clean. That matches the orchestrator's record `verifyw6end.txt:474–482` and `verifyw6end.suite_0.12.5.log`. `git rev-parse 'd1b9225^{tree}'` → `cd292445be66cbf2eeaad1695ace466ecedefc11`. (`5db771e^{tree}` is `4036090`, which differs only under `knowledge-vault/`.)
- `knowledge-vault/Implementation/Waves/00006-fixes/evidence/window-option-scope.txt` probe 2 shows `vim.wo[win][0]` options coming back with the buffer on 0.12.5.
- The amendment's verbatim answer matches the orchestrator's ledger ("PD1, (a), PD2 (a), PD3 (b), PD4 (a), PD5 (a), PD6 (a) as for 4. …"). The quote stops where the next answer begins. Each answer equals the recommendation.
- No text still presents an option the user did not choose as the one to build. The PD list keeps the options for context, and the help's "if PD4 is (a)" is resolved by the amendment.

### P1–P4, re-run on 0.12.5 (sources extracted from `evidence/t24-probes.txt`, run as recorded)

| probe | recorded | re-measured |
|---|---|---|
| P1 `\p` only | 0 ms | 0 ms |
| P1 `\p`+`\pa`+`\pc`, timeoutlen 1000 | 1064 ms | 1117 ms |
| P1 timeoutlen 300 | 321 ms | 334 ms |
| P1 typing `\pa` | 0 ms | 0 ms |
| P1 `<Leader>p`, mapleader unset | 1066 ms | 1125 ms |
| P1 notimeout | still waiting after 3000 ms | same |
| P2 `-nargs=?` | `args="pane agent"`, one farg | same |
| P2 completion `Aineo pane ` | the six subcommands | same |
| P2 `:Aineo pane agent` | USAGE | same |
| P3 sizes through a swap | 59x25 / 59x1 / 60x27, unchanged | same |
| P3 cursor after 30 lines while hidden | line 100 of 130, `w0` 88 | same |
| P4 `:helptags`, `:help aineo-\pa`/`\pc` | no error, tags found | same |

Every claim drawn from P1–P4 holds. The timings differ by 13–59 ms, within noise; "after 'timeoutlen'" holds.

---

## T30 — findings

### T30-1. CONFIRMED (high): C's branches for `claude/init.lua:105–107` do not cover what 0.12.5 does
- The brief offers two outcomes: "If 0.12.5 runs the command or raises …" (keep the check, restate, report), or "If 0.12.5 does as 0.11.6 did …" (kind 3).
- **Measured** (`brief-probe-C1.lua`, `brief-probe-C1.out`): `jobstart({'sh','-c','echo ran in $(pwd); sleep 1'}, { term = true, cwd = <chmod 000> })` returns job 3. The child is gone at once (`ps` finds nothing), `on_exit` gives **122**, the buffer is empty, and the exit line reads `[Process exited 122]`. Nothing runs, nothing raises, and no copy of the editor runs.
- That is a third outcome. Without the check, the user would see an exited session with `[Process exited 122]` in place of `settings.cwd: expected a directory that exists and can be entered`: a change the user sees. So the right action is the first branch's (keep, restate, report), but the brief's words do not lead there.
- **Correction:** add the outcome "the job starts and exits at once (measured by the brief review: 122, `[Process exited 122]`)" to the first branch.

### T30-2. MISSING (high): a docstring the task row covers, outside the list and the boundary
- The task row: "every docstring that gives a Neovim 0.11.6 behaviour as a reason says what 0.12.5 does".
- The brief's list comes from grepping for `0.11`, which cannot find a docstring that states a 0.11.6 behaviour without naming the version.
- `lua/aineo/health.lua:122–129` (`run_within_bound()`) gives as its reason "the wait keeps its bound even while the command writes without end, when Neovim's own `vim.wait()` time-out does not run out". That is the 0.11.6 behaviour of `Learnings/vim.wait does not time out under an event flood.md` ("In Neovim 0.11.6, `vim.wait(ms, …)` does not return at `ms` while a child process keeps writing").
- **Measured on 0.12.5** (`brief-probe-W.lua`, `brief-probe-W.out`): with `yes flood` writing into a no-op stdout handler, `vim.wait(1000, …)` returned after **1002 ms**, and with `fast_only` after **1003 ms**. 0.12.5 does not have the behaviour. The code stays useful (it kills the group at the bound), but its stated reason is 0.11-only.
  - *Correction, 2026-10-05 (T30's knowledge pass; the finding above is left as it was reported): the 1002 ms came from a flood that never reached Neovim, and 0.12.5 has the behaviour. With no pipe opened for the writer's output (`stdout = false`), or with the writer sending it to `/dev/null`, `vim.wait(1000, …)` returns at 1001–1002 ms while the writer still floods. With a handler reading the flood, it returns only once the writer is killed. The figures: 3998–3999 ms with the writer killed at 3 s, from the T30 fix round; 10.9–11.0 s with it killed at 10 s, from the T30 packet; and PR #108's attack review's matrix. `vim.wait()` still subtracts whole milliseconds per pass: `LOOP_PROCESS_EVENTS_UNTIL` in `src/nvim/event/multiqueue.h` has the same body in v0.11.6 and v0.12.5. `run_within_bound()`'s reason holds on 0.12.5, and its docstring was kept (`evidence/t30-probes.txt` › *C6, why 1002 ms*). The probe this finding cites, `brief-probe-W.lua`, was kept nowhere.*
- `health.lua` is "every other file under `lua/`", forbidden to T30.
- 30 Learnings mention 0.11 (`grep -l "0\.11" knowledge-vault/Learnings/*.md`). Any of them behind an unnamed docstring is the same class.
- **Correction:** either add `lua/aineo/health.lua`: the docstring of `run_within_bound()`, with the probe as its measurement (T24 lands first, so no file conflict); or narrow the task row to "docstrings that name 0.11.6" and record the unnamed class as an open thread.

### T30-3. CONFIRMED (medium): D understates what pins the check, and what its removal makes false
- **What pins it:** "`tests/test_timed_attempts.lua:188` pins it" and "Remove the check, its loop, its case …". Two cases pin it:
  - `:188`, *whose LuaJIT compiles no code is started again before it is timed*;
  - `:202`, *that compiles no code in five starts is timed after its fifth start*.
  - Both use two helpers at `:38–63` (`start_compiling_on_even_starts_after()`, `child_holds_a_trace()`).
  - V4 run (table below) kills both, so both pin the check.
- **What it makes false:** `knowledge-vault/Review/2026-09-24 — v1 MVP readings review.md` MR212 records RP4's reading as "kept — put to the user … 'ok on the reading'", and that reading includes "where five starts give one, a LuaJIT that compiles code". T29's note (`:34`, `:289`) says the same. Removing the check makes MR212 false. The brief does not name MR212 among the knowledge pass's corrections, nor say that the user should hear that a clause of a reading they accepted is gone.
- **Correction:** say "its two cases (`:188`, `:202`) and their two helpers (`:38–63`)". Name MR212 for the knowledge pass, and the user's notice.

### T30-4. CONFIRMED (medium): the boundary leaves out three edits the brief's own instructions need
- **The evidence file.** *Where you write*: "Commit the probes' record as `knowledge-vault/Implementation/Waves/00007-panes/evidence/t30-probes.txt`". *You may touch* does not list it. The orchestrator's intake compares the file list with *You may touch* (SKILL §5), so the brief's own instruction would show as a widening.
- **A case name.** B removes the `'Error executing lua: '` row from `tests/test_mcp_delivery.lua:331–334`, whose case name is *… without either Neovim’s framing*. With one row left the name is false. The boundary for that file allows "the branches under A, the parametrized row under B, and their docstrings", not a case name.
- **The baseline run.** "Your run of `make test` on that `origin/dev`, before your first edit, is your baseline" asks for a whole-suite run that D26 and `implementer.md:56` ("The whole suite runs once per push, never per unit") do not call for. The brief itself says the dispatch message pastes the counts from the orchestrator's verification of T24's merge, which is the same tree.
- **Correction:** add the evidence path and the case name to *You may touch*; replace the baseline sentence with "the counts the dispatch message pastes are your baseline".

### T30-5. CONFIRMED (low-medium): C's other measurements are feasible, with two pitfalls the brief does not name
- **`init.lua:392`, the rows of a hidden terminal** (`brief-probe-C2.out`): `stty size` in a terminal no window shows → `5 80`, then `14 80` once shown in 14 rows. Same as 0.11.6: kind 3.
- **`readiness.lua:60`, the tallest of the windows:**
  - With the screen redrawn while the job runs (as mini.test's children redraw), windows of 1 and 12 rows give `1 80 -> 12 80`, and windows of 12 and 1 give `12 80`. That is the tallest, as for 0.11.6.
  - With a single `:redraw` before the job printed (`brief-probe-C.out`), windows of 7 and 14 rows gave **`7 80`**.
  - **Pitfall:** a measurement without redraws reads the first window's height and would restate the docstring wrongly. "In any tab page" was not measured here.
- **`stop.lua:32`, the signals after `jobstop()`** (`brief-probe-C4.out`): nothing ignored → 0.00 s, code 129; HUP ignored → **2.00 s, 143** (SIGTERM); HUP and TERM ignored → **4.00 s, 137** (SIGKILL). This fits `EXIT_AFTER_HANGUP_MS = 5000`.
  - **Pitfall:** the brief's one process "that ignores SIGHUP and SIGTERM" measures only the SIGKILL. The docstring's SIGTERM time needs a second process that ignores only the hangup.
- **`init.lua:407`, exit code 122:** already measured. `tests/test_claude.lua:396` (*is exited with 122 when the system cannot execute the command*) passes on 0.12.5 (`base-claude`, 73/`Fails (0)`). Kind 3; the brief's "if the code differs" cannot arise on this host.
- **Correction:** add "measure terminal sizes with the screen redrawn" and "add a process that ignores only the hangup".

### T30-6. CONFIRMED (low-medium): the review allocation departs from SKILL §6 and is credited to words that do not carry it
- "Reviews: attack by `neovim-claude-code-reviewer`; test integrity and records together by `reviewer`". The wave plan adds "at the user's 'optimize' of 2026-10-04".
- SKILL §6 gives a code packet three reviews, one per dimension. Only test-only, documentation and small-fix packets get fewer. T30 is regular and changes `plugin/` and `lua/`.
- The user's words were "Please be carefull with the testing strategy, since each run is taking too long, try to optimize." T27–T29's brief review already read them as asking for an optimisation without saying what to drop (`brief-review-t27-t29.md:33`). Nothing in them is about review dimensions.
- **Correction:** three reviews; or record the merge as the orchestrator's decision, not the user's, and how §6 allows it.

### T30-7. CONFIRMED (low): the session-note slot is not an exact filename
- `knowledge-vault/Sessions/<the date you start> — T30 Drop Neovim 0.11.md`. The template (`packet-brief.md:38`) asks for "this exact filename, chosen by the orchestrator so it collides with no other packet's".
- **Correction:** fix the date at dispatch.

### T30-8. CONFIRMED (low): the D29 and T30 records contradict what the T30 implementer must read
- The brief says "D29's minimum is the user's, 2026-10-05", and asks the implementer to read the root `CLAUDE.md` and the project note's *Open threads*.
- `CLAUDE.md:31` says the minimum is "the orchestrator's reading of it, not yet answered". The project note says so at `:5` and `:114`.
- A careful implementer meets a disagreement between the plan, its brief and `CLAUDE.md`, which `CLAUDE.md` tells it to report as a spec conflict. (Same root as T24-9.)
- **Correction:** correct the project note in #103 (knowledge) and `CLAUDE.md:31` on an `ai/` branch before dispatch, or say in the brief that both are stale until then.

### T30 — verified true (REFUTED as defects)
- **The list.** Grep over `lua plugin scripts tests doc Makefile .github` (`.github` does not exist) for `0\.11`, `nvim-0\.1`, `has('nvim`, `Error executing lua`, `vim.version`, `vim.fn.has(`, `nvim-0`, `0.10`, LuaJIT, plus compatibility idioms (`vim.loop`, `tbl_islist`, `tbl_flatten`, `or vim.uv`, `exists(`, old `vim.validate({`). Every hit is in the brief's lists or its *What stays*, except the two items below.
  - `tests/test_mcp_delivery.lua:331/334` is a case name (T30-4).
  - `:373`'s reason quotes `Error executing lua:` mid-sentence. It stays valid after B, since it is not anchored.
  - **"Eight test branches":** 8 — `test_entry.lua` 196, 220, 264, 282, 311; `test_claude.lua` 29, 55; `test_mcp_delivery.lua` 389. Every line number in A–D and *What stays* is right at `5db771e`.
- **B, can 0.12.5 still produce `Error executing lua: `?** No, by two measures.
  - **Every path tried** (`brief-probe-B.lua`, `brief-probe-B.out`):
    - `nvim_exec2`, `vim.cmd` and `nvim_command` of `:lua`, `luaeval()`, `:luado`, `:luafile`, `v:lua`, a user command, `doautocmd` of a Lua callback, `nvim_buf_call()`;
    - over RPC to a second 0.12.5: `nvim_exec_lua` (as the relay asks, including `require('aineo.report')` missing), `nvim_exec2`, `nvim_command`, `nvim_call_function('luaeval')`.
    - Every first line is framed `Lua: `, `E5108: Lua: `, `E5111: Lua: `, `E5113: Lua chunk: `, `Lua callback: `, or `Lua :command callback: `. None is `Error executing lua: `.
  - **The binary:** `strings -a /opt/homebrew/Cellar/neovim/0.12.5_1/bin/nvim | grep -i executing` holds no "Error executing" at all, and `grep -rn -i "error executing"` over 0.12.5's `runtime/lua` finds nothing.
- **B, is the editor always the Neovim that runs aineo?** Yes, for every path aineo builds.
  - The relay is started as `<v:progpath> --headless --clean … -l relay.lua` with `AINEO_EDITOR_ADDRESS = v:servername` (`lua/aineo/mcp/init.lua:25–35`). The editor it asks is the editor that started Claude Code, and the relay runs the same binary.
  - The only other Neovim that could answer is one that later binds the same address: a fixed `--listen` such as `127.0.0.1:6666`, after the editor died and left its Claude Code running. That Neovim, of any version, would then answer a delivery that fails anyway. B's removal would only leave an unstripped prefix in that tool error. Not worth a branch; record it in the docstring if you like.
- **What stays.** `stop.lua:11–13`, `readiness.lua:4` and the fixture header (`startup-2.1.281.bytes:3`) record where measurements of Claude Code were taken, so they are provenance. `stop.lua`'s waits do rest on them; re-measuring them on 0.12.5 needs Claude Code, so it is an open thread for the orchestrator, not T30's.
- **D, is 200 children enough?**
  - **Against about 1 in 12:** P(0 of 200 | 1/12) = 2.8 × 10⁻⁸.
  - **After 0 of 200:** the 95 % upper bound on the rate is 1.49 %. Under T29's second-fastest of three, a case then fails only when two of its three children compile nothing: ≤ 6.6 × 10⁻⁴.
  - **Measured here:** 200 of 200 fresh `nvim --clean --headless -l` children compile (`brief-run-D.sh`), and 200 of 200 embedded RPC children too (`brief-probe-D-embed.lua`), so D's removal path is the likely one.
  - **Consistency with T29:** the removal leaves "second-fastest of three, a home per attempt", which is T29's judging, but see T30-3 for MR212.
- **D29 annotation and the user's words.** The quote "drop support for 0.11 and the dangling code and tests, since we are still in greenfield area, this is the right time for the clean up." is verbatim in the ledger. It supports the first reading, and the annotation keeps the second as the orchestrator's.
- **The question's wording** "Say if you meant to keep 0.11 working untested" is the orchestrator's own, and **UNVERIFIABLE**: the ledger records the user's reply ("as for 4. drop support …") but not item 4's text.
- **Code identity.** `git diff --stat d1b9225 5db771e -- . ':!knowledge-vault'` prints nothing.
- **The task row** is verbatim in the brief (byte comparison with plan note line 157).

### Mutants V1–V4, applied literally to this worktree (`5db771e`'s code), only the named files, on 0.12.5

Unmutated: `test_entry.lua` 47/`Fails (0)` (67 s); `test_claude.lua` 73/`Fails (0)` (158 s); `test_mcp_delivery.lua` 26/`Fails (0)` (2 s).

| id | literal edit | file run | result | cause |
|---|---|---|---|---|
| V1 | `plugin/aineo.lua`: delete the line `'^Lua: ',` from `ERROR_FRAMING` | `tests/test_entry.lua` | **killed**, `Fails (5)`, by assertion | `left = 'aineo: Lua: nvim_exec2()[1]..TermOpen Autocommands …', right = 'aineo: nvim_exec2()[1]..TermOpen Autocommands …'`. The five cases are the four TermOpen cases and the BufFilePre one under *:Aineo open* (`brief-run-v1-entry.log`) |
| V1 | same | `tests/test_claude.lua` | survives, 73/`Fails (0)` | `test_claude.lua` holds no case for it; `test_entry.lua` kills it, which the brief allows ("or") |
| V2 | `lua/aineo/mcp/editor.lua`: delete the line `'^Lua: ',` from `ERROR_FRAMING` | `tests/test_mcp_delivery.lua` | **killed**, `Fails (8)`, by assertion | among them the framing case's `{ "Lua: " }` row: `left = "the editor did not take the report: Lua: aineo.report has no environment …", right = "… aineo.report has no environment …"` (`brief-run-v2-mcp.log`) |
| V3 | `tests/test_claude.lua:55`: `if vim.fn.has('nvim-0.12') == 0 then` → `if true then` | `tests/test_claude.lua` | **killed**, `Fails (1)`, by assertion | *session_status() leaves the terminal showing Neovim’s exit line*: "Failed expectation for a string containing a part … Part: "[Process exited 3]"", `tests/test_claude.lua:412` (`brief-run-v3-claude.log`) |
| V4 | `tests/helpers/timed_attempts.lua`: `local STARTS_FOR_A_COMPILING_CHILD = 5` → `= 1` | `tests/test_timed_attempts.lua` | **killed**, `Fails (2)`, by assertion | `:188`: `different values at key "compiled", left = "3.0 s", right = "within the limit"`; `:202`: `different values at key branch 2->1, left = 1, right = 5` (`brief-run-v4-timed.log`) |

Summary: 4 of 4 killed by assertion on files that exist today. Each was restored with `git checkout --`, and the tree is clean.

### Other probes run for this review (0.12.5)

| probe | result |
|---|---|
| D20 check in the wave plan (`brief-probe-U.out`) | `u` brings back text removed by `nvim_buf_set_lines()` (whole buffer) and by `nvim_buf_set_text()` (a selection): holds |

---

## Both briefs

- **Every pin that counts what a packet changes is inside its boundary?**
  - **T24:** yes. `test_plugin`, `test_entry`, `helpers/entry`, `test_entry_prefix`, `test_health` (with T24-8's three positional pins) and `test_doc` are in the boundary. `helpers/health.lua`'s parsers are generic (`'^%- ✅ OK (%S+) runs '`).
  - **T30:** no test counts the suite. The case name is outside the boundary (T30-4).
- **Every document the change makes false is named?**
  - **T24:** T24-7. The project note is the knowledge pass's.
  - **T30:** MR212 is not named (T30-3). The project note's three threads are named. Its `:5` and `:114` are already false (T30-8).
- **Does anything a brief forbids contradict its task?**
  - **T24:** the plugin helper for PD4 (T24-1); and the report home, which PD3 does not need if built as T24-2 says.
  - **T30:** `health.lua` (T30-2), the case name and the evidence file (T30-4).
- **Session notes and scratch prefixes.** `2026-10-05 — T24 Panes.md` and `… — T30 Drop Neovim 0.11.md` are both free (`ls knowledge-vault/Sessions/`) and distinct. The scratch prefixes `t24-` and `t30-` are distinct. Branches `feature/t24-panes` and `refactor/t30-drop-nvim-011` do not exist on the remote.
  - T30's resource `impl_t30_drop_011` and its branch slug `t30-drop-nvim-011` differ. That is harmless: `prepare-worktree.sh` accepts it.

### The six rules, recomputed from the briefs on 2026-10-05

Open pull requests: #103 only (`gh pr list --state open`), whose six files are all under `knowledge-vault/`. #102 is closed. Waves: 00001–00006 `landed`, 00007 `claimed` by this orchestrator's session. T25 and T26 have no brief.

| rule | T24 | T30 |
|---|---|---|
| 1 dependencies | T12 done, PR #84 merged 2026-09-28 ✓ | T24 (rule 2) — ✗ until T24 merges, as the plan gates it |
| 2 files | `lua/aineo/layout/`; `plugin/aineo.lua` (tables, `:Aineo`, plus the helper T24-1 asks for); `lua/aineo/health.lua` (`PREFIX_KEYS`); `doc/aineo.txt` (sections 1, 3, 4, 5, 10); new `tests/test_*panes*.lua`; the six pin files. No open packet shares any ✓ | `plugin/aineo.lua` and `tests/test_entry.lua` are shared with T24, and with T30-2's correction `lua/aineo/health.lua` too: after T24 ✓. The others belong to no open packet ✓ |
| 3 schema | none ✓ | none ✓ |
| 4 dependency change | none (the mini.nvim pin is unchanged) ✓ | none ✓ |
| 5 undecided decision | PD1–PD6 answered ✓. Open behaviours that need the orchestrator's readings first: T24-2 (PD3 with no arrival), T24-4 (a partially closed right column) | D29's minimum is the user's ✓. MR212's clause goes with D's removal, so tell the user (T30-3). The review allocation is not the user's (T30-6) |
| 6 task lines | the T24 row (plan note :151) holds its mark ✓ | the T30 row (:157), added by #103, holds its mark ✓ |

### The slots of `prompts/packet-brief.md`

| slot | T24 | T30 |
|---|---|---|
| role line | ✓ | ✓ |
| Objective: task verbatim | ✓ (byte-identical) | ✓ (byte-identical) |
| They rest on | ✓ | ✓ (D29, D10) |
| Facts, checked against `origin/dev` | ✓ (labelled `d1b9225`; T24-9) | ✓ in substance, as *What to clean, found with grep … on `5db771e`* |
| Baseline, with its evidence file | ✓ | ✓, but its instruction to run is wrong (T30-4) |
| Read first | ✓ | ✓ |
| Branch | ✓ | ✓ (`refactor/`, as the root `CLAUDE.md` allows) |
| Class | ✓ regular | ✓ regular (reviews: T30-6) |
| Model | ✓ | ✓ |
| Resources | ✓ `impl_t24_panes` | ✓ `impl_t30_drop_011` |
| You may touch | ✓ (T24-1) | ✓ (T30-2, T30-4) |
| You must not touch | ✓ | ✓ |
| Section exception | none, omitted ✓ | none, omitted ✓ |
| Session note, exact name | ✓ | **placeholder date** (T30-7) |
| Scratch prefix | ✓ `t24-` | ✓ `t30-` |
| What was decided already | ✓ | ✓ |
| Budget | ✓ | ✓ |
| Report | ✓ | ✓ |

---

## Verdicts

- **T24: dispatch after these corrections.** T24-1 to T24-5 change what gets built or how it is pinned. T24-6 to T24-9 are records. The most important is T24-1: a pane door that opens the layout must hand Input to the draft home, and the boundary must allow the helper that does it.
- **T30: dispatch after these corrections.** T30-1 to T30-5 change what the implementer does. T30-6 to T30-8 are records. The most important is T30-1: the measured 0.12.5 outcome for an unenterable `cwd` (the job starts and exits 122) is in neither branch, and it leads to a change the user would see.

For the other dimensions: nothing beyond the records items above, which a records review of #103 would also find.

## Cleanup

- **The tree:** `git status --short` prints nothing. Every mutant was restored with `git checkout --`, and the worktree is at `850c86f`, detached.
- **Processes:** every probe child was stopped by its own pid. The embedded RPC children were stopped with `jobstop` and `jobwait`, and the terminal jobs with `jobstop`. `pgrep -fl agent-ac53ba0be8246bd98`, `pgrep -fl "yes flood"`, `pgrep -fl "stty size"` and `pgrep -fl "ran in"` print nothing.
- **Shared state:** `.tests/homes/` is empty after the runs. Scratch homes (`brief-home/`), probe directories and `deps/` (mini.nvim at its pin, fetched by `make deps`) lie inside this worktree, which is discarded.
- **Resources:** `prepare-worktree.sh review_brief_t24_t30` printed `AGENT_RESOURCE=review_brief_t24_t30` and created nothing (`prepare_project` is empty), so there is nothing to release.
