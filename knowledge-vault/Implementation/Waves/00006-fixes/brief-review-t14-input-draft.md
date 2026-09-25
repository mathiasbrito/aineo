# Brief review: T14, Input draft (PR #32, `knowledge/wave6-t14-input-draft` at `091be6b`)

*Verbatim but for paths, which are replaced by their roles. Every finding is answered in the corrected brief; the orchestrator decided findings 1 and 2 as readings (a pending change only at quit; the draft empties at once; a restore only into a new or emptied Input).*

**Reviewer:** `reviewer`, brief dimension, Opus 5.5.
**Where:** detached at `091be6b`. That commit's parent is `d35dc4f`, which is `origin/dev`, and it changes `knowledge-vault/` only. Every code fact below was therefore read at `d35dc4f`.
**Resources:** `review_brief_t14`. `prepare-worktree.sh` printed `AGENT_RESOURCE=review_brief_t14` and created nothing. `make deps` was run in this worktree.
**Instruments:**
- the host's `nvim`, `/opt/homebrew/bin/nvim`, 0.12.5;
- `<builds>/nvim-0.11.6/nvim-macos-arm64/bin/nvim`, 0.11.6, run through the `env PATH=… make` form the brief gives.

Probes live in this worktree's `.claude/local/orchestrator/brief-t14-probe/`, and merge files in `…/brief-t14-merge/`. I never ran `claude`.
**Open packets:**
- T9: PR #30, head `40bc378`;
- T13: PR #31, head `84fb0e1`.

**Labels** (the `brief` block):
- **CONFIRMED:** a statement in the brief is false or misleading, shown by the check given.
- **REFUTED:** I tried to fault the statement and could not.
- **MISSING:** a slot, a boundary item, a behaviour or a rule is not met.
- **UNVERIFIABLE:** as the charter defines it.

---

## Findings, most severe first

### 1. CONFIRMED: ID2's quit save, as worded, breaks ID6's "the last change wins" and ID4's "restores nothing"

ID2 says: "Quitting saves the draft, whatever the delay's state." That is a write of Input's text at every quit. D17 and ID6 say two editors share one draft and "the last change wins". The two cannot both hold.

**Scenario A: two editors.**
1. Editor A has "alpha", saved.
2. Editor B opens in the same folder and restores "alpha" (ID3).
3. B's user replaces it with "beta", saved.
4. A quits without having changed anything since. ID2 writes "alpha".
5. The last change was B's, but the draft says "alpha".

**Scenario B: a sent text comes back.**
1. A and B both show "alpha".
2. A sends it. Input and the draft are cleared (ID4).
3. B quits. ID2 writes "alpha" back.
4. The next start restores a message that was already sent.

**Scenario C: `:bdelete` in Input.** Measured with `brief-t14-probe/bdelete.lua` on 0.12.5 and 0.11.6, using a buffer made as `make_scratch()` makes Input:
- after `:bdelete`, the buffer is `valid=true loaded=false`, its lines are `{}`;
- `on_lines=0` and `on_detach=true`: its text is dropped without a change event;
- shown again, its lines are `{ "" }`.

A quit that then writes Input's text writes an empty draft. So the text saved earlier is lost at quit: the loss D17 exists to prevent.

**ID6 as worded cannot be seen red first.** Its natural test, "A saves, then B saves, and B's text is read back", is green as soon as ID1 exists. It turns red only against a quit that rewrites.

**Correction.** Replace ID2 with:

> "At quit, a change not yet saved (the delay still running) is saved. A quit with nothing unsaved writes nothing."

- Restoring the draft into Input (ID3) is not a change: it schedules no save. Otherwise B's restore can overwrite a change A made during the delay.
- Give ID6 the red test: two editors, where the one with the older change quits last. The draft still holds the newer change.
- Give ID2 a second test: `:bdelete` Input, then quit. The draft keeps its text.
- Record this as the orchestrator's reading of D17 for the MVP review. D17's "last change winning" supports it.
- Plan mutant: "the quit writes Input's text with no change pending".

### 2. MISSING: ID3's restore can meet an Input emptied within the save delay, and bring sent text back

