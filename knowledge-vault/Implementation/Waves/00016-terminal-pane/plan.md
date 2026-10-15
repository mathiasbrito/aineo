---
wave: 00016
status: planned
rolling: true
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for the user
planned_at: 2026-10-14
base: e05a1e3
claimed_by:
claimed_at:
landed_at:
pull_requests:
---

# Wave 16 — a shell terminal pane in the right column

**Planned by:** the orchestrator's planning agent, 2026-10-14. **Base:** `dev` `e05a1e3`, with wave 15 under way: T60–T65 merged, T64 in review, T66 next. **Built after T66 merges.** Each brief's first commit re-checks its facts against the `dev` it starts from, and a changed fact is a dated amendment at the end of the brief (A163, as A256 did for T66).
**Ask:** the user's request and answer of 2026-10-14 (*The user's words*, below).
**Composition from:** [[Planning/aineo — v1 agent console]] › D18, D25, D52, D53, D58, D59, D63, C1, C7, C12, and the D68 and T69–T70 this plan writes. See also [[Projects/aineo]] and [[Implementation/Waves/00015-tabs/plan]], whose model of one copy per tab this wave builds on.

**Two regular packets in two stages.**
- **Stage 1 — T69:** the layout's third pane, `terminal`, and a new shell home, `lua/aineo/shell/`, one copy per tab. No key yet, no behaviour change for the user. Its files are disjoint from T67's and T68's, so it runs beside them.
- **Stage 2 — T70:** the key, the composition root, the tab's close, the health check and the help. It shares `plugin/aineo.lua`, `lua/aineo/health.lua` and `doc/aineo.txt` with T67 and T68, so it starts once T69, T67 and T68 have merged (O1).

## The user's words — 2026-10-14

Verbatim, from the orchestrator's record of the conversation:

> "another feature, that maybe can go in the same wave, a terminal in the left, we have the report, and git windows we will have the \<some_key> which opens a terminal besides the terminal running claude, session is persistent until the user closes it, if done so, the buffer is destroyed and the user comes back to the report windows. If you prefer to have it in a separated wave, feel free."

The orchestrator asked where the terminal should open:

> Q: "Where should the shell terminal open? Today the right column switches between the agent pane (Report + Input) and the changes pane (git)." — A: "A third pane on the right (Recommended)" (option text: "Like \pa and \g: the key shows a shell pane in the right column in place of Report/git; closing it (exit or :bd) wipes it and shows the agent pane (Report) again. One per tab.")

**What the words decide:**
- a key opens a shell terminal beside Claude's terminal;
- it is a third pane of the right column, shown in place of the agent pane or the changes pane, as `\pa` and `\g` show theirs;
- it persists until the user closes it;
- closing it, by `exit` or `:bd`, destroys its buffer and shows the agent pane, the Report, again;
- one per tab.

The request says "in the left"; the answer places it in the right column, and the answer is what this plan builds. A separate wave was the user's offer, taken here.

The user has told the orchestrator to finish wave 15 and this wave without waiting for answers. So nothing here is put to the user: every open choice is under *Decisions for the orchestrator*, with a recommendation the orchestrator rules and reports.

## The model

1. **The pane.** The right column shows one of three panes: the agent pane, the changes pane, and the terminal pane (D68). The terminal pane shows the tab's shell in the Report's window, over Input, which stays in its window (O4). The windows and their sizes stay put, as D18 has them.
2. **The shell.** A new home, `lua/aineo/shell/`, starts the user's `'shell'` in a terminal of its own, in the folder, with `AINEO_CHILD` set. Each tab has its own copy (`new()`), and the module is the first tab's, as wave 15's homes are (O7–O10).
3. **Persistent.** `\pa` and `\g` hide the shell and leave it running. The key shows the same buffer again, in Terminal mode (O6, O11).
4. **Closing.** Any end of the shell wipes its buffer and shows the agent pane, the Report's window reopened in place when the wipe closed it: `exit`, whatever its status; `:bd!`; `:bw!` (O12). A tab's close stops its shell. Quitting adds nothing, since Neovim hangs up the shell itself (O13).
5. **Who does what.** The layout is handed the shell's buffer, as it is handed the changes pane's, and reacts to its wipe. The shell home makes, wipes and stops the buffer. The composition root (`plugin/aineo.lua`) wires the key, the tab and the close.

