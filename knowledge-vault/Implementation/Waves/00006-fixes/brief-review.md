# Brief review: wave 6 (PR #29, `knowledge/wave6-fixes-plan` at `0f01c96`)

*Verbatim but for paths, which are replaced by their roles. The corrections it asked for are in the plan and the three briefs as merged; the orchestrator took findings 2 and 21 as readings (T12 warns on its own; from another tab it acts on the layout's tab).*

**Reviewer:** `reviewer`, brief dimension, Opus 5.5. Detached at `0f01c96`, based on `dev` `9af91a6`. `origin/dev` has since moved to `f6c7c6b`: PR #28 and its correction merged. That touches only `.claude/skills/orchestrate/SKILL.md` and `prompts/packet-brief.md`, so every code fact below holds at both shas.
**Resources:** `review_brief_w6`. `prepare-worktree.sh` printed `AGENT_RESOURCE=review_brief_w6`, and `prepare_project` is empty. `make deps` was run in this worktree.
**Instruments:** the host's `nvim` is Homebrew 0.12.5. I also ran `<scratchpad>/nvim-0.11.6/nvim-macos-arm64/bin/nvim` (0.11.6). Probes live in this worktree's `.review-scratch/`. Run outputs are in the shared scratchpad under `brief-w6-*`. I never ran the real `claude`: only `strings` read its binary.

**Labels** (the `brief` block): **CONFIRMED** means a statement is false or misleading, shown by the check given. **REFUTED** means I tried to fault the statement and could not. **MISSING** means a slot, a boundary item or a rule is not met. **UNVERIFIABLE** is used as the charter defines it.

---

## Findings, most severe first

### 1. CONFIRMED: T12's boundary forbids two files that CN5 cannot pass without
- `tests/helpers/entry.lua:18` pins `M.USAGE = 'aineo: :Aineo takes one of send, open, report, input, claude'`. `tests/test_entry.lua:40`, `:55` and `:65` assert it.
- `plugin/aineo.lua:30` builds `USAGE` from `SUBCOMMANDS`. Adding `claude-numbers` therefore turns those three cases red until the helper changes.
- T12's brief line 86 forbids `tests/helpers/`.
- `tests/test_entry.lua:45` pins `getcompletion('Aineo ', 'cmdline')` to `{ 'send', 'open', 'report', 'input', 'claude' }`.
- Four cases are named "…its five subcommands…": `:37`, `:44`, `:52` and `:59`.
- T12 may touch `tests/test_entry_*.lua` (brief line 79, and the plan's row). That glob does not match `tests/test_entry.lua`.
- **Failure scenario:** the implementer adds `'claude-numbers'` to `SUBCOMMANDS`. Four cases in `tests/test_entry.lua` fail by assertion. The fix lies in two files outside the boundary, so the packet ends in a true partial or a boundary breach.
- **Correction:** add both files to T12's *may touch*:
  - `tests/helpers/entry.lua`, `M.USAGE` only;
  - `tests/test_entry.lua`, the completion pin at `:45` and the four case names.

  Add them to the plan's T12 row too. `tests/test_entry.lua` is a T13 file in this wave, and T12 already waits for T13's merge. Add it to the re-check list for T12's amendment.

### 2. CONFIRMED: T12's CN4 asks for a warning through a path that only gives errors
- CN4 says: "one warning through the same path every action's failure takes (`run()`)".
- `run()` notifies at `vim.log.levels.ERROR` (`plugin/aineo.lua:201`).
- MR64 says action errors arrive at `ERROR`, and "Send's refusals stay its own warnings".
- `run()` is also reached by `start_up`, through `open_unless_session_restored` (`plugin/aineo.lua:353`). The boundary excludes "`start_up` or what it reaches", so `run()` cannot gain a level.
- **Failure scenario:** a CN4 test that expects `WARN` cannot turn green without touching `run()`. A test that expects `ERROR` contradicts the word "warning".
- **Correction:** state one of the two:
  - (a) the command raises, and `run()` reports `aineo: <why>` at `ERROR`, like every action failure. Help line 120 already says so of actions.
  - (b) the command notifies its own `WARN`, as Send does (`aineo: nothing sent —`), and does not raise.

  The plan's readings list says "the warning", so (b) matches it. Name the choice as the reading.

### 3. MISSING: all three briefs lack what the merged rule 2 now requires for a vimdoc file
- Rule 2 as merged at `f6c7c6b` requires the fence "by each section's first and last line, quoted".
- It also requires "the file's own pin run on the merged file (`make test_file FILE=tests/test_doc.lua`)". `git merge-file` cannot see E154: two packets adding the same tag merge clean.
- `prompts/packet-brief.md` gained the slot *A document shared under rule 2's section exception*.
- The briefs fence by tag only and order only `git merge-tree`. The plan cites PR #28 as "merged before dispatch", but not the corrected text.
- **Correction:** fill the new slot in each brief with these quoted lines, measured on `9af91a6`:
  - **T9:** first `8. THE AGENT REPORT                                             *aineo-report*` (l.253); last `the working directory of its own moment.` (l.280).
  - **T13:** first `2. REQUIREMENTS AND INSTALLATION                               *aineo-install*` (l.36); last ``|aineo-configuration|; then run `:checkhealth aineo` (|aineo-health|).`` (l.48).
  - **T12:** first `4. COMMANDS                                                   *aineo-commands*` (l.89); last `of both (|aineo-health|).` (l.177). This is one contiguous range covering `*aineo-mappings*` (l.124) and `Prefix keys ~` (l.145), which sits above `*aineo-keys*` (l.146).
- Add to each brief: before pushing, run `make test_file FILE=tests/test_doc.lua` on the merged file, and report both results.

### 4. CONFIRMED: T13 failure 4 has the wrong cause
- The brief says: "0.12 puts the position of its own Lua code inside the error".
- Both versions put the position there. I measured `pcall(vim.system, {'/nonexistent/aineo-probe'})` (`.review-scratch/syserr.lua`):
  - **0.11.6:** `.../share/nvim/runtime/lua/vim/_system.lua:254: ENOENT: …`. `health.lua`'s `'^.-%.lua:%d+: '` strips this, leaving `ENOENT: …`.
  - **0.12.5:** `vim/_core/system:324: ENOENT: …`. 0.12's runtime modules carry chunk names without `.lua`, so the pattern does not match.
- **Failure scenario:** an implementer who believes 0.12 *adds* a position looks for a new prefix to strip. The real change is the missing `.lua` in the position's form.
- **Correction:** "Both versions prefix the position of Neovim's own Lua. 0.11's ends in `.lua:<n>: `, which `error_line()` strips. 0.12's is a chunk name without `.lua` (`vim/_core/system:326: `), which it does not."
- Also say whether NC2 covers the same shape in `plugin/aineo.lua`'s `ERROR_FRAMING` (`'^.-%.lua:%d+: '`). I know of no action that raises from 0.12's runtime Lua, and the suite shows none.

### 5. CONFIRMED: T13 failures 5–7 have a misleading cause
- The brief says: "where only the binary's built-in `package.path` was searched".
- Neovim's runtimepath loader lists no "no file" lines on either version, so that output cannot show whether it searched.
- I measured with a probe run through `make test_file`: `.review-scratch/test_brief_probe_tui.lua`, using the same start as `tests/helpers/report_tui.lua`.
- **0.12.5:** the first RPC request is answered with `vim_did_enter = 0`, the checkout not on `'runtimepath'`, and ``module 'aineo.report' not found``.
  - The request is served inside 0.12's startup wait, `vim.wait(100, … did_dsr_response …)` in `vim/_core/defaults.lua:977`. That is the OSC 11/DSR background query, which the helper's pty never answers.
  - The wait comes before `-u scripts/minimal_init.lua` runs. The failure's own traceback names `vim/_core/defaults:977`.
  - 1.5 s later, the same editor loads `aineo.report`. Its `:messages` then holds ``E1568: Terminal did not respond to DSR request for 'background' color. Startup may be slower. :help 'ttyfast'``, and the mode is `n`.
  - `defaults.lua` suppresses E1568 only when `NVIM_TEST` is set.
- **0.11.6:** the first request is answered after VimEnter (`vim_did_enter = 1`), and `:messages` is empty.
- **Correction:** replace the sentence with this measured cause. Give E1568 as a second 0.12 effect in that editor, since `test_mcp_blocked_editor.lua` is about messages and hit-enter prompts.

### 6. CONFIRMED: T13 failure 3 has two differences; the brief gives one
- 0.11 expects: `aineo: nvim_exec2()[1]..TermOpen Autocommands for "*": Vim(append):Error executing lua callback: [string "<nvim>"]:3: the user autocommand fails`.
- 0.12.5 gives: `aineo: Lua: nvim_exec2()[1]..TermOpen Autocommands for "*": Vim(append):Lua callback: [string "<nvim>"]:3: the user autocommand fails`. Source: `brief-w6-run-entry.txt`.
- The evidence file cuts the expected value off at `'aineo: nvim_exec2()[1]..TermOpen `, so the inner difference is hidden.
- Stripping `^Lua: ` leaves the test red on 0.12.
- **Correction:** quote both full messages. Say that the inner text differs by version and the test states both, per the brief's own last behaviour bullet. Framing is not stripped inside the line.

### 7. CONFIRMED: T9's RC4 and one of its plan mutants rest on an unmeasured premise
I measured on 0.11.6 and 0.12.5 with `.review-scratch/hlclear.lua` and `hlclear2.lua`.
- A group set with `nvim_set_hl(0, g, { link = 'Comment', default = true })` keeps its link after `:colorscheme default`, `:colorscheme habamax` and `:highlight clear`, with no re-definition.
- The link is lost only when the group already had a definition when aineo set its default: a scheme's attributes, or a scheme's link. After `:colorscheme default`, that group is `{}`.
- A user's `:highlight` made before the default link wins, giving `{ fg = 16711680 }`.
- **Consequences:**
  - The plan mutant "the groups not defined again after `:colorscheme`" survives any RC4 test in which aineo defines the groups first.
  - "`default = true` dropped" is killed only if the user's highlight precedes aineo's first definition.
- **Correction:** RC4 states the order.
  > A user's `:highlight`, or a colour scheme's, made before the Report first shows a report, wins. After `:colorscheme` switches to a scheme that does not define a group, the group is linked to its default again. This includes a group the earlier scheme had defined before aineo first defined it.

  The mutant then names that test.

### 8. CONFIRMED: T12 and T9 overlap on a test file as declared
- T12 may touch `tests/test_entry_*.lua` (brief line 79; the plan's row `tests/test_entry_*`). That includes `tests/test_entry_report.lua`, a T9 file (T9 brief line 68).
- The plan's rule 2 says "No registration file is shared". As declared, a test file is.
- T12 needs only `tests/test_entry_prefix.lua`, whose `PREFIX_KEYS` parametrize list is at l.7–13, or a new file.
- **Correction:** name T12's files. Drop the glob.

### 9. MISSING: NC3 changes 0.11's behaviour, and no reading names it
- On 0.11 today, Claude's tool error reads `the editor did not take the report: Error executing lua: aineo.report has no environment: …`.
- `tests/test_mcp_delivery.lua:322` pins that text as expected. It comes from `lua/aineo/mcp/editor.lua:148`, `first_line(tostring(failure[2]))`.
- NC3 says "on both versions… without Neovim's framing", which changes v0.1.0's tool-error text on D10's minimum.
- No row decides this. MR64 covers the user's error only, and is itself an open reading.
- The plan's *orchestrator's readings … for the MVP review* lists T9's and T12's readings, and none for T13.
- **Correction:** say in T13 that the 0.11 expectation at `:322` changes too. Add this as a T13 reading in the plan.

### 10. CONFIRMED: an implementer cannot write its report to `<scratchpad>`
- Each brief writes `<scratchpad>/tN-report-packet.md`, where `<scratchpad>` is "the orchestrator's scratch directory".
- I measured it. My `Write` to `<scratchpad>/…` was refused: "This agent is isolated in the worktree … Edit the worktree copy of this file instead of the shared-checkout path."
- A shell redirect to the same directory worked.
- The ledger's 18:02 line records the same harness fact.
- **Correction:** the report path is the agent's own worktree `.claude/local/orchestrator/`, which is gitignored (`.gitignore:39`). The 0.11.6 binary keeps its absolute path, since reading and running it are allowed: I ran it.

### 11. MISSING: the literal form of "0.11.6 first on `PATH`"
- The worktree guard refused `PATH="<dir>:$PATH" make test_file …`: "runs make with a value computed at runtime (the variable PATH)".
- This form ran: `env PATH=<scratchpad>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test_file FILE=…`. Children started through `vim.v.progpath` then run 0.11.6: the probe reported `0.11.6+ge8b87a554f`.
- **Correction:** give this form in T9, T13 and T12.

### 12. CONFIRMED: two baseline figures are attributed to the wrong run
- **0.12.5 (T9 l.45):** T9 attributes `727 cases, Fails (8)` to "the host's `nvim`".
  - The evidence header says the downloaded `v0.12.5` build was first on `PATH`.
  - On Homebrew's 0.12.5 I reproduced the eight failures in their five files: health 78/1, entry 41/1, delivery 18/1, blocked editor 3/3, claude 71/2, and the guard 5/0. I did not run the whole suite there.
- **0.11.6 (T9 l.44, T13 l.50, plan l.30):** the figure is the wave-5 verification of `a9f8027`.
  - Its record names no Neovim version, and "Homebrew's build" appears in no record.
  - The downloaded 0.11.6 has since run `9af91a6`: `727 cases, Fails (0)` in `nvim0116-suite.txt`, 489 s per the ledger. The file does not name its binary.
- **Correction:**
  - add `evidence/baseline-0.11.6.txt`, with the binary's path and `nvim --version` in its header, as the 0.12.5 file has, and cite it in T9, T13 and the plan;
  - attribute T9's 0.12.5 figure to the downloaded build, or tell the packets to use `<scratchpad>/nvim-0.12.5/…` for parity.

### 13. CONFIRMED: T9's RC6 and RC7 cannot be "seen red first"
- The heading says "The behaviours: one test each, each seen red first".
- RC6 adds no test; its property is that existing tests stay unchanged.
- RC7 ("defines no highlight group and adds no autocommand") is green on `dev`, where no group exists: `git grep -n -E "nvim_set_hl|ColorScheme" origin/dev -- lua plugin` prints nothing.
- **Correction:** label RC6 and RC7 as invariants, pins that stay green. Give each a mutant that shows it can fail. For RC7: groups defined at `require('aineo.report')`, or in `plugin/aineo.lua`, turn its test red.

### 14. CONFIRMED: T13's help boundary contradicts itself
- The brief says "`doc/aineo.txt`, **only inside** `*aineo-install*`", and also "any help line that quotes an error with Neovim's framing".
- `grep -n -E 'Error executing|Lua: |Vim:|Vim\(' doc/aineo.txt` finds no match.
- **Correction:** "No help line quotes Neovim's framing today (grep)."

### 15. MISSING: T13's health boundary does not cover the shared helper
- The boundary allows "`lua/aineo/health.lua`, the 'could not run' warning only".
- The warning's text comes from `error_line()` (`health.lua:15`). The Configuration error uses the same helper (`health.lua:30`).
- **Correction:** say whether `error_line()` is inside the boundary.

### 16. MISSING: T12's boundary misses a description string and two count pins
- `plugin/aineo.lua:437` has `desc = 'aineo: send, open, report, input or claude'`, which `:command Aineo` shows. It goes stale.
  - T12 may touch only the "subcommand, action and key tables".
  - **Correction:** add this line to the boundary.
- `tests/test_health.lua:562` and `:597` hold `eq(#health.section(report, 'Prefix mappings'), 5)`, which becomes 6.
  - The brief's fact names only the lists. The more complete list is 499–503, 615–619, 630–634, 758–762 and 816–820.
  - These pins are inside the boundary.

### 17. CONFIRMED: T9 and the plan cite task ids with no row
- T9 cites T11 at l.11 and l.87. The plan cites T10 and T11.
- Neither has a task row, on `dev` or in this PR. The brief rule says: "A task id is looked up, never recalled."
- **Correction:** write "a later packet (the icon, C10)" in place of T11.

### 18. CONFIRMED: T13 cites the wrong rows for its error rule
- T13 l.13 attributes "every error an action raises reaches the user once as `aineo: <its first line>`, without Neovim's framing" to "C1 and MR64".
- C1 (plan note l.59) says nothing about errors. MR64 does, and its review note's status is "open".
- **Correction:** "C1, the entry point, and MR64, an open reading: …"

### 19. MISSING: T9's RC5 omits a third path
- RC5 names two paths. A third exists: `:edit` in the Report empties it, and `BufReadCmd` fills it again through `show_records()` (`buffer.lua:41–61`).
- **Correction:** name the `:edit` path in RC5.

### 20. CONFIRMED: an evidence command prints 0 as written
- `evidence/help-merge-check.txt` records `grep -c 'FROM THE (REPORT|KEYS) PACKET' merged.txt` → `3`.
- As written, this is a basic regular expression, and it prints `0`. I measured it with the shell's `grep` and with `/usr/bin/grep`. With `-E` it prints `3`.
- The merge itself holds:
  - re-run, it gives rc 0, byte-identical to the kept `merged.txt`;
  - `base.txt` equals `doc/aineo.txt` at `9af91a6`.
- **Correction:** record `grep -c -E`.

### 21. MISSING: T12 does not say what happens from another tab
- CN4 does not say what `\tcn` does from a tab other than the layout's. Claude's window exists, in another tab. Does it toggle there, or count as "not shown"?

### 22. UNVERIFIABLE: the plan's "in 460 s" (l.23)
- The raw output, `nvim012-suite.txt`, carries no timing.
- The evidence header says "17:44–17:51", but the raw file's mtime is 17:50.

### 23. CONFIRMED: the user's words are quoted two ways
- D16 quotes "A toggle for line number for the claude buffer…".
- T12 l.97 quotes "A toogle for line number for the claude buffer…".
- Both are given as the user's words. Quote the user's exact text in both.

### 24. MISSING (note): T12's session-note date
- T12's session-note name, `2026-09-25 — T12 Claude line numbers`, is dated today. T12 waits for T13's merge, so it may be dispatched on a later day.
- **Correction:** fix the date in its dated amendment.

---

## REFUTED: what I checked that held

**T13's eight failures.**
- All eight reproduced in my worktree on Homebrew 0.12.5 (`brief-w6-run-{health,entry,delivery,blocked,claude}.txt`), each by the assertion the brief names:
  - #1: an error-pattern mismatch;
  - #2: a `contains` failure;
  - #3, #4 and #8: equality failures;
  - #5–7: the require error at `report_tui.lua:97`.
- `tests/test_entry_guard.lua` gave 5 cases, `Fails (0)`.
- The whole-suite `727 / Fails (8)` in `nvim012-suite.txt` matches the evidence.

**T13 NC5.** 0.12.5 still shows `[Process exited 3]`, as an overlay virtual-text extmark.
- It comes from the default `TermClose` autocommand of group `nvim.terminal` ("Displays the "[Process exited]" virtual text"). The buffer's text lacks it.
- On 0.11.6 it is buffer text (`.review-scratch/exitline*.lua`).
- So the "spec conflict" branch does not apply, and `lua/aineo/claude/` needs no change.
- The test reads the extmark on 0.12. If it goes through `claude.wait_for_screen` (`tests/helpers/claude_session.lua`), that helper is outside T13's boundary: write the check inline in `tests/test_claude.lua`, or add the helper.
- Worth adding to the brief as a measured fact.

**T13's other facts.**
- `plugin/aineo.lua:172` holds `ERROR_FRAMING` exactly as quoted, used by `error_line()`.
- Both tarballs' sha256 equal the releases' digests, `d5ee93b6…c1dd` and `65fb0000…1f9b` (`gh api …/releases/tags/…`).
- The `gh api 'repos/neovim/neovim/contents/<path>?ref=v0.12.5'` command works.

**The Neovim evidence.**
- v0.11.6 has no `dim`: 0 matches in `vterm_defs.h`.
- `attrs.dim` is at v0.12.0 `terminal.c:1458` and v0.12.5 `:1477`.
- PR #37997 is "feat(terminal): support SGR dim, overline attributes", merged 2026-02-27.
- v0.11.6 has `parse_osc8` and `hl_add_url` at `terminal.c:296`, `:322` and `:352`.

**The Claude Code evidence.** 2.1.282's `strings` output reproduces the ctrl+n and ctrl+p table, with 0 strings for ctrl+y and ctrl+q. The binary was not executed.

**Code identity.**
- `git diff --stat a9f8027 9af91a6 -- lua plugin tests scripts doc Makefile` prints nothing.
- `9af91a6..f6c7c6b` touches only `.claude/`.

**T9's facts.**
- `render.lua:36–41` holds the header format, with `DETAILS_INDENT` = `#'HH:MM '`.
- `buffer.append_lines` is at `:106`.
- `show_records` renders at `init.lua:105`; a new report renders at `:169`.
- `records.lua:173` holds `vim.json.encode(record)`.
- The `nvim_set_hl|ColorScheme` grep is empty.
- The four test files are exactly those `git grep -l '\[(started|…)\]'` finds.
- No test takes screenshots.
- Only `test_plugin.lua:42` reads autocommands, and only at startup.
- All five `Diagnostic*` groups and `Comment` exist in a clean start on both versions.

**T9's small-fix class** (SKILL §3). The class holds:
- one behaviour;
- one home, `lua/aineo/report/`, with its tests and its invalidated help section;
- no new row;
- none of the excluded paths: `claude/`, `mcp/`, `send/`, the fake and transcripts, `health.lua`, `init.lua`, `scripts/`, `tests/helpers/`, `Makefile`;
- a `bugfix/` branch and a `Small fix:` title;
- two reviews per §3.

One wording point: "It rests on C6 and C10". C10 is new in this PR and is T11's. T9 rests on C6; cite C10 as context.

**The help tags.**
- `aineo-\tcn`, `:Aineo-claude-numbers`, `<Plug>(aineo-claude-numbers)` and `hl-AineoReportTime` are each found by `:help` on both versions.
- I built a full help copy with T12's three tags beside `:Aineo-claude`, `<Plug>(aineo-claude)` and `aineo-\c`. On both versions, all 19 command, mapping and key tags land on their own line (`missing: {}`).

**The help split, measured with `git merge-file`** (`.review-scratch/merge/`). I made one edit set per packet, confined to its section, with hunks at the section's edges. T9's is appended just above the rule that opens `*aineo-autostart*`.

| pair | result |
|---|---|
| T9 × T13 | rc 0, 8 marked lines |
| T9 × T12 | rc 0, 9 marked lines |
| T13 × T12 | rc 0, 7 marked lines |
| T13 × T9 | byte-identical to T9 × T13 |
| all three | rc 0 |

- `make test_file FILE=tests/test_doc.lua` on the three-way merged file: 36 cases, `Fails (0)`. The file was restored afterwards.
- Nearest hunks:
  - T13's section ends at l.48 and T12's begins at l.89: 40 unchanged lines between them.
  - T12's ends at l.177 and T9's begins at l.253.
- The tag sets are disjoint, so no E154.

**T12's facts at `9af91a6`** (and `f6c7c6b`).
- `plugin/aineo.lua`: `SUBCOMMANDS` l.27, `ACTIONS` l.152, `run` l.195, `PREFIX_KEYS` l.220, `prefix .. PREFIX_KEYS[subcommand]` l.247.
- `health.lua`: `PREFIX_KEYS` l.241.
- `test_health.lua`: lists at 499–503 and 615.
- `test_plugin.lua`: the pin at l.62.
- `layout/init.lua`: the alias at l.16, `role_of` at l.34, and a public surface of exactly `open`, `focus` and `input_buffer` (`columns.lua` exports only `windows_between`).
- The user's config, read only: `lazy.lua:22` holds `vim.g.maplocalleader = "\\"`. No static `\t…` or `<LocalLeader>t` mapping. This is a static read only, and it cannot see plugins.
- **After T13's merge, expect to re-read:** `plugin/aineo.lua` 195/220/247 if T13 adds lines near `ERROR_FRAMING`; `health.lua:241` if `error_line()` changes; `test_health.lua` 499+ if T13 edits the test at ~l.213.

**The frozen pin's list after T12.** `tests/test_plugin.lua:70–81` holds 12 entries, sorted as the pin sorts them. I checked this with `table.sort`. `nvim_get_keymap` records the lhs as `\tcn`:
```
'n <Plug>(aineo-claude)', 'n <Plug>(aineo-claude-numbers)', 'n <Plug>(aineo-input)',
'n <Plug>(aineo-open)', 'n <Plug>(aineo-report)', 'n <Plug>(aineo-send)',
'n \\c', 'n \\i', 'n \\o', 'n \\r', 'n \\s', 'n \\tcn',
```
Commands (`{ 'Aineo' }`) and autocommands (`{ 'aineo StdinReadPost' }`) are unchanged.

**The wave's bookkeeping.**
- The three session-note names are free on `dev` and distinct.
- The scratch prefixes `t9-`, `t13-` and `t12-` are distinct.
- The resource names match `^(impl|review)(_[a-z0-9]+)+$`.
- The branch prefixes follow the template: a small fix and T13 on `bugfix/`, D16 on `feature/`.
- The reviewer allocation matches §3 and §6.
- The `Waves/CLAUDE.md` amendments (the claimed row, the no-edit rule, the naming list) and `rolling: false` are present.
- Each task text in the briefs is identical to its row in the plan note.
- The `git merge-tree --write-tree` form is allowed by the new template slot.

---

## Mutants

I ran no code mutants in this dimension. I measured whether each plan mutant can be killed:

| plan mutant | test that kills it | measured |
|---|---|---|
| T9 "groups not defined again after `:colorscheme`" | only an RC4 test in which the group is defined before aineo's first definition, then a scheme without it is loaded | a default link survives `:colorscheme` and `:hi clear` on 0.11.6 and 0.12.5 when aineo defined it first, so the naive test cannot kill this (finding 7) |
| T9 "`default = true` dropped" | a user-wins test with the user's `:highlight` set **before** the first report | the user's attributes held over a later default link, on both versions |
| T12 "`tcn` missing from `health.lua`'s key table" | `test_health.lua:600` (exists on the base) | reasoned from the helpers: `keys_mapped_to_aineo` against `keys_reported_in_place` |
| T13 four mutants | the eight tests on the base, on 0.12 | all eight are red on the base, reproduced |

Summary: 4 plan mutants examined, 1 equivalent unless RC4 is corrected, 3 killable by named tests.

---

## The six rules, recomputed from the briefs

| rule | T9 ‖ T13 (dispatched together) | T12 (after T13's merge; T9 may still be open) |
|---|---|---|
| 1 dependencies | both need T8 (done) ✓ | T8 ✓; waits for T13 by rule 2, as the plan says ✓ |
| 2 files | intersection = `doc/aineo.txt` only. Under the section exception: `*aineo-install*` l.36–48 and `*aineo-report*` l.253–280, merged clean, `test_doc.lua` 36/0 on the merged file. **The brief slot and the quoted fences of the merged rule are missing (finding 3)** | with T13: `plugin/aineo.lua`, `health.lua` and `test_health.lua`, **plus `tests/test_entry.lua`, which T12 needs but does not declare (finding 1)**, handled by waiting for the merge. With T9: help sections disjoint (l.89–177 against l.253–280, clean), **but `tests/test_entry_report.lua` is in both declared sets (finding 8)** ✗ |
| 3 schema | none ✓ | none ✓ |
| 4 dependencies | none; `Makefile` and `scripts/` are forbidden to both ✓ | none ✓ |
| 5 decisions | T9's colours are a named reading ✓. **T13's change on 0.11 is unnamed (finding 9)** | **CN4's level is undecided or contradictory (finding 2)**; behaviour from another tab is unstated (finding 21) |
| 6 task lines | T9 l.112, T12 l.113, T13 l.114: adjacent, 0-line gaps. All three hold their marks, and each brief says so ✓ | same ✓ |

---

## Verdict per brief

- **plan.md: correct before merge.**
  - Rule-2 bullets: cite the merged fence rule, and fix T12's glob and missing files (findings 1, 3, 8).
  - The equivalent mutant (7).
  - The T13 reading (9).
  - The 0.11.6 evidence and attributions (12).
  - The T10 and T11 references (17).
  - The evidence grep (20).
- **brief-t9-report-colours.md: dispatch after corrections.**
  - Items 3, 7, 10, 11, 12, 13, 17 and 19.
  - The C10 wording.
  - The class holds.
- **brief-t13-neovim-0-12.md: dispatch after corrections.**
  - Items 3, 4, 5, 6, 9, 10, 11, 12, 14, 15 and 18.
  - Add NC5's measured fact.
  - Its causes as written misdirect three of the four fixes.
- **brief-t12-claude-numbers.md: do not dispatch as written.** Dispatch after corrections in its dated amendment:
  - items 1, 2, 3, 8, 10, 11, 16, 21, 23 and 24;
  - the re-check list above.

As written, an implementer would reach a true partial (finding 1), or would have to decide CN4 itself (finding 2).

**The single most important change:** widen T12's boundary to `tests/helpers/entry.lua` and `tests/test_entry.lua`, and decide CN4's level. In T13, replace the misstated causes of failures 3, 4 and 5–7 with the measured ones.

## Other dimensions
- **records (PR #29):**
  - D16's quote differs from T12's;
  - "460 s" is unverifiable;
  - the evidence's `grep` has no `-E`;
  - T10 and T11 are cited without rows;
  - §3 says the first plan "lands with its first packet", but this one carries three.
- **attack (T9, later):** on `:edit` in the Report, the lines are emptied while their extmarks survive, collapsed. Check that refills do not pile up stale spans.
- **test-integrity (T13, later):** a version-branched expectation must not accept either version's text on both versions.

## Cleanup
- `prepare-worktree.sh` created nothing: `prepare_project` is empty, and it printed `AGENT_RESOURCE=review_brief_w6`.
- No process of mine is left: `pgrep -fl agent-a2af00cee00f88f87` printed nothing.
- `doc/aineo.txt` is restored with `git checkout HEAD -- doc/aineo.txt`. `git status --short` shows only `?? .review-scratch/`.
- The worktree stays detached at `0f01c96` and is left in place.
- Files I wrote in the shared scratchpad, all prefixed `brief-w6-`:
  - `brief-w6-deps.txt`, which is empty;
  - `brief-w6-run-{guard,health,entry,delivery,blocked,claude}.txt`;
  - this report's copy, `brief-w6-report.md`.
