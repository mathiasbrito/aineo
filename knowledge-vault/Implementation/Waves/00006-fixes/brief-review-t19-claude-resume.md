# Brief review: T19 rewritten (PR #69, head `b2d8893`)

**Reviewer:** `reviewer`, dimension **brief**, bound by `.claude/agents/reviewer.md` (read at `b2d8893`).
**Worktree:** detached at `b2d8893` (`git log -1`: `b2d8893 Rewrite T19's brief after its first brief review`). **Resource:** `review_brief_t19` (`prepare-worktree.sh` printed `AGENT_RESOURCE=review_brief_t19`; `prepare_project` is empty and created nothing).

**Subject:** `knowledge-vault/Implementation/Waves/00006-fixes/brief-t19-claude-resume.md`, its section in `plan.md` (`## Packet T19 — 2026-09-26`, the lines this PR adds), and `evidence/baseline-0a6b5bd.txt`.

**What was checked against what:**
- `origin/dev` is `8879268`. `git merge-tree --write-tree origin/dev eea246c` gives `0a6b5bda…`, the tree the brief names. PR #64 is open at `eea246c`; PR #68 (T17) is open at `5552de2`.
- Code facts were read at the tree `0a6b5bd` (`git archive 0a6b5bd` into `code0a6/` in this worktree's scratchpad, with `make deps`).
- `git diff --stat 8879268 0a6b5bd` is T21's alone: `doc/aineo.txt`, `lua/aineo/layout/init.lua`, `tests/test_entry_claude_exit.lua`, its session note.

**How the probes ran** (every file in this worktree's `.claude/local/orchestrator/`; no real `claude`, nothing written outside this worktree):
- `code0a6/tests/brief_probe_t19.lua`: the SR3 fallback simulated on `0a6b5bd` as the first review did it — the layout open around a `ready` fake, its job stopped, then `require('aineo.claude').start_session()` called outside the composition root. 7 cases.
- `code0a6h/`: a second copy of `0a6b5bd` with a **prototype of SR3 and its hand-off** (below, T19b-R1), and `tests/brief_probe_t19h.lua`: the fallback taken for real from Claude Code's exit, through `\o`, for five variants of the hand-off. 21 cases per run.
- `code0a6m/`: a third copy with a leaked `--resume` (R2).
- `brief-uuid.lua`, `brief-wrap60.lua`: headless scripts (`nvim --clean -l`).
- Commands: `make test_file FILE=…` on the host's 0.12.5; `env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test_file FILE=…` on 0.11.6. Every probe run had `Fails (0)`, except:
  - one probe mistake, which I corrected: the S4 key `x`, typed in Normal mode once the hand-off works, raises Neovim's own E21, and the probe now records it;
  - the leak run's failures (R2). Results: `code0a6*/.tests/brief-t19*-results-*.jsonl`, summarised by `brief-summarise.py` and `brief-summarise-h.py`.
- The host's load average ran between 50 and 180 throughout.

**Labels,** as the `brief` block of `reviewer-brief.md` uses them:
- **CONFIRMED:** a statement in the brief that is false or misleading, with the check that shows it.
- **MISSING:** something the task, the boundary or a rule needs that the brief leaves out.
- **REFUTED:** a statement or worry I tried to fault and could not.
- **UNVERIFIABLE:** something I could not check, with the reason.

---

## Findings

### T19b-1. CONFIRMED (medium-high): SR3's account of what goes wrong without the hand-off is T20's tree's, not `0a6b5bd`'s. One of the three tests it prescribes is green before any hand-off, and the EX tests are green too if they reach the new terminal by `\c`.

**What the brief says** (SR3, first sub-bullet): without the hand-off "`\c` would then stay in Normal mode (T20's CT1 lost), and `:edit` in Claude's window would raise `Invalid buffer id` (D25's fault)". *Facts* › *Who holds Claude's terminal*: "T21's `M.focus()` treats Claude's window as gone and reopens the layout around `current_claude_terminal()`, whose `claude_terminal` is also stale, and so would start Claude Code a second time. That consequence is read from the code at `0a6b5bd`, not measured." The tests it prescribes: "`\c` enters Terminal mode in the new terminal; a file opened in Claude's window moves to the file column without an error; T21's EX1 and EX2 hold for the new terminal."

**Why it changed.** T21 added two checks (`git diff 8879268 0a6b5bd -- lua/aineo/layout/init.lua`):
- `redirect()` returns when its window's own buffer is wiped (`layout/init.lua:325`);
- `M.focus()` reopens the layout when its role's buffer is wiped (`:822`).

So at `0a6b5bd` the first `\c` after the fallback goes through the arrangement, `current_claude_terminal()` finds `claude_terminal` wiped and calls `started_claude_terminal()`, and `start_session()` returns the running replacement (`claude/init.lua:202–203`). That one `\c` repairs **both** holders: `claude_terminal` is set at `plugin/aineo.lua:119`, `state.buffers.claude` at `layout/init.lua:790`.

**Measured, simulated fallback (`brief_probe_t19.lua`), 0.12.5 and 0.11.6 identical:**

| after the fallback, no hand-off | observed | the brief says |
|---|---|---|
| windows | `terminal, report, input`; old buffer invalid; Claude's window shows the new terminal | ✓ (the wipe handler leaves it) |
| `\c` from Input | `current = terminal`, mode **`t`**, starts **2 → 2** | "stays in Normal mode"; "start Claude Code a second time" ✗ |
| `:edit f.txt` in Claude's window, before any focus | windows `f.txt, report, input`: the file **stays in Claude's window**, the new terminal hidden; `v:errmsg` empty, nothing notified | "`Invalid buffer id`" ✗ (the fault is a different one) |
| then `\c` | windows `terminal, f.txt, report, input`, mode `t`: repaired | — |
| the replacement exits before any focus, then `\c` | starts **2 → 3**, a new session in Claude's window, mode `t`; the replacement's exit is gone | ✓ only in this case |
| control, no fallback: the session exits, then `\c` | starts 1 → 1, mode `nt`, the exit on screen | — |
| entered with a window command and `i`, then the replacement exits | mode **`t`** (EX1 lost); the next key wipes it and Claude's window stays on an empty buffer (EX2's fault), no error | ✓ |
| entered with `\c`, then the replacement exits | mode `nt`: EX1 holds | — |
| `i` on the ended replacement, no `\c` before | mode `t`: T21's refusal lost | — |

The same results came from the prototype that takes the fallback for real from Claude Code's exit (variant `none`, both versions; T19b-R1).

**Why it misleads.** Under `tdd` the implementer writes each test and expects to see it fail.
- The `\c` test is green before any hand-off. It turns red only for the composition root's half alone: with the layout following and `claude_terminal` not, `\c` gives `nt` (mutant `layout-only`, below).
- The EX1 and EX2 tests are green before any hand-off whenever they reach the new terminal by `\c`, which is the natural way to write them. EX1 was measured. EX2 follows from the same repair, since after `\c` the layout holds the new terminal, as the `:edit` row shows.
- The `:edit` test is red, but not with the error the brief names. An implementer who asserts "no error" as its red would stay green.
- The brief names the second start as the consequence while the replacement runs. It happens only once the replacement has exited before any focus.

**Correction.** Replace SR3's sentence "`\c` would then stay in Normal mode … (D25's fault)." with:

