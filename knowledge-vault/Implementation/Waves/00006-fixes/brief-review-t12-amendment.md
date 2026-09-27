# Brief review — T12's amendment of 2026-09-27 (PR #80)

- **Subject:** `knowledge-vault/Implementation/Waves/00006-fixes/brief-t12-claude-numbers.md`, head `4dc8f85` (`origin/knowledge/w6-t12-amend`), the brief above the amendment included.
- **Facts checked on:** the tree `acc62d0`. `git merge-tree --write-tree origin/dev 6d5a013` and the same against `origin/feature/t19-claude-resume` both print `acc62d03b6751229f0173f16e74cdbd0fd8a3f10`. `git diff 6d5a013 acc62d0 -- lua plugin tests doc scripts Makefile` is empty, so the amendment's "whose code is PR #73's head's" holds. The tree was extracted with `git archive acc62d0` into the scratchpad, `brief-acc/`, and the probes ran there.
- **Builds:** 0.12.5 is `/opt/homebrew/bin/nvim` and 0.11.6 is `<builds>/nvim-0.11.6/nvim-macos-arm64/bin/nvim`. Every probe ran under `--clean --headless` with the XDG directories and `NVIM_LOG_FILE` set inside this worktree's `.tests/`.
- **What the labels mean** (the `brief` block of `reviewer-brief.md`): **CONFIRMED** means the statement is false or misleading, and the finding gives the check that shows it. **REFUTED** means I tried to fault the statement and could not. **MISSING** means a slot, a boundary item or a rule is not met. **UNVERIFIABLE** means I could not check it, and the finding says why.
- **Brief lines:** "line N" means a line of the brief file at `4dc8f85`. Lines 134–199 are the amendment.

## Findings, most severe first

### 1. CONFIRMED (rule 5): CN9's premise is wrong, and its pin cannot tell the two behaviours apart (lines 171–177)

The amendment says the user's own `TermOpen` autocommands, "a common `setlocal nonumber` among them, run for each new terminal", and "a new terminal may undo it". It asks for two pins, one with no `TermOpen` autocommand and one with `autocmd TermOpen * setlocal nonumber norelativenumber`.

**What I measured.** The probe is `brief-t12b-cn9.lua`, run by `brief-t12b-cn9.sh`, with output in `brief-t12b-cn9-run1.txt`. Claude's window was opened by the real `aineo.layout.open()` at `acc62d0`. Each terminal was made as `aineo.claude` makes it: `nvim_create_buf(false, true)`, then `jobstart(…, { term = true })` inside `nvim_buf_call()`. The new terminal was swapped in with a literal copy of `replace_terminal()`, then `follow_claude_terminal()` was called. The user has `set number`. The results were identical on 0.12.5 and 0.11.6:

| How the toggle set the option | User `TermOpen` autocommand | After open | After `\tcn` | After a new terminal enters |
|---|---|---|---|---|
| `vim.wo[win]` (as `:set` does) | none | number=true | number=false | **number=false** (the toggle is kept) |
| `vim.wo[win]` | `setlocal nonumber norelativenumber` | true | false | **false** |
| `vim.wo[win][0]` (as `:setlocal` does) | none | true | false | **true** (the toggle is undone) |
| `vim.wo[win][0]` | `setlocal nonumber norelativenumber` | true | false | **true** |

- **The user's autocommand changes nothing, in any row.** aineo starts every terminal in a hidden buffer through `nvim_buf_call()` (`lua/aineo/claude/init.lua:138`). Its `TermOpen` autocommands therefore run in an autocommand window, which is discarded. This includes Neovim's own `nvim.terminal` handler, which already does `vim.wo[0][0].number = false` and `.relativenumber = false` (`runtime/lua/vim/_core/defaults.lua:738–739` on 0.12.5, `_defaults.lua:625–626` on 0.11.6). So Claude's window shows numbers when the user has `set number` (the "After open" column). It also means that no test can run with "no `TermOpen` autocommand". The two pins CN9 asks for measure the same thing twice.
- **The option scope decides the outcome, and the brief does not choose one.** An implementer who follows the layout's own idiom, `wrap_right_column()` at `lua/aineo/layout/init.lua:193`, which is `vim.wo[win][0]` (T16), gets numbers that come back after T19's fallback or after `\o` restarts Claude Code. An implementer who uses `vim.wo[win]` keeps the numbers hidden, but the toggle then spreads (finding 1a). These are two defensible behaviours, so rule 5 applies: the brief must dispatch one of them.