ID3 restores the draft "when aineo opens its layout … and Input is empty", on "every way the layout opens". Two things combine:
- `open()` calls `layout.open()` at every `\o` (`plugin/aineo.lua:131–134`), and `M.open` "restores the layout while it is open" (`layout/init.lua:589–594`);
- ID1's save is delayed.

**Scenario:**
1. The user types "hello" and presses `\s`.
2. Send empties Input (`send/init.lua:118`). The draft file still holds "hello" until the delay passes.
3. The user presses `\o` within the delay.
4. Input is empty, so "hello" is restored into it and saved again as the draft.
5. A second `\s` sends it twice.

The same happens if the user empties Input with `ggdG` and presses `\o`. It also happens with `\c` or `\i`, if the hand-off runs after every focus rather than only when the layout opened (finding 3).

This is a behaviour D17 leaves open (rule 5). **Correction:** decide it as a reading, one of:
- **(a)** an Input that becomes empty empties the draft at once, with no delay; a non-empty change is saved after the delay;
- **(b)** the draft is restored only when it is handed an Input it has not seen, or one whose text was dropped without a change: the first open, or after a wipe or `:bdelete`.

Then:
- add to ID4 a test: `\s`, then at once `\o`, and Input stays empty;
- add the plan mutant "the draft restored at every open, whatever the pending save".

### 3. MISSING: ID3's focus path, where the hand-off must happen, and no test or mutant for it

- **Where the hand-off can go.** On the first open, Input does not exist while `arrangement()` runs: it is made later, in `build()` → `take_input_buffer(shown)` (`layout/init.lua:469`). So Input can be handed over only after `require('aineo.layout').open()` or `.focus()` returns.
- **What `focus()` cannot see.** `focus()` (`plugin/aineo.lua:143–148`) cannot tell whether the layout opened. `layout.focus` calls the arrangement callback only when the role's window is missing (`layout/init.lua:641–646`). So the composition root learns it only by marking the callback it passes.
- **The test boundary covers only two paths.** The brief allows new `tests/test_entry_*.lua` "for the path through `:Aineo open` and the autostart". It names no test for `\r`, `\i`, `\c`, `:Aineo report|input|claude` or their `<Plug>` mappings.
- **Scenario:**
  1. `autostart = false`, and the user's first action is `\i`.
  2. The layout opens through `focus()`.
  3. If the hand-off was wired after `layout.open` in `open()` only, the draft is neither restored nor saved.
  4. Quitting then loses the text: the problem this packet fixes.
- **Correction:**
  - say that Input is handed over after both `open()` and `focus()`, and in `focus()` only when its callback ran;
  - add an ID3 test through `\i` (or `:Aineo input`) on a fresh start;
  - add the plan mutant "the hand-off only in `open()`".

### 4. MISSING: ID4's test must send from another window and read the draft before any quit

I measured with `brief-t14-probe/textchanged.lua` on 0.12.5 and 0.11.6, in the same run on each. An API change to a buffer that is not current:
- gives `TextChanged=0 on_lines=1`;
- the control, the same buffer current, gives `TextChanged=1 on_lines=1`.

`\s` is a global mapping, so Send can empty Input from the Claude window, the Report or the file column.

**Scenario:**
1. The draft tracks `TextChanged*`, and the user sends from the file column.
2. The draft keeps the sent text until Input is next entered, or until the quit save.
3. A crash first, which D17's "survives a crash too" covers, restores the sent message.

A test that quits before reading the file passes against this mutant, because the quit save writes the empty Input.

- **The existing Send helper does not reach the draft.** `tests/helpers/send.lua:43–49` and `:69` open the layout with `require('aineo.layout').open` directly. That bypasses `plugin/aineo.lua`, so the draft is never handed Input. The ID4 test must open through `:Aineo open`. `tests/helpers/` is outside the boundary.
- **Correction:** ID4's test sends with Input not current and reads the draft after the delay, before any quit. Add the plan mutant "changes seen through `TextChanged` only". The mechanism stays the implementer's; the brief gives the measured fact.

### 5. MISSING: the quit path beside aineo's own `VimLeavePre` stop

The brief says nothing about the handler already on this path. I measured and read the following.

