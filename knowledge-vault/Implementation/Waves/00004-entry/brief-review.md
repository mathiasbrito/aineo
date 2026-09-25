# Brief review — wave 4, T7 entry point

*Verbatim but for paths: the home directory is written `~` and the orchestrator's scratch directory `<scratchpad>`.*

**Reviewer:** `reviewer`, dimension *brief*. **Subject:** `brief-t7-entry.md` and `plan.md` in PR #16 (head `b02ecba`). Base `origin/dev` = `bb0e185`.

**Setup:**
- Detached at `b02ecba`. `git diff --name-only bb0e185 b02ecba` touches `knowledge-vault/` only, so the code, `.claude/` and tests are `bb0e185`'s.
- `prepare-worktree.sh review_brief_w4`, then `make deps` (mini.nvim `1345d19`).
- Nothing was run against the real `claude`.

**Question:** would an implementer acting on this brief be misled by anything in it?

## Findings, most severe first

### 1. CONFIRMED (high): the `--embed` route dies about 10 ms after the test attaches its UI. No test can use it as the brief describes.

**The claim.** The brief (*How tests reach a UI-attached start*), `plan.md` l.36 and `t7-startup-summary.txt` item 2 all say the same thing. An `nvim --embed` RPC job waits for `nvim_ui_attach`, then sees a UI at `VimEnter` — "a UI-attached start without a terminal … stop it by its channel".

**What I measured.** I ran probes as `make test_file` cases, so they ran under the suite's own isolation (`.tests/brief-w4/test_embed_*.lua`).

- **F — exit code and stderr.** `--embed --clean -n`, attached at 160x42, three runs. The child exited with **code 1 at 18.8, 20.0 and 19.2 ms** after the start, with empty stderr.
- **D — lifetime.** `nvim_ui_attach` returned at 11.0 ms and the child exited 1 at 21.4 ms. The first side-channel query at +100 ms failed.
- **A — the UI channel itself.** The first `rpcrequest` after the attach fails with an empty error, and the child has exited by +500 ms.
- **B — `--listen` plus a second channel.** A query sent at once still wins the race: `did_enter=1`, `uis=1`, `columns=160`, and `stdpath('state')` under `.tests/state`. The UI channel is already gone by then (`Invalid channel: 4`).

The test's Neovim cannot take the child's `redraw` notifications, and the child ends as soon as its UI channel closes.

**The orchestrator's own evidence shows the same thing.**
- `t7-embed-out.txt` holds `VimEnter` and `UIEnter` but **no `VimEnter+1s` line**. The probe writes that line one second after `VimEnter`, and every terminal start in `t7-startup-out.txt` has it.
- My re-run of `t7-embed-probe.lua` gives the same result: no `VimEnter+1s`.
- The summary does not mention it.

**Failure scenario.** The implementer follows the recipe for EP7's positive case, EP8 (D15), M22 or M23:
- The child runs the autostart and starts the fake.
- About 10 ms later the child exits 1, taking the layout and the session with it.
- "Stop it by its channel" then fails with `Invalid channel`.

Every UI-attached test is either flaky or impossible, and M22/M23 lose the tests meant to kill them.

**The fix, measured (`test_terminal_route.lua`).** Run an interactive `nvim` in a terminal job of a mini.test child (`jobstart(…, { term = true })`, the child at 200x50), and query it over its `--listen` address through `sockconnect`. The results:
- `uis=1` and `argc=0` at `VimEnter`, with `plugin/aineo.lua` sourced;
- still alive 1.5 s later, at 200x48;
- `stdpath('state')` and `CLAUDE_CONFIG_DIR` under `.tests/`;
- exit 0 on `qa!`.

This is the route the startup driver itself used. Its helper fits in `tests/helpers/entry*.lua`, inside the boundary.

**Correct:** the brief's section, `plan.md` l.36, and `t7-startup-summary.txt` item 2.

### 2. MISSING (high, safety): nothing stops a failed UI check from running the real `claude` in every suite child.

The premises, each checked:
- **Every child sources `plugin/aineo.lua`.** The `tests/helpers/child.lua` docstring says so, and `scripts/minimal_init.lua` prepends the checkout.
- **The defaults would start `claude`.** D13 and `lua/aineo/config/init.lua:41-49` give `autostart = true` and `claude.cmd = { "claude" }`.
- **`claude` is on the suite's PATH.** `command -v claude` gives `~/.local/bin/claude`, and the `Makefile` leaves `PATH` alone.
- **A headless child counts as a bare start.** `argc()` is 0, as measured.