**1a. What the `:set` form spreads to.** The probe is `brief-t12b-cn9b.lua` › `file`, with output in `brief-t12b-cn9b-run1.txt`. After `\tcn` set with `vim.wo[win]`, I ran `:edit <file>` in Claude's window. The layout's redirect moved the file to the file column, and the file showed **number=false** on both versions, although the user has `set number`. With `vim.wo[win][0]` the file shows number=true. So the `:set` form breaks CN3 for every window opened from Claude's window after the toggle. The amendment's line 161 says CN3 "covers" the file column, but it does not name this case.

**1b. "aineo does not re-apply the toggle" is a behaviour, not a reading.** With the `:setlocal` form, it means that after every restart of Claude Code the user sees the numbers come back. With the `:set` form it means the opposite, plus finding 1a. Either way the user sees it. It goes in *Readings for the MVP review* with its measured outcome, and never as "Neovim keeps its options" or as the doing of a `TermOpen` autocommand.

**Correction.** Replace lines 175–177 with the following, choosing one behaviour or putting the choice to the user:

> aineo starts each terminal in a hidden buffer (`nvim_buf_call()` around `jobstart()`), so no `TermOpen` autocommand reaches Claude's window: not Neovim's own `nvim.terminal` handler, which turns the numbers off, and not a user's `setlocal nonumber` (measured, both versions, brief review 2026-09-27). What Claude's window shows after a new terminal enters depends on how `\tcn` sets its options:
> - **as `:setlocal` does (`vim.wo[win][0]`), as the layout already does for wrap.** The new terminal takes the window's own values again, so the user's numbers return. A file opened from Claude's window keeps the user's numbers.
> - **as `:set` does (`vim.wo[win]`).** The numbers stay hidden, but every buffer that later enters the window, and every file opened from it into the file column, shows them hidden too.
>
> **CN9 — `<the chosen one>`.** Pin it on a new terminal made by the real path: `\o` after the fake exits, or T19's fallback, in `tests/test_entry_claude_numbers.lua`. Also pin that a file opened from Claude's window after `\tcn` shows the user's numbers (CN3). Name the outcome in *Readings for the MVP review*.

My leaning is `vim.wo[win][0]`, with the toggle not re-applied. That is the only form that keeps CN3, and it matches T16. Re-applying the toggle when the terminal changes would take a hook in `follow_claude_terminal()` and in `open()`'s restore, and that is a larger decision.

### 2. CONFIRMED: the `\o` rebuild reading does not describe what Neovim does (line 123, not amended)

The brief's reading is "The rebuilt window takes the user's defaults, unless you find a reason otherwise". The probe is `brief-t12b-cn9b.lua` › `rebuild`: `\tcn`, then close Claude's window, then `layout.open()` again, which runs `reopen_closed_windows()`. With either scope and on both versions, the rebuilt Claude window shows **number=false**. It keeps the hidden numbers, because Neovim gives the new window the options Claude's terminal last had in a window. So "the user's defaults" is not what happens without code that resets them. Such code would go in `reopen_closed_windows()`, and no case asks for it.

The wipe path differs (`brief-t12b-cn9b.lua` › `wiped`). The Claude window is left on an empty buffer after the wipe, then a new terminal enters it. The `:set` form keeps the numbers hidden. The `:setlocal` form shows number=true from the wipe onward.

**Correction.** Replace line 123 with:

> what `\o` does to a toggled window it rebuilds: Neovim gives the rebuilt Claude window the options the terminal last had, so its numbers stay hidden (measured, both versions). State that as the reading, or make the layout reset them and pin it.

Name the wipe path beside it.

### 3. CONFIRMED: CN7's list of `tests/test_health.lua` pins is wrong and incomplete (lines 38, 59, 152–156)