- **Order flips.** `aineo.claude`'s stop is a `VimLeavePre` handler registered when a session starts (`claude/init.lua:51–63`), so before the layout opens. It is registered again, and so moved last, when a new session starts after the last one exited (`nvim_create_augroup('aineo.claude', {})` clears the group). `brief-t14-probe/leave.lua` on 0.12.5:
  - first session: `claude-stop`, then `draft-save`;
  - after a second session starts: `draft-save`, then `claude-stop`.
- **The stop blocks.** It blocks up to 11.8 s (`claude/stop.lua:63–64`) before any handler after it runs. A draft quit save registered after it runs only once the stop has finished.
- **A Lua error does not skip later handlers.** With `DRAFT_RAISES=1`, `claude-stop` still ran after the draft handler raised, on both versions.
- **An uncaught exception does skip them.** A Vimscript `throw` in an earlier handler skipped both later handlers on 0.12.5 and on 0.11.6: the probe file was never written.
  - The T8 session note (*Left open*) already records this narrower fact: "only an Ex-command autocommand's uncaught `throw` skipped a later handler".
  - So the limit the help states for the stop (`doc/aineo.txt:378–381`, `health.lua:496`) applies to a `VimLeavePre` draft save too, in its measured form. Only the delayed save then holds.
- **An error at exit holds Neovim at a prompt.** `getout()` waits at a hit-enter prompt when an error was given during exit. It is `if (did_emsg) … wait_return(false)` at `src/nvim/main.c:855–859` in v0.12.5 and `:797–801` in v0.11.6, read from the tags' raw source.
  - A quit handler that raises, or notifies at `ERROR` (`vim.notify` passes `err = level == ERROR`), stops the quit until a key is pressed.
  - A headless test never shows that prompt.
  - `WARN` does not set the error.
- **`BufUnload` comes first.** `BufUnload` fires for every loaded buffer before `VimLeavePre`: `main.c:804–812`, then `:824`, in v0.12.5; `:746–754`, then `:766`, in v0.11.6. It is a hook that does not depend on the order of `VimLeavePre` handlers.
- **ID7 and the open path.** ID7 says the draft "never raises into the user's typing". A read failure raised inside `open()` would reach `run()` instead:
  - `run()` reports it at `ERROR` (`plugin/aineo.lua:195–203`);
  - on the autostart, the start is recorded as `open-failed` (`:353–358`) although the layout opened.

**Correction:**
- Give these facts in the brief.
- ID7: the draft never raises — not from its quit handler, not out of `open()` or `focus()` — and its warning is `WARN`.
- Name the limit. An earlier quit handler that throws skips the quit save. Say where it is documented: inside the `*aineo-layout*` fence, or widen the boundary to `*aineo-limits*`. `health.lua:496` lists the stop's limit, and `health.lua` is forbidden here.

### 6. CONFIRMED: ID8 cannot be seen red first. It is an invariant the frozen pins already hold (the first brief review's finding 13)

- The heading says "one test each, each seen red first". On `dev` no draft module exists, so a new ID8 test is green before any code.
- **Measured.** I made a stand-in `lua/aineo/draft/init.lua` and ran two mutants against `make test_file FILE=tests/test_plugin.lua` (4 cases).
  - **Mutant 1:** `require('aineo.draft')` added under `vim.g.loaded_aineo = true` in `plugin/aineo.lua`. It fails 2 of 4, each by assertion:
    - *is sourced at startup and loads no aineo module*: `Left: { "aineo.draft" }` against `Right: {}`;
    - *loads the configuration alone in a headless start*: `Left: { "aineo.config", "aineo.draft" }` against `Right: { "aineo.config" }`.
  - **Mutant 2:** `vim.api.nvim_create_autocmd('VimLeavePre', { group = vim.api.nvim_create_augroup('aineo.draft', {}), callback = function() end })` added at the same place. It fails *defines :Aineo, … the StdinReadPost autocommand alone*: `left = "aineo.draft VimLeavePre", right = nil`.
  - Both files are restored.
- **Correction:** label ID8 an invariant, as RC7 is. Name `tests/test_plugin.lua` lines 16–21, 23–27 and 62–84 as the tests that kill the plan mutant "the draft home loaded at startup". Drop "one test" for it.
- ID6 is fixed by finding 1.