**Failure scenario.** Under M19 ("autostart without the UI check") or any regression of that check:
- every headless child in the suite runs `start_session({ cmd = { 'claude' } })`, which is the real CLI;
- so does the M19 test itself, unless it set `claude.cmd`.

That breaks D10 ("the real Claude never runs in the suite") and this review's own rule. The brief says "The real `claude` never runs in your packet" but gives no instruction that makes it so. The orchestrator is told to run M19 "on your final head", but not narrowed.

I did not run M19; running it would start the real CLI.

**Fix:**
- Every autostart test, the refusal tests above all, sets `claude.cmd` to the fake, so "a session started" is seen in the fake's record.
- M19 runs only against its narrowed group.
- A suite-wide default belongs in `scripts/minimal_init.lua`, which is outside the boundary. Route it as a follow-up, or open that one line to the packet.

### 3. CONFIRMED (medium): `$AINEO_CHILD` from the caller reaches every test Neovim.

- **Measured:** under `AINEO_CHILD=1 make test_file …`, both the runner and a mini.test child read `vim.env.AINEO_CHILD == "1"`.
- **Why it leaks:** `scripts/minimal_init.lua` strips only `CLAUDE*`, and the `Makefile` unexports `NVIM NVIM_APPNAME MYVIMRC VIMINIT AI_AGENT`, not this variable.
- **Where it comes from:** aineo's own Claude terminal sets it (`lua/aineo/claude/init.lua:22`).
- **When it bites:** once T7 lands, the user's editor autostarts aineo (`~/.config/nvim/lua/plugins/aineo.lua`, read only: `lazy = false`, no `opts` or `config`). An agent running `make test` inside that Claude then hands `AINEO_CHILD=1` to every child.

**Failure scenario:**
- EP7's positive tests fail for no fault in the code.
- The `--headless` test passes because of `AINEO_CHILD`, not because of the UI check, so M19 survives.

`scripts/` and the `Makefile` are outside the boundary, and the brief does not say the tests must set the variable.

**Fix:** each autostart test sets `AINEO_CHILD` explicitly in the environment the tested Neovim starts with. `tests/test_claude.lua:149` clears it only after startup, which is too late for an autostart.

### 4. MISSING (medium): M22's kill depends on how its test is built, and the brief does not say how.

A test of "never when `$AINEO_CHILD` is set" kills M22 only when every other condition holds: a UI attached, a bare start, and `autostart = true`. In a headless child the UI check refuses first, so M22 survives.

Finding 1 leaves the brief with no working UI-attached route, so a headless `AINEO_CHILD` test is the likely result. The same holds for any refusal case; the template's own rule is that a negative case is "wrong in exactly one way".

**Fix:** say that each refusal case in EP7 and EP8 changes exactly one condition of a start that does autostart, with that positive control in the same group.

### 5. CONFIRMED (medium): EP3 and EP10 pull against each other, and the brief states both as settled.

- **EP3:** the configuration must be complete when the mappings are made. That is later than sourcing, since lazy.nvim runs `setup()` after `plugin/`.
- **EP10:** "T1's pin stands; a headless start loads none."

T1's pin reads `package.loaded` after `VimEnter`. I measured `vim.v.vim_did_enter == 1` right after `children.restart(child)`.

**Probe (run5).** I appended a `VimEnter` callback that calls `require('aineo.config').resolve_config(…)` to `plugin/aineo.lua`, ran `make test_file FILE=tests/test_plugin.lua`, then restored the file. The result:

```
FAIL … is sourced at startup and loads no aineo module
Left: { "aineo.config" }  Right: {}
```

So the obvious design breaks the pin in every headless child: mappings or the autostart check made at `VimEnter` from the resolved configuration.

**Fix:** state that the pin reads after `VimEnter`. Then either:
- require the UI check before any `require`, and a mapping approach that loads nothing in a headless start where `setup()` never ran; or
- move the pin to "sourcing loads none" and say what a headless start may load.

### 6. CONFIRMED (medium): the specialist's rules contradict C1, and the brief does not reconcile them.