- **The amendment says "The brief's "816–820" no longer exists". That is false.** `tests/test_health.lua` has not changed since `9af91a6`: `git diff --stat 9af91a6 acc62d0 -- tests/test_health.lua` is empty. Lines 816–820 are still the per-key list `'- ⚠️ WARNING ,s is not mapped'` … `,c is not mapped`, in *warn of each key nobody mapped, as after setup() changes the prefix late* (line 809).
- **MISSING, since the original brief: nine index reads.** Nine cases read the leader warning as the section's sixth line, `[6]`, at lines 513, 530, 546, 579, 650, 670, 834, 849 and 860. A sixth key line pushes that warning to `[7]`.
- **Measured.** I changed only the key tables in the scratch tree: `SUBCOMMANDS`, `ACTIONS` gaining a no-op, `PREFIX_KEYS` gaining `['claude-numbers'] = 'tcn'`, and health's record `{ key = 'tcn', subcommand = 'claude-numbers' }`. Then I ran `make test_file FILE=tests/test_health.lua` on 0.12.5 (output in `brief-t12b-tables.txt`). The run gave `Fails (16)` of 78: the 5 lists, the 2 counts and the 9 index reads. The comparison at line 600 and the first-line check at line 741 stayed green.

**Correction.** Replace lines 153–156 with:

> - the per-key lists at lines 499–503, 615–619, 630–634, 758–762 and 816–820 (the file is unchanged since `9af91a6`);
> - the two counts of 5 at lines 562 and 597;
> - nine reads of the leader warning as line `[6]`, which becomes `[7]`: lines 513, 530, 546, 579, 650, 670, 834, 849 and 860;
> - the comparison at line 600, and line 741's check of the first line, stay green. With the key tables alone, 16 of the file's 78 cases fail (brief review, 0.12.5).

Correct CN7's line 38 to match.

### 4. MISSING: CN4 does not say what counts as Claude's window when its terminal was wiped (lines 23–26)

Since T21 (D25, help lines 208–211), a Claude window that Neovim cannot close stays on an empty buffer after a wipe. `state.windows.claude` is still valid in that state. `M.focus()` counts that window as gone: `not vim.api.nvim_buf_is_valid(state.buffers[role])` (`layout/init.lua:822`). CN4's definition is "the layout is closed, or its Claude window was closed", so by CN4 there *is* a Claude window. `\tcn` would then toggle the numbers of a window showing an empty buffer. With the `:setlocal` form, the next terminal resets them anyway (finding 2).

**Correction.** Add to CN4:

> A Claude window left on an empty buffer after its terminal was wiped counts as no Claude window, as `focus()` counts it.

Or add the opposite. Either way, pin it.

### 5. MISSING: nothing tells the implementer not to route the toggle through `open()` or `focus()` (line 178)

The amendment's line 178 reads "CN4b's 'from another tab' is re-measured on them". That gives no instruction. The toggle must not go through `M.open()` or `M.focus()`, for three reasons:
- `open()` switches to the layout's tab (`layout/init.lua:789`), against CN3.
- `open()` rebuilds a closed Claude window, against CN4.
- `focus()` moves the cursor, against CN3.

T14 did not change the layout since `9af91a6`. T16, T21 and T19 did. The sentence holds only of `plugin/aineo.lua`'s local `open()` and `focus()`.

What holds instead, measured by `brief-t12b-cn4b.lua` on both versions: setting `vim.wo[win]` or `vim.wo[win][0]` on `state.windows.claude` from another tab leaves the current tab, window, cursor (2,1) and mode (`n`) as they were. CN4b is therefore buildable directly.

**Correction.** Replace line 178 with:

> The toggle sets the options on the layout's Claude window from any tab, and goes through neither `M.open()`, which moves to the layout's tab and rebuilds closed windows, nor `M.focus()`, which moves the cursor.

### 6. CONFIRMED: "`\o` or `\c` starts Claude Code again after an exit" (line 173) is false

The amendment itself requires, at line 167, that the help's line 213 stay true: "Of the actions, only `open` restarts an exited Claude Code". Line 173 contradicts it. In the code:
- `focus()` calls the arrangement, and so `current_claude_terminal()`, only when the role's window is gone or its buffer was wiped (`plugin/aineo.lua:195–198`, `layout/init.lua:822`).
- An exited terminal is still a valid buffer, so `\c` after an exit only moves the cursor.

**Correction:**

> `\o` restarts an exited Claude Code, its new terminal taking the old one's place in Claude's window; `\c`, `\r` and `\i` start one only once the terminal was wiped, into a Claude window Neovim could not close (help lines 204–215).

### 7. MISSING: fixture names must be unique beside T22 (Boundary, amended)