### 7. MISSING: ID5 and ID6 point at `records_file()` for the path only. The same file holds the three measured patterns the draft needs

`lua/aineo/report/records.lua` has:
- a temporary file unique to the editor, `('%s.%d.cut'):format(target, vim.uv.os_getpid())`, renamed over the target, following a symlink through `fs_realpath` (`:99–116`);
- `OWNER_ONLY` (`0600`) on every file it creates (`:13–15`, `:79`), "since a report can quote the user's work". A draft is the user's unsent text verbatim;
- `make_directory()` (`:133–154`), which retries `mkdir()` that another editor raced.

Without them, ID5 and ID6 fail in ways the brief does not name.

- **A shared temporary name.** I interleaved two saves through one temporary name (`brief-t14-probe/shared_temp.lua`, 0.12.5: open, write, second open, rename, write, rename).
  - Between A's rename and B's write, the draft held `""`: neither the previous draft nor the new one. A crash of B there leaves it empty, against ID5.
  - B's rename then failed with `ENOENT`, which gives a spurious ID7 warning, although B's text landed.
- **The default mode.** `writefile()` and `io.open()` create `-rw-r--r--` under umask `022` (measured).
  - This host's `stdpath('state')` is `drwx------`, which hides the draft here.
  - A user's `XDG_STATE_HOME` may not be.
- **Atomicity is only red with a seam.** "A crash mid-write" can be seen red only through an injected write failure: the draft home takes its file writes as a declared dependency, and the test makes one fail after truncating. Nothing else kills the plan mutant "a non-atomic write".

**Correction:**
- ID5 names these three patterns and `0600`.
- ID5 names the test that kills "a non-atomic write".
- Say that under this boundary (`lua/aineo/report/` forbidden, the records internal to that home) the patterns are copied, not shared. That is a DRY question a records reviewer will otherwise raise; name it as a reading.

### 8. MISSING: the new home has no C# row

- The plan note's *Architecture* table maps every home to a component: C1–C10.
- "A new module home, for example `lua/aineo/draft/`" would be the only home in no row, and no row names its specialist.
- **Correction:** fix the home's name (`lua/aineo/draft/`), and either add a C11 row in this PR ("Draft: Input's unsent text kept per working directory (D17) | `lua/aineo/draft/` | `neovim-lua-developer`") or say that the knowledge pass after the merge adds it.

### 9. CONFIRMED: line citations that are off, or will move when T13 merges

- **`give_report_environment()`** "lines 55–69" (brief l.54) is 56–70: docstring 56–57, function 58–70.
- **ID5's "line 57"** is the docstring's second line. The `vim.fn.getcwd()` it means is at `:67`.
- **The fence (l.97):** "Your section is lines 51–86 above" states the fence by line number. Rule 2 says never.
  - On T13's head the section is 52–87 (`grep -n` on `t13.txt`: `3. THE LAYOUT` at 52, the last line at 87).
  - The plan's row says "lines 51–86 against 253–280". After T13 that is 52–87 against 254–281. T9's own branch now spans 253–305.
  - Keep the quoted lines, and drop the numbers or mark them "at `d35dc4f`".
- **Only the help moves when T13 merges.** T13 changes `plugin/aineo.lua` at `:168–172` only (`ERROR_FRAMING` gains one line), below every T14 citation. It does not touch `layout/`, `send/` or `records.lua`. Every other fact holds after T13.

### 10. CONFIRMED and MISSING: the baseline

- **Attributed to the wrong sha.** The plan's T14 section says "Baseline: `dev` at `d35dc4f`", then cites `evidence/baseline-0.11.6.txt` and `baseline-0.12.5.txt`. Both headers say "at dev 9af91a6".
  - The code is identical: `git diff --stat 9af91a6 d35dc4f -- lua plugin tests scripts doc Makefile` prints nothing. So the figures carry over.
  - The 0.12.5 figure omits "727 cases", and was measured with the downloaded v0.12.5 build first on `PATH`.
  - **Correction:** "measured at `9af91a6` (code identical at `d35dc4f`): 0.11.6 727 / `Fails (0)`; downloaded 0.12.5 727 / `Fails (8)`".
