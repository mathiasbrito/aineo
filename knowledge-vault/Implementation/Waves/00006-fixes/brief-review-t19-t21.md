# Brief review: T19 and T21 (PR #62, head `15c7e20`)

**Reviewer:** `reviewer`, dimension **brief**, bound by `.claude/agents/reviewer.md`.
**Worktree:** `agent-acf092ba79e6de0a1`, detached at `15c7e20` (`git log -1`: `15c7e20 Plan T19 and T21: resume per folder, and Claude's exit`). **Resource:** `review_brief_t19_t21` (`prepare-worktree.sh` printed `AGENT_RESOURCE=review_brief_t19_t21`; `prepare_project` is empty and created nothing).

**What was checked against what:**
- Code facts were checked against `617e4a5`. `git diff --stat 617e4a5 525b22b -- lua plugin tests doc Makefile scripts` is empty. `git merge-tree --write-tree 6e5e6ce 617e4a5` gives `525b22bb…`, the tree the baseline names.
- `git diff --stat 6e5e6ce origin/dev -- . ':!knowledge-vault'` is empty, so `dev` (`d4eacdf`) has moved by vault commits only.

**How the probes ran:**
- Where: a `git archive 617e4a5` copy at `.claude/local/orchestrator/code617/` in this worktree, with `make deps`.
- Files:
  - `code617/tests/brief_probe_t21.lua` and `brief_probe_t21b.lua`: mini.test cases that record what they observe;
  - `brief-order.lua`, `brief-wrap.lua` and `brief-rand.lua`: headless scripts.
- Command: `make test_file FILE=…` on 0.12.5, and `env PATH=<builds>/nvim-0.11.6/…:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test_file FILE=…` on 0.11.6. Every run had `Fails (0)`, except one probe mistake that I corrected: `child.lua` cannot run while `f` waits for its character.
- Results: `code617/.tests/brief-results-*.jsonl`.
- No real `claude` was run, and nothing outside this worktree was written.

**Labels,** as the `brief` block of `reviewer-brief.md` uses them:
- **CONFIRMED:** a statement in the brief that is false or misleading, with the check that shows it.
- **MISSING:** something the task, the boundary or a rule needs that the brief leaves out.
- **REFUTED:** a statement or worry I tried to fault and could not.
- **UNVERIFIABLE:** something I could not check, with the reason.

---

## T19: `brief-t19-claude-resume.md`

### T19-1. CONFIRMED (high): SR3's replacement leaves the composition root and the layout holding the wiped terminal. `started_claude_terminal()` cannot repair the layout's side, so T19 and T21 are not independent.

**What the brief says.** SR3: "its terminal taking the failed one's place in every window that showed it, as `start_session()` does today (`replace_terminal()`)". The *Boundary* allows only `started_claude_terminal()` in `plugin/aineo.lua`, and nothing in `lua/aineo/layout/`.

**Why today's path is safe and SR3's is not.** Today `replace_terminal()` runs only inside a `start_session()` that the composition root called. The composition root then hands the returned buffer on:
- it keeps it as `claude_terminal` (`plugin/aineo.lua:119`);
- and passes it to `layout.open(arrangement(…))` (`:166`), or to the arrangement inside `focus()` (`:186`).

SR3's fallback replaces the terminal from Claude Code's exit, behind the composition root's back. Nothing then updates:
- `claude_terminal` (`plugin/aineo.lua:107`), which `can_type_to_claude()` reads (`:199–202`) and `current_claude_terminal()` reads (`:135–140`);
- the layout's `state.buffers.claude`, set only by `build()` (`layout/init.lua:502`) and `open()` (`:637`), and read by `redirect()` (`:327`), `reopen_closed_windows()` (`:513`) and `show_buffers()` (`:535`).