- `claude_session.fake(name, …)` makes `fixture.directory('claude-' .. name)` (`tests/helpers/claude_session.lua:84`).
- `fixture.directory()` deletes any directory of that name before it makes one (`tests/helpers/fixture.lua:16–22`).
- T22's brief (line 32) keeps every fixture in one shared `.tests/fixtures/`. It relies on no fixture name being used by two files, and it runs files side by side.

A new `tests/test_entry_claude_numbers.lua` modelled on `tests/test_entry.lua` would copy names such as `entry-open-…`. Once T22 lands, that file and `test_entry.lua` would then delete each other's fixtures.

**Correction.** Add to *Boundary, amended*:

> Give every fixture your cases make — `fixture.directory('…')`, `claude_session.fake('…')` — a name no other test file uses; prefix it `claude-numbers-`. Once T22 lands, files run side by side over one `.tests/fixtures/`.

### 8. CONFIRMED in part: the baseline calls the case "load-sensitive", but its own case failed at low load (lines 197–199)

**Reproduced.** From `<builds>/verify73.txt`, `verify73.suite_0.12.5.log` and `verify73.suite_0.11.6.log`:
- 1227 cases on both versions.
- 0.12.5: `Fails (0)`, 869 s.
- 0.11.6: `Fails (1)`, 890 s. The failing case is `arrival = "3.7 s"`, with `edit = "3.7 s"` too, which the amendment leaves out.
- "at load 38–83" is the 1-, 5- and 15-minute averages read at the end of the 0.12.5 run (`38.11 75.17 82.65`). "At load 131" for 0.11.6 is only the 1-minute average.

**UNVERIFIABLE:** "failed at load 115 (3.5 s) and passed at load 95". No file in the orchestrator's scratch directory records those two lone runs.

**My lone runs** (`make test_file FILE=tests/test_report_paths.lua`, tree `acc62d0`; files `brief-t12b-paths-011.txt`, `brief-t12b-paths-runs.txt`, `brief-t12b-paths-fresh.txt`):
- On 0.11.6, the first run **failed at load 29.4 → 36.2**, with `arrival = "3.6 s"` and `edit = "3.7 s"`.
- The next five 0.11.6 runs passed, at loads from 37.7 to 48.0. Two of them started from a fresh `.tests/`.
- Three 0.12.5 runs passed, at loads 36.7–40.9.

So the case fails intermittently on 0.11.6, and failed at a lower load than the passing runs. The instruction can be followed, since I followed it, but its "load-sensitive" premise is not established. It also does not say whether a lone failure blocks the push.

**Correction.** Replace the last sentence of line 199 with:

> It fails intermittently on 0.11.6. The brief review saw it fail alone at load 29 (3.6 s) and pass five times at 38–48. If it fails in your run, re-run its file alone, `env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test_file FILE=tests/test_report_paths.lua`, up to three times. Report each result with `sysctl -n vm.loadavg` before and after. It is not yours to change, and it does not hold your push.

Also attribute "load 38–83" as the three averages at the run's end.

### 9. MISSING: the help — sentences that go stale, and one outside the fence (lines 94, 105, 162–167, 185)

**Inside the section.** Three passages become false or incomplete. The brief's blanket "correct them" covers them, but they are worth naming:
- line 171, "Runs one of aineo's five actions";
- lines 244–245, "followed by one key to each `<Plug>` mapping" — `tcn` is three keys;
- lines 258–263, the overlap paragraph, which covers only the other direction (finding 10).

**Outside the section.** The introduction at lines 25–28 lists every key: "Every command sits behind one prefix key … `\s` …, `\o` …, and `\r`, `\i` and `\c` …". After T12 it silently leaves out `\tcn`, and the fence forbids the edit.

The fence existed for T9, which merged as PR #30. No packet beside T12 edits `doc/aineo.txt`: T22's and T23's boundaries exclude `doc/`. So nothing needs the fence any more.

**Correction.** Either make `doc/aineo.txt` whole T12's, since no packet shares it, and name lines 25–28 among the documents invalidated. Or keep the fence and name lines 25–28 as a known gap for the report.

