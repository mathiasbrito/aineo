<!-- The brief reviewer's report for wave 2 (reviewer, Opus), verbatim except: the scratch directory written <scratchpad>, the home directory ~, and a claude.ai session link shortened — this repository is public. Its corrections are in the briefs and the plan as merged. -->

# Brief review — wave 2 (T3 layout, T4 Claude session, T5 report channel)

**Reviewer:** `reviewer`, dimension **brief**, Opus. **Base:** detached at `origin/dev` = `798275d` (`git log -1 --oneline` → `798275d Bring the wave-1 ai pass to T1's corrected head`). **Subject:** PR #6 head `c5bcc58`, `knowledge-vault/Implementation/Waves/00002-layout-session-report/` — `plan.md`, the three briefs, `evidence/`. The three briefs in the PR are byte-identical to the scratch drafts `orch-brief-t{3,4,5}-*.md` (`diff` printed nothing).
**Resource:** `review_brief_w2` (`prepare-worktree.sh` → `AGENT_RESOURCE=review_brief_w2`; `prepare_project` is empty, so nothing was created). mini.nvim fetched by `make deps` into this worktree at `1345d191…` (the Makefile's pin). Nvim `v0.11.6`. The real `claude` was never run.
**Probes:** `scratchpad/briefw2-probe/` (P1–P11, runner `run.sh`, every probe under `--clean` with all four `XDG_*` and `NVIM_LOG_FILE` pointed into that directory, `NVIM` unset); the MCP pages fetched raw into `scratchpad/briefw2-mcp/`.

Question: **would an implementer acting on these briefs be misled?** Yes, in five places that would cost a packet a failed design or a surviving mutant (1–5), and in a dozen smaller statements. None needs a change of composition; every correction is text in a brief, the plan or `evidence/`.

---

## Findings, most severe first

### 1. CONFIRMED — T3 and T5: an unnamed, empty `nofile` buffer is reused by `:edit`, so Input and the Report can be turned into the user's file, and the next report is written into it
*Briefs:* T3 l.16 ("It is not a file (`'buftype'` `nofile`, so the redirect never takes it for one)"), L2 l.24 (the startup buffer becomes Input), L7 l.29 ("the aineo window gets its own buffer back, the same buffer number"), l.15 (the Report stand-in is "a scratch buffer"); T5 R3 l.31 describes the Report buffer (nofile, no swap, hidden-kept, read-only) with no name.
*Measured (P2, Nvim 0.11.6):* `:edit <file>` from a window showing an unnamed, empty buffer reuses that buffer (Nvim's `curbuf_reusable`) — `'buftype'` `nofile`, listed or not, `'modifiable'` off or on:

```
startup buffer made nofile                 before=1 after=1 same=true buftype(after)="" name(after)=p2-file-1.txt
nvim_create_buf(false, true) scratch       before=2 after=2 same=true buftype(after)=""
scratch, nomodifiable (a read-only Report) before=4 after=4 same=true buftype(after)=""
scratch, named aineo://input               before=5 after=6 same=false
scratch holding one line of text           before=7 after=8 same=false
```

*Failure scenario (P11):* a new directory, no report yet; the user types `:edit init.lua` in the Report window. Buffer N — the one `aineo.report` holds — becomes `init.lua` (`buftype ""`, `modifiable true`). The redirect cannot give the Report window "its own buffer back": that number now names the file. The next report is appended by the home to buffer N:

```
the user file buffer now reads: { "return { user = true }", "06:30 [done] task — summary" } modified=true modifiable=false
```

— the report is inside the user's file, which is marked modified and left non-modifiable. The same happens to an empty Input (L2's startup buffer, or a new Input before the user types).
*Correction:* both briefs state that the Input and the Report buffers carry a name from the moment they are made (e.g. `aineo://input`, `aineo://report` — measured: a named scratch buffer is not reused, case 5), with a test each: `:edit <file>` in the window showing the *empty* buffer leaves the buffer's number, name and `'buftype'` intact. T3's Report stand-in is named too, and one L7 case runs with Input empty. This is the T3↔T5 contract: add "the Report buffer is named" to T5's R3 and to T3's "what the layout is handed".

### 2. CONFIRMED — T3: L4 cannot be met by the pins C2 names, and M10 cannot be killed by it
*Brief:* L4 l.26 — "After `:wincmd =`, and after a window elsewhere in the tab is split and closed, the three windows keep their widths and heights"; M10 l.76 — "remove the setting that pins Claude's window's width → the L4 test fails".
*Measured (P3d, inside a child from mini.test v0.18.0's `new_child_neovim()`, 80×24, D4 at 40 | 39 and Report 14 over Input 7, `'winfixwidth'` and `'winfixheight'` on all three; "M10" = Claude's `'winfixwidth'` off):*

| perturbation | all pinned | M10 |
|---|---|---|
| `:wincmd =` | kept (40, 14/7) | kept (40) |
| `:split` then `:close` in Input | **Report 14→10, Input 7→11** | same |
| `:vsplit` then `:close` in Input | **Claude 40→20** | Claude 40→11 |
| `:vertical botright new` then `:close` | **Claude 40→20** | Claude 40→19 |
| `:topleft vnew` then `:close` | **Claude 40→61** | kept (40) |
| `:help` from Input then `:close` | kept | kept |
| D6 (file column open), `:vsplit`+`:close` in Input | Claude kept 26 (Report/Input 26→45) | Claude 26→13 |
| D6, `:vertical botright new`+`:close` | Claude kept 26 (file 26→5) | Claude 26→16 |

`:wincmd =` cannot kill M10: D4's two columns are already equal. Every D4 split-and-close either changes a pinned window too (so L4 fails against the correct implementation) or changes nothing in either variant; no D4 perturbation keeps the pinned width while moving M10's. `:topleft vnew` is worse pinned than unpinned. Only with the file column open does a perturbation separate M10 — and then the pinned Report and Input widths still move.
*Failure scenario:* the implementer writes L4 as stated; it fails on the correct pins, so they add an active re-apply (on `WinClosed`/`WinNew`), which restores Claude's width whatever `'winfixwidth'` says — M10 then survives; or they keep only the perturbations that pass (`:wincmd =`, `:help`) — M10 survives.
*Correction:* restate L4 from the measurement: after `:wincmd =` all sizes are kept; with the file column open, after `:vertical botright new` then `:close`, Claude's width is kept (26 vs 16 under M10) — assert on Claude's width only. State that split-and-close elsewhere is **not** held by the options alone (heights and the other widths move), and either drop that half of L4 or make it an explicit re-apply behaviour with M10 redefined against it. Also measured, confirming L6's premise: in the child, `'columns'` 80→120 fires `VimResized` once and the pinned Claude window keeps 40 columns while the right column takes 79.

### 3. CONFIRMED — T4 and T5: M4 and M7 survive a test that compares decoded JSON
*Briefs:* T4 S2 l.30 ("one JSON string whose decoded value is `{ "mcpServers": <the servers given> }`"), M4 l.93; T5 M1 l.38, M7 l.91.
*Measured (P5):* `MiniTest.expect.equality(vim.json.decode('{"env":[]}'), { env = vim.empty_dict() })` **passes**; `vim.deep_equal(vim.json.decode('[]'), vim.json.decode('{}'))` is `true`. An S2 or M1 test written as "the decoded value equals the expected table" cannot see `[]` for `{}`.
*Correction:* tell both packets how the kill is observable — assert on the raw text (`"env":{}`), or re-encode what was decoded (measured: `vim.json.encode(vim.json.decode('{}'))` is `{}`, of `'[]'` is `[]`), or compare `getmetatable(decoded.env)` with `getmetatable(vim.empty_dict())` (measured: equal for `{}`, `nil` for `[]`).

### 4. CONFIRMED — T4 (with T3): S6's wipe closes the layout's left window on every restart
*Brief:* S6 l.34 — "Restarting an exited session starts a new process in a new terminal buffer, which the caller receives …; the old terminal buffer is wiped".
*Measured (P9):* a dead terminal buffer (`[Process exited 0]`) shown in the left of two windows; `nvim_buf_delete(old, { force = true })` closes that window, whether or not it is the current one — the tab goes from 2 windows to 1.
*Failure scenario:* R1's restart (`\o` after an exit): the dead buffer is still in T3's pinned Claude window; S6 wipes it; the window closes; the layout is down a column until the caller notices and re-opens it — and T3's L5/L12 re-open with the buffer they were last handed, now invalid.
*Correction:* S6 says the new buffer takes the old one's place in every window showing it (`vim.fn.win_findbuf(old)`) before the old is wiped, with a test: a window showing the dead buffer shows the new one after restart and is still valid. That stays inside `aineo.claude` (it owns the buffer; it does not need `aineo.layout`).

### 5. CONFIRMED — T4 S7: the stop timings are attributed to the wrong press, and part of them to a run not in `evidence/`
*Brief:* l.37 — "a double Ctrl-C (two `\3`, 0.3 s apart) at idle exits 0 — with or without text in the input box — within about 1.6–2.9 s of the second press".
*Evidence:* `t4-driver.lua:30-31` takes `t0` **before the first** `\3`; the two measured exits, 1939 and 2843 ms (`t4-screens.txt:48,100`), are from the first press — ≈1.64 and ≈2.54 s from the second. The empty-prompt case ("without text", 1759 ms), `/exit` (1766 ms) and Ctrl-D (1614 ms) appear only in `t2-summary.txt:22-24`: the committed `t2-driver.lua:38-39` presses 1.2 s apart, and `t2-run2-screens.txt` holds only the two 1.2 s non-exits (l.120, l.216) and `jobstop` 1648 ms (l.241). No driver or screen for a 0.3 s idle double press at an empty prompt is in `evidence/` (nor in the orchestrator's scratch output files).
Also not stated: the one measured mid-turn success waited **2.5 s** between the single `\3` and the double (`t4-driver.lua:55`, `vim.wait(2500)`); how long the turn takes to end after the first press was not measured. "Derive yours from the phases" gives the implementer no figure for the first phase.
*Correction:* "1.6–2.5 s after the second press (1939 and 2843 ms after the first, `t4-screens.txt`)"; mark the empty-prompt, `/exit` and Ctrl-D figures as from a run whose record is not kept (or re-record it); name the 2.5 s gap as the only one known to work.

### 6. CONFIRMED — T5 M1: the `tools/call` recording is cited to a file that does not hold it, and no raw message exists in `evidence/`
*Brief:* l.37 — "a `tools/call` carries `name`, `arguments` and `_meta` (`claudecode/toolUseId`, `progressToken`) (`evidence/t2-summary.txt`). Build your client-side test messages from these recordings".
*Evidence:* `grep -rn "_meta\|toolUseId\|progressToken" evidence/` → only `t4-summary.txt:25-26`, as key names. No raw `tools/call` line is committed; the raw params exist only in the orchestrator's scratch `t2-probe/mcp.log` — `{"name": "ping", "arguments": {"note": "t2"}, "_meta": {"claudecode/toolUseId": "toolu_…", "progressToken": 2}}` — and the request's `id` was never logged.
*Correction:* cite `t4-summary.txt`; commit the raw params line (with the tool-use id replaced) or say the `tools/call` test message is reconstructed from the key names, not recorded.

### 7. CONFIRMED — T5 M1: "error `-32700` and `id` null" contradicts MCP 2025-11-25
*Brief:* l.43. *Standard (read raw, `docs/specification/2025-11-25/basic/index.mdx`, "Error Responses"):* `id?: string | number` — "Error responses MUST include the same ID as the request they correspond to (except in error cases where the ID could not be read due a malformed request)"; `schema/2025-11-25/schema.ts:159-162` `JSONRPCErrorResponse { id?: RequestId }`, with `RequestId = string | number` (l.122). Base JSON-RPC's `null` is not a valid MCP id; MCP omits it. The brief's reading list (l.68) names *Lifecycle* and *Tools* only; the rule is on the *Overview* page.
*Correction:* "with no `id`" and add `basic/index` (Overview → Messages) to the pages read raw. Everything else in M1 checked true — see REFUTED.

### 8. CONFIRMED — T4 S8: the terminal-query list names two queries Neovim does not answer and omits the five it does
*Brief:* l.48 — "terminal queries (DA, `ESC[16t`, a kitty graphics query) whose answers Neovim's terminal writes back to the fake's input".
*Measured (P7):* a POSIX-sh stand-in in raw mode replays the recorded bytes in a `jobstart` terminal and records its input. Neovim 0.11.6 (libvterm 0.3) writes back XTVERSION `ESC P>|libvterm(0.3) ESC \` (×2), kitty-keyboard flags `ESC[?5u`, DA1 `ESC[?1;2c` (×4), DECRQM `ESC[?2026;0$y` (×2) and `ESC[?1016;0$y`, and 16 DECXCPR cursor reports (`ESC[?20;3R` / `ESC[?20;14R` at 120×40 — they depend on the terminal's size). Nothing answers `ESC[16t` or the kitty graphics query. Also confirmed, as the brief says: raw mode receives the byte `\3`; cooked mode receives SIGINT (the stand-in exited 130).
*Correction:* replace the list with the measured one.

### 9. CONFIRMED — T5 M8: "(and so does R5's pin)" is false for the pin the brief describes
*Brief:* R5 l.33 — "lists every status from the one list (a pin: every status appears in it)"; M8 l.92. A pin that iterates the module's list checks the instructions against the list they are generated from: with `blocked` removed from both, it passes. Only a pin naming C6's five statuses literally fails.
*Correction:* "R5's pin names C6's five statuses in the test, not from the module's list".

### 10. CONFIRMED — all three: the deep-require check each brief orders flags every require of a home's own files
*Briefs:* T3 l.43, T4 l.58, T5 l.57 — "`grep -rnE "require\(['\"]aineo\.[a-z_]+\." lua plugin tests scripts` — prints nothing on `origin/dev`; run it before you report." True at `798275d` (printed nothing), but T1's home is one file; wave 2's are the first with several. Demonstrated: the pattern matches `require('aineo.mcp.protocol')` and `require('aineo.report.render')` wherever they sit, and passes `require(... .. '.protocol')`. The rule it stands for forbids only requires from **outside** a home (modularity §1, "no `require` reaches past a home's entry point"; `neovim-lua-developer.md`: "`require('<plugin>.<concern>.<file>')` from outside is a deep import").
*Failure scenario:* T5 splits `lua/aineo/mcp/` into protocol, relay and entry files, requires them by full path, the check prints three lines, and the packet either crams the home into `init.lua`, invents a relative-require convention alone, or stops on a spec conflict.
*Correction:* each brief says how a home requires its own files (and whether the check's intra-home hits are expected and listed in the report), the same way in all three.

### 11. CONFIRMED — T3 L3 cites D5 for something D5 does not say
*Brief:* l.25 — "the orchestrator's reading, since D5 rejected a new tab". D5 (plan l.42): "Files open in a middle column … — superseding 'files in a new tab'" — it rejects a new tab **for files**, not for the layout. L3 (closing the user's other windows) is also the reading nearest to a rule-5 behaviour; the user's standing order lets it go to the MVP review, but not on a borrowed citation. *Correction:* drop the D5 clause; keep it as a reading.

### 12. CONFIRMED — plan: L12 is a reading in the table but not in the list for the user, and not marked in the brief
*Plan:* l.42 — T3 "readings stated (L1, L3, L6, L11, L12)" (12 ids across the table); l.65-67 lists eleven, without L12; the commit message says "Eleven readings". T3's L12 (l.34 — "reopening the layout first when that window is gone") carries no "the orchestrator's reading". *Correction:* either mark L12 in the brief and add it as the twelfth item, or drop it from the table.

### 13. CONFIRMED (minor) — T4: R2 at its row says SIGINT; the brief says keys before any signal
*Brief:* l.11 summarises R2 as "quitting Neovim stops Claude, interrupting first", l.35 "by the keys a user would press, before any signal", and l.11 tells the packet to read the rows, "not this summary". R2 (plan l.89) still reads "interrupting first (SIGINT)". The Q4 resolution (plan l.92) reconciles it, but the brief does not say so. *Correction:* one clause — R2's interrupt is carried out as the Ctrl-C byte, which the TUI reads in raw mode (Q4, resolved 2026-09-24).

### 14. MISSING — T4: what the stop costs at every test's teardown, and what M6's killing test must assert
*Measured (P6):* mini.test's `child.stop()` sends `silent! 0cquit` over RPC; that fires `VimLeavePre` in the child and the call **blocks until the handler returns** — `child.stop() returned after 3044 ms` for a 3 s handler (the 1000 ms `jobwait` is not the bound). With S7's reading (register the stop when the process starts), every test that leaves a session running pays the whole stop at teardown. The *ready* fake as bulleted (l.43, "then echoes what it receives") does not exit on a double `\3`, though S7 measured that the idle CLI does — so every ready-mode teardown runs to the fallback's bound. *Also measured (P1, P1b):* `:qa` without `!` with a terminal job running quits Nvim 0.11.6 at once, `QuitPre` and `VimLeavePre` fire, no E948/E37 — the brief's "nothing" option is the answer.
*Correction:* every fake mode except *deaf* exits 0 on the measured double `\3` at idle; name the teardown cost; say M6's busy test asserts the fake's own record of how it ended (exit 0 on keys, no SIGHUP) — the fallback stops it under M6 too, so "no `claude` outlives Neovim" does not kill M6.

### 15. CONFIRMED (minor) — T4 S4: the settle cannot be "derived" from the sources named
*Brief:* l.32 — "derive whether readiness waits after the glyph from what the fake and the recorded bytes show". The bytes file is one 2964-byte stream with no timing; the fake replays whatever the packet writes. Neither can show whether the real CLI takes input sent right after the glyph. *Correction:* say it is unmeasured; the packet chooses and states it as a reading for the MVP list (it moves C4's refusal window).

### 16. CONFIRMED — evidence (and T4's copy instruction): the recorded bytes carry a live claude.ai session link
`t4-claude-2.1.281-startup-paste-exit.bytes.txt`, byte 1582: an OSC 8 hyperlink to `https://claude.ai/code/<remote-control-link>` (the `/rc` Remote Control link) — after the ready prompt (byte 1027) and before the paste (byte 2048), i.e. inside the idle-startup stretch a *ready* fake would replay. The commit message says the evidence's tier and home path were replaced "since the repository is public". T4 l.43 tells the packet to "copy what you use into your fixtures" under `tests/fixtures/claude/`. *Correction:* replace the link in `evidence/` before merge, and tell T4 to copy only through the ready prompt or scrub the link.

### 17. CONFIRMED (minor) — all three: "about 87 s on the orchestrator's host" names no run
T3 l.40, T4 l.55, T5 l.53. The figure is the T1 correction agent's (its report: "111 cases, 0 fails, in 87, 88 and 87 s" at `5b323d8`), not the orchestrator's baseline run — `evidence/baseline.txt` records no time. Re-measured here: **85 s** at `798275d` (`rc=0 seconds=85 at 798275d 2026-09-24 06:12 CEST`). *Correction:* attribute it to the run.

### 18. UNVERIFIABLE — plan l.25: "with every `CLAUDE*` variable … removed, except in T2's first run"
For the trust-dialog screen (F6, Claude Code 2.1.280, the afternoon of 2026-09-23) the environment is not recorded (`t4-trust-dialog-screen.txt` header: "Text copied from that session's tool output"), and that spike predates T2's run 1, which found the leak. Related, minor: `t2-summary.txt` ("Worked in both runs") and T4 S4 ("worked in every run") — T2's run 1 waited on the footer (`READY=false`) and sent no input, so the glyph-plus-settle was not exercised there.

### Lesser notes (no finding number; the packets are not misled, reviewers may be)
- **Ambient reads.** T5 injects the clock (R2) but R4 reads the working directory and `stdpath('state')`, and M3 `v:progpath`; T4's facts allow `aineo.config` to be read "if you read `claude.cmd` from it rather than receiving it", while the same list says the root "hands each home the values it needs". `neovim-lua-developer.md` puts ambient reads in the composition root or behind injection. One sentence per brief would save a review round.
- **`tests/fixtures/{claude,mcp}/`** is a new tracked directory; modularity §1's `tests/` row says shared support lives in `tests/helpers/`. Harmless (the runner collects `test_*.lua` only; fixtures are text), but no document names it.
- **Plan l.55**, "the three implementers take the limit; reviews run … three at a time" — read literally, three reviews beside two running implementers is five agents on a limit of three.
- **Session-note names** are patterns with the date left open and, unlike wave 1's brief, no `-b` fallback. The three topics differ, so they cannot collide (REFUTED below).

---

## REFUTED — suspected and found true

**Task ids and rows.** T3, T4 and T5 lines are verbatim from the plan's table (plan at `c5bcc58` l.100-102). Every cited row read at the row and says what the brief claims: T3 — C2, C9, D4 (incl. "the startup empty buffer becomes Input"), D5 (except finding 11), D6, D7, D13, F3, A5; T4 — C3, D2, D8, D10, D11 ("raises no permission mode and answers no prompt"), D13, R1, R2 (finding 13), Q4 (as resolved in this PR), F6; T5 — C5, C6, D8, D11, F4, A1, A3, A4. The T4 row's amended *Depends on* is not a D# or C# row, so the Authority section allows it.

**Paths and symbols on `origin/dev`.** `git log`: T1 is nine commits `5edf69f` … `7284c00`, the ai pass `12353b2`, `83c263e`, `798275d`. Top level exactly the fourteen names listed. `lua/aineo/` holds `init.lua` and `config/init.lua` only; `lua/aineo/{layout,claude,mcp,report}/` absent. `tests/helpers/` holds `child.lua`, `fixture.lua`, `git.lua`, `make.lua`; `dofile('tests/helpers/child.lua')` at `tests/test_plugin.lua:2`; `child.restart(child, extra_args)` as described; `fixture.directory` / `fixture.write` under `.tests/fixtures/`. `resolve_config` (`config/init.lua:261`), `record_setup_options` (:235), `recorded_setup_options` (:244) as described; nothing calls `resolve_config` at startup (`plugin/aineo.lua` sets `vim.g.loaded_aineo` only). Makefile: the five targets, the six isolation variables under `.tests/`, `stdpath('state')` = `.tests/state/nvim`; `run_tests.lua:128` collects `globpath('tests', '**/test_*.lua')`; `RUN_TIME_LIMIT_MS = 16 * 60 * 1000` (:59). The deep-require check prints nothing at `798275d`.
**`child.job.address`** — mini.nvim `1345d19` `lua/mini/test.lua:1176` `local job = { address = vim.fn.tempname() }`, :1186 `'--listen', job.address`, kept as `child.job` (:1215). True.
**Modularity §1** — `layout` and `report` may require `config`; `mcp` may require `config`, `report`; `claude` may require `config`, `mcp`. The briefs quote it correctly.

**Baseline.** Re-measured at `798275d` in this worktree: `Total number of cases: 111`, `Fails (0) and Notes (0)`, exit 0, 85 s. `git diff --stat 5b323d8 798275d -- lua plugin scripts tests Makefile neovim.yml selene.toml .stylua.toml` prints nothing. `.claude/hooks/test-hooks.sh`: `78 passed`, exit 0.

**Standards.** MCP 2025-11-25 read raw: version negotiation (Lifecycle, "Version Negotiation": same version if supported, else another, SHOULD be the latest) matches M1; `ping` → empty `result` (utilities/ping); unknown tool → `-32602` protocol error, input validation → `isError: true` result (Tools, "Error Handling"); notifications get no response (Overview); `-32700`, `-32601`, `-32602` in `schema.ts:173-176`; `capabilities.tools` an object; `inputSchema` `type: object`, `additionalProperties: false` recommended. `:h` in 0.11.6: `BufWinEnter` (autocmd.txt:307), `'winfixwidth'` / `'winfixheight'` (options.txt:7209, 7217 — "The width may be changed anyway"), `'buftype'` (:1172), `VimResized` (autocmd.txt:1145, "Not when starting up"), `E1513` (message.txt:117), `$NVIM` set by `jobstart()` (vvars.txt:565). The default `TermClose` autocommand closes only terminals started as `'shell'` (news-0.10), so S5's `[Process exited N]` stays for `claude.cmd`.

**Evidence, at its stated scope.** Handshake order and ids, and the server's `NVIM`, `AINEO_CHILD`, `AINEO_PROBE` (`t2-handshake.txt:4-9`); Q1 and Q2 with the control (`t2-summary.txt:13-19`); presses 1.2 s apart do not exit (`t2-run2-screens.txt:120, 216`); `jobstop` → 129 (:241, `t4-screens.txt:148`); one `\3` mid-turn keeps the process and puts the text back (`t4-screens.txt`, MIDTURN-ONE); a double `\3` mid-turn does not exit within 10 s (MIDTURN-DOUBLE); the trust dialog's selected line carries `❯`; `type = 'stdio'` entries worked (both drivers). Versions (2.1.281, trust dialog 2.1.280) are stated where used.

**Measured behaviours the briefs rely on.** `:qa` with a running terminal job (P1, P1b) — see 14. VimResized in a mini.test child and the pinned width (P3d) — see 2. Raw/cooked Ctrl-C (P7) — see 8. C5's relay shape: `nvim --headless --clean -l` reads stdin line by line, sees EOF, exits 0 (P8); under `-l`, `print`, `vim.notify`, `:echo` and `nvim_echo` go to **stderr**, not stdout (P10) — no MCP stream pollution; an unprotected failed `sockconnect` raises (exit 1), consistent with M2's "keeps serving" requiring a `pcall`.

**Contract T4 ↔ T5.** Both tables give the same three values in the same shapes (servers `{ aineo = { type = 'stdio', command, args, env } }`, tools `{ 'mcp__aineo__report' }`, instructions one string); T5's `env` always carries the address, T4 must still encode an empty one as an object — consistent. T4 requires neither `aineo.mcp` nor `aineo.report`. The injection argument holds: nothing T4 builds or tests needs T5's code. **T3 ↔ T5** is consistent except the name (finding 1).

**Boundary.** Every file each packet creates is in its may-touch list; no packet needs a registration file (collection by glob, `make lint` by directory; `.gitignore` ignores only `/deps/` and `/.tests/`, so `tests/fixtures/` can be committed). No existing pin counts what the packets add: `tests/test_plugin.lua`'s startup pins (no aineo module loaded, no autocommand/command/mapping) hold because no packet touches `plugin/`. No document is invalidated. Forbidden paths contradict nothing the tasks need. Session notes `… — T3 layout.md`, `… — T4 Claude session.md`, `… — T5 report channel.md` are distinct and free (`Sessions/` at `c5bcc58`: two 2026-09-23 notes and the wave-1 retrospective). Scratch prefixes `t3-`, `t4-`, `t5-` are distinct from each other and from every existing scratch file. Resource names pass `prepare-worktree.sh`'s `^(impl|review)(_[a-z0-9]+)+$`.

**Slots** (`packet-brief.md`), all three: role (and specialist file), objective with verbatim task line, rests-on, facts, baseline (pasted, evidence file named), read-first, branch, model, resources, may touch (with "no existing document"), must not touch, session note, scratch prefix, spec-conflict line, decided, budget (T3, T4 medium to large; T5 large), report path and shape — present and non-empty.

---

## Plan mutants — assessed against the tests each brief describes

| mutant (literal edit) | brief's killing test | as specified | evidence |
|---|---|---|---|
| M4 — `--mcp-config` entry's empty `env` built as `{}` | S2 | **survives** a decoded-equality S2 | P5 (finding 3) |
| M5 — readiness on the glyph alone | S4 *trust* | killable: the trust screen carries `❯ No, exit` | `t4-trust-dialog-screen.txt:13` |
| M6 — stop sequence without its first `\3` | S7 *busy* | killable **only** if the test asserts the fake ended on keys; the fallback stops it anyway | finding 14 |
| M7 — `capabilities.tools` built as `{}` | M1 | **survives** a decoded-equality M1 | P5 (finding 3) |
| M8 — `blocked` removed from the one list | R1 (`blocked` refused) and R5's pin | R1 kills; R5's pin as described does not | finding 9 |
| M9 — one persistence file for every directory | R4 other-directory | killable | — |
| M10 — Claude's width not pinned | L4 | **not killable** by `:wincmd =` or any D4 split-and-close; killable in D6 on Claude's width only | P3d (finding 2) |
| M11 — redirect leaves the file in the aineo window | L7 | killable (once finding 1 is fixed, or the Input case is never green) | — |
| M12 — new file column on every redirect | L9 | killable | — |

**Summary: 9 plan mutants assessed — 4 killable as specified (M5, M9, M11, M12), 1 killable by one of its two named tests (M8), 4 need a test the brief does not describe (M4, M6, M7, M10). No code mutant was run: there is no code yet.**

---

## The six rules, recomputed from the briefs

| rule | T3 | T4 | T5 | result |
|---|---|---|---|---|
| 1. Dependencies | T1 (landed) | T1 (landed), T2 (done in this PR), T5 removed by injection — holds | T1, T2 | **pass**, once PR #6 is merged |
| 2. File sets disjoint, registration files included | `lua/aineo/layout/**`, `tests/test_layout*.lua`, `tests/helpers/layout*` | `lua/aineo/claude/**`, `tests/test_claude*.lua`, `tests/helpers/{claude,fake_claude}*`, `tests/fixtures/claude/**` | `lua/aineo/{mcp,report}/**`, `tests/test_{mcp,report}*.lua`, `tests/helpers/{mcp,report}*`, `tests/fixtures/mcp/**` | **pass** — no shared file, so no `git merge-file` to run; `make test` collects by glob, `make lint` by directory; the plan's registration grep prints nothing and its positive control hits `lua/aineo/config/init.lua:50` |
| 3. At most one schema packet | none | none | none | **pass** |
| 4. No dependency change | none | none (fake in sh or `nvim -l`) | none | **pass** — mini.nvim stays at `1345d19` |
| 5. No undecided decision | L1, L3, L6, L11 (+L12 unlisted) | S3, S6, S7 (+ the settle, finding 15) | R2, R3, R4, R5 | **pass after corrections** — none needs the user before dispatch under the standing order of 2026-09-23 23:41; L12 and the settle must be listed; L3 is the nearest to a behaviour decision |
| 6. Task lines | row l.100 | row l.101 | row l.102 | adjacent, gaps 0 — **pass by held marks**: all three briefs forbid the plan note and ask for `## Task lines` |

---

## Verdict

**The briefs would mislead.** The two statements most likely to cost a packet its design are finding 1 (a `nofile` Input or Report is still reused by `:edit`, and the Report home then writes reports into the user's file) and finding 2 (L4 is unattainable with the pins C2 names, and M10 cannot die by it); three more would let a plan mutant survive or break the layout at integration (3, 4, and M6 in 14). **Single most important change before dispatch:** state in T3 and T5 that the Input and Report buffers are named from creation, with the empty-buffer `:edit` test — the only finding whose failure reaches the user's files.

- **T3 (layout): dispatch after corrections** — 1, 2, 10, 11, 12 (and the T3 side of 4: the Claude window shows whatever buffer the caller hands it after a restart).
- **T4 (Claude session): dispatch after corrections** — 3, 4, 5, 8, 10, 13, 14, 15, 16.
- **T5 (report channel): dispatch after corrections** — 1, 3, 6, 7, 9, 10.
- **Plan:** 12, 17, 18, and the lesser notes.

## For the other dimensions

- **Records (PR #6):** finding 16 — the committed bytes carry a claude.ai session link although the commit says the evidence was scrubbed for a public repository; `Projects/aineo.md` (this PR) sends Q5 "to the user at the MVP review" while the plan's Q5 row says "converged with the user before T7 is dispatched"; the plan cites `brief-review.md`, which does not exist yet; the plan quotes the user's order without its opening "I changed my mind," (the ledger has it verbatim).
- **Attack / test-integrity (future T3–T5 reviews):** re-run P2/P11 (buffer reuse), P3d (pins), P5 (decoded equality), P9 (wipe) against the packets' heads; the probes are in `scratchpad/briefw2-probe/`.

## Cleanup

- Resource `review_brief_w2`: `prepare-worktree.sh` printed `AGENT_RESOURCE=review_brief_w2`; its `prepare_project` is empty, so nothing was created and nothing is left to release.
- Processes: every probe Nvim exited (`rc=` lines in each output); the mini.test children were stopped by `child.stop()`; P6 confirmed its child gone (`child alive right after stop: false`). `pgrep -fl "sleep 30"`, `pgrep -fl briefw2`, `pgrep -fl "stty raw"` printed nothing.
- Files: only `briefw2-*` under the scratchpad (probes, MCP pages, `briefw2-maketest.log`, `briefw2-hooks.log`, `briefw2-pr/` extract) and this report; `deps/` and `.tests/` exist only inside this worktree. Nothing committed, pushed or dispatched; the worktree is left in place, detached at `798275d`.