> Measured on `0a6b5bd` with a simulated fallback (this brief's review, both versions): the first `\c` repairs both holders, since T21's `M.focus()` reopens the layout when its buffer is wiped (`layout/init.lua:822`) and `start_session()` returns the running replacement. Until a `\c`, the layout and the composition root hold the wiped terminal:
> - a file opened in Claude's window stays there, hiding the new terminal, because `redirect()` gives up on a wiped buffer (`:325`), without an error;
> - the new terminal entered any other way (a window command, then `i`) loses EX1 and EX2: Terminal mode stays at its exit, the next key wipes it, and Claude's window stays on an empty buffer;
> - `i` on the ended replacement is not refused;
> - if the replacement exits before any focus, `\c` starts another Claude Code (a third) instead of showing its exit.

Replace the test list with:

> **Test, after the fallback, before any `\c`:**
> - a file opened in Claude's window moves to the file column;
> - the new terminal entered with a window command and `i` returns to Normal mode as its process ends (EX1), and is closed by a wipe as EX2 says;
> - `i` on the ended replacement is refused;
> - the replacement exits, then `\c` shows its exit in Normal mode and starts nothing.
>
> And `\c` enters Terminal mode in the new terminal. That test is green before any hand-off, since `\c` repairs both holders. It turns red only when the layout follows and the composition root does not. Build the layout's half first to see it red.

Replace the *Facts* sentence "…and so would start Claude Code a second time. That consequence is read from the code at `0a6b5bd`, not measured." with: "…`start_session()` returns the running replacement, and both holders are repaired. Only once the replacement has exited does that `\c` start another Claude Code (measured, this brief's review)."

### T19b-2. CONFIRMED (medium): the boundary contradicts itself. "Not `start_up` or what it reaches" forbids `started_claude_terminal()`, which the same bullet allows.

`start_up()` (`plugin/aineo.lua:463`) → `open_after_dashboards()` (`:480`) → `open_unless_session_restored()` (`:453`) → `run(open)` (`:437`) → `open()` (`:164`) → `started_claude_terminal()`, `arrangement()` and `keep_input_draft()` → `kept_places()` (`:166–167`, `:98`). So "what `start_up` reaches" includes every function T19 needs, `started_claude_terminal()` and the `kept_places()` it reads among them. It also forbids the second route SR3 offers ("routing the fallback through the composition root's own start", which is `open()`).

The clause is T12's, copied from `brief-t12-claude-numbers.md:87`. For T12's tables it made sense; here it contradicts the allowed lines.

**Correction.** Replace "— not the subcommand, action or key tables (T12 follows you there), and not `start_up` or what it reaches" with:

> — `started_claude_terminal()`, the settings it passes, the declaration of `claude_terminal` and its readers `current_claude_terminal()` and `can_type_to_claude()`, and nothing else: not the subcommand, action or key tables (T12 follows you there), not `open()`, `focus()`, `arrangement()`, `kept_places()` (read it, do not change it), `run()` or the autostart's functions.

### T19b-3. CONFIRMED (medium): the second route, "routing the fallback through the composition root's own start", does not by itself reach the layout's holder. It needs `open()` or `arrangement()` outside the allowed lines, and, done as `\o` does it, it moves the user to the layout's tab.

- The Claude home cannot call the composition root. Either route needs a callback in the settings. Re-running `started_claude_terminal()` from that callback updates `claude_terminal` only; the layout keeps the wiped terminal (mutant `root-only` below: `:edit`, EX1 and the `i` refusal all fail).
- To reach the layout without the named entry point, the callback must call `require('aineo.layout').open(…)`. That needs `arrangement()`, which is declared after `started_claude_terminal()` (`:150` against `:116`) and so is not in its scope, or a copy of it.
- **Measured** (prototype variant `open`, both versions): the fallback taken while the user is in another tab (`:tabnew` right after `\o`) moves them to the layout's tab. `tabpagenr()` goes 2 → 1. The entry-point variant leaves them in tab 2. `M.open()`'s restore also reopens any closed window of the layout (`layout/init.lua:789`, `:795`).

**Correction.** Drop "— or by routing the fallback through the composition root's own start", or replace it with: "Routing it through `\o`'s path (`layout.open()`) instead moves the user to the layout's tab and reopens windows they closed; it is not wanted."

### T19b-4. CONFIRMED (low-medium): the message wraps in Claude's usual column, not only while the file column is open, and never in the entry suites' child.

The brief ties the wrap to "Claude's column is 39 columns on a 120-column screen while the file column is open". Without the file column, Claude's column is half the screen (`layout/init.lua:160`): 60 columns on a 120-column screen.
- **Measured** (`brief-wrap60.lua`, 0.12.5 and 0.11.6): at 60 columns the 75-character message is two rows, `"No conversation found with session ID: 0f9e7c2a-1b3d-4e5f-8a"` and `"9b-0c1d2e3f4a5b"`.
- The message wraps on any screen narrower than 150 columns.
- The entry suites' child is 240 columns (`tests/helpers/entry.lua:14`), so Claude's column is 120 there. A plugin-level test never sees the wrap unless it narrows the screen.

**Correction.** Replace the parenthesis with: "(measured at 40 and 60 columns: Claude's column is half the screen, 60 columns on a 120-column screen, and a third, 39, while the file column is open; the message wraps on any screen narrower than 150 columns, but not in the entry suites' 240-column child — a test of the wrap narrows it)".

### T19b-5. MISSING (low-medium): a kept id that is not an id.

The kept-id file can hold something other than a valid id: an empty file, or a write cut short. The draft home's own suite pins writes that fail after truncating and writes cut short (`tests/test_draft.lua:164`, `:196`, T14's F1).
- D23 records Claude Code 2.1.283's `-r, --resume [value]` as "opens a picker when given no value". An empty kept id passed as `--resume ''` is unmeasured and may open that picker.
- A malformed one may print an error other than SR3's. Then SR3 says "Any other exit shows as today … and the kept id stays", so every start in that directory fails the same way, for good.