I also checked that CN8's tags can be built. I added `*:Aineo-claude-numbers*`, `*<Plug>(aineo-claude-numbers)*` and `*aineo-\tcn*` in the scratch help. `make test_file FILE=tests/test_doc.lua` then gave `Fails (0)` of 36 on 0.12.5, "fits in 78 columns" included. So `:help aineo-\tcn` finds the tag despite the `\t` (`brief-t12b-doc.txt`).

### 10. MISSING (a reading for the MVP review): a user's own `\t` or `\tc` will wait for `'timeoutlen'`

`has_global_mapping()` (`plugin/aineo.lua:325`) compares only the exact sequence. A user whose own `\t` or `\tc` is mapped keeps it, but once aineo maps `\tcn` that key waits for `'timeoutlen'`. This is the first aineo key long enough for that to happen: help lines 261–263 describe only a user's longer key. CN6's "never over the user's own global mapping of that sequence" holds literally.

**Correction.** Add to *The orchestrator's readings*:

> a user's own `\t` or `\tc` now waits for 'timeoutlen'; the help says so beside the `\sa` example.

### 11. CONFIRMED (minor): "(was a map at 241)" (line 150)

At `9af91a6`, `lua/aineo/health.lua:241` was the same list of `{ key = …, subcommand = … }` records (`git show 9af91a6:lua/aineo/health.lua`). Only the line moved, by T13's 12-line `ERROR_POSITIONS`.

**Correction:**

> its key table `PREFIX_KEYS`, a list of `{ key = 's', subcommand = 'send' }` records, is at line 253 (was 241).

### 12. CONFIRMED (minor): `columns.lua` "(T17)" and "T17's middle column" (lines 160–161)

- `lua/aineo/layout/columns.lua` was created by `3a16ac6` (2026-09-24, T3's fix round, `Sessions/2026-09-24 — T3 layout.md:566`).
- "The middle column" is C9's file column (D5). T17 opens files into it and created no column.

An implementer could go looking for a second window that does not exist.

**Correction:**

> `columns.lua` (T3) reads a tab's window tree. The file column (C9, D5's "middle column", into which T17 opens paths) is a window of the layout's tab with no role.

### 13. CONFIRMED (minor, original fact not amended): the `USAGE` assertion lines (line 54)

`tests/test_entry.lua` asserts `entry.USAGE` at lines **41, 56 and 66**. The brief says 40, 55 and 65. The amendment moved the case names by one line but not these.

**Correction.** Add to line 148:

> `tests/test_entry.lua` asserts `entry.USAGE` at lines 41, 56 and 66 (were 40, 55 and 65).

### 14. UNVERIFIABLE: "Your Neovim config … maps nothing under `\t`" (line 64)

The fact is dated 2026-09-25. The amendment did not re-read it, and I did not read the developer's Neovim directories: T22 and T23 treat them as off limits, and so did I. It matters only for finding 10.

**Correction:** date it as not re-checked, or re-read it before dispatch.

### 15. CONFIRMED (minor, attribution): "On 0.12.5 a fresh `.tests/` fails readiness and message cases" (line 193)

This is the measurement of T22's brief review at `aaa326a`: 73 cases in 8 files (`brief-t22-parallel-runner.md:27–31`). The amendment gives no attribution. I did not re-measure it; I created `.tests/state/nvim` before every run.

**Correction:** append "(measured by T22's brief review at `aaa326a`)".

## REFUTED — statements tried and found true

Each of these was read at `acc62d0` unless another source is named.

**`plugin/aineo.lua`:**
- 533 lines.
- `SUBCOMMANDS` at 27, `USAGE` at 30.
- `ACTIONS` at 232, `run()` at 290, its `ERROR` notify at 296.
- `PREFIX_KEYS` at 315; `prefix .. PREFIX_KEYS[subcommand]` at 342.
- `start_up` at 474; `desc` at 532.
- `run()` notifies only at `ERROR`, and `start_up` reaches it through `run(start_up)` and `run(open)`.

**`tests/test_entry.lua`:**
- The case names saying "five" are at 38, 45, 53 and 60.
- The completion pin is at 46.

**Other test files:**
- `tests/helpers/entry.lua:18` `M.USAGE`, and `tests/test_entry_prefix.lua:7–13`, are unchanged since `9af91a6`.
- `tests/test_plugin.lua`: the pin is at 62 and `'n <Plug>(aineo-claude)'` at 71. Byte order puts `claude)` before `claude-numbers)` and `\s` before `\tcn`, so the original list at line 57 is correctly sorted. With the key tables alone that pin fails, and only that one of the file's 4 cases.