- **MISSING: the brief's *Baseline* slot has no counts and no evidence file.** The template asks for both. It defers to T13's merge, which is right. But "every fact above" does not reach the *Baseline* slot or the boundary's line numbers. Say that the dated amendment pastes T13's merge counts with their evidence file and re-checks the fence lines.
- **My re-measure** at `091be6b`, whose code is `d35dc4f`'s: 0.11.6 gives 727 cases, `Fails (0)`, rc 0. The host's 0.12.5 gives 727, `Fails (8)`, rc 2, the same eight. The figures hold at `d35dc4f`.

### 11. MISSING: no evidence file for the measured problem

- The brief cites a measurement, and `Waves/CLAUDE.md:16` puts the measurements briefs cite under `evidence/`. None was added.
- **I re-measured it: it holds.**
  - 0.12.5: the `nofile` command exited 0.
  - 0.11.6: the `nofile` command exited 0.
  - The normal buffer gave `E37: No write since last change`, then `E162`, on both, in a run ended by `-c 'cquit 3'` (exit 3). As written, with `-c 'qa'` alone, that normal-buffer command does not exit.
- **Correction:** add `evidence/t14-nofile-quit.txt` with both commands, the `cquit` fallback and both versions' output.

### 12. MISSING: how to test the help on the merged file

- The brief orders `git merge-tree --write-tree <your head> <branch>`, then `test_doc.lua` "on the merged file". It gives no step from the printed tree id to a file in the worktree.
- **Measured under this worktree's guard:**
  - `git merge-tree --write-tree origin/bugfix/t13-neovim-0-12 origin/bugfix/t9-report-colours` printed `9696adb…`;
  - `git show <ref>:doc/aineo.txt > <file>` ran as a plain command;
  - `git checkout HEAD -- doc/aineo.txt` restores the file.
- **Correction:** give those three steps, and "exit 0 and no conflict listed means clean", as T12's brief does.

### 13. CONFIRMED (cosmetic): the last fence line's quoting breaks in rendering

- Brief l.84 quotes ``lives in one tab; from another tab, `\o` moves you to it.`` in single backticks, around a line that holds backticks. Rendered, the code span ends at `\o`.
- The raw bytes do match `doc/aineo.txt:86`.
- **Correction:** use double backticks, as the first brief review wrote T13's last line.

### 14. MISSING (low): two criteria cannot be graded

- **ID2, "never … noticeably slows a quit",** has no bound. When Claude runs, aineo's own stop already holds the quit up to 11.8 s. Give a bound, such as one synchronous write of the text, or drop the clause.
- **ID7, "one warning",** does not say one per failure or one per editor. With an unwritable state directory, a save after each pause in typing would warn every time. Say "once, until a save succeeds", or whichever is meant.

### 15. MISSING (records): what the PR leaves for later

- The plan's T14 section names `brief-review-t14-input-draft.md`, which is not in the PR at `091be6b`. It lands with the corrections.
- T12's brief l.68 says "You are dispatched after T13 merges". Its baseline becomes T14's merge.
- T14 inserts lines between `plugin/aineo.lua:53` and `:148`. That moves every `plugin/aineo.lua` line T12 cites: 152, 195, 220, 247 and 437. T12's dated amendment re-checks them. The plan's line "T12, dispatched after T13's merge", not editable under the folder rule, is superseded by the T14 section's "Order".

### 16. UNVERIFIABLE: the user's words

- The brief quotes "Unsent Input is lost", "completly undesired behavior" and the offered option's text. None of them is recorded outside this PR.
- The quotes are consistent across D17, the plan section, the brief and the commit. The PR body and commit paraphrase "completely undesired" without quotation marks.

---

## REFUTED: what I checked that held

**The measured problem.** A `nofile` buffer holding text quits silently, exit 0. A normal buffer gives E37. This holds on 0.12.5 and 0.11.6 (finding 11).