**Correction.** Add to SR2: "Only an id of the form SR1 pins is resumed. A kept file that holds anything else counts as no session (SR1), and is replaced. Write the id whole or not at all, as the draft home writes its file." Add the plan mutant "a kept file holding an empty or malformed id passed to `--resume`".

### T19b-6. MISSING (low-medium): a reading is not named. After SR3, a user who was in Claude's prompt is left in Normal mode in the new session.

**Measured** (prototype, every variant, both versions): `\c` right after `\o`, before the resume fails. After the fallback the cursor is in the new terminal in mode `nt`.
- T21's EX1 ended Terminal mode as the failed terminal's process ended (`layout/init.lua:578–582`), and nothing enters it again.
- The user's next keys are then Normal-mode commands on a live prompt.

T21 named that reading for a real exit (brief-t21, line 38). For SR3 no exit is left on screen, which is EX1's reason.

**Correction.** Add to the readings: "after SR3's fallback the user is in Normal mode in the new terminal, even when they were typing in the one that failed (T21's EX1 at its exit); `\c` puts them in the new prompt". Or specify the opposite as a behaviour, with its test.

### T19b-7. CONFIRMED (low): records. The user's first words differ from D23's record; D23 is not "quoted whole"; and one sentence of SR3 credits the user with the orchestrator's reading.