**`lua/aineo/health.lua`:**
- `check_prefix_key()` (303–304) is the only reader of `.key`. It builds `prefix .. prefix_key.key`, which a three-character key does not break.
- `PREFIX_KEYS_PENDING` is at 447, and its text stays true.
- `tests/helpers/health.lua:109` reads `(%S+)`, which takes `\tcn`.

**`lua/aineo/layout/init.lua`:**
- 854 lines; the alias at 16; `role_of` at 37.
- `M.open` at 786, `M.focus` at 818, `M.follow_claude_terminal` at 842, `M.input_buffer` at 850.

**`doc/aineo.txt`:**
- The section runs from line 168 to line 274, with `*aineo-mappings*` at 221, `Prefix keys ~` at 242 and `*aineo-keys*` at 243.
- T19's sentence is at 213.

**The window behaviours:**
- "Window options … are taken again when a buffer never shown in a window enters it" holds. With the `:setlocal` form, the local values reset to the window's own values. The hidden buffer's autocommand window does not count as "shown".
- CN4b can be built with either scope (finding 5).
- CN8's tags are exactly `:Aineo-claude-numbers`, `<Plug>(aineo-claude-numbers)` and `aineo-\tcn`: the derived-tag case at `tests/test_doc.lua:153` asked for these three when I ran it with the key tables alone.
- `tests/test_entry_prefix.lua` stays green with the tables alone (29 cases), so CN6's red step comes from the implementer adding a row.

**Records and history:**
- The user's words in line 116 match D16's source column verbatim, "toogle" included.
- The task row in line 9 matches the plan's line 132.
- `Sessions/2026-09-25 — T7 entry point.md` exists.
- T9 is done as PR #30.
- "T13 … and T19 have merged" (line 136) is written for the dispatch after PR #73. At `4dc8f85` T19 is still `active`, which the amendment's heading states.

**Other checks:**
- Send refuses at `WARN` with `aineo: nothing sent — …` (`lua/aineo/send/init.lua:28–39`).
- The amendment holds no personal data: no absolute path, no address.

## The six rules, recomputed from the briefs (T12 amended, T22, T23)

| Rule | Result |
|---|---|
| **1. Dependencies** | Met. T12 depends on T8, which is done, and is dispatched after PR #73. T22 depends on T1 and T19, and also waits for #73. T23 depends on T1. |
| **2. File sets disjoint** | Met on files. T12's files are `plugin/aineo.lua`, `lua/aineo/layout/`, `tests/test_layout*.lua`, `lua/aineo/health.lua`, `tests/test_health.lua`, `tests/test_plugin.lua`, `tests/test_entry_prefix.lua` or `tests/test_entry_claude_numbers.lua`, `tests/test_entry.lua`, `tests/helpers/entry.lua` and `doc/aineo.txt`. T22's are `scripts/`, the `Makefile`'s `test` and `test_file` targets, `tests/test_runner*.lua`, `tests/test_isolation.lua`, `tests/helpers/make.lua` and `tests/helpers/fixture.lua`. T23's are `lua/aineo/git/`, `tests/test_git*.lua` and `tests/helpers/git_repo.lua`. The intersection is empty. PR #79's 18 files all lie in T23's set. Every pin that counts what T12 adds is inside T12's set: `test_plugin`, `test_entry` with `helpers/entry`, `test_health`, and `test_doc`, which is derived and needs no edit. No T22 file counts keymaps, subcommands or test files (grep, and `scripts/run_tests.lua:128` globs). T19's diff to `plugin/aineo.lua`, the layout, `doc/aineo.txt` and `test_layout.lua` lands before T12 branches. The one coupling is the shared fixture names (finding 7). |
| **3. Schema** | None of the three has a schema. |
| **4. Dependencies changed** | None. `deps/` and the `deps` target are untouched: T22 may not touch `deps`. |
| **5. No undecided decision** | **Not met.** CN9 (finding 1) and the `\o` rebuild (finding 2) each leave two defensible behaviours. |
| **6. Task lines** | Met. T12 is at line 132, T22 at 142 and T23 at 143. T22 and T23 are adjacent, but all three briefs hold their marks and forbid the task list. The gaps are 10 and 1 lines. |