**Facts at `d35dc4f`.**
- `layout/init.lua`: `make_scratch()` docstring from 353, `buftype = 'nofile'` at 358, then `bufhidden = 'hide'`, `buflisted = false` and `swapfile = false` (357–362); `take_input_buffer()` at 399–411 makes `shown` Input when it is unnamed, empty and not wiped once hidden; `M.input_buffer()` at 653.
- `plugin/aineo.lua`: `open()` at 131; `focus()` at 143 goes through `arrangement()` (118–125), which calls `give_report_environment()` (119); the environment is given once, with `state_directory = stdpath('state')` and `working_directory = getcwd()`.
- `send/init.lua`: it clears Input at 118 and puts it back at 121.
- `records.lua`: `records_file()` at 30 builds `<state>/aineo/reports/<sha256>.jsonl`.
- The task row in the brief is byte-identical to the plan note's T14 row. D17's row says what the brief says.
- C4 says "then Input cleared". C6 says "persisted under `stdpath('state')`". C2 does not say "scratch", but the code and the help do; that is a gloss, not an error.

**The boundary: the draft works without touching `lua/aineo/layout/`.**
- It learns Input's buffer from the public `input_buffer()`, which Send already uses (`send/init.lua:47`). That value can be a wiped buffer, which Send guards with `nvim_buf_is_valid`.
- It learns Input's changes from `nvim_buf_attach`'s `on_lines`, which fires for an API change to a buffer that is not current (measured, finding 4).
- Everything the hand-off needs is in `plugin/aineo.lua` (finding 3):
  - handing Input over again after a wipe, since Input is made anew then (`layout/init.lua:586`);
  - attaching again after `:bdelete`, which fires `on_detach` (measured);
  - marking `focus()`'s callback.
- The spec-conflict clause is sound. I found nothing that needs the layout.

**ID3's paths.**
- `plugin/aineo.lua` is the only production caller of `layout.open` or `layout.focus`: lines 133 and 145 (`git grep`).
- The autostart reaches `open()` (`run(open)`, 353). `\o`, `:Aineo open` and `<Plug>(aineo-open)` reach `open()`. `\r`, `\i`, `\c`, `:Aineo report|input|claude` and their `<Plug>` mappings reach `focus()`.
- `\s` opens nothing.
- So every path is covered once both sites hand Input over (finding 3).

**ID4 without the Send home.** Send changes Input only through `nvim_buf_set_lines` (118, 121), and `on_lines` sees both calls, including a restore after a failed write. No change to `lua/aineo/send/` is needed.

**ID5's working directory.**
- The Reports' key is `getcwd()` at the first `arrangement()` call, which is the first time the layout opens. The help says so at 278–280.
- `give_report_environment()` has no other caller.
- "Keyed by the same working directory the Reports use … taken the first time" is consistent. A draft given its environment in the same call gets the same value.
- The help should say it as the Report's paragraph does: the first open's directory, for the editor's life.

**The frozen pins.** `tests/test_plugin.lua` kills both startup mutants by assertion (finding 6). No other suite pins an exact module list after the layout opens: `test_health.lua:71` pins only the check's own loads. No suite counts `VimLeavePre` handlers, or reads `nvim_get_autocmds({})` after startup. `test_entry_report.lua:83,108` glob only `*.jsonl`, so the suggested `.txt` name matters.

**The help fence.**
- The quoted first line is byte-identical to `doc/aineo.txt:51` (`cmp`). The last line's raw bytes match line 86.
- I built a T14 edit at both edges of the section: a changed Input bullet at 66–67, and a `*aineo-draft*` paragraph appended after 86 (`brief-t14-merge/t14.txt`).
- `git merge-file` results:
  - T14 × T9's head `40bc378`: exit 0, no conflict markers;
  - T14 × T13's head `84fb0e1`: exit 0, no markers;
  - all three: exit 0, no markers, each packet's text present (`*aineo-draft*` at 90, `hl-AineoReportTime` at 297, the version line at 39).
- `make test_file FILE=tests/test_doc.lua` results, the file restored afterwards (`git status` clean):
  - on T14 × T9, on 0.12.5: 36 cases, `Fails (0)`;
  - on all three, on 0.11.6: 36, `Fails (0)`;
  - on all three, on 0.12.5: 36, `Fails (0)`.
- T9 adds six `hl-AineoReport*` tags, and a T14 `*aineo-draft*` is disjoint from them, so there is no E154.
- T12's section begins at 89. T14's append lands after the blank line 87, so line 88, the `===` rule, separates them. They are sequential in any case.