- The brief quotes "also I want the plugin to remmeber the last session that was opened, and when reopening to load the session.". D23 (`Planning/aineo — v1 agent console.md:60`) records "I want the plugin to remmeber the last session that was opened, and when reopening to load the session". At most one is verbatim. The first brief had the same text. The first review marked the user's exact words UNVERIFIABLE, and so do I; the two records still disagree.
- The commit message and the plan say "D23 is quoted whole". The brief quotes neither D23's decision nor its rationale whole.
- SR3 says "The user chose this over falling back to the folder's last conversation". The user rejected the folder's last conversation as a fallback. That the fallback is a *new session* is the orchestrator's reading, which reading 1 says.

**Correction.**
- Quote the request as D23 records it, or quote D23's row verbatim in *What was decided already*.
- In the plan's T19 section, change "D23 is quoted whole" to "D23's options are quoted as D23 records them".
- In SR3, change "The user chose this over …" to "The user rejected falling back to the folder's last conversation (D23's options not chosen); the new session is the orchestrator's reading (below)."

### T19b-8. MISSING (low): the lint refuses the `bit` global that the id's version and variant bits invite.

`neovim.yml` (the selene standard) has no `bit`. **Measured:** `selene` on a file with `bit.bor(bit.band(b, 0x0f), 0x40)` gives 2 × `error[undefined_variable]: 'bit' is not defined`. `require('bit').bor(…)` and plain arithmetic (`b % 16 + 0x40`) pass. `neovim-lua-developer.md:24` says "use `bit`".

**Correction.** Add to SR1: "`make lint` refuses the global `bit`: use `require('bit')`, or arithmetic".

### T19b-9. CONFIRMED (low): three small inconsistencies.
- The *Facts* list states point 4, "the `Makefile` also removes the kept ids at the start of a run", as one of the four measures. The boundary says "the `Makefile`, only the clean-up at the start of a run, **if you choose it**". Make both say the same: required, or optional.
- *The documentation this change invalidates* names the Claude home's docstrings and the help. It leaves out `started_claude_terminal()`'s and `claude_terminal`'s docstrings (`plugin/aineo.lua:104–115`), which a settings callback changes.
- *Who holds Claude's terminal* lists the readers of `state.buffers.claude`. It leaves out `redirect_when_file()` (`layout/init.lua:348`) and `M.focus()`'s check (`:822`), the reader that repairs both holders (T19b-1).

---

## T19b-R. REFUTED: statements and worries tried and not faulted

### R1. The widened boundary is enough for the hand-off, by a callback in the settings and one layout entry point, and T21's handlers then hold for the new terminal.

A prototype in `code0a6h/` (not for adoption; built to measure the boundary):
- **`lua/aineo/claude/init.lua`**, `launch()`'s `on_exit`: on exit code 1 with "No conversation found" in the terminal's rows, joined, schedule `M.start_session(settings with fallen_back = true)`, then call `settings.on_new_terminal(buffer)`.
- **`plugin/aineo.lua`**, inside `started_claude_terminal()`'s settings only: `on_new_terminal = function(buffer) claude_terminal = buffer; require('aineo.layout').take_claude_terminal(buffer) end`.
- **`lua/aineo/layout/init.lua`**, one function: `M.take_claude_terminal(buffer)` sets `state.buffers.claude = buffer` once the layout has been opened.
- **`tests/helpers/fake_claude.lua`**: under a probe variable, the first start prints the message and exits 1.