## D68 — written into the plan note

> **D68** — A shell terminal in the right column, a third pane beside the agent pane and the changes pane (the user's decision). A key shows a shell in the right column, in place of the agent pane or the changes pane, as `\pa` and `\g` show theirs. The shell persists until the user closes it. Closing it, by `exit` or `:bd`, destroys its buffer and shows the agent pane, the Report, again. There is one per tab. The key, the window it takes, its command, directory and environment, and what a tab's close and the quit do to it are the planning's proposals, ruled by the orchestrator (`Implementation/Waves/00016-terminal-pane/plan.md`, O4–O14), and not part of this row (amends D18, D63; C1, C12)

**Dated notes, 2026-10-14,** on D18, D58 and D63, and on C1 and C12, each for its part.

**Task rows:** T69 and T70, after T68.

## Baseline

This plan ran no suite. The last whole run on record is wave 15's (`00015-tabs/plan.md` › *Baseline*). Each dispatch message pastes the counts of the test files its packet runs, measured on the `dev` it starts from.

## Measured before planning

`evidence/w16-probes.sh` holds the run, and `evidence/w16-probes.txt` its output. Host: macOS, Neovim 0.12.5, `'shell'` `/bin/zsh`. Each probe ran `nvim --clean --headless`, with three windows as the layout has them and a shell in the Report's window. No suite ran, and the real `claude` never ran.

- **Q1, `exit` (status 0), the shell started as `'shell'` alone.** Neovim's own `TermClose` handler (the `nvim.terminal` group) deletes the buffer, which closes the Report's window. The order is `WinClosed`, `BufUnload`, `BufDelete`, `BufWipeout`, and only then aineo's own `TermClose`.
- **Q2, `exit 3`; Q3, `exit` from a shell started with an argument.** The buffer stays, with Neovim's `[Process exited n]`. Only Neovim's handler deletes, and only on status 0 when the command is `'shell'` exactly.
- **Q4, `:bdelete!`; Q5, `:bwipeout!`, while the shell runs.** Both wipe the buffer and close the Report's window, and `WinClosed` comes before every buffer event.
- **Q6, `:bdelete` without `!`.** Refused with E89, as Neovim refuses it for every running terminal.
- **Q7.** Putting the Report back on `BufUnload` comes too late: the window is closed already.
- **Q8.** Putting the Report back in the window before deleting the buffer keeps the window.
- **Q9, the environment.** A job inherits the editor's environment, `NVIM` included, and `env` adds a variable. Leaving variables out takes `clear_env` and a whole environment.
- **Q10.** A terminal job's `cwd` is the folder given.
- **Q11.** `:qa` (no `!`) quits with a shell running in a terminal; Neovim does not refuse it.
- **Q12.** At the quit, the shell receives SIGHUP.

Read on `dev` `e05a1e3`:
- **R1.** `aineo.layout` has two panes. `PANE_BUFFERS` (`lua/aineo/layout/init.lua`) maps each to the buffer it shows in each right-column window. `OTHER_PANE` assumes two. `show_pane()` validates `'agent' or 'changes'`. `PANE_LANDING` lands `\pa` in the Report and `\g` in the commits window (D59). `focus('report'|'input')` shows the agent pane first (D18's PD1).
- **R2.** The layout creates no buffer but Input, and is handed every other (its header).
- **R3.** Claude's terminal is an unlisted buffer (`nvim_create_buf(false, true)`) started by `jobstart()` in `nvim_buf_call()`, with `AINEO_CHILD=1` added to the editor's environment (`lua/aineo/claude/init.lua`, `CHILD_ENVIRONMENT`, `run_in_terminal()`).
- **R4.** Only the autostart reads `AINEO_CHILD`. It refuses to start inside aineo's own Claude terminal, and the health check says so (`plugin/aineo.lua` › `NOT_BARE_INTERACTIVE`, `lua/aineo/health.lua`). aineo puts no `CLAUDE*` variable in the editor's own environment (`git grep 'vim.env.'`).
- **R5.** The prefix keys, with wave 15's: `s o r i c tcn S N pa g` today; T66 adds `T` and `1`–`9`, and T67 adds `Q`. `:Aineo pane` takes `agent` and `changes` (`SUBCOMMAND_WORDS`). Twins come from `PREFIX_KEYS` through `map_terminal_prefix()`. `lua/aineo/health.lua` keeps its own `PREFIX_KEYS` list.

## Decisions for the orchestrator

Numbered once, here. Each recommendation is (a), and both briefs are written for the recommendations. A ruling other than (a) is a dated amendment of the brief before dispatch.

**The wave**

- **O1 — The shape.**
  - (a) Two packets.
    - T69, the layout's pane and the shell home, is dispatched once T66 has merged. It runs beside T67 and T68, whose files it does not share.
    - T70 is dispatched once T69, T67 and T68 have merged. It shares `plugin/aineo.lua`, `lua/aineo/health.lua` and `doc/aineo.txt` with them.
  - (b) As (a), with T70 run between T67 and T68. T68 then re-checks its facts after T70.
  - (c) One packet. It would hold the layout, a new home and the composition root, and wait for T68 whole.
- **O2 — Models and reviews**, as the orchestrator's instruction says.
  - Both packets: `neovim-lua-developer` on Sonnet. Neither starts, stops or routes to Claude Code.
  - Attack: `neovim-lua-reviewer` (Opus). Tests and records: one `records-reviewer` (Sonnet).
  - One fix round, the orchestrator's own check, and at most 5 mutants each.
  - A packet that comes back short of its brief goes to Opus for its fix round.
- **O3 — The class.** (a) Both regular, each keeping D26: the whole suite once before each push. These are the user's prompt-driven waves (D30), but neither packet is a small fix: T69 changes the layout's pane switch, and T70 changes the composition root.

**The pane**

- **O4 — The window the shell takes.**
  - (a) The Report's window, with Input under it in its own. The windows and their sizes stay put (D18): the shell takes the Report's share of the column (`layout.report_height`, ⅔ by default). Input stays visible, and Send still sends it.
  - (b) The whole right column: Input's window closes while the shell shows, and is made again under the Report when another pane shows. This goes against D18's "the right column's windows and their sizes stay put", a binding row, so it needs the user. It also breaks every path of the layout that counts on three windows.
  - (c) Input's window, under the Report. The user's answer says "in place of Report/git".
- **O5 — `\r` and `\i` under the terminal pane.**
  - (a) `\i` moves the cursor to Input and leaves the shell shown, since Input is shown already. `\r` shows the agent pane first, as under the changes pane (D18's PD1). `\c` and `\tcn` leave the pane as it is.
  - (b) Both show the agent pane first, as under the changes pane. A shell hidden by `\i` must then be shown again with the key.
- **O6 — The key.**
  - (a) `\pt` ("pane terminal"), with `:Aineo pane terminal`, `<Plug>(aineo-pane-terminal)` and the twin `<C-\>pt` in Terminal and Insert mode (D58). It belongs with `\pa` and `:Aineo pane`.
    - Collisions are checked against every key in R5. `\p` already waits for `\pa`, so `\pt` adds no wait. Neither `\pt` nor `\pa` is a prefix of the other, and no key starts with `\pt`.
    - In Terminal mode, Neovim keeps `<C-\><C-n>` and `<C-\><C-o>` for itself (A170), and `<C-\>p` is neither.
  - (b) `\x`, a single key, with the same command and `<Plug>`.
  - (c) `\t`. Rejected: `\t` begins `\tcn`, so it would wait `'timeoutlen'` and swallow the next key, the fault D53 removed from `\c`.

**The shell**

- **O7 — Its home.**
  - (a) A new `lua/aineo/shell/`, one concern: start, wipe and stop the tab's shell terminal. `new()` gives a copy, and the module is the first tab's copy, as wave 15's homes have it (A237). The layout is handed the buffer and creates none (R2).
  - (b) In the layout. Rejected: the layout creates no buffer but Input and runs no job.
  - (c) In the Claude session home. Rejected: another concern, and that home's interface is wave 15's to change.
- **O8 — The command.**
  - (a) `'shell'`, run as `:terminal` with no argument runs it, its words split as Neovim splits them. The buffer is unlisted, as Claude's terminal is (R3), and kept while hidden (`'bufhidden'` `hide`). Neovim's own handler may then wipe it on `exit` 0 (Q1), and the design expects that.
  - (b) A setting, `shell.cmd`. Nobody asked for it.
- **O9 — Its directory.**
  - (a) The folder: the directory of the editor's first aineo start (`places.working_directory`), where every tab's Claude Code runs (A241), whatever `:cd` or `:tcd` says.
  - (b) The current window's `getcwd()`, as `:terminal` takes it. After a `:tcd`, the shell would then run beside a Claude Code in another folder.
- **O10 — Its environment.**
  - (a) The editor's own, with `AINEO_CHILD=1` added, as Claude's terminal has it (R3, Q9). A `nvim` started in the shell then does not autostart aineo, and the health check's autostart line names the shell beside Claude's terminal. aineo removes nothing: it puts no `CLAUDE*` variable in the editor's environment (R4), and the user's own variables, such as `CLAUDE_CONFIG_DIR`, must reach a `claude` the user runs there.
  - (b) The editor's own, unchanged. A `nvim` in the shell would autostart aineo in the same folder and resume the folder's kept session: a second Claude Code on one session.
  - (c) The editor's own, with every `CLAUDE*` variable removed (`clear_env`, Q9). Rejected for the reason in (a).
- **O11 — The mode on arrival.**
  - (a) Every press of the key lands in the shell in Terminal mode, as `\c` lands in Claude's prompt. From a twin, the mode is left first and Terminal mode entered after (D58, A169).
  - (b) Normal mode, as `\pa` and `\g` land (D59).

**Closing**

- **O12 — The shell's end.**
  - (a) Every end shows the agent pane, then the buffer is gone:
    - `exit`, with any status. The shell home wipes the buffer once its job ends (Q2, Q3), and puts the agent pane back first, so the Report's window stays (Q8).
    - Neovim's own wipe on `exit` 0 (Q1), and `:bd!` and `:bw!` (Q4, Q5), close the Report's window before any buffer event (Q7). The layout reacts to its shell buffer's wipe by showing the agent pane, reopening the Report's window in its place.
    - Either way the cursor lands in the Report when it was in the shell's window (D59's landing). Otherwise it stays where it is.
    - `:bd` without `!` is refused by Neovim (E89, Q6), and the help says to add `!`.
  - (b) A non-zero exit keeps the buffer, with Neovim's `[Process exited n]`, until the user wipes it. Against the user's "the buffer is destroyed".
- **O13 — A tab's close and the quit.**
  - (a) A tab's close stops its shell (`jobstop()`) and wipes its buffer, with the tab's other copies, before its Claude Code's stop, which waits. That covers T66's close by Neovim's commands (A251) and T67's `\Q` (A250). The quit adds nothing: `:qa` does not refuse a running shell (Q11), and Neovim hangs it up after aineo's `VimLeavePre` stop of Claude Code (Q12).
  - (b) Also stop every shell in `VimLeavePre`. That gains nothing over Q12.
- **O14 — Health and help.**
  - (a) `:checkhealth aineo` lists `\pt` and `<C-\>pt`, and says which shell the pane runs (`'shell'`), with a warning when it is not executable.
    - The help gains the terminal pane in *Panes*, `:Aineo pane terminal` in COMMANDS, the `<Plug>` and `aineo-\pt` in MAPPINGS, the twin in *aineo-terminal-keys*, and the lines in HEALTH CHECK.
    - LIMITS gains `The terminal pane ~`: `:bd` needs `!`; a `nvim` in the shell does not autostart; the next start does not bring a shell back; and the quit ends it as Neovim ends every terminal.
  - (b) The keys alone.

## Checks for the user

After T70 is released.

- **M1.** Press `\pt`, run a command, then `\pa`, then `\pt` again. Is it the same shell, with the command's output, in Terminal mode?
- **M2.** Type `exit` in the shell. Does the Report come back, with the cursor in it, and the right column at its usual sizes?
- **M3.** With two tabs (`\T`), press `\pt` in each. Is each tab's shell its own?

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T69 | T69 | `neovim-lua-developer` / sonnet | `lua/aineo/layout/init.lua`; a new `lua/aineo/shell/`; new `tests/test_layout_terminal_pane.lua`, `tests/test_shell.lua`; `tests/test_layout_panes.lua`, `tests/test_layout_copies.lua` where a pin moves | no | no | O4, O5, O7–O10, O12 | held |
| T70 | T70 | `neovim-lua-developer` / sonnet | `plugin/aineo.lua`, `lua/aineo/health.lua`, `doc/aineo.txt`; a new `tests/test_entry_terminal_pane.lua`; the entry, health and doc suites where a pin moves | no | no | O6, O9–O11, O13, O14 | held |

**Rule 1, dependencies.** ✓ T69 rests on T60 (the layout's copies) and on T66's model, which is merged first. T70 rests on T69, and on T66–T68 for the tab's close and its keys.

**Rule 2, files.** ✓
- T69 touches only the layout home, a new home and their tests. T67 touches `plugin/aineo.lua`, `lua/aineo/claude/agents.lua`, `lua/aineo/health.lua`, `doc/aineo.txt` and the entry suites. T68 touches `plugin/aineo.lua`, `lua/aineo/claude/init.lua`, `lua/aineo/tabs/`, `doc/aineo.txt` and its suites. T69 shares none of them.
- T70 shares `plugin/aineo.lua`, `lua/aineo/health.lua` and `doc/aineo.txt` with T67 and T68, so it runs after both (O1).

**Rule 3, schema.** None. The shell keeps nothing on disk. ✓

**Rule 4, dependencies.** None. ✓

**Rule 5, decisions.** ✓ once ruled. The third pane, its persistence, its close and one per tab are the user's. O1–O14 are the orchestrator's to rule.

**Rule 6, task lines.** ✓ Each packet holds its mark and writes a `## Task lines` section in its session note. The knowledge pass marks each line after its merge.

## Host and reviewers

| packet | implementer | reviews | session note | resource | branch |
|---|---|---|---|---|---|
| T69 | `neovim-lua-developer`, sonnet | attack by `neovim-lua-reviewer` (Opus); tests and records by one `records-reviewer` (Sonnet); one fix round; the orchestrator's check | `Sessions/<date> — T69 Terminal pane.md` | `impl_t69_terminal_pane` | `feature/t69-terminal-pane` |
| T70 | `neovim-lua-developer`, sonnet | as T69 | `Sessions/<date> — T70 Terminal pane key.md` | `impl_t70_terminal_pane_key` | `feature/t70-terminal-pane-key` |

`<date>` is the dispatch date, which the dispatch message gives.

## Verification mutants

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks, and on the whole suite only when it survives there.

**T69** (on `tests/test_layout_terminal_pane.lua`, `tests/test_shell.lua`):
1. The layout's wipe handler dropped. After `:bwipeout!` of the shown shell, the right column has one window, with no Report.
2. The agent pane not put back before the shell home's wipe. After `exit 3`, the Report's window is a new window, not the one that showed the shell.
3. `AINEO_CHILD` left out of the shell's environment. `$AINEO_CHILD` in the shell is empty.
4. `new()` returning the module's copy. A second copy's `start()` gives the first copy's buffer.
5. The terminal pane's Input taken as the agent pane's buffer in the in-place check. Asking for the terminal pane while it shows switches the windows again and moves Input's view.

**T70** (on `tests/test_entry_terminal_pane.lua`):
1. The key starting a new shell every time. A second `\pt` shows another buffer, and the first shell's output is gone.
2. No Terminal mode after `\pt`. The mode after the key is `n`.
3. A tab's close leaving the shell. After `:tabclose`, the tab's shell job still runs.
4. The shell started in `getcwd()`. After `:tcd` to another folder, `pwd` in a new shell prints that folder.
5. `terminal` left out of `SUBCOMMAND_WORDS`. `:Aineo pane terminal` is refused with the usage line.

## The orchestrator's rulings — 2026-10-14, before dispatch

The user told the orchestrator to finish wave 15 and this wave without waiting for answers ("finish the wave, do not wait for me. Also start the next one and move until the end..."). O1–O14 are each ruled as their recommended (a), numbered A279–A292 in order (O1 → A279 … O14 → A292): the orchestrator's assumptions under that instruction and the user's of 2026-10-06, never the user's decisions; the briefs are written for (a). Each brief's first commit re-checks it against the `dev` it starts from (T66, and for T70 T67 and T68, merged by then), as A256 did.

## Briefs

- `brief-t69-terminal-pane.md`: T69, stage 1.
- `brief-t70-terminal-pane-key.md`: T70, stage 2.

## Not in this wave

- Several shells in one tab, and a shell that a key closes without `exit` or `:bd!`.
- Bringing a shell back at the next start.
- A setting for the shell's command (O8 (b)).

## Landed

*(Written by the knowledge pass.)*