**Measured on `617e4a5`, 0.12.5 and 0.11.6 alike** (probe `SR3 fallback behind the composition root`). The fallback was simulated: a `ready` session was opened, its job stopped, and `require('aineo.claude').start_session()` called outside the composition root.
- After the replacement, the old buffer is invalid and Claude's window shows the new terminal: `windows = { "terminal", "aineo://report", "aineo://input" }`.
- `\c` from Input gives `current = "terminal"`, `mode = "nt"`. T20's CT1 (Terminal mode in Claude's prompt) is lost, because `can_type_to_claude()` compares against the stale `claude_terminal`.
- `:edit <file>` in Claude's window gives `windows = { f.txt, f.txt, aineo://report, aineo://input }` and `layout/init.lua:327: Invalid buffer id`. This is exactly D25's fault, and the new terminal ends up hidden behind the file.
- The state stays stale until `\o`. `\c`, `\r` and `\i` never call the arrangement while Claude's window exists (`layout/init.lua:668`).
- It also defeats T21. Any EX1 or EX2 keyed on `state.buffers.claude` will not apply to a session that SR3's fallback started.

**Correction.** Add to SR3:

> The new terminal must reach everything that held the failed one. `replace_terminal()` puts it in the windows, but the composition root keeps `claude_terminal` (`plugin/aineo.lua:107`, read by `can_type_to_claude()` and `current_claude_terminal()`) and the layout keeps `state.buffers.claude`. Keep `claude_terminal` current from inside `started_claude_terminal()`, through a callback in the settings it passes. Test that after the fallback `\c` enters Terminal mode in the new session, and that a file opened in Claude's window moves to the file column without an error.

The layout's side needs a choice from the orchestrator before dispatch. Three options:
- **(a)** T21 takes it: "when Claude's terminal is wiped while Claude's window shows another terminal, the layout takes that terminal as Claude's". This is the state `replace_terminal()` leaves, since it sets the new buffer before it deletes the old one. T19 then merges after T21, with one case for the pair.
- **(b)** T19 runs after T21, with a named layout entry point in its boundary.
- **(c)** Check before the start, so that there is no asynchronous replacement at all: does a `projects/*/<id>.jsonl` exist under Claude's configuration directory? Q8 B and F measured that the file exists after a typed session and is absent after an untyped one. This is tier 2 (observable, undocumented), like the message, and it does not cover the unmeasured "existed and is gone" case.

Today the plan says T19 and T21 run "beside each other". Under (a) or (b) they do not.

### T19-2. CONFIRMED (medium-high): the remedy for a kept id leaking between cases would not stop it, and it misstates T14's precedent.

**What the brief says.** "`make test` and `make test_file` empty the drafts there at the start of each run (`Makefile:72–79`), because a draft one case left came back in another (T14)… Give every case that starts a session a state directory of its own (…), or extend the `Makefile`'s clean-up line to the kept ids; say which you chose."

**Why option (b) does not work.** The `Makefile` removes the drafts at the start of a run: `rm` at `:79` for `test` and `:86` for `test_file`. It does nothing between cases. Its own comment (`:68–71`) and T14's I2 are about a draft *an earlier run* left. T14's note says so in *Limits*: "empty … at the start of each run, not between cases".