Every line is inside *You may touch*. The fallback was taken in every one of the 87 recorded cases: 66 on 0.12.5 and 21 on 0.11.6. No record shows a single start.

Results, identical on both versions (S2–S5 before any `\c`; ✓ is the behaviour T21 and D25 want):

| variant (literal edit in `on_new_terminal`) | S1 `\c` → `t` | S2 `:edit` moves the file | S3 replacement exits, `\c` starts nothing | S4 EX1, entered by window + `i` | S5 `i` refused on the ended replacement | S7 tab kept |
|---|---|---|---|---|---|---|
| `entry`: both holders | ✓ | ✓ | ✓ (`nt`, 2 starts) | ✓ (`nt`) | ✓ | ✓ |
| `none`: `return` at once | ✓ (green before) | ✗ | ✗ (3 starts) | ✗ (`t`, then empty window) | ✗ | ✓ |
| `layout-only`: `claude_terminal = buffer` skipped | **✗ (`nt`)** | ✓ | ✓ | ✓ | ✓ | ✓ |
| `root-only`: entry point not called | ✓ | ✗ | ✓ | ✗ | ✗ | ✓ |
| `open`: `layout.open()` in place of the entry point | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ (tab 2 → 1) |

`layout-only` and `root-only` ran on 0.12.5 only.

What T21's code does **during and after** a `replace_terminal()` (`claude/init.lua:71–79`), read at `0a6b5bd` and measured above:

| handler | during the replacement | after it, while the layout holds the wiped terminal |
|---|---|---|
| `TermClose`: `remember_claude_exit()`, `leave_terminal_mode_as_claude_exits()` (`:589`, `:578`) | the failed terminal's exit is remembered; Terminal mode ends if it was current (T19b-6) | the replacement's exit is ignored: EX1 lost |
| `BufWinEnter`: `redirect_when_file()` | the new terminal is not a file: nothing | a file in Claude's window is scheduled, then `redirect()` gives up (`:325`) |
| `BufWipeout`: `close_claude_window_when_wiped()` (`:647`) | the window shows the new terminal: it is left, no error (the brief's statement ✓) | the replacement's wipe is ignored: the window stays on an empty buffer |
| `TermEnter`: `refuse_terminal_mode_once_claude_exited()` (`:614`) | — | not refused on the ended replacement |
| `M.focus()`'s wiped-buffer check (`:822`) | — | the first `\c` reopens around `current_claude_terminal()` and repairs both holders; a second start only if the replacement has ended |
| `show_buffers()`, `reopen_closed_windows()` (`:556`, `:519`) | — | run only inside `M.open()`, after `:790` has taken the new buffer: they never see the wiped one |

### R2. The leak remedy's four points: every existing case stays green with a leaked `--resume`.

**Read:** the only readers of the fake's arguments outside `tests/test_claude.lua` are:
- `test_entry.lua:109`, `:121` and `:133`. Each reads the words after its own flag, and `words_after()` stops at the next `--` word (`tests/helpers/claude_session.lua:271–289`).
- `test_entry_claude_exit.lua:175`, the deaf fake, whose `argv` is always `[]`.

Nothing else pins the count. No test globs the suites' shared state directory: `test_draft.lua:439` globs a state directory of its own, through the draft home alone.

**Measured** (`code0a6m/`: `claude_arguments()` given `'--resume', '0f9e7c2a-1b2c-4d5e-8f90-123456789abc'` before `--mcp-config`, so every start of every case carries a leaked `--resume`; 0.12.5, one file at a time; every file that starts a Claude session):

| file | cases | Fails |
|---|---|---|
| `test_entry.lua` | 47 | 3 in the loop, under a load of about 75: the two Send cases (nothing received) and the startup-prefix case (a `log: … not accessible` line, the copy's first run). Re-run alone: 3 of 3 pass. Re-run whole: **0** |
| `test_entry_claude_mode.lua` | 12 | 0 |
| `test_entry_claude_exit.lua` | 61 | 0 |
| `test_entry_draft.lua` | 17 | 0 |
| `test_entry_report.lua` | 4 | 0 |
| `test_entry_startup.lua` | 28 | 0 |
| `test_health.lua` | 78 | 0 |
| `test_send.lua` | 32 | 0 |
| `test_claude.lua` | 71 | 1: the flags pin (`:180`), `--resume` in the flag list, as expected; T19 updates it |

The four points hold, with one inconsistency (T19b-9, point 4).

### R3. The id.
- **`vim.uv.random(16)`** returns a 16-byte string on 0.12.5 (LuaJIT 2.1.1788856981) and 0.11.6 (LuaJIT 2.1.1741730670), with `flags` omitted, `nil` or `{}`, and with a callback (`brief-uuid.lua`).
- **The form is a valid version-4 UUID.** Read at RFC 9562:
  - §4.1: variant `1 0 x x`, hex `8-9,A-B`;
  - §4.2: version `0 1 0 0`, 4;
  - §5.4: "The 4-bit version field … set to 0b0100 (4)", "The 2-bit variant field … set to 0b10";
  - §4: the letters "may be all uppercase, all lowercase, or mixed case".

  Ids built as SR1 says match `^%x{8}-%x{4}-4%x{3}-[89ab]%x{3}-%x{12}$` on both versions, and two in a row differ.
- **`math.random` is not seeded.** Its first draw is `0.79420629243124` in every run on both versions: two on 0.12.5 and two on 0.11.6.

### R4. Cited lines at `0a6b5bd`, each read.
- **The Claude home:**
  - `aineo.claude.Settings` at 12–17;
  - `replace_terminal()` at 71–79;
  - `launch()` at 154, the command at 156–157;
  - `start_session()` at 200;
  - `session_status()` at 224.
- **The composition root:**
  - `kept_places()` at 63, `stdpath('state')`;
  - `claude_terminal` at 107;
  - `started_claude_terminal()` at 116, set at 119, settings at 119–125, `cwd = vim.fn.getcwd()`;
  - `current_claude_terminal()` at 135–140;
  - `can_type_to_claude()` at 199–202.
- **The layout:**
  - `redirect()` at 319;
  - `build()` sets `state.buffers` at 511;
  - `reopen_closed_windows()` at 519, reading at 522;
  - `show_buffers()` at 556;
  - T21's handlers at 579, 590, 617, 648;
  - `M.open()` sets it at 790.
- **Naming and precedents:**
  - `records.lua` 24–35 (the docstring and body are 23–37);
  - `draft/init.lua:83`, `set_draft_environment()` at 348;
  - `arguments.lua`'s docstring on `--allowedTools` last (18–25).
- **Tests and the `Makefile`:**
  - `test_claude.lua:175–185`, with `#arguments == 7` at 184;
  - `test_entry.lua:109`, `:121`, `:133`;
  - `test_entry_report.lua:83`, `:108`;
  - `test_plugin.lua:6–8`;
  - `Makefile:38`, `:72`, `:79`, `:86`.
- **The fake and the help:**
  - the fake's first record line `{ argv, cwd, env, pid }`, and no "session" or "resume" in it;
  - `:checkhealth` runs `claude.cmd --version` only (`doc/aineo.txt:445–446`);
  - Claude's column a third, `floor((columns − 2) / 3)`, 39 at 120 (`layout/init.lua:156`).
- **Records:** MR125 is "A draft for every working directory is kept, never removed." T14's note has *Limits* ("not between cases", line 368) and I2 (line 162).
- **Q8 against its evidence file:**
  - A: 2.1 s, exit 1, no screen of its own;
  - G: 1.4 s;
  - F: no conversation;
  - C: "Error: Session ID <id> is already in use.", 0.3 s;
  - D: continues the same id;
  - E: two `--resume` of one id, 8 s apart, neither refused, no message sent;
  - not measured: "existed and is gone".

### R5. The help's two ranges and T17.
- Both quoted boundaries exist at `0a6b5bd`:
  - `Input's draft ~` at 91, with `were opened until \`\o\` restores the layout.` at 89 and a blank line at 90;
  - `aineo starts Claude Code with three additions of its own:` at 318, to `  mcp__aineo__report\`.` at 324.
- T17's help hunks (`8879268..5552de2`) are at dev 354, 357–361 and 391 (`Links ~` and the colour groups). T19's list is at dev 307–313, 40 lines above them.
- **Merged:** a T19-shaped edit on `0a6b5bd`'s help (a new `Claude's session ~` above `Input's draft ~`; "four additions" and a fourth bullet after line 324), `git merge-file` against base `8879268` and T17's `5552de2`, exit 0, no conflict.
- T17's other files are `lua/aineo/report/{buffer,colours,init,paths,render}.lua` and `tests/test_report_paths.lua`. They are disjoint from T19's boundary. T17 does not change `records.lua`, which the brief cites.

### R6. The baseline.
- `MiniTest.collect` over `tests/**/test_*.lua` at `0a6b5bd`: 33 files, **1074 cases**, as the evidence says.
- `stylua --check` and `selene` over `lua plugin scripts tests/helpers tests/test_*.lua`: rc 0, 0 errors.
- `Fails (0)` is attributed to the orchestrator's verification of PR #64, which is correct; I did not re-run the whole suite (the host was loaded, and the brief asks for one suite at a time).
- `origin/dev` is `8879268`, the evidence's base.

### R7. The first review's findings, answered.

| finding | answered? |
|---|---|
| T19-1 the hand-off | Yes in substance: the boundary grows, and the route by callback and entry point works (R1). But its stated consequences and tests are T20's tree's (T19b-1), a clause of the boundary forbids it (T19b-2), and the second route is incomplete (T19b-3). |
| T19-2 the leak | Yes: the four points, and the precedent is corrected to "an earlier run … the next run"; measured in R2. |
| T19-3 not `.jsonl` | Yes (SR1). |
| T19-4 the id | Yes: `vim.uv.random(16)`, the form, the two-editors test, and the two plan mutants. |
| T19-5 the help's list | Yes: the second range is in *You may touch*. |
| T19-6 the records | The option is now quoted as D23 has it, and the rejected alternatives are there. The first quotation still differs from D23 (T19b-7). |
| T19-7 the wrap | Yes, but only for the file column (T19b-4). |
| T19-8 timing and scope | Yes: 2.1 s and 1.4 s, one run each, 120×40, and "not measured" named. |
| T19-9 lines | Yes: 71–79; `Makefile:72`, `:79`, `:86`; T14's *Limits* and I2. |
| T19-10 the merge check | Yes: T18 has merged, and the check is against `origin/bugfix/t17-report-paths`, which exists (PR #68). |
| T19-11 two readings | Yes (readings 5 and 6). |

### R8. The readings.
Each of the seven is named as a reading, and none is a decision the user has not made:
- reading 1 rests on D23 and on the rejected folder's-last fallback;
- reading 3 rests on MR125, itself an open reading;
- reading 4 is a limit measured by Q8's E;
- reading 7 is D23's own text.

T19b-6 is an eighth that is missing.

### R9. Slots, and the records.
- **Slots:** every slot of `packet-brief.md` is present and filled — objective, facts, baseline, read-first, branch, class, model, resources, may and must-not touch, shared document, session note, scratch prefix `t19-`, decisions, budget, report path `<scratchpad>/t19-report-packet.md`. The session-note name, with `<the day you are dispatched>`, follows every other brief of this wave; no `Sessions/` note has that topic.
- **Personal data:** none in the three files. No path, login or address; "the user's login" names no one.

### R10. UNVERIFIABLE.
- That Claude Code 2.1.283 accepts a lower-case version-4 UUID from `vim.uv.random` for `--session-id`: I never run the real `claude`.
- The user's exact first words (T19b-7).
- The baseline's `Fails (0)` (R6).

---

## The six rules, recomputed from the brief (T19 against T17 PR #68 at `5552de2`, T21 PR #64 at `eea246c`, T12 `brief-t12-claude-numbers.md`)

| rule | T19 |
|---|---|
| 1 dependencies | T14 done; Q8 measured; T21 merged before dispatch (the facts are `eea246c`'s: dispatch only if PR #64 merges at that head, or re-check the cited lines) ✓ |
| 2 files | **T19 ∩ T17:** only `doc/aineo.txt`, under the section exception, and merged clean (R5) ✓. **T19 ∩ T21:** sequential ✓. **T19 ∩ T12:** `plugin/aineo.lua`, `lua/aineo/layout/`, `tests/test_layout*.lua`, `tests/test_entry*.lua`: overlapping by file, and sequential by the plan ("T19 and T12 follow T21, one at a time") ✓; T12's brief cites lines at `9af91a6` and will need re-checking after T19. **Registration files:** none; a new module under `lua/aineo/claude/` loads lazily; `test_plugin.lua:6–8` pins what loads at startup and is unaffected. The boundary's own clause is contradictory (T19b-2) |
| 3 schema | T19 alone keeps something new, a session id per directory; T17 keeps nothing new ✓ |
| 4 dependency change | none: `vim.uv.random` is built in ✓ |
| 5 undecided decision | none that is the user's; one reading unnamed (T19b-6) |
| 6 task lines | T19 at row 138; T17 at 136 and T21 at 140, each one row away; the wave holds its marks ✓ |

---

## Mutant table

The plan's mutant "the composition root's or the layout's holder left on the failed terminal after SR3", split in two and measured on the prototype, with the brief's prescribed tests and the ones T19b-1 adds:

| mutant (literal edit in the prototype's `on_new_terminal`) | `\c` → `t` (brief) | `:edit` moves (brief) | EX1 via `\c` (brief, natural form) | EX1 via window + `i` (T19b-1) | `i` refused (T19b-1) | exit then `\c` starts nothing (T19b-1) |
|---|---|---|---|---|---|---|
| no hand-off (`return` at once) | survives | killed | survives | killed | killed | killed |
| `layout-only` (skip `claude_terminal = buffer`) | killed (`nt`) | survives | survives* | survives | survives | survives |
| `root-only` (skip the entry point) | survives | killed | survives | killed | killed | survives |

\* `\c` leaves the user in `nt`, and the mode after the exit is `nt`. A test that asserts only the mode after the exit is green; one that first asserts Terminal mode after `\c` is killed, as the `\c` test is.

Every cell was measured on 0.12.5 (`brief_probe_t19h.lua`, S1–S5 and S8; S8 is "EX1 via `\c`"). The no-hand-off row was measured on 0.11.6 too, where it matches, S8 excepted: I measured that one on 0.11.6 only by the simulated fallback (`brief_probe_t19.lua`, "EX1 with `\c`": `nt`).

*Summary: 3 mutants × 6 tests. Of the brief's three tests as they would naturally be written, the `\c` test kills only `layout-only`, the `:edit` test kills the other two, and EX1 reached by `\c` kills none. The tests T19b-1 adds each kill no-hand-off, and all but the last kill `root-only`; none kills `layout-only`, which only the `\c` test catches.*

---

## Verdict

**Dispatch after corrections** T19b-1 to T19b-9, once PR #64 merges at `eea246c`.

**Would an implementer acting on this brief be misled?** Yes, on the one thing the rewrite was for. The hand-off can be built inside the boundary, and T21's handlers then hold for the new terminal (R1, measured on both versions).

But the brief describes the failure it guards against as it was on T20's tree. At `0a6b5bd` the first `\c` repairs both holders by itself. So the `\c` test, and any EX test reached by `\c`, are green before the hand-off. The `:edit` test is red, but for a reason other than the one the brief names. The second start the brief warns of happens only once the replacement has ended.

The tests together still kill each half of the hand-off (the mutant table). What misleads the implementer is which test is red before the hand-off, and why.

The single most important correction is T19b-1: replace SR3's consequences and test list with the measured ones, so that each test is red before the hand-off. Then fix the boundary's contradiction (T19b-2), without which the lines T19 needs are forbidden.

**For the other dimensions:**
- **attack:** the kept id's validity (T19b-5); SR3 while the user is in another tab or in the prompt (T19b-3, T19b-6).
- **test-integrity:** check that the hand-off's tests reach the new terminal without `\c`, and run the `layout-only` and `root-only` mutants.
- **records:** the D23 quotation and "quoted whole" (T19b-7).

## Cleanup

- **Resource:** `review_brief_t19`. `prepare-worktree.sh` printed `AGENT_RESOURCE=review_brief_t19`, and its `prepare_project` is empty, so it created nothing to release.
- **Processes:** every probe ran under `make test_file` and ended with it; each child Neovim and fake was stopped by its own test's teardown. `pgrep -f '<this worktree>/.claude/local/orchestrator/code0a6'` → `procs=0`.
- **Tracked files:** `git status --short` in this worktree is empty, at `b2d8893`, detached. Every probe file, copy and log is under the gitignored `.claude/local/orchestrator/`: `code0a6/`, `code0a6h/`, `code0a6m/`, `code0a6.tar`, `brief-merge/`, `brief-*.lua`, `brief-*.py`, `brief-*.sh`, `brief-*.txt`, `brief-t19-first.md`.
- Nothing was written outside this worktree, the real `claude` never ran, and nothing was committed or pushed.