**Slots:** every slot of the template is filled, the budget is stated as Medium, and the report shape is named.

**Session notes:** `<day> — T12 Claude line numbers.md`, `<day> — T22 parallel runner.md` and `<day> — T23 git home.md` are distinct.

**Scratch prefixes:** `t12-`, `t22-` and `t23-` are distinct.

## Probes

This is a brief review, so no mutants were run.

| Probe | What it shows | Result |
|---|---|---|
| `brief-t12b-cn9.lua`, 2 scopes × 2 autocommand settings × 2 versions | What Claude's window shows after a new terminal enters | The option scope decides; the `TermOpen` autocommand changes nothing (finding 1) |
| `brief-t12b-cn9b.lua` › `file` | A file opened from a toggled Claude window | Numbers hidden with `vim.wo[win]`, the user's with `vim.wo[win][0]` (finding 1a) |
| `brief-t12b-cn9b.lua` › `rebuild` | Claude's window rebuilt by `open()` after a close | Numbers stay hidden with both scopes (finding 2) |
| `brief-t12b-cn9b.lua` › `wiped` | A new terminal entering the window kept after a wipe | `:set` keeps the toggle; `:setlocal` is reset at the wipe (finding 2) |
| `brief-t12b-cn4b.lua` | Toggle from another tab | Tab, window, cursor and mode unchanged; both scopes work (finding 5) |
| Key tables alone, 0.12.5 | Which pins go red | `test_health` 16 of 78, `test_plugin` 1 of 4, `test_doc` 1 of 36 (the three tags), `test_entry_prefix` 0 of 29 (findings 3 and 9) |
| Three tags added to the help, 0.12.5 | Whether CN8 can be built | `test_doc` 0 of 36 fail |
| `test_report_paths.lua` alone, 6 runs on 0.11.6 and 3 on 0.12.5 | Whether the case depends on load | 1 of 6 failed on 0.11.6 at load 29–36; the rest passed at 37–48 (finding 8) |

## Verdict

**Dispatch after corrections.**

An implementer acting on the amendment would be misled in three places:
- **CN9.** It points them at `TermOpen` autocommands that cannot reach Claude's window, and asks for two pins that measure the same thing. It leaves unstated the one choice that decides the behaviour: `vim.wo[win]` against `vim.wo[win][0]`. That choice is a rule-5 decision. One side of it breaks CN3 for files opened from Claude's window.
- **The `\o` rebuild reading.** It asserts a behaviour that Neovim does not give without code.
- **CN7's pin list.** It tells them a list is gone that is still there, and omits nine index reads. 16 cases go red where the brief names 7.

**The one thing to change before dispatch:** decide CN9's behaviour, with the user or as a stated reading, and rewrite lines 171–177 as in finding 1. Recommended: `vim.wo[win][0]`, and a new terminal shows the user's numbers again.

## For the other dimensions

- **attack:** a T12 pull request should be probed with `:edit` from Claude's window after `\tcn` (findings 1a and 3), and with `\tcn` on a Claude window left empty after a wipe (finding 4).
- **test-integrity:** a CN9 pin that sets `autocmd TermOpen … setlocal nonumber` proves nothing about Claude's window, since no `TermOpen` autocommand reaches it. Expect identical results with and without it.

## Cleanup

- **Resource.** `prepare-worktree.sh review_brief_t12b` printed `AGENT_RESOURCE=review_brief_t12b`. Its `prepare_project` is empty, so there was nothing to release.
- **Tracked files.** `git status --short` is empty; I changed no tracked file.
- **Scratch.** All scratch is in this worktree's `.claude/local/orchestrator/`: `brief-acc/`, `brief-t12b-*` and the report. The isolated homes are in `.tests/brief-t12b/`.
- **Scratch edits.** The copy of `deps/mini.nvim` is at `1345d19`. The scratch tree's `plugin/aineo.lua`, `lua/aineo/health.lua` and `doc/aineo.txt` were restored after the probes, from `acc62d0` and the `.orig` copies.
- **Processes.** `ps -Ao pid,ppid,etime,command | grep "[s]leep 30"` prints nothing: no probe terminal was left running.
- **Nothing else was touched.** No real `claude` was run. Nothing outside this worktree was written; the orchestrator's directory was read and run only.