- **Default mappings.** `.claude/agents/neovim-lua-developer.md` › *What bites here* says: "**No global keymaps by default** … Expose `<Plug>(…)` mappings, Lua functions and user commands". The packet is dispatched as that specialist, and the root `CLAUDE.md` makes its rules binding. But C1, D1 and D13 require the `\` prefix mapped by default.
- **Unknown keys.** The same file says "Unknown keys — typos — are reported by the health check, not checked on the hot path". EP4 puts one warning on every Open.

Under the root `CLAUDE.md`, a disagreement between documents is a spec conflict the packet reports. An implementer could stop there or pick a side.

**Fix:** one line under *What was decided already*. The plan's C1, D1 and D13 are the spec for v1 and require the default prefix mappings, over the specialist's general rule. Also say whether EP4's warning is kept or left to T8's health check.

### 7. CONFIRMED (medium-low): EP8's stand-in recipe misses how mini.starter opens, and the real mini.starter is already in `deps/`.

`deps/mini.nvim/lua/mini/starter.lua`, at the pin `1345d19`:
- l.1063 opens it on `VimEnter` with `nested = true, once = true`, running `vim.cmd('noautocmd lua MiniStarter.open()')`;
- l.1342 sets the filetype with `noautocmd silent! set filetype=ministarter`.

So no `FileType`, `BufEnter` or `BufWinEnter` fires for its buffer. A stand-in that "opens a buffer of [its] filetype" sets that filetype normally, so `FileType` fires.

**Failure scenario:** an implementation that detects a dashboard through `FileType` passes its mini.starter stand-in and misses the real one, and D15 fails for mini.starter users.

**Fix:**
- Point at `deps/mini.nvim`'s starter as the real thing for mini.starter. It is a test dependency already, so no dependency change.
- Require stand-ins to open their buffer under `noautocmd` too, or say detection must not rely on the dashboard buffer's autocommands.

### 8. CONFIRMED (low): "`origin/dev` is `bb0e185`" will be false at dispatch.

- The template (`packet-brief.md` l.3) merges the brief and plan before dispatch.
- `git ls-tree -r --name-only origin/dev knowledge-vault/Implementation/Waves/` lists nothing for `00004`. Until PR #16 lands, the evidence paths the brief cites do not exist on `origin/dev`.
- The same finding was made for wave 3 (finding 10) and fixed there as: "`origin/dev` at dispatch is `c7a9c99` followed by this wave's knowledge commits". The fix has not carried over to wave 4.

**Fix:** reuse wave 3's wording.

### 9. CONFIRMED (low): the column minimum is stated in *Facts*, but the recipe gives 80x24.

The *Facts* line (160 columns, 240 with the file column) is correct: the test-integrity review of PR #15, finding 10, found that at 80x24, 11 of 20 Send cases never see `ready`.

But the recipe a UI-attached test copies says `nvim_ui_attach(80, 24, …)`. With the terminal route, the hosting child's window sets the size: a child at 200x50 gave 200x48.

**Fix:** state the minimum in the recipe itself.

### 10. CONFIRMED (low): EP11's test has no natural home inside the boundary.

- The stack overflow is in `plain_copy` (`lua/aineo/config/init.lua`, reached from `record_setup_options`). The fix site is inside the boundary.
- T1's note records the overflow (`Sessions/2026-09-23 — T1 tooling foundation.md` l.239 and l.387).
- "`setup()` … gives one error naming `opts`" belongs beside `tests/test_aineo.lua:86`, `T['setup()']['refuses options that are not a table, naming them']`.
- The boundary opens `test_aineo.lua` only "for the pins above", and opens `test_config.lua` for EP11.

**Fix:** open `test_aineo.lua`'s `setup()` group for EP11.

### 11. CONFIRMED (low): EP9 says "wired by hand exactly as EP4 says". It was not exactly.

`t7-driver.lua` differs from EP4 in four ways:
- it ran on `c7a9c99`. The homes it used are unchanged since, except `claude/init.lua` (+19 lines, `write_to_session`), per `git diff --stat c7a9c99 bb0e185`;
- it showed the terminal with `nvim_win_set_buf`, not `layout.open`;
- it passed `cmd = { 'claude' }` literally and took `cwd` from `T7_CWD`;
- it resolved no configuration.

It also ran without `CLAUDE_CONFIG_DIR`, so it used the user's own Claude settings: the final screen reads "auto mode on". So it does not show that the call went through without a prompt *because of* `--allowedTools`.

The two claims the brief draws from it are what the run shows:
- the tool was accepted with its type-array schema;
- the call rendered in C6's format.

Using it as a one-off real-CLI fact is sound.

**Fix:** drop "exactly", and do not let the run stand for `--allowedTools`.

### 12. CONFIRMED (low): EP6's wording, and three readings the brief does not route.

- **EP6 says "Send refuses".** Under textlock, `send()` raises Neovim's `E565` and writes nothing (`lua/aineo/send/init.lua` docstring; the attack review of PR #15, finding 2). It does not refuse with a `vim.notify`.
- **Readings not routed to *Readings for the MVP review*:**
  - EP5: `\r`, `\i` and `\c` start a session when none runs. That includes restarting one that exited, and R1 names only `\o` for that.
  - EP1's one message.
  - EP4's warning on every Open.

  The plan lists only EP7's and EP8's readings.

### REFUTED: statements I tried to fault, which held

**Cited rows** (plan note at `bb0e185`, identical to PR #16's except the status and T6 lines):
- C1 (l.58), C2–C6 (l.59–63), D1 (l.38), D3 (l.40), D13 (l.50) and D15 (l.52, already on `dev`) each say what the brief says.
- R1 and R3 (l.91 and l.93) match.
- The *v1 commands* line (l.68) matches EP1–EP3.
- D14 (T6 built it) and D9 (Opus) match.

**Interfaces at `bb0e185`:**
- `resolve_config(global_settings, setup_options)` at `config/init.lua:261` returns the config and the sorted unknown keys, and raises an error naming the full path (`claude.cmd`). `recorded_setup_options` is at :244.
- `set_report_environment` at `report/init.lua:47` takes `{clock, state_directory, working_directory}`. `report_buffer` is at :138, and raises until the environment is set.
- `report_instructions(tool_name)` is at `report/instructions.lua:46`, re-exported at `report/init.lua:36`.
- `mcp_servers(editor_address, editor_program)` at `mcp/init.lua:25` checks only that both are strings. So M21's `''` reaches `deliver_report`, fails to connect, and returns `'failed'`: no report reaches the Report, and the EP9 assertion kills M21.
- `report_tool_name` is at :41 and `allowed_mcp_tools` at :49.
- `start_session(settings)` at `claude/init.lua:186` takes `{cmd, cwd, mcp_servers, allowed_tools, instructions}`. Its docstring says "5, at 80 columns", "shown in the same tick", and "takes the old one's place in every window that showed it".
- `session_status` is at :210 and `write_to_session(bytes)` at :235.
- `layout.open(arrangement)` at :592 takes `{claude, report, report_height}`. A dashboard buffer with `buftype=nofile` in the starting window is replaced by Input (`build`, `is_file`).
- `focus(role, arrangement)` at :619 opens the layout when the window is gone. `input_buffer` is at :632.
- `send()` at `send/init.lua:104` takes no argument.

**Modularity direction table** (`.claude/skills/modularity/SKILL.md` §1, l.34–42):
- `plugin/aineo.lua` may require any home's entry point, and `lua/aineo/init.lua` only `aineo.config`. The brief states both, and T7's edge is right.
- "Adding to the public API is not allowed" holds: `init.lua` could reach no other home.

**T1's pins:**
- `tests/test_plugin.lua:16` (*is sourced at startup and loads no aineo module*) and `:30` (*defines no autocommand, command or mapping*) exist, as does `tests/test_aineo.lua:23` (*exposes setup() alone*).
- No other test counts commands, keymaps or autocommands (grep for `nvim_get_commands`, `nvim_get_keymap`, `nvim_get_autocmds`, `maparg`, `mapcheck`, `hasmapto`).

**The fake:**
- It has 15 modes (`tests/helpers/fake_claude.lua:80-96`). `busy` draws `STARTUP` with `in_turn`, and `turn` exists.
- The echo fact is the brief review of wave 3, finding 2. The 160/240 fact is the test-integrity review of PR #15, finding 10. The textlock citation is the attack review of PR #15, finding 2. Each says what the brief says.

**Startup facts, re-run** (both drivers, state and log in a scratch directory, `NVIM*` and `AINEO_CHILD` unset):
- bare: `VimEnter` `uis=1 argc=0`, then `UIEnter`;
- stdin: `StdinReadPost` before `VimEnter`, `argc=0`, the buffer reads "piped";
- file: `argc=1`;
- headless: `uis=0`, no `UIEnter`;
- embed: no event before the attach, then `VimEnter` `uis=1` and `UIEnter`, and **no `VimEnter+1s`** (finding 1).

The user's shada (`1790196947`/48551) and Neovim log (`1746530923`/0) were identical before and after.

**mini.test's child is always `--headless`:** `deps/mini.nvim/lua/mini/test.lua:1186-1189`.

**EP3's plugin-manager question is real and answerable.** The user's spec is `lazy = false` with no `opts` or `config`, so lazy.nvim calls no `setup()`. How lazy.nvim orders `plugin/` against `config` is answerable from its source at a cited version.

**EP8 can be answered** through the terminal route, the real mini.starter, and stand-ins, once finding 7's `noautocmd` point is in the brief.

**Testability:**
- EP1–EP6, EP9, EP10 and EP11 are testable in headless mini.test children (EP6 at ≥160 columns).
- EP7 and EP8 are testable through the terminal route (finding 1).
- M20, M21 and M23 are killed by the tests the brief prescribes. M19 is too, with finding 2's guard, and M22 once finding 4's positive control is in place.

**Baseline, re-measured:**
- `make test` at `b02ecba`, whose code tree is `bb0e185`'s: **491 cases, `Fails (0) and Notes (0)`, rc=0**.
- `.claude/hooks/test-hooks.sh`: **78 passed**, rc=0.
- `0b52d7f..bb0e185` changes 9 files: T6's 8 code and test files, plus its session note. `9706947..bb0e185` differs only in 3 `.claude/agents` files, not in T6's files.

**Boundary:**
- It covers every file EP1–EP11 need, including new `tests/helpers/entry*` for the terminal-route helper and `tests/fixtures/entry/` for stand-in inits.
- No registration file exists: the runner globs `tests/**/test_*.lua`.
- There is no README and no `doc/`, so no documentation outside the touched files is invalidated.
- The only gaps are findings 2, 3 and 10.

**Names and prefixes:**
- The session-note filename `… — T7 entry point.md` is free. `Sessions/` holds only `2026-09-25 — Wave 3 retrospective.md` for today.
- The scratch prefix `t7-` is unused at the scratchpad's top level.

## Six rules, recomputed from the brief

| Rule | Recomputed | Result |
|---|---|---|
| 1. Dependencies | T7's row lists T3, T4, T5 and T6. All their code is on `bb0e185`: T3 PR #9, T4 PR #11, T5 PR #10, T6 PR #15, at `0b52d7f..bb0e185`. T6's row still reads "active" on `dev` until PR #16 lands. | met |
| 2. Disjoint file sets, registration files included | One packet. No registration file. The two T1 pins are inside the boundary. No `git merge-file` check is needed. | met |
| 3. At most one schema packet | None. | met |
| 4. No dependency change | None. lazy.nvim is only to be read or measured in scratch, and mini.starter is already in `deps/` at the pin. | met |
| 5. No undecided decision | D15 is the user's decision. EP7's unnamed starts and EP8's moments are routed as readings. Three things are not user decisions but are presented as settled without saying so: findings 5 and 6 (instructions that contradict each other or the specialist) and finding 12 (readings not routed). | met, with findings 5, 6 and 12 |
| 6. Task lines non-adjacent | One packet, marks held, no edit to the task list. The gap question does not arise. | met |

## Slots

Every template slot is present and non-empty: role, objective with the task verbatim, the rows it rests on, facts, baseline, read-first, branch, model, resources, may and must-not touch, session note, scratch prefix, decided, budget ("medium to large") and report.

The session note is named with a date placeholder rather than an exact filename. That is acceptable for a single packet.

The template's general line "anything outside the boundary is a spec conflict" appears only for the homes. That is a minor gap.

## Verdict

**Dispatch after these corrections.** Most important is finding 1: the brief's only route to a UI-attached start dies about 10 ms after the attach. Replace it with the terminal route, which is measured above. Close finding 2 in the same edit, so no autostart test or mutant can start the real `claude`.

Findings 3–7 each need a line or two. Findings 8–12 are wording.

## For the orchestrator

- Run M19 narrowed, and only once the headless test sets `claude.cmd` to the fake.
- A later `ai/` or T1 follow-up could make `scripts/minimal_init.lua` default `claude.cmd` to something harmless, and clear `AINEO_CHILD`, suite-wide.

## Cleanup

- Nothing was committed and nothing is left running: `pgrep -fl 'brief-w4|agent-a78859aad9cccff2c'` printed nothing.
- `git status --short` is clean at `b02ecba`. `plugin/aineo.lua` was restored from its copy after the run5 probe.
- The probes live only under the gitignored `.tests/brief-w4/`, and in the scratchpad at `brief-w4-probe/`, `brief-w4-make-test.txt`, `brief-w4-hooks.txt` and `brief-w4-deps.txt`.
- `prepare-worktree.sh review_brief_w4` created no resource; its only output was `AGENT_RESOURCE=review_brief_w4`, so nothing needs releasing.
- The user's shada and Neovim log have the same mtime and size before and after.