A draft is written only when Input changes. A kept id is written by *every* start (the brief's reading 2). So from the first case that starts Claude Code through `plugin/aineo.lua` in the checkout's directory, every later case of the same run starts with `--resume <that id>`. That happens in normal runs, not only after a failure.

**Why option (a) cannot be done inside the boundary.** Those cases live outside `tests/test_claude*.lua`. `entry.use_fake` is called 32 times in `test_entry.lua`, 11 in `test_entry_claude_mode.lua`, 10 in `test_entry_draft.lua` and 5 in `test_entry_report.lua`. Only the report and draft cases that set their own `XDG_STATE_HOME` are isolated. Those files, and `tests/helpers/entry.lua`, are outside T19's *You may touch*. T21 owns new cases in `test_entry*.lua`, and it writes them in parallel without knowing about the kept id.

**What would work** (checked against the pins):
1. The fake's default treats `--session-id` and `--resume` as inert: it records them and nothing more.
2. It models SR3 only under a variable that T19's own cases set.
3. Each of T19's cases has a state directory of its own: `stand_in_settings()` in `claude_session.lua`, or `vim.env.XDG_STATE_HOME` for plugin-level cases.
4. The `Makefile` removes the kept ids at the start of a run as well.

Every other case then runs with a leaked `--resume` and stays green:
- `test_entry.lua:109`, `:121` and `:133` read the words after their own flag;
- `#arguments == 7` is pinned only in `test_claude.lua:183`, which T19 updates;
- provided `--allowedTools` stays last.

**Correction.** Replace the paragraph with those four points. Replace "because a draft one case left came back in another" with "because a draft an earlier run left came back in the next run".

### T19-3. MISSING (medium): the kept-id file must not be a `.jsonl` file.

`tests/test_entry_report.lua:83` and `:108` assert that `glob(<state>/**/*.jsonl)` holds only the Reports' records file. Both cases start Claude Code through `plugin/aineo.lua` with their own state directory, so T19's file lands under that same directory. The file is outside T19's boundary, and T18 (PR #60) is changing it.

**Correction.** Add to SR1: "name the file with an extension other than `.jsonl`; `tests/test_entry_report.lua:83,108` pin every `*.jsonl` under a case's state directory".

### T19-4. MISSING (medium): where the random id comes from, and its form.

`math.random` is not seeded. Every Neovim draws the same sequence:
- `0.79420629243124 45799` from `nvim --clean -l`, three runs on 0.12.5 and two on 0.11.6;
- the same from `nvim --headless --clean +lua…`.

A UUID built from it, or from `math.randomseed(os.time())`, is the same in every editor, or in every editor started in the same second.

Two Q8 facts make that matter:
- `--session-id` of an id already used exits 1 at once (Q8 C). Q8 measured this in one folder; across folders it was not measured.
- Claude Code's `--session-id <uuid>` wants a valid UUID. A malformed one never reaches the real `claude` in the suite.

`vim.uv.random(16)` works on both versions: it returns 16 bytes.

**Correction.** Add to SR1:

> the id is made from `vim.uv.random(16)` and written `8-4-4-4-12` in hex, version nibble 4, variant `10xx`; a test pins that form on the recorded argument, and two editors started afresh in two directories get two different ids.

Add the plan mutants "the id from an unseeded `math.random`" and "one fixed id".

### T19-5. CONFIRMED (medium): the change invalidates a help line that T19 is not allowed to touch.

`doc/aineo.txt:307` (at `617e4a5`; `:301` on `dev`) reads "aineo starts Claude Code with three additions of its own:". After T19 there are four, since `--session-id`/`--resume` is an argument aineo adds (`:270`: "aineo appends its own arguments (|aineo-report|)").

The brief lets T19 change only the new subsection, and `*aineo-report*` belongs to T18 and later T17. The brief's own instruction, "the documentation this change invalidates … Correct them in the same change", therefore cannot be followed.

T18's first changed line is `dev:315`, with at least four unchanged lines after the list (`dev:301–310`), so the edit can merge.

**Correction.** Add to *You may touch*: `doc/aineo.txt`, from "aineo starts Claude Code with three additions of its own:" to "`mcp__aineo__report`.", with the merge-tree check against `origin/bugfix/t18-report-line` (T19-10).

### T19-6. CONFIRMED (low-medium): records. The option is misquoted, and the rejected alternatives are missing.

- **Misquote.** The brief quotes the option as "…A plain-terminal conversation in the same folder is ignored; a folder where aineo never started one gets a new session." D23 records it as "…A conversation you ran in a plain terminal in the same folder is ignored. A folder where aineo never started one gets a new session." At most one of these is verbatim.
- **Missing alternatives.** The brief leaves out what the second question rejected: "the folder's last conversation by anyone" and "aineo's own with the folder's last as a fallback". The second bears directly on SR3. The user rejected falling back to the folder's last conversation (`--continue`-like), so SR3's fallback is a *new* session. The implementer should read that as the user's choice, not as the orchestrator's.

**Correction.** Copy D23's text and its rejected options into *What was decided already*.

### T19-7. MISSING (low-medium): the terminal wraps SR3's message at the window's width.

**Measured** (`brief-wrap.lua`, 0.12.5 and 0.11.6): with a window 40 columns wide, the 75-character message comes out as two buffer rows, `"No conversation found with session ID: 0"` and `"f9e7c2a-…"`.

Claude's column is a third of the screen while the file column is open (`layout/init.lua:151–159`): 39 columns on a 120-column screen. A match on the whole line, or on the line with the id, then fails.

**Correction.** Add to SR3: "the terminal wraps the message at the window's width; match across its rows, or on the prefix only".

The rest of the question is REFUTED; see T19-R1.

### T19-8. CONFIRMED (low): SR3 states more than Q8 measured.

- **Timing.** "About 2 s after it starts": Q8 measured 2.1 s (A, an id never used) and 1.4 s (G, the untyped session, which is SR3's common case), one run each. The Q8 row says "1–2 s".
- **Scope.** SR3 is titled "a kept session Claude Code no longer has", but the measured facts cover an id it *never had* (A) and an untyped one (G). Q8's own *Not measured* line names "`--resume` of an id whose conversation existed and is gone", and the brief leaves it out.

**Correction.** Write "exits 1 after 2.1 s (A) and 1.4 s (G), one run each, on the Q8 driver's 120×40 pseudo-terminal". Add "Not measured: an id whose conversation existed and is gone. SR3 assumes the same exit; name it in your note's *Limits*."

### T19-9. CONFIRMED (low): line ranges and a section name.

- `replace_terminal()` is at lines 71–79, not 71–81.
- The `Makefile`'s clean-up is `:72` (the variable), `:79` and `:86`, not `:72–79`.
- The help's two sections are 67 lines apart at `617e4a5` (`Input's draft ~` at 91, `*:Aineo-claude*` at 158), not "about 80". This is in the plan's rule-2 row.
- T14's note has no "state-directory lessons". Point to *Limits* (the leak between cases) and *Fix round*, I2.

None of these misleads.

### T19-10. MISSING (low-medium, both briefs): the merge check leaves out the one other packet that is open and edits the help.

Both briefs check against `origin/bugfix/t17-report-paths`. That branch does not exist, and T17 comes after T18. Neither brief checks `origin/bugfix/t18-report-line` (PR #60, head `d7906dd`, in its fix round). T18 edits `doc/aineo.txt` (`*aineo-report*`, hunks from `dev:312`) and `tests/test_entry_report.lua`.

T19's list of "the other packets" also leaves out T18.

**Correction.** In both briefs, add `origin/bugfix/t18-report-line` to the list of "the other packets" and to the steps "Before you push".

### T19-11. MISSING (low): two readings are not named.

- The SR3 fallback is visible. The user sees "No conversation found with session ID: …" for 1–2 s at every start that follows an untyped session, before the new one replaces it. This follows from reading 2.
- Claude's session follows `settings.cwd`, while the Reports and the draft stay with the first working directory (`kept_places()`). SR4 states the behaviour; the reading should say the two can diverge after `:cd`.

### T19-R. REFUTED: statements and worries tried and not faulted

1. **The fake can model SR3, and a test can tell SR3's exit from another.**
   - The message is in the terminal buffer at `TermClose` and at `on_exit`: 8 of 8 runs, for both an `sh` writer and an `nvim -l` writer, on 0.12.5 and 0.11.6.
   - `TermClose` fires before `on_exit`: 5 of 5 runs on each version (`brief-order.lua`).
   - Exit code 1 alone cannot tell SR3's exit apart: Q8 C also exits 1. The text, read across the terminal's rows, can.
2. **SR3's fallback follows from what was measured.** G shows that `--resume` of an untyped session always fails. Without a fallback the kept id stays, so every `\o` would resume it and fail again. D23's "a folder where aineo never started one gets a new session", and the user's rejection of the last-conversation fallback (T19-6), both point to a *new* session.
3. **Facts that held at `617e4a5`:**
   - `aineo.claude.Settings` at 12–17, `launch()` at 154, the command at 157, `start_session()` at 200, `session_status()` at 224;
   - `started_claude_terminal()` at 116, its settings at 119–125, `cwd = vim.fn.getcwd()`;
   - `kept_places()` at 63, `stdpath('state')`;
   - the flags pin at `test_claude.lua:174–184`, with `#arguments == 7`;
   - the fake's first record line `{ argv, cwd, env, pid }`, its modes, and `AINEO_FAKE_CLAUDE_EXIT_CODE`; `grep session\|resume` finds nothing in the fake;
   - `Makefile:38`;
   - `records.lua:24–35` and `draft/init.lua:83` (SHA-256 naming);
   - `test_entry_report.lua` sets `vim.env.XDG_STATE_HOME` to a `fixture.directory` at `:41`, `:52`, `:76` and `:96`;
   - `set_draft_environment()` at `draft/init.lua:348`, and no home calls `stdpath` itself;
   - `test_plugin.lua:6–8`;
   - `:checkhealth` runs only `claude --version` (`doc/aineo.txt:428–429`);
   - the three flags took effect interactively in wave 2 (`00002…/evidence/t2-summary.txt:16–19`);
   - MR125 is "A draft for every working directory is kept, never removed".
4. **Modularity.** The state directory can come from the composition root inside `started_claude_terminal()`: `kept_places()` (line 63) is in scope there. Its first call already happens in the same tick as `arrangement()`'s, so the memoized working directory does not change. The session itself needs no other line of `plugin/aineo.lua`, but see T19-1.
5. **The baseline.** 985 cases collected at `617e4a5`: `MiniTest.collect` over 32 files. `Fails (0)` comes from the evidence file, the orchestrator's run, which I did not re-run.
6. **UNVERIFIABLE:** that 2.1.283's `--help` lists `--session-id <uuid>` and `-r, --resume [value]` (D23), and the user's exact words in "also I want …". I never run the real `claude` and never read `~/.claude/`.

---

## T21: `brief-t21-claude-exit.md`

### T21-1. CONFIRMED (medium-high): EX1 as written does not keep D25's "no key closes the terminal".

The user was promised "aineo puts you back in Normal mode, so the exit message stays and no key closes it", and D25 says the same. EX1 tests only "the next key": "it closes nothing". Reading 2 says "a key they type then is a Normal-mode command".

**Measured** (`brief_probe_t21b.lua`, both versions): after EX1's Normal mode (`TermClose` → `:stopinsert`, mode `nt`), typing `i` `x`, or the words "fix this", wipes the terminal. The result is `terminal_valid = false`, `windows = { "", "", "aineo://report", "aineo://input" }` and the layout's error.
- `i`, `a`, `I` and `A` enter Terminal mode again on the exited terminal, and the next key closes it.
- A user who was typing when Claude Code exited keeps typing, so this is the likely path, not a corner case.

**A layout-home fix, measured on both versions.** A `TermEnter` handler that runs `:stopinsert` when the terminal's job has ended (`vim.fn.jobwait({ vim.bo.channel }, 0)[1] ~= -1`) keeps the terminal and its exit on screen. After "ix" and after "fix this" the only effect is `E21`, and the mode stays `nt`.

**Correction.** Add an EX1 bullet:

> Terminal mode is not entered again on Claude's ended terminal: after the exit, `i`, `a`, `I`, `A` or `:startinsert` there leave it in Normal mode, and typing on closes nothing.

Add a test that types `i` then a key, and the mutant "Terminal mode allowed again on the ended terminal". If this is not done, the gap is a departure from D25 and goes to the user.

### T21-2. CONFIRMED (medium): putting EX1 in the layout contradicts C3's row, which the brief tells the implementer to rest on.

- **C3** (module `lua/aineo/claude/`) carries the annotation "puts the user back in Normal mode when Claude Code exits while the user is in its prompt, D25, 2026-09-26".
- **C2** carries only "a wiped Claude terminal no longer breaks the layout, D25".
- **The brief** rests T21 on C2 and C3, forbids `lua/aineo/claude/`, and places EX1 in `lua/aineo/layout/`.
- **The rule.** Root `CLAUDE.md` says that a packet which finds the plan and its brief disagreeing reports a spec conflict. An implementer who reads C3 as instructed may stop there.
- **The user's framing.** The user was told "The fix spans two parts of the code". *Where it lives* explains the move, but neither the brief's readings nor the plan's rule-5 row names it.

**Correction.** Either move the Normal-mode annotation from C3 to C2 (records only; the decision D25 is unchanged), or add to the brief's readings, and to the plan's rule-5 row:

> EX1, which C3's row records, is written in the layout home (C2's module) by the orchestrator's choice, so that T19 can change the Claude home beside it. The C3 annotation names the behaviour, not its module.

### T21-3. MISSING (medium): negative cases for EX1, without which two plan mutants cannot die.

**Measured** (probe `EX1 handler while Input is in Insert mode`, both versions): a `TermClose` → `:stopinsert` with no guard ends the user's Insert mode in Input when Claude Code exits (`mode_at = "i"`, `mode_after = "n"`).

EX1 lists only positive cases. Reading 1 ("another terminal … keeps Neovim's own behaviour") is not something the brief requires a test for. As a result:
- the plan mutant "Normal mode forced on every terminal's exit" has no test that is expected to kill it;
- "forced on Claude's exit wherever the cursor is" is not even listed.

**Correction.** Add to EX1, as tested cases:
- Claude Code exits while the cursor is in Input in Insert mode: the mode stays;
- another terminal's process ends while the user is in Terminal mode there: Neovim's own behaviour.

Add the mutant "`:stopinsert` on Claude's exit wherever the cursor is".

### T21-4. CONFIRMED (medium-low): the account of EX2's fault leaves out the condition under which it happens, so an EX2 test can be green before any fix.

**Measured** (probes `EX2 …`, both versions, `617e4a5`):

| Wipe | Claude's window then | `\c` then |
|---|---|---|
| Key after the exit, Claude's window current, **no listed buffer** | an empty, unnamed, *listed* buffer (`buftype ''`); an extra window; `Invalid buffer id` | `mode = "n"`, still `exited` |
| Key after the exit, a file opened before (in the file column, or in Claude's window) | Neovim **closes** Claude's window; no error | `starting`, mode `t`: works today |
| `:bdelete! <terminal>` from Input | window closed; buffer invalid (so `:bdelete!` wipes a terminal, as the brief says) | works today |
| `:bdelete!` / `:bwipeout!` from Claude's window, no listed buffer | same as the first row | fails |

So the fault needs two things together: the wipe runs with Claude's window current, and no other listed buffer exists. Neovim then makes the current buffer empty instead of closing the window. T20's own `:bwipeout!`-from-Input case was green for exactly this reason (guarantee finding 1).

**Correction.** Add to EX2:

> red only when the wipe runs with Claude's window current and no listed buffer exists; from Input, from another tab, or once any file buffer is listed, Neovim closes Claude's window and today's code passes

Test both conditions.

### T21-5. CONFIRMED (low): a measurement attributed to the wrong run.

"Measured on `dev` before T20 (… finding 1, `guarantee-probe3.lua`)": `guarantee-probe3.lua` ran on T20's head `f187132`, not on `dev`. Dev's behaviour was measured by probe2's P9c and P9d, on `f187132` with T20's `startinsert` removed (M1).

**Correction.** Write: "measured on T20's head `f187132` (`guarantee-probe3.lua`); with T20's `startinsert` removed, dev's behaviour, by `guarantee-probe2.lua` P9c and P9d; re-measured by the brief review on `617e4a5`, 0.12.5 and 0.11.6".

### T21-6. CONFIRMED (low-medium): rule 2 overlaps with T18.

T21's *You may touch* includes "`tests/test_entry*.lua`, new cases". That covers `tests/test_entry_report.lua`, which T18's PR #60 modifies (4 lines). The plan's rule-2 cell for T21 checks only against T19.

**Correction.** Change it to "new cases in `tests/test_entry_claude_mode.lua`, or new files named `tests/test_entry_*.lua`; not `tests/test_entry_report.lua` (T18)". The merge check is T19-10.

### T21-7. CONFIRMED (low): "session" means different things in the two briefs.

EX2 says "the next `\c` starts a new session". Once T19 lands, that start is `--resume <kept id>`: a new Claude Code, but the same conversation. T19's brief uses "session" for the conversation.

**Correction.** Write "starts Claude Code again, in a new terminal (T20's CT1)", in EX2 and in the help lines T21 rewrites.

### T21-8. CONFIRMED (low): line ranges off by one or two.

- `redirect_when_file()` is 336–345, not 336–347.
- `reopen_closed_windows()` is 510–527, not 510–528.
- `M.focus()` is 664–675, not 664–676.

None misleads.

### T21-R. REFUTED: statements and worries tried and not faulted

1. **The layout home can meet EX1 on its own.** `:stopinsert` from a `TermClose` handler leaves Terminal mode, both called directly and through `vim.schedule`, on 0.12.5 and 0.11.6. The handler sees `mode = "t"` and the current buffer is the terminal. Afterwards the mode is `nt`, and the next `x` gives only `E21` with the terminal kept. This answers the brief's "not measured" sentence: it can now say "measured by the brief review".
2. **The layout home can meet EX2 without `plugin/aineo.lua` or `lua/aineo/claude/`.**
   - When Claude's window is closed after a wipe, `\c` goes through `layout.focus()` → the arrangement → `current_claude_terminal()` (whose `claude_terminal` is now invalid) → a new start. The result is `starting`, mode `t`, windows `{ terminal, report, input }` (the `:bdelete!`-from-Input probe, both versions).
   - So a layout that closes Claude's window when its terminal is wiped and the window no longer shows a terminal, and that never puts back an invalid role buffer in `redirect()`, reaches EX2.
   - Not measured: Claude's window as the only window of its tab, where closing it fails.
3. **What `focus()` and `current_claude_terminal()` do:**
   - Claude's window closed: the layout opens again around the terminal as it is, or around a new start once the terminal was wiped.
   - The window shows another buffer: the cursor goes there, no arrangement is made, no session starts, and the mode is Normal (`n` on the empty buffer; `nt` on a replacement terminal the composition root does not know, T19-1).
4. **Facts that held at `617e4a5`:**
   - `state` at 20–27, `has_window()` at 50–53, `redirect()` at 315–329 with the put-back at 327, `show_buffers()` at 531–538, `watch_windows()` at 547–559;
   - `focus()`, `can_type_to_claude()` and `focus_claude()` (`plugin/aineo.lua:181–217`);
   - the help at 158–164 and 166–170, quoted exactly;
   - T20's fakes, `ready` ×6, `exit` ×2 and `trust` ×2, driven with `child.type_keys`;
   - T20's note, which has *Limits* and *Readings for the MVP review*.
5. **The fault as the brief describes it** (the plain key-wipe) was reproduced on `617e4a5`, both versions. It needs the condition in T21-4.
6. **Records.** The question as put, and the three options, match D25 word for word.

---

## The six rules, recomputed from the briefs (T19, T21, T18 PR #60 at `d7906dd`, T12 `brief-t12-claude-numbers.md`)

| Rule | Result |
|---|---|
| 1 Dependencies | **T19:** T14 merged; Q8 resolved, row `:114` ✓. **T21:** T20, PR #58, **not merged yet**; the brief is conditional on it ✓, but the plan's "T20 merged ✓" is premature. **T12:** after T19 and T21 ✓ (and T13, per its own plan). |
| 2 Files | **T19 ∩ T21:** empty by name. `lua/aineo/claude/`, `tests/test_claude*.lua`, `tests/helpers/`, `Makefile` against `lua/aineo/layout/`, `tests/test_layout*.lua`, `tests/test_entry*.lua`. The help sits at 91 against 158–170, 67 lines apart ✓. **But T19-1** needs the layout (T21's). **T21 ∩ T18:** `tests/test_entry_report.lua` ✗ (T21-6). **T19 ∩ T18:** empty ✓; with T19-5 the edit is at `dev:301–310`, against T18's first change at `dev:315`, with ≥ 4 unchanged lines between. **T12:** `plugin/aineo.lua` (T19), `lua/aineo/layout/`, `tests/test_layout*.lua` and `*aineo-commands*` 158–170 (T21), so T12 follows both ✓. **Registration files:** none. A new module under `lua/aineo/claude/` loads lazily; `test_plugin.lua:6–8` pins what is loaded at startup and is unaffected. |
| 3 Schema | T19 alone persists something new (the kept id): at most one ✓. |
| 4 Dependency change | None ✓. `vim.uv.random` and `vim.fn.sha256` are built in. |
| 5 Undecided decision | **T19:** SR3's fallback is a reading, supported by D23 and by the user's rejection of the last-conversation fallback ✓. The readings in T19-11 are to be named. **T21:** EX1's module against C3's row (T21-2) is not named. D25's "no key closes it" is under-delivered (T21-1). |
| 6 Task lines | T18 137, T19 138, T20 139, T21 140; T12 131. T19 and T21 have one row between them. T18/T19 and T20/T21 are adjacent. Every packet holds its marks ✓. |

**Slots:**
- Every template slot is present in both briefs: role line, objective, facts, baseline, read-first, branch, class, model, resources, may and must, shared-document section, session note, scratch prefix (`t19-`, `t21-`), decided, budget and report.
- The session-note names are free and distinct (`… — T19 Claude resume.md`, `… — T21 Claude exit.md`). Neither is an exact filename, since the date is left open; acceptable.
- Branches: `feature/` for a new capability, and `bugfix/` against D25 ✓.

---

## Verdicts

- **T19: do not dispatch as written.**
  - T19-1 needs a choice from the orchestrator first: how the layout learns SR3's replacement terminal. That choice may reorder the wave, with T19 after T21, or extend T21.
  - Once it is made: **dispatch after corrections** T19-1 to T19-11.
- **T21: dispatch after corrections** T21-1 to T21-8, and T19-10.
  - If option (a) of T19-1 is chosen, add its EX bullet ("a Claude terminal replaced in Claude's window becomes Claude's") and move T19 after T21.

**The single most important change:** decide, before either packet is dispatched, who makes the layout and the composition root follow a Claude terminal that the Claude home replaces on its own (T19-1). Neither brief assigns it. Each packet's suite would stay green, and the combination would bring back D25's `Invalid buffer id` and T20's lost Terminal mode.

## Cleanup

- `pgrep -f agent-acf092ba79e6de0a1 | wc -l` → `0`; every probe child was stopped by `post_once`.
- `git status --porcelain` is empty, and HEAD is `15c7e20`.
- Everything I wrote is under this worktree's gitignored `.claude/local/orchestrator/`: `code617/` with its `.tests/` and probe files, `brief-*.lua`, and this report.
- `prepare-worktree.sh` created no resource to release.