**Bookkeeping.**
- The session-note name is free on `dev` and distinct from T9's, T12's and T13's.
- `feature/t14-input-draft` has no remote branch. `lua/aineo/draft` and `aineo.draft` appear nowhere on `dev`.
- The scratch prefix `t14-` is distinct. `impl_t14_input_draft` is a valid resource name.
- The branch prefix fits a new behaviour. The model is `opus`, the class is regular, and the budget and report path are stated.
- The 0.11.6 `env PATH=… make` form runs under the guard: I used it.
- The wave is `claimed` by this orchestrator's session. The T14 section sits directly above `## Landed`, and nothing else in the folder was edited.
- T14 is the next free T#, `active`.

---

## Mutants

| mutant (literal edit) | where | expected killer | result |
|---|---|---|---|
| `require('aineo.draft')` after `vim.g.loaded_aineo = true`, with a stand-in `lua/aineo/draft/init.lua` returning `{}` | `plugin/aineo.lua:24` | `test_plugin.lua:20`, `:26` | killed, 2 of 4, assertion (`{ "aineo.draft" }` against `{}`; `{ "aineo.config", "aineo.draft" }` against `{ "aineo.config" }`) |
| `vim.api.nvim_create_autocmd('VimLeavePre', { group = vim.api.nvim_create_augroup('aineo.draft', {}), callback = function() end })` at the same place | `plugin/aineo.lua:24` | `test_plugin.lua:68` | killed, 1 of 4, assertion (`autocmds`→2 = `"aineo.draft VimLeavePre"` against `nil`) |

The other plan mutants target code that does not exist yet. What each needs:
- **"Delayed save dropped", "quit save dropped", "restored over text", "written in the working directory".** Killable by ID1, ID2, the second bullet of ID3, and ID5, as worded.
- **"Not cleared when Send clears Input".** Survives an ID4 test that quits before reading the draft (finding 4).
- **"A non-atomic write".** Needs an injected write failure (finding 7).
- **"Loaded at startup".** Killed by the existing pins (above).
- **Missing from the plan:** the quit rewrites with nothing pending (finding 1); restore at every open (2); the hand-off only in `open()` (3); `TextChanged` only (4); a shared temporary name, and `0644` (7).

Summary: 2 mutants run, 2 killed by assertion. 7 plan mutants examined: 1 killed by existing pins, 1 survives the natural test, 1 needs a seam the brief does not name. 6 missing mutants named.

---

## Suite (re-measure of the base)

Measured at `091be6b`, whose code is identical to `d35dc4f`'s, with `make deps` at the pin:

| Neovim | command | result | output |
|---|---|---|---|
| 0.11.6 (`<builds>` build, through the brief's `env PATH=… make test`) | `make test` | 727 cases, `Fails (0)`, rc 0 | `brief-t14-suite-0116.txt` |
| 0.12.5 (Homebrew, the host's) | `make test` | 727 cases, `Fails (8)`, rc 2 | `brief-t14-suite-0125.txt` |

The eight 0.12.5 failures are the ones T13 fixes:
- `test_claude` 2;
- `test_entry` 1;
- `test_health` 1;
- `test_mcp_blocked_editor` 3;
- `test_mcp_delivery` 1.

So the plan's figures hold at `d35dc4f`. The 0.12.5 figure also holds on the host's build, not only on the downloaded one.

---

## The six rules, recomputed from the briefs for T14

The open packets are T9 (PR #30, `40bc378`) and T13 (PR #31, `84fb0e1`). T12 is planned. Wave 6 is the only claimed wave.

| rule | T14 against the open and planned packets |
|---|---|
| 1 dependencies | T8 done (plan note l.112) ✓. It waits for T13's merge under rule 2 ✓ |
| 2 files | **T13:** `plugin/aineo.lua`, since T13 changes 168–172 and T14 changes around 53–148. This is handled by waiting for T13's merge. The help (T13's `*aineo-install*`) is disjoint. T13's other eight files are none of T14's ✓. **T9:** its seven files are the help, `report/{buffer,colours,init,render}.lua`, `test_report_colours.lua` and its note. Only `doc/aineo.txt` is shared. The fences are quoted, and the synthetic edge edit measured clean, with `test_doc` 36/0 on the merged file on both versions ✓. **T12:** `plugin/aineo.lua`, sequential after T14 ✓. T12's layout, health, `test_plugin.lua` list and entry files are none of T14's ✓. **Registration and counting pins:** none moves. The frozen pins stay unchanged under ID8. No suite counts modules or autocommands after the layout opens, and none globs `*.txt` under the state directory ✓. **One planning gap:** the new home has no C# row (finding 8) |
| 3 schema / shared state | `<state>/aineo/drafts/` is new and T14's alone ✓ |
| 4 dependencies | none; `Makefile` and `scripts/` are forbidden ✓ |
| 5 decisions | D17 is decided. The delay and the file layout are readings ✓. **Two behaviours D17 leaves open are not decided:** what the quit writes (finding 1) and when a restore may run (finding 2) ✗. Correct them as the orchestrator's readings of D17 |
| 6 task lines | T12 at l.114, T13 at l.115, T14 at l.116. T14 is adjacent to T13 (0-line gap) and one line from T12. All hold their marks, and the brief says so ✓ |

---

## Verdict

**brief-t14-input-draft.md: dispatch after corrections.**
- **Required:** findings 1–7.
  - 1 and 2 decide the two open behaviours (rule 5).
  - 3 and 4 close the paths a test would otherwise miss.
  - 5 gives the quit path's measured facts.
  - 6 labels ID8.
  - 7 names the write patterns and `0600`.
- **Before dispatch:** 8–13.
- 14–16 are advisory.

As written, an implementer can satisfy every ID literally and still:
- bring a sent message back, twice over: a quit rewrite, and a restore within the delay;
- open the layout by `\i` with no draft at all.

**plan.md, T14 section:**
- the baseline's attribution (finding 10);
- the line numbers after T13 (finding 9);
- rule 5's two readings;
- the missing plan mutants (the *Mutants* section above).

**The single most important change:** replace ID2's "saves the draft whatever the delay's state" with "saves a change not yet saved". Decide ID3's restore trigger against the save delay. Both are readings of D17's own "last change winning".

## Other dimensions

- **records (PR #32):**
  - the plan names `brief-review-t14-input-draft.md` before it exists;
  - the baseline cites evidence from `9af91a6` as `d35dc4f`'s;
  - no evidence file for the `nofile` measurement;
  - no C# row for the new home.
- **attack (T14, later):**
  - `:bdelete` in Input, then quit;
  - `\s`, then at once `\o` or `\c`;
  - two editors in one folder, the older one quitting last;
  - a Vimscript `throw` in a user `VimLeavePre` before aineo's;
  - an unwritable `<state>/aineo/drafts`.
- **test-integrity (T14, later):**
  - an ID4 test that quits before reading the draft passes against a `TextChanged`-only draft;
  - an ID6 test that never makes the older change quit last passes against a quit that rewrites.

## Cleanup

- **Resources.** `prepare-worktree.sh review_brief_t14` printed `AGENT_RESOURCE=review_brief_t14` and created nothing, so there is nothing to release.
- **Processes.** `pgrep -fl agent-a43882987b79ea2f6` printed nothing (rc 1). Both suite runs exited on their own (rc 0 and rc 2).
- **Worktree.**
  - Restored with `git checkout HEAD -- doc/aineo.txt` and `git checkout HEAD -- plugin/aineo.lua`.
  - The stand-in `lua/aineo/draft/` was removed.
  - `git status --short` prints nothing.
  - The worktree stays detached at `091be6b` and is left in place.
- **The developer's state.** Nothing was written there. The probes ran `nvim --clean -i NONE -n`. `~/.local/state/nvim` shows no change after 18:22, which is before this review. Its permissions were read with `stat` only.
- **Files I wrote.** All are in this worktree's gitignored `.claude/local/orchestrator/`, prefixed `brief-t14-`:
  - `-deps`, `-doc-*`, `-mutant-*`, `-row-*` and `-suite-*` outputs;
  - `brief-t14-merge/`, with the help versions and merges;
  - `brief-t14-probe/`, with `leave.lua`, `textchanged.lua`, `bdelete.lua` and `shared_temp.lua`, their outputs, and `main-0.12.5.c` and `main-0.11.6.c` fetched with `gh api`;
  - this report.
