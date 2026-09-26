# Brief review — T20 (`\c` leaves you typing to Claude), PR #54

**Dimension:** brief. **Head:** `e218c50` on `knowledge/w6-t20-plan`, detached; `dev` = `2b75fc0`. **Subject:** `## Packet T20 — 2026-09-26` in `knowledge-vault/Implementation/Waves/00006-fixes/plan.md`, `brief-t20-claude-terminal-mode.md`, `evidence/baseline-2b75fc0.txt`. **Question:** would an implementer acting on T20's brief be misled?

Labels, as the `brief` block defines them: **CONFIRMED** — a statement that is false or misleading, with the check that shows it; **REFUTED** — a statement I tried to fault and could not; **MISSING** — a slot, a boundary item, a rule or a case not met; **UNVERIFIABLE** — why.

## How it was measured

- An experimental `claude` action in my worktree's `plugin/aineo.lua` (never committed, restored with `git checkout`), switchable by `vim.g.t20_variant`: `none` (dev as it is), `after` (status read after `focus('claude')`, `vim.cmd.startinsert()` unless `'exited'`, the brief's example), `before` (status read before the focus), `always` (no status check), `feedkeys` (`nvim_feedkeys('i', 'n', false)` in place of `startinsert`), `early` (`startinsert` before the focus), `jobwait` (`jobwait({channel}, 0)` before the read). Each records the status before and after the focus and `nvim_get_mode().mode` inside the callback. The patched file is kept as `brief-t20-probe-plugin-aineo.lua` beside this report.
- Probe files run with `make test_file` under the suites' isolation, one at a time, first on the host's 0.12.5, then on the downloaded 0.11.6 in the brief's literal `env PATH=… make` form, at load averages of 36–111: `brief-t20-test_t20probe.lua` (65 observations), `test_t20race.lua`, `test_t20mut.lua`, `test_t20tui.lua`, `test_t20ready.lua` — moved to this directory afterwards. Raw observations: `brief-t20-probe-{012,011}.txt`, `brief-t20-race-{012,011}.txt`, `brief-t20-race-jobwait-012.txt`, `brief-t20-mut-012.txt`, `brief-t20-tui-{012,011}.txt`, `brief-t20-ready-012.txt`; run logs `brief-t20-run-*.log`, each ending `Fails (0)` (the probes record rather than assert).
- The transcript of the orchestrator's session (`938616f1-….jsonl`, read only, lines 9082–9166) for the user's words and the question as put.

## Findings, most severe first

### F1 — MISSING, and CT2 misleading as worded: the case that decides *when* the status is read is absent

**Statement (brief, CT1 and CT2):** CT1's four cases; "CT2 — When Claude's session has ended (`require('aineo.claude').session_status()` returns `'exited'`), `\c` moves to Claude's window and stays in Normal mode."

**Evidence.** In every case CT1 and CT2 list, the status read before `focus('claude')` equals the one read after it. They differ in one case the brief does not list: **Claude Code exited and its terminal was wiped.** That is the very event CT2 guards against: in Terminal mode a key on the ended terminal wipes it and closes Claude's window (`ended_open_always_after_key`: `terminal_valid = false`, windows `{ "aineo://report", "aineo://input" }`, both versions). Then `session_status()` returns `'exited'` before the key, and `\c` starts a new session (help 162–163: "once the terminal was wiped"), `'starting'` after the focus. Measured, both versions, with the layout closed (`wiped_*`) and left open (`wiped_open_*`):

| variant | trace | mode after `\c` |
|---|---|---|
| `after` (the brief's example) | before `exited`, after `starting` | `t` |
| `before` (status read before the focus) | before `exited`, after `starting` | `nt` — Normal mode on a new session |

So the mutant "the status read before `focus('claude')`" survives every test a packet builds from CT1 and CT2 as written, and it is not among the plan's verification mutants. CT2's wording, read at the key ("when Claude's session has ended"), even asks for the wrong one here.

**Correction.**
- CT1, a fifth case: "after Claude's terminal was wiped — Claude Code exited and a key closed its terminal, or `:bwipeout!` — where `\c` starts a new session: `session_status()` reads `'exited'` before the key and `'starting'` after it."
- CT2: "When the session `\c` lands on has ended — `session_status()`, read after the focus, returns `'exited'` — …".
- The plan's verification mutants: add "the status read before `focus('claude')`".
- For the test, inside the boundary: the `exit` fake's restarted session inherits the child's environment and exits again 200 ms later, so either read the mode right after the key or call `entry.use_fake(child, claude_session.fake(…, 'ready'))` again before `\c`.

### F2 — CONFIRMED: plan verification mutant 4 is equivalent as the brief's own mechanism writes it

**Statement (plan, *Verification mutants*):** "the mode entered before the layout's focus, so it lands in the window the cursor left".

**Evidence.** `vim.cmd.startinsert()` only asks for the mode. Neovim enters it when the callback returns, in the window that is current then, which the brief itself says ("a mapping's callback and an Ex command end before Neovim acts on `:startinsert`"). Variant `early` (`startinsert` before `focus('claude')`), measured on 0.12.5 and 0.11.6 (`brief-t20-mut-{012,011}.txt`): mode `t`, window `terminal`, when pressed from Input, after a reopen, from another tab, and as a typed `:Aineo claude`. It lands in Claude's window every time, and no test can kill it.

**Correction.** Drop it, or replace it with F1's mutant (the status read before the focus), which is the ordering fault that exists. A mode entered at once, before the focus (`vim.cmd('normal! i')`), is a different edit that I did not measure. If the plan keeps a mutant of that kind, it should name that literal edit.

### F3 — MISSING: plan verification mutant 3 has no killer, and `entry.press` cannot be one

**Statement (plan):** "Terminal mode entered for `\r` or `\i` as well". **Brief:** "CT3 and CT4 are invariants" (untested); CT4: "`\r` and `\i` leave the mode as today".

**Evidence.**
- No test on the base reads the mode after `\r` or `\i`. With `vim.cmd.startinsert()` added to `focus()` for every role but `'claude'`, `tests/test_entry.lua` ran 47 cases, `Fails (0)`, and `tests/test_entry_draft.lua` 17 cases, `Fails (0)`, on 0.12.5 (`brief-t20-run-m3-*-012.log`).
- A test written with `tests/helpers/entry.lua`'s `press()`, which is `nvim_feedkeys(…, 'mx')`, cannot kill it either. `x` ends Insert mode before it returns, so the mode reads `n` after `\r` and `\i` even under the mutant (`focus_all_r`, `focus_all_i`, both versions). With `child.type_keys('\\r')` or `child.cmd('Aineo input')` it reads `i` (`focus_all_typed_*`, `focus_all_cmd_*`, both versions).
- For the terminal, `press()` does show `t`: under `x`, entering Terminal mode is deferred, not ended.

**Correction.** Either make CT4's first clause a tested behaviour — "`\r` and `\i` leave the mode as it was, checked with `child.type_keys` or `:Aineo report|input`, never `entry.press`" — or remove mutant 3 from the verification list. Either way, add the `x`-flag asymmetry to the brief's "Mind when a mode change takes effect".

### F4 — CONFIRMED: the tests fact points at the wrong file and omits the cases CT4 keeps green

**Statement (Facts):** "`tests/test_entry_prefix.lua` types the prefix keys; `tests/test_entry_draft.lua:293` runs the first `\i`, `\r` or `\c`."

**Evidence.**
- `tests/test_entry_prefix.lua` types nothing. Its cases check `maparg()` of the prefix mappings.
- The typed prefix is in `tests/test_entry.lua` › *the prefix typed* (lines 521–541), which has `\o` and `\r` but no `\c`.
- The fact's list of existing cases that run the `claude` action leaves out:
  - `tests/test_entry_draft.lua:216–253` — `\c`, then `\i`, then typing;
  - `tests/test_entry_draft.lua:274–291` — `\c` after a Send;
  - `tests/test_entry.lua:391–460` — `:Aineo claude`, including after Claude has exited, with the layout open and closed.
- Those cases are what CT4 keeps green. They stay green under the `after` variant: `tests/test_entry.lua` 47 cases and `tests/test_entry_draft.lua` 17 cases, `Fails (0)`, on 0.12.5 and 0.11.6 (`brief-t20-run-{entry,draft}-patched-*.log`). So CT4's claim holds, as R8 records, and only the pointer is wrong. After `\c`, `entry.press(child, '\\i')` from Terminal mode still reaches Input (`then_i_*`: window `aineo://input`, both versions).

**Correction.** "`tests/test_entry_prefix.lua` checks the prefix mappings with `maparg()`. `tests/test_entry.lua` › *the prefix typed* (521–541) types `\o` and `\r`, with no `\c`: a typed `\c` case belongs there or in a new file. The `claude` action already runs in `tests/test_entry.lua:391–460` (`:Aineo claude`, after an exit too), `:504–519` (`<Plug>`), and `tests/test_entry_draft.lua:216–253`, `:274–291` and `:293–305`."

### F5 — MISSING: the value Normal mode reads in Claude's window

**Evidence.** In a terminal window, Normal mode reads `'nt'` from `nvim_get_mode().mode`, not `'n'`. That holds on dev as it is (`*_none`) and under CT2 (`ended_*_after`), on both versions. A CT2 test written `eq(mode, 'n')` goes red for a reason that is not the behaviour.

**Correction.** In CT2: "stays in Normal mode (`nvim_get_mode().mode == 'nt'` in the terminal's window)".

### F6 — MISSING (a bound CT2 should state): the key and the exit can cross, and nothing the composition root reads sees it

**Evidence.**
- `\c` typed while the editor was busy as Claude Code exited: `child.lua_notify('vim.uv.sleep(1500)')`, then `nvim_input('\\c')`, with the `exit` fake.
- 6 of 6 runs on 0.12.5 and 6 of 6 on 0.11.6: the key is handled before the exit's events. `session_status()` reads `'starting'` or `'ready'` at the key, Terminal mode is entered, then `TermClose` and `on_exit` land. The next key wipes the terminal and closes Claude's window (`race_*`, `race_*_after_key`).
- `jobwait({ vim.bo[terminal].channel }, 0)` before the read changes nothing (4 of 4, `brief-t20-race-jobwait-012.txt`).
- Inside a `TermClose` handler, `session_status()` is not yet `'exited'` (`termclose`, both versions): the terminal closes before `on_exit` runs.

The editor has not processed the exit when the key runs, so this is the same case as Claude Code exiting a moment after `\c`, or under the user's own typing today. That answers the orchestrator's CT2 question. With the status read after the focus, every settled ending is told apart by `session_status()` alone: an exit with the window open, an exit with the layout closed, a wipe (R5). The one window-versus-status disagreement is this race, and it is intrinsic.

**Correction.** Add to CT2: "CT2 reads the session as the editor knows it when `\c` runs. An exit the editor has not processed yet, or one that comes after the key, leaves Terminal mode on, and the next key closes the terminal, as it does today when Claude Code exits under your typing. It is a bound: record it in the note's readings, and do not test for it." That keeps the implementer and the guarantee reviewer off an unfixable case.

### F7 — MISSING (a bound, low): a key that answers the draft's warning prompt at `\c` now reaches Claude

**Evidence.**
- A real TUI (`tests/helpers/entry_editor.lua`, 80 columns): the `drafts` path is a file, so the draft cannot be read, and the first `\c` opens the layout. `brief-t20-tui-{012,011}.txt`: `x` on both versions; `<Esc>` and Enter on 0.11.6 only.
- After `\c` the editor waits at "Press ENTER or type command to continue" (mode `r`), as it does today, then enters Terminal mode.
- A key other than Enter, Space or CTRL-C is handed on, and now reaches Claude Code: `x` → the fake received `x`, and the screen shows it typed. `<Esc>` → the fake received `ESC[27;1u`, which Claude Code may take as an interrupt. Enter → nothing is passed on.
- On dev as it is, the same `x` runs as a Normal-mode command (`E21`).

The help's promise at 121–125 ("its prompt never takes a key you type there") is about the other direction and still holds. This path is new, and the brief's CT4 ("the draft's hand-off after a reopen … unchanged") does not name it.

**Correction.** One line in CT4 naming it as a known bound for the note's readings. A fix would reach the draft home, which the class forbids.

### F8 — MISSING (for information): Claude Code now receives focus events

**Evidence.** The recorded startup `tests/fixtures/claude/startup-2.1.281.bytes` enables focus reporting (`ESC[?1004h`, 1 occurrence). Entering Terminal mode therefore sends Claude `ESC[I`, and leaving it sends `ESC[O`. The fake recorded `\27[I\27[O` around `\c` and `\i` (`then_i_*`, both versions).

**Correction.** In CT4: "Claude Code, which enables focus reporting, receives `ESC[I` when `\c` enters Terminal mode and `ESC[O` when it is left. A test that reads what the fake received after `\c` sees them."

### F9 — MISSING: rule 2's fence for the help is stated by tag and line number, not by quoted first and last lines

**Statement (Boundary):** "**Your lines** are the three entries named above and line 28."

**Evidence.**
- SKILL §3 rule 2 requires, for a vimdoc file, that the fence is stated "by each section's first and last line, quoted … (never by line number)". T10's section is given that way; T20's is not.
- `*aineo-keys*` is a tag inside section 5, not a section of its own.
- The introduction's sentence runs over lines 26–28, so rewording it reflows 27–28.
- The rule itself holds. A T20-shaped edit, lines 27–28 rewritten and 158 extended by two lines, merged with T10's head `0ec7ef5` over their base `84df4c2` by `git merge-file`: 0 conflict markers, both edits kept (`brief-t20-merge/`).
- T10's hunks sit inside `8. THE AGENT REPORT` … `the working directory of its own moment.` (lines 261–348 at `0ec7ef5`).

**Correction.** State T20's lines quoted:
- the introduction from "Every command sits behind one prefix key" to "and `\c` move to the Report, Input and Claude.";
- `*aineo-commands*` from "`:Aineo claude		Moves the cursor to Claude's terminal.`" to "an exited Claude Code." — lines 158–164, which is where CT2's "Normal mode once Claude Code has exited" belongs, beside "its exit on screen";
- the `<Plug>(aineo-claude)` entry;
- the `\c` entry.

### F10 — MISSING (records, low): the question is quoted cut short, and the rejected options are not recorded

**Evidence.**
- Transcript lines 9155 and 9156 hold the question as put: "T20: `\c` moves to Claude's window and enters Terminal mode, so the cursor sits in Claude's prompt ready to type. If Claude's session has ended, `\c` stays in Normal mode, so a keypress can't close the ended terminal. It changes `\c` in plugin/aineo.lua, where T14 is working now. How should it run?"
- The brief and the plan section quote it as "as put" and stop after "terminal.", with no mark. The dropped sentence ("It changes `\c` …") is the one that supports CT3's reading.
- Neither records the two options not chosen, which the template's *What was decided already* asks for:
  - "Regular packet, after T14" — "The full three reviews and a re-measure. Slower; the change is a few lines.";
  - "Small fix, after T12" — "T12 goes first as planned; T20 follows it."
- The user's words ("also one more feature '\c' must move to the claude window in insert mode, cursor on the prompt.") and the chosen option's label and description are verbatim.
- The diff holds no personal data: no path, name, host or address.

**Correction.** Quote the question whole, or mark the cut with "…", and list the two rejected options with their descriptions in the brief and the plan section.

### F11 — CONFIRMED (low): small imprecisions

- `session_status()` is `lua/aineo/claude/init.lua:224–235`; 236 is blank.
- "`PREFIX_KEYS` maps `c` to it": `map_prefix()` maps `\c` to `<Plug>(aineo-claude)`, whose callback runs `run(ACTIONS.claude)` inside a `pcall`.
- "(the modularity skill's direction table)": "`require()`s a home only inside a callback" is in the homes table (`SKILL.md:26`). The direction table (`:34–44`) lets `plugin/aineo.lua` require any home's entry point.
- The flaky list names "`session_status()`", which is not a file. It means the cases that wait on it.
- Rule 1's "T14, done ✓": T14 has merged (`2b75fc0`), but its row is still `active` and its *Landed* entry is not written. "merged" is the true word.
- "the docstrings of `focus()` …": `focus()`'s docstring is invalidated only if `focus()` changes. The brief's own seam leaves it alone.

**Corrections.** Replace each statement above with the fact that follows it.

## REFUTED — statements I tried to fault and could not

- **R1 — the task row.** It is quoted verbatim, as dev's task list line 138 holds it.
- **R2 — the plugin facts.**
  - `focus()` is `plugin/aineo.lua:179–189`, `current_claude_terminal()` is `:135–140`, and `ACTIONS.claude` is `:204–206`.
  - Nothing enters Terminal mode today: `*_none` reads `nt` on every path.
- **R3 — CT1 on every path it lists, and when the mode takes effect.** With the status read after the focus and `vim.cmd.startinsert()` (or `nvim_feedkeys('i', 'n', false)`), the mode reads `t` in Claude's window on both versions:
  - `\c` from Input, from the Report and from the file column;
  - `<Plug>(aineo-claude)` from another tab (tab 1 of 2);
  - `:Aineo claude` by RPC and typed;
  - after `tabnew | tabonly` reopens the layout;
  - the first `\c`;
  - on the trust dialog (`'starting'`) and at `'ready'` (reached in about 1.5 s on 0.12.5).

  Inside the callback the mode is still `nt`, as the brief says. A child test sees `t` straight after `entry.press`, `child.type_keys` or `child.cmd`, with `blocking = false`, so later RPC reads work.
- **R4 — CT2's rationale.** A key in Terminal mode on an ended terminal wipes it and closes Claude's window, on both versions.
- **R5 — CT2 read after the focus, on every settled ending.** Measured on both versions:
  - an exit with Claude's window open reads `'exited'`, mode `nt`;
  - with the layout closed, the layout reopens around the exited terminal, `'exited'`, `nt`;
  - after a wipe, a new session reads `'starting'`, mode `t`.
- **R6 — the class.**
  - `session_status()` reports `'exited'` and needs no change in `lua/aineo/claude/`.
  - The composition root may require it inside a callback.
  - An ended session needs no change in `tests/helpers/`: the fake's `exit` mode exists, and `tests/test_entry.lua:425–490` already builds ended and wiped sessions with it. The same holds for F1's wiped case.
  - One behaviour, in `plugin/aineo.lua` outside `start_up`, and no row: `\c` still moves to Claude (C1), as T16's row carries none.
  - The PR #51 records review's intake worry (a `jobwait`) does not arise, and a `jobwait` would not even help (F6).
- **R7 — CT3 is a reading, not a decision.**
  - C1 makes every command a triple: D16 and D18 both say "as for every command (C1)".
  - The help's `<Plug>(aineo-claude)` "Does what |:Aineo-claude| does".
  - The health check reports "\c runs <Plug>(aineo-claude)".
  - A Terminal mode for `\c` alone would break all three.
  - The question put to the user said "It changes `\c`".

  The brief sends it to *Readings for the MVP review*, a heading ten session notes already use. Suggestion: cite C1 and D16's "as for every command" as its ground.
- **R8 — CT4's existing cases stay green.** Under a correct implementation, measured on both versions (F4).
- **R9 — the help facts.**
  - Line 158 is in `*aineo-commands*`, lines 188–189 in `*aineo-mappings*`, lines 204–205 under `*aineo-keys*`, and line 28 in the introduction.
  - `tests/test_doc.lua` pins tags only, and T20 adds none.
- **R10 — the baseline.**
  - The evidence file reproduces `verify46.txt` lines 2–14: guard 5 cases and suite 890 cases, `Fails (0)`, on both versions, and lint clean.
  - The tree it ran on, `f217fc8`, shows no `git diff --stat` against `2b75fc0` over `lua plugin tests doc scripts Makefile`.
  - Independent run, 0.12.5 only: see *Baseline re-measured*.
- **R11 — rule 2 with T10.**
  - T10's files (PR #52, `0ec7ef5`): `doc/aineo.txt`; `lua/aineo/report/{buffer,colours,links,render}.lua`; `tests/test_report_{colours,links}.lua`; its note.
  - The only file both packets touch is `doc/aineo.txt`. Its merge is clean (F9).
  - T10 does not touch `tests/test_doc.lua`, so step 2's copy of it is a no-op. It is harmless.
- **R12 — the slots and the boundary.**
  - Every template slot is present and filled.
  - The branch `bugfix/t20-claude-terminal-mode` is free on origin.
  - The resource `impl_t20_claude_terminal_mode` passes `prepare-worktree.sh`'s pattern.
  - The session-note name is free and distinct from T10's. Its `<the day you are dispatched>` form is the wave's own and was accepted in earlier brief reviews.
  - The scratch prefix `t20-` is distinct from T10's.
  - The model, the budget and the report shape (`<scratchpad>/t20-report-packet.md`) are stated.
  - The PR title and "no commit subject says small" are both there.
- **R13 — the literal 0.11.6 command form.** I used it for every 0.11.6 run.
- **R14 — the verification mutants the brief's tests do kill.**
  - "never entered" is killed by any CT1 case.
  - "entered on an ended session too" (`always`: `t` on an ended session) is killed by the CT2 case.
  - "only when the window was already open" is killed by the reopen case, which reads `nt` on dev as it is.
- **R15 — the commit message.** It is a body with IDs, not one line, and carries its trailers.

## Six rules, recomputed from the briefs

Open packets: T10 (PR #52, `0ec7ef5`, in verification). T12 (`brief-t12-claude-numbers.md`, `plugin/aineo.lua`) waits for T20. T17 and T18 wait for T10, and T19 for Q8. The only claimed wave is `00006-fixes`.

| rule | T20 against T10 | result |
|---|---|---|
| 1 dependencies | T20 ← T14, merged at `2b75fc0` (`c53c73f` … `2b75fc0` on dev) | ✓ (the word "done" is F11) |
| 2 files | T20: `plugin/aineo.lua`, `tests/test_entry*.lua` (new cases or a new file), `doc/aineo.txt` (intro, `*aineo-commands*`, `*aineo-mappings*`/`*aineo-keys*` entries), its note. T10: `lua/aineo/report/*`, two report test files, `doc/aineo.txt` (section 8 only), its note. The one shared file sits under the vimdoc exception, and `git merge-file` is clean. Neither packet appends to a registration file, and no pin counts T20's cases (the runner globs `tests/**/test_*.lua`; `test_doc.lua` pins tags). | ✓, but the fence is stated by line number (F9) |
| 3 schema | none | ✓ |
| 4 dependencies | none (mini.nvim is pinned in the Makefile, not touched) | ✓ |
| 5 decisions | the class and the behaviour were decided by the user (transcript 9156). CT3 is a reading (R7). F1's wiped case is a reading of the user's own rationale ("so a keypress can't close the ended terminal": no ended terminal is on screen there) | ✓, once F1's reading is stated |
| 6 task lines | T20 at line 138 is adjacent to T19 at 137, so the marks are held and a `## Task lines` section is written. T10 is at 128, a gap of 9 lines | ✓ |

## Baseline re-measured

`make test` at `e218c50` (whose code is `2b75fc0`'s), on the host's 0.12.5, probes removed and `plugin/aineo.lua` restored first, load average 55–111: **Total number of cases: 890, `Fails (0) and Notes (0)`, rc=0** (`brief-t20-run-suite-012.log`). That matches the evidence file. 0.11.6 was not re-run whole, since the host is loaded; the evidence's 0.11.6 line rests on `verify46.txt`, which R10 checked.

## Verdict

**Dispatch after corrections.** Four facts in the brief are wrong or imprecise:
- the test file named in the facts (F4);
- the rule-2 fence, stated by line number (F9);
- the records: the question cut short, the rejected options left out (F10);
- the small imprecisions (F11).

The brief also leaves an implementer free to read the session's status at the wrong moment: before the focus rather than after it. No case it lists would catch that. The deciding case is the natural sequel to CT2's own scenario — Claude exits, a key wipes the terminal, `\c` starts a new one (F1). Two of the plan's five verification mutants cannot die as written. The early mode is equivalent (F2), and the `\r`/`\i` one has no test, which `entry.press` could not be anyway (F3). The mode value for Normal mode in a terminal is unnamed (F5). CT2 needs its intrinsic race stated as a bound (F6). F7 and F8 are one line each.

**The single most important change:** add F1's wiped-terminal case to CT1, read CT2 "after the focus", and put "the status read before `focus('claude')`" into the verification mutants in place of mutant 4.

Other dimensions:
- **guarantee:** re-run F1's `before` mutant and F3's mutant with `child.type_keys`.
- **records:** check that F6 and F7 are in the note's readings.

## Cleanup

- `prepare-worktree.sh review_brief_t20` printed `AGENT_RESOURCE=review_brief_t20`. Its `prepare_project` is empty, so it created no resource and there is nothing to release.
- `git status --short` prints nothing, at `e218c50 Plan T20: \c leaves the user typing to Claude`:
  - `plugin/aineo.lua` was restored with `git checkout`;
  - the probe test files were moved out of `tests/` into this directory as `brief-t20-test_t20*.lua`.
- No process started from this worktree is running: `ps -ax | grep agent-ad05f6e837e43e3d8` counts 0.
- `deps/` (mini.nvim at the pin, from `make deps`) and `.tests/` are gitignored and stay with the worktree, which is discarded. I wrote nothing outside this worktree and ran no real `claude`.
